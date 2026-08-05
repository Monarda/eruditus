# General Base Effects: the caster picks the guideline level

**Todo item:** 25 (absorbs the level-arithmetic half of items 4b and 4c for
General entries; unblocks item 4's conditional wards)

**Status:** designed 2026-08-05

**Rulebook:** `Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition
(Core Rules).md`. Line references in this document are to that file.

---

## Problem

47 base-effect catalog entries are General guidelines: the rulebook prints
`General` where every other row prints a level, because the caster chooses it.
They are stored with `baseLevel: 0` today, so a General spell computes as
`0 + magnitudes` — which is simply wrong. 33 published spells are affected,
including every Vim spell and every ward, so this is the gate on the whole of
Vim (54 catalog effects) and on item 4's conditional wards.

The rulebook states the rule at line 12410:

> Some spells are General spells (abbreviated to Gen), which means that they
> may be learned at any level of difficulty — the higher the level, the more
> powerful the spell.

and at line 12414:

> General level spells are open-ended only in the sense that they may be
> learned at any level. They may not be used at a level higher (or lower) than
> that which is known, and **different levels of a General level spell are
> still different spells.**

That last sentence is the one that shapes the design: a published General spell
is not a spell. It is a template from which spells are made.

### The audit that drove the design

All 33 General spells were extracted with both their stat line and their design
line and compared. They are not one shape:

| Shape | Count | Design line | Reading |
|---|---|---|---|
| **A — offset** | 18 | `(Base effect, +2 Voice)` | tokens match the stat line; level = chosen base + magnitudes |
| **B — self-contained** | 10 | `(Base effect)` / `(Base spell)` | stat line carries real R/D/T, design line prices none of it |
| **C — no design line** | 5 | — | *Aegis*, *Wizard's Vigil*, *Sight of the True Form*, and two wards |

Shape B is not sloppiness in the book. The guideline rows say so outright:
every ward row ends `…(Touch, Ring, Circle)` and the Intellego Imaginem row
ends `…(Vision target)`. *Ward against the Beasts of Legend* prints its design
line as the literal words `(As ward guideline)`.

### The unifying rule

A General guideline is priced **against a reference set of Range, Duration and
Target**. Varying them costs or refunds the difference:

> **level = chosen base + (actual R/D/T cost − reference R/D/T cost)**

Shape A entries have a reference of Personal/Momentary/Individual — all zero —
which is why their whole stat line is charged. Shape B entries have a reference
their guideline row names. There is one mechanism, not two.

This is what makes a *varied* General spell expressible. A version of *Ward
against the Beasts of Legend* at Personal/Sun/Individual is one magnitude
cheaper than the printed Touch/Ring/Circle version, so it is five levels lower
while warding against exactly the same Might — the guideline's effect is
anchored to the chosen base, not to the computed level.

### The derived quantity is part of the deliverable

Every General guideline states its effect as a function of the chosen base.
Scanning all 47 rows, they fit one shape — `multiplier × (base + N magnitudes)`:

| Guideline | Printed text | Reads as |
|---|---|---|
| every ward | "Might ≤ the level of the spell" | `base` |
| `pevi-G3` | "Might Score by the level of the spell + 2 magnitudes" | `base + 10` |
| `pevi-G1` | "twice the (level + 2 magnitudes)" | `2 × (base + 10)` |
| `pevi-G5` | "half the (level + 4 magnitudes …)" | `½ × (base + 20)` |
| `revi-G3` | "level + 5 magnitudes" | `base + 25` |
| `craq-gen` | "+(Level) damage" | `base` damage |
| `invi-G` | "negative magnitude up to the guideline − 2" | `base` in **magnitudes**, −2 |

The reference triple and the effect formula are **independent**. It is
tempting to read *Demon's Eternal Oblivion*'s guideline ("Reduce a target's
Might Score by the level of the spell + 2 magnitudes") as evidence that
`pevi-G3`'s reference is Voice, since the two coincide there. It is not:
DEO's own design line charges `+2 Voice` in full, so `pevi-G3`'s reference is
Personal/Mom/Individual like any ordinary guideline. The reduction is
`base + 10` always, and it merely *equals* the spell's level for DEO because
DEO happens to be cast at Voice. Cast the same guideline at Personal and the
reduction is level + 10.

---

## What already exists, and must not be duplicated

- **`SpellLevelCalculator` already handles refunds.** Item 24 added negative
  magnitudes and the additive-tier mirror rule. A base-10 ward refunded three
  magnitudes traces `10 → 5 → 4 → 3`, not `10 − 15 = −5`, because each refund
  below level 5 costs 1 rather than 5. It lands at 3 and cannot cross 1.
- **Per-parameter deltas are arithmetically identical to one lump.** `[−1, −2]`
  and `[−3]` both give 3 from base 10, verified. The breakdown may therefore
  show one line per parameter.
- **Dangling ids already degrade gracefully.** `calculateBreakdown` treats an
  unresolvable modifier id as contributing 0 rather than throwing, with a
  comment explaining why `SpellLibraryBloc` depends on it. `templateId`
  follows that precedent.
- **`resolutions.json` and its ledger** already record base-effect decisions
  against the candidate set they were made against. General spells use it
  unchanged.
- **`Parameter.requiresRitual`** already exists, so ritual-only durations and
  targets need nothing here.

## Backwards compatibility is not a goal

Eruditus is a prototype with no users. The database is dropped, the schema is
rebuilt, `base_effects.json` is rewritten and `spell_library.json` is
regenerated. No migration path is designed and none should be added.

---

## Design

### 1. `BaseEffect.baseLevel` becomes nullable, and null *is* General

No separate `isGeneral` flag. A General guideline genuinely has no base level,
so a nullable field states that directly and makes "flag disagrees with value"
unrepresentable. All 47 entries go `0` → `null`.

Two new optional fields:

- `reference: ParameterTriple?` — the guideline's assumed Range, Duration and
  Target ids. Absent means Personal/Momentary/Individual. Sourced from the
  guideline row's own parenthetical, never inferred from the spells that cite
  it (see §5 for why that distinction carries the whole verification story).
- `effectFormula: GeneralEffectFormula?` — required on every General entry,
  absent on every other:

  | Field | Values |
  |---|---|
  | `kind` | `mightThreshold`, `mightReduction`, `damage`, `targetSpellLevel`, `visDestroyed`, `spellTraceMagnitude` |
  | `multiplier` | `½`, `1`, `2` |
  | `offsetMagnitudes` | any integer, positive or negative |
  | `unit` | `levels` or `magnitudes` |
  | `stressDie` | bool — appends "+ a stress die (no botch)" |

  The value is `multiplier × (chosenBase + offsetMagnitudes × 5)`, computed in
  levels. `unit: magnitudes` converts the result for display only, by line
  12030's rule (level ÷ 5, rounded up); the arithmetic itself is always in
  levels. `invi-G` is the case that needs it: "negative magnitude up to the
  magnitude of the guideline − 2".

`GeneralEffectFormula` is the only genuinely new value type. It exists so that
the description generator and, later, item 4's ward UI read the same number
instead of each parsing prose.

### 2. `SpellLevelCalculator` gets stricter, not looser

`baseLevel` may now be required ≥ 1. The only reason level 0 was ever
legitimate was the 47 sentinel rows, and they no longer carry a level at all.
The guard collapses from `level < 1 && level < baseLevel` to `level < 1`, and
the long comment justifying the base-0 allowance goes with it.

### 3. `Spell` gains a chosen level and a soft template link

- `chosenBaseLevel: int?` — required and ≥ 1 when the base effect is General,
  absent otherwise.
- `templateId: String?` — provenance only. **Nothing dereferences it during
  validation or calculation.** A spell shared between users without its
  template validates and computes exactly as if the field were absent. It is
  cleared when the user changes the base effect, on the same reasoning as
  `pruneModifierSelections`: the link would otherwise assert a lineage that no
  longer holds.

### 4. `SpellTemplate`, a new read-only entity

Everything a `Spell` has except `chosenBaseLevel`, plus the guideline it
resolves to. Lives in `assets/data/spell_templates.json`, loaded by
`AssetDataLoader` alongside the library. Users instantiate templates in this
spec; they do not author them.

This is what keeps `LevelBreakdown.level` a plain `int`. No spell card, library
sort, `findSimilarSpells` call or import assertion needs a "General" branch,
because no `Spell` is ever level-less.

### 5. Engine: one code path, not a branch

`calculateBreakdown` changes in one place. The base contribution takes
`chosenBaseLevel` instead of `baseLevel`, and each of Range, Duration and
Target emits **the delta against the reference** rather than the raw cost:

```
Base effect · Ward against beings associated with Animal … (chosen)   20
Range · Personal (guideline assumes Touch)                            −1
Duration · Sun (guideline assumes Ring)                                0
Target · Individual (guideline assumes Circle)                         0
                                                          Level        15
```

For a non-General effect the reference is Personal/Mom/Individual, every delta
equals the raw cost, and the emitted contributions are byte-identical to
today's. The 273 existing spells are untouched by construction rather than by
testing — though §8 tests it anyway, because that identity is the argument for
there being one path.

The deltas flow into `SpellLevelCalculator.calculate` as separate per-parameter
magnitudes, which §"What already exists" establishes is equivalent to one
combined magnitude.

A second engine output, `deriveGeneralEffect`, turns `chosenBaseLevel` plus
`effectFormula` into a value and a rendered sentence — `Might ≤ 20`,
`+30 damage`, `spells of level ≤ 45, + a stress die (no botch)`. **It reads
only the chosen base, never the computed level.** That is precisely what keeps
a Personal-range ward's threshold at its larger value. It returns null for
non-General effects.

`_deriveRitualStatus` needs no change: it reads `rawLevel`, which is a real
integer for every spell.

### 6. Validation

`validateSpellDraft` gains two rules:

- A General base effect with no chosen level → *"Choose a level for this
  General guideline"*. This is the error item 25 asks for, in place of a
  silent zero.
- A chosen level below 1 → an error.

It keeps catching the calculator's throw, whose message widens from item 24's
*"Negative magnitudes reduce this spell below level 1"* to cover parameter
refunds as well as adjustments.

A General guideline missing its `effectFormula` has **no** runtime handling by
design. It is a data error, caught by assertion 7 at build time.

### 7. UI

**Library.** Templates render in the same list as spells, with a `Gen` chip
where the level number sits, and the guideline's effect written in terms of the
base — *"keeps out beasts whose Might is at most the spell's level"*. They are
not editable and cannot be deleted. Search and source filters treat them as
ordinary rows; sorting by level groups them separately rather than assigning
them a number.

**Instantiation routes into the creation screen, prefilled.** A
`Learn at level…` action on a template opens the Create tab with technique,
form, base effect, Range, Duration, Target, requisites and modifiers set from
the template, `templateId` recorded, and focus in the chosen-level field.

It is deliberately **not** a dialog that only asks for a number. The varied
ward — same guideline, Personal/Sun/Individual — is the motivating case, and it
only works if the parameters stay editable after instantiation. A dialog would
force the user to instantiate and then immediately edit.

**Creation screen.** The base-effect dropdown already lists the 47 General
entries. Selecting one reveals a single numeric field, *Guideline level*, shown
only for General effects, with the derived effect sentence below it updating
live as the number changes. The level breakdown shows the reference deltas from
§5.

### 8. Import harness

The General branch replaces
`blocked.append((block.name, "General level — todo item 25"))`.

**Emitting templates.** A General spell resolves its guideline through
`resolutions.json` exactly as any other spell does, then emits a
`SpellTemplate` rather than a `Spell`. Candidates are no longer filtered by
level — every General row for that Technique/Form is a candidate — so
`ledger.candidates` needs a General path filtering on `baseLevel is None`
instead of on equality. This is why *Demon's Eternal Oblivion* faces 13
candidates and every ReVi spell faces 5.

**Assertion 6 — the reference oracle.**

> For every template, `(stat-line R/D/T cost) − (guideline reference cost)`
> must equal the design line's parsed magnitude tokens.

This assertion carries unusual weight. Assertion 1 ("every spell computes to
its printed level") can check **nothing** about a General spell: there is no
printed level, and every candidate has the same absent base level, so a wrong
ledger pick computes identically to a right one. This is item 32's hazard at
full strength, on 21 spells at once. Assertion 6 is the only automated check
these spells will ever have. It catches a wrong ledger pick whenever the
candidates' references differ, and a mis-authored reference triple always.

Its non-circularity is the reason §1 insists the reference is sourced from the
guideline row's parenthetical rather than inferred from the spells. Infer it
from the design line and the assertion becomes vacuous.

Verified against the corpus before writing this spec: wards predict 0 tokens
and print `(Base spell)`; *DEO* predicts `+2 Voice`; *Discern the Images of
Truth and Falsehood* predicts `+1 Conc`. All match.

**Assertion 7 — formula coverage.** Every General catalog entry has an
`effectFormula`, and every emitted effect sentence is generated from it rather
than hand-copied.

**Eleven spells stay blocked, each with a recorded reason.**

- **Five have no design line:** *Aegis of the Hearth*, *Wizard's Vigil*,
  *Sight of the True Form*, *Ward against the Beasts of Legend*, *Ward against
  Faeries of the Mountain*. The two wards may resolve once the design-line
  parser accepts `(As ward guideline)` as a zero-token line — a small splitter
  change worth attempting within this work.
- **Five fail assertion 6:** *Wizard's Communion*, *Restore the Moved Image*,
  *Lay to Rest the Haunting Spirit* and *The Invisible Eye Revealed* print
  `(Base effect)` where their stat lines imply real cost and no guideline
  parenthetical explains it; *Dispel the Phantom Image* has no Perdo Imaginem
  General row in the catalog at all.
- **One blocks on item 26, not on this work:** *Watching Ward* is shape A and
  its design line parses, but its stat line reads `D: Spec`, which is not a
  Duration in `parameters.json`, so `emit._parameter_name` raises. That is item
  26's still-open decision on what a `Special` Duration resolves to. Item 26's
  note that *Watching Ward* "needs item 25 regardless" is correct but was only
  half the story: it needs both.

*Aegis of the Hearth* deserves its own note: it cannot be derived by any
modelling. Touch/Year/Boundary is nine magnitudes, so a level-30 Aegis needs
base −15. The rulebook says why in the spell's own text — it was a Major
Breakthrough, "the spell is more powerful than it ought to be, and has no Perdo
requisite". It stays blocked permanently, like *Whispering Winds*.

**Expected outcome: 273 → ~295 imported, 87 → ~65 blocked** — 22 of the 33
newly importable, or 24 if the `(As ward guideline)` splitter change lands.

**Two spells touch item 18 as well.** *Disenchant* and *Watching Ward* print
`Ritual` on a General stat line and are already on item 18's list of seven
storyguide rulings. *Disenchant* imports as a template regardless — the ritual
flag is a separate concern on the same spell. *Watching Ward* is blocked above
for a third, unrelated reason.

---

## Testing

**Python — `scripts/spell_import/tests/`**

- Assertions 6 and 7 as specified above.
- A reference-triple table test in the shape of the existing
  `test_emit.ModifierOptionTableTest`, checking every authored reference
  against its guideline row's parenthetical.
- A staleness test in the shape of `KnownUnresolvableStalenessTest`, so the ten
  recorded blockers fail loudly if one starts importing.

**Dart — `test/`**

- `SpellLevelCalculator` refund cases, including the base-10-at-−3-magnitudes
  trace (`10 → 5 → 4 → 3`) and the below-1 throw.
- `calculateBreakdown` emitting identical contributions for a non-General
  effect — this is what proves the reference delta is one code path.
- `deriveGeneralEffect` across every formula kind, both units, and all three
  multipliers, including that its value is **invariant** when Range, Duration
  or Target change.
- Template round-tripping through serialization and backup.
- A spell whose `templateId` names nothing still validates and computes.

**Integration — `integration_test/`**

Item 6's standing rule applies. The chosen-level field's *re-render* behaviour —
appearing when a General effect is selected, disappearing when the base effect
changes back — is exactly the mocked-bloc blind spot that hid the add-requisite
crash. It belongs here, not in a mocked widget test.

---

## Non-goals

- **Item 4's ward configuration UI.** It consumes `deriveGeneralEffect`, but
  the ward-type field and its display are work on top of this.
- **Item 18's storyguide rulings**, including for *Disenchant* and *Watching
  Ward*.
- **Item 22's four missing General catalog rows** (Rego Animal, Rego Mentem,
  Muto Aquam, Muto Terram).
- **The ten blocked spells.** Each has a recorded reason; none is papered over.
- **Item 4b/4c for non-General entries.** `GeneralEffectFormula` retires the
  level-dependent-output problem for the 47 General rows only. Fire-damage
  magnitudes on ordinary Ignem guidelines remain deferred.
- **User-authored templates.** Templates are read-only catalog data here.
- **Any migration path.** See "Backwards compatibility is not a goal".

---

## A caution for implementation

The reference triple is the load-bearing piece of data in this design and the
easiest to get quietly wrong. Author it from the guideline row's printed
parenthetical and nothing else. If a spell's design line disagrees with what
the reference predicts, **that spell is blocked** — it is not evidence that the
reference should be adjusted to fit. Five spells already fail that way, and
bending their references to make them import would destroy the only oracle
General spells have, on all 23 of the ones that pass.
