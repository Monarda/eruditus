# Final Review Fix Report: 4 Important Findings

## Status: COMPLETE

All 4 Important findings from the final whole-branch code review (which
approved all 15 MVP tasks with no Critical issues) are fixed, tested, and
committed. Full suite: **134/134 passing** (118 pre-existing + 16 new tests,
zero regressions). The real end-to-end integration test
(`spell_creation_flow_test.dart`, `-d windows`) still passes.

Commit: `a27db5c` — "fix: address 4 Important findings from final MVP code
review" (single commit; see reasoning under "Why one commit" below).

## Issue 1: Spell level never displayed on Library/Suggestion cards

**Fix approach:** precompute levels in the blocs (not in the widgets), reusing
the single existing `SpellEngine.calculateSpellLevel` implementation, so
there's exactly one place that knows how to sum magnitudes into a level.

- `SpellCreationState` gained `Map<String, int> suggestionLevels` (keyed by
  spell id). `SpellCreationBloc`'s `SpellCalculated` handling now computes it
  alongside `suggestions`, calling `spellEngine.calculateSpellLevel` per
  suggestion — the exact same call `findSimilarSpells` already makes
  internally for its sort, just also captured for display.
- `SpellLibraryBloc` gained a `SpellEngine` dependency (constructor param) and
  `SpellLibraryState` gained `Map<String, int> spellLevels`, computed the same
  way for every spell on `LibraryRequested`.
- `main.dart` now passes the **same** `SpellEngine` instance to both
  `SpellCreationBloc` and `SpellLibraryBloc` — it's reused purely for its
  `calculateSpellLevel` method, no duplicated math, no second engine
  constructed.
- `SpellCard` now renders `spell.description` (when present) as a second
  subtitle line, and both screens pass `level: <state>.<x>Levels[s.id]` into
  every `SpellCard`.

**Tests:** `spell_creation_bloc_test.dart` (`SpellCalculated precomputes a
level for each suggestion...`), `spell_library_bloc_test.dart` (`LibraryRequested
precomputes each spell's level...`), `spell_card_test.dart` (description
rendering, present/absent), `spell_library_screen_test.dart` (`shows each
card's precomputed level from state.spellLevels`), and
`spell_creation_screen_test.dart` (`shows suggestions with their level and
description...`).

## Issue 2: Re-saving a spell crashed; no success feedback or draft reset

**Root cause confirmed:** `SpellSaveRequested`'s handler had no try/catch, and
reused the same stable `draft.id` on every save, so a second save hit
sqflite's default `ConflictAlgorithm.abort` UNIQUE-constraint check and threw
uncaught out of the bloc, stranding the UI mid-`saving`.

**Fix (all three parts from the finding):**

1. Wrapped the save in try/catch. On failure, emits
   `SpellCreationStatus.error` + a new `errorMessage` field, following the same
   status/errorMessage convention already used by `SpellLibraryState`/
   `ConfigurationState` (note: like those, `copyWith`'s `errorMessage` does
   **not** fall back to the previous value — every emit implicitly clears a
   stale error unless explicitly re-passed).
2. **Chose "fresh draft/id after save" over `ConflictAlgorithm.replace`.**
   Reasoning: tapping "Save" a second time after a spell is already saved
   reads as "I'm done with this one, start the next" — not "silently
   overwrite the spell I just saved with whatever's still in the form."
   `ConflictAlgorithm.replace` would make a second, unrelated save request
   overwrite the first spell's row if the id ever collided, which is a much
   more surprising/destructive outcome than simply always minting a fresh
   draft. A successful save now emits `SpellCreationState.initial().copyWith(status:
   saved, savedSpell: spell)` — a brand-new `SpellDraft()` (new generated id)
   with everything else reset, which both gives the user a ready-to-go form
   for their next spell *and* structurally prevents the original crash, since
   a subsequent save can never collide on the same primary key again.
3. `SpellCreationScreen`'s single top-level `BlocBuilder` became a
   `BlocConsumer`: the `listener` shows a `SnackBar` on both `saved` (success,
   naming the spell) and `error` (failure, showing `errorMessage`). The
   results block (calculated-level card, suggestions, Discard/Save row) is now
   shown for `calculated`, `saving`, **and** `error` status (previously only
   `calculated`), so the user is never stranded with no controls; Save/Discard
   are disabled (not hidden) while `saving` to prevent the exact double-submit
   that caused the original crash, and a small `CircularProgressIndicator`
   replaces the Save button's label while in flight.

