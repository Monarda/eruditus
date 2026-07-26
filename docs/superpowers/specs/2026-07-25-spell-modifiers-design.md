# Spell Modifiers: unified magnitude-contributing options

**Date:** 2026-07-25
**Status:** Design agreed section-by-section in discussion; written spec pending review
**Supersedes:** todo items 3 (Size feature) and the magnitude-bearing parts of todo item 4 (out-of-scope base effects)

## Problem

Two todo items — the Size feature and the "~200 out-of-scope base effects" — are one body of work. Both break the same assumption: that a spell's level is `baseEffect.baseLevel` plus a flat set of magnitudes drawn only from Range, Duration, Target, requisites and special factors.

### The "~200 effects" figure is misleading

Of 604 built-in base effects, 217 carry a `notes` field. 130 of those are noted `"Variable base level"` or `"General entry; variable base level"` — but every one of them already has a correct integer `baseLevel`. The Perdo Imaginem run is 2, 3, 3, 4, 4, 5: each rung of the guideline's ladder was extracted as its own effect. That note is informational ("this guideline offers a range of levels"), not a defect. Those effects need no model change.

A further 14 notes describe runtime relationships the app displays as text and does not compute: conditional wards and level-dependent Might reduction, whose effect depends on the target creature's Might versus the spell's level.

A second audit pass — checking each flagged effect's description rather than trusting its note — eliminated two more apparent families. **The recurring trap: a note saying "material difficulty" or "Characteristic point scaling" often means the guideline's rungs were extracted as separate base effects, which is already correct modelling.** The test is whether the base level is quoted for *one* case with others adding magnitudes (a modifier), or whether each case has its own effect (no work needed).

The genuine functional gaps are **23 effects across 4 families**, plus Size, which applies broadly rather than to a countable set of effects:

| Family | Effects | Why it is a modifier |
|---|---|---|
| Material difficulty (Muto/Perdo/Rego Terram) | 17 | Base levels are quoted for dirt (`"Weaken dirt"`, `"Control or move dirt"`); harder materials add magnitudes |
| Unnatural context (Creo Auram: +1/+2/+4) | 3 | Base is the phenomenon; unnatural context adds magnitudes |
| Distance ladder (Rego Herbam, Ignem, Terram) | 3 | Base is 5 paces; greater distances add magnitudes |
| Size (all Forms) | applies broadly | Base is one Individual; larger targets add magnitudes |

**Not modifier families, despite their notes:**

- **Creo Terram material (5 effects)** — `crte-1` sand, `crte-3` stone/glass, `crte-5` base metal, `crte-15a` precious metal, `crte-25a` gemstone. Material *is* the base effect. This is why material difficulty scopes to three technique+form pairs and not to Terram as a whole.
- **Characteristic point scaling (6 effects)** — `creem-30` through `creem-55` are six separate effects at levels 30/35/40/45/50/55. Choosing "to no more than +2" *is* choosing `creem-40`.
- **Rego Imaginem additional senses (4 effects)** — already covered by the existing `reim-additional-senses` special factor, which migrates as part of the complexity group. No new definition.
- **Creo Vim variable complexity (4 effects)** — `crvi-G1` through `crvi-G4` are General entries whose level is bounded by the spell's own level. That is the deferred derived-output shape, not `option → magnitude`.

### Why one mechanism, not four features

All four reduce to the same shape: *a choice the caster makes that costs magnitudes.* They differ only in what they are scoped to and whether the choice is exclusive — both of which are field values, not behaviour. Building Size alone would mean building this machinery once and then three more times, and would leave the existing special-factor mechanism as a fifth near-duplicate.

`SpecialFactor` already implements the shape for one family. The 7 built-in special factors *are* the Imaginem complexity pattern: technique+form scoped, magnitude-bearing, multi-select, already feeding `calculateSpellLevel`. What it cannot express is (a) mutual exclusivity, (b) any scope other than technique+form, and (c) non-magnitude constraints.

### Explicitly not a plugin architecture

