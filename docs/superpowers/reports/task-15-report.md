# Task 15 Implementation Report: End-to-End Integration Test

## Status: COMPLETE

Implemented directly by the controller (no subagent dispatched), since resolving
the device/runtime target required a series of environment decisions only the
user could make (chromedriver provisioning, a firewall rule, Windows Developer
Mode). Full narrative is in `.superpowers/sdd/progress.md`'s Task 15 entry —
this report summarizes the outcome.

## What was done

1. `pubspec.yaml`: `integration_test: sdk: flutter` added to `dev_dependencies`.
2. `integration_test/spell_creation_flow_test.dart`: end-to-end test driving the
   real `EruditusApp` (real blocs, real in-memory database via
   `sqflite_common_ffi`) through: select Creo Imaginem → pick the "affects two
   senses" base effect → calculate → verify suggestions include the two
   matching built-in library spells → save as "My New Illusion" → switch to
   the Library tab → verify it appears → filter to "My Spells" → verify only
   the new spell shows.
3. `test_driver/integration_test.dart`: the `flutter drive` harness (needed for
   the Chrome/chromedriver path that was ultimately abandoned, kept since it's
   harmless and documents that path was tried).
4. `lib/main.dart`: **real product fix**. `SpellLibraryScreen`'s `initState()`
   only dispatches `LibraryRequested()` once; since `IndexedStack` keeps all
   tab screens permanently mounted, switching to the Library tab after saving
   a spell from the Create tab never refreshed the list. Fixed by dispatching
   `LibraryRequested()` from the bottom nav's `onTap` whenever switching to the
   Library tab. This was a real bug affecting actual users, caught only
   because this was the first test to exercise the real save → real database
   → real reload path end-to-end.

## Environment resolution (for the record)

No device/runtime target for `integration_test` worked out of the box on this
Windows machine:
- `-d chrome` is unsupported outright for `integration_test` via `flutter test`
  on this Flutter version; it requires the separate `flutter drive` +
  chromedriver + driver-harness path instead.
- `-d windows` needed Windows Developer Mode enabled (symlink support for
  native plugin builds).

The user chose to pursue both:
- Chrome: user provided a chromedriver-adjacent folder (which turned out to
  actually be a bare Chrome-for-Testing browser build, not chromedriver
  itself); controller fetched the correct matching chromedriver build from
  Google's official distribution (with the user's advance permission), fixed
  a version mismatch against system Chrome, and diagnosed a Windows Firewall
  block on `dart.exe` (user added the firewall rule themselves). Once
  connected, the test failed for good reason: `sqflite_common_ffi` cannot run
  on web at all (`dart:ffi` doesn't exist in a browser) — a genuine, hard
  incompatibility, not a config issue. Chrome was abandoned as the target.
- Windows: user enabled Developer Mode
  (`Set-ItemProperty ... AllowDevelopmentWithoutDevLicense 1`, run by the user,
  verified by the controller via registry read). This worked: native build,
  no chromedriver/driver-harness needed.

## Bugs the test caught once it could actually run

1. **Test-only**: Flutter's sliver `ListView` only mounts children within the
   viewport + cache extent, even for the non-builder `children:` form. The
   suggestions section and the newly-saved (28th, last-appended) library spell
   were genuinely below the fold and unbuilt. Fixed with
   `tester.scrollUntilVisible(...)`, carefully scoped since `IndexedStack`
   keeps every tab mounted (multiple `Scrollable`s in the tree at once) and
   `TextField`/`EditableText` adds its own internal `Scrollable` too.
2. **Real product bug**: see `lib/main.dart` fix above.

## Verification

- `flutter test integration_test/spell_creation_flow_test.dart -d windows`:
  passes (1/1).
- `flutter test -v` (full suite): passes (118/118), no regressions from the
  `main.dart` change.
- No stray `chromedriver.exe`/`eruditus.exe`/`flutter_tester.exe` processes
  left running after any run (checked via `tasklist` after each attempt).

## Current repository state (uncommitted, ready to commit)

- `pubspec.yaml` / `pubspec.lock`: `integration_test` dependency added.
- `integration_test/spell_creation_flow_test.dart`: created, passing.
- `test_driver/integration_test.dart`: created (Chrome path artifact, harmless
  to keep).
- `lib/main.dart`: Library-tab-staleness fix.

## Commit hash(es)

None yet — pending commit of the above files together, then dispatch of this
task's code review per the standard subagent-driven-development flow.
