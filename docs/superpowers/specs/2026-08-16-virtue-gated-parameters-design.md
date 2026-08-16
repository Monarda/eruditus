# Virtue-Gated Parameters: Merinita Faerie Magic and Symbolic Magic — Design

**Date:** 2026-08-16
**Status:** Approved for planning

## Goal

Close todo item 17: add the 6 Faerie Magic and 3 Symbolic Magic parameters
that item 17 has left blocked since 2026-07-27, by giving `Parameter` a
Virtue-gating mechanism scoped to what the app actually is — a spell/catalog
calculator with no character model, not a character sheet. Also close the one
Form-scoped parameter (Fire) and the one ritual-only Range gap (Symbol Range)
this uncovers, and land one worked, citable example spell so the mechanism is
proven against real content rather than synthetic fixtures alone.

## Rulebook Basis

- **Merinita — Faerie Magic**, Core Rules ("Definitive Edition"), lines
  10022–10046. *"Initiates of the Outer Mystery gain access to special
  Ranges, Durations, and Targets... Spells created using these parameters can
  only be learned by characters with Faerie Magic."* (line 10030)
- **Symbolic Magic (Major Folk Mystery)**, *Houses of Hermes: Mystery Cults*,
  lines 3743–3763 — grants the Symbol Range/Duration/Target triad, each
  individually stated to require a ritual.
