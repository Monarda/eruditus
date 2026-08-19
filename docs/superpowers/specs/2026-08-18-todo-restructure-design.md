# Restructuring `.superpowers/todo.md`

**Date:** 2026-08-18 · **Status:** design approved, not yet implemented

**Figures re-verified 2026-08-19**, after `023767a` merged item 67's cross-field
constraints and opened item 74. Every count below is from that tree.

## Problem

`.superpowers/todo.md` has grown to 2230 lines / 144 KB. It is loaded at the
start of a session so a fresh context knows what is open and what has already
been decided, and at its current size that purpose is failing: the parts worth
loading are a small minority of the bytes.

Measured 2026-08-19:

| | |
|---|---|
| Total | 2230 lines / 144 KB |
| `## Completed ✅` | 1034 lines — 46% of the file |
| Section C / Section D | 494 / 477 lines |
| Preamble (status, counts, how-to-read) | ~110 lines |
| Item headings | 81 — 38 in open sections, 43 under Completed (42 numbered + one unnumbered summary) |
| Un-ticked `- [ ]` sub-bullets | 80, against 18 ticked |
| Internal `item N` cross-references | 165 |

Three structural faults, distinct from mere size:

1. **Status is encoded in three places that disagree.** Section membership,
   heading suffix (`— DONE 2026-08-17`), and per-bullet checkbox. Item 73 sits
   under `## Completed ✅` with seven open bullets and zero closed. Items 59,
   60 and 61 each exist twice — once as a tombstone in section C, once for real
   under Completed.
2. **The real unit of work is an unnumbered sub-bullet.** There are 80 open
   ones. Having no id, they cannot be cross-referenced, prioritised or moved,
   so they accumulate inside whichever item spawned them — item 38 holds 7,
   item 73 holds 7.
3. **`## Where the import stands` is generated content in a hand-edited file.**
   77 lines of counts, three suite results and a catalog table, all obtained by
   running commands, all requiring periodic manual re-verification.

## Goals

- Cut the always-read core to roughly 200 lines.
- Preserve every existing item number. No renumbering, no redirect table.
- Keep all 165 cross-references resolvable.
- Make the structure resist re-inflation, rather than merely resetting its size.

## Non-goals

- Changing what any item says. This is a move, not a re-litigation. The one
  exception is the re-triage in step 2, which adds a field without editing
  bodies.
- Generating `STATUS.md`. Specified here as a follow-on; deliberately excluded
  from this work (see *Sequencing*).
- Any change to `docs/superpowers/plans/`, `specs/` or `reports/`.
- Any change to `~/.claude/settings.json`. The rule-3 gate is project-scoped by
  requirement; it must not fire in other repositories.

## Design

### File layout

```
.superpowers/
  todo.md            THE INDEX. always read. ~110 lines
  DECISIONS.md       standing constraints, distilled. always read. ~90 lines
  STATUS.md          generated dashboard. read when the numbers matter
  themes/
    rules-fidelity.md  catalog vs. what the rulebook prints      (12 items)
    model.md           what the spell model can't yet express     (7 items)
    importer.md        scripts/spell_import, ledger, provenance   (5 items)
    app.md             the Flutter app and project chores        (10 items)
    multibook.md       the second-book program, sub-project C     (2 items)
  ARCHIVE.md         41 closed items, verbatim. not loaded by default. ~950 lines
  .last-reviewed-merge  one sha. state for the rule-3 gate (see below)
.claude/
  settings.json      project-scoped Stop hook
  skills/closing-an-item/SKILL.md   the extraction procedure
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
rejected — it invalidates 165 in-file cross-references plus every reference in
commit messages, specs and plan documents, and makes a redirect table permanent
load-bearing infrastructure.

### Sub-items

Every open sub-bullet gets a dotted id under its parent: `38.2`, `73.4`. These
are stable and never reused, on the same rule as item numbers. Ticking `38.1`
does not renumber `38.2`.

Dotted ids were preferred over promoting each bullet to a full item because the
grouping carries real provenance — "all seven were found by one whole-branch
review of item 25" is information, and promotion weakens it to a citation while
taking the item count from 36 to roughly 116.

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
| 73 | do     | open 7/7     | importer.md       | Deferred minors from item 65       |
```

`open 6/7` means six of seven sub-ids remain open, so an item's weight is
visible without opening its theme file. `Kind` is `—` for closed items.

### Priority

The existing A/B/C/D bands are **dropped**, not carried across. They record a
judgement made weeks ago and are no longer reliable; a stale band is worse than
no band, because a fresh session will act on it.

Priority survives in exactly one place: the `Now:` line, holding two or three
item numbers. A short list that is visibly a snapshot is more honest than 36
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

