import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/requisite.dart';

void main() {
  group('Requisite', () {
    test('an adding requisite has magnitude 1', () {
      expect(Requisite(art: 'Ignem', kind: RequisiteKind.adding).magnitude, 1);
    });

    test('a free requisite has magnitude 0', () {
      expect(Requisite(art: 'Ignem', kind: RequisiteKind.free).magnitude, 0);
    });

    test('toMap/fromMap round-trip preserves art and kind', () {
      for (final kind in RequisiteKind.values) {
        final requisite = Requisite(art: 'Vim', kind: kind);

        final restored = Requisite.fromMap(requisite.toMap());

        expect(restored.art, requisite.art);
        expect(restored.kind, requisite.kind, reason: 'kind $kind did not survive the round-trip');
        expect(restored.magnitude, requisite.magnitude);
      }
    });

    test('fromMap throws a clear FormatException when art is missing', () {
      final map = {'kind': 'free'};

      expect(
        () => Requisite.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('art'), contains('Requisite')),
          ),
        ),
      );
    });

    test('fromMap throws a clear FormatException when kind is missing', () {
      final map = {'art': 'Vim'};

      expect(
        () => Requisite.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('kind'), contains('Requisite')),
          ),
        ),
      );
    });

    test('fromMap throws a clear FormatException naming the valid kinds when kind is unknown', () {
      final map = {'art': 'Vim', 'kind': 'mandatory'};

      expect(
        () => Requisite.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('mandatory'), contains('free'), contains('adding')),
          ),
        ),
      );
    });
  });
}
