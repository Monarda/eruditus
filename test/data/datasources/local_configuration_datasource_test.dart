import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';
import 'package:eruditus/models/modifier.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late LocalConfigurationDatasource datasource;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    datasource = LocalConfigurationDatasource(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('custom effects', () {
    test('insertCustomEffect then getAllCustomEffects returns it', () async {
      final effect = BaseEffect(
        id: 'ce1', technique: 'Creo', form: 'Ignem',
        description: 'My custom fire effect', baseLevel: 8, source: 'user-created',
      );

      await datasource.insertCustomEffect(effect);
      final all = await datasource.getAllCustomEffects();

      expect(all.length, 1);
      expect(all.first.description, 'My custom fire effect');
      expect(all.first.baseLevel, 8);
    });

    test('deleteCustomEffect removes it', () async {
      final effect = BaseEffect(
        id: 'ce1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 5, source: 'user-created',
      );
      await datasource.insertCustomEffect(effect);

      await datasource.deleteCustomEffect('ce1');

      final all = await datasource.getAllCustomEffects();
      expect(all, isEmpty);
    });
  });

  group('custom parameters', () {
    test('insertCustomParameter then getAllCustomParameters returns it', () async {
      final parameter = Parameter(
        id: 'cp1', name: 'Pair', category: 'Target', magnitude: 2, source: 'user-created',
      );

      await datasource.insertCustomParameter(parameter);
      final all = await datasource.getAllCustomParameters();

      expect(all.length, 1);
      expect(all.first.name, 'Pair');
      expect(all.first.magnitude, 2);
    });

    test('deleteCustomParameter removes it', () async {
      final parameter = Parameter(
        id: 'cp1', name: 'Pair', category: 'Target', magnitude: 2, source: 'user-created',
      );
      await datasource.insertCustomParameter(parameter);

      await datasource.deleteCustomParameter('cp1');

      final all = await datasource.getAllCustomParameters();
      expect(all, isEmpty);
    });
  });

  group('custom special factors', () {
    test('insertCustomFactor then getAllCustomFactors returns it', () async {
      final factor = SpecialFactor(
        id: 'cf1', technique: 'Creo', form: 'Ignem',
        name: 'My Custom Factor', description: 'test factor', magnitude: 1, source: 'user-created',
      );

      await datasource.insertCustomFactor(factor);
      final all = await datasource.getAllCustomFactors();

      expect(all.length, 1);
      expect(all.first.name, 'My Custom Factor');
    });

    test('deleteCustomFactor removes it', () async {
      final factor = SpecialFactor(
        id: 'cf1', technique: 'Creo', form: 'Ignem',
        name: 'test', description: 'test', magnitude: 1, source: 'user-created',
      );
      await datasource.insertCustomFactor(factor);

      await datasource.deleteCustomFactor('cf1');

      final all = await datasource.getAllCustomFactors();
      expect(all, isEmpty);
    });
  });

  test('custom modifiers round-trip through the database', () async {
    final modifier = Modifier(
      id: 'custom-m1',
      name: 'House size rule',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(form: 'Terram'),
      options: [ModifierOption(id: 'custom-m1-big', label: 'Big', magnitude: 2)],
      source: 'user-created',
    );

    await datasource.insertCustomModifier(modifier);
    final all = await datasource.getAllCustomModifiers();

    expect(all.length, 1);
    expect(all.first.id, 'custom-m1');
    expect(all.first.scope.form, 'Terram');
    expect(all.first.optionById('custom-m1-big')?.magnitude, 2);

    await datasource.deleteCustomModifier('custom-m1');
    expect(await datasource.getAllCustomModifiers(), isEmpty);
  });
}