A strategy or handler interface was considered and rejected for this spec. With derived outputs out of scope (below), all four families are `option → magnitude`; four implementations of an interface whose bodies all read "return the selected option's magnitude" is speculative generality. The mechanism is data plus one interpreter.

Should the deferred derived-output patterns come into scope later, that judgement should be revisited — those read the final computed level and produce a different quantity, which is a genuinely different shape and the point at which a code seam earns its place.

## Scope

**In:**

- A unified `Modifier` model replacing `SpecialFactor`, with single and multi selection modes and flexible scoping.
- Data definitions for all four modifier families, plus migration of the existing special factors into the complexity group.
- Level calculation, validation, and pruning of stale selections.
- An itemised level breakdown in the Create tab.
- A collapsed-summary Modifiers section in the Create tab.
- Terram spells added to the built-in library so the asset pipeline exercises single-select and Form-scoped modifiers.

**Out, deliberately deferred:**

- **Derived outputs** — Creo Aquam `damage = +[spell level]`, Muto Aquam `Ease Factor +3 per magnitude`, Rego ward `Might ≤ level`, Ignem Might reduction. These stay descriptive text. They are not `option → magnitude` and want a different design.
- **Ritual** — 11 effects are Ritual-only. There is no Ritual concept anywhere in `lib/` and no Ritual entry in the Duration ladder, so this needs a new spell property before it needs a modifier. Deferred entirely to its own spec.
- **Size for Mentem and Vim** — the rulebook exempts both for Individual targets. Group sizing for them is determined by the number of minds or effects respectively, which is a different mechanism and out of scope.
- **User-authored modifiers** — modifiers ship as asset data. The model carries `source` from the outset so user-created modifiers drop in later without a schema change, but no Settings CRUD is built now.
- **Requisites are unaffected.** A requisite is an Art requirement, not a magnitude-bearing option, and keeps its own `requisites` list and UI section.

### Backward compatibility is not a goal

This is a prototype with no deployed users. No compatibility shims are written, no field is read under two names, and no id is frozen to preserve old references. This decision is what makes several choices below simpler than they would otherwise be.

## Domain model

```dart
enum ModifierSelectionMode { single, multi }

class ModifierOption {
  final String id;               // 'terram-material-gemstone'
  final String label;            // 'Gemstone'
  final String? description;
  final int magnitude;           // 2
  final String? baseIndividual;  // 'one cubic inch'
}

class Modifier {
  final String id;               // 'terram-material'
  final String name;             // 'Material difficulty'
  final String? description;
  final ModifierSelectionMode selectionMode;
  final ModifierScope scope;
  final List<ModifierOption> options;
  final String source;           // 'built-in' | 'user-created'
}

class ModifierScope {
  final String? technique;              // null = any technique
  final String? form;                   // null = any form
  final List<String> effectIds;         // empty = any effect within technique/form
  final List<String> excludeTechniques; // techniques the modifier never applies to
}
```

`scope.appliesTo(draft)` is true when the technique matches or is null, the technique is not in `excludeTechniques`, the form matches or is null, and `effectIds` is empty or contains the draft's base-effect id.

`excludeTechniques` exists because the rulebook states "Intellego spells are not affected by Target size". That is a Technique-wide exemption cutting across every Form, and a positive `technique` match cannot express it — the alternative would be one Size definition per Form *and* Technique, 40 in total.

`baseIndividual` on an option records what one Individual is for that choice, which is what the Size ladder multiplies. It carries no magnitude of its own.

### Selection storage

On both `Spell` and `SpellDraft`:

```dart
final Map<String, List<String>> selectedModifiers;   // modifierId → optionIds
```

Chosen over a flat list of option ids for O(1) lookup when rendering each applicable modifier, and because clearing one modifier's selection is a key removal rather than a filter over a global list.

This does not make an invalid state unrepresentable — a `single`-mode modifier can still hold two option ids in its list. Closing that properly needs a sealed `SingleSelection`/`MultiSelection` pair, which can itself contradict the definition's `selectionMode`, so it buys little for the added machinery. The invariant is enforced by validation instead. This is the one place the type is deliberately weaker than the rule.

## Scope binding: the 16 definitions

