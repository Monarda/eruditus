import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late ConfigurationRepository repository;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = ConfigurationRepository(
      assetLoader: AssetDataLoader(),
      configDatasource: LocalConfigurationDatasource(database: database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('getAllEffects combines built-in and custom effects', () async {
    await repository.addCustomEffect(BaseEffect(
      id: 'custom-1', technique: 'Creo', form: 'Ignem',
      description: 'My custom effect', baseLevel: 7, source: 'user-created',
    ));

    final all = await repository.getAllEffects();

    expect(all.length, 404); // 403 built-in (5 Forms) + 1 custom
    expect(all.any((e) => e.id == 'custom-1'), isTrue);
  });

  test('deleteCustomEffect removes only the custom one', () async {
    await repository.addCustomEffect(BaseEffect(
      id: 'custom-1', technique: 'Creo', form: 'Ignem',
      description: 'test', baseLevel: 5, source: 'user-created',
    ));

    await repository.deleteCustomEffect('custom-1');

    final all = await repository.getAllEffects();
    expect(all.length, 403);
  });

  test('getAllParameters combines built-in and custom parameters', () async {
    await repository.addCustomParameter(Parameter(
      id: 'custom-p1', name: 'Pair', category: 'Target', magnitude: 2, source: 'user-created',
    ));

    final all = await repository.getAllParameters();

    expect(all.length, 18); // 17 built-in + 1 custom
  });

  test('getAllSpecialFactors combines built-in and custom factors', () async {
    await repository.addCustomFactor(SpecialFactor(
      id: 'custom-f1', technique: 'Creo', form: 'Ignem',
      name: 'My Factor', description: 'test', magnitude: 1, source: 'user-created',
    ));

    final all = await repository.getAllSpecialFactors();

    expect(all.length, 8); // 7 built-in + 1 custom
  });
}
