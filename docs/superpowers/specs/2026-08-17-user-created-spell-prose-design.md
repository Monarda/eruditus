# Summary/Description Entry for User-Created Spells — Design

**Date:** 2026-08-17
**Status:** Approved for planning

## Goal

Close todo item 13. A user-created spell can be saved today with no prose at
all, because the creation screen collects nothing but a name and
`validateSpellProse` therefore exempts user-created spells from the
summary-or-description rule. Add the input, carry the text through to the
saved spell, and make the rule unconditional.

## Rulebook Basis

None — this is app-model work, not rules fidelity. No rulebook text bears on
whether a magus writes down what their own spell does.

## Prior Decision This Settles

`docs/superpowers/specs/2026-07-27-spell-provenance-and-tags-design.md`
(lines 63–77) states invariant 1 — "a published spell has at least one of
summary/description; a user-created spell may have neither" — is
**conditional only as an interim measure**, deferred because collecting the
text "needs an input field and a new event, which is UI work and out of scope
here". It also records the two rejected alternatives: forcing a prose field
into the creation screen at that time (scope creep) and auto-deriving a
summary (storing derivable data, "precisely what the id-reference
normalization removed").

This design does the deferred UI work. The auto-derivation rejection still
stands and is respected below — the one place text is produced rather than
typed is a fixed sentinel for legacy rows, which derives nothing.

## Existing State (confirmed by reading the code, not assumed)

- `validateSpellProse` (`lib/models/spell.dart:25-37`) branches on
  `source == PublicationSource.published`. Its doc comment already says
  "Tighten this when that UI lands — todo item 13".
- It is called from two places, both of which **throw**: the `Spell`
  constructor (`:289-296`, `FormatException`) and `SpellDraft.toSpell`
  (`:434-437`, `StateError`).
- `SpellDraft` already carries `summary` and `description`, and `toSpell`
  passes both through. The provenance work added them for this task, so no
  model field is needed.
- The spell's **name is not part of the draft**. It is collected by
  `_SaveSpellDialog` (`spell_creation_screen.dart:798-836`) at save time and
  passed on `SpellSaveRequested(name)`, which carries nothing else.
- `SpellEngine.validateSpellDraft` gates **breakdown recalculation**:
  `spell_creation_bloc.dart:387-391` returns early on any error, so the level
  is not computed while the draft is invalid.
- `_SpecificTypeField` (`spell_creation_screen.dart:678-714`) is the existing
  pattern for a free-text draft field: a private `StatefulWidget` owning its
  controller with a `didUpdateWidget` resync, because an uncontrolled
  `TextFormField` seeds from `initialValue` once and never resyncs when this
  screen's state survives underneath `main.dart`'s `IndexedStack`.
- `TemplateInstantiated` already copies `ritualDeclaration` and
  `analogyRationale` from the template into the draft.
- `Spell.fromMap` is the single deserialization path for **both** the DB
  (`LocalSpellDatasource.getAllSpells` → `rows.map(_fromRow)`) and backup
  restore (`BackupService.importFromJson`, which builds its spells in a list
  literal). Neither tolerates a throw: the first takes the Library read with
  it, the second aborts the whole restore.

## Decisions

**Decision 1 — the rule becomes unconditional, with no source branch.**
`validateSpellProse` drops its `source` parameter rather than keeping it and
ignoring it, so no call site can imply a distinction that no longer exists.
The message becomes `'a spell needs a summary or a description'`.

**Decision 2 — one input, writing to `summary`.** The rule keeps its existing
"at least one of the two" wording; the UI simply only ever writes `summary`.
`description` is documented as verbatim rulebook text and a user-created
spell has no rulebook, so nothing is offered for it and its meaning is
unchanged.

**Decision 3 — the draft is the home; the save dialog is the backstop.** The
summary is edited in a screen-body section like every other draft field. If it
is still empty when Save is pressed, the save dialog collects it alongside the
name. The Save button itself is never disabled for want of a summary — there
is no dead end and no forced ordering, and the requirement is enforced at the
gate where the user is already being asked for something.

**Decision 4 — `validateSpellDraft` gains nothing.** Prose is a save-time
gate, not a draft-validity one. Adding the check there would stop the level
breakdown from computing until a summary was typed, which breaks the screen's
core build-and-watch-the-level loop. This is the one place the design
deliberately does *not* enforce the new rule.

**Decision 5 — legacy records are backfilled at deserialization, not
rejected.** In `Spell.fromMap`, a record whose summary and description are
both absent or empty gets `summary = 'No summary recorded.'` —

- **In `fromMap`, not in the datasource**, because a backup written before
  this change hits the identical wall one layer over.
- **Only when `source == userCreated`.** A published spell with no prose must
  keep throwing, or assertion 7 (`published_spell_import_test.dart`) quietly
  loses its teeth. The importer gives all 325 published spells prose, so this
  branch is unreachable from shipped data by construction.
- **A fixed sentinel, not a derivation.** Name and stat line both already
  appear on the card, so deriving from them adds nothing; the sentinel states
  the one true thing, that none was recorded. This is not the auto-derived
  summary the provenance spec rejected: it derives nothing and applies only to
  records written before the requirement existed.
- **Read-only.** Nothing is written back, so there is still no migration
  story, consistent with the standing "the database is droppable" constraint.

**Decision 6 — `TemplateInstantiated` seeds the summary from the template.**
Copying authored prose, not deriving it, so Decision 5's boundary and the
provenance spec's rejection both hold. Without it, instantiating a ward
template would demand the user invent text for a spell that already has some.

## Approach

### Model (`lib/models/spell.dart`)

- `validateSpellProse({required String? summary, required String? description})`
  — `source` parameter removed; message reworded.
- Both call sites (`Spell` constructor, `SpellDraft.toSpell`) drop the
  `source:` argument. Their throwing behaviour is unchanged.
- `Spell.fromMap` applies the Decision 5 backfill before constructing.

### Event (`lib/bloc/spell_creation/spell_creation_event.dart`)

- New `SummaryChanged(String summary)`.
- `SpellSaveRequested` gains `final String? summary` — "supplied at save time
  because the draft had none". Its `props` include it.

### Bloc (`lib/bloc/spell_creation/spell_creation_bloc.dart`)

- `SummaryChanged` → `state.copyWith(draft: state.draft.copyWith(summary: ...))`
  and nothing else. **No breakdown recompute**: prose cannot change a level,
  and recomputing on every keystroke of a multi-line field is waste.
- `_handleSpellSaveRequested` applies an event-supplied summary to the draft
  before `toSpell`:
  `final draft = event.summary == null ? state.draft : state.draft.copyWith(summary: event.summary);`
  One event, one atomic save — rather than dispatching `SummaryChanged` and
  then `SpellSaveRequested`, which would half-apply if the second were lost.
- `TemplateInstantiated` seeds `summary: template.summary` (Decision 6).
- **No clear-on-discard or clear-on-save work is needed.** `SpellDiscarded`
  and a successful save both emit `SpellCreationState.initial()`, which
  replaces the whole draft, so the summary goes with it. This is unlike the
  per-field pruning `TechniqueSelected`/`FormSelected`/`TargetSelected` do,
  because prose is scoped to nothing.
- Note `SpellDraft.copyWith` resolves `summary ?? this.summary`, so it can set
  a summary but not clear one back to null. Nothing here needs to: an empty
  string is what an emptied field produces, and every check below treats
  empty and null alike.

### UI (`lib/presentation/screens/spell_creation_screen.dart`)

- A `Summary` section in the body, using a new private `_SummaryField`
  built on `_SpecificTypeField`'s controller + `didUpdateWidget` pattern.
  `maxLines: 3`, key `summary-field`, helper text naming it as required and
  saying where it shows up. The `didUpdateWidget` resync is load-bearing here
  and not decorative: a successful save resets the draft to `initial()`, and
  without the resync the field would keep showing the saved spell's summary
  over an empty draft — the same class of bug the pattern was written for.
- `_SaveSpellDialog` gains `final bool requiresSummary`. When true it renders
  a second field (key `save-dialog-summary-field`) and its Save button stays
  disabled until **both** fields are non-empty; when false it is exactly
  today's dialog.
- The dialog returns both values; the screen passes them to
  `SpellSaveRequested`. `requiresSummary` is computed from the draft:
  `(draft.summary ?? '').trim().isEmpty && (draft.description ?? '').trim().isEmpty`.

### Tests

- **Model:** the rule rejects a prose-less spell of *either* source and
  accepts either field alone; `fromMap` backfills a user-created record with
  neither, leaves an existing summary untouched, and still throws for a
  published record with neither.
- **Bloc:** `SummaryChanged` updates the draft and leaves the breakdown
  untouched; a save with a dialog-supplied summary produces a spell carrying
  it; a save with a draft summary and no event summary keeps the draft's;
  `TemplateInstantiated` seeds from the template.
- **Widget:** the body field renders and dispatches; the dialog shows the
  second field only when the draft has no prose; Save is disabled until both
  fields are filled.
- **Integration:** the existing create-and-save flow needs the new dialog
  step, since saving now requires prose.

## Testing Strategy

The `Spell` constructor throws, so **every existing fixture that builds a
user-created spell without prose fails once the rule is unconditional.** That
sweep is the bulk of the work, not the feature. 16 test files reference
`userCreated`; `spell_test.dart` and `spell_engine_test.dart` hold the most
`Spell(...)` literals. Expect to fix fixtures first and let the suite drive
the list — a red suite here is the specification of the remaining work, not a
surprise.

`flutter test` does not run `integration_test/`. Both must pass, plus the
Python suite, per the standing verification rule.

## Out of Scope

- **Editing a saved spell's summary.** No edit-spell UI exists; this design
  does not add one. A backfilled sentinel is therefore not user-repairable
  in-app, which is accepted.
- **Offering `description` to users** (Decision 2), and any widening of its
  documented meaning.
- **Writing the backfill back to the database** (Decision 5) — no migration.
- **Prose on `SpellTemplate`.** Templates are catalog data emitted by the
  importer, not user records, and are unaffected by this rule.
- **Tag entry** (todo item 9), which shares the "creation screen collects only
  a name" root cause but is its own item.
