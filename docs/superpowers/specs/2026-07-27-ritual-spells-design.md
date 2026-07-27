# Ritual Spells — Design

**Date:** 2026-07-27
**Status:** Approved for planning

## Goal

Model Ritual spells: which spells are Rituals, why, and what that does to the
calculated level. Closes todo item 4's "Ritual-Only Constraints" bullet, closes
the ritual-flag constraint todo item 15 deferred, and unblocks half of todo item
17 (Faerie/Symbolic Magic parameters, which need a ritual flag before they can
be added).

## Rulebook Basis

All line references are to
`Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md`.

The governing passage is "Ritual Spells" (line 12340). A spell is a Ritual when
any of the following holds:

| # | Condition | Source |
|---|---|---|
| 1 | Level **greater than** 50 | line 12346 |
| 2 | Duration **Year** | lines 12344, 12116 |
| 3 | Target **Boundary** | lines 12345, 12138 |
| 4 | The guideline requires it | line 12350 |
| 5 | A Momentary **Creo** spell creating a lasting thing | lines 12351, 12100 |
| 6 | The troupe judges the effect too spectacular to be freely available | line 12352 |

Conditions 1–4 are forced by the spell's own configuration. Conditions 5 and 6
are judgements only a person can make, so they must be recorded, not derived.

Two further consequences of being a Ritual:

- **Minimum level 20.** "Ritual spells are always at least level 20, even if the
  level calculation would make them lower" (line 12354). This is a level rule,
  not a flag.
- The reason a spell is a Ritual is itself load-bearing. An enchanted item may
  hold a spell that is a Ritual *only* because its level exceeds 50, but not one
  that is a Ritual for any other reason (line 10566). Nothing in this app
  enchants items yet, but a design that discards the reason forecloses it.

### Points the rulebook settles that the todo list got wrong

- **Ritual is not a Duration.** Todo item 4 says "if ritual-only, force Duration
  = Ritual". Ritual is a spell *type*, orthogonal to all eight Durations. That
  bullet is mistaken as written and this design does not implement it.
- **Vision Target does not force a Ritual**, despite sharing Boundary's +4
  magnitude. Line 12345 permits it for magical-sense spells explicitly.
- **Level exactly 50 is legal for a Formulaic spell.** The threshold is `> 50`,
  not `>= 50`: "they may have a level of 50, but not 51 or higher" (line 12346).
- **Healing is not a hard ritual requirement.** A healing spell cast other than
  as a Momentary Ritual "actually suspends the healing process so that, upon the
  spell's expiration, wounds are as fresh as they were when the spell was cast"
  (line 13415). A Sun-duration `Heal a Light Wound` is a legal Formulaic spell
  that does something different — not an error to reject.
- **Aegis of the Hearth needs no special case.** Its stat block is
  `R: Touch, D: Year, T: Bound, Ritual` (line 15934), so conditions 2 and 3 both
  fire. The "spells inherited from the Cult of Mercury are also Ritual spells"
  clause (line 12418) never needs to be reached for it.

## Out of Scope

- **The storyguide-ruling UI.** Condition 6 is added to the *model* so that data
  can express it and no second schema migration is needed later, but no control
  exposes it in this iteration. Recorded as a new todo item.
