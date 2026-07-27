import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:eruditus/presentation/screens/backup_screen.dart';
import 'package:eruditus/presentation/screens/configuration_screen.dart';
import 'package:eruditus/presentation/screens/spell_creation_screen.dart';
import 'package:eruditus/presentation/screens/spell_library_screen.dart';
import 'package:eruditus/utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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
  );
  final spellRepository = SpellRepository(
      datasource: LocalSpellDatasource(database: database), resolver: resolver);
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
      const SpellLibraryScreen(),
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
          final result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
          final path = result?.files.single.path;
          if (path == null) return null;
          return File(path).readAsString();
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
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
