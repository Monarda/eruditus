import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/target_type.dart';

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

    test('requiresRitual defaults to false and round-trips when true', () {
      final plain = Parameter(
        id: 'p-1', name: 'Sun', category: 'Duration', magnitude: 2,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(plain.requiresRitual, isFalse);

      final ritual = Parameter(
        id: 'p-2', name: 'Year', category: 'Duration', magnitude: 4,
        requiresRitual: true,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(Parameter.fromMap(ritual.toMap()).requiresRitual, isTrue);
      expect(Parameter.fromMap(plain.toMap()).requiresRitual, isFalse);
    });

    test('fromMap treats an absent requiresRitual key as false', () {
      final restored = Parameter.fromMap({
        'id': 'p-3',
        'name': 'Touch',
        'category': 'Range',
        'magnitude': 1,
        'source': 'published',
        'citations': [
          {'bookId': 'arm5-core'},
        ],
      });
      expect(restored.requiresRitual, isFalse);
    });

    test('requiresVirtue defaults to null and round-trips when set', () {
      final plain = Parameter(
        id: 'p-4', name: 'Touch', category: 'Range', magnitude: 1,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(plain.requiresVirtue, isNull);

      final gated = Parameter(
        id: 'p-5', name: 'Road', category: 'Range', magnitude: 2,
        requiresVirtue: 'Faerie Magic',
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(Parameter.fromMap(gated.toMap()).requiresVirtue, 'Faerie Magic');
      expect(Parameter.fromMap(plain.toMap()).requiresVirtue, isNull);
    });

    test('fromMap treats an absent requiresVirtue key as null', () {
      final restored = Parameter.fromMap({
        'id': 'p-6',
        'name': 'Touch',
        'category': 'Range',
        'magnitude': 1,
        'source': 'published',
        'citations': [
          {'bookId': 'arm5-core'},
        ],
      });
      expect(restored.requiresVirtue, isNull);
    });

    test('scope defaults to unrestricted and round-trips a Form restriction', () {
      final plain = Parameter(
        id: 'p-7', name: 'Voice', category: 'Range', magnitude: 2,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(plain.scope.forms, isEmpty);

      final scoped = Parameter(
        id: 'p-8', name: 'Fire', category: 'Duration', magnitude: 3,
        scope: const ParameterScope(forms: ['Ignem', 'Imaginem']),
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(
        Parameter.fromMap(scoped.toMap()).scope.forms,
        ['Ignem', 'Imaginem'],
      );
    });

    test('fromMap treats an absent scope key as unrestricted', () {
      final restored = Parameter.fromMap({
        'id': 'p-9',
        'name': 'Touch',
        'category': 'Range',
        'magnitude': 1,
        'source': 'published',
        'citations': [
          {'bookId': 'arm5-core'},
        ],
      });
      expect(restored.scope.forms, isEmpty);
    });

    group('targetType', () {
      Map<String, dynamic> base() => {
            'id': 'target-room',
            'name': 'Room',
            'category': 'Target',
            'magnitude': 2,
            'source': 'published',
            'citations': [
              {'bookId': 'arm5-core'}
            ],
          };

      test('parses all three kinds', () {
        for (final kind in TargetType.values) {
          final parameter =
              Parameter.fromMap({...base(), 'targetType': kind.name});
          expect(parameter.targetType, kind);
        }
      });

      test('is null when absent, which is how a Range or Duration row reads', () {
        final parameter = Parameter.fromMap({
          ...base(),
          'id': 'duration-sun',
          'name': 'Sun',
          'category': 'Duration',
        });
        expect(parameter.targetType, isNull);
      });

      test('throws on an unknown kind rather than defaulting', () {
        expect(
          () => Parameter.fromMap({...base(), 'targetType': 'volume'}),
          throwsA(isA<FormatException>()),
        );
      });

      test('round-trips through toMap, and omits the key when null', () {
        final annotated =
            Parameter.fromMap({...base(), 'targetType': 'container'});
        expect(annotated.toMap()['targetType'], 'container');

        final bare = Parameter.fromMap(base());
        expect(bare.toMap().containsKey('targetType'), isFalse);
      });
    });
  });

  group('ParameterScope', () {
    test('an unrestricted scope (default) applies to every Form, including null', () {
      const scope = ParameterScope();
      expect(scope.appliesTo(form: 'Ignem'), isTrue);
      expect(scope.appliesTo(form: 'Terram'), isTrue);
      expect(scope.appliesTo(form: null), isTrue);
    });

    test('a restricted scope applies only to a listed Form', () {
      const scope = ParameterScope(forms: ['Ignem', 'Imaginem']);
      expect(scope.appliesTo(form: 'Ignem'), isTrue);
      expect(scope.appliesTo(form: 'Imaginem'), isTrue);
      expect(scope.appliesTo(form: 'Terram'), isFalse);
      expect(scope.appliesTo(form: null), isFalse);
    });

    test('toMap/fromMap round-trips forms', () {
      const scope = ParameterScope(forms: ['Ignem', 'Imaginem']);
      final restored = ParameterScope.fromMap(scope.toMap());
      expect(restored.forms, ['Ignem', 'Imaginem']);
    });

    test('fromMap treats a null map as unrestricted', () {
      expect(ParameterScope.fromMap(null).forms, isEmpty);
    });
  });
}