- **A `suggested` sweep over Creo *creation* guidelines.** Line 12176 makes every
  Creo creation as much a condition-5 case as healing is ("An item made with Creo
  only lasts for the duration of the spell, unless the spell was a Momentary
  Ritual"), which is hundreds of entries across all ten Forms. The default-on
  behaviour below makes the sweep unnecessary for correctness; it would only add
  explanatory text. Deliberately skipped, recorded as a todo item so the
  asymmetry with healing is a decision on file rather than an oversight.
- **The Size-ladder ceiling.** Every Size ladder stops at +4 (×10,000), which
  blocks the published ritual *Rain of Oil* (MuAu 50, `+5 size`) from the
  library. That is todo item 4's territory. Recorded as a todo item.
- **Casting mechanics.** Vis cost, casting time, Artes Liberales and Philosophiae
  in the casting total, long-term Fatigue — the app models spell *design*, not
  spellcasting, and none of it affects the level.
- **Faerie and Symbolic Magic ritual parameters** (`Until (Condition)`, `Bargain`,
  `Year + 1`, and the three Symbol parameters). Confirmed ritual-requiring during
  this research (line 10042), but blocked on todo item 17's Virtue-gating model.

## Approach: Derive It; Store Only the Declaration

`Spell` gains exactly one new persisted field, recording only what cannot be
derived. Everything else is computed from the catalog on every read.

This follows the pattern the id-reference normalization established and that
todo item 14 restates for container targets: storing derivable data is what that
work removed. A stored `isRitual` boolean would go stale the moment the catalog
moved — edit a custom parameter's flag, or change a Duration through a path that
forgets to recompute, and the record lies. Saved spells resolve their catalog
fresh on every load precisely so this cannot happen.

Deriving also yields the *reasons* for free, which the UI needs and which a
future item-enchantment feature cannot do without.

## Model Changes

### `Parameter` — `requiresRitual`

```dart
final bool requiresRitual;   // default false
```

JSON key absent means `false`. Set `true` on exactly two of the 25 entries:
`duration-year` and `target-boundary`. The rulebook states this rule *as a
property of the Duration and the Target* (lines 12116, 12138), so that is where
it lives.

### `BaseEffect` — `ritualRequirement`

```dart
enum RitualRequirement { none, suggested, required }
final RitualRequirement ritualRequirement;   // default none
```

Serialized by name; absent means `none`. An enum rather than two booleans
because the states are mutually exclusive and ordered — two booleans would admit
an impossible `required && suggested`. Parsing follows the existing
`ModifierSelectionMode` precedent exactly, including a `FormatException` naming
the valid values on an unknown name.

`required` forces a Ritual. `suggested` forces nothing; it drives explanatory
text only.

### `Spell` and `SpellDraft` — `ritualDeclaration`

```dart
enum RitualDeclaration { none, lastingCreation, storyguideRuling }
final RitualDeclaration ritualDeclaration;   // default none
```

Serialized by name; absent means `none`. `SpellDraft` carries the same field with
`copyWith` support.

An enum rather than a bool because the two declarations behave differently under
pruning (below) and a bool could not tell them apart. Adding `storyguideRuling`
now, while its UI is deferred, costs nothing and avoids a second schema bump —
the same reasoning todo item 14 gives for pairing its work with the provenance
change.

### Not changed: `Modifier`

Reusing `Modifier` was considered and rejected on three counts. `ModifierScope`
matches on technique, form and effect ids only, with no Duration axis, so it
cannot express "offer this only when Creo **and** Momentary". `ModifierOption`
carries a magnitude, and a Ritual adds none, so it would be a permanent zero row
in the level breakdown. And the minimum-level-20 floor is unexpressible as a
modifier under any encoding.

### Not changed: `notes` on `BaseEffect`

The existing prose stays. The flag serves the engine, the note serves the reader,
and several notes carry information the flag does not — `crte-25b` reads
"Variable base level; ritual-only", and deleting it would lose a variable-base-level
warning todo item 4 still needs.

## Engine

### `RitualStatus`

```dart
enum RitualReason {
  yearDuration,
  boundaryTarget,
  exceedsMaxFormulaicLevel,
  guideline,
  lastingCreation,
  storyguideRuling,
}

class RitualStatus {
  final bool isRitual;               // reasons.isNotEmpty
  final List<RitualReason> reasons;
}
```

Reasons **accumulate rather than short-circuit**. Aegis of the Hearth reports
both `yearDuration` and `boundaryTarget`. Anything less makes the UI text a lie
and makes the item-enchantment distinction (line 10566) underivable.

`LevelBreakdown` gains two fields: `ritualStatus`, and `rawLevel` — the level
before the floor is applied. Because it rides inside the breakdown the bloc
state already carries, no new state field is needed. `ResolvedSpell` gains a
`ritualDeclaration` passthrough getter alongside its existing record getters.

### Order of operations in `SpellEngine.calculateBreakdown`

1. Compute the raw level exactly as today.
2. Determine `RitualStatus` from: either parameter's `requiresRitual`; the base
   effect's `ritualRequirement == required`; `rawLevel > 50`; and
   `ritualDeclaration`.
3. If `isRitual` and `rawLevel < 20`, the level is 20. Otherwise it is `rawLevel`.

**The circularity is only apparent.** Step 3 raises a level *to* 20 and never
above it, so it can never push a level past 50 and re-trigger step 2. One pass
suffices; there is no fixed point to solve. This is asserted by a test, not left
as a comment, so the ordering stays provably correct if the constants change.

`SpellLevelCalculator.calculate` is **not** modified and its tests are
unchanged. It stays a pure magnitude-summing function; the floor is applied by
`SpellEngine`, the only layer that knows what a Ritual is.

The floor is **not** modelled as an extra `LevelContribution`. Contributions
carry magnitudes, and `LevelBreakdown.magnitudeTotal` sums them; a contribution
holding a level delta of `20 - rawLevel` would silently corrupt that sum. The UI
instead compares `level` against `rawLevel` and, when they differ, explains the
minimum in its own line — so a raw-level-2 calculation displaying as 20 is
explained without lying about the magnitudes.

### Declarations are honoured unconditionally

The engine accepts `lastingCreation` and `storyguideRuling` as reasons on any
spell, without re-checking Creo or Momentary. A storyguide ruling is legitimate
on any spell by definition, so a guard would be wrong. Keeping the draft honest
is the bloc's job, below.

## UI and Bloc

### `ritual_section.dart`

A new `lib/presentation/widgets/ritual_section.dart`, following the
`modifiers_section.dart` precedent. `spell_creation_screen.dart` is already 400+
lines with two inline `_build*` helpers and should not gain a third. It renders
two independent things:

1. A **status banner**, shown whenever `RitualStatus.isRitual`, listing every
   reason in plain words — "Ritual: Year duration; Boundary target".
   Non-interactive.
2. A **checkbox** (`Key('ritual-checkbox')`), shown only when
   `draft.technique == 'Creo' && draft.duration?.id == 'duration-momentary'`.
   It sets `ritualDeclaration` to `lastingCreation` or `none`.

Both may appear at once. A Creo/Momentary/Boundary spell is already forced; the
banner says so and the checkbox stays live and harmless.

### Default state of the checkbox

Ticked whenever it is visible. Per condition 5, a Momentary Creo spell that
creates or heals anything lasting *must* be a Ritual, and a Momentary Creo spell
that is not a Ritual creates something that vanishes at once — almost always a
mistake rather than an intent. Defaulting on is the faithful reading.

The default is applied in event handlers rather than recomputed during build, so
an unrelated rebuild can never re-tick a box the user deliberately cleared:

- `BaseEffectSelected` → set `lastingCreation` if the draft is Creo with
  Momentary duration, else `none`. Changing the base effect resets the
  declaration, which is correct: the declaration is a statement *about that
  effect*.
- `DurationSelected` → entering Momentary applies the same rule; leaving
  Momentary clears it.

`RitualRequirement.suggested` does **not** drive the default. It drives
explanatory text next to the checkbox — "without a Momentary Ritual this
suspends healing rather than curing it."

### Pruning

The bloc clears `ritualDeclaration` when it holds `lastingCreation` and the
draft leaves Creo + Momentary eligibility, on `TechniqueSelected`,
`BaseEffectSelected` and `DurationSelected`. This is the same job
`pruneModifierSelections` does for stranded modifier selections, for the same
reason: a stale selection that keeps affecting the level invisibly is exactly
the bug that pattern exists to prevent.

`storyguideRuling` is **never** pruned. Nothing in this iteration sets it from
the UI, and a ruling is not invalidated by changing Duration.

### Events and validation

One new event: `RitualDeclarationChanged(RitualDeclaration declaration)`.

`validateSpellDraft` gains nothing. There is no illegal combination to reject —
a Year-duration spell is not an error, it is a Ritual. A user-facing error for
the pruned-away state would be an error message for an unreachable condition.

### Library

`SpellCard` shows a Ritual marker. `SpellLibraryBloc` already computes a
breakdown per saved spell, so `RitualStatus` is available there at no cost.

## Data Changes

### `parameters.json` — 2 edits of 25

`"requiresRitual": true` on `duration-year` and `target-boundary`. Nothing else.

### `base_effects.json` — `ritualRequirement`

**`"required"` on 7 entries**, promoting today's free-text `notes` to a
structured flag:

| Id | Technique/Form | Existing note or marker |
|---|---|---|
| `craq-25b` | Creo Aquam | "(Ritual)" in the description |
| `crau-25` | Creo Auram | "Ritual only" |
| `crco-5b` | Creo Corpus | "Ritual only" |
| `crig-25b` | Creo Ignem | "Ritual only" |
| `crte-25b` | Creo Terram | "Variable base level; ritual-only" |
| `pevi-G9` | Perdo Vim | "General entry; must be Ritual" |
| `pevi-G10` | Perdo Vim | "General entry; must be Ritual" |

**`"suggested"` on 38 entries.** Today's flagging is inconsistent: five Creo
Corpus healing entries carry a note, while Creo Animal and Creo Herbam healing —
which the rulebook treats identically — carry none, and Creo Corpus's own
`crco-25c` "Restore a lost limb" and its five aging-crisis entries carry none
either.

The rule applied, stated first as the rationale for the list that follows:

> Include a Creo guideline when what it produces **persists after the magic
> ends** — healing a wound, restoring a lost limb or sense, curing a disease,
> resolving an aging crisis, raising the dead, permanently raising a
> Characteristic.
>
> Exclude it when the effect is sustained *by* the spell.

Every row of the Creo Animal (line 12468), Creo Corpus (line 13413) and Creo
Herbam (line 13919) guideline tables was walked against the catalog. The
resulting membership is exact, and every id below was verified to exist with the
stated Technique and Form. None overlaps the seven `required` entries.

**Creo Animal — 11**

| Id | Level | Guideline |
|---|---|---|
| `cran-15a` | 15 | Heal a Light Wound |
| `cran-20a` | 20 | Heal a Medium Wound |
| `cran-25b` | 25 | Heal a Heavy Wound |
| `cran-25c` | 25 | Restore a lost sense |
| `cran-25d` | 25 | Restore a lost limb |
| `cran-25e` | 25 | Cure a disease, counteracting its effects |
| `cran-30a` | 30 | Heal an Incapacitating Wound |
| `cran-30b` | 30 | Increase a Characteristic, to no more than average |
| `cran-35` | 35 | Heal all wounds |
| `cran-40` | 40 | Increase a Characteristic, to two above average |
| `cran-75` | 75 | Raise an animal from the dead |

**Creo Corpus — 20**

| Id | Level | Guideline |
|---|---|---|
| `crco-15a` | 15 | Heal a Light Wound |
| `crco-15c` | 15 | Resolve a minor aging crisis |
| `crco-20a` | 20 | Heal a Medium Wound |
| `crco-20b` | 20 | Heal the debilitating after-effects of a disease, poison, or injury |
| `crco-20c` | 20 | Resolve a serious aging crisis |
| `crco-25a` | 25 | Heal a Heavy Wound |
| `crco-25b` | 25 | Improve all wounds by one level of severity |
| `crco-25c` | 25 | Restore a lost limb |
| `crco-25d` | 25 | Resolve a major aging crisis |
| `crco-30a` | 30 | Heal an Incapacitating Wound |
| `crco-30b` | 30 | Increase a physical Characteristic, to no more than 0 |
| `crco-30d` | 30 | Resolve a critical aging crisis |
| `crco-35a` | 35 | Heal all wounds |
| `crco-35b` | 35 | Resolve a terminal aging crisis |
| `crco-35c` | 35 | Increase a physical Characteristic, to no more than +1 |
| `crco-40` | 40 | Increase a physical Characteristic, to no more than +2 |
| `crco-45` | 45 | Increase a physical Characteristic, to no more than +3 |
| `crco-50` | 50 | Increase a physical Characteristic, to no more than +4 |
| `crco-55` | 55 | Increase a physical Characteristic, to no more than +5 |
| `crco-70` | 70 | Raise the dead |

**Creo Herbam — 7**

| Id | Level | Guideline |
|---|---|---|
| `crhe-1e` | 1 | Heal a Light Wound to a plant |
| `crhe-2c` | 2 | Heal a Medium Wound to a plant |
| `crhe-3b` | 3 | Heal a Heavy Wound to a plant |
| `crhe-4` | 4 | Heal an Incapacitating Wound to a plant |
| `crhe-5` | 5 | Heal all Wounds to a plant |
| `crhe-10` | 10 | Heal all damage to a plant, including wounds, disease, and poison |
| `crhe-15b` | 15 | Restore a damaged manufactured wooden item |

### Exclusions, and why

Recorded so each is a decision on file rather than an omission.

- **Recovery-roll bonuses** (`cran-1`, `crco-1a`, and their ladders). The bonus
  applies while the spell runs; nothing persists. The Creo Corpus preamble
  (line 13416) treats these as a separate category from healing outright.
- **"Preserve a corpse from decay"** (`cran-2b`, `crco-2b`, `crhe-2b`) and
  **"Prevent a plant from becoming sick"** (`crhe-1d`). Ongoing preservation,
  sustained by the spell.
- **`crco-1b`** (wounds treated as less serious for activity) and **`crco-3b`**
  (prevent wounds worsening). Suppression, not repair.
- **`cran-25a` "Stop the progress of a disease."** Line 12478 contrasts this
  directly with "Cure a disease, counteracting its effects (unless Momentary
  Ritual, same as stopping progress)" — the *cure* is the ritual case, the
  *stopping* is not.
