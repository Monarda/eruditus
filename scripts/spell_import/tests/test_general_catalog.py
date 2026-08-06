import unittest

from .. import catalog as catalog_module

VALID_KINDS = {
    "mightThreshold", "mightReduction", "damage",
    "targetSpellLevel", "visDestroyed", "spellTraceMagnitude",
    "castingTotalReduction",
}
VALID_MULTIPLIERS = {"half", "one", "two"}
VALID_UNITS = {"levels", "magnitudes"}

STANDARD_REFERENCE = {
    "rangeId": "range-personal",
    "durationId": "duration-momentary",
    "targetId": "target-individual",
}


class GeneralCatalogTest(unittest.TestCase):
    def setUp(self):
        self.catalog = catalog_module.Catalog.load()
        self.general = [e for e in self.catalog.base_effects
                        if e["baseLevel"] is None]
        self.parameter_ids = {p["id"] for p in self.catalog.parameters}

    def test_there_are_51_general_entries(self):
        # 47 when this test was written, plus the four the extractor had
        # silently dropped (todo item 34): rean-gen-2, muaq-gen-2, reme-G2
        # and mute-gen. Muto Terram had no General entry at all.
        self.assertEqual(len(self.general), 51)

    def test_every_general_entry_has_a_formula(self):
        missing = [e["id"] for e in self.general if not e.get("effectFormula")]
        self.assertEqual(missing, [])

    def test_no_ordinary_entry_has_a_formula(self):
        stray = [e["id"] for e in self.catalog.base_effects
                 if e["baseLevel"] is not None and e.get("effectFormula")]
        self.assertEqual(stray, [])

    def test_every_formula_field_is_in_range(self):
        for effect in self.general:
            formula = effect["effectFormula"]
            with self.subTest(effect["id"]):
                self.assertIn(formula["kind"], VALID_KINDS)
                self.assertIn(formula.get("multiplier", "one"), VALID_MULTIPLIERS)
                self.assertIn(formula.get("unit", "levels"), VALID_UNITS)
                self.assertIsInstance(formula.get("offsetMagnitudes", 0), int)

    def test_every_reference_names_real_parameters(self):
        for effect in self.catalog.base_effects:
            reference = effect.get("reference", STANDARD_REFERENCE)
            with self.subTest(effect["id"]):
                for key in ("rangeId", "durationId", "targetId"):
                    self.assertIn(reference[key], self.parameter_ids)

    def test_every_ward_is_priced_against_touch_ring_circle(self):
        # Every ward bullet in the rulebook ends "(Touch, Ring, Circle)", and
        # there are exactly 12 of them. The catalog held 10 until todo item 34
        # restored the two the extractor had dropped: rean-gen-2 (the circle
        # warding against animals, which the rulebook distinguishes from
        # beings associated with Animal) and reme-G2 (spirits of one realm,
        # which had been merged into reme-G's description).
        # Assert equality, not a lower bound — a bound would not notice a ward
        # losing its formula.
        wards = [e for e in self.general
                 if e["effectFormula"]["kind"] == "mightThreshold"]
        self.assertEqual(len(wards), 12)
        for effect in wards:
            with self.subTest(effect["id"]):
                self.assertEqual(effect["reference"], {
                    "rangeId": "range-touch",
                    "durationId": "duration-ring",
                    "targetId": "target-circle",
                })
