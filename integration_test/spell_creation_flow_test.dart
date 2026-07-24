import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/services/backup_service.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/main.dart';
import 'package:eruditus/presentation/screens/spell_library_screen.dart';

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
      final spellRepository = SpellRepository(datasource: LocalSpellDatasource(database: database));
      final libraryRepository = LibraryRepository(assetLoader: assetLoader, spellRepository: spellRepository);
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final allSpecialFactors = await configRepository.getAllSpecialFactors();
      final spellEngine = SpellEngine(allSpells: allSpells, allSpecialFactors: allSpecialFactors);

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

      // Calculate.
      await tester.tap(find.byKey(const Key('calculate-button')));
      await tester.pumpAndSettle();

      // The form is long (dropdowns, parameter/special-factor pickers, the
      // calculated-level card) and the suggestions list renders below the
      // fold, so the ListView's sliver machinery won't have built those
      // widgets yet. Scroll them into view before asserting/tapping.
      await tester.scrollUntilVisible(
        find.text('Phantasm of the Talking Head'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Suggestions should include built-in Creo Imaginem spells.
      expect(find.text('Phantasm of the Talking Head'), findsOneWidget);
      expect(find.text('Haunt of the Living Ghost'), findsOneWidget);

      // Save the new draft under a name.
      await tester.scrollUntilVisible(
        find.byKey(const Key('save-button')),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('spell-name-field')), 'My New Illusion');
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
      // specifically. The new spell is appended after 27 built-ins, so it's
      // off-screen and needs scrolling into view before it's built.
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
}
