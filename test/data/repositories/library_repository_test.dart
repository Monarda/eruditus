import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
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
  late LibraryRepository repository;
  late SpellRepository spellRepository;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final assetLoader = AssetDataLoader();
    final resolver = SpellResolver(
      effects: await assetLoader.loadBaseEffects(),
      parameters: await assetLoader.loadParameters(),
    );
    spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database), resolver: resolver);
    repository = LibraryRepository(
        assetLoader: assetLoader, spellRepository: spellRepository, resolver: resolver);
  });

  tearDown(() async {
    await database.close();
  });

  test('getBuiltInSpells returns all 36 built-in library spells', () async {
    final builtIn = await repository.getBuiltInSpells();
    expect(builtIn.length, 36);
    expect(builtIn.every((s) => s.source == PublicationSource.published), isTrue);
  });

  test('getAllSpells combines built-in and user spells', () async {
    await spellRepository.saveSpell(Spell(
      id: 'user-1',
      name: 'My Custom Spell',
      baseEffectId: 'e1',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));

    final all = await repository.getAllSpells();

    expect(all.length, 37); // 36 built-in + 1 user
    expect(all.any((s) => s.id == 'user-1'), isTrue);
  });

  test('searchSpells filters by name, case-insensitively', () async {
    final results = await repository.searchSpells('phantasm');
    expect(results, isNotEmpty);
    expect(results.every((s) => s.name!.toLowerCase().contains('phantasm')), isTrue);
  });

  test('filterBySource returns only matching-source spells', () async {
    await spellRepository.saveSpell(Spell(
      id: 'user-1',
      name: 'Mine',
      baseEffectId: 'e1',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));

    final userSpells = await repository.filterBySource(PublicationSource.userCreated);

    expect(userSpells.length, 1);
    expect(userSpells.first.id, 'user-1');
  });

  // Task 3's headline fix: LibraryRepository refreshes its resolver's catalog
  // snapshot from ConfigurationRepository on every getAllSpells() call (see
  // _refreshResolver), so a spell picks up catalog changes made after the
  // resolver was first built — including a deletion, which must flip a
  // previously-resolved spell to unresolved on the very next load. This is
  // only exercised when configRepository is actually supplied (its null
  // check short-circuits _refreshResolver otherwise), which the other tests
  // in this file deliberately don't do. The equivalent behaviour is also
  // covered by integration_test/spell_creation_flow_test.dart's 4th test,
  // but `flutter test` does not run integration_test/ by default, so this
  // unit test is what actually exercises the refresh path in CI/local runs.
  test(
    'getAllSpells re-resolves against the current catalog: a spell becomes '
    'unresolved after its custom effect is deleted',
    () async {
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
      );
      final spellRepositoryWithConfig = SpellRepository(
          datasource: LocalSpellDatasource(database: database), resolver: resolver);
      final repositoryWithConfig = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepositoryWithConfig,
        resolver: resolver,
        configRepository: configRepository,
      );

      final customEffect = BaseEffect(
        id: 'custom-refresh-effect',
        technique: 'Creo',
        form: 'Ignem',
        description: 'A custom effect for the refresh test',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      await configRepository.addCustomEffect(customEffect);

      await spellRepositoryWithConfig.saveSpell(Spell(
        id: 'spell-on-custom-effect',
        name: 'Spell On Custom Effect',
        baseEffectId: customEffect.id,
        rangeId: 'range-personal',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

      final beforeDeletion = await repositoryWithConfig.getAllSpells();
      final beforeSpell = beforeDeletion.firstWhere((s) => s.id == 'spell-on-custom-effect');
      expect(beforeSpell.isResolved, isTrue);

      await configRepository.deleteCustomEffect(customEffect.id);

      final afterDeletion = await repositoryWithConfig.getAllSpells();
      final afterSpell = afterDeletion.firstWhere((s) => s.id == 'spell-on-custom-effect');
      expect(afterSpell.isResolved, isFalse);
    },
  );
}
