# Bloc Test Factories, the Fake-Async Rule, and an All-Suites Runner — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close todo item 6's three remaining boxes — a shared bloc-factory test helper (mocked blocs *and* real blocs over in-memory fake repositories), the fake-async rule documented where a test author meets it, and one command that runs every suite.

**Architecture:** One new non-test file, `test/support/bloc_factories.dart`, holds three mock-bloc classes, factory functions that pair construction with `whenListen`, three hand-written in-memory repository fakes, and synchronous real-bloc factories. Its library-level dartdoc is the canonical statement of the rule. Five widget-test files then import it instead of hand-rolling. A separate `tool/run_all_tests.dart` shells out to the four steps CI runs.

**Tech Stack:** Dart / Flutter 3.44.8, `bloc_test`, `mocktail`, `flutter_test`; Python 3.13 stdlib `unittest` for the import harness, invoked through `uv`.

## Global Constraints

- **Migration is behaviour-preserving.** No assertion in any migrated file changes. Only `Mock*`/`Fake*` class declarations, `registerFallbackValue` blocks, and bloc construction lines are touched.
- **The helper file must NOT end in `_test.dart`** — `flutter test` would collect it and report "no tests" as a failure.
- **The fakes are synchronous.** No `await` in a factory. A real-bloc factory must be callable from inside a `testWidgets` body.
- **`test/bloc/spell_creation_bloc_test.dart` and `test/bloc/spell_library_bloc_test.dart` are OUT OF SCOPE.** They use mocktail for error injection (`thenThrow`), which the fakes deliberately do not replace. Do not touch them.
- **Dart suite count: 660 before, 661 after.** Exactly one test is added (Task 5). Any other change to the count is a mistake to investigate, not to accept.
- **Python is invoked as `uv run --no-project python ...`** locally, per this repo's convention, even though CI uses bare `python`.
- Run `flutter analyze` before every commit; CI fails on any analyzer **warning**, not just errors.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `test/support/bloc_factories.dart` | Create | Mock blocs, mock factories, in-memory repository fakes, real-bloc factories, and the library dartdoc stating the rule |
| `test/support/bloc_factories_test.dart` | Create | Proves the real-bloc path actually re-renders (Task 5) |
| `tool/run_all_tests.dart` | Create | Runs the four CI steps, reports a summary, exits non-zero on any failure |
| `test/widget_test.dart` | Modify | Drop 3 mocks + 6 fakes + 6 fallback calls; correct the false comment at `:54-60` |
| `test/presentation/screens/configuration_screen_test.dart` | Modify | Drop 1 mock + 2 fakes + 2 fallback calls |
| `test/presentation/screens/spell_creation_screen_test.dart` | Modify | Drop 2 mocks + 4 fakes + 4 fallback calls |
| `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart` | Modify | Drop 2 mocks + 4 fakes + 4 fallback calls |
| `test/presentation/screens/spell_library_screen_test.dart` | Modify | Drop 2 mocks + 4 fakes + 4 fallback calls |
| `.superpowers/todo.md` | Modify | Tick item 6's three boxes; correct the "nine test files" figure |

---

## Task 1: The helper's mock half

**Files:**
- Create: `test/support/bloc_factories.dart`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - `class MockSpellCreationBloc extends MockBloc<SpellCreationEvent, SpellCreationState> implements SpellCreationBloc`
  - `class MockSpellLibraryBloc extends MockBloc<SpellLibraryEvent, SpellLibraryState> implements SpellLibraryBloc`
  - `class MockConfigurationBloc extends MockBloc<ConfigurationEvent, ConfigurationState> implements ConfigurationBloc`
  - `void registerBlocFallbackValues()`
  - `MockSpellCreationBloc mockSpellCreationBloc({SpellCreationState? initialState, Stream<SpellCreationState>? states})`
  - `MockSpellLibraryBloc mockSpellLibraryBloc({SpellLibraryState? initialState, Stream<SpellLibraryState>? states})`
  - `MockConfigurationBloc mockConfigurationBloc({ConfigurationState? initialState, Stream<ConfigurationState>? states})`

- [ ] **Step 1: Create the file with its library dartdoc and mock half**

This dartdoc is Component 2 of the spec — the canonical statement of the rule. Write it exactly; later tasks add code below it but must not edit it.

