# Todo Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `.superpowers/todo.md` (2230 lines) into an always-read index, five theme files, a distilled decision log and an unread archive, preserving every item number.

**Architecture:** The split is performed by a checked-in Python script driven by an explicit id-to-theme mapping table, not by hand. A second script asserts the structural invariants and stays in the repo afterwards as the guard against drift. Judgement work — extracting still-binding constraints out of closed bodies — is deliberately a separate phase with its own review, because it is the only step a script cannot verify.

**Tech Stack:** Python 3.13 (stdlib only, `unittest`), markdown, Claude Code hooks (`.claude/settings.json`).

**Design spec:** `docs/superpowers/specs/2026-08-18-todo-restructure-design.md`

## Global Constraints

- **Never renumber.** Ids are `1`–`74` plus the literal `4b` and `4c`. Ids are never reused.
- **Bodies move verbatim.** The only permitted edits during Phase 1 are heading-level changes and sub-id insertion. No rewording, no summarising, no fixing of stale claims.
- **Sub-ids are `<parent>.<n>`**, numbered by source order within the parent, starting at 1, counting ticked and unticked bullets alike so a tick never renumbers a sibling.
- **Never touch `~/.claude/settings.json`.** The rule-3 gate is project-scoped; it must not fire in other repositories.
- **Hooks must declare `"shell": "bash"`** or they break on Windows (see `superpowers/6.2.0/docs/windows/polyglot-hooks.md`).
- **Run Python as `uv run --no-project python ...`** locally; this repo has no `pyproject.toml`. CI uses bare `python` on its own runner.
- **Temporary files go to the session scratchpad**, never `/tmp` (which resolves to `C:\tmp` on this machine).
- The three deliberate deletions, and nothing else, may be lost: the item 59/60/61 tombstones, the `## 0`/`A`/`B`/`C`/`D` band headers with their preambles, and `## Where the import stands`.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `scripts/todo/__init__.py` | package marker |
| `scripts/todo/parse.py` | parse a todo-style markdown into `Item` records; shared by both scripts |
| `scripts/todo/mapping.py` | the id-to-theme table and the deletion allowlist — data, not logic |
| `scripts/todo/migrate.py` | one-time split: `(text, mapping) -> {filename: text}` |
| `scripts/todo/check.py` | the standing invariant checker |
| `scripts/todo/tests/` | `unittest` suite for all four modules |
| `.superpowers/themes/*.md` | five theme files |
| `.superpowers/ARCHIVE.md`, `DECISIONS.md`, `STATUS.md` | archive, decision log, dashboard |
| `.claude/skills/closing-an-item/SKILL.md` | the rule-3 extraction procedure |

**Modified:** `.superpowers/todo.md` (becomes the index), `.github/workflows/tests.yml`, `.claude/settings.json`.

`parse.py` is separate from `check.py` because the migration is one-time and the checker is forever; folding them would leave dead migration code in a file CI runs weekly.

---

# Phase 1 — Mechanical Migration

Scriptable and verifiable. Ends with a green checker and a byte-level reconciliation against `git show`.

### Task 1: Parse todo markdown into items

**Files:**
- Create: `scripts/todo/__init__.py`, `scripts/todo/parse.py`
- Create: `scripts/todo/tests/__init__.py`, `scripts/todo/tests/test_parse.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `Item` dataclass with fields `id: str`, `title: str`, `start: int`, `end: int`, `body: list[str]`, `open_bullets: int`, `done_bullets: int`, and property `total_bullets: int`. Function `parse_items(lines: list[str]) -> list[Item]`. Function `section_of(lines: list[str], line_no: int) -> str` returning the enclosing `## ` heading text.

- [ ] **Step 1: Write the failing test**

```python
# scripts/todo/tests/test_parse.py
import unittest
from scripts.todo.parse import parse_items, section_of

SAMPLE = """# Title

## C. Not on the Critical Path

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells
- [x] Something already done
- [ ] A third thing

### 4b. Intensity/Damage Modifiers
Prose only, no bullets.

## Completed

### 65. HoH:MC Spell Extraction
- **Not a checkbox bullet.**
""".split("\n")


class ParseItemsTest(unittest.TestCase):
    def test_finds_every_item_including_letter_suffixed_ids(self):
        self.assertEqual([i.id for i in parse_items(SAMPLE)], ["7", "4b", "65"])

    def test_counts_open_and_done_bullets_separately(self):
        item = parse_items(SAMPLE)[0]
        self.assertEqual((item.open_bullets, item.done_bullets), (2, 1))
        self.assertEqual(item.total_bullets, 3)

    def test_a_prose_item_has_no_bullets(self):
        self.assertEqual(parse_items(SAMPLE)[1].total_bullets, 0)

    def test_a_non_checkbox_bullet_is_not_counted(self):
        self.assertEqual(parse_items(SAMPLE)[2].total_bullets, 0)

    def test_body_stops_at_the_next_section_not_the_next_item(self):
        # 4b is the last item of section C; its body must not swallow
        # the "## Completed" heading that follows it.
        body = parse_items(SAMPLE)[1].body
        self.assertIn("Prose only, no bullets.", body)
        self.assertNotIn("## Completed", body)

    def test_section_of_reports_the_enclosing_section(self):
        items = parse_items(SAMPLE)
        self.assertEqual(section_of(SAMPLE, items[0].start), "C. Not on the Critical Path")
        self.assertEqual(section_of(SAMPLE, items[2].start), "Completed")

    def test_titles_drop_the_id_prefix(self):
        self.assertEqual(parse_items(SAMPLE)[0].title, "Spell Export/Backup Validation")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --no-project python -m unittest discover -s scripts/todo/tests -t . -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.todo'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/todo/parse.py
"""Parse a todo-style markdown file into addressable items.

Shared by migrate.py (one-time) and check.py (forever). The body of an item
runs to the next `### ` heading OR the next `## ` section heading, whichever
comes first -- the last item of a section must not swallow the heading that
ends it.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

