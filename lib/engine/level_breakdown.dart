import 'package:equatable/equatable.dart';
import 'package:eruditus/engine/ritual_status.dart';

/// One line of a spell's level calculation. [magnitude] holds the base level
/// when [isBase] is true, and a magnitude contribution otherwise.
class LevelContribution extends Equatable {
  final String label;
  final int magnitude;
  final bool isBase;

  const LevelContribution({
    required this.label,
    required this.magnitude,
    this.isBase = false,
  });

  // See RitualStatus.props for why these three types carry value equality.
  @override
  List<Object?> get props => [label, magnitude, isBase];
}

/// A spell's calculated level together with the sources that produced it.
class LevelBreakdown extends Equatable {
  /// The level after the Ritual minimum has been applied. This is the number
  /// the user sees.
  final int level;

  /// The level the magnitudes alone produce, before the Ritual minimum. Equal
  /// to [level] whenever the minimum does not bite.
  final int rawLevel;

  final RitualStatus ritualStatus;
  final List<LevelContribution> contributions;

  const LevelBreakdown({
    required this.level,
    required this.rawLevel,
    required this.contributions,
    this.ritualStatus = const RitualStatus.notRitual(),
  });

  /// True when the Ritual minimum raised the level. The floor is deliberately
  /// NOT modelled as a [LevelContribution]: contributions carry magnitudes and
  /// [magnitudeTotal] sums them, so a contribution holding a level delta would
  /// silently corrupt that sum. Callers explain the difference themselves by
  /// comparing [level] against [rawLevel].
  bool get ritualMinimumApplied => level != rawLevel;

  /// Total magnitude from every non-base contribution. Not displayed in the
  /// UI — see the spec's UI section — but used by tests and by callers that
  /// need the magnitude sum without re-deriving it.
  int get magnitudeTotal => contributions
      .where((c) => !c.isBase)
      .fold(0, (sum, c) => sum + c.magnitude);

  @override
  List<Object?> get props => [level, rawLevel, ritualStatus, contributions];
}
