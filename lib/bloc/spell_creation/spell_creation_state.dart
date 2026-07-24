import 'package:equatable/equatable.dart';
import 'package:eruditus/models/spell.dart';

enum SpellCreationStatus { initial, editing, calculated, saving, saved, discarded }

class SpellCreationState extends Equatable {
  final SpellCreationStatus status;
  final SpellDraft draft;
  final List<String> validationErrors;
  final int? calculatedLevel;
  final List<Spell> suggestions;
  final Spell? savedSpell;

  const SpellCreationState({
    required this.status,
    required this.draft,
    this.validationErrors = const [],
    this.calculatedLevel,
    this.suggestions = const [],
    this.savedSpell,
  });

  factory SpellCreationState.initial() => SpellCreationState(
        status: SpellCreationStatus.initial,
        draft: SpellDraft(),
      );

  SpellCreationState copyWith({
    SpellCreationStatus? status,
    SpellDraft? draft,
    List<String>? validationErrors,
    int? calculatedLevel,
    List<Spell>? suggestions,
    Spell? savedSpell,
  }) {
    return SpellCreationState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
      validationErrors: validationErrors ?? this.validationErrors,
      calculatedLevel: calculatedLevel ?? this.calculatedLevel,
      suggestions: suggestions ?? this.suggestions,
      savedSpell: savedSpell ?? this.savedSpell,
    );
  }

  @override
  List<Object?> get props => [
        status,
        draft,
        validationErrors,
        calculatedLevel,
        suggestions,
        savedSpell,
      ];
}
