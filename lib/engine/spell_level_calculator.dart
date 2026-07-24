class SpellLevelCalculator {
  static int calculate(int baseLevel, List<int> magnitudes) {
    if (baseLevel < 0) {
      throw ArgumentError.value(
        baseLevel,
        'baseLevel',
        'Base level must not be negative',
      );
    }

    for (var i = 0; i < magnitudes.length; i++) {
      if (magnitudes[i] < 0) {
        throw ArgumentError.value(
          magnitudes[i],
          'magnitudes[$i]',
          'Magnitude must not be negative',
        );
      }
    }

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
