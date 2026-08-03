# Rulebook Source Provenance: record the input, don't freeze it

**Date:** 2026-08-03
**Status:** Design agreed section-by-section in discussion
**Todo item:** 30 (new — to be added to section A of `.superpowers/todo.md`)
**Relates to:** item 27 (the import harness this protects), item 29 (CI)

## Problem

`assets/data/spell_library.json` is generated output. Its correctness argument is
"the generator is verified, and the generator is deterministic." Both halves are
true, and together they still do not establish that the committed asset is right,
because the generator reads an input that **lives outside this repository and is
not versioned with it**.

`sources.py:13` resolves the rulebook to `REPO_ROOT.parent /
"Ars-Magica-Open-License"` — a separate GitHub repository
(`OriginalMadman/Ars-Magica-Open-License`), not a submodule, not pinned. Nothing
in this repo records which revision of it produced the committed 250 spells.

### This is not hypothetical

On 2026-08-03 a routine "do the tests pass?" check went red with three failures:

```
test_finds_exactly_360_spells        AssertionError: 346 != 360
test_committed_library_matches_a_fresh_run   ... is stale or was hand-edited
test_every_committed_key_is_a_real_spell     8 ledger keys with no matching spell
```

All three had one cause: the local rulebook checkout was three weeks behind, so
the parser saw 346 spells instead of 360. The code was correct, the asset was
correct, the ledger was correct. Diagnosis took roughly half an hour, most of it
spent looking for a code fault that did not exist — because **not one of the
three messages mentioned the source.** The middle message actively misdirected:
it blamed the asset for being "stale or hand-edited" when the asset was neither.

### The input moves often

Measured over 2026-05-01 → 2026-08-03:

| | Commits |
|---|---|
| Rulebook repository, all books | 108 |
| The Definitive Edition core rules file alone | 28 |

Roughly a weekly cadence on the file that matters, and the quality trend is
upward — chapter-by-chapter proof-reading is in progress upstream. The 346 → 360
jump was itself an upstream *improvement*: a chapter 9 review made 14 previously
unparseable spells parse.

### Why pinning is the wrong answer

The obvious fix is a pinned revision. It is rejected: with the source improving
weekly, a pin means deliberately consuming a text that grows steadily worse
relative to what is available, and bumping it becomes a chore whose reward for
skipping is invisible. A pin optimises reproducibility at the direct expense of
the thing the source is *for*.

The requirement is therefore not to freeze the input but to **record it**, so
that changes are attributable, diagnosable, and adopted deliberately.

## What already works, and must not be rebuilt

Two mechanisms already solve parts of this correctly. The design builds on them
rather than duplicating them.

**`RegenerationTest` is already a precisely-targeted drift detector.** It
compares a fresh extraction against the committed asset, so it fires exactly when
a source change *reaches the library* — and stays silent when the rulebook's
chapter 13, 14 or 16 are revised, because those contain no spells. No hash of the
source file can match that precision: a file-level hash fires on all 28 file
changes, most of which cannot affect a spell. Its only defect is the wording of
its failure message.

**The ledger already models input-drift for the catalogs.** `ledger.py:92-96`
records the candidate set each decision was made against and raises `StaleEntry`
when the catalog moves under it. This covers the rulebook too, from a different
direction: an errata that edits a spell's `Base N` changes its candidate set and
raises `StaleEntry`; a renamed spell orphans its ledger key and
`test_every_committed_key_is_a_real_spell` catches it. **No new mechanism is
needed for ledger exposure.**

What is missing is only **source identity** — and without it, none of the three
failures below can be addressed.

## Requirements

In priority order, as agreed:

1. **A regenerated asset cannot be committed unreviewed.** The hazard is a
   reflexive `--write` after a red test, silently shipping 250 changed spells.
2. **A source change must be diagnosable as a source change**, not presented as a
   code or asset fault.
3. **A local checkout falling behind upstream must surface**, rather than the
   harness quietly working against months-old text.

Requirement 3 is met from two directions. A checkout that is behind *the revision
the asset was built from* surfaces locally and immediately, through requirement
2's mechanism — that is precisely the 2026-08-03 case, and the worked message in
§2 shows it: `recorded` is newer than `current`. A checkout that is behind
*upstream* while remaining self-consistent produces no local signal at all, and
is caught only by the weekly CI job in §5.

