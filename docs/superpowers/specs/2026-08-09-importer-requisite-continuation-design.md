# Importer Requisite Continuation: the line the parser never reads

**Todo item:** new (file under section A, alongside item 29's import-harness
follow-ups). **Blocks item 40 Part B** — the `requisites` map reshape should
land on assets whose requisites are correct, not on assets missing 24 of them.

**Status:** designed 2026-08-09

**Rulebook:** not a rules question. The requisites are already stated in the
book; this is about the extractor failing to read them.

---

## Problem

The Definitive Edition writes a spell's requisites on a `<br>`-continuation
line beneath the stat line:

```
R: Touch, D: Sun, T: Ind<br>
Req: Corpus<br>
Gives one land beast a human form, though its intellect remains the same...
```

`blocks.py` locates the stat line and passes **that single raw line** to
`statline.parse_statline` (`blocks.py:112-113`). `statline._REQ`
(`statline.py:32`) searches only within the tail of the line it was given, so
`requisite_arts` comes back empty. The requisite is never seen.

The same missed line causes a second defect. The prose scan starts at
`cursor = index + 1` (`blocks.py:120`) — the `Req:` line itself — and that line
is non-empty and matches none of the `_NAME` / `_SECTION` / `_LEVEL` / `_DESIGN`
break patterns, so it is appended to `prose_lines` and ends up prefixed to the
spell's description.

One unread line, two defects: requisites lost, descriptions corrupted.

### This is shipped, not latent

Measured against the committed `assets/data/spell_library.json` (294 published
spells) on 2026-08-09:

| State | Count |
|---|---|
| Descriptions beginning `Req: <Art>` | **34** |
| ...which also lost their requisite entirely | **24** |
| ...which got a requisite from the *design line* instead | 10 |
| Requisite present, description clean | 2 |

The 10 that still carry a requisite do so by luck of a different code path:
`emit.py` reads requisite tokens from the **design line** (`+1 Rego requisite`)
as well as from `stat.requisite_arts`, and only the design-line route is
working. The 2 clean entries are a generation-window artifact — they were
produced while a local, since-discarded edit had put `Req:` inline.

Counting the book rather than the asset, at both revisions of interest:

| Rulebook revision | Inline `Req:` | Continuation-line `Req:` |
|---|---|---|
| `4a6887f` (the current `source.lock` pin) | 0 | 41 |
| `e292c50` (current upstream) | 0 | **45** |

Zero inline at either revision. Every requisite in the book is on a
continuation line, and the extractor reads none of them.

### Why it matters now

Any regeneration silently deletes requisites. That trap was armed before this
work and would have sprung inside item 40 Part B's diff, which is expected to
be a requisites *shape* change and nothing else. Discovering a content
regression inside a shape-only review is exactly the failure this spec exists
to prevent.

## Decisions taken

**The fold happens in `blocks.py`, not `statline.py`.** `blocks.py` owns line
assembly; `statline.py` owns parsing one logical stat line. Teaching
`parse_statline` about continuation lines would put line-assembly knowledge in
the parser and give it a two-line contract. Folding before the call keeps both
contracts intact and leaves `parse_statline` untested-for-regression only in
the sense that its behaviour genuinely does not change.

**The pin bump and the parser fix land as one change.** Decided 2026-08-09 by
the user. They are separable — the continuation format predates the pin, so the
parser fix is demonstrable at `4a6887f` — but the intermediate state has no
independent value and would cost a second full regeneration. Sequencing them
the other way (parser fix first, at the old pin) is worse: at `4a6887f`
*Thaumaturgical Transformation of Plants to Iron* still carries the `Reg:`
typo, which parses `target_name` as `'Ind Reg'`, an unresolvable target that
would block the spell until the pin bump repaired it.

The cost of one step is that the diff mixes upstream churn with parser-fix
effects. That is recovered analytically in Verification below, without extra
commits.

**No backwards compatibility.** Consistent with the project's standing
position: the assets are regenerated artifacts and the DB is droppable.

## Design

### The fix

In `blocks.py`, between locating the stat line and parsing it: look ahead past
blank lines; if the next line — after `statline.strip_markup` — matches
`^Req(?:uisites?)?:`, append its text to the stat line before calling
`parse_statline`, and start the prose scan at the line *after* it.