| Family | Scope | Mode | Definitions |
|---|---|---|---|
| Size | `form:` each of 8 Forms, technique null, `excludeTechniques: ['Intellego']` | single | 8 |
| Material difficulty *(also sets base Individual)* | `technique+form`: Muto/Terram, Perdo/Terram, Rego/Terram | single | 3 |
| Aquam base Individual | `form: 'Aquam'` | single | 1 |
| Unnatural context | `technique: 'Creo', form: 'Auram'` | single | 1 |
| Distance ladder | `effectIds: ['rrhe-10b', 'rrig-3c', 'rete-4']` | single | 1 |
| Complexity *(migrated)* | `technique+form` on Creo/Perdo/Rego Imaginem | multi | 3 |

The Form-only wildcard (technique null) is used by the Size ladders. Material difficulty deliberately does **not** use it: Creo Terram models material as the base effect, so a Terram-wide scope would wrongly offer a material modifier on top of `crte-5` "Create base metal".

The `effectIds` scope has exactly one user, the distance ladder, whose three effects sit in three different technique+form pairs and cannot be expressed any other way.

### Size follows the rulebook, not per-Form invention

Three rules from the core rules text govern this and correct an earlier assumption that each Form has its own bespoke ladder:

1. **The ladder is universal.** "Adding one magnitude (five levels) to the spell multiplies the maximum size of its target by ten." Every Form's rungs are therefore +0 (base), +1 (×10), +2 (×100) and so on. Only the *base Individual* differs per Form, and that is a label, not a magnitude.
2. **Mentem and Vim are exempt.** Both state "Size modifiers don't apply to … effects with Individual targets", so neither gets a ladder — 8, not 10.
3. **Intellego is exempt across all Forms**, handled by `excludeTechniques`.

### Base-Individual sub-types are modelled, not deferred

Aquam and Terram each define five base Individuals rather than one:

| Form | Sub-types |
|---|---|
| Aquam | water (pool 5 paces across, 2 deep) · naturally-occurring liquids (2 across, 1 deep) · processed liquids (1 across, ½ deep) · dangerous liquids (½ across, ⅕ deep) · poisons (a single dose) |
| Terram | sand/dirt/mud/clay (10 cubic paces) · stone (1 cubic pace) · base metals (1 cubic foot) · precious metals (1/10 cubic foot) · gemstones (1 cubic inch) |

**A sub-type carries no magnitude.** It fixes what one Individual is, which is the quantity the Size ladder then multiplies. This is why it lives on `ModifierOption.baseIndividual` rather than becoming a separate concept.

For Terram the material choice and the base-Individual choice are the same axis — picking gemstone both costs +2 difficulty and sets the base to one cubic inch — so the three material modifiers carry both, and grow from 3 options to 5: base metals, precious metals and gemstones all cost +2 but have different base Individuals. Creo Terram needs no such modifier because its five effects (`crte-1` … `crte-25a`) already encode the material.

Aquam gets a standalone modifier whose five options are all magnitude 0, since nothing in Aquam varies difficulty by sub-type.

The Imaginem migration groups today's independent factors into one multi-select `Modifier` per technique+form — three checkboxes under a "Complexity" heading rather than three loose ones. Behaviourally identical, since multi-select over options is equivalent to independent toggles.

The most modifiers any single spell can attract is three, and exactly one effect hits that ceiling: `rete-4` (Rego Terram, transport a non-living object) draws Size, material difficulty and the distance ladder at once. It is therefore the natural fixture for multi-modifier tests. Every other affected effect draws one or two.

## Engine

`SpellEngine.allSpecialFactors` / `updateSpecialFactors` become `allModifiers` / `updateModifiers`, preserving the existing seam that lets Settings changes reach the Create tab without a restart. `calculateSpellLevel` takes `selectedModifiers` in place of `selectedSpecialFactorIds`.

Selected options resolve to magnitudes and append to the existing magnitude list. **Magnitude order does not matter:** `SpellLevelCalculator` splits each magnitude against a shrinking additive capacity, which looks order-sensitive, but the total reduces to `base + min(total, cap) + max(0, total − cap) × 5`. Modifier magnitudes are safe wherever they land in the list.

