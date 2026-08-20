import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/services/backup_service.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/general_effect_formula.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/target_type.dart';
import 'package:eruditus/presentation/screens/about_screen.dart';
import 'package:eruditus/presentation/screens/backup_screen.dart';
import 'package:eruditus/presentation/screens/configuration_screen.dart';
import 'package:eruditus/presentation/screens/spell_creation_screen.dart';
import 'package:eruditus/presentation/screens/spell_library_screen.dart';
import 'package:eruditus/utils/constants.dart';

import '../support/bloc_factories.dart';
import '../support/pump_app.dart';

/// The pseudo-locale coverage guard (item 80, task 11).
///
/// `main.dart`'s `_MainTabView` is private, so this pumps each of the four
/// screens directly rather than the whole tab view -- reusing
/// `bloc_factories.dart`'s mocks, matching how every other screen test in
/// this repo already pumps them.
///
/// Chrome strings that must never survive a switch to the pseudo-locale.
///
/// If one of these is findable under `en_XA`, it is still a hardcoded literal.
///
/// ⚠️ Deliberately NOT listed, because they are rulebook content that stays
/// hardcoded by design (see Task 10 and item 80.3): the four realm values
/// 'Divine', 'Faerie', 'Infernal', 'Magic'. Adding any of these four here
/// would make this test fail on correct code.
///
/// The filter/category comparison keys 'All', 'Published', 'My Spells',
/// 'Range', 'Duration', 'Target' are a different case, and listing them here
/// IS safe: they appear as *values* being compared (e.g. a category filter's
/// internal key), never rendered as display `Text` under this pseudo-locale,
/// so pseudo-transforming the chrome that labels them does not touch these
/// literals at all. 'My Spells' already sat in this list, passing, which is
/// the proof -- a previous version of this comment claimed the opposite for
/// all six, which was simply false for at least that one.
const _mustNotSurvive = <String>[
  'Create Spell',
  'Save to Library',
  'Spell Library',
  'My Spells',
  'Export Backup to File',
  'Import Backup from File',
  'Add Custom Effect',
  'Add Custom Parameter',
  'Spell level',
  'Needs review',
  'Not declared',
  'Guideline level',
  'Container behaviour',
  // added as tasks 7-10 migrated far more than the plan originally tabulated
  'Modifiers',
  'Configuration',
  'Effects',
  'Parameters',
  'Requisites',
  'Adjustments',
  'Summary',
  'Find Similar Spells',
  // Verified as real additions during the final-review fix pass (MINOR 3):
  // each of these five is display text, and each disappears under the
  // pseudo-locale on correct code.
  'All',
  'Published',
  'Range',
  'Duration',
  'Target',
  // Item 79's About & Licences screen. Chrome only — see the assertion in
  // that screen's own testWidgets below for the content half.
  'About & Licences',
  'How eruditus is licensed',
  'Disclaimer of warranties',
  'No endorsement',
  'Open-source package licences',
  // Item 79 finding I4: these seven headings render inside the private
  // _Edition widget (plus Trademarks, rendered in the top-level Column but
  // missed by the same oversight) and were not covered above. All eight are
  // ARB chrome headings, not notice-body content, so they belong here.
  'Attribution',
  'Books used',
  'Creators',
  'Copyright',
  'Licence',
  'Source',
  'Modifications',
  'Trademarks',
];

/// Strings that SHOULD still render in English under the pseudo-locale.
///
/// These are the deliberate exclusions. Asserting them positively stops a
/// future change quietly migrating rulebook content into ARB — the failure
/// item 80.3 exists to prevent — and documents the boundary in executable form.
const _mustSurvive = <String>[
  'Divine',
  'Faerie',
  'Infernal',
  'Magic',
];

const _pseudoLocale = Locale('en', 'XA');

/// Runs the full [_mustNotSurvive] list against whatever is currently
/// pumped. Deliberately the *whole* list on every screen, not a per-screen
/// subset: a string absent from a given screen trivially passes there, and
/// this way a future regression is caught no matter which of the four
/// screens it lands on.
void _expectNoneSurvive(String screen) {
  for (final literal in _mustNotSurvive) {
    expect(find.text(literal), findsNothing,
        reason: '[$screen] "$literal" is still a hardcoded literal — move it '
            'to ARB. Do not remove this entry to make the test pass.');
  }
}

