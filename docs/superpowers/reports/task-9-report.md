# Task 9: SpellLibraryBloc — Report

**Status: DONE**

## What was implemented

Following TDD as directed by the task brief (`.superpowers/sdd/task-9-brief.md`):

1. Wrote the failing test `test/bloc/spell_library_bloc_test.dart` exactly as specified (three `blocTest`s: load all spells, filter to "My Spells", search by query), ran it, and confirmed it failed to compile (`SpellLibraryBloc` did not exist — `The method 'add' isn't defined for the type 'Object?'` etc.).
2. Created `lib/bloc/spell_library/spell_library_event.dart` and `lib/bloc/spell_library/spell_library_state.dart` exactly as specified in the brief (single-state-class design with a `SpellLibraryStatus` enum and a `visibleSpells` getter that applies `filter` then `query` to `allSpells`).
3. Implemented `lib/bloc/spell_library/spell_library_bloc.dart` — initially exactly as specified in the brief (three separate `on<LibraryRequested>`/`on<SearchQueryChanged>`/`on<FilterChanged>` handlers), then reran the tests. This surfaced a genuine, deterministic race condition (see "Deviation from brief" below) that required changing the bloc's internal event-dispatch structure — not just adding a `wait:` — to make the tests pass correctly.
4. Ran the full project test suite (`flutter test`) — all 81 tests passed, no regressions.
5. Ran `flutter analyze` on the new bloc files and the new test file — no issues found.
6. Reran `test/bloc/spell_library_bloc_test.dart` 4 times total (1 initial + 3 repeats) after the fix — passed every time, confirming stability.
7. Committed only the files this task specifies (`lib/bloc/spell_library/`, `test/bloc/spell_library_bloc_test.dart`). Pre-existing untracked items in the working tree (`.claude/`, `docs/superpowers/reports/task-7-report.md`, `docs/superpowers/reports/task-8-report.md`) were left untouched per instructions.

## Deviation from brief: sequential event dispatch (not just `wait:`)

The brief's exact bloc code (three independent `on<E>()` registrations) plus `wait: const Duration(milliseconds: 300)` on the affected `blocTest`s still failed the `FilterChanged to "My Spells"` test deterministically (reproduced consistently, not flaky). The failure was a content mismatch, not a "too few states captured" shortness — i.e. a different class of problem than the `wait:` issue the task's note anticipated.

Root cause, confirmed by reading `bloc-8.1.4/lib/src/bloc.dart`:
- flutter_bloc's `on<E>(handler, transformer)` registers **one independent stream subscription per event type**, each filtered from the same underlying broadcast event controller.
- The package's default `EventTransformer` doc comment says explicitly: *"By default all events are processed concurrently."* This concurrency is across different event types, not just repeats of the same type.
- In the test, `bloc.add(const LibraryRequested())` is followed immediately (no `await`) by `bloc.add(const FilterChanged('My Spells'))`. `LibraryRequested`'s handler is `async` and suspends at `await libraryRepository.getAllSpells()` (a real asset-load + DB query). Because `FilterChanged`'s handler is registered as an independent, fully synchronous subscription, it runs to completion and emits **before** `LibraryRequested`'s awaited call resolves.
- This produced an extra, unanticipated intermediate state — `(loading, allSpells: [], filter: 'My Spells')` — instead of the brief's expected sequence of `(loaded, filter: 'All', 28 spells)` then `(loaded, filter: 'My Spells', 1 spell)`. Adding `wait:` only affects how long `testBloc` waits before tearing the bloc down after `act` — it cannot reorder handlers that are racing on different subscriptions.

