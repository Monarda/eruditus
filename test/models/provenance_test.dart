import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  test('a published provenance with a citation round-trips', () {
    final provenance = Provenance(
      source: PublicationSource.published,
      citations: const [Citation(bookId: 'arm5-core')],
    );
    final restored = Provenance.fromMap(provenance.toMap());

    expect(restored.source, PublicationSource.published);
    expect(restored.citations, [const Citation(bookId: 'arm5-core')]);
  });

  test('a user-created provenance with no citations round-trips', () {
    final provenance = Provenance(source: PublicationSource.userCreated);
    final restored = Provenance.fromMap(provenance.toMap());

    expect(restored.source, PublicationSource.userCreated);
    expect(restored.citations, isEmpty);
  });

  test('published with no citations throws at construction', () {
    expect(() => Provenance(source: PublicationSource.published),
        throwsA(isA<FormatException>()));
  });

  test('user-created with a citation throws at construction', () {
    expect(
      () => Provenance(
        source: PublicationSource.userCreated,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromMap defaults citations to empty when the key is absent', () {
    final provenance = Provenance.fromMap({'source': 'user-created'});
    expect(provenance.citations, isEmpty);
  });

  test('two citations to the same book on different pages both survive', () {
    final provenance = Provenance(
      source: PublicationSource.published,
      citations: const [
        Citation(bookId: 'arm5-core', page: 10),
        Citation(bookId: 'arm5-core', page: 42),
      ],
    );
    final restored = Provenance.fromMap(provenance.toMap());
    expect(restored.citations, hasLength(2));
  });
}
