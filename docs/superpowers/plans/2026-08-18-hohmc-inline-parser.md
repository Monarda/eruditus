# HoH:MC Inline Parser and Multi-Book Plumbing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the 14 spells *Houses of Hermes: Mystery Cults* prints, by adding a second block-anchor style to the parser and turning the importer's one hard-coded book into a per-book registry.

**Architecture:** A new `blocks.parse_inline` stands beside the untouched `parse_de` and is selected by a `PARSERS` dict; `sources.BOOKS` names each book's id, title and parser; `run()` loops that registry and threads the book id into the emitters in place of a hard-coded constant. Everything downstream of `SpellBlock` — the tokenizer core, catalog, ledger, level arithmetic — is unchanged and never learns that more than one book exists.

**Tech Stack:** Python 3 standard library only (`re`, `dataclasses`, `json`, `pathlib`, `unittest`). No third-party packages. Dart/Flutter is touched only in that regenerated JSON assets are read by the existing Flutter test suite.

**Spec:** `docs/superpowers/specs/2026-08-18-hohmc-inline-parser-design.md`

## Global Constraints

- **Never run `dart format` in this repo.** Hand-indent Dart and check with `git diff -w`.
- **Never reformat committed JSON assets.** `assets/data/base_effects.json` is one compact object per line; `parameters.json`, `container_modes.json`, `resolutions.json` and `hand_authored_templates.json` are indent-2. Match the file you are editing, exactly.
- **`flutter analyze` must exit 0.**
- **All three suites must pass before a task is complete:**
  - Python: `python -m unittest discover -s scripts/spell_import/tests -t .` (317 tests green at plan time)
  - Dart: `flutter test` (728 tests green at plan time)
  - Integration: `flutter test integration_test -d windows` (8 tests green at plan time)
  - Tasks 1–5 touch no Dart and no asset; for those, Python alone is sufficient and the plan says so per task. Tasks 6 and 7 require all three.
- **Run Python with `uv`:** `uv run --no-project python -m unittest ...`. This repo has no `pyproject.toml`.
- **Temporary files go in the session scratchpad directory, never `/tmp`.** Python on this machine resolves `/tmp` to `C:\tmp`, the drive root.
- **The extractor must never write `resolutions.json`.** `run()` only reports what widened; `migrate_ledger.py` is the only writer.
- **Anything that belongs in a generated asset but cannot be generated must live in a committed input file**, never only in the output — `--write` rebuilds the assets from the run's own output and would otherwise delete it.
- **`spells_parsed` conservation holds:** every parsed block lands in exactly one Report bucket. Adding a bucket means adding it to that sum.
- **No spell from any book but HoH:MC may enter `spell_library.json` in this pass.**
- **The rulebook checkout is licensed third-party material and is never edited.** Corrections live in this repo's typo tables.

## File Structure

**Modified — parser and registry (Tasks 1–2):**
- `scripts/spell_import/statline.py` — gains `strip_quote`, which strips blockquote markers while preserving `**`; `strip_markup` is redefined in terms of it.
- `scripts/spell_import/blocks.py` — gains `parse_inline` and `PARSERS`. `parse_de` is not modified.
- `scripts/spell_import/sources.py` — gains the `Book` dataclass, the `BOOKS` registry and `book_by_id`.

**Modified — vocabulary (Task 3):**
- `scripts/spell_import/designline.py` — five Target labels, a case-tolerant general-base pattern, one allow-list entry.
- `scripts/spell_import/emit.py` — `_resolve_requisite_label` becomes `_resolve_requisite_arts`, returning a list.

**Modified — provenance and reporting (Task 4):**
- `scripts/spell_import/provenance.py` — the lock becomes a mapping of book id to identity.
- `scripts/spell_import/report.py` — renders one report across several books.
- `scripts/spell_import/source.lock` — regenerated in the new shape.

**Modified — the run loop (Task 5):**
- `scripts/spell_import/extract_spells.py` — loops `BOOKS`, threads `book_id`, applies the skip list, checks for duplicate ids, gains `--diagnose`.

**Modified — data and curation (Task 6):**
- `assets/data/base_effects.json` — one new row, `revi-hohmc-G1`.
- `scripts/spell_import/hand_authored_templates.json` — one new template.
- `scripts/spell_import/resolutions.json` — 11 new entries, plus 4 migrated.
- `scripts/spell_import/container_modes.json` — 4 new entries.
- `assets/data/spell_library.json`, `assets/data/spell_templates.json` — regenerated.

**Tests:** `scripts/spell_import/tests/test_blocks.py`, `test_statline.py`, `test_sources.py`, `test_designline.py`, `test_emit.py`, `test_provenance.py`, `test_report.py`, `test_extract.py`, `test_catalog.py`.

---

### Task 1: The inline block parser

**Files:**
- Modify: `scripts/spell_import/statline.py:44-45` (the `strip_markup` definition)
- Modify: `scripts/spell_import/blocks.py` (append; do not edit `parse_de`)
- Test: `scripts/spell_import/tests/test_statline.py`, `scripts/spell_import/tests/test_blocks.py`

**Interfaces:**
- Consumes: `statline.is_statline`, `statline.is_damaged_statline`, `statline.parse_statline`, `blocks.SpellBlock`, `blocks._normalize_stat_line`, `blocks._DESIGN`, `blocks._REQ_CONTINUATION` — all existing.
- Produces:
  - `statline.strip_quote(line: str) -> str`
  - `blocks.parse_inline(lines: list[str]) -> tuple[list[SpellBlock], list[str]]` — same signature as `parse_de`
  - `blocks.PARSERS: dict[str, Callable[[list[str]], tuple[list[SpellBlock], list[str]]]]` with keys `"de"` and `"inline"`

**Background you need.** HoH:MC prints spell blocks in a different shape from the Definitive Edition. Most sit inside markdown blockquotes:

```
> ##### Revenge of the Bitten Toad
> PeAn 20
> R: Per, D: Diam, T: Flavor
>
> Any creatures who bite (or otherwise taste) the caster suffer a Heavy Wound...
>
> (Base 15, +1 Diam)
```

The `PeAn 20` line carries technique, form and printed level, so no section-heading state machine is needed. `parse_de`'s `_SECTION` and `_LEVEL` machinery has no analogue here — do not try to reuse it.

Three shapes vary and all three occur in the book:
1. Blockquoted (`> `-prefixed) or plain. `statline.strip_markup` already strips `> `, which is why all 16 stat lines already parse today.
2. The name is usually `##### Name`, but *Ball of Abysmal Music* uses `**Ball of Abysmal Music**`. Both must work.
3. **A blank line may sit between the name and the `TeFo Level` line.** *Revenge of the Bitten Toad* has none; *Perceive the Change* has one. The name search must walk upward past blank lines.

- [ ] **Step 1: Write the failing test for `strip_quote`**

Add to `scripts/spell_import/tests/test_statline.py`:

```python
    def test_strip_quote_removes_blockquote_but_keeps_bold(self):
        self.assertEqual(statline.strip_quote("> **Ball of Abysmal Music**"),
                         "**Ball of Abysmal Music**")

    def test_strip_quote_removes_nested_blockquote_markers(self):
        self.assertEqual(statline.strip_quote("> > MuIm 20"), "MuIm 20")

    def test_strip_markup_still_removes_bold(self):
        self.assertEqual(statline.strip_markup("> **MuIm 20**"), "MuIm 20")
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_statline -v`
Expected: FAIL — `AttributeError: module 'scripts.spell_import.statline' has no attribute 'strip_quote'`

- [ ] **Step 3: Add `strip_quote` and redefine `strip_markup` in terms of it**

Replace `scripts/spell_import/statline.py:44-45`:

```python
def strip_markup(line: str) -> str:
    return _BOLD.sub("", _BR.sub("", _LEADING.sub("", line))).strip()
```

with:

```python
def strip_quote(line: str) -> str:
    """Blockquote markers and <br> removed; emphasis markup preserved.

    `strip_markup` removes `**` too, which is exactly wrong when the question
    being asked is "is this line a bold-only spell name?" -- by the time the
    asterisks are gone, `**Ball of Abysmal Music**` is indistinguishable from
    a line of prose. blocks.parse_inline needs the distinction.
    """
    return _BR.sub("", _LEADING.sub("", line)).rstrip()


def strip_markup(line: str) -> str:
    return _BOLD.sub("", strip_quote(line)).strip()
```

- [ ] **Step 4: Run the statline tests to confirm they pass**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_statline -v`
Expected: PASS, including every pre-existing test in the file — `strip_markup`'s behaviour must be unchanged.

- [ ] **Step 5: Write the failing test for `parse_inline`**

Add to `scripts/spell_import/tests/test_blocks.py`. The first class parses the real book, mirroring how `ParseDefinitiveEditionTest` treats the core rules; the second uses fixtures so the edge cases are pinned without depending on the rulebook's wording.

```python
HOHMC_TITLE = "Ars Magica 5e - Houses of Hermes - Mystery Cults"


class ParseInlineAgainstMysteryCultsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lines = sources.read_lines(sources.resolve_book(HOHMC_TITLE))
        cls.blocks, cls.problems = blocks.parse_inline(lines)

    def test_finds_all_sixteen_blocks(self):
        # 16 stat lines in the book, all 16 anchored. Two of these are not
        # importable spells and are excluded later, in run()'s skip list --
        # the parser's job is to find blocks, not to judge them.
        self.assertEqual(len(self.blocks), 16)

    def test_reports_no_parse_problems(self):
        self.assertEqual(self.problems, [])

    def test_a_blockquoted_block_parses_completely(self):
        block = next(b for b in self.blocks if b.name == "Revenge of the Bitten Toad")
        self.assertEqual((block.technique, block.form), ("Perdo", "Animal"))
        self.assertEqual(block.printed_level, 20)
        self.assertEqual(block.stat.target_name, "Flavor")
        self.assertEqual(block.design_line, "(Base 15, +1 Diam)")

    def test_a_plain_unquoted_block_parses_completely(self):
        block = next(b for b in self.blocks if b.name == "The Voice of the Bjornaer Magus")
        self.assertEqual((block.technique, block.form), ("Muto", "Animal"))
        self.assertEqual(block.printed_level, 15)
        self.assertEqual(block.design_line, "(Base 5, +2 Sun)")

    def test_a_bold_named_block_is_found(self):
        # Ball of Abysmal Music is the one spell headed **Name** rather than
        # ##### Name. Rejecting it would lose a real spell to typesetting.
        block = next(b for b in self.blocks if b.name == "Ball of Abysmal Music")
        self.assertEqual((block.technique, block.form), ("Muto", "Imaginem"))
        self.assertEqual(block.printed_level, 20)

    def test_a_blank_line_between_name_and_anchor_is_tolerated(self):
        # Perceive the Change has a blank blockquote line between its heading
        # and its InAn 14 line; Revenge of the Bitten Toad has none.
        block = next(b for b in self.blocks if b.name == "Perceive the Change")
        self.assertEqual((block.technique, block.form), ("Intellego", "Animal"))

    def test_general_level_blocks_have_no_printed_level(self):
        general = sorted(b.name for b in self.blocks if b.printed_level is None)
        self.assertEqual(general, [
            "Facilitate the Stifled (Form) Spell",
            "Faerie Chains of the Familiar Slave",
            "The Rooster's Crow",
            "Tie the Threads That Bind",
        ])

    def test_a_design_line_separated_by_paragraphs_is_still_found(self):
        # Form of the (Temperament) Heartbeast prints four variant paragraphs
        # between its stat line and its design line. A fixed-size lookahead
        # window would miss it.
        block = next(b for b in self.blocks
                     if b.name == "Form of the (Temperament) Heartbeast")
        self.assertEqual(block.design_line, "(Base 5, +2 Sun; +1 complexity)")

    def test_a_requisite_continuation_line_is_folded_in(self):
        # Embrace of Boethius prints "Req: Vim, Corpus" on its own line below
        # the stat line, the same shape parse_de already folds.
        block = next(b for b in self.blocks if b.name == "Embrace of Boethius")
        self.assertEqual(block.stat.requisite_arts, ["Vim", "Corpus"])
        self.assertTrue(block.stat.is_ritual)


