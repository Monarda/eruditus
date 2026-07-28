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
