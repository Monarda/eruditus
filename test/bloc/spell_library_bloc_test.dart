import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/selected_parameter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late LibraryRepository libraryRepository;
  // Built from the real, asset-loaded special factors (not an empty list):
  // several built-in library spells reference special factors by id, and
  // SpellEngine.calculateSpellLevel throws if a referenced id can't be
  // resolved, so an empty factors list would crash level computation for
  // those spells.
  late SpellEngine spellEngine;

  final rangeParam = Parameter(id: 'p1', name: 'Voice', category: 'Range', magnitude: 0, source: 'built-in');
  final durationParam = Parameter(id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in');
  final targetParam = Parameter(id: 'p3', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in');

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final spellRepository = SpellRepository(datasource: LocalSpellDatasource(database: database));
    await spellRepository.saveSpell(Spell(
      id: 'user-1', name: 'My Custom Fireball', technique: 'Creo', form: 'Ignem',
      baseEffect: BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 5, source: 'built-in',
      ),
      range: SelectedParameter(parameterId: 'p1', parameter: rangeParam),
      duration: SelectedParameter(parameterId: 'p2', parameter: durationParam),
      target: SelectedParameter(parameterId: 'p3', parameter: targetParam),
      selectedSpecialFactorIds: const [],
      requiredRequisites: const [], additionalRequisites: const [],
      source: 'user-created', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));
    libraryRepository = LibraryRepository(assetLoader: AssetDataLoader(), spellRepository: spellRepository);
    final specialFactors = await AssetDataLoader().loadSpecialFactors();
    spellEngine = SpellEngine(allSpells: const [], allSpecialFactors: specialFactors);
  });

  tearDown(() async {
    await database.close();
  });

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested loads all spells (27 built-in + 1 user)',
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) => bloc.add(const LibraryRequested()),
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.loading),
      isA<SpellLibraryState>()
          .having((s) => s.status, 'status', SpellLibraryStatus.loaded)
          .having((s) => s.allSpells.length, 'allSpells.length', 28)
          .having((s) => s.visibleSpells.length, 'visibleSpells.length', 28),
    ],
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested precomputes each spell\'s level via the shared SpellEngine, keyed by id',
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) => bloc.add(const LibraryRequested()),
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.loading),
      isA<SpellLibraryState>()
          .having((s) => s.status, 'status', SpellLibraryStatus.loaded)
          // 'user-1' has baseLevel 5 with no parameters/factors/requisites, so
          // its level is exactly the base level.
          .having((s) => s.spellLevels['user-1'], "spellLevels['user-1']", 5),
    ],
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested loads successfully even when a saved spell references a deleted special factor id',
    // Simulates: a user selected a custom special factor while creating a
    // spell, saved the spell (persisting the factor's id in
    // selectedSpecialFactorIds), then later deleted that custom factor in
    // the Settings tab. Deletion doesn't cascade to already-saved spells, so
    // this spell keeps a dangling id. Before the fix,
    // SpellEngine.calculateSpellLevel threw StateError for this id, and
    // because LibraryRequested wraps the whole load in one try/catch, that
    // single bad reference dropped the *entire* Library tab into its error
    // state, hiding every spell. It must instead load successfully.
    setUp: () async {
      final spellRepository = SpellRepository(datasource: LocalSpellDatasource(database: database));
      await spellRepository.saveSpell(Spell(
        id: 'user-dangling', name: 'Spell With Deleted Factor', technique: 'Creo', form: 'Ignem',
        baseEffect: BaseEffect(
          id: 'e2', technique: 'Creo', form: 'Ignem',
          description: 'test', baseLevel: 5, source: 'built-in',
        ),
        range: SelectedParameter(parameterId: 'p1', parameter: rangeParam),
        duration: SelectedParameter(parameterId: 'p2', parameter: durationParam),
        target: SelectedParameter(parameterId: 'p3', parameter: targetParam),
        selectedSpecialFactorIds: const ['no-longer-exists'],
        requiredRequisites: const [], additionalRequisites: const [],
        source: 'user-created', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      ));
    },
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) => bloc.add(const LibraryRequested()),
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.loading),
      isA<SpellLibraryState>()
          .having((s) => s.status, 'status', SpellLibraryStatus.loaded)
          .having((s) => s.allSpells.length, 'allSpells.length', 29)
          .having((s) => s.spellLevels['user-dangling'], "spellLevels['user-dangling']", 5),
    ],
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'FilterChanged to "My Spells" narrows visibleSpells to user-created only',
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const FilterChanged('My Spells'));
    },
    skip: 1,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>()
          .having((s) => s.status, 'status', SpellLibraryStatus.loaded)
          .having((s) => s.visibleSpells.length, 'visibleSpells.length', 28),
      isA<SpellLibraryState>()
          .having((s) => s.filter, 'filter', 'My Spells')
          .having((s) => s.visibleSpells.length, 'visibleSpells.length', 1)
          .having((s) => s.visibleSpells.single.id, 'visibleSpells.single.id', 'user-1'),
    ],
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'SearchQueryChanged narrows visibleSpells by name, case-insensitively',
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const SearchQueryChanged('fireball'));
    },
    skip: 1,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>(),
      isA<SpellLibraryState>()
          .having((s) => s.query, 'query', 'fireball')
          .having((s) => s.visibleSpells.length, 'visibleSpells.length', 1)
          .having((s) => s.visibleSpells.single.id, 'visibleSpells.single.id', 'user-1'),
    ],
  );
}
