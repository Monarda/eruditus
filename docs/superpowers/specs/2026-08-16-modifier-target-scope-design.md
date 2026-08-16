# Target Restriction on ModifierScope — Design

**Date:** 2026-08-16
**Status:** Approved for planning

## Goal

Close todo item 19's remaining architectural gap: `ModifierScope` has no
Target axis, so `size-mentem` (the Mentem Size ladder) is offered and applies
uniformly regardless of Target, even though Core Rules line 14900 says Size
modifiers don't apply to Mentem effects with an Individual Target (Group,
Room, Structure and Boundary are unaffected by that exemption — minds can be
counted). Today's workaround is a description string
("Applies when targeting multiple minds via area targets") that nothing
enforces.

## Rulebook Basis

Core Rules line 14900: "Minds do not have a size, so size modifiers do not
apply to Mentem effects with **Individual** targets. However, minds can be
counted, so for Groups you still need to boost the size to affect more
people."

## Existing State (confirmed by reading the code, not assumed)

- `ModifierScope` already carries `excludeTechniques` for exactly this shape
  of problem — a carve-out a positive `technique`/`form` match can't express.
  Every Size ladder uses it to exclude Intellego. No positive allow-list
  field exists anywhere in the model; there is no precedent or current need
  for one on Target either — only one exclusion case (Individual, on
  `size-mentem`) is known.
- Target parameters are catalog-referenced by id (`target-individual`,
  `target-group`, `target-room`, `target-structure`, `target-boundary`, …,
  `assets/data/parameters.json`), the same way `baseEffectId` references
  `base_effects.json`. `ModifierScope.appliesTo()`'s existing `baseEffectId`
  parameter is the right precedent for how a new `targetId` parameter should
  read.
- `appliesTo()` is called from exactly two places today:
  - `spell_creation_screen.dart`'s `modifiersForSelection`, filtering which
    modifiers the creation-screen picker offers.
  - `SpellEngine.pruneModifierSelections`, which drops a selection whose
    modifier no longer applies after the draft changes.
- `pruneModifierSelections` is invoked (via `SpellCreationBloc._withPrunedModifiers`)
  from the `TechniqueSelected`, `FormSelected`, and `BaseEffectSelected`
  handlers only. **The `TargetSelected` handler
  (`spell_creation_bloc.dart:146-150`) does not prune at all.** This means a
  Target axis on `ModifierScope` would be inert without also fixing this: a
  caster who selects `size-mentem` while targeting Group, then switches to
  Individual, would keep the stale selection silently contributing magnitude
  — the exact live bug this item exists to close.
- Nothing today validates modifier-scope conformance at save time
  (`validateSpellAgainstCatalog`'s check 5 only checks `selectionMode`
  cardinality, not `appliesTo()`). Correctness rests entirely on the picker
  never offering an out-of-scope choice plus pruning catching drift after the
  fact. This is a pre-existing gap across all of `ModifierScope`'s axes, not
  specific to Target — see Out of Scope.

## Out of Scope

- **A `validateSpellAgainstCatalog` check enforcing modifier-scope
  conformance at save time.** The gap described above is real but pre-dates
  this item and applies equally to the existing technique/form/effectIds
  axes. Fixing it is a separate, later hardening item (item-40-shaped), not
  bundled into a Target-specific fix.
- **A positive `allowedTargets` field.** Only one exclusion case is known
  (`size-mentem` excludes Individual). `excludeTargets` matches the existing
  `excludeTechniques` precedent exactly; an allow-list can be added later
  without a breaking change if a case for it ever appears.
- **Any change to `calculateBreakdown`.** It already trusts `selectedModifiers`
  unconditionally for every axis; this item doesn't change that trust
  boundary, only what feeds it correctly via the picker and pruning.

## Approach

### Model (`lib/models/modifier.dart`)

`ModifierScope` gains a fourth scoping field, alongside `excludeTechniques`:

```dart
final List<String> excludeTargets; // target ids, e.g. "target-individual"
```

Defaults to `const []`; serialized/deserialized in `toMap()`/`fromMap()`
identically to `excludeTechniques`.

`appliesTo()` gains an optional `String? targetId` parameter and one new
check, in the same position as the existing exclude-technique check:

```dart
bool appliesTo({String? technique, String? form, String? baseEffectId, String? targetId}) {
  if (technique != null && excludeTechniques.contains(technique)) return false;
  if (targetId != null && excludeTargets.contains(targetId)) return false;
  if (this.technique != null && this.technique != technique) return false;
  if (this.form != null && this.form != form) return false;
  if (effectIds.isNotEmpty &&
      (baseEffectId == null || !effectIds.contains(baseEffectId))) {
    return false;
  }
  return true;
}
```

### Data (`assets/data/modifiers.json`)

`size-mentem`'s scope gains `"excludeTargets": ["target-individual"]`.

### Wiring (the part that actually fixes the bug)

- `SpellEngine.pruneModifierSelections` (`lib/engine/spell_engine.dart`)
  gains a `String? targetId` parameter, passed straight into `appliesTo()`.
- `SpellCreationBloc._withPrunedModifiers` (`spell_creation_bloc.dart:324`)
  passes `targetId: draft.target?.id` through to `pruneModifierSelections`.
  Since it reads from the already-updated `draft`, this one change covers
  all call sites uniformly — no per-handler special-casing needed.
- **The `TargetSelected` handler wraps its draft update in
  `_withPrunedModifiers`**, matching how `TechniqueSelected`/`FormSelected`/
  `BaseEffectSelected` already do. This is the behavior change: switching
  Target away from Individual (or onto it) now prunes any selection that no
  longer applies, the same way switching Form already does.
- `spell_creation_screen.dart`'s `modifiersForSelection` filter
  (`spell_creation_screen.dart:69-75`) passes `targetId: draft.target?.id`,
  so the picker stops offering `size-mentem` at all once Target is
  Individual, rather than relying solely on pruning to clean up after the
  fact.

### Tests

- **`test/models/modifier_test.dart`** — `excludeTargets` rejects a listed
  target id even when technique/form/effectIds all match; serialization
  round-trip includes `excludeTargets`.
- **`test/data/asset_modifier_integrity_test.dart`** — assert `size-mentem`'s
  `excludeTargets` contains `target-individual`, mirroring the existing
  `excludeTechniques` assertion for Intellego in the same file.
- **`test/engine/spell_engine_test.dart`** — `pruneModifierSelections` drops
  a `size-mentem` selection when called with `targetId: 'target-individual'`,
  and keeps it for `targetId: 'target-group'`.
- **`test/bloc/spell_creation_bloc_test.dart`** — select `size-mentem` on a
  Mentem draft targeting Group, dispatch
  `TargetSelected(targetIndividualParameter)`, assert `size-mentem` is gone
  from `state.draft.selectedModifiers`.
- **`test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`**
  (the existing file exercising scope-based show/hide of a modifier in the
  picker, e.g. its `Custom Complexity` case) — `size-mentem` is absent from
  the offered list when the draft's Target is Individual, present for Group.

## Testing Strategy

Standard `flutter test` coverage for the model, engine, bloc and widget
changes above. No Python import-pipeline code is touched (`modifiers.json`
is hand-maintained catalog data, not importer output), so no Python tests
are affected.
