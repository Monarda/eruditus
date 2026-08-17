import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/spell_template.dart';

void main() {
  SpellTemplate build({ContainerMode containerMode = ContainerMode.unstated}) =>
      SpellTemplate(
        id: 'tpl-pevi-demons-eternal-oblivion',
        name: "Demon's Eternal Oblivion",
        baseEffectId: 'pevi-G3',
        technique: 'Perdo',
        form: 'Vim',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        summary: 'Weakens and possibly destroys a creature with Infernal Might.',
        containerMode: containerMode,
        provenance: Provenance(
            source: PublicationSource.published,
            citations: [Citation(bookId: 'arm5-core')]),
      );

  test('round-trips through a map', () {
    final restored = SpellTemplate.fromMap(build().toMap());

    expect(restored.id, 'tpl-pevi-demons-eternal-oblivion');
    expect(restored.baseEffectId, 'pevi-G3');
    expect(restored.technique, 'Perdo');
    expect(restored.form, 'Vim');
    expect(restored.analogyRationale, isNull);
    expect(restored.rangeId, 'range-voice');
  });

  test('carries no level of any kind', () {
    expect(build().toMap().containsKey('chosenBaseLevel'), isFalse);
    expect(build().toMap().containsKey('printedLevel'), isFalse);
  });

  test('chosenSlots defaults to empty and round-trips', () {
    final template = SpellTemplate(
      id: 't-1', name: 'Test Template', baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      summary: 'Test template summary',
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    expect(template.chosenSlots, isEmpty);

    final withSlot = SpellTemplate(
      id: 't-2', name: 'Test Ward', baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      summary: 'Test ward summary',
      chosenSlots: const {'realm': 'Faerie'},
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    expect(SpellTemplate.fromMap(withSlot.toMap()).chosenSlots, {'realm': 'Faerie'});
  });

  group('containerMode', () {
    test('defaults to unstated', () {
      expect(build().containerMode, ContainerMode.unstated);
    });

    test('round-trips through toMap/fromMap', () {
      for (final mode in ContainerMode.values) {
        final restored =
            SpellTemplate.fromMap(build(containerMode: mode).toMap());
        expect(restored.containerMode, mode);
      }
    });

    test('serializes to the rulebook words', () {
      expect(build(containerMode: ContainerMode.static).toMap()['containerMode'],
          'static');
      expect(build(containerMode: ContainerMode.dynamic).toMap()['containerMode'],
          'dynamic');
    });

    test('a record with no containerMode key reads as unstated', () {
      final map = build().toMap()..remove('containerMode');
      expect(SpellTemplate.fromMap(map).containerMode, ContainerMode.unstated);
    });

    test('throws on an unknown stored value rather than defaulting', () {
      final map = build().toMap()..['containerMode'] = 'ongoing';
      expect(() => SpellTemplate.fromMap(map), throwsA(isA<FormatException>()));
    });
  });
}
