# Published Spell Import Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a re-runnable extractor plus a five-assertion test harness that imports the 286 currently-expressible Definitive Edition spells into `assets/data/spell_library.json` and proves they are right — including the base-effect choices that a level test cannot see.

**Architecture:** A Python package under `scripts/spell_import/` reads the rulebook markdown and the three JSON catalogs, and writes `assets/data/spell_library.json`. It resolves base effects only where exactly one candidate exists; everything ambiguous is answered by a hand-edited ledger the script reads and never writes. Correctness is enforced from the Dart side by asset tests that recompute every spell's level and Ritual status, and from the Python side by a regeneration check.

**Tech Stack:** Python 3 (stdlib only — no new dependencies), Dart/Flutter for the asset tests, existing `AssetDataLoader` / `SpellEngine` / `SpellLevelCalculator`.

**Spec:** `docs/superpowers/specs/2026-07-28-published-spell-import-design.md`

## Global Constraints

- **Python: stdlib only.** No pip installs. Tests use `unittest`, not pytest.
- **Directory is `scripts/spell_import/`, not `scripts/import/`.** The spec says `scripts/import/`; `import` is a Python keyword, so that directory can never be a package and every module inside it would be import-fragile. This is the one deliberate deviation from the spec. Everything else follows it.
- **Source precedence: `reviewed/` → `wip/` → `raw-md/`,** first hit wins, never `raw-md` for a book the others have. Skip any file whose name contains `DO NOT USE`.
- **Rulebook root:** `C:\Users\idf53\Development\personal\arsm\Ars-Magica-Open-License` — a sibling of this repo, resolved relative to the repo root, never hardcoded as an absolute path in committed code.
- **The script never writes `resolutions.json`.** It may write `resolutions.proposed.json`, which is gitignored.
- **Every spell id is `lib-<techform>-<name-slug>`** (e.g. `lib-crim-talking-head`), matching the 36 existing entries.
- **`Citation.page` stays null.** The reviewed markdown has no page markers.
- **Flutter is not on the default PATH.** Prefix every Flutter command with `export PATH="$HOME/SDKs/flutter/flutter/bin:$PATH"` (Bash tool) or use the full path.
- **Do not renumber todo items.** Item 27 is this work.
- **Unknown design-line tokens are a hard error, never a silent skip.** That is the mechanism by which blocked spells are detected rather than mis-imported.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/spell_import/sources.py` | Resolve a book title to a path by precedence; read it into lines |
| `scripts/spell_import/statline.py` | Detect and parse `R: … D: … T: …` lines, including damaged ones |
| `scripts/spell_import/blocks.py` | Assemble spell blocks: name, Technique/Form, level, stat line, prose, design line |
| `scripts/spell_import/designline.py` | Tokenize `(Base 15, +1 Touch, +2 Group)` into a base level and magnitude tokens |
| `scripts/spell_import/catalog.py` | Load the three JSON catalogs; narrow base-effect candidates; slug ids |
| `scripts/spell_import/ledger.py` | Load and validate `resolutions.json` |
| `scripts/spell_import/emit.py` | Build the Spell JSON dict for one resolved spell |
| `scripts/spell_import/extract_spells.py` | CLI entry point wiring the above together |
| `scripts/spell_import/resolutions.json` | **Hand-edited.** The base-effect decision ledger |
| `scripts/spell_import/tests/test_*.py` | Python unit tests, `unittest` |
| `test/data/published_spell_import_test.dart` | Dart asset assertions 1–4 |
| `assets/data/spell_library.json` | Generated output, committed |

**Where the five assertions live.** Assertions 1–4 (level equality, Ritual agreement, resolution completeness, reference integrity) are Dart asset tests in `flutter test`. Assertion 5 (regeneration is clean) needs to run the Python extractor, so it is a Python `unittest`. Both suites must run in CI; neither alone is sufficient. Task 8 and Task 7 respectively.

---

## Task 1: Source resolution

**Files:**
- Create: `scripts/spell_import/__init__.py` (empty)
- Create: `scripts/spell_import/sources.py`
- Create: `scripts/spell_import/tests/__init__.py` (empty)
- Test: `scripts/spell_import/tests/test_sources.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `RULEBOOK_ROOT: pathlib.Path`
  - `resolve_book(title: str, root: Path = RULEBOOK_ROOT) -> Path` — raises `FileNotFoundError` if absent
  - `read_lines(path: Path) -> list[str]` — returns lines with the trailing newline stripped, blockquote markers left intact
  - `DE_TITLE: str = "Ars Magica - Definitive Edition (Core Rules)"`

- [ ] **Step 1: Write the failing test**

Create `scripts/spell_import/tests/test_sources.py`:

```python
import unittest

from scripts.spell_import import sources


class ResolveBookTest(unittest.TestCase):
    def test_prefers_reviewed_over_raw(self):
        path = sources.resolve_book(sources.DE_TITLE)
        self.assertEqual(path.parent.name, "reviewed")

    def test_falls_back_to_wip_when_not_reviewed(self):
        path = sources.resolve_book("Ars Magica 5e - Magi of Hermes")
        self.assertEqual(path.parent.name, "wip")

    def test_uses_raw_only_as_last_resort(self):
        path = sources.resolve_book("Ars Magica 5e - Mundane Beasts")
        self.assertIn(path.parent.name, ("wip", "raw-md"))

    def test_unknown_book_raises(self):
        with self.assertRaises(FileNotFoundError):
            sources.resolve_book("Ars Magica 5e - No Such Book")

    def test_do_not_use_files_are_never_returned(self):
        for path in sources.all_books().values():
            self.assertNotIn("DO NOT USE", path.name)

    def test_read_lines_strips_newlines_but_keeps_blockquotes(self):
        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        self.assertGreater(len(lines), 10000)
        self.assertFalse(any(line.endswith("\n") for line in lines))
        self.assertTrue(any(line.startswith(">") for line in lines))
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
python -m unittest scripts.spell_import.tests.test_sources -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import'`

- [ ] **Step 3: Write the implementation**

Create empty `scripts/__init__.py`, `scripts/spell_import/__init__.py` and `scripts/spell_import/tests/__init__.py`, then create `scripts/spell_import/sources.py`:

```python
"""Resolve an Ars Magica rulebook to the best available markdown copy.

The rulebook repo holds the same book in three folders of descending quality.
`reviewed` has been proof-read; `raw-md` is unreviewed OCR with word-internal
case errors ("tHe Bitten toad") and split ligatures ("infl icted"). Parsing
raw OCR produces wrong data that looks plausible, so precedence is not a
preference — it is a correctness requirement.
"""
import pathlib
import re

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
RULEBOOK_ROOT = REPO_ROOT.parent / "Ars-Magica-Open-License"

# Descending quality. First hit wins.
FOLDERS = ("reviewed", "wip", "raw-md")

DE_TITLE = "Ars Magica - Definitive Edition (Core Rules)"

# raw-md filenames carry OCR-run suffixes and digital-edition tags that the
# reviewed copies do not, so books must be matched on title, not filename.
_SUFFIX = re.compile(r"\s*-\s*(ForceOCRfixed|RedoOCR)$")
_EDITION_TAG = re.compile(r"\s*\[digital edition\].*$")


def title_of(path: pathlib.Path) -> str:
    stem = path.name[: -len(".md")] if path.name.endswith(".md") else path.name
    stem = _EDITION_TAG.sub("", stem)
    return _SUFFIX.sub("", stem).strip()


def all_books(root: pathlib.Path = RULEBOOK_ROOT) -> dict[str, pathlib.Path]:
    """Every book title mapped to its best available copy."""
    resolved: dict[str, pathlib.Path] = {}
    for folder in FOLDERS:
        directory = root / folder
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.md")):
            if "DO NOT USE" in path.name:
                continue
            resolved.setdefault(title_of(path), path)
    return resolved


def resolve_book(title: str, root: pathlib.Path = RULEBOOK_ROOT) -> pathlib.Path:
    books = all_books(root)
    if title not in books:
        raise FileNotFoundError(
            f"no markdown copy of {title!r} under {root} "
            f"(looked in {', '.join(FOLDERS)})"
        )
    return books[title]


def read_lines(path: pathlib.Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="strict").split("\n")
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
python -m unittest scripts.spell_import.tests.test_sources -v
```

Expected: PASS, 6 tests.

If `test_falls_back_to_wip_when_not_reviewed` fails, run `python -c "from scripts.spell_import import sources; print(sources.resolve_book('Ars Magica 5e - Magi of Hermes'))"` and correct the expected folder — the point of the test is precedence, not that one specific book.

- [ ] **Step 5: Commit**

```bash
git add scripts/__init__.py scripts/spell_import/ && git commit -m "feat(import): resolve rulebooks by reviewed > wip > raw-md precedence"
```

