# Additive Guideline Modifiers — Design

**Status:** Approved, ready for planning.

## Problem

Item 28 (guideline-level-derivation, merged 2026-08-15) modeled three published
guidelines' prose scaling rules as modifiers instead of duplicated catalog rows.
Afterward, the user asked whether other Technique+Form guidelines have the same
"ladder" shape, and whether the goal should extend beyond unblocking imports to
also simplifying spell *creation* — letting a user design a new spell that needs
a rulebook-stated scaling rule the catalog currently has no way to represent at
all.

Two research passes (documented in full in the session that produced this spec)
answered both questions:

1. **A row-duplication scan** of `assets/data/base_effects.json` found 13
   Technique+Form families using the same "separate numbered row per rung"
   pattern item 28 refactored away — but confirmed none of them currently block
   any corpus spell. This is real technical debt, but fixing it means deleting
   rows and re-verifying every corpus reference per family (the same work item
   28's Task 1 did for `peig-10b`, including a near-miss a review cycle had to
   catch). It's tracked as backlog item 41, not part of this spec.

2. **A prose-first scan** of the rulebook's Chapter 9 guideline preambles (not
   just tables) for "add one magnitude" / "for every N" style formulas found 9
   rules that were *never* duplicated into rows at all — so the row-based scan
   could never have found them — meaning today there is simply no way to select
   these scaling choices when designing a spell. Two of the nine
   (Perdo Corpus disease Ease Factor, Creo/Muto Aquam poison Ease Factor) turned
   out to be a different kind of feature entirely (see "What this does not do")
   and are tracked separately as item 42. The remaining **7 rules**, plus **one
   scope hole** in an already-shipped modifier, are this spec's scope.

## Scope — 8 items

