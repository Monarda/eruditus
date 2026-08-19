import re
import unittest

from scripts.spell_import import catalog


class SlugTest(unittest.TestCase):
    def test_matches_the_existing_library_convention(self):
        self.assertEqual(
            catalog.slug_id("Creo", "Imaginem", "Phantasm of the Talking Head"),
            "lib-crim-phantasm-talking-head",
        )

    def test_keeps_content_words_that_look_like_stock_phrases(self):
        # "Phantasm" was a stopword until todo item 29: it is a content word
        # naming what the spell creates, and stripping it silently merged the
        # distinguishing half of two ids away. Only articles and prepositions
        # are dropped.
        self.assertEqual(
            catalog.slug_id("Creo", "Imaginem", "Phantasm of the Human Form"),
            "lib-crim-phantasm-human-form",
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
        # A floor, not an equality. This was `== 25`, the core rulebook's own
        # Range/Duration/Target count (todo item 15), until item 17 added
        # nine virtue-gated parameters and made a hand-maintained total
        # something every future supplement has to bump -- exactly the drift
        # item 5 fixed by deriving counts instead of writing them down. What
        # actually needs guarding is that every parameter a spell references
        # resolves, and assertion 4 does that against the real corpus.
        self.assertGreaterEqual(len(self.catalog.parameters), 25)

    def test_creo_animal_level_15_is_ambiguous(self):
        # Soothe Pains of the Beast says "Base level 15" and Creo Animal has
        # four entries at 15. This ambiguity is the reason the ledger exists.
        found = self.catalog.candidates("Creo", "Animal", 15, catalog.CORE_BOOK_ID)
        self.assertGreaterEqual(len(found), 2)

    def test_candidates_are_sorted_and_deduplicated(self):
        found = self.catalog.candidates("Creo", "Animal", 15, catalog.CORE_BOOK_ID)
        self.assertEqual(found, sorted(set(found)))

    def test_absent_level_yields_no_candidates(self):
        self.assertEqual(
            self.catalog.candidates("Creo", "Animal", 9999, catalog.CORE_BOOK_ID), []
        )

    def test_parameter_lookup_by_category_and_name(self):
        self.assertEqual(self.catalog.parameter_id("Range", "Touch"), "range-touch")
        self.assertEqual(self.catalog.parameter_id("Target", "Boundary"), "target-boundary")
        with self.assertRaises(KeyError):
            self.catalog.parameter_id("Target", "Nowhere")

    def test_general_candidates_are_the_levelless_rows(self):
        candidates = self.catalog.general_candidates("Perdo", "Vim", catalog.CORE_BOOK_ID)

        self.assertEqual(len(candidates), 13)
        self.assertIn("pevi-G3", candidates)

    def test_a_core_spell_is_never_offered_a_supplement_row(self):
        # The scoping rule (catalog.visible_books): a core spell may only use
        # core rows. Book-blind resolution offered HoH:MC's crvi-hohmc-G1 to
        # three core Creo Vim spells and revi-hohmc-G1 to four core Rego Vim
        # ones, and every one became a `unreviewedCandidates` backlog entry a
        # human had to clear by hand -- for a row those spells could never
        # legally use. Without this test, the next supplement does it again.
        for technique, form, supplement_row in (
            ("Creo", "Vim", "crvi-hohmc-G1"),
            ("Rego", "Vim", "revi-hohmc-G1"),
        ):
            core = self.catalog.general_candidates(
                technique, form, catalog.CORE_BOOK_ID
            )
            self.assertNotIn(supplement_row, core)
            # ...and the supplement's own spells still see it.
            own = self.catalog.general_candidates(technique, form, "arm5-hohmc")
            self.assertIn(supplement_row, own)
            self.assertEqual(set(core) - set(own), set())

    def test_every_base_effect_is_visible_to_its_own_book(self):
        # The filter narrows by *provenance*, so a row must never be filtered
        # out of the candidate set for a spell from the very book that printed
        # it -- that would be a row no spell could ever resolve to.
        for effect in self.catalog.base_effects:
            book = (effect.get("citations") or [{}])[0].get("bookId")
            self.assertIn(book, catalog.visible_books(book), msg=effect["id"])

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

    def test_open_slots_returns_the_annotated_list(self):
        catalog_inst = catalog.Catalog(
            base_effects=[
                {"id": "revi-G1", "technique": "Rego", "form": "Vim",
                 "baseLevel": None, "openSlots": ["realm"]},
            ],
            parameters=[], modifiers=[],
        )
        self.assertEqual(catalog_inst.open_slots("revi-G1"), ["realm"])

    def test_open_slots_defaults_to_empty_when_the_key_is_absent(self):
        catalog_inst = catalog.Catalog(
            base_effects=[
                {"id": "crig-10a", "technique": "Creo", "form": "Ignem",
                 "baseLevel": 10},
            ],
            parameters=[], modifiers=[],
        )
        self.assertEqual(catalog_inst.open_slots("crig-10a"), [])

    def test_open_slots_raises_on_an_unknown_id(self):
        catalog_inst = catalog.Catalog(base_effects=[], parameters=[], modifiers=[])
        with self.assertRaises(KeyError):
            catalog_inst.open_slots("does-not-exist")

    def test_pevi_g2_declares_specificType_open(self):
        catalog_inst = catalog.Catalog.load()
        self.assertEqual(catalog_inst.open_slots("pevi-G2"), ["specificType"])

    def test_pevi_g7_declares_specificType_open(self):
        catalog_inst = catalog.Catalog.load()
        self.assertEqual(catalog_inst.open_slots("pevi-G7"), ["specificType"])

    def test_pevi_g10_declares_form_and_specificType_open(self):
        catalog_inst = catalog.Catalog.load()
        self.assertEqual(catalog_inst.open_slots("pevi-G10"), ["form", "specificType"])

    def test_pevi_g11_declares_form_open(self):
        catalog_inst = catalog.Catalog.load()
        self.assertEqual(catalog_inst.open_slots("pevi-G11"), ["form"])

    def test_revi_g5_declares_specificType_open(self):
        catalog_inst = catalog.Catalog.load()
        self.assertEqual(catalog_inst.open_slots("revi-G5"), ["specificType"])

    def test_muvi_g2_declares_form_open(self):
        catalog_inst = catalog.Catalog.load()
        self.assertEqual(catalog_inst.open_slots("muvi-G2"), ["form"])

    def test_muvi_g3_declares_form_open(self):
        catalog_inst = catalog.Catalog.load()
        self.assertEqual(catalog_inst.open_slots("muvi-G3"), ["form"])

    def test_muvi_g1_declares_nothing_open(self):
        # Deliberately not annotated -- its only corpus user (Shroud Magic)
        # never mentions Form in its own prose (design spec Decision 12's
        # context; muvi-G1 itself carries no rough edge, muvi-G2 does).
        catalog_inst = catalog.Catalog.load()
        self.assertEqual(catalog_inst.open_slots("muvi-G1"), [])

    def test_crvi_ladder_is_collapsed_to_one_row(self):
        catalog_inst = catalog.Catalog.load()
        ids = {e["id"] for e in catalog_inst.base_effects}
        self.assertIn("crvi-5a", ids)
        self.assertNotIn("crvi-10a", ids)
        self.assertNotIn("crvi-15a", ids)

    def test_peig_ladder_is_collapsed_to_one_row(self):
        catalog_inst = catalog.Catalog.load()
        ids = {e["id"] for e in catalog_inst.base_effects}
        self.assertIn("peig-5b", ids)
        self.assertNotIn("peig-10b", ids)

    def test_rego_transport_distance_scope_covers_all_five_forms(self):
        catalog_inst = catalog.Catalog.load()
        modifier = next(
            m for m in catalog_inst.modifiers if m["id"] == "rego-transport-distance"
        )
        self.assertEqual(
            set(modifier["scope"]["effectIds"]),
            {"rehe-10b", "reig-3c", "rete-4", "rean-10b", "reaq-4b"},
        )


class TargetTypeTest(unittest.TestCase):
    def setUp(self):
        self.catalog = catalog.Catalog.load()

    def test_returns_the_kind_for_a_target(self):
        self.assertEqual(self.catalog.target_type("target-room"), "container")
        self.assertEqual(self.catalog.target_type("target-group"), "object")
        self.assertEqual(self.catalog.target_type("target-vision"), "sense")

    def test_returns_none_for_a_non_target_parameter(self):
        self.assertIsNone(self.catalog.target_type("duration-sun"))

    def test_returns_none_for_an_unknown_id(self):
        self.assertIsNone(self.catalog.target_type("target-nowhere"))


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

    @staticmethod
    def _suffix(effect: dict) -> str:
        """The id's level part, with any book segment stripped.

        A core row is `<technique><form>-<level>`. A row from a supplement
        carries its book between the two -- `crvi-hohmc-G1` cites
        `arm5-hohmc` -- so a reader can tell at a glance that the guideline
        is not in the core rulebook's own tables. Deriving that segment from
        the row's own citation rather than a hardcoded list makes this
        enforce the convention instead of tolerating one exception to it: a
        supplement row that omits its segment, or names the wrong book, still
        lands in `unparsed` below.
        """
        suffix = effect["id"].split("-", 1)[1]
        for citation in effect.get("citations") or []:
            book = citation.get("bookId", "")
            segment = book.split("-", 1)[-1]
            if book != catalog.CORE_BOOK_ID and suffix.startswith(f"{segment}-"):
                return suffix[len(segment) + 1:]
        return suffix

    def test_every_id_suffix_matches_its_own_base_level(self):
        mismatches = []
        unparsed = []
        for effect in self.effects:
            suffix = self._suffix(effect)
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