ITEM_RE = re.compile(r"^### (?P<id>\d+[a-z]?)\.\s*(?P<title>.*)$")
SECTION_RE = re.compile(r"^## (?P<title>.*)$")
OPEN_BULLET_RE = re.compile(r"^\s*- \[ \]")
DONE_BULLET_RE = re.compile(r"^\s*- \[x\]")


@dataclass
class Item:
    id: str
    title: str
    start: int          # 1-based line number of the ### heading
    end: int            # 1-based, inclusive, last line of the body
    body: list[str]
    open_bullets: int
    done_bullets: int

    @property
    def total_bullets(self) -> int:
        return self.open_bullets + self.done_bullets


def parse_items(lines: list[str]) -> list[Item]:
    heads = [(n, m) for n, line in enumerate(lines, 1)
             if (m := ITEM_RE.match(line))]
    stops = sorted([n for n, line in enumerate(lines, 1) if SECTION_RE.match(line)]
                   + [n for n, _ in heads])
    items = []
    for line_no, match in heads:
        later = [s for s in stops if s > line_no]
        end = (later[0] - 1) if later else len(lines)
        body = lines[line_no:end]
        items.append(Item(
            id=match.group("id"),
            title=match.group("title").strip(),
            start=line_no,
            end=end,
            body=body,
            open_bullets=sum(1 for b in body if OPEN_BULLET_RE.match(b)),
            done_bullets=sum(1 for b in body if DONE_BULLET_RE.match(b)),
        ))
    return items


def section_of(lines: list[str], line_no: int) -> str:
    """The `## ` heading enclosing a 1-based line number, or "" if none."""
    current = ""
    for n, line in enumerate(lines, 1):
        if n > line_no:
            break
        if m := SECTION_RE.match(line):
            current = m.group("title").strip()
    return current
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --no-project python -m unittest discover -s scripts/todo/tests -t . -v`
Expected: PASS, 6 tests

- [ ] **Step 5: Sanity-check against the real file**

Run:
```bash
uv run --no-project python -c "
from scripts.todo.parse import parse_items
lines = open('.superpowers/todo.md', encoding='utf-8').read().split('\n')
items = parse_items(lines)
print(len(items), 'items;', sum(i.open_bullets for i in items), 'open bullets')
"
```
Expected: `81 items; 80 open bullets`

- [ ] **Step 6: Commit**

```bash
git add scripts/todo/
git commit -m "feat: parse todo.md into addressable items"
```

---

### Task 2: The id-to-theme mapping table

**Files:**
- Create: `scripts/todo/mapping.py`
- Create: `scripts/todo/tests/test_mapping.py`

**Interfaces:**
- Consumes: `parse_items` from Task 1.
- Produces: `THEMES: dict[str, str]` mapping id to theme filename; `TOMBSTONES: frozenset[str]`; `MISFILED: dict[str, str]`; `ALL_IDS: frozenset[str]`; `theme_for(item_id: str) -> str`.

This task is data with a test that pins it to reality, so a later drift in `todo.md` fails loudly instead of silently dropping an item.

- [ ] **Step 1: Write the failing test**

```python
# scripts/todo/tests/test_mapping.py
import unittest
from scripts.todo.mapping import THEMES, TOMBSTONES, MISFILED, ALL_IDS, theme_for


