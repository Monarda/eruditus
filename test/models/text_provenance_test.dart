import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/text_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal published spell. Only the fields the provenance rule reads
/// matter here; the rest are the smallest values that satisfy Spell's own
/// invariants.
Spell _spell({required String? summary, required String? description}) => Spell(
      id: 'lib-test',
      name: 'Test Spell',
      baseEffectId: 'cran-1',
      technique: 'Creo',
      form: 'Animal',
      rangeId: 'range-touch',
      durationId: 'duration-moon',
      targetId: 'target-group',
      requisites: const {},
      summary: summary,
      description: description,
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

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

  group('model getters apply the rule', () {
    test('a published guideline\'s description is verbatim, with its citation', () {
      final effect = BaseEffect(
        id: 'cran-1',
        technique: 'Creo',
        form: 'Animal',
        description: 'Give an animal a +1 bonus to Recovery rolls',
        baseLevel: 1,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [citation],
        ),
      );

      expect(effect.sourcedDescription.provenance, TextProvenance.verbatim);
      expect(effect.sourcedDescription.citations, const [citation]);
    });

    test('a custom guideline\'s description is authored', () {
      final effect = BaseEffect(
        id: 'custom-1',
        technique: 'Creo',
        form: 'Animal',
        description: 'My homebrew guideline',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      expect(effect.sourcedDescription.provenance, TextProvenance.authored);
    });

    test('a null summary yields a null SourcedText, not an empty one', () {
      final spell = _spell(summary: null, description: 'text');

      expect(spell.sourcedSummary, isNull);
      expect(spell.sourcedDescription, isNotNull);
    });
  });
}
