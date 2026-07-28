import unittest

from scripts.spell_import import ledger


def build(entries: dict) -> ledger.Ledger:
    return ledger.Ledger.from_dict(entries)


class ResolveTest(unittest.TestCase):
    def test_single_candidate_needs_no_entry(self):
        self.assertEqual(build({}).resolve("lib-cran-x", ["cran-5a"]), "cran-5a")

    def test_ledger_entry_answers_an_ambiguous_spell(self):
        book = build({
            "lib-cran-weavers-trap-of-webs": {
                "baseEffectId": "cran-5a",
                "candidates": ["cran-5a", "cran-5b", "cran-5c"],
                "rationale": "Grows spider webs; cran-5a creates an animal product.",
            }
        })
        self.assertEqual(
            book.resolve("lib-cran-weavers-trap-of-webs", ["cran-5a", "cran-5b", "cran-5c"]),
            "cran-5a",
        )

    def test_missing_entry_fails(self):
        with self.assertRaises(ledger.MissingEntry):
            build({}).resolve("lib-cran-x", ["cran-5a", "cran-5b"])

    def test_no_candidates_fails(self):
        # A spell whose Technique/Form/level combination matches zero
        # base-effect guideline entries at all — a real scenario once real
        # spells are imported (Task 10).
        with self.assertRaises(ledger.MissingEntry):
            build({}).resolve("lib-cran-x", [])

    def test_stale_candidate_set_fails(self):
        # Todo item 22 adds guideline rows. A decision made against three
        # candidates deserves re-examination when there are four.
        book = build({
            "lib-cran-x": {
                "baseEffectId": "cran-5a",
                "candidates": ["cran-5a", "cran-5b"],
                "rationale": "chosen when there were two",
            }
        })
        with self.assertRaises(ledger.StaleEntry):
            book.resolve("lib-cran-x", ["cran-5a", "cran-5b", "cran-5c"])

    def test_entry_for_an_unambiguous_spell_fails(self):
        book = build({
            "lib-cran-x": {
                "baseEffectId": "cran-5a",
                "candidates": ["cran-5a"],
                "rationale": "unnecessary",
            }
        })
        with self.assertRaises(ledger.UnnecessaryEntry):
            book.resolve("lib-cran-x", ["cran-5a"])

    def test_stale_multi_candidate_entry_becomes_unnecessary_at_one(self):
        # A ledger entry was written when there were two candidates, and the
        # catalog has since narrowed to one (a guideline row was corrected or
        # removed). This pins the current behavior: no ambiguity now means no
        # entry is needed, regardless of whether the entry's own recorded
        # candidates list has since gone stale — UnnecessaryEntry wins over
        # StaleEntry here, and removing the entry as instructed resolves both.
        book = build({
            "lib-cran-x": {
                "baseEffectId": "cran-5a",
                "candidates": ["cran-5a", "cran-5b"],
                "rationale": "chosen when there were two",
            }
        })
        with self.assertRaises(ledger.UnnecessaryEntry):
            book.resolve("lib-cran-x", ["cran-5a"])

    def test_chosen_id_must_be_among_the_candidates(self):
        book = build({
            "lib-cran-x": {
                "baseEffectId": "cran-99",
                "candidates": ["cran-5a", "cran-5b"],
                "rationale": "typo",
            }
        })
        with self.assertRaises(ledger.StaleEntry):
            book.resolve("lib-cran-x", ["cran-5a", "cran-5b"])

    def test_entry_without_a_rationale_is_rejected(self):
        with self.assertRaises(ValueError):
            build({"lib-cran-x": {"baseEffectId": "cran-5a", "candidates": ["cran-5a", "cran-5b"]}})


class CommittedLedgerTest(unittest.TestCase):
    def test_the_committed_ledger_parses(self):
        self.assertIsInstance(ledger.Ledger.load().entries, dict)
