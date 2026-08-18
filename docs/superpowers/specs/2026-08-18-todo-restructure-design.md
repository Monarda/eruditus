# Restructuring `.superpowers/todo.md`

**Date:** 2026-08-18 · **Status:** design approved, not yet implemented

## Problem

`.superpowers/todo.md` has grown to 2136 lines / 141 KB. It is loaded at the
start of a session so a fresh context knows what is open and what has already
been decided, and at its current size that purpose is failing: the parts worth
loading are a small minority of the bytes.

Measured 2026-08-18:

| | |
|---|---|
| Total | 2136 lines / 141 KB |
| `## Completed ✅` | 1007 lines — 47% of the file |
| Section C / Section D | 494 / 383 lines |
| Preamble (status, counts, how-to-read) | ~110 lines |
| Item headings | 75 (73 unique numbers) — 37 in open sections, 42 under Completed |
| Un-ticked `- [ ]` sub-bullets | 78, against 15 ticked |
| Internal `item N` cross-references | 158 |

Three structural faults, distinct from mere size:

1. **Status is encoded in three places that disagree.** Section membership,
   heading suffix (`— DONE 2026-08-17`), and per-bullet checkbox. Item 73 sits
   under `## Completed ✅` with eight open bullets and zero closed. Items 59,
   60 and 61 each exist twice — once as a tombstone in section C, once for real
   under Completed.
2. **The real unit of work is an unnumbered sub-bullet.** There are 78 open
   ones. Having no id, they cannot be cross-referenced, prioritised or moved,
   so they accumulate inside whichever item spawned them — item 38 holds 7,
   item 73 holds 8.
3. **`## Where the import stands` is generated content in a hand-edited file.**
   77 lines of counts, three suite results and a catalog table, all obtained by
   running commands, all requiring periodic manual re-verification.

## Goals

- Cut the always-read core to roughly 200 lines.
- Preserve every existing item number. No renumbering, no redirect table.
- Keep all 158 cross-references resolvable.
- Make the structure resist re-inflation, rather than merely resetting its size.

## Non-goals

- Changing what any item says. This is a move, not a re-litigation. The one
  exception is the re-triage in step 2, which adds a field without editing
  bodies.
- Generating `STATUS.md`. Specified here as a follow-on; deliberately excluded
  from this work (see *Sequencing*).
- Any change to `docs/superpowers/plans/`, `specs/` or `reports/`.

## Design

### File layout

```
.superpowers/
  todo.md            THE INDEX. always read. ~110 lines
  DECISIONS.md       standing constraints, distilled. always read. ~90 lines
  STATUS.md          generated dashboard. read when the numbers matter
  themes/
    rules-fidelity.md  catalog vs. what the rulebook prints      (12 items)
    model.md           what the spell model can't yet express     (6 items)
    importer.md        scripts/spell_import, ledger, provenance   (6 items)
    app.md             the Flutter app and project chores         (9 items)
    multibook.md       the second-book program, sub-project C     (2 items)
  ARCHIVE.md         42 closed items, verbatim. not loaded by default. ~950 lines
```

A session reads `todo.md` + `DECISIONS.md` always, and one theme file on top
when working in that theme.

Rejected: an `open/` vs `closed/` directory split (status belongs in one place,
the index) and a file per item (the current problem with more `ls` output).

### Item numbers

Numbers remain a **flat global namespace**, exactly as today. Themes are files;
numbers are ids. The index maps every number to its home file and status, so
`item 38` resolves in one lookup. This is the issue-tracker model: global ids,
labels for grouping.

Renumbering into theme-prefixed ids (`IMP-7`, `CAT-3`) was considered and
rejected — it invalidates 158 in-file cross-references plus every reference in
commit messages, specs and plan documents, and makes a redirect table permanent
load-bearing infrastructure.

### Sub-items

Every open sub-bullet gets a dotted id under its parent: `38.2`, `73.4`. These
are stable and never reused, on the same rule as item numbers. Ticking `38.1`
does not renumber `38.2`.

Dotted ids were preferred over promoting each bullet to a full item because the
grouping carries real provenance — "all seven were found by one whole-branch
review of item 25" is information, and promotion weakens it to a citation while
taking the item count from 35 to roughly 110.

### The index (`todo.md`)

```markdown
# Eruditus — Item Index

**Now:** 32 · 71 · 66

| #  | Kind   | Status       | Home              | Title                              |
|----|--------|--------------|-------------------|------------------------------------|
| 4  | do     | open         | rules-fidelity.md | Conditional wards                  |
| 7  | do     | open 3/4     | app.md            | Spell export/backup validation     |
| 32 | do     | open         | importer.md       | Audit resolutions.json             |
| 38 | do     | open 6/7     | importer.md       | Follow-ups from item 25's review   |
| 59 | —      | closed 08-17 | ARCHIVE.md        | Spell level computes live          |
| 73 | do     | open 8/8     | importer.md       | Deferred minors from item 65       |
```

`open 6/7` means six of seven sub-ids remain open, so an item's weight is
visible without opening its theme file. `Kind` is `—` for closed items.

### Priority

The existing A/B/C/D bands are **dropped**, not carried across. They record a
judgement made weeks ago and are no longer reliable; a stale band is worse than
no band, because a fresh session will act on it.

