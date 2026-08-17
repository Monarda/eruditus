# Container Target Mode: Static vs. Dynamic — Design

**Date:** 2026-08-17
**Status:** Approved for planning
**Closes:** todo item 14 (and the last open row of todo section 0)

## Goal

Record, per spell, whether a container-target spell is **static** or **dynamic**
in the rulebook's sense. The distinction is real, is fixed when the spell is
designed, and nothing in the app can currently express it.

## Rulebook Basis

Definitive Edition core rules, the **"Container Targets" sidebar** (lines
12238–12262), section **"Static and Dynamic Targets"** (12242). This design uses
the rulebook's own two words for the two modes.

- **Static** (12246) — affects valid targets inside the container *at the moment
  of casting*, and keeps affecting them even if they leave, and even if the
  container ceases to exist. Nothing entering later is affected. This is how
  object Targets always work. *Exception:* a static **Circle** spell still ends
  if the circle is broken.
- **Dynamic** (12248) — affects valid targets *while* they are in the container.
  A target that leaves stops being affected; one that enters or re-enters starts
  being affected. The spell ends early if the container ceases to exist.

Three sentences from that sidebar decide the whole design:

1. **"The way that a particular spell works is fixed when it is designed, and
   cannot be changed by the casting magus"** (12250) — a design-time property of
   the spell, so it is stored on the record, not chosen at cast time.
2. The worked example (12252) is **two spells with identical Technique, Form,
   Range, Duration and Target** differing only in mode. No function of the
   parameter tuple can recover it, so it must be stored rather than derived.
3. Both versions in that example are the **same level**, and no magnitudes
   appear anywhere in the sidebar. **The mode is level-neutral.**

Target types come from line 12120: *"There are three types of target: objects,
containers, and senses."* Each Target then states its own type (Individual
12122, Circle 12124, Part 12128, Group 12130, Room 12132, Structure 12136,
Boundary 12138, senses 12152–12160).

## Two Prior Claims This Corrects

Todo item 14 carried a warning note, since deleted, guessing the rulebook might
settle the behaviour *per Target* and collapse the item. Both of its claims were
wrong for this purpose:

- **Group** is indeed fixed at casting (12130), but Group is an **object**
  Target and so was never in scope. Object targets are always static.
- **Circle** is **not** inherently ongoing. The "prevents things warded against
  from entering" language (12166) belongs to the **Magical Wards** rules and
  binds Circle *wards*, not the Circle Target. A non-ward Circle spell takes
  either mode.

All four container Targets take either mode.

## Decisions

**Decision 1 — Target type is catalog data, on `Parameter`.**
`Parameter` (`lib/models/parameter.dart:27`) gains `TargetType? targetType`
with values `object`, `container`, `sense`. Null for Range and Duration rows.
Nullable rather than defaulted, because "this is not a Target" and "this is a
Target of unknown type" are different, and only the first should be silent.

Not a hardcoded set of four ids in Dart: `custom_parameters` lets a user author
their own Target, which would then have no way to declare itself a container.

All 14 Target rows in `assets/data/parameters.json` are annotated — a
transcription of the rulebook, not a judgement:

| type | rows |
|---|---|
| `container` | `target-circle`, `target-room`, `target-structure`, `target-boundary` |
| `sense` | `target-taste`, `target-touch`, `target-smell`, `target-hearing`, `target-vision` |
| `object` | `target-individual`, `target-part`, `target-group`, `target-bloodline`, `target-symbol` |

The two supplement Targets were checked against their own books rather than
assumed. `target-symbol` is *"essentially a large Group"* (Houses of Hermes:
Mystery Cults, line 3763) — object. `target-bloodline` (core 10046) is object,
and carries its **own** built-in ongoing rule: the spell *"applies to all members
of the bloodline born during its duration, as well as those already living when
it is cast."* That is not a choice, so Bloodline must **not** offer one — the
`object` annotation is what forbids it. Do not "fix" this later on the grounds
that Bloodline behaves dynamically.

**Decision 2 — the mode is a stored enum with a neutral member.**

```dart
enum ContainerMode { unstated, static, dynamic }
```

`static` and `dynamic` are built-in identifiers in Dart but are legal as enum
constants; this was verified with the analyzer before being specified, and
`.name` yields exactly `"static"` / `"dynamic"` for serialization.

The field goes on **`Spell`, `SpellTemplate`, and `SpellDraft`**, defaulting to
`ContainerMode.unstated`, serialized by `.name`, parsed by a
`containerModeFromName(name, className)` helper that throws on an unknown value —
copying `ritualDeclarationFromName` (`lib/models/ritual_declaration.dart:14`)
exactly.