```dart
/// Shared bloc factories for widget tests.
///
/// ## The rule: don't await real I/O in a test body
///
/// A `testWidgets` body runs inside a **fake-async zone**. Awaiting real
/// asynchronous I/O there — a real database open, a real asset load — never
/// completes, because the zone controls the clock and nothing advances it.
/// That is the hang. It is *not* a Bloc limitation, and an earlier version of
/// this repo's notes said it was.
///
/// A Bloc is an event handler. A **real** bloc runs fine in a widget test,
/// including `pumpAndSettle`, as long as nothing behind it performs real I/O.
/// Faking the repository is what removes the I/O.
///
/// Two corollaries:
///
/// * `setUp` and `tearDown` run **outside** the fake-async zone, so real async
///   work there completes normally. That is why `test/widget_test.dart` opens
///   its real `AppDatabase` in `setUp` rather than inline.
/// * `tester.runAsync` is the documented escape hatch from *inside* the zone,
///   when a test genuinely needs real async work mid-body.
///
/// ## Which factory do I want?
///
/// * **A mock bloc** ([mockSpellCreationBloc] and siblings) when the assertion
///   is about rendering a *given* state. You supply the state; nothing
///   transitions.
/// * **A real bloc over a fake repository** ([realSpellCreationBloc] and
///   siblings) whenever the failure mode is **"what happens on re-render"**. A
///   mock emits no new state, so the rebuild after an interaction never
///   happens and the assertion cannot fail. The add-requisite crash — a
///   `DropdownButtonFormField` holding a value no longer in its `items` — was
///   invisible to six passing widget tests for exactly this reason.
///
/// Driving a mock through a `StreamController` is the third option; pass it as
/// the `states` argument rather than hand-rolling the wiring.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';

class MockSpellCreationBloc extends MockBloc<SpellCreationEvent, SpellCreationState>
    implements SpellCreationBloc {}

class MockSpellLibraryBloc extends MockBloc<SpellLibraryEvent, SpellLibraryState>
    implements SpellLibraryBloc {}

class MockConfigurationBloc extends MockBloc<ConfigurationEvent, ConfigurationState>
    implements ConfigurationBloc {}

class _FakeSpellCreationEvent extends Fake implements SpellCreationEvent {}

class _FakeSpellCreationState extends Fake implements SpellCreationState {}

class _FakeSpellLibraryEvent extends Fake implements SpellLibraryEvent {}

class _FakeSpellLibraryState extends Fake implements SpellLibraryState {}

class _FakeConfigurationEvent extends Fake implements ConfigurationEvent {}

class _FakeConfigurationState extends Fake implements ConfigurationState {}

bool _fallbacksRegistered = false;

/// Registers mocktail fallback values for every bloc event and state.
///
/// Idempotent, so calling it from more than one `setUpAll` is safe. Call it
/// once per test file that uses any mock factory here.
void registerBlocFallbackValues() {
  if (_fallbacksRegistered) return;
  _fallbacksRegistered = true;
  registerFallbackValue(_FakeSpellCreationEvent());
  registerFallbackValue(_FakeSpellCreationState());
  registerFallbackValue(_FakeSpellLibraryEvent());
  registerFallbackValue(_FakeSpellLibraryState());
  registerFallbackValue(_FakeConfigurationEvent());
  registerFallbackValue(_FakeConfigurationState());
}

/// A mocked [SpellCreationBloc] already wired to emit [initialState].
///
/// Pairing construction with `whenListen` is the point: a bare `MockBloc` has
/// a null state, and every call site previously repeated this by hand.
MockSpellCreationBloc mockSpellCreationBloc({
  SpellCreationState? initialState,
  Stream<SpellCreationState>? states,
}) {
  final bloc = MockSpellCreationBloc();
  whenListen(
    bloc,
    states ?? const Stream<SpellCreationState>.empty(),
    initialState: initialState ?? SpellCreationState.initial(),
  );
  return bloc;
}

/// A mocked [SpellLibraryBloc] already wired to emit [initialState].
MockSpellLibraryBloc mockSpellLibraryBloc({
  SpellLibraryState? initialState,
  Stream<SpellLibraryState>? states,
}) {
  final bloc = MockSpellLibraryBloc();
  whenListen(
    bloc,
    states ?? const Stream<SpellLibraryState>.empty(),
    initialState: initialState ?? SpellLibraryState.initial(),
  );
  return bloc;
}

/// A mocked [ConfigurationBloc] already wired to emit [initialState].
MockConfigurationBloc mockConfigurationBloc({
  ConfigurationState? initialState,
  Stream<ConfigurationState>? states,
}) {
  final bloc = MockConfigurationBloc();
  whenListen(
    bloc,
    states ?? const Stream<ConfigurationState>.empty(),
    initialState: initialState ?? ConfigurationState.initial(),
  );
  return bloc;
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `flutter analyze test/support/bloc_factories.dart`
Expected: `No issues found!`

If `SpellCreationState.initial()`, `SpellLibraryState.initial()` or `ConfigurationState.initial()` does not exist with that exact name, stop and check the state class — `test/widget_test.dart:96-100` calls all three, so they should. Do not invent a substitute.

- [ ] **Step 3: Verify the file is not collected as a test**

Run: `flutter test test/support/`
Expected: fails with "No test files found" or similar. That is the **correct** outcome — it confirms the filename keeps the helper out of the suite. If it instead reports 0 tests passing in `bloc_factories.dart`, the file is being collected and must be renamed.

- [ ] **Step 4: Commit**

```bash
git add test/support/bloc_factories.dart
git commit -m "test: add shared mock bloc factories and the fake-async rule

Three MockBloc subclasses, six fallback values and the whenListen pairing
were copied across five test files. They live here once now.

The library dartdoc states the rule those files got wrong: the hang is real
I/O awaited in a fake-async test body, not a Bloc limitation.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: The in-memory repository fakes

**Files:**
- Modify: `test/support/bloc_factories.dart` (append; do not edit the dartdoc)

**Interfaces:**
- Consumes: Task 1's file.
- Produces:
  - `class FakeSpellRepository implements SpellRepository` with `final Map<String, Spell> spells`
  - `class FakeLibraryRepository implements LibraryRepository` with settable `List<ResolvedSpell> spells`, `List<ResolvedTemplate> templates`, `List<ResolvedException> exceptions`
  - `class FakeConfigurationRepository implements ConfigurationRepository` with settable `List<BaseEffect> effects`, `List<Parameter> parameters`, `List<Modifier> modifiers`