---

## Task 2: Stat-line detection and parsing

**Files:**
- Create: `scripts/spell_import/statline.py`
- Test: `scripts/spell_import/tests/test_statline.py`

**Interfaces:**
- Consumes: `sources.read_lines`
- Produces:
  - `strip_markup(line: str) -> str` — removes leading `>`/whitespace and all `**`
  - `is_statline(line: str) -> bool` — the conjunction: `R:` then `D:` then `T:`
  - `is_damaged_statline(line: str) -> bool` — two of three fields present, but not `is_statline`
  - `StatLine` dataclass: `.range_name: str`, `.duration_name: str`, `.target_name: str`, `.is_ritual: bool`, `.requisite_arts: list[str]`, `.trailing: str`
  - `parse_statline(line: str) -> StatLine` — raises `ValueError` on a damaged line

- [ ] **Step 1: Write the failing test**

Create `scripts/spell_import/tests/test_statline.py`:

```python
import unittest

from scripts.spell_import import statline


class DetectTest(unittest.TestCase):
    def test_plain_line(self):
        self.assertTrue(statline.is_statline("R: Touch, D: Mom, T: Ind"))

    def test_bold_markup_between_fields(self):
        # Against the Dark writes every stat line this way. A pattern anchored
        # at the start of the line rejects the whole book.
        self.assertTrue(statline.is_statline("**R:** Voice, **D:** Diameter, **T:** Part"))

    def test_blockquote_sidebar(self):
        self.assertTrue(statline.is_statline("> R: Per, D: Diam, T: Flavor"))

    def test_period_separators(self):
        self.assertTrue(statline.is_statline("R: Personal. D: Conc. T: Touch"))

    def test_description_run_onto_the_line(self):
        self.assertTrue(
            statline.is_statline("R: Touch, D: Mom, T: Boundary, Ritual Causes a roll")
        )

    def test_prose_is_not_a_statline(self):
        self.assertFalse(statline.is_statline("The caster must touch the target."))

    def test_damaged_lines_are_detected_not_parsed(self):
        for line in [
            "R: Arc, D: Conc, R: Ind",        # T mistyped as R
            "R: Voice, D Mom, T: Group",      # colon dropped after D
            "R: Touch, T: Ring, D: Circle",   # D and T transposed
        ]:
            self.assertFalse(statline.is_statline(line), line)
            self.assertTrue(statline.is_damaged_statline(line), line)


class ParseTest(unittest.TestCase):
    def test_parses_the_three_fields(self):
        parsed = statline.parse_statline("R: Touch, D: Sun, T: Ind")
        self.assertEqual(parsed.range_name, "Touch")
        self.assertEqual(parsed.duration_name, "Sun")
        self.assertEqual(parsed.target_name, "Ind")
        self.assertFalse(parsed.is_ritual)
        self.assertEqual(parsed.requisite_arts, [])

    def test_detects_the_ritual_flag(self):
        parsed = statline.parse_statline("R: Touch, D: Mom, T: Ind, Ritual")
        self.assertTrue(parsed.is_ritual)
        self.assertEqual(parsed.target_name, "Ind")

    def test_reads_requisites(self):
        parsed = statline.parse_statline("R: Touch, D: Mom, T: Part, Ritual Req: Vim, Corpus")
        self.assertTrue(parsed.is_ritual)
        self.assertEqual(parsed.requisite_arts, ["Vim", "Corpus"])

    def test_strips_trailing_br_tags(self):
        parsed = statline.parse_statline("R: Touch, D: Moon, T: Ind<br>")
        self.assertEqual(parsed.target_name, "Ind")

    def test_damaged_line_raises(self):
        with self.assertRaises(ValueError):
            statline.parse_statline("R: Touch, T: Ring, D: Circle")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
python -m unittest scripts.spell_import.tests.test_statline -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.statline'`

- [ ] **Step 3: Write the implementation**

Create `scripts/spell_import/statline.py`:

```python
"""Find and read a spell's stat line: `R: Touch, D: Sun, T: Ind, Ritual`.

The stat line is the anchor for the whole import. Every spell has one and
almost nothing else does, which makes it a far more reliable locator than the
heading structure — headings vary between books and are sometimes simply wrong
(the Definitive Edition files four Creo Terram spells under a Guidelines
heading with no Spells heading of its own).

The predicate is "contains R:, then D:, then T:", NOT "starts with R:". The
two are indistinguishable on the Definitive Edition, which is why the weaker
rule looks sound; across the supplements the conjunction finds 2378 stat lines
against 1300, because books such as Against the Dark write
`**R:** Voice, **D:** Diameter, **T:** Part`.
"""
import dataclasses
import re

_LEADING = re.compile(r"^[>\s]*")
_BOLD = re.compile(r"\*\*")
_BR = re.compile(r"<br\s*/?>", re.IGNORECASE)

_CONJUNCTION = re.compile(r"\bR:\s*\S.*?\bD:\s*\S.*?\bT:\s*\S")
# Tolerant: a field is present if its letter is followed by an optional colon
# and then a word. Used only to raise damaged lines for review.
_FIELD = re.compile(r"\b([RDT]):?\s+\*{0,2}[A-Za-z]")

_FIELDS = re.compile(
    r"\bR:\s*(?P<range>.+?)\s*[,.]\s*"
    r"\bD:\s*(?P<duration>.+?)\s*[,.]\s*"
    r"\bT:\s*(?P<target>.+)$"
)
_REQ = re.compile(r"\bReq(?:uisites?)?:\s*(?P<arts>[A-Za-z, ]+)")
_RITUAL = re.compile(r"\bRitual\b")

ARTS = {
    "Creo", "Intellego", "Muto", "Perdo", "Rego",
    "Animal", "Aquam", "Auram", "Corpus", "Herbam",
    "Ignem", "Imaginem", "Mentem", "Terram", "Vim",
}


def strip_markup(line: str) -> str:
    return _BOLD.sub("", _BR.sub("", _LEADING.sub("", line))).strip()


def is_statline(line: str) -> bool:
    return bool(_CONJUNCTION.search(strip_markup(line)))


def is_damaged_statline(line: str) -> bool:
    """Two of the three fields present, but not a well-formed stat line.

    These are not skipped and not parsed — they are reported. A transposed
    `R: Touch, T: Ring, D: Circle` would otherwise import with Duration and
    Target swapped, and both values are legal, so nothing downstream would
    notice.
    """
    cleaned = strip_markup(line)
    if _CONJUNCTION.search(cleaned):
        return False
    return len({m.group(1) for m in _FIELD.finditer(cleaned)}) >= 2


@dataclasses.dataclass(frozen=True)
class StatLine:
    range_name: str
    duration_name: str
    target_name: str
    is_ritual: bool
    requisite_arts: list[str]
    trailing: str


def parse_statline(line: str) -> StatLine:
    cleaned = strip_markup(line)
    match = _FIELDS.search(cleaned)
    if not match:
        raise ValueError(f"not a well-formed stat line: {line!r}")

    tail = match.group("target")
    is_ritual = bool(_RITUAL.search(tail))

    requisites: list[str] = []
    req_match = _REQ.search(tail)
    if req_match:
        for art in req_match.group("arts").split(","):
            art = art.strip()
            if art in ARTS:
                requisites.append(art)
        tail = tail[: req_match.start()]

    # The target is the first token run before Ritual/Req/description prose.
    target = _RITUAL.split(tail)[0].strip().rstrip(",.").strip()
    # Some books run the description straight on: keep only the leading words
    # that look like a target name (capitalised words, "or", parenthesis-free).
    target = re.match(r"[A-Za-z]+(?:\s+[A-Za-z]+){0,2}", target)
    target = target.group(0).strip() if target else ""

    return StatLine(
        range_name=match.group("range").strip().rstrip(",."),
        duration_name=match.group("duration").strip().rstrip(",."),
        target_name=target,
        is_ritual=is_ritual,
        requisite_arts=requisites,
        trailing=cleaned,
    )
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
python -m unittest scripts.spell_import.tests.test_statline -v
```

Expected: PASS, 12 tests.

- [ ] **Step 5: Sanity-check the predicate against the real book**

```bash
python -c "from scripts.spell_import import sources, statline; L=sources.read_lines(sources.resolve_book(sources.DE_TITLE)); print('anchors', sum(map(statline.is_statline, L)), 'damaged', sum(map(statline.is_damaged_statline, L)))"
```

