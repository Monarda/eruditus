# Page References (item 78) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every citation a printed page number where the evidence supports one, so item 56's hints can say "see p. 112".

**Architecture:** A new `pages.py` parses the rulebook's four index tables into an anchor→page map and a line→page lookup, guarded so it returns `None` rather than guessing. Three populations get pages three ways: core spells from the curated Spells Index, core guidelines/parameters/modifiers by nearest-preceding-anchor inference, and HoH:MC from a committed ledger authored by reading its PDF. Delivery is split because only three of the six assets have a generator.

**Tech Stack:** Python 3 stdlib only (`re`, `json`, `bisect`, `unittest`) for everything committed. `pypdf` is used *once*, by a subagent authoring a ledger, and never enters the repo.

**Spec:** `docs/superpowers/specs/2026-08-21-page-references-design.md`

## Global Constraints

- **Python is stdlib-only.** `scripts/spell_import/` has no third-party dependency and must not gain one. `pypdf` appears only in a throwaway script under the scratchpad, never under `scripts/`.
- **Run Python as `uv run --no-project python -m scripts.spell_import.<module>`** from the repo root. This repo has no `pyproject.toml`.
- **The Python suite is `python -m unittest discover -s scripts/spell_import/tests -t .` — 397 tests, green.** Leave it green and report the new total.
- **The Dart suite is 860 tests, green.** Only the last task touches Dart.
- **Never run `dart format`.** It is not clean in this repo. `flutter analyze` must exit 0.
- **The rulebook is a sibling checkout** at `../Ars-Magica-Open-License`, pinned at `ffc1c6b`. Read `reviewed/Ars Magica - Definitive Edition (Core Rules).md`. Never write to it.
- **Never run `find` at the filesystem root.** A PreToolUse hook enforces this machine-wide.
- **Preserve each asset's existing newline convention** when rewriting it. `scripts/flag_ritual_effects.py`'s header records that this bit someone before.
- **A null page is valid and permanent.** `Citation`'s doc comment says a citation naming only its book is complete. Never emit a guessed page to avoid a null.
- **`bookId` denotes an edition.** `Citation.page` stays a scalar `int?`; a different edition is a different `bookId`. Decided in the spec (78.6); do not introduce an edition field.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/spell_import/pages.py` | **New.** Parse the four index tables; slug headings GitHub-style with dedupe; expose `anchor_pages`, `line_pages`, `page_for_line`, and `spell_index_pages`. Owns both guards. |
| `scripts/spell_import/tests/test_pages.py` | **New.** Slugging, ranges, monotonicity, both guards. |
| `scripts/spell_import/hohmc_pages.json` | **New.** Committed ledger: HoH:MC record id → page + the evidence phrase. |
| `scripts/spell_import/emit.py` | Populate `page` on the three emitted assets. |
| `scripts/enrich_catalog_pages.py` | **New one-shot.** Pages into the three hand-maintained catalogs; applied once, then kept for reference. |
| `lib/models/citation.dart` | Retract the "cannot" doc comment. |
| `.superpowers/DECISIONS.md` | Retract the "Known limits" entry. |

---

### Task 1: The anchor map and its guards

Pure parsing over the rulebook markdown. No assets change, nothing consumes it yet.

**Files:**
- Create: `scripts/spell_import/pages.py`
- Test: `scripts/spell_import/tests/test_pages.py`

**Interfaces:**
- Consumes: `scripts/spell_import/sources.py` for the rulebook path — read it and use its existing accessor rather than hardcoding a path.
- Produces:
  - `slugify(heading: str) -> str`
  - `build_index(lines: list[str]) -> PageIndex`
  - `class PageIndex` with fields `anchor_pages: dict[str, int]`, `line_pages: list[tuple[int, int]]`, `spell_index_pages: dict[str, int]` (spell name → page, from the Spells Index), `heading_lines: list[int]`, `heading_slugs: dict[str, int]` (slug → heading line), and methods `page_for_line(line: int) -> int | None` and `monotonicity_violations() -> list[tuple[int, int, int, int]]`
  - `load_index() -> PageIndex` — reads the pinned rulebook and builds one
  - `MAX_ANCHOR_DISTANCE = 60`

- [ ] **Step 1: Read the two files you must match**

Read `scripts/spell_import/sources.py` (how the rulebook path is resolved — do not hardcode it) and `scripts/spell_import/tests/test_sources.py` (how tests get at the rulebook). Follow both. If the rulebook is unavailable in your environment, report NEEDS_CONTEXT rather than inventing a fixture path.

- [ ] **Step 2: Write the failing test**

Create `scripts/spell_import/tests/test_pages.py`:

```python
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


