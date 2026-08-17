import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/services/backup_service.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late SpellRepository spellRepository;
  late ConfigurationRepository configRepository;
  late BackupService service;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final assetLoader = AssetDataLoader();
    final resolver = SpellResolver(
      effects: await assetLoader.loadBaseEffects(),
      parameters: await assetLoader.loadParameters(),
      modifiers: await assetLoader.loadModifiers(),
    );
    configRepository = ConfigurationRepository(
      assetLoader: assetLoader,
      configDatasource: LocalConfigurationDatasource(database: database),
    );
    spellRepository = SpellRepository(
      datasource: LocalSpellDatasource(database: database),
      resolver: resolver,
      configRepository: configRepository,
    );
    service = BackupService(spellRepository: spellRepository, configRepository: configRepository);
  });

  tearDown(() async {
    await database.close();
  });

  Spell buildSpell(String id, {required String baseEffectId, int? chosenBaseLevel}) => Spell(
        id: id,
        name: id,
        baseEffectId: baseEffectId,
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'range-touch',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const {},
        chosenBaseLevel: chosenBaseLevel,
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Spell validSpell(String id) => buildSpell(id, baseEffectId: 'crig-10a');

  /// Invalid: a General guideline with no level supplied (check 1).
  Spell generalSpellWithNoChosenLevel(String id) =>
      buildSpell(id, baseEffectId: 'revi-G1');

  Spell spellOnCustomEffect(String id, String effectId) =>
      buildSpell(id, baseEffectId: effectId);

  BaseEffect customEffect(String id) => BaseEffect(
        id: id,
        technique: 'Creo',
        form: 'Ignem',
        description: 'A custom effect',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
      );

  test('exportToJson includes only user-created spells and custom config, with version and date', () async {
    await spellRepository.saveSpell(Spell(
      id: 'user-1',
      name: 'My Fireball',
      baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const {},
      summary: 'Conjures a bolt of flame.',
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));
    await configRepository.addCustomEffect(BaseEffect(
      id: 'custom-1', technique: 'Creo', form: 'Ignem',
      description: 'Custom', baseLevel: 3,
      provenance: Provenance(source: PublicationSource.userCreated),
    ));

    final jsonString = await service.exportToJson();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    expect(data['version'], '5.0');
    expect(data['exportDate'], isNotNull);
    expect((data['spells'] as List).length, 1);
    expect((data['spells'] as List).first['name'], 'My Fireball');
    expect((data['customEffects'] as List).length, 1);
    expect((data['customEffects'] as List).first['id'], 'custom-1');
  });

  test('importFromJson restores spells and custom effects', () async {
    final importedSpell = Spell(
      id: 'imported-1',
      name: 'Imported Spell',
      baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const {},
      summary: 'A spell restored from a backup file.',
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final backup = {
      'version': '5.0',
      'exportDate': DateTime.now().toIso8601String(),
      'spells': [importedSpell.toMap()],
      'customEffects': [
        BaseEffect(
          id: 'custom-2', technique: 'Muto', form: 'Corpus',
          description: 'Imported effect', baseLevel: 4,
          provenance: Provenance(source: PublicationSource.userCreated),
        ).toMap(),
      ],
      'customParameters': [],
    };

    final result = await service.importFromJson(jsonEncode(backup));

    expect(result.spellsImported, 1);
    expect(result.effectsImported, 1);

    final spells = await spellRepository.getAllUserSpells();
    expect(spells.any((s) => s.id == 'imported-1'), isTrue);

    final effects = await configRepository.getAllEffects();
    expect(effects.any((e) => e.id == 'custom-2'), isTrue);
  });

  test('importFromJson is idempotent — importing the same backup twice does not throw or duplicate', () async {
    final importedSpell = Spell(
      id: 'imported-1',
      name: 'Imported Spell',
      baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const {},
      summary: 'A spell restored from a backup file.',
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final jsonString = jsonEncode({
      'version': '5.0',
      'exportDate': DateTime.now().toIso8601String(),
      'spells': [importedSpell.toMap()],
      'customEffects': [],
      'customParameters': [],
    });

    await service.importFromJson(jsonString);
    await service.importFromJson(jsonString);

    final spells = await spellRepository.getAllUserSpells();
    expect(spells.where((s) => s.id == 'imported-1').length, 1);
  });

  test('importFromJson throws FormatException for malformed JSON', () {
    expect(
      () => service.importFromJson('not valid json{{{'),
      throwsFormatException,
    );
  });

  test('importFromJson throws FormatException for an unsupported version', () {
    final backup = jsonEncode({'version': '99.0', 'spells': []});
    expect(
      () => service.importFromJson(backup),
      throwsFormatException,
    );
  });

  test('export/import round-trips ritualDeclaration', () async {
    final spell = Spell(
      id: 'ritual-1', name: 'Touch of Midas',
      baseEffectId: 'crte-15a',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'range-touch',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const {},
      ritualDeclaration: RitualDeclaration.lastingCreation,
      summary: 'Transmutes base metal into gold.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026), updatedAt: DateTime(2026),
    );

    final restored = Spell.fromMap(spell.toMap());

    expect(restored.ritualDeclaration, RitualDeclaration.lastingCreation);
  });

  test('a spell with a chosen level and template link survives a round trip', () async {
    // Deliberately calls through BackupService rather than re-testing
    // serialization: todo item 7 records that the existing backup round-trip
    // test duplicates spell_test.dart and never exercises the service at all.
    // Templates are NOT covered — they are read-only published asset data,
    // like spell_library.json, which no backup carries.
    const wardSpellId = 'ward-1';
    Spell wardSpell({required int chosenBaseLevel, required String templateId}) => Spell(
          id: wardSpellId,
          name: 'Ward Against Beasts of Legend',
          baseEffectId: 'rean-gen',
          technique: 'Rego',
          form: 'Animal',
          rangeId: 'range-touch',
          durationId: 'duration-ring',
          targetId: 'target-circle',
          requisites: const {},
          summary: 'Wards a circle against beasts of legend.',
          provenance: Provenance(source: PublicationSource.userCreated),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          chosenBaseLevel: chosenBaseLevel,
          chosenSlots: const {'realm': 'Magic'},
          templateId: templateId,
        );

    await spellRepository.saveSpell(wardSpell(
        chosenBaseLevel: 20,
        templateId: 'tpl-rean-ward-against-beasts-of-legend'));

    await service.importFromJson(await service.exportToJson());

    final restored = (await spellRepository.getAllUserSpells())
        .firstWhere((s) => s.record.id == wardSpellId);

    expect(restored.record.chosenBaseLevel, 20);
    expect(restored.record.templateId, 'tpl-rean-ward-against-beasts-of-legend');
  });

  test('a spell built on a custom effect from the same backup imports', () async {
    // Regression: spells were written before the custom effects they depend
    // on, so this spell used to be validated against a catalog missing its
    // own effect.
    final json = jsonEncode({
      'version': '5.0',
      'exportDate': DateTime.now().toIso8601String(),
      'spells': [spellOnCustomEffect('s1', 'custom-1').toMap()],
      'customEffects': [customEffect('custom-1').toMap()],
      'customParameters': <Map<String, dynamic>>[],
    });

    final result = await service.importFromJson(json);

    expect(result.spellsImported, 1);
    expect(result.rejectedSpells, isEmpty);
  });

  test('an invalid spell is skipped and reported, and the good ones still land', () async {
    final json = jsonEncode({
      'version': '5.0',
      'exportDate': DateTime.now().toIso8601String(),
      'spells': [
        validSpell('good-1').toMap(),
        generalSpellWithNoChosenLevel('bad-1').toMap(),
        validSpell('good-2').toMap(),
      ],
      'customEffects': <Map<String, dynamic>>[],
      'customParameters': <Map<String, dynamic>>[],
    });

    final result = await service.importFromJson(json);

    expect(result.spellsImported, 2);
    expect(result.rejectedSpells.map((e) => e.spellId), ['bad-1']);
    expect(await spellRepository.getSpellById('good-2'), isNotNull);
  });

  test('round-trip through the real service preserves a valid spell', () async {
    // Closes todo item 7's coverage hole: the old round-trip test duplicated
    // spell_test.dart's serialization test and never called the service.
    await spellRepository.saveSpell(validSpell('rt-1'));

    final exported = await service.exportToJson();
    await spellRepository.deleteSpell('rt-1');
    final result = await service.importFromJson(exported);

    expect(result.spellsImported, 1);
    expect(await spellRepository.getSpellById('rt-1'), isNotNull);
  });
}
