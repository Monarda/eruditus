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


HOHMC_TITLE = "Ars Magica 5e - Houses of Hermes - Mystery Cults"


class ParseInlineAgainstMysteryCultsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lines = sources.read_lines(sources.resolve_book(HOHMC_TITLE))
        cls.blocks, cls.problems = blocks.parse_inline(lines)

    def test_finds_all_sixteen_blocks(self):
        # 16 stat lines in the book, all 16 anchored. Two of these are not
        # importable spells and are excluded later, in run()'s skip list --
        # the parser's job is to find blocks, not to judge them.
        self.assertEqual(len(self.blocks), 16)

    def test_reports_no_parse_problems(self):
        self.assertEqual(self.problems, [])

    def test_a_blockquoted_block_parses_completely(self):
        block = next(b for b in self.blocks if b.name == "Revenge of the Bitten Toad")
        self.assertEqual((block.technique, block.form), ("Perdo", "Animal"))
        self.assertEqual(block.printed_level, 20)
        self.assertEqual(block.stat.target_name, "Flavor")
        self.assertEqual(block.design_line, "(Base 15, +1 Diam)")

    def test_a_plain_unquoted_block_parses_completely(self):
        block = next(b for b in self.blocks if b.name == "The Voice of the Bjornaer Magus")
        self.assertEqual((block.technique, block.form), ("Muto", "Animal"))
        self.assertEqual(block.printed_level, 15)
        self.assertEqual(block.design_line, "(Base 5, +2 Sun)")

    def test_a_bold_named_block_is_found(self):
        # Ball of Abysmal Music is the one spell headed **Name** rather than
        # ##### Name. Rejecting it would lose a real spell to typesetting.
        block = next(b for b in self.blocks if b.name == "Ball of Abysmal Music")
        self.assertEqual((block.technique, block.form), ("Muto", "Imaginem"))
        self.assertEqual(block.printed_level, 20)

    def test_a_blank_line_between_name_and_anchor_is_tolerated(self):
        # Perceive the Change has a blank blockquote line between its heading
        # and its InAn 14 line; Revenge of the Bitten Toad has none.
        block = next(b for b in self.blocks if b.name == "Perceive the Change")
        self.assertEqual((block.technique, block.form), ("Intellego", "Animal"))

    def test_general_level_blocks_have_no_printed_level(self):
        general = sorted(b.name for b in self.blocks if b.printed_level is None)
        self.assertEqual(general, [
            "Facilitate the Stifled (Form) Spell",
            "Faerie Chains of the Familiar Slave",
            "The Rooster's Crow",
            "Tie the Threads That Bind",
        ])

    def test_a_design_line_separated_by_paragraphs_is_still_found(self):
        # Form of the (Temperament) Heartbeast prints four variant paragraphs
        # between its stat line and its design line. A fixed-size lookahead
        # window would miss it.
        block = next(b for b in self.blocks
                     if b.name == "Form of the (Temperament) Heartbeast")
        self.assertEqual(block.design_line, "(Base 5, +2 Sun; +1 complexity)")

    def test_a_requisite_continuation_line_is_folded_in(self):
        # Embrace of Boethius prints "Req: Vim, Corpus" on its own line below
        # the stat line, the same shape parse_de already folds.
        block = next(b for b in self.blocks if b.name == "Embrace of Boethius")
        self.assertEqual(block.stat.requisite_arts, ["Vim", "Corpus"])
        self.assertTrue(block.stat.is_ritual)

    def test_the_remaining_blocks_prose_and_design_line_match_the_book(self):
        # test_finds_all_sixteen_blocks and test_reports_no_parse_problems
        # only pin an aggregate count and an empty problem list; that would
        # not catch a subtly wrong prose or design line on any one block.
        # Three blocks have their design_line checked individually above
        # (Revenge of the Bitten Toad, Form of the (Temperament) Heartbeast)
        # or their stat checked (Embrace of Boethius) -- these are the other
        # 13, each transcribed here from the book's own printed text
        # (reviewed/Ars Magica 5e - Houses of Hermes - Mystery Cults.md),
        # not from what the parser currently emits.
        expectations = {
            "Perceive the Change": (
                "This effect detects whether the enchanted item is touching "
                "an animal; if so, it triggers any effects tied to it with "
                "a Linked Trigger.",
                "(Base 3, +1 Touch, +2 Sun; +1 two uses/day, "
                "+3 environmental trigger \\[sunrise/sunset\\])",
            ),
            "Hibernation of the Slumbering Turb": (
                "Anyone touching the caster falls asleep and does not "
                "awaken until the spell expires.",
                "(Base 4, +4 Year, +1 Texture, +1 Creo requisite, +1 complexity)",
            ),
            "Scent of the Predator": (
                "Anyone smelling the caster is struck by an overwhelming "
                "sensation of menace and hostility.",
                "(Base 4, +2 Sun, +2 Scent)",
            ),
            "Marking the Territory": (
                "Anyone smelling the territory marked out by the caster's "
                "scent (usually his urine) cannot enter the warded area",
                '(Base 3 \\[move in direction "away"\\], +2 Ring, +2 Scent)',
            ),
            "Clarion Call of the War Horse": (
                "Anyone hearing the caster's battle cry is heartened by its "
                "tone, and receives a +3 bonus to his Brave Personality Trait.",
                "(Base 3, +1 Diam, +3 Sound)",
            ),
            "The Rooster's Crow": (
                "Any demons who hear the caster's shout lose Might equal to "
                "the spell's (level \u2013 5) if the spell penetrates their "
                "Magic Resistance.",
                "(Base effect, +3 Sound)",
            ),
            "Brilliance of the Eagle's Plumage": (
                "Anyone looking directly at the caster is blinded by the "
                "brilliant light shining from his body.",
                "(Base 5, +1 Conc, +4 Spectacle)",
            ),
            "Closed Mouth of the Nightwalker": (
                "Anyone seeing the caster instantly forgets that he did so, "
                "assuming that the spell's Penetration breaches the "
                "target's Magic Resistance.",
                "(Base 10, +2 Sun, +4 Spectacle)",
            ),
            "Facilitate the Stifled (Form) Spell": (
                "This spell is cast at the same time as another formulaic "
                "spell (see ArM5, page 159) whose level must be less than "
                "twice the level of this spell.",
                "(Base effect, +1 Touch)",
            ),
            "Faerie Chains of the Familiar Slave": (
                "This ritual binds a supernatural creature to the caster "
                "as her familiar, until a condition incorporated into the "
                "spell comes to pass.",
                "(Base effect, +1 Touch, +4 Until)",
            ),
            "Ball of Abysmal Music": (
                "This spell targets a formulaic Ignem spell while it is "
                "being cast, changing it so that instead of creating fire, "
                "heat, or light, it produces a harmless burst of color and "
                "sound.",
                "(Base 10, +2 Voice)",
            ),
            "Embrace of Boethius": (
                "This spell damages the target's mind, heart, and Gift, "
                "destroying a part of his understanding of formulaic spell "
                "casting and forcing him to rely on casting tools.",
                "(Base 15, + 1 Touch, +1 Part, +2 necessary requisites)",
            ),
            "Tie the Threads That Bind": (
                "This spell is uniquely used for the construction of automata.",
                "(Base Effect, +1 Touch, +2 Group)",
            ),
        }
        self.assertEqual(len(expectations), 13)
        by_name = {b.name: b for b in self.blocks}
        for name, (prose_prefix, design_line) in expectations.items():
            with self.subTest(name=name):
                block = by_name[name]
                self.assertTrue(block.prose.startswith(prose_prefix), block.prose[:120])
                self.assertEqual(block.design_line, design_line)


