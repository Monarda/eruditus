# Published Spell Import: harness first, library second

**Date:** 2026-07-28
**Status:** Design agreed section-by-section in discussion
**Todo item:** 27
**Source:** `Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md`,
Chapter 9 (lines 12020–16004)

## Problem

The library holds 36 spells. The Definitive Edition core rules print **360**. The
goal is all of them, but the interesting question is not how to write 360 JSON
objects — it is how to know they are *right*.

### The obvious test does not work

The natural harness is "computed level equals printed level." It is necessary and
it is not sufficient, because **it cannot see a wrong base effect**.

A published spell's design line names its guideline only by level: *Soothe Pains
of the Beast* says `Base level 15`. Creo Animal has **four** entries at level 15.
All four produce the same computed level. Choosing the wrong one is invisible to
the level test and wrong in the library.

This is not hypothetical. Todo item 5 fixed exactly this: 19 built-in spells
referenced base-effect ids that were wrong or entirely invented, merging two real
catalog entries into one nonexistent id — and every level test was green,
because as that item records, "every corrected pair has an identical
`baseLevel`." At 36 spells that produced 19 errors. At 360 it will produce more,
and nothing in the current test suite would report them.

### How much judgement is actually required

Of the 360 spells, 324 carry a numeric `Base N`:

| | Count |
|---|---|
| Exactly one catalog entry at that Technique/Form/level | 133 |
| Two or more candidates — requires reading the description | 186 |
| No catalog entry at that level at all | 5 |

**Automated text matching does not close the 186.** A matcher scoring token
overlap and sequence similarity between each candidate guideline and the spell's
description produces a clear winner (margin ≥ 0.20) for only 50, a weak
preference for 60, and an effective tie for 76 — and its confident answers are
often wrong. It matched *Weaver's Trap of Webs*, which grows a net of spider
webs, to `cran-5c` "Give an animal a +12 bonus to Recovery rolls" over `cran-5a`
"Create an animal product, such as spidersilk or wool". Guideline text is short
and shares little vocabulary with flavour-heavy spell prose, so there is little
signal to work with.

This is the design's central constraint: **the extractor must not pretend to
resolve what it cannot resolve.** A confidence score attached to a bad guess is
worse than no guess, because it launders judgement into data.

### What can be extracted mechanically

Everything else. Each spell prints its name, level, and a stat line
(`R: Touch, D: Sun, T: Ind, Ritual`), plus an optional `Req:` line and a
parenthetical design line. Range, Duration, Target, requisites, the Ritual flag
and every magnitude token are stated outright. None of that needs judgement.

### The stat line is the anchor, not the heading

Every spell has a stat line and nothing else in the book has quite its shape, so
**the stat line locates the spell; the heading structure only decorates it.**
This inverts the obvious approach of walking headings and collecting spells along
the way, and it is materially more robust — a heading walk already produced one
silent misfiling during the audit (see Risks).

**The predicate is "the line contains `R:`, then `D:`, then `T:`" — not
"the line starts with `R:`."** The two are indistinguishable on the Definitive
Edition, which is exactly why the weaker one is tempting: both give 385/360 there.
Across the supplements the conjunction finds **2378** stat lines against 1300 for
the anchored form — 83% more, at the same proxy precision. The single largest
cause is *Against the Dark*, which writes `**R:** Voice, **D:** Diameter,
**T:** Part`; a pattern anchored at the start of the line expects whitespace where
the closing `**` sits and rejects every stat line in the book. Matching on the
presence and order of the three fields makes no claim about the markup between
them, which is the whole point.

A **tolerant second pass** catches what the conjunction cannot: 9 lines carry
genuine source damage — `R: Arc, D: Conc, R: Ind` (T mistyped as R),
`R: Voice, D Mom, T: Group` (dropped colon), and four in *Realms of Power: Magic*
reading `R: Touch, T: Ring, D: Circle` with Duration and Target transposed. Any
two of the three fields present should raise the line for review rather than parse
it. The transposed pair is the reason: `Ring` and `Circle` are both valid values,
so a silent parse yields a wrong spell that no downstream assertion can see.

