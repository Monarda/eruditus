import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/data/repositories/library_repository.dart';

class SpellLibraryBloc extends Bloc<SpellLibraryEvent, SpellLibraryState> {
  final LibraryRepository libraryRepository;

  // All events are funneled through a single handler (registered on the base
  // `SpellLibraryEvent` type) with a sequential transformer. flutter_bloc's
  // default behavior processes events of *different* types concurrently
  // (each `on<E>()` call sets up its own independent subscription), which
  // would let a synchronous FilterChanged/SearchQueryChanged race ahead of
  // an in-flight, asynchronous LibraryRequested load and interleave states
  // unpredictably. Sequential processing here guarantees events are applied
  // strictly in arrival order.
  SpellLibraryBloc({required this.libraryRepository}) : super(SpellLibraryState.initial()) {
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
        emit(state.copyWith(status: SpellLibraryStatus.loaded, allSpells: spells));
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
