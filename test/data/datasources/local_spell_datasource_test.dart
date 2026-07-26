import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/base_effect.dart';

Parameter _sp(String id, String name, String category) =>
    Parameter(id: id, name: name, category: category, magnitude: 0, source: 'built-in');

final _range = _sp('range-personal', 'Personal', 'Range');
final _duration = _sp('duration-momentary', 'Momentary', 'Duration');
final _target = _sp('target-individual', 'Individual', 'Target');

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late LocalSpellDatasource datasource;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    datasource = LocalSpellDatasource(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  Spell buildSpell(String id, {String? name}) => Spell(
        id: id,
        name: name,
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: 'e1',
          technique: 'Creo',
          form: 'Ignem',
          description: 'Create flame',
          baseLevel: 10,
          source: 'built-in',
        ),
        range: _range,
        duration: _duration,
        target: _target,
        requisites: const [],
        source: 'user-created',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('insertSpell then getSpellById returns the spell', () async {
    await datasource.insertSpell(buildSpell('1', name: 'My Fireball'));

    final retrieved = await datasource.getSpellById('1');

    expect(retrieved, isNotNull);
    expect(retrieved!.name, 'My Fireball');
    expect(retrieved.technique, 'Creo');
    expect(retrieved.baseEffect.baseLevel, 10);
  });

  test('getSpellById returns null for unknown id', () async {
    final retrieved = await datasource.getSpellById('does-not-exist');
    expect(retrieved, isNull);
  });

  test('getAllSpells returns all inserted spells', () async {
    await datasource.insertSpell(buildSpell('1', name: 'Spell One'));
    await datasource.insertSpell(buildSpell('2', name: 'Spell Two'));

    final all = await datasource.getAllSpells();

    expect(all.length, 2);
    expect(all.map((s) => s.id), containsAll(['1', '2']));
  });

  test('updateSpell persists changes', () async {
    await datasource.insertSpell(buildSpell('1', name: 'Original Name'));

    await datasource.updateSpell(buildSpell('1', name: 'Updated Name'));

    final retrieved = await datasource.getSpellById('1');
    expect(retrieved!.name, 'Updated Name');
  });

  test('deleteSpell removes the spell', () async {
    await datasource.insertSpell(buildSpell('1'));

    await datasource.deleteSpell('1');

    final retrieved = await datasource.getSpellById('1');
    expect(retrieved, isNull);
  });
}