Anchoring in the reviewed Definitive Edition finds **385** lines. Exactly
**360** are immediately preceded by a `##### <Name>` heading, and **every** such
heading in the spell chapter has a stat line under it — a clean 1:1 with zero
orphans in either direction. That is independent confirmation of the 360, from a
parse sharing no logic with the heading walk.

The other 25 are not spells and are cheap to exclude: 15 creature powers and 10
elemental powers in blockquote sidebars, all carrying a
`*Name*, N points, Init equal to (Qik + 4), Terram` line where a spell carries a
name heading. The discriminator is that heading — not a line-number range.

Two consequences for the extractor:

- **Read blockquotes.** Stripping a leading `> ` before matching adds 10 hits in
  the core rules alone. A matcher anchored to column 0 silently skips every
  sidebar.
- **Assert the 1:1.** An anchor with no name heading, and a name heading with no
  anchor, are both parse failures worth reporting rather than skipping.

## Scope

**In:**

- A maintained, idempotent extraction script producing `spell_library.json`.
- A hand-edited resolution ledger recording every base-effect decision that
  required judgement, and the candidate set it was made against.
- Five asset assertions, including one oracle independent of the base effect.
- The **286 currently expressible spells**.
- Hand-derived breakdowns for the 3 fixed-level spells the rulebook prints no
  design line for.
- Retiring `loadSpellLibrary`'s hardcoded count (item 5's stated reasoning for
  leaving it no longer holds).
- Correcting `Citation.page`'s doc comment.
- Item 23's `spell_library.json` formatting inconsistency, fixed for free by
  regeneration.

**Out:**

- The **74 spells blocked** by todo items 24, 25, 26, 19, 18, 4 and 28. They are
  imported as each blocker clears; the harness reports the count rising.
- Page numbers. `Citation.page` is nullable and its doc comment says page numbers
  "arrive with the spell-parsing work" — but the reviewed markdown carries no
  page markers, only prose cross-references of the form "see page 213". The
  promise cannot be kept from this source. The field stays null and the comment
  is corrected rather than left to mislead the next reader.
- Supplement spellbooks. One rulebook at a time.

### The 74 blocked spells

| Family | Spells | Item |
|---|---|---|
| General-level — base level is chosen, not fixed | 33 | 25 |
| Ad-hoc per-spell magnitude (`+1 fancy effect`) | 21 | 24 |
| Ritual only by storyguide ruling | 7 | 18 |
| Non-standard Range/Duration/Target | 6 | 26 |
| Guideline level absent from the rulebook's own table | 5 | 28 |
| Size ladder above +4 | 4 | 19 |
| Ward mechanics in the design line | 1 | 4 |

Families overlap, so these sum to more than 74.

## Design

### Three artifacts

```
scripts/import/extract_spells.py    maintained, idempotent, re-runnable
scripts/import/resolutions.json     the ledger — hand-edited, never written by the script
assets/data/spell_library.json      generated output, committed
```

The script reads the rulebook plus `base_effects.json`, `parameters.json` and
`modifiers.json`, and writes the library. Re-running against an unchanged ledger
and unchanged catalogs produces byte-identical output.

This follows the `scripts/` precedent set by `flag_ritual_effects.py` — Python,
committed, headed by a comment stating its status — but differs in kind: that one
is explicitly one-shot and marked "do not re-run." This one is meant to be re-run,
and says so.

Spell ids follow the existing convention, `lib-<techform>-<name-slug>`
(`lib-crim-talking-head`), generated and collision-checked rather than
hand-assigned.

### The extractor narrows; it does not decide

For each spell the script emits every mechanically-determined field, and for the
base effect it emits a **candidate list** filtered by Technique, Form and the
design line's stated base level. Where exactly one candidate exists it resolves
outright. Where more than one exists it consults the ledger, and if the ledger
has no entry it writes the spell to `resolutions.proposed.json` and **fails**.

