import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String _databaseName = 'eruditus.db';
  static const int _databaseVersion = 2;

  final Database db;

  AppDatabase._(this.db);

  static Future<AppDatabase> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), _databaseName);
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: (db, version) => _createSchema(db),
        // Backward compatibility is not a goal for this prototype. Rather than
        // translate stored spells whose shape has changed, drop everything and
        // rebuild: destructive, but self-healing and explicit, where a silent
        // schema mismatch would fail confusingly at read time.
        onUpgrade: (db, oldVersion, newVersion) async {
          for (final table in const [
            'spells',
            'custom_effects',
            'custom_parameters',
            'custom_factors',
            'custom_modifiers',
          ]) {
            await db.execute('DROP TABLE IF EXISTS $table');
          }
          await _createSchema(db);
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE spells (
        id TEXT PRIMARY KEY,
        name TEXT,
        technique TEXT NOT NULL,
        form TEXT NOT NULL,
        source TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_effects (
        id TEXT PRIMARY KEY,
        technique TEXT NOT NULL,
        form TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_parameters (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_factors (
        id TEXT PRIMARY KEY,
        technique TEXT NOT NULL,
        form TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_modifiers (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() => db.close();
}