This follows `RitualDeclaration`'s path deliberately. That enum was added to the
model and the built-in library before any UI set it, with the stated reason that
"adding that UI needs no migration" (`ritual_declaration.dart:10`). The same
applies here, and matters more: the mode becomes **required** once spells belong
to a character, and that must not need a migration either.

**Decision 3 — "not applicable" is never stored.**
Whether a spell *owes* a mode is a pure function of catalog data — is the Target
a container, is the Duration Momentary. Storing an `n/a` value would be storing
derivable data, exactly what the id-reference normalization removed. So
`unstated` means **"no decision recorded"** and never "none owed". That is what
keeps the outstanding set findable later.

**Decision 4 — the hard rule and the soft rule are separate rules.**
Conflating them is what would force a migration later.

- **Hard, enforced now.** A new **check 9** in `validateSpellAgainstCatalog`
  (`lib/models/spell.dart:85`): the mode must be `unstated` unless the Target is
  a container. This is the rulebook's own boundary — only container Targets have
  the distinction at all.
- **Soft, derived, enforced by nobody yet.** A free function
  `spellOwesContainerMode({Parameter? target, Parameter? duration, required ContainerMode mode})`
  returning true when the Target is a container **and** the Duration is not
  Momentary **and** the mode is `unstated`. Tested, with no production caller.
  It is the hook the character work flips to a requirement.

Momentary is deliberately in the *soft* rule only. A Momentary container spell
cannot distinguish the two designs — nothing can enter during a duration that
does not elapse — so it owes nothing. But stating a mode on one is harmless
rather than wrong, so check 9 must not reject it. Check 9 stays purely about
Target type, which is all the rulebook actually constrains.

**Decision 5 — `validateSpellAgainstCatalog` gains a required, nullable Target.**
It cannot currently see the Target at all. Signature gains
`required Parameter? target` — *required to pass* so no caller can forget check
9, *nullable to hold* so an unresolvable target id skips the check rather than
throwing, matching how check 5 already treats an unresolvable modifier as
contributing 0.

Both production call sites already have it in hand: `draft.target`
(`lib/engine/spell_engine.dart:83`) and the resolved `target`
(`lib/models/resolved_spell.dart:74`). The remaining churn is ~10 test call
sites and is mechanical.

Note that in production, templates never pass through this function —
`isTemplate: true` appears only in tests. Check 9 over the 8 backfilled ward
templates is therefore enforced by `published_spell_import_test.dart`'s
assertion, which is where template validation lives.

**Decision 6 — `TargetSelected` must prune the mode.**
Unlike item 13's summary, which is scoped to nothing, this field is scoped to
the Target. Switching Room → Individual with a mode stated would leave a draft
that check 9 rejects at save with no visible cause. `TargetSelected`
(`spell_creation_bloc.dart:147-155`) already prunes stale modifier selections
after item 19; the mode joins it. Pruning is conditional on the *new* Target's
type, so switching Room → Structure preserves a stated mode.

**Decision 7 — `TemplateInstantiated` copies the mode from the template.**
It already copies `ritualDeclaration`, `analogyRationale` and (since item 13)
`summary`. Without this, instantiating a ward template would silently drop the
`dynamic` the backfill just recorded.

**Decision 8 — the backfill is a committed importer input.**
`spell_library.json` and `spell_templates.json` are both regenerated by
`--write`, so a mode written into either output would be destroyed on the next
run — the same trap item 55 hit, which is why `hand_authored_templates.json`
exists as a carried-in input.

New file `scripts/spell_import/container_modes.json`, keyed by spell id, each
entry carrying `mode` and `rationale`, consumed at emit time. It mirrors
`resolutions.json`'s role without reusing it: that ledger answers which
base-effect candidate a spell resolves to, and its staleness machinery
(candidate sets, widening, migration) has no meaning for a mode ruling.

**Eight entries, all `dynamic`, all sharing one rationale** — the Magical Wards
rule (12166) that a Circle ward prevents warded things inside from leaving and
outside from entering. This is one decision applied eight times, not eight
judgements:

```
lib-rean-circle-beast-warding
tpl-rean-ward-against-beasts-legend
tpl-reaq-ward-against-faeries-waters
tpl-reau-ward-against-faeries-air
tpl-rehe-ward-against-faeries-wood
tpl-reme-ring-warding-against-spirits
tpl-rete-ward-against-faeries-mountain
tpl-revi-circular-ward-against-demons
```

