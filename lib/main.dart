import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';
import 'package:eruditus/presentation/screens/backup_screen.dart';
import 'package:eruditus/presentation/screens/configuration_screen.dart';
import 'package:eruditus/presentation/screens/spell_creation_screen.dart';
import 'package:eruditus/presentation/screens/spell_library_screen.dart';
import 'package:eruditus/utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = await AppDatabase.open();
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
  final allEffects = await configRepository.getAllEffects();
  final allParameters = await configRepository.getAllParameters();

  final spellEngine = SpellEngine(allSpells: allSpells, allSpecialFactors: allSpecialFactors);

  final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
  final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository);
  final configurationBloc = ConfigurationBloc(configRepository: configRepository);

  runApp(EruditusApp(
    spellCreationBloc: spellCreationBloc,
    spellLibraryBloc: spellLibraryBloc,
    configurationBloc: configurationBloc,
    allEffects: allEffects,
    allParameters: allParameters,
    allSpecialFactors: allSpecialFactors,
    backupService: backupService,
  ));
}

class EruditusApp extends StatelessWidget {
  final SpellCreationBloc spellCreationBloc;
  final SpellLibraryBloc spellLibraryBloc;
  final ConfigurationBloc configurationBloc;
  final List<BaseEffect> allEffects;
  final List<Parameter> allParameters;
  final List<SpecialFactor> allSpecialFactors;
  final BackupService backupService;

  const EruditusApp({
    super.key,
    required this.spellCreationBloc,
    required this.spellLibraryBloc,
    required this.configurationBloc,
    required this.allEffects,
    required this.allParameters,
    required this.allSpecialFactors,
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
        child: _MainTabView(
          allEffects: allEffects,
          allParameters: allParameters,
          allSpecialFactors: allSpecialFactors,
          backupService: backupService,
        ),
      ),
    );
  }
}

class _MainTabView extends StatefulWidget {
  final List<BaseEffect> allEffects;
  final List<Parameter> allParameters;
  final List<SpecialFactor> allSpecialFactors;
  final BackupService backupService;

  const _MainTabView({
    required this.allEffects,
    required this.allParameters,
    required this.allSpecialFactors,
    required this.backupService,
  });

  @override
  State<_MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<_MainTabView> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      SpellCreationScreen(
        techniques: ArsArts.all,
        forms: ArsForms.all,
        availableEffects: widget.allEffects,
        availableParameters: widget.allParameters,
        availableFactors: widget.allSpecialFactors,
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
        onTap: (i) => setState(() => _index = i),
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