- **All maturation entries** (`cran-15d`, `cran-20c`, `cran-25f`, `cran-30c`,
  `crco-30c`, `crhe-15a`, `crhe-20`, `crhe-25`, `crhe-30`, `crhe-40`) and
  **`crhe-1a`** ("grows well for the duration of the spell"). Their own text
  demands a Duration; accelerated growth applies only while the spell runs.
- **All Creo creation guidelines** (`cran-5a/5b/10a/10b/15c/50`, `crhe-1b/1c/2a/3a`,
  and their equivalents in every other Form). Line 12176 makes these condition-5
  cases too, but the creation sweep is deliberately out of scope — see "Out of
  Scope". The default-on behaviour covers them for correctness regardless.
- **Creo Mentem memory restoration** (`creem-4b`, `creem-5b`, `creem-10a`,
  "Restore a memory… to a fresh state"). The criterion arguably reaches them, but
  the approved sweep is Creo *bodily* healing across Animal, Corpus and Herbam;
  memory restoration is not covered by the healing-suspension rule at line 13415,
  and all three are already flagged "Variable base level" — todo item 4's
  territory. Left out, recorded below as an open question.

`crco-70` "Raise the dead" and `cran-75` "Raise an animal from the dead" carry
the flag redundantly — a base level of 70 or 75 already trips condition 1 — for
uniformity, at no cost.

