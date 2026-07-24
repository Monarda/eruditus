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
        source: 'built-in',
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
        'source': 'built-in',
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

  group('SelectedParameter', () {
    test('toMap/fromMap round-trip preserves the nested Parameter', () {
      final parameter = Parameter(
        id: 'p-1',
        name: 'Voice',
        category: 'Range',
        magnitude: 2,
        source: 'built-in',
      );
      final selected = SelectedParameter(
        parameterId: 'p-1',
        parameter: parameter,
      );

      final restored = SelectedParameter.fromMap(selected.toMap());

      expect(restored.parameterId, selected.parameterId);
      expect(restored.parameter.id, parameter.id);
      expect(restored.parameter.name, parameter.name);
      expect(restored.parameter.category, parameter.category);
      expect(restored.parameter.magnitude, parameter.magnitude);
      expect(restored.parameter.source, parameter.source);
    });

    test('fromMap throws a clear FormatException when parameterId is missing', () {
      final map = {
        'parameter': {
          'id': 'p-1',
          'name': 'Voice',
          'category': 'Range',
          'magnitude': 2,
          'source': 'built-in',
        },
      };

      expect(
        () => SelectedParameter.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('parameterId'), contains('SelectedParameter')),
          ),
        ),
      );
    });
  });
}
