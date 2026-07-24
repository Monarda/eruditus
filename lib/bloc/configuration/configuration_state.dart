import 'package:equatable/equatable.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';

enum ConfigurationStatus { loading, loaded, error }

class ConfigurationState extends Equatable {
  final ConfigurationStatus status;
  final List<BaseEffect> effects;
  final List<Parameter> parameters;
  final List<SpecialFactor> factors;
  final String? errorMessage;

  const ConfigurationState({
    required this.status,
    this.effects = const [],
    this.parameters = const [],
    this.factors = const [],
    this.errorMessage,
  });

  factory ConfigurationState.initial() => const ConfigurationState(status: ConfigurationStatus.loading);

  ConfigurationState copyWith({
    ConfigurationStatus? status,
    List<BaseEffect>? effects,
    List<Parameter>? parameters,
    List<SpecialFactor>? factors,
    String? errorMessage,
  }) {
    return ConfigurationState(
      status: status ?? this.status,
      effects: effects ?? this.effects,
      parameters: parameters ?? this.parameters,
      factors: factors ?? this.factors,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, effects, parameters, factors, errorMessage];
}