Fix: restructured `lib/bloc/spell_library/spell_library_bloc.dart` to register a **single** `on<SpellLibraryEvent>` handler (on the abstract base event type, so it matches every subclass) with an inline sequential transformer (`(events, mapper) => events.asyncExpand(mapper)` — the same technique the `bloc_concurrency` package's `sequential()` uses, added here without a new dependency), dispatching internally via `if (event is ...)`. This guarantees all events — regardless of type — are processed strictly in arrival order: `FilterChanged` now genuinely waits for `LibraryRequested`'s in-flight load to finish before it runs. This also reflects more correct real-world UI behavior (a filter tap during a load shouldn't produce a state that silently drops back to an unfiltered list once the load resolves).

The event/state files (`spell_library_event.dart`, `spell_library_state.dart`) and the test file match the brief verbatim (including the two `wait: const Duration(milliseconds: 300)` additions needed for the real async I/O, per the task's documented allowance). Only the bloc's internal dispatch mechanism differs from the brief's literal code, and the public API (`SpellLibraryBloc({required libraryRepository})`, events, state shape) is unchanged.

## Test commands and output

### Confirm test fails before implementation

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test test/bloc/spell_library_bloc_test.dart -v
```

Relevant output:
```
test/bloc/spell_library_bloc_test.dart:82:12: Error: The method 'add' isn't defined for the type 'Object?'.
      bloc.add(const LibraryRequested());
           ^^^
00:00 +0 -1: Some tests failed.
```

### First implementation attempt (brief's code verbatim, no `wait:`)

```
flutter test test/bloc/spell_library_bloc_test.dart -v
```
All 3 tests failed — states captured were too short (matches the documented Task 8-style timing gap).

### After adding `wait: const Duration(milliseconds: 300)` to all three blocTests

```
flutter test test/bloc/spell_library_bloc_test.dart -v
```
2 of 3 passed; `FilterChanged to "My Spells"` still failed, this time with a content mismatch (not shortness):
```
Actual: [
  SpellLibraryState(SpellLibraryStatus.loading, [], , My Spells, null),
  SpellLibraryState(SpellLibraryStatus.loaded, [...28 spells...], , My Spells, null)
]
Which: at location [0] ... has `status` with value SpellLibraryStatus.loading
```
This confirmed the race described above (filter applied before the load's `loaded` state was ever emitted with the default filter).

### After restructuring the bloc to sequential single-handler dispatch

```
flutter test test/bloc/spell_library_bloc_test.dart -v
```
Output:
```
00:00 +0: loading C:/Users/idf53/Development/personal/arsm/eruditus/test/bloc/spell_library_bloc_test.dart
00:00 +0: (setUpAll)
00:00 +0: LibraryRequested loads all spells (27 built-in + 1 user)
00:00 +1: FilterChanged to "My Spells" narrows visibleSpells to user-created only
00:00 +2: SearchQueryChanged narrows visibleSpells by name, case-insensitively
00:01 +3: (tearDownAll)
00:01 +3: All tests passed!
```

Reran this same command 3 additional times (4 runs total) — passed every time, no flakiness.

### Full suite regression check

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test
```

Tail of output:
```
00:12 +79: C:/.../test/models/spell_test.dart: Spell Model SpellDraft.toSpell throws StateError naming all missing fields
00:13 +80: C:/.../test/widget_test.dart: Counter increments smoke test
00:14 +81: All tests passed!
```

All 81 tests in the project pass (78 from Tasks 1-8 plus 3 new tests for this task).

### Static analysis

```
flutter analyze lib/bloc/spell_library test/bloc/spell_library_bloc_test.dart
```
```
Analyzing 2 items...
No issues found! (ran in 3.7s)
```

## Concerns

- The bloc's internal dispatch structure (single `on<SpellLibraryEvent>` handler with a manual sequential transformer) differs from the brief's literal code. This was necessary because the brief's code, as given, has a genuine deterministic race — not something a `wait:` tweak on the test side could fix — when run against the real `LibraryRepository` (real asset loading + SQLite I/O) rather than a synchronous fake. The public API, event/state classes, and test file all match the brief verbatim.
- No new package dependency was introduced; the sequential-processing technique (`events.asyncExpand(mapper)`) is the same one used internally by the `bloc_concurrency` package's `sequential()`, written inline.
- Given this same "separate `on<E>()` per event type races under real I/O" pattern could also latently affect other blocs in this codebase (e.g. `SpellCreationBloc` from Task 8) if a future test or UI interaction adds a synchronous event immediately after an async one without awaiting, it may be worth a follow-up look — flagging as a low-priority note, not blocking this task.

## Files changed

- `lib/bloc/spell_library/spell_library_event.dart` (new)
- `lib/bloc/spell_library/spell_library_state.dart` (new)
- `lib/bloc/spell_library/spell_library_bloc.dart` (new)
- `test/bloc/spell_library_bloc_test.dart` (new)

## Commit

`48d5930` — "feat: add SpellLibraryBloc for browsing and filtering the spell library"
