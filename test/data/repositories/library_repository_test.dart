import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';

SelectedParameter _sp(String id, String name, String category) => SelectedParameter(
      parameterId: id,
      parameter: Parameter(
          id: id, name: name, category: category, magnitude: 0, source: 'built-in'),
    );

final _range = _sp('range-personal', 'Personal', 'Range');
final _duration = _sp('duration-momentary', 'Momentary', 'Duration');
final _target = _sp('target-individual', 'Individual', 'Target');

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
    spellRepository = SpellRepository(datasource: LocalSpellDatasource(database: database));
    repository = LibraryRepository(assetLoader: AssetDataLoader(), spellRepository: spellRepository);
  });

  tearDown(() async {
    await database.close();
  });

  test('getBuiltInSpells returns all 27 built-in library spells', () async {
    final builtIn = await repository.getBuiltInSpells();
    expect(builtIn.length, 27);
    expect(builtIn.every((s) => s.source == 'built-in'), isTrue);
  });

  test('getAllSpells combines built-in and user spells', () async {
    await spellRepository.saveSpell(Spell(
      id: 'user-1', name: 'My Custom Spell', technique: 'Creo', form: 'Ignem',
      baseEffect: BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 5, source: 'built-in',
      ),
      range: _range, duration: _duration, target: _target,
      selectedSpecialFactorIds: const [],
      requisites: const [],
      source: 'user-created', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));

    final all = await repository.getAllSpells();

    expect(all.length, 28); // 27 built-in + 1 user
    expect(all.any((s) => s.id == 'user-1'), isTrue);
  });

  test('searchSpells filters by name, case-insensitively', () async {
    final results = await repository.searchSpells('phantasm');
    expect(results, isNotEmpty);
    expect(results.every((s) => s.name!.toLowerCase().contains('phantasm')), isTrue);
  });

  test('filterBySource returns only matching-source spells', () async {
    await spellRepository.saveSpell(Spell(
      id: 'user-1', name: 'Mine', technique: 'Creo', form: 'Ignem',
      baseEffect: BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 5, source: 'built-in',
      ),
      range: _range, duration: _duration, target: _target,
      selectedSpecialFactorIds: const [],
      requisites: const [],
      source: 'user-created', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));

    final userSpells = await repository.filterBySource('user-created');

    expect(userSpells.length, 1);
    expect(userSpells.first.id, 'user-1');
  });
}