The importer must **fail loudly** on an entry naming an unknown spell id, or one
whose spell does not have a container Target. A silently-ignored entry is a
decision that looks recorded and isn't.

## Corpus State After This Lands

29 container-target rows: 20 in `spell_library.json` (boundary 8, room 9,
structure 2, circle 1), 9 in `spell_templates.json` (circle 8, room 1).

| | rows | after |
|---|---|---|
| Circle wards | 8 | `dynamic`, by the Magical Wards rule |
| Momentary duration | 5 | `unstated`, and owes nothing |
| Needs a prose reading | 16 | `unstated`, and owes a ruling |

`tpl-crvi-restore-faded-threads` (Circle, Diameter) is the one Circle row the
ward rule does **not** decide — it is not a ward — so it sits in the 16. An
earlier count of "9 wards" was wrong by one; this is the corrected figure.

## UI

A segmented control directly beneath the Target dropdown
(`spell_creation_screen.dart:242`), rendered only when
`draft.target?.targetType == TargetType.container`. This mirrors the open-slot
fields at `:202-209`, which appear immediately beneath the thing they qualify.

Three segments — `Not stated`, `Static`, `Dynamic` — with a helper line beneath
describing the selected one in plain terms. `unstated` is a **visible,
selectable** segment rather than an absence, because it is a real stored value:
deferring should be an act the user takes, not something that happens by not
noticing a control.

New event `ContainerModeSelected(ContainerMode mode)`, handled draft-only with
**no breakdown recompute** — the mode is level-neutral, so recomputing would be
waste, exactly as with item 13's `SummaryChanged`.

The Save button is never gated on the mode, and the save dialog never prompts
for it. It is optional by design until spells belong to characters.

## Storage

`AppDatabase` version 8 → 9, using the existing drop-and-rebuild `onUpgrade`.
The `spells` table stores the whole record as one JSON blob in `data`, so the
new field lands inside it with no DDL change — additive like v5/v6/v7, and
dropped anyway under the standing "backward compatibility is not a goal for this
prototype" policy.

## Testing

- **Model:** `ContainerMode` round-trips on `Spell` and `SpellTemplate`; an
  unknown stored name throws; the default is `unstated`.
- **Parameter:** `targetType` parses all three values, is null for a
  Range/Duration row, and throws on an unknown value.
- **Catalog:** every row in `parameters.json` with `category == "Target"` has a
  `targetType`. This is what stops a future Target being added without one.
- **Check 9:** rejects a stated mode on an object Target and on a sense Target;
  accepts either mode on each of the four containers; skips when `target` is
  null.
- **`spellOwesContainerMode`:** true for container + non-Momentary + unstated;
  false for each of the three negations independently, including the Momentary
  case, which is the one a reader is most likely to get wrong later.
- **Bloc:** `ContainerModeSelected` updates the draft and leaves the breakdown
  untouched; `TargetSelected` to a non-container clears a stated mode;
  `TargetSelected` between two containers preserves it; `TemplateInstantiated`
  copies the template's mode.
- **Widget:** the control renders only for a container Target and dispatches on
  tap.
- **Python:** every `container_modes.json` key names a real spell; every named
  spell has a container Target; an unknown id fails the run; emitted rows carry
  the mode.
- **Assertion suite:** the 8 backfilled wards satisfy check 9 through
  `published_spell_import_test.dart`.

Full verification is `flutter test`, `integration_test/`, and the Python suite —
`flutter test` does not run `integration_test/`.

## Out of Scope

- **The 16 prose judgements.** Each needs its spell's printed description read
  and a mode argued for; several will be genuinely arguable. That is its own
  item, and `container_modes.json` is where they will land.
- **Making the mode required.** It becomes required when spells belong to a
  character. `spellOwesContainerMode` is the hook; nothing calls it yet.
- **Editing a saved spell's mode.** No edit-spell UI exists, so a library spell's
  mode is not user-repairable in-app. Accepted, exactly as item 13 accepted the
  same limitation for a backfilled summary.
- **Any level effect.** The mode is descriptive; `SpellEngine` is untouched and
  assertions 1–7 are unaffected either way.
- **`Restore the Faded Threads`.** A Circle spell the ward rule does not decide;
  it stays `unstated` rather than being guessed at.
- **Explaining a Target's own built-in rules** — Bloodline's "members born
  during its duration", Circle's "ends if the circle is broken". These are
  properties of the Target that the app never surfaces, which is display work,
  not modelling: **todo item 56**. The segmented control's helper line is this
  design's one local instance, and should be folded into any general mechanism
  that lands later rather than left as a bespoke explainer.
