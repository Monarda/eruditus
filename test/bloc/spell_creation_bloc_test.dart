import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
import 'package:eruditus/models/special_factor.dart';
import 'package:eruditus/models/spell.dart';

class MockSpellRepository extends Mock implements SpellRepository {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(Spell(
      id: 'fallback', technique: 'Creo', form: 'Ignem',
      baseEffect: BaseEffect(
        id: 'fb', technique: 'Creo', form: 'Ignem',
        description: 'fallback', baseLevel: 1, source: 'built-in',
      ),
      parameters: const [], selectedSpecialFactorIds: const [],
      requiredRequisites: const [], additionalRequisites: const [],
      source: 'user-created', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));
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
    'SpellCalculated precomputes a level for each suggestion, keyed by spell id',
    build: () {
      final suggestion = Spell(
        id: 'suggestion-1', name: 'Pillar of Fire', technique: 'Creo', form: 'Ignem',
        baseEffect: creoIgnemEffect,
        parameters: const [], selectedSpecialFactorIds: const [],
        requiredRequisites: const [], additionalRequisites: const [],
        source: 'built-in', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      return SpellCreationBloc(
        spellEngine: SpellEngine(allSpells: [suggestion], allSpecialFactors: const []),
        spellRepository: spellRepository,
      );
    },
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const SpellCalculated());
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          .having((s) => s.suggestions.map((sp) => sp.id), 'suggestions ids', ['suggestion-1'])
          .having((s) => s.suggestionLevels['suggestion-1'], 'suggestionLevels[suggestion-1]', 10),
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
    'SpellSaveRequested resets to a fresh, empty draft after a successful save',
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
          .having((s) => s.draft.technique, 'draft.technique (reset)', isNull)
          .having((s) => s.draft.form, 'draft.form (reset)', isNull)
          .having((s) => s.draft.baseEffect, 'draft.baseEffect (reset)', isNull),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // Regression test for the pre-fix crash: the old handler had no
    // try/catch and always reused the same draft.id across saves, so a
    // second SpellSaveRequested hit sqflite's UNIQUE constraint (default
    // ConflictAlgorithm.abort) and threw, uncaught, straight out of the bloc.
    // Post-fix, a successful save resets to a fresh draft (new id), so
    // filling in and saving a second spell inserts a second, independent
    // row instead of colliding -- and this test would fail with an unhandled
    // exception if that were not the case.
    'save, then fill in and save again: both persist as distinct spells with no thrown error',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) async {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const SpellSaveRequested('First Spell'));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      bloc.add(const TechniqueSelected('Rego'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(BaseEffect(
        id: 'e2', technique: 'Rego', form: 'Ignem',
        description: 'Redirect flame', baseLevel: 5, source: 'built-in',
      )));
      bloc.add(const SpellSaveRequested('Second Spell'));
    },
    wait: const Duration(milliseconds: 300),
    verify: (_) async {
      final saved = await spellRepository.getAllUserSpells();
      expect(saved.length, 2);
      expect(saved.map((s) => s.name), containsAll(['First Spell', 'Second Spell']));
      expect(saved.map((s) => s.id).toSet().length, 2); // distinct ids, no collision
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellSaveRequested emits an error status (not a thrown exception) when the repository fails',
    build: () {
      final repo = MockSpellRepository();
      when(() => repo.saveSpell(any())).thenThrow(Exception('disk full'));
      return SpellCreationBloc(spellEngine: spellEngine, spellRepository: repo);
    },
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const SpellSaveRequested('Doomed Spell'));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', contains('disk full'))
          // The in-progress draft is preserved (not reset) on failure, so the
          // user doesn't lose their work and can retry.
          .having((s) => s.draft.technique, 'draft.technique (preserved)', 'Creo'),
    ],
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

  blocTest<SpellCreationBloc, SpellCreationState>(
    // All events go through a single on<SpellCreationEvent>() handler with a
    // sequential (asyncExpand) transformer, so a synchronous SpellDiscarded
    // dispatched right behind an async SpellSaveRequested cannot race ahead
    // of it -- it is guaranteed to be processed only after the save's saving
    // -> saved emissions have both landed. This exercises the exact
    // save/discard interleaving Issue 4 was concerned about.
    'SpellDiscarded dispatched immediately after SpellSaveRequested is processed strictly after '
    'the save completes, never racing ahead of it',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const SpellSaveRequested('Raced Spell'));
      bloc.add(const SpellDiscarded());
    },
    skip: 3,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.saved)
          .having((s) => s.savedSpell?.name, 'savedSpell.name', 'Raced Spell'),
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.initial),
    ],
    verify: (_) async {
      final saved = await spellRepository.getAllUserSpells();
      expect(saved.length, 1);
      expect(saved.first.name, 'Raced Spell');
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'AvailableFactorsSynced updates the SpellEngine so a newly available special '
    'factor resolves during SpellCalculated instead of throwing',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(allSpells: const [], allSpecialFactors: const []),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      final newFactor = SpecialFactor(
        id: 'custom-1', technique: 'Creo', form: 'Ignem',
        name: 'Custom Complexity', description: 'A custom factor',
        magnitude: 3, source: 'user-created',
      );
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(AvailableFactorsSynced([newFactor]));
      bloc.add(const SpecialFactorToggled('custom-1', true));
      bloc.add(const SpellCalculated());
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.selectedSpecialFactorIds, 'selectedSpecialFactorIds', ['custom-1']),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          // Base 10 already exceeds the additive-tier cap of 5, so the
          // factor's +3 magnitude falls entirely in the multiplier tier:
          // 10 + (3 * 5) = 25.
          .having((s) => s.calculatedLevel, 'calculatedLevel', 25),
    ],
  );
}
