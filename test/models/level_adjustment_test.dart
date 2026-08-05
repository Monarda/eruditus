import 'package:eruditus/models/level_adjustment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelAdjustment', () {
    test('round-trips through toMap/fromMap', () {
      final adjustment = LevelAdjustment(magnitude: 1, note: 'fancy effect');
      expect(LevelAdjustment.fromMap(adjustment.toMap()), adjustment);
    });

    test('accepts a negative magnitude', () {
      // The Severed Limb Made Whole charges -1 because the old limb is needed.
      final adjustment =
          LevelAdjustment(magnitude: -1, note: 'because the old limb is needed');
      expect(adjustment.magnitude, -1);
      expect(LevelAdjustment.fromMap(adjustment.toMap()), adjustment);
    });

    test('accepts a zero magnitude, because some notes record that a thing is free', () {
      final adjustment = LevelAdjustment(
          magnitude: 0, note: 'mist is a purely cosmetic effect and thus is free');
      expect(adjustment.magnitude, 0);
    });

    test('rejects an empty note, because the note is the justification', () {
      expect(() => LevelAdjustment(magnitude: 1, note: '   '),
          throwsA(isA<FormatException>()));
    });

    test('fromMap rejects a missing magnitude', () {
      expect(() => LevelAdjustment.fromMap({'note': 'x'}),
          throwsA(isA<FormatException>()));
    });

    test('fromMap rejects a missing note', () {
      expect(() => LevelAdjustment.fromMap({'magnitude': 1}),
          throwsA(isA<FormatException>()));
    });

    test('fromMap rejects an empty or whitespace-only note', () {
      // Not a completeness box: SpellCreationBloc handles this same "the note
      // went blank" case when the creation screen's note field is cleared, and
      // a hand-edited backup JSON reaches the model by this path instead.
      expect(() => LevelAdjustment.fromMap({'magnitude': 1, 'note': ''}),
          throwsA(isA<FormatException>()));
      expect(() => LevelAdjustment.fromMap({'magnitude': 1, 'note': '  '}),
          throwsA(isA<FormatException>()));
    });

    test('two adjustments with the same magnitude and note are equal', () {
      expect(LevelAdjustment(magnitude: 2, note: 'n'),
          LevelAdjustment(magnitude: 2, note: 'n'));
    });
  });
}
