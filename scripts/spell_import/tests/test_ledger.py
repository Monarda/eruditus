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
        #
        # A pure addition like this one is the *widening* case (below), which
        # `WidenedEntry` subclasses `StaleEntry` for -- so this assertion
        # still holds, and the build still fails until somebody acts.
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

    def test_an_entry_may_not_override_a_sole_candidate(self):
        # Todo item 29, decided 2026-08-17. The import design spec once
        # promised an "explicit override" for exactly this shape -- one
        # candidate, and an entry naming a different id. `resolve` never
        # implemented it, and the promise was dropped rather than built.
        #
        # This reads like `test_chosen_id_must_be_among_the_candidates` with
        # a shorter list, and that is the point: the one-candidate case is
        # the override case, and it is the one somebody would be tempted to
        # special-case. Deleting this as a duplicate would delete the
        # decision.
        #
        # The rule: the ledger records a choice *among* the candidates a
        # spell's design line admits, never one against them. A sole
        # candidate that is the wrong guideline is a `base_effects.json`
        # bug, or an ExceptionSpell.
        book = build({
            "lib-cran-x": {
                "baseEffectId": "cran-5b",
                "candidates": ["cran-5a"],
                "rationale": "an override the ledger does not offer",
            }
        })
        with self.assertRaises(ledger.StaleEntry):
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


class WideningTest(unittest.TestCase):
    """Adding a catalog row must not cost a re-read of unrelated spells.

    Todo item 55: one supplement guideline invalidated three Creo Vim
    entries whose choices it could not possibly have changed. A widening is
    the case where that is mechanically true — rows were added, none
    removed, and the recorded choice is still on offer.
    """

    ENTRY = {
        "lib-cran-x": {
            "baseEffectId": "cran-5a",
            "candidates": ["cran-5a", "cran-5b"],
            "rationale": "chosen when there were two",
        }
    }

    def test_a_pure_addition_is_a_widening(self):
        with self.assertRaises(ledger.WidenedEntry):
            build(self.ENTRY).resolve("lib-cran-x", ["cran-5a", "cran-5b", "cran-5c"])

    def test_a_removal_is_not_a_widening(self):
        # The choice survives, but a candidate the rationale argued against
        # has vanished, so the recorded reasoning no longer describes the
        # catalog. That needs a human, not a rewrite.
        with self.assertRaises(ledger.StaleEntry):
            build(self.ENTRY).resolve("lib-cran-x", ["cran-5a", "cran-5c"])
        self.assertNotIsInstance(
            self._raised(["cran-5a", "cran-5c"]), ledger.WidenedEntry)

    def test_losing_the_chosen_row_is_not_a_widening(self):
        self.assertNotIsInstance(
            self._raised(["cran-5b", "cran-5c", "cran-5d"]), ledger.WidenedEntry)

    def _raised(self, candidates: list[str]) -> Exception:
        try:
            build(self.ENTRY).resolve("lib-cran-x", candidates)
        except ledger.LedgerError as error:
            return error
        raise AssertionError("expected a LedgerError")

    def test_migration_keeps_the_decision_and_names_what_it_skipped(self):
        migrated = ledger.migrate_raw(
            self.ENTRY, {"lib-cran-x": ["cran-5a", "cran-5b", "cran-5c"]})
        entry = migrated["lib-cran-x"]

        self.assertEqual(entry["baseEffectId"], "cran-5a")
        self.assertEqual(entry["rationale"], "chosen when there were two")
        self.assertEqual(entry["candidates"], ["cran-5a", "cran-5b", "cran-5c"])
        # The point of the whole mechanism: the new row is recorded as
        # something nobody weighed, rather than absorbed into a candidate
        # list whose rationale never mentions it.
        self.assertEqual(entry["unreviewedCandidates"], ["cran-5c"])

    def test_migration_leaves_other_entries_untouched(self):
        raw = dict(self.ENTRY)
        raw["lib-cran-y"] = {
            "baseEffectId": "cran-9a",
            "candidates": ["cran-9a", "cran-9b"],
            "rationale": "unrelated",
        }
        migrated = ledger.migrate_raw(raw, {"lib-cran-x": ["cran-5a", "cran-5b", "cran-5c"]})
        self.assertEqual(migrated["lib-cran-y"], raw["lib-cran-y"])

    def test_a_second_widening_accumulates_rather_than_replaces(self):
        once = ledger.migrate_raw(
            self.ENTRY, {"lib-cran-x": ["cran-5a", "cran-5b", "cran-5c"]})
        twice = ledger.migrate_raw(
            once, {"lib-cran-x": ["cran-5a", "cran-5b", "cran-5c", "cran-5d"]})
        self.assertEqual(twice["lib-cran-x"]["unreviewedCandidates"],
                         ["cran-5c", "cran-5d"])

    def test_a_migrated_entry_still_resolves(self):
        migrated = ledger.migrate_raw(
            self.ENTRY, {"lib-cran-x": ["cran-5a", "cran-5b", "cran-5c"]})
        book = build(migrated)
        self.assertEqual(
            book.resolve("lib-cran-x", ["cran-5a", "cran-5b", "cran-5c"]), "cran-5a")
        self.assertEqual(book.unreviewed(), {"lib-cran-x": ("cran-5c",)})

    def test_unreviewed_candidates_must_be_candidates(self):
        with self.assertRaises(ValueError):
            build({
                "lib-cran-x": {
                    "baseEffectId": "cran-5a",
                    "candidates": ["cran-5a", "cran-5b"],
                    "rationale": "x",
                    "unreviewedCandidates": ["cran-5z"],
                }
            })


class CommittedLedgerTest(unittest.TestCase):
    def test_the_committed_ledger_parses(self):
        self.assertIsInstance(ledger.Ledger.load().entries, dict)

    def test_every_committed_key_is_a_real_spell(self):
        # A ledger entry is never consulted unless a spell reaches
        # Ledger.resolve() with a matching id — a spell that is currently
        # blocked (an unrecognised design-line token, no design line, etc.)
        # never looks its id up at all. A typo'd key, or one for a spell
        # that no longer exists under that name, would sit silently unused
        # rather than raising anything. This catches that directly, instead
        # of waiting for the spell's blocker to clear.
        from scripts.spell_import import (
            blocks, catalog as catalog_module, extract_spells, sources,
        )

        # A ledger key can come from any registered book, not just the core
        # rules -- iterate sources.BOOKS with each book's own parser rather
        # than hardcoding the DE parse, or a second book's real ids read as
        # "no matching spell" against this test's own raw parse, exactly the
        # false positive this test exists to avoid.
        real_ids: set[str] = set()
        for registered in sources.BOOKS:
            lines = sources.read_lines(sources.resolve_book(registered.title))
            parsed, _ = blocks.PARSERS[registered.parser](lines)
            # SPELL_NAME_TYPOS corrects a name (and so its derived id) before
            # extract_spells.run ever emits a spell -- mirror that here, or a
            # corrected id reads as "no matching spell" against this test's
            # own raw parse, exactly the false positive this test exists to
            # avoid.
            real_ids.update(
                catalog_module.slug_id(
                    b.technique, b.form,
                    extract_spells.SPELL_NAME_TYPOS.get(b.name, b.name),
                )
                for b in parsed
            )

        book = ledger.Ledger.load()
        unknown = sorted(set(book.entries) - real_ids)
        self.assertEqual(unknown, [], msg=f"ledger keys with no matching spell: {unknown}")
