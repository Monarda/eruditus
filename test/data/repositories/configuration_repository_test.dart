import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

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
      description: 'My custom effect', baseLevel: 7,
      provenance: Provenance(source: PublicationSource.userCreated),
    ));

    final all = await repository.getAllEffects();

    expect(all.length, 609); // 608 built-in (10 Forms) + 1 custom
    expect(all.any((e) => e.id == 'custom-1'), isTrue);
  });

  test('deleteCustomEffect removes only the custom one', () async {
    await repository.addCustomEffect(BaseEffect(
      id: 'custom-1', technique: 'Creo', form: 'Ignem',
      description: 'test', baseLevel: 5,
      provenance: Provenance(source: PublicationSource.userCreated),
    ));

    await repository.deleteCustomEffect('custom-1');

    final all = await repository.getAllEffects();
    expect(all.length, 608);
  });

  test('getAllParameters combines built-in and custom parameters', () async {
    await repository.addCustomParameter(Parameter(
      id: 'custom-p1', name: 'Pair', category: 'Target', magnitude: 2,
      provenance: Provenance(source: PublicationSource.userCreated),
    ));

    final all = await repository.getAllParameters();

    expect(all.length, 35); // 34 built-in + 1 custom
  });

  test('getAllModifiers combines built-in and custom modifiers', () async {
    await repository.addCustomModifier(Modifier(
      id: 'custom-m1',
      name: 'House rule',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(form: 'Ignem'),
      options: [ModifierOption(id: 'custom-m1-a', label: 'A', magnitude: 1)],
      provenance: Provenance(source: PublicationSource.userCreated),
    ));

    final all = await repository.getAllModifiers();

    expect(all.any((m) => m.id == 'crim-complexity'), isTrue, reason: 'published');
    expect(all.any((m) => m.id == 'custom-m1'), isTrue, reason: 'custom');
  });
}
