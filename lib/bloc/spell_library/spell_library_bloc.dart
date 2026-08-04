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
        final levels = <String, int>{};
        final ritualIds = <String>{};
        for (final s in spells) {
          // An unresolved spell has no base effect to calculate from. It is
          // omitted rather than defaulted to 0, so the card can tell
          // "invalid" apart from "genuinely level 0".
          if (!s.isResolved) continue;
          final breakdown = spellEngine.calculateBreakdown(
            baseEffect: s.baseEffect!, range: s.range!, duration: s.duration!,
            target: s.target!, selectedModifiers: s.selectedModifiers,
            requisites: s.requisites, adjustments: s.adjustments,
            ritualDeclaration: s.ritualDeclaration,
          );
          levels[s.id] = breakdown.level;
          if (breakdown.ritualStatus.isRitual) ritualIds.add(s.id);
        }

        emit(state.copyWith(
          status: SpellLibraryStatus.loaded,
          allSpells: spells,
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
