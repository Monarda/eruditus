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

  SpellCreationBloc({
    required this.spellEngine,
    required this.spellRepository,
  }) : super(SpellCreationState.initial()) {
    on<TechniqueSelected>((event, emit) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(technique: event.technique, baseEffect: null),
      ));
    });

    on<FormSelected>((event, emit) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(form: event.form, baseEffect: null),
      ));
    });

    on<BaseEffectSelected>((event, emit) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(baseEffect: event.effect),
      ));
    });

    on<ParameterAdded>((event, emit) {
      final updated = [
        ...state.draft.parameters,
        SelectedParameter(parameterId: event.parameter.id, parameter: event.parameter),
      ];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(parameters: updated),
      ));
    });

    on<ParameterRemoved>((event, emit) {
      final updated = state.draft.parameters
          .where((p) => p.parameterId != event.parameterId)
          .toList();
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(parameters: updated),
      ));
    });

    on<SpecialFactorToggled>((event, emit) {
      final current = state.draft.selectedSpecialFactorIds;
      final updated = event.selected
          ? [...current, event.factorId]
          : current.where((id) => id != event.factorId).toList();
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(selectedSpecialFactorIds: updated),
      ));
    });

    on<RequiredRequisiteChanged>((event, emit) {
      final updated = event.art == null ? <RequiredRequisite>[] : [RequiredRequisite(art: event.art!)];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requiredRequisites: updated),
      ));
    });

    on<AdditionalRequisiteAdded>((event, emit) {
      final updated = [...state.draft.additionalRequisites, AdditionalRequisite(art: event.art)];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(additionalRequisites: updated),
      ));
    });

    on<AdditionalRequisiteRemoved>((event, emit) {
      final updated = state.draft.additionalRequisites
          .where((r) => r.art != event.art)
          .toList();
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(additionalRequisites: updated),
      ));
    });

    on<SpellCalculated>((event, emit) {
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

      emit(state.copyWith(
        status: SpellCreationStatus.calculated,
        validationErrors: const [],
        calculatedLevel: level,
        suggestions: suggestions,
      ));
    });

    on<SpellSaveRequested>((event, emit) async {
      emit(state.copyWith(status: SpellCreationStatus.saving));

      final spell = state.draft.toSpell(name: event.name, source: 'user-created');
      await spellRepository.saveSpell(spell);

      emit(state.copyWith(status: SpellCreationStatus.saved, savedSpell: spell));
    });

    on<SpellDiscarded>((event, emit) {
      emit(SpellCreationState.initial());
    });
  }
}
