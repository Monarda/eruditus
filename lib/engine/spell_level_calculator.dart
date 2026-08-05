class SpellLevelCalculator {
  /// Combines a base level with a list of magnitudes.
  ///
  /// Below level 5 the rulebook's steps are 1, 2, 3, 4, 5 — so a magnitude
  /// inside that additive tier is worth 1 level, not 5. Above it, each
  /// magnitude is worth 5.
  ///
  /// Negative magnitudes are permitted: one published spell, *The Severed Limb
  /// Made Whole*, charges -1 because the old limb is needed. They mirror the
  /// positive rule — worth 1 while the spell sits inside the additive tier,
  /// 5 above it — and restore the additive capacity they give back, so that
  /// `[1, -1]` is always a no-op regardless of base level.
  ///
  /// The invariant is **not** the flat "the result must be at least 1" this
  /// method was first written with. `assets/data/base_effects.json` holds 47
  /// base-level-0 guidelines (the General and ward lines — `crvi-G1`,
  /// `rean-gen`, `inco-gen`…), and one of those at Personal/Momentary/
  /// Individual is `calculate(0, [0, 0, 0])`, a legitimate level 0 that this
  /// method has always returned. What is rejected is magnitudes *driving* a
  /// spell below where it started: `level < 1 && level < baseLevel`. So base 0
  /// with no net magnitude still returns 0, while base 5 with five -1s throws.
  static int calculate(int baseLevel, List<int> magnitudes) {
    if (baseLevel < 0) {
      throw ArgumentError.value(
        baseLevel,
        'baseLevel',
        'Base level must not be negative',
      );
    }

    int level = baseLevel;
    int additiveCapacity = (5 - baseLevel).clamp(0, double.infinity).toInt();

    for (final magnitude in magnitudes) {
      if (magnitude >= 0) {
        final additivePortion = magnitude.clamp(0, additiveCapacity);
        final multiplierPortion = magnitude - additivePortion;

        level += additivePortion;
        additiveCapacity -= additivePortion;
        level += (multiplierPortion * 5);
      } else {
        for (var step = 0; step < -magnitude; step++) {
          if (level <= 5) {
            level -= 1;
            additiveCapacity += 1;
          } else {
            level -= 5;
          }
        }
      }
    }

    // Only magnitudes that pushed the spell below where it started are an
    // error. A base-0 guideline that never moved is level 0 and always was.
    if (level < 1 && level < baseLevel) {
      throw ArgumentError.value(
        level,
        'magnitudes',
        'Negative magnitudes reduced the spell below level 1',
      );
    }

    return level;
  }
}