class BuildIndexTest(unittest.TestCase):
    def test_duplicate_headings_get_numeric_suffixes_in_document_order(self):
        lines = ["# Alpha", "text", "# Alpha", "text", "# Alpha"]
        index = pages.build_index(lines)
        self.assertEqual(
            sorted(index.heading_lines), [1, 3, 5],
            "every duplicate heading must keep its own line, not collapse")
        self.assertIn("alpha", index.heading_slugs)
        self.assertIn("alpha-1", index.heading_slugs)
        self.assertIn("alpha-2", index.heading_slugs)

    def test_a_page_range_takes_its_first_page(self):
        lines = ["# Ability Types", "| Entry | [158-159](#ability-types) |"]
        index = pages.build_index(lines)
        self.assertEqual(index.anchor_pages["ability-types"], 158)

    def test_an_anchor_with_no_matching_heading_is_dropped_not_guessed(self):
        lines = ["# Real", "| x | [12](#not-a-heading) |"]
        index = pages.build_index(lines)
        self.assertNotIn("not-a-heading", index.anchor_pages)


class PageForLineTest(unittest.TestCase):
    def _index(self):
        # Heading at line 1 = page 10; heading at line 100 = page 20.
        lines = ["# A"] + ["body"] * 98 + ["# B", "| x | [10](#a) | [20](#b) |"]
        return pages.build_index(lines)

    def test_returns_the_nearest_preceding_anchor(self):
        self.assertEqual(self._index().page_for_line(50 - 30), 10)

    def test_refuses_when_the_nearest_anchor_is_too_far(self):
        index = self._index()
        self.assertIsNone(
            index.page_for_line(1 + pages.MAX_ANCHOR_DISTANCE + 1),
            "a page inferred across a large gap is a guess, not a reading")

    def test_accepts_just_inside_the_distance_guard(self):
        index = self._index()
        self.assertEqual(index.page_for_line(1 + pages.MAX_ANCHOR_DISTANCE - 1), 10)

    def test_returns_none_before_the_first_anchor(self):
        self.assertIsNone(self._index().page_for_line(0))


class RealRulebookTest(unittest.TestCase):
    """Measured facts about the pinned rulebook. If one of these changes, the
    source moved -- check `source.lock` before changing the number."""

    @classmethod
    def setUpClass(cls):
        cls.index = pages.load_index()

    def test_resolves_about_sixteen_hundred_calibration_points(self):
        self.assertGreater(len(self.index.line_pages), 1500)

    def test_the_spells_index_covers_every_published_spell(self):
        self.assertEqual(len(self.index.spell_index_pages), 360)

    def test_pages_never_go_backwards_as_lines_advance(self):
        violations = self.index.monotonicity_violations()
        self.assertEqual(
            violations, [],
            "an anchor read out of its section poisons every line after it "
            "until the next anchor -- see the spec, section 3")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_pages -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.pages'`.

- [ ] **Step 4: Implement `pages.py`**

Write `scripts/spell_import/pages.py`:

