# Guideline Level Derivation: ladders, and General guidelines with a committed level

**Todo item:** 28 ("Guideline Levels Absent from the Rulebook's Own Table")

**Status:** designed 2026-08-15

**Rulebook:** Core Rules Chapter 9 guideline tables; specific citations inline
below.

---

## Problem

5 published spells cite a base-effect level their guideline's own printed
table doesn't list, and the import harness blocks all 5 under one reason,
"no base effect at that Technique/Form/level":

- *Infernal Smoke of Death* (MuAu, base 25)
- *Fog of Confusion* (MuAu, base 2)
- *Wizard's Icy Grip* (PeIg, base 20)
- *The Enigma's Gift* (CrVi, base 20)
- *Sense of the Lingering Magic* (InVi, base 10)

Item 28's original framing treated these as one problem — "recoverable from
documented prose rules." Investigating each spell's actual guideline text
shows they aren't: **three distinct problem shapes hide behind one blocked
reason**, and a fourth spell doesn't resolve cleanly at all.

### Group A — extends a numbered ladder via a stated linear rule

*The Enigma's Gift* (Creo Vim): the guideline table prints levels 5/10/15
("give the target one/two/three Warping Points"), a clean, evenly-spaced
progression with no stated upper bound. The spell's own design line already
prints "(Base 20, ...)" and its prose says "gains four Warping Points" —
the fourth rung of the same progression, one step past what the table
bothered to print.

*Wizard's Icy Grip* (Perdo Ignem): the guideline's own preamble states the
rule explicitly — "For every five points by which the fire's damage exceeds
+5, add one magnitude to the level of the spell." Levels 5 (+5 damage) and 10
(+10 damage) are already printed rows; level 20 (+20 damage) is the same
rule, three magnitudes past the +5 baseline instead of two.

*Fog of Confusion* (Muto Auram): the guideline's own preamble states "Transforming
only one property of air generally lowers the level by one magnitude." The
spell's design line already prints "(Base 2, ...)"; `muau-3` ("Transform an
amount of air into another form of air") minus that one magnitude is exactly
2.

In every Group A case, the design line already tells you the base level —
nothing is being *derived* by this work. What's missing is a catalog row (or
equivalent) at that level, backed by the guideline's own stated rule.

### Group B — a General guideline, committed to one level by a published spell

*Infernal Smoke of Death* is built on `muau-gen`, the Muto Auram **General**
row ("Transform air into a gas doing +level damage") — which already exists
in the catalog. Its design line prints "(Base 25, ...)" too. But this is not
a missing-row problem: **the importer currently has no path for a published
spell that commits to one specific level of a General guideline to become a
concrete `Spell`.** Every published General-guideline spell today routes to
`build_template` (open level, caster picks at instantiation) — even when the
book prints one specific worked example at one specific level, as it does
here. `SpellTemplate`'s architecture is correct for the common case (a
General guideline genuinely is open-ended per Core Rules line 12414); this
spell is the case that architecture doesn't cover — a caster already made the
choice, in print, once.

### The spell that doesn't resolve

*Sense of the Lingering Magic* (Intellego Vim, base 10): its prose combines
InVi's General residue-detection row with the numbered level-5 "detect any
active magic" row, and neither alone nor an obvious combination produces base
10 without guessing at an unstated formula. **Left blocked.** This project's
established discipline (`KNOWN_UNRESOLVABLE`, the ledger, item 39) is to
record what's uncertain rather than fabricate a rule the rulebook doesn't
state. It stays under item 28, not item 39 — item 39 is explicitly about
choosing among *existing* candidate rows with no catalog gap; this spell has
a genuine catalog gap, it just isn't derivable, unlike its four siblings.

---

## Decisions taken

