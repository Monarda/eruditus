# Live Spell Level Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the spell level at all times while a caster designs, instead of only after pressing **Calculate & View Suggestions**.

**Architecture:** A new total function `SpellEngine.previewLevel(draft)` returns either a `LevelBreakdown` or the one reason there isn't one, so a half-built draft can never throw. Every `emit` in `SpellCreationBloc` is routed through a single `_emit` funnel that attaches that preview, making it structurally impossible for a handler to emit a state whose breakdown disagrees with its own draft. The screen renders it as a pinned, collapsible `LevelBanner` above the scrolling form; the button keeps only the expensive suggestions half, and Save/Discard stop being gated behind it.

**Tech Stack:** Flutter, `flutter_bloc`, `equatable`, `bloc_test`, `mocktail`.

**Spec:** `docs/superpowers/specs/2026-08-17-live-spell-level-design.md`

## Global Constraints

- **This is a prototype. No backwards compatibility is owed.** Rename and delete freely; there is no stored `LevelBreakdown` and no migration to write.
- **TDD throughout.** Write the failing test, watch it fail for the stated reason, then implement.
- **Run tests with `flutter test`.** If it fails complaining about permissions on `sqlite3.dll`, that is stale `flutter_tester` processes holding a lock, not a real failure. Kill them and re-run:
  `Get-Process flutter_tester -ErrorAction SilentlyContinue | Stop-Process -Force`
- **Comment style:** this codebase writes comments that explain *why*, often several sentences, citing the case that motivated the code. Match that density — the surrounding files are the reference.
- **Exact user-facing strings**, used verbatim in both tests and implementation:
  - `Choose a base effect to see a level.`
  - `Type a level for this General guideline.`
  - `Choose a Range, Duration and Target.`
  - `Magnitudes reduce this spell below level 1.`
  - Banner heading: `Spell level`
  - Placeholder number: `—` (U+2014 em dash)
  - Button label: `Find Similar Spells`
- **Widget keys:** `level-banner`, `breakdown-total`, `level-banner-toggle`, `level-unavailable-reason`, `ritual-minimum-note`, `calculate-button` (kept, despite the relabel — it is the suggestions button now and the key churn would buy nothing).

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `lib/engine/ritual_status.dart` | `RitualStatus` becomes `Equatable` | 1 |
| `lib/engine/level_breakdown.dart` | `LevelContribution`/`LevelBreakdown` become `Equatable`; new `LevelPreview` | 1, 2 |
| `lib/engine/spell_engine.dart` | new `previewLevel` — the only non-throwing level entry point | 2 |
| `lib/bloc/spell_creation/spell_creation_state.dart` | `levelUnavailableReason`, sentinel on `breakdown`, drop `calculatedLevel` | 3 |
| `lib/bloc/spell_creation/spell_creation_bloc.dart` | `_emit` funnel, `_initialState`, save guard | 4 |
| `lib/presentation/widgets/level_banner.dart` | pinned collapsible banner (from `level_breakdown_card.dart`) | 5 |
| `lib/presentation/screens/spell_creation_screen.dart` | `Column` body, `showSuggestions`, ungated Save/Discard | 6 |
| `.superpowers/todo.md` | close item 59 and item 58's first bullet | 7 |

---

### Task 1: Make the breakdown value types `Equatable`

**Why this is Task 1 and not an afterthought:** `SpellCreationState` extends `Equatable` and lists `breakdown` in `props`, but `LevelBreakdown` has no `==`, so it compares by *identity*. Today that is harmless because `breakdown` changes only on Calculate. Once Task 4's funnel mints a fresh `LevelBreakdown` on every emit, no two states would ever compare equal — bloc would emit on every event even when nothing changed, and `bloc_test`'s `expect:` lists could never match. This is the same trap `generalEffectSentence` documents in `spell_creation_state.dart:82-91`, where a non-Equatable value was deliberately kept out of `props`.

**Files:**
- Modify: `lib/engine/ritual_status.dart:26-42`
- Modify: `lib/engine/level_breakdown.dart:5-50`
- Test: `test/engine/level_breakdown_test.dart`

**Interfaces:**
- Produces: `RitualStatus`, `LevelContribution`, `LevelBreakdown` all with value equality. Every existing constructor stays `const` and every field name is unchanged.

- [ ] **Step 1: Write the failing test**

Append to `test/engine/level_breakdown_test.dart` (inside `main()`; add `import 'package:eruditus/engine/ritual_status.dart';` at the top if it is not already there):

```dart
  group('value equality', () {
    test('two structurally identical contributions are equal', () {
      expect(
        const LevelContribution(label: 'Range · Voice', magnitude: 2),
        const LevelContribution(label: 'Range · Voice', magnitude: 2),
      );
    });

    test('contributions differing in any field are not equal', () {
      expect(
        const LevelContribution(label: 'Range · Voice', magnitude: 2),
        isNot(const LevelContribution(label: 'Range · Voice', magnitude: 3)),
      );
      expect(
        const LevelContribution(label: 'Base', magnitude: 2, isBase: true),
        isNot(const LevelContribution(label: 'Base', magnitude: 2)),
      );
    });

    test('two structurally identical ritual statuses are equal', () {
      expect(
        const RitualStatus([RitualReason.lastingCreation]),
        const RitualStatus([RitualReason.lastingCreation]),
      );
      expect(const RitualStatus.notRitual(), const RitualStatus([]));
    });

    test('two separately built but identical breakdowns are equal', () {
      // The property Task 4's emit funnel depends on: it rebuilds the
      // breakdown on every event, so an edit that does not move the level
      // must produce a breakdown that compares *equal* to the previous one.
      // Without this, SpellCreationState (which lists breakdown in props)
      // would look changed on every single emit.
      LevelBreakdown build() => const LevelBreakdown(
            level: 20,
            rawLevel: 20,
            ritualStatus: RitualStatus([RitualReason.lastingCreation]),
            contributions: [
              LevelContribution(label: 'Base effect · Create flame', magnitude: 10, isBase: true),
              LevelContribution(label: 'Range · Voice', magnitude: 2),
            ],
          );

      expect(build(), build());
    });

    test('breakdowns differing only in a nested contribution are not equal', () {
      const a = LevelBreakdown(
        level: 20, rawLevel: 20,
        contributions: [LevelContribution(label: 'Range · Voice', magnitude: 2)],
      );
      const b = LevelBreakdown(
        level: 20, rawLevel: 20,
        contributions: [LevelContribution(label: 'Range · Touch', magnitude: 1)],
      );

      expect(a, isNot(b));
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/engine/level_breakdown_test.dart`
Expected: FAIL. The equality tests fail because these are plain classes comparing by identity — `Expected: LevelContribution:<...> Actual: LevelContribution:<...>` on two distinct instances.

