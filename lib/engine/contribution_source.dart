import 'package:equatable/equatable.dart';

/// Which of the three parameter slots a [SlotContribution] charges for.
enum ParameterSlot { range, duration, target }

/// What produced one line of a level calculation, as structure rather than
/// prose.
///
/// The engine has no BuildContext and so no locale: composing a display string
/// here made the level breakdown untranslatable in principle. Each variant
/// names its operands and leaves the wording to
/// `presentation/format/contribution_formatter.dart`.
///
/// Sealed on purpose. A sixth variant will not compile until the formatter's
/// switch handles it, so no contribution can reach the screen unlocalised.
sealed class ContributionSource extends Equatable {
  const ContributionSource();
}

/// The guideline's own base level. [description] is rulebook content.
final class BaseEffectContribution extends ContributionSource {
  final String description;

  const BaseEffectContribution(this.description);

  @override
  List<Object?> get props => [description];
}

/// One Range/Duration/Target line. [actualName] and [referenceName] are
/// rulebook content; a non-null [referenceName] means the guideline was priced
/// against a different parameter and the delta is being explained.
final class SlotContribution extends ContributionSource {
  final ParameterSlot slot;
  final String actualName;
  final String? referenceName;

  const SlotContribution({
    required this.slot,
    required this.actualName,
    this.referenceName,
  });

  @override
  List<Object?> get props => [slot, actualName, referenceName];
}

/// A requisite Art and the parameter driving it. [art] is Latin and is never
/// translated; [parameterName] is rulebook content.
final class RequisiteContribution extends ContributionSource {
  final String art;
  final String parameterName;

  const RequisiteContribution({required this.art, required this.parameterName});

  @override
  List<Object?> get props => [art, parameterName];
}

/// A one-off level adjustment.
///
/// [note] is USER CONTENT — prose the caster typed. It renders verbatim under
/// every locale, never enters an ARB file, and is exempt from the pseudo-locale
/// transform.
final class AdjustmentContribution extends ContributionSource {
  final String note;

  const AdjustmentContribution(this.note);

  @override
  List<Object?> get props => [note];
}

/// A selected modifier option. Both fields are rulebook content.
final class ModifierContribution extends ContributionSource {
  final String modifierName;
  final String optionLabel;

  const ModifierContribution({
    required this.modifierName,
    required this.optionLabel,
  });

  @override
  List<Object?> get props => [modifierName, optionLabel];
}
