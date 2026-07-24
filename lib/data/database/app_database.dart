import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String _databaseName = 'eruditus.db';
  static const int _databaseVersion = 1;

  final Database db;

  AppDatabase._(this.db);

  static Future<AppDatabase> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), _databaseName);
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: (db, version) async {
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
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();
}