## Design

### 1. The lock file

`scripts/spell_import/source.lock`, committed, hand-readable:

```json
{
  "book": "Ars Magica - Definitive Edition (Core Rules)",
  "path": "reviewed/Ars Magica - Definitive Edition (Core Rules).md",
  "sha256": "4f3a…9c1",
  "rulebook": {
    "commit": "97cc62d",
    "date": "2026-07-18",
    "subject": "Review Definitive Edition chapter 16"
  },
  "spellsParsed": 360,
  "spellsImported": 250
}
```

Its meaning is precisely: **the last source revision known to produce this
asset.** Not "the only acceptable source" — the lock never constrains what you
read locally.

- **`sha256` is the only field ever compared.** The `rulebook` block is
  advisory: printed in messages, never used for correctness. When the rulebook is
  not a git checkout (a downloaded zip), it is `null` and everything else still
  works. The hard dependency stays on the file.
- **`path` is recorded** so that `sources.py`'s `reviewed` → `wip` → `raw-md`
  precedence silently changing its answer is visible as a source change.
- **No `generatedAt`.** It would churn the diff on every regeneration while
  telling you nothing `git log` does not.
- **`spellsParsed` / `spellsImported`** exist to make the failure message useful
  (below), and to make a source *regression* — 360 → 346 — legible rather than
  mysterious.

A new module `scripts/spell_import/provenance.py` owns loading, writing,
computing current identity, and comparing. One purpose, no rulebook parsing.

### 2. Diagnosis: the lock informs, it does not gate

**`RegenerationTest` remains the only *test* that gates on drift.** Gating a test
on the file hash was considered and rejected — see Rejected Alternatives. Its
failure message becomes drift-aware by consulting the lock:

```
rulebook source moved since spell_library.json was generated.

  recorded : 97cc62d "Review Definitive Edition chapter 16" (2026-07-18)
             sha256 4f3a…9c1 — 360 parsed, 250 imported
  current  : 005a33c "Merge pull request #54 …" (2026-07-13)
             sha256 b81d…2e7 — 346 parsed

This is not a code failure. Regenerate and review:
  python -m scripts.spell_import.extract_spells --write --accept-source
```

When the lock agrees with the current source, the message keeps today's "stale or
was hand-edited" wording, which is then accurate. The message is chosen by
consulting the lock, **not by test execution order** — ordering across unittest
modules is not guaranteed and must not be relied on.

Because the lock records the last revision *known to produce this asset*, a
harmless upstream change (chapter 16) leaves it valid and requires no bump.

### 3. The gate: `--accept-source`

| Invocation | Lock matches | Behaviour |
|---|---|---|
| `--write` | yes | Writes the asset, as today. Lock unchanged. |
| `--write` | no, and the asset would change | **Refuses, exit 1**, prints the drift message. |
| `--write` | no, but the asset is identical | No-op, as today. |
| `--write --accept-source` | no | Writes asset, rewrites lock, writes the change report. |
| `--write --accept-source` | yes | Behaves as plain `--write`; the flag is harmless, not an error. |
| `--write` | no lock file exists | **Refuses**, as for a mismatch. `--accept-source` creates it. |
| `--accept-source` alone | — | argparse error; meaningless without `--write`. |

An absent lock is treated as drift rather than as "nothing to check", so
bootstrapping the file is the same deliberate act as adopting a source change.
This also means a lock deleted by accident cannot silently stop protecting the
asset.

The existing guard at `extract_spells.py:179` — `if write and not unresolved and
not problems` — stays **in front of** this. Accepting a source never bypasses it:
if an upstream edit introduces new ambiguity, `--write --accept-source` still
refuses and writes `resolutions.proposed.json`. The two gates are ordered
deliberately and must not later be merged into one.

### 4. The change report

`scripts/spell_import/import_report.md`, committed, written **only when the asset
actually changes** — a no-op regeneration leaves it untouched, so it never churns
the diff.

```markdown
# Import change report

Source: 005a33c → f36ac84 ("Merge pull request #66 …", 2026-07-29)
Parsed 346 → 360 · imported 241 → 250 · blocked 105 → 110 · unresolved 0 → 0

## Newly imported (9)
- Wizard's Mount (ReAn 20) — was: unrecognised design-line token

## No longer imported (0)

## Changed (3)
- The Crystal Dart — level 10 → 15
  design line: (Base 3, +1 Touch, +1 size) → (Base 5, +1 Touch, +1 size)
```

