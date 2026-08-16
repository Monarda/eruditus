import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  final effect = BaseEffect(
      id: 'crim-2', technique: 'Creo', form: 'Imaginem',
      description: 'Create an image that affects two senses', baseLevel: 2,
      provenance: Provenance(source: PublicationSource.userCreated));
  final voice = Parameter(
      id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final momentary = Parameter(
      id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final individual = Parameter(
      id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

  // Test helpers for the problems getter tests
  final testRange = Parameter(
      id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final testDuration = Parameter(
      id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final testTarget = Parameter(
      id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

  BaseEffect fixedEffect() => BaseEffect(
        id: 'crig-10a', technique: 'Creo', form: 'Ignem',
        description: 'A fire doing +10 damage', baseLevel: 10,
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );

  BaseEffect generalEffect() => BaseEffect(
        id: 'revi-G1', technique: 'Rego', form: 'Vim',
        description: 'Ward against beings of one realm', baseLevel: null,
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );

  Spell buildSpell({String? baseEffectId}) => Spell(
        id: 'spell-1',
        name: 'Phantasm',
        baseEffectId: baseEffectId ?? 'crig-10a',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const {},
        description: 'A face on a wall. Level 10.',
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Spell record() => Spell(
        id: 'spell-1',
        name: 'Phantasm',
        baseEffectId: 'crim-2',
        technique: 'Creo',
        form: 'Imaginem',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const {},
        description: 'A face on a wall. Level 10.',
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('a fully resolved spell exposes catalog data through delegating getters', () {
    final resolved = ResolvedSpell(
        record: record(), baseEffect: effect, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isTrue);
    expect(resolved.unresolvedReferences, isEmpty);
    expect(resolved.id, 'spell-1');
    expect(resolved.name, 'Phantasm');
    expect(resolved.source, PublicationSource.published);
    expect(resolved.description, 'A face on a wall. Level 10.');
    // Derived from the base effect, never stored separately, so they cannot
    // disagree with it.
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
  });

  test('a missing base effect makes the spell unresolved and names the reference', () {
    final resolved = ResolvedSpell(
        record: record(), baseEffect: null, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['crim-2']);
    expect(resolved.technique, isNull);
    expect(resolved.form, isNull);
    // The record survives intact so the spell can still be listed and re-saved.
    expect(resolved.id, 'spell-1');
    expect(resolved.name, 'Phantasm');
  });

  test('every missing reference is reported, not just the first', () {
    final resolved = ResolvedSpell(
        record: record(), baseEffect: null, range: null, duration: momentary, target: null);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences,
        containsAll(['crim-2', 'range-voice', 'target-individual']));
    expect(resolved.unresolvedReferences, isNot(contains('duration-momentary')));
  });

  test('problems is empty for a valid spell', () {
    final resolved = ResolvedSpell(
      record: buildSpell(),
      baseEffect: fixedEffect(),
      range: testRange, duration: testDuration, target: testTarget,
    );
    expect(resolved.problems, isEmpty);
  });

  test('problems reports a General spell with no chosen level', () {
    final resolved = ResolvedSpell(
      record: buildSpell(baseEffectId: 'revi-G1'),
      baseEffect: generalEffect(),
      range: testRange, duration: testDuration, target: testTarget,
    );
    expect(resolved.problems, contains('Choose a level for this General guideline'));
  });

  test('problems is empty when the base effect does not resolve', () {
    // Nothing to validate against. isResolved already reports this, and it
    // answers a different question -- see the class doc.
    final resolved = ResolvedSpell(
      record: buildSpell(),
      baseEffect: null,
      range: testRange, duration: testDuration, target: testTarget,
    );
    expect(resolved.isResolved, isFalse);
    expect(resolved.problems, isEmpty);
  });

  test('chosenSlots passes through from the record', () {
    final spell = Spell(
      id: 's-1', baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      requisites: const {},
      chosenSlots: const {'realm': 'Divine'},
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final resolved = ResolvedSpell(record: spell);
    expect(resolved.chosenSlots, {'realm': 'Divine'});
  });

  test('problems reports check 6 when the resolved base effect declares an unfilled open slot', () {
    final effect = BaseEffect(
      id: 'revi-G1', technique: 'Rego', form: 'Vim',
      description: 'Ward against beings from one realm', baseLevel: null,
      openSlots: const [OpenSlotKind.realm],
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final spell = Spell(
      id: 's-2', baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      requisites: const {},
      chosenBaseLevel: 20,
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final resolved = ResolvedSpell(record: spell, baseEffect: effect);
    expect(resolved.problems, contains('Choose a realm for this guideline'));
  });

  test('problems does not report check 6 when chosenSlots is actually wired through', () {
    final effect = BaseEffect(
      id: 'revi-G1', technique: 'Rego', form: 'Vim',
      description: 'Ward against beings from one realm', baseLevel: null,
      openSlots: const [OpenSlotKind.realm],
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final spell = Spell(
      id: 's-3', baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      requisites: const {},
      chosenBaseLevel: 20,
      chosenSlots: const {'realm': 'Divine'},
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final resolved = ResolvedSpell(record: spell, baseEffect: effect);
    expect(resolved.problems, isNot(contains('Choose a realm for this guideline')));
  });
}
