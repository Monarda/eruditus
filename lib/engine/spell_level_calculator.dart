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
  /// The invariant is that a spell always has a level of at least 1. Base
  /// level 0 used to be permitted because `base_effects.json` held 47
  /// General guidelines stored with `baseLevel: 0`; those now carry
  /// `baseLevel: null` and supply the caster's chosen level instead, so the
  /// allowance and its special case are gone.
  static int calculate(int baseLevel, List<int> magnitudes) {
    if (baseLevel < 1) {
      throw ArgumentError.value(
        baseLevel,
        'baseLevel',
        'Base level must be at least 1',
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

    if (level < 1) {
      throw ArgumentError.value(
        level,
        'magnitudes',
        'Magnitudes reduced the spell below level 1',
      );
    }

    return level;
  }
}
