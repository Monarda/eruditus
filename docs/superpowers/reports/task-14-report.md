# Task 14 Implementation Report: Backup Service and Backup Screen (File-Based Export/Import)

**Status: DONE**

## What was implemented

Followed TDD exactly per `.superpowers/sdd/task-14-brief.md`, with two adaptations required by
this environment (details in "Concerns" below):

1. **`test/data/services/backup_service_test.dart`** (new) — 5 tests using a real in-memory
   SQLite database (`sqflite_common_ffi`), covering export (only user-created spells/config,
   with version + date), import (restoring spells and custom effects), idempotent re-import
   (no duplicate/throw on a second import of the same backup), and `FormatException` for
   malformed JSON and unsupported versions. Ran first to confirm it failed (`BackupService`
   class not found) before implementing.

2. **`lib/data/services/backup_service.dart`** (new) — `BackupService` with
   `exportToJson()`/`importFromJson()`/`BackupImportResult`, implemented exactly per the
   brief's given code: export gathers `getAllUserSpells()` plus `source == 'user-created'`
   custom effects/parameters/factors into a JSON envelope (`version`, `exportDate`, `spells`,
   `customEffects`, `customParameters`, `customFactors`); import is idempotent by checking
   `getSpellById`/`updateSpell` vs `saveSpell` for spells, and by calling
   `deleteCustomX(id)` immediately before `addCustomX(...)` for config entries (a no-op
   delete when the ID isn't present, since `DELETE WHERE id = ?` matching zero rows isn't an
   error).

3. **`test/presentation/screens/backup_screen_test.dart`** (new) — 3 widget tests: export
   button invokes the injected `exportJson` callback with the service's JSON and shows a
   success message; a cancelled import (`importJson` returns `null`) shows "Import
   cancelled."; malformed import content shows an "Import failed: ..." message. Ran first to
   confirm it failed (`BackupScreen` class not found) before implementing.

4. **`lib/presentation/screens/backup_screen.dart`** (new) — `BackupScreen`
   (`StatefulWidget`) implemented exactly per the brief's given code: takes `backupService`,
   `exportJson`, and `importJson` as constructor parameters (all file I/O injected, no direct
   dependency on `file_picker`/`dart:io`), with export/import buttons and a status message
   area.