This is the review surface that requirement 1 depends on: ~15 readable lines in
place of a diff across 250 JSON objects. Committing it makes `git log
scripts/spell_import/import_report.md` a history of every source adoption and its
effect.

**Old design-line quoting is best-effort.** The old design line is in neither the
asset nor the lock; it is retrieved with `git -C <rulebook> show
<recorded-sha>:<path>`, using the SHA and path the lock now records. When the
rulebook is not a git checkout, or that revision is not fetched, the line is
omitted with a note — **never a failure**. Everything else in the report derives
from comparing two asset files and needs no git at all.

### 5. CI

Two jobs. The lock is what lets them differ:

**`tests`** — on push and pull request. Reads the rulebook SHA *from
`source.lock`* and clones the rulebook at that exact revision, then runs
`python -m unittest discover` and `flutter test`. Hermetic and reproducible: it
tests the code against a fixed input, so upstream churn cannot redden an
unrelated pull request. **This job is item 29's deliverable, not this item's** —
it is specified here only because the lock is what makes it reproducible, and
because building it without the lock would produce the churn-prone version. Item
30 owns the lock; item 29 owns the workflow.

**`rulebook-freshness`** — weekly cron. Clones the rulebook at `origin/main`,
regenerates, and compares against the committed asset. Identical → green, with an
informational note if the source moved harmlessly. Differs → fails, with the
change report as the failure output. Silent for a chapter 16 review, loud for a
chapter 9 one. This is requirement 3.

**One supporting change:** `sources.py`'s `RULEBOOK_ROOT` needs an
`ARS_RULEBOOK_ROOT` environment-variable override, defaulting to today's sibling
path. `actions/checkout` will not clone outside the workspace, so the current
hardcoded sibling path cannot be satisfied on a runner. It also helps any
contributor whose local layout differs.

## Testing

- **`test_provenance.py`** — the lock round-trips; sha computation is stable;
  absent git metadata degrades to `null` without error; the drift message names
  both revisions.
- **`test_report.py`** — diffing two fixture asset lists yields the expected
  added / removed / changed sets, including design-line quoting when old text is
  supplied and its clean omission when it is not.
- **`RegenerationTest`** — message updated, plus a test that it distinguishes
  "source moved" from "hand-edited".

Both new modules run **against fixtures with no rulebook present**. This is
deliberate: it begins the source-independent test split item 29 calls for,
without undertaking that whole job here. Five of the seven existing test modules
read the live book and there are no fixtures today.

## Rejected alternatives

- **Pin the rulebook revision.** Rejected: the source improves weekly, so a pin
  means consuming steadily worse text and bumping it becomes a skippable chore.
  See Problem.
- **Gate on the source file hash.** Rejected during design, after being proposed.
  It fires on every byte change to the file — all 28 since May, most of which
  cannot touch a spell — which trains reflexive use of `--accept-source` and so
  defeats requirement 1. Asset-equivalence is precise by construction; the hash
  is not. This is why the lock is diagnostic rather than gating.
- **Vendor chapter 9 into this repository.** Seriously considered: the markdown
  diff is the best possible review surface, and it makes the harness hermetic.
  Rejected because it is pinning with extra steps — deliberately stale by
  default — and duplicates ~4,000 lines of another project's text. Its main
  advantage is recovered cheaply by the report's design-line quoting.
- **Provenance in git metadata only** (commit message or git note). Rejected:
  tests cannot read it, so requirement 2 — the concrete pain — stays unfixed.
- **Provenance inside `spell_library.json`.** Rejected: that file is the Flutter
  app's data contract, and build metadata does not belong in it.

## Non-goals

- Not a pin. The lock never constrains which rulebook is read locally.
- No automatic adoption. Nothing regenerates the asset without a human passing
  `--accept-source`.
- `spell_library.json`'s schema is untouched; the app's data contract does not
  change.
- The in-repo catalogs (`base_effects.json`, `parameters.json`,
  `modifiers.json`) are already versioned with the code and stay out of scope.
- Ledger staleness is already handled and is not re-implemented here.