### `spell_library.json` — 5 new built-in spells

All five are published core-rulebook spells, cited to `arm5-core`. Every base
effect and modifier option named below was verified to exist in the current
catalog.

| Spell | Arts | Level | Base effect | Design line | Ritual because |
|---|---|---|---|---|---|
| Incantation of the Body Made Whole (13496) | CrCo | 40 | `crco-35a` | Base 35, +1 Touch | `lastingCreation` |
| Touch of Midas (15312) | CrTe | 20 | `crte-15a` | Base 15, +1 Touch | `lastingCreation` |
| Curse of the Ravenous Swarm (12516) | CrAn | 50 | `cran-5b` | Base 5, +1 Touch, +3 Moon, +2 Group, +2 size, +1 requisite | `storyguideRuling` |
| Breath of the Open Sky (13214) | CrAu | 40 | `crau-5` | Base 5, +1 Touch, +1 Conc, +4 size, +1 unnatural | `storyguideRuling` |
| Incantation of Summoning the Dead (15260) | ReMe | 40 | `reem-15b` | Base 15, +4 Arc, +1 Conc | `storyguideRuling` |

The first two are the healing and permanent-creation cases; neither fires any
forced condition, so their ritual status comes purely from the declaration.
Touch of Midas lands on exactly 20, pinning the floor's boundary: it proves the
floor is a no-op at 20 rather than silently adding.

