import 'package:equatable/equatable.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/ritual_declaration.dart';

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

class ModifierOptionSelected extends SpellCreationEvent {
  final String modifierId;
  final String optionId;
  const ModifierOptionSelected(this.modifierId, this.optionId);
  @override
  List<Object?> get props => [modifierId, optionId];
}

class ModifierOptionDeselected extends SpellCreationEvent {
  final String modifierId;
  final String optionId;
  const ModifierOptionDeselected(this.modifierId, this.optionId);
  @override
  List<Object?> get props => [modifierId, optionId];
}

/// Dispatched whenever ConfigurationBloc's known modifiers change, so the
/// SpellEngine's option-magnitude lookup stays in sync without a restart.
class AvailableModifiersSynced extends SpellCreationEvent {
  final List<Modifier> modifiers;
  const AvailableModifiersSynced(this.modifiers);
  @override
  List<Object?> get props => [modifiers];
}

/// Dispatched whenever ConfigurationBloc's known parameters change, so the
/// SpellEngine can resolve a General guideline's reference parameter (e.g.
/// Touch for a ward) by id without a restart. Mirrors
/// [AvailableModifiersSynced].
class AvailableParametersSynced extends SpellCreationEvent {
  final List<Parameter> parameters;
  const AvailableParametersSynced(this.parameters);
  @override
  List<Object?> get props => [parameters];
}

/// The caster's own statement about a spell's Ritual status — the part the
/// rulebook leaves to judgement rather than to the spell's configuration.
class RitualDeclarationChanged extends SpellCreationEvent {
  final RitualDeclaration declaration;
  const RitualDeclarationChanged(this.declaration);
  @override
  List<Object?> get props => [declaration];
}

class AdjustmentAdded extends SpellCreationEvent {
  const AdjustmentAdded();
  @override
  List<Object?> get props => const [];
}

class AdjustmentRemoved extends SpellCreationEvent {
  final int index;
  const AdjustmentRemoved(this.index);
  @override
  List<Object?> get props => [index];
}

class AdjustmentUpdated extends SpellCreationEvent {
  final int index;
  final int magnitude;
  final String note;
  const AdjustmentUpdated(this.index, this.magnitude, this.note);
  @override
  List<Object?> get props => [index, magnitude, note];
}