class ParseInlineFixtureTest(unittest.TestCase):
    def test_a_stat_line_with_no_anchor_above_it_is_skipped(self):
        lines = [
            "Some prose about a creature.",
            "",
            "R: Touch, D: Sun, T: Ind",
            "",
            "(Base 5, +2 Sun)",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(found, [])
        self.assertEqual(problems, [])

    def test_an_anchor_with_no_name_above_it_is_skipped(self):
        lines = [
            "Just prose, not a name.",
            "MuAn 15",
            "R: Per, D: Sun, T: Ind",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(found, [])
        self.assertEqual(problems, [])

    def test_two_adjacent_blocks_do_not_bleed_into_each_other(self):
        lines = [
            "##### First Spell",
            "MuAn 15",
            "R: Per, D: Sun, T: Ind",
            "",
            "Prose for the first.",
            "",
            "(Base 5, +2 Sun)",
            "",
            "##### Second Spell",
            "PeAn 20",
            "R: Per, D: Diam, T: Ind",
            "",
            "Prose for the second.",
            "",
            "(Base 15, +1 Diam)",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(problems, [])
        self.assertEqual([b.name for b in found], ["First Spell", "Second Spell"])
        self.assertEqual(found[0].design_line, "(Base 5, +2 Sun)")
        self.assertEqual(found[0].prose, "Prose for the first.")
        self.assertEqual(found[1].design_line, "(Base 15, +1 Diam)")
        self.assertEqual(found[1].prose, "Prose for the second.")

    def test_a_block_with_no_design_line_still_parses(self):
        lines = [
            "##### Lonely Spell",
            "MuAn 15",
            "R: Per, D: Sun, T: Ind",
            "",
            "Prose with no design line.",
            "",
            "#### Some Other Section",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(problems, [])
        self.assertEqual(len(found), 1)
        self.assertIsNone(found[0].design_line)

    def test_a_damaged_stat_line_with_an_anchor_above_it_is_reported(self):
        # HoH:MC has zero damaged stat lines, so nothing in the corpus test
        # covers this branch. R and T are transposed below, same shape as
        # statline.DetectTest.test_damaged_lines_are_detected_not_parsed.
        lines = [
            "##### A Made-Up Spell",
            "MuAn 15",
            "R: Per, T: Ring, D: Circle",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(found, [])
        self.assertEqual(len(problems), 1)
        self.assertIn("damaged stat line", problems[0])

    def test_a_damaged_stat_line_with_no_anchor_above_it_is_skipped(self):
        # The same damaged line, but with no `TeFo Level` anchor above it --
        # an enchanted-device effect or NPC power, not a spell. Silence here
        # matches the silent skip an ordinary unanchored stat line gets.
        lines = [
            "Some prose about a creature.",
            "R: Per, T: Ring, D: Circle",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(found, [])
        self.assertEqual(problems, [])

    def test_parsers_registry_exposes_both_styles(self):
        self.assertEqual(sorted(blocks.PARSERS), ["de", "inline"])
        self.assertIs(blocks.PARSERS["de"], blocks.parse_de)
        self.assertIs(blocks.PARSERS["inline"], blocks.parse_inline)