Resolution keeps the existing dangling-reference tolerance: an unresolvable option id contributes **0 magnitude rather than throwing**, because `SpellLibraryBloc` computes a level for every saved spell on load and one bad reference would otherwise drop the whole Library tab into its error state.

### Validation

In `validateSpellDraft`:

- A `single`-mode modifier with more than one selected option → error.
- An option id absent from its modifier's option list → 0 magnitude, no error, consistent with dangling factors.
- Modifiers are **optional**. No selection means no magnitude; nothing forces a Terram spell to declare a material.

### Pruning stale selections

Selections are scoped, so changing Technique, Form or base effect can leave a selection stranded, and a stranded selection silently changes the level. `TechniqueSelected`, `FormSelected` and `BaseEffectSelected` therefore drop any selection whose modifier no longer satisfies `scope.appliesTo`. This follows existing precedent — those handlers already null out `baseEffect`.

This behaviour is re-render dependent and is the single highest-risk item in this spec. See Testing.

## UI

### Modifiers section

A collapsed summary row, expandable on demand, placed after Requisites:

- Collapsed: the modifier group's name, a count of selected options, and a `+N` magnitude badge.
- Expanded: one control per applicable modifier — a dropdown for `single` mode, checkboxes for `multi`.
- When no modifier applies to the current Technique+Form+effect, the section is absent entirely.

The aggregate contribution stays visible while collapsed via the `+N` badge, so a pruning event changes something the user can see even without expanding.

### Level breakdown

The calculated-level card lists each contribution and the final level:

```
Calculated spell level                 10

Base effect · image, two senses         2
Range · Voice                          +2
Duration · Momentary                   +0
Target · Individual                    +0
Requisite · Auram, adding              +1
Size · Individual                      +0
Complexity · sensory                   +1
```

The total magnitude and the additive-tier/multiplier split are **not** shown. Showing a magnitude total beside the level invites "why isn't 2 + 4 = 6?", which only the tier split answers; both are deferred together. This means the relationship between the listed contributions and the final number is not fully explained by the panel — an accepted consequence, recorded here because it is the panel's main limitation.

This requires `calculateSpellLevel` to return a structured result rather than a bare `int`.

## Persistence and migration

`spells.data` is a JSON blob, so the spell-shape change needs no column change — only the blob contents become invalid.

- Database version goes 1 → 2. The `onUpgrade` handler **drops every table and re-runs `onCreate`**. There is no `onUpgrade` today.
- This **destroys any locally saved spells and custom configuration.** Accepted: prototype, no deployed users, and it is self-healing rather than failing confusingly.
- `custom_factors` becomes `custom_modifiers`.

### Data and code changes

- `assets/data/special_factors.json` → `modifiers.json`, holding the 16 definitions.
- `SpecialFactor`, its serialization and its test are deleted. `selectedSpecialFactorIds` is removed outright, not read as a fallback.
- `ConfigurationBloc`'s factor plumbing is renamed rather than removed — it is the seam authorability will use later.
- 10 of the 27 built-in spell assets reference factor ids (`lib-crim-talking-head`, `lib-crim-phantasmal-animal`, `lib-crim-human-form`, `lib-crim-haunt`, `lib-peim-veil-of-invisibility`, `lib-peim-smothered-sound`, `lib-reim-wizards-sidestep`, `lib-reim-captive-voice`, `lib-reim-confusion-insane-vibrations`, `lib-reim-wizard-torn`). Their references become `selectedModifiers` maps, **preserving magnitudes exactly** so their stated levels still verify against calculation.

### Content extraction tasks

Two deliverables are rulebook extractions, handled the same way the 604 base effects were — a defined task against a named source, not open questions:

1. **Size ladders for 8 Forms** (all but Mentem and Vim), each `excludeTechniques: ['Intellego']`. The rungs are the universal ×10 progression, so this is authoring labels and base-Individual text rather than deriving magnitudes. The `Size` parameter category is currently empty; there is no Size data in the repo. Base Individuals come from the rulebook's `#### Base Individuals` table.
2. **3–4 Terram library spells**, with their stated levels, chosen to cover a material selection, a Size selection, and one carrying both.

