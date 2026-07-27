import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/spell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late LibraryRepository repository;
  late SpellRepository spellRepository;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final assetLoader = AssetDataLoader();
    final resolver = SpellResolver(
      effects: await assetLoader.loadBaseEffects(),
      parameters: await assetLoader.loadParameters(),
    );
    spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database), resolver: resolver);
    repository = LibraryRepository(
        assetLoader: assetLoader, spellRepository: spellRepository, resolver: resolver);
  });

  tearDown(() async {
    await database.close();
  });

  test('getBuiltInSpells returns all 30 built-in library spells', () async {
    final builtIn = await repository.getBuiltInSpells();
    expect(builtIn.length, 30);
    expect(builtIn.every((s) => s.source == 'built-in'), isTrue);
  });

  test('getAllSpells combines built-in and user spells', () async {
    await spellRepository.saveSpell(Spell(
      id: 'user-1',
      name: 'My Custom Spell',
      baseEffectId: 'e1',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      source: 'user-created', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));

    final all = await repository.getAllSpells();

    expect(all.length, 31); // 30 built-in + 1 user
    expect(all.any((s) => s.id == 'user-1'), isTrue);
  });

  test('searchSpells filters by name, case-insensitively', () async {
    final results = await repository.searchSpells('phantasm');
    expect(results, isNotEmpty);
    expect(results.every((s) => s.name!.toLowerCase().contains('phantasm')), isTrue);
  });

  test('filterBySource returns only matching-source spells', () async {
    await spellRepository.saveSpell(Spell(
      id: 'user-1',
      name: 'Mine',
      baseEffectId: 'e1',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      source: 'user-created', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));

    final userSpells = await repository.filterBySource('user-created');

    expect(userSpells.length, 1);
    expect(userSpells.first.id, 'user-1');
  });
}