void main() {
  setUpAll(registerBlocFallbackValues);

  testWidgets(
    'spell creation screen: no chrome string survives, and the realm control '
    'still renders the four hardcoded realm values',
    (tester) async {
      // The screen is a lazily-built ListView; a tall surface keeps every
      // section (Requisites, Adjustments, Modifiers, Summary, Save…) in the
      // tree at once instead of needing a scroll per assertion. Same trick
      // spell_creation_screen_test.dart's useTallSurface uses.
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final rangeParam = Parameter(
        id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2,
        provenance: Provenance(
            source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      final durationParam = Parameter(
        id: 'duration-mom', name: 'Momentary', category: 'Duration', magnitude: 0,
        provenance: Provenance(
            source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      // Container-typed, so the draft below reaches _ContainerModeField
      // ("Container behaviour").
      final containerTarget = Parameter(
        id: 'target-boundary', name: 'Boundary', category: 'Target', magnitude: 8,
        targetType: TargetType.container,
        provenance: Provenance(
            source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      // General (baseLevel: null), so the draft reaches the "Guideline level"
      // field; declares an open realm slot, so it also reaches the realm
      // dropdown the _mustSurvive assertion needs.
      final generalRealmEffect = BaseEffect(
        id: 'revi-G1', technique: 'Rego', form: 'Vim',
        description: 'Ward against beings from one realm', baseLevel: null,
        openSlots: const [OpenSlotKind.realm],
        provenance: Provenance(
            source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
      );
      // An unrestricted scope (no technique/form/effectIds) applies to any
      // draft, so ModifiersSection renders non-empty and shows its heading.
      final wildcardModifier = Modifier(
        id: 'mod-1', name: 'Test Modifier',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(),
        options: [ModifierOption(id: 'opt-1', label: 'Option', magnitude: 1)],
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final bloc = mockSpellCreationBloc(
        initialState: SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(
            technique: 'Rego', form: 'Vim',
            baseEffect: generalRealmEffect,
            range: rangeParam, duration: durationParam, target: containerTarget,
            chosenBaseLevel: 20,
          ),
        ),
      );
      final configBloc = mockConfigurationBloc(
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [generalRealmEffect],
          parameters: [rangeParam, durationParam, containerTarget],
          modifiers: [wildcardModifier],
        ),
      );

      await pumpApp(
        tester,
        const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        providers: [
          BlocProvider<SpellCreationBloc>.value(value: bloc),
          BlocProvider<ConfigurationBloc>.value(value: configBloc),
        ],
        wrapInScaffold: false,
        locale: _pseudoLocale,
      );
      await tester.pumpAndSettle();

      _expectNoneSurvive('spell creation');

      // The realm dropdown's key is a ValueKey suffixed with the current
      // chosen realm (see spell_creation_screen_test.dart's findRealmField),
      // not a plain Key.
      final realmField = find.byWidgetPredicate((w) =>
          w is DropdownButtonFormField<String> &&
          (w.key as ValueKey).value.toString().startsWith('chosen-realm-field'));
      expect(realmField, findsOneWidget,
          reason: 'the realm control must actually be reachable, or the '
              '_mustSurvive assertion below is vacuous');

      // A closed DropdownButtonFormField only shows the *selected* value (none
      // is chosen here); the four realm options only enter the widget tree
      // once the menu is open.
      await tester.tap(realmField);
      await tester.pumpAndSettle();

      for (final realm in _mustSurvive) {
        expect(find.text(realm), findsWidgets,
            reason: '"$realm" is rulebook content (Task 10 / item 80.3) and '
                'must stay hardcoded English, not be migrated to ARB');
      }
    },
  );

  testWidgets(
    'spell library screen: no chrome string survives, including a flawed '
    'spell\'s "Needs review" chip',
    (tester) async {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final rangeParam = Parameter(
        id: 'p1', name: 'Voice', category: 'Range', magnitude: 0,
        provenance: Provenance(
            source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      final durationParam = Parameter(
        id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0,
        provenance: Provenance(
            source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      final targetParam = Parameter(
        id: 'p3', name: 'Individual', category: 'Target', magnitude: 0,
        provenance: Provenance(
            source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );

      // A requisite naming the spell's own Technique is what
      // validateSpellAgainstCatalog's check 3 rejects — the same fixture
      // shape spell_creation_screen_test.dart and spell_library_screen_test.dart
      // use to get a genuinely non-empty ResolvedSpell.problems.
      final flawedRecord = Spell(
        id: 'flawed-1', name: 'Flawed Ward', baseEffectId: effect.id,
        technique: 'Creo', form: 'Ignem',
        rangeId: rangeParam.id, durationId: durationParam.id, targetId: targetParam.id,
        requisites: const {'Creo': RequisiteKind.adding},
        summary: 'A test spell.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final flawed = ResolvedSpell(
          record: flawedRecord, baseEffect: effect,
          range: rangeParam, duration: durationParam, target: targetParam);
      expect(flawed.problems, isNotEmpty,
          reason: 'fixture sanity check: the spell must actually be flawed, '
              'or the Needs review chip below never renders');

      final bloc = mockSpellLibraryBloc(
        initialState: SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [flawed]),
      );

      await pumpApp(
        tester,
        const SpellLibraryScreen(),
        providers: [BlocProvider<SpellLibraryBloc>.value(value: bloc)],
        wrapInScaffold: false,
        locale: _pseudoLocale,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('needs-review-chip')), findsOneWidget,
          reason: 'the chip must actually be on screen, or the "Needs review" '
              'entry in _mustNotSurvive is checked against nothing');

      _expectNoneSurvive('spell library');
    },
  );

  testWidgets(
    'configuration screen: no chrome string survives, on either tab or '
    'either add-custom dialog',
    (tester) async {
      final bloc = mockConfigurationBloc(
        initialState: ConfigurationState(status: ConfigurationStatus.loaded, effects: const [], parameters: const []),
      );

      await pumpApp(
        tester,
        const ConfigurationScreen(),
        providers: [BlocProvider<ConfigurationBloc>.value(value: bloc)],
        wrapInScaffold: false,
        locale: _pseudoLocale,
      );
      await tester.pumpAndSettle();

      _expectNoneSurvive('configuration (effects tab)');

      await tester.tap(find.byKey(const Key('add-effect-button')));
      await tester.pumpAndSettle();
      _expectNoneSurvive('configuration (add-effect dialog)');
      // Dismiss via the barrier: showDialog defaults to barrierDismissible,
      // and the dialog's own Cancel button carries no Key to tap by, and its
      // label is pseudo-transformed under en_XA so it can't be found by text.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Can't switch tabs by tapping English label text under en_XA, so tap
      // the Tab widget itself by index.
      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();
      _expectNoneSurvive('configuration (parameters tab)');

      await tester.tap(find.byKey(const Key('add-parameter-button')));
      await tester.pumpAndSettle();
      _expectNoneSurvive('configuration (add-parameter dialog)');
    },
  );

  group('backup screen', () {
    // Real database, real BackupService -- mirrors backup_screen_test.dart's
    // own setUp/tearDown. Real async I/O belongs in setUp (which runs outside
    // the fake-async zone testWidgets bodies execute in), not inline in a
    // test body; see bloc_factories.dart's top-of-file note.
    late AppDatabase database;
    late BackupService backupService;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final resolver = SpellResolver(
        effects: await assetLoader.loadBaseEffects(),
        parameters: await assetLoader.loadParameters(),
        modifiers: await assetLoader.loadModifiers(),
      );
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      backupService = BackupService(
        spellRepository: SpellRepository(
          datasource: LocalSpellDatasource(database: database),
          resolver: resolver,
          configRepository: configRepository,
        ),
        configRepository: configRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('no chrome string survives', (tester) async {
      await pumpApp(
        tester,
        BackupScreen(
          backupService: backupService,
          exportJson: (json) async {},
          importJson: () async => null,
        ),
        wrapInScaffold: false,
        locale: _pseudoLocale,
      );
      await tester.pumpAndSettle();

      _expectNoneSurvive('backup');
    });
  });

  testWidgets(
    'about screen: no chrome string survives, and the licence notice still '
    'renders in English',
    (tester) async {
      await pumpApp(
        tester,
        const AboutScreen(),
        locale: _pseudoLocale,
        wrapInScaffold: false,
      );
      await tester.pumpAndSettle();

      _expectNoneSurvive('about');

      // The §3(a) notice is a deliberately-English population, the same
      // status as the four realm values in _mustSurvive: a licensor's
      // copyright line and creator credit are not ours to translate, and
      // routing them through ARB would hand a translator a legal notice to
      // reword. See DECISIONS.md, "Internationalisation", and item 79.
      expect(find.textContaining('Atlas Games'), findsWidgets,
          reason: 'licence content is deliberately not routed through ARB');
    },
  );
}
