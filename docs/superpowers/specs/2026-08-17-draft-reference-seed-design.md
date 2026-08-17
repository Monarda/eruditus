# A Draft Should Start at Its Guideline's Own Reference Triple — Design

**Date:** 2026-08-17
**Status:** Approved for planning
**Closes:** todo item 60; todo item 38's first bullet (`SpellEngine.allParameters`
starts empty)

## Goal

A spell draft must always show a Range, a Duration and a Target, and those three
must start at the zero point the selected guideline is actually priced against.

Today `SpellDraft` leaves all three null (`lib/models/spell.dart:467-469`, no
defaults in the constructor at `:483-507`), so every empty draft renders three
blank dropdowns. Worse, a draft left at Personal/Momentary/Individual under a
guideline priced against Touch/Ring/Circle starts *below* its own zero point.

## Why It Matters: The Delta Model

`SpellEngine._parameterContribution` (`lib/engine/spell_engine.dart:226-229`)
charges each parameter as the difference between what the spell uses and what
its guideline was priced against — not as the raw magnitude:

> For an ordinary guideline the reference is Personal/Momentary/Individual, all
> magnitude 0, so the delta equals the raw magnitude and the emitted label is
> unchanged. That identity is why this is one code path and not a branch on
> `isGeneral`.

So a ward guideline (reference Touch/Ring/Circle) left at the blank-draft
default contributes **−1, −2, 0**. Three negative magnitudes can drive the level
below 1, which `validateSpellDraft` reports as *"Magnitudes reduce this spell
below level 1"* (`spell_engine.dart:107-123`). The caster is told their spell is
broken because the app never put them at the guideline's own starting point.

## The Explicit/Implicit Distinction Needs No Code

`BaseEffect.reference` already **defaults** to `ParameterTriple.standard()` —
Personal/Momentary/Individual — both in the constructor
(`base_effect.dart:122`) and when the field is absent from JSON (`:153-155`).

Therefore "the guideline's reference where explicit, the fixed default
otherwise" and "always `baseEffect.reference`" are **the same rule**, and the
second is the one to write. **Do not build an is-this-explicit predicate.** Item
38's open worry — that the model cannot tell an authored
Personal/Momentary/Individual from an unauthored one — is real, and is
irrelevant here precisely because both readings seed identically.

## Observable Footprint

Measured 2026-08-17 against `assets/data/base_effects.json` (609 entries):

| Reference triple | Count | Entries |
|---|---|---|
| `range-touch` / `duration-ring` / `target-circle` | 12 | `rean-gen`, `rean-gen-2`, `reaq-gen`, `reau-gen`, `reco-gen`, `rehe-gen`, `reig-gen`, `reim-G`, `reme-G`, `reme-G2`, `rete-G`, `revi-G1` |
| `range-personal` / `duration-momentary` / `target-vision` | 1 | `inim-G` |
| *(absent — falls back to standard)* | 596 | — |

All 13 are General guidelines. So this rule changes the seed for 13 guidelines
and leaves 596 at the flat default — which is why the wards are the only place
it is observable, and equally why it is worth doing.

Every seeded id resolves to an unscoped core parameter, verified against
`assets/data/parameters.json`. The catalog holds exactly one Form-scoped
parameter, `duration-fire` (Ignem/Imaginem), and it is never a reference.

## The Rule

One function, applied at every draft-shaping site. No special cases.

```
seedParameters(draft, previousReference, catalog) -> draft
  next = draft.baseEffect?.reference ?? ParameterTriple.standard()
  for slot in {range, duration, target}:
    if draft[slot] == null OR draft[slot].id == previousReference[slot]:
      candidate = catalog.firstWhereOrNull(p => p.id == next[slot])
      if candidate != null AND candidate.scope.appliesTo(form: draft.form):
        draft[slot] = candidate
```

`previousReference` is the **outgoing** guideline's reference —
`state.draft.baseEffect?.reference ?? ParameterTriple.standard()` — captured
before the draft is updated.

### Why the `== previousReference[slot]` Test