class ParseInlineFixtureTest(unittest.TestCase):
    def test_a_stat_line_with_no_anchor_above_it_is_skipped(self):
        lines = [
            "Some prose about a creature.",
            "",
            "R: Touch, D: Sun, T: Ind",
            "",
            "(Base 5, +2 Sun)",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(found, [])
        self.assertEqual(problems, [])

    def test_an_anchor_with_no_name_above_it_is_skipped(self):
        lines = [
            "Just prose, not a name.",
            "MuAn 15",
            "R: Per, D: Sun, T: Ind",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(found, [])
        self.assertEqual(problems, [])

    def test_two_adjacent_blocks_do_not_bleed_into_each_other(self):
        lines = [
            "##### First Spell",
            "MuAn 15",
            "R: Per, D: Sun, T: Ind",
            "",
            "Prose for the first.",
            "",
            "(Base 5, +2 Sun)",
            "",
            "##### Second Spell",
            "PeAn 20",
            "R: Per, D: Diam, T: Ind",
            "",
            "Prose for the second.",
            "",
            "(Base 15, +1 Diam)",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(problems, [])
        self.assertEqual([b.name for b in found], ["First Spell", "Second Spell"])
        self.assertEqual(found[0].design_line, "(Base 5, +2 Sun)")
        self.assertEqual(found[0].prose, "Prose for the first.")
        self.assertEqual(found[1].design_line, "(Base 15, +1 Diam)")
        self.assertEqual(found[1].prose, "Prose for the second.")

    def test_a_block_with_no_design_line_still_parses(self):
        lines = [
            "##### Lonely Spell",
            "MuAn 15",
            "R: Per, D: Sun, T: Ind",
            "",
            "Prose with no design line.",
            "",
            "#### Some Other Section",
        ]
        found, problems = blocks.parse_inline(lines)
        self.assertEqual(problems, [])
        self.assertEqual(len(found), 1)
        self.assertIsNone(found[0].design_line)

    def test_parsers_registry_exposes_both_styles(self):
        self.assertEqual(sorted(blocks.PARSERS), ["de", "inline"])
        self.assertIs(blocks.PARSERS["de"], blocks.parse_de)
        self.assertIs(blocks.PARSERS["inline"], blocks.parse_inline)
```

- [ ] **Step 6: Run it to confirm it fails**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_blocks -v`
Expected: FAIL — `AttributeError: module 'scripts.spell_import.blocks' has no attribute 'parse_inline'`

- [ ] **Step 7: Implement `parse_inline`**

Append to `scripts/spell_import/blocks.py`, after `parse_de`. Do not modify `parse_de` — it imports 325 working spells, and generalising it into a mode-switching parser is explicitly not the design.

```python
# The inline anchor: "PeAn 20" or "MuVi Gen" on its own line, directly above
# the stat line. Unlike the Definitive Edition's "### Creo Animal Spells" +
# "#### LEVEL 20" pair, this one line carries Technique, Form and printed
# level together, so parse_inline needs no section state at all.
_INLINE_ANCHOR = re.compile(
    r"^(?P<technique>Cr|In|Mu|Pe|Re)(?P<form>An|Aq|Au|Co|He|Ig|Im|Me|Te|Vi)\s+"
    r"(?:(?P<level>\d+)|(?P<general>Gen))\s*$"
)
_HEADING = re.compile(r"^#{1,6}\s")
# A name printed as bold text rather than a heading. Ball of Abysmal Music is
# the only HoH:MC spell headed this way. The `$` anchor is what keeps this
# from swallowing "**Dutiful Movement:** The automaton can walk..." -- a bold
# run followed by prose is a labelled paragraph, not a spell name.
_BOLD_NAME = re.compile(r"^\*\*(?P<name>.+?)\*\*\s*$")

_TECHNIQUE_NAMES = {
    "Cr": "Creo", "In": "Intellego", "Mu": "Muto", "Pe": "Perdo", "Re": "Rego",
}
_FORM_NAMES = {
    "An": "Animal", "Aq": "Aquam", "Au": "Auram", "Co": "Corpus",
    "He": "Herbam", "Ig": "Ignem", "Im": "Imaginem", "Me": "Mentem",
    "Te": "Terram", "Vi": "Vim",
}


def _inline_anchor(lines: list[str], index: int):
    """The `TeFo Level` match at `index`, or None."""
    if index < 0:
        return None
    return _INLINE_ANCHOR.match(statline.strip_markup(lines[index]))


def _inline_name_above(lines: list[str], start: int) -> str | None:
    """The spell name at or above `start`, skipping blank lines.

    Returns None as soon as a non-blank line that is not a name is reached,
    so ordinary prose above an anchor cannot be mistaken for a heading. The
    blank-skipping is not defensive: Perceive the Change has a blank
    blockquote line between its heading and its anchor, and Revenge of the
    Bitten Toad has none.
    """
    cursor = start
    while cursor >= 0:
        quoted = statline.strip_quote(lines[cursor])
        if not quoted.strip():
            cursor -= 1
            continue
        cleaned = statline.strip_markup(lines[cursor])
        # Any heading level, not just `#####`: parse_de's _NAME is specific to
        # the Definitive Edition's own nesting, and the supplements do not
        # share it.
        if _HEADING.match(cleaned):
            return _HEADING.sub("", cleaned).strip()
        bold = _BOLD_NAME.match(quoted)
        if bold is not None:
            return statline.strip_markup(bold.group("name"))
        return None
    return None


def parse_inline(lines: list[str]) -> tuple[list[SpellBlock], list[str]]:
    """Assemble spell blocks anchored on an inline `TeFo Level` line.

    Used by supplements rather than the Definitive Edition. The anchor is the
    stat line, as always; what discriminates a spell from a creature power
    here is the `TeFo Level` line directly above it, with the name above that
    as either a heading or a bold run.

    A stat line with no anchor above it is skipped in silence, exactly as
    parse_de skips creature and elemental powers. Across the corpus those
    unanchored blocks are overwhelmingly enchanted-device effects and NPC
    spell lists rather than spells, so reporting each one would bury the
    genuine problems.
    """
    problems: list[str] = []
    found: list[SpellBlock] = []

    for index, raw in enumerate(lines):
        if statline.is_damaged_statline(raw):
            if _inline_anchor(lines, index - 1) is not None:
                problems.append(f"line {index + 1}: damaged stat line {raw.strip()!r}")
            continue

        if not statline.is_statline(raw):
            continue

        anchor = _inline_anchor(lines, index - 1)
        if anchor is None:
            continue

        name = _inline_name_above(lines, index - 2)
        if name is None:
            continue

        technique = _TECHNIQUE_NAMES[anchor.group("technique")]
        form = _FORM_NAMES[anchor.group("form")]
        level = None if anchor.group("general") else int(anchor.group("level"))

        normalized = _normalize_stat_line(raw)
        folded = statline.strip_markup(normalized)

        # Identical to parse_de's fold: look past blank lines for a `Req:`
        # continuation printed on its own line and splice it into the stat
        # line, so parse_statline keeps seeing one logical line.
        prose_start = index + 1
        cursor = prose_start
        while cursor < len(lines) and not statline.strip_markup(lines[cursor]):
            cursor += 1
        if cursor < len(lines):
            candidate = statline.strip_markup(lines[cursor])
            if _REQ_CONTINUATION.match(candidate):
                folded = f"{folded}, {candidate}"
                prose_start = cursor + 1

        try:
            stat = statline.parse_statline(folded)
        except ValueError as e:
            problems.append(f"line {index + 1}: {e}")
            continue

        prose_lines: list[str] = []
        design: str | None = None
        cursor = prose_start
        while cursor < len(lines):
            candidate = statline.strip_markup(lines[cursor])
            if _DESIGN.match(candidate):
                design = candidate
                break
            # Stop at the next block or section. The scan is bounded by
            # structure rather than a line count on purpose: Form of the
            # (Temperament) Heartbeast prints four variant paragraphs between
            # its stat line and its design line.
            if _HEADING.match(candidate) or _BOLD_NAME.match(
                    statline.strip_quote(lines[cursor])):
                break
            if candidate:
                prose_lines.append(candidate)
            cursor += 1

        found.append(SpellBlock(
            name=name,
            technique=technique,
            form=form,
            printed_level=level,
            stat=stat,
            prose=" ".join(prose_lines),
            design_line=design,
            line_no=index + 1,
        ))

    return found, problems


PARSERS = {
    "de": parse_de,
    "inline": parse_inline,
}
```

- [ ] **Step 8: Run the block tests to confirm they pass**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_blocks -v`
Expected: PASS, all classes. If `test_finds_all_sixteen_blocks` reports fewer than 16, print the names found and diff against the expected 16 rather than loosening the assertion.

- [ ] **Step 9: Run the whole Python suite**

Run: `uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS. `parse_de` is untouched and `strip_markup`'s behaviour is unchanged, so the pre-existing 317 must all still pass.

- [ ] **Step 10: Commit**

```bash
git add scripts/spell_import/statline.py scripts/spell_import/blocks.py scripts/spell_import/tests/test_statline.py scripts/spell_import/tests/test_blocks.py
git commit -m "feat: parse inline TeFo-anchored spell blocks

parse_de anchors on the Definitive Edition's heading structure and sees
zero of HoH:MC's 16 blocks. parse_inline stands beside it, anchoring on
the 'PeAn 20' line the supplements print directly above the stat line,
with the name above that as either a heading or a bold run.

strip_quote is split out of strip_markup because deciding whether a line
is a bold-only spell name requires seeing the asterisks."
```

---

### Task 2: The book registry

**Files:**
- Modify: `scripts/spell_import/sources.py` (append after `DE_TITLE`)
- Test: `scripts/spell_import/tests/test_sources.py`

**Interfaces:**
- Consumes: `blocks.PARSERS` (Task 1), `sources.DE_TITLE` (existing).
- Produces:
  - `sources.Book` — frozen dataclass with fields `id: str`, `title: str`, `parser: str`
  - `sources.BOOKS: tuple[Book, ...]`
  - `sources.book_by_id(book_id: str) -> Book` — raises `KeyError` for an unknown id

**Why the core book only, for now.** `BOOKS` holds one entry in this task. HoH:MC joins it in Task 6, together with the ledger entries and catalog row it needs — switching it on earlier would leave the extractor unable to resolve 11 spells and the suite red for four tasks.

- [ ] **Step 1: Write the failing test**

Add to `scripts/spell_import/tests/test_sources.py`:

```python
import json
import pathlib
import unittest

from scripts.spell_import import blocks, catalog as catalog_module, sources


class BookRegistryTest(unittest.TestCase):
    def test_every_registered_book_id_is_a_known_book(self):
        """The registry's ids are what emitted citations carry.

        assets/data/books.json is the app's own list of books; a registry id
        absent from it would emit a citation pointing at nothing, and no
        other test joins those two files.
        """
        path = catalog_module.DATA_DIR / "books.json"
        known = {b["id"] for b in json.loads(path.read_text(encoding="utf-8"))}
        for book in sources.BOOKS:
            self.assertIn(book.id, known, msg=book.title)

    def test_every_registered_parser_exists(self):
        for book in sources.BOOKS:
            self.assertIn(book.parser, blocks.PARSERS, msg=book.id)

    def test_every_registered_book_resolves_to_a_markdown_copy(self):
        for book in sources.BOOKS:
            self.assertTrue(sources.resolve_book(book.title).is_file(), msg=book.id)

    def test_book_ids_are_unique(self):
        ids = [b.id for b in sources.BOOKS]
        self.assertEqual(sorted(ids), sorted(set(ids)))

    def test_the_core_book_is_registered_with_the_de_parser(self):
        core = sources.book_by_id("arm5-core")
        self.assertEqual(core.title, sources.DE_TITLE)
        self.assertEqual(core.parser, "de")

    def test_book_by_id_rejects_an_unknown_id(self):
        with self.assertRaises(KeyError):
            sources.book_by_id("arm5-nonesuch")
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_sources -v`
Expected: FAIL — `AttributeError: module 'scripts.spell_import.sources' has no attribute 'BOOKS'`

- [ ] **Step 3: Add the registry**

Append to `scripts/spell_import/sources.py`, after the `DE_TITLE` assignment:

```python
@dataclasses.dataclass(frozen=True)
class Book:
    """A book the importer reads, and how to read it.

    `title` is the markdown filename stem in the rulebook checkout, which is
    NOT the display title assets/data/books.json carries -- the checkout
    writes "Houses of Hermes - Mystery Cults" where books.json says
    "Houses of Hermes: Mystery Cults". Deriving one from the other would be a
    guess about punctuation across 54 filenames, so the mapping is explicit
    and a test joins the two files.
    """
    id: str      # the assets/data/books.json id, e.g. "arm5-hohmc"
    title: str   # the markdown filename stem in the rulebook checkout
    parser: str  # a key into blocks.PARSERS


BOOKS: tuple[Book, ...] = (
    Book(id="arm5-core", title=DE_TITLE, parser="de"),
)


def book_by_id(book_id: str) -> Book:
    for book in BOOKS:
        if book.id == book_id:
            return book
    raise KeyError(f"no registered book with id {book_id!r}")
```

`dataclasses` is not currently imported by `sources.py`. Add `import dataclasses` to the import block at the top, keeping the existing alphabetical order (`dataclasses`, `difflib`, `os`, `pathlib`).

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_sources -v`
Expected: PASS

- [ ] **Step 5: Run the whole Python suite**

Run: `uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/sources.py scripts/spell_import/tests/test_sources.py
git commit -m "feat: add a per-book registry naming each book's parser

One entry for now. HoH:MC joins in the commit that also carries the
ledger entries and catalog row it needs, so the extractor is never left
unable to resolve a book it has been told to read.

The registry title is the checkout's filename stem, not books.json's
display title -- they differ in punctuation, and a test joins them."
```

---

### Task 3: Design-line vocabulary and plural requisites

**Files:**
- Modify: `scripts/spell_import/designline.py:15-16` (`_BASE_GENERAL`), `:60-64` (`_BARE_REQUISITE_LABELS`), `:66-85` (`PARAMETER_LABELS`)
- Modify: `scripts/spell_import/emit.py:134-155` (`_resolve_requisite_label`), `:176`, `:314`
- Test: `scripts/spell_import/tests/test_designline.py`, `scripts/spell_import/tests/test_emit.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `emit._resolve_requisite_arts(token, block) -> list[str]`, replacing `emit._resolve_requisite_label(token, block) -> str`.

**Background.** Only 4 of HoH:MC's 16 design lines tokenize today. Four narrow changes fix every one belonging to an importable spell. The first is a gap item 64 left: it added five Targets to `parameters.json` but never taught the tokenizer their design-line labels, so `+2 Scent` and its siblings raise `UnknownToken` and block 7 spells.

- [ ] **Step 1: Write the failing tests for the vocabulary**

Add to `scripts/spell_import/tests/test_designline.py`:

```python
    def test_sensory_target_magnitudes_tokenize(self):
        # Item 64 put these five Targets in parameters.json but not in the
        # tokenizer's label table, so every spell using one blocked.
        for label, name in [("Flavor", "Flavor"), ("Texture", "Texture"),
                            ("Scent", "Scent"), ("Sound", "Sound"),
                            ("Spectacle", "Spectacle")]:
            with self.subTest(label):
                design = designline.parse_design(f"(Base 5, +2 {label})")
                labels = [t.label for t in design.tokens if t.kind == "parameter"]
                self.assertIn(name, labels)

    def test_a_capitalised_base_effect_is_a_general_base(self):
        # Tie the Threads That Bind prints "(Base Effect, ...)"; every core
        # spell prints "(Base effect, ...)".
        design = designline.parse_design("(Base Effect, +1 Touch, +2 Group)")
        self.assertIsNone(design.base_level)

    def test_a_lowercase_base_effect_is_still_a_general_base(self):
        design = designline.parse_design("(Base effect, +1 Touch)")
        self.assertIsNone(design.base_level)

    def test_necessary_requisites_is_a_bare_requisite_token(self):
        design = designline.parse_design(
            "(Base 15, + 1 Touch, +1 Part, +2 necessary requisites)")
        bare = [t for t in design.tokens if t.kind == "requisite"]
        self.assertEqual(len(bare), 1)
        self.assertEqual(bare[0].magnitude, 2)
        self.assertEqual(bare[0].label, "")
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_designline -v`
Expected: FAIL with `UnknownToken: unrecognised token '+2 Flavor'` and `UnknownToken: unrecognised base term 'Base Effect'`

- [ ] **Step 3: Make the three vocabulary changes**

In `scripts/spell_import/designline.py`, change `_BASE_GENERAL` from:

```python
_BASE_GENERAL = re.compile(
    r"^Base\s+(effect|spell)\b|^Base$|^As\s+ward\s+guideline$")
```

to:

```python
# "Base Effect" (Tie the Threads That Bind, HoH:MC) alongside the core
# rulebook's "Base effect". Spelled out rather than re.IGNORECASE, which
# would also loosen the `Base` and `As ward guideline` alternatives this
# pattern shares -- "BASE" and "as WARD guideline" are not corpus wordings.
_BASE_GENERAL = re.compile(
    r"^Base\s+([Ee]ffect|[Ss]pell)\b|^Base$|^As\s+ward\s+guideline$")
```

In `_BARE_REQUISITE_LABELS`, add one entry with its justification:

```python
_BARE_REQUISITE_LABELS = frozenset({
    "requisite",
    "requisites",
    "extra effect from requisite",
    # Embrace of Boethius (HoH:MC) charges "+2 necessary requisites" against
    # its two declared Req: arts. A closed entry rather than a pattern, the
    # same discipline as the rest of this set: the phrasing occurs exactly
    # once across all 54 books in the corpus.
    "necessary requisites",
})
```

In `PARAMETER_LABELS`, add the five sensory Targets beside the existing sense Targets:

```python
    "Taste": "Taste", "Smell": "Smell", "Hearing": "Hearing", "Vision": "Vision",
    # Sensory Magic Targets (HoH:MC, catalog rows added by todo item 64).
    # The Targets landed in parameters.json without their design-line labels,
    # which blocked all seven spells that use one.
    "Flavor": "Flavor", "Texture": "Texture", "Scent": "Scent",
    "Sound": "Sound", "Spectacle": "Spectacle",
```

- [ ] **Step 4: Run the designline tests to confirm they pass**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_designline -v`
Expected: PASS

- [ ] **Step 5: Write the failing test for plural requisites**

Add to `scripts/spell_import/tests/test_emit.py`. Build the token and block with whatever helpers that file already uses for `designline.Token` and `blocks.SpellBlock`; if it has none, construct them directly — `statline.StatLine` takes `range_name`, `duration_name`, `target_name`, `is_ritual`, `requisite_arts`, `trailing`.

```python
    def _block_with_requisites(self, arts):
        return blocks.SpellBlock(
            name="Test Spell", technique="Perdo", form="Mentem",
            printed_level=35,
            stat=statline.StatLine(
                range_name="Touch", duration_name="Mom", target_name="Part",
                is_ritual=True, requisite_arts=list(arts), trailing=""),
            prose="", design_line=None, line_no=1)

    def test_a_labelled_requisite_token_resolves_to_its_own_art(self):
        token = designline.Token(kind="requisite", magnitude=1, label="Creo")
        arts = emit._resolve_requisite_arts(token, self._block_with_requisites(["Creo"]))
        self.assertEqual(arts, ["Creo"])

    def test_a_bare_requisite_token_resolves_to_the_sole_declared_art(self):
        token = designline.Token(kind="requisite", magnitude=1, label="")
        arts = emit._resolve_requisite_arts(token, self._block_with_requisites(["Vim"]))
        self.assertEqual(arts, ["Vim"])

    def test_a_bare_token_splits_across_arts_when_the_count_matches(self):
        # Embrace of Boethius: Req: Vim, Corpus and "+2 necessary requisites".
        # Two arts, magnitude two -- +1 each is the book's own arithmetic.
        token = designline.Token(kind="requisite", magnitude=2, label="")
        block = self._block_with_requisites(["Vim", "Corpus"])
        self.assertEqual(emit._resolve_requisite_arts(token, block), ["Vim", "Corpus"])

    def test_a_bare_token_still_raises_when_the_count_does_not_match(self):
        # Three magnitudes across two arts is a distribution nothing in the
        # design line states. Guessing it is exactly what this must not do.
        token = designline.Token(kind="requisite", magnitude=3, label="")
        block = self._block_with_requisites(["Vim", "Corpus"])
        with self.assertRaises(designline.UnknownToken):
            emit._resolve_requisite_arts(token, block)

    def test_a_bare_token_still_raises_when_no_art_is_declared(self):
        token = designline.Token(kind="requisite", magnitude=1, label="")
        with self.assertRaises(designline.UnknownToken):
            emit._resolve_requisite_arts(token, self._block_with_requisites([]))
```

If `designline.Token`'s constructor signature differs from `kind`/`magnitude`/`label`, read it and match it — do not change the dataclass.

- [ ] **Step 6: Run it to confirm it fails**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_emit -v`
Expected: FAIL — `AttributeError: module 'scripts.spell_import.emit' has no attribute '_resolve_requisite_arts'`

- [ ] **Step 7: Replace `_resolve_requisite_label` with `_resolve_requisite_arts`**

In `scripts/spell_import/emit.py`, replace the whole of `_resolve_requisite_label` (lines 134-155) with:

```python
def _resolve_requisite_arts(token, block) -> list[str]:
    """The arts a `kind="requisite"` token belongs to.

    Usually just `[token.label]` -- designline.py already resolved it from
    the design line's own text. The exception is a bare requisite token, e.g.
    "+N requisite" or "+N necessary requisites"
    (designline._BARE_REQUISITE_LABELS), which carries an empty label because
    designline.py never sees the Req: line and so cannot know which art the
    magnitude belongs to.

    Resolving it here, against `block.stat`, is safe in exactly two shapes.
    One declared art takes the whole magnitude. Several declared arts take it
    only when the magnitude equals how many there are, which makes +1 each
    the book's own arithmetic rather than an inference -- Embrace of Boethius
    declares Req: Vim, Corpus and charges "+2 necessary requisites". Any
    other ratio raises, the same discipline as every other closed-allow-list
    decision in this pipeline: a distribution the design line does not state
    is not one this importer may guess at.
    """
    if token.label:
        return [token.label]
    arts = block.stat.requisite_arts
    if len(arts) == 1:
        return list(arts)
    if arts and token.magnitude == len(arts):
        return list(arts)
    raise designline.UnknownToken(
        f"{block.name}: a bare requisite token of magnitude {token.magnitude} "
        f"needs either exactly one Req: art or as many arts as magnitudes, "
        f"found {arts!r}"
    )
```

Then update both call sites. At `emit.py:176` (in `build_spell`) and `emit.py:314` (in `build_template`), replace:

```python
        if token.kind == "requisite" and token.label != "free":
            art = _resolve_requisite_label(token, block)
            requisites.setdefault(art, "adding" if token.magnitude else "free")
```

with:

```python
        if token.kind == "requisite" and token.label != "free":
            for art in _resolve_requisite_arts(token, block):
                requisites.setdefault(art, "adding" if token.magnitude else "free")
```

Search the file for any remaining reference to `_resolve_requisite_label` and update it; there should be exactly two call sites.

- [ ] **Step 8: Run the emit tests to confirm they pass**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_emit -v`
Expected: PASS

- [ ] **Step 9: Run the whole Python suite, and check the extractor still imports 325**

```bash
uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .
uv run --no-project python -m scripts.spell_import.extract_spells
```
Expected: suite PASS; extractor prints `imported : 325`, `blocked : 0`, `unresolved: 0`. None of these changes may move the core book's numbers — if `imported` shifts, a vocabulary entry has changed how an existing spell tokenizes and must be narrowed.

- [ ] **Step 10: Commit**

```bash
git add scripts/spell_import/designline.py scripts/spell_import/emit.py scripts/spell_import/tests/test_designline.py scripts/spell_import/tests/test_emit.py
git commit -m "feat: teach the tokenizer the sensory Targets and plural requisites

Item 64 added five Sensory Magic Targets to parameters.json without
their design-line labels, so '+2 Scent' and its siblings blocked seven
HoH:MC spells at the tokenizer.

_resolve_requisite_arts returns a list so a bare token can cover several
declared arts, but only when the magnitude equals how many there are --
any other ratio still raises rather than guessing a distribution."
```

---

### Task 4: Per-book provenance lock

**Files:**
- Modify: `scripts/spell_import/provenance.py:113-140` (`load`, `write`, `matches`, `describe_change`)
- Modify: `scripts/spell_import/report.py:57-125` (`render`)
- Modify: `scripts/spell_import/source.lock` (regenerated in Task 5; leave alone here)
- Test: `scripts/spell_import/tests/test_provenance.py`, `scripts/spell_import/tests/test_report.py`

**Interfaces:**
- Consumes: `sources.Book` (Task 2).
- Produces:
  - `provenance.load(path=LOCK_PATH) -> dict[str, SourceIdentity]` — empty dict when the file is absent
  - `provenance.write(identities: dict[str, SourceIdentity], path=LOCK_PATH) -> None`
  - `provenance.matches(lock: dict[str, SourceIdentity], current: SourceIdentity) -> bool` — looks the book up by `current.book`
  - `provenance.describe_change(lock: dict[str, SourceIdentity], current: SourceIdentity) -> str`
  - `report.render(...)` takes `locks: dict[str, SourceIdentity]` and `currents: list[SourceIdentity]` in place of the single `lock`/`current` pair

**Note on the lock's key.** `SourceIdentity.book` holds the *title*, not the book id. Key the lock by book id, which is stable across a filename change in the checkout, and let `matches` look up `current.book`… which is a title. Resolve this by adding the id to `SourceIdentity`: give it a `book_id: str` field, serialized as `"bookId"`, and key the lock dict by that. `describe` gains a `book_id` parameter.

- [ ] **Step 1: Write the failing tests**

Add to `scripts/spell_import/tests/test_provenance.py`:

```python
    def _identity(self, book_id="arm5-core", sha="abc123"):
        return provenance.SourceIdentity(
            book_id=book_id, book="A Book", path="reviewed/A Book.md",
            sha256=sha, rulebook=None, spells_parsed=10, spells_imported=9)

    def test_the_lock_round_trips_several_books(self):
        path = pathlib.Path(self.tmpdir) / "source.lock"
        identities = {
            "arm5-core": self._identity("arm5-core", "aaa"),
            "arm5-hohmc": self._identity("arm5-hohmc", "bbb"),
        }
        provenance.write(identities, path)
        loaded = provenance.load(path)
        self.assertEqual(sorted(loaded), ["arm5-core", "arm5-hohmc"])
        self.assertEqual(loaded["arm5-hohmc"].sha256, "bbb")

    def test_an_absent_lock_loads_as_an_empty_mapping(self):
        path = pathlib.Path(self.tmpdir) / "nonesuch.lock"
        self.assertEqual(provenance.load(path), {})

    def test_matches_compares_the_named_book_only(self):
        lock = {"arm5-core": self._identity("arm5-core", "aaa"),
                "arm5-hohmc": self._identity("arm5-hohmc", "bbb")}
        self.assertTrue(provenance.matches(lock, self._identity("arm5-hohmc", "bbb")))
        self.assertFalse(provenance.matches(lock, self._identity("arm5-hohmc", "ccc")))

    def test_a_book_absent_from_the_lock_does_not_match(self):
        lock = {"arm5-core": self._identity("arm5-core", "aaa")}
        self.assertFalse(provenance.matches(lock, self._identity("arm5-hohmc", "bbb")))

    def test_describe_change_names_the_book_that_moved(self):
        lock = {"arm5-hohmc": self._identity("arm5-hohmc", "bbb")}
        message = provenance.describe_change(lock, self._identity("arm5-hohmc", "ccc"))
        self.assertIn("arm5-hohmc", message)
```

The test class needs a temporary directory. If `test_provenance.py` has no `setUp` creating one, add:

```python
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmpdir, ignore_errors=True)
```

with `import shutil`, `import tempfile`, `import pathlib` at the top.

- [ ] **Step 2: Run them to confirm they fail**

Run: `uv run --no-project python -m unittest scripts.spell_import.tests.test_provenance -v`
Expected: FAIL — `TypeError: SourceIdentity.__init__() got an unexpected keyword argument 'book_id'`

- [ ] **Step 3: Add `book_id` to `SourceIdentity` and make the lock a mapping**

In `scripts/spell_import/provenance.py`, add `book_id` as the first field of `SourceIdentity` and carry it through `to_dict`/`from_dict`:

```python
@dataclasses.dataclass(frozen=True)
class SourceIdentity:
    book_id: str
    book: str
    path: str
    sha256: str
    rulebook: RulebookRevision | None
    spells_parsed: int | None = None
    spells_imported: int | None = None

    def to_dict(self) -> dict:
        return {
            "bookId": self.book_id,
            "book": self.book,
            "path": self.path,
            "sha256": self.sha256,
            "rulebook": None if self.rulebook is None else dataclasses.asdict(self.rulebook),
            "spellsParsed": self.spells_parsed,
            "spellsImported": self.spells_imported,
        }

    @classmethod
    def from_dict(cls, raw: dict) -> "SourceIdentity":
        revision = raw.get("rulebook")
        return cls(
            book_id=raw["bookId"],
            book=raw["book"],
            path=raw["path"],
            sha256=raw["sha256"],
            rulebook=None if revision is None else RulebookRevision(**revision),
            spells_parsed=raw.get("spellsParsed"),
            spells_imported=raw.get("spellsImported"),
        )
```

`describe` gains the id as its first parameter:

```python
def describe(
    book_id: str,
    book: str,
    path: pathlib.Path,
    root: pathlib.Path,
    parsed: int | None = None,
    imported: int | None = None,
) -> SourceIdentity:
    relative = path.relative_to(root).as_posix()
    return SourceIdentity(
        book_id=book_id,
        book=book,
        path=relative,
        sha256=sha256_of(path),
        rulebook=git_revision(root, relative),
        spells_parsed=parsed,
        spells_imported=imported,
    )
```

Replace `load`, `write` and `matches`:

```python
def load(path: pathlib.Path = LOCK_PATH) -> dict[str, SourceIdentity]:
    """Every recorded book, by id. An absent lock is an empty mapping.

    A mapping rather than a single identity because the importer reads more
    than one book, and a book that has not moved must not be re-attested
    because a different one did.
    """
    if not path.is_file():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {book_id: SourceIdentity.from_dict(entry) for book_id, entry in raw.items()}


def write(identities: dict[str, SourceIdentity], path: pathlib.Path = LOCK_PATH) -> None:
    payload = {book_id: identities[book_id].to_dict() for book_id in sorted(identities)}
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def matches(lock: dict[str, SourceIdentity], current: SourceIdentity) -> bool:
    """Only the hash decides, and only for the book being asked about."""
    recorded = lock.get(current.book_id)
    return recorded is not None and recorded.sha256 == current.sha256
```

And `describe_change`, so the message names the book:

```python
def describe_change(lock: dict[str, SourceIdentity], current: SourceIdentity) -> str:
    accept = "  python -m scripts.spell_import.extract_spells --write --accept-source"
    recorded = lock.get(current.book_id)
    if recorded is None:
        return (
            f"source.lock has no record of {current.book_id} ({current.book}), so "
            "the rulebook revision behind the generated assets is unrecorded.\n\n"
            f"  current  : {current.label()}\n"
            f"             {current.spells_parsed} parsed\n\n"
            "Create it, reviewing the result:\n" + accept
        )
    return (
        f"the source for {current.book_id} ({current.book}) moved since the "
        "generated assets were built.\n\n"
        f"  recorded : {recorded.label()}\n"
        f"             {recorded.spells_parsed} parsed, "
        f"{recorded.spells_imported} imported\n"
        f"  current  : {current.label()}\n"
        f"             {current.spells_parsed} parsed\n\n"
        "This is not a code failure. Regenerate and review:\n" + accept
    )
```

- [ ] **Step 4: Update `report.render` for several books**

In `scripts/spell_import/report.py`, change `render`'s signature and its identity header. Replace the `lock`/`current` parameters with:

```python
def render(
    diff: AssetDiff,
    locks: dict[str, provenance.SourceIdentity],
    currents: list[provenance.SourceIdentity],
    imported: int,
    blocked: int,
    unresolved: int,
    old_design_lines: dict[str, str] | None = None,
    new_design_lines: dict[str, str] | None = None,
) -> str:
    lines = ["# Import change report", ""]

    for current in sorted(currents, key=lambda i: i.book_id):
        recorded = locks.get(current.book_id)
        lines.append(f"## {current.book} (`{current.book_id}`)")
        if recorded is None:
            lines.append(f"Initial import at {current.label().splitlines()[0]}")
            lines.append(f"Parsed {current.spells_parsed}")
        else:
            old_commit = "unknown" if recorded.rulebook is None else recorded.rulebook.commit
            new_commit = "unknown" if current.rulebook is None else current.rulebook.commit
            subject = "" if current.rulebook is None else f' ("{current.rulebook.subject}")'
            lines.append(f"Source: {old_commit} → {new_commit}{subject}")
            lines.append(
                f"Parsed {recorded.spells_parsed} → {current.spells_parsed} · "
                f"imported {recorded.spells_imported} → {current.spells_imported}")
        lines.append("")

    # Asset-wide totals: the assets are one file each, so their diff is one
    # diff no matter how many books fed it.
    lines.append(f"Imported {imported} · blocked {blocked} · unresolved {unresolved}")
    lines.append("")
```

Leave the rest of `render` — the added/removed/changed sections — exactly as it is; those read the diff, not the identities.

`report.design_lines_of` calls `blocks.parse_de` directly. Leave it: it exists to read a *past revision of the core rulebook* from git for the design-line column, and the core book's parser has not changed.

- [ ] **Step 5: Update the report tests**

`scripts/spell_import/tests/test_report.py` constructs `SourceIdentity` and calls `render`. Update every construction to pass `book_id=` and every `render` call to pass `locks={...}` and `currents=[...]`. Add one test:

```python
    def test_the_report_has_a_section_per_book(self):
        core = self._identity("arm5-core", "Core Rules")
        supp = self._identity("arm5-hohmc", "Mystery Cults")
        text = report.render(
            report.AssetDiff(added=[], removed=[], changed=[]),
            locks={}, currents=[core, supp],
            imported=2, blocked=0, unresolved=0)
        self.assertIn("`arm5-core`", text)
        self.assertIn("`arm5-hohmc`", text)
```

- [ ] **Step 6: Update the one existing `describe`/`load` caller**

`extract_spells.py:927` calls `provenance.describe(sources.DE_TITLE, path, root, ...)` and `:932` calls `provenance.load()`. Task 5 rewrites that whole region; for now make the minimum edit that keeps the module importable and the suite green:

```python
    identity = provenance.describe(
        "arm5-core", sources.DE_TITLE, path, root,
        parsed=len(parsed), imported=len(spells)
    )
```

and where the lock is consulted, `provenance.matches(lock, identity)` already takes the new mapping shape, so only `provenance.write(identity)` needs to become `provenance.write({identity.book_id: identity})`. Search for every `provenance.` call in `extract_spells.py` and fix each.

- [ ] **Step 7: Run the whole Python suite**

Run: `uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS. Some `test_extract.py` assertions read `report.identity.spells_parsed`; that field still exists and still holds the core book's identity, so they are unaffected by this task.

- [ ] **Step 8: Regenerate `source.lock` in the new shape**

```bash
uv run --no-project python -m scripts.spell_import.extract_spells --write --accept-source
```
Expected: exit 0. Inspect `scripts/spell_import/source.lock` — it must now be `{"arm5-core": {...}}` with a `"bookId": "arm5-core"` inside, and `git diff assets/data/` must be empty: the lock's shape changed, the assets did not.

- [ ] **Step 9: Commit**

```bash
git add scripts/spell_import/provenance.py scripts/spell_import/report.py scripts/spell_import/source.lock scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_provenance.py scripts/spell_import/tests/test_report.py
git commit -m "refactor: key source.lock by book id

The lock recorded exactly one book. A mapping lets a book that has not
moved keep its attestation when a different one does, and SourceMoved
can now name which book it means.

SourceIdentity gains bookId because its existing 'book' field holds the
checkout's filename, which is not stable enough to key on."
```

---

### Task 5: Multi-book `run()`, the skip list, and diagnostics

**Files:**
- Modify: `scripts/spell_import/extract_spells.py:676-1000` (`run`), `:1003-1070` (`main`), `:564-590` (`Report`)
- Modify: `scripts/spell_import/emit.py:158-235` (`build_spell`), `:300-365` (`build_template`), `:800-820` (`build_exception_spell`)
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: `sources.BOOKS`, `sources.book_by_id` (Task 2); `blocks.PARSERS` (Task 1); `provenance.load/write/matches/describe` (Task 4).
- Produces:
  - `emit.build_spell(..., book_id: str)`, `emit.build_template(..., book_id: str)`, `emit.build_exception_spell(..., book_id: str)` — a required keyword argument on each
  - `extract_spells.SKIPPED_BLOCKS: dict[str, dict[str, str]]` — book id to spell name to reason
  - `extract_spells.DuplicateSpellId(Exception)`
  - `Report.identities: dict[str, provenance.SourceIdentity]` replacing `Report.identity`
  - `Report.skipped: list[tuple[str, str]]`
  - `extract_spells.diagnose(title: str, parser: str) -> str`

**`BOOKS` still holds only the core book after this task.** Every count stays where it is; the suite stays green. Task 6 adds the second entry.

- [ ] **Step 1: Add the skip list and the duplicate-id guard**

In `scripts/spell_import/extract_spells.py`, near the other hand-curated tables (after `SPELL_NAME_TYPOS`), add:

```python
class DuplicateSpellId(Exception):
    """Two books produced the same spell id.

    Ids are flat -- `lib-<tefo>-<slug>`, no book segment -- because they are
    also the resolutions.json keys, and namespacing them would churn all 206
    for no correctness gain. The cost of flat ids is that two books naming
    the same spell at the same Technique and Form would silently merge into
    one row, so the collision is made loud here instead.
    """


# Blocks the parser finds that are not importable spells, by book id. Each
# carries its reason: a skip with no stated reason is indistinguishable from
# a spell somebody forgot about.
SKIPPED_BLOCKS: dict[str, dict[str, str]] = {
    "arm5-hohmc": {
        "Perceive the Change":
            "an enchanted-device effect, not a spell: 'Pen 0, constant "
            "effect', costing '+1 two uses/day, +3 environmental trigger'. "
            "The app models no enchantments. Its stat line mis-parses to "
            "T: 'Ind Pen', which is the tell.",
        "Faerie Chains of the Familiar Slave":
            "hand-authored in hand_authored_templates.json by todo item 17; "
            "its guideline crvi-hohmc-G1 carries no effectFormula, so the "
            "extractor cannot build it.",
        "Tie the Threads That Bind":
            "hand-authored for the same reason as Faerie Chains: its "
            "guideline revi-hohmc-G1 carries no effectFormula, because the "
            "Might threshold is measured against the total computed level.",
    },
}
```

- [ ] **Step 2: Thread `book_id` through the three emitters**

In `scripts/spell_import/emit.py`, add a required keyword-only `book_id: str` parameter to `build_spell`, `build_template` and `build_exception_spell`, and replace each hard-coded citation. Change `spell["citations"] = [{"bookId": CORE_BOOK_ID}]` (line 231) to `spell["citations"] = [{"bookId": book_id}]`, and the same at lines 360 and 817.

Keep `CORE_BOOK_ID` defined — `catalog.cites(entry, CORE_BOOK_ID)` uses it throughout the oracle tests.

Add the parameter after the existing keyword arguments so positional callers are unaffected:

```python
def build_spell(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
    realm_by_spell_id: dict[str, str] | None = None,
    chosen_base_level: int | None = None,
    override_modifiers: dict[str, list[str]] | None = None,
    extra_adjustment: tuple[int, str] | None = None,
    analogy_rationale: str | None = None,
    *,
    book_id: str,
) -> dict:
```

- [ ] **Step 3: Turn `run()` into a loop over `BOOKS`**

The body of `run()` from the `for block in parsed:` loop to just before `templates.extend(hand_authored_templates())` becomes the body of a per-book loop. Restructure the head of `run()`:

```python
def run(write: bool = False, accept_source: bool = False) -> Report:
    root = sources.default_root()
    catalog = catalog_module.Catalog.load()
    book = ledger_module.Ledger.load()

    design_lines: dict[str, str] = {}
    spells: list[dict] = []
    templates: list[dict] = []
    exception_spells: list[dict] = []
    blocked: list[tuple[str, str]] = []
    skipped: list[tuple[str, str]] = []
    unresolved: list[str] = []
    problems: list[str] = []
    proposals: dict[str, dict] = {}
    widenings: dict[str, list[str]] = {}
    identities: dict[str, provenance.SourceIdentity] = {}

    for registered in sources.BOOKS:
        path = sources.resolve_book(registered.title, root)
        lines = sources.read_lines(path)
        parsed, book_problems = blocks.PARSERS[registered.parser](lines)
        problems.extend(f"{registered.id}: {p}" for p in book_problems)

        skips = SKIPPED_BLOCKS.get(registered.id, {})
        imported_before = len(spells)

        for block in parsed:
            if block.name in skips:
                skipped.append((block.name, skips[block.name]))
                continue
            ...  # the existing per-block body, unchanged except as noted below
```

Inside that body, every `emit.build_spell(...)`, `emit.build_template(...)` and `emit.build_exception_spell(...)` call gains `book_id=registered.id`.

After the per-block loop, still inside the book loop:

```python
        identities[registered.id] = provenance.describe(
            registered.id, registered.title, path, root,
            parsed=len(parsed), imported=len(spells) - imported_before,
        )
```

The local name `book` currently holds the `Ledger`. The loop variable is deliberately named `registered` so it does not shadow it — do not rename the ledger, which is referenced throughout the block body.

- [ ] **Step 4: Add the duplicate-id check**

After the book loop, before `templates.extend(hand_authored_templates())`:

```python
    seen: dict[str, str] = {}
    for row in spells + templates + exception_spells:
        if row["id"] in seen:
            raise DuplicateSpellId(
                f"{row['id']} produced twice: {seen[row['id']]!r} and "
                f"{row['name']!r}. Spell ids carry no book segment, so two "
                "books naming the same spell at the same Technique and Form "
                "collide. Rename one in a typo table, or give it an "
                "ExceptionSpell."
            )
        seen[row["id"]] = row["name"]
```

Place it before `hand_authored_templates()` is appended so a hand-authored template colliding with a parsed one is caught too — move the check to after that `extend` call instead, which covers both.

- [ ] **Step 5: Update `Report` and its construction**

In the `Report` dataclass, replace:

```python
    identity: provenance.SourceIdentity
```

with:

```python
    # One identity per book read, by book id. A mapping rather than a single
    # value because a rulebook that moved is a per-book fact.
    identities: dict[str, provenance.SourceIdentity]
    # Parsed blocks deliberately not imported, with the reason each. A bucket
    # of its own so the conservation invariant in test_extract.py still adds
    # up: a skipped block was parsed, and must land somewhere.
    skipped: list[tuple[str, str]]
```

Update the `Report(...)` construction at the end of `run()` to pass `identities=identities, skipped=skipped`, and fix the `--write` block: `provenance.load()` now returns a mapping, `matches` is checked per book, and `write` takes the mapping.

```python
    if write and not unresolved and not problems:
        lock = provenance.load()
        moved = [i for i in identities.values() if not provenance.matches(lock, i)]
        ...
        if moved and not accept_source:
            if would_change or not lock:
                raise SourceMoved("\n\n".join(
                    provenance.describe_change(lock, i) for i in moved))
```

and where the lock is rewritten, `provenance.write(identities)`.

- [ ] **Step 6: Add `--diagnose`**

Add beside `run()`:

```python
def diagnose(title: str, parser: str) -> str:
    """Parse any book and report what would happen, writing nothing.

    The point of this mode is measurement, not import: the corpus survey
    behind todo item 65 classified anchors, it never checked that an
    anchored block parses. A long failure list is the honest result.
    """
    root = sources.default_root()
    path = sources.resolve_book(title, root)
    parsed, problems = blocks.PARSERS[parser](path.read_text(
        encoding="utf-8", errors="strict").split("\n"))

    catalog = catalog_module.Catalog.load()
    with_design = [b for b in parsed if b.design_line]
    tokenized = 0
    failures: list[str] = []
    for block in with_design:
        try:
            designline.parse_design(block.design_line)
            tokenized += 1
        except designline.UnknownToken as error:
            failures.append(f"  {block.name}: {error}")

    lines = [
        f"{title}  [parser: {parser}]",
        f"  blocks found      : {len(parsed)}",
        f"  with a design line: {len(with_design)}",
        f"  design line reads : {tokenized}",
        f"  parse problems    : {len(problems)}",
        "",
    ]
    lines.extend(f"  PARSE {p}" for p in problems)
    lines.extend(sorted(failures))
    return "\n".join(lines)
```

In `main`, add the arguments and the early exit:

```python
    parser.add_argument(
        "--diagnose", metavar="TITLE",
        help="parse one book and report what would happen; writes nothing",
    )
    parser.add_argument(
        "--parser", default="inline", choices=sorted(blocks.PARSERS),
        help="block parser to use with --diagnose (default: inline)",
    )
```

and, directly after `args = parser.parse_args(argv)`:

```python
    if args.diagnose:
        if args.write:
            parser.error("--diagnose writes nothing; drop --write")
        print(diagnose(args.diagnose, args.parser))
        return 0
```

- [ ] **Step 7: Update `test_extract.py` for the new Report shape**

Three assertions need changing. In `test_every_emitted_spell_has_the_required_fields`, replace the fixed citation check with one that accepts any registered book:

```python
            self.assertEqual(spell["source"], "published")
            self.assertEqual(len(spell["citations"]), 1)
            self.assertIn(spell["citations"][0]["bookId"],
                          {b.id for b in sources.BOOKS}, msg=spell["id"])
```

In `test_every_parsed_block_lands_in_exactly_one_bucket`, sum across books and add the new bucket:

```python
        r = self.report
        carried_in = len(extract_spells.hand_authored_templates())
        parsed_total = sum(i.spells_parsed for i in r.identities.values())
        self.assertEqual(
            len(r.spells) + len(r.templates) - carried_in + len(r.exceptions)
            + len(r.blocked) + len(r.skipped) + len(r.unresolved),
            parsed_total,
            "a spell fell out of the report entirely -- it must appear in "
            "exactly one bucket, blocked and skipped included")
```

Search `test_extract.py` for every other `report.identity` reference and repoint it at `report.identities["arm5-core"]`.

Add:

```python
    def test_every_skip_carries_a_reason(self):
        for name, reason in self.report.skipped:
            self.assertTrue(reason.strip(), msg=name)

    def test_duplicate_ids_are_refused(self):
        rows = [{"id": "lib-muan-x", "name": "First"},
                {"id": "lib-muan-x", "name": "Second"}]
        seen = {}
        with self.assertRaises(extract_spells.DuplicateSpellId):
            for row in rows:
                if row["id"] in seen:
                    raise extract_spells.DuplicateSpellId(row["id"])
                seen[row["id"]] = row["name"]
```

Replace that last test with one that exercises the real guard if `run()` exposes it as a helper; if the check stays inline in `run()`, extract it to a module-level `_reject_duplicate_ids(rows: list[dict]) -> None` and test that directly. Prefer the extraction — a test that reimplements the logic it is checking proves nothing.

- [ ] **Step 8: Run the whole Python suite**

Run: `uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS, with counts unchanged: `BOOKS` still holds only the core book.

- [ ] **Step 9: Verify the extractor and the diagnostic both work**

```bash
uv run --no-project python -m scripts.spell_import.extract_spells
uv run --no-project python -m scripts.spell_import.extract_spells --diagnose "Ars Magica 5e - Houses of Hermes - Mystery Cults" --parser inline
```
Expected: the first prints `imported : 325`, `blocked : 0`, `unresolved: 0`. The second prints 16 blocks found and lists the design lines that fail — expect roughly four failures, all belonging to blocks the skip list excludes. `git status` must show no asset changes.

- [ ] **Step 10: Commit**

```bash
git add scripts/spell_import/extract_spells.py scripts/spell_import/emit.py scripts/spell_import/tests/test_extract.py
git commit -m "feat: run the importer over a registry of books

run() loops sources.BOOKS, dispatches each to its registered parser and
threads the book id into the emitters in place of a hard-coded constant.
Skipped blocks get a bucket of their own so the conservation invariant
still adds up, and a duplicate-id guard makes a cross-book collision
loud rather than silently merging two spells.

--diagnose parses any book and writes nothing, which is how the other
inline books get measured without importing them.

BOOKS still holds only the core book; the counts are unchanged."
```

---

### Task 6: Switch on HoH:MC

**Files:**
- Modify: `scripts/spell_import/sources.py` (the `BOOKS` tuple)
- Modify: `assets/data/base_effects.json` (append one row before the closing `]`)
- Modify: `scripts/spell_import/hand_authored_templates.json` (append one template)
- Modify: `scripts/spell_import/resolutions.json` (11 new entries)
- Modify: `scripts/spell_import/container_modes.json` (4 new entries)
- Regenerate: `assets/data/spell_library.json`, `assets/data/spell_templates.json`, `scripts/spell_import/source.lock`
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces: no new API. This task is data.

**This task is atomic on purpose.** Adding the book without its ledger entries leaves 11 spells unresolved and `run()` refusing to write; adding the entries without the book fails the test that every ledger entry names a parsed spell. They land together.

- [ ] **Step 1: Add the automata guideline**

Append to `assets/data/base_effects.json`, as the last entry before the closing `]`. **One compact object on one line**, matching every other row in the file. Add a comma to the end of the current last line (`muim-hohmc-10`).

```json
  {"id": "revi-hohmc-G1", "technique": "Rego", "form": "Vim", "description": "Unite an automaton's instilled effects into a cohesive whole (level >= construct's Magic Might)", "baseLevel": null, "source": "published", "citations": [{"bookId": "arm5-hohmc"}], "notes": "General entry; must be Ritual; requires the Craft Automata Major Hermetic Virtue the Automata Mystery grants (HoH:MC line 4652); hand-authored, not part of the core-rules extraction -- HoH:MC prints no Rego Vim guideline for this spell, only the spell's own level rule; no effectFormula -- the Might threshold ties to the total computed level, not chosenBaseLevel, and this guideline has no reference to make those coincide", "ritualRequirement": "required", "requiresVirtue": "Craft Automata"}
```

- [ ] **Step 2: Add the hand-authored template**

Append to `scripts/spell_import/hand_authored_templates.json`, inside the array, after the Faerie Chains entry. Indent-2, matching the file.

```json
  {
    "id": "tpl-revi-tie-threads-that-bind",
    "name": "Tie the Threads That Bind",
    "technique": "Rego",
    "form": "Vim",
    "requisites": {},
    "source": "published",
    "selectedModifiers": {},
    "baseEffectId": "revi-hohmc-G1",
    "rangeId": "range-touch",
    "durationId": "duration-momentary",
    "targetId": "target-group",
    "summary": "Unites an automaton's instilled effects into a cohesive whole. The spell's base effect level must equal or exceed the construct's Magic Might, so the final level must equal or exceed its Magic Might + 15.",
    "description": "This ritual is used only in the construction of automata. Once the magus has finished enchanting the automaton, he casts this spell onto the construction to unite all the magic into a cohesive unit. The base effect level must equal or exceed the construct's Magic Might to be successful, meaning the final spell level must equal or exceed the automaton's Magic Might + 15. Hand-authored rather than extracted: HoH:MC prints no Rego Vim guideline for it, only the spell's own level rule, so revi-hohmc-G1 carries no effectFormula and the extractor cannot compute the level. It may be invented by anyone who has been Initiated into the Automata Mystery of House Verditius, which grants the Craft Automata Virtue.",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  }
```

- [ ] **Step 3: Add the 11 ledger entries**

Append to `scripts/spell_import/resolutions.json`. Indent-2, matching the file. Each `candidates` list must be exactly what the catalog offers — if the extractor later reports a `StaleEntry`, the recorded list is wrong and the *entry* is what gets corrected, never the test.

```json
  "lib-pean-revenge-bitten-toad": {
    "baseEffectId": "pean-15b",
    "candidates": ["pean-15a", "pean-15b", "pean-15c", "pean-15d"],
    "rationale": "Its prose reads 'Any creatures who bite (or otherwise taste) the caster suffer a Heavy Wound' -- verbatim the guideline 'Inflict a Heavy Wound'. Not a destroyed sense, a crippled limb, or ageing."
  },
  "lib-crme-scent-predator": {
    "baseEffectId": "crme-4a",
    "candidates": ["crme-4a", "crme-4b"],
    "rationale": "Its prose reads 'Anyone smelling the caster is struck by an overwhelming sensation of menace and hostility' -- an emotion placed into a mind, not a memory restored to a fresh state."
  },
  "lib-reco-marking-territory": {
    "baseEffectId": "reco-3a",
    "candidates": ["reco-3a", "reco-3b"],
    "rationale": "The design line glosses its own base: '(Base 3 [move in direction \"away\"], +2 Ring, +2 Scent)'. That is 'Move a target slowly in one direction', not a minor symptom of disease."
  },
  "lib-mume-clarion-call-war-horse": {
    "baseEffectId": "mume-3b",
    "candidates": ["mume-3a", "mume-3b"],
    "rationale": "Its prose reads 'Anyone hearing the caster's battle cry is heartened by its tone, and receives a +3 bonus to his Brave Personality Trait' -- a major change to emotion, not to a memory of a series of events."
  },
  "lib-crig-brilliance-eagles-plumage": {
    "baseEffectId": "crig-5c",
    "candidates": ["crig-5a", "crig-5b", "crig-5c", "crig-5d", "crig-5e"],
    "rationale": "Its prose reads 'blinded by the brilliant light shining from his body' -- 'Create light as bright as direct sunlight on a clear day'. The spell creates no fire, ignites nothing, and heats nothing."
  },
  "lib-peme-closed-mouth-nightwalker": {
    "baseEffectId": "peme-10a",
    "candidates": ["peme-10a", "peme-10b"],
    "rationale": "Its prose reads 'Anyone seeing the caster instantly forgets that he did so' -- one brief memory removed, not a reduction of all the target's mental capabilities."
  },
  "lib-muan-voice-bjornaer-magus": {
    "baseEffectId": "muan-5b",
    "candidates": ["muan-5a", "muan-5b", "muan-5c"],
    "rationale": "The caster stays the same animal and gains a human voice: 'it targets the vocal capacity of that form'. That is 'Change an animal in a minor way so that it is no longer natural', not a change into a different animal, and the target is a living beast rather than animal products."
  },
  "lib-muan-form-temperament-heartbeast": {
    "baseEffectId": "muan-5b",
    "candidates": ["muan-5a", "muan-5b", "muan-5c"],
    "rationale": "Same reading as The Voice of the Bjornaer Magus: the animal is unchanged and its temperament correspondences are unnaturally enhanced ('they enhance the correspondences to the temperament of that form'). A minor unnatural change to an animal."
  },
  "lib-peme-embrace-boethius": {
    "baseEffectId": "peme-15a",
    "candidates": ["peme-15a", "peme-15b", "peme-15c"],
    "rationale": "Its prose reads 'destroying a part of his understanding of formulaic spell casting' -- a major, long memory removed. It removes no emotions and drives nobody insane."
  },
  "lib-muvi-facilitate-stifled-form-spell": {
    "baseEffectId": "muvi-G1",
    "candidates": ["muvi-G1", "muvi-G2", "muvi-G3"],
    "rationale": "The spell removes the casting penalty for reduced or absent gestures and voice, leaving the targeted spell otherwise intact -- a superficial change. Its prose's ceiling, a target 'whose level must be less than twice the level of this spell', matches G1's doubling tier rather than G2's or G3's tighter ones."
  },
  "lib-pevi-roosters-crow": {
    "baseEffectId": "pevi-G3",
    "candidates": ["pevi-G1", "pevi-G10", "pevi-G11", "pevi-G12", "pevi-G13", "pevi-G2", "pevi-G3", "pevi-G4", "pevi-G5", "pevi-G6", "pevi-G7", "pevi-G8", "pevi-G9"],
    "rationale": "Its prose reads 'Any demons who hear the caster's shout lose Might equal to the spell's (level / 5)' -- the same wording and the same mechanic as Demon's Eternal Oblivion, which this ledger already resolves to pevi-G3 (Reduce target's Might Score). Might Score rather than Might Pool for the same reason that spell chose it."
  },
```

- [ ] **Step 4: Add the four container modes**

Append to `scripts/spell_import/container_modes.json`, indent-2:

```json
  "lib-mume-clarion-call-war-horse": {
    "mode": "dynamic",
    "rationale": "Sensory Magic Targets (HoH:MC line 1002): the Target is continuously acquired throughout the spell's duration -- anyone who hears the caster's battle cry is affected, for as long as it lasts. Membership changes over the duration, which is the dynamic reading. Stated at the Target level with no per-spell choice offered; see todo item 68."
  },
  "tpl-pevi-roosters-crow": {
    "mode": "dynamic",
    "rationale": "Sensory Magic Targets (HoH:MC line 1002): the Target is continuously acquired throughout the spell's duration -- any demon who hears the shout is affected. Membership changes over the duration, which is the dynamic reading. Stated at the Target level with no per-spell choice offered; see todo item 68."
  },
  "lib-crig-brilliance-eagles-plumage": {
    "mode": "dynamic",
    "rationale": "Sensory Magic Targets (HoH:MC line 1002): the Target is continuously acquired throughout the spell's duration -- anyone who looks directly at the caster is affected, for as long as he concentrates. Membership changes over the duration, which is the dynamic reading. Stated at the Target level with no per-spell choice offered; see todo item 68."
  },
  "lib-peme-closed-mouth-nightwalker": {
    "mode": "dynamic",
    "rationale": "Sensory Magic Targets (HoH:MC line 1002): the Target is continuously acquired throughout the spell's duration -- anyone who sees the caster is affected, for as long as it lasts. Membership changes over the duration, which is the dynamic reading. Stated at the Target level with no per-spell choice offered; see todo item 68."
  },
```

- [ ] **Step 5: Register the book**

In `scripts/spell_import/sources.py`, extend `BOOKS`:

```python
BOOKS: tuple[Book, ...] = (
    Book(id="arm5-core", title=DE_TITLE, parser="de"),
    Book(
        id="arm5-hohmc",
        title="Ars Magica 5e - Houses of Hermes - Mystery Cults",
        parser="inline",
    ),
)
```

- [ ] **Step 6: Run the extractor and read what it says**

```bash
uv run --no-project python -m scripts.spell_import.extract_spells --show-blocked
```
Expected: `imported : 336`, `templates: 31`, `blocked : 0`, `unresolved: 0`, and a widening report naming 4 ReVi entries. If `unresolved` is non-zero, the message names the spell and what it expected — fix the ledger entry, not the test. If `blocked` is non-zero, read the reason before changing anything: a genuinely unmodelled token is a finding to report, not a table entry to invent.

- [ ] **Step 7: Migrate the widened ledger entries**

```bash
uv run --no-project python -m scripts.spell_import.migrate_ledger --write
```
Expected: 4 entries gain `"unreviewedCandidates": ["revi-hohmc-G1"]`. Their `baseEffectId` and `rationale` must be byte-identical afterwards — check with `git diff scripts/spell_import/resolutions.json` and confirm only the candidate lists and the new field changed.

- [ ] **Step 8: Regenerate the assets**

```bash
uv run --no-project python -m scripts.spell_import.extract_spells --write --accept-source
```
Expected: exit 0, and `git status` shows `spell_library.json`, `spell_templates.json`, `source.lock` and `import_report.md` changed. Read `scripts/spell_import/import_report.md`: it must list 11 newly imported spells and 3 new templates, and **nothing removed and nothing changed** — a core-book spell appearing under "Changed" means one of Tasks 1–5 altered existing behaviour and must be investigated before going further.

- [ ] **Step 9: Update the count assertions**

Search `scripts/spell_import/tests/test_extract.py` for the comment `(Verified today: 325+27+8+0+0 = 360 = spells_parsed.)` and update the arithmetic to the numbers the run now reports. Add:

```python
    def test_the_supplement_spells_are_imported(self):
        by_id = {s["id"]: s for s in self.report.spells}
        for spell_id in ("lib-pean-revenge-bitten-toad",
                         "lib-crme-scent-predator",
                         "lib-muim-ball-abysmal-music",
                         "lib-peme-embrace-boethius"):
            self.assertIn(spell_id, by_id)
            self.assertEqual(by_id[spell_id]["citations"],
                             [{"bookId": "arm5-hohmc"}], msg=spell_id)

    def test_the_two_requisites_of_embrace_of_boethius_both_cost(self):
        # "+2 necessary requisites" against Req: Vim, Corpus -- +1 each.
        spell = next(s for s in self.report.spells
                     if s["id"] == "lib-peme-embrace-boethius")
        self.assertEqual(spell["requisites"], {"Vim": "adding", "Corpus": "adding"})

    def test_the_four_sensory_container_spells_are_dynamic(self):
        rows = {s["id"]: s for s in self.report.spells + self.report.templates}
        for spell_id in ("lib-mume-clarion-call-war-horse",
                         "tpl-pevi-roosters-crow",
                         "lib-crig-brilliance-eagles-plumage",
                         "lib-peme-closed-mouth-nightwalker"):
            self.assertEqual(rows[spell_id].get("containerMode"), "dynamic", spell_id)

    def test_the_three_unimportable_blocks_are_skipped_with_reasons(self):
        names = {name for name, _ in self.report.skipped}
        self.assertEqual(names, {
            "Perceive the Change",
            "Faerie Chains of the Familiar Slave",
            "Tie the Threads That Bind",
        })

    def test_the_hand_authored_automata_template_survives_a_run(self):
        by_id = {t["id"]: t for t in self.report.templates}
        template = by_id["tpl-revi-tie-threads-that-bind"]
        self.assertEqual(template["baseEffectId"], "revi-hohmc-G1")
```

- [ ] **Step 10: Run all three suites**

```bash
uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .
flutter test
flutter analyze
flutter test integration_test -d windows
```
Expected: Python green; Dart green; `flutter analyze` exit 0; integration green. The Dart suite reads the regenerated assets, so a schema mistake in the new rows surfaces there — `asset_data_loader_test.dart` in particular.

- [ ] **Step 11: Commit**

```bash
git add assets/data/base_effects.json assets/data/spell_library.json assets/data/spell_templates.json scripts/spell_import/sources.py scripts/spell_import/resolutions.json scripts/spell_import/container_modes.json scripts/spell_import/hand_authored_templates.json scripts/spell_import/source.lock scripts/spell_import/import_report.md scripts/spell_import/tests/test_extract.py
git commit -m "feat: import the 14 HoH:MC spells

Registers Mystery Cults with the inline parser and lands everything it
needs in one commit: 11 ledger rulings, 4 container modes, the automata
guideline revi-hohmc-G1, and the hand-authored template that guideline
exists for.

revi-hohmc-G1 widens 4 ReVi general entries, migrated in the previous
commit -- the recorded choices stand and the added id is marked
unreviewed, exactly as crvi-hohmc-G1 was handled by item 17."
```

---

### Task 7: Diagnostics across the other inline books

**Files:**
- Modify: `.superpowers/todo.md` (item 65's entry and the *Where the import stands* table)

**Interfaces:**
- Consumes: `extract_spells.diagnose` (Task 5).
- Produces: nothing executable. This task records measurements.

**This task writes no spells.** Item 65 is explicit: no spell from any book but HoH:MC enters `spell_library.json` in this pass. `--diagnose` cannot write, which is what makes running it safe.

- [ ] **Step 1: Run the diagnostic against the three books**

Write each result to the session scratchpad, not `/tmp`:

```bash
SP="<the scratchpad directory from your instructions>"
for BOOK in "Ars Magica 5e - Covenants" \
            "Ars Magica 5e - Houses of Hermes - Societates" \
            "Ars Magica 5e - Transforming Mythic Europe"; do
  uv run --no-project python -m scripts.spell_import.extract_spells \
    --diagnose "$BOOK" --parser inline > "$SP/diag-$(echo "$BOOK" | tr ' /' '--').txt"
done
```

If a title does not resolve, `sources.resolve_book` suggests close matches in its error — use the suggestion. Confirm the exact filenames with `ls` against the rulebook checkout's `reviewed/` directory first.

- [ ] **Step 2: Read the results and summarise them honestly**

For each book record: blocks found, how many carried a design line, how many of those tokenized, and the three or four most common failure reasons. **A low tokenize rate is a measurement, not a defect** — the corpus survey classified anchors and never checked that an anchored block parses, so this is the first time that rate has been observed.

Do not fix anything you find. If a failure looks like a one-character transcription slip of the kind `_normalize_stat_line` already handles, note it as a candidate for a later pass rather than acting on it.

- [ ] **Step 3: Record the results in the todo**

In `.superpowers/todo.md`, move item 65 to the completed section following the file's existing convention for completed items (heading suffixed with the commit range, moved below the open items), and add the measured table:

```markdown
| Book | Blocks | With design line | Tokenized | Notes |
|---|---|---|---|---|
```

Update *Where the import stands*: the live extractor run line (`336 imported · 31 templates · 8 exceptions · 0 blocked · 0 unresolved`, or whatever Task 6 actually produced), the three suite counts, the catalog sizes (`base_effects.json` gains one row), and the unreviewed-entry count, which rises from 3 to 7.

- [ ] **Step 4: Open a follow-up item for what the diagnostics found**

Add a new numbered item recording the anchored-but-unparseable rate and what would be needed to close it, with the per-book numbers. State plainly that the dominant remaining cost is per-book ledger curation, not parser code.

- [ ] **Step 5: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: record item 65 complete and the inline diagnostics

Measures the anchored-but-unparseable rate across the three inline-heavy
books for the first time. The corpus survey classified anchors; it never
checked that an anchored block parses, and these numbers are that check.

Nothing from these books was imported, per item 65's own constraint."
```

---

## Self-Review

**Spec coverage.** Book registry → Task 2. `parse_inline` → Task 1. `strip_quote` → Task 1. Design-line vocabulary (5 Targets, `Base Effect`, `necessary requisites`) → Task 3. `_resolve_requisite_arts` → Task 3. Per-book `source.lock` → Task 4. Multi-book `run()`, skip list, duplicate-id check, `--diagnose` → Task 5. `revi-hohmc-G1` and the hand-authored template → Task 6. 11 ledger rulings → Task 6. 4 container modes → Task 6. `migrate_ledger` → Task 6. Diagnostics against three books → Task 7. Every spec section maps to a task.

**Placeholder scan.** No TBDs. Every code step carries the actual code; every data step carries the actual JSON; every test step carries the actual test body. Task 7 Steps 2–4 describe judgement work whose output cannot be written in advance — they state exactly what to measure and what not to do about it.

**Type consistency.** `Book(id, title, parser)` is constructed identically in Tasks 2 and 6. `blocks.PARSERS` keys `"de"`/`"inline"` are the same strings in Tasks 1, 2, 5. `provenance.describe(book_id, book, path, root, parsed, imported)` has the same signature in Tasks 4 and 5. `Report.identities` and `Report.skipped` are introduced in Task 5 and read in Tasks 5 and 6. `emit.build_spell(..., *, book_id)` is defined and called in Task 5.

**One known risk, flagged rather than hidden.** Task 6 Step 6 predicts `imported : 336` and `templates: 31`. Those follow from 11 library spells and 2 extracted templates plus 1 hand-authored, on top of today's 325 and 28. If the extractor reports different numbers, the discrepancy is real information: read `--show-blocked` before adjusting anything, and treat a changed *core* spell as a regression in Tasks 1–5 rather than a number to update.
