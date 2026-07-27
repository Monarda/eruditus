import 'dart:convert';

import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/models/spell.dart';

class LocalSpellDatasource {
  final AppDatabase database;

  LocalSpellDatasource({required this.database});

  Future<void> insertSpell(Spell spell) async {
    await database.db.insert('spells', _toRow(spell));
  }

  Future<void> updateSpell(Spell spell) async {
    await database.db.update(
      'spells',
      _toRow(spell),
      where: 'id = ?',
      whereArgs: [spell.id],
    );
  }

  Future<void> deleteSpell(String id) async {
    await database.db.delete('spells', where: 'id = ?', whereArgs: [id]);
  }

  Future<Spell?> getSpellById(String id) async {
    final rows = await database.db.query('spells', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<Spell>> getAllSpells() async {
    final rows = await database.db.query('spells');
    return rows.map(_fromRow).toList();
  }

  Map<String, Object?> _toRow(Spell spell) => {
        'id': spell.id,
        'name': spell.name,
        'source': spell.provenance.source.wireValue,
        'data': jsonEncode(spell.toMap()),
        'created_at': spell.createdAt.toIso8601String(),
        'updated_at': spell.updatedAt.toIso8601String(),
      };

  Spell _fromRow(Map<String, Object?> row) {
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    return Spell.fromMap(data);
  }
}
