import json
import unittest

from scripts.spell_import import extract_spells
from scripts.spell_import.sources import REPO_ROOT

LIBRARY = REPO_ROOT / "assets" / "data" / "spell_library.json"


class RunTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def test_reports_no_parse_problems(self):
        self.assertEqual(self.report.problems, [])

    def test_every_emitted_spell_has_the_required_fields(self):
        for spell in self.report.spells:
            for field in ("id", "name", "baseEffectId", "rangeId", "durationId",
                          "targetId", "source", "createdAt", "updatedAt",
                          "summary", "citations"):
                self.assertIn(field, spell, msg=spell.get("id"))
            self.assertEqual(spell["source"], "published")
            self.assertEqual(spell["citations"], [{"bookId": "arm5-core"}])

    def test_ids_are_unique(self):
        ids = [s["id"] for s in self.report.spells]
        self.assertEqual(len(ids), len(set(ids)))

    def test_no_page_numbers_are_invented(self):
        for spell in self.report.spells:
            for citation in spell["citations"]:
                self.assertNotIn("page", citation)

    def test_blocked_spells_are_reported_not_dropped_silently(self):
        # The audit found 74 blocked. Assert a range, not a number: each
        # blocker item that clears moves spells from blocked to imported, and
        # this test should not need editing when that happens.
        self.assertGreater(len(self.report.blocked), 0)
        self.assertLess(len(self.report.blocked), 120)


class RegenerationTest(unittest.TestCase):
    """Assertion 5: running the extractor produces no diff.

    This lives in Python rather than `flutter test` because it has to run the
    extractor. CI must run both suites; neither alone covers all five
    assertions.
    """

    def test_committed_library_matches_a_fresh_run(self):
        report = extract_spells.run(write=False)
        committed = json.loads(LIBRARY.read_text(encoding="utf-8"))
        self.assertEqual(
            extract_spells.serialize(report.spells),
            extract_spells.serialize(committed),
            msg="assets/data/spell_library.json is stale or was hand-edited — "
                "re-run `python -m scripts.spell_import.extract_spells --write`",
        )

    def test_two_runs_are_byte_identical(self):
        first = extract_spells.serialize(extract_spells.run(write=False).spells)
        second = extract_spells.serialize(extract_spells.run(write=False).spells)
        self.assertEqual(first, second)
