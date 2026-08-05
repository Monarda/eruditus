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

    test('a null baseLevel marks the effect General', () {
      final effect = BaseEffect(
        id: 'revi-G1', technique: 'Rego', form: 'Vim',
        description: 'Ward against supernatural beings from one realm',
        baseLevel: null,
        provenance: Provenance(source: PublicationSource.published, citations: [
          Citation(bookId: 'arm5-core'),
        ]),
      );

      expect(effect.isGeneral, isTrue);
      expect(effect.baseLevel, isNull);
      expect(effect.toMap()['baseLevel'], isNull);
    });

    test('an ordinary effect is not General', () {
      final effect = BaseEffect(
        id: 'crig-10', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 10,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      expect(effect.isGeneral, isFalse);
    });

    test('fromMap round-trips a null baseLevel', () {
      final map = {
        'id': 'revi-G1', 'technique': 'Rego', 'form': 'Vim',
        'description': 'Ward', 'baseLevel': null,
        'source': 'user-created',
      };

      expect(BaseEffect.fromMap(map).isGeneral, isTrue);
    });

    test('fromMap rejects a missing baseLevel key', () {
      final map = {
        'id': 'revi-G1', 'technique': 'Rego', 'form': 'Vim',
        'description': 'Ward', 'source': 'userCreated',
      };

      expect(() => BaseEffect.fromMap(map), throwsFormatException);
    });

    test('ritualRequirement defaults to none and round-trips every value', () {
      for (final value in RitualRequirement.values) {
        final effect = BaseEffect(
          id: 'e-1', technique: 'Creo', form: 'Corpus',
          description: 'Heal a Light Wound', baseLevel: 15,
          ritualRequirement: value,
          provenance: Provenance(source: PublicationSource.userCreated),
        );
        expect(BaseEffect.fromMap(effect.toMap()).ritualRequirement, value);
      }

      final plain = BaseEffect(
        id: 'e-2', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 10,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      expect(plain.ritualRequirement, RitualRequirement.none);
    });

    test('fromMap treats an absent ritualRequirement key as none', () {
      final restored = BaseEffect.fromMap({
        'id': 'e-3',
        'technique': 'Creo',
        'form': 'Ignem',
        'description': 'Create flame',
        'baseLevel': 10,
        'source': 'user-created',
      });
      expect(restored.ritualRequirement, RitualRequirement.none);
    });

    test('fromMap throws a clear FormatException on an unknown ritualRequirement', () {
      expect(
        () => BaseEffect.fromMap({
          'id': 'e-4',
          'technique': 'Creo',
          'form': 'Ignem',
          'description': 'Create flame',
          'baseLevel': 10,
          'ritualRequirement': 'mandatory',
          'source': 'user-created',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('mandatory'),
              contains('BaseEffect'),
              contains('suggested'),
            ),
          ),
        ),
      );
    });
  });
}