The last three give the storyguide-ruling path real data coverage while its UI
is deferred, and the Rego Mentem one proves a Ritual need not be Creo. Their
modifier selections use `size-animal-2`, `size-auram-4` +
`creo-auram-unnatural-slight`, and none respectively — all already present.
Curse of the Ravenous Swarm also carries a `Rego` requisite of kind `adding`
(+1), matching its printed `Req: Rego` and "+1 extra effect from requisite".

**No published core Ritual computes below 20**, because the level-20 floor is
baked into how they were designed; the lowest (Chirurgeon's Healing Touch,
Soothe Pains of the Beast, Touch of Midas) all land on exactly 20. The floor
actually biting is therefore covered by a unit test with a synthetic spell, not
by a library fixture.

### No migration of existing library spells

None of the 31 current built-ins is a Ritual: none has Year duration or Boundary
target, none exceeds level 50, and none is Creo with Momentary duration.

## Persistence

`AppDatabase._databaseVersion` 4 → 5. The `spells` table DDL is unchanged —
`ritualDeclaration` lives inside the existing JSON `data` blob — so this is the
identical shape of change the v4 bump made, and the existing `onUpgrade` (drop
`spells`, rebuild, leave the custom catalog intact) already does the right thing
without modification.

`BackupService` round-trips through `toMap`/`fromMap` and follows automatically.
Todo item 7 wants a backup round-trip test; adding one for this field is a
natural down payment on it.