## Testing

The layering here is deliberate, informed by two failures earlier in this project: a crash that 6 passing widget tests could not see, and an integration test that had been broken for several commits without anyone noticing.

- **Model** — round-trip for `Modifier`, `ModifierOption`, `ModifierScope`; an `appliesTo` matrix covering each wildcard combination (technique-only, form-only, both, `effectIds` hit and miss).
- **Engine** — magnitude summing for both selection modes; unresolvable option id contributes 0 rather than throwing; a `single`-mode modifier with two selected options produces a validation error; breakdown contents match the contributing sources.
- **Bloc** — selection and deselection; pruning on `TechniqueSelected`, `FormSelected` and `BaseEffectSelected`.
- **Asset integrity** — every modifier's `scope.effectIds` resolves to a real effect, mirroring the existing "every spell's referenced ids exist" test. This is what catches typos across 16 hand-authored definitions.
- **Widget** — collapsed summary renders the count and `+N` badge; expanding shows a dropdown for single mode and checkboxes for multi.
- **Integration, real bloc, mandatory** — select a modifier, change Form, assert the selection is pruned and the badge updates. Pruning is re-render dependent, and mocked widget tests emit no new state, so they are structurally incapable of catching it. Run via `flutter test integration_test/<file> -d windows`; `flutter test` alone does not execute this directory.

### Why Terram matters to the test set

All 27 built-in spells are Imaginem. Without new library content, the asset-level "calculated level matches stated level" test would exercise only multi-select complexity on Imaginem, leaving no asset-pipeline coverage of single-select modifiers, of Form-only wildcard scoping, or of 7 of the 8 Size ladders.

### Pre-existing failures

5 tests fail before this work starts (3 in `configuration_bloc_test.dart`, 2 in `asset_data_loader_test.dart`), caused by stale effect-count expectations from the base-effects extraction. They are tracked as todo item 5 and are not in scope here; implementation should confirm the count stays at 5 rather than treating a green run as the bar.

## Risks

| Risk | Mitigation |
|---|---|
| Pruning silently changes a level | Integration coverage with a real bloc; `+N` badge visible while collapsed |
| Typos across 16 hand-authored definitions | Asset-integrity test resolving every `effectIds` entry |
| Migration breaks the 10 Imaginem spells' verified levels | Magnitudes preserved exactly; existing calculated-vs-stated test guards it |
| `single`-mode invariant violated in stored data | Validation rule; accepted as a validation concern rather than a type-level one |
| Size ladder data unavailable or inaccurate | Framed as a rulebook extraction task with a named source, as with base effects |

## Deferred work, recorded

- Derived outputs — 7 effects whose result scales with the final level (damage, Ease Factor), plus the 14 Might-threshold and Might-reduction effects. Needs a code seam, not data.
- Ritual as a spell property, plus Ritual-only validation for 11 effects, and 1 further effect constrained to Momentary duration.
- **Requisite hints** — 7 effects carry notes of the form `"Requires Animal requisite"` (also Terram, Herbam, Auram, Mentem). The requisites feature already exists, so these could pre-populate a requisite when such an effect is selected. Surfaced during this spec's data audit; not a modifier and not in scope.
- **One genuinely variable base level** — a single Muto effect noted `"variable base level (depends on target and transformation complexity)"` has no fixed level in the rules. It is the lone case matching the original out-of-scope document's "variable base" pattern, and the only one of the 130 variable-base notes that is not simply informational.
- 3 Muto Vim effects carrying constraint notes on what may be changed.
- Size interaction with non-Individual Targets. The rulebook sizes Part, Group, Room, Structure and Boundary independently (a base Group is ten Individuals, a base Room holds a hundred). This spec's ladders assume Target Individual; sizing the other Targets is a further piece of work.
- User-authored modifiers in Settings.
- Magnitude total and additive-tier/multiplier split in the breakdown panel.
