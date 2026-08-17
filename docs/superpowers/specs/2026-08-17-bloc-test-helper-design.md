# Bloc Test Factories, the Fake-Async Rule, and an All-Suites Runner — Design

**Date:** 2026-08-17
**Status:** Approved for planning
**Closes:** todo item 6 (its three remaining open boxes)

## Goal

Three things item 6 still owes, which share one root cause:

1. A test helper offering bloc factories of **both** kinds — mocked blocs for
   state-driven assertions, and **real blocs with faked repositories** for
   anything asserting a rebuild.
2. The rule that governs the choice, documented where a test author meets it.
3. One command running every suite, so "tests pass" means all of them.

## The Correction This Rests On

Item 6 was opened believing *"a real Bloc hangs forever under `flutter_tester`;
known Bloc limitation."* **That is false and does not reproduce.** A real
`SpellCreationBloc` with only `SpellRepository` mocked, dispatching
`TechniqueSelected` and rebuilding a `BlocBuilder`, passes in under a second
including `pumpAndSettle`.

The accurate diagnosis is **real async I/O awaited directly inside a
`testWidgets` body**, because that body runs in a fake-async zone. A Bloc is an
event handler; it hangs only if it awaits real I/O, and faking the *repository*
removes that.

This matters to the design rather than merely to the record: the false premise
concluded that re-render coverage had to move to `integration_test/`. It does
not. A real bloc over a faked repository re-renders in a plain widget test at
widget-test speed, which is what makes this helper worth having at all.

## Measured Starting State

Verified 2026-08-17 by reading the files, correcting item 6's own figure.

| What | Count | Files |
|---|---|---|
| Hand-rolled `MockBloc` subclass + `registerFallbackValue` | **5** | `widget_test.dart`, `presentation/screens/configuration_screen_test.dart`, `.../spell_creation_screen_test.dart`, `.../spell_creation_screen_configuration_sync_test.dart`, `.../spell_library_screen_test.dart` |
| Hand-rolled `Mock implements <Repository>` | 2 | `bloc/spell_creation_bloc_test.dart`, `bloc/spell_library_bloc_test.dart` |
| Neither — swept up by the original grep | 2 | `bloc/configuration_bloc_test.dart` (imports `bloc_test`, hand-rolls nothing), `engine/spell_engine_test.dart` (matched only a comment naming another test file) |

**Item 6's "nine test files" figure is therefore wrong**; it counted a
`mocktail|bloc_test` grep. The real number is 5, or 7 counting repository mocks.

Two existing patterns the design follows rather than replaces:

- `configuration_bloc_test.dart` and `backup_screen_test.dart` already build
  **real** objects over a real in-memory `AppDatabase` opened in `setUp`. The
  real-bloc half of this helper is that pattern with the I/O removed, not a new
  idea.
- Constructor surfaces confirmed: `SpellEngine({required allSpells,
  allModifiers = const [], allParameters = const []})` constructs synchronously,
  and the three repositories are concrete classes whose only non-public members
  are private — so a Dart `implements` fake owes just the public methods plus
  the injected fields.

## Component 1 — `test/support/bloc_factories.dart`

One file, no `_test.dart` suffix, so the runner does not collect it.

### Mock blocs

`MockSpellCreationBloc`, `MockSpellLibraryBloc`, `MockConfigurationBloc` defined
once, plus `registerBlocFallbackValues()` — idempotent, collapsing the six
`registerFallbackValue` calls the 5 files each repeat into one `setUpAll` line.

### Mock factories

```dart
MockSpellCreationBloc mockSpellCreationBloc({
  SpellCreationState? initialState,
  Stream<SpellCreationState>? states,
});
```

…and siblings for library and configuration. Each constructs the mock **and**
wires `whenListen` with a sane default initial state. Every call site today
repeats that pairing by hand, and omitting it produces a null-state crash rather
than a useful failure. The optional `states` parameter is the documented
`StreamController` escape hatch, so a test driving states through a mock does
not hand-roll one.

### In-memory fakes

`FakeSpellRepository` (backed by a `Map<String, Spell>`), `FakeLibraryRepository`
and `FakeConfigurationRepository` (settable lists). Each `implements` its
concrete repository. The injected fields — `datasource`, `resolver`,
`configRepository`, `assetLoader` — are overridden as getters that throw
`UnsupportedError` naming the fake and saying it replaces behaviour, not
plumbing. A test reaching for real internals then fails loudly instead of
mysteriously.

No stubbing, no `when()`, no fallback registration on this path. That is the
point: the boilerplate item 6 objects to is *removed*, not relocated.

### Real-bloc factories

