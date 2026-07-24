import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';
import 'package:eruditus/models/requisite.dart';

void main() {
  group('SpellEngine.validateSpellDraft', () {
    final engine = SpellEngine(allSpells: [], allSpecialFactors: []);

    test('fails if technique not selected', () {
      final draft = SpellDraft(
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: '1', technique: 'Creo', form: 'Ignem',
          description: 'test', baseLevel: 10, source: 'built-in',
        ),
      );

      final errors = engine.validateSpellDraft(draft);
      expect(errors, contains('Technique must be selected'));
    });

    test('fails if form not selected', () {
      final draft = SpellDraft(
        technique: 'Creo',
        baseEffect: BaseEffect(
          id: '1', technique: 'Creo', form: 'Ignem',
          description: 'test', baseLevel: 10, source: 'built-in',
        ),
      );

      final errors = engine.validateSpellDraft(draft);
      expect(errors, contains('Form must be selected'));
    });

    test('fails if base effect not selected', () {
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Ignem',
      );

      final errors = engine.validateSpellDraft(draft);
      expect(errors, contains('Base effect must be selected'));
    });

    test('passes for valid draft', () {
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: '1', technique: 'Creo', form: 'Ignem',
          description: 'Create flame', baseLevel: 10, source: 'built-in',
        ),
      );

      final errors = engine.validateSpellDraft(draft);
      expect(errors, isEmpty);
    });
  });

  group('SpellEngine.calculateSpellLevel', () {
    test('computes level from base effect alone (no parameters/factors/requisites)', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 10, source: 'built-in',
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        parameters: [],
        selectedSpecialFactorIds: [],
        additionalRequisites: [],
      );

      expect(level, 10);
    });

    test('includes parameter magnitudes', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Muto', form: 'Corpus',
        description: 'Eyes of the Cat base', baseLevel: 2, source: 'built-in',
      );
      final touch = Parameter(id: 'p1', name: 'Touch', category: 'Range', magnitude: 1, source: 'built-in');
      final sun = Parameter(id: 'p2', name: 'Sun', category: 'Duration', magnitude: 2, source: 'built-in');

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        parameters: [
          SelectedParameter(parameterId: touch.id, parameter: touch),
          SelectedParameter(parameterId: sun.id, parameter: sun),
        ],
        selectedSpecialFactorIds: [],
        additionalRequisites: [],
      );

      expect(level, 5); // Eyes of the Cat: Base 2 + Touch(+1) + Sun(+2) = 5
    });

    test('includes special factor magnitudes resolved by ID', () {
      final complexity = SpecialFactor(
        id: 'sf1', technique: 'Creo', form: 'Imaginem',
        name: 'Increasing Sensory Complexity',
        description: 'moving visual or clear words', magnitude: 1, source: 'built-in',
      );
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [complexity]);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Imaginem',
        description: 'Phantasm', baseLevel: 2, source: 'built-in',
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        parameters: [],
        selectedSpecialFactorIds: ['sf1'],
        additionalRequisites: [],
      );

      expect(level, 3); // Base 2 + factor(+1) = 3 (within additive tier)
    });

    test('includes additional requisite magnitudes', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Fire with Ignem light', baseLevel: 3, source: 'built-in',
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        parameters: [],
        selectedSpecialFactorIds: [],
        additionalRequisites: [AdditionalRequisite(art: 'Ignem')],
      );

      expect(level, 4); // Base 3 + additional requisite(+1) = 4
    });
  });

  group('SpellEngine.findSimilarSpells', () {
    Spell buildSpell(String id, String technique, String form, String name, int baseLevel) {
      return Spell(
        id: id, technique: technique, form: form,
        name: name, baseEffect: BaseEffect(
          id: 'e$id', technique: technique, form: form,
          description: name, baseLevel: baseLevel, source: 'built-in',
        ),
        parameters: [], selectedSpecialFactorIds: [],
        requiredRequisites: [], additionalRequisites: [],
        source: 'built-in', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
    }

    test('returns only spells with matching Technique+Form', () {
      final spell1 = buildSpell('1', 'Creo', 'Ignem', 'Pillar of Fire', 10);
      final spell2 = buildSpell('2', 'Creo', 'Ignem', 'Fireball', 5);
      final spell3 = buildSpell('3', 'Muto', 'Corpus', 'Transform Body', 5);

      final engine = SpellEngine(allSpells: [spell1, spell2, spell3], allSpecialFactors: []);

      final similar = engine.findSimilarSpells('Creo', 'Ignem');

      expect(similar.length, 2);
      expect(similar.map((s) => s.id), containsAll(['1', '2']));
    });

    test('sorts by closeness to referenceLevel when provided', () {
      final spell10 = buildSpell('10', 'Creo', 'Ignem', 'Level 10 spell', 10);
      final spell20 = buildSpell('20', 'Creo', 'Ignem', 'Level 20 spell', 20);
      final spell50 = buildSpell('50', 'Creo', 'Ignem', 'Level 50 spell', 50);

      final engine = SpellEngine(
        allSpells: [spell50, spell10, spell20], // deliberately unsorted input
        allSpecialFactors: [],
      );

      final similar = engine.findSimilarSpells('Creo', 'Ignem', referenceLevel: 22);

      // Closest to 22 is 20 (diff 2), then 10 (diff 12), then 50 (diff 28)
      expect(similar.map((s) => s.id).toList(), ['20', '10', '50']);
    });
  });
}
