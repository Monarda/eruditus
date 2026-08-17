import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/spell.dart';

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
        baseEffectId: 'e1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'range-personal',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const {},
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('insertSpell then getSpellById returns the spell', () async {
    await datasource.insertSpell(buildSpell('1', name: 'My Fireball'));

    final retrieved = await datasource.getSpellById('1');

    expect(retrieved, isNotNull);
    expect(retrieved!.name, 'My Fireball');
    expect(retrieved.baseEffectId, 'e1');
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
