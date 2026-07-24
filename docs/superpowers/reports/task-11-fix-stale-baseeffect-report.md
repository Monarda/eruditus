# Task 11 Fix: Stale `baseEffect` Not Cleared on Technique/Form Change — Report

**Status: DONE**

## Background

Task 11's code review of Task 8's `SpellCreationBloc` (already approved) surfaced a real, confirmed bug: `TechniqueSelected` and `FormSelected` handlers updated `draft.technique` / `draft.form` but never cleared `draft.baseEffect`. Sequence to reproduce: select Technique=Creo, Form=Ignem, pick a `BaseEffect` valid for Creo+Ignem, then change Form to Corpus. `SpellCreationScreen`'s `effectsForSelection` filter recomputes to Corpus-valid effects, which no longer include the stale Ignem-based `BaseEffect` object — but `draft.baseEffect` still holds it, and passing it as `initialValue` to a `DropdownButtonFormField<BaseEffect>` whose `items` no longer contain a matching value trips Flutter's assertion that `initialValue` must be null or match an item by `==`. This is a genuine crash, not just a test gap.

The complication: `SpellDraft.copyWith`'s existing pattern (`field ?? this.field`) cannot distinguish "argument omitted" from "argument explicitly passed `null`" — both fall through to the `??` fallback and keep the old value. This limitation had already been logged as a Minor finding in Task 8's review, predicting exactly this future need.

## What changed

1. **`lib/models/spell.dart`** — `SpellDraft.copyWith` now uses a private `_Unset` sentinel (`const _unset = _Unset();`) as the default value for the `baseEffect` parameter (typed `Object?` to accept either the sentinel or a real `BaseEffect?`). Omitting `baseEffect` keeps the current value (`identical(baseEffect, _unset)` is true); passing `baseEffect: null` explicitly now clears it to `null`; passing a real `BaseEffect` sets it. All other fields are untouched (no scope creep — YAGNI per the task brief).

2. **`lib/bloc/spell_creation/spell_creation_bloc.dart`** — `TechniqueSelected` and `FormSelected` handlers now pass `baseEffect: null` explicitly alongside the technique/form update, so a previously selected effect that's likely invalid for the new technique/form is cleared:
   ```dart
   draft: state.draft.copyWith(technique: event.technique, baseEffect: null),
   draft: state.draft.copyWith(form: event.form, baseEffect: null),
   ```

3. **`test/models/spell_draft_copy_with_test.dart`** — added two tests:
   - `copyWith(baseEffect: null)` explicitly clears `baseEffect` to `null` from a draft that had a non-null effect.
   - `copyWith()` with no `baseEffect` argument preserves the existing `baseEffect` (regression test for the "omit means no change" contract).

4. **`test/bloc/spell_creation_bloc_test.dart`** — added two `blocTest`s: dispatching `TechniqueSelected` (respectively `FormSelected`) after a `BaseEffectSelected` has set a `baseEffect` results in a state where `draft.baseEffect` is `null` (while the new technique/form value is set correctly).

No other files were touched, and `copyWith` was not extended with similar sentinel support for other nullable fields (e.g. `description`) since the bug being fixed only concerns `baseEffect`.

## Process followed (TDD)

### Step 1-2: write failing tests, confirm they fail

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test test/models/spell_draft_copy_with_test.dart test/bloc/spell_creation_bloc_test.dart
```

Result (against pre-fix code): 3 failures, exactly as expected —
```
00:01 +1 -1: ...spell_draft_copy_with_test.dart: SpellDraft.copyWith(baseEffect: null) explicitly clears baseEffect to null [E]
  Expected: null
    Actual: <Instance of 'BaseEffect'>

00:01 +6 -2: ...spell_creation_bloc_test.dart: TechniqueSelected clears a previously selected baseEffect [E]
  Expected: [... `draft.baseEffect`: null ...]
    Actual: [... draft.baseEffect with value <Instance of 'BaseEffect'> ...]

00:01 +6 -3: ...spell_creation_bloc_test.dart: FormSelected clears a previously selected baseEffect [E]
  Expected: [... `draft.baseEffect`: null ...]
    Actual: [... draft.baseEffect with value <Instance of 'BaseEffect'> ...]

00:03 +7 -3: Some tests failed.
```
(The "omit preserves value" test passed even before the fix, since omitting a plain nullable parameter behaves the same as omitting a sentinel-defaulted one — it's a regression guard, not intended to fail pre-fix.)

### Step 3: implement the fix

Changes described above to `lib/models/spell.dart` and `lib/bloc/spell_creation/spell_creation_bloc.dart`.

### Step 4: confirm tests pass, then full-suite reruns

```
flutter test test/models/spell_draft_copy_with_test.dart test/bloc/spell_creation_bloc_test.dart
```
```
00:00 +2: ...spell_draft_copy_with_test.dart: (both new tests pass)
00:01 +7: ...spell_creation_bloc_test.dart: TechniqueSelected clears a previously selected baseEffect
00:02 +8: ...spell_creation_bloc_test.dart: FormSelected clears a previously selected baseEffect
00:03 +10: All tests passed!
```

Full suite, run 1:
```
flutter test
...
00:12 +95: All tests passed!
```

Full suite, run 2 (rerun for flakiness check):
```
flutter test
...
00:12 +95: All tests passed!
```

Full suite, run 3 (rerun for flakiness check):
```
flutter test
...
00:13 +95: All tests passed!
```

95 tests passed consistently across all 3 runs (the task brief's estimate of "91+ tests" — the suite has grown to 95 with other in-flight presentation-layer work already present in the working tree; all pass, no regressions, no flakiness observed).

## Commit

```
6617112 fix: clear stale baseEffect when technique/form changes
```

Files committed: `lib/models/spell.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart`, `test/models/spell_draft_copy_with_test.dart`, `test/bloc/spell_creation_bloc_test.dart` (4 files changed, 72 insertions, 4 deletions). No other files were staged or touched — unrelated pre-existing working-tree changes (`.claude/`, `pubspec.lock`/`pubspec.yaml`, `lib/presentation/`, `test/presentation/`) were left untouched.