class MappingTest(unittest.TestCase):
    def test_every_open_item_has_exactly_one_theme(self):
        for item_id in ALL_IDS - TOMBSTONES:
            self.assertIn(item_id, THEMES, f"item {item_id} has no theme")

    def test_tombstones_have_no_theme(self):
        for item_id in TOMBSTONES:
            self.assertNotIn(item_id, THEMES)

    def test_theme_counts_match_the_spec_appendix(self):
        counts = {}
        for theme in THEMES.values():
            counts[theme] = counts.get(theme, 0) + 1
        self.assertEqual(counts, {
            "rules-fidelity.md": 12,
            "app.md": 9,
            "model.md": 7,
            "importer.md": 6,
            "multibook.md": 2,
        })

    def test_item_73_is_recorded_as_misfiled_under_completed(self):
        self.assertEqual(MISFILED["73"], "importer.md")

    def test_theme_for_raises_on_an_unknown_id(self):
        with self.assertRaises(KeyError):
            theme_for("999")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --no-project python -m unittest scripts.todo.tests.test_mapping -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.todo.mapping'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/todo/mapping.py
"""Which theme file each item lands in.

Data, not logic. Derived from the spec's appendix. Changing an item's home
later is a one-line edit here plus a re-run of check.py -- nothing
cross-references a file, only a number.
"""
from __future__ import annotations

RULES = "rules-fidelity.md"
APP = "app.md"
MODEL = "model.md"
IMPORTER = "importer.md"
MULTIBOOK = "multibook.md"

THEMES: dict[str, str] = {
    # catalog vs. what the rulebook prints
    "4": RULES, "4b": RULES, "4c": RULES, "12": RULES, "20": RULES,
    "21": RULES, "22": RULES, "36": RULES, "41": RULES, "42": RULES,
    "50": RULES, "63": RULES,
    # the Flutter app and project chores
    "7": APP, "9": APP, "10": APP, "11": APP, "16": APP, "18": APP,
    "33": APP, "56": APP, "58": APP,
    # what the spell model can't yet express
    "47": MODEL, "53": MODEL, "54": MODEL, "57": MODEL, "67": MODEL,
    "69": MODEL, "74": MODEL,
    # scripts/spell_import, ledger, provenance
    "23": IMPORTER, "31": IMPORTER, "32": IMPORTER, "38": IMPORTER,
    "70": IMPORTER, "73": IMPORTER,
    # the second-book program
    "66": MULTIBOOK, "71": MULTIBOOK,
}

# Redirect-only headings in section C. Deleted; the index carries the redirect.
TOMBSTONES: frozenset[str] = frozenset({"59", "60", "61"})

# Filed under `## Completed` but carrying only open bullets.
MISFILED: dict[str, str] = {"73": IMPORTER}

# Every id `todo.md` currently holds, closed ones included.
ALL_IDS: frozenset[str] = frozenset(
    {str(n) for n in range(1, 75)} | {"4b", "4c"}
)


