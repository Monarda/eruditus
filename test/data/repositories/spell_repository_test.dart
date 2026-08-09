import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/invalid_spell_exception.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/spell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late ConfigurationRepository configRepository;
  late SpellRepository repository;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final assetLoader = AssetDataLoader();
    configRepository = ConfigurationRepository(
      assetLoader: assetLoader,
      configDatasource: LocalConfigurationDatasource(database: database),
    );
    final resolver = SpellResolver(
      effects: await configRepository.getAllEffects(),
      parameters: await configRepository.getAllParameters(),
      modifiers: await configRepository.getAllModifiers(),
    );
    repository = SpellRepository(
      datasource: LocalSpellDatasource(database: database),
      resolver: resolver,
      configRepository: configRepository,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Spell buildSpell(
    String id, {
    String? name,
    String baseEffectId = 'crig-10a',
    Map<String, List<String>> selectedModifiers = const {},
  }) =>
      Spell(
        id: id,
        name: name,
        baseEffectId: baseEffectId,
        rangeId: 'range-touch',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        selectedModifiers: selectedModifiers,
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  BaseEffect customEffect(String id) => BaseEffect(
        id: id,
        technique: 'Creo',
        form: 'Ignem',
        description: 'A custom effect',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
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

  test('saveSpell rejects a General spell with no chosen level', () async {
    final spell = buildSpell('bad-1', baseEffectId: 'revi-G1'); // a real General id

    expect(
      () => repository.saveSpell(spell),
      throwsA(isA<InvalidSpellException>().having(
        (e) => e.problems, 'problems',
        contains('Choose a level for this General guideline'),
      )),
    );
  });

  test('saveSpell rejects two options on a single-selection modifier', () async {
    final spell = buildSpell(
      'bad-3',
      selectedModifiers: {
        'size-ignem': ['size-ignem-1', 'size-ignem-2'],
      },
    );

    expect(
      () => repository.saveSpell(spell),
      throwsA(isA<InvalidSpellException>().having(
        (e) => e.problems, 'problems',
        contains('Only one option may be selected for Size'),
      )),
    );
  });

  test('a rejected spell is not written', () async {
    final spell = buildSpell('bad-2', baseEffectId: 'revi-G1');

    try {
      await repository.saveSpell(spell);
    } on InvalidSpellException {
      // expected
    }

    expect(await repository.getSpellById('bad-2'), isNull);
  });

  test('saveSpell accepts a valid spell', () async {
    await repository.saveSpell(buildSpell('good-1'));
    expect(await repository.getSpellById('good-1'), isNotNull);
  });

  test('updateSpell rejects an invalid spell too', () async {
    await repository.saveSpell(buildSpell('good-2'));

    expect(
      () => repository.updateSpell(
        buildSpell('good-2', baseEffectId: 'revi-G1'),
      ),
      throwsA(isA<InvalidSpellException>()),
    );
  });

  test('a spell built on a just-added custom effect saves without a Library visit', () async {
    // The staleness case: SpellRepository refreshes for itself rather than
    // waiting for LibraryRepository to do it on a Library tab visit.
    await configRepository.addCustomEffect(customEffect('custom-1'));

    await repository.saveSpell(buildSpell('good-3', baseEffectId: 'custom-1'));

    expect(await repository.getSpellById('good-3'), isNotNull);
  });
}