Expected: `anchors 385 damaged 0`. If the anchor count differs from 385, stop and investigate before continuing — every later task depends on it.

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/ && git commit -m "feat(import): detect and parse spell stat lines"
```

---

## Task 3: Spell block assembly

**Files:**
- Create: `scripts/spell_import/blocks.py`
- Test: `scripts/spell_import/tests/test_blocks.py`

**Interfaces:**
- Consumes: `sources.read_lines`, `statline.is_statline`, `statline.parse_statline`, `statline.is_damaged_statline`, `statline.strip_markup`
- Produces:
  - `SpellBlock` dataclass: `.name: str`, `.technique: str`, `.form: str`, `.printed_level: int | None` (None = General), `.stat: StatLine`, `.prose: str`, `.design_line: str | None`, `.line_no: int`
  - `parse_de(lines: list[str]) -> tuple[list[SpellBlock], list[str]]` — returns blocks and a list of human-readable parse problems

- [ ] **Step 1: Write the failing test**

Create `scripts/spell_import/tests/test_blocks.py`:

```python
import unittest

from scripts.spell_import import blocks, sources


class ParseDefinitiveEditionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        cls.blocks, cls.problems = blocks.parse_de(lines)

    def test_finds_exactly_360_spells(self):
        self.assertEqual(len(self.blocks), 360)

    def test_reports_no_parse_problems(self):
        self.assertEqual(self.problems, [])

    def test_every_spell_has_a_technique_and_form(self):
        for block in self.blocks:
            self.assertTrue(block.technique, block.name)
            self.assertTrue(block.form, block.name)

    def test_creo_terram_spells_are_not_filed_under_rego_mentem(self):
        # The DE has "### Creo Terram Guidelines" and no "### Creo Terram
        # Spells" heading. A parser keying off the "Spells" suffix files these
        # four under the previous section, Rego Mentem.
        tower = next(b for b in self.blocks if b.name == "Conjuring the Mystic Tower")
        self.assertEqual((tower.technique, tower.form), ("Creo", "Terram"))
        for name in ["Seal the Earth", "Touch of Midas", "Wall of Protecting Stone"]:
            block = next(b for b in self.blocks if b.name == name)
            self.assertEqual((block.technique, block.form), ("Creo", "Terram"), name)

    def test_general_level_spells_have_no_printed_level(self):
        general = [b for b in self.blocks if b.printed_level is None]
        self.assertEqual(len(general), 33)

    def test_a_known_spell_parses_completely(self):
        block = next(b for b in self.blocks if b.name == "Soothe Pains of the Beast")
        self.assertEqual((block.technique, block.form), ("Creo", "Animal"))
        self.assertEqual(block.printed_level, 20)
        self.assertTrue(block.stat.is_ritual)
        self.assertEqual(block.stat.range_name, "Touch")
        self.assertEqual(block.design_line, "(Base level 15, +1 Touch)")

    def test_three_spells_have_no_design_line(self):
        missing = sorted(b.name for b in self.blocks
                         if b.design_line is None and b.printed_level is not None)
        self.assertEqual(missing, [
            "Enchantment of the Scrying Pool",
            "Hermes' Portal",
            "Whispering Winds",
        ])

    def test_creature_powers_are_excluded(self):
        names = {b.name for b in self.blocks}
        self.assertNotIn("Crush", names)
        self.assertNotIn("Healing Gaze", names)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
python -m unittest scripts.spell_import.tests.test_blocks -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.blocks'`

- [ ] **Step 3: Write the implementation**

Create `scripts/spell_import/blocks.py`:

```python
"""Assemble Definitive Edition spell blocks around their stat lines.

Structure in the reviewed DE:

    ### Creo Animal Spells          <- Technique and Form
    #### LEVEL 20                   <- printed level (or "#### GENERAL")
    ##### Soothe Pains of the Beast <- name
    R: Touch, D: Mom, T: Ind, Ritual
    <prose...>
    (Base level 15, +1 Touch)       <- design line

The stat line is the anchor and the `##### ` heading directly above it is the
discriminator. 385 lines in the book match the stat-line predicate; exactly
360 have a name heading above them, and every name heading in the spell
chapter has a stat line beneath it. The other 25 are creature and elemental
powers, which carry a `*Crush*, 0 points, Init equal to (Qik-2), Terram` line
instead of a heading.
"""
import dataclasses
import re

from . import statline

# Match "### Creo Terram Guidelines" as readily as "### Creo Animal Spells".
# Keying off the "Spells" suffix silently misfiles four Creo Terram spells.
_SECTION = re.compile(
    r"^###\s+(?P<technique>Creo|Intellego|Muto|Perdo|Rego)\s+"
    r"(?P<form>Animal|Aquam|Auram|Corpus|Herbam|Ignem|Imaginem|Mentem|Terram|Vim)\b"
)
_LEVEL = re.compile(r"^####\s+(?:\*{0,2})(?:LEVEL\s+(?P<level>\d+)|(?P<general>GENERAL))")
_NAME = re.compile(r"^#####\s+(?P<name>.+?)\s*$")
_DESIGN = re.compile(r"^\(\s*Base\b")


@dataclasses.dataclass
class SpellBlock:
    name: str
    technique: str
    form: str
    printed_level: int | None
    stat: statline.StatLine
    prose: str
    design_line: str | None
    line_no: int


def parse_de(lines: list[str]) -> tuple[list[SpellBlock], list[str]]:
    problems: list[str] = []
    found: list[SpellBlock] = []

    technique = form = None
    level: int | None = None
    is_general = False
    name: str | None = None
    name_line = -1

    for index, raw in enumerate(lines):
        cleaned = statline.strip_markup(raw)

        section = _SECTION.match(cleaned)
        if section:
            technique = section.group("technique")
            form = section.group("form")
            continue

        level_heading = _LEVEL.match(cleaned)
        if level_heading:
            is_general = level_heading.group("general") is not None
            level = None if is_general else int(level_heading.group("level"))
            continue

        name_heading = _NAME.match(cleaned)
        if name_heading:
            name = name_heading.group("name")
            name_line = index
            continue

        if statline.is_damaged_statline(raw):
            problems.append(f"line {index + 1}: damaged stat line {raw.strip()!r}")
            continue

        if not statline.is_statline(raw):
            continue

        # A stat line whose preceding non-blank line is not a name heading is a
        # creature or faerie power, not a spell.
        if name is None or index != name_line + 1:
            continue

        if technique is None or form is None:
            problems.append(f"line {index + 1}: {name!r} has no Technique/Form section")
            name = None
            continue

        prose_lines: list[str] = []
        design: str | None = None
        cursor = index + 1
        while cursor < len(lines):
            candidate = statline.strip_markup(lines[cursor])
            if _NAME.match(candidate) or _SECTION.match(candidate) or _LEVEL.match(candidate):
                break
            if _DESIGN.match(candidate):
                design = candidate
                break
            if candidate:
                prose_lines.append(candidate)
            cursor += 1

        found.append(SpellBlock(
            name=name,
            technique=technique,
            form=form,
            printed_level=level,
            stat=statline.parse_statline(raw),
            prose=" ".join(prose_lines),
            design_line=design,
            line_no=index + 1,
        ))
        name = None

    return found, problems
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
python -m unittest scripts.spell_import.tests.test_blocks -v
```

Expected: PASS, 8 tests.

If `test_finds_exactly_360_spells` reports fewer, print the shortfall with:

```bash
python -c "from scripts.spell_import import sources, statline, blocks; L=sources.read_lines(sources.resolve_book(sources.DE_TITLE)); b,p=blocks.parse_de(L); print(len(b), p[:5]); import re; hits=[i for i,l in enumerate(L) if statline.is_statline(l)]; named=[i for i in hits if L[i-1].strip().startswith('##### ')]; print('named anchors', len(named)); got={x.line_no-1 for x in b}; print('missed', [(i+1, L[i-1][:60]) for i in named if i not in got][:10])"
```

- [ ] **Step 5: Commit**

```bash
git add scripts/spell_import/ && git commit -m "feat(import): assemble DE spell blocks anchored on the stat line"
```

---

## Task 4: Design-line tokenizer

**Files:**
- Create: `scripts/spell_import/designline.py`
- Test: `scripts/spell_import/tests/test_designline.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `Design` dataclass: `.base_level: int | None` (None = "Base effect", i.e. General), `.tokens: list[Token]`
  - `Token` dataclass: `.magnitude: int`, `.label: str`, `.kind: str` (one of `"parameter"`, `"requisite"`, `"modifier"`, `"unknown"`)
  - `parse_design(text: str) -> Design` — raises `UnknownToken` for anything not in the vocabulary

- [ ] **Step 1: Write the failing test**

Create `scripts/spell_import/tests/test_designline.py`:

```python
import unittest

from scripts.spell_import import designline


class ParseDesignTest(unittest.TestCase):
    def test_plain_base_and_parameters(self):
        design = designline.parse_design("(Base 4, +1 Touch, +3 Moon)")
        self.assertEqual(design.base_level, 4)
        self.assertEqual([(t.magnitude, t.label) for t in design.tokens],
                         [(1, "Touch"), (3, "Moon")])

    def test_base_level_spelling(self):
        self.assertEqual(designline.parse_design("(Base level 15, +1 Touch)").base_level, 15)

    def test_base_colon_spelling(self):
        self.assertEqual(designline.parse_design("(Base: 15, +1 Touch, +2 Group)").base_level, 15)

    def test_general_spells_have_no_base_level(self):
        design = designline.parse_design("(Base effect, +1 Touch, +4 Boundary)")
        self.assertIsNone(design.base_level)

    def test_period_separator(self):
        design = designline.parse_design("(Base 5. +2 Sun)")
        self.assertEqual(design.base_level, 5)
        self.assertEqual(len(design.tokens), 1)

    def test_parenthesised_comment_is_ignored(self):
        design = designline.parse_design("(Base 4 (a very unnatural liquid), +1 Touch)")
        self.assertEqual(design.base_level, 4)
        self.assertEqual(len(design.tokens), 1)

    def test_requisite_tokens(self):
        design = designline.parse_design("(Base 5, +1 Touch, +1 Creo requisite)")
        requisite = design.tokens[-1]
        self.assertEqual(requisite.kind, "requisite")
        self.assertEqual(requisite.magnitude, 1)
        self.assertEqual(requisite.label, "Creo")

    def test_free_requisite_costs_nothing(self):
        design = designline.parse_design("(Base 4, +1 Touch, +3 Moon, requisite free)")
        self.assertEqual(design.tokens[-1].kind, "requisite")
        self.assertEqual(design.tokens[-1].magnitude, 0)

    def test_size_token_is_a_modifier(self):
        design = designline.parse_design("(Base 3, +2 Voice, +2 Sun, +1 size)")
        self.assertEqual(design.tokens[-1].kind, "modifier")
        self.assertEqual(design.tokens[-1].label, "size")

    def test_unknown_token_raises(self):
        # "+1 fancy effect" is an ad-hoc per-spell magnitude (todo item 24).
        # It must fail loudly so the spell is reported blocked, not imported
        # with a silently dropped magnitude.
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 10, +1 Touch, +1 fancy effect)")


class VocabularyCoverageTest(unittest.TestCase):
    def test_every_de_design_line_either_parses_or_names_its_blocker(self):
        from scripts.spell_import import blocks, sources
        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        parsed, _ = blocks.parse_de(lines)

        unknown = []
        for block in parsed:
            if block.design_line is None:
                continue
            try:
                designline.parse_design(block.design_line)
            except designline.UnknownToken as error:
                unknown.append((block.name, str(error)))

        # Blocked spells are expected to fail here — that is the mechanism.
        # What must not happen is a silent success on a token we do not model.
        self.assertLess(len(unknown), 90,
                        msg=f"far more unparsed than the audit's 74 blocked: {unknown[:10]}")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
python -m unittest scripts.spell_import.tests.test_designline -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.designline'`

- [ ] **Step 3: Write the implementation**

Create `scripts/spell_import/designline.py`:

```python
"""Tokenize a spell's design line: `(Base 15, +1 Touch, +2 Group)`.