The script never writes `resolutions.json`. A generated file that silently
rewrites the human decisions it depends on is not a ledger.

### Ledger format

```json
"lib-cran-weavers-trap-of-webs": {
  "baseEffectId": "cran-5a",
  "candidates": ["cran-5a", "cran-5b", "cran-5c"],
  "rationale": "Grows spider webs; cran-5a is 'Create an animal product, such as spidersilk or wool'."
}
```

Recording `candidates` is what keeps the ledger honest over time. Todo item 22
adds guideline rows to Creo Animal, Creo Corpus, Rego Animal, Rego Mentem, Muto
Aquam and Muto Terram. When it lands, the candidate set for affected spells
changes — and a decision made when there were three candidates deserves
re-examination when there are four. Comparing the recorded set against the
freshly computed one turns that from something someone might remember into
something the build enforces.

Entries are required only where judgement was exercised. An entry for an
unambiguous spell is rejected, to keep the ledger a record of decisions rather
than a second copy of the library — except as an explicit override, which needs
a rationale like any other decision.

### Five assertions

1. **Level equality.** Computed level equals printed level, for every published
   spell. Catches parameter, modifier, requisite and ritual-floor mistakes.

2. **Ritual agreement.** Derived `RitualStatus.isRitual` matches the source's
   printed Ritual flag, spell by spell, over whatever is imported. Nothing may
   derive as a Ritual that the rulebook does not print as one, and nothing
   printed as one may fail to.

   **This is the assertion that carries the design.** It is a second oracle that
   does not depend on the base effect being right, and it is sensitive to
   precisely the things assertion 1 is blind to.

   **State it per-spell, not as a count.** 39 of the 360 print `Ritual`, but only
   **19 of those fall in the importable 286** — the other 20 are blocked by items
   25, 24, 18 and 19, several of them *because* of how their Ritual status is
   expressed. A count assertion would therefore be wrong on the day it lands and
   would need editing every time a blocker clears. Per-spell agreement is correct
   at every intermediate state and needs no maintenance.

   It also gives item 18 a regression target: of the 39, 32 derive correctly from
   Year duration, Boundary target, level > 50, or the Creo+Momentary checkbox.
   The 7 that do not are named in that item.

3. **Resolution completeness.** Every spell whose base effect had more than one
   candidate has a ledger entry, and no entry's recorded candidate set differs
   from the computed one.

4. **Reference integrity.** Every `baseEffectId`, `rangeId`, `durationId`,
   `targetId`, modifier id and option id resolves. Extends the existing
   "every spell's referenced ids exist" test to the new volume.

5. **Regeneration is clean.** Running the extractor produces no diff against the
   committed `spell_library.json`. This is what stops a hand-edit to the
   generated file from surviving unnoticed until the next regeneration silently
   discards it.

Assertion 5's count derivation replaces `loadSpellLibrary`'s hardcoded literal.
Item 5 deliberately left that literal in place, reasoning that the library was
"small, hand-curated, changed in deliberate reviewed batches, not bulk-extracted."
Every clause of that reasoning stops being true here.

### The three spells with no printed design line

Five further spells lack one but are General-level, so they belong to item 25.
These three are fixed-level and therefore expressible, needing only a derivation:

| Spell | Level | Source line |
|---|---|---|
| *Enchantment of the Scrying Pool* (InAq) | 30 | 12900 |
| *Whispering Winds* (InAu) | 15 | 13251 |
| *Hermes' Portal* (ReTe) | 75 | 15638 |

Each is derived by hand from its stat line and a chosen guideline, and each
derivation is then **checked by assertion 1** — if the derivation is wrong the
computed level will not equal the printed one. Hand-derivation under a test is a
different thing from hand-derivation on trust.

## Testing