## Testing

**Engine.** Each of the six reasons in isolation. The over-determined Aegis case,
asserting *two* reasons rather than one. The floor biting (`crhe-1e` plant
healing at Touch, raw level 2 → 20). The floor not biting (Incantation stays 40).
The floor as a no-op at exactly 20 (Touch of Midas). The threshold pair: level 50
is not a Ritual, level 51 is. And an explicit invariant test that the floor can
never yield a level above 50, so the single-pass ordering stays provably correct.

**Models.** Enum name round-trip for both new enums; `FormatException` on an
unknown name; absent JSON keys defaulting to `none` and `false`.

**Assets.** Assert exactly two parameters carry `requiresRitual` — hardcoded,
because `parameters.json` is the hand-curated list todo item 5 deliberately left
as literals.

For `base_effects.json`, assert the flagged ids **as exact sets** against the
seven `required` and thirty-eight `suggested` ids listed above, not as counts.
Todo item 5's reasoning for deriving counts applies to properties of the file as
a whole, which drift as the extraction grows; this is a hand-reviewed membership
decision, and the set is the thing worth pinning. A count would pass while an
entry silently moved from one flag to the other. Also assert every
`ritualRequirement` value parses.

Assert all five new library spells resolve and calculate to their printed levels.

**Widgets.** Mocked blocs covering the visibility rule (shown for Creo +
Momentary, hidden otherwise), the default-ticked state, and the banner's reason
text.

**Integration.** One `integration_test/` case building a declared Ritual end to
end. Per todo item 6 and the known real-Bloc hang under `flutter_tester`, this
needs `-d windows`, and "tests pass" for this branch means **both** suites, not
`flutter test` alone.

## Todo Items to Add

1. **Storyguide-ruling UI.** The model supports `RitualDeclaration.storyguideRuling`
   and three library spells use it; no control sets it. Adding one must also
   revisit the prune rule so the two declaration kinds stay distinguishable.
2. **Size-ladder ceiling.** Every ladder stops at +4 (×10,000). This blocks the
   published ritual *Rain of Oil* (MuAu 50 with an Aquam requisite, line 13310:
   `Base 4, +3 Sight, +2 Sun, +5 size`). Belongs with todo item 4.
3. **Creo creation `suggested` sweep.** Skipped deliberately, per "Out of Scope".
   Recorded so the asymmetry with the healing sweep is a decision on file.
4. **Creo Mentem memory restoration.** Decide whether `creem-4b`, `creem-5b` and
   `creem-10a` are condition-5 cases. Entangled with their existing "Variable
   base level" flag, so it belongs with todo item 4.
5. **Four Creo Animal guidelines missing from the catalog**, found while walking
   the table for this pass and unrelated to Rituals: level 35 "Increase a
   Characteristic to one above average", level 40 "Cause an animal to reach full
   maturity in a moment", level 45 "Increase a Characteristic to three above
   average", and level 55 "Increase a Characteristic to five above average". The
   catalog has `cran-35` (Heal all wounds), `cran-40` (Characteristic) and
   `cran-50` (magical beast) but no siblings for these four rows.