The Definitive Edition uses 104 distinct token shapes across 360 spells. Only
the ones this module models can be imported; everything else raises
UnknownToken, which is how a blocked spell announces itself. A tokenizer that
skipped what it did not recognise would import the spell with a missing
magnitude and a level that no longer matches — and assertion 1 would catch it
only by luck, since two dropped magnitudes can cancel.
"""
import dataclasses
import re

_PARENTHETICAL = re.compile(r"\([^)]*\)")
_BASE = re.compile(r"^Base(?:\s+level)?:?\s+(?P<level>\d+)")
_BASE_GENERAL = re.compile(r"^Base\s+(effect|spell)\b|^Base$")
_TOKEN = re.compile(r"^(?P<sign>[+-])\s*(?P<magnitude>\d+)\s+(?P<label>.+)$")
_REQUISITE = re.compile(r"^(?P<art>[A-Z][a-z]+)\s+requisites?$")
_FREE_REQUISITE = re.compile(
    r"^(?:no\s+(?:cost|addition)\s+for\s+requisites?|requisites?\s+free)$", re.IGNORECASE
)

# Range, Duration and Target names as the design lines spell them, mapped to
# the `name` field in assets/data/parameters.json.
PARAMETER_LABELS = {
    "Touch": "Touch", "Eye": "Eye", "Voice": "Voice", "Sight": "Sight",
    "Arc": "Arcane Connection", "Arcane Connection": "Arcane Connection",
    "Per": "Personal", "Personal": "Personal",
    "Mom": "Momentary", "Momentary": "Momentary",
    "Diam": "Diameter", "Diameter": "Diameter",
    "Conc": "Concentration", "Concentration": "Concentration",
    "Sun": "Sun", "Ring": "Ring", "Moon": "Moon", "Year": "Year",
    "Ind": "Individual", "Individual": "Individual",
    "Part": "Part", "Group": "Group", "Room": "Room",
    "Circle": "Circle", "Structure": "Structure",
    "Bound": "Boundary", "Boundary": "Boundary",
    "Taste": "Taste", "Smell": "Smell", "Hearing": "Hearing", "Vision": "Vision",
}

# Tokens that map onto entries in assets/data/modifiers.json. The label is
# resolved to a modifier option in catalog.py, not here.
MODIFIER_LABELS = {
    "size", "Size", "unnatural", "stone", "metal",
    "changing image", "intricacy", "complexity",
}


class UnknownToken(ValueError):
    """A design-line token this importer does not model.

    Not a bug — the expected outcome for the 74 spells blocked on todo items
    24, 25, 26, 28, 18, 19 and 4.
    """


@dataclasses.dataclass(frozen=True)
class Token:
    magnitude: int
    label: str
    kind: str


@dataclasses.dataclass(frozen=True)
class Design:
    base_level: int | None
    tokens: list[Token]


def parse_design(text: str) -> Design:
    inner = text.strip()
    if inner.startswith("("):
        inner = inner[1:]
    if inner.endswith(")"):
        inner = inner[:-1]
    # Drop bracketed asides such as "(a very unnatural liquid)" before splitting.
    inner = _PARENTHETICAL.sub("", inner)

    parts = [p.strip() for p in re.split(r"[,.](?=\s|$)", inner) if p.strip()]
    if not parts:
        raise UnknownToken(f"empty design line: {text!r}")

    head = parts[0]
    base_match = _BASE.match(head)
    if base_match:
        base_level: int | None = int(base_match.group("level"))
    elif _BASE_GENERAL.match(head):
        base_level = None
    else:
        raise UnknownToken(f"unrecognised base term {head!r} in {text!r}")

    tokens: list[Token] = []
    for part in parts[1:]:
        if _FREE_REQUISITE.match(part):
            tokens.append(Token(magnitude=0, label="free", kind="requisite"))
            continue

        token_match = _TOKEN.match(part)
        if not token_match:
            raise UnknownToken(f"unrecognised token {part!r} in {text!r}")

        magnitude = int(token_match.group("magnitude"))
        if token_match.group("sign") == "-":
            magnitude = -magnitude
        label = token_match.group("label").strip()

        requisite_match = _REQUISITE.match(label)
        if requisite_match:
            tokens.append(Token(magnitude, requisite_match.group("art"), "requisite"))
        elif label in PARAMETER_LABELS:
            tokens.append(Token(magnitude, PARAMETER_LABELS[label], "parameter"))
        elif label in MODIFIER_LABELS:
            tokens.append(Token(magnitude, label, "modifier"))
        else:
            raise UnknownToken(f"unrecognised token {part!r} in {text!r}")

    return Design(base_level=base_level, tokens=tokens)
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
python -m unittest scripts.spell_import.tests.test_designline -v
```

Expected: PASS, 11 tests.

- [ ] **Step 5: Print the blocked-token census and record it**

```bash
python -c "
import collections
from scripts.spell_import import sources, blocks, designline
L = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
parsed, _ = blocks.parse_de(L)
bad = collections.Counter()
for b in parsed:
    if b.design_line is None: continue
    try: designline.parse_design(b.design_line)
    except designline.UnknownToken as e: bad[str(e).split(chr(39))[1]] += 1
print(sum(bad.values()), 'spells blocked on', len(bad), 'distinct tokens')
for t, c in bad.most_common(25): print(' %3d  %s' % (c, t))
"
```

Record the output in the commit message. If a token here looks like something the catalog *does* model (a parameter or an existing modifier), add it to `PARAMETER_LABELS` / `MODIFIER_LABELS` and re-run. Anything genuinely un-modelled stays blocked.

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/ && git commit -m "feat(import): tokenize design lines; unknown tokens block a spell loudly"
```

---

## Task 5: Catalog loading, candidate narrowing and id slugging

**Files:**
- Create: `scripts/spell_import/catalog.py`
- Test: `scripts/spell_import/tests/test_catalog.py`

**Interfaces:**
- Consumes: `blocks.SpellBlock`, `designline.Design`
- Produces:
  - `Catalog` class with `.base_effects: list[dict]`, `.parameters: list[dict]`, `.modifiers: list[dict]`
  - `Catalog.load() -> Catalog`
  - `Catalog.candidates(technique: str, form: str, base_level: int) -> list[str]` — base-effect ids, sorted
  - `Catalog.parameter_id(category: str, name: str) -> str` — raises `KeyError`
  - `slug_id(technique: str, form: str, name: str) -> str`

- [ ] **Step 1: Write the failing test**

Create `scripts/spell_import/tests/test_catalog.py`:

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
python -m unittest scripts.spell_import.tests.test_catalog -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.catalog'`

- [ ] **Step 3: Write the implementation**

Create `scripts/spell_import/catalog.py`:

```python
"""Load the committed JSON catalogs and narrow base-effect candidates.