```python
"""Printed page numbers, recovered from the rulebook's four index tables.

Every row in those tables cites a page as `[313](#anchor)`, and an anchor
resolves to a heading whose line we know -- so a line's page is the page of
the nearest anchored heading above it. Both guards below return None rather
than a guess: a wrong page sends a reader to the wrong place, which is worse
than sending them nowhere.

See docs/superpowers/specs/2026-08-21-page-references-design.md.
"""

import bisect
import re

from scripts.spell_import import sources

# How far above a line its nearest anchor may sit before inference becomes a
# guess. Measured distance from a guideline to its nearest anchor is median
# 13 / p90 22 lines, and a printed page spans roughly 44 markdown lines -- so
# 60 accepts every real case while refusing the 789-line gap that exists
# elsewhere in the document.
MAX_ANCHOR_DISTANCE = 60

# `[313](#anchor)` and `[158-159](#anchor)`. The range's first page is what a
# citation carries; the pattern must still recognise the form, or the row is
# silently skipped rather than parsed.
_ANCHOR = re.compile(r"\[(\d+)(?:-\d+)?\]\(#([^)]+)\)")
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")


def slugify(heading):
    """GitHub's heading-slug rules, which is what the anchors were built with."""
    text = heading.strip().lstrip("#").strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    return re.sub(r"\s+", "-", text).strip("-")


class PageIndex:
    def __init__(self, anchor_pages, line_pages, spell_index_pages,
                 heading_lines, heading_slugs):
        self.anchor_pages = anchor_pages
        self.line_pages = line_pages
        self.spell_index_pages = spell_index_pages
        self.heading_lines = heading_lines
        self.heading_slugs = heading_slugs
        self._lines = [line for line, _ in line_pages]

    def page_for_line(self, line):
        """The printed page of `line`, or None when the evidence is too thin."""
        position = bisect.bisect_right(self._lines, line) - 1
        if position < 0:
            return None
        anchor_line, page = self.line_pages[position]
        if line - anchor_line > MAX_ANCHOR_DISTANCE:
            return None
        return page

    def monotonicity_violations(self):
        """Adjacent calibration points whose page decreases as the line grows.

        A decrease means an anchor is being read out of its section, and
        `page_for_line` walks backwards -- so one bad anchor gives a wrong
        page to every line after it until the next one.
        """
        out = []
        for i in range(len(self.line_pages) - 1):
            line_a, page_a = self.line_pages[i]
            line_b, page_b = self.line_pages[i + 1]
            if page_b < page_a:
                out.append((line_a, page_a, line_b, page_b))
        return out


def _headings(lines):
    """Slug every heading, deduping repeats the way GitHub does."""
    seen = {}
    slugs = {}
    heading_lines = []
    for offset, text in enumerate(lines):
        if not text.strip().startswith("#"):
            continue
        line = offset + 1
        heading_lines.append(line)
        base = slugify(text)
        count = seen.get(base, 0)
        seen[base] = count + 1
        slugs[base if count == 0 else "%s-%d" % (base, count)] = line
    return heading_lines, slugs


def _spell_index_pages(lines, slugs):
    """The Spells Index's curated name -> page table.

    Authoritative, and nothing may second-guess it: the first occurrence of a
    spell name in the PDF matches this page only 57% of the time.
    """
    out = {}
    heading = next(
        (i for i, t in enumerate(lines)
         if t.strip().startswith("#")
         and t.strip().lstrip("#").strip().lower() == "spells index"),
        None)
    if heading is None:
        return out
    for text in lines[heading + 1:]:
        stripped = text.strip()
        if stripped.startswith("#"):
            break
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 4:
            continue
        match = _ANCHOR.search(cells[-1])
        if not match:
            continue
        name = _LINK.sub(r"\1", cells[0]).strip()
        if name:
            out[name] = int(match.group(1))
    return out


def build_index(lines):
    heading_lines, slugs = _headings(lines)
    anchor_pages = {}
    line_pages = {}
    for text in lines:
        for match in _ANCHOR.finditer(text):
            page, slug = int(match.group(1)), match.group(2)
            if slug not in slugs:
                continue   # an anchor with no heading is dropped, never guessed
            anchor_pages.setdefault(slug, page)
            line_pages.setdefault(slugs[slug], page)
    return PageIndex(
        anchor_pages=anchor_pages,
        line_pages=sorted(line_pages.items()),
        spell_index_pages=_spell_index_pages(lines, slugs),
        heading_lines=heading_lines,
        heading_slugs=slugs,
    )


def load_index():
    """Build a PageIndex from the pinned rulebook."""
    return build_index(sources.core_rulebook_text().split("\n"))
```

**`sources.core_rulebook_text()` is a guess at that accessor's name.** Step 1 had you read `sources.py`; use whatever it actually exposes, and say in your report what you used.

**Expect `monotonicity_violations()` to be non-empty on the first run** — the spec records 22. That test failing is Task 2's work, not a reason to weaken the assertion.

- [ ] **Step 5: Run the tests**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_pages -v`
Expected: all pass except `test_pages_never_go_backwards_as_lines_advance`, which fails with a non-empty violations list. Record the exact count and the first three violations in your report — Task 2 needs them.

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/pages.py scripts/spell_import/tests/test_pages.py
git commit -m "feat: parse the rulebook indexes into an anchor->page map

Guards return None rather than guessing: no page before the first
anchor, and none across a gap wider than MAX_ANCHOR_DISTANCE. The
monotonicity test fails as expected -- resolving those violations is
the next task, and they are the correctness gate on this map."
```

---

### Task 2: Resolve the monotonicity violations

**Files:**
- Modify: `scripts/spell_import/pages.py`
- Modify: `scripts/spell_import/tests/test_pages.py`

**Interfaces:**
- Consumes: everything Task 1 produced.
- Produces: no new public names. `monotonicity_violations()` returns `[]` on the pinned rulebook.

- [ ] **Step 1: Diagnose before fixing**

Print every violation with 3 lines of context around each heading:

```bash
uv run --no-project python -c "
from scripts.spell_import import pages
i = pages.load_index()
for a, pa, b, pb in i.monotonicity_violations():
    print(f'line {a} p{pa}  ->  line {b} p{pb}')
"
```

**Classify each one before changing any code.** The spec records that at least some are appendix headings carrying a body page number — the Reference Guide reproduces body content, so an anchor there legitimately points backwards. That is a real structural fact about the book, not a parsing bug.

Write the classification into your report: for each violation, which of these it is, with evidence.

- [ ] **Step 2: Write the failing test for the rule you found**

The fix depends on the classification, so the test does too. If the violations are appendix anchors (the expected case), the rule is that anchors inside the Reference Guide's line range do not become calibration points, because their pages describe other sections. Add:

```python
    def test_reference_guide_anchors_are_not_calibration_points(self):
        """The Reference Guide reproduces body content and cites the body's
        pages, so an anchor there points backwards. Using it as a calibration
        point would give every following line a page from a different chapter."""
        start, end = pages.REFERENCE_GUIDE_RANGE
        inside = [ln for ln, _ in self.index.line_pages if start <= ln <= end]
        self.assertEqual(inside, [])
```

If your classification finds a different cause, write the test that pins *that* rule instead, and say so in your report. Do not delete or weaken `test_pages_never_go_backwards_as_lines_advance`.

- [ ] **Step 3: Implement the exclusion**

Add `REFERENCE_GUIDE_RANGE = (start, end)` to `pages.py` as a module constant with a comment naming how the bounds were determined, and filter those lines out of `line_pages` in `build_index`. Bounds come from the rulebook's own headings — find them, do not guess them.

- [ ] **Step 4: Run the tests**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_pages -v`
Expected: all pass, including monotonicity. Report how many calibration points remain (Task 1 measured >1500; note the drop).

- [ ] **Step 5: Commit**

```bash
git add scripts/spell_import/pages.py scripts/spell_import/tests/test_pages.py
git commit -m "fix: exclude anchors that cite another section's pages

Resolves the monotonicity violations rather than smoothing them: an
anchor pointing backwards is the signal that it is being read out of
its section, and would give every following line a wrong page."
```

---

### Task 3: The HoH:MC ledger

Authoring data, not code. **This task's page lookups are mechanical — run them on the cheapest available model.**

**Files:**
- Create: `scripts/spell_import/hohmc_pages.json`
- Test: `scripts/spell_import/tests/test_pages.py` (add a class)

**Interfaces:**
- Consumes: nothing from Tasks 1-2.
- Produces: `hohmc_pages.json`, a JSON object mapping record id → `{"page": int, "matched": str}`.

- [ ] **Step 1: Extract the PDF text to the scratchpad**

The PDF is at `F:\OneDrive\RPGs\Ars Magica\Ars Magica 5e - Houses Of Hermes - Mystery Cults.pdf`. **Printed page = PDF index + 1**, confirmed on 125 of its 138 pages. The 13 exceptions are one textless cover (index 0) and ten chapter-opening pages whose first extracted line is the chapter number rather than the folio.

Write a throwaway script **into the scratchpad, not into the repo** — `scripts/` is stdlib-only and must not gain a `pypdf` dependency:

```bash
uv run --no-project --with pypdf python -c "
from pypdf import PdfReader
import json, pathlib
r = PdfReader(r'F:\OneDrive\RPGs\Ars Magica\Ars Magica 5e - Houses Of Hermes - Mystery Cults.pdf')
out = {i + 1: (p.extract_text() or '') for i, p in enumerate(r.pages)}
pathlib.Path('hohmc_pages_text.json').write_text(json.dumps(out), encoding='utf-8')
print('pages:', len(out))
"
```

Run it from your scratchpad directory. If the F: drive is unavailable, report BLOCKED — do not invent page numbers.

- [ ] **Step 2: List the records needing a page**

```bash
uv run --no-project python -c "
import json
recs = []
for f in ('spell_library', 'spell_templates', 'spell_exceptions'):
    for r in json.load(open(f'assets/data/{f}.json', encoding='utf-8')):
        if any(c['bookId'] == 'arm5-hohmc' for c in r.get('citations', [])):
            recs.append((r['id'], r['name']))
print(len(recs))
for i, n in recs: print(f'{i}\t{n}')
"
```

Expected: 15 records. Also check `base_effects.json`, `parameters.json` and `modifiers.json` for `arm5-hohmc` citations the same way and include those ids — the spec counts 27 HoH:MC citations in total, so there are more than these 15.

- [ ] **Step 3: Find each record's page**

For each record, search the extracted text for a distinctive phrase from its `description` (not its `name` — names fail on typography: *Ball of Abysmal Music* matches by description and not by name). Where the description fails, try the name. Where both fail, **read the pages around the ones its siblings landed on and find it by eye** — three records resolve by neither automated route, and they are the reason this is authored rather than matched.

Record the page **and the phrase you matched**, so a reviewer can check without reopening the PDF.

- [ ] **Step 4: Write the ledger**

Create `scripts/spell_import/hohmc_pages.json`, sorted by id, two-space indented to match the repo's other ledgers:

```json
{
  "lib-crme-scent-predator": {
    "page": 29,
    "matched": "the exact phrase you found on that page"
  }
}
```

Every record from Step 2 gets an entry. If you genuinely cannot place one, do **not** omit it silently — give it `"page": null` and a `"matched"` explaining what you tried, and flag it in your report.

- [ ] **Step 5: Write the coverage test**

Add to `scripts/spell_import/tests/test_pages.py`:

```python
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
```

- [ ] **Step 6: Run the tests and commit**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_pages -v`
Expected: all pass.

```bash
git add scripts/spell_import/hohmc_pages.json scripts/spell_import/tests/test_pages.py
git commit -m "feat: the HoH:MC page ledger

HoH:MC's markdown carries zero page anchors, so its 27 citations get a
committed ledger read from the PDF rather than a matcher in the repo.
Each entry carries the phrase it was matched on, so the claim is
checkable without reopening the PDF."
```

---

### Task 4: Strip the inference machinery, add the two lookups

**⚠️ This task removes code Tasks 1-2 added.** That is deliberate and user-directed: measurement showed the rulebook's own tables answer by lookup what the anchor map was inferring. 608/608 core base effects resolve by `(technique, form)` against the Spell Guidelines Index, where the locator reached ~80%. Do not preserve the inference "just in case" — the 74 hand-justified anchor exclusions it depends on are the risk being removed.

**Files:**
- Modify: `scripts/spell_import/pages.py`
- Modify: `scripts/spell_import/tests/test_pages.py`

**Interfaces:**
- Consumes: nothing new.
- Produces, and nothing else:
  - `slugify(heading: str) -> str` (kept — the table parsers use it)
  - `build_index(lines: list[str]) -> PageIndex`
  - `load_index() -> PageIndex`
  - `class PageIndex` with exactly three fields: `spell_index_pages: dict[str, int]`, `guideline_index_pages: dict[tuple[str, str], int]`, `topic_index_pages: dict[str, int]`

**Removed entirely:** `page_for_line`, `monotonicity_violations`, `anchor_pages`, `line_pages`, `heading_lines`, `heading_slugs`, `MAX_ANCHOR_DISTANCE`, `REFERENCE_GUIDE_RANGE`, `_MAX_CITED_SPREAD`, `_ISOLATED_UNRELIABLE_LINES`, `_SPELL_GUIDELINES_INDEX_RANGE`, and every test that covers them.

- [ ] **Step 1: Write the failing tests for the two new parsers**

Replace the obsolete test classes in `scripts/spell_import/tests/test_pages.py` with:

```python
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_pages -v`
Expected: FAIL — `AttributeError: 'PageIndex' object has no attribute 'guideline_index_pages'`.

- [ ] **Step 3: Rewrite `pages.py`**

Keep `slugify` and the `_ANCHOR` / `_LINK` regexes. Replace everything else with three table parsers.

The Spell Guidelines Index sits between `### Spell Guidelines Index` and the next heading; its columns are **Form, Technique, page** — in that order, which is not the order the key uses. The Traditional Index runs from `## Traditional Index` to end of file; strip `&nbsp;` from its entry text and lowercase it. The Spells Index parser already exists and keeps working — do not rewrite it.

`PageIndex` becomes a plain container of the three dicts with no methods.

- [ ] **Step 4: Run the tests**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_pages -v`
Expected: PASS. Report the test count, and the Python suite total against the current 458 — **it should go down**, because the removed machinery's tests go with it. Say by how much, and confirm zero failures.

- [ ] **Step 5: Commit**

```bash
git add scripts/spell_import/pages.py scripts/spell_import/tests/test_pages.py
git commit -m "refactor: replace page inference with three table lookups"
```

---

### Task 5: Populate the three generated assets

**Files:**
- Modify: `scripts/spell_import/emit.py` (the three `citations` sites near lines 262, 394, 854)
- Test: `scripts/spell_import/tests/test_emit.py`

**Interfaces:**
- Consumes: `pages.load_index()` giving `spell_index_pages`; `scripts/spell_import/hohmc_pages.json`.
- Produces: `spell_library.json`, `spell_templates.json`, `spell_exceptions.json` whose citations carry `page` where a table or the ledger names one.

- [ ] **Step 1: Read the three sites and their tests**

Read `emit.py` around lines 262, 394 and 854, and `scripts/spell_import/tests/test_emit.py` to see how emitted records are asserted. Follow the existing style; do not add a parallel fixture system.

- [ ] **Step 2: Write the failing test**

Add to `test_emit.py`, matching its fixtures:

```python
    def test_a_core_spell_citation_carries_its_spells_index_page(self):
        record = self._emit_core_spell(name="Pilum of Fire")
        citation = record["citations"][0]
        self.assertEqual(citation["bookId"], "arm5-core")
        self.assertIsInstance(citation["page"], int)

    def test_a_hohmc_citation_takes_its_page_from_the_ledger(self):
        record = self._emit_hohmc_spell(record_id="lib-crme-scent-predator")
        self.assertEqual(record["citations"][0]["page"], 29)

    def test_a_citation_with_no_known_page_omits_the_key_entirely(self):
        """Citation.toMap omits page when null, so an unknown page must be
        absent rather than present-and-null."""
        record = self._emit_core_spell(name="A Spell Not In The Index")
        self.assertNotIn("page", record["citations"][0])
```

Build `_emit_core_spell` / `_emit_hohmc_spell` as thin helpers over whatever `test_emit.py` already uses to construct a record. **Read that file first.**

- [ ] **Step 3: Run it to verify it fails**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_emit -v`
Expected: FAIL — `KeyError: 'page'`.

- [ ] **Step 4: Implement**

Add one helper in `emit.py` used by all three sites, so the rule lives once:

```python
def _citation(book_id, *, spell_name=None, record_id=None):
    """One citation, with a page when a table or the ledger names one.

    Core spells take the Spells Index's page; HoH:MC records take the
    committed ledger's. A page is omitted, never null: `Citation.toMap` writes
    the key only when it has a value, and an absent key round-trips through
    `Citation.fromMap`'s `map['page'] as int?` unchanged.
    """
```

Load the index and the ledger **once per run**, not per record.

- [ ] **Step 5: Regenerate and inspect**

```bash
uv run --no-project python -m scripts.spell_import.extract_spells --write
git diff --stat assets/data/
```

Expected: the three emitted assets change; nothing else. **The extractor's own counts must be unchanged** — 336 imported, 31 templates, 8 exceptions, 0 blocked, 3 skipped, 0 unresolved. Spot-check three spells against the Spells Index by hand and put them in your report.

- [ ] **Step 6: Run both suites and commit**

```bash
uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .
flutter test
```

Report the Python total; Dart should be unchanged at 860.

```bash
git add scripts/spell_import/emit.py scripts/spell_import/tests/test_emit.py assets/data/
git commit -m "feat: emit page numbers on spell, template and exception citations"
```

---

### Task 6: The one-shot catalog enrichment

`base_effects.json`, `parameters.json` and `modifiers.json` are hand-maintained and have no generator, so their pages are applied once and committed — following `scripts/flag_ritual_effects.py`, which did the same for a different field.

**Files:**
- Create: `scripts/enrich_catalog_pages.py`
- Modify: `assets/data/base_effects.json`, `assets/data/parameters.json`
- Test: `scripts/spell_import/tests/test_pages.py`

**Interfaces:**
- Consumes: `pages.load_index()` giving `guideline_index_pages` and `topic_index_pages`.
- Produces: nothing later tasks consume.

- [ ] **Step 1: Read the precedent**

Read `scripts/flag_ritual_effects.py` in full. Yours gets the same header — one-shot, already applied, do not re-run without checking. **Note its warning about newlines:** it rewrites every line, so preserve each file's existing convention or the diff becomes unreadable.

- [ ] **Step 2: Apply the two lookups**

- `base_effects.json`: for each entry citing `arm5-core`, look up `(technique, form)` in `guideline_index_pages` and write `page` into that citation. Expect **608 of 608**.
- `parameters.json`: for each entry citing `arm5-core`, look up `f"{name} ({category})".lower()` in `topic_index_pages`. Expect **20 of 31** — the 11 misses (`Sight`, `Arcane Connection`, `Boundary`, and the sensory Targets) get no page, deliberately.
- `modifiers.json`: **not enriched.** Modifiers are not individually indexed — `Complexity` and `Material` return nothing — so all 35 keep no page. Do not invent a mechanism for them.

**Never widen a key to raise coverage.** Matching bare `Voice` where the table says `Voice (Range)` is the guessing this design removed.

- [ ] **Step 3: Inspect the diff closely**

```bash
git diff --stat assets/data/
git diff assets/data/parameters.json | head -40
```

Every changed line must be a `page` addition inside a `citations` entry. Reordered keys, changed indentation or altered newlines mean the script is wrong — revert and fix it rather than committing a reformatting.

- [ ] **Step 4: Add the coverage floor test**

Add to `scripts/spell_import/tests/test_pages.py`. Replace `<N>` with the count your run actually produced, and report what it was:

```python
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
        self.assertGreaterEqual(count, <N>)
```

- [ ] **Step 5: Run both suites and commit**

```bash
uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .
flutter test
```

Report both totals.

```bash
git add scripts/enrich_catalog_pages.py assets/data/ scripts/spell_import/tests/test_pages.py
git commit -m "feat: page numbers for the hand-maintained catalogs"
```

---

### Task 7: `books.json`, and the three retractions

**Files:**
- Modify: `assets/data/books.json`, `lib/models/citation.dart`, `.superpowers/DECISIONS.md`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: nothing. Produces: nothing. This is the last task.

- [ ] **Step 1: Write the failing Dart test**

`books.json` declares `arm5-core` as `"Ars Magica Fifth Edition"` / `"ArM5"` / `"5e"`, but the pages now shipping are **Definitive Edition**, which paginates differently — the Reference Guide prints both (*"Fifth Edition p7, Definitive Edition p8"*), so a DE page under a 5e label sends the reader to the wrong page.

Add to `test/data/datasources/asset_data_loader_test.dart`, following its style:

```dart
    test('arm5-core declares the Definitive Edition, which its pages belong to',
        () async {
      final books = await AssetDataLoader().loadBooks();
      final core = books.firstWhere((b) => b.id == 'arm5-core');

      expect(core.title, contains('Definitive Edition'));
      expect(core.edition, isNot('5e'),
          reason: 'a Definitive Edition page under a 5e label sends the '
              'reader to the wrong page — see todo item 78.5');
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — title is "Ars Magica Fifth Edition".

- [ ] **Step 3: Update `books.json`**

Change `arm5-core`'s `title`, `abbreviation` and `edition` to name the Definitive Edition. **Do not change the `id`** — it appears in 1034 citations across every asset. Leave `arm5-hohmc` alone; it is a 5e supplement and correctly labelled.

- [ ] **Step 4: Retract the three "cannot" claims**

Each retraction says what was actually wrong: *the claim was measured against the book's body and never tested against its indexes.*

1. `lib/models/citation.dart` — the doc comment says pages "cannot be recovered from the import source" and an earlier promise "could not be kept". Replace with what is now true: pages come from the book's index tables for core content and from a ledger for HoH:MC, and a citation naming only its book is **still** valid and permanent. Keep that last sentence — 46 core records rely on it.
2. `.superpowers/DECISIONS.md`, "Known limits — do not re-promise" — retract the page entry, citing item 78.
3. Item 56's warning in `.superpowers/themes/app.md` is already struck through and marked RETRACTED 2026-08-20; update it to cite this landing.

- [ ] **Step 5: Run everything**

```bash
flutter pub get
flutter analyze
flutter test
uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .
uv run --no-project python -m scripts.todo.check
```

Expected: analyze exits 0; Dart green (report the total against 860); Python green; `0 problem(s)`.

- [ ] **Step 6: Commit**

```bash
git add assets/data/books.json lib/models/citation.dart .superpowers/
git commit -m "feat: label arm5-core as the Definitive Edition, retract three cannot-claims"
```

---

## After the plan

Not part of any task:

- **No PDF cross-check of core pages.** Proposed and withdrawn: raw PDF text agrees with the Spells Index only 57% of the time, so it would validate the better source against the worse one.
- **Close item 78** with the `closing-an-item` skill: 78.1, 78.4, 78.5, 78.6 done; **78.3 closes as obsolete** — it validated an anchor map that no longer exists; **78.2 stays open** and now means "the 46 core records no table indexes", which is a different question from the one it was filed for.
- **Update `.superpowers/STATUS.md`** with both suite counts.
- **Update item 87.3** — the source marker can now say book *and* page, which is the decision that item deferred.
- **Tell item 56 it is unblocked**, and note that HoH:MC hints name a book without a page, permanently.
