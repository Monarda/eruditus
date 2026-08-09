import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/invalid_spell_exception.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

class SpellRepository {
  final LocalSpellDatasource datasource;
  final SpellResolver resolver;
  final ConfigurationRepository configRepository;

  SpellRepository({
    required this.datasource,
    required this.resolver,
    required this.configRepository,
  });

  // Writes take the record; reads return it joined to the catalogs.

  /// Writes [spell], refusing an invalid one.
  ///
  /// Throws [InvalidSpellException] rather than writing a record that breaks a
  /// catalog-dependent invariant. See [saveAll] for the batch path, which
  /// reports instead of throwing — it is not a bypass, it runs the same check.
  Future<void> saveSpell(Spell spell) async {
    await _assertValid(spell, refresh: true);
    await datasource.insertSpell(spell);
  }

  Future<void> updateSpell(Spell spell) async {
    await _assertValid(spell, refresh: true);
    await datasource.updateSpell(spell);
  }

  Future<void> deleteSpell(String id) => datasource.deleteSpell(id);

  /// Writes every valid spell in [spells] and returns the ones it refused.
  ///
  /// Refreshes the catalog **once** for the whole batch: nothing caches the
  /// database half of the catalog, so refreshing per spell would re-read it
  /// once per row. Same validator as [saveSpell], different failure mode —
  /// a backup should not lose good rows to one bad one.
  Future<List<InvalidSpellException>> saveAll(Iterable<Spell> spells) async {
    await _refreshResolver();

    final rejected = <InvalidSpellException>[];
    for (final spell in spells) {
      final problems = _problemsFor(spell);
      if (problems.isNotEmpty) {
        rejected.add(InvalidSpellException(spell.id, problems));
        continue;
      }
      final existing = await datasource.getSpellById(spell.id);
      if (existing == null) {
        await datasource.insertSpell(spell);
      } else {
        await datasource.updateSpell(spell);
      }
    }
    return rejected;
  }

  Future<ResolvedSpell?> getSpellById(String id) async {
    final record = await datasource.getSpellById(id);
    return record == null ? null : resolver.resolve(record);
  }

  Future<List<ResolvedSpell>> getAllUserSpells() async =>
      resolver.resolveAll(await datasource.getAllSpells());

  Future<void> _assertValid(Spell spell, {required bool refresh}) async {
    if (refresh) await _refreshResolver();
    final problems = _problemsFor(spell);
    if (problems.isNotEmpty) {
      throw InvalidSpellException(spell.id, problems);
    }
  }

  /// The record's problems, or empty when its base effect does not resolve.
  ///
  /// An unresolvable base effect is *not* a write-time error: it is what
  /// `ResolvedSpell.isResolved` already reports, and refusing the write would
  /// mean a user who deleted a custom effect could no longer save edits to the
  /// spells built on it.
  List<String> _problemsFor(Spell spell) => resolver.resolve(spell).problems;

  /// Brings the shared resolver up to date before validating against it.
  ///
  /// Mirrors `LibraryRepository._refreshResolver`, and reaches the same object:
  /// one `SpellResolver` instance is shared by both repositories (`main.dart`).
  /// Without this, a spell built on a custom effect added since the last
  /// Library tab visit would be refused for referring to an effect the
  /// resolver has not heard of.
  Future<void> _refreshResolver() async {
    resolver.updateCatalogs(
      effects: await configRepository.getAllEffects(),
      parameters: await configRepository.getAllParameters(),
      modifiers: await configRepository.getAllModifiers(),
    );
  }
}
