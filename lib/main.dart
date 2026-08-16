import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

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
import 'package:eruditus/presentation/screens/backup_screen.dart';
import 'package:eruditus/presentation/screens/configuration_screen.dart';
import 'package:eruditus/presentation/screens/spell_creation_screen.dart';
import 'package:eruditus/presentation/screens/spell_library_screen.dart';
import 'package:eruditus/utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for web and desktop platforms
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final database = await AppDatabase.open();
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
  // Shares the same SpellEngine instance as spellCreationBloc, purely for its
  // calculateSpellLevel method (so Library cards use the exact same level
  // math, with no duplicated implementation).
  final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
  final configurationBloc = ConfigurationBloc(configRepository: configRepository);

  runApp(EruditusApp(
    spellCreationBloc: spellCreationBloc,
    spellLibraryBloc: spellLibraryBloc,
    configurationBloc: configurationBloc,
    backupService: backupService,
  ));
}

class EruditusApp extends StatelessWidget {
  final SpellCreationBloc spellCreationBloc;
  final SpellLibraryBloc spellLibraryBloc;
  final ConfigurationBloc configurationBloc;
  final BackupService backupService;

  const EruditusApp({
    super.key,
    required this.spellCreationBloc,
    required this.spellLibraryBloc,
    required this.configurationBloc,
    required this.backupService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eruditus',
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SpellCreationBloc>.value(value: spellCreationBloc),
          BlocProvider<SpellLibraryBloc>.value(value: spellLibraryBloc),
          BlocProvider<ConfigurationBloc>.value(value: configurationBloc),
        ],
        child: _MainTabView(backupService: backupService),
      ),
    );
  }
}

class _MainTabView extends StatefulWidget {
  final BackupService backupService;

  const _MainTabView({required this.backupService});

  @override
  State<_MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<_MainTabView> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const SpellCreationScreen(
        techniques: ArsArts.all,
        forms: ArsForms.all,
      ),
      // Learning a template dispatches TemplateInstantiated (which the Create
      // tab's IndexedStack-preserved state picks up on its next build) and
      // then jumps there, so the caster lands straight on the draft they just
      // asked to build rather than staying on the Library tab to find it.
      SpellLibraryScreen(onTemplateLearned: () => setState(() => _index = 0)),
      const ConfigurationScreen(),
      BackupScreen(
        backupService: widget.backupService,
        exportJson: (jsonContent) async {
          await FilePicker.saveFile(
            dialogTitle: 'Save Backup',
            fileName: 'eruditus_backup.json',
            bytes: utf8.encode(jsonContent),
          );
        },
        importJson: () async {
          // file_picker 12 added pickFile() for exactly this single-file
          // case; pickFiles(allowMultiple: false) still works but is now
          // deprecated in favor of it.
          final result = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
          final path = result?.path;
          if (path == null) return null;
          return File(path).readAsString();
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        // With no `type` given, BottomNavigationBar defaults to `fixed`
        // for 2-3 items and `shifting` for 4+ -- so these 4 items were
        // silently landing in `shifting` mode. That mode ignores
        // `backgroundColor` entirely (confirmed against the widget's own
        // source) and hides unselected labels by default, despite every
        // item below explicitly setting one. Pin `fixed` so behavior
        // doesn't depend on how many tabs happen to exist.
        type: BottomNavigationBarType.fixed,
        // M3's own default item colors were also too close in tone to
        // this app's pale surface to read as visible -- confirmed by
        // temporarily forcing loud diagnostic colors and watching the
        // bar actually appear. Pin them to theme-derived colors with
        // guaranteed contrast against the surface instead.
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface,
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          // SpellLibraryScreen is kept alive by IndexedStack, so its
          // initState only fires once; re-request on every visit so a
          // spell saved from the Create tab shows up without a restart.
          if (i == 1) {
            context.read<SpellLibraryBloc>().add(const LibraryRequested());
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.auto_fix_high), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: 'Backup'),
        ],
      ),
    );
  }
}