**Context the implementer needs:** these three repositories are **concrete classes**, not abstract interfaces. Implementing one in Dart obliges you to satisfy its public surface *and* its public final fields (as getters), but **not** its private members (`_refreshResolver`, `_problemsFor`, `_assertValid`) — private members are invisible across libraries. The injected fields are the ones you must stub, and they should throw rather than return something plausible.

`ResolvedSpell` is `const`-constructible from a record alone (`ResolvedSpell(record: spell)`), and its own dartdoc says direct construction outside `SpellResolver` is exactly for test fixtures. That is why the fake can wrap records without a resolver.

- [ ] **Step 1: Append the fakes**

```dart
/// The message every fake uses when a test reaches for real plumbing.
Never _plumbingUnsupported(String fake, String member) => throw UnsupportedError(
      '$fake replaces repository *behaviour*, not its plumbing, so `$member` '
      'is unavailable. If a test needs the real thing, build the real '
      'repository in setUp (which runs outside the fake-async zone) instead '
      'of reaching through this fake.',
    );

/// An in-memory [SpellRepository] holding records in a plain map.
///
/// Deliberately has no error-injection hook: mocktail is the better tool for
/// making a call fail on demand, and `test/bloc/spell_creation_bloc_test.dart`
/// already uses it that way. This fake models storage that works.
class FakeSpellRepository implements SpellRepository {
  final Map<String, Spell> spells = {};

  @override
  LocalSpellDatasource get datasource =>
      _plumbingUnsupported('FakeSpellRepository', 'datasource');

  @override
  SpellResolver get resolver =>
      _plumbingUnsupported('FakeSpellRepository', 'resolver');

  @override
  ConfigurationRepository get configRepository =>
      _plumbingUnsupported('FakeSpellRepository', 'configRepository');

  @override
  Future<void> saveSpell(Spell spell) async => spells[spell.id] = spell;

  @override
  Future<void> updateSpell(Spell spell) async => spells[spell.id] = spell;

  @override
  Future<void> deleteSpell(String id) async => spells.remove(id);

  @override
  Future<List<InvalidSpellException>> saveAll(Iterable<Spell> toSave) async {
    for (final spell in toSave) {
      spells[spell.id] = spell;
    }
    return const [];
  }

  @override
  Future<ResolvedSpell?> getSpellById(String id) async {
    final record = spells[id];
    return record == null ? null : ResolvedSpell(record: record);
  }

  @override
  Future<List<ResolvedSpell>> getAllUserSpells() async =>
      spells.values.map((record) => ResolvedSpell(record: record)).toList();
}

/// An in-memory [LibraryRepository]. Assign the lists to control what loads.
class FakeLibraryRepository implements LibraryRepository {
  List<ResolvedSpell> spells = [];
  List<ResolvedTemplate> templates = [];
  List<ResolvedException> exceptions = [];

  @override
  AssetDataLoader get assetLoader =>
      _plumbingUnsupported('FakeLibraryRepository', 'assetLoader');

  @override
  SpellRepository get spellRepository =>
      _plumbingUnsupported('FakeLibraryRepository', 'spellRepository');

  @override
  SpellResolver get resolver =>
      _plumbingUnsupported('FakeLibraryRepository', 'resolver');

  @override
  ConfigurationRepository? get configRepository => null;

  @override
  Future<List<ResolvedSpell>> getBuiltInSpells() async => spells;

  @override
  Future<List<ResolvedTemplate>> getTemplates() async => templates;

  @override
  Future<List<ResolvedException>> getExceptions() async => exceptions;

  @override
  Future<List<ResolvedSpell>> getAllSpells() async => spells;

  @override
  Future<List<ResolvedSpell>> searchSpells(String query) async {
    if (query.isEmpty) return spells;
    final lower = query.toLowerCase();
    return spells.where((s) => (s.name ?? '').toLowerCase().contains(lower)).toList();
  }

  @override
  Future<List<ResolvedSpell>> filterBySource(PublicationSource source) async =>
      spells.where((s) => s.source == source).toList();
}

/// An in-memory [ConfigurationRepository]. Assign the lists to control the
/// catalog; the add/delete methods mutate them.
class FakeConfigurationRepository implements ConfigurationRepository {
  List<BaseEffect> effects = [];
  List<Parameter> parameters = [];
  List<Modifier> modifiers = [];

  @override
  AssetDataLoader get assetLoader =>
      _plumbingUnsupported('FakeConfigurationRepository', 'assetLoader');

  @override
  LocalConfigurationDatasource get configDatasource =>
      _plumbingUnsupported('FakeConfigurationRepository', 'configDatasource');

  @override
  Future<List<BaseEffect>> getAllEffects() async => effects;

  @override
  Future<List<Parameter>> getAllParameters() async => parameters;

  @override
  Future<List<Modifier>> getAllModifiers() async => modifiers;

  @override
  Future<void> addCustomEffect(BaseEffect effect) async => effects.add(effect);

  @override
  Future<void> deleteCustomEffect(String id) async =>
      effects.removeWhere((e) => e.id == id);

  @override
  Future<void> addCustomParameter(Parameter parameter) async =>
      parameters.add(parameter);

  @override
  Future<void> deleteCustomParameter(String id) async =>
      parameters.removeWhere((p) => p.id == id);

  @override
  Future<void> addCustomModifier(Modifier modifier) async =>
      modifiers.add(modifier);

  @override
  Future<void> deleteCustomModifier(String id) async =>
      modifiers.removeWhere((m) => m.id == id);
}
```