```dart
SpellCreationBloc realSpellCreationBloc({
  FakeSpellRepository? spells,
  SpellEngine? engine,
});
```

…and siblings, defaulting to a fresh fake and `SpellEngine(allSpells: const [])`.
**Fully synchronous** — a test body constructs one with no `await`, which is
exactly the property that keeps it inside the fake-async zone safely.

## Component 2 — The Rule, as Library Dartdoc

The rule lives as a library-level dartdoc comment on `bloc_factories.dart`. An
author cannot reach a factory without passing the explanation of which one to
pick. It states:

- **The rule: don't await real I/O in a test body** — *not* "don't use real
  blocs." The body runs in a fake-async zone.
- **Corollary 1:** `setUp`/`tearDown` run outside that zone, so real async work
  there completes normally. This is why `widget_test.dart` opens its real
  `AppDatabase` in `setUp`.
- **Corollary 2:** `tester.runAsync` is the documented escape hatch from inside
  the zone. It appears nowhere in this repo today.
- **Which factory:** mocks for state-driven assertions; **real bloc + faked
  repository whenever the failure mode is "what happens on re-render"**, because
  a mock emits no new state and so the rebuild never happens. Cites the
  add-requisite `DropdownButtonFormField` crash, invisible to 6 passing widget
  tests for exactly this reason.

### A correction to make in the tree

`test/widget_test.dart:54-60` currently explains the `setUp` workaround
correctly and then attributes it to *"the same category of issue documented for
real Blocs."* That half is the false premise. It keeps its accurate first half
and gains a pointer to the helper. Leaving it would teach the wrong rule at the
exact spot a test author looks.

## Component 3 — `tool/run_all_tests.dart`

Run as `dart run tool/run_all_tests.dart`. Matches the repo's one precedent for
tooling (`tool/setup_web.dart`) and needs no new toolchain.

It mirrors CI's four steps, in CI's order:

| Step | Command |
|---|---|
| Analyze | `flutter analyze` |
| Import harness | `uv run --no-project python -m unittest discover -s scripts/spell_import/tests -t .` |
| Dart suite | `flutter test` |
| Integration suite | `flutter test integration_test -d <device>` |

**Four, not three.** `flutter analyze` gates the Dart suite in
`.github/workflows/tests.yml`, so a runner omitting it can go green where CI
would not.

**Device from `Platform.operatingSystem`** (`windows` today), so the same
command survives the Linux-runner experiment the workflow comments keep
deliberately open.

**Every step runs even after a failure**, then a per-step summary prints and the
process exits non-zero if any failed. Stopping at the first failure would hide
precisely the "which suites actually ran" question this item exists to answer.

**Two deliberate deviations from CI, both commented in the script:**

- The Python invocation uses `-t .`, which is what CI runs — *not* the
  `-p "test_*.py"` form item 6 quotes.
- It calls Python through `uv run --no-project`, this machine's convention,
  where CI uses bare `python` under `actions/setup-python`.

`ARS_RULEBOOK_ROOT` is not set by the script. CI sets it because it clones the
rulebook to a temp path; locally the default sibling-checkout discovery applies,
and the ambient environment passes through.

## Component 4 — Migration

The 5 files drop their local `Mock*`/`Fake*` classes and `registerFallbackValue`
blocks in favour of helper imports. **Behaviour-preserving: no assertion
changes.** The 2 repository-mock files are migrated to the fakes as well, since
that is what the fakes are for.

Then item 6's three boxes are ticked and its "nine test files" figure is
corrected to five, with a line recording where the nine came from.

## Testing

The helper is test infrastructure, so its verification is the suites it serves:

1. **The full runner passes** — all four steps green. This is also the first
   real exercise of Component 3.
2. **Test count does not drop.** The Dart suite stands at 660 today, so it must
   read **661** after this lands: migration is mechanical and must not silently
   delete a case, and item 3 below adds exactly one.
3. **One new test proving the capability**, not merely the plumbing: a real
   `SpellCreationBloc` over a `FakeSpellRepository`, dispatching an event and
   asserting the widget tree **rebuilt**. Without it the "real bloc" half is
   asserted only by the dartdoc claiming it works.

## Out of Scope

- **Converting existing mocked-bloc tests into real-bloc tests.** That changes
  what those 5 files assert. Item 6 asks for the capability and the documented
  rule, not a re-litigation of their coverage.
- **The empty `test/presentation/widgets/` directory** and the widget-test title
  that promises more than it asserts — that is item 23.
- **Moving the integration job to Linux.** The workflow comments call that a
  deliberate experiment to run on a branch and watch go green; the runner's
  per-platform device selection merely stops hard-coding against it.
