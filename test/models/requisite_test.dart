import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/requisite.dart';

void main() {
  group('RequiredRequisite', () {
    test('toMap/fromMap round-trip', () {
      final requisite = RequiredRequisite(art: 'Ignem');

      final restored = RequiredRequisite.fromMap(requisite.toMap());

      expect(restored.art, requisite.art);
    });

    test('fromMap throws a clear FormatException when art is missing', () {
      final map = <String, dynamic>{};

      expect(
        () => RequiredRequisite.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('art'), contains('RequiredRequisite')),
          ),
        ),
      );
    });
  });

  group('AdditionalRequisite', () {
    test('toMap/fromMap round-trip', () {
      final requisite = AdditionalRequisite(art: 'Vim', magnitude: 3);

      final restored = AdditionalRequisite.fromMap(requisite.toMap());

      expect(restored.art, requisite.art);
      expect(restored.magnitude, requisite.magnitude);
    });

    test('fromMap defaults magnitude to 1 when not present', () {
      final map = {'art': 'Vim'};

      final restored = AdditionalRequisite.fromMap(map);

      expect(restored.art, 'Vim');
      expect(restored.magnitude, 1);
    });

    test('fromMap throws a clear FormatException when art is missing', () {
      final map = <String, dynamic>{'magnitude': 2};

      expect(
        () => AdditionalRequisite.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('art'), contains('AdditionalRequisite')),
          ),
        ),
      );
    });
  });
}
