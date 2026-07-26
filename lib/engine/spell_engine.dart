import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/spell_level_calculator.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/special_factor.dart';

class SpellEngine {
  final List<Spell> allSpells;

  // Mutable (not final): custom special factors can be added at runtime via
  // ConfigurationBloc (Settings tab) after this engine is constructed. See
  // [updateSpecialFactors] and SpellCreationBloc's handling of
  // AvailableFactorsSynced, which keeps this in sync so a newly added custom
  // factor's magnitude can be resolved without an app restart.
  List<SpecialFactor> allSpecialFactors;

  // Mutable (not final): custom modifiers can be added at runtime via
  // ConfigurationBloc (Settings tab) after this engine is constructed, same
  // as allSpecialFactors above. See [updateModifiers].
  List<Modifier> allModifiers;

  SpellEngine({
    required this.allSpells,
    required this.allSpecialFactors,
    this.allModifiers = const [],
  });

  /// Replaces the known special factors used for magnitude lookups in
  /// [calculateSpellLevel]. Called whenever the Settings tab's configured
  /// special factors change, so a newly added custom factor becomes usable
  /// in the Create tab immediately.
  void updateSpecialFactors(List<SpecialFactor> factors) {
    allSpecialFactors = factors;
  }

  /// Replaces the known modifiers used for magnitude lookups in
  /// [calculateBreakdown]. Called whenever the Settings tab's configured
  /// modifiers change, so a newly added custom modifier becomes usable in the
  /// Create tab immediately.
  void updateModifiers(List<Modifier> modifiers) {
    allModifiers = modifiers;
  }

  List<String> validateSpellDraft(SpellDraft draft) {
    final errors = <String>[];

    if (draft.technique == null || draft.technique!.isEmpty) {
      errors.add('Technique must be selected');
    }

    if (draft.form == null || draft.form!.isEmpty) {
      errors.add('Form must be selected');
    }

    if (draft.baseEffect == null) {
      errors.add('Base effect must be selected');
    }

    if (draft.range == null) {
      errors.add('Range must be selected');
    }

    if (draft.duration == null) {
      errors.add('Duration must be selected');
    }

    if (draft.target == null) {
      errors.add('Target must be selected');
    }

    // Validate requisites: no art can equal the spell's own technique or form.
    final seenArts = <String>{};
    for (final req in draft.requisites) {
      if (req.art == draft.technique || req.art == draft.form) {
        errors.add('Requisite art cannot be the spell\'s own technique or form');
      }
      if (seenArts.contains(req.art)) {
        errors.add('Duplicate requisite art: ${req.art}');
      }
      seenArts.add(req.art);
    }

    return errors;
  }

  LevelBreakdown calculateBreakdown({
    required BaseEffect baseEffect,
    required SelectedParameter range,
    required SelectedParameter duration,
    required SelectedParameter target,
    required List<String> selectedSpecialFactorIds,
    required Map<String, List<String>> selectedModifiers,
    required List<Requisite> requisites,
  }) {
    final contributions = <LevelContribution>[
      LevelContribution(
          label: 'Base effect · ${baseEffect.description}',
          magnitude: baseEffect.baseLevel,
          isBase: true),
      LevelContribution(
          label: 'Range · ${range.parameter.name}', magnitude: range.parameter.magnitude),
      LevelContribution(
          label: 'Duration · ${duration.parameter.name}', magnitude: duration.parameter.magnitude),
      LevelContribution(
          label: 'Target · ${target.parameter.name}', magnitude: target.parameter.magnitude),
    ];

    for (final requisite in requisites) {
      contributions.add(LevelContribution(
          label: 'Requisite · ${requisite.art}, ${requisite.kind.name}',
          magnitude: requisite.magnitude));
    }

    // A selected id that no longer resolves (a factor or modifier deleted
    // after the spell was saved) contributes 0 rather than throwing. See
    // SpellLibraryBloc.LibraryRequested, which computes this for every saved
    // spell and would otherwise drop the Library tab into its error state.
    for (final id in selectedSpecialFactorIds) {
      for (final factor in allSpecialFactors.where((f) => f.id == id).take(1)) {
        contributions.add(
            LevelContribution(label: 'Factor · ${factor.name}', magnitude: factor.magnitude));
      }
    }

    selectedModifiers.forEach((modifierId, optionIds) {
      for (final modifier in allModifiers.where((m) => m.id == modifierId).take(1)) {
        for (final optionId in optionIds) {
          final option = modifier.optionById(optionId);
          if (option == null) continue;
          contributions.add(LevelContribution(
              label: '${modifier.name} · ${option.label}', magnitude: option.magnitude));
        }
      }
    });

    final magnitudes = [
      for (final contribution in contributions)
        if (!contribution.isBase) contribution.magnitude,
    ];

    return LevelBreakdown(
      level: SpellLevelCalculator.calculate(baseEffect.baseLevel, magnitudes),
      contributions: contributions,
    );
  }

  int calculateSpellLevel({
    required BaseEffect baseEffect,
    required SelectedParameter range,
    required SelectedParameter duration,
    required SelectedParameter target,
    required List<String> selectedSpecialFactorIds,
    Map<String, List<String>> selectedModifiers = const {},
    required List<Requisite> requisites,
  }) =>
      calculateBreakdown(
        baseEffect: baseEffect,
        range: range,
        duration: duration,
        target: target,
        selectedSpecialFactorIds: selectedSpecialFactorIds,
        selectedModifiers: selectedModifiers,
        requisites: requisites,
      ).level;

  List<Spell> findSimilarSpells(String technique, String form, {int? referenceLevel}) {
    final matches = allSpells
        .where((spell) => spell.technique == technique && spell.form == form)
        .toList();

    if (referenceLevel != null) {
      matches.sort((a, b) {
        final levelA = calculateSpellLevel(
          baseEffect: a.baseEffect,
          range: a.range,
          duration: a.duration,
          target: a.target,
          selectedSpecialFactorIds: a.selectedSpecialFactorIds,
          requisites: a.requisites,
        );
        final levelB = calculateSpellLevel(
          baseEffect: b.baseEffect,
          range: b.range,
          duration: b.duration,
          target: b.target,
          selectedSpecialFactorIds: b.selectedSpecialFactorIds,
          requisites: b.requisites,
        );
        return (levelA - referenceLevel).abs().compareTo((levelB - referenceLevel).abs());
      });
    }

    return matches;
  }
}