- [ ] **Step 2: Add the imports these fakes need**

Append to the existing import block at the top of the file (keep it alphabetical within the `package:eruditus` group):

```dart
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/invalid_spell_exception.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_exception.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/models/spell.dart';
```

- [ ] **Step 3: Verify it analyzes clean**

Run: `flutter analyze test/support/bloc_factories.dart`
Expected: `No issues found!`

The likely failure is `missing_concrete_implementation` — the analyzer naming a member one of the three repositories declares that the fake does not. Add it, mirroring the shape above: a data method returns from the in-memory list; an injected field throws via `_plumbingUnsupported`. Do not silence it with `noSuchMethod`; the explicit list is what makes a repository gaining a method a compile error here rather than a silent gap.

- [ ] **Step 4: Commit**

```bash
git add test/support/bloc_factories.dart
git commit -m "test: add in-memory repository fakes for real-bloc widget tests

Hand-written rather than mocktail mocks: a real bloc under test needs a
repository that behaves, not one that needs a when() per method. Injected
fields throw a message pointing at setUp rather than returning a plausible
null.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: The real-bloc factories

**Files:**
- Modify: `test/support/bloc_factories.dart` (append)

**Interfaces:**
- Consumes: Task 2's `FakeSpellRepository`, `FakeLibraryRepository`, `FakeConfigurationRepository`.
- Produces:
  - `SpellCreationBloc realSpellCreationBloc({FakeSpellRepository? spells, SpellEngine? engine})`
  - `SpellLibraryBloc realSpellLibraryBloc({FakeLibraryRepository? library, SpellEngine? engine})`
  - `ConfigurationBloc realConfigurationBloc({FakeConfigurationRepository? configuration})`

**Context:** the bloc constructors are `SpellCreationBloc({required spellEngine, required spellRepository})`, `SpellLibraryBloc({required libraryRepository, required spellEngine})`, `ConfigurationBloc({required configRepository})`. `SpellEngine({required allSpells, allModifiers = const [], allParameters = const []})` constructs synchronously, which is what keeps these factories free of `await`.

- [ ] **Step 1: Append the factories**

```dart
/// A **real** [SpellCreationBloc] over an in-memory repository.
///
/// Synchronous by design — call it straight from a `testWidgets` body. Use
/// this, not [mockSpellCreationBloc], when the assertion is about a rebuild.
SpellCreationBloc realSpellCreationBloc({
  FakeSpellRepository? spells,
  SpellEngine? engine,
}) =>
    SpellCreationBloc(
      spellEngine: engine ?? SpellEngine(allSpells: const []),
      spellRepository: spells ?? FakeSpellRepository(),
    );

/// A **real** [SpellLibraryBloc] over an in-memory repository.
SpellLibraryBloc realSpellLibraryBloc({
  FakeLibraryRepository? library,
  SpellEngine? engine,
}) =>
    SpellLibraryBloc(
      libraryRepository: library ?? FakeLibraryRepository(),
      spellEngine: engine ?? SpellEngine(allSpells: const []),
    );

/// A **real** [ConfigurationBloc] over an in-memory repository.
ConfigurationBloc realConfigurationBloc({
  FakeConfigurationRepository? configuration,
}) =>
    ConfigurationBloc(
      configRepository: configuration ?? FakeConfigurationRepository(),
    );
```

- [ ] **Step 2: Add the engine import**

```dart
import 'package:eruditus/engine/spell_engine.dart';
```

- [ ] **Step 3: Verify it analyzes clean**

Run: `flutter analyze test/support/bloc_factories.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add test/support/bloc_factories.dart
git commit -m "test: add real-bloc factories over the in-memory fakes

Synchronous, so a testWidgets body can construct one without awaiting real
I/O -- which is the whole reason a real bloc is usable in a widget test.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: The all-suites runner

**Files:**
- Create: `tool/run_all_tests.dart`

**Interfaces:**
- Consumes: nothing. Independent of Tasks 1-3; may be done in any order relative to them.
- Produces: `dart run tool/run_all_tests.dart`, exit 0 only if all four steps pass.

- [ ] **Step 1: Write the runner**