Two properties follow, and both are what the existing code already expects:

- `parse_statline` receives one logical stat line, exactly as today. Its `_REQ`
  regex, its multi-art comma splitting, and its `ARTS` membership filter all
  work unchanged on the folded text.
- The `Req:` line is consumed by stat-line assembly, so it can no longer reach
  `prose_lines`.

Requisites arriving from the stat line remain `kind: "free"`, and `emit.py`'s
existing dedupe (`if not any(r["art"] == art for r in requisites)`) continues to
give design-line tokens precedence — a `+1 Rego requisite` design token stays
`adding` and is not overwritten by the stat line's free entry.

### Files

- **Modify:** `scripts/spell_import/blocks.py` — the fold, in the block-assembly
  loop.
- **Modify:** `scripts/spell_import/source.lock` — pin `4a6887f` → `e292c50`.
- **Regenerate:** `assets/data/spell_library.json`,
  `assets/data/spell_templates.json`, `scripts/spell_import/import_report.md`.
- **Test:** `scripts/spell_import/tests/test_blocks.py`.

Nothing in `lib/` changes. `statline.py` and `emit.py` are untouched.

## Testing

Python unit tests over block assembly:

1. A continuation-line `Req: Corpus` yields `requisite_arts == ['Corpus']`.
2. That same block's `prose` does **not** begin with `Req:`.
3. A multi-art continuation line `Req: Corpus, Terram` yields both arts.
4. A blank line between the stat line and `Req:` is tolerated.
5. An inline `Req:` on the stat line still parses — the path is not regressed
   even though no current revision of the book uses it.
6. A spell with no requisite line is unaffected: `requisite_arts == []` and its
   prose begins with its actual first prose sentence.

The Dart side needs no new tests. Assertion 7 in
`test/data/published_spell_import_test.dart` already asserts
`validateSpellAgainstCatalog` reports zero problems across every published
spell and template, and it becomes load-bearing here: every newly-appearing
requisite is a fresh opportunity for a self-matching-art or duplicate-art
violation that no previous run could have surfaced. If assertion 7 reddens, it
has found a real defect in the book, the catalog, or `emit.py` — not a test to
relax.

## Verification

`import_report.md` is the review instrument. It reports parsed / imported /
blocked counts and names every spell whose import status changed, so a spell
gained or lost is visible rather than buried in a 300-spell diff.

**Expected, and to be confirmed rather than assumed:**

- **24** currently-imported spells gain the requisite they had lost, and **34**
  descriptions lose their `Req: <Art>` prefix. The book's 45 continuation lines
  are the upper bound, not the expected asset delta — the remainder belong to
  spells that are blocked and therefore absent from `spell_library.json`. Some
  of those may now become importable, which `import_report.md` will name.
- *Plants to Iron* keeps its Terram requisite — it currently has one only by
  the generation-window artifact, and should now obtain it legitimately.
- The imported count does not fall. A drop means a spell that previously parsed
  now does not, and must be explained before the change lands.

**Diff attribution without extra commits.** To separate upstream churn from
parser-fix effects, generate the intermediate state into a scratch directory —
pin bumped, parser unfixed — and diff it against both endpoints. This is
analysis only; the repository receives one commit. It answers "which change
caused what" for the review, which is the property the two-step sequencing
would have provided.

## What this deliberately does not do

- **No `requisites` shape change.** That is item 40 Part B, designed separately
  and landing after this. Its decisions are already taken: `requisites` becomes
  `Map<String, RequisiteKind>`, the `Requisite` class is deleted with
  `magnitude` moving onto the enum, the wire format becomes a JSON object, and
  the validator's duplicate-art check is deleted while the self-matching-art
  check survives.
- **No repair of `emit.py`'s two duplicated requisite blocks.** The spell and
  template emitters carry the same nine lines twice (`emit.py:92-99`,
  `emit.py:163-170`). Real, pre-existing, and untouched by this fix — filed
  rather than folded in.
- **No `statline.py` changes.** The parser's contract is correct; only its
  input was incomplete.
- **No rulebook edits.** The book's continuation-line formatting is legitimate
  markup that the extractor should read, not a typo to patch upstream. The
  earlier local `Reg:` → `Req:` fix was a genuine typo and has since been fixed
  upstream independently.
