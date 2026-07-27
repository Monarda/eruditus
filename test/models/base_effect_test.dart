import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  group('BaseEffect', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final effect = BaseEffect(
        id: 'be-1',
        technique: 'Creo',
        form: 'Ignem',
        description: 'Create flame',
        baseLevel: 10,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );

      final restored = BaseEffect.fromMap(effect.toMap());

      expect(restored.id, effect.id);
      expect(restored.technique, effect.technique);
      expect(restored.form, effect.form);
      expect(restored.description, effect.description);
      expect(restored.baseLevel, effect.baseLevel);
      expect(restored.provenance.source, effect.provenance.source);
      expect(restored.provenance.citations, effect.provenance.citations);
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

    test('a published effect needs at least one citation', () {
      expect(
        () => BaseEffect(
          id: 'x', technique: 'Creo', form: 'Ignem', description: 'x', baseLevel: 5,
          provenance: Provenance(source: PublicationSource.published),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trips a published effect with a citation', () {
      final effect = BaseEffect(
        id: 'x', technique: 'Creo', form: 'Ignem', description: 'x', baseLevel: 5,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final restored = BaseEffect.fromMap(effect.toMap());
      expect(restored.provenance.source, PublicationSource.published);
      expect(restored.provenance.citations, [const Citation(bookId: 'arm5-core')]);
    });

    test('a user-created effect needs no citation', () {
      final effect = BaseEffect(
        id: 'x', technique: 'Creo', form: 'Ignem', description: 'x', baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      expect(effect.provenance.citations, isEmpty);
    });
  });
}
