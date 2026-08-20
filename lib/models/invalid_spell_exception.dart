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

  /// A diagnostic message, not user-facing prose.
  ///
  /// `backup_screen.dart` surfaces only `spellId` from a batch of these, but
  /// `SpellCreationBloc._handleSpellSaveRequested` catches
  /// `InvalidSpellException` specifically on the single-save path and reads
  /// [problems] directly into `SpellCreationState.validationErrors` -- the
  /// same structured, already-localised channel `validateSpellDraft`
  /// populates -- rather than calling [toString] or this getter. Do not
  /// route this string to a user: [SpellValidationError]'s variants are
  /// `Equatable`, whose default `toString()` prints each variant's bare name
  /// and field values (e.g. `RequisiteIsOwnArt()`), and the plain `join`
  /// below has no locale to render in -- neither is fit for display.
  String get message => 'Spell $spellId is invalid: ${problems.join('; ')}';

  @override
  String toString() => 'InvalidSpellException: $message';
}
