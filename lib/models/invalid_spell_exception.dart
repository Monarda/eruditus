import 'package:eruditus/models/spell_validation_error.dart';

/// Thrown when a write is refused because the spell breaks a catalog-dependent
/// invariant — see `validateSpellAgainstCatalog`.
///
/// Blocking rather than degrading is a deliberate decision (spec decision 1),
/// flagged as revisitable: a spell that becomes invalid *after* it was written
/// is degraded instead, via `ResolvedSpell.problems`, because there is no write
/// to refuse in that case.
class InvalidSpellException implements Exception {
  final String spellId;
  final List<SpellValidationError> problems;

  InvalidSpellException(this.spellId, this.problems);

  /// A diagnostic message, not user-facing prose: this class has no locale to
  /// render [problems] with (the same reason they are structured rather than
  /// English in the first place), so this names the variants rather than
  /// wording them. No caller renders this to a user today -- see
  /// `backup_screen.dart`, which surfaces only `spellId` from a batch of
  /// these.
  String get message =>
      'Spell $spellId is invalid: ${problems.map((p) => p.runtimeType).join('; ')}';

  @override
  String toString() => 'InvalidSpellException: $message';
}
