# Task 11: Spell Creation Screen (UI) - Implementation Report

**Status:** DONE (implemented directly by controller, not a dispatched subagent)

## What happened

A subagent was dispatched to implement Task 11 per the standard subagent-driven-development process. It correctly implemented `SpellCreationScreen` (`lib/presentation/screens/spell_creation_screen.dart`) quickly, but then hit a genuine widget-test failure and spent approximately 45 minutes debugging it — creating four scratch `_debug_*.dart` files, progressively narrowing down the reproduction, without resolving it. The user flagged the unusually long runtime; the controller checked in via `SendMessage`, then stopped the subagent via `TaskStop` after confirming (via file-modification timestamps) it was still actively working but not converging.

## Root cause (found by the controller after taking over)

A real `Bloc`'s internal event-transformer pipeline hangs indefinitely under this project's `flutter_tester` build (Flutter 3.44.8). Confirmed via systematic elimination:
- `bloc.add()` called directly with no tap/gesture involved: hangs identically to the tap-driven case.
- `pump()`, `pumpAndSettle()`, `pump(Duration)`, and `runAsync()` wrapping: all hang identically — none of these mechanics helped.
- Reproduced identically on `bloc` 8.1.4 and 9.2.1 (upgraded specifically to test this hypothesis) — not a version-specific bug.
- A raw `StreamController` + `StreamBuilder` (no `Bloc` involved) works fine in the same environment, in under 1 second.
- `bloc_test`'s `blocTest` (which doesn't use `testWidgets`/`flutter_tester` at all) works fine — confirmed by Tasks 8-10's dozens of passing tests, including with real repositories/databases.

This narrows the issue specifically to a real `Bloc`'s internal pipeline running inside the `testWidgets` fake-async zone in this environment — not streams in general, not bloc logic, not gestures, not bloc version.

## Fix

Widget tests use `mocktail`'s `MockBloc` + `whenListen` instead of a real bloc — this is also the idiomatic `flutter_bloc` widget-testing pattern regardless of this environment's quirk, since the real bloc logic is already covered by Tasks 8-10's `blocTest` suites.

## What was implemented

- `lib/presentation/screens/spell_creation_screen.dart`: Technique/Form/BaseEffect dropdowns, parameter chips (add via dropdown, remove via chip delete), special-factor checkboxes filtered to the current Technique+Form, validation error display, calculated-level card, "Calculate & View Suggestions" button. Debug `print()` statements from the investigation were removed before commit.
- `test/presentation/screens/spell_creation_screen_test.dart`: 7 tests using `MockSpellCreationBloc` (extends `MockBloc`) + `whenListen` to control state, and `verify(() => bloc.add(...))` to check dispatched events.
- `pubspec.yaml`: added `mocktail: ^1.0.4` (dev dependency), and bumped `flutter_bloc` 8.1.0→9.0.0 / `bloc_test` 9.1.7→10.0.0 (investigated as a possible fix for the hang — it wasn't, but kept since it's fully compatible: 90/90 pre-existing tests pass unchanged — per the project's "prefer latest library versions" standing preference).

## Test verification

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
cd C:\Users\idf53\Development\personal\arsm\eruditus
flutter test test/presentation/screens/spell_creation_screen_test.dart
```

Result: 7/7 tests pass. Verified stable across 3 consecutive reruns (~2-4s each, no flakiness).

Full suite (`flutter test`): 91/91 pass.

## Plan-wide follow-up (separate commit `0af835b`)

Tasks 12-15 (not yet dispatched) had the same real-bloc-in-widget-test shape planned. To avoid rediscovering this same issue three more times:
- Tasks 12-13's widget tests rewritten to use `MockBloc`/`whenListen`.
- `EruditusApp` (Task 13) redesigned to take pre-built blocs via constructor injection (`BlocProvider.value`) rather than constructing them internally via `create:` — this is the dependency-injection seam that makes mocking possible at all for `EruditusApp`-level tests (including `test/widget_test.dart`'s smoke test).
- Task 15 (the genuine end-to-end test, which cannot mock without defeating its purpose) rewritten to use Flutter's `integration_test` package, which runs on a real device/browser/desktop runtime with a real event loop — sidestepping the `flutter_tester`-specific issue entirely. `-d chrome` recommended as the friction-free target for this Windows dev environment (already-installed Chrome, no native build, no Developer Mode requirement).

## Other findings during investigation

- Confirmed `TaskStop` on a Bash background task does not kill child processes it spawned — a stopped `flutter test` command's `flutter_tester.exe`/`dartaotruntime.exe` survive and can hold the test-harness communication port, causing subsequent unrelated `flutter test` invocations to hang too. Always sweep `tasklist` for stray `flutter`/`dart`/`find` processes after stopping a hung flutter test task, not just after a normal completion.
- A stray `find.exe` (GNU findutils, from the controller's own earlier investigative `find` commands) was also found running and killed — likely unrelated to the actual bug, but cleared as part of the same cleanup pass.

## Commit

`fb2ae5c` — "feat: add SpellCreationScreen UI (Task 11)" — contains `lib/presentation/screens/spell_creation_screen.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `pubspec.yaml`, `pubspec.lock`.
