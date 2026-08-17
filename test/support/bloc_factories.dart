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
