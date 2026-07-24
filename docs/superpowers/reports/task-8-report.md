# Task 8: SpellCreationBloc — Report

**Status: DONE**

## What was implemented

Following TDD as directed by the task brief (`.superpowers/sdd/task-8-brief.md`):

1. Added the `bloc_test: ^9.1.7` dev dependency to `pubspec.yaml` and ran `flutter pub get`.
2. Wrote the failing test `test/models/spell_draft_copy_with_test.dart` exactly as specified, ran it, and confirmed it failed to compile (`The method 'copyWith' isn't defined for the type 'SpellDraft'`).
3. Added `SpellDraft.copyWith` to `lib/models/spell.dart` (after `toSpell`), exactly as specified in the brief. Reran the test — passed.
4. Created `lib/bloc/spell_creation/spell_creation_event.dart` and `lib/bloc/spell_creation/spell_creation_state.dart` exactly as specified (the single-state-class design with a `SpellCreationStatus` enum, per the documented deviation from the original design spec).
5. Wrote the failing test `test/bloc/spell_creation_bloc_test.dart` exactly as specified, ran it, and confirmed it failed to compile (`SpellCreationBloc` did not exist).
6. Implemented `lib/bloc/spell_creation/spell_creation_bloc.dart` exactly as specified in the brief.
7. Reran the bloc test suite — 4 of 5 tests passed immediately; the `SpellSaveRequested saves the spell and emits saving then saved` test failed deterministically (reproduced 3/3 runs, not flaky). See "Deviation from brief" below for the root cause and fix.
8. Ran the full project test suite (`flutter test`) — all 78 tests passed, no regressions.
9. Ran `flutter analyze` on all new/modified files — no issues found.
10. Committed only the files this task specifies (`pubspec.yaml`, `pubspec.lock`, `lib/models/spell.dart`, `lib/bloc/spell_creation/`, the two new test files). Two unrelated untracked items already in the working tree (`.claude/` and `docs/superpowers/reports/task-7-report.md`) were left untouched per instructions.

## Deviation from brief: added `wait:` to one blocTest

The brief's `SpellSaveRequested` test (as given, with no `wait:` parameter) failed deterministically with only the `saving` state captured — the `saved` state never appeared, and no exception was thrown or logged.

Root cause, confirmed by reading `bloc_test`'s and `bloc`'s source (`bloc_test-9.1.7/lib/src/bloc_test.dart`, `bloc-8.1.4/lib/src/bloc.dart`, `emitter.dart`):
- `testBloc` (the engine behind `blocTest`) only waits `wait ?? Duration.zero` after `act` returns before calling `bloc.close()`.
- `Bloc.close()` calls `emitter.cancel()` on every still-pending emitter, and `_Emitter.cancel()` immediately sets `_isCanceled = true` and completes the emitter's internal completer **without waiting for the handler's `Future` (the actual `async` function body) to finish**.
- Once `_isCanceled` is true, any subsequent `emit(...)` call from the still-running handler is silently dropped (`if (!_isCanceled) _emit(state)` in `emitter.dart`).
- The real `sqflite_common_ffi` write inside `spellRepository.saveSpell(spell)` takes longer than the single `Duration.zero` tick `testBloc` waits by default, so `close()` cancels the emitter mid-flight and the second `emit(saved)` call is dropped without any error surfacing.

This is a known, documented use of `bloc_test`'s `wait:` parameter ("can be used to wait for async operations within the bloc under test"), not a bug in the bloc implementation. I added `wait: const Duration(milliseconds: 300)` to that one `blocTest` call in `test/bloc/spell_creation_bloc_test.dart`. Reran the full bloc test file 3 times after the change — all 5 tests passed every time (previously the failure was 3/3 reproducible, so this is not paper over flakiness — it fixes a structural timing gap in the test as originally specified).

No production code (`spell_creation_bloc.dart`) needed to change for this — the bug was in the test's missing `wait:`, not in the bloc's event handling logic.

## Test commands and output

### Step 3: confirm `copyWith` test fails before implementation

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test test/models/spell_draft_copy_with_test.dart -v
```

Relevant output:
```
test/models/spell_draft_copy_with_test.dart:13:27: Error: The method 'copyWith' isn't defined for the type 'SpellDraft'.
      final updated = draft.copyWith(form: 'Corpus');
                            ^^^^^^^^
