import 'package:equatable/equatable.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/models/spell.dart';

enum SpellCreationStatus { initial, editing, calculated, saving, saved, error, discarded }

class SpellCreationState extends Equatable {
  final SpellCreationStatus status;
  final SpellDraft draft;
  final List<String> validationErrors;
  final int? calculatedLevel;
  final LevelBreakdown? breakdown;
  final List<Spell> suggestions;
  // Precomputed per-suggestion spell levels, keyed by spell id, so the UI can
  // show "name, level, source, description" on each suggestion card without
  // recomputing (or duplicating) SpellEngine.calculateSpellLevel itself.
  final Map<String, int> suggestionLevels;
  final Spell? savedSpell;
  final String? errorMessage;

  const SpellCreationState({
    required this.status,
    required this.draft,
    this.validationErrors = const [],
    this.calculatedLevel,
    this.breakdown,
    this.suggestions = const [],
    this.suggestionLevels = const {},
    this.savedSpell,
    this.errorMessage,
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
    LevelBreakdown? breakdown,
    List<Spell>? suggestions,
    Map<String, int>? suggestionLevels,
    Spell? savedSpell,
    String? errorMessage,
  }) {
    return SpellCreationState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
      validationErrors: validationErrors ?? this.validationErrors,
      calculatedLevel: calculatedLevel ?? this.calculatedLevel,
      breakdown: breakdown ?? this.breakdown,
      suggestions: suggestions ?? this.suggestions,
      suggestionLevels: suggestionLevels ?? this.suggestionLevels,
      savedSpell: savedSpell ?? this.savedSpell,
      // Unlike the other fields, errorMessage is NOT carried forward via a
      // `?? this.errorMessage` fallback: every emit implicitly clears a
      // stale error unless the handler explicitly re-passes one, matching
      // the convention already used by SpellLibraryState/ConfigurationState.
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        draft,
        validationErrors,
        calculatedLevel,
        breakdown,
        suggestions,
        suggestionLevels,
        savedSpell,
        errorMessage,
      ];
}
