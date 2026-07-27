import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/parameter.dart';

void main() {
  group('Parameter', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final parameter = Parameter(
        id: 'p-1',
        name: 'Voice',
        category: 'Range',
        magnitude: 2,
        source: 'published',
      );

      final restored = Parameter.fromMap(parameter.toMap());

      expect(restored.id, parameter.id);
      expect(restored.name, parameter.name);
      expect(restored.category, parameter.category);
      expect(restored.magnitude, parameter.magnitude);
      expect(restored.source, parameter.source);
    });

    test('fromMap throws a clear FormatException when a required field is missing', () {
      final map = {
        'id': 'p-1',
        'name': 'Voice',
        'category': 'Range',
        // 'magnitude' missing
        'source': 'published',
      };

      expect(
        () => Parameter.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('magnitude'), contains('Parameter')),
          ),
        ),
      );
    });
  });
}
