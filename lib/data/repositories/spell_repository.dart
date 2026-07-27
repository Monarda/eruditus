import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

class SpellRepository {
  final LocalSpellDatasource datasource;
  final SpellResolver resolver;

  SpellRepository({required this.datasource, required this.resolver});

  // Writes take the record; reads return it joined to the catalogs.
  Future<void> saveSpell(Spell spell) => datasource.insertSpell(spell);
  Future<void> updateSpell(Spell spell) => datasource.updateSpell(spell);
  Future<void> deleteSpell(String id) => datasource.deleteSpell(id);

  Future<ResolvedSpell?> getSpellById(String id) async {
    final record = await datasource.getSpellById(id);
    return record == null ? null : resolver.resolve(record);
  }

  Future<List<ResolvedSpell>> getAllUserSpells() async =>
      resolver.resolveAll(await datasource.getAllSpells());
}
