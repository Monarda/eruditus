# Cross-Field Parameter Constraints — One Choice Forcing or Forbidding Another

Designed 2026-08-18. Opens the capability item 67 filed as *"no capability
exists: no parameter constrains another parameter's value today"*, and settles
item 68's open question — not by taste, but because a core rule decides it.

## A note on line citations before anything else

**Every core-rules line citation written into this codebase before today is
exactly 8 lines low**, verified at eleven separate sites (todo item 70). The
`reviewed/` core file gained 8 lines somewhere before line 10566.

**This spec cites the current file throughout.** So where
`target_type.dart:3` says the "three types of target" sentence is at 12120,
this spec says 12128. Both point at the same sentence; the older number is
stale. Do not reconcile them by changing this spec's numbers — item 70 fixes
the code's.

## Why now: what the corpus survey established

A survey of all 52 non-duplicate books in the rulebook checkout (9 parallel
agents, 90 raw candidate findings) was run specifically to decide whether this
constraint family deserved a general mechanism. It argued *against* a general
engine and *for* doing one targeted thing properly:

- **The dominant shape is already solved.** Roughly 35-40 of the 90 findings
  are rules forcing Ritual status. `requiresRitual`, `ritualRequirement` and
  `RitualStatus`'s accumulate-reasons design handle every one. The new books
  (Faerie Season/Aura/Hidden durations, Merinita Perpetuity, Provençal's Via
  Mercuria, Ancient Magic's Event/Unlimited) need **catalog rows, not
  machinery**.
- **The cross-field value class is real but small — four rules, not forty.**
  Listed in full below.
- **Most apparent novelty is outside the app's world**: creature-type
  prohibitions (angels cannot be compelled), external character state
  (Merinita's Might Duration reads the caster's Might score), enchanted items,
  and non-Hermetic traditions with their own vocabularies. No mechanism inside
  the spell model would capture any of them.

The four in-scope rules:

| # | Rule | Source | Operator |
|---|---|---|---|
| 1 | Personal Range ⇒ Target must not be a container | **Core 12086** | forbidding |
| 2 | A Sensory Target ⇒ Range must be Personal | HoH:MC 1006 | forcing |
| 3 | A Sensory Target ⇒ Intellego must not appear as a requisite | HoH:MC 1009 | forbidding |
| 4 | A Sensory Target ⇒ the mode is dynamic by rule | HoH:MC 1002 | forcing |

**Rule 1 is why this is worth building.** Item 67 judged the capability
disproportionate for five Virtue-gated rows, and that judgement was correct on
the evidence it had. The survey found the same shape in the **core rulebook**,
applying to every spell, gated behind no Virtue, and enforced nowhere:

> **Personal:** The spell only affects the caster… **Personal Range spells can
> never have a container Target (such as Circle, Room, or Structure).**
> — Core Rules 12086

`grep range-personal lib/` finds only the default reference triple. Nothing
checks it. The 325-spell library has 0 violations, 28 templates have 0, and no
guideline's reference triple violates it — so the gap is latent, not live. The
creation screen permits it freely.

## Decision 1 — The Sensory Targets are not containers, and core 12086 proves it

Item 64 gave `target-sound` and `target-spectacle` `targetType: container`,
following the book's printed magnitude equivalences (Sound≡Structure,
Spectacle≡Boundary). Item 68 opened the question of whether that
misrepresents them and deliberately declined to answer.

**Core 12086 answers it, by contradiction.** HoH:MC 1006 requires the Range of
every Sensory Magic spell to be Personal. Core 12086 forbids a Personal-Range
spell from having a container Target. If Sound is a container, every Sound
spell must be Personal and cannot be Personal.

This is not hypothetical. The four printed HoH:MC spells confirm the Personal
Range arithmetically — *The Rooster's Crow* is `(Base 3, +1 Diam, +3 Sound)`
for MuMe 15, with no Range term, i.e. Personal at +0.

So the `container` classification is wrong. The book's equivalence sentences
**price** the Target; they do not **classify** it — precisely what item 68
suspected when it observed that "the resulting 3/2 split appears nowhere in
the source."

### Why not `object` or `sense` either