```dart
// Runs every suite this project has, in the order .github/workflows/tests.yml
// runs them. `flutter test` alone is NOT the suite: it does not run
// integration_test/ (those need a device), and CI additionally gates on
// `flutter analyze`. Before this script existed there was no single command
// meaning "everything CI checks" -- see .superpowers/todo.md item 6.
//
// Every step runs even after one fails, then the summary prints. Stopping at
// the first failure would hide exactly the question this script exists to
// answer: which suites actually ran?
import 'dart:io';

/// One command, with a human-readable label for the summary table.
class _Step {
  final String label;
  final String executable;
  final List<String> arguments;

  const _Step(this.label, this.executable, this.arguments);
}

/// The integration suite needs a real device, and the device name is
/// platform-specific. `windows` is the only configuration this suite has ever
/// run in; Linux desktop support exists in the repo but has never been
/// exercised (see the comment on the `integration` job in tests.yml).
String _integrationDevice() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  throw UnsupportedError(
    'No integration device known for ${Platform.operatingSystem}. Add one '
    'here, and expect to exercise it on a branch before trusting it.',
  );
}

List<_Step> _steps() => [
      // CI fails the build on any analyzer error OR warning, so a runner that
      // skipped this could go green where CI would not.
      const _Step('Analyze', 'flutter', ['analyze']),
      // `uv run --no-project` is this machine's convention for a repo with no
      // pyproject.toml. CI uses bare `python` under actions/setup-python; the
      // unittest arguments are identical to CI's on purpose.
      const _Step('Import harness (Python)', 'uv', [
        'run',
        '--no-project',
        'python',
        '-m',
        'unittest',
        'discover',
        '-s',
        'scripts/spell_import/tests',
        '-t',
        '.',
      ]),
      const _Step('Dart suite', 'flutter', ['test']),
      _Step('Integration suite', 'flutter', [
        'test',
        'integration_test',
        '-d',
        _integrationDevice(),
      ]),
    ];

Future<void> main() async {
  final results = <String, bool>{};

  for (final step in _steps()) {
    stdout.writeln('');
    stdout.writeln('=== ${step.label} ===');
    stdout.writeln('\$ ${step.executable} ${step.arguments.join(' ')}');

    int exitCode;
    try {
      final process = await Process.start(
        step.executable,
        step.arguments,
        mode: ProcessStartMode.inheritStdio,
        runInShell: true,
      );
      exitCode = await process.exitCode;
    } on ProcessException catch (error) {
      // A missing executable is a failure of this step, not of the script.
      stdout.writeln('Could not run ${step.executable}: ${error.message}');
      exitCode = 127;
    }

    results[step.label] = exitCode == 0;
  }

  stdout.writeln('');
  stdout.writeln('=== Summary ===');
  results.forEach((label, passed) {
    stdout.writeln('${passed ? 'PASS' : 'FAIL'}  $label');
  });

  final failed = results.values.where((passed) => !passed).length;
  if (failed > 0) {
    stdout.writeln('');
    stdout.writeln('$failed of ${results.length} steps failed.');
    exit(1);
  }
  stdout.writeln('');
  stdout.writeln('All ${results.length} steps passed.');
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `flutter analyze tool/run_all_tests.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run it**

Run: `dart run tool/run_all_tests.dart`
Expected: all four steps `PASS`, exit 0. This takes several minutes — the integration suite builds a Windows desktop app.

If the Python step fails because `uv` is not on PATH, that is a real finding about the environment, not a reason to rewrite the step: report it rather than silently swapping in bare `python`.

- [ ] **Step 4: Verify a failure is actually reported**

Do not trust the summary until you have watched it fail. Temporarily edit the Dart-suite step's arguments to `['test', 'test/does_not_exist_test.dart']`, run again, and confirm the summary shows `FAIL  Dart suite`, the other three still ran, and `echo $LASTEXITCODE` (PowerShell) is 1. **Then revert the edit.**

- [ ] **Step 5: Commit**

```bash
git add tool/run_all_tests.dart
git commit -m "tool: add a single command running every suite

flutter test is not the suite: it skips integration_test/, and CI also gates
on flutter analyze. Four steps, CI's order, all of them run even after one
fails so the summary answers which suites actually ran.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Prove the real-bloc path re-renders

**Files:**
- Create: `test/support/bloc_factories_test.dart`

**Interfaces:**
- Consumes: `realSpellCreationBloc`, `FakeSpellRepository` from Tasks 2-3.
- Produces: nothing later tasks use.

**Why this test exists:** without it, the claim that a real bloc re-renders in a plain widget test is asserted only by a dartdoc comment. This is the one new test in the plan — the suite goes 660 → 661.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';

import 'bloc_factories.dart';

void main() {
  testWidgets(
    'a real bloc over a fake repository rebuilds the tree after an event',
    (tester) async {
      // The point of the test: constructed inline in the test body, with no
      // await. A real repository here would hang the fake-async zone.
      final bloc = realSpellCreationBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<SpellCreationBloc>.value(
          value: bloc,
          child: BlocBuilder<SpellCreationBloc, SpellCreationState>(
            builder: (context, state) => Text(
              state.draft.technique ?? 'no technique',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ));

      expect(find.text('no technique'), findsOneWidget);

      bloc.add(const TechniqueSelected('Creo'));
      await tester.pumpAndSettle();

      // A mocked bloc emits no new state, so this assertion is the one a mock
      // structurally cannot make fail.
      expect(find.text('Creo'), findsOneWidget);
    },
  );
}
```

- [ ] **Step 2: Run it to verify it fails for the right reason**

Run: `flutter test test/support/bloc_factories_test.dart`

Expected at this point: **PASS**, if Tasks 1-3 are complete. That is fine — this test documents a capability rather than driving new production code, so there is no red phase to manufacture.

