import 'dart:convert';

import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';

class LocalConfigurationDatasource {
  final AppDatabase database;

  LocalConfigurationDatasource({required this.database});

  Future<void> insertCustomEffect(BaseEffect effect) async {
    await database.db.insert('custom_effects', {
      'id': effect.id,
      'technique': effect.technique,
      'form': effect.form,
      'data': jsonEncode(effect.toMap()),
    });
  }

  Future<void> deleteCustomEffect(String id) async {
    await database.db.delete('custom_effects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BaseEffect>> getAllCustomEffects() async {
    final rows = await database.db.query('custom_effects');
    return rows
        .map((row) => BaseEffect.fromMap(jsonDecode(row['data'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> insertCustomParameter(Parameter parameter) async {
    await database.db.insert('custom_parameters', {
      'id': parameter.id,
      'category': parameter.category,
      'data': jsonEncode(parameter.toMap()),
    });
  }

  Future<void> deleteCustomParameter(String id) async {
    await database.db.delete('custom_parameters', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Parameter>> getAllCustomParameters() async {
    final rows = await database.db.query('custom_parameters');
    return rows
        .map((row) => Parameter.fromMap(jsonDecode(row['data'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> insertCustomModifier(Modifier modifier) async {
    await database.db.insert('custom_modifiers', {
      'id': modifier.id,
      'data': jsonEncode(modifier.toMap()),
    });
  }

  Future<void> deleteCustomModifier(String id) async {
    await database.db.delete('custom_modifiers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Modifier>> getAllCustomModifiers() async {
    final rows = await database.db.query('custom_modifiers');
    return rows
        .map((row) => Modifier.fromMap(jsonDecode(row['data'] as String) as Map<String, dynamic>))
        .toList();
  }
}
