import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/special_factor.dart';

void main() {
  group('SpecialFactor', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final factor = SpecialFactor(
        id: 'sf-1',
        technique: 'Creo',
        form: 'Ignem',
        name: 'Unnatural Fire',
        description: 'Fire that acts strangely',
        magnitude: 1,
        source: 'built-in',
      );

      final restored = SpecialFactor.fromMap(factor.toMap());

      expect(restored.id, factor.id);
      expect(restored.technique, factor.technique);
      expect(restored.form, factor.form);
      expect(restored.name, factor.name);
      expect(restored.description, factor.description);
      expect(restored.magnitude, factor.magnitude);
      expect(restored.source, factor.source);
    });

    test('fromMap throws a clear FormatException when a required field is missing', () {
      final map = {
        'id': 'sf-1',
        'technique': 'Creo',
        'form': 'Ignem',
        'name': 'Unnatural Fire',
        'description': 'Fire that acts strangely',
        // 'magnitude' missing
        'source': 'built-in',
      };

      expect(
        () => SpecialFactor.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('magnitude'), contains('SpecialFactor')),
          ),
        ),
      );
    });
  });
}