Narrowing is all this module does about base effects. It never picks between
candidates: a design line names its guideline only by level, and picking the
wrong one of four entries at the same level is invisible to a level test.
That decision belongs to a human and is recorded in ledger.json.
"""
import dataclasses
import json
import pathlib
import re

from .sources import REPO_ROOT

DATA_DIR = REPO_ROOT / "assets" / "data"

TECHNIQUE_ABBREVIATION = {
    "Creo": "cr", "Intellego": "in", "Muto": "mu", "Perdo": "pe", "Rego": "re",
}
FORM_ABBREVIATION = {
    "Animal": "an", "Aquam": "aq", "Auram": "au", "Corpus": "co", "Herbam": "he",
    "Ignem": "ig", "Imaginem": "im", "Mentem": "me", "Terram": "te", "Vim": "vi",
}

# Leading articles and stock phrases the existing 36 ids drop.
_STOPWORDS = {"the", "of", "a", "an", "phantasm"}


def slug_id(technique: str, form: str, name: str) -> str:
    prefix = TECHNIQUE_ABBREVIATION[technique] + FORM_ABBREVIATION[form]
    words = re.sub(r"[^a-z0-9\s-]", "", name.lower()).split()
    kept = [w for w in words if w not in _STOPWORDS] or words
    return f"lib-{prefix}-{'-'.join(kept)}"


@dataclasses.dataclass
class Catalog:
    base_effects: list[dict]
    parameters: list[dict]
    modifiers: list[dict]

    @classmethod
    def load(cls, data_dir: pathlib.Path = DATA_DIR) -> "Catalog":
        def read(name: str) -> list[dict]:
            return json.loads((data_dir / name).read_text(encoding="utf-8"))

        return cls(
            base_effects=read("base_effects.json"),
            parameters=read("parameters.json"),
            modifiers=read("modifiers.json"),
        )

    def candidates(self, technique: str, form: str, base_level: int) -> list[str]:
        return sorted({
            effect["id"]
            for effect in self.base_effects
            if effect["technique"] == technique
            and effect["form"] == form
            and effect["baseLevel"] == base_level
        })

    def parameter_id(self, category: str, name: str) -> str:
        for parameter in self.parameters:
            if parameter["category"] == category and parameter["name"] == name:
                return parameter["id"]
        raise KeyError(f"no {category} parameter named {name!r} in parameters.json")
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
python -m unittest scripts.spell_import.tests.test_catalog -v
```

Expected: PASS, 7 tests.

If `test_matches_the_existing_library_convention` fails, print the 36 committed ids and adjust `_STOPWORDS` until the slugger reproduces them:

```bash
python -c "import json; print('\n'.join(s['id'] + '  <-  ' + s['name'] for s in json.load(open('assets/data/spell_library.json'))))"
```

- [ ] **Step 5: Add a test that the slugger reproduces every committed id**

Append to `scripts/spell_import/tests/test_catalog.py`:

```python
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
```

Run it. If a handful of the 36 cannot be reproduced by any reasonable rule, record them in an explicit `ID_OVERRIDES: dict[str, str]` in `catalog.py` keyed by spell name, apply it in `slug_id`, and note in the commit which ids needed it and why. Do not loosen the test.

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/ && git commit -m "feat(import): load catalogs, narrow base-effect candidates, slug spell ids"
```

---

## Task 6: The resolution ledger

**Files:**
- Create: `scripts/spell_import/ledger.py`
- Create: `scripts/spell_import/resolutions.json` (initially `{}`)
- Modify: `.gitignore`
- Test: `scripts/spell_import/tests/test_ledger.py`

**Interfaces:**
- Consumes: `catalog.Catalog`
- Produces:
  - `Entry` dataclass: `.base_effect_id: str`, `.candidates: list[str]`, `.rationale: str`
  - `Ledger` class: `.entries: dict[str, Entry]`, `.load() -> Ledger`
  - `Ledger.resolve(spell_id: str, candidates: list[str]) -> str` — raises `LedgerError` subclasses
  - Exceptions: `MissingEntry`, `StaleEntry`, `UnnecessaryEntry`

- [ ] **Step 1: Write the failing test**

Create `scripts/spell_import/tests/test_ledger.py`:

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
python -m unittest scripts.spell_import.tests.test_ledger -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.ledger'`

- [ ] **Step 3: Write the implementation**

Create `scripts/spell_import/resolutions.json` containing exactly:

```json
{}
```

Create `scripts/spell_import/ledger.py`:

```python
"""The hand-edited record of every base-effect decision that needed judgement.

A published spell's design line names its guideline only by level. Creo Animal
has four entries at level 15, all producing the same computed level, so the
level test cannot tell a right choice from a wrong one. Todo item 5 is the
proof: 19 of 36 built-in spells referenced wrong or invented base-effect ids
while every level test was green.

