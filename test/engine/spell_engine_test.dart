import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/modifier.dart';

SelectedParameter _sp(String id, String name, String category) => SelectedParameter(
  parameterId: id,
  parameter: Parameter(id: id, name: name, category: category, magnitude: 0, source: 'built-in'),
);

final _range = _sp('range-personal', 'Personal', 'Range');
final _duration = _sp('duration-momentary', 'Momentary', 'Duration');
final _target = _sp('target-individual', 'Individual', 'Target');


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
        range: _range,
        duration: _duration,
        target: _target,
      );

      final errors = engine.validateSpellDraft(draft);
      expect(errors, isEmpty);
    });

    test('fails if a requisite art is the spell\'s own technique or form', () {
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: '1', technique: 'Creo', form: 'Ignem',
          description: 'Create flame', baseLevel: 10, source: 'built-in',
        ),
        range: _range,
        duration: _duration,
        target: _target,
        requisites: [Requisite(art: 'Ignem', kind: RequisiteKind.adding)],
      );

      final errors = engine.validateSpellDraft(draft);
      expect(
        errors,
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('fails if the same requisite art is listed twice', () {
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: '1', technique: 'Creo', form: 'Ignem',
          description: 'Create flame', baseLevel: 10, source: 'built-in',
        ),
        range: _range,
        duration: _duration,
        target: _target,
        requisites: [
          Requisite(art: 'Auram', kind: RequisiteKind.free),
          Requisite(art: 'Auram', kind: RequisiteKind.adding),
        ],
      );

      final errors = engine.validateSpellDraft(draft);
      expect(errors, contains('Duplicate requisite art: Auram'));
    });

    test('passes with several distinct requisites of mixed kinds', () {
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: '1', technique: 'Creo', form: 'Ignem',
          description: 'Create flame', baseLevel: 10, source: 'built-in',
        ),
        range: _range,
        duration: _duration,
        target: _target,
        requisites: [
          Requisite(art: 'Auram', kind: RequisiteKind.free),
          Requisite(art: 'Terram', kind: RequisiteKind.adding),
          Requisite(art: 'Rego', kind: RequisiteKind.adding),
        ],
      );

      final errors = engine.validateSpellDraft(draft);
      expect(errors, isEmpty);
    });

    test('fails when a single-select modifier has more than one option chosen', () {
      final material = Modifier(
        id: 'terram-material',
        name: 'Material difficulty',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
        options: [
          ModifierOption(id: 'mat-stone', label: 'Stone', magnitude: 1),
          ModifierOption(id: 'mat-metal', label: 'Metal', magnitude: 2),
        ],
        source: 'built-in',
      );
      final testEngine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: [material]);
      final draft = SpellDraft(
        technique: 'Rego',
        form: 'Terram',
        baseEffect: BaseEffect(
          id: 'rete-4', technique: 'Rego', form: 'Terram',
          description: 'Transport', baseLevel: 4, source: 'built-in',
        ),
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'terram-material': ['mat-stone', 'mat-metal']},
      );

      expect(testEngine.validateSpellDraft(draft),
          contains('Only one option may be selected for Material difficulty'));
    });

    test('a multi-select modifier with several options chosen is valid', () {
      final complexity = Modifier(
        id: 'crim-complexity',
        name: 'Complexity',
        selectionMode: ModifierSelectionMode.multi,
        scope: const ModifierScope(technique: 'Creo', form: 'Imaginem'),
        options: [
          ModifierOption(id: 'a', label: 'A', magnitude: 1),
          ModifierOption(id: 'b', label: 'B', magnitude: 1),
        ],
        source: 'built-in',
      );
      final testEngine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: [complexity]);
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Imaginem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Imaginem',
          description: 'Image', baseLevel: 2, source: 'built-in',
        ),
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'crim-complexity': ['a', 'b']},
      );

      expect(testEngine.validateSpellDraft(draft), isEmpty);
    });
  });

  group('SpellEngine.pruneModifierSelections', () {
    final material = Modifier(
      id: 'terram-material',
      name: 'Material difficulty',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
      options: [ModifierOption(id: 'mat-metal', label: 'Metal', magnitude: 2)],
      source: 'built-in',
    );
    final distance = Modifier(
      id: 'rego-transport-distance',
      name: 'Transport distance',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(effectIds: ['rete-4']),
      options: [ModifierOption(id: 'dist-500', label: '500 paces', magnitude: 2)],
      source: 'built-in',
    );
    final engine = SpellEngine(
        allSpells: [], allSpecialFactors: [], allModifiers: [material, distance]);

    test('keeps selections whose modifier still applies', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'terram-material': ['mat-metal']},
        technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4',
      );

      expect(pruned, {'terram-material': ['mat-metal']});
    });

    test('drops selections stranded by a Form change', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'terram-material': ['mat-metal']},
        technique: 'Rego', form: 'Ignem', baseEffectId: null,
      );

      expect(pruned, isEmpty);
    });

    test('drops effect-scoped selections stranded by a base effect change', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'rego-transport-distance': ['dist-500']},
        technique: 'Rego', form: 'Terram', baseEffectId: 'rete-1',
      );

      expect(pruned, isEmpty);
    });

    test('drops selections whose modifier no longer exists at all', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'deleted-modifier': ['x']},
        technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4',
      );

      expect(pruned, isEmpty);
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
        range: _range, duration: _duration, target: _target, selectedSpecialFactorIds: [], requisites: [],
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
      final touchSp = SelectedParameter(parameterId: touch.id, parameter: touch);
      final sunSp = SelectedParameter(parameterId: sun.id, parameter: sun);

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: touchSp, duration: sunSp, target: _target, selectedSpecialFactorIds: [],
        requisites: [],
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
        range: _range, duration: _duration, target: _target, selectedSpecialFactorIds: ['sf1'],
        requisites: [],
      );

      expect(level, 3); // Base 2 + factor(+1) = 3 (within additive tier)
    });

    test('treats a dangling special factor id (deleted after the spell was saved) as 0 magnitude instead of throwing', () {
      // No special factors known to the engine at all -- simulates the
      // referenced custom factor having been deleted in Settings after a
      // spell that selected it was saved.
      final engine = SpellEngine(allSpells: [], allSpecialFactors: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Imaginem',
        description: 'Phantasm', baseLevel: 2, source: 'built-in',
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target, selectedSpecialFactorIds: ['deleted-factor-id'],
        requisites: [],
      );

      expect(level, 2); // Base 2 + unresolved factor(+0) = 2, no StateError
    });

    test('an adding requisite contributes +1 magnitude', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Fire with Ignem light', baseLevel: 3, source: 'built-in',
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target, selectedSpecialFactorIds: [],
        requisites: [Requisite(art: 'Auram', kind: RequisiteKind.adding)],
      );

      expect(level, 4); // Base 3 + adding requisite(+1) = 4
    });

    test('a free requisite contributes no magnitude', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Fire with Ignem light', baseLevel: 3, source: 'built-in',
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target, selectedSpecialFactorIds: [],
        requisites: [Requisite(art: 'Auram', kind: RequisiteKind.free)],
      );

      expect(level, 3); // Base 3 + free requisite(+0) = 3
    });

    test('an adding modifier option raises the level by its magnitude', () {
      final material = Modifier(
        id: 'terram-material',
        name: 'Material difficulty',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
        options: [
          ModifierOption(id: 'mat-dirt', label: 'Dirt', magnitude: 0),
          ModifierOption(id: 'mat-metal', label: 'Metal or gemstone', magnitude: 2),
        ],
        source: 'built-in',
      );
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: [material]);
      final baseEffect = BaseEffect(
        id: 'rete-4', technique: 'Rego', form: 'Terram',
        description: 'Transport a non-living object', baseLevel: 4, source: 'built-in',
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedSpecialFactorIds: const [],
        selectedModifiers: const {'terram-material': ['mat-metal']},
        requisites: const [],
      );

      // Base 4 leaves 1 point of additive capacity; the modifier's 2 magnitude
      // takes 1 additively and 1 at x5: 4 + 1 + 5 = 10.
      expect(breakdown.level, 10);
      expect(
        breakdown.contributions.any((c) => c.label.contains('Metal or gemstone') && c.magnitude == 2),
        isTrue,
      );
    });

    test('an unresolvable modifier option contributes 0 and does not throw', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: const []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 3, source: 'built-in',
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedSpecialFactorIds: const [],
        selectedModifiers: const {'deleted-modifier': ['deleted-option']},
        requisites: const [],
      );

      expect(breakdown.level, 3);
    });

    test('the breakdown lists base, parameters, requisites and modifiers', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: const []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 3, source: 'built-in',
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedSpecialFactorIds: const [],
        selectedModifiers: const {},
        requisites: [Requisite(art: 'Auram', kind: RequisiteKind.adding)],
      );

      expect(breakdown.contributions.first.isBase, isTrue);
      expect(breakdown.contributions.first.magnitude, 3);
      expect(breakdown.contributions.any((c) => c.label.startsWith('Range')), isTrue);
      expect(breakdown.contributions.any((c) => c.label.startsWith('Requisite')), isTrue);
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
        range: _range, duration: _duration, target: _target,
        selectedSpecialFactorIds: [],
        requisites: [],
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
