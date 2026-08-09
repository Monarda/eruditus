import unittest

from scripts.spell_import import blocks, sources


class ParseDefinitiveEditionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        cls.blocks, cls.problems = blocks.parse_de(lines)

    def test_finds_exactly_360_spells(self):
        self.assertEqual(len(self.blocks), 360)

    def test_reports_no_parse_problems(self):
        self.assertEqual(self.problems, [])

    def test_every_spell_has_a_technique_and_form(self):
        for block in self.blocks:
            self.assertTrue(block.technique, block.name)
            self.assertTrue(block.form, block.name)

    def test_creo_terram_spells_are_not_filed_under_rego_mentem(self):
        # The DE has "### Creo Terram Guidelines" and no "### Creo Terram
        # Spells" heading. A parser keying off the "Spells" suffix files these
        # four under the previous section, Rego Mentem.
        tower = next(b for b in self.blocks if b.name == "Conjuring the Mystic Tower")
        self.assertEqual((tower.technique, tower.form), ("Creo", "Terram"))
        for name in ["Seal the Earth", "Touch of Midas", "Wall of Protecting Stone"]:
            block = next(b for b in self.blocks if b.name == name)
            self.assertEqual((block.technique, block.form), ("Creo", "Terram"), name)

    def test_general_level_spells_have_no_printed_level(self):
        general = [b for b in self.blocks if b.printed_level is None]
        self.assertEqual(len(general), 33)

    def test_a_known_spell_parses_completely(self):
        block = next(b for b in self.blocks if b.name == "Soothe Pains of the Beast")
        self.assertEqual((block.technique, block.form), ("Creo", "Animal"))
        self.assertEqual(block.printed_level, 20)
        self.assertTrue(block.stat.is_ritual)
        self.assertEqual(block.stat.range_name, "Touch")
        self.assertEqual(block.design_line, "(Base level 15, +1 Touch)")

    def test_three_spells_have_no_design_line(self):
        missing = sorted(b.name for b in self.blocks
                         if b.design_line is None and b.printed_level is not None)
        self.assertEqual(missing, [
            "Enchantment of the Scrying Pool",
            "Hermes' Portal",
            "Whispering Winds",
        ])

    def test_creature_powers_are_excluded(self):
        names = {b.name for b in self.blocks}
        self.assertNotIn("Crush", names)
        self.assertNotIn("Healing Gaze", names)

    def test_ward_against_the_beasts_of_legend_gets_the_general_design_line(self):
        # (As ward guideline) is its own General shorthand, distinct from the
        # "(Base ...)" family _DESIGN otherwise looks for.
        block = next(b for b in self.blocks
                    if b.name == "Ward against the Beasts of Legend")
        self.assertEqual(block.design_line, "(As ward guideline)")

    def test_special_and_variable_design_notes_are_not_mistaken_for_a_design_line(self):
        # Recognising "(As ward guideline)" must not widen _DESIGN into a
        # catch-all for every one-line parenthetical note. "(Special spell)"
        # and "(Variable base)" are prose asides of their own, not a design
        # line by any name, so they stay part of the prose and design_line
        # stays None -- exactly as before the widening.
        special = next(b for b in self.blocks
                       if b.name == "Enchantment of the Scrying Pool")
        self.assertIsNone(special.design_line)
        variable = next(b for b in self.blocks
                        if b.name == "Sight of the True Form")
        self.assertIsNone(variable.design_line)

    def test_seven_spells_have_no_design_line(self):
        # The exact-set regression guard for the _DESIGN widening: 8 spells
        # had no design line before "(As ward guideline)" was recognised;
        # Ward against the Beasts of Legend resolved out of that set, leaving
        # these 7. Pinning the full set (not just a count, and not just the
        # two spot-checked above) is what would notice a future regex change
        # quietly moving a *different* spell instead.
        #
        # Ward against Faeries of the Mountain belongs on this list on
        # purpose: it has no design line at all. Its entry cross-references
        # "Ward Against Faeries of the Waters" in prose ("As Ward Against
        # Faeries of the Waters (ReAq Gen), but for faeries of earth and
        # stone") rather than printing a parenthetical, so it is not a
        # candidate for the widening and stays blocked.
        missing = sorted(b.name for b in self.blocks if b.design_line is None)
        self.assertEqual(missing, [
            "Aegis of the Hearth",
            "Enchantment of the Scrying Pool",
            "Hermes' Portal",
            "Sight of the True Form",
            "Ward against Faeries of the Mountain",
            "Whispering Winds",
            "Wizard's Vigil",
        ])

    def test_continuation_line_requisite_is_read(self):
        # "The Beast Remade" (Muto Corpus) prints its requisite on the line
        # after the stat line:
        #   R: Touch, D: Sun, T: Ind<br>
        #   Req: Corpus<br>
        # parse_statline never sees that second line unless blocks.py folds
        # it in first.
        block = next(b for b in self.blocks if b.name == "The Beast Remade")
        self.assertEqual(block.stat.requisite_arts, ["Corpus"])

    def test_continuation_line_requisite_does_not_leak_into_prose(self):
        # The same unread line used to be appended to prose_lines, so the
        # description came out prefixed "Req: Corpus Gives one land beast...".
        block = next(b for b in self.blocks if b.name == "The Beast Remade")
        self.assertFalse(block.prose.startswith("Req:"), block.prose[:40])

    def test_continuation_line_with_multiple_arts_is_read(self):
        # "Fog of Confusion" prints "Req: Imaginem, Rego" on its
        # continuation line -- both arts must survive the fold and the
        # comma split in statline._REQ.
        block = next(b for b in self.blocks if b.name == "Fog of Confusion")
        self.assertEqual(block.stat.requisite_arts, ["Imaginem", "Rego"])

    def test_blank_line_between_stat_line_and_requisite_is_tolerated(self):
        # No spell in the current book actually has a blank line here (every
        # one of the 45 continuation lines sits immediately below its stat
        # line), but the fold must not depend on that -- it looks past
        # blank lines rather than only at index + 1.
        lines = [
            "##### A Made-Up Spell",
            "R: Touch, D: Sun, T: Ind",
            "",
            "Req: Corpus",
            "A description sentence.",
            "(Base 5, +1 Touch, +2 Sun)",
        ]
        blocks_found, problems = blocks.parse_de(
            ["### Muto Corpus Spells", "#### LEVEL 10"] + lines
        )
        self.assertEqual(problems, [])
        self.assertEqual(len(blocks_found), 1)
        self.assertEqual(blocks_found[0].stat.requisite_arts, ["Corpus"])
        self.assertEqual(blocks_found[0].prose, "A description sentence.")

    def test_inline_requisite_on_the_stat_line_still_parses(self):
        # No revision of the book currently uses this form, but it is the
        # form statline._REQ was originally written for, and the fold must
        # not regress it: a stat line that already carries its own Req:
        # should not look for -- or require -- a continuation line at all.
        lines = [
            "##### Another Made-Up Spell",
            "R: Touch, D: Sun, T: Ind, Req: Corpus",
            "A description sentence.",
            "(Base 5, +1 Touch, +2 Sun)",
        ]
        blocks_found, problems = blocks.parse_de(
            ["### Muto Corpus Spells", "#### LEVEL 10"] + lines
        )
        self.assertEqual(problems, [])
        self.assertEqual(len(blocks_found), 1)
        self.assertEqual(blocks_found[0].stat.requisite_arts, ["Corpus"])
        self.assertEqual(blocks_found[0].prose, "A description sentence.")

    def test_spell_with_no_requisite_line_is_unaffected(self):
        # Regression guard: a spell with no Req: anywhere keeps
        # requisite_arts == [] and its prose starts with its real first
        # sentence, not with anything consumed by the new look-ahead.
        block = next(b for b in self.blocks if b.name == "Soothe Pains of the Beast")
        self.assertEqual(block.stat.requisite_arts, [])
        self.assertFalse(block.prose.startswith("Req:"))
