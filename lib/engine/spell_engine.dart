import 'package:eruditus/engine/spell_level_calculator.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/special_factor.dart';

class SpellEngine {
  final List<Spell> allSpells;
  final List<SpecialFactor> allSpecialFactors;

  SpellEngine({
    required this.allSpells,
    required this.allSpecialFactors,
  });

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

    return errors;
  }

  int calculateSpellLevel({
    required BaseEffect baseEffect,
    required List<SelectedParameter> parameters,
    required List<String> selectedSpecialFactorIds,
    required List<AdditionalRequisite> additionalRequisites,
  }) {
    final magnitudes = <int>[
      ...parameters.map((p) => p.parameter.magnitude),
      ...selectedSpecialFactorIds.map((id) =>
          allSpecialFactors.firstWhere((f) => f.id == id).magnitude),
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
          parameters: a.parameters,
          selectedSpecialFactorIds: a.selectedSpecialFactorIds,
          additionalRequisites: a.additionalRequisites,
        );
        final levelB = calculateSpellLevel(
          baseEffect: b.baseEffect,
          parameters: b.parameters,
          selectedSpecialFactorIds: b.selectedSpecialFactorIds,
          additionalRequisites: b.additionalRequisites,
        );
        return (levelA - referenceLevel).abs().compareTo((levelB - referenceLevel).abs());
      });
    }

    return matches;
  }
}
