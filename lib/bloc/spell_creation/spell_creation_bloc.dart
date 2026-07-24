import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';

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
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(technique: event.technique, baseEffect: null),
      ));
    } else if (event is FormSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(form: event.form, baseEffect: null),
      ));
    } else if (event is BaseEffectSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(baseEffect: event.effect),
      ));
    } else if (event is ParameterAdded) {
      final updated = [
        ...state.draft.parameters,
        SelectedParameter(parameterId: event.parameter.id, parameter: event.parameter),
      ];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(parameters: updated),
      ));
    } else if (event is ParameterRemoved) {
      final updated = state.draft.parameters
          .where((p) => p.parameterId != event.parameterId)
          .toList();
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(parameters: updated),
      ));
    } else if (event is SpecialFactorToggled) {
      final current = state.draft.selectedSpecialFactorIds;
      final updated = event.selected
          ? [...current, event.factorId]
          : current.where((id) => id != event.factorId).toList();
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(selectedSpecialFactorIds: updated),
      ));
    } else if (event is RequiredRequisiteChanged) {
      final updated = event.art == null ? <RequiredRequisite>[] : [RequiredRequisite(art: event.art!)];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requiredRequisites: updated),
      ));
    } else if (event is AdditionalRequisiteAdded) {
      final updated = [...state.draft.additionalRequisites, AdditionalRequisite(art: event.art)];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(additionalRequisites: updated),
      ));
    } else if (event is AdditionalRequisiteRemoved) {
      final updated = state.draft.additionalRequisites
          .where((r) => r.art != event.art)
          .toList();
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(additionalRequisites: updated),
      ));
    } else if (event is SpellCalculated) {
      _handleSpellCalculated(emit);
    } else if (event is SpellSaveRequested) {
      await _handleSpellSaveRequested(event, emit);
    } else if (event is SpellDiscarded) {
      emit(SpellCreationState.initial());
    } else if (event is AvailableFactorsSynced) {
      spellEngine.updateSpecialFactors(event.factors);
    }
  }

  void _handleSpellCalculated(Emitter<SpellCreationState> emit) {
    final errors = spellEngine.validateSpellDraft(state.draft);
    if (errors.isNotEmpty) {
      emit(state.copyWith(status: SpellCreationStatus.editing, validationErrors: errors));
      return;
    }

    final level = spellEngine.calculateSpellLevel(
      baseEffect: state.draft.baseEffect!,
      parameters: state.draft.parameters,
      selectedSpecialFactorIds: state.draft.selectedSpecialFactorIds,
      additionalRequisites: state.draft.additionalRequisites,
    );

    final suggestions = spellEngine.findSimilarSpells(
      state.draft.technique!,
      state.draft.form!,
      referenceLevel: level,
    );

    // Precompute each suggestion's own level (reusing SpellEngine's single
    // calculateSpellLevel implementation rather than duplicating the
    // magnitude-summing logic) so cards can display it.
    final suggestionLevels = <String, int>{
      for (final s in suggestions)
        s.id: spellEngine.calculateSpellLevel(
          baseEffect: s.baseEffect,
          parameters: s.parameters,
          selectedSpecialFactorIds: s.selectedSpecialFactorIds,
          additionalRequisites: s.additionalRequisites,
        ),
    };

    emit(state.copyWith(
      status: SpellCreationStatus.calculated,
      validationErrors: const [],
      calculatedLevel: level,
      suggestions: suggestions,
      suggestionLevels: suggestionLevels,
    ));
  }

  Future<void> _handleSpellSaveRequested(
    SpellSaveRequested event,
    Emitter<SpellCreationState> emit,
  ) async {
    emit(state.copyWith(status: SpellCreationStatus.saving));

    try {
      final spell = state.draft.toSpell(name: event.name, source: 'user-created');
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
