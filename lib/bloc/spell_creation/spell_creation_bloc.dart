import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/requisite.dart' show Requisite, RequisiteKind;
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
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withPrunedModifiers(
            state.draft.copyWith(technique: event.technique, baseEffect: null)),
      ));
    } else if (event is FormSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft:
            _withPrunedModifiers(state.draft.copyWith(form: event.form, baseEffect: null)),
      ));
    } else if (event is BaseEffectSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withPrunedModifiers(state.draft.copyWith(baseEffect: event.effect)),
      ));
    } else if (event is RangeSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(range: event.parameter),
      ));
    } else if (event is DurationSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(duration: event.parameter),
      ));
    } else if (event is TargetSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(target: event.parameter),
      ));
    } else if (event is RequisiteAdded) {
      final kind = event.kind == 'adding' ? RequisiteKind.adding : RequisiteKind.free;
      final updated = [...state.draft.requisites, Requisite(art: event.art, kind: kind)];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is RequisiteRemoved) {
      final updated = state.draft.requisites
          .where((r) => r.art != event.art)
          .toList();
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is RequisiteKindChanged) {
      final kind = event.newKind == 'adding' ? RequisiteKind.adding : RequisiteKind.free;
      final updated = state.draft.requisites.map((r) {
        return r.art == event.art ? Requisite(art: r.art, kind: kind) : r;
      }).toList();
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
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
    } else if (event is SpellCalculated) {
      _handleSpellCalculated(emit);
    } else if (event is SpellSaveRequested) {
      await _handleSpellSaveRequested(event, emit);
    } else if (event is SpellDiscarded) {
      emit(SpellCreationState.initial());
    }
  }

  SpellDraft _withPrunedModifiers(SpellDraft draft) => draft.copyWith(
        selectedModifiers: spellEngine.pruneModifierSelections(
          selectedModifiers: draft.selectedModifiers,
          technique: draft.technique,
          form: draft.form,
          baseEffectId: draft.baseEffect?.id,
        ),
      );

  void _handleSpellCalculated(Emitter<SpellCreationState> emit) {
    final errors = spellEngine.validateSpellDraft(state.draft);
    if (errors.isNotEmpty) {
      emit(state.copyWith(status: SpellCreationStatus.editing, validationErrors: errors));
      return;
    }

    final breakdown = spellEngine.calculateBreakdown(
      baseEffect: state.draft.baseEffect!,
      range: state.draft.range!,
      duration: state.draft.duration!,
      target: state.draft.target!,
      selectedModifiers: state.draft.selectedModifiers,
      requisites: state.draft.requisites,
    );
    final level = breakdown.level;

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
          baseEffect: s.baseEffect!, range: s.range!, duration: s.duration!, target: s.target!,
          selectedModifiers: s.selectedModifiers, requisites: s.requisites,
        ),
    };

    emit(state.copyWith(
      status: SpellCreationStatus.calculated,
      validationErrors: const [],
      calculatedLevel: level,
      breakdown: breakdown,
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