| # | Technique+Form | Rule | Base effects touched |
|---|---|---|---|
| 1 | Rego Herbam/Ignem/Terram (existing `rego-transport-distance`) | Scope fix — the modifier already encodes "add 1 magnitude for 50 paces, 2 for 500 paces, 3 for 1 league, 4 for 7 leagues, 5 for an Arcane Connection," verified verbatim in Rego Animal and Rego Aquam's own guideline text, but its `effectIds` omits both Forms' rows (`rean-10b`, `reaq-4b`) | None — one-line `effectIds` edit |
| 2 | Muto Ignem | "For every five points by which the fire's damage exceeds +5, add one magnitude to the level of the spell" (Core Rules ~line 14394) | None — new broadly-scoped modifier |
| 3 | Rego Ignem | Same wording, Core Rules ~line 14515 (a *different* Rego Ignem rule from the wards-vs-fire ladder in item 41 — this one covers changing/controlling an existing fire's intensity generally, not the specific warding-effect table) | None — new broadly-scoped modifier |
| 4 | Creo Animal | "To create treated animal products... add one magnitude... To create treated and processed animal products... add two magnitudes" (~line 12462) | None — new broadly-scoped modifier |
| 5 | Muto Herbam | "To change plants into treated or finished material... add one magnitude" (~line 14036) | None — new broadly-scoped modifier |
| 6 | Perdo Herbam | "Destroying live wood is usually a bit harder — add one magnitude" (~line 14102) | None — new broadly-scoped modifier |
| 7 | Perdo Auram | "Causing the destruction of air with great precision raises the magnitude by at least one level" (~line 13318) | None — new broadly-scoped modifier |
| 8 | Rego Auram | "Controlling an amount of air with great strength or great precision raises the magnitude of the spell by one level" (~line 13356) | None — new broadly-scoped modifier |

All line numbers are from the research pass and must be re-verified against the
exact current text of
`C:/Development/personal/Ars-Magica-Open-License/reviewed/Ars Magica -
Definitive Edition (Core Rules).md` during planning — the research pass
paraphrased some of this wording rather than quoting it character-for-character
throughout, and the `reviewed/` file's line numbers may have shifted since the
research pass read it.

## Architecture

No new mechanism. This reuses item 28's two established modifier shapes
exactly:

- **Multi-rung ladder** (mirrors `chill-damage`): a `selectionMode: single`
  modifier with several `ModifierOption`s at increasing magnitudes, for a rule
  stated as a repeating "+N per +M" formula. Items 2 and 3 (fire-intensity) use
  this shape — same rate as the already-shipped `chill-damage`, so their option
  ladders should mirror its rung count and magnitude spacing unless the exact
  rulebook wording for Muto/Rego Ignem's version states a different cap.
- **Small enumerated ladder** (2-3 explicit named tiers, not a repeating
  formula): items 4 and 5 (treated / treated-and-processed) — "add one
  magnitude" then "add two magnitudes" are two named tiers, not an open-ended
  rate, so these are `selectionMode: single` modifiers with 2 non-zero options
  (plus the implicit "neither" state of not selecting the modifier at all,
  matching the existing convention — see `single-property-transformation`,
  which has one option representing the "yes" state and no explicit "no"
  option).
- **Binary rider** (mirrors `single-property-transformation`): a single-option
  `selectionMode: single` modifier with one `+1`-magnitude option, for a rule
  stated as a flat "raises the magnitude by one" condition with no further
  scaling. Items 6, 7, 8 use this shape.

Every new modifier is **broadly scoped** — `technique`/`form` set, `effectIds`
empty — because none of these rules are tied to one specific base-effect row;
each is a general rider available across its whole Technique+Form's
guidelines, exactly like `single-property-transformation`'s scope
(`technique: "Muto", form: "Auram"`, no `effectIds`).

This track touches **only `assets/data/modifiers.json`** (plus the one-line
`effectIds` fix to the existing `rego-transport-distance` entry). Unlike item
28, it makes **no changes to `base_effects.json`, no importer changes, and no
`NUMBERED_OVERRIDES` entries** — nothing is deleted or re-resolved, since every
item here is either a pure addition or a one-line scope widening on an
already-correct modifier. This makes the whole track lower-risk and smaller
than item 28's core work.

## Testing

Dart `SpellEngine` tests per new modifier, mirroring item 28 Task 1's test
style exactly (construct a synthetic `Modifier`/`BaseEffect`, call
`calculateBreakdown`, assert the resulting level) — one test per rung/tier for
the ladder-shaped modifiers (items 2-5), one test for each binary rider (items
6-8) confirming the flat `+1` magnitude, plus the negative-magnitude-floor
safety test pattern (item 28 Decision 4) is not needed here since none of
these modifiers use a negative magnitude.

One Python test confirming the `rego-transport-distance` scope fix doesn't
disturb any existing corpus resolution — every spell that currently resolves
through `rehe-10b`/`reig-3c`/`rete-4` must still resolve identically after
`rean-10b`/`reaq-4b` are added to its scope (this is an additive scope change,
so no existing behavior should shift; the test exists to prove that, not
because the change is expected to break anything).

## What this does not do

- **Does not refactor any of the 13 row-duplication families** (Creo Ignem
  damage+shape, Rego Ignem wards-vs-fire, Rego Terram projectile, Rego Corpus
  transport, Creo Animal/Corpus/Mentem characteristic-increase, Muto Corpus
  Soak, Intellego Vim detect-magnitude, Creo/Intellego/Muto Imaginem senses,
  Perdo Vim AC-duration-steps, Creo Vim decay-steps). Recorded as backlog item
  41 with the full inventory.
- **Does not add a derived Ease Factor display** for Perdo Corpus disease or
  Creo/Muto Aquam poison scaling. Those rules describe a passive consequence of
  the spell's *final* level (however it got there), not a selectable modifier
  — closer to `craq-gen`'s `effectFormula` mechanism than to the modifier
  system. Recorded as backlog item 42.
- **Does not attempt an exhaustive prose scan of every rulebook chapter.** The
  research pass covered Chapter 9's 50 Technique+Form guideline sections in
  full; Vim's guidelines were scanned but excluded (their scaling is already
  handled via `effectFormula`, a different mechanism); material outside
  Chapter 9 (Hermetic Virtues/Flaws, Vis, appendices) was not scanned and may
  contain similar rules — out of scope for this pass.

## Decisions

1. **Split by risk, not by discovery order.** The additive track (this spec)
   and the refactor track (item 41) were found in the same research pass but
   split into separate specs because they have genuinely different risk
   profiles: additive changes can't break an existing corpus reference (there's
   nothing to delete), refactors can (and did, once, in item 28's Task 1).
2. **Ease Factor scaling is a different feature, not a modifier gap.** Caught
   during design rather than assumed from the research pass's raw finding —
   the research report listed it alongside the other 7 gaps, but re-reading the
   exact rulebook wording showed it scales with the spell's *total* level
   change from any source, not a specific selected choice, so treating it as a
   `selectionMode: single` modifier would be modeling the wrong mechanism.
3. **Ladder rung counts are not pinned by corpus need, unlike item 28.** Item
   28's ladders stopped at exactly the rung a real published spell needed
   (Decision 7 in that spec). These modifiers have no such anchor — no
   published spell in the corpus currently uses any of them (that's the whole
   point: they're needed for future spell design, not any current import).
   Rung counts should be grounded against how far the rulebook's own prose
   states the rule scales, verified during planning against the exact text,
   not guessed.
