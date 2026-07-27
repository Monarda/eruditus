import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  group('Parameter', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final parameter = Parameter(
        id: 'p-1',
        name: 'Voice',
        category: 'Range',
        magnitude: 2,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );

      final restored = Parameter.fromMap(parameter.toMap());

      expect(restored.id, parameter.id);
      expect(restored.name, parameter.name);
      expect(restored.category, parameter.category);
      expect(restored.magnitude, parameter.magnitude);
      expect(restored.provenance.source, parameter.provenance.source);
      expect(restored.provenance.citations, parameter.provenance.citations);
    });

    test('fromMap throws a clear FormatException when a required field is missing', () {
      final map = {
        'id': 'p-1',
        'name': 'Voice',
        'category': 'Range',
        // 'magnitude' missing
        'source': 'published',
        'citations': [
          {'bookId': 'arm5-core'},
        ],
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

    test('a published parameter needs at least one citation', () {
      expect(
        () => Parameter(
          id: 'x', name: 'X', category: 'Range', magnitude: 1,
          provenance: Provenance(source: PublicationSource.published),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trips a published parameter with a citation', () {
      final parameter = Parameter(
        id: 'x', name: 'X', category: 'Range', magnitude: 1,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final restored = Parameter.fromMap(parameter.toMap());
      expect(restored.provenance.source, PublicationSource.published);
      expect(restored.provenance.citations, [const Citation(bookId: 'arm5-core')]);
    });
  });
}
