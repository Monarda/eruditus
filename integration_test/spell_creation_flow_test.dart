import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/services/backup_service.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/main.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/presentation/screens/spell_library_screen.dart';

/// Switches to the Library tab and lets the transition settle. Used by the
/// ward-template test below, which needs to reach the "Learn at level…"
/// button; factored out as its own helper rather than inlined, matching
/// selectTechniqueAndForm/selectBaseEffect below.
Future<void> openLibraryTab(WidgetTester tester) async {
  await tester.tap(find.text('Library'));
  await tester.pumpAndSettle();
}

/// Picks a Technique then a Form from their dropdowns, in the four-tap
/// sequence (open, choose, open, choose) every existing test in this file
/// already repeats inline. Factored out for the General-level-field test
/// below rather than inlined a sixth time.
Future<void> selectTechniqueAndForm(
    WidgetTester tester, String technique, String form) async {
  await tester.tap(find.byKey(const Key('technique-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(technique).last);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('form-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(form).last);
  await tester.pumpAndSettle();
}

/// Picks a base effect by matching a substring of its rendered description,
/// since the dropdown has no id-based lookup available to a widget test —
/// items render as '${description} (${General or Base N})'
/// (spell_creation_screen.dart).
Future<void> selectBaseEffect(WidgetTester tester, String descriptionSubstring) async {
  await tester.tap(find.byKey(const Key('base-effect-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(descriptionSubstring).last);
  await tester.pumpAndSettle();
}

/// The spell creation screen's own Scrollable.
///
/// `scrollUntilVisible` with no `scrollable:` requires exactly one Scrollable
/// in the tree, and every TextField builds one -- so the always-present
/// summary field makes the bare form ambiguous. Using .first ensures we always
/// scroll the ListView, not a TextFormField's internal Scrollable, keeping
/// these scrolls deterministic no matter how many fields render.
final spellCreationScrollable = find.byType(Scrollable).first;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'end-to-end: create a spell matching an existing Technique+Form, see suggestions, '
    'save it, and find it in the library',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      // We start on the Create tab.
      expect(find.text('Create Spell'), findsOneWidget);

      // Select Creo Imaginem, which has 5 built-in library spells (Task 6).
      await tester.tap(find.byKey(const Key('technique-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Creo').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('form-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Imaginem').last);
      await tester.pumpAndSettle();

      // Select the "affects two senses" base effect (Base 2), matching Phantasm
      // of the Talking Head's base effect from the seed library.
      await tester.tap(find.byKey(const Key('base-effect-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an image that affects two senses (Base 2)').last);
      await tester.pumpAndSettle();

      // Range, Duration and Target became mandatory for a valid draft when the
      // single parameter list was split into one dropdown per category, so they
      // must be set or validation blocks the calculation below.
      for (final entry in const {
        'range-dropdown': 'Personal',
        'duration-dropdown': 'Momentary',
        'target-dropdown': 'Individual',
      }.entries) {
        await tester.scrollUntilVisible(
          find.byKey(Key(entry.key)),
          200.0,
          scrollable: spellCreationScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining(entry.value).last);
        await tester.pumpAndSettle();
      }

      // Calculate. Those three dropdowns (plus the requisites section) pushed
      // this button below the fold, so it needs scrolling into view first.
      await tester.scrollUntilVisible(
        find.byKey(const Key('calculate-button')),
        200.0,
        scrollable: spellCreationScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calculate-button')));
      await tester.pumpAndSettle();

      // The form is long (dropdowns, parameter/modifier pickers, the
      // calculated-level card) and the suggestions list renders below the
      // fold, so the ListView's sliver machinery won't have built those
      // widgets yet. Scroll them into view before asserting/tapping.
      await tester.scrollUntilVisible(
        find.text('Phantasm of the Talking Head'),
        200.0,
        scrollable: spellCreationScrollable,
      );
      await tester.pumpAndSettle();

      // Suggestions should include built-in Creo Imaginem spells.
      expect(find.text('Phantasm of the Talking Head'), findsOneWidget);
      expect(find.text('Haunt of the Living Ghost'), findsOneWidget);

      // Save the new draft under a name.
      await tester.scrollUntilVisible(
        find.byKey(const Key('save-button')),
        200.0,
        scrollable: spellCreationScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('spell-name-field')), 'My New Illusion');
      await tester.enterText(
          find.byKey(const Key('save-dialog-summary-field')), 'Created by an integration test.');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-save-button')));
      await tester.pumpAndSettle();
      // The save chain (dialog pop -> outer showDialog future -> bloc.add ->
      // async DB write -> emit(saved)) can finish after pumpAndSettle already
      // sees zero scheduled frames, since real async I/O isn't tied to frame
      // scheduling. Give it a little real wall-clock margin before moving on.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Switch to the Library tab and confirm the saved spell is there.
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      // IndexedStack keeps every tab mounted, so there are multiple
      // Scrollables in the tree now; scope to the Library screen's list
      // specifically. The new spell is appended after the built-in library
      // (294 spells + 23 templates as of writing), so it's off-screen and
      // needs scrolling into view before it's built.
      // (Scoping to SpellLibraryScreen alone still matches 2 Scrollables:
      // the search TextField's internal one, plus the actual list's, so
      // narrow down to the ListView's Scrollable specifically.)
      final libraryListView = find.descendant(
        of: find.byType(SpellLibraryScreen),
        matching: find.byType(ListView),
      );
      final libraryScrollable = find.descendant(
        of: libraryListView,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('My New Illusion'),
        200.0,
        scrollable: libraryScrollable,
        // Default maxScrolls (50) covers 10,000px, sized for the ~27-spell
        // library this test was written against; the seed library has since
        // grown to 294 spells + 23 templates, pushing a newly-saved spell
        // well past that budget. Bumped generously so this doesn't need
        // retuning every time the seed library grows again.
        maxScrolls: 500,
      );
      await tester.pumpAndSettle();

      expect(find.text('My New Illusion'), findsOneWidget);

      // Filtering to "My Spells" should show only the one we just saved.
      await tester.tap(find.widgetWithText(RadioListTile<String>, 'My Spells'));
      await tester.pumpAndSettle();

      expect(find.text('My New Illusion'), findsOneWidget);
      expect(find.text('Phantasm of the Talking Head'), findsNothing);

      await database.close();
    },
  );

  // Requisites had no real-bloc coverage, and a crash slipped through as a
  // result: the widget tests mock SpellCreationBloc, so no new state is ever
  // emitted and the rebuild that follows adding a requisite never happens.
  // This drives the genuine bloc, so add/re-render/change-kind/remove all run
  // against real state transitions.
  testWidgets(
    'end-to-end: add requisites of both kinds, see the level change, then remove one',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      Future<void> scrollTo(Finder finder) async {
        await tester.scrollUntilVisible(finder, 200.0, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      }

      // The RitualSection widget added between the Modifiers section and the
      // Calculate button (Task 7 of the Ritual Spells work) added enough
      // extra height that, once the viewport has scrolled forward to reach
      // calculate-button/level-breakdown-card, the requisite row further up
      // the list is scrolled out of view above the viewport. scrollTo only
      // ever scrolls forward, so getting back to it needs a negative delta —
      // same technique already used below for form-dropdown.
      Future<void> scrollBackTo(Finder finder) async {
        await tester.scrollUntilVisible(finder, -200.0, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      }

      // Rego, not Creo: Creo + Momentary now defaults the Ritual declaration
      // on (Task 6/7 of the Ritual Spells work), which floors the calculated
      // level to 20 whenever the raw total is lower. Both the free and the
      // adding requisite levels below land under 20, so with Creo they'd both
      // be floored to the same value and the "level must rise" assertion
      // below would spuriously fail. Rego + Momentary is not a lasting-Creo
      // case, so no default applies and the raw levels differ as intended.
      await tester.tap(find.byKey(const Key('technique-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rego').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('form-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignem').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base-effect-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('(Base 4)').last);
      await tester.pumpAndSettle();

      // Range/Duration/Target are required before a level can be calculated.
      for (final entry in const {
        'range-dropdown': 'Personal',
        'duration-dropdown': 'Momentary',
        'target-dropdown': 'Individual',
      }.entries) {
        await scrollTo(find.byKey(Key(entry.key)));
        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining(entry.value).last);
        await tester.pumpAndSettle();
      }

      // Add a requisite. This is the step that used to crash: the chosen art
      // leaves the add dropdown's items on the resulting rebuild.
      await scrollTo(find.byKey(const Key('requisite-add-dropdown')));
      await tester.tap(find.byKey(const Key('requisite-add-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auram').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('requisite-row-Auram')), findsOneWidget);

      // Free by default, so the level matches the no-requisite calculation.
      await scrollTo(find.byKey(const Key('calculate-button')));
      await tester.tap(find.byKey(const Key('calculate-button')));
      await tester.pumpAndSettle();
      await scrollTo(find.byKey(const Key('level-breakdown-card')));
      final levelWithFreeRequisite = tester
          .widget<Text>(find.descendant(
            of: find.byKey(const Key('breakdown-total')),
            matching: find.byType(Text),
          ).last)
          .data!;

      // Promote it to adding: +1 magnitude, so the level must rise.
      await scrollBackTo(find.byKey(const Key('requisite-kind-Auram')));
      await tester.tap(find.byKey(const Key('requisite-kind-Auram')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adding (+1)').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await scrollTo(find.byKey(const Key('calculate-button')));
      await tester.tap(find.byKey(const Key('calculate-button')));
      await tester.pumpAndSettle();
      await scrollTo(find.byKey(const Key('level-breakdown-card')));
      final levelWithAddingRequisite = tester
          .widget<Text>(find.descendant(
            of: find.byKey(const Key('breakdown-total')),
            matching: find.byType(Text),
          ).last)
          .data!;

      expect(
        levelWithAddingRequisite,
        isNot(levelWithFreeRequisite),
        reason: 'promoting a requisite from free to adding should change the level',
      );

      // Removing it puts the art back in the add dropdown and must not throw.
      await scrollBackTo(find.byKey(const Key('requisite-remove-Auram')));
      await tester.tap(find.byKey(const Key('requisite-remove-Auram')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('requisite-row-Auram')), findsNothing);
      expect(find.text('No requisites.'), findsOneWidget);

      await database.close();
    },
  );

  // Pruning only manifests on the rebuild that follows a scope change.
  // Widget tests mock SpellCreationBloc, so no new state is ever emitted and
  // that rebuild never happens — the same structural blind spot that let the
  // requisites crash above slip through. This drives the genuine bloc so a
  // Form change that strands a modifier selection actually gets exercised.
  testWidgets(
    'end-to-end: a modifier selection is pruned when its scope-defining Form changes',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(
        allSpells: allSpells,
        allModifiers: await configRepository.getAllModifiers(),
      );

      final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      Future<void> scrollTo(Finder finder) async {
        await tester.scrollUntilVisible(finder, 200.0,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('technique-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rego').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('form-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terram').last);
      await tester.pumpAndSettle();

      // Expand and choose a material, which only Terram offers.
      await scrollTo(find.byKey(const Key('modifiers-expand-toggle')));
      await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
      await tester.pumpAndSettle();

      await scrollTo(find.byKey(const Key('modifier-dropdown-rego-terram-material')));
      await tester.tap(find.byKey(const Key('modifier-dropdown-rego-terram-material')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Base metal (+2)').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await scrollTo(find.byKey(const Key('modifiers-summary')));
      expect(find.text('+2'), findsOneWidget);

      // Switching Form strands that selection; it must be pruned, and the
      // badge must fall back to +0 rather than silently keeping the magnitude.
      // (The modifiers section is now expanded, so the form dropdown has
      // scrolled out of view and needs to be brought back before tapping it.)
      // The form dropdown sits near the very top of the list, well outside
      // the ListView's build cache extent by this point, so scrolling back
      // up to it needs a negative delta (the shared `scrollTo` helper above
      // only ever scrolls forward/down, matching every other use in this file).
      await tester.scrollUntilVisible(
        find.byKey(const Key('form-dropdown')),
        -200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('form-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignem').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await scrollTo(find.byKey(const Key('modifiers-summary')));
      expect(find.text('+2'), findsNothing);
      expect(find.byKey(const Key('modifier-dropdown-rego-terram-material')), findsNothing);

      await database.close();
    },
  );

  // The deletion-invalidates-spells policy is the one genuinely new behaviour
  // in this plan, and it only manifests once a deletion propagates through a
  // reload. Mocked widget tests can't observe that, so this drives the real
  // blocs/repositories end to end.
  testWidgets(
    'end-to-end: a spell built on a custom effect stays listed and marked '
    'unavailable after that effect is deleted',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      // Author a custom base effect, build a spell on it, then delete the
      // effect. The user has accepted that this invalidates the spell — it must
      // stay listed and clearly marked, not vanish and not crash the tab.
      final customEffect = BaseEffect(
        id: 'custom-integration-effect',
        technique: 'Creo',
        form: 'Ignem',
        description: 'A custom effect for the integration test',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      await configRepository.addCustomEffect(customEffect);

      await spellRepository.saveSpell(Spell(
        id: 'spell-on-custom-effect',
        name: 'Spell On Custom Effect',
        baseEffectId: customEffect.id,
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
      ));

      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      final libraryListView = find.descendant(
          of: find.byType(SpellLibraryScreen), matching: find.byType(ListView));
      final libraryScrollable = find.descendant(
          of: libraryListView, matching: find.byType(Scrollable));

      // maxScrolls bumped from the 50-scroll default: sized for the ~27-spell
      // library this test was written against, since grown to 294 spells +
      // 23 templates (see the comment on the equivalent scroll above).
      await tester.scrollUntilVisible(
          find.text('Spell On Custom Effect'), 200.0,
          scrollable: libraryScrollable, maxScrolls: 500);
      await tester.pumpAndSettle();

      expect(find.text('Spell On Custom Effect'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Confirms the spell is genuinely resolved at this point (not just
      // listed) — the custom effect was added after the resolver was built
      // at test setup, so this also exercises the resolver picking up a
      // newly-added catalog entry, not just tolerating a deleted one.
      expect(find.textContaining('Unavailable'), findsNothing);

      // Delete the effect out from under it and reload the library.
      await configRepository.deleteCustomEffect(customEffect.id);
      spellLibraryBloc.add(const LibraryRequested());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Spell On Custom Effect'), 200.0,
          scrollable: libraryScrollable, maxScrolls: 500);
      await tester.pumpAndSettle();

      // Still listed, now visibly unavailable, and the tab is intact.
      expect(tester.takeException(), isNull);
      expect(find.text('Spell On Custom Effect'), findsOneWidget);
      expect(find.textContaining('Unavailable'), findsOneWidget);

      await database.close();
    },
  );

  testWidgets(
    'end-to-end: a Momentary Creo spell is offered the Ritual checkbox, and '
    'declaring it produces a Ritual spell',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(
          spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(
          libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Create Spell'), findsOneWidget);

      // Select Creo / Terram / Create precious metal.
      await tester.tap(find.byKey(const Key('technique-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Creo').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('form-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terram').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base-effect-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Create precious metal').last);
      await tester.pumpAndSettle();

      // Touch / Momentary / Individual. Each dropdown must be scrolled into
      // view first — the form is taller than the viewport, and the existing
      // test in this file uses exactly this helper for the same reason.
      for (final entry in const {
        'range-dropdown': 'Touch',
        'duration-dropdown': 'Momentary',
        'target-dropdown': 'Individual',
      }.entries) {
        await tester.scrollUntilVisible(
          find.byKey(Key(entry.key)),
          200.0,
          scrollable: spellCreationScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();
        // Dropdown items render as '${name} (+${magnitude})' (e.g. 'Touch
        // (+1)'), not the bare name, so this needs textContaining rather than
        // an exact match — the same pattern the existing test above uses for
        // this same Range/Duration/Target loop.
        await tester.tap(find.textContaining(entry.value).last);
        await tester.pumpAndSettle();
      }

      // The "creates something lasting" radio option appears for Creo +
      // Momentary and is selected by default.
      final lastingCreationRadio =
          find.byKey(const Key('ritual-radio-lastingCreation'));
      await tester.scrollUntilVisible(
        lastingCreationRadio,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        RadioGroup.maybeOf<RitualDeclaration>(tester.element(lastingCreationRadio))
            ?.groupValue,
        RitualDeclaration.lastingCreation,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('calculate-button')),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calculate-button')));
      await tester.pumpAndSettle();

      // Touch of Midas: base 15, +1 Touch = 20.
      expect(find.text('20'), findsWidgets);

      await tester.scrollUntilVisible(
        find.byKey(const Key('ritual-banner')),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('ritual-banner')), findsOneWidget);

      await database.close();
    },
  );

  // General base effects (Task 25) have no fixed level in the catalog; the
  // caster chooses one. The chosen-level field must appear only while a
  // General effect is selected, and must disappear again — without leaving a
  // stale value behind — the moment the selection moves to an ordinary,
  // fixed-level effect.
  testWidgets(
    'end-to-end: the guideline level field appears only for General effects',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      await selectTechniqueAndForm(tester, 'Rego', 'Animal');

      // rean-gen: the sole Rego Animal General entry.
      await selectBaseEffect(tester, 'Ward against beings associated with Animal');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chosen-base-level-field')), findsOneWidget);

      // rean-1 (Base 1): an ordinary, fixed-level Rego Animal row. Switching
      // to it clears chosenBaseLevel (spell_creation_bloc.dart: only a
      // General->General switch preserves it), so the field must be gone.
      await selectBaseEffect(tester, 'Manipulate items made from animal products');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chosen-base-level-field')), findsNothing);

      await database.close();
    },
  );

  // Learning a template (Task 14b) instantiates a draft on the Create tab
  // with its base effect pre-selected. When that base effect is General
  // (rean-gen -> reaq-gen for the ward templates), the chosen-level field
  // must appear there too, and the resulting effect sentence and calculated
  // level must reflect the level the user types in.
  testWidgets(
    'end-to-end: learning a ward template produces a levelled spell',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      await openLibraryTab(tester);

      // IndexedStack keeps both tabs' scrollables in the tree at once, so
      // this scroll must scope to the Library screen's ListView's
      // Scrollable specifically (do not reuse find.byType(Scrollable).first,
      // which would find the Create tab's scrollable instead). There are 23
      // template cards above the spell list, so the target card needs
      // scrolling into view before it's built.
      final libraryListView = find.descendant(
        of: find.byType(SpellLibraryScreen), matching: find.byType(ListView));
      final libraryScrollable = find.descendant(
        of: libraryListView, matching: find.byType(Scrollable));

      const learnKey = Key('learn-tpl-reaq-ward-against-faeries-waters');
      await tester.scrollUntilVisible(find.byKey(learnKey), 200.0, scrollable: libraryScrollable);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(learnKey));
      await tester.pumpAndSettle();

      // Tapping Learn dispatches TemplateInstantiated and (via main.dart's
      // onTemplateLearned callback) switches straight to the Create tab, so
      // no explicit tab switch is needed before the assertion below.
      await tester.enterText(find.byKey(const Key('chosen-base-level-field')), '20');
      await tester.pumpAndSettle();

      // reaq-gen's reference is Touch/Ring/Circle, and Ward against Faeries
      // of the Waters has that same stat line, so the actual R/D/T cost
      // equals the reference cost and level = chosenBaseLevel + 0.
      expect(find.text('Affects beings with Might 20 or less'), findsOneWidget);

      // Back on the Create tab, use the same scroll pattern as every other
      // calculate-button scroll in this file.
      await tester.scrollUntilVisible(
        find.byKey(const Key('calculate-button')), 200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calculate-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('20'), findsWidgets);

      await database.close();
    },
  );

  testWidgets(
    'end-to-end: the Exceptions section lists a real exception spell and offers no action',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      await openLibraryTab(tester);

      // Wizard's Communion is one of the six real exception spells written
      // to assets/data/spell_exceptions.json. Exceptions render as the last
      // section of the Library list, below ~23 templates and ~294 spells
      // (the same seed-library size the other tests in this file scroll
      // past -- see the maxScrolls comments above), so the default
      // maxIteration (50 drags * 200px = 10,000px) falls well short; bumped
      // to match the maxScrolls: 500 budget those other tests already
      // needed for the same reason.
      await tester.dragUntilVisible(
        find.text("Wizard's Communion"),
        find.byType(ListView),
        const Offset(0, -200),
        maxIteration: 500,
      );
      expect(find.text("Wizard's Communion"), findsOneWidget);
      expect(find.byKey(const Key('exception-chip')), findsWidgets);
      expect(find.text('Learn at level…'), findsNothing);

      await database.close();
    },
  );
}