### Enforcing rule 3

Rule 3 is the one that decides whether this restructure holds. Rules 1, 2 and 4
are conventions whose violation is visible in a diff; rule 3's violation is an
*omission*, and omissions are invisible. Left to discipline it will decay the
same way the Completed section did.

Note the distinction from migration step 3 below: that is a one-time backfill of
41 already-closed bodies, and no branch will ever finish for those. What is
automated here is the recurring rule.

**A hook cannot perform the extraction.** Deciding which sentences of a closed
item still bind is judgement; a hook is a shell command. It can only remind (so
the model does the work) or gate (check that the work happened and refuse to end
the turn otherwise). This design gates, because the failure mode being guarded
against is precisely a step quietly not happening.

**Trigger: a `Stop` hook keyed on merges, not on the finishing skill.** Matching
`PostToolUse` on the `Skill` tool was considered and rejected — it fires when
`finishing-a-development-branch` *launches*, before tests run and before
anything is closed, so it can only inject a reminder into the top of a long flow
and hope it survives.

Instead, `.superpowers/.last-reviewed-merge` holds one sha. On `Stop` the hook
compares it against `git rev-list --merges -1 HEAD`:

- equal → exit 0, silent.
- different → exit 2 with a message naming the merge; the model receives it and
  must address it before the turn ends. Performing the extraction updates the
  file, which self-clears the prompt.

Three consequences, of which the third is the strongest argument for the design:

1. It cannot scroll out of context the way an injected reminder can.
2. A false positive is cheap — many merges bind nothing new, and "no standing
   constraints here" is a five-second answer. A false negative is what produced
   the 1007-line Completed section.
3. **It catches merges made outside Claude Code.** No hook fires for a merge in
   a terminal or a GUI, but the sha still moves, so the next session in this
   repo opens by asking. Nothing keyed to the skill can do this.

**The procedure lives in a project skill, not in the hook.**
`.claude/skills/closing-an-item/SKILL.md` holds the extraction steps; the hook
carries only the trigger and a pointer to it. This keeps the procedure versioned
in the repo, editable without touching settings, and invokable by hand when an
item closes without a merge.

Two constraints on the implementation:

- The hook must declare `"shell": "bash"` to work on Windows. Superpowers' own
  `docs/windows/polyglot-hooks.md` documents the failure it avoids: PowerShell
  and CMD both mis-parse a leading quoted path.
- **Merge-and-item-close is a proxy, not an identity.** One merge may close
  three items or none. The gate asks a question; it does not assert that an item
  closed.

Scope: this is project-scoped configuration in the repo's own
`.claude/settings.json`, which travels with the repo and fires nowhere else. The
user-level `~/.claude/settings.json` is not touched.

## Migration

1. **Build the index mechanically** from current headings — number, title,
   open/closed state, sub-bullet counts.
2. **Re-triage the 36 open items** into decide/do/maybe and pick the `Now:`
   list. A full classification is proposed from the bodies for the user to
   correct; the `Now:` line is the user's call. *This is the only step
   requiring user input.*
3. **Extract binding constraints from the 41 closed bodies into
   `DECISIONS.md`,** merged with the existing standing-constraints section.
4. **Move closed bodies verbatim to `ARCHIVE.md`.** No editing — verbatim is
   what makes step 3 safe to be aggressive.
5. **Split open bodies into the five theme files,** assigning dotted sub-ids as
   they land. Delete the three tombstones (items 59, 60, 61); move item 73 out
   of Completed into `importer.md`, which is what it actually is.
6. **Verify mechanically.**

### Verification

- Every number 1–74 appears exactly once in the index.
- Every one of the 165 `item N` cross-references resolves to an index row.
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

The rule-3 gate lands **after** migration step 6, for two reasons. It keys on
`.superpowers/.last-reviewed-merge`, which has nothing to point at until
`DECISIONS.md` exists; and a gate installed mid-migration would fire on the
migration's own merge, which closes no item. Its settings edit should go through
the `update-config` skill rather than a hand-written JSON patch.

## Appendix: proposed theme assignment

36 open items — the 35 under sections B/C/D once the three tombstones are
removed, plus item 73, which is currently misfiled under Completed.

| Theme | Items | n |
|---|---|---|
| `rules-fidelity.md` | 4, 4b, 4c, 12, 20, 21, 22, 36, 41, 42, 50, 63 | 12 |
| `app.md` | 7, 9, 10, 11, 16, 18, 23, 33, 56, 58 | 10 |
| `model.md` | 47, 53, 54, 57, 67, 69, 74 | 7 |
| `importer.md` | 31, 32, 38, 70, 73 | 5 |
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