def theme_for(item_id: str) -> str:
    return THEMES[item_id]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --no-project python -m unittest scripts.todo.tests.test_mapping -v`
Expected: PASS, 5 tests.

`ALL_IDS` is enforced against the real file by `split`'s precondition in Task 4,
not by a test here — a test reading `.superpowers/todo.md` would go red the
moment Task 5 replaces that file with the index.

- [ ] **Step 5: Commit**

```bash
git add scripts/todo/mapping.py scripts/todo/tests/test_mapping.py
git commit -m "feat: pin the id-to-theme mapping with a reality check"
```

---

### Task 3: The invariant checker

**Files:**
- Create: `scripts/todo/check.py`
- Create: `scripts/todo/tests/test_check.py`

**Interfaces:**
- Consumes: `parse_items`, `Item` from Task 1; `ALL_IDS` from Task 2.
- Produces: `check(root: Path) -> list[str]` returning human-readable problems, empty when clean. `main() -> int` for CLI use, exit 1 on problems. Scans only `TRACKED` plus `themes/*.md` — never the git-ignored scratch under `.superpowers/`.

This is the artefact that outlives the migration. It encodes the spec's Verification section as something runnable.

- [ ] **Step 1: Write the failing test**

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --no-project python -m unittest scripts.todo.tests.test_check -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.todo.check'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/todo/check.py
"""Structural invariants for the split todo tree.

Run by CI and by the closing-an-item skill. Encodes the design spec's
Verification section:

  * every index row's Home file really holds that heading
  * every heading in a theme or the archive really has an index row
  * the index's `open a/b` counts match the bodies
  * every `item N` cross-reference resolves to an index row
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from scripts.todo.parse import parse_items

ROW_RE = re.compile(
    r"^\|\s*(?P<id>\d+[a-z]?)\s*\|"      # id
    r"\s*(?P<kind>[^|]*)\|"              # kind
    r"\s*(?P<status>[^|]*)\|"            # status
    r"\s*(?P<home>[^|]*)\|"              # home
)
COUNT_RE = re.compile(r"open\s+(?P<open>\d+)/(?P<total>\d+)")
XREF_RE = re.compile(r"\bitems?\s+(\d+[a-z]?)")


TRACKED = ("todo.md", "DECISIONS.md", "STATUS.md", "ARCHIVE.md")


def _read(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").split("\n")


def _tracked_files(root: Path):
    """Only the todo tree.

    `.superpowers/` also holds git-ignored scratch -- the SDD workspace and
    base_effects_extraction -- whose prose is not ours to police. Task briefs
    in particular quote item numbers out of the plan, so an rglob here would
    fail on this run's own working files.
    """
    for name in TRACKED:
        if (root / name).exists():
            yield root / name
    yield from sorted(root.glob("themes/*.md"))


def _index_rows(lines: list[str]) -> list[dict[str, str]]:
    rows = []
    for line in lines:
        if m := ROW_RE.match(line):
            rows.append({k: v.strip() for k, v in m.groupdict().items()})
    return rows


def check(root: Path) -> list[str]:
    problems: list[str] = []
    index_lines = _read(root / "todo.md")
    rows = _index_rows(index_lines)

    seen: set[str] = set()
    for row in rows:
        if row["id"] in seen:
            problems.append(f"item {row['id']}: listed twice in the index")
        seen.add(row["id"])

    # Every body heading, keyed by id, with the file it was found in.
    bodies: dict[str, tuple[str, object]] = {}
    for path in sorted(root.glob("themes/*.md")) + [root / "ARCHIVE.md"]:
        if not path.exists():
            continue
        for item in parse_items(_read(path)):
            if item.id in bodies:
                problems.append(f"item {item.id}: body appears in two files")
            bodies[item.id] = (path.name, item)

    by_id = {row["id"]: row for row in rows}

    for row in rows:
        home, item_id = row["home"], row["id"]
        found = bodies.get(item_id)
        if found is None or found[0] != home:
            where = "nowhere" if found is None else found[0]
            problems.append(
                f"item {item_id}: index says {home}, body found in {where}")
            continue
        if m := COUNT_RE.search(row["status"]):
            item = found[1]
            actual = (item.open_bullets, item.total_bullets)
            claimed = (int(m.group("open")), int(m.group("total")))
            if actual != claimed:
                problems.append(
                    f"item {item_id}: index claims open {claimed[0]}/{claimed[1]}, "
                    f"body has {actual[0]}/{actual[1]}")

    for item_id, (name, _) in sorted(bodies.items()):
        if item_id not in by_id:
            problems.append(f"item {item_id}: orphan heading in {name}, no index row")

    for path in _tracked_files(root):
        for n, line in enumerate(_read(path), 1):
            if line.lstrip().startswith("|"):
                continue        # index rows are not cross-references
            for ref in XREF_RE.findall(line):
                if ref not in by_id:
                    problems.append(
                        f"{path.name}:{n}: 'item {ref}' resolves to no index row")

    return problems


def main() -> int:
    problems = check(Path(".superpowers"))
    for problem in problems:
        print(problem)
    print(f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --no-project python -m unittest scripts.todo.tests.test_check -v`
Expected: PASS, 7 tests

**Known limitation, accept it deliberately:** `XREF_RE` catches `item 25` and
the *first* number of `items 65, 57, 27`. It under-detects rather than
false-alarms, so a green checker does not prove all 165 references resolve — it
proves no *detected* reference dangles. Widening it to comma lists is a fine
later change; do not weaken it to make a failure go away.

- [ ] **Step 5: Commit**

```bash
git add scripts/todo/check.py scripts/todo/tests/test_check.py
git commit -m "feat: structural invariant checker for the split todo tree"
```

---

### Task 4: The migrator

**Files:**
- Create: `scripts/todo/migrate.py`
- Create: `scripts/todo/tests/test_migrate.py`

**Interfaces:**
- Consumes: `parse_items`, `Item`, `section_of` from Task 1; `THEMES`, `TOMBSTONES`, `MISFILED`, `ALL_IDS` from Task 2.
- Produces: `split(lines: list[str], expected_ids: frozenset[str] | None = None) -> dict[str, str]` mapping output relative path to full text; raises `ValueError` when the file's ids do not match `ALL_IDS`. `add_sub_ids(body: list[str], item_id: str) -> list[str]`.

Pure function. Writing files is the caller's job (Task 5), so the split is unit-testable without touching disk.

- [ ] **Step 1: Write the failing test**

```python
# scripts/todo/tests/test_migrate.py
import unittest
from scripts.todo.migrate import split, add_sub_ids

SAMPLE = """# Eruditus Todo List

## C. Not on the Critical Path

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells
- [x] Already done

### 59. The Level Should Compute Live
**✅ COMPLETE 2026-08-17** — see `## Completed ✅`.

## Completed ✅

### 65. HoH:MC Spell Extraction
Closed, with a binding constraint inside.

### 73. Deferred Minor Findings
- [ ] Something still open
""".split("\n")


class AddSubIdsTest(unittest.TestCase):
    def test_numbers_bullets_in_source_order_from_one(self):
        out = add_sub_ids(["- [ ] first", "- [x] second", "- [ ] third"], "38")
        self.assertEqual(out, [
            "- [ ] **38.1** first",
            "- [x] **38.2** second",
            "- [ ] **38.3** third",
        ])

    def test_a_ticked_bullet_still_consumes_its_number(self):
        # so ticking one never renumbers a sibling
        out = add_sub_ids(["- [x] done", "- [ ] open"], "9")
        self.assertTrue(out[1].startswith("- [ ] **9.2**"))

    def test_indented_continuation_lines_are_untouched(self):
        out = add_sub_ids(["- [ ] first", "      continued here"], "7")
        self.assertEqual(out[1], "      continued here")

    def test_non_checkbox_bullets_are_untouched(self):
        out = add_sub_ids(["- **See also:** item 65"], "72")
        self.assertEqual(out, ["- **See also:** item 65"])


SAMPLE_IDS = frozenset({"7", "59", "65", "73"})


class SplitTest(unittest.TestCase):
    def setUp(self):
        self.out = split(SAMPLE, SAMPLE_IDS)

    def test_a_file_the_mapping_does_not_match_is_refused(self):
        with self.assertRaises(ValueError) as caught:
            split(SAMPLE, SAMPLE_IDS | {"999"})
        self.assertIn("999", str(caught.exception))

    def test_open_items_land_in_their_theme_file(self):
        self.assertIn("### 7. Spell Export/Backup Validation",
                      self.out["themes/app.md"])

    def test_closed_items_land_in_the_archive(self):
        self.assertIn("### 65. HoH:MC Spell Extraction", self.out["ARCHIVE.md"])

    def test_a_misfiled_item_goes_to_its_theme_not_the_archive(self):
        self.assertIn("### 73. Deferred Minor Findings",
                      self.out["themes/importer.md"])
        self.assertNotIn("### 73.", self.out["ARCHIVE.md"])

    def test_tombstones_are_dropped_entirely(self):
        joined = "".join(self.out.values())
        self.assertNotIn("### 59.", joined)

    def test_the_index_lists_every_surviving_item_once(self):
        index = self.out["todo.md"]
        for item_id in ("7", "65", "73"):
            self.assertEqual(index.count(f"| {item_id} "), 1)

    def test_the_index_records_sub_bullet_counts(self):
        self.assertIn("open 1/2", self.out["todo.md"])

    def test_bodies_are_carried_verbatim_apart_from_sub_ids(self):
        self.assertIn("Closed, with a binding constraint inside.",
                      self.out["ARCHIVE.md"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --no-project python -m unittest scripts.todo.tests.test_migrate -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.todo.migrate'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/todo/migrate.py
"""The one-time split of todo.md into an index, themes and an archive.

Pure: `split` returns {relative path: text} and touches no disk. Bodies are
copied verbatim; the only edit is sub-id insertion.
"""
from __future__ import annotations

import re

from scripts.todo.mapping import ALL_IDS, MISFILED, THEMES, TOMBSTONES
from scripts.todo.parse import Item, parse_items, section_of

CHECKBOX_RE = re.compile(r"^(?P<lead>\s*- \[(?: |x)\] )(?P<rest>.*)$")

INDEX_HEADER = """# Eruditus — Item Index

**Now:** _(set during re-triage)_

**How this works:** item numbers are stable global ids, never reused and never
renumbered. Themes are files; the table below is the only thing that maps a
number to its home. `open 3/7` means three of seven sub-ids remain open.
Standing constraints live in `DECISIONS.md`; closed bodies in `ARCHIVE.md`.

| #  | Kind | Status | Home | Title |
|----|------|--------|------|-------|
"""


def add_sub_ids(body: list[str], item_id: str) -> list[str]:
    out, n = [], 0
    for line in body:
        if m := CHECKBOX_RE.match(line):
            n += 1
            out.append(f"{m.group('lead')}**{item_id}.{n}** {m.group('rest')}")
        else:
            out.append(line)
    return out


def _status(item: Item, closed: bool) -> str:
    if closed:
        return "closed"
    if item.total_bullets:
        return f"open {item.open_bullets}/{item.total_bullets}"
    return "open"


def split(lines: list[str],
          expected_ids: frozenset[str] | None = None) -> dict[str, str]:
    """Split todo.md. Refuses to run against a file mapping.py does not match.

    The guard lives here rather than in a test because a test reading the live
    todo.md would go red the moment the migration replaces that file.
    """
    expected = ALL_IDS if expected_ids is None else expected_ids
    found = {item.id for item in parse_items(lines)}
    if found != expected:
        raise ValueError(
            f"todo.md has moved since mapping.py was written: "
            f"{sorted(found ^ expected)} -- reconcile ALL_IDS and THEMES first")

    files: dict[str, list[str]] = {}
    rows: list[tuple[str, str]] = []

    def emit(path: str, text: list[str]) -> None:
        files.setdefault(path, []).extend(text)

    for item in parse_items(lines):
        if item.id in TOMBSTONES:
            continue
        in_completed = section_of(lines, item.start).startswith("Completed")
        closed = in_completed and item.id not in MISFILED
        home = "ARCHIVE.md" if closed else f"themes/{THEMES[item.id]}"
        body = item.body if closed else add_sub_ids(item.body, item.id)
        emit(home, [f"### {item.id}. {item.title}"] + body + [""])
        shown = home.split("/")[-1]
        rows.append((item.id, f"| {item.id} |  | {_status(item, closed)} "
                              f"| {shown} | {item.title} |"))

    def sort_key(row: tuple[str, str]) -> tuple[int, str]:
        digits = re.match(r"(\d+)([a-z]?)", row[0])
        return int(digits.group(1)), digits.group(2)

    index = INDEX_HEADER + "\n".join(r for _, r in sorted(rows, key=sort_key)) + "\n"

    out = {"todo.md": index}
    for path, text in files.items():
        title = path.split("/")[-1].removesuffix(".md").replace("-", " ").title()
        out[path] = f"# {title}\n\n" + "\n".join(text).rstrip() + "\n"
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --no-project python -m unittest scripts.todo.tests.test_migrate -v`
Expected: PASS, 12 tests

- [ ] **Step 5: Run the whole suite**

Run: `uv run --no-project python -m unittest discover -s scripts/todo/tests -t . -v`
Expected: PASS, 30 tests

- [ ] **Step 6: Commit**

```bash
git add scripts/todo/migrate.py scripts/todo/tests/test_migrate.py
git commit -m "feat: pure split of todo.md into index, themes and archive"
```

---

### Task 5: Run the migration and reconcile

**Files:**
- Create: `.superpowers/themes/*.md`, `.superpowers/ARCHIVE.md`, `.superpowers/STATUS.md`, `.superpowers/DECISIONS.md`
- Modify: `.superpowers/todo.md` (replaced by the index)

**Interfaces:**
- Consumes: `split` from Task 4, `check` from Task 3.
- Produces: the migrated tree. No new symbols.

- [ ] **Step 1: Confirm the pre-migration baseline**

```bash
git show HEAD:.superpowers/todo.md | wc -l
```

Expected: 2230. If it differs, `todo.md` moved after this plan was written —
re-run Task 2's mapping test before going further.

- [ ] **Step 2: Move the two hand-written sections out before splitting**

`## Where the import stands` becomes `STATUS.md`; `## Notes — standing constraints` seeds `DECISIONS.md`. Both move **verbatim**; distillation is Phase 2's job.

```bash
uv run --no-project python - <<'PY'
from pathlib import Path
lines = Path(".superpowers/todo.md").read_text(encoding="utf-8").split("\n")
def section(name):
    start = next(i for i, l in enumerate(lines) if l.startswith(f"## {name}"))
    end = next((i for i, l in enumerate(lines[start + 1:], start + 1)
                if l.startswith("## ")), len(lines))
    return "\n".join(lines[start:end]).rstrip() + "\n"

Path(".superpowers/STATUS.md").write_text(
    "# Status\n\n**Hand-maintained until the generator lands.** Every figure "
    "below was obtained by running something; re-verify before trusting.\n\n"
    + section("Where the import stands"), encoding="utf-8")
Path(".superpowers/DECISIONS.md").write_text(
    "# Standing Decisions and Constraints\n\nOrganised by topic. Each entry "
    "cites the item it came from.\n\n"
    + section("Notes — standing constraints"), encoding="utf-8")
print("wrote STATUS.md and DECISIONS.md")
PY
```

- [ ] **Step 3: Run the split**

```bash
uv run --no-project python - <<'PY'
from pathlib import Path
from scripts.todo.migrate import split
root = Path(".superpowers")
lines = (root / "todo.md").read_text(encoding="utf-8").split("\n")
(root / "themes").mkdir(exist_ok=True)
for rel, text in split(lines).items():
    (root / rel).write_text(text, encoding="utf-8")
    print(f"{rel}: {len(text.splitlines())} lines")
PY
```

Expected: `todo.md` around 90 lines; five theme files; `ARCHIVE.md` around 950.

- [ ] **Step 4: Run the checker**

Run: `uv run --no-project python -m scripts.todo.check`
Expected: `0 problem(s)`, exit 0.

If cross-reference problems appear for ids that only ever lived in prose, fix the prose — do not weaken the checker.

- [ ] **Step 5: Reconcile against the snapshot**

Every non-blank line of the original must survive somewhere, except the enumerated deletions.

```bash
uv run --no-project python - <<'PY'
import subprocess
from pathlib import Path
before = subprocess.run(["git", "show", "HEAD:.superpowers/todo.md"],
                        capture_output=True, text=True,
                        encoding="utf-8").stdout.split("\n")
from scripts.todo.check import _tracked_files
after = "\n".join(p.read_text(encoding="utf-8")
                  for p in _tracked_files(Path(".superpowers")))
allowed = ("## 0.", "## A.", "## B.", "## C.", "## D.",
           "## Where the import stands", "### 59.", "### 60.", "### 61.")
missing = [l for l in before
           if l.strip() and l not in after and not l.startswith(allowed)]
print(f"{len(missing)} unaccounted lines")
for line in missing[:40]:
    print("  ", line[:100])
PY
```

Reads the baseline straight from git, so nothing depends on a scratchpad path.
Expected: a small count, every entry traceable to a band preamble or a
tombstone. **Anything else is a dropped body — stop and fix before
committing.**

- [ ] **Step 6: CHECKPOINT — re-triage with the user**

Present all 36 open items with a proposed `Kind` (`decide`/`do`/`maybe`) read
off each body, and ask for the `Now:` line. Fill both into `todo.md`. Do not
guess the `Now:` line.

The migrator writes closed rows as bare `closed`, not `closed 08-17` as the
spec's illustrative sample shows — a closure date is not reliably recoverable
from every heading, and inventing one would be worse than omitting it. Add
dates here for the items whose headings state one. The checker parses only
`open a/b`, so either form passes.

- [ ] **Step 7: Wire the checker into CI**

Add to `.github/workflows/tests.yml`, in the job that runs the Python suite:

```yaml
      - name: Check the todo tree's structural invariants
        run: python -m scripts.todo.check
```

- [ ] **Step 8: Run every suite**

```bash
uv run --no-project python -m unittest discover -s scripts/todo/tests -t .
uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .
flutter test
```
Expected: all green. `flutter test` is unaffected but proves the tree is untouched.

- [ ] **Step 9: Commit**

```bash
git add .superpowers/ .github/workflows/tests.yml
git commit -m "refactor: split todo.md into an index, five themes and an archive"
```

---

# Phase 2 — Constraint Extraction

**Run this in a separate session.** It is the only step no script verifies, and the one the whole restructure depends on. Phase 1 must be committed and green first.

### Task 6: Distil DECISIONS.md from the archived bodies

**Files:**
- Modify: `.superpowers/DECISIONS.md`
- Read: `.superpowers/ARCHIVE.md`

**Interfaces:**
- Consumes: the migrated tree from Task 5.
- Produces: no symbols. Output is prose, reviewed by the user.

- [ ] **Step 1: Read all 41 archived bodies**

Read `ARCHIVE.md` end to end. Do not skim — the constraints are embedded in narrative, not signposted.

- [ ] **Step 2: Extract every still-binding statement**

A statement qualifies only if a future session could **violate it by accident**. Concretely:

| Qualifies | Does not |
|---|---|
| a naming rule with a stated reason (item 72's "Effect complexity") | what the work was |
| an invariant later code must preserve | which commits did it |
| a rejected approach plus why it was rejected | the review process used |
| a gotcha that bit someone once | a count, a date, a test name |

Record each as a topic-headed entry citing its origin item, matching the existing shape in `DECISIONS.md`:

```markdown
## <Topic>
<the constraint, stated as a rule, with its reason>  *(item N)*
```

Group by topic and merge duplicates across items — the same rule stated in two closed bodies becomes one entry citing both.

- [ ] **Step 3: Verify each entry against its source**

For each entry, re-read the archived body it cites and confirm the entry does not overstate it. An extraction that hardens a tentative observation into a rule is worse than no extraction.

- [ ] **Step 4: Run the checker**

Run: `uv run --no-project python -m scripts.todo.check`
Expected: `0 problem(s)` — the `item N` citations must all resolve.

- [ ] **Step 5: CHECKPOINT — user reviews the output**

Present `DECISIONS.md` in full. This is the review the phase exists for. Expect entries to be cut as over-extracted or added as missed.

- [ ] **Step 6: Commit**

```bash
git add .superpowers/DECISIONS.md
git commit -m "docs: distil standing constraints out of the archived bodies"
```

---

# Phase 3 — The Rule-3 Gate

Lands after Phase 2, because the gate points at `DECISIONS.md`.

### Task 7: The closing-an-item skill

**Files:**
- Create: `.claude/skills/closing-an-item/SKILL.md`

**Interfaces:**
- Consumes: `check` from Task 3.
- Produces: a skill invokable as `closing-an-item`.

- [ ] **Step 1: Write the skill**

```markdown
---
name: closing-an-item
description: Use when an item in .superpowers/ closes, or when a merge lands that closed one - extracts still-binding constraints into DECISIONS.md before the body is archived
---

# Closing an Item

Lifecycle rule 3: **constraints come out before the body goes in.** An item's
body is about to stop being read. Anything in it that still binds must move to
`DECISIONS.md` first, or it is lost.

## Steps

1. **Identify what closed.** Name the item numbers the merge closed. A merge may
   close several items, or none — "none" is a valid answer and ends this
   procedure after step 5.
2. **Re-read each closing item's body in full**, in its theme file.
3. **Extract every still-binding statement into `DECISIONS.md`**, topic-headed,
   citing the item. A statement qualifies only if a future session could violate
   it by accident: a naming rule with its reason, an invariant later code must
   preserve, a rejected approach and why, a gotcha that bit someone. Not: what
   the work was, which commits did it, counts, dates, test names.
4. **Move the body verbatim to `ARCHIVE.md`** and flip its index row to
   `closed <MM-DD>`, home `ARCHIVE.md`, `Kind` `—`.
5. **Record the merge as reviewed:**

   ```bash
   git rev-list --merges -1 HEAD > .superpowers/.last-reviewed-merge
   ```

6. **Verify:** `uv run --no-project python -m scripts.todo.check` must print
   `0 problem(s)`.
7. **Commit** `.superpowers/` together, so the extraction and the archival land
   in one commit.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The body is in git, nothing is lost" | Git is not read at session start. Unextracted means unread. |
| "It's all obvious from the code" | If it were, the item would not have needed a reason written down. |
| "This merge closed nothing, skip the whole thing" | Still run step 5, or the gate asks again tomorrow. |
| "I'll extract it when someone needs it" | That is exactly how the 1007-line Completed section happened. |
```

- [ ] **Step 2: Verify the skill loads**

Run: `uv run --no-project python -c "
import re, pathlib
text = pathlib.Path('.claude/skills/closing-an-item/SKILL.md').read_text(encoding='utf-8')
assert text.startswith('---'), 'missing frontmatter'
assert re.search(r'^name: closing-an-item$', text, re.M), 'missing name'
assert re.search(r'^description: ', text, re.M), 'missing description'
print('frontmatter ok')
"`
Expected: `frontmatter ok`

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/closing-an-item/
git commit -m "feat: closing-an-item skill holding the rule-3 procedure"
```

---

### Task 8: The Stop hook

**Files:**
- Create: `.superpowers/.last-reviewed-merge`
- Modify: `.claude/settings.json`

**Interfaces:**
- Consumes: the skill from Task 7.
- Produces: a project-scoped `Stop` hook.

- [ ] **Step 1: Seed the state file at the current merge**

```bash
git rev-list --merges -1 HEAD > .superpowers/.last-reviewed-merge
cat .superpowers/.last-reviewed-merge
```

Seeding at HEAD is deliberate: the migration's own merge closed no item, so the gate must not fire for it.

- [ ] **Step 2: Write the hook script**

Create `.superpowers/hooks/check-merge-reviewed` (extensionless, per the Windows polyglot-hooks guidance):

```bash
#!/usr/bin/env bash
# Stop hook: has the newest merge had its item-closure extraction done?
# Exit 2 feeds stderr back to Claude and blocks the turn from ending.
set -u

state=".superpowers/.last-reviewed-merge"
[ -f "$state" ] || exit 0

newest=$(git rev-list --merges -1 HEAD 2>/dev/null) || exit 0
[ -n "$newest" ] || exit 0

reviewed=$(cat "$state")
[ "$newest" = "$reviewed" ] && exit 0

subject=$(git log -1 --format=%s "$newest")
cat >&2 <<EOF
Merge $newest has not been through item closure:

  $subject

Invoke the closing-an-item skill. If it closed no items, say so and record it:
  git rev-list --merges -1 HEAD > $state
EOF
exit 2
```

- [ ] **Step 3: Make it executable and test it fires**

```bash
chmod +x .superpowers/hooks/check-merge-reviewed
echo "0000000000000000000000000000000000000000" > .superpowers/.last-reviewed-merge
bash .superpowers/hooks/check-merge-reviewed; echo "exit=$?"
```
Expected: the message on stderr, `exit=2`.

- [ ] **Step 4: Test it stays quiet when current**

```bash
git rev-list --merges -1 HEAD > .superpowers/.last-reviewed-merge
bash .superpowers/hooks/check-merge-reviewed; echo "exit=$?"
```
Expected: no output, `exit=0`.

- [ ] **Step 5: Register the hook**

Use the `update-config` skill to add to **`.claude/settings.json`** (the project file, never `~/.claude/settings.json`):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .superpowers/hooks/check-merge-reviewed",
            "shell": "bash"
          }
        ]
      }
    ]
  }
}
```

`"shell": "bash"` is required — without it PowerShell mis-parses the command on Windows.

- [ ] **Step 6: Commit**

```bash
git add .claude/settings.json .superpowers/hooks/ .superpowers/.last-reviewed-merge
git commit -m "feat: gate merges on item-closure extraction"
```

---

## Done When

- `.superpowers/todo.md` is an index of roughly 90 lines and every id 1–74 resolves.
- `uv run --no-project python -m scripts.todo.check` prints `0 problem(s)`, and CI runs it.
- `DECISIONS.md` holds the constraints, reviewed by the user; `ARCHIVE.md` holds 41 closed bodies.
- A merge that has not been through closure blocks the turn until it has.
