import 'package:eruditus/engine/spell_level_calculator.dart';
import 'package:eruditus/models/base_effect.dart';
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

  SpellEngine({
    required this.allSpells,
    required this.allSpecialFactors,
  });

  /// Replaces the known special factors used for magnitude lookups in
  /// [calculateSpellLevel]. Called whenever the Settings tab's configured
  /// special factors change, so a newly added custom factor becomes usable
  /// in the Create tab immediately.
  void updateSpecialFactors(List<SpecialFactor> factors) {
    allSpecialFactors = factors;
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

    return errors;
  }

  int calculateSpellLevel({
    required BaseEffect baseEffect,
    required SelectedParameter range,
    required SelectedParameter duration,
    required SelectedParameter target,
    required List<String> selectedSpecialFactorIds,
    required List<AdditionalRequisite> additionalRequisites,
  }) {
    final magnitudes = <int>[
      range.parameter.magnitude,
      duration.parameter.magnitude,
      target.parameter.magnitude,
      // A selected factor id that no longer resolves against
      // allSpecialFactors (e.g. a custom factor the user deleted in Settings
      // after saving a spell that referenced it) contributes 0 magnitude
      // rather than throwing. A dangling reference shouldn't make an
      // otherwise-valid spell's level uncomputable -- see
      // SpellLibraryBloc.LibraryRequested, which computes this for every
      // saved spell and would otherwise drop the whole Library tab into its
      // error state over one bad reference.
      for (final id in selectedSpecialFactorIds)
        for (final f in allSpecialFactors.where((f) => f.id == id).take(1))
          f.magnitude,
      ...additionalRequisites.map((r) => r.magnitude),
    ];

    return SpellLevelCalculator.calculate(baseEffect.baseLevel, magnitudes);
  }

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
          additionalRequisites: a.additionalRequisites,
        );
        final levelB = calculateSpellLevel(
          baseEffect: b.baseEffect,
          range: b.range,
          duration: b.duration,
          target: b.target,
          selectedSpecialFactorIds: b.selectedSpecialFactorIds,
          additionalRequisites: b.additionalRequisites,
        );
        return (levelA - referenceLevel).abs().compareTo((levelB - referenceLevel).abs());
      });
    }

    return matches;
  }
}
