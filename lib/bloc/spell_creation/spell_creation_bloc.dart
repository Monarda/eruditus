import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/requisite.dart' show RequisiteKind;
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart' show SpellDraft;
import 'package:eruditus/models/publication_source.dart';

class SpellCreationBloc extends Bloc<SpellCreationEvent, SpellCreationState> {
  final SpellEngine spellEngine;
  final SpellRepository spellRepository;

  // All events are funneled through a single handler (registered on the base
  // `SpellCreationEvent` type) with a sequential transformer, for the same
  // reason as SpellLibraryBloc/ConfigurationBloc: flutter_bloc's default
  // behavior processes events of *different* types concurrently (each
  // `on<E>()` call sets up its own independent subscription), which would let
  // a synchronous SpellDiscarded race ahead of an in-flight, asynchronous
  // SpellSaveRequested and interleave states unpredictably (e.g. a discard
  // getting clobbered by a save that was already in flight). Sequential
  // processing here guarantees events are applied strictly in arrival order.
  SpellCreationBloc({
    required this.spellEngine,
    required this.spellRepository,
  }) : super(SpellCreationState.initial()) {
    on<SpellCreationEvent>(
      _onEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  Future<void> _onEvent(SpellCreationEvent event, Emitter<SpellCreationState> emit) async {
    if (event is TechniqueSelected) {
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(state.draft.copyWith(
          technique: event.technique,
          baseEffect: null,
          // A chosen level or template link both point at the base effect
          // that just disappeared -- neither can survive it, for the same
          // reason pruneModifierSelections drops a stranded modifier rather
          // than let it keep affecting the level invisibly.
          chosenBaseLevel: null,
          templateId: null,
          chosenSlots: const {},
        )),
        reapplyDefault: false,
      );
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is FormSelected) {
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(state.draft.copyWith(
          form: event.form,
          baseEffect: null,
          chosenBaseLevel: null,
          templateId: null,
          chosenSlots: const {},
        )),
        reapplyDefault: false,
      );
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is BaseEffectSelected) {
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(state.draft.copyWith(
          baseEffect: event.effect,
          // A template link asserts lineage to the *previous* base effect;
          // it cannot survive a change to a new one, General or not.
          templateId: null,
          // Deliberate: unlike Technique/Form, a chosen level isn't tied to
          // one specific General guideline -- it's "spell level N", equally
          // meaningful against whichever General guideline is selected. Only
          // clear it when the new effect isn't General at all; forcing a
          // re-type on every guideline switch would be friction with no
          // correctness gain.
          chosenBaseLevel: event.effect.isGeneral ? state.draft.chosenBaseLevel : null,
          chosenSlots: _prunedSlots(state.draft.chosenSlots, event.effect),
        )),
        reapplyDefault: true,
      );
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is ChosenBaseLevelChanged) {
      final draft = state.draft.copyWith(chosenBaseLevel: event.level);
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is OpenSlotChosen) {
      final updated = {...state.draft.chosenSlots, event.kind: event.value};
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(chosenSlots: updated),
      ));
    } else if (event is RangeSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(range: event.parameter),
      ));
    } else if (event is DurationSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withRitualDeclaration(
          state.draft.copyWith(duration: event.parameter),
          reapplyDefault: true,
        ),
      ));
    } else if (event is TargetSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(target: event.parameter),
      ));
    } else if (event is RequisiteAdded) {
      final kind = event.kind == 'adding' ? RequisiteKind.adding : RequisiteKind.free;
      final updated = {...state.draft.requisites, event.art: kind};
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is RequisiteRemoved) {
      final updated = Map<String, RequisiteKind>.from(state.draft.requisites)
        ..remove(event.art);
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is RequisiteKindChanged) {
      final kind = event.newKind == 'adding' ? RequisiteKind.adding : RequisiteKind.free;
      final updated = {...state.draft.requisites, event.art: kind};
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is AdjustmentAdded) {
      final updated = [
        ...state.draft.adjustments,
        LevelAdjustment(magnitude: 0, note: '(describe this adjustment)'),
      ];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    } else if (event is AdjustmentRemoved) {
      // Index-keyed, so a stale index from a rebuild-in-flight must be
      // ignored rather than throwing RangeError into the bloc.
      if (event.index < 0 || event.index >= state.draft.adjustments.length) return;
      final updated = [...state.draft.adjustments]..removeAt(event.index);
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    } else if (event is AdjustmentUpdated) {
      if (event.index < 0 || event.index >= state.draft.adjustments.length) return;
      final existing = state.draft.adjustments[event.index];
      // LevelAdjustment rejects a blank note, and the note field commits on
      // every focus loss — so select-all, delete, tab away arrives here as an
      // empty note. Constructing one would throw FormatException out of this
      // handler: no state emitted, the field left showing empty while the
      // draft still held the old value, and the user's next edit operating on
      // stale data. Keep the note the draft already has instead; the magnitude
      // in the event is still honoured.
      final note = event.note.trim().isEmpty ? existing.note : event.note;
      final updated = [...state.draft.adjustments];
      updated[event.index] = LevelAdjustment(magnitude: event.magnitude, note: note);
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    } else if (event is ModifierOptionSelected) {
      final modifier =
          spellEngine.allModifiers.where((m) => m.id == event.modifierId).firstOrNull;
      final current = state.draft.selectedModifiers[event.modifierId] ?? const <String>[];
      final updated = modifier?.selectionMode == ModifierSelectionMode.single
          ? [event.optionId]
          : [...current.where((id) => id != event.optionId), event.optionId];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(selectedModifiers: {
          ...state.draft.selectedModifiers,
          event.modifierId: updated,
        }),
      ));
    } else if (event is ModifierOptionDeselected) {
      final remaining = (state.draft.selectedModifiers[event.modifierId] ?? const <String>[])
          .where((id) => id != event.optionId)
          .toList();
      final updated = {...state.draft.selectedModifiers};
      if (remaining.isEmpty) {
        updated.remove(event.modifierId);
      } else {
        updated[event.modifierId] = remaining;
      }
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(selectedModifiers: updated),
      ));
    } else if (event is AvailableModifiersSynced) {
      spellEngine.updateModifiers(event.modifiers);
    } else if (event is AvailableParametersSynced) {
      spellEngine.updateParameters(event.parameters);
    } else if (event is RitualDeclarationChanged) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(ritualDeclaration: event.declaration),
      ));
    } else if (event is TemplateInstantiated) {
      final template = event.template;
      // The repository never hands out an unresolved template for this
      // purpose in normal use, but a stale reference (a custom effect or
      // parameter deleted between the Library screen's load and the tap)
      // can still reach here. There is nothing to build a draft from, so
      // emit nothing rather than seed one missing a baseEffect/range/
      // duration/target -- the same "degrade, don't half-build" policy
      // ResolvedTemplate/ResolvedSpell already follow.
      if (!template.isResolved) return;

      // A fresh SpellDraft (constructed, not copyWith-ed off state.draft), so
      // it gets a new id -- the in-progress draft, if any, is abandoned
      // rather than mutated in place.
      final draft = _withPrunedModifiers(SpellDraft(
        technique: template.technique,
        form: template.form,
        baseEffect: template.baseEffect,
        range: template.range,
        duration: template.duration,
        target: template.target,
        selectedModifiers: template.selectedModifiers,
        requisites: template.requisites,
        adjustments: template.adjustments,
        summary: template.summary,
        description: template.description,
        // Verbatim, NOT run through _withRitualDeclaration. A template's
        // declaration is published catalog data about *this* effect, not
        // something to re-derive from the draft's current Technique/
        // Duration -- Disenchant (Perdo Vim, Momentary) declares
        // lastingCreation, and _withRitualDeclaration only reapplies that
        // default for Creo + Momentary, so routing it through there would
        // silently strip a Ritual status the guideline actually has.
        ritualDeclaration: template.ritualDeclaration,
        templateId: template.id,
        chosenSlots: template.chosenSlots,
      ));

      // From SpellCreationState.initial(), not state.copyWith(...): a stale
      // breakdown/suggestions/calculatedLevel left over from whatever the
      // user was doing before must not follow them into the new spell.
      emit(SpellCreationState.initial().copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is SpellCalculated) {
      _handleSpellCalculated(emit);
    } else if (event is SpellSaveRequested) {
      await _handleSpellSaveRequested(event, emit);
    } else if (event is SpellDiscarded) {
      emit(SpellCreationState.initial());
    }
  }

  /// The sentence [SpellCreationState.generalEffectSentence] should carry for
  /// [draft], or null when there is none to show. Delegates to
  /// SpellEngine.deriveGeneralEffect, which already covers "not General", "no
  /// formula" and "no level chosen yet" -- this just also covers "no base
  /// effect at all", which deriveGeneralEffect can't take a null for.
  String? _generalEffectSentenceFor(SpellDraft draft) {
    final baseEffect = draft.baseEffect;
    if (baseEffect == null) return null;
    return spellEngine
        .deriveGeneralEffect(baseEffect: baseEffect, chosenBaseLevel: draft.chosenBaseLevel)
        ?.sentence;
  }

  /// Drops any `chosenSlots` entry [effect] no longer declares open — the
  /// map-keyed sibling of `chosenBaseLevel: null`'s clearing above. `null`
  /// [effect] (Technique/Form changed, base effect cleared) drops everything.
  Map<String, String> _prunedSlots(Map<String, String> slots, BaseEffect? effect) {
    if (effect == null) return const {};
    final openKindNames = effect.openSlots.map((k) => k.name).toSet();
    return Map.fromEntries(
      slots.entries.where((entry) => openKindNames.contains(entry.key)),
    );
  }

  SpellDraft _withPrunedModifiers(SpellDraft draft) => draft.copyWith(
        selectedModifiers: spellEngine.pruneModifierSelections(
          selectedModifiers: draft.selectedModifiers,
          technique: draft.technique,
          form: draft.form,
          baseEffectId: draft.baseEffect?.id,
        ),
      );

  /// Re-derives [SpellDraft.ritualDeclaration] after a change to Technique,
  /// Form, base effect or Duration.
  ///
  /// A `lastingCreation` declaration is a statement about *this* effect at
  /// *this* Duration; when either moves out of eligibility the statement has
  /// become false and must go, exactly as pruneModifierSelections drops a
  /// stranded modifier rather than let it keep affecting the level invisibly.
  ///
  /// A `storyguideRuling` is never touched. It is not invalidated by changing
  /// Duration, and no UI sets it yet — silently wiping one would make the
  /// deferred storyguide-ruling UI a second migration.
  SpellDraft _withRitualDeclaration(SpellDraft draft, {required bool reapplyDefault}) {
    if (draft.ritualDeclaration == RitualDeclaration.storyguideRuling) return draft;

    if (!draft.isEligibleForLastingCreationDeclaration) {
      return draft.copyWith(ritualDeclaration: RitualDeclaration.none);
    }
    if (reapplyDefault) {
      return draft.copyWith(ritualDeclaration: RitualDeclaration.lastingCreation);
    }
    return draft;
  }

  void _handleSpellCalculated(Emitter<SpellCreationState> emit) {
    final errors = spellEngine.validateSpellDraft(state.draft);
    if (errors.isNotEmpty) {
      emit(state.copyWith(status: SpellCreationStatus.editing, validationErrors: errors));
      return;
    }

    final breakdown = spellEngine.calculateBreakdown(
      baseEffect: state.draft.baseEffect!,
      chosenBaseLevel: state.draft.chosenBaseLevel,
      range: state.draft.range!,
      duration: state.draft.duration!,
      target: state.draft.target!,
      selectedModifiers: state.draft.selectedModifiers,
      requisites: state.draft.requisites,
      adjustments: state.draft.adjustments,
      ritualDeclaration: state.draft.ritualDeclaration,
    );
    final level = breakdown.level;

    final candidateSuggestions = spellEngine.findSimilarSpells(
      state.draft.technique!,
      state.draft.form!,
      referenceLevel: level,
    );

    // Precompute each suggestion's own level and Ritual status (reusing
    // SpellEngine's single calculateBreakdown implementation rather than
    // duplicating the magnitude-summing/Ritual-deriving logic) so cards can
    // display both, matching the library screen's chip.
    //
    // findSimilarSpells already drops a same-Technique-Form spell it cannot
    // compute a level for (adjustments/magnitudes driving it below level 1 —
    // see the comparator there), but this loop guards independently rather
    // than trusting that upstream filtering: a spell reaching here that still
    // throws is dropped from `suggestions` outright, not kept as a level-less
    // card. Unlike the Library screen (which shows every saved spell and so
    // degrades an uncomputable one to a missing-level row), every entry here
    // exists to be compared against the just-calculated level — a spell with
    // no level cannot be "similar to level N", so it is not a suggestion.
    final suggestionLevels = <String, int>{};
    final ritualSuggestionIds = <String>{};
    final suggestions = <ResolvedSpell>[];
    for (final s in candidateSuggestions) {
      try {
        final suggestionBreakdown = spellEngine.calculateBreakdown(
          baseEffect: s.baseEffect!, chosenBaseLevel: s.record.chosenBaseLevel,
          range: s.range!, duration: s.duration!, target: s.target!,
          selectedModifiers: s.selectedModifiers, requisites: s.requisites,
          adjustments: s.adjustments,
          ritualDeclaration: s.ritualDeclaration,
        );
        suggestionLevels[s.id] = suggestionBreakdown.level;
        if (suggestionBreakdown.ritualStatus.isRitual) ritualSuggestionIds.add(s.id);
        suggestions.add(s);
      } on ArgumentError {
        continue;
      }
    }

    emit(state.copyWith(
      status: SpellCreationStatus.calculated,
      validationErrors: const [],
      calculatedLevel: level,
      breakdown: breakdown,
      suggestions: suggestions,
      suggestionLevels: suggestionLevels,
      ritualSuggestionIds: ritualSuggestionIds,
    ));
  }

  Future<void> _handleSpellSaveRequested(
    SpellSaveRequested event,
    Emitter<SpellCreationState> emit,
  ) async {
    emit(state.copyWith(status: SpellCreationStatus.saving));

    try {
      final spell = state.draft.toSpell(name: event.name, source: PublicationSource.userCreated);
      await spellRepository.saveSpell(spell);

      // Reset to a fresh, empty draft (with a newly generated id) rather than
      // reusing the just-saved draft/id. This both (a) gives the user a
      // ready-to-go form for their next spell, matching the "Save" action
      // reading as "this spell is done, start the next one" rather than
      // "keep editing the same one", and (b) structurally prevents the
      // previous crash: a subsequent SpellSaveRequested can no longer collide
      // on the same primary key, since the draft backing it is always new.
      emit(SpellCreationState.initial().copyWith(
        status: SpellCreationStatus.saved,
        savedSpell: spell,
      ));
    } catch (e) {
      emit(state.copyWith(status: SpellCreationStatus.error, errorMessage: e.toString()));
    }
  }
}