- [ ] **Step 3: Make `RitualStatus` Equatable**

In `lib/engine/ritual_status.dart`, add the import and change the class declaration and add `props`:

```dart
import 'package:equatable/equatable.dart';
```

```dart
class RitualStatus extends Equatable {
```

and immediately before the closing brace of the class, after `bool get isRitual => reasons.isNotEmpty;`:

```dart
  // Value equality, not identity: this sits inside LevelBreakdown, which sits
  // in SpellCreationState.props. SpellCreationBloc rebuilds the breakdown on
  // every emit, so an identity comparison here would make every state look
  // changed even when the level and its reasons had not moved.
  @override
  List<Object?> get props => [reasons];
```

Both constructors stay `const` — `Equatable`'s own constructor is `const`, so nothing else changes.

- [ ] **Step 4: Make `LevelContribution` and `LevelBreakdown` Equatable**

In `lib/engine/level_breakdown.dart`, add to the imports:

```dart
import 'package:equatable/equatable.dart';
```

Change `class LevelContribution {` to `class LevelContribution extends Equatable {` and add before its closing brace:

```dart
  // See RitualStatus.props for why these three types carry value equality.
  @override
  List<Object?> get props => [label, magnitude, isBase];
```

Change `class LevelBreakdown {` to `class LevelBreakdown extends Equatable {` and add before its closing brace:

```dart
  @override
  List<Object?> get props => [level, rawLevel, ritualStatus, contributions];
```

