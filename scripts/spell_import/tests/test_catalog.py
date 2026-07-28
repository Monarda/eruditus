import unittest

from scripts.spell_import import catalog


class SlugTest(unittest.TestCase):
    def test_matches_the_existing_library_convention(self):
        self.assertEqual(
            catalog.slug_id("Creo", "Imaginem", "Phantasm of the Talking Head"),
            "lib-crim-talking-head",
        )

    def test_strips_apostrophes_and_punctuation(self):
        self.assertEqual(
            catalog.slug_id("Rego", "Terram", "Hermes' Portal"),
            "lib-rete-hermes-portal",
        )


class CandidatesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog.Catalog.load()

    def test_loads_the_committed_catalogs(self):
        self.assertGreater(len(self.catalog.base_effects), 600)
        self.assertEqual(len(self.catalog.parameters), 25)

    def test_creo_animal_level_15_is_ambiguous(self):
        # Soothe Pains of the Beast says "Base level 15" and Creo Animal has
        # four entries at 15. This ambiguity is the reason the ledger exists.
        found = self.catalog.candidates("Creo", "Animal", 15)
        self.assertGreaterEqual(len(found), 2)

    def test_candidates_are_sorted_and_deduplicated(self):
        found = self.catalog.candidates("Creo", "Animal", 15)
        self.assertEqual(found, sorted(set(found)))

    def test_absent_level_yields_no_candidates(self):
        self.assertEqual(self.catalog.candidates("Creo", "Animal", 9999), [])

    def test_parameter_lookup_by_category_and_name(self):
        self.assertEqual(self.catalog.parameter_id("Range", "Touch"), "range-touch")
        self.assertEqual(self.catalog.parameter_id("Target", "Boundary"), "target-boundary")
        with self.assertRaises(KeyError):
            self.catalog.parameter_id("Target", "Flavor")


class ExistingIdsTest(unittest.TestCase):
    def test_slugger_reproduces_every_committed_library_id(self):
        import json

        from scripts.spell_import.sources import REPO_ROOT

        library = json.loads(
            (REPO_ROOT / "assets" / "data" / "spell_library.json").read_text(encoding="utf-8")
        )
        effects = {e["id"]: e for e in catalog.Catalog.load().base_effects}

        mismatches = []
        for spell in library:
            effect = effects[spell["baseEffectId"]]
            generated = catalog.slug_id(effect["technique"], effect["form"], spell["name"])
            if generated != spell["id"]:
                mismatches.append((spell["name"], spell["id"], generated))

        self.assertEqual(mismatches, [], msg="the slugger must reproduce existing ids exactly")
