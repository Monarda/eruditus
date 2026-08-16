import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/models/spell_template.dart';
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

  SpellTemplate record() => SpellTemplate(
        id: 'tpl-1',
        name: 'Phantasm',
        baseEffectId: 'crim-2',
        technique: 'Creo',
        form: 'Imaginem',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        description: 'A face on a wall. Level 10.',
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );

  test('a fully resolved template exposes catalog data through delegating getters', () {
    final resolved = ResolvedTemplate(
        record: record(), baseEffect: effect, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isTrue);
    expect(resolved.unresolvedReferences, isEmpty);
    expect(resolved.id, 'tpl-1');
    expect(resolved.name, 'Phantasm');
    expect(resolved.source, PublicationSource.published);
    expect(resolved.description, 'A face on a wall. Level 10.');
    // Stored on the record -- happens to match the base effect here because
    // this fixture isn't an analogy (see SpellTemplate.analogyRationale).
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
  });

  test('a missing base effect makes the template unresolved and names the reference', () {
    final resolved = ResolvedTemplate(
        record: record(), baseEffect: null, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['crim-2']);
    // technique/form are stored on the record, not derived from the base
    // effect, so they survive even when the base effect itself is missing.
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
    // The record survives intact so the template can still be listed.
    expect(resolved.id, 'tpl-1');
    expect(resolved.name, 'Phantasm');
  });

  test('a missing range makes the template unresolved and names the reference', () {
    final resolved = ResolvedTemplate(
        record: record(), baseEffect: effect, range: null, duration: momentary, target: individual);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['range-voice']);
  });

  test('a missing duration makes the template unresolved and names the reference', () {
    final resolved = ResolvedTemplate(
        record: record(), baseEffect: effect, range: voice, duration: null, target: individual);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['duration-momentary']);
  });

  test('a missing target makes the template unresolved and names the reference', () {
    final resolved = ResolvedTemplate(
        record: record(), baseEffect: effect, range: voice, duration: momentary, target: null);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['target-individual']);
  });

  test('every missing reference is reported, in record order, not just the first', () {
    final resolved = ResolvedTemplate(
        record: record(), baseEffect: null, range: null, duration: momentary, target: null);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences,
        ['crim-2', 'range-voice', 'target-individual']);
    expect(resolved.unresolvedReferences, isNot(contains('duration-momentary')));
  });

  test('chosenSlots passes through from the record', () {
    final template = SpellTemplate(
      id: 't-1', name: 'Test Ward', baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      summary: 'Test ward summary',
      chosenSlots: const {'realm': 'Magic'},
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final resolved = ResolvedTemplate(record: template);
    expect(resolved.chosenSlots, {'realm': 'Magic'});
  });

  test('technique/form come from the record even when the base effect disagrees', () {
    // The Vim-analogy shape this plan exists for: a Rego Imaginem template
    // built on a Rego Vim base effect "by analogy".
    final vimEffect = BaseEffect(
      id: 'revi-G2', technique: 'Rego', form: 'Vim',
      description: 'Sustain or suppress a spell', baseLevel: null,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final analogyTemplate = SpellTemplate(
      id: 'tpl-analogy', name: 'Restore the Moved Image',
      baseEffectId: 'revi-G2',
      technique: 'Rego',
      form: 'Imaginem',
      analogyRationale: 'By analogy to Rego Vim\'s sustain-or-suppress guideline.',
      rangeId: 'range-voice', durationId: 'duration-momentary', targetId: 'target-individual',
      description: 'Cancels a ReIm spell that moves an image.',
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );

    final resolved = ResolvedTemplate(
        record: analogyTemplate, baseEffect: vimEffect, range: voice, duration: momentary, target: individual);

    // The template is Rego Imaginem, not Rego Vim -- even though its base
    // effect is a Vim guideline.
    expect(resolved.technique, 'Rego');
    expect(resolved.form, 'Imaginem');
    expect(resolved.baseEffect?.form, 'Vim'); // the borrowed guideline, for contrast
  });
}
