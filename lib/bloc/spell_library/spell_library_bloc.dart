import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/data/repositories/library_repository.dart';
import 'package:eruditus/engine/spell_engine.dart';

class SpellLibraryBloc extends Bloc<SpellLibraryEvent, SpellLibraryState> {
  final LibraryRepository libraryRepository;
  // Reused (not duplicated) purely for its calculateBreakdown method, so the
  // Library screen can show each spell's level and Ritual status using the
  // exact same magnitude-summing/Ritual-deriving implementation
  // SpellCreationBloc already uses.
  final SpellEngine spellEngine;

  // All events are funneled through a single handler (registered on the base
  // `SpellLibraryEvent` type) with a sequential transformer. flutter_bloc's
  // default behavior processes events of *different* types concurrently
  // (each `on<E>()` call sets up its own independent subscription), which
  // would let a synchronous FilterChanged/SearchQueryChanged race ahead of
  // an in-flight, asynchronous LibraryRequested load and interleave states
  // unpredictably. Sequential processing here guarantees events are applied
  // strictly in arrival order.
  SpellLibraryBloc({required this.libraryRepository, required this.spellEngine})
      : super(SpellLibraryState.initial()) {
    on<SpellLibraryEvent>(
      _onEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  Future<void> _onEvent(SpellLibraryEvent event, Emitter<SpellLibraryState> emit) async {
    if (event is LibraryRequested) {
      emit(state.copyWith(status: SpellLibraryStatus.loading));
      try {
        final spells = await libraryRepository.getAllSpells();
        final templates = await libraryRepository.getTemplates();
        final exceptions = await libraryRepository.getExceptions();
        final levels = <String, int>{};
        final ritualIds = <String>{};
        for (final s in spells) {
          // An unresolved spell has no base effect to calculate from. It is
          // omitted rather than defaulted to 0, so the card can tell
          // "invalid" apart from "genuinely level 0".
          if (!s.isResolved) continue;
          // Per spell, not per load. A saved spell whose adjustments drive it
          // below level 1 makes calculateBreakdown throw; with one try around
          // the whole loop that single row dropped the entire Library tab into
          // its error state on every launch, leaving no in-app way to reach
          // and delete the offending spell. Degrade to one level-less row
          // instead — the same treatment an unresolved spell gets above, and
          // SpellCard already renders a missing level as plain
          // "Technique Form" with no level suffix.
          try {
            final breakdown = spellEngine.calculateBreakdown(
              baseEffect: s.baseEffect!, chosenBaseLevel: s.record.chosenBaseLevel,
              range: s.range!, duration: s.duration!,
              target: s.target!, selectedModifiers: s.selectedModifiers,
              requisites: s.requisites, adjustments: s.adjustments,
              ritualDeclaration: s.ritualDeclaration,
            );
            levels[s.id] = breakdown.level;
            if (breakdown.ritualStatus.isRitual) ritualIds.add(s.id);
          } catch (_) {
            continue;
          }
        }

        emit(state.copyWith(
          status: SpellLibraryStatus.loaded,
          allSpells: spells,
          templates: templates,
          exceptions: exceptions,
          spellLevels: levels,
          ritualSpellIds: ritualIds,
        ));
      } catch (e) {
        emit(state.copyWith(status: SpellLibraryStatus.error, errorMessage: e.toString()));
      }
    } else if (event is SearchQueryChanged) {
      emit(state.copyWith(query: event.query));
    } else if (event is FilterChanged) {
      emit(state.copyWith(filter: event.filter));
    }
  }
}
