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
///
/// Deliberately does no validation either: the real [SpellRepository] refuses
/// an invalid spell (`InvalidSpellException` from `saveSpell`, a rejects list
/// from `saveAll`), and this fake always writes. A test whose subject is
/// *rejection* wants the real repository built in `setUp`, or a mocktail mock.
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
