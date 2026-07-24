class SpellLevelCalculator {
  static int calculate(int baseLevel, List<int> magnitudes) {
    int level = baseLevel;
    int additiveCapacity = (5 - baseLevel).clamp(0, double.infinity).toInt();

    for (final magnitude in magnitudes) {
      if (additiveCapacity > 0) {
        final additivePortion = magnitude.clamp(0, additiveCapacity);
        final multiplierPortion = magnitude - additivePortion;

        level += additivePortion;
        additiveCapacity -= additivePortion;
        level += (multiplierPortion * 5);
      } else {
        level += (magnitude * 5);
      }
    }

    return level;
  }
}