- **Faerie Chains of the Familiar Slave**, *Houses of Hermes: Mystery Cults*,
  lines 3371–3387 — the worked example, chosen because it is explicitly
  gated (*"it may be invented by anyone who has been Initiated into the
  Outer Mystery of Faerie Magic"*) and uses Until (Condition), one of the six
  new parameters, directly.

## Out of Scope (deliberately)

- **Real access control.** No character/Virtue/roster model is added. A
  Virtue-gated parameter is exactly as selectable as any other — the flag is
  informational, the same relationship `requiresRitual` already has to
  spell-saving (see Existing State). Confirmed with the user: building actual
  gating is a much larger, unrequested project.
- **Bargain's nested duration computation.** Its true level isn't
  `Base + magnitude` — the rulebook says to *"calculate the level of the
  spell that takes effect when the bargain is broken, and add three
  magnitudes"* (line 10038), a second nested calculation `SpellEngine`
  doesn't support (the same shape of problem as *Mists of Change*'s
  two-Durations-at-once `ExceptionSpell`). This design catalogs Bargain with
  `magnitude: 4` (Year's value) for consistency with every other Duration
  entry and documents the gap in a code comment; any real spell built on it
  would need `ExceptionSpell` treatment, not a computed `Spell`/
  `SpellTemplate`. **Filed as a new todo item** (see Deferred Follow-ups).
- **Open/variable requisites.** *Faerie Chains of the Familiar Slave*'s own
  requisite ("a Technique and Form appropriate to the creature's nature") is
  chosen per-casting, but `SpellTemplate.requisites` only supports fixed
  `{Art: kind}` pairs. Left empty (`requisites: {}`) with the gap noted in
  the template's description text. **Filed as a new todo item.**
- **A worked Symbolic Magic example spell.** No spell in the corpus uses
  Symbol Range/Duration/Target in a full stat block (confirmed: grepped the
  entire reviewed corpus). The 3 Symbolic Magic parameters are added for
  catalog completeness per the rulebook, same as many existing parameters and
  modifiers that have no single worked example combining them; not a blocker.

## Existing State (confirmed by reading the code, not assumed)

- `Parameter.requiresRitual` (`lib/models/parameter.dart`) is already a
  generic flag, not an id check, and its own doc comment says so explicitly:
  *"Deliberately a generic flag rather than an id check, because the Faerie
  and Symbolic Magic parameters of todo item 17 need the same treatment."*
  Nothing about it needs to change for the ritual half of this work.
- `RitualReason` (`lib/engine/ritual_status.dart`) is already named
  generically (`ritualOnlyDuration`, `ritualOnlyTarget`, not `yearDuration`/
  `boundaryTarget`) for exactly this reason — its own doc comment: *"todo
  item 17 adds three more ritual-only Durations and a reason called
  `yearDuration` would become a lie."*
- **Gap found in the same engine method:** `SpellEngine._deriveRitualStatus`
  (`lib/engine/spell_engine.dart:245`) only checks `duration.requiresRitual`
  and `target.requiresRitual` — it is never passed `range` at all. Symbol
  Range is the first ritual-only Range parameter the catalog will ever have,
  so this is a real correctness gap this item must close, not a pre-existing
  design choice to preserve.
- `ModifierScope` (`lib/models/modifier.dart`) is the precedent for scoping a
  catalog entry to specific Techniques/Forms, but its five axes
  (technique/form/effectIds/excludeTechniques/excludeTargets) are sized for
  `Modifier`'s needs. `Parameter` has no scoping concept at all today — every
  entry in `parameters.json` is universally offered.
- `ExceptionSpell` (`lib/models/exception_spell.dart`) exists for spells
  whose arithmetic genuinely doesn't compute — its own doc comment lists
  *Watching Ward*, *Wizard's Communion*, *Wizard's Vigil*, and *Aegis of the
  Hearth* as the General-kind, no-printed-level family. *Faerie Chains* was
  checked against this and rejected: its Duration (Until (Condition)) is a
  real, standard parameter once this item lands, unlike those four spells'
  genuinely unrepresentable event-triggered/dual durations.
- `SpellTemplate` (`lib/models/spell_template.dart`) is documented as
  *"everything a Spell has except a level"* and cites Core Rules line 12414
  directly: *"different levels of a General level spell are still different
  spells."* This is exactly *Faerie Chains*'s shape — its level depends on
  the target creature's Might, chosen per-casting, same as any other General
  guideline's caster-chosen level.
- `GeneralEffectKind.mightThreshold` already exists (*"Might Score less than
  or equal to the level of the spell"* family) and produces the sentence
  *"Affects beings with Might $value or less."* Paired with
  `offsetMagnitudes: -3`, `deriveGeneralEffect` computes
  `SpellLevelCalculator.calculate(chosenBaseLevel, [-3])` — at level 20 this
  reads "Affects beings with Might 5 or less," which is the exact inverse of
  *Faerie Chains*'s own rule ("level must be no less than Might + 15"). No
  new `GeneralEffectKind` is needed.

## Approach

### 1. `requiresVirtue` (informational Virtue-gating) — on both `Parameter` and `BaseEffect`

*Faerie Chains of the Familiar Slave* gates two different things
independently: its Duration (Until (Condition) — *"also requires a Ritual
spell"*, and per the Faerie Magic section, usable only by Faerie Magic
initiates) **and its base effect itself** (line 3373: *"it may be invented
by anyone who has been Initiated into the Outer Mystery of Faerie Magic"*).
A spell could in principle use an ordinary, unrestricted base effect with a
Virtue-gated parameter, or a Virtue-gated base effect with only ordinary
parameters — the two are independent facts the rulebook states separately,
so both models need the field, not just `Parameter`.

Add the identical nullable field to both `lib/models/parameter.dart` and
`lib/models/base_effect.dart` (plain duplication, matching this codebase's
existing style of composing small flags per-model rather than a shared
mixin — e.g. `requiresRitual` has no equivalent base class either):

```dart
/// The Mystery Virtue the rulebook requires to use this parameter (e.g.
/// "Faerie Magic"), or null for a parameter anyone can use. Informational
/// only, like requiresRitual's relationship to spell-saving -- the app has
/// no character/Virtue model, so nothing is actually gated. See todo item 17.
final String? requiresVirtue;
```

On `Parameter`, this sits alongside the existing `requiresRitual`. On
`BaseEffect`, it sits alongside the existing `ritualRequirement` enum — no
"suggested" state is needed here, since the rulebook never hedges on Virtue
requirements the way it does on Ritual ones, so a plain nullable `String` (not
a 3-state enum) is the right shape for both models. Both round-trip through
`toMap`/`fromMap` the same way `requiresRitual` does (key omitted or `null`
when absent).

### 2. `ParameterScope` (Fire's Form restriction)

New, deliberately small class in `lib/models/parameter.dart` (not a new
file — `Parameter` is still one small model, unlike `Modifier`'s already
multi-class file):

```dart
/// Which Forms a parameter is offered for. Empty means unrestricted.
/// Only a Forms list -- no Technique axis, no exclude-lists, no effectIds --
/// because Fire is the only parameter across all 9 new entries that needs
/// scoping at all. Extend when real evidence demands it, not preemptively.
class ParameterScope {
  final List<String> forms;
  const ParameterScope({this.forms = const []});

  // form is nullable, not required, matching ModifierScope.appliesTo --
  // draft.form is String? (unset until the user picks one).
  bool appliesTo({String? form}) => forms.isEmpty || forms.contains(form);

  Map<String, dynamic> toMap() => {'forms': forms};
  factory ParameterScope.fromMap(Map<String, dynamic>? map) => ParameterScope(
        forms: map == null ? const [] : List<String>.from(map['forms'] as List? ?? const []),
      );
}
```

`Parameter` gets `final ParameterScope scope;` defaulting to
`const ParameterScope()` (unrestricted) — every existing parameter round-trips
unchanged (`fromMap` treats an absent `scope` key as unrestricted, same
default-tolerance convention as `requiresRitual`).

### 3. Dropdown filtering (`spell_creation_screen.dart`)

`_buildParameterDropdown` currently filters only by `category`
(`lib/presentation/screens/spell_creation_screen.dart:574`). Add a scope
filter, mirroring the existing `modifiersForSelection` pattern at line 69:

```dart
final categoryParameters = parameters
    .where((p) => p.category == category && p.scope.appliesTo(form: draft.form))
    .toList();
```

`draft.form` is already in scope at this call site (same object
`modifiersForSelection` reads).

### 4. Virtue-gating UI note

Each parameter dropdown item's label gets a trailing note when
`requiresVirtue` is set, e.g. `Until (Condition) (requires Faerie Magic)` —
consistent with how the existing item text already appends other qualifiers.
The base effect dropdown (`spell_creation_screen.dart`, the
`base-effect-dropdown` item builder that already appends
`(${e.isGeneral ? 'General' : 'Base ${e.baseLevel}'})`) gets the identical
trailing note for `BaseEffect.requiresVirtue`, e.g. *"Bind a supernatural
creature as a temporary familiar (General, requires Faerie Magic)"*. The
Ritual banner (`RitualSection`) is unaffected by either note; the Virtue
information lives on the pickers themselves, not the Ritual banner, since a
parameter or base effect can require a Virtue without being Ritual (Road) and
vice versa (Year, already Ritual, requires no Virtue).

`DropdownButtonFormField` reuses each item's widget for the closed-field
display, not just the open menu, so this note stays visible once a
Virtue-gated entry is selected — no separate persistent banner is needed for
that reason alone.

**Two known limitations, accepted rather than solved here:**

- Fire's Form restriction is explained nowhere — an out-of-scope Form simply
  never shows the item, so nobody learns *why* Fire is missing from a
  Creo Corpus draft, for instance.
- The base-effect dropdown's description text can be long enough that
  `TextOverflow.ellipsis` clips the trailing note — an existing risk for the
  `(General)`/`(Base N)` suffix today, marginally worse with
  `, requires Faerie Magic` appended.

Both were weighed against adding a caption line (`InputDecoration.helperText`)
or a single grouped requirements banner near `RitualSection`; kept as
trailing dropdown-item text for consistency with the existing
`(+magnitude)`/`(General)` pattern and to avoid a new widget for this item.

### 5. `RitualReason.ritualOnlyRange` (closing the engine gap)

`RitualReason` gains a fourth generically-named member,
`ritualOnlyRange`, alongside the existing `ritualOnlyDuration`/
`ritualOnlyTarget`. `SpellEngine._deriveRitualStatus` (line 245) takes a new
required `range` parameter and adds the reason when `range.requiresRitual`,
mirroring the existing duration/target checks exactly. The one call site
(line 192) already has `range` resolved locally for the breakdown.

`RitualSection._describe` (`lib/presentation/widgets/ritual_section.dart:47`)
gets a matching case, and the widget gains a `rangeName` field alongside its
existing `durationName`/`targetName`, wired the same way from
`spell_creation_screen.dart`.

### 6. The 9 new parameters (`assets/data/parameters.json`)

| id | name | category | magnitude | requiresRitual | requiresVirtue | scope |
|---|---|---|---|---|---|---|
| `range-road` | Road | Range | 2 (= Voice) | false | Faerie Magic | — |
| `duration-bargain` | Bargain | Duration | 4 (= Year; see Out of Scope) | false | Faerie Magic | — |
| `duration-fire` | Fire | Duration | 3 (= Moon) | false | Faerie Magic | forms: [Ignem, Imaginem] |
| `duration-until-condition` | Until (Condition) | Duration | 4 (= Year) | true | Faerie Magic | — |
| `duration-year-plus-one` | Year + 1 | Duration | 4 (= Year) | true | Faerie Magic | — |
| `target-bloodline` | Bloodline | Target | 3 (= Structure) | false | Faerie Magic | — |
| `range-symbol` | Symbol | Range | 4 (= Arcane Connection) | true | Symbolic Magic | — |
| `duration-symbol` | Symbol | Duration | 4 (= Year) | true | Symbolic Magic | — |
| `target-symbol` | Symbol | Target | 4 (= Boundary) | true | Symbolic Magic | — |

The 6 Faerie Magic entries cite `arm5-core`. The 3 Symbolic Magic entries
cite the new book (below).

### 7. New book: *Houses of Hermes: Mystery Cults*

Add to `assets/data/books.json`:

```json
{
  "id": "arm5-hohmc",
  "title": "Ars Magica 5e - Houses of Hermes: Mystery Cults",
  "abbreviation": "HoH:MC",
  "edition": "5e"
}
```

First supplement book in the catalog (previously only `arm5-core`).

### 8. New base effect: binding a temporary faerie familiar

New `BaseEffect` in `assets/data/base_effects.json`, sourced from *Houses of
Hermes: Mystery Cults* (not the core rules — confirmed by reading the Creo
Vim Guidelines table in the core rulebook directly; no row there covers this):

- `technique: "Creo"`, `form: "Vim"`, `baseLevel: null` (General)
- `ritualRequirement: RitualRequirement.required` (the text says *"This
  ritual binds..."* outright, independent of Until (Condition) also forcing
  it — same belt-and-suspenders pattern as other doubly-ritual entries)
- `requiresVirtue: "Faerie Magic"` — the base effect's own gate, independent
  of Until (Condition) also being Faerie-Magic-gated (line 3373: *"it may be
  invented by anyone who has been Initiated into the Outer Mystery of Faerie
  Magic"*). Same belt-and-suspenders relationship as the ritual requirement
  above: two independent rulebook statements, both recorded, neither implying
  the other.
- `effectFormula: GeneralEffectFormula(kind: mightThreshold, offsetMagnitudes: -3)`
- `description`: drawn from the rulebook's own summary of the effect.

### 9. The worked example: `SpellTemplate` for *Faerie Chains of the Familiar Slave*

New entry in `assets/data/spell_templates.json`:

- `technique: "Creo"`, `form: "Vim"`
- `rangeId: "range-touch"`, `durationId: "duration-until-condition"`,
  `targetId: "target-individual"`
- `baseEffectId`: the new base effect from step 8
- `requisites: {}` — the gap noted in Out of Scope, documented in the
  template's `description`
- `provenance`: `published`, citing `arm5-hohmc`

This is left level-open (as every `SpellTemplate` is) — the caster fills in
`chosenBaseLevel` based on the target creature's Might at instantiation time,
identically to how every other General guideline already works in this app.

## Deferred Follow-ups (new todo items)

1. **Bargain's nested duration computation** — `SpellEngine` cannot compute
   "level of the triggered spell + 3 magnitudes." Blocked on deciding whether
   this needs a new `SpellEngine` capability or every Bargain spell must be
   an `ExceptionSpell`.
2. **Open/variable requisites** — no published spell needing an
   any-Technique-and-Form-chosen-per-casting requisite has been importable
   until *Faerie Chains*. Same shape of gap as todo item 50's `ModifierScope`
   granularity problem, but for `SpellTemplate.requisites`/`Spell.requisites`
   instead.

## Testing Strategy

- **Model tests**: `Parameter.requiresVirtue` and `.scope` round-trip
  (`test/models/parameter_test.dart`), `ParameterScope.appliesTo` unit tests,
  `BaseEffect.requiresVirtue` round-trip (`test/models/base_effect_test.dart`).
- **Engine tests**: `RitualStatus`/`RitualReason.ritualOnlyRange` derivation
  (`test/engine/ritual_status_test.dart`, `test/engine/spell_engine_test.dart`)
  — a Range with `requiresRitual: true` produces the new reason; existing
  duration/target cases unaffected.
- **Widget tests**: parameter dropdown filters Fire out for non-Ignem/
  Imaginem Forms and back in when the Form changes
  (`test/presentation/screens/spell_creation_screen_test.dart`); the Virtue
  note renders when `requiresVirtue` is set on a parameter *and* on a base
  effect (two independent render sites); `RitualSection` renders the new
  `ritualOnlyRange` reason text.
- **Data tests**: `test/data/datasources/asset_data_loader_test.dart`-style
  coverage that the 9 new parameters load with the expected flags; a
  `published_spell_import_test.dart`-style assertion that the new
  `SpellTemplate` computes (once a `chosenBaseLevel` is supplied) and that
  its Ritual status derives correctly from Until (Condition).
- **Regeneration discipline**: none — this data is authored directly in
  `assets/data/*.json`, not produced by the Python import pipeline (which is
  scoped to the core-rules corpus only), so no `extract_spells.py` re-run is
  needed. `flutter test` is the full verification surface for this item.
