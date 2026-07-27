import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/engine/spell_level_calculator.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart';

class SpellEngine {
  final List<ResolvedSpell> allSpells;

  // Mutable (not final): custom modifiers can be added at runtime via
  // ConfigurationBloc (Settings tab) after this engine is constructed. See
  // [updateModifiers].
  List<Modifier> allModifiers;

  SpellEngine({
    required this.allSpells,
    this.allModifiers = const [],
  });

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

    draft.selectedModifiers.forEach((modifierId, optionIds) {
      for (final modifier in allModifiers.where((m) => m.id == modifierId).take(1)) {
        if (modifier.selectionMode == ModifierSelectionMode.single && optionIds.length > 1) {
          errors.add('Only one option may be selected for ${modifier.name}');
        }
      }
    });

    return errors;
  }

  LevelBreakdown calculateBreakdown({
    required BaseEffect baseEffect,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    required Map<String, List<String>> selectedModifiers,
    required List<Requisite> requisites,
    RitualDeclaration ritualDeclaration = RitualDeclaration.none,
  }) {
    final contributions = <LevelContribution>[
      LevelContribution(
          label: 'Base effect · ${baseEffect.description}',
          magnitude: baseEffect.baseLevel,
          isBase: true),
      LevelContribution(label: 'Range · ${range.name}', magnitude: range.magnitude),
      LevelContribution(label: 'Duration · ${duration.name}', magnitude: duration.magnitude),
      LevelContribution(label: 'Target · ${target.name}', magnitude: target.magnitude),
    ];

    for (final requisite in requisites) {
      contributions.add(LevelContribution(
          label: 'Requisite · ${requisite.art}, ${requisite.kind.name}',
          magnitude: requisite.magnitude));
    }

    // A selected id that no longer resolves (a modifier deleted after the
    // spell was saved) contributes 0 rather than throwing. See
    // SpellLibraryBloc.LibraryRequested, which computes this for every saved
    // spell and would otherwise drop the Library tab into its error state.
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

    final rawLevel = SpellLevelCalculator.calculate(baseEffect.baseLevel, magnitudes);

    final ritualStatus = _deriveRitualStatus(
      baseEffect: baseEffect,
      duration: duration,
      target: target,
      ritualDeclaration: ritualDeclaration,
      rawLevel: rawLevel,
    );

    // Single pass, no fixed point: the floor only ever raises a level TO 20,
    // and 20 is below the Formulaic cap of 50, so applying it can never
    // trigger the exceedsMaxFormulaicLevel reason that was just evaluated.
    // ritual_status_test.dart asserts that invariant on the constants.
    final level = ritualStatus.isRitual && rawLevel < RitualStatus.minimumRitualLevel
        ? RitualStatus.minimumRitualLevel
        : rawLevel;

    return LevelBreakdown(
      level: level,
      rawLevel: rawLevel,
      ritualStatus: ritualStatus,
      contributions: contributions,
    );
  }

  /// Every reason [rawLevel]'s spell is a Ritual, accumulated in a stable
  /// order. Declarations are honoured unconditionally — a storyguide ruling is
  /// legitimate on any spell by definition, and keeping a live draft's
  /// declaration meaningful is the bloc's job, not the engine's.
  RitualStatus _deriveRitualStatus({
    required BaseEffect baseEffect,
    required Parameter duration,
    required Parameter target,
    required RitualDeclaration ritualDeclaration,
    required int rawLevel,
  }) {
    final reasons = <RitualReason>[];

    if (duration.requiresRitual) reasons.add(RitualReason.ritualOnlyDuration);
    if (target.requiresRitual) reasons.add(RitualReason.ritualOnlyTarget);
    if (baseEffect.ritualRequirement == RitualRequirement.required) {
      reasons.add(RitualReason.guideline);
    }
    if (rawLevel > RitualStatus.maxFormulaicLevel) {
      reasons.add(RitualReason.exceedsMaxFormulaicLevel);
    }
    switch (ritualDeclaration) {
      case RitualDeclaration.lastingCreation:
        reasons.add(RitualReason.lastingCreation);
      case RitualDeclaration.storyguideRuling:
        reasons.add(RitualReason.storyguideRuling);
      case RitualDeclaration.none:
        break;
    }

    return RitualStatus(reasons);
  }

  int calculateSpellLevel({
    required BaseEffect baseEffect,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    Map<String, List<String>> selectedModifiers = const {},
    required List<Requisite> requisites,
    RitualDeclaration ritualDeclaration = RitualDeclaration.none,
  }) =>
      calculateBreakdown(
        baseEffect: baseEffect,
        range: range,
        duration: duration,
        target: target,
        selectedModifiers: selectedModifiers,
        requisites: requisites,
        ritualDeclaration: ritualDeclaration,
      ).level;

  List<ResolvedSpell> findSimilarSpells(String technique, String form, {int? referenceLevel}) {
    final matches = allSpells
        .where((s) => s.isResolved && s.technique == technique && s.form == form)
        .toList();

    if (referenceLevel != null) {
      matches.sort((a, b) {
        final levelA = calculateSpellLevel(
          baseEffect: a.baseEffect!, range: a.range!, duration: a.duration!, target: a.target!,
          selectedModifiers: a.selectedModifiers, requisites: a.requisites,
          ritualDeclaration: a.ritualDeclaration,
        );
        final levelB = calculateSpellLevel(
          baseEffect: b.baseEffect!, range: b.range!, duration: b.duration!, target: b.target!,
          selectedModifiers: b.selectedModifiers, requisites: b.requisites,
          ritualDeclaration: b.ritualDeclaration,
        );
        return (levelA - referenceLevel).abs().compareTo((levelB - referenceLevel).abs());
      });
    }

    return matches;
  }

  /// Drops any selection whose modifier no longer applies to the draft. A
  /// stranded selection would otherwise keep contributing magnitude invisibly
  /// after the caster changes Technique, Form or base effect.
  Map<String, List<String>> pruneModifierSelections({
    required Map<String, List<String>> selectedModifiers,
    String? technique,
    String? form,
    String? baseEffectId,
  }) {
    final kept = <String, List<String>>{};
    selectedModifiers.forEach((modifierId, optionIds) {
      for (final modifier in allModifiers.where((m) => m.id == modifierId).take(1)) {
        if (modifier.scope.appliesTo(
            technique: technique, form: form, baseEffectId: baseEffectId)) {
          kept[modifierId] = optionIds;
        }
      }
    });
    return kept;
  }
}