What you must verify instead is that it has teeth. Temporarily change `realSpellCreationBloc()` to `mockSpellCreationBloc()` (adding `bloc.add` will need removing, since a mock ignores it — instead just delete the `bloc.add` line and keep the assertions). Re-run and confirm the final `expect(find.text('Creo'), ...)` **fails**. That failure is the proof the test distinguishes a real bloc from a mock. **Then revert.**

If the real-bloc version does *not* pass, do not weaken the test — check `TechniqueSelected`'s exact constructor and `SpellCreationState.draft.technique`'s exact name against `lib/bloc/spell_creation/`, and fix the test to match the real API.

- [ ] **Step 3: Commit**

```bash
git add test/support/bloc_factories_test.dart
git commit -m "test: prove a real bloc re-renders in a plain widget test

Item 6 was opened believing this hangs. It does not, and the belief cost the
cheap fix for re-render coverage. Asserting it keeps the correction from
decaying back into folklore.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Migrate `configuration_screen_test.dart`

**Files:**
- Modify: `test/presentation/screens/configuration_screen_test.dart:16-36`

**Interfaces:**
- Consumes: `mockConfigurationBloc`, `registerBlocFallbackValues`, `MockConfigurationBloc`.

This is the smallest of the five and establishes the pattern for Tasks 7-9. **No assertion changes.**

- [ ] **Step 1: Delete the local declarations**

Remove lines 16-21 entirely:

```dart
class MockConfigurationBloc extends MockBloc<ConfigurationEvent, ConfigurationState>
    implements ConfigurationBloc {}

class FakeConfigurationEvent extends Fake implements ConfigurationEvent {}

class FakeConfigurationState extends Fake implements ConfigurationState {}
```

- [ ] **Step 2: Add the helper import**

The file is at `test/presentation/screens/`, so the relative path up to `test/support/` is three levels:

```dart
import '../../support/bloc_factories.dart';
```

- [ ] **Step 3: Replace the fallback registration**

Replace:

```dart
  setUpAll(() {
    registerFallbackValue(FakeConfigurationEvent());
    registerFallbackValue(FakeConfigurationState());
  });
```

with:

```dart
  setUpAll(registerBlocFallbackValues);
```

- [ ] **Step 4: Move construction into the factory**

`bloc` is currently built in `setUp` and given its state later inside `pumpScreen`. The factory pairs the two, so build it in `pumpScreen` instead. Delete this `setUp` block entirely:

```dart
  setUp(() {
    bloc = MockConfigurationBloc();
  });
```

and change `pumpScreen`'s first line from:

```dart
    whenListen(bloc, const Stream<ConfigurationState>.empty(), initialState: state);
```

to:

```dart
    bloc = mockConfigurationBloc(initialState: state);
```

`late MockConfigurationBloc bloc;` stays — later assertions reference it.

- [ ] **Step 5: Drop now-unused imports**

`package:bloc_test/bloc_test.dart` and `package:mocktail/mocktail.dart` are likely unused now. Remove any the analyzer flags — CI fails on warnings, and an unused import is one.

- [ ] **Step 6: Verify**

Run: `flutter analyze test/presentation/screens/configuration_screen_test.dart && flutter test test/presentation/screens/configuration_screen_test.dart`
Expected: `No issues found!`, then every test in the file passing, with **the same count as before the change**. Note that count now; you will compare the suite total at Task 10.

- [ ] **Step 7: Commit**

```bash
git add test/presentation/screens/configuration_screen_test.dart
git commit -m "test: migrate configuration_screen_test to the shared bloc factories

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: Migrate `spell_creation_screen_test.dart`

**Files:**
- Modify: `test/presentation/screens/spell_creation_screen_test.dart:32-46, 125-128`

**Interfaces:**
- Consumes: `mockSpellCreationBloc`, `mockConfigurationBloc`, `registerBlocFallbackValues`.

Same pattern as Task 6, two blocs instead of one.

- [ ] **Step 1: Delete the local declarations**

Remove the `MockSpellCreationBloc` and `MockConfigurationBloc` class declarations (`:32-38`) and the four `Fake*` declarations (`:40-46`).

- [ ] **Step 2: Add the helper import**

```dart
import '../../support/bloc_factories.dart';
```

- [ ] **Step 3: Replace the fallback registration**

Replace the four `registerFallbackValue(...)` calls at `:125-128` with a single `registerBlocFallbackValues();` inside the same `setUpAll`. If that `setUpAll` does nothing else, reduce it to `setUpAll(registerBlocFallbackValues);`.

- [ ] **Step 4: Route construction through the factories**

Each construction-plus-`whenListen` pair collapses into one factory call. The three shapes you will meet, and what each becomes:

```dart
// BEFORE — construction and state wiring separated
final bloc = MockSpellCreationBloc();
whenListen(bloc, const Stream<SpellCreationState>.empty(),
    initialState: someState);

// AFTER
final bloc = mockSpellCreationBloc(initialState: someState);
```

```dart
// BEFORE — no explicit state, relying on the initial one
final configBloc = MockConfigurationBloc();
whenListen(configBloc, const Stream<ConfigurationState>.empty(),
    initialState: ConfigurationState.initial());

// AFTER — initial() is the factory's default
final configBloc = mockConfigurationBloc();
```

