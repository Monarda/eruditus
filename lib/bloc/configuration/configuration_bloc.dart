import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';

class ConfigurationBloc extends Bloc<ConfigurationEvent, ConfigurationState> {
  final ConfigurationRepository configRepository;

  // All events are funneled through a single handler (registered on the base
  // `ConfigurationEvent` type) with a sequential transformer, for the same
  // reason as SpellLibraryBloc (Task 9): flutter_bloc's default behavior
  // processes events of *different* types concurrently (each `on<E>()` call
  // sets up its own independent subscription). Every add/delete handler here
  // internally calls `add(const ConfigurationRequested())` to reload, which
  // creates exactly the rapid, mixed-type event sequence that would race
  // under concurrent processing. Sequential processing guarantees events are
  // applied strictly in arrival order.
  ConfigurationBloc({required this.configRepository}) : super(ConfigurationState.initial()) {
    on<ConfigurationEvent>(
      _onEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  Future<void> _onEvent(ConfigurationEvent event, Emitter<ConfigurationState> emit) async {
    if (event is ConfigurationRequested) {
      emit(state.copyWith(status: ConfigurationStatus.loading));
      try {
        final effects = await configRepository.getAllEffects();
        final parameters = await configRepository.getAllParameters();
        final modifiers = await configRepository.getAllModifiers();
        emit(state.copyWith(
          status: ConfigurationStatus.loaded,
          effects: effects,
          parameters: parameters,
          modifiers: modifiers,
        ));
      } catch (e) {
        emit(state.copyWith(status: ConfigurationStatus.error, errorMessage: e.toString()));
      }
    } else if (event is CustomEffectAdded) {
      await configRepository.addCustomEffect(event.effect);
      await _reload(emit);
    } else if (event is CustomEffectDeleted) {
      await configRepository.deleteCustomEffect(event.id);
      await _reload(emit);
    } else if (event is CustomParameterAdded) {
      await configRepository.addCustomParameter(event.parameter);
      await _reload(emit);
    } else if (event is CustomParameterDeleted) {
      await configRepository.deleteCustomParameter(event.id);
      await _reload(emit);
    } else if (event is CustomModifierAdded) {
      await configRepository.addCustomModifier(event.modifier);
      await _reload(emit);
    } else if (event is CustomModifierDeleted) {
      await configRepository.deleteCustomModifier(event.id);
      await _reload(emit);
    }
  }

  Future<void> _reload(Emitter<ConfigurationState> emit) async {
    emit(state.copyWith(status: ConfigurationStatus.loading));
    try {
      final effects = await configRepository.getAllEffects();
      final parameters = await configRepository.getAllParameters();
      final modifiers = await configRepository.getAllModifiers();
      emit(state.copyWith(
        status: ConfigurationStatus.loaded,
        effects: effects,
        parameters: parameters,
        modifiers: modifiers,
      ));
    } catch (e) {
      emit(state.copyWith(status: ConfigurationStatus.error, errorMessage: e.toString()));
    }
  }
}
