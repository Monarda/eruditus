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

  Spell record() => Spell(
        id: 'spell-1',
        name: 'Phantasm',
        baseEffectId: 'crim-2',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
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
}
