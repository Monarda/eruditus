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

    test('a negative base level still throws', () {
      expect(() => SpellLevelCalculator.calculate(-1, const []), throwsArgumentError);
    });

    group('base level floor', () {
      test('a base level of 0 is rejected', () {
        expect(() => SpellLevelCalculator.calculate(0, const []),
            throwsA(isA<ArgumentError>()));
      });

      test('a base level of 1 is accepted', () {
        expect(SpellLevelCalculator.calculate(1, const []), 1);
      });
    });

    group('parameter refunds', () {
      test('base 10 refunded three magnitudes lands at 3, not -5', () {
        // 10 is above the additive tier, so the first refund costs 5;
        // 5 and 4 are inside it, so the next two cost 1 each: 10 -> 5 -> 4 -> 3.
        expect(SpellLevelCalculator.calculate(10, const [-1, -2]), 3);
      });

      test('splitting a refund across parameters matches one combined refund', () {
        expect(SpellLevelCalculator.calculate(10, const [-1, -2]),
            SpellLevelCalculator.calculate(10, const [-3]));
      });

      test('a refund that would cross 1 throws', () {
        expect(() => SpellLevelCalculator.calculate(5, const [-5]),
            throwsA(isA<ArgumentError>()));
      });
    });
  });
}