It is the decided answer to item 60's one open question: *does selecting a
guideline overwrite parameters the user already set?*

A parameter still holding the outgoing guideline's reference value is one the
user never moved off the seed, so it follows the new guideline's zero point. A
parameter holding anything else was chosen deliberately and survives. The test
is a value comparison against data already in hand — it introduces no
"touched" flag and no new state.

Worked cases:

| Outgoing ref | Draft | Incoming ref | Result |
|---|---|---|---|
| Personal/Momentary/Individual | Personal/Momentary/Individual | Touch/Ring/Circle | Touch/Ring/Circle — adopted |
| Personal/Momentary/Individual | Voice/Sun/Room | Touch/Ring/Circle | Voice/Sun/Room — kept |
| Touch/Ring/Circle | Touch/Ring/**Room** | Personal/Momentary/Individual | Personal/Momentary/**Room** — per-field |

The per-field third row is the point: the rule is evaluated one slot at a time,
so a caster who deliberately picked a Target keeps it while their untouched
Range and Duration re-seed.

This follows the precedent `BaseEffectSelected` already set for
`chosenBaseLevel` (`spell_creation_bloc.dart:107-113`): a documented
keep-or-clear rule reasoned from what the value still means, rather than a
blanket policy in either direction.

### The Two Guards

Both degrade rather than throw, matching the codebase's existing
"degrade, don't half-build" policy.

- **Unresolvable id** → the field is left exactly as it is. With an empty
  catalog every slot stays null, i.e. today's behaviour, so existing tests that
  construct a bare `SpellEngine` keep passing unchanged.
- **`scope.appliesTo` fails** → skip. A *custom* guideline whose `reference`
  names a Form-scoped parameter would otherwise write a value into a dropdown
  that filters it out, tripping the `DropdownButtonFormField` assertion that
  `_withPrunedFormScopedParameters` (`spell_creation_bloc.dart:379-388`) already
  documents. No catalog entry does this today; the guard is one line.

## Placement

A **private static** function in `lib/bloc/spell_creation/spell_creation_bloc.dart`,
taking `List<Parameter>` explicitly, plus a thin instance wrapper supplying
`spellEngine.allParameters`.

- **Static**, because the bloc's `super(...)` call must seed the initial state
  and cannot reference `this`. Constructor *parameters* are legal in an
  initializer list, so the engine is threaded through as a parameter. Being
  static and pure also makes the rule unit-testable with no bloc at all.
- **In the bloc**, not on `SpellEngine`, despite `_parameterById` living there.
  `ParameterTriple` answers "what is this *guideline* priced against"; the seed
  answers "where does a *draft* start". Reading the former to produce the latter
  is the whole point of this item, but they remain different questions. Every
  sibling draft-shaping helper — `_withPrunedModifiers`,
  `_withPrunedFormScopedParameters`, `_withRitualDeclaration`, `_prunedSlots` —
  is already a bloc-private function, and the bloc already reads
  `spellEngine.allModifiers` directly (`:241`), so the dependency direction is
  established.

## Call Sites

| Site | `previousReference` | Effect |
|---|---|---|
| `super(...)` initial state | standard | all three null → seeded |
| `SpellDiscarded` (`:328-329`) | standard | fresh draft, new id, seeded |
| post-save reset (`:512-515`) | standard | same |
| `BaseEffectSelected` (`:89-122`) | outgoing effect's reference | the adopt case |
| `TechniqueSelected` (`:44-69`) | outgoing effect's reference | guideline cleared → back to standard |
| `FormSelected` (`:70-88`) | outgoing effect's reference | as above, **and** refills a `duration-fire` that the Form change just pruned |
| `TemplateInstantiated` (`:276-323`) | — | **not called** |

`TemplateInstantiated` is deliberately excluded. A template's parameters are
published catalog data about that specific effect and must survive verbatim —
the same reasoning the handler already applies to `ritualDeclaration`.

Covering `TechniqueSelected`/`FormSelected` closes a hole reached by a different
door than item 60 describes: `_withPrunedFormScopedParameters` nulls a
`duration-fire` when the Form leaves Ignem/Imaginem, leaving the blank dropdown
this item exists to eliminate. The `draft[slot] == null` arm of the same rule
handles it, so this costs no extra branch.

## Ordering and Knock-On State

Seeding runs **before** the existing helpers in each handler, because they read
the parameters it writes.

- `_withPrunedModifiers` filters by `targetId` — an adopted Target must be
  visible to it.
- `_withRitualDeclaration` reads `duration.id == momentary`. Adopting
  `duration-ring` for a Creo ward correctly drops a `lastingCreation`
  declaration, because that declaration has become false.
- In `FormSelected`, the order is: prune Form-scoped → seed → prune modifiers →
  ritual. Pruning first is what creates the null the seed then fills.

**New behaviour required in `BaseEffectSelected`:** it must now prune
`containerMode` exactly as `TargetSelected` does
(`keepsMode = newTarget.targetType == TargetType.container`,
`spell_creation_bloc.dart:160-163`). It has never needed to before, because it
could not change the Target. Adopting `target-circle` is a container→container
move and keeps the mode; adopting `target-individual` away from a `Circle` must
clear it, or `validateSpellAgainstCatalog`'s check 9 rejects the save with no
visible cause.

`keepsMode` is computed from the **resulting** draft's Target, not from whether
the seed changed it. That is unconditionally safe: when the seed leaves the
Target alone, the mode can only be set if that Target is already a container
(the only path that sets a mode is `ContainerModeSelected`, and `TargetSelected`
prunes it otherwise), so the check is a no-op in exactly the cases where nothing
moved.

## Prerequisite: Item 38's First Bullet

**Item 60 cannot work without this**, which is why item 60 says it "probably
wants to land with it."

`main.dart:68` constructs `SpellEngine(allSpells: allSpells)` with no
parameters, defaulting `allParameters` to `const []`
(`spell_engine.dart:32`). The only thing that ever fills it is
`AvailableParametersSynced`, dispatched from a `BlocListener` in
`SpellCreationScreen` whose `listenWhen` fires **only on change**
(`spell_creation_screen.dart:44-50`). If `ConfigurationBloc` has already loaded
its parameters before the Create tab first builds, that listener never fires and
`allParameters` stays empty for the life of the app — so no seed id can ever
resolve to a `Parameter`.

**Fix:** pass `parameters: await configRepository.getAllParameters()` at
`SpellEngine` construction in `main.dart`. That call is already made two lines
above for `SpellResolver` (`main.dart:50`), so it costs one argument and no new
I/O.

This independently closes item 38's own bug: `SpellLibraryBloc` shares the same
engine instance (`main.dart:74`) and `main.dart`'s `IndexedStack` builds the
Library tab eagerly, so a saved General ward-type spell could have its reference
discount silently skipped and be momentarily overcharged, with no error
surfaced.

## Testing

**Rule, as a pure function:** adopt-when-untouched; keep-when-chosen; the
per-field mixed case; null-fill; empty-catalog degradation to today's nulls;
out-of-scope candidate skipped.

**Bloc, per call site:** initial state seeded; `SpellDiscarded` seeded with a
new draft id; post-save reset seeded; `BaseEffectSelected` adopting a ward's
Touch/Ring/Circle; `TechniqueSelected`/`FormSelected` returning to standard;
`FormSelected` refilling a pruned `duration-fire`; `TemplateInstantiated`
keeping template parameters verbatim.

**Knock-on state:** `target-circle` → `target-individual` clearing
`containerMode`; `target-circle` → another container Target keeping it;
adopting `duration-ring` dropping a `lastingCreation` declaration.

**Wiring:** `main.dart` passes a non-empty `allParameters` to `SpellEngine`.

## Explicitly Out of Scope

- **Live level recomputation** — todo item 59. The seed shrinks the window in
  which a draft has no level, but does not close it: a draft with no base effect
  still has none.
- **Any is-this-explicit predicate on `BaseEffect.reference`** — see above; the
  remaining half of item 38's last bullet stays open.
