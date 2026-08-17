import 'package:equatable/equatable.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

enum SpellCreationStatus { initial, editing, calculated, saving, saved, error, discarded }

class SpellCreationState extends Equatable {
  final SpellCreationStatus status;
  final SpellDraft draft;
  final List<String> validationErrors;
  final LevelBreakdown? breakdown;
  /// Why there is no [breakdown], when there isn't one — "Choose a base effect
  /// to see a level.", and so on. Non-null exactly when [breakdown] is null,
  /// because both are written together by SpellCreationBloc's emit funnel from
  /// a single SpellEngine.previewLevel result.
  ///
  /// Not a validation error: it renders inside the level banner as ordinary
  /// text saying what to do next, never as the red error text those use.
  final String? levelUnavailableReason;
  final List<ResolvedSpell> suggestions;
  // Precomputed per-suggestion spell levels, keyed by spell id, so the UI can
  // show "name, level, source, description" on each suggestion card without
  // recomputing (or duplicating) SpellEngine.calculateSpellLevel itself.
  final Map<String, int> suggestionLevels;
  // Ids of suggestions that are themselves Ritual spells, so cards can show
  // the same Ritual chip the library screen shows.
  final Set<String> ritualSuggestionIds;
  final Spell? savedSpell;
  final String? errorMessage;
  /// The rendered strength of a General guideline at the chosen level, or null
  /// when the guideline is not General or no level is set. Precomputed by the
  /// bloc from SpellEngine.deriveGeneralEffect, following suggestionLevels:
  /// the screen renders it and never calls the engine.
  ///
  /// The sentence rather than the whole GeneralEffectValue, because
  /// GeneralEffectValue is not Equatable — in `props` it would compare by
  /// identity, and two structurally identical values would make the state
  /// look changed when nothing had.
  final String? generalEffectSentence;

  const SpellCreationState({
    required this.status,
    required this.draft,
    this.validationErrors = const [],
    this.breakdown,
    this.levelUnavailableReason,
    this.suggestions = const [],
    this.suggestionLevels = const {},
    this.ritualSuggestionIds = const {},
    this.savedSpell,
    this.errorMessage,
    this.generalEffectSentence,
  });

  factory SpellCreationState.initial() => SpellCreationState(
        status: SpellCreationStatus.initial,
        draft: SpellDraft(),
      );

  SpellCreationState copyWith({
    SpellCreationStatus? status,
    SpellDraft? draft,
    List<String>? validationErrors,
    Object? breakdown = _unset,
    Object? levelUnavailableReason = _unset,
    List<ResolvedSpell>? suggestions,
    Map<String, int>? suggestionLevels,
    Set<String>? ritualSuggestionIds,
    Spell? savedSpell,
    String? errorMessage,
    Object? generalEffectSentence = _unset,
  }) {
    return SpellCreationState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
      validationErrors: validationErrors ?? this.validationErrors,
      // Both use the same `_unset` sentinel as generalEffectSentence below,
      // and for a sharper version of the same reason. The emit funnel writes
      // whichever of the two the current draft calls for and clears the other,
      // so a plain `?? this.breakdown` -- which cannot tell "omitted" from
      // "explicitly cleared" apart -- would strand a level on screen for a
      // draft that no longer has one.
      breakdown: identical(breakdown, _unset)
          ? this.breakdown
          : breakdown as LevelBreakdown?,
      levelUnavailableReason: identical(levelUnavailableReason, _unset)
          ? this.levelUnavailableReason
          : levelUnavailableReason as String?,
      suggestions: suggestions ?? this.suggestions,
      suggestionLevels: suggestionLevels ?? this.suggestionLevels,
      ritualSuggestionIds: ritualSuggestionIds ?? this.ritualSuggestionIds,
      savedSpell: savedSpell ?? this.savedSpell,
      // Unlike the other fields, errorMessage is NOT carried forward via a
      // `?? this.errorMessage` fallback: every emit implicitly clears a
      // stale error unless the handler explicitly re-passes one, matching
      // the convention already used by SpellLibraryState/ConfigurationState.
      errorMessage: errorMessage,
      // Unlike errorMessage, generalEffectSentence must be *clearable*
      // without being wiped on every emit: only the four handlers that can
      // change baseEffect or chosenBaseLevel ever recompute it, and every
      // other emit needs to carry the existing value forward untouched. A
      // plain `?? this.generalEffectSentence` can't tell "omitted" from
      // "explicitly cleared to null" apart, so this uses the same
      // `_unset`-sentinel trick as SpellDraft.copyWith.
      generalEffectSentence: identical(generalEffectSentence, _unset)
          ? this.generalEffectSentence
          : generalEffectSentence as String?,
    );
  }

  @override
  List<Object?> get props => [
        status,
        draft,
        validationErrors,
        breakdown,
        levelUnavailableReason,
        suggestions,
        suggestionLevels,
        ritualSuggestionIds,
        savedSpell,
        errorMessage,
        generalEffectSentence,
      ];
}

/// Sentinel used by [SpellCreationState.copyWith] to distinguish "argument
/// omitted" (keep current value) from "argument explicitly passed as null"
/// (clear the field). Mirrors [SpellDraft.copyWith]'s `_unset` in
/// lib/models/spell.dart.
class _Unset {
  const _Unset();
}

const _unset = _Unset();
