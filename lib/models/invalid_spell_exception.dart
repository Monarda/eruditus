/// Thrown when a write is refused because the spell breaks a catalog-dependent
/// invariant — see `validateSpellAgainstCatalog`.
///
/// Blocking rather than degrading is a deliberate decision (spec decision 1),
/// flagged as revisitable: a spell that becomes invalid *after* it was written
/// is degraded instead, via `ResolvedSpell.problems`, because there is no write
/// to refuse in that case.
class InvalidSpellException implements Exception {
  final String spellId;
  final List<String> problems;

  InvalidSpellException(this.spellId, this.problems);

  String get message => 'Spell $spellId is invalid: ${problems.join('; ')}';

  @override
  String toString() => 'InvalidSpellException: $message';
}
