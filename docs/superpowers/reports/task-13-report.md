# Task 13 Implementation Report: Configuration Screen and App Wiring (main.dart)

**Status: DONE**

## What was implemented

Followed TDD exactly per `.superpowers/sdd/task-13-brief.md`:

1. **`test/presentation/screens/configuration_screen_test.dart`** (new) — 3 widget tests using
   `mocktail`'s `MockBloc`/`whenListen` against `MockConfigurationBloc` (never a real `Bloc`):
   - tabs render (Effects / Parameters / Special Factors)
   - custom effects from state render in the list
   - filling and confirming the add-effect dialog dispatches `CustomEffectAdded` with the
     entered values, verified via `isA<CustomEffectAdded>().having(...)` matchers (not exact
     object equality, since `BaseEffect` has no value equality and the dialog generates a
     fresh `id`).
   - Ran first to confirm it failed (`ConfigurationScreen` class not found) before implementing.

2. **`lib/presentation/screens/configuration_screen.dart`** (new) — `ConfigurationScreen`
   (`StatefulWidget`, dispatches `ConfigurationRequested` on mount) with a 3-tab
   `DefaultTabController`/`TabBar`/`TabBarView` for Effects, Parameters, and Special Factors.
   Each tab lists built-in entries (read-only, labeled "Built-in") and custom entries
   (`source == 'user-created'`, with a delete `IconButton`), plus a `FloatingActionButton`
   that opens an add-dialog (`_AddEffectDialog`, `_AddParameterDialog`, `_AddFactorDialog`)
   with technique/form dropdowns (from `ArsArts.all`/`ArsForms.all`), text fields, and
   validation before dispatching the corresponding `*Added` event.

3. **`lib/main.dart`** (rewritten) — replaced the default Flutter counter-app template.
   `main()` now opens `AppDatabase`, constructs `AssetDataLoader`, `SpellRepository`,
   `LibraryRepository`, `ConfigurationRepository`, loads all spells/effects/parameters/
   factors, builds `SpellEngine`, and constructs the three real blocs
   (`SpellCreationBloc`, `SpellLibraryBloc`, `ConfigurationBloc`), passing them into
   `EruditusApp`. `EruditusApp` is a `StatelessWidget` that takes **pre-built blocs via
   constructor injection** and wires them with `MultiBlocProvider` + `BlocProvider.value`
   (not `create:` callbacks) — this is the deliberate DI seam from the brief that keeps
   `EruditusApp` testable with mock blocs. `_MainTabView` shows Create/Library/Settings
   tabs via `IndexedStack` + `BottomNavigationBar` (Backup tab deferred to Task 14).

4. **`test/widget_test.dart`** (rewritten) — replaced the stale counter-app smoke test.
   Now injects `MockSpellCreationBloc`, `MockSpellLibraryBloc`, `MockConfigurationBloc`
   (all via `mocktail`'s `MockBloc`/`whenListen`) directly into `EruditusApp`'s constructor,
   confirming the Create tab renders by default and all three bottom-nav labels
   (Create/Library/Settings) are present. Removed one unused `flutter/material.dart` import
   that `flutter analyze` flagged (the brief's literal listing included it, but nothing in
   the file references `Material`/`MaterialApp` directly since `EruditusApp` builds that
   itself) — purely a cleanup, no behavior change.

No hangs were encountered at any point; every widget test used mock blocs exactly per the
brief's pattern, so the Task-11-era real-bloc-under-`flutter_tester` hang never triggered.

## Test commands and output

Ran with Flutter's PATH exported first:
```bash
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
```

### Step 2 — confirm failing test before implementation
```
flutter test test/presentation/screens/configuration_screen_test.dart
```
```
00:00 +0: loading .../configuration_screen_test.dart
test/presentation/screens/configuration_screen_test.dart:11:8: Error: Error when reading
'lib/presentation/screens/configuration_screen.dart': The system cannot find the file specified
...
00:00 +0 -1: loading .../configuration_screen_test.dart [E]
  Failed to load ...
00:00 +0 -1: Some tests failed.
```
Confirmed FAIL as expected (no `ConfigurationScreen` class yet).

### Step 4 — after implementing `ConfigurationScreen`
```
flutter test test/presentation/screens/configuration_screen_test.dart
```
```
00:00 +0: loading .../configuration_screen_test.dart
00:00 +0: (setUpAll)
00:00 +0: shows Effects, Parameters, Special Factors tabs
00:00 +1: renders custom effects present in state
00:00 +2: filling the add-effect dialog dispatches CustomEffectAdded with the entered values
00:01 +3: (tearDownAll)
00:01 +3: All tests passed!
```

### `test/widget_test.dart` alone (checked for hangs before the full run)
```
flutter test test/widget_test.dart
```
```
00:00 +0: loading .../test/widget_test.dart
00:00 +0: (setUpAll)
00:00 +0: EruditusApp launches showing the Create tab and bottom navigation
00:00 +1: (tearDownAll)
00:00 +1: All tests passed!
```

### Step 7 — full suite, run 4 times total (2 before the unused-import cleanup, 2 after) to
rule out flakiness
```
flutter test
```
Run 1: `00:08 +110: All tests passed!` (exit 0)
Run 2: `00:08 +110: All tests passed!` (exit 0)
(then removed the unused `flutter/material.dart` import from `test/widget_test.dart`)
Run 3: `00:08 +110: All tests passed!` (exit 0)
Run 4 (post-cleanup verification): `00:09 +110: All tests passed!` (exit 0)

All 110 tests across the whole suite pass consistently, no flakiness, no hangs.

### `flutter analyze`
```
flutter analyze
```
```
Analyzing eruditus...
   info - 'groupValue' is deprecated ... lib\presentation\screens\spell_library_screen.dart:51:23
   info - 'onChanged' is deprecated ... lib\presentation\screens\spell_library_screen.dart:52:23
2 issues found.
```
Both are pre-existing infos in a file this task didn't touch (`spell_library_screen.dart`,
from Task 12). No new warnings/errors from this task's files.

## Concerns

None. The implementation follows the brief's exact code for `ConfigurationScreen`, `main.dart`,
and both test files, with only one trivial cleanup (removing an unused import from
`test/widget_test.dart` that `flutter analyze` flagged — no functional change). Field names,
constructor signatures, and repository/bloc APIs referenced in `main.dart` were all verified
against the actual Task 1-12 source before writing, and matched the brief exactly.

Genuine end-to-end verification with real data flowing through the real stack (real blocs,
real SQLite, real assets) is explicitly deferred to Task 15 via `integration_test`, since
that's the only place a real bloc's pipeline works in this environment (a real device/emulator,
not `flutter_tester`).

## Commit

`3fd0786` — "feat: add ConfigurationScreen and wire up the full app in main.dart"

Files committed (exactly as specified in the brief's Step 8, nothing else):
- `lib/presentation/screens/configuration_screen.dart` (new)
- `lib/main.dart` (modified)
- `test/widget_test.dart` (modified)
- `test/presentation/screens/configuration_screen_test.dart` (new)

The pre-existing untracked `.claude/` directory was left alone, as instructed (not part of
this task).
