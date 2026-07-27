import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String _databaseName = 'eruditus.db';
  static const int _databaseVersion = 4;

  final Database db;

  AppDatabase._(this.db);

  static Future<AppDatabase> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), _databaseName);
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: (db, version) => _createSchema(db),
        // Backward compatibility is not a goal for this prototype, and in this
        // branch's v4 bump the `spells` table's DDL is unchanged — what
        // changed is the shape of the JSON stored in its `data` blob (the new
        // `SpellSource`/citations/tags/summary split), which old rows don't
        // have and `Spell.fromMap` cannot parse. Rather than translate stored
        // spells whose blob shape has changed, drop just that table and
        // rebuild it: destructive, but self-healing and explicit, where a
        // silent schema mismatch would fail confusingly at read time. The
        // rest of the custom catalog (`custom_effects`, `custom_parameters`,
        // `custom_modifiers`) is untouched by this upgrade and must survive
        // it. `custom_factors` is dropped too, but only as dead-table
        // cleanup: `_createSchema` never creates it, so this is a no-op with
        // zero data-loss risk.
        onUpgrade: (db, oldVersion, newVersion) async {
          for (final table in const ['spells', 'custom_factors']) {
            await db.execute('DROP TABLE IF EXISTS $table');
          }
          await _createSchema(db);
        },
      ),
    );
    return AppDatabase._(db);
  }

  // IF NOT EXISTS on every table: `onUpgrade` no longer drops
  // `custom_effects`/`custom_parameters`/`custom_modifiers` before calling
  // this, so those tables already exist by the time this runs on an upgrade
  // and a plain CREATE TABLE would fail with "table already exists". The
  // `spells` table was just dropped by `onUpgrade`, so IF NOT EXISTS is a
  // no-op there; on a fresh `onCreate` install nothing exists yet, so IF NOT
  // EXISTS is a no-op everywhere.
  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS spells (
        id TEXT PRIMARY KEY,
        name TEXT,
        source TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_effects (
        id TEXT PRIMARY KEY,
        technique TEXT NOT NULL,
        form TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_parameters (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_modifiers (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() => db.close();
}