- **`object` is contradicted.** Core 12128: an object Target "affects the
  things in that Target for the duration of the spell, even if they change so
  that they would no longer qualify" — static semantics.
  `target_type.dart` states it plainly: an object Target "is always static
  (12246)". HoH:MC 1002 says the opposite: "Targets need not be present at the
  casting of the spell, and are continuously acquired throughout the spell's
  duration."
- **`sense` is explicitly ruled out by HoH:MC itself.** 1009: "Spells which
  grant magical senses (see ArM5, pages 113-114) fill that role." A `sense`
  Target grants the *caster* a magical sense; a Sensory Target makes *others*
  sensing the caster into targets. Opposite directions.

All three core kinds are contradicted by the source. That is the warrant for a
fourth.

### `TargetType.sensorium`

The obvious objection is that core 12128 says "There are three types of
target" — the sentence `TargetType`'s own doc comment rests on. **HoH:MC
supplies the exemption in its own words** (line 1000): these Targets

> …were **imperfectly melded to Hermetic Theory**, remaining a Mystery of
> House Bjornaer.

The book states that they do not fit standard Hermetic theory. Modelling them
as one of standard theory's three kinds is what would contradict the source.

**The name is a deliberate coinage.** "Sensorium" appears **zero times** in all
54 books. The existing three values are verbatim rulebook words, and this one
visibly is not — which is the point: a fourth kind that the core rules do not
enumerate should not wear a name that looks quoted. It is also the right part
of speech (a bare noun, like its three siblings) and semantically precise:
HoH:MC 1008 delimits the Target by the *target beings'* sensory apparatus
("The spell can only affect a being who is capable of sensing the caster in the
way specified. For example, deaf people are immune to Target Sound spells").

**The one real cost is proximity to `sense`**, and the doc comment must pay it
explicitly rather than describing `sensorium` in isolation. The distinction is
load-bearing — it is the stated reason Intellego is forbidden — so
`target_type.dart`'s comment must (a) drop the "rulebook's three kinds" claim,
(b) cite HoH:MC 1000 for why a fourth exists, and (c) contrast the two in one
sentence: **a `sense` Target grants the caster a magical sense; a `sensorium`
Target affects those who sense the caster.**

### This decision is nearly free, and that is the strongest argument for it

`TargetType.container` has exactly four production consumers, and every one
becomes correct for the Sensory rows the moment the kind changes:

| Consumer | Effect of the change |
|---|---|
| `spell_creation_screen.dart:321` | The static/dynamic control stops being offered — the choice the book withholds |
| `spell_creation_bloc.dart:708` `_isContainer` | A stated mode is cleared on landing, no special case |
| `spell.dart:226` check 9 | A mode stated on one becomes a validation error, free |
| `spell.dart:259` `spellOwesContainerMode` | Stops demanding a ruling, free |

Magnitudes are untouched (0/1/2/3/4 stand), so **no spell's level changes**.
Item 68 closes, and rule 4 — the containerMode forcing rule — closes with it
**without any forcing mechanism being built at all**. The mode is not forced to
`dynamic`; the question stops being asked, which is what the book actually
does.

## Decision 2 — Two `Parameter` fields, one per operator

The remaining rules split by operator, and the split is not cosmetic: **you
cannot auto-set a "must not"**. A forbidding rule has no single value to
impose, so its only possible consequence is removing options.

### `forbidsTargetTypes: List<TargetType>` — rule 1

Carried by `range-personal` alone: `[TargetType.container]`.

By *kind*, not by target id, because that is how core 12086 states it ("a
container Target (such as Circle, Room, or Structure)" — "such as" is
illustrative, and Boundary is a container per core 12146). Keying on the kind
means Boundary and any future container row are covered without a data edit.

### `requiresRangeId: String?` — rule 2

Carried by the five Sensory Target rows: `"range-personal"`.

Named to match the existing `requires*` family (`requiresRitual`,
`requiresVirtue`), with the `Id` suffix marking it a catalog reference, as
`rangeId`/`durationId`/`targetId` do everywhere else.

**These two now cooperate rather than contradict**, but only because Decision 1
removed the container classification first. Under item 64's data they are in
direct conflict — which is the contradiction that motivated Decision 1.

## Decision 3 — The Intellego requisite needs no new field

HoH:MC 1009 forbids Intellego "even as a requisite". The five rows already
carry `scope.excludeTechniques: ["Intellego"]`, which today reaches only the
spell's own Technique. A new validation check reads **that same list** against
`requisites.keys`.

One check, zero new catalog data. The widening — "a Technique this parameter
excludes may not appear as a requisite either" — is the correct reading for the
only rule that uses it, and `ParameterScope`'s doc comment must record that
this is now the field's meaning. If a future parameter ever needs to exclude a
Technique while permitting it as a requisite, that is when the field splits;
per the repo's standing rule, extend on evidence, not preemptively.

## UX — forcing locks, forbidding filters

**Forcing (rule 2).** Selecting a Sensory Target sets the Range to Personal and
disables the Range dropdown, with a helper line naming the reason and its
citation. This is the auto-set-and-lock behaviour chosen for this design.

**Forbidding (rule 1).** No value to impose, so both dropdowns filter against
the current peer selection: with Personal chosen, container Targets are absent
from the Target list; with a container Target chosen, Personal is absent from
the Range list.

**Pruning obeys one rule: the field you just edited wins, and conflicting peers
yield.** This is not new — it is exactly what `TargetSelected` already does to
`containerMode` (`spell_creation_bloc.dart:364-368`), for the reason stated
there: a stale peer left behind is what check 9 rejects "with no visible
cause".

Range, Duration and Target are **peers** — unlike `ParameterScope`'s existing
axes, where Technique and Form are upstream of the parameter being scoped. That
is what is structurally new here, and why pruning has to run in both
directions:

- **`RangeSelected(r)`** — if the current Target's kind is in
  `r.forbidsTargetTypes`, clear the Target, and clear `containerMode` with it
  (item 58's lesson: a mode outliving its Target reattaches to the next one).
- **`TargetSelected(t)`** — if `t.requiresRangeId` is set, set the Range to it;
  otherwise, if the current Range forbids `t.targetType`, clear the Range.
  Existing modifier and `containerMode` pruning is unchanged.

The bloc enforces this regardless of what the UI offers. The dropdown filtering
is a convenience; the invariant does not depend on it.

**Leaving a Sensory Target does not restore the previous Range.** The lock
lifts and the Range stays Personal, which is legal under every rule and for
every Target kind. Restoring a remembered prior value would mean storing edit
history the draft does not keep, and Personal is the standard reference Range
anyway (`ParameterTriple.standard()`).

## Validation — the record path

Three checks join `validateSpellAgainstCatalog`. Numbering continues from 9
(4 was deleted, not reused):

- **Check 10** — Range and Target are incompatible: the Target's kind appears
  in the Range's `forbidsTargetTypes`. Message names both parameters.
- **Check 11** — the Target sets `requiresRangeId` and the spell's Range is not
  it.
- **Check 12** — a requisite names a Technique in the Target's
  `scope.excludeTechniques`.

All three follow the existing tolerance conventions: a null Range or Target
skips silently (an unresolvable id is `ResolvedSpell.isResolved`'s problem, per
check 5 and check 9's precedent), and problems accumulate rather than
short-circuit.

**None is wrapped in `if (!isTemplate)`.** They join checks 3, 5, 7, 8 and 9
rather than the completeness checks 1, 2 and 6: a template's Range and Target
are as fully its own as a spell's, and an incompatible pair recorded on one is
just as much a data bug. Nothing about instantiation supplies a Range.

These are what guard the importer and already-saved records, where no dropdown
filtering exists.

## Ordering — this blocks item 65

**Decision 1 must land before item 65 imports HoH:MC's spells.** Sub-project B
imports the four Sound and Spectacle spells; under item 64's current data they
would import straight into the contradiction, and check 10 would then reject
four correctly-transcribed published spells. Item 65's design (`38a6991`) does
not anticipate this.

## Tests

Updated:

- `test/data/datasources/asset_data_loader_test.dart:69-70` — `target-sound`
  and `target-spectacle` become `TargetType.sensorium`. **This is the drift
  detector doing its job**; item 64 added it precisely so a kind change could
  not pass silently.

New:

1. **The five Sensory rows load as `sensorium`** with magnitudes 0/1/2/3/4
   unchanged — the kind moved, the pricing did not.
2. **`targetTypeFromName` round-trips `'sensorium'`** and still throws on an
   unknown name.
3. **Check 10 rejects Personal + each container kind**, and accepts Personal +
   an object/sense/sensorium Target.
4. **Selecting Personal clears a container Target and its mode** — the mode
   clear is the assertion that would fail against a plausible implementation
   that only cleared the Target.
5. **Selecting a container Target clears a Personal Range** — the other
   direction, which a one-way implementation would miss.
6. **Selecting a Sensory Target auto-sets the Range to Personal.**
7. **Check 11 rejects a Sensory Target with a non-Personal Range.**
8. **Check 12 rejects an Intellego requisite on a Sensory Target**, and
   accepts a non-Intellego one.
9. **`spellOwesContainerMode` returns false for a Sensory Target**, and check 9
   rejects a mode stated on one — the two free consequences of Decision 1,
   pinned so a later kind change cannot quietly undo them.
10. **Corpus guard:** no spell in `spell_library.json` and no template in
    `spell_templates.json` violates checks 10, 11 or 12. All three are 0 today
    (verified), so this starts green and stays a drift detector.

## Out of scope, with reasons

- **The Form-suits-the-medium rule** (HoH:MC 1010). Storyguide judgment by the
  book's own wording — display work, item 56. Item 67's bullet stands.
- **Core 12152** — granting magical senses to many people "requires Muto Mentem
  magic, with Intellego Form requisites". The trigger ("grants senses to many")
  is not mechanically detectable from the recorded fields; there is no flag
  saying a spell does that.
- **Core 15820** — a Muto Vim spell whose result would require a Ritual forces
  the original *or* the MuVi spell to be a Ritual. Constrains a **pair** of
  spells; the app models one at a time. Recorded, not built.
- **Everything in survey Class 4** — creature prohibitions, external character
  state, enchanted items, non-Hermetic traditions, all 11 legacy-edition
  findings.
- **A declarative constraint DSL.** The survey's four-rule result does not
  justify one. Item 69 holds the trigger conditions for revisiting.
- **`requiresVirtue` remaining unenforced.** Noted deliberately rather than
  fixed: this design locks a Range on behalf of a Virtue the app never checks
  the magus has. That asymmetry is acceptable only because there is no
  character model to check against, and it is stated here so it is not
  rediscovered as a bug. Rule 1, the driving case, is unaffected — it is gated
  behind no Virtue.

## Files

- `lib/models/target_type.dart` — `sensorium`; doc comment rewritten per
  Decision 1
- `lib/models/parameter.dart` — `forbidsTargetTypes`, `requiresRangeId`,
  serialization both ways; `ParameterScope` doc comment records the requisite
  reading
- `lib/models/spell.dart` — checks 10, 11, 12
- `lib/bloc/spell_creation/spell_creation_bloc.dart` — bidirectional pruning in
  `RangeSelected` and `TargetSelected`
- `lib/presentation/screens/spell_creation_screen.dart` — peer-aware dropdown
  filtering; locked Range with reason line
- `assets/data/parameters.json` — 5 rows change `targetType`; `range-personal`
  gains `forbidsTargetTypes`; 5 rows gain `requiresRangeId`
- `test/data/datasources/asset_data_loader_test.dart`,
  `test/models/parameter_test.dart`, `test/models/spell_test.dart`,
  `test/bloc/spell_creation_bloc_test.dart`,
  `test/data/published_spell_import_test.dart`
- `.superpowers/todo.md` — close item 68; close item 67's Range and requisite
  bullets; note the ordering constraint on item 65

**Repo conventions that bind this work:** `parameters.json` stores one compact
object per line and must not be reformatted — check `git diff --numstat`.
Never run `dart format`; hand-indent and check with `git diff -w`.
`flutter analyze` must stay at exit 0.

## See also

- **Item 67** — filed rules 2 and 3 as needing a design decision. This is it.
- **Item 68** — closed by Decision 1, on evidence rather than preference.
- **Item 70** — the survey's three incidental defects, including the +8
  citation drift this spec works around.
- **Item 69** — the deferred constraint-handling pains, and the trigger for
  revisiting a declarative mechanism.
- **Item 65** — blocked by Decision 1; see *Ordering*.
- **Item 64** — added the rows and made the `container` call this revises. Its
  reasoning was sound on the evidence it had; core 12086 is new evidence.
- **Item 14** — the container-mode feature whose derived predicate and check 9
  do the right thing for free here.
- **Item 56** — where the un-enforceable Sensory restrictions surface as hints.
