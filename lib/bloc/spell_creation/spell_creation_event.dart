import 'package:equatable/equatable.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';

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

class RangeSelected extends SpellCreationEvent {
  final Parameter parameter;
  const RangeSelected(this.parameter);
  @override
  List<Object?> get props => [parameter];
}

class DurationSelected extends SpellCreationEvent {
  final Parameter parameter;
  const DurationSelected(this.parameter);
  @override
  List<Object?> get props => [parameter];
}

class TargetSelected extends SpellCreationEvent {
  final Parameter parameter;
  const TargetSelected(this.parameter);
  @override
  List<Object?> get props => [parameter];
}

class SpecialFactorToggled extends SpellCreationEvent {
  final String factorId;
  final bool selected;
  const SpecialFactorToggled(this.factorId, this.selected);
  @override
  List<Object?> get props => [factorId, selected];
}

class RequisiteAdded extends SpellCreationEvent {
  final String art;
  final String kind; // 'free' or 'adding'
  const RequisiteAdded(this.art, this.kind);
  @override
  List<Object?> get props => [art, kind];
}

class RequisiteRemoved extends SpellCreationEvent {
  final String art;
  const RequisiteRemoved(this.art);
  @override
  List<Object?> get props => [art];
}

class RequisiteKindChanged extends SpellCreationEvent {
  final String art;
  final String newKind; // 'free' or 'adding'
  const RequisiteKindChanged(this.art, this.newKind);
  @override
  List<Object?> get props => [art, newKind];
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

/// Dispatched whenever ConfigurationBloc's known special factors change
/// (initial load, or a custom factor added/deleted in the Settings tab), so
/// SpellCreationBloc can keep its SpellEngine's magnitude-lookup table in
/// sync without requiring an app restart.
class AvailableFactorsSynced extends SpellCreationEvent {
  final List<SpecialFactor> factors;
  const AvailableFactorsSynced(this.factors);
  @override
  List<Object?> get props => [factors];
}
