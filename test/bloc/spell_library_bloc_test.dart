import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_template.dart';
import 'package:eruditus/models/parameter.dart';

class MockLibraryRepository extends Mock implements LibraryRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late LibraryRepository libraryRepository;
  late SpellEngine spellEngine;
  late SpellResolver resolver;
  late int builtInCount;

  final rangeParam = Parameter(
      id: 'p1', name: 'Voice', category: 'Range', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final durationParam = Parameter(
      id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final targetParam = Parameter(
      id: 'p3', name: 'Individual', category: 'Target', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final effect1 = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'test', baseLevel: 5,
    provenance: Provenance(source: PublicationSource.userCreated),
  );
  final effect2 = BaseEffect(
    id: 'e2', technique: 'Creo', form: 'Ignem',
    description: 'test', baseLevel: 5,
    provenance: Provenance(source: PublicationSource.userCreated),
  );
  final ritualDurationParam = Parameter(
      id: 'p4', name: 'Year', category: 'Duration', magnitude: 0, requiresRitual: true,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

  final mockLibraryRepository = MockLibraryRepository();

  final ritualSpell = ResolvedSpell(
    record: Spell(
      id: 'ritual-1',
      name: 'Wizard\'s Sidestep',
      baseEffectId: 'e1',
      rangeId: 'p1',
      durationId: 'p4',
      targetId: 'p3',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    baseEffect: effect1,
    range: rangeParam,
    duration: ritualDurationParam,
    target: targetParam,
  );
  // Base 5 with a -5 adjustment: five steps down from level 5 lands on 0,
  // which is below both 1 and where it started, so it has no level at all.
  // Reachable before this fix by tapping the creation screen's unbounded
  // decrement button, since saving never ran the calculator.
  final uncomputableSpell = ResolvedSpell(
    record: Spell(
      id: 'uncomputable-1',
      name: 'Over-Discounted Spell',
      baseEffectId: 'e1',
      rangeId: 'p1',
      durationId: 'p2',
      targetId: 'p3',
      requisites: const [],
      adjustments: [LevelAdjustment(magnitude: -5, note: 'far too generous')],
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    baseEffect: effect1,
    range: rangeParam,
    duration: durationParam,
    target: targetParam,
  );
  final ordinarySpell = ResolvedSpell(
    record: Spell(
      id: 'ordinary-1',
      name: 'Ordinary Spell',
      baseEffectId: 'e1',
      rangeId: 'p1',
      durationId: 'p2',
      targetId: 'p3',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    baseEffect: effect1,
    range: rangeParam,
    duration: durationParam,
    target: targetParam,
  );

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    // Deliberately a small local fixture catalog (2 effects, 3 parameters)
    // rather than the real AssetDataLoader catalog. This means when
    // libraryRepository.getBuiltInSpells() resolves the real built-in
    // library spells against this resolver below, almost none of them
    // resolve — only spells built on ids from this narrow set (the fixture
    // Spells this file saves itself, e.g. `user-1`/`user-dangling`) come back
    // resolved. `allSpells.length` doesn't care either way: every Spell
    // (resolved or not) still appears in the list. But `spellLevels` is keyed
    // only by resolved spells' ids (see SpellLibraryBloc._onEvent), so the
    // `spellLevels['user-1']`/`spellLevels['user-dangling']` assertions below
    // work only because those particular fixtures were deliberately built
    // with ids from this narrow catalog — none of the real built-ins are
    // expected to contribute a spellLevels entry here.
    resolver = SpellResolver(
      effects: [effect1, effect2],
      parameters: [rangeParam, durationParam, targetParam],
      modifiers: const [],
    );
    // Derived, not a literal — the built-in count is generator output now
    // (see AssetDataLoaderTest's identically-motivated fix) and changes
    // every time the published-spell-import pipeline is re-run.
    builtInCount = (await AssetDataLoader().loadSpellLibrary()).length;
    final configRepository = ConfigurationRepository(
      assetLoader: AssetDataLoader(),
      configDatasource: LocalConfigurationDatasource(database: database),
    );
    // SpellRepository.saveSpell refreshes the shared resolver from
    // configRepository before validating. Registering e1/e2/p1/p2/p3 as
    // custom entries here keeps them resolvable through that refresh —
    // otherwise the refresh would swap this file's deliberately narrow
    // fixture catalog (see the comment above) for the real one, which
    // doesn't contain these ids, and the spellLevels assertions below would
    // find 'user-1'/'user-dangling' unresolved instead of level 5. The real
    // catalog also gets merged in alongside them, so built-in library
    // spells now resolve too — harmless here since nothing asserts an
    // exhaustive spellLevels map, only specific keys.
    await configRepository.addCustomEffect(effect1);
    await configRepository.addCustomEffect(effect2);
    await configRepository.addCustomParameter(rangeParam);
    await configRepository.addCustomParameter(durationParam);
    await configRepository.addCustomParameter(targetParam);
    final spellRepository = SpellRepository(
      datasource: LocalSpellDatasource(database: database),
      resolver: resolver,
      configRepository: configRepository,
    );
    await spellRepository.saveSpell(Spell(
      id: 'user-1',
      name: 'My Custom Fireball',
      baseEffectId: 'e1',
      rangeId: 'p1',
      durationId: 'p2',
      targetId: 'p3',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));
    libraryRepository = LibraryRepository(
        assetLoader: AssetDataLoader(), spellRepository: spellRepository, resolver: resolver);
    spellEngine = SpellEngine(allSpells: const []);
  });

  tearDown(() async {
    await database.close();
  });

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested loads all spells (built-in + 1 user)',
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) => bloc.add(const LibraryRequested()),
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.loading),
      isA<SpellLibraryState>()
          .having((s) => s.status, 'status', SpellLibraryStatus.loaded)
          .having((s) => s.allSpells.length, 'allSpells.length', builtInCount + 1)
          .having((s) => s.visibleSpells.length, 'visibleSpells.length', builtInCount + 1),
    ],
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested precomputes each spell\'s level via the shared SpellEngine, keyed by id',
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) => bloc.add(const LibraryRequested()),
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.loading),
      isA<SpellLibraryState>()
          .having((s) => s.status, 'status', SpellLibraryStatus.loaded)
          // 'user-1' has baseLevel 5 with no parameters/factors/requisites, so
          // its level is exactly the base level.
          .having((s) => s.spellLevels['user-1'], "spellLevels['user-1']", 5),
    ],
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested loads successfully even when a saved spell references a deleted modifier id',
    // Simulates: a user selected a custom modifier option while creating a
    // spell, saved the spell (persisting the modifier's id in
    // selectedModifiers), then later deleted that custom modifier in the
    // Settings tab. Deletion doesn't cascade to already-saved spells, so
    // this spell keeps a dangling id. SpellEngine.calculateSpellLevel must
    // not throw for this id — the spell has to keep its real level 5, not
    // merely survive as the level-less row an uncomputable spell degrades to
    // (see 'one uncomputable spell does not take the whole library down').
    setUp: () async {
      // Same database as the outer setUp, which already registered e1/e2 as
      // custom effects — this configRepository sees them too.
      final configRepository = ConfigurationRepository(
        assetLoader: AssetDataLoader(),
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      await spellRepository.saveSpell(Spell(
        id: 'user-dangling',
        name: 'Spell With Deleted Modifier',
        baseEffectId: 'e2',
        rangeId: 'p1',
        durationId: 'p2',
        targetId: 'p3',
        selectedModifiers: const {
          'no-longer-exists': ['no-longer-exists'],
        },
        requisites: const [],
        provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      ));
    },
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) => bloc.add(const LibraryRequested()),
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.loading),
      isA<SpellLibraryState>()
          .having((s) => s.status, 'status', SpellLibraryStatus.loaded)
          .having((s) => s.allSpells.length, 'allSpells.length', builtInCount + 2)
          .having((s) => s.spellLevels['user-dangling'], "spellLevels['user-dangling']", 5),
    ],
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested marks Year-duration spells as Rituals',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells())
          .thenAnswer((_) async => [ritualSpell, ordinarySpell]);
      // Unstubbed otherwise: mocktail throws on the call, the handler's catch
      // swallows it, and the bloc lands in `error` instead of `loaded` — see
      // Correction 3.
      when(() => mockLibraryRepository.getTemplates()).thenAnswer((_) async => []);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) => bloc.add(const LibraryRequested()),
    verify: (bloc) {
      expect(bloc.state.ritualSpellIds, contains(ritualSpell.id));
      expect(bloc.state.ritualSpellIds, isNot(contains(ordinarySpell.id)));
    },
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'one uncomputable spell does not take the whole library down',
    // A spell saved with adjustments that drive it below level 1 has no
    // computable level, and calculateBreakdown throws for it. With one try
    // around the whole loop that single row put the Library tab into its
    // error state on every launch — and since the tab was the only way to
    // reach the spell, there was no in-app way to delete it. It must degrade
    // to one level-less row instead, with every other spell intact.
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells())
          .thenAnswer((_) async => [ritualSpell, uncomputableSpell, ordinarySpell]);
      when(() => mockLibraryRepository.getTemplates()).thenAnswer((_) async => []);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) => bloc.add(const LibraryRequested()),
    verify: (bloc) {
      expect(bloc.state.status, SpellLibraryStatus.loaded);
      expect(bloc.state.allSpells.length, 3);
      // The good rows keep their levels; the bad one is simply absent from
      // spellLevels, exactly as an unresolved spell is, and SpellCard renders
      // that as "Creo Ignem" with no level.
      expect(bloc.state.spellLevels[ordinarySpell.id], 5);
      expect(bloc.state.spellLevels[ritualSpell.id], isNotNull);
      expect(bloc.state.spellLevels.containsKey(uncomputableSpell.id), isFalse);
    },
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'FilterChanged to "My Spells" narrows visibleSpells to user-created only',
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const FilterChanged('My Spells'));
    },
    skip: 1,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>()
          .having((s) => s.status, 'status', SpellLibraryStatus.loaded)
          .having((s) => s.visibleSpells.length, 'visibleSpells.length', builtInCount + 1),
      isA<SpellLibraryState>()
          .having((s) => s.filter, 'filter', 'My Spells')
          .having((s) => s.visibleSpells.length, 'visibleSpells.length', 1)
          .having((s) => s.visibleSpells.single.id, 'visibleSpells.single.id', 'user-1'),
    ],
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'SearchQueryChanged narrows visibleSpells by name, case-insensitively',
    build: () => SpellLibraryBloc(
      libraryRepository: libraryRepository,
      spellEngine: spellEngine,
    ),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const SearchQueryChanged('fireball'));
    },
    skip: 1,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellLibraryState>(),
      isA<SpellLibraryState>()
          .having((s) => s.query, 'query', 'fireball')
          .having((s) => s.visibleSpells.length, 'visibleSpells.length', 1)
          .having((s) => s.visibleSpells.single.id, 'visibleSpells.single.id', 'user-1'),
    ],
  );

  // Template fixtures for the templates/visibleTemplates tests below. Built by
  // hand rather than loaded from the asset file — see Correction 4: a bloc
  // test must not depend on the asset file's contents.
  final templateRecordA = SpellTemplate(
    id: 'tpl-a',
    name: 'Template Alpha',
    baseEffectId: 'e1',
    rangeId: 'p1',
    durationId: 'p2',
    targetId: 'p3',
    description: 'Alpha template',
    provenance: Provenance(
        source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
  );
  final templateRecordB = SpellTemplate(
    id: 'tpl-b',
    name: 'Template Beta',
    baseEffectId: 'e2',
    rangeId: 'p1',
    durationId: 'p2',
    targetId: 'p3',
    description: 'Beta template',
    provenance: Provenance(
        source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
  );
  final templateA = ResolvedTemplate(
      record: templateRecordA,
      baseEffect: effect1,
      range: rangeParam,
      duration: durationParam,
      target: targetParam);
  final templateB = ResolvedTemplate(
      record: templateRecordB,
      baseEffect: effect2,
      range: rangeParam,
      duration: durationParam,
      target: targetParam);

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested populates templates with every template the repository returns',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates())
          .thenAnswer((_) async => [templateA, templateB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) => bloc.add(const LibraryRequested()),
    verify: (bloc) {
      expect(bloc.state.status, SpellLibraryStatus.loaded);
      expect(bloc.state.templates, [templateA, templateB]);
    },
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'templates survives a subsequent SearchQueryChanged and FilterChanged',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates())
          .thenAnswer((_) async => [templateA, templateB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const SearchQueryChanged('alpha'));
      bloc.add(const FilterChanged('Published'));
    },
    wait: const Duration(milliseconds: 300),
    verify: (bloc) {
      // Neither copyWith call named `templates`, so it must have been
      // carried forward from the load rather than reset to the default [].
      expect(bloc.state.templates, [templateA, templateB]);
    },
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'visibleTemplates includes every template under the "All" filter',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates())
          .thenAnswer((_) async => [templateA, templateB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) => bloc.add(const LibraryRequested()),
    verify: (bloc) => expect(bloc.state.visibleTemplates.length, 2),
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'visibleTemplates includes every template under the "Published" filter',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates())
          .thenAnswer((_) async => [templateA, templateB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const FilterChanged('Published'));
    },
    wait: const Duration(milliseconds: 300),
    verify: (bloc) => expect(bloc.state.visibleTemplates.length, 2),
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    // A template is published catalog data and can never be one of the
    // user's own spells -- same rule visibleSpells follows for "My Spells".
    'visibleTemplates is empty under the "My Spells" filter',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates())
          .thenAnswer((_) async => [templateA, templateB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const FilterChanged('My Spells'));
    },
    wait: const Duration(milliseconds: 300),
    verify: (bloc) => expect(bloc.state.visibleTemplates, isEmpty),
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'visibleTemplates narrows by name under a query, case-insensitively',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates())
          .thenAnswer((_) async => [templateA, templateB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const SearchQueryChanged('alpha'));
    },
    wait: const Duration(milliseconds: 300),
    verify: (bloc) {
      expect(bloc.state.visibleTemplates.length, 1);
      expect(bloc.state.visibleTemplates.single.id, 'tpl-a');
    },
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'a repository that throws from getTemplates puts the bloc in error, like any other load failure',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates()).thenThrow(Exception('boom'));
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) => bloc.add(const LibraryRequested()),
    expect: () => [
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.loading),
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.error),
    ],
  );
}
