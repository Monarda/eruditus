import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/models/base_effect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late ConfigurationRepository configRepository;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    configRepository = ConfigurationRepository(
      assetLoader: AssetDataLoader(),
      configDatasource: LocalConfigurationDatasource(database: database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  blocTest<ConfigurationBloc, ConfigurationState>(
    'ConfigurationRequested loads built-in effects/parameters/factors',
    build: () => ConfigurationBloc(configRepository: configRepository),
    act: (bloc) => bloc.add(const ConfigurationRequested()),
    expect: () => [
      isA<ConfigurationState>().having((s) => s.status, 'status', ConfigurationStatus.loading),
      isA<ConfigurationState>()
          .having((s) => s.status, 'status', ConfigurationStatus.loaded)
          .having((s) => s.effects.length, 'effects.length', 38)
          .having((s) => s.parameters.length, 'parameters.length', 17)
          .having((s) => s.factors.length, 'factors.length', 7),
    ],
  );

  blocTest<ConfigurationBloc, ConfigurationState>(
    'CustomEffectAdded persists then reloads with the new effect included',
    build: () => ConfigurationBloc(configRepository: configRepository),
    act: (bloc) {
      bloc.add(const ConfigurationRequested());
      bloc.add(CustomEffectAdded(BaseEffect(
        id: 'custom-1', technique: 'Creo', form: 'Ignem',
        description: 'My custom effect', baseLevel: 7, source: 'user-created',
      )));
    },
    skip: 2,
    expect: () => [
      isA<ConfigurationState>().having((s) => s.status, 'status', ConfigurationStatus.loading),
      isA<ConfigurationState>()
          .having((s) => s.status, 'status', ConfigurationStatus.loaded)
          .having((s) => s.effects.length, 'effects.length', 39)
          .having((s) => s.effects.any((e) => e.id == 'custom-1'), 'has custom-1', isTrue),
    ],
  );

  blocTest<ConfigurationBloc, ConfigurationState>(
    'CustomEffectDeleted removes it and reloads',
    build: () => ConfigurationBloc(configRepository: configRepository),
    act: (bloc) async {
      bloc.add(const ConfigurationRequested());
      bloc.add(CustomEffectAdded(BaseEffect(
        id: 'custom-1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 5, source: 'user-created',
      )));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CustomEffectDeleted('custom-1'));
    },
    skip: 4,
    expect: () => [
      isA<ConfigurationState>().having((s) => s.status, 'status', ConfigurationStatus.loading),
      isA<ConfigurationState>()
          .having((s) => s.status, 'status', ConfigurationStatus.loaded)
          .having((s) => s.effects.length, 'effects.length', 38),
    ],
  );
}