This file is written by hand and read by the extractor. The extractor never
writes it — a generated file that silently rewrites the human decisions it
depends on is not a ledger.
"""
import dataclasses
import json
import pathlib

LEDGER_PATH = pathlib.Path(__file__).resolve().parent / "resolutions.json"


class LedgerError(Exception):
    """Base class for ledger problems. All are build failures."""


class MissingEntry(LedgerError):
    pass


class StaleEntry(LedgerError):
    pass


class UnnecessaryEntry(LedgerError):
    pass


@dataclasses.dataclass(frozen=True)
class Entry:
    base_effect_id: str
    candidates: list[str]
    rationale: str


@dataclasses.dataclass
class Ledger:
    entries: dict[str, Entry]

    @classmethod
    def from_dict(cls, raw: dict) -> "Ledger":
        entries: dict[str, Entry] = {}
        for spell_id, value in raw.items():
            for field in ("baseEffectId", "candidates", "rationale"):
                if field not in value:
                    raise ValueError(f"{spell_id}: ledger entry is missing {field!r}")
            if not str(value["rationale"]).strip():
                raise ValueError(f"{spell_id}: ledger entry needs a non-empty rationale")
            entries[spell_id] = Entry(
                base_effect_id=value["baseEffectId"],
                candidates=sorted(value["candidates"]),
                rationale=value["rationale"],
            )
        return cls(entries=entries)

    @classmethod
    def load(cls, path: pathlib.Path = LEDGER_PATH) -> "Ledger":
        return cls.from_dict(json.loads(path.read_text(encoding="utf-8")))

    def resolve(self, spell_id: str, candidates: list[str]) -> str:
        candidates = sorted(candidates)
        entry = self.entries.get(spell_id)

        if len(candidates) == 1:
            if entry is not None and entry.base_effect_id == candidates[0]:
                raise UnnecessaryEntry(
                    f"{spell_id}: only one candidate ({candidates[0]}); "
                    "remove the ledger entry, or change it to a deliberate override"
                )
            if entry is None:
                return candidates[0]

        if not candidates:
            raise MissingEntry(f"{spell_id}: no base effect at that Technique/Form/level")

        if entry is None:
            raise MissingEntry(
                f"{spell_id}: {len(candidates)} candidates {candidates} and no ledger entry"
            )

        if entry.candidates != candidates:
            raise StaleEntry(
                f"{spell_id}: decided against {entry.candidates} but the catalog now "
                f"offers {candidates} — re-examine the choice, then update the entry"
            )

        if entry.base_effect_id not in candidates:
            raise StaleEntry(
                f"{spell_id}: chose {entry.base_effect_id}, which is not among {candidates}"
            )

        return entry.base_effect_id
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
python -m unittest scripts.spell_import.tests.test_ledger -v
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Gitignore the proposals file**

Append to `.gitignore`:

```
# Written by scripts/spell_import/extract_spells.py when the ledger is
# incomplete. It is a worksheet, not a record — copy decisions into
# resolutions.json by hand.
scripts/spell_import/resolutions.proposed.json
```

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/ .gitignore && git commit -m "feat(import): add the base-effect resolution ledger"
```

---

## Task 7: Emit the library and prove regeneration is clean

**Files:**
- Create: `scripts/spell_import/emit.py`
- Create: `scripts/spell_import/extract_spells.py`
- Modify: `assets/data/spell_library.json` (regenerated)
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: everything above
- Produces:
  - `emit.build_spell(block, base_effect_id, catalog, design) -> dict` — one `spell_library.json` entry
  - `extract_spells.run(write: bool) -> Report`
  - `Report` dataclass: `.spells: list[dict]`, `.blocked: list[tuple[str, str]]`, `.unresolved: list[str]`, `.problems: list[str]`

- [ ] **Step 1: Write the failing test**

Create `scripts/spell_import/tests/test_extract.py`:

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
python -m unittest scripts.spell_import.tests.test_extract -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.extract_spells'`

- [ ] **Step 3: Write `emit.py`**

```python
"""Build one assets/data/spell_library.json entry from a parsed spell block."""
from . import catalog as catalog_module
from . import designline

# The existing 36 entries all carry this fixed timestamp. Generated entries
# must too: a wall-clock value would make every run produce a diff, defeating
# the regeneration assertion.
FIXED_TIMESTAMP = "2026-01-01T00:00:00.000"

CORE_BOOK_ID = "arm5-core"


def build_spell(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
) -> dict:
    range_id = catalog.parameter_id("Range", _parameter_name(design, "range", block))
    duration_id = catalog.parameter_id("Duration", _parameter_name(design, "duration", block))
    target_id = catalog.parameter_id("Target", _parameter_name(design, "target", block))

    requisites = [
        {"art": token.label, "kind": "adding" if token.magnitude else "free"}
        for token in design.tokens
        if token.kind == "requisite" and token.label != "free"
    ]
    for art in block.stat.requisite_arts:
        if not any(r["art"] == art for r in requisites):
            requisites.append({"art": art, "kind": "free"})

    spell = {
        "id": catalog_module.slug_id(block.technique, block.form, block.name),
        "name": block.name,
        "requisites": requisites,
        "source": "published",
        "createdAt": FIXED_TIMESTAMP,
        "updatedAt": FIXED_TIMESTAMP,
        "selectedModifiers": {},
        "baseEffectId": base_effect_id,
        "rangeId": range_id,
        "durationId": duration_id,
        "targetId": target_id,
        "summary": _summary(block),
        "citations": [{"bookId": CORE_BOOK_ID}],
    }

    if block.stat.is_ritual:
        spell["ritualDeclaration"] = "lastingCreation"

    return spell


def _parameter_name(design: designline.Design, slot: str, block) -> str:
    """Resolve a slot from the stat line, expanded to its full catalog name."""
    raw = {
        "range": block.stat.range_name,
        "duration": block.stat.duration_name,
        "target": block.stat.target_name,
    }[slot]
    if raw not in designline.PARAMETER_LABELS:
        raise designline.UnknownToken(f"{block.name}: unknown {slot} {raw!r}")
    return designline.PARAMETER_LABELS[raw]


def _summary(block) -> str:
    """Prose plus the printed level, which the level-equality test reads back.

    The existing 36 entries end their summary with "Level N." and
    asset_data_loader_test.dart parses exactly that. Keep the shape.
    """
    prose = " ".join(block.prose.split())
    if len(prose) > 400:
        prose = prose[:397].rstrip() + "..."
    return f"{prose} Level {block.printed_level}."
```

- [ ] **Step 4: Write `extract_spells.py`**

```python
"""Extract published spells from the rulebook into assets/data/spell_library.json.

Maintained and re-runnable, unlike scripts/flag_ritual_effects.py. Running it
against an unchanged ledger and unchanged catalogs produces byte-identical
output; `test_extract.py` asserts exactly that.

    python -m scripts.spell_import.extract_spells          # report only
    python -m scripts.spell_import.extract_spells --write  # rewrite the asset