Priority survives in exactly one place: the `Now:` line, holding two or three
item numbers. A short list that is visibly a snapshot is more honest than 35
rows quietly asserting a stale ordering.

The band column is replaced by `Kind`, which is derivable from the item body
and therefore checkable rather than rotting:

| Kind | Means | Checkable by |
|---|---|---|
| `decide` | a question is open; no one has answered it | body says "decide whether…" |
| `do` | the decision is made, the work is not | body says what to change |
| `maybe` | filed deliberately as not-yet-worth-doing | body says so, e.g. item 33's "Do not do it on its own" |

This distinction is already promised by the current file's own *How to read
this file* section; it has simply never been a scannable field.

### `DECISIONS.md`

Organised **by topic, not by item number**, because that is how it gets
consulted. It starts from the existing `## Notes — standing constraints`
section, which is already this shape, and absorbs the roughly 15 constraints
currently buried inside closed item bodies. Each entry cites its origin item so
provenance survives distillation:

```markdown
## Modifier naming
"Effect complexity", not "Complexity" — the three Imaginem sensory-complexity
modifiers are already all named "Complexity", and the UI heads each modifier
group by name. Two groups with the same heading, one checkboxes and one a
dropdown, is unusable.  *(item 72)*
```

### Lifecycle rules

1. Numbers and sub-ids are never reused and never renumbered.
2. An item's home file may change freely; only its index row must follow.
   Nothing cross-references a file, only a number.
3. **Closing an item extracts its binding constraints to `DECISIONS.md` first,
   then moves the body verbatim to `ARCHIVE.md`.** This is the rule whose
   absence produced the 1007-line Completed section: closure narrative had
   nowhere to go except the live file, so it stayed there.
4. A new finding becomes a sub-id under the item that produced it, not a new
   item, unless genuinely unrelated to that parent.

## Migration

1. **Build the index mechanically** from current headings — number, title,
   open/closed state, sub-bullet counts.
2. **Re-triage the 35 open items** into decide/do/maybe and pick the `Now:`
   list. A full classification is proposed from the bodies for the user to
   correct; the `Now:` line is the user's call. *This is the only step
   requiring user input.*
3. **Extract binding constraints from the 42 closed bodies into
   `DECISIONS.md`,** merged with the existing standing-constraints section.
4. **Move closed bodies verbatim to `ARCHIVE.md`.** No editing — verbatim is
   what makes step 3 safe to be aggressive.
5. **Split open bodies into the five theme files,** assigning dotted sub-ids as
   they land. Delete the three tombstones (items 59, 60, 61); move item 73 out
   of Completed into `importer.md`, which is what it actually is.
6. **Verify mechanically.**

### Verification

- Every number 1–73 appears exactly once in the index.
- Every one of the 158 `item N` cross-references resolves to an index row.
- Concatenating the new files reproduces every paragraph of
  `git show HEAD:.superpowers/todo.md` apart from the deliberate deletions,
  which are enumerated explicitly rather than inferred: the three tombstones
  (items 59, 60, 61), the A/B/C/D band headers and their preambles, and the
  `## Where the import stands` section superseded by `STATUS.md`.

### Risk

**Step 3 is where this succeeds or fails.** Steps 1, 2, 4, 5 and 6 are
logistics that git makes reversible. If the constraint extraction is lazy, the
result is a tidier file that has lost the reason item 72 named a modifier
"Effect complexity" — and a future session renames it back. Step 3 should be
reviewed on its output, not on its process.

## Sequencing

`STATUS.md` generation is a follow-on, not part of this work. It is a script
(`extract_spells` already prints the counts; the three suite results are
commands), and bundling it here would make step 6's line-accounting
meaningless — generated content cannot be diffed against the old hand-written
text.

Until that script exists, `STATUS.md` holds the current hand-written
`## Where the import stands` content, moved verbatim and marked as
hand-maintained.

## Appendix: proposed theme assignment

35 open items — the 34 under sections B/C/D once the three tombstones are
removed, plus item 73, which is currently misfiled under Completed.

| Theme | Items | n |
|---|---|---|
| `rules-fidelity.md` | 4, 4b, 4c, 12, 20, 21, 22, 36, 41, 42, 50, 63 | 12 |
| `app.md` | 7, 9, 10, 11, 16, 18, 33, 56, 58 | 9 |
| `model.md` | 47, 53, 54, 57, 67, 69 | 6 |
| `importer.md` | 23, 31, 32, 38, 70, 73 | 6 |
| `multibook.md` | 66, 71 | 2 |

Two assignments are judgement calls worth stating rather than burying:

- **Item 10 (Documentation) and item 11 (Performance) are project chores, not
  app features.** They go in `app.md` because item 11's open bullets are about
  app startup and library-load cost, and item 10's remaining two bullets are
  small. A sixth file for three lines of documentation chores would cost more
  than it saves.
- **Item 38's sub-ids span three themes** (a duplicated-logic bullet about the
  Dart model, two efficiency bullets about the Library load path, two about the
  Python pipeline). It stays whole in `importer.md`, because sub-ids are not
  independently relocatable — a sub-id's home is its parent's home, by
  construction. If that grouping ever becomes the wrong trade, the fix is to
  promote the outlying sub-ids to full items with an origin citation, not to
  split the parent across files.