`props` deliberately omits `ritualMinimumApplied` and `magnitudeTotal` — both are derived from `level`/`rawLevel`/`contributions`, so including them would compare the same data twice.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/engine/`
Expected: PASS, all files.

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS. Adding equality only makes more things compare equal; nothing in the suite asserts that two identical breakdowns differ.

- [ ] **Step 7: Commit**

```bash
git add lib/engine/ritual_status.dart lib/engine/level_breakdown.dart test/engine/level_breakdown_test.dart
git commit -m "refactor: give the breakdown value types value equality"
```

---

### Task 2: `SpellEngine.previewLevel` — a level entry point that cannot throw

**Files:**
- Modify: `lib/engine/level_breakdown.dart` (add `LevelPreview`)
- Modify: `lib/engine/spell_engine.dart` (add `previewLevel` after `validateSpellDraft`, which ends at `:126`)
- Test: `test/engine/spell_engine_test.dart`

**Interfaces:**
- Consumes: `LevelBreakdown` from Task 1.
- Produces:
  - `class LevelPreview { LevelBreakdown? breakdown; String? unavailableReason; }` with `const LevelPreview.available(LevelBreakdown)` and `const LevelPreview.unavailable(String)`.
  - `LevelPreview SpellEngine.previewLevel(SpellDraft draft)` — never throws.

- [ ] **Step 1: Write the failing test**

Add to `test/engine/spell_engine_test.dart`, inside `main()`. Read the top of that file first and reuse its existing fixtures (`SpellEngine` construction, a numbered `BaseEffect`, and Range/Duration/Target `Parameter`s) rather than building new ones; the names below assume `engine`, `creoIgnemEffect`, `rangeParam`, `durationParam`, `targetParam`. If the file's fixtures are named differently, use its names — do not add duplicates.

```dart
  group('previewLevel', () {
    test('no base effect yet: says so instead of computing', () {
      final preview = engine.previewLevel(SpellDraft(technique: 'Creo', form: 'Ignem'));

      expect(preview.breakdown, isNull);
      expect(preview.unavailableReason, 'Choose a base effect to see a level.');
    });

    test('General guideline with no chosen level: says so instead of throwing', () {
      // calculateBreakdown throws ArgumentError here (spell_engine.dart:140-146)
      // and this state is reachable on literally every keystroke, so the live
      // path must answer with a reason rather than propagate.
      final general = BaseEffect(
        id: 'gen-1', technique: 'Creo', form: 'Ignem',
        description: 'Ward against beings', baseLevel: null,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final preview = engine.previewLevel(SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: general,
        range: rangeParam, duration: durationParam, target: targetParam,
      ));

      expect(preview.breakdown, isNull);
      expect(preview.unavailableReason, 'Type a level for this General guideline.');
    });

    test('a missing parameter: says so instead of computing', () {
      final preview = engine.previewLevel(SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: rangeParam, duration: durationParam,
      ));

      expect(preview.breakdown, isNull);
      expect(preview.unavailableReason, 'Choose a Range, Duration and Target.');
    });

    test('magnitudes below level 1: says so instead of throwing', () {
      // The other reachable ArgumentError. A stack of negative adjustments is
      // an ordinary intermediate state while a caster is still typing notes.
      final preview = engine.previewLevel(SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: rangeParam, duration: durationParam, target: targetParam,
        // Not `const`: LevelAdjustment's constructor validates the note.
        adjustments: [
          LevelAdjustment(magnitude: -5, note: 'a'),
          LevelAdjustment(magnitude: -5, note: 'b'),
          LevelAdjustment(magnitude: -5, note: 'c'),
        ],
      ));

      expect(preview.breakdown, isNull);
      expect(preview.unavailableReason, 'Magnitudes reduce this spell below level 1.');
    });

    test('a complete draft: returns the same breakdown calculateBreakdown would', () {
      final draft = SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: rangeParam, duration: durationParam, target: targetParam,
      );

      final preview = engine.previewLevel(draft);

      expect(preview.unavailableReason, isNull);
      expect(
        preview.breakdown,
        engine.calculateBreakdown(
          baseEffect: creoIgnemEffect, chosenBaseLevel: null,
          range: rangeParam, duration: durationParam, target: targetParam,
          selectedModifiers: const {}, requisites: const {},
        ),
      );
    });

    test('a base effect missing comes before a missing parameter', () {
      // Order matters: an empty draft is missing everything, and the caster's
      // first move is the guideline, so that is the reason worth showing.
      final preview = engine.previewLevel(SpellDraft());

      expect(preview.unavailableReason, 'Choose a base effect to see a level.');
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL to compile — `The method 'previewLevel' isn't defined for the type 'SpellEngine'`.

- [ ] **Step 3: Add `LevelPreview`**

Append to `lib/engine/level_breakdown.dart`:

```dart
/// The answer to "does this draft have a level yet, and if not, why not".
///
/// Exactly one of [breakdown] and [unavailableReason] is non-null. This exists
/// because [LevelBreakdown] is computed live, on every draft-changing event,
/// and a draft mid-edit is routinely not computable — see
/// `SpellEngine.previewLevel`, the only thing that constructs one.
///
/// Deliberately not Equatable, unlike its neighbours in this file: it is never
/// stored in bloc state. `SpellCreationState` holds its two halves as separate
/// fields, and those are what get compared.
class LevelPreview {
  final LevelBreakdown? breakdown;
  final String? unavailableReason;

  const LevelPreview.available(LevelBreakdown this.breakdown)
      : unavailableReason = null;

  const LevelPreview.unavailable(String this.unavailableReason)
      : breakdown = null;
}
```

- [ ] **Step 4: Add `previewLevel`**

In `lib/engine/spell_engine.dart`, insert immediately after `validateSpellDraft` closes (`:126`) and before `calculateBreakdown`:

```dart
  /// [calculateBreakdown] for a draft that may not be finished — the level as
  /// it stands, or the single reason there isn't one.
  ///
  /// **This is not validation.** It answers "is there a number", not "is this
  /// spell legal": [validateSpellDraft] owns the catalog invariants and stays
  /// behind a button press, because its messages render as red text and firing
  /// them on every keystroke would flag a half-built draft as broken (todo
  /// item 59). This method's reasons are the opposite in tone — they say what
  /// to do next, not what is wrong.
  ///
  /// It exists because [calculateBreakdown] throws two ways that are ordinary
  /// intermediate states rather than errors: a General guideline before its
  /// level is typed, and negative magnitudes that momentarily drive the level
  /// below 1. The button-driven path could let those escape, since nothing
  /// called it until the draft was finished. A live path cannot, so every
  /// throw is converted here and this method never throws.
  ///
  /// A null Technique or Form needs no reason of its own: the base effect
  /// dropdown does not render without them
  /// (`spell_creation_screen.dart:115`), so the first branch covers it.
  LevelPreview previewLevel(SpellDraft draft) {
    final baseEffect = draft.baseEffect;
    if (baseEffect == null) {
      return const LevelPreview.unavailable('Choose a base effect to see a level.');
    }
    if (baseEffect.isGeneral && draft.chosenBaseLevel == null) {
      return const LevelPreview.unavailable('Type a level for this General guideline.');
    }

    final range = draft.range;
    final duration = draft.duration;
    final target = draft.target;
    if (range == null || duration == null || target == null) {
      return const LevelPreview.unavailable('Choose a Range, Duration and Target.');
    }

    try {
      return LevelPreview.available(calculateBreakdown(
        baseEffect: baseEffect,
        chosenBaseLevel: draft.chosenBaseLevel,
        range: range,
        duration: duration,
        target: target,
        selectedModifiers: draft.selectedModifiers,
        requisites: draft.requisites,
        adjustments: draft.adjustments,
        ritualDeclaration: draft.ritualDeclaration,
      ));
    } on ArgumentError {
      return const LevelPreview.unavailable('Magnitudes reduce this spell below level 1.');
    }
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/engine/level_breakdown.dart lib/engine/spell_engine.dart test/engine/spell_engine_test.dart
git commit -m "feat: add SpellEngine.previewLevel, a level entry point that cannot throw"
```

---

### Task 3: State carries the reason, and loses `calculatedLevel`

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_state.dart`
- Modify: `test/bloc/spell_creation_bloc_test.dart` (mechanical: `:139`, `:317`, `:1012`, `:1034`, `:1098`, `:1940`, `:1943`, `:2052`, `:2210`, `:2267`)
- Modify: `test/presentation/screens/spell_creation_screen_test.dart` (mechanical: `:227`, `:273`, `:350`, `:385`, `:424`, `:439`, `:459`, `:488`, `:511`, `:583`, `:591`, `:627`)

**Interfaces:**
- Consumes: `LevelBreakdown` (Task 1).
- Produces: `SpellCreationState.levelUnavailableReason` (`String?`); `copyWith` accepts `Object? breakdown = _unset` and `Object? levelUnavailableReason = _unset`; `calculatedLevel` no longer exists.

- [ ] **Step 1: Write the failing test**

Add to `test/bloc/spell_creation_bloc_test.dart`, at the top level of `main()` (it tests the state class, not the bloc, so it does not belong inside an event group):

```dart
  group('SpellCreationState.copyWith clearing', () {
    test('an omitted breakdown is carried forward, an explicit null clears it', () {
      const breakdown = LevelBreakdown(level: 20, rawLevel: 20, contributions: []);
      final withBreakdown = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(),
        breakdown: breakdown,
      );

      expect(withBreakdown.copyWith(status: SpellCreationStatus.saving).breakdown, breakdown,
          reason: 'an emit that says nothing about the level must not wipe it');
      expect(withBreakdown.copyWith(breakdown: null).breakdown, isNull,
          reason: 'a draft going incomplete must be able to clear the level');
    });

    test('an omitted reason is carried forward, an explicit null clears it', () {
      final withReason = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(),
        levelUnavailableReason: 'Choose a base effect to see a level.',
      );

      expect(withReason.copyWith(status: SpellCreationStatus.saving).levelUnavailableReason,
          'Choose a base effect to see a level.');
      expect(withReason.copyWith(levelUnavailableReason: null).levelUnavailableReason, isNull);
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name 'copyWith clearing'`
Expected: FAIL to compile — `The named parameter 'levelUnavailableReason' isn't defined`.

- [ ] **Step 3: Change the state class**

In `lib/bloc/spell_creation/spell_creation_state.dart`:

Delete the `calculatedLevel` field declaration (`:12`), its constructor parameter (`:39`), its `copyWith` parameter (`:58`), its `copyWith` body line (`:71`), and its entry in `props` (`:100`). It duplicated `breakdown.level` and no production code ever read it.

Add beside `breakdown` (`:13`):

```dart
  /// Why there is no [breakdown], when there isn't one — "Choose a base effect
  /// to see a level.", and so on. Non-null exactly when [breakdown] is null,
  /// because both are written together by SpellCreationBloc's emit funnel from
  /// a single SpellEngine.previewLevel result.
  ///
  /// Not a validation error: it renders inside the level banner as ordinary
  /// text saying what to do next, never as the red error text those use.
  final String? levelUnavailableReason;
```

Add `this.levelUnavailableReason,` to the constructor's optional block.

Change the two `copyWith` parameters to sentinel form:

```dart
    Object? breakdown = _unset,
    Object? levelUnavailableReason = _unset,
```

and their bodies:

```dart
      // Both use the same `_unset` sentinel as generalEffectSentence below,
      // and for a sharper version of the same reason. The emit funnel writes
      // whichever of the two the current draft calls for and clears the other,
      // so a plain `?? this.breakdown` -- which cannot tell "omitted" from
      // "explicitly cleared" apart -- would strand a level on screen for a
      // draft that no longer has one.
      breakdown: identical(breakdown, _unset)
          ? this.breakdown
          : breakdown as LevelBreakdown?,
      levelUnavailableReason: identical(levelUnavailableReason, _unset)
          ? this.levelUnavailableReason
          : levelUnavailableReason as String?,
```

Add `levelUnavailableReason,` to `props`.

- [ ] **Step 4: Fix the mechanical test references**

In both test files, delete every `calculatedLevel: <value>,` line from state constructions. Then fix the six assertions:

- `test/bloc/spell_creation_bloc_test.dart:139`, `:317`, `:1012`, `:1034`, `:1098` — replace
  `.having((s) => s.calculatedLevel, 'calculatedLevel', N)` with
  `.having((s) => s.breakdown?.level, 'breakdown.level', N)`.
- `:1943` — replace `expect(bloc.state.calculatedLevel, isNull)` with `expect(bloc.state.breakdown, isNull)`.
- `:2052` — replace `expect(bloc.state.calculatedLevel, isNotNull)` with `expect(bloc.state.breakdown, isNotNull)`.

Do not change anything else in those tests yet; Task 4 rewrites the two that assert `same(...)`.

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS. If a `calculatedLevel` reference remains anywhere, the compile error names the file and line — delete it the same way.

- [ ] **Step 6: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_state.dart test/bloc/spell_creation_bloc_test.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: carry a levelUnavailableReason in state, drop the unread calculatedLevel"
```

---

### Task 4: The emit funnel

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart`
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `SpellEngine.previewLevel` (Task 2); `SpellCreationState.levelUnavailableReason` (Task 3).
- Produces: every emitted `SpellCreationState` has `breakdown` and `levelUnavailableReason` agreeing with its own `draft`, on every event and from the very first state.

- [ ] **Step 1: Write the failing tests**

Add a new group to `test/bloc/spell_creation_bloc_test.dart`. Use the file's existing `spellEngine` / `spellRepository` / `creoIgnemEffect` / `rangeParam` / `durationParam` / `targetParam` fixtures — read the file's `setUp` first and match its names.

```dart
  group('the level is live', () {
    test('the initial state already explains why there is no level', () {
      final bloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      addTearDown(bloc.close);

      expect(bloc.state.breakdown, isNull);
      expect(bloc.state.levelUnavailableReason, 'Choose a base effect to see a level.');
    });

    blocTest<SpellCreationBloc, SpellCreationState>(
      'a complete draft has a level with no button press at all',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(RangeSelected(rangeParam))
        ..add(DurationSelected(durationParam))
        ..add(TargetSelected(targetParam)),
      verify: (bloc) {
        expect(bloc.state.status, SpellCreationStatus.editing,
            reason: 'no SpellCalculated was ever dispatched');
        expect(bloc.state.breakdown, isNotNull);
        expect(bloc.state.levelUnavailableReason, isNull);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'an edit that empties the draft clears the level and says why',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(RangeSelected(rangeParam))
        ..add(DurationSelected(durationParam))
        ..add(TargetSelected(targetParam))
        // Clears baseEffect (spell_creation_bloc.dart:57), so the level goes
        // with it rather than lingering as a number for a spell that no
        // longer has a guideline.
        ..add(const TechniqueSelected('Perdo')),
      verify: (bloc) {
        expect(bloc.state.breakdown, isNull);
        expect(bloc.state.levelUnavailableReason, 'Choose a base effect to see a level.');
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'discarding resets to a draft that explains itself',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(const SpellDiscarded()),
      verify: (bloc) {
        expect(bloc.state.breakdown, isNull);
        expect(bloc.state.levelUnavailableReason, 'Choose a base effect to see a level.');
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'saving an invalid draft emits its errors and writes nothing',
      // With Save no longer sitting behind Calculate, this guard is the only
      // thing between an incomplete draft and the repository.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(const SpellSaveRequested('Pillar of Flames')),
      verify: (bloc) {
        expect(bloc.state.validationErrors, isNotEmpty);
        expect(bloc.state.status, SpellCreationStatus.editing);
        expect(bloc.state.savedSpell, isNull);
      },
    );
  });
```

- [ ] **Step 2: Rewrite the two `same(...)` tests, which encode the old contract**

`test/bloc/spell_creation_bloc_test.dart` has two tests asserting the breakdown is the *identical instance* after an edit — the SummaryChanged one near `:2205` and the ContainerModeSelected one near `:2262`, each with a comment saying "must not recompute the breakdown". That contract is exactly what item 58's first bullet complains about and what this task inverts: the breakdown *is* recomputed on every event, and the point is that a level-neutral edit leaves it at an equal *value*.

Replace the `verify:` block of the SummaryChanged test with:

```dart
      verify: (bloc) {
        expect(bloc.state.breakdown, isNotNull,
            reason: 'the fixture must actually produce a breakdown, or this test proves nothing');
        expect(bloc.state.draft.summary, 'A jet of flame.');
        // Value, not identity (this used to assert `same`). The emit funnel
        // rebuilds the breakdown on every event, so what matters is that a
        // level-neutral edit lands on an equal one -- prose cannot move a
        // level, and the level must not blink out while it is typed.
        // This is todo item 58's first bullet.
        expect(bloc.state.breakdown, breakdownBeforeSummary);
        expect(bloc.state.levelUnavailableReason, isNull);
      },
```

Replace the `verify:` block of the ContainerModeSelected test with the same shape, and delete its now-wrong "Identity, not value" comment above `build:`:

```dart
      verify: (bloc) {
        expect(bloc.state.breakdown, isNotNull,
            reason: 'the fixture must actually produce a breakdown, or this test proves nothing');
        expect(bloc.state.draft.containerMode, ContainerMode.static);
        // See the SummaryChanged test above: the container mode is
        // level-neutral, so the recomputed breakdown must compare equal.
        expect(bloc.state.breakdown, breakdownBeforeContainerMode);
        expect(bloc.state.levelUnavailableReason, isNull);
      },
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL. The new "the level is live" tests fail on `breakdown, isNotNull` / `levelUnavailableReason` being null, because nothing computes a preview yet. The invalid-save test fails because the save currently proceeds.

- [ ] **Step 4: Add the funnel and the initial state**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, replace the constructor (`:34-48`) with:

```dart
  SpellCreationBloc({
    required this.spellEngine,
    required this.spellRepository,
  }) : super(_initialState(spellEngine)) {
    on<SpellCreationEvent>(
      _onEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  /// The first thing the Create tab renders: an empty draft seeded at the
  /// standard reference triple, already carrying the reason it has no level.
  ///
  /// A static method taking the engine, rather than an instance one, for the
  /// same reason [_emptySeeded] is: `super(...)` runs before `this` exists, so
  /// the constructor cannot reach [_emit] even though it needs exactly what
  /// [_emit] does. Seeded here rather than in SpellCreationState.initial(),
  /// which has no catalog to resolve ids against -- and must not gain one,
  /// since TemplateInstantiated builds on it and its parameters must survive
  /// verbatim.
  static SpellCreationState _initialState(SpellEngine engine) {
    final draft = _emptySeeded(engine.allParameters);
    final preview = engine.previewLevel(draft);
    return SpellCreationState.initial().copyWith(
      draft: draft,
      breakdown: preview.breakdown,
      levelUnavailableReason: preview.unavailableReason,
    );
  }

  /// Emits [next] with its level recomputed from its own draft.
  ///
  /// **Every emit in this bloc goes through here.** That is the whole point:
  /// the level is a pure function of the draft, so no handler should have to
  /// remember to refresh it, and none can forget. Before this, an edit emitted
  /// `status: editing` and the screen hid the level card until the user pressed
  /// Calculate again -- so the number a caster designs towards was absent
  /// exactly while they were designing (todo item 59), and two level-neutral
  /// events hid it for no reason at all (todo item 58).
  ///
  /// Recomputing unconditionally is cheap: [SpellEngine.previewLevel] walks a
  /// handful of contributions. The expensive half -- findSimilarSpells and a
  /// calculateBreakdown per candidate -- stays behind SpellCalculated.
  ///
  /// A level-neutral edit produces an *equal* breakdown rather than the same
  /// instance, which is why LevelBreakdown, LevelContribution and RitualStatus
  /// carry value equality: SpellCreationState lists breakdown in its props, and
  /// identity comparison would make every state here look changed.
  void _emit(Emitter<SpellCreationState> emit, SpellCreationState next) {
    final preview = spellEngine.previewLevel(next.draft);
    emit(next.copyWith(
      breakdown: preview.breakdown,
      levelUnavailableReason: preview.unavailableReason,
    ));
  }
```

- [ ] **Step 5: Route every emit through the funnel**

In `_onEvent` and both `_handle...` methods, change every `emit(` call to `_emit(emit, `, closing the extra paren. There are 26. Work top to bottom so none is missed; `grep -n 'emit(' lib/bloc/spell_creation/spell_creation_bloc.dart` afterwards should show no bare `emit(state` or `emit(Spell` left outside `_emit`'s own body.

Two branches additionally need an emit they do not have today. Replace:

```dart
    } else if (event is AvailableModifiersSynced) {
      spellEngine.updateModifiers(event.modifiers);
    } else if (event is AvailableParametersSynced) {
      spellEngine.updateParameters(event.parameters);
```

with:

```dart
    } else if (event is AvailableModifiersSynced) {
      spellEngine.updateModifiers(event.modifiers);
      // Re-emits the current state so the funnel recomputes the level against
      // the new catalog. A selected modifier whose magnitude only just became
      // resolvable changes the level, and with the level live that has to show
      // immediately rather than at the next unrelated edit. When nothing moves,
      // the recomputed state compares equal and Bloc emits nothing.
      _emit(emit, state);
    } else if (event is AvailableParametersSynced) {
      spellEngine.updateParameters(event.parameters);
      _emit(emit, state);
```

- [ ] **Step 6: Simplify `_handleSpellCalculated` and guard the save**

In `_handleSpellCalculated`, delete the local `calculateBreakdown` call and the `final level = breakdown.level;` line, and replace them with:

```dart
    // The funnel already computed this draft's breakdown, and validateSpellDraft
    // returning empty just re-ran the same calculation over the same draft --
    // so it is non-null here by construction. Reading it beats a third identical
    // call whose only product is the reference level below.
    final level = state.breakdown!.level;
```

Then delete `calculatedLevel: level,` from the final emit (Task 3 removed the field) and leave `breakdown: breakdown` out too — the funnel writes it. The final emit becomes:

```dart
    _emit(emit, state.copyWith(
      status: SpellCreationStatus.calculated,
      validationErrors: const [],
      suggestions: suggestions,
      suggestionLevels: suggestionLevels,
      ritualSuggestionIds: ritualSuggestionIds,
    ));
```

In `_handleSpellSaveRequested`, insert before the `status: saving` emit:

```dart
    // Save used to render only after a successful Calculate, so the draft
    // reaching here had already been validated. It renders unconditionally now
    // (todo item 59), which makes this the only thing between an invalid draft
    // and the repository. The screen also disables the button while there is no
    // level, but that is an affordance, not a gate -- a dispatched event has to
    // be safe on its own.
    final errors = spellEngine.validateSpellDraft(state.draft);
    if (errors.isNotEmpty) {
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        validationErrors: errors,
      ));
      return;
    }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS.

If a `blocTest` `expect:` list now fails with an unexpected extra state, check whether the event genuinely changed the level. If it did, the extra state is correct and the expectation should be updated; if it did not, the two states should have compared equal, which means Task 1's `props` is missing a field.

- [ ] **Step 8: Run the full suite**

Run: `flutter test`
Expected: PASS except `test/presentation/screens/spell_creation_screen_test.dart`, which may still pass here — the screen is untouched until Task 6.

- [ ] **Step 9: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: recompute the spell level on every emit

Routes every emit through one funnel that attaches SpellEngine.previewLevel,
so no handler can emit a state whose breakdown disagrees with its own draft.
Closes todo item 58's first bullet as a consequence rather than a patch."
```

---

### Task 5: `LevelBanner`

**Files:**
- Create: `lib/presentation/widgets/level_banner.dart`
- Delete: `lib/presentation/widgets/level_breakdown_card.dart`
- Create: `test/presentation/widgets/level_banner_test.dart`
- Delete: `test/presentation/widgets/level_breakdown_card_test.dart`

**Interfaces:**
- Consumes: `LevelBreakdown` (Task 1).
- Produces: `LevelBanner({Key? key, LevelBreakdown? breakdown, String? unavailableReason})`.

`LevelBreakdownCard` has exactly one call site, so this is a rename-and-extend rather than a new widget beside an old one. The name changes because it is no longer a card in the scroll.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/level_banner_test.dart`. It is `level_breakdown_card_test.dart` carried over — the contribution and ritual-note assertions are unchanged in substance, but now happen after expanding.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/presentation/widgets/level_banner.dart';

void main() {
  const breakdown = LevelBreakdown(
    level: 10,
    rawLevel: 10,
    contributions: [
      LevelContribution(label: 'Base effect · image, two senses', magnitude: 2, isBase: true),
      LevelContribution(label: 'Range · Voice', magnitude: 2),
      LevelContribution(label: 'Duration · Momentary', magnitude: 0),
      LevelContribution(label: 'Material difficulty · Metal or gemstone', magnitude: 2),
    ],
  );

  Future<void> pump(WidgetTester tester, Widget banner) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: banner)));
  }

  testWidgets('shows the level', (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.byKey(const Key('breakdown-total')), findsOneWidget);
    expect(find.text('Spell level'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('is collapsed by default, so the form keeps its room', (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    expect(find.text('Range · Voice'), findsNothing);
  });

  testWidgets('lists every contribution once expanded, base without a plus sign',
      (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Base effect · image, two senses'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Range · Voice'), findsOneWidget);
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+0'), findsOneWidget);
    expect(find.text('Material difficulty · Metal or gemstone'), findsOneWidget);
  });

  testWidgets('collapses again on a second tap', (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Range · Voice'), findsNothing);
  });

  testWidgets('does not show a magnitude total', (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    // The tier split that would explain a total is deferred, so showing the
    // total alone would invite "why isn't 2 + 4 = 6?".
    expect(find.textContaining('Total magnitude'), findsNothing);
  });

  testWidgets('does not show a Ritual minimum note when the floor did not apply',
      (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ritual-minimum-note')), findsNothing);
  });

  testWidgets('shows a Ritual minimum note with the raw and floored levels when the floor applied',
      (tester) async {
    const flooredBreakdown = LevelBreakdown(
      level: 20,
      rawLevel: 2,
      contributions: [
        LevelContribution(label: 'Base effect · Heal a Light Wound to a plant', magnitude: 1, isBase: true),
        LevelContribution(label: 'Range · Touch', magnitude: 1),
      ],
    );

    await pump(tester, const LevelBanner(breakdown: flooredBreakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ritual-minimum-note')), findsOneWidget);
    expect(find.text('Ritual minimum: raised from 2 to 20'), findsOneWidget);
  });

  testWidgets('with no level, shows an em dash and the reason', (tester) async {
    await pump(tester, const LevelBanner(
      unavailableReason: 'Choose a base effect to see a level.',
    ));

    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.byKey(const Key('level-unavailable-reason')), findsOneWidget);
    expect(find.text('Choose a base effect to see a level.'), findsOneWidget);
  });

  testWidgets('with no level, offers no expand affordance', (tester) async {
    await pump(tester, const LevelBanner(
      unavailableReason: 'Choose a base effect to see a level.',
    ));

    expect(find.byKey(const Key('level-banner-toggle')), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/widgets/level_banner_test.dart`
Expected: FAIL to compile — `Error when reading 'lib/presentation/widgets/level_banner.dart': The system cannot find the file`.

- [ ] **Step 3: Create the widget**

Create `lib/presentation/widgets/level_banner.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:eruditus/engine/level_breakdown.dart';

/// The spell's level, pinned above the creation form and outside its scroll.
///
/// **Always on screen, and never hidden by an edit.** [breakdown] null means
/// the draft cannot produce a level yet, and [unavailableReason] fills the slot
/// the number would occupy. This is the whole point of todo item 59: before it,
/// the level appeared only after a button press and every subsequent edit hid
/// it again, so the number a caster designs towards was absent exactly while
/// they were designing.
///
/// Pinned rather than left in the scroll because the form runs from Technique
/// down to Summary -- an inline card is off-screen precisely when the caster is
/// editing the fields at the top. Placed *above* the ListView in a Column, so
/// the on-screen keyboard (which insets from the bottom) can never cover it.
///
/// Collapsed by default. The contribution list runs to a dozen rows on a spell
/// with several modifiers, requisites and adjustments, which pinned open would
/// swallow the form -- so the header is always visible and the detail is one
/// tap away, capped at 40% of the height with its own scroll.
///
/// Deliberately omits the magnitude total and the additive-tier/multiplier
/// split: both are deferred together, because a total shown without the tier
/// arithmetic raises a question only the tier arithmetic answers.
class LevelBanner extends StatefulWidget {
  final LevelBreakdown? breakdown;
  final String? unavailableReason;

  const LevelBanner({super.key, this.breakdown, this.unavailableReason});

  @override
  State<LevelBanner> createState() => _LevelBannerState();
}

class _LevelBannerState extends State<LevelBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final breakdown = widget.breakdown;
    final reason = widget.unavailableReason;

    return Material(
      key: const Key('level-banner'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              key: const Key('breakdown-total'),
              children: [
                Expanded(
                  child: Text('Spell level',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(breakdown == null ? '—' : '${breakdown.level}',
                    style: Theme.of(context).textTheme.headlineSmall),
                // No breakdown means nothing to expand, so no control offering
                // to -- a disabled chevron would imply detail is being withheld
                // when there is simply none yet.
                if (breakdown != null)
                  IconButton(
                    key: const Key('level-banner-toggle'),
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    tooltip: _expanded ? 'Hide the breakdown' : 'Show the breakdown',
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
              ],
            ),
            if (reason != null)
              Text(
                reason,
                key: const Key('level-unavailable-reason'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (breakdown != null && _expanded)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      ...breakdown.contributions.map((contribution) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(contribution.label)),
                                Text(contribution.isBase
                                    ? '${contribution.magnitude}'
                                    : '+${contribution.magnitude}'),
                              ],
                            ),
                          )),
                      // The floor is deliberately not a LevelContribution (see
                      // the class doc on ritualMinimumApplied), so a
                      // raw-level-2 calculation that displays as 20 needs its
                      // own line explaining the gap -- otherwise the
                      // contributions above visibly fail to sum to the total.
                      if (breakdown.ritualMinimumApplied)
                        Padding(
                          key: const Key('ritual-minimum-note'),
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Ritual minimum: raised from ${breakdown.rawLevel} to ${breakdown.level}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/presentation/widgets/level_banner_test.dart`
Expected: PASS.

- [ ] **Step 5: Delete the old widget and its test**

```bash
git rm lib/presentation/widgets/level_breakdown_card.dart test/presentation/widgets/level_breakdown_card_test.dart
```

The screen still imports it, so the build breaks here. Task 6 fixes that; do not add a compatibility shim.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/level_banner.dart test/presentation/widgets/level_banner_test.dart
git commit -m "feat: add LevelBanner, a pinned collapsible level display

Replaces LevelBreakdownCard, which is no longer a card in the scroll. The
screen is wired up in the next commit and does not build in between."
```

---

### Task 6: Wire up the screen

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart:17`, `:80-83`, `:85-90`, `:277-296`, `:307-315`, `:339-389`
- Test: `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: `LevelBanner` (Task 5); `state.levelUnavailableReason` (Task 3).
- Produces: no new interface; this is the last consumer.

- [ ] **Step 1: Write the failing tests**

In `test/presentation/screens/spell_creation_screen_test.dart`:

Rewrite the test at `:220` (`renders the level breakdown when status is calculated`) — its name and its premise are both wrong now:

```dart
  testWidgets('renders the level with no calculation, and its detail on demand',
      (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
      ),
      breakdown: const LevelBreakdown(
        level: 20,
        rawLevel: 20,
        contributions: [
          LevelContribution(label: 'Base effect · Create flame', magnitude: 10, isBase: true),
          LevelContribution(label: 'Range · Voice', magnitude: 2),
        ],
      ),
    );
    await pumpScreen(tester, state);

    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.text('20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Range · Voice'), findsOneWidget);
  });
```

Replace the test at `:244` (`does not render the calculated-level card before calculation`) — it asserts the defect:

```dart
  testWidgets('renders the level placeholder before anything is chosen', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.initial,
      draft: SpellDraft(),
      levelUnavailableReason: 'Choose a base effect to see a level.',
    );
    await pumpScreen(tester, state);

    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.text('Choose a base effect to see a level.'), findsOneWidget);
  });
```

Add these:

```dart
  testWidgets('Discard is reachable before any button press', (tester) async {
    // The escape hatch that did not exist: Discard rendered only inside the
    // results block, so before the first Calculate there was no way to
    // abandon a draft at all.
    await pumpScreen(tester, SpellCreationState.initial());

    await tester.tap(find.byKey(const Key('discard-button')));
    await tester.pump();

    verify(() => bloc.add(const SpellDiscarded())).called(1);
  });

  testWidgets('Save is offered before any button press, but disabled with no level',
      (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());

    final saveButton = tester.widget<ElevatedButton>(find.byKey(const Key('save-button')));
    expect(saveButton.onPressed, isNull,
        reason: 'no level means nothing saveable, and the banner already says why');
  });

  testWidgets('Save is enabled once there is a level', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
      ),
      breakdown: const LevelBreakdown(level: 20, rawLevel: 20, contributions: []),
    );
    await pumpScreen(tester, state);

    final saveButton = tester.widget<ElevatedButton>(find.byKey(const Key('save-button')));
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('suggestions stay behind the button', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
      ),
      breakdown: const LevelBreakdown(level: 20, rawLevel: 20, contributions: []),
    );
    await pumpScreen(tester, state);

    expect(find.text('Similar Spells'), findsNothing,
        reason: 'the level is live but findSimilarSpells is the expensive half');
    expect(find.text('Find Similar Spells'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: FAIL to compile — the screen still imports the deleted `level_breakdown_card.dart`.

- [ ] **Step 3: Swap the import**

In `lib/presentation/screens/spell_creation_screen.dart:17`, replace:

```dart
import 'package:eruditus/presentation/widgets/level_breakdown_card.dart';
```

with:

```dart
import 'package:eruditus/presentation/widgets/level_banner.dart';
```

- [ ] **Step 4: Rename the gate and restructure the body**

Replace `:80-83` with:

```dart
          final isSaving = state.status == SpellCreationStatus.saving;
          // Narrowed from the old showResultsBlock, which gated the level card
          // and the Save/Discard row too. Only the suggestions are still worth
          // a button (findSimilarSpells plus a calculateBreakdown per
          // candidate); the level is a pure function of the draft and is now
          // always on screen. An edit still clears the list, which stays
          // right -- suggestions computed against a superseded level should
          // not linger.
          final showSuggestions = state.status == SpellCreationStatus.calculated ||
              isSaving ||
              state.status == SpellCreationStatus.error;
```

Replace the `body: ListView(` opening at `:87` so the banner sits outside the scroll:

```dart
            body: Column(
              children: [
                LevelBanner(
                  breakdown: state.breakdown,
                  unavailableReason: state.levelUnavailableReason,
                ),
                Expanded(
                  child: ListView(
                    key: const Key('spell-creation-scroll'),
                    padding: const EdgeInsets.all(16),
                    children: [
```

and close it correspondingly at the end of the children list (`:390-391`), adding the two extra closing brackets the `Expanded`/`Column` need. Indentation of the whole list shifts; let `dart format` sort it out rather than reindenting by hand.

- [ ] **Step 5: Ungate the level, the ritual banner, and the Save/Discard row**

Delete the inline card at `:307-308`:

```dart
                if (showResultsBlock && state.breakdown != null)
                  LevelBreakdownCard(breakdown: state.breakdown!),
```

Replace the `RitualSection`'s `ritualStatus:` argument and the comment above it (`:277-286`) with:

```dart
                RitualSection(
                  // Ungated, unlike before: this used to be forced to
                  // notRitual outside the results block because state.breakdown
                  // was a snapshot carried forward across edits, so the banner
                  // could keep showing a reason computed for a draft the user
                  // had since changed. The breakdown is recomputed on every
                  // emit now, so there is no stale value left to guard against.
                  ritualStatus: state.breakdown?.ritualStatus ?? const RitualStatus.notRitual(),
```

Relabel the button at `:313`:

```dart
                  child: const Text('Find Similar Spells'),
```

Then change `if (showResultsBlock) ...[` at `:315` to `if (showSuggestions) ...[`, and **move the Save/Discard `Row` (`:348-388`) out of that block**, to sit after it as an unconditional child, preceded by `const SizedBox(height: 16)`. Leave the suggestions heading, the suggestion cards and the error text inside. Change the Save button's `onPressed` guard from `isSaving ? null : ...` to:

```dart
                          onPressed: isSaving || state.breakdown == null
                              ? null
                              : () async {
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: PASS.

Two failure modes to expect while iterating. Tests that scroll via `screenScrollable` still work — the ListView keeps its `spell-creation-scroll` key. Tests asserting a `find.text` that now lives in the collapsed banner detail need a `level-banner-toggle` tap first, exactly as Step 1's rewritten test does.

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: PASS, including `test/widget_test.dart` and any integration test that drives this screen. An integration test that pressed Calculate before asserting on the level will now find it already there — if it asserts the level is *absent* first, that assertion encodes the old defect and should be deleted rather than worked around.

- [ ] **Step 8: Format and commit**

```bash
dart format lib/presentation/screens/spell_creation_screen.dart
git add lib/presentation/screens/spell_creation_screen.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: pin the live level banner and ungate Save/Discard

The button keeps only the suggestions it is expensive enough to deserve.
Discard is reachable before the first press for the first time."
```

---

### Task 7: Run the app, then close the todo items

**Files:**
- Modify: `.superpowers/todo.md` (item 59 at `:700-741`, item 58's first bullet at `:834-844`)

- [ ] **Step 1: Run the app and confirm the behaviour by hand**

Use the `run` skill. Then, in the Create tab, without pressing any button:

1. On arrival the banner reads `Spell level —` with "Choose a base effect to see a level."
2. Pick Technique **Creo**, Form **Ignem**, then a base effect — the number appears immediately.
3. Change Range, then Duration — the number moves each time, and never blinks out.
4. Type in Summary — the number does not move and does not disappear (item 58's bullet).
5. Tap the chevron — the contributions appear; tap again — they collapse.
6. Tap **Discard** without ever having pressed the suggestions button — the form resets.
7. Pick a General guideline and clear its level — the banner reads "Type a level for this General guideline." rather than throwing.

- [ ] **Step 2: Close item 59**

In `.superpowers/todo.md`, replace the body of `### 59. The Level Should Compute Live, Not Behind a Button` with:

```markdown
**✅ COMPLETE 2026-08-17** — see `## Completed ✅`.
```

and add this entry under `## Completed ✅`, above item 60's, substituting the real commit hash of Task 6:

```markdown
### 59. The Spell Level Computes Live (`<hash>`)
The level existed only after pressing **Calculate & View Suggestions**, and
every later edit emitted `status: editing`, which hid it again — so the number
a caster designs towards was absent exactly while they were designing. One
button gated three unrelated things; they are now separated.

- **Every emit in `SpellCreationBloc` goes through one `_emit` funnel** that
  attaches `SpellEngine.previewLevel(draft)`. No handler can emit a state whose
  breakdown disagrees with its own draft, which is why this closed item 58's
  first bullet as a consequence rather than a patch — a level no edit can hide
  cannot be hidden by `ContainerModeSelected` or `SummaryChanged` either.
- **`previewLevel` is not validation, deliberately.** It answers "is there a
  number", returning either a breakdown or one of four reasons; both of
  `calculateBreakdown`'s reachable throws (a General guideline before its level
  is typed, magnitudes below level 1) become reasons rather than escaping.
  `validateSpellDraft` still owns the catalog invariants and still fires only on
  the two button presses, because its messages render as red text and firing
  them per keystroke would flag a half-built draft as broken.
- **`LevelBreakdown`, `LevelContribution` and `RitualStatus` gained value
  equality.** The funnel mints a new breakdown per emit and `breakdown` is in
  `SpellCreationState.props`, so identity comparison would make every state look
  changed. Two bloc tests that asserted `same(...)` now assert equality.
- **The button became "Find Similar Spells"** and gates only the suggestions —
  `findSimilarSpells` plus a `calculateBreakdown` per candidate is the half
  expensive enough to deserve one.
- **Save and Discard render unconditionally.** Discard was previously
  unreachable before the first Calculate, leaving no way to abandon a draft at
  all. Save is disabled while there is no level, and
  `_handleSpellSaveRequested` validates first — the affordance is not the gate.
- **`LevelBreakdownCard` became `LevelBanner`**, pinned above the scroll in a
  `Column` (above the ListView, so the keyboard cannot cover it), collapsed by
  default, showing an em dash plus a reason when there is no level.
```

- [ ] **Step 3: Close item 58's first bullet**

Change its checkbox from `- [ ]` to `- [x]` and append to it:

```markdown
      **✅ DONE 2026-08-17 via item 59.** The emit funnel recomputes the level
      on every event, so no edit can hide it — including these two. Both
      events' tests now assert the recomputed breakdown compares *equal*
      (they previously asserted `same`, which encoded the old contract).
```

- [ ] **Step 4: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close todo item 59 and item 58's first bullet"
```

---

## Self-Review Notes

Checked against `docs/superpowers/specs/2026-08-17-live-spell-level-design.md`:

- **Decision 1** (`previewLevel`, four reasons, not validation) → Task 2, one test per reason plus ordering.
- **Decision 2** (`_emit` funnel, `_initialState`, `state.breakdown!.level`, save guard, state field changes) → Tasks 3 and 4.
- **Decision 3** (pinned collapsible banner, keys, 40% cap, chevron only with a breakdown) → Task 5.
- **Decision 4** (`showSuggestions`, relabel, ungated Save/Discard, live `RitualSection`, errors unchanged) → Task 6.
- **Testing section** → distributed across Tasks 1–6; the three churn categories are Task 3 Step 4, Task 4 Step 2, and Task 6 Step 1.

**One addition the spec did not anticipate:** Task 1 exists because `LevelBreakdown`, `LevelContribution` and `RitualStatus` compare by identity while `breakdown` sits in `SpellCreationState.props`. The funnel mints a new breakdown per emit, so without value equality no two states would ever compare equal — every event would emit, and `bloc_test` expectations could not match. Two existing tests (`SummaryChanged`, `ContainerModeSelected`) assert `same(...)` on the breakdown and are rewritten in Task 4 Step 2; they encode the contract this work inverts.

**Ordering note:** Task 5 deletes `level_breakdown_card.dart` while the screen still imports it, so the tree does not build between Tasks 5 and 6. That is deliberate — a compatibility shim for a one-call-site widget would be dead code the moment Task 6 landed. Both commits are on the same branch and land together.
