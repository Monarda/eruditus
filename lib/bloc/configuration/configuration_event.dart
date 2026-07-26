import 'package:equatable/equatable.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';

abstract class ConfigurationEvent extends Equatable {
  const ConfigurationEvent();
  @override
  List<Object?> get props => [];
}

class ConfigurationRequested extends ConfigurationEvent {
  const ConfigurationRequested();
}

class CustomEffectAdded extends ConfigurationEvent {
  final BaseEffect effect;
  const CustomEffectAdded(this.effect);
  @override
  List<Object?> get props => [effect];
}

class CustomEffectDeleted extends ConfigurationEvent {
  final String id;
  const CustomEffectDeleted(this.id);
  @override
  List<Object?> get props => [id];
}

class CustomParameterAdded extends ConfigurationEvent {
  final Parameter parameter;
  const CustomParameterAdded(this.parameter);
  @override
  List<Object?> get props => [parameter];
}

class CustomParameterDeleted extends ConfigurationEvent {
  final String id;
  const CustomParameterDeleted(this.id);
  @override
  List<Object?> get props => [id];
}

class CustomFactorAdded extends ConfigurationEvent {
  final SpecialFactor factor;
  const CustomFactorAdded(this.factor);
  @override
  List<Object?> get props => [factor];
}

class CustomFactorDeleted extends ConfigurationEvent {
  final String id;
  const CustomFactorDeleted(this.id);
  @override
  List<Object?> get props => [id];
}

class CustomModifierAdded extends ConfigurationEvent {
  final Modifier modifier;
  const CustomModifierAdded(this.modifier);
  @override
  List<Object?> get props => [modifier];
}

class CustomModifierDeleted extends ConfigurationEvent {
  final String id;
  const CustomModifierDeleted(this.id);
  @override
  List<Object?> get props => [id];
}
