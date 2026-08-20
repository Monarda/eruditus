import 'package:collection/collection.dart';
import 'package:eruditus/engine/contribution_source.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/engine/spell_level_calculator.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/general_effect_formula.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_validation_error.dart';

class SpellEngine {
  final List<ResolvedSpell> allSpells;

  // Mutable (not final): custom modifiers can be added at runtime via
  // ConfigurationBloc (Settings tab) after this engine is constructed. See
  // [updateModifiers].
  List<Modifier> allModifiers;

  // Mutable for the same reason as [allModifiers]: kept in sync so
  // [_parameterById] can resolve a General guideline's reference parameter
  // (e.g. Touch for a ward) without the caller having to thread the whole
  // catalog through every call.
  List<Parameter> allParameters;

  SpellEngine({
    required this.allSpells,
    this.allModifiers = const [],
    this.allParameters = const [],
  });

  /// Replaces the known modifiers used for magnitude lookups in
  /// [calculateBreakdown]. Called whenever the Settings tab's configured
  /// modifiers change, so a newly added custom modifier becomes usable in the
  /// Create tab immediately.
  void updateModifiers(List<Modifier> modifiers) {
    allModifiers = modifiers;
  }

  /// Replaces the known parameters used to resolve a reference id in
  /// [_parameterContribution]. Mirrors [updateModifiers].
  void updateParameters(List<Parameter> parameters) {
    allParameters = parameters;
  }

  Parameter? _parameterById(String id) =>
      allParameters.where((p) => p.id == id).firstOrNull;

  List<SpellValidationError> validateSpellDraft(SpellDraft draft) {
    final errors = <SpellValidationError>[];

    if (draft.technique == null || draft.technique!.isEmpty) {
      errors.add(const TechniqueMissing());
    }

    if (draft.form == null || draft.form!.isEmpty) {
      errors.add(const FormMissing());
    }

    if (draft.baseEffect == null) {
      errors.add(const BaseEffectMissing());
    }

    if (draft.range == null) {
      errors.add(const RangeMissing());
    }

    if (draft.duration == null) {
      errors.add(const DurationMissing());
    }

    if (draft.target == null) {
      errors.add(const TargetMissing());
    }

    // The catalog-dependent invariants live in one place, shared with
    // SpellRepository's write-time block and ResolvedSpell.problems, so the
    // draft path and the record path cannot drift.
    if (draft.baseEffect != null && draft.technique != null && draft.form != null) {
      errors.addAll(validateSpellAgainstCatalog(
        effect: draft.baseEffect!,
        technique: draft.technique ?? '',
        form: draft.form ?? '',
        analogyRationale: draft.analogyRationale,
        chosenBaseLevel: draft.chosenBaseLevel,
        requisites: draft.requisites,
        selectedModifiers: draft.selectedModifiers,
        modifiers: allModifiers,
        chosenSlots: draft.chosenSlots,
        range: draft.range,
        target: draft.target,
        containerMode: draft.containerMode,
      ));
    }

    // Last, and only once the draft is complete enough to compute: a draft
    // whose negative magnitudes drive the level below 1 has no level at all.
    // SpellLevelCalculator signals that by throwing, and nothing downstream
    // catches it — SpellCreationBloc._handleSpellCalculated would take the
    // ArgumentError straight out of the handler, and _handleSpellSaveRequested
    // never calls the calculator at all, so an uncomputable draft would save.
    // Reported here instead, as one more validation message the creation
    // screen already renders -- and this check is also what keeps such a draft
    // out of the repository, because _handleSpellSaveRequested calls this
    // method before it writes anything and returns on the first non-empty
    // result (see the guard at the top of that method). Nothing in the UI can
    // stand in for it: Save renders unconditionally since todo item 59, so the
    // button is pressable on a draft that never calculated, and its
    // disabled-while-there-is-no-level state is an affordance rather than a
    // gate -- a dispatched SpellSaveRequested has to be safe on its own. The
    // motivating case is a stack of negative adjustments on an otherwise
    // complete draft: previewLevel already answers "no level" in the banner,
    // but only this line stops the same draft being saved.
    if (errors.isEmpty) {
      try {
        calculateBreakdown(
          baseEffect: draft.baseEffect!,
          chosenBaseLevel: draft.chosenBaseLevel,
          range: draft.range!,
          duration: draft.duration!,
          target: draft.target!,
          selectedModifiers: draft.selectedModifiers,
          requisites: draft.requisites,
          adjustments: draft.adjustments,
          ritualDeclaration: draft.ritualDeclaration,
        );
      } on ArgumentError {
        errors.add(const MagnitudesBelowOne());
      }
    }

    return errors;
  }

