/// Why a spell is a Ritual. See Core Rules "Ritual Spells", line 12340.
///
/// [ritualOnlyRange], [ritualOnlyDuration] and [ritualOnlyTarget] are named
/// for the generic `Parameter.requiresRitual` flag rather than for specific
/// parameters, because todo item 17 adds three more ritual-only Durations
/// and the first-ever ritual-only Range (Symbol) -- a reason called
/// `yearDuration` would become a lie, and Range needed a reason at all.
/// Callers that want to name the parameter read its `name` directly.
enum RitualReason {
  ritualOnlyRange,
  ritualOnlyDuration,
  ritualOnlyTarget,
  exceedsMaxFormulaicLevel,
  guideline,
  lastingCreation,
  storyguideRuling,
}

/// Whether a spell is a Ritual, and every reason it is one.
///
/// Reasons accumulate rather than short-circuit: Aegis of the Hearth is a
/// Ritual for two independent reasons, and reporting only the first would make
/// the UI text wrong. It would also foreclose the enchanted-item rule at Core
/// Rules line 10566, which turns on a spell being a Ritual *only* because its
/// level exceeds the Formulaic cap.
class RitualStatus {
  /// The highest level a Formulaic or Spontaneous spell may have. Core Rules
  /// line 12346: "they may have a level of 50, but not 51 or higher."
  static const int maxFormulaicLevel = 50;

  /// Core Rules line 12354: "Ritual spells are always at least level 20, even
  /// if the level calculation would make them lower."
  static const int minimumRitualLevel = 20;

  final List<RitualReason> reasons;

  const RitualStatus(this.reasons);

  const RitualStatus.notRitual() : reasons = const [];

  bool get isRitual => reasons.isNotEmpty;
}