5. **`lib/main.dart`** (modified) — added the `dart:convert`/`dart:io`/`file_picker` imports,
   constructed `backupService = BackupService(spellRepository: ..., configRepository: ...)`
   in `main()`, threaded it through `EruditusApp` and `_MainTabView` as a plain constructor
   field (not a `BlocProvider`, since `BackupScreen` isn't bloc-based), added `BackupScreen`
   as the 4th tab wired to real `file_picker`/`dart:io` (`FilePicker.saveFile`/`pickFiles` +
   `File(path).readAsString()`), and added the 4th `BottomNavigationBarItem` ("Backup",
   `Icons.cloud_upload`).

6. **`test/widget_test.dart`** (modified) — added a real in-memory `AppDatabase`-backed
   `BackupService` (same pattern as Tasks 4-7: `sqfliteFfiInit()`/`databaseFactoryFfi`),
   passed as `backupService:` into `EruditusApp(...)`, and added
   `expect(find.text('Backup'), findsOneWidget);` to the assertions.

## Two adaptations required (both discovered via TDD, not assumed)

**1. Missing `TestWidgetsFlutterBinding.ensureInitialized()`.** The brief's exact test code
for `backup_service_test.dart` and `backup_screen_test.dart` omitted this call, which every
other real-`ConfigurationRepository`-backed test in this codebase (Task 7's
`configuration_repository_test.dart`, etc.) includes — without it, `AssetDataLoader`'s
`rootBundle.loadString()` throws `Binding has not yet been initialized`. Added the same line
used elsewhere in the project to both new test files.

**2. `tester.tap()` + `pumpAndSettle()` doesn't complete real async work triggered from a
button callback under this project's `flutter_tester` build.** This is a new, broader
manifestation of the environment issue already documented for real Blocs — it isn't
Bloc-specific; it's about *any* genuine async platform-channel/database I/O awaited either
(a) directly inside a `testWidgets` test body, or (b) via a widget callback dispatched by
`tester.tap()`. Concretely:

- Calling `await backupService.exportToJson()` directly inside a `testWidgets` body (not
  wrapped in `tester.runAsync()`) hung indefinitely (>90s, "did not complete") — even though
  the identical call in a plain `test()` body (as in `backup_service_test.dart`) completes
  instantly. Same for `await AppDatabase.open(...)` called directly inside a `testWidgets`
  body in `widget_test.dart`.
- Driving the export button via `tester.tap()` (with or without wrapping in
  `tester.runAsync()`) let the test finish "successfully" (fast, not hanging) but with the
  async work never actually completing before assertions ran — confirmed by a
  `DatabaseException(error database_closed)` thrown *after* the test had already ended,
  proving `_handleExport`'s real async chain kept running past `pumpAndSettle()`'s return.

  Root cause: `tester.tap()` dispatches the gesture (and its `onPressed` callback) through
  the normal test/fake-async zone regardless of whether the `tap()` call itself is wrapped in
  `runAsync()`, so a callback doing genuine async I/O never actually gets to run to
  completion in real time.

**Fixes applied (functionally equivalent to the brief's intent, verified working):**
- In `backup_screen_test.dart`'s export test: instead of `tester.tap(...)` +
  `pumpAndSettle()`, look up the button widget
  (`tester.widget<ElevatedButton>(find.byKey(...))`) and invoke its `onPressed` callback
  directly inside `tester.runAsync()`, then `await tester.pump()` twice to let `setState`
  propagate. The other two tests (`cancelled`/`malformed`) don't touch real I/O and pass
  unmodified with plain `tester.tap()` + `pumpAndSettle()`.
- In `widget_test.dart`: moved `AppDatabase.open()`/`BackupService` construction out of the
  `testWidgets` body and into `setUp()`/`tearDown()` (mirroring the already-working pattern
  in `backup_screen_test.dart`), since `setUp`/`tearDown` callbacks run outside the
  fake-async test-body zone and real async I/O there completes normally. `pumpWidget` itself
  never triggers real I/O (only tapping export/import would), so this was sufficient.

No hang exceeded the 2-minute threshold in the final passing state; every hang encountered
during investigation was resolved via the above (confirmed root cause with disposable debug
test files, all deleted before the final commit).

## Test commands and output

Ran with Flutter's PATH exported first:
```bash
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
```

### `backup_service_test.dart` — after implementing `BackupService`
```
flutter test test/data/services/backup_service_test.dart -v
```
```
00:00 +0: (setUpAll)
00:00 +0: exportToJson includes only user-created spells and custom config, with version and date
00:00 +1: importFromJson restores spells and custom effects
00:00 +2: importFromJson is idempotent — importing the same backup twice does not throw or duplicate
00:00 +3: importFromJson throws FormatException for malformed JSON
00:00 +4: importFromJson throws FormatException for an unsupported version
00:00 +5: (tearDownAll)
00:01 +5: All tests passed!
```

### `backup_screen_test.dart` — after implementing `BackupScreen` and the export-test fix
```
flutter test test/presentation/screens/backup_screen_test.dart -v
```
```
00:00 +0: (setUpAll)
00:00 +0: tapping export calls exportJson with the service output and shows success
00:00 +1: tapping import with a cancelled file picker shows "Import cancelled."
00:00 +2: tapping import with malformed content shows the failure message
00:00 +3: (tearDownAll)
00:00 +3: All tests passed!
```
Reran twice more — identical pass, no flakiness.

### `widget_test.dart` — after main.dart wiring and the setUp/tearDown fix
```
flutter test test/widget_test.dart -v
```
```
00:00 +0: (setUpAll)
00:00 +0: EruditusApp launches showing the Create tab and bottom navigation
00:00 +1: (tearDownAll)
00:00 +1: All tests passed!
```
Reran twice more — identical pass, no flakiness.

### Full suite — run 3 times to rule out flakiness
```
flutter test
```
Run 1: `00:09 +118: All tests passed!` (exit 0)
Run 2: `00:09 +118: All tests passed!` (exit 0)
Run 3: `00:10 +118: All tests passed!` (exit 0)

All 118 tests across the whole suite (108 from Tasks 1-13 + 10 new from Task 14) pass
consistently across 3 full runs, no flakiness, no hangs.

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
from Task 12). No new warnings/errors from any of this task's files.

## Concerns

1. **`file_picker` API mismatch with the brief.** The brief's `main.dart` snippet used
   `FilePicker.platform.saveFile(...)`/`FilePicker.platform.pickFiles(...)`. The installed
   `file_picker: ^11.0.2` exposes `FilePicker` as an `abstract final class` with plain
   `static` methods — there is no `.platform` getter in this version. Used
   `FilePicker.saveFile(...)`/`FilePicker.pickFiles(...)` directly instead (functionally
   identical; confirmed by reading the installed package source). This is a real API surface
   difference, not a typo — worth noting if a future task references the older
   `FilePicker.platform` pattern from elsewhere.
2. **Two test-file adaptations were necessary** (see above) beyond the brief's literal code,
   both driven by the project's already-known "real async hangs/doesn't complete under
   `flutter_tester`" issue extending beyond just Blocs to any real platform-channel/database
   I/O triggered inside a `testWidgets` body or via `tester.tap()`. Recommend updating the
   project's shared testing guidance to note this broader scope for future tasks that mix
   real repositories/services into widget tests.
3. No other functional concerns. `BackupScreen`'s UI, `BackupService`'s import/export/
   idempotency logic, and the 4th "Backup" nav tab all match the brief's design intent.

## Commit

`321d600` — "feat: add BackupService and BackupScreen (file-based export/import)"

Files committed (exactly as specified in the brief's Step 11, nothing else):
- `lib/data/services/backup_service.dart` (new)
- `lib/presentation/screens/backup_screen.dart` (new)
- `lib/main.dart` (modified)
- `test/data/services/backup_service_test.dart` (new)
- `test/presentation/screens/backup_screen_test.dart` (new)
- `test/widget_test.dart` (modified)

The pre-existing untracked `.claude/` directory was left alone, as instructed (not part of
this task). No other uncommitted changes were present in the working tree at commit time.
