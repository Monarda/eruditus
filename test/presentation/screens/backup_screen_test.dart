import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/services/backup_service.dart';
import 'package:eruditus/presentation/screens/backup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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

  testWidgets('tapping export calls exportJson with the service output and shows success', (tester) async {
    // Note: exportToJson() reads the built-in effects/parameters/factors JSON
    // assets via rootBundle, a genuine async platform-channel round trip. Under
    // this project's flutter_tester build, a plain `tester.tap()` dispatches the
    // button's onPressed callback in a context where that real async work never
    // resolves before the test completes (confirmed: it throws a
    // "database_closed" exception *after* the test ends when driven via tap()+
    // pumpAndSettle()). Invoking the button's onPressed callback directly inside
    // tester.runAsync() runs it in a real (non-fake-async) zone, letting the
    // asset load actually complete before we assert on it.
    String? capturedJson;

    await tester.pumpWidget(MaterialApp(
      home: BackupScreen(
        backupService: backupService,
        exportJson: (json) async => capturedJson = json,
        importJson: () async => null,
      ),
    ));

    final exportButton = tester.widget<ElevatedButton>(find.byKey(const Key('export-button')));
    await tester.runAsync(() => exportButton.onPressed!() as Future<void>);
    await tester.pump();
    await tester.pump();

    expect(capturedJson, isNotNull);
    expect(find.text('Backup exported successfully.'), findsOneWidget);
  });

  testWidgets('tapping import with a cancelled file picker shows "Import cancelled."', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BackupScreen(
        backupService: backupService,
        exportJson: (json) async {},
        importJson: () async => null,
      ),
    ));

    await tester.tap(find.byKey(const Key('import-button')));
    await tester.pumpAndSettle();

    expect(find.text('Import cancelled.'), findsOneWidget);
  });

  testWidgets('tapping import with malformed content shows the failure message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BackupScreen(
        backupService: backupService,
        exportJson: (json) async {},
        importJson: () async => 'not valid json',
      ),
    ));

    await tester.tap(find.byKey(const Key('import-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Import failed:'), findsOneWidget);
  });
}