- **Asset level** — the five assertions above, over the full generated library.
- **Extractor level** — unit coverage for the stat-line parser, the design-line
  tokenizer and the id slugger, using fixtures drawn from the awkward cases found
  during the audit rather than from the easy ones: a spell with a `Req:` line, one
  with a parenthesised comment inside its design line, one with `Base level 15`
  rather than `Base 15`, and one whose target is `Ind Reg: Terram`.
- **Ledger level** — a stale entry fails; a missing entry fails; an entry for an
  unambiguous spell fails.

Note that `flutter test` does not run `integration_test/` (todo item 6). Nothing
here needs a device, so all of it must live under `test/` and run in the default
suite. A 360-spell asset test that only runs on demand is a 360-spell asset test
that rots.

## Risks

| Risk | Mitigation |
|---|---|
| Wrong base effect at the same level ships silently | Ledger + assertion 3; assertion 2 as an independent oracle |
| A hand-edit to the generated library is later discarded | Assertion 5 |
| Catalog growth invalidates decisions made against an older candidate set | Candidate set recorded in the ledger; mismatch fails the build |
| Rulebook markdown structure defects | **Already encountered.** The Creo Terram spells sit under a `### Creo Terram Guidelines` heading with no corresponding `### Creo Terram Spells` heading. A parser keying off the `Spells` suffix files four spells — including *Conjuring the Mystic Tower* — under Rego Mentem. Anchoring on the stat line contains the damage but does not cure it: the anchor fixes *which* blocks are spells, while Technique and Form still come from the section heading. So both apply — key off `### <Technique> <Form>` regardless of suffix, **and** assert every parsed spell had a Technique and Form actually set. |
| The audit's counts are wrong | The extractor is a second, independent implementation of the same parse. Where the two disagree, the disagreement is a finding, not a nuisance. 360, 286, 133, 186 and 39 are expected results to reconcile against, not targets to reproduce. |

## Deferred work, recorded

- **Page numbers** — not present in the reviewed markdown. Would need the PDF or
  a different source edition.
- **Supplement spellbooks** — deferred, but no longer an unknown. Resolving each
  5e supplement by source precedence (below) and anchoring on the stat line finds
  **2378 candidate spells across 43 books** — 6.6× the core rules — of which 88%
  carry a `(Base ...)` design line.

  The anchor generalises; the *decoration* does not. Where the Definitive Edition
  puts Technique, Form and level in headings, supplements put them on a line of
  their own in at least six shapes — `PeAn 20`, `InVi Level 20`, `MuAq(An) 20`,
  `CrVi General`, and, in *Realms of Power: Faerie*, `Empathy/Conjure 20`, which
  is not Hermetic magic at all and does not belong in this library. Separators
  vary too (`R: Personal. D: Conc. T: Touch`), and some books run the description
  onto the end of the stat line. So the per-book work is a small adapter for the
  identity line, not a new parser — which is worth knowing before anyone budgets
  for the second book.
- **Source precedence.** The same book appears in `reviewed/`, `wip/` and
  `raw-md/`, and they are not equivalent. Always resolve **`reviewed` → `wip` →
  `raw-md`**, taking the first hit, and never read `raw-md` for a book the other
  two have. `raw-md` is unreviewed OCR with word-internal case errors
  (`tHe Bitten toad`) and split ligatures (`infl icted`); it also holds two
  alternate copies of the core rules and a file marked `DO NOT USE`. Filenames
  differ across folders, so match on book title, not filename.

  This has a direct consequence here: the 604 base effects were extracted from
  `raw-md/Ars Magica 5e - Core Rules.md`, which under this rule is the wrong
  source — a reviewed Definitive Edition exists and is what this import reads.
  Todo item 22 reconciles the ~10 known differences; a systematic reconciliation
  of the two sources is separate work, and should end with the catalog rebuilt
  from `reviewed`.
- **The 74 blocked spells.** Each clears with its own todo item. The harness is
  built so that adding them is data plus ledger entries, not further test work.
