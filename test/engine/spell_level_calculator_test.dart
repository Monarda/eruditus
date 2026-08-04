import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/spell_level_calculator.dart';

void main() {
  group('SpellLevelCalculator', () {
    test('Eyes of the Cat: Base 2 + Touch(+1) + Sun(+2) = 5', () {
      const baseLevel = 2;
      const magnitudes = [1, 2];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 5);
    });

    test('Seal the Earth: Base 1 + Voice(+2) + Sun(+2) + Group(+2) = 15', () {
      const baseLevel = 1;
      const magnitudes = [2, 2, 2];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 15);
    });

    test('Haunt: Base 2 + Arc(+4) + Conc(+1) + Move(+2) + Intricacy(+1) + Intellego(+1) = 35', () {
      const baseLevel = 2;
      const magnitudes = [4, 1, 2, 1, 1];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 35);
    });

    test('Base 10 + Voice(+2) = 20 (base already above 5)', () {
      const baseLevel = 10;
      const magnitudes = [2];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 20);
    });

    test('Base 1 + Touch(+1) = 2 (both within additive tier)', () {
      const baseLevel = 1;
      const magnitudes = [1];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 2);
    });

    test('Empty magnitudes returns base level', () {
      const baseLevel = 5;
      const magnitudes = <int>[];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 5);
    });

    test('Magnitude splitting: Base 4 + Touch(+1) + Sun(+2) = 15', () {
      const baseLevel = 4;
      const magnitudes = [1, 2];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 15);
    });

    test('Base 5 exactly: capacity is 0, magnitude goes straight to multiplier tier', () {
      const baseLevel = 5;
      const magnitudes = [2];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 15);
    });

    test('Zero-value magnitude is a no-op', () {
      const baseLevel = 3;
      const magnitudes = [0];

      final level = SpellLevelCalculator.calculate(baseLevel, magnitudes);

      expect(level, 3);
    });

    test('Negative baseLevel throws ArgumentError', () {
      const baseLevel = -1;
      const magnitudes = [1];

      expect(
        () => SpellLevelCalculator.calculate(baseLevel, magnitudes),
        throwsArgumentError,
      );
    });

    test('a negative magnitude subtracts 5 above the additive tier', () {
      // The Severed Limb Made Whole: base 25, so additive capacity is already 0.
      expect(SpellLevelCalculator.calculate(25, [1, -1]), 25);
      expect(SpellLevelCalculator.calculate(25, [-1]), 20);
    });

    test('a negative magnitude subtracts 1 inside the additive tier', () {
      // Below level 5 a magnitude is worth 1, so removing one takes 1 back.
      expect(SpellLevelCalculator.calculate(3, [1]), 4);
      expect(SpellLevelCalculator.calculate(3, [1, -1]), 3);
      expect(SpellLevelCalculator.calculate(3, [-1]), 2);
    });

    test('a negative magnitude crossing out of the multiplier tier lands on 5', () {
      expect(SpellLevelCalculator.calculate(5, [1]), 10);
      expect(SpellLevelCalculator.calculate(5, [1, -1]), 5);
    });

    test('subtracting restores additive capacity, so the next add is worth 1 again', () {
      // base 3 (capacity 2) -> +1 -> 4 (capacity 1) -> -1 -> 3 (capacity 2)
      // -> +2 -> 5, not 3 + 1 + 5.
      expect(SpellLevelCalculator.calculate(3, [1, -1, 2]), 5);
    });

    test('throws when subtraction drives the result below 1', () {
      expect(() => SpellLevelCalculator.calculate(5, [-1, -1, -1, -1, -1]),
          throwsArgumentError);
    });

    test('a base-0 guideline with no magnitudes is level 0, not an error', () {
      // Regression: base_effects.json holds 47 base-level-0 guidelines (the
      // General and ward lines — crvi-G1, rean-gen, inco-gen…), all selectable
      // in the creation screen. One at Personal/Momentary/Individual is
      // exactly this call, and it returned 0 until the "level >= 1" guard
      // this branch added started rejecting it.
      expect(SpellLevelCalculator.calculate(0, const []), 0);
      expect(SpellLevelCalculator.calculate(0, const [0, 0, 0]), 0);
    });

    test('a base-0 guideline that adds then removes a magnitude is still 0', () {
      expect(SpellLevelCalculator.calculate(0, const [1, -1]), 0);
    });

    test('a base-0 guideline pushed below 0 by a magnitude still throws', () {
      // The guard fires on magnitudes driving the level below where it
      // started, so base 0 is not a blanket exemption.
      expect(() => SpellLevelCalculator.calculate(0, const [-1]),
          throwsArgumentError);
    });

    test('a negative base level still throws', () {
      expect(() => SpellLevelCalculator.calculate(-1, const []), throwsArgumentError);
    });
  });
}
