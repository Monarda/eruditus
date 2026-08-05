import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/general_effect_formula.dart';

void main() {
  test('every kind and multiplier round-trips through a map', () {
    for (final kind in GeneralEffectKind.values) {
      for (final multiplier in GeneralEffectMultiplier.values) {
        for (final unit in GeneralEffectUnit.values) {
          final formula = GeneralEffectFormula(
            kind: kind, multiplier: multiplier, offsetMagnitudes: 2,
            unit: unit, stressDie: true);

          expect(GeneralEffectFormula.fromMap(formula.toMap()).toMap(),
              formula.toMap());
        }
      }
    }
  });

  test('defaults are multiplier one, offset zero, levels, no stress die', () {
    final formula =
        GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold);

    expect(formula.multiplier, GeneralEffectMultiplier.one);
    expect(formula.offsetMagnitudes, 0);
    expect(formula.unit, GeneralEffectUnit.levels);
    expect(formula.stressDie, isFalse);
  });

  test('a negative offset is allowed', () {
    final formula = GeneralEffectFormula(
      kind: GeneralEffectKind.spellTraceMagnitude,
      offsetMagnitudes: -2,
      unit: GeneralEffectUnit.magnitudes);

    expect(formula.offsetMagnitudes, -2);
  });

  test('an unknown kind name is a FormatException, not a silent default', () {
    expect(
        () => GeneralEffectFormula.fromMap({'kind': 'noSuchKind'}),
        throwsFormatException);
  });

  test('an unknown multiplier name is a FormatException', () {
    expect(
        () => GeneralEffectFormula.fromMap({
          'kind': 'mightThreshold',
          'multiplier': 'noSuchMultiplier',
        }),
        throwsFormatException);
  });

  test('an unknown unit name is a FormatException', () {
    expect(
        () => GeneralEffectFormula.fromMap({
          'kind': 'mightThreshold',
          'unit': 'noSuchUnit',
        }),
        throwsFormatException);
  });

  test('fromMap with only kind set uses all other defaults', () {
    final formula = GeneralEffectFormula.fromMap({'kind': 'damage'});

    expect(formula.kind, GeneralEffectKind.damage);
    expect(formula.multiplier, GeneralEffectMultiplier.one);
    expect(formula.offsetMagnitudes, 0);
    expect(formula.unit, GeneralEffectUnit.levels);
    expect(formula.stressDie, isFalse);
  });
}
