# Importer Requisite Continuation Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach the spell importer to read a `Req: <Art>` line that the
Definitive Edition prints on the line *after* the stat line, instead of
losing the requisite and corrupting the description with a stray `Req:`
prefix.

**Architecture:** One new fold step in `blocks.py`'s block-assembly loop:
after locating a stat line, look past blank lines for a `Req:`-prefixed
line; if found, append its text to the stat line before parsing and start
the prose scan after it. `statline.py` and `emit.py` are untouched — the
parser keeps its one-logical-line contract, unaware anything upstream
changed.

**Tech Stack:** Python 3.13, `unittest`. No Dart changes.

## Global Constraints

- **No `lib/` changes.** This is a data/importer fix; the Dart side reads
  whatever the importer emits, unchanged.
- **No `statline.py` or `emit.py` changes.** Their contracts are already
  correct; only `blocks.py`'s input to `statline.parse_statline` was
  incomplete.
- **No rulebook edits.** The continuation-line format is legitimate markup
  to be read, not a typo to patch upstream.
- **No backwards compatibility / migration story.** Prototype stage; the
  regenerated assets simply replace the committed ones.
- **The pin bump (`source.lock` `4a6887f` → `e292c50`) and the parser fix
  land in the same commit.** Decided 2026-08-09 by the user — see
  `docs/superpowers/specs/2026-08-09-importer-requisite-continuation-design.md`,
  "Decisions taken". Do not split this into two commits.
- **Regeneration goes through the importer's own `--write --accept-source`
  flow**, never by hand-editing `source.lock` or the generated JSON — that
  flow is what keeps `source.lock`'s sha/date/subject and the asset's
  provenance consistent with each other.

## Verified expectations (measured against the live rulebook checkout, read-only, before writing any code)

These numbers were confirmed by simulating the fold in a scratch script
against the actual sibling checkout (`e292c50`) and the actual
`blocks.parse_de`/`extract_spells.run` pipeline, so Task 1's regeneration
step should reproduce them exactly:

- `imported` stays **294**, `templates` stays **23**, `blocked` stays **43**
  — and the blocked set is the *same 43 spells*, not merely the same count.
  The fold changes what requisites are read; it does not newly unblock or
  block anything.
- **26** currently-imported spells gain a requisite they previously lost
  (all `kind: "free"`, all going from `[]` to a single-entry list). This
  corrects the design spec's estimate of 24 — the spec explicitly marked
  that number "to be confirmed rather than assumed," and the confirmed
  figure is 26.
- **34** imported spells' descriptions lose a stray `Req: <Art>` prefix (26
  of those are the ones above; the other 8 already carried the right
  requisite via the design-line path and only their description changes).
  Zero descriptions still start with `Req:` after the fix.
- **0** templates change — none of the 45 book continuation lines belong to
  a General-level (template) spell.
- No self-matching-art or duplicate-art violation is introduced: none of
  the 45 continuation-line arts equals its own spell's Technique or Form,
  and none duplicates another requisite already on the same stat line.
  (This is exactly what assertion 7 — see Task 1 Step 9 — re-verifies on
  the Dart side.)
- *Thaumaturgical Transformation of Plants to Iron* is one of the 26: it
  gains its Terram requisite legitimately from the continuation line, no
  longer depending on the since-fixed `Reg:`→`Req:` upstream typo.

---

### Task 1: Fold `Req:` continuation lines into the stat line, bump the pin, regenerate

**Files:**
- Modify: `scripts/spell_import/blocks.py`
- Test: `scripts/spell_import/tests/test_blocks.py`
- Regenerate (via `extract_spells.py --write --accept-source`, not by hand):
  `scripts/spell_import/source.lock`, `assets/data/spell_library.json`,
  `assets/data/spell_templates.json`, `scripts/spell_import/import_report.md`
- Modify: `docs/superpowers/specs/2026-08-09-importer-requisite-continuation-design.md`
  (record confirmed numbers in place of predictions, once regeneration
  proves them)

**Interfaces:**
- Consumes: `statline.strip_markup(line: str) -> str`, `statline.is_statline(line: str) -> bool`,
  `statline.parse_statline(line: str) -> StatLine` (all pre-existing,
  unchanged signatures, from `scripts/spell_import/statline.py`).
- Produces: no new public interface — `blocks.parse_de` keeps its existing
  signature `parse_de(lines: list[str]) -> tuple[list[SpellBlock], list[str]]`.
  Callers (`extract_spells.py`) need no changes.

- [ ] **Step 1: Read the current block-assembly loop for the insertion point**

