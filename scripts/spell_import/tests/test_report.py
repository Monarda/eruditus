import unittest

from scripts.spell_import import provenance, report


def spell(spell_id, name="A Spell", base="cran-5a", **extra):
    entry = {"id": spell_id, "name": name, "baseEffectId": base, "summary": "Prose. Level 20."}
    entry.update(extra)
    return entry


LOCK = provenance.SourceIdentity(
    book="Book", path="reviewed/Book.md", sha256="a" * 64,
    rulebook=provenance.RulebookRevision("97cc62d", "2026-07-18", "Review chapter 9"),
    spells_parsed=346, spells_imported=241,
)
CURRENT = provenance.SourceIdentity(
    book="Book", path="reviewed/Book.md", sha256="b" * 64,
    rulebook=provenance.RulebookRevision("f36ac84", "2026-07-29", "Merge pull request #66"),
    spells_parsed=360, spells_imported=250,
)


class DiffAssetsTest(unittest.TestCase):
    def test_identical_lists_produce_an_empty_diff(self):
        old = [spell("lib-a"), spell("lib-b")]
        found = report.diff_assets(old, list(reversed(old)))
        self.assertTrue(found.is_empty)

    def test_detects_added_removed_and_changed(self):
        old = [spell("lib-a"), spell("lib-b", base="cran-5a")]
        new = [spell("lib-b", base="cran-5c"), spell("lib-c")]
        found = report.diff_assets(old, new)
        self.assertEqual([s["id"] for s in found.added], ["lib-c"])
        self.assertEqual([s["id"] for s in found.removed], ["lib-a"])
        self.assertEqual([(o["id"], n["id"]) for o, n in found.changed], [("lib-b", "lib-b")])

    def test_results_are_sorted_by_id(self):
        old = []
        new = [spell("lib-z"), spell("lib-a")]
        self.assertEqual([s["id"] for s in report.diff_assets(old, new).added], ["lib-a", "lib-z"])


class RenderTest(unittest.TestCase):
    def setUp(self):
        self.diff = report.diff_assets(
            [spell("lib-a"), spell("lib-b", base="cran-5a")],
            [spell("lib-b", base="cran-5c"), spell("lib-c", name="New Spell")],
        )

    def test_header_names_both_revisions_and_the_count_transitions(self):
        text = report.render(self.diff, LOCK, CURRENT, imported=250, blocked=110, unresolved=0)
        self.assertIn("97cc62d", text)
        self.assertIn("f36ac84", text)
        self.assertIn("346 → 360", text)
        self.assertIn("241 → 250", text)
        # blocked before is derived: 346 - 241 = 105
        self.assertIn("105 → 110", text)

    def test_lists_each_changed_spell_with_what_changed(self):
        text = report.render(self.diff, LOCK, CURRENT, imported=250, blocked=110, unresolved=0)
        self.assertIn("New Spell", text)
        self.assertIn("baseEffectId", text)
        self.assertIn("cran-5a", text)
        self.assertIn("cran-5c", text)

    def test_quotes_design_lines_when_both_are_supplied(self):
        text = report.render(
            self.diff, LOCK, CURRENT, imported=250, blocked=110, unresolved=0,
            old_design_lines={"lib-b": "(Base 3, +1 Touch)"},
            new_design_lines={"lib-b": "(Base 5, +1 Touch)"},
        )
        self.assertIn("(Base 3, +1 Touch) → (Base 5, +1 Touch)", text)

    def test_omits_design_lines_with_a_note_when_the_old_text_is_unavailable(self):
        text = report.render(
            self.diff, LOCK, CURRENT, imported=250, blocked=110, unresolved=0,
            old_design_lines=None,
            new_design_lines={"lib-b": "(Base 5, +1 Touch)"},
        )
        self.assertNotIn("→ (Base 5, +1 Touch)", text)
        self.assertIn("design lines unavailable", text)

    def test_no_lock_renders_as_an_initial_import(self):
        text = report.render(self.diff, None, CURRENT, imported=250, blocked=110, unresolved=0)
        self.assertIn("initial import", text.lower())
