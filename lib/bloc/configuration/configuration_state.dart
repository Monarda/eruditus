import 'package:equatable/equatable.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';

enum ConfigurationStatus { loading, loaded, error }

class ConfigurationState extends Equatable {
  final ConfigurationStatus status;
  final List<BaseEffect> effects;
  final List<Parameter> parameters;
  final List<Modifier> modifiers;
  final String? errorMessage;

  const ConfigurationState({
    required this.status,
    this.effects = const [],
    this.parameters = const [],
    this.modifiers = const [],
    this.errorMessage,
  });

  factory ConfigurationState.initial() => const ConfigurationState(status: ConfigurationStatus.loading);

  ConfigurationState copyWith({
    ConfigurationStatus? status,
    List<BaseEffect>? effects,
    List<Parameter>? parameters,
    List<Modifier>? modifiers,
    String? errorMessage,
  }) {
    return ConfigurationState(
      status: status ?? this.status,
      effects: effects ?? this.effects,
      parameters: parameters ?? this.parameters,
      modifiers: modifiers ?? this.modifiers,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, effects, parameters, modifiers, errorMessage];
}
