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
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The built-in effect count is derived from the actual asset data rather
  // than hardcoded, since base_effects.json is bulk-extracted and grows
  // across many commits -- a literal number here previously drifted from 38
  // to 604 without being noticed. These tests are about ConfigurationBloc's
  // add/delete/reload behavior, not about re-verifying AssetDataLoader's
  // parsing (that's asset_data_loader_test.dart's job), so deriving the
  // baseline from the same production loader is the right oracle here.
  late int builtInEffectCount;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    builtInEffectCount = (await AssetDataLoader().loadBaseEffects()).length;
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
          .having((s) => s.effects.length, 'effects.length', builtInEffectCount)
          .having((s) => s.parameters.length, 'parameters.length', 34),
    ],
  );

  blocTest<ConfigurationBloc, ConfigurationState>(
    'CustomEffectAdded persists then reloads with the new effect included',
    build: () => ConfigurationBloc(configRepository: configRepository),
    act: (bloc) {
      bloc.add(const ConfigurationRequested());
      bloc.add(CustomEffectAdded(BaseEffect(
        id: 'custom-1', technique: 'Creo', form: 'Ignem',
        description: 'My custom effect', baseLevel: 7,
        provenance: Provenance(source: PublicationSource.userCreated),
      )));
    },
    skip: 2,
    expect: () => [
      isA<ConfigurationState>().having((s) => s.status, 'status', ConfigurationStatus.loading),
      isA<ConfigurationState>()
          .having((s) => s.status, 'status', ConfigurationStatus.loaded)
          .having((s) => s.effects.length, 'effects.length', builtInEffectCount + 1)
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
        description: 'test', baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      )));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CustomEffectDeleted('custom-1'));
    },
    skip: 4,
    expect: () => [
      isA<ConfigurationState>().having((s) => s.status, 'status', ConfigurationStatus.loading),
      isA<ConfigurationState>()
          .having((s) => s.status, 'status', ConfigurationStatus.loaded)
          .having((s) => s.effects.length, 'effects.length', builtInEffectCount),
    ],
  );
}
