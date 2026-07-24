import 'package:equatable/equatable.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';

abstract class SpellCreationEvent extends Equatable {
  const SpellCreationEvent();
  @override
  List<Object?> get props => [];
}

class TechniqueSelected extends SpellCreationEvent {
  final String technique;
  const TechniqueSelected(this.technique);
  @override
  List<Object?> get props => [technique];
}

class FormSelected extends SpellCreationEvent {
  final String form;
  const FormSelected(this.form);
  @override
  List<Object?> get props => [form];
}

class BaseEffectSelected extends SpellCreationEvent {
  final BaseEffect effect;
  const BaseEffectSelected(this.effect);
  @override
  List<Object?> get props => [effect];
}

class ParameterAdded extends SpellCreationEvent {
  final Parameter parameter;
  const ParameterAdded(this.parameter);
  @override
  List<Object?> get props => [parameter];
}

class ParameterRemoved extends SpellCreationEvent {
  final String parameterId;
  const ParameterRemoved(this.parameterId);
  @override
  List<Object?> get props => [parameterId];
}

class SpecialFactorToggled extends SpellCreationEvent {
  final String factorId;
  final bool selected;
  const SpecialFactorToggled(this.factorId, this.selected);
  @override
  List<Object?> get props => [factorId, selected];
}

class RequiredRequisiteChanged extends SpellCreationEvent {
  final String? art;
  const RequiredRequisiteChanged(this.art);
  @override
  List<Object?> get props => [art];
}

class AdditionalRequisiteAdded extends SpellCreationEvent {
  final String art;
  const AdditionalRequisiteAdded(this.art);
  @override
  List<Object?> get props => [art];
}

class AdditionalRequisiteRemoved extends SpellCreationEvent {
  final String art;
  const AdditionalRequisiteRemoved(this.art);
  @override
  List<Object?> get props => [art];
}

class SpellCalculated extends SpellCreationEvent {
  const SpellCalculated();
}

class SpellSaveRequested extends SpellCreationEvent {
  final String name;
  const SpellSaveRequested(this.name);
  @override
  List<Object?> get props => [name];
}

class SpellDiscarded extends SpellCreationEvent {
  const SpellDiscarded();
}