Open `scripts/spell_import/blocks.py` and confirm the code around lines
111–131 still reads as it did when this plan was written:

```python
        try:
            normalized = _normalize_stat_line(raw)
            stat = statline.parse_statline(normalized)
        except ValueError as e:
            problems.append(f"line {index + 1}: {e}")
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
```

If it has drifted, stop and reconcile with whoever changed it before
continuing — the steps below are diffs against this exact text.

- [ ] **Step 2: Write the failing tests in `test_blocks.py`**

Add these six test methods to the existing `ParseDefinitiveEditionTest`
class in `scripts/spell_import/tests/test_blocks.py` (it already parses the
live rulebook once in `setUpClass`, so most of these read `cls.blocks`
exactly like the file's existing tests):

```python
    def test_continuation_line_requisite_is_read(self):
        # "The Beast Remade" (Muto Corpus) prints its requisite on the line
        # after the stat line:
        #   R: Touch, D: Sun, T: Ind<br>
        #   Req: Corpus<br>
        # parse_statline never sees that second line unless blocks.py folds
        # it in first.
        block = next(b for b in self.blocks if b.name == "The Beast Remade")
        self.assertEqual(block.stat.requisite_arts, ["Corpus"])

    def test_continuation_line_requisite_does_not_leak_into_prose(self):
        # The same unread line used to be appended to prose_lines, so the
        # description came out prefixed "Req: Corpus Gives one land beast...".
        block = next(b for b in self.blocks if b.name == "The Beast Remade")
        self.assertFalse(block.prose.startswith("Req:"), block.prose[:40])

    def test_continuation_line_with_multiple_arts_is_read(self):
        # "Fog of Confusion" prints "Req: Imaginem, Rego" on its
        # continuation line -- both arts must survive the fold and the
        # comma split in statline._REQ.
        block = next(b for b in self.blocks if b.name == "Fog of Confusion")
        self.assertEqual(block.stat.requisite_arts, ["Imaginem", "Rego"])

    def test_blank_line_between_stat_line_and_requisite_is_tolerated(self):
        # No spell in the current book actually has a blank line here (every
        # one of the 45 continuation lines sits immediately below its stat
        # line), but the fold must not depend on that -- it looks past
        # blank lines rather than only at index + 1.
        lines = [
            "##### A Made-Up Spell",
            "R: Touch, D: Sun, T: Ind",
            "",
            "Req: Corpus",
            "A description sentence.",
            "(Base 5, +1 Touch, +2 Sun)",
        ]
        blocks_found, problems = blocks.parse_de(
            ["### Muto Corpus Spells", "#### LEVEL 10"] + lines
        )
        self.assertEqual(problems, [])
        self.assertEqual(len(blocks_found), 1)
        self.assertEqual(blocks_found[0].stat.requisite_arts, ["Corpus"])
        self.assertEqual(blocks_found[0].prose, "A description sentence.")

    def test_inline_requisite_on_the_stat_line_still_parses(self):
        # No revision of the book currently uses this form, but it is the
        # form statline._REQ was originally written for, and the fold must
        # not regress it: a stat line that already carries its own Req:
        # should not look for -- or require -- a continuation line at all.
        lines = [
            "##### Another Made-Up Spell",
            "R: Touch, D: Sun, T: Ind, Req: Corpus",
            "A description sentence.",
            "(Base 5, +1 Touch, +2 Sun)",
        ]
        blocks_found, problems = blocks.parse_de(
            ["### Muto Corpus Spells", "#### LEVEL 10"] + lines
        )
        self.assertEqual(problems, [])
        self.assertEqual(len(blocks_found), 1)
        self.assertEqual(blocks_found[0].stat.requisite_arts, ["Corpus"])
        self.assertEqual(blocks_found[0].prose, "A description sentence.")

    def test_spell_with_no_requisite_line_is_unaffected(self):
        # Regression guard: a spell with no Req: anywhere keeps
        # requisite_arts == [] and its prose starts with its real first
        # sentence, not with anything consumed by the new look-ahead.
        block = next(b for b in self.blocks if b.name == "Soothe Pains of the Beast")
        self.assertEqual(block.stat.requisite_arts, [])
        self.assertFalse(block.prose.startswith("Req:"))
```

- [ ] **Step 3: Run the suite and confirm the new tests fail**

Run: `python -m unittest scripts.spell_import.tests.test_blocks -v`

Expected: the four tests that read live spells
(`test_continuation_line_requisite_is_read`,
`test_continuation_line_requisite_does_not_leak_into_prose`,
`test_continuation_line_with_multiple_arts_is_read`,
`test_spell_with_no_requisite_line_is_unaffected`) — the last one because
`prose.startswith("Req:")` is actually about *other* spells, so it should
already pass; the first three FAIL, showing `requisite_arts == []` where
`["Corpus"]` / `["Imaginem", "Rego"]` was expected, and a prose string
starting with `"Req: Corpus ..."`. The two synthetic tests
(`test_blank_line_between_stat_line_and_requisite_is_tolerated`,
`test_inline_requisite_on_the_stat_line_still_parses`) also FAIL or ERROR,
since the blank-line-tolerant fold does not exist yet. All twelve
pre-existing tests in the file still PASS.

- [ ] **Step 4: Implement the fold in `blocks.py`**

Add the new regex constant next to the file's other line-matching patterns
(after `_DESIGN` at line 32):

```python
# A requisite the book prints on its own line, directly beneath the stat
# line, rather than inline within it. See
# docs/superpowers/specs/2026-08-09-importer-requisite-continuation-design.md.
_REQ_CONTINUATION = re.compile(r"^Req(?:uisites?)?:")
```

Replace the block quoted in Step 1 with:

```python
        normalized = _normalize_stat_line(raw)
        folded = statline.strip_markup(normalized)

        # Look past any blank lines for a Req: continuation line and fold
        # it into the stat line before parsing, so parse_statline keeps
        # seeing one logical line exactly as it always has. If none is
        # found, prose_start stays at index + 1 and behaviour is identical
        # to before this fold existed.
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
            name = None
            continue

        prose_lines: list[str] = []
        design: str | None = None
        cursor = prose_start
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
```

Two things to note while making this change:
- `folded` is built by stripping markup from the normalized stat line
  *before* handing it to `parse_statline`, which itself calls
  `strip_markup` again — that second call is a no-op on already-stripped
  text (idempotent), so the non-fold path behaves byte-for-byte as before.
- The blank-line skip loop only ever *moves* `prose_start` forward when a
  `Req:` line is actually found (inside the `if _REQ_CONTINUATION.match`
  branch). If it isn't found, `prose_start` is still `index + 1`, so a
  spell with blank lines before its real prose (and no requisite) is
  parsed exactly as it was before this change.

- [ ] **Step 5: Run `test_blocks.py` again and confirm everything passes**

Run: `python -m unittest scripts.spell_import.tests.test_blocks -v`

Expected: all 18 tests in the file PASS (12 pre-existing + 6 new).

- [ ] **Step 6: Run the full Python suite and confirm the expected, singular failure**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`

Expected: 187 tests run (181 that existed before this task + the 6 added in
Step 2), with exactly one failure:
`test_committed_library_matches_a_fresh_run`
(`scripts.spell_import.tests.test_extract.RegenerationTest`). This is
expected at this point in the task — `source.lock` and the committed
assets still reflect the un-folded parser at the old pin, and a fresh run
now legitimately disagrees with them because the parser reads more than it
used to. Step 7 resolves it. If any *other* test fails, stop and
investigate before continuing — that would mean the fold changed something
beyond what this task intends.

- [ ] **Step 7: Regenerate the assets and adopt the new pin**

Confirm the rulebook sibling checkout is at the revision this plan expects:

```bash
git -C ../Ars-Magica-Open-License rev-parse --short HEAD
```

Expected: `e292c50`. If it differs, stop — this plan's verified expectations
above were measured against `e292c50` specifically, and a different
revision needs its own read-only check before regenerating against it (see
the design spec's "Diff attribution without extra commits" note, and use
the same scratch-script approach if the book has moved again).

Then regenerate:

```bash
python -m scripts.spell_import.extract_spells --write --accept-source
```

Expected output: `imported : 294`, `templates: 23`, `blocked  : 43`,
`unresolved: 0`, followed by `wrote assets/data/spell_library.json` and
`wrote assets/data/spell_templates.json`. This also rewrites
`scripts/spell_import/source.lock` (pin becomes `e292c50`) and
`scripts/spell_import/import_report.md`.

- [ ] **Step 8: Verify `import_report.md` matches the plan's expectations**

Open `scripts/spell_import/import_report.md` and confirm its summary line
reads `Parsed 360 → 360 · imported 294 → 294 · blocked 43 → 43 · unresolved
0 → 0` (no change in any of the four headline counts — the fold changes
requisites and descriptions, not import/block status), and that its
"Newly imported" and "No longer imported" sections are both empty. Spot
check two names from the "Verified expectations" section above — "The
Beast Remade" and "Fog of Confusion" — appear among whatever change list
the report shows for requisite/description content (the report's exact
section names may vary; the point is that these two are visibly listed,
not silently changed).

- [ ] **Step 9: Run the full Python suite again and confirm it's fully green**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`

Expected: `Ran 187 tests` with `OK` — including
`test_committed_library_matches_a_fresh_run`, now passing because the
committed assets and `source.lock` agree with a fresh run again.

- [ ] **Step 10: Run the Dart suite and confirm assertion 7 stays green**

Run: `flutter test`

Expected: all tests pass, including
`test/data/published_spell_import_test.dart`'s assertion 7
(`validateSpellAgainstCatalog` reports zero problems across every published
spell and template). Per the design spec, this assertion is load-bearing
here: every one of the 26 newly-appearing requisites is a fresh opportunity
for a self-matching-art or duplicate-art violation that no previous run
could have surfaced. The "Verified expectations" section above already
confirmed analytically that none of the 45 continuation-line arts collides
with its own spell's Technique/Form or with another requisite on the same
line — this step is the authoritative Dart-side confirmation of that same
fact, not a formality. If it reddens, that is a real defect in the book,
the catalog, or `emit.py` — stop and investigate; do not weaken or skip the
assertion.

- [ ] **Step 11: Record the confirmed numbers in the design spec**

Open
`docs/superpowers/specs/2026-08-09-importer-requisite-continuation-design.md`
and, in its "Verification" section, change the sentence that currently
reads:

```markdown
- **24** currently-imported spells gain the requisite they had lost, and **34**
  descriptions lose their `Req: <Art>` prefix. The book's 45 continuation lines
  are the upper bound, not the expected asset delta — the remainder belong to
  spells that are blocked and therefore absent from `spell_library.json`. Some
  of those may now become importable, which `import_report.md` will name.
```

to:

```markdown
- **Confirmed 2026-08-09, on regeneration:** **26** currently-imported spells
  gained the requisite they had lost, and **34** descriptions lost their
  `Req: <Art>` prefix (the original estimate here was 24; the actual count,
  measured, is 26). `imported`/`templates`/`blocked` counts were unchanged and
  the blocked *set* was identical before and after — no spell became newly
  importable.
```

Leave the rest of the section (the *Plants to Iron* bullet and the
"imported count does not fall" bullet) as-is — both were confirmed true and
need no correction.

- [ ] **Step 12: Commit everything as one commit**

```bash
git add scripts/spell_import/blocks.py \
        scripts/spell_import/tests/test_blocks.py \
        scripts/spell_import/source.lock \
        assets/data/spell_library.json \
        assets/data/spell_templates.json \
        scripts/spell_import/import_report.md \
        docs/superpowers/specs/2026-08-09-importer-requisite-continuation-design.md
git commit -m "fix: read Req: continuation lines in the importer

blocks.py handed statline.parse_statline only the stat line itself, so a
requisite the Definitive Edition prints on the following <br> line (all 45
of them, in the current book) was never read -- the requisite was lost,
and the same unread line was appended to the spell's description instead.

Fold that line into the stat line before parsing, so parse_statline keeps
its one-logical-line contract unchanged.

Lands together with the source.lock pin bump (4a6887f -> e292c50) and the
regenerated assets, by design -- see the linked spec's 'Decisions taken'.

26 imported spells gain a requisite; 34 descriptions lose a stray Req:
prefix; imported/blocked counts and the blocked set are unchanged.
"
```

(Use a real editor or `git commit` without `-m` if the multi-line message
above doesn't paste cleanly through your shell.)

---

## Self-review

**Spec coverage:** every element of the design spec's "Design" and
"Testing" sections maps onto Task 1: the fold implementation (Step 4), all
six named test cases (Step 2, verbatim), the pin bump and regeneration as
one commit (Steps 7, 12), assertion 7 as the Dart-side check (Step 10), and
the diff-attribution/verification numbers (all confirmed ahead of time in
"Verified expectations" and recorded back into the spec in Step 11). The
spec's "What this deliberately does not do" list — no `requisites` shape
change, no `emit.py` dedup cleanup, no `statline.py` changes, no rulebook
edits — is reflected in Global Constraints and in Task 1 touching none of
those files.

**Placeholder scan:** no TBD/TODO; every step carries real code, real
spell names, and real expected numbers rather than descriptions of what to
check.

**Type consistency:** `blocks.parse_de` keeps its existing signature;
`SpellBlock`, `StatLine`, and their fields are unchanged. The new
`_REQ_CONTINUATION` constant is local to `blocks.py` and not referenced
elsewhere.

**Scope:** one task, one commit, as the user directed. Nothing here
depends on or blocks on Part B (the `requisites` map reshape), which stays
a separate, later cycle per the spec.