| # | Decision | Rationale |
|---|---|---|
| 1 | **Group A's three ladders unify their guideline's existing numbered rows into one base effect + a modifier ladder, not three separate new catalog rows** | Matches the codebase's existing `size-*` modifiers exactly: `selectionMode: single`, several options each costing one more magnitude. Adding `crvi-20`/`peig-20`/`muau-2` as three more standalone numbered rows would work but wastes the fact that a *rule*, not a coincidence, connects each rung — the ladder shape documents and generalizes the rule itself, the same reason item 28's own todo text preferred "model the prose rules" over "add derived rows" once a real pattern exists. |
| 2 | **The refactor is safe: zero corpus spells reference any of the 6 rows being restructured** (`crvi-5a`/`10a`/`15a`, `peig-5b`/`10b`) | Checked directly against `spell_library.json`/`spell_templates.json` before proposing the refactor, mirroring the same corpus-verification discipline the open-guideline-slots work established. No ledger entries, no re-import of existing spells, no risk to already-working data. |
| 3 | **The MuAu single-property discount is scoped to the whole Form, not one guideline row** | The preamble states it as a general rule for any Muto Auram effect, not a property of `muau-3` specifically. Scoping the modifier broadly (`technique: Muto, form: Auram`, no `effectIds`) makes it reusable the next time any MuAu spell needs it, matching the "model the rule, not the one spell" instruction that motivated Group A's whole approach. |
| 4 | **A negative-magnitude modifier option needs no new safety code** | `SpellEngine.calculateBreakdown` already folds every selected modifier's magnitude into the same `contributions` list that feeds `SpellLevelCalculator.calculate`, which already throws (surfaced to the UI as "Magnitudes reduce this spell below level 1") whenever the total drops below level 1 — the identical guard that already protects item 24's ad-hoc adjustments. Verified by reading `spell_engine.dart:123-187` directly, not assumed. |
| 5 | **Group B is resolved by a hand-verified table, not an automatic heuristic** | A rule like "no numbered match at this level → assume it's a General guideline's committed level" would misclassify Group A's own spells, which *also* have no numbered match at their exact level. Only a human can tell "this level is missing from the table" (Group A) apart from "this level was never meant to be in the table, because the guideline is General and this spell just picked one" (Group B). A small table (`GENERAL_LEVEL_BY_SPELL_ID`), mirroring `KNOWN_UNRESOLVABLE`/`REALM_BY_SPELL_ID`'s existing pattern exactly, keeps that judgment call auditable and explicit, the same discipline as every other hand-verified table in this importer. |
| 6 | **`Sense of the Lingering Magic` stays under item 28, not item 39** | Item 39 is explicitly scoped to spells with "no catalog gap" — multiple existing candidate rows, ambiguous only in which one applies. This spell has a genuine catalog gap (no InVi row at level 10); it just isn't derivable from the guideline text the way its four siblings are. Moving it to item 39 would blur a distinction the todo file already draws deliberately. |
| 7 | **Both ladders stop at the rung the corpus actually needs, not the furthest the rule could theoretically extend** | CrVi's progression (5→1WP, 10→2WP, 15→3WP) is inferred from three printed table points plus one derived point (20→4WP, confirmed by *The Enigma's Gift*'s own prose) — nothing in the rulebook states the pattern continues past 4 WP, so the ladder stops there rather than speculatively adding an untested 5th rung. PeIg's rule *is* stated as a general, open-ended formula ("for every five points..."), so its ladder fills the one gap between its two known points (+15 damage, between the printed +10 and the newly-needed +20) since that rung sits *between* two already-confirmed points on an explicit rule — a materially safer inference than extrapolating past the highest known point. |

---

## Design

### Group A: the two modifier ladders and the one broad discount

**CrVi Warping Point burst.** `crvi-5a` becomes the sole base effect (id
unchanged, `baseLevel: 5`), its description generalized from "...giving
target **one** Warping Point" to "...giving the target Warping Points" (the
count is now the modifier's job, not the base description's). `crvi-10a` and
`crvi-15a` are deleted — their content becomes modifier options. New modifier:

```json
{
  "id": "warping-point-burst",
  "name": "Warping Points",
  "description": "Each magnitude gives the target one more Warping Point",
  "selectionMode": "single",
  "scope": {"technique": "Creo", "form": "Vim", "effectIds": ["crvi-5a"]},
  "options": [
    {"id": "warping-point-burst-1", "label": "One Warping Point", "magnitude": 0},
    {"id": "warping-point-burst-2", "label": "Two Warping Points", "magnitude": 1},
    {"id": "warping-point-burst-3", "label": "Three Warping Points", "magnitude": 2},
    {"id": "warping-point-burst-4", "label": "Four Warping Points", "magnitude": 3}
  ]
}
```

`crvi-5b`/`10b`/`15b` (the Arcane Connection decay rows at the same levels)
are untouched — a different rule, already correctly modeled as three
separate rows, not part of this ladder.

**PeIg chill-damage.** `peig-5b` becomes the sole base effect (id unchanged,
`baseLevel: 5`), description generalized from "+5 damage" to "damage
scaling with the spell's level". `peig-10b` is deleted. New modifier:

```json
{
  "id": "chill-damage",
  "name": "Chill Damage",
  "description": "Every 5 points the damage exceeds +5 adds one magnitude",
  "selectionMode": "single",
  "scope": {"technique": "Perdo", "form": "Ignem", "effectIds": ["peig-5b"]},
  "options": [
    {"id": "chill-damage-5", "label": "+5 damage", "magnitude": 0},
    {"id": "chill-damage-10", "label": "+10 damage", "magnitude": 1},
    {"id": "chill-damage-15", "label": "+15 damage", "magnitude": 2},
    {"id": "chill-damage-20", "label": "+20 damage", "magnitude": 3}
  ]
}
```

