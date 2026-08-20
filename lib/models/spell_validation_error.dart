import 'package:equatable/equatable.dart';

/// Why a spell draft or record fails validation, as structure rather than
/// prose.
///
/// `validateSpellDraft` and `validateSpellAgainstCatalog` run in domain code
/// with no BuildContext and so no locale: composing a display string there
/// made every validation message untranslatable in principle. Each variant
/// names its operands and leaves the wording to
/// `presentation/format/contribution_formatter.dart`. Results render in three
/// places: the creation screen's validation list, and `ResolvedSpell.problems`
/// on spell cards in both the creation screen and the library screen.
///
/// Sealed on purpose, mirroring [ContributionSource]: a twenty-second variant
/// will not compile until the formatter's switch handles it, so no problem can
/// reach the screen unlocalised.
sealed class SpellValidationError extends Equatable {
  const SpellValidationError();
}

/// `validateSpellDraft`'s six field-presence checks and its own "no
/// computable level" check. No operands.
final class TechniqueMissing extends SpellValidationError {
  const TechniqueMissing();

  @override
  List<Object?> get props => const [];
}

final class FormMissing extends SpellValidationError {
  const FormMissing();

  @override
  List<Object?> get props => const [];
}

final class BaseEffectMissing extends SpellValidationError {
  const BaseEffectMissing();

  @override
  List<Object?> get props => const [];
}

final class RangeMissing extends SpellValidationError {
  const RangeMissing();

  @override
  List<Object?> get props => const [];
}

final class DurationMissing extends SpellValidationError {
  const DurationMissing();

  @override
  List<Object?> get props => const [];
}

final class TargetMissing extends SpellValidationError {
  const TargetMissing();

  @override
  List<Object?> get props => const [];
}

/// A draft whose negative magnitudes drive it below level 1. Distinct from
/// [LevelUnavailableReason.magnitudesBelowOne] (`level_breakdown.dart`) —
/// same fact, reached by a different path (the save button, not the live
/// preview), with different rendered text (no trailing full stop here).
final class MagnitudesBelowOne extends SpellValidationError {
  const MagnitudesBelowOne();

  @override
  List<Object?> get props => const [];
}

/// `validateSpellAgainstCatalog` check 1: a General guideline's level comes
/// from the caster, so it must be present.
final class GeneralLevelNotChosen extends SpellValidationError {
  const GeneralLevelNotChosen();

  @override
  List<Object?> get props => const [];
}

/// `validateSpellAgainstCatalog` check 1's converse: a chosen level below 1.
final class ChosenLevelBelowOne extends SpellValidationError {
  const ChosenLevelBelowOne();

  @override
  List<Object?> get props => const [];
}

/// `validateSpellAgainstCatalog` check 2: a chosen base level on a
/// non-General guideline is stray, meaningless stored data.
final class ChosenLevelNotGeneral extends SpellValidationError {
  const ChosenLevelNotGeneral();

  @override
  List<Object?> get props => const [];
}

/// `validateSpellAgainstCatalog` check 3: a requisite naming the spell's own
/// Art is meaningless.
final class RequisiteIsOwnArt extends SpellValidationError {
  const RequisiteIsOwnArt();

  @override
  List<Object?> get props => const [];
}

/// `validateSpellAgainstCatalog` check 8: Technique/Form differs from the
/// base effect's own, with no explanation.
final class AnalogyRationaleMissing extends SpellValidationError {
  const AnalogyRationaleMissing();

  @override
  List<Object?> get props => const [];
}

/// `validateSpellAgainstCatalog` check 8's converse: an explanation attached
/// to a spell that doesn't actually differ.
final class AnalogyRationaleUnwanted extends SpellValidationError {
  const AnalogyRationaleUnwanted();

  @override
  List<Object?> get props => const [];
}

/// `validateSpellAgainstCatalog` check 5: more than one option selected for a
/// single-select modifier. [modifierName] is rulebook content.
final class ModifierNotMultiSelect extends SpellValidationError {
  final String modifierName;

  const ModifierNotMultiSelect(this.modifierName);

  @override
  List<Object?> get props => [modifierName];
}

/// `validateSpellAgainstCatalog` check 6: an open slot the guideline declares
/// mandatory has not been filled. [kindNames] is rulebook content, already
/// joined for the "or" case (e.g. pevi-G10's Form OR a specific type).
final class OpenSlotNotChosen extends SpellValidationError {
  final String kindNames;

  const OpenSlotNotChosen(this.kindNames);

  @override
  List<Object?> get props => [kindNames];
}

/// `validateSpellAgainstCatalog` check 7: stray chosen-slot data for a kind
/// this guideline never declared open. [description] is rulebook content and
/// appears twice in the rendered sentence.
final class ChosenSlotNotOpen extends SpellValidationError {
  final String description;

  const ChosenSlotNotOpen(this.description);

  @override
  List<Object?> get props => [description];
}

/// `validateSpellAgainstCatalog` check 9: a container mode stated on a
/// non-container Target. [targetName] is rulebook content.
final class ContainerModeOnNonContainer extends SpellValidationError {
  final String targetName;

  const ContainerModeOnNonContainer(this.targetName);

  @override
  List<Object?> get props => [targetName];
}

/// `validateSpellAgainstCatalog` check 10: Core Rules 12086 -- a Personal
/// Range spell can never have a container Target. All three fields are
/// rulebook content.
final class RangeForbidsTarget extends SpellValidationError {
  final String rangeName;
  final String targetName;
  final String targetKind;

  const RangeForbidsTarget({
    required this.rangeName,
    required this.targetName,
    required this.targetKind,
  });

  @override
  List<Object?> get props => [rangeName, targetName, targetKind];
}

/// `validateSpellAgainstCatalog` check 11: HoH:MC 1006 -- a Target that
/// dictates its spell's Range (e.g. Sensory Magic requires Personal).
/// [requiredRangeId] is a catalog id, not a display name -- this function has
/// no parameter catalog to resolve it against. [targetName] and [rangeName]
/// are rulebook content.
final class RangeRequiredByTarget extends SpellValidationError {
  final String targetName;
  final String requiredRangeId;
  final String rangeName;

  const RangeRequiredByTarget({
    required this.targetName,
    required this.requiredRangeId,
    required this.rangeName,
  });

  @override
  List<Object?> get props => [targetName, requiredRangeId, rangeName];
}

/// `validateSpellAgainstCatalog` check 12, first half: HoH:MC 1009 -- a
/// Sensory Magic Target cannot be combined with its excluded Technique.
/// [targetName] and [technique] are rulebook content.
final class TechniqueExcludedByTarget extends SpellValidationError {
  final String targetName;
  final String technique;

  const TechniqueExcludedByTarget({
    required this.targetName,
    required this.technique,
  });

  @override
  List<Object?> get props => [targetName, technique];
}

/// `validateSpellAgainstCatalog` check 12, second half: the same exclusion,
/// checked against each requisite Art. [targetName] and [art] are rulebook
/// content.
final class RequisiteArtExcludedByTarget extends SpellValidationError {
  final String targetName;
  final String art;

  const RequisiteArtExcludedByTarget({
    required this.targetName,
    required this.art,
  });

  @override
  List<Object?> get props => [targetName, art];
}