"""
import argparse
import dataclasses
import json
import sys

from . import blocks, catalog as catalog_module, designline, ledger as ledger_module, emit, sources

LIBRARY_PATH = catalog_module.DATA_DIR / "spell_library.json"
PROPOSALS_PATH = ledger_module.LEDGER_PATH.with_name("resolutions.proposed.json")


@dataclasses.dataclass
class Report:
    spells: list[dict]
    blocked: list[tuple[str, str]]
    unresolved: list[str]
    problems: list[str]


def serialize(spells: list[dict]) -> str:
    """Canonical form. Sorting by id is what makes the output stable."""
    ordered = sorted(spells, key=lambda s: s["id"])
    return json.dumps(ordered, indent=2, ensure_ascii=False) + "\n"


def run(write: bool = False) -> Report:
    lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
    parsed, problems = blocks.parse_de(lines)
    catalog = catalog_module.Catalog.load()
    book = ledger_module.Ledger.load()

    spells: list[dict] = []
    blocked: list[tuple[str, str]] = []
    unresolved: list[str] = []
    proposals: dict[str, dict] = {}

    for block in parsed:
        if block.design_line is None:
            blocked.append((block.name, "no design line printed"))
            continue

        try:
            design = designline.parse_design(block.design_line)
        except designline.UnknownToken as error:
            blocked.append((block.name, str(error)))
            continue

        if design.base_level is None or block.printed_level is None:
            blocked.append((block.name, "General level — todo item 25"))
            continue

        spell_id = catalog_module.slug_id(block.technique, block.form, block.name)
        candidates = catalog.candidates(block.technique, block.form, design.base_level)

        try:
            base_effect_id = book.resolve(spell_id, candidates)
        except ledger_module.MissingEntry as error:
            unresolved.append(str(error))
            if candidates:
                proposals[spell_id] = {
                    "baseEffectId": "",
                    "candidates": candidates,
                    "rationale": "",
                    "_name": block.name,
                    "_line": block.line_no,
                    "_descriptions": [
                        e["description"] for e in catalog.base_effects if e["id"] in candidates
                    ],
                }
            continue
        except ledger_module.LedgerError as error:
            unresolved.append(str(error))
            continue

        try:
            spells.append(emit.build_spell(block, base_effect_id, catalog, design))
        except (designline.UnknownToken, KeyError) as error:
            blocked.append((block.name, str(error)))

    if proposals:
        PROPOSALS_PATH.write_text(
            json.dumps(proposals, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

    if write and not unresolved and not problems:
        LIBRARY_PATH.write_text(serialize(spells), encoding="utf-8")

    return Report(spells=spells, blocked=blocked, unresolved=unresolved, problems=problems)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="rewrite spell_library.json")
    args = parser.parse_args(argv)

    report = run(write=args.write)

    print(f"imported : {len(report.spells)}")
    print(f"blocked  : {len(report.blocked)}")
    print(f"unresolved: {len(report.unresolved)}")

    for problem in report.problems:
        print(f"  PARSE  {problem}", file=sys.stderr)
    for message in report.unresolved[:20]:
        print(f"  LEDGER {message}", file=sys.stderr)
    if report.unresolved:
        print(f"\nwrote {PROPOSALS_PATH} — copy decisions into resolutions.json by hand",
              file=sys.stderr)

    if report.problems or report.unresolved:
        return 1
    if args.write:
        print(f"wrote {LIBRARY_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 5: Run the extractor and read the report**

```bash
python -m scripts.spell_import.extract_spells
```

Expected: a non-zero exit with a large `unresolved` count and `resolutions.proposed.json` written. That is the correct first-run state — the ledger is empty. Note the three counts; they size Task 10.

- [ ] **Step 6: Run the tests**

```bash
python -m unittest scripts.spell_import.tests.test_extract -v
```

Expected at this point: `RunTest` passes; both `RegenerationTest` tests **fail**, because nothing has been written yet. That is correct — they go green in Task 10 once the ledger is complete and the asset is regenerated.

- [ ] **Step 7: Commit**

```bash
git add scripts/spell_import/ && git commit -m "feat(import): emit spell entries and assert clean regeneration"
```

---

## Task 8: Dart asset assertions

**Files:**
- Create: `test/data/published_spell_import_test.dart`
- Test: itself

**Interfaces:**
- Consumes: `AssetDataLoader`, `SpellEngine`, `SpellLevelCalculator`, `assets/data/spell_library.json`
- Produces: assertions 1–4

Write this task **before** the library is regenerated. Against the current 36 spells every assertion should already pass; that proves the harness works before it is trusted with 286.

- [ ] **Step 1: Write the test**

Create `test/data/published_spell_import_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/publication_source.dart';

/// Assertions 1-4 of the published spell import harness.
/// See docs/superpowers/specs/2026-07-28-published-spell-import-design.md
///
/// Assertion 5 (regeneration is clean) lives in
/// scripts/spell_import/tests/test_extract.py, because it has to run the
/// extractor. Both suites must run in CI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = AssetDataLoader();

  /// The printed level, which every generated summary ends with.
  int printedLevel(String? summary) {
    final match = RegExp(r'Level (\d+)\.$').firstMatch((summary ?? '').trim());
    expect(match, isNotNull, reason: 'summary must end with "Level N.": "$summary"');
    return int.parse(match!.group(1)!);
  }

  test('assertion 1: every spell computes to its printed level', () async {
    final spells = await loader.loadSpellLibrary();
    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final engine = SpellEngine(allSpells: const [], allModifiers: await loader.loadModifiers());

    final mismatches = <String>[];
    for (final spell in spells) {
      final breakdown = engine.calculateBreakdown(
        baseEffect: effects[spell.baseEffectId]!,
        range: parameters[spell.rangeId]!,
        duration: parameters[spell.durationId]!,
        target: parameters[spell.targetId]!,
        selectedModifiers: spell.selectedModifiers,
        requisites: spell.requisites,
        ritualDeclaration: spell.ritualDeclaration,
      );
      final want = printedLevel(spell.summary);
      if (breakdown.level != want) {
        mismatches.add('${spell.name}: computed ${breakdown.level}, printed $want');
      }
    }

    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
  });

  test('assertion 2: derived Ritual status matches the printed Ritual flag', () async {
    // The oracle that does not depend on the base effect being right, and so
    // is sensitive to precisely what assertion 1 is blind to.
    //
    // Stated per-spell, not as a count. 39 of the 360 published spells print
    // Ritual but only 19 fall in the importable set; a count assertion would
    // be wrong on the day it lands and would need editing every time a
    // blocker clears.
    final spells = await loader.loadSpellLibrary();
    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final engine = SpellEngine(allSpells: const [], allModifiers: await loader.loadModifiers());

    final raw = jsonDecode(await rootBundle.loadString('assets/data/spell_library.json')) as List;
    final printedRitual = {
      for (final entry in raw.cast<Map<String, dynamic>>())
        entry['id'] as String: entry['ritualDeclaration'] != null,
    };

    final disagreements = <String>[];
    for (final spell in spells) {
      final derived = engine
          .calculateBreakdown(
            baseEffect: effects[spell.baseEffectId]!,
            range: parameters[spell.rangeId]!,
            duration: parameters[spell.durationId]!,
            target: parameters[spell.targetId]!,
            selectedModifiers: spell.selectedModifiers,
            requisites: spell.requisites,
            ritualDeclaration: spell.ritualDeclaration,
          )
          .ritualStatus
          .isRitual;

      if (derived != printedRitual[spell.id]) {
        disagreements.add(
          '${spell.name}: derived $derived, rulebook prints ${printedRitual[spell.id]}',
        );
      }
    }

    expect(disagreements, isEmpty, reason: disagreements.join('\n'));
  });

  test('assertion 3: every ambiguous base effect has a ledger entry', () async {
    // Enforced in full by the extractor, which refuses to write an
    // unresolved spell. This is the standing guard on the committed asset:
    // no spell may reference a base effect at a level where the catalog
    // offers alternatives without a recorded decision.
    final spells = await loader.loadSpellLibrary();
    final effects = await loader.loadBaseEffects();

    final ledgerJson = jsonDecode(
      await File('scripts/spell_import/resolutions.json').readAsString(),
    ) as Map<String, dynamic>;

    final undocumented = <String>[];
    for (final spell in spells) {
      final chosen = effects.firstWhere((e) => e.id == spell.baseEffectId);
      final candidates = effects
          .where((e) =>
              e.technique == chosen.technique &&
              e.form == chosen.form &&
              e.baseLevel == chosen.baseLevel)
          .map((e) => e.id)
          .toSet();
      if (candidates.length > 1 && !ledgerJson.containsKey(spell.id)) {
        undocumented.add('${spell.name}: ${candidates.length} candidates, no ledger entry');
      }
    }

    expect(undocumented, isEmpty, reason: undocumented.join('\n'));
  });

  test('assertion 4: every referenced id resolves', () async {
    final spells = await loader.loadSpellLibrary();
    final effectIds = (await loader.loadBaseEffects()).map((e) => e.id).toSet();
    final parameterIds = (await loader.loadParameters()).map((p) => p.id).toSet();
    final modifiers = await loader.loadModifiers();
    final bookIds = (await loader.loadBooks()).map((b) => b.id).toSet();

    for (final spell in spells) {
      expect(effectIds, contains(spell.baseEffectId), reason: spell.name);
      for (final id in [spell.rangeId, spell.durationId, spell.targetId]) {
        expect(parameterIds, contains(id), reason: '${spell.name}: $id');
      }
      spell.selectedModifiers.forEach((modifierId, optionIds) {
        final modifier = modifiers.where((m) => m.id == modifierId);
        expect(modifier, isNotEmpty, reason: '${spell.name}: modifier $modifierId');
        for (final optionId in optionIds) {
          expect(modifier.first.optionById(optionId), isNotNull,
              reason: '${spell.name}: option $optionId');
        }
      });
      expect(spell.provenance.source, PublicationSource.published, reason: spell.name);
      for (final citation in spell.provenance.citations) {
        expect(bookIds, contains(citation.bookId), reason: spell.name);
      }
    }
  });
}
```

Add `import 'dart:io';` at the top for the `File` used in assertion 3.

- [ ] **Step 2: Run the tests against the current 36 spells**

```bash
export PATH="$HOME/SDKs/flutter/flutter/bin:$PATH" && flutter test test/data/published_spell_import_test.dart
```

Expected: all four PASS. The harness must be green on the existing library before it is trusted with 286 spells.

If assertion 1 fails on an existing spell, that is a real pre-existing bug — fix the spell's data, do not weaken the test.

If assertion 3 fails, the existing 36 include an ambiguous choice with no ledger entry. Add entries for exactly those spells to `resolutions.json` with a rationale drawn from the guideline text, and re-run.

- [ ] **Step 3: Commit**

```bash
git add test/data/published_spell_import_test.dart scripts/spell_import/resolutions.json && git commit -m "test: add the four Dart asset assertions for published spell import"
```

---

## Task 9: Retire the hardcoded count and correct Citation.page

**Files:**
- Modify: `test/data/datasources/asset_data_loader_test.dart:117-123`
- Modify: `lib/models/citation.dart:3-7`

**Interfaces:**
- Consumes: nothing
- Produces: nothing

- [ ] **Step 1: Replace the hardcoded 36 with a derived count**

In `test/data/datasources/asset_data_loader_test.dart`, replace the test at lines 117–123 with:

```dart
  test('loadSpellLibrary loads every spell in the asset file', () async {
    final spells = await loader.loadSpellLibrary();

    // Derived from the raw file, not a literal. Item 5 left this as a
    // hardcoded 36 on the reasoning that the library was "small,
    // hand-curated, changed in deliberate reviewed batches, not
    // bulk-extracted". Every clause of that stopped being true when the
    // library became generator output.
    final rawList =
        jsonDecode(await rootBundle.loadString('assets/data/spell_library.json')) as List;
    expect(spells.length, rawList.length,
        reason: 'loadSpellLibrary should return exactly the entries in spell_library.json');
    expect(spells.every((s) => s.provenance.source == PublicationSource.published), isTrue);
    expect(spells.every((s) => s.name != null && s.name!.isNotEmpty), isTrue);
  });
```

- [ ] **Step 2: Correct the Citation.page doc comment**

In `lib/models/citation.dart`, replace lines 3–7 with:

```dart
/// One place a spell was published: a book, and optionally the page.
///
/// [page] is nullable and is null for every built-in entry. The reviewed
/// rulebook markdown carries no page markers — only prose cross-references of
/// the form "see page 213" — so page numbers cannot be recovered from the
/// import source. An earlier version of this comment promised they would
/// "arrive with the spell-parsing work"; that work is done and the promise
/// could not be kept. Supplying them needs the PDFs or a different edition.
/// A citation naming only its book is complete and valid.
```

- [ ] **Step 3: Run the affected suites**

```bash
export PATH="$HOME/SDKs/flutter/flutter/bin:$PATH" && flutter test test/data/datasources/asset_data_loader_test.dart test/models/citation_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add test/data/datasources/asset_data_loader_test.dart lib/models/citation.dart && git commit -m "refactor: derive the library count from the asset; correct Citation.page's promise"
```

---

## Task 10: Fill the ledger and import the library

This is the long task and the one that carries the judgement. Work in batches by Technique and Form so a reviewer can check a coherent slice.

**Files:**
- Modify: `scripts/spell_import/resolutions.json`
- Modify: `assets/data/spell_library.json`

- [ ] **Step 1: Generate the worksheet**

```bash
python -m scripts.spell_import.extract_spells
```

This writes `scripts/spell_import/resolutions.proposed.json`, one object per unresolved spell carrying its candidate ids, each candidate's guideline text, and the source line number.

- [ ] **Step 2: Resolve one Technique/Form batch**

For each spell in the batch, read the spell's description at its `_line` in the rulebook and each candidate's guideline text, then write an entry into `resolutions.json`:

```json
{
  "lib-cran-weavers-trap-of-webs": {
    "baseEffectId": "cran-5a",
    "candidates": ["cran-5a", "cran-5b", "cran-5c"],
    "rationale": "Grows a net of spider webs; cran-5a is 'Create an animal product, such as spidersilk or wool'."
  }
}
```

Rules, all enforced by Task 6's code:
- `candidates` must be the full candidate set, verbatim from the worksheet. It is what lets item 22's new guideline rows flag this decision as stale rather than letting it stand unexamined.
- `rationale` must be non-empty and must say *why*, quoting the guideline text.
- `baseEffectId` must be one of `candidates`.

**Do not** paste the worksheet's `_name`, `_line` or `_descriptions` keys into `resolutions.json` — they are worksheet scaffolding.

**Do not** guess. A confidence score attached to a bad guess is worse than no guess, because it launders judgement into data. If a choice genuinely cannot be made from the text, leave it unresolved and record the spell in todo item 27 as needing a rules decision.

- [ ] **Step 3: Re-run and confirm the batch resolved**

```bash
python -m scripts.spell_import.extract_spells
```

Expected: `unresolved` drops by the size of the batch. Repeat steps 2–3 until `unresolved` is 0.

- [ ] **Step 4: Write the library**

```bash
python -m scripts.spell_import.extract_spells --write
```

Expected: exit 0, `imported : 286` (or the number the audit's blockers permit — the audit's 286 is a figure to reconcile against, not a target to reproduce; if the extractor disagrees, the disagreement is a finding, investigate it before proceeding).

- [ ] **Step 5: Run every suite**

```bash
python -m unittest discover -s . -p "test_*.py" -t . -v
```

Expected: PASS, including both `RegenerationTest` tests, which were failing at the end of Task 7.

```bash
export PATH="$HOME/SDKs/flutter/flutter/bin:$PATH" && flutter test
```

Expected: PASS, all four assertions green over the full imported library.

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/resolutions.json assets/data/spell_library.json && git commit -m "feat: import the expressible published Definitive Edition spells"
```

---

## Task 11: The three spells with no printed design line

**Files:**
- Modify: `scripts/spell_import/resolutions.json`
- Modify: `scripts/spell_import/extract_spells.py`
- Modify: `assets/data/spell_library.json`

Three fixed-level spells print no design line, so nothing can be derived mechanically. Five more lack one but are General-level and belong to todo item 25.

| Spell | Technique/Form | Level | Source line |
|---|---|---|---|
| *Enchantment of the Scrying Pool* | Intellego Aquam | 30 | 12900 |
| *Whispering Winds* | Intellego Auram | 15 | 13251 |
| *Hermes' Portal* | Rego Terram | 75 | 15638 |

- [ ] **Step 1: Write the failing test**

Append to `scripts/spell_import/tests/test_extract.py`:

```python
class HandDerivedTest(unittest.TestCase):
    def test_the_three_design_line_less_spells_are_imported(self):
        report = extract_spells.run(write=False)
        names = {s["name"] for s in report.spells}
        for name in ["Enchantment of the Scrying Pool", "Whispering Winds", "Hermes' Portal"]:
            self.assertIn(name, names)
```

- [ ] **Step 2: Run it to verify it fails**

```bash
python -m unittest scripts.spell_import.tests.test_extract.HandDerivedTest -v
```

Expected: FAIL — the three are in `blocked` with `"no design line printed"`.

- [ ] **Step 3: Add a hand-derivation table to `extract_spells.py`**

Insert above `run()`:

```python
# The rulebook prints no design line for these three. Each derivation below is
# done by hand from the spell's stat line and a chosen guideline, and each is
# then checked by assertion 1 — if a derivation is wrong the computed level
# will not equal the printed one. Hand-derivation under a test is a different
# thing from hand-derivation on trust.
#
# Five further spells also lack a design line but are General-level and so
# belong to todo item 25, not here.
HAND_DERIVED: dict[str, str] = {
    "Enchantment of the Scrying Pool": "(Base 3, +1 Touch, +2 Sun, +2 Room)",
    "Whispering Winds": "(Base 2, +3 Sight, +1 Conc)",
    "Hermes' Portal": "(Base 35, +1 Touch, +2 Group, +4 size)",
}
```

Then, in `run()`, replace:

```python
        if block.design_line is None:
            blocked.append((block.name, "no design line printed"))
            continue
```

with:

```python
        design_text = block.design_line or HAND_DERIVED.get(block.name)
        if design_text is None:
            blocked.append((block.name, "no design line printed"))
            continue
```

and change the next line to `design = designline.parse_design(design_text)`.

- [ ] **Step 4: Correct each derivation until assertion 1 passes**

The three magnitude strings above are placeholders in one specific sense: they are a first reading of each spell's stat line, and assertion 1 is the arbiter. Run:

```bash
python -m scripts.spell_import.extract_spells --write && export PATH="$HOME/SDKs/flutter/flutter/bin:$PATH" && flutter test test/data/published_spell_import_test.dart
```

For each spell assertion 1 reports, open the rulebook at its source line, read the stat line and the guideline table for its Technique and Form, and correct the entry. Do not adjust the printed level to match a derivation — the printed level is the authority.

- [ ] **Step 5: Re-run every suite**

```bash
python -m unittest discover -s . -p "test_*.py" -t . && export PATH="$HOME/SDKs/flutter/flutter/bin:$PATH" && flutter test
```

Expected: PASS.

- [ ] **Step 6: Update todo item 27 and commit**

Tick the completed boxes under item 27 in `.superpowers/todo.md`, and record the final imported and blocked counts there.

```bash
git add scripts/spell_import/ assets/data/spell_library.json .superpowers/todo.md && git commit -m "feat: hand-derive the three spells the rulebook prints no design line for"
```

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| Maintained, idempotent extractor | 1–7 |
| Hand-edited ledger recording decision + candidate set | 6, 10 |
| Assertion 1 — level equality | 8 |
| Assertion 2 — Ritual agreement, per-spell | 8 |
| Assertion 3 — resolution completeness | 6 (extractor), 8 (asset guard) |
| Assertion 4 — reference integrity | 8 |
| Assertion 5 — regeneration is clean | 7 |
| Import the expressible spells | 10 |
| Retire `loadSpellLibrary`'s hardcoded count | 9 |
| Correct `Citation.page`'s doc comment | 9 |
| The 3 spells with no design line | 11 |
| Stat-line anchor, conjunction not `^R:` | 2 |
| Blockquote-aware matching | 2 |
| Tolerant pass for damaged lines | 2 |
| 1:1 anchor/heading assertion | 3 |
| Creo Terram heading defect | 3 |
| Source precedence reviewed > wip > raw-md | 1 |
| Item 23's formatting inconsistency | 7 (`serialize` normalises the whole file) |
| Extractor unit coverage | 2, 4, 5 |
| Ledger unit coverage | 6 |

**Known gaps, stated rather than hidden:**

- **Modifier selection is not implemented.** `emit.build_spell` always writes `"selectedModifiers": {}`, but design lines carry `+1 size`, `+2 stone`, `+1 changing image` and similar, which `designline.py` classifies as `kind="modifier"`. Task 10 will surface this as assertion-1 failures on those spells. **Resolve it there**: either map modifier tokens to `modifiers.json` option ids inside `emit.build_spell`, or block those spells and record the count. Do not silently drop the magnitude — that is exactly the failure the tokenizer is designed to prevent.
- **The 286 figure is unverified by this plan.** It comes from the audit's throwaway scripts. Task 10 Step 4 treats a disagreement as a finding to investigate, per the spec's Risks table.
- **Supplement import is out of scope,** as the spec says. Task 1's `resolve_book` and Task 2's predicate are written to generalise; `blocks.parse_de` deliberately is not.

**Type consistency:** `Design`/`Token` (Task 4) are consumed by `emit.build_spell` (Task 7) with the field names defined in Task 4. `Catalog.candidates` returns `list[str]` and `Ledger.resolve` takes `list[str]` — matched. `SpellBlock.printed_level` is `int | None` and both Task 7 and Task 11 handle the `None` case.

---

## Execution Handoff

Plan complete. Two execution options — see the message accompanying this file.
