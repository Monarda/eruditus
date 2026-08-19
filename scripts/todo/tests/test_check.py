# scripts/todo/tests/test_check.py
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.todo.check import check

INDEX = """# Eruditus — Item Index

**Now:** 32

| #  | Kind | Status       | Home        | Title           |
|----|------|--------------|-------------|-----------------|
| 7  | do   | open 2/3     | app.md      | Backup checks   |
| 65 | —    | closed 08-18 | ARCHIVE.md  | Inline parser   |
"""

THEME = """# App

### 7. Backup checks
See item 65 for why.
- [ ] **7.1** first
- [x] **7.2** second
- [ ] **7.3** third
"""

ARCHIVE = """# Archive

### 65. Inline parser
Closed.
"""


def build(tmp: Path, index=INDEX, theme=THEME, archive=ARCHIVE):
    (tmp / "themes").mkdir()
    (tmp / "todo.md").write_text(index, encoding="utf-8")
    (tmp / "themes" / "app.md").write_text(theme, encoding="utf-8")
    (tmp / "ARCHIVE.md").write_text(archive, encoding="utf-8")
    return tmp


class CheckTest(unittest.TestCase):
    def run_on(self, **kw):
        with TemporaryDirectory() as d:
            return check(build(Path(d), **kw))

    def test_a_consistent_tree_reports_nothing(self):
        self.assertEqual(self.run_on(), [])

    def test_an_index_row_whose_home_lacks_the_heading_is_reported(self):
        problems = self.run_on(theme="# App\n\n### 9. Something else\n")
        self.assertTrue(any("7" in p and "app.md" in p for p in problems))

    def test_a_heading_with_no_index_row_is_reported_as_an_orphan(self):
        problems = self.run_on(theme=THEME + "\n### 41. Orphaned\nBody.\n")
        self.assertTrue(any("41" in p and "orphan" in p.lower() for p in problems))

    def test_a_stale_sub_bullet_count_is_reported(self):
        problems = self.run_on(index=INDEX.replace("open 2/3", "open 1/3"))
        self.assertTrue(any("7" in p and "2/3" in p for p in problems))

    def test_an_unresolvable_cross_reference_is_reported(self):
        problems = self.run_on(theme=THEME.replace("item 65", "item 999"))
        self.assertTrue(any("999" in p for p in problems))

    def test_a_duplicate_index_row_is_reported(self):
        problems = self.run_on(index=INDEX + "| 7 | do | open 2/3 | app.md | Dup |\n")
        self.assertTrue(any("7" in p and "twice" in p.lower() for p in problems))

    def test_an_archived_predecessor_under_an_open_id_is_legal(self):
        # item 4 has an open body in a theme AND an archived predecessor
        # under the same number. The archive is history, not a second home.
        problems = self.run_on(
            archive=ARCHIVE + "\n### 7. Backup checks, the original\nClosed part.\n")
        self.assertEqual(problems, [])

    def test_git_ignored_scratch_is_not_scanned(self):
        # .superpowers/sdd/<plan>/ holds task briefs that quote item numbers
        # out of the plan. They are not part of the todo tree.
        with TemporaryDirectory() as d:
            root = build(Path(d))
            scratch = root / "sdd" / "a-plan"
            scratch.mkdir(parents=True)
            (scratch / "task-1-brief.md").write_text(
                "Quotes item 999 from the plan.\n", encoding="utf-8")
            self.assertEqual(check(root), [])


if __name__ == "__main__":
    unittest.main()
