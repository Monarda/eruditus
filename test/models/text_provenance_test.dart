import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/text_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const citation = Citation(bookId: 'arm5-core');

  group('sourcedFrom — the one rule', () {
    test('text on a published entry is the rulebook\'s own words', () {
      final result = sourcedFrom(
        'Give an animal a +1 bonus to Recovery rolls',
        Provenance(source: PublicationSource.published, citations: const [citation]),
      );

      expect(result.provenance, TextProvenance.verbatim);
      expect(result.text, 'Give an animal a +1 bonus to Recovery rolls');
      expect(result.citations, const [citation]);
    });

    test('text on a user-created entry is the user\'s own words', () {
      final result = sourcedFrom(
        'My homebrew guideline',
        Provenance(source: PublicationSource.userCreated),
      );

      expect(result.provenance, TextProvenance.authored);
      expect(result.citations, isEmpty);
    });

    test('it carries every citation through, not just the first', () {
      final result = sourcedFrom(
        'text',
        Provenance(source: PublicationSource.published, citations: const [
          Citation(bookId: 'arm5-core', page: 112),
          Citation(bookId: 'arm5-hohmc'),
        ]),
      );

      expect(result.citations, hasLength(2));
      expect(result.citations.last.bookId, 'arm5-hohmc');
    });
  });

  group('the verbatim-implies-citation invariant', () {
    test('a verbatim quote whose source cannot be named is rejected', () {
      expect(
        () => SourcedText.verbatim('text', const []),
        throwsA(isA<ArgumentError>()),
        reason: 'a quote we cannot attribute is a licence defect, not a '
            'display bug — see DECISIONS.md, "Licensing and attribution"',
      );
    });

    test('authored text carries no citations', () {
      expect(const SourcedText.authored('ours').citations, isEmpty);
    });

    test('a translation must still name what it was translated from', () {
      expect(
        () => SourcedText.translated('texto', const []),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        SourcedText.translated('texto', const [citation]).provenance,
        TextProvenance.translated,
      );
    });
  });

  group('value equality', () {
    test('two SourcedTexts with the same parts are equal', () {
      expect(
        SourcedText.verbatim('a', const [citation]),
        SourcedText.verbatim('a', const [citation]),
      );
    });

    test('same text, different provenance, is not equal', () {
      expect(
        SourcedText.verbatim('a', const [citation]),
        isNot(const SourcedText.authored('a')),
      );
    });
  });
}