**Regression test reproducing the pre-fix crash:** `spell_creation_bloc_test.dart`
→ `'save, then fill in and save again: both persist as distinct spells with no
thrown error'` — fills and saves a spell, waits for it to land, then fills and
saves a second, different spell on the same bloc instance, and asserts both
persist with **distinct ids** and no exception propagates. A second bloc test
(`'... emits an error status (not a thrown exception) when the repository
fails'`) uses a `mocktail`-mocked `SpellRepository.saveSpell` that throws, and
asserts the bloc emits `error` + `errorMessage` (preserving the in-progress
draft) instead of the exception escaping — this is the actual "crash → no
longer crashes" proof, since it exercises the try/catch directly rather than
relying on the draft-reset side-effect to avoid ever re-triggering the DB
conflict. Widget-level coverage in `spell_creation_screen_test.dart`: SnackBar
on success, SnackBar + still-visible Save/Discard on error, and
Save/Discard both disabled while `saving`.

## Issue 3: Custom effects/parameters/factors didn't reach Create until restart

**Decision: `SpellCreationScreen` now reads effects/parameters/factors live
from `ConfigurationBloc`'s state, and no longer takes them as static
constructor lists at all.** This was explicitly framed as the "more correct"
option in the brief, and it is: `ConfigurationBloc` already gets fresh data
the moment a custom item is added (regardless of which tab is visible, since
`IndexedStack` keeps every tab's `initState` — and thus every bloc listener —
alive from app start), so reading it live means the Create tab is correct the
instant a custom item is added, with no tab-switch re-fetch event needed at
all (unlike the simpler Task-15-style "re-dispatch on tab tap" pattern, which
would only refresh at the moment of switching tabs and would still show stale
data if a change happened while already on the Create tab).

This surfaced a real second-order problem, which is also fixed:

