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
  late BackupService backupService;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final assetLoader = AssetDataLoader();
    final resolver = SpellResolver(
      effects: await assetLoader.loadBaseEffects(),
      parameters: await assetLoader.loadParameters(),
    );
    spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database), resolver: resolver);
    configRepository = ConfigurationRepository(
      assetLoader: assetLoader,
      configDatasource: LocalConfigurationDatasource(database: database),
    );
    backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);
  });

  tearDown(() async {
    await database.close();
  });

  test('exportToJson includes only user-created spells and custom config, with version and date', () async {
    await spellRepository.saveSpell(Spell(
      id: 'user-1',
      name: 'My Fireball',
      baseEffectId: 'e1',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));
    await configRepository.addCustomEffect(BaseEffect(
      id: 'custom-1', technique: 'Creo', form: 'Ignem',
      description: 'Custom', baseLevel: 3,
      provenance: Provenance(source: PublicationSource.userCreated),
    ));

    final jsonString = await backupService.exportToJson();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    expect(data['version'], '2.0');
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
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final backup = {
      'version': '2.0',
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

    final result = await backupService.importFromJson(jsonEncode(backup));

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
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final jsonString = jsonEncode({
      'version': '2.0',
      'exportDate': DateTime.now().toIso8601String(),
      'spells': [importedSpell.toMap()],
      'customEffects': [],
      'customParameters': [],
    });

    await backupService.importFromJson(jsonString);
    await backupService.importFromJson(jsonString);

    final spells = await spellRepository.getAllUserSpells();
    expect(spells.where((s) => s.id == 'imported-1').length, 1);
  });

  test('importFromJson throws FormatException for malformed JSON', () {
    expect(
      () => backupService.importFromJson('not valid json{{{'),
      throwsFormatException,
    );
  });

  test('importFromJson throws FormatException for an unsupported version', () {
    final backup = jsonEncode({'version': '99.0', 'spells': []});
    expect(
      () => backupService.importFromJson(backup),
      throwsFormatException,
    );
  });
}
