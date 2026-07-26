/// One line of a spell's level calculation. [magnitude] holds the base level
/// when [isBase] is true, and a magnitude contribution otherwise.
class LevelContribution {
  final String label;
  final int magnitude;
  final bool isBase;

  const LevelContribution({
    required this.label,
    required this.magnitude,
    this.isBase = false,
  });
}

/// A spell's calculated level together with the sources that produced it.
class LevelBreakdown {
  final int level;
  final List<LevelContribution> contributions;

  const LevelBreakdown({required this.level, required this.contributions});

  /// Total magnitude from every non-base contribution. Not displayed in the
  /// UI — see the spec's UI section — but used by tests and by callers that
  /// need the magnitude sum without re-deriving it.
  int get magnitudeTotal => contributions
      .where((c) => !c.isBase)
      .fold(0, (sum, c) => sum + c.magnitude);
}