- `SpellEngine.calculateSpellLevel` resolves a selected special factor's
  magnitude by **id lookup** in its `allSpecialFactors` list, which was
  captured once, frozen, at app startup. A custom special factor selected via
  the now-live dropdown would not be resolvable there, and would throw ("Bad
  state: no element") the moment `SpellCalculated` ran. Fixed by making
  `SpellEngine.allSpecialFactors` mutable with an `updateSpecialFactors(...)`
  method, a new `AvailableFactorsSynced` event on `SpellCreationBloc`, and a
  `BlocListener<ConfigurationBloc, ConfigurationState>` (wrapping the screen)
  that forwards `configState.factors` into that event whenever it changes —
  covering both the initial load and every subsequent Settings-tab edit.
- `BaseEffect`/`Parameter`/`SpecialFactor` gained **id-based value equality**
  (`==`/`hashCode`). This was necessary, not optional: `ConfigurationRepository`
  re-parses built-in JSON and re-queries custom rows fresh on *every* call
  (`AssetDataLoader` has no cache), so every `ConfigurationBloc` reload
  produces entirely new object instances, even for unchanged items.
  `DropdownButtonFormField<BaseEffect>`'s `initialValue: draft.baseEffect`
  matches its `items` by `==`, which defaults to reference equality — so
  without this fix, reading effects live from `ConfigurationBloc` would throw
  a "no item found for value" assertion the moment *any* config reload
  happened (even an unrelated one, e.g. adding a custom parameter) while a
  base effect was already selected in the draft. This is flagged clearly in
  the diff as a deliberate, minimal, necessary consequence of the "live data"
  choice, not scope creep for its own sake.
- `main.dart` simplified accordingly: `SpellCreationScreen` now only takes
  `techniques`/`forms` (static app constants, unrelated to user configuration);
  the `allEffects`/`allParameters` fetches in `main()` that existed solely to
  feed those old constructor params were removed as dead code.

**Tests:** a new file,
`test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`,
covers the cross-feature seam explicitly requested: it uses a `MockBloc` +
`StreamController<ConfigurationState>` (not a real bloc — this project's
established constraint is that a real `Bloc`'s event pipeline hangs
indefinitely under `flutter_tester`; see `flutter_sdk_path`/`real_bloc_widget_test_hang`
project memory), dispatches `CustomParameterAdded`/`CustomFactorAdded` on the
mock (verifying the exact event a real Settings-tab dialog would send), then
pushes the post-reload `ConfigurationState` through the controlled stream
*without reconstructing the widget*, and asserts the new parameter becomes
selectable and `AvailableFactorsSynced` is forwarded to `SpellCreationBloc`
with the new factor. `spell_creation_bloc_test.dart` also covers
`AvailableFactorsSynced` end-to-end at the bloc level (select a not-yet-known
factor id, sync it in, calculate, assert the level resolves instead of
throwing).

## Issue 4: Save/Discard race in SpellCreationBloc (UI-unreachable, latent)

Consolidated all of `SpellCreationBloc`'s per-event `on<E>()` registrations
into a single `on<SpellCreationEvent>()` handler with
`transformer: (events, mapper) => events.asyncExpand(mapper)`, exactly
mirroring the pattern already used by `SpellLibraryBloc` and
`ConfigurationBloc` (both carry the same explanatory comment about why:
flutter_bloc's default per-type `on<E>()` registration processes different
event types *concurrently*, which is what let this race exist in principle).
Every existing handler body was preserved as an `if (event is X) { ... } else
if ...` branch inside one `_onEvent` method — logic unchanged, only the
event-dispatch mechanism changed.

**Verification this didn't regress anything:** ran the full pre-existing
`SpellCreationBloc` test suite (all passed unchanged) plus a new explicit test,
`'SpellDiscarded dispatched immediately after SpellSaveRequested is processed
strictly after the save completes, never racing ahead of it'`, which fires
`SpellSaveRequested` then `SpellDiscarded` back-to-back and asserts the
emission order is `saving → saved → initial` (discard runs only after the
save's both emissions land) — the exact interleaving hazard the finding
described.

## Why one commit (not one per issue)

I considered splitting into per-issue commits but the actual changes are
inseparably entangled at the file level: `SpellCreationBloc`'s single
handler method contains Issue 1's suggestion-level computation, Issue 2's
try/catch, and *is* Issue 4's consolidation, all in the same `_onEvent`
method; `SpellCreationScreen` contains Issue 1's level/description display,
Issue 2's SnackBar/disabled-buttons, and Issue 3's live-config reads in the
same `build()`; and `main.dart`'s `SpellLibraryBloc(...)` call needed the new
required `spellEngine` param (Issue 1) in the same edit that removed the old
static-list constructor args (Issue 3) — splitting these would have meant at
least one intermediate commit that doesn't compile. A single commit with a
structured, per-issue message body was the more honest representation of the
actual work than a cosmetically-separated history that doesn't reflect how
interdependent the changes are.

## Full file list touched

- `lib/models/base_effect.dart`, `lib/models/parameter.dart`,
  `lib/models/special_factor.dart` — id-based `==`/`hashCode` (Issue 3
  dependency).
- `lib/engine/spell_engine.dart` — mutable `allSpecialFactors` +
  `updateSpecialFactors()` (Issue 3).
- `lib/bloc/spell_creation/spell_creation_event.dart` — new
  `AvailableFactorsSynced` event (Issue 3).
- `lib/bloc/spell_creation/spell_creation_state.dart` — new `error` status,
  `errorMessage`, `suggestionLevels` (Issues 1, 2).
- `lib/bloc/spell_creation/spell_creation_bloc.dart` — single sequential
  handler (Issue 4); try/catch + fresh-draft-after-save (Issue 2);
  suggestionLevels (Issue 1); `AvailableFactorsSynced` handling (Issue 3).
- `lib/bloc/spell_library/spell_library_state.dart`,
  `lib/bloc/spell_library/spell_library_bloc.dart` — `SpellEngine` dependency +
  `spellLevels` (Issue 1).
- `lib/presentation/widgets/spell_card.dart` — description rendering
  (Issue 1).
- `lib/presentation/screens/spell_creation_screen.dart` — live
  `ConfigurationBloc` reads (Issue 3); SnackBar, disabled Save/Discard while
  saving, broadened results-block visibility (Issue 2); level passed to
  suggestion cards (Issue 1).
- `lib/presentation/screens/spell_library_screen.dart` — level passed to
  cards (Issue 1).
- `lib/main.dart` — `SpellLibraryBloc` gets `spellEngine`; `SpellCreationScreen`
  constructor simplified; dead `allEffects`/`allParameters` fetches removed
  (Issues 1, 3).
- Tests updated/added: `test/bloc/spell_creation_bloc_test.dart`,
  `test/bloc/spell_library_bloc_test.dart`,
  `test/presentation/widgets/spell_card_test.dart`,
  `test/presentation/screens/spell_creation_screen_test.dart`,
  `test/presentation/screens/spell_library_screen_test.dart`,
  `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`
  (new), `test/widget_test.dart`,
  `integration_test/spell_creation_flow_test.dart`.

## Verification

- `flutter test`: **134/134 passing** (118 pre-existing + 16 new, 0
  regressions).
- `flutter test integration_test/spell_creation_flow_test.dart -d windows`:
  **1/1 passing** (real blocs, real in-memory sqflite, full save → library
  flow).
- `flutter analyze`: 2 pre-existing `info`-level `deprecated_member_use`
  warnings on `RadioListTile`/`groupValue` in
  `spell_library_screen.dart` — explicitly listed as an out-of-scope Minor
  finding in the dispatch brief, not touched. No new warnings introduced.

## Explicitly out of scope (per the dispatch brief)

Did not touch: dead `test_driver/integration_test.dart`, undisposed
`TextEditingController`s in config dialogs, `RadioListTile` deprecation,
`BottomNavigationBar` shifting-type default, backup import trusting embedded
`source`, hardcoded tab index. These are the Minor findings from the same
review and are explicitly called out as a separate triage.

## Commit hash

`a27db5c` — "fix: address 4 Important findings from final MVP code review"
