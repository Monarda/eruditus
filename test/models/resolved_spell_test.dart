import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_template.dart';
import 'package:eruditus/models/spell_validation_error.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/text_provenance.dart';

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
    // Stored on the record -- happens to match the base effect here because
    // this fixture isn't an analogy (see Spell.analogyRationale).
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
  });

  test('a missing base effect makes the spell unresolved and names the reference', () {
    final resolved = ResolvedSpell(
        record: record(), baseEffect: null, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['crim-2']);
    // technique/form are stored on the record, not derived from the base
    // effect, so they survive even when the base effect itself is missing.
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
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
    expect(resolved.problems, contains(const GeneralLevelNotChosen()));
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
      summary: 'Wards a circle against the Divine realm.',
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
      summary: 'Wards a circle against beings from one realm.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final resolved = ResolvedSpell(record: spell, baseEffect: effect);
    expect(resolved.problems, contains(const OpenSlotNotChosen([OpenSlotKind.realm])));
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
      summary: 'Wards a circle against beings from the Divine realm.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final resolved = ResolvedSpell(record: spell, baseEffect: effect);
    expect(resolved.problems, isNot(contains(const OpenSlotNotChosen([OpenSlotKind.realm]))));
  });

  test('technique/form come from the record even when the base effect disagrees', () {
    // The Vim-analogy shape this plan exists for: a Rego Imaginem spell
    // built on a Rego Vim base effect "by analogy".
    final vimEffect = BaseEffect(
      id: 'revi-G2', technique: 'Rego', form: 'Vim',
      description: 'Sustain or suppress a spell', baseLevel: null,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final analogySpell = Spell(
      id: 'spell-analogy', name: 'Restore the Moved Image',
      baseEffectId: 'revi-G2',
      technique: 'Rego',
      form: 'Imaginem',
      analogyRationale: 'By analogy to Rego Vim\'s sustain-or-suppress guideline.',
      rangeId: 'range-voice', durationId: 'duration-momentary', targetId: 'target-individual',
      requisites: const {},
      description: 'Cancels a ReIm spell that moves an image.',
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final resolved = ResolvedSpell(
        record: analogySpell, baseEffect: vimEffect, range: voice, duration: momentary, target: individual);

    // The spell is Rego Imaginem, not Rego Vim -- even though its base
    // effect is a Vim guideline.
    expect(resolved.technique, 'Rego');
    expect(resolved.form, 'Imaginem');
    expect(resolved.baseEffect?.form, 'Vim'); // the borrowed guideline, for contrast
  });

  group('sourcedSummary/sourcedDescription (finding F1: template-seeded prose)', () {
    final template = SpellTemplate(
      id: 'tpl-1',
      name: 'Faerie Chains',
      baseEffectId: 'crvi-1',
      technique: 'Creo',
      form: 'Vim',
      rangeId: 'range-touch',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      summary: 'The book\'s own summary.',
      description: 'The book\'s own description.',
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-hohmc', page: 99)],
      ),
    );

    Spell templateSeededSpell({String? summary, String? description, String? templateId = 'tpl-1'}) =>
        Spell(
          id: 'spell-from-template',
          name: 'My Familiar Bond',
          baseEffectId: 'crvi-1',
          technique: 'Creo',
          form: 'Vim',
          rangeId: 'range-touch',
          durationId: 'duration-momentary',
          targetId: 'target-individual',
          requisites: const {},
          summary: summary,
          description: description,
          templateId: templateId,
          provenance: Provenance(source: PublicationSource.userCreated),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

    test('unedited template-seeded prose is verbatim, cited to the template', () {
      final resolved = ResolvedSpell(
        record: templateSeededSpell(
          summary: 'The book\'s own summary.',
          description: 'The book\'s own description.',
        ),
        sourceTemplate: template,
      );

      expect(resolved.sourcedSummary?.provenance, TextProvenance.verbatim);
      expect(resolved.sourcedSummary?.citations, template.provenance.citations,
          reason: 'a user-created spell has no citations of its own -- the '
              'quote must be cited to the template it came from');
      expect(resolved.sourcedDescription?.provenance, TextProvenance.verbatim);
      expect(resolved.sourcedDescription?.citations, template.provenance.citations);
    });

    test('editing the summary flips it to authored, independent of the description', () {
      final resolved = ResolvedSpell(
        record: templateSeededSpell(
          summary: 'My own rewording of the summary.',
          description: 'The book\'s own description.',
        ),
        sourceTemplate: template,
      );

      expect(resolved.sourcedSummary?.provenance, TextProvenance.authored);
      expect(resolved.sourcedSummary?.citations, isEmpty);
      expect(resolved.sourcedDescription?.provenance, TextProvenance.verbatim,
          reason: 'the description was not touched and still matches the template');
    });

    test('no templateId (an ordinary user-created spell) is authored, as before', () {
      final resolved = ResolvedSpell(
        record: templateSeededSpell(
          summary: 'My own spell idea.',
          description: 'My own longer description.',
          templateId: null,
        ),
      );

      expect(resolved.sourcedSummary?.provenance, TextProvenance.authored);
      expect(resolved.sourcedDescription?.provenance, TextProvenance.authored);
    });

    test('a templateId that does not resolve (deleted/stale) degrades to authored, not a crash', () {
      final resolved = ResolvedSpell(
        record: templateSeededSpell(
          summary: 'The book\'s own summary.',
          description: 'The book\'s own description.',
          templateId: 'tpl-does-not-exist',
        ),
        sourceTemplate: null,
      );

      expect(resolved.sourcedSummary?.provenance, TextProvenance.authored);
      expect(resolved.sourcedDescription?.provenance, TextProvenance.authored);
    });

    test('a published spell (no template origin) is unaffected: verbatim with its own citations', () {
      final resolved = ResolvedSpell(record: record());

      expect(resolved.sourcedDescription?.provenance, TextProvenance.verbatim);
      expect(resolved.sourcedDescription?.citations, record().provenance.citations);
    });
  });
}
