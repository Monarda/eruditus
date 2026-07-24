import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/models/spell.dart';

class SpellRepository {
  final LocalSpellDatasource datasource;

  SpellRepository({required this.datasource});

  Future<void> saveSpell(Spell spell) => datasource.insertSpell(spell);
  Future<void> updateSpell(Spell spell) => datasource.updateSpell(spell);
  Future<void> deleteSpell(String id) => datasource.deleteSpell(id);
  Future<Spell?> getSpellById(String id) => datasource.getSpellById(id);
  Future<List<Spell>> getAllUserSpells() => datasource.getAllSpells();
}