  /// [calculateBreakdown] for a draft that may not be finished — the level as
  /// it stands, or the single reason there isn't one.
  ///
  /// **This is not validation.** It answers "is there a number", not "is this
  /// spell legal": [validateSpellDraft] owns the catalog invariants and stays
  /// behind a button press, because its messages render as red text and firing
  /// them on every keystroke would flag a half-built draft as broken (todo
  /// item 59). This method's reasons are the opposite in tone — they say what
  /// to do next, not what is wrong.
  ///
  /// It exists because [calculateBreakdown] throws two ways that are ordinary
  /// intermediate states rather than errors: a General guideline before its
  /// level is typed, and a level that lands below 1. The button-driven path
  /// could let those escape, since nothing called it until the draft was
  /// finished. A live path cannot, so every throw is converted here and this
  /// method never throws.
  ///
  /// The below-1 throw arrives by two quite different routes and so gets two
  /// different reasons. A caster who typed `0` into the Guideline level field
  /// has an out-of-range base level and no magnitudes involved at all; a caster
  /// whose negative adjustments outran a legal base level has the opposite
  /// problem. Both reach the same ArgumentError from SpellLevelCalculator, so
  /// the General case is answered *before* the try below rather than inside its
  /// catch, which cannot tell them apart.
  ///
  /// A null Technique or Form needs no reason of its own: the base effect
  /// dropdown does not render without them
  /// (`spell_creation_screen.dart:115`), so the first branch covers it.
  LevelPreview previewLevel(SpellDraft draft) {
    final baseEffect = draft.baseEffect;
    if (baseEffect == null) {
      return const LevelPreview.unavailable(LevelUnavailableReason.noBaseEffect);
    }
    if (baseEffect.isGeneral) {
      final chosenBaseLevel = draft.chosenBaseLevel;
      if (chosenBaseLevel == null) {
        return const LevelPreview.unavailable(LevelUnavailableReason.generalLevelNotTyped);
      }
      // A typed `0` -- or a backspace down to it, which the field commits the
      // same way -- is not the null case above and not the magnitudes case
      // below. calculateBreakdown hands the chosen level straight to
      // SpellLevelCalculator, which rejects `baseLevel < 1` before a single
      // magnitude has been applied, so without this branch a bare `0` fell
      // through to the catch at the end of this method and reported
      // LevelUnavailableReason.magnitudesBelowOne on a draft that has no
      // magnitudes to blame. Found by hand-testing the live banner during item
      // 59's review, on a General guideline with the level field emptied.
      if (chosenBaseLevel < 1) {
        return const LevelPreview.unavailable(LevelUnavailableReason.generalLevelBelowOne);
      }
    }

    final range = draft.range;
    final duration = draft.duration;
    final target = draft.target;
    if (range == null || duration == null || target == null) {
      return const LevelPreview.unavailable(LevelUnavailableReason.parametersIncomplete);
    }

    try {
      return LevelPreview.available(calculateBreakdown(
        baseEffect: baseEffect,
        chosenBaseLevel: draft.chosenBaseLevel,
        range: range,
        duration: duration,
        target: target,
        selectedModifiers: draft.selectedModifiers,
        requisites: draft.requisites,
        adjustments: draft.adjustments,
        ritualDeclaration: draft.ritualDeclaration,
      ));
    } on ArgumentError {
      return const LevelPreview.unavailable(LevelUnavailableReason.magnitudesBelowOne);
    }
  }

