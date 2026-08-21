import unittest

from scripts.spell_import import pages


class SlugifyTest(unittest.TestCase):
    def test_lowercases_and_hyphenates(self):
        self.assertEqual(pages.slugify("## Spell Guidelines"), "spell-guidelines")

    def test_strips_punctuation_but_keeps_hyphens(self):
        self.assertEqual(pages.slugify("### Bjornaer -- The Heartbeast"),
                         "bjornaer----the-heartbeast")

    def test_ignores_leading_hashes_and_whitespace(self):
        self.assertEqual(pages.slugify("   #   Creo Animal  "), "creo-animal")


class RealRulebookTest(unittest.TestCase):
    """Measured facts about the pinned rulebook. If one of these changes, the
    source moved -- check `source.lock` before changing the number."""

    @classmethod
    def setUpClass(cls):
        cls.index = pages.load_index()

    def test_the_spells_index_covers_every_published_spell(self):
        self.assertEqual(len(self.index.spell_index_pages), 360)


class GuidelineIndexTest(unittest.TestCase):
    """The Spell Guidelines Index is `| Form | Technique | [page](#anchor) |`,
    50 rows -- one per Technique/Form pair. Note the column order: Form first."""

    @classmethod
    def setUpClass(cls):
        cls.index = pages.load_index()

    def test_it_has_one_row_per_technique_form_pair(self):
        self.assertEqual(len(self.index.guideline_index_pages), 50)

    def test_creo_animal_resolves_to_its_printed_page(self):
        self.assertEqual(self.index.guideline_index_pages[("Creo", "Animal")], 315)

    def test_every_core_base_effect_resolves(self):
        """Measured 2026-08-21: 608 of 608. If this drops, either the catalog
        gained an art pair the book does not print, or the parser broke."""
        import json
        import pathlib
        root = pathlib.Path(__file__).resolve().parents[3]
        effects = json.loads(
            (root / "assets/data/base_effects.json").read_text(encoding="utf-8"))
        unresolved = [
            e["id"] for e in effects
            if any(c["bookId"] == "arm5-core" for c in e.get("citations", []))
            and (e["technique"], e["form"]) not in self.index.guideline_index_pages
        ]
        self.assertEqual(unresolved, [])


class TopicIndexTest(unittest.TestCase):
    """The Traditional Index indexes a parameter by name AND category --
    `Voice (Range)`, not `Voice`."""

    @classmethod
    def setUpClass(cls):
        cls.index = pages.load_index()

    def test_a_range_resolves_under_its_qualified_name(self):
        self.assertEqual(self.index.topic_index_pages["voice (range)"], 303)

    def test_a_duration_and_a_target_resolve_too(self):
        self.assertEqual(self.index.topic_index_pages["momentary (duration)"], 304)
        self.assertEqual(self.index.topic_index_pages["individual (target)"], 305)

    def test_a_bare_name_does_not_resolve(self):
        """Widening the key to bare `Voice` would reintroduce guessing: the
        index has other entries a bare name could collide with."""
        self.assertNotIn("voice", self.index.topic_index_pages)


class HohmcLedgerTest(unittest.TestCase):
    """The ledger is hand-checked data, so the test guards its shape and its
    coverage -- not the page numbers themselves, which only the PDF can
    confirm."""

    @classmethod
    def setUpClass(cls):
        import json
        import pathlib
        root = pathlib.Path(__file__).resolve().parents[3]
        cls.ledger = json.loads(
            (root / "scripts/spell_import/hohmc_pages.json").read_text(encoding="utf-8"))
        cls.records = []
        for name in ("spell_library", "spell_templates", "spell_exceptions",
                     "base_effects", "parameters", "modifiers"):
            data = json.loads(
                (root / f"assets/data/{name}.json").read_text(encoding="utf-8"))
            for record in data:
                if any(c["bookId"] == "arm5-hohmc"
                       for c in record.get("citations", [])):
                    cls.records.append(record["id"])

    def test_every_hohmc_record_has_a_ledger_entry(self):
        missing = sorted(set(self.records) - set(self.ledger))
        self.assertEqual(missing, [],
                         "a HoH:MC record shipping page-less while its "
                         "siblings carry pages is an authoring gap, not a "
                         "valid null")

    def test_the_ledger_has_no_entries_for_records_that_do_not_exist(self):
        extra = sorted(set(self.ledger) - set(self.records))
        self.assertEqual(extra, [])

    def test_every_page_is_inside_the_book(self):
        for record_id, entry in self.ledger.items():
            page = entry["page"]
            if page is None:
                continue
            self.assertTrue(1 <= page <= 138, f"{record_id}: page {page}")

    def test_every_entry_records_the_evidence_for_its_page(self):
        for record_id, entry in self.ledger.items():
            self.assertTrue(entry.get("matched"), record_id)


class CatalogPageCoverageTest(unittest.TestCase):
    """A floor, not a ceiling: 35 modifiers and 11 parameters carry no page by
    design, so this catches a regression without demanding 100%."""

    def test_core_catalog_pages_do_not_regress(self):
        import json
        import pathlib
        root = pathlib.Path(__file__).resolve().parents[3]
        count = 0
        for name in ("base_effects", "parameters", "modifiers"):
            data = json.loads(
                (root / f"assets/data/{name}.json").read_text(encoding="utf-8"))
            for record in data:
                for citation in record.get("citations", []):
                    if citation["bookId"] == "arm5-core" and "page" in citation:
                        count += 1
        self.assertGreaterEqual(count, 628)


if __name__ == "__main__":
    unittest.main()
