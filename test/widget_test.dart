import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/services/backup_service.dart';
import 'package:eruditus/main.dart';

class MockSpellCreationBloc extends MockBloc<SpellCreationEvent, SpellCreationState>
    implements SpellCreationBloc {}

class MockSpellLibraryBloc extends MockBloc<SpellLibraryEvent, SpellLibraryState>
    implements SpellLibraryBloc {}

class MockConfigurationBloc extends MockBloc<ConfigurationEvent, ConfigurationState>
    implements ConfigurationBloc {}

class FakeSpellCreationEvent extends Fake implements SpellCreationEvent {}
class FakeSpellCreationState extends Fake implements SpellCreationState {}
class FakeSpellLibraryEvent extends Fake implements SpellLibraryEvent {}
class FakeSpellLibraryState extends Fake implements SpellLibraryState {}
class FakeConfigurationEvent extends Fake implements ConfigurationEvent {}
class FakeConfigurationState extends Fake implements ConfigurationState {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSpellCreationEvent());
    registerFallbackValue(FakeSpellCreationState());
    registerFallbackValue(FakeSpellLibraryEvent());
    registerFallbackValue(FakeSpellLibraryState());
    registerFallbackValue(FakeConfigurationEvent());
    registerFallbackValue(FakeConfigurationState());
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // The real AppDatabase (and the BackupService built on top of it) is opened
  // here in setUp/tearDown rather than inline in the testWidgets body. Real
  // async I/O (real database/asset-loading calls) awaited directly inside a
  // testWidgets body hangs indefinitely under this project's flutter_tester
  // build (confirmed: >90s with no completion), the same category of issue
  // documented for real Blocs. setUp/tearDown callbacks run outside that
  // fake-async test-body zone, so real async work there completes normally.
  late AppDatabase database;
  late BackupService backupService;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    backupService = BackupService(
      spellRepository: SpellRepository(datasource: LocalSpellDatasource(database: database)),
      configRepository: ConfigurationRepository(
        assetLoader: AssetDataLoader(),
        configDatasource: LocalConfigurationDatasource(database: database),
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('EruditusApp launches showing the Create tab and bottom navigation', (tester) async {
    final spellCreationBloc = MockSpellCreationBloc();
    final spellLibraryBloc = MockSpellLibraryBloc();
    final configurationBloc = MockConfigurationBloc();

    whenListen(spellCreationBloc, const Stream<SpellCreationState>.empty(),
        initialState: SpellCreationState.initial());
    whenListen(spellLibraryBloc, const Stream<SpellLibraryState>.empty(),
        initialState: SpellLibraryState.initial());
    whenListen(configurationBloc, const Stream<ConfigurationState>.empty(),
        initialState: ConfigurationState.initial());

    await tester.pumpWidget(EruditusApp(
      spellCreationBloc: spellCreationBloc,
      spellLibraryBloc: spellLibraryBloc,
      configurationBloc: configurationBloc,
      backupService: backupService,
    ));

    expect(find.text('Create Spell'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
  });
}