  LevelBreakdown calculateBreakdown({
    required BaseEffect baseEffect,
    int? chosenBaseLevel,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    required Map<String, List<String>> selectedModifiers,
    required Map<String, RequisiteKind> requisites,
    List<LevelAdjustment> adjustments = const [],
    RitualDeclaration ritualDeclaration = RitualDeclaration.none,
  }) {
    final baseLevel = baseEffect.isGeneral ? chosenBaseLevel : baseEffect.baseLevel;
    if (baseLevel == null) {
      throw ArgumentError.value(
        chosenBaseLevel,
        'chosenBaseLevel',
        'A General guideline needs a chosen level',
      );
    }

    final contributions = <LevelContribution>[
      LevelContribution(
          source: BaseEffectContribution(baseEffect.description),
          magnitude: baseLevel,
          isBase: true),
      _parameterContribution(
          ParameterSlot.range, range, baseEffect.reference.rangeId),
      _parameterContribution(
          ParameterSlot.duration, duration, baseEffect.reference.durationId),
      _parameterContribution(
          ParameterSlot.target, target, baseEffect.reference.targetId),
    ];

    for (final entry in requisites.entries) {
      contributions.add(LevelContribution(
          source: RequisiteContribution(
              art: entry.key, parameterName: entry.value.name),
          magnitude: entry.value.magnitude));
    }

    // Adjustments are magnitudes like any other, so they flow into the same
    // calculator call below and need no special case there.
    for (final adjustment in adjustments) {
      contributions.add(LevelContribution(
          source: AdjustmentContribution(adjustment.note),
          magnitude: adjustment.magnitude));
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
              source: ModifierContribution(
                  modifierName: modifier.name, optionLabel: option.label),
              magnitude: option.magnitude));
        }
      }
    });

    final magnitudes = [
      for (final contribution in contributions)
        if (!contribution.isBase) contribution.magnitude,
    ];

    final rawLevel = SpellLevelCalculator.calculate(baseLevel, magnitudes);

    final ritualStatus = _deriveRitualStatus(
      baseEffect: baseEffect,
      range: range,
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

  /// One Range/Duration/Target line, charged as the difference between what
  /// the spell actually uses and what its guideline was priced against.
  ///
  /// For an ordinary guideline the reference is Personal/Momentary/Individual,
  /// all magnitude 0, so the delta equals the raw magnitude and the emitted
  /// label is unchanged. That identity is why this is one code path and not a
  /// branch on `isGeneral`.
  LevelContribution _parameterContribution(
      ParameterSlot slot, Parameter actual, String referenceId) {
    if (actual.id == referenceId) {
      return LevelContribution(
          source: SlotContribution(slot: slot, actualName: actual.name),
          magnitude: 0);
    }

    final reference = _parameterById(referenceId);
    if (reference == null || reference.magnitude == 0) {
      return LevelContribution(
          source: SlotContribution(slot: slot, actualName: actual.name),
          magnitude: actual.magnitude);
    }

    return LevelContribution(
      source: SlotContribution(
          slot: slot, actualName: actual.name, referenceName: reference.name),
      magnitude: actual.magnitude - reference.magnitude,
    );
  }

  /// Every reason [rawLevel]'s spell is a Ritual, accumulated in a stable
  /// order. Declarations are honoured unconditionally — a storyguide ruling is
  /// legitimate on any spell by definition, and keeping a live draft's
  /// declaration meaningful is the bloc's job, not the engine's.
  RitualStatus _deriveRitualStatus({
    required BaseEffect baseEffect,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    required RitualDeclaration ritualDeclaration,
    required int rawLevel,
  }) {
    final reasons = <RitualReason>[];

    if (range.requiresRitual) reasons.add(RitualReason.ritualOnlyRange);
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
    int? chosenBaseLevel,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    Map<String, List<String>> selectedModifiers = const {},
    required Map<String, RequisiteKind> requisites,
    List<LevelAdjustment> adjustments = const [],
    RitualDeclaration ritualDeclaration = RitualDeclaration.none,
  }) =>
      calculateBreakdown(
        baseEffect: baseEffect,
        chosenBaseLevel: chosenBaseLevel,
        range: range,
        duration: duration,
        target: target,
        selectedModifiers: selectedModifiers,
        requisites: requisites,
        adjustments: adjustments,
        ritualDeclaration: ritualDeclaration,
      ).level;

  List<ResolvedSpell> findSimilarSpells(String technique, String form, {int? referenceLevel}) {
    final matches = allSpells
        .where((s) => s.isResolved && s.technique == technique && s.form == form)
        .toList();

    if (referenceLevel != null) {
      // A match here is resolved (isResolved above) but not necessarily
      // computable: one may carry adjustments/magnitudes that drive it below
      // level 1, which SpellLevelCalculator signals by throwing rather than
      // by leaving it unresolved. Such a spell has no level to compare
      // against referenceLevel, so it cannot be "similar to level N" —
      // dropped here rather than kept unsorted or sorted last, same as an
      // unresolved spell already is by the `isResolved &&` filter above.
      // Levels are computed once per spell up front (not per comparator
      // call) so a bad spell can be removed before matches.sort ever runs,
      // and so a good spell isn't recomputed on every comparison.
      final levels = <String, int>{};
      matches.removeWhere((s) {
        try {
          levels[s.id] = calculateSpellLevel(
            baseEffect: s.baseEffect!, chosenBaseLevel: s.record.chosenBaseLevel,
            range: s.range!, duration: s.duration!, target: s.target!,
            selectedModifiers: s.selectedModifiers, requisites: s.requisites,
            adjustments: s.adjustments, ritualDeclaration: s.ritualDeclaration,
          );
          return false;
        } on ArgumentError {
          return true;
        }
      });

      matches.sort((a, b) => (levels[a.id]! - referenceLevel)
          .abs()
          .compareTo((levels[b.id]! - referenceLevel).abs()));
    }

    return matches;
  }

  /// Drops any selection whose modifier no longer applies to the draft. A
  /// stranded selection would otherwise keep contributing magnitude invisibly
  /// after the caster changes Technique, Form, base effect or Target.
  Map<String, List<String>> pruneModifierSelections({
    required Map<String, List<String>> selectedModifiers,
    String? technique,
    String? form,
    String? baseEffectId,
    String? targetId,
  }) {
    final kept = <String, List<String>>{};
    selectedModifiers.forEach((modifierId, optionIds) {
      for (final modifier in allModifiers.where((m) => m.id == modifierId).take(1)) {
        if (modifier.scope.appliesTo(
            technique: technique,
            form: form,
            baseEffectId: baseEffectId,
            targetId: targetId)) {
          kept[modifierId] = optionIds;
        }
      }
    });
    return kept;
  }

  /// The strength of a General guideline's effect at the level the caster
  /// chose, or null when the guideline is not General or no level is set yet.
  ///
  /// Reads [chosenBaseLevel] and never the computed spell level. That is
  /// deliberate and load-bearing: a ward moved from Touch/Ring/Circle to
  /// Personal/Sun/Individual is one magnitude cheaper, and must still keep out
  /// exactly the same Might.
  GeneralEffectValue? deriveGeneralEffect({
    required BaseEffect baseEffect,
    required int? chosenBaseLevel,
  }) {
    final formula = baseEffect.effectFormula;
    if (!baseEffect.isGeneral || formula == null || chosenBaseLevel == null) {
      return null;
    }

    // Through the calculator, never `offsetMagnitudes * 5`. Above level 5 the
    // two agree; inside the 1-5 additive tier they do not, and the calculator
    // is right. A base-3 DEO produces a level-5 spell, so "the level of the
    // spell + 2 magnitudes" is 5 — `* 5` would claim 13. See Global
    // Constraints.
    final int inLevels;
    try {
      inLevels = SpellLevelCalculator.calculate(
          chosenBaseLevel, [formula.offsetMagnitudes]);
    } on ArgumentError {
      // A negative offset drove the value below 1, so there is no strength to
      // report. Null rather than a throw: this renders a sentence, and one bad
      // saved spell must not take out the Library tab. Task 8 stops such a
      // spell being saved at all.
      return null;
    }

    final scaled = switch (formula.multiplier) {
      // Halving rounds DOWN. The only "round up" the rulebook states is for
      // magnitudes (line 12030), applied below; halving a spell level has no
      // such rule, and rounding down is the reading that never lets a
      // dispelling spell reach one level higher than its guideline allows.
      GeneralEffectMultiplier.half => inLevels ~/ 2,
      GeneralEffectMultiplier.one => inLevels,
      GeneralEffectMultiplier.two => inLevels * 2,
    };

    final value = formula.unit == GeneralEffectUnit.magnitudes
        ? (scaled / 5).ceil()
        : scaled;

    return GeneralEffectValue(
      value: value,
      unit: formula.unit,
      sentence: _effectSentence(formula, value),
    );
  }

  static String _effectSentence(GeneralEffectFormula formula, int value) {
    final body = switch (formula.kind) {
      GeneralEffectKind.mightThreshold => 'Affects beings with Might $value or less',
      GeneralEffectKind.mightReduction => 'Reduces Might by $value',
      GeneralEffectKind.damage => 'Does +$value damage',
      GeneralEffectKind.targetSpellLevel => 'Affects effects of level $value or less',
      GeneralEffectKind.visDestroyed => 'Destroys $value pawns\' worth of raw vis',
      GeneralEffectKind.spellTraceMagnitude =>
        'Reaches spell traces down to negative magnitude $value',
      GeneralEffectKind.castingTotalReduction => 'Reduces the casting total by $value',
    };

    return formula.stressDie ? '$body, + a stress die (no botch)' : body;
  }
}
