import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('upgrading to v4 drops spells but preserves the custom catalogs', () async {
    // A v3 database, built by hand: spells still carries the pre-v4 shape, and
    // each custom catalog holds one row that must survive the upgrade.
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'test_migration.db');

    // Clean up any existing test database
    try {
      await databaseFactory.deleteDatabase(path);
    } catch (_) {}
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE spells (
              id TEXT PRIMARY KEY, name TEXT, source TEXT NOT NULL,
              data TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)
          ''');
          await db.execute('''
            CREATE TABLE custom_effects (
              id TEXT PRIMARY KEY, technique TEXT NOT NULL, form TEXT NOT NULL,
              data TEXT NOT NULL)
          ''');
          await db.execute('''
            CREATE TABLE custom_parameters (
              id TEXT PRIMARY KEY, category TEXT NOT NULL, data TEXT NOT NULL)
          ''');
          await db.execute('''
            CREATE TABLE custom_modifiers (id TEXT PRIMARY KEY, data TEXT NOT NULL)
          ''');
        },
      ),
    );
    await old.insert('spells', {
      'id': 'old-spell', 'name': 'Old', 'source': 'built-in',
      'data': '{}', 'created_at': 'x', 'updated_at': 'x',
    });
    await old.insert('custom_effects', {
      'id': 'keep-effect', 'technique': 'Creo', 'form': 'Ignem', 'data': '{}',
    });
    await old.insert('custom_parameters', {
      'id': 'keep-parameter', 'category': 'Range', 'data': '{}',
    });
    await old.insert('custom_modifiers', {'id': 'keep-modifier', 'data': '{}'});
    await old.close();

    final upgraded = await AppDatabase.open(path: path);

    // The user's authored catalog survives — only the spells table changed shape.
    expect(await upgraded.db.query('custom_effects'), hasLength(1));
    expect(await upgraded.db.query('custom_parameters'), hasLength(1));
    expect(await upgraded.db.query('custom_modifiers'), hasLength(1));

    // Stored spells are destroyed rather than translated, by design.
    expect(await upgraded.db.query('spells'), isEmpty);

    await upgraded.close();
  });
}
