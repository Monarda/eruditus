import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late SpellRepository spellRepository;
  late SpellEngine spellEngine;

  final creoIgnemEffect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'Create flame', baseLevel: 10, source: 'built-in',
  );
  final voiceParam = Parameter(id: 'p1', name: 'Voice', category: 'Range', magnitude: 2, source: 'built-in');

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    spellRepository = SpellRepository(datasource: LocalSpellDatasource(database: database));
    spellEngine = SpellEngine(allSpells: const [], allSpecialFactors: const []);
  });

  tearDown(() async {
    await database.close();
  });

  blocTest<SpellCreationBloc, SpellCreationState>(
    'emits editing state with technique set when TechniqueSelected is added',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc.add(const TechniqueSelected('Creo')),
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having((s) => s.draft.technique, 'draft.technique', 'Creo'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated emits validation errors when draft is incomplete',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc.add(const SpellCalculated()),
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having((s) => s.validationErrors, 'validationErrors', isNotEmpty),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated emits calculated level and no errors when draft is valid',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(ParameterAdded(voiceParam));
      bloc.add(const SpellCalculated());
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having((s) => s.draft.parameters.length, 'draft.parameters.length', 1),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          .having((s) => s.calculatedLevel, 'calculatedLevel', 20) // Base10 + Voice(+2)*5
          .having((s) => s.validationErrors, 'validationErrors', isEmpty),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellSaveRequested saves the spell and emits saving then saved',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const SpellSaveRequested('My Fireball'));
    },
    skip: 3,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.saved)
          .having((s) => s.savedSpell?.name, 'savedSpell.name', 'My Fireball'),
    ],
    verify: (_) async {
      final saved = await spellRepository.getAllUserSpells();
      expect(saved.length, 1);
      expect(saved.first.name, 'My Fireball');
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'TechniqueSelected clears a previously selected baseEffect',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const TechniqueSelected('Rego'));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.technique, 'draft.technique', 'Rego')
          .having((s) => s.draft.baseEffect, 'draft.baseEffect', isNull),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'FormSelected clears a previously selected baseEffect',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const FormSelected('Corpus'));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.form, 'draft.form', 'Corpus')
          .having((s) => s.draft.baseEffect, 'draft.baseEffect', isNull),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellDiscarded resets to a fresh initial state',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const SpellDiscarded());
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.initial),
    ],
  );
}
