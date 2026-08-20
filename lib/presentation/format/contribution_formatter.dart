import 'package:eruditus/engine/contribution_source.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/spell_validation_error.dart';

/// Words a [ContributionSource] for display.
///
/// The switch is exhaustive over the sealed type, so a new variant will not
/// compile until it has wording here. That is the point: it makes "did we miss
/// a string?" a compile error rather than a review question.
String formatContribution(AppLocalizations l10n, ContributionSource source) =>
    switch (source) {
      BaseEffectContribution(:final description) =>
        l10n.contributionBaseEffect(description),
      SlotContribution(:final slot, :final actualName, referenceName: null) =>
        l10n.contributionSlot(_slotName(l10n, slot), actualName),
      SlotContribution(
        :final slot,
        :final actualName,
        :final referenceName?
      ) =>
        l10n.contributionSlotAssumes(
            _slotName(l10n, slot), actualName, referenceName),
      RequisiteContribution(:final art, :final parameterName) =>
        l10n.contributionRequisite(art, parameterName),
      AdjustmentContribution(:final note) => l10n.contributionAdjustment(note),
      ModifierContribution(:final modifierName, :final optionLabel) =>
        l10n.contributionModifier(modifierName, optionLabel),
    };

/// gen-l10n cannot generate a getter keyed by a Dart enum, so the mapping lives
/// here. Exhaustive for the same reason as above.
String _slotName(AppLocalizations l10n, ParameterSlot slot) => switch (slot) {
      ParameterSlot.range => l10n.slotRange,
      ParameterSlot.duration => l10n.slotDuration,
      ParameterSlot.target => l10n.slotTarget,
    };

/// Rulebook-derived wording for an [OpenSlotKind], matching the rulebook's
/// own phrasing rather than the bare enum name. Deliberately not localized
/// via `l10n` -- see the `@description` on `validationOpenSlotNotChosen` /
/// `validationChosenSlotNotOpen` in the ARB: this is rulebook content passed
/// through as an operand, the same category as a Range or Target name.
String _openSlotKindWord(OpenSlotKind kind) => switch (kind) {
      OpenSlotKind.realm => 'realm',
      OpenSlotKind.form => 'Form',
      OpenSlotKind.specificType => 'specific type of enchantment',
    };

/// Joins declared open-slot kinds the way pevi-G10's two alternatives read:
/// "Form or a specific type of enchantment". A single kind needs no join --
/// every other catalog entry declares exactly one.
String _openSlotKindNames(List<OpenSlotKind> kinds) => kinds.length == 1
    ? _openSlotKindWord(kinds.single)
    : kinds.map(_openSlotKindWord).join(' or a ');

/// Words a [LevelUnavailableReason] for display.
///
/// Exhaustive for the same reason as [formatContribution]: a new reason will
/// not compile until it has wording here.
String formatUnavailableReason(
        AppLocalizations l10n, LevelUnavailableReason reason) =>
    switch (reason) {
      LevelUnavailableReason.noBaseEffect => l10n.levelUnavailableNoBaseEffect,
      LevelUnavailableReason.generalLevelNotTyped =>
        l10n.levelUnavailableGeneralLevelNotTyped,
      LevelUnavailableReason.generalLevelBelowOne =>
        l10n.levelUnavailableGeneralLevelBelowOne,
      LevelUnavailableReason.parametersIncomplete =>
        l10n.levelUnavailableParametersIncomplete,
      LevelUnavailableReason.magnitudesBelowOne =>
        l10n.levelUnavailableMagnitudesBelowOne,
    };

/// Words a [SpellValidationError] for display.
///
/// Exhaustive for the same reason as [formatContribution]: a new variant will
/// not compile until it has wording here.
String formatValidationError(AppLocalizations l10n, SpellValidationError error) =>
    switch (error) {
      TechniqueMissing() => l10n.validationTechniqueMissing,
      FormMissing() => l10n.validationFormMissing,
      BaseEffectMissing() => l10n.validationBaseEffectMissing,
      RangeMissing() => l10n.validationRangeMissing,
      DurationMissing() => l10n.validationDurationMissing,
      TargetMissing() => l10n.validationTargetMissing,
      MagnitudesBelowOne() => l10n.validationMagnitudesBelowOne,
      GeneralLevelNotChosen() => l10n.validationGeneralLevelNotChosen,
      ChosenLevelBelowOne() => l10n.validationChosenLevelBelowOne,
      ChosenLevelNotGeneral() => l10n.validationChosenLevelNotGeneral,
      RequisiteIsOwnArt() => l10n.validationRequisiteIsOwnArt,
      AnalogyRationaleMissing() => l10n.validationAnalogyRationaleMissing,
      AnalogyRationaleUnwanted() => l10n.validationAnalogyRationaleUnwanted,
      ModifierNotMultiSelect(:final modifierName) =>
        l10n.validationModifierNotMultiSelect(modifierName),
      OpenSlotNotChosen(:final kinds) =>
        l10n.validationOpenSlotNotChosen(_openSlotKindNames(kinds)),
      ChosenSlotNotOpen(:final kind, :final rawName) =>
        l10n.validationChosenSlotNotOpen(
            kind != null ? _openSlotKindWord(kind) : rawName),
      ContainerModeOnNonContainer(:final targetName) =>
        l10n.validationContainerModeOnNonContainer(targetName),
      RangeForbidsTarget(:final rangeName, :final targetName, :final targetKind) =>
        l10n.validationRangeForbidsTarget(rangeName, targetName, targetKind),
      RangeRequiredByTarget(
        :final targetName,
        :final requiredRangeId,
        :final rangeName
      ) =>
        l10n.validationRangeRequiredByTarget(
            targetName, requiredRangeId, rangeName),
      TechniqueExcludedByTarget(:final targetName, :final technique) =>
        l10n.validationTechniqueExcludedByTarget(targetName, technique),
      RequisiteArtExcludedByTarget(:final targetName, :final art) =>
        l10n.validationRequisiteArtExcludedByTarget(targetName, art),
    };
