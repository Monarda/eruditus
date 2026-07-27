import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';

void main() {
  group('BaseEffect', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final effect = BaseEffect(
        id: 'be-1',
        technique: 'Creo',
        form: 'Ignem',
        description: 'Create flame',
        baseLevel: 10,
        source: 'published',
      );

      final restored = BaseEffect.fromMap(effect.toMap());

      expect(restored.id, effect.id);
      expect(restored.technique, effect.technique);
      expect(restored.form, effect.form);
      expect(restored.description, effect.description);
      expect(restored.baseLevel, effect.baseLevel);
      expect(restored.source, effect.source);
    });

    test('fromMap throws a clear FormatException when a required field is missing', () {
      final map = {
        'id': 'be-1',
        'technique': 'Creo',
        // 'form' missing
        'description': 'Create flame',
        'baseLevel': 10,
        'source': 'published',
      };

      expect(
        () => BaseEffect.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('form'), contains('BaseEffect')),
          ),
        ),
      );
    });

    test('fromMap throws a clear FormatException when a required field has the wrong type', () {
      final map = {
        'id': 'be-1',
        'technique': 'Creo',
        'form': 'Ignem',
        'description': 'Create flame',
        'baseLevel': 'not-an-int',
        'source': 'published',
      };

      expect(
        () => BaseEffect.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('baseLevel'), contains('BaseEffect')),
          ),
        ),
      );
    });
  });
}
