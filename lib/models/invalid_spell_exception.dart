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

  /// A diagnostic message, not user-facing prose: no caller renders this to a
  /// user today -- see `backup_screen.dart`, which surfaces only `spellId`
  /// from a batch of these. The plain `join` below still reads well because
  /// [SpellValidationError]'s variants are `Equatable`, whose default
  /// `toString()` prints each variant's name and field values
  /// (`EquatableConfig.stringify` is true under asserts, which covers
  /// `flutter test` and every debug build) -- there is no need to hand-roll
  /// wording here just because this class, like [SpellValidationError]
  /// itself, has no locale to render one in.
  String get message => 'Spell $spellId is invalid: ${problems.join('; ')}';

  @override
  String toString() => 'InvalidSpellException: $message';
}