```dart
// BEFORE — a test driving a sequence of states
final bloc = MockSpellCreationBloc();
whenListen(bloc, Stream.fromIterable([stateA, stateB]),
    initialState: stateA);

// AFTER
final bloc = mockSpellCreationBloc(
  initialState: stateA,
  states: Stream.fromIterable([stateA, stateB]),
);
```

**Do not change which state any test uses.** Whatever a `whenListen` supplied, the factory call must supply the same. If a test asserts on a state you would have to invent, you have misread it — go back and re-read rather than substituting a default.

- [ ] **Step 5: Drop now-unused imports**

Remove whatever the analyzer flags — likely `bloc_test` and `mocktail`.

- [ ] **Step 6: Verify**

Run: `flutter analyze test/presentation/screens/spell_creation_screen_test.dart && flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: `No issues found!`, all tests passing, same count as before.

- [ ] **Step 7: Commit**

```bash
git add test/presentation/screens/spell_creation_screen_test.dart
git commit -m "test: migrate spell_creation_screen_test to the shared bloc factories

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: Migrate `spell_creation_screen_configuration_sync_test.dart`

**Files:**
- Modify: `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart:41-62`

**Interfaces:**
- Consumes: `mockSpellCreationBloc`, `mockConfigurationBloc`, `registerBlocFallbackValues`.

- [ ] **Step 1: Delete the local declarations**

Remove the `MockSpellCreationBloc` and `MockConfigurationBloc` declarations (`:41-47`) and the four `Fake*` declarations (`:49-55`).

- [ ] **Step 2: Add the helper import**

```dart
import '../../support/bloc_factories.dart';
```

- [ ] **Step 3: Replace the fallback registration**

Replace the four `registerFallbackValue(...)` calls at `:59-62` with `registerBlocFallbackValues();`.

- [ ] **Step 4: Route construction through the factories**

Each `Mock*Bloc()` plus its paired `whenListen` becomes one factory call carrying the same state:

```dart
// BEFORE
final bloc = MockSpellCreationBloc();
whenListen(bloc, const Stream<SpellCreationState>.empty(),
    initialState: someState);

// AFTER
final bloc = mockSpellCreationBloc(initialState: someState);
```

**This file's subject is configuration sync**, so it is the likeliest of the five to drive a *sequence* of states rather than one. Any such test keeps its stream, passed as `states:`:

```dart
// BEFORE
final configBloc = MockConfigurationBloc();
whenListen(configBloc, Stream.fromIterable([loading, loaded]),
    initialState: loading);

// AFTER
final configBloc = mockConfigurationBloc(
  initialState: loading,
  states: Stream.fromIterable([loading, loaded]),
);
```

Collapsing such a test to a bare `initialState` would delete exactly the behaviour it tests. Read each one before changing it.

- [ ] **Step 5: Drop now-unused imports**

- [ ] **Step 6: Verify**

Run: `flutter analyze test/presentation/screens/spell_creation_screen_configuration_sync_test.dart && flutter test test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`
Expected: `No issues found!`, all tests passing, same count as before.

- [ ] **Step 7: Commit**

```bash
git add test/presentation/screens/spell_creation_screen_configuration_sync_test.dart
git commit -m "test: migrate the configuration-sync screen test to the shared bloc factories

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 9: Migrate `spell_library_screen_test.dart` and `widget_test.dart`

**Files:**
- Modify: `test/presentation/screens/spell_library_screen_test.dart:27-39, 132-135`
- Modify: `test/widget_test.dart:26-49, 54-60, 91-100`

**Interfaces:**
- Consumes: all three mock factories and `registerBlocFallbackValues`.

These two are grouped because `widget_test.dart` carries the comment correction, which belongs in the same commit as its migration.

- [ ] **Step 1: Migrate `spell_library_screen_test.dart`**

Delete the `MockSpellLibraryBloc` / `MockSpellCreationBloc` declarations (`:27-31`) and the four `Fake*` declarations (`:33-39`). Add `import '../../support/bloc_factories.dart';`. Replace the four `registerFallbackValue(...)` calls at `:132-135` with `registerBlocFallbackValues();`. Route each construction through `mockSpellLibraryBloc(...)` / `mockSpellCreationBloc(...)`, carrying the same states. Drop unused imports.

- [ ] **Step 2: Verify that file**

Run: `flutter analyze test/presentation/screens/spell_library_screen_test.dart && flutter test test/presentation/screens/spell_library_screen_test.dart`
Expected: `No issues found!`, all tests passing, same count as before.

- [ ] **Step 3: Migrate `widget_test.dart`**

Delete the three `Mock*Bloc` declarations (`:26-33`) and six `Fake*` declarations (`:35-40`). Add `import 'support/bloc_factories.dart';` — **one level, not two**, since this file sits at `test/` root.

Replace the six `registerFallbackValue(...)` calls (`:44-49`) with `registerBlocFallbackValues();`, keeping the `sqfliteFfiInit()` and `databaseFactory` lines that follow them in the same `setUpAll`.

Replace `:91-100` — the three constructions plus their three `whenListen` calls — with:

```dart
    final spellCreationBloc = mockSpellCreationBloc();
    final spellLibraryBloc = mockSpellLibraryBloc();
    final configurationBloc = mockConfigurationBloc();