`peig-5a`/`10a` (the unrelated "chill an object"/"destroy one aspect of a
fire" rows at the same levels) are untouched.

**MuAu single-property discount.** A new modifier, not attached to any one
effect id:

```json
{
  "id": "single-property-transformation",
  "name": "Single Property",
  "description": "Transforming only one property of air lowers the level by one magnitude",
  "selectionMode": "single",
  "scope": {"technique": "Muto", "form": "Auram"},
  "options": [
    {"id": "single-property-transformation-yes", "label": "Transforms only one property", "magnitude": -1}
  ]
}
```

`Fog of Confusion` imports as `muau-3` + this modifier selected. No safety
code needed for the negative magnitude (Decision 4).

### Group B: `GENERAL_LEVEL_BY_SPELL_ID`

A new hand-verified table in `extract_spells.py`, mirroring
`KNOWN_UNRESOLVABLE`'s placement and style exactly:

```python
# A published spell that commits to one specific level of a General
# guideline -- the guideline itself stays open-ended (Core Rules line
# 12414), but this particular published spell already made the choice, in
# print, once. Verified once per entry against the rulebook, never inferred
# ("no numbered match" is also true of every Group-A spell in item 28's
# design spec -- conflating the two would misclassify them).
GENERAL_LEVEL_BY_SPELL_ID = {
    "lib-muau-infernal-smoke-death": 25,
}
```

(The exact slug must be verified with `catalog_module.slug_id("Muto",
"Auram", "Infernal Smoke of Death")` during implementation, not assumed —
the stopword list can shift a guess.)

`extract_spells.py`'s numbered-resolution path, on finding zero numbered
candidates at the design line's base level, checks this table before giving
up: a hit routes to `emit.build_spell` with `base_effect_id` set to the
Technique+Form's General row and the table's level supplied as
`chosenBaseLevel` — the same field `Spell` already carries for exactly this
purpose (item 25), just filled by the importer instead of a caster. A miss
still blocks, unchanged from today.

This makes `build_spell` grow an optional `chosen_base_level: int | None`
parameter (defaulted, mirroring Part A's `realm_by_spell_id` lesson so no
pre-existing call site breaks), emitted as `"chosenBaseLevel"` in the
spell's dict only when non-null.

---

## Testing

- Dart: `SpellEngine` tests confirming the CrVi/PeIg ladders compute the
  right level at each rung, and that the MuAu discount's negative magnitude
  correctly throws via the existing `SpellLevelCalculator` guard when
  combined with a small enough base/parameters (proving Decision 4's claim,
  not just asserting it).
- Python: `catalog.py`/`emit.py` tests for both ladders' `_option_exists`
  wiring (mirroring the existing `_MODIFIER_OPTIONS` test coverage), and a
  new test for `GENERAL_LEVEL_BY_SPELL_ID`'s routing — a hit producing a
  `Spell` with the right `baseEffectId`/`chosenBaseLevel`, a miss still
  blocking.
- Corpus: after regeneration, all 4 resolvable spells (`The Enigma's Gift`,
  `Wizard's Icy Grip`, `Fog of Confusion`, `Infernal Smoke of Death`) import
  successfully; `Sense of the Lingering Magic` remains blocked, now with an
  updated reason noting it was investigated and needs a rules decision
  rather than "no base effect."

---

## Scope

One plan, not split — unlike the open-guideline-slots work, there's no
natural fault line here worth two review cycles. Group A (3 spells, pure
catalog/modifier data) and Group B (1 spell, new importer routing logic)
are small enough combined to stay one plan; Group B's code change
(`build_spell`'s new optional parameter) is a handful of lines, not a new
subsystem.

---

## What this deliberately does not do

- **It does not resolve `Sense of the Lingering Magic`.** Left blocked,
  with its reason updated to reflect investigation, not silence.
- **It does not build a general "General guideline + committed level"
  UI affordance.** `GENERAL_LEVEL_BY_SPELL_ID` is import-time only; nothing
  changes for a user creating a custom spell by hand — they still pick a
  General effect and type a level, exactly as today.
- **It does not extend either ladder past the rung the corpus needs.**
  See Decision 7. A future spell needing a 5th Warping Point or +25 chill
  damage adds one more option to an existing modifier — a small, low-risk
  change when it's actually needed, not now on spec.
- **It does not touch item 39's 4 spells** or any other blocked-spell
  bucket. Scope is exactly the 5 spells item 28 named.
