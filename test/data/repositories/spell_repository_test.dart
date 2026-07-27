import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
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
  late SpellRepository repository;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final assetLoader = AssetDataLoader();
    final resolver = SpellResolver(
      effects: await assetLoader.loadBaseEffects(),
      parameters: await assetLoader.loadParameters(),
    );
    repository = SpellRepository(
        datasource: LocalSpellDatasource(database: database), resolver: resolver);
  });

  tearDown(() async {
    await database.close();
  });

  Spell buildSpell(String id, {String? name}) => Spell(
        id: id,
        name: name,
        baseEffectId: 'e1',
        rangeId: 'range-personal',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        source: 'user-created',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('saveSpell then getSpellById returns it', () async {
    await repository.saveSpell(buildSpell('1', name: 'My Fireball'));

    final retrieved = await repository.getSpellById('1');

    expect(retrieved?.name, 'My Fireball');
  });

  test('getAllUserSpells returns all saved spells', () async {
    await repository.saveSpell(buildSpell('1', name: 'One'));
    await repository.saveSpell(buildSpell('2', name: 'Two'));

    final all = await repository.getAllUserSpells();

    expect(all.length, 2);
  });

  test('updateSpell persists changes', () async {
    await repository.saveSpell(buildSpell('1', name: 'Original'));

    await repository.updateSpell(buildSpell('1', name: 'Updated'));

    final retrieved = await repository.getSpellById('1');
    expect(retrieved?.name, 'Updated');
  });

  test('deleteSpell removes it', () async {
    await repository.saveSpell(buildSpell('1'));

    await repository.deleteSpell('1');

    expect(await repository.getSpellById('1'), isNull);
  });
}
