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

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final spellRepository = SpellRepository(datasource: LocalSpellDatasource(database: database));
    await spellRepository.saveSpell(Spell(
      id: 'user-1', name: 'My Custom Fireball', technique: 'Creo', form: 'Ignem',
      baseEffect: BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 5, source: 'built-in',
      ),
      parameters: const [], selectedSpecialFactorIds: const [],
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