00:00 +0 -1: Some tests failed.
```

### Step 5: confirm `copyWith` test passes after implementation

```
flutter test test/models/spell_draft_copy_with_test.dart -v
```
```
00:00 +0: SpellDraft.copyWith preserves id and unspecified fields, overrides given ones
00:01 +1: All tests passed!
```

### Step 7: confirm bloc test fails before implementation

```
flutter test test/bloc/spell_creation_bloc_test.dart -v
```

Compilation error (no `SpellCreationBloc` class), exit code 1, as expected.

### Step 9: bloc tests after implementation (first run, before the `wait:` fix)

```
flutter test test/bloc/spell_creation_bloc_test.dart test/models/spell_draft_copy_with_test.dart -v
```

Relevant output — 4 states expected, only 1 captured:
```
00:00 +3 -1: SpellSaveRequested saves the spell and emits saving then saved [E]
  Expected: [ ... saving ..., ... saved with savedSpell.name: 'My Fireball' ... ]
    Actual: [ SpellCreationState(SpellCreationStatus.saving, ...) ]
     Which: at location [1] is [...] which shorter than expected
00:00 +4 -1: Some tests failed.
```
Reproduced identically 3/3 runs (not flaky) — root-caused and fixed as described above by adding `wait: const Duration(milliseconds: 300)` to that blocTest.

### Final run: all bloc + copyWith tests, after the `wait:` fix

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test test/bloc/spell_creation_bloc_test.dart test/models/spell_draft_copy_with_test.dart
```

Output:
```
00:00 +0: loading C:/Users/idf53/Development/personal/arsm/eruditus/test/bloc/spell_creation_bloc_test.dart
00:00 +0: C:/.../spell_creation_bloc_test.dart: (setUpAll)
00:00 +0: C:/.../spell_creation_bloc_test.dart: emits editing state with technique set when TechniqueSelected is added
00:00 +1: C:/.../spell_creation_bloc_test.dart: SpellCalculated emits validation errors when draft is incomplete
00:00 +2: C:/.../spell_creation_bloc_test.dart: SpellCalculated emits calculated level and no errors when draft is valid
00:00 +3: C:/.../spell_creation_bloc_test.dart: SpellSaveRequested saves the spell and emits saving then saved
00:00 +4: C:/.../spell_creation_bloc_test.dart: SpellSaveRequested saves the spell and emits saving then saved
00:00 +5: C:/.../spell_creation_bloc_test.dart: SpellDiscarded resets to a fresh initial state
00:00 +6: C:/.../spell_creation_bloc_test.dart: (tearDownAll)
00:01 +6: All tests passed!
```
(6 tests total: 1 copyWith + 5 bloc tests — matches the brief's expected count.) Reran this same command 3 times in a row; all 3 runs passed with no flakiness.

### Full suite regression check

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test
```

Tail of output:
```
00:07 +76: C:/.../test/models/spell_test.dart: Spell Model SpellDraft.toSpell throws StateError naming all missing fields
00:07 +77: C:/.../test/widget_test.dart: Counter increments smoke test
00:09 +78: All tests passed!
```

All 78 tests in the project pass (previous 72 from Tasks 1-7 plus 6 new tests for this task).

### Static analysis

```
flutter analyze lib/bloc lib/models/spell.dart test/bloc test/models/spell_draft_copy_with_test.dart
```
```
Analyzing 4 items...
No issues found! (ran in 69.7s)
```

## Concerns

- The one deviation from the brief's exact test code (adding `wait: const Duration(milliseconds: 300)` to the `SpellSaveRequested` blocTest) is a fix for a structural timing gap in the brief's original test, not a shortcut — see "Deviation from brief" above for the full root-cause analysis. No production code changed as a result.
- Everything else — `SpellDraft.copyWith`, the event/state files, and the bloc implementation itself — matches the brief verbatim; all consumed interfaces (`SpellEngine.validateSpellDraft`/`calculateSpellLevel`/`findSimilarSpells`, `SpellRepository.saveSpell`/`getAllUserSpells`, and the Task 1 models) matched exactly what the brief assumed, with no discrepancies.

## Files changed

- `lib/models/spell.dart` (modified — added `SpellDraft.copyWith`)
- `lib/bloc/spell_creation/spell_creation_event.dart` (new)
- `lib/bloc/spell_creation/spell_creation_state.dart` (new)
- `lib/bloc/spell_creation/spell_creation_bloc.dart` (new)
- `test/models/spell_draft_copy_with_test.dart` (new)
- `test/bloc/spell_creation_bloc_test.dart` (new)
- `pubspec.yaml` / `pubspec.lock` (modified — added `bloc_test` dev dependency)

## Commit

`bf72cf1b155d8a2420ad84b416e113b04dd9658f` — "feat: add SpellCreationBloc and SpellDraft.copyWith"
