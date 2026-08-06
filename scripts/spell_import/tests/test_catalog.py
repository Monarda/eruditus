import re
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

    def test_general_candidates_are_the_levelless_rows(self):
        candidates = self.catalog.general_candidates("Perdo", "Vim")

        self.assertEqual(len(candidates), 13)
        self.assertIn("pevi-G3", candidates)

    def test_reference_cost_sums_the_triple(self):
        # Touch(1) + Ring(2) + Circle(0)
        self.assertEqual(self.catalog.reference_cost("rean-gen"), 3)
        # No reference key: Personal(0) + Momentary(0) + Individual(0). Weak
        # on its own -- all three defaults are magnitude 0 by definition, so
        # this pins the value without proving the lookup actually built the
        # default triple and summed it via `by_id`; a shortcut that special-
        # cased "no reference -> 0" would pass this line identically. The
        # mixed case below is what actually discriminates.
        self.assertEqual(self.catalog.reference_cost("pevi-G3"), 0)
        # A mixed triple: two defaults and one that costs. This is the case
        # that discriminates -- a lookup that summed only the non-default key,
        # or one that bailed out to 0 whenever it saw a default, gets this
        # wrong. rean-gen (3) and pevi-G3 (0) do not distinguish those bugs.
        # inim-G's reference is Personal/Momentary/Vision, and Vision is
        # magnitude 4.
        self.assertEqual(self.catalog.reference_cost("inim-G"), 4)

    def test_reference_cost_message_names_the_unknown_effect_id(self):
        with self.assertRaisesRegex(KeyError, "not-a-real-effect-id"):
            self.catalog.reference_cost("not-a-real-effect-id")


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


class BaseEffectIdSchemeTest(unittest.TestCase):
    """Every base-effect id must encode its own technique/form/level.

    259 of 604 ids failed this once (e.g. `reem-15b` for Rego Mentem, which
    should be `reme-15b`) because they predated `TECHNIQUE_ABBREVIATION`/
    `FORM_ABBREVIATION` and were never reconciled against them. This is the
    regression guard: it holds `base_effects.json` to the same scheme
    `slug_id` uses, so a future hand-edit can't silently drift again.
    """

    _GENERAL_SUFFIX = re.compile(r"^(gen(-\d+)?|G\d*)$", re.IGNORECASE)
    _LEVEL_SUFFIX = re.compile(r"^(\d+)[a-z]?$")

    @classmethod
    def setUpClass(cls):
        cls.effects = catalog.Catalog.load().base_effects

    def test_every_id_prefix_matches_its_own_technique_and_form(self):
        mismatches = []
        for effect in self.effects:
            prefix = effect["id"].split("-", 1)[0]
            expected = (
                catalog.TECHNIQUE_ABBREVIATION[effect["technique"]]
                + catalog.FORM_ABBREVIATION[effect["form"]]
            )
            if prefix != expected:
                mismatches.append((effect["id"], effect["technique"], effect["form"], expected))
        self.assertEqual(mismatches, [], msg="id prefix must be technique+form abbreviation")

    def test_every_id_suffix_matches_its_own_base_level(self):
        mismatches = []
        unparsed = []
        for effect in self.effects:
            suffix = effect["id"].split("-", 1)[1]
            if self._GENERAL_SUFFIX.match(suffix):
                if effect["baseLevel"] is not None:
                    mismatches.append((effect["id"], "General", effect["baseLevel"]))
                continue
            level_match = self._LEVEL_SUFFIX.match(suffix)
            if not level_match:
                unparsed.append((effect["id"], suffix))
                continue
            if effect["baseLevel"] != int(level_match.group(1)):
                mismatches.append((effect["id"], level_match.group(1), effect["baseLevel"]))
        self.assertEqual(unparsed, [], msg="id suffix shape not recognised")
        self.assertEqual(mismatches, [], msg="id suffix level must match baseLevel")
