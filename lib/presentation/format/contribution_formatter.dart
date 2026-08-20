import 'package:eruditus/engine/contribution_source.dart';
import 'package:eruditus/l10n/app_localizations.dart';

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