```

The factories' defaults are `SpellCreationState.initial()`, `SpellLibraryState.initial()` and `ConfigurationState.initial()` — exactly what those `whenListen` calls passed.

- [ ] **Step 4: Correct the false comment at `:54-60`**

This is Component 2's second half. Replace the comment block with:

```dart
  // The real AppDatabase (and the BackupService built on top of it) is opened
  // here in setUp/tearDown rather than inline in the testWidgets body. Real
  // async I/O awaited directly inside a testWidgets body hangs indefinitely,
  // because that body runs in a fake-async zone (confirmed: >90s with no
  // completion). setUp/tearDown run outside that zone, so real async work
  // there completes normally.
  //
  // This is NOT a Bloc limitation, though this comment used to say it was. A
  // real Bloc over a faked repository runs fine in a widget test -- see
  // test/support/bloc_factories.dart, which documents the rule and provides
  // factories for both cases.
```

- [ ] **Step 5: Verify both files**

Run: `flutter analyze test/widget_test.dart && flutter test test/widget_test.dart`
Expected: `No issues found!`, all tests passing.

- [ ] **Step 6: Commit**

```bash
git add test/presentation/screens/spell_library_screen_test.dart test/widget_test.dart
git commit -m "test: migrate the last two files, and correct the false-premise comment

widget_test.dart's setUp comment explained the real workaround and then
attributed it to a Bloc limitation that does not exist. Kept the accurate
half; the rest now points at the helper.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 10: Close item 6

**Files:**
- Modify: `.superpowers/todo.md:290-311` (item 6's checkboxes and its first bullet)

- [ ] **Step 1: Run everything, via the new runner**

Run: `dart run tool/run_all_tests.dart`
Expected: four `PASS` rows, exit 0.

**Record the Dart suite's test count.** It must read **661** — 660 before, plus Task 5's one new test. If it reads anything else, stop and find out which migrated file lost or gained a case before touching the todo. Do not update the todo against an unverified count.

- [ ] **Step 2: Tick the three boxes and correct the figure**

In item 6, change the three `- [ ]` boxes to `- [x]` and append what was done, matching the file's established style (each closed box states the outcome and what still binds):

```markdown
- [x] **Create a test helper with bloc factories — DONE 2026-08-17.**
      `test/support/bloc_factories.dart` provides both kinds: `mock*Bloc`
      factories that pair construction with `whenListen` (a bare `MockBloc`
      has a null state, and every call site used to repeat that pairing by
      hand), and `real*Bloc` factories over hand-written in-memory
      repository fakes. **Corrected: this said "nine test files" — it is
      five.** The nine came from a `mocktail|bloc_test` grep that swept up
      `configuration_bloc_test.dart` (imports `bloc_test`, hand-rolls
      nothing) and `spell_engine_test.dart` (matched only a comment naming
      another file). Seven if you count the two that hand-roll a repository
      mock — and **those two are deliberately not migrated**: both use
      mocktail for *error injection* (`thenThrow`), which an in-memory fake
      models worse, so the fakes carry no error hook.
- [x] **Document the resulting rule — DONE 2026-08-17.** It is the library
      dartdoc on `bloc_factories.dart`, so an author cannot reach a factory
      without passing the explanation of which one to pick. The false
      premise was also removed from `test/widget_test.dart`'s `setUp`
      comment, which had explained the real workaround and then attributed
      it to a Bloc limitation.
- [x] **One command running all suites — DONE 2026-08-17.**
      `dart run tool/run_all_tests.dart`. **Four steps, not three:**
      `flutter analyze` gates the Dart suite in CI, so a three-step runner
      could go green where CI would not. Every step runs even after one
      fails, so the summary answers "which suites actually ran". The device
      comes from `Platform.operatingSystem` rather than a hard-coded
      `windows`, so the Linux-runner experiment the workflow comments keep
      open does not need this file edited.
```

- [ ] **Step 3: Move item 6 to `## Completed ✅`**

Item 6 has no open boxes left. Per the file's own convention ("**Completed** holds closed items reduced to the decisions, constraints and gotchas that still bind"), move the whole section there, keeping its number and its ⚠️ correction block — that correction is the most valuable thing in the item and must survive the move.

Update its heading to `### 6. Widget-Test Coverage Hole — DONE 2026-08-17`.

- [ ] **Step 4: Update the suite table in *Where the import stands***

The Dart row reads **660 tests, green**. Change it to **661**, and leave the `Last updated` date at 2026-08-17.

- [ ] **Step 5: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close todo item 6

All three remaining boxes done. Two of the item's own claims were wrong and
are corrected on the way out: 'nine test files' was five, and the runner
needs four steps because CI gates on flutter analyze.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Verification (whole plan)

- [ ] `dart run tool/run_all_tests.dart` — four steps, all PASS, exit 0.
- [ ] Dart suite reads **661 tests** (660 + Task 5's one).
- [ ] `grep -rn "extends MockBloc" test/` returns **only** `test/support/bloc_factories.dart`.
- [ ] `grep -rn "registerFallbackValue" test/` returns only `bloc_factories.dart` and `test/bloc/spell_creation_bloc_test.dart:42` (which registers a `Spell`, not a bloc event, and is out of scope).
- [ ] `grep -rn "same category of issue documented for real Blocs" test/` returns nothing.
- [ ] `git log --oneline` shows one commit per task, none mixing a migration with a helper change.
