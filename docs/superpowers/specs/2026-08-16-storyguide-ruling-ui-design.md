# Storyguide-Ruling UI for Rituals — Design

**Date:** 2026-08-16
**Status:** Approved for planning

## Goal

Close todo item 18's two remaining checklist bullets: expose
`RitualDeclaration.storyguideRuling` in the spell creation UI (the model and
three built-in library spells already carry it, but no control sets it), and
confirm `SpellCreationBloc._withRitualDeclaration` keeps the two declaration
kinds — `lastingCreation` and `storyguideRuling` — distinguishable now that
both are user-settable.

## Rulebook Basis

Core Rules line 12352: the troupe may declare any spell a Ritual because its
effect is "so spectacular that it must not be easily accessible to magi."
This is condition 6 of the Ritual Spells design
(`docs/superpowers/specs/2026-07-27-ritual-spells-design.md`), orthogonal to
Technique, Form, and Duration — unlike condition 5 (`lastingCreation`), which
only applies to a Momentary Creo spell.

## Out of Scope

- **Item 21 (Creo Mentem memory restoration)** and **item 23 (cosmetic/test
  hygiene findings)** — separate todo items, not touched here.
- **Reclassifying the 4 remaining non-derivable Ritual spells** (*Rain of
  Oil*, *Incantation of Summoning the Dead*, *Disenchant*, *Watching Ward*) —
  a data-classification question, not UI work. Only the 3 spells that already
  carry `storyguideRuling` in the catalog (*Curse of the Ravenous Swarm*,
  *Neptune's Wrath*, *Breath of the Open Sky*) are relevant here, and they
  already import correctly; this design only adds the control that lets a
  *user* set the same declaration on a spell they're creating.
- **Model/schema changes.** `RitualDeclaration`, `SpellDraft.ritualDeclaration`,
  and the engine's unconditional honoring of any declaration
  (`SpellEngine._deriveRitualStatus`) already exist and are correct — see
  Existing State below.

## Existing State (confirmed by reading the code, not assumed)

- `RitualDeclaration` is a single enum (`none`, `lastingCreation`,
  `storyguideRuling`) — a spell's declaration is one of the three, never a
  combination. `SpellDraft.ritualDeclaration` stores it; `RitualSection`'s one
  checkbox today only ever sends `lastingCreation` or `none`.
- `SpellEngine._deriveRitualStatus` already honors any `ritualDeclaration`
  unconditionally, by design (its own comment: "a storyguide ruling is
  legitimate on any spell by definition, and keeping a live draft's
  declaration meaningful is the bloc's job, not the engine's").
- `SpellCreationBloc._withRitualDeclaration` already special-cases
  `storyguideRuling`: it returns the draft untouched, before checking
  lasting-creation eligibility at all, whenever
  `draft.ritualDeclaration == RitualDeclaration.storyguideRuling`. This means
  a storyguide ruling already survives every `reapplyDefault` call site
  (`TechniqueSelected`, `FormSelected`, `BaseEffectSelected`,
  `DurationSelected`) unchanged. Until now this path was only reachable via
  `TemplateInstantiated` (built-in spell data), never live user input — no UI
  control has ever set it directly.
- `RitualDeclarationChanged`'s bloc handler already sets whatever declaration
  it's given verbatim (`draft.copyWith(ritualDeclaration: event.declaration)`),
  with no re-derivation. Wiring a third UI option through this event needs no
  handler change.

Because of this, the work is UI plus regression tests proving the existing
guard holds under real user input — not new bloc logic. If the new tests
surface a real gap, it gets fixed as part of this work, not deferred.

## Approach

### `RitualSection` widget (`lib/presentation/widgets/ritual_section.dart`)

Replace the single `CheckboxListTile` with a `RadioListTile<RitualDeclaration>`
group of up to three options:

1. **Not declared** (`RitualDeclaration.none`) — always present.
2. **Creates something lasting** (`RitualDeclaration.lastingCreation`) — only
   present when `showLastingCreationOption` is true (renamed from today's
   `showDeclarationCheckbox`; same underlying value,
   `draft.isEligibleForLastingCreationDeclaration`). Keeps its existing
   subtitle, including the healing-suspension explanation when
   `guidelineIsSuggested`.
3. **Storyguide ruling: too spectacular to be freely available**
   (`RitualDeclaration.storyguideRuling`) — always present, since condition 6
   applies to any spell. Subtitle: a one-line note that this is a troupe
   judgement call, not something the guideline determines.

A radio group (rather than a second independent checkbox) makes the mutual
exclusivity visible in the UI: only one option can be selected at a time,
matching the single-enum model exactly. Selecting any option dispatches
`RitualDeclarationChanged(thatDeclaration)` — no new event type needed.

The widget's early-return that hides the whole section for an ordinary,
non-Ritual, ineligible spell is removed. The declaration control is now
always rendered — condition 6 makes it always potentially relevant — matching
how `_buildRequisitesSection`/`_buildAdjustmentsSection` are always-visible
elsewhere on this same screen. The Ritual banner above the control stays
conditional on `ritualStatus.isRitual`, exactly as today.

New widget keys: `ritual-radio-none`, `ritual-radio-lastingCreation`,
`ritual-radio-storyguideRuling` (replacing `ritual-checkbox`).

### `spell_creation_screen.dart`

Rename the `showDeclarationCheckbox:` argument passed to `RitualSection` to
`showLastingCreationOption:`. Same value (`draft.isEligibleForLastingCreationDeclaration`).
No other wiring changes.

### `SpellCreationBloc._withRitualDeclaration`

No logic change expected (see Existing State). Add regression tests that
exercise the storyguide-ruling path via real events for the first time:

- Set `storyguideRuling` via `RitualDeclarationChanged`, then dispatch
  `DurationSelected` (a `reapplyDefault: true` call site) to a
  non-Momentary duration — assert the declaration is still `storyguideRuling`.
- Set `storyguideRuling`, then dispatch `TechniqueSelected`/`FormSelected`/
  `BaseEffectSelected` — assert it survives (these clear `analogyRationale`
  etc. but must not touch a storyguide ruling).
- Set `lastingCreation` (on an eligible Creo+Momentary draft), then dispatch
  `RitualDeclarationChanged(RitualDeclaration.storyguideRuling)` — assert the
  declaration becomes `storyguideRuling` (single-enum replacement, not both
  set).
- Set `storyguideRuling`, then dispatch
  `RitualDeclarationChanged(RitualDeclaration.none)` — assert it clears to
  `none` (an explicit "not declared" choice is honored, not silently
  redirected back to a default).

If any of these fail against the current implementation, fix
`_withRitualDeclaration` (or the handler) as part of this same task — the
plan should not assume the fix is unnecessary, only that it's unlikely.

### Tests

- **`test/presentation/widgets/ritual_section_test.dart`**: rewritten for the
  radio group — the control is visible even for an ordinary non-Ritual spell;
  the lasting-creation option is present/absent by
  `showLastingCreationOption`; selecting each option reports the right
  `RitualDeclaration`; the banner's reason text is unaffected by this change.
- **`test/bloc/spell_creation_bloc_test.dart`**: the four regression cases
  above.

## Testing Strategy

Standard `flutter test` coverage for the widget and bloc changes above. No
model, engine, or import-pipeline code is touched, so no Python tests and no
new integration test are needed for this item.
