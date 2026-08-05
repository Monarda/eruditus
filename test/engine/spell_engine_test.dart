import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/level_adjustment.dart';

Parameter _sp(String id, String name, String category) => Parameter(
    id: id, name: name, category: category, magnitude: 0,
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

final _range = _sp('range-personal', 'Personal', 'Range');
final _duration = _sp('duration-momentary', 'Momentary', 'Duration');
final _target = _sp('target-individual', 'Individual', 'Target');


void main() {
  group('SpellEngine.validateSpellDraft', () {
    final engine = SpellEngine(allSpells: []);

    test('fails if technique not selected', () {
      final draft = SpellDraft(
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: '1', technique: 'Creo', form: 'Ignem',
          description: 'test', baseLevel: 10,
          provenance: Provenance(source: PublicationSource.userCreated),
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
          description: 'test', baseLevel: 10,
          provenance: Provenance(source: PublicationSource.userCreated),
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
          description: 'Create flame', baseLevel: 10,
          provenance: Provenance(source: PublicationSource.userCreated),
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
          description: 'Create flame', baseLevel: 10,
          provenance: Provenance(source: PublicationSource.userCreated),
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
          description: 'Create flame', baseLevel: 10,
          provenance: Provenance(source: PublicationSource.userCreated),
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
          description: 'Create flame', baseLevel: 10,
          provenance: Provenance(source: PublicationSource.userCreated),
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
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final testEngine = SpellEngine(allSpells: [], allModifiers: [material]);
      final draft = SpellDraft(
        technique: 'Rego',
        form: 'Terram',
        baseEffect: BaseEffect(
          id: 'rete-4', technique: 'Rego', form: 'Terram',
          description: 'Transport', baseLevel: 4,
          provenance: Provenance(source: PublicationSource.userCreated),
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
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final testEngine = SpellEngine(allSpells: [], allModifiers: [complexity]);
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Imaginem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Imaginem',
          description: 'Image', baseLevel: 2,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'crim-complexity': ['a', 'b']},
      );

      expect(testEngine.validateSpellDraft(draft), isEmpty);
    });

    test('reports a draft whose adjustments drive it below level 1', () {
      // Nothing downstream catches SpellLevelCalculator's ArgumentError: the
      // creation bloc's Calculate handler would take it straight out, and its
      // Save handler never calls the calculator at all, so the spell would
      // save and then break the Library tab on the next launch. It has to
      // surface as a validation message instead.
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Ignem',
          description: 'test', baseLevel: 5,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        range: _range, duration: _duration, target: _target,
        adjustments: [
          LevelAdjustment(magnitude: -5, note: 'far too generous a discount'),
        ],
      );

      expect(engine.validateSpellDraft(draft),
          contains('Negative magnitudes reduce this spell below level 1'));
    });

    test('a base-0 guideline draft is valid, because level 0 is a real level', () {
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Vim',
        baseEffect: BaseEffect(
          id: 'crvi-G1', technique: 'Creo', form: 'Vim',
          description: 'Ward against a General guideline', baseLevel: 0,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        range: _range, duration: _duration, target: _target,
      );

      expect(engine.validateSpellDraft(draft), isEmpty);
      expect(
        engine.calculateSpellLevel(
          baseEffect: draft.baseEffect!,
          range: _range, duration: _duration, target: _target,
          requisites: const [],
        ),
        0,
      );
    });
  });

  group('SpellEngine.pruneModifierSelections', () {
    final material = Modifier(
      id: 'terram-material',
      name: 'Material difficulty',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
      options: [ModifierOption(id: 'mat-metal', label: 'Metal', magnitude: 2)],
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
    );
    final distance = Modifier(
      id: 'rego-transport-distance',
      name: 'Transport distance',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(effectIds: ['rete-4']),
      options: [ModifierOption(id: 'dist-500', label: '500 paces', magnitude: 2)],
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
    );
    final engine = SpellEngine(
        allSpells: [], allModifiers: [material, distance]);

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
      final engine = SpellEngine(allSpells: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 10,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target, requisites: [],
      );

      expect(level, 10);
    });

    test('includes parameter magnitudes', () {
      final engine = SpellEngine(allSpells: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Muto', form: 'Corpus',
        description: 'Eyes of the Cat base', baseLevel: 2,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final touch = Parameter(
          id: 'p1', name: 'Touch', category: 'Range', magnitude: 1,
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
      final sun = Parameter(
          id: 'p2', name: 'Sun', category: 'Duration', magnitude: 2,
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: touch, duration: sun, target: _target,
        requisites: [],
      );

      expect(level, 5); // Eyes of the Cat: Base 2 + Touch(+1) + Sun(+2) = 5
    });

    test('an adding requisite contributes +1 magnitude', () {
      final engine = SpellEngine(allSpells: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Fire with Ignem light', baseLevel: 3,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        requisites: [Requisite(art: 'Auram', kind: RequisiteKind.adding)],
      );

      expect(level, 4); // Base 3 + adding requisite(+1) = 4
    });

    test('a free requisite contributes no magnitude', () {
      final engine = SpellEngine(allSpells: []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Fire with Ignem light', baseLevel: 3,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
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
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [material]);
      final baseEffect = BaseEffect(
        id: 'rete-4', technique: 'Rego', form: 'Terram',
        description: 'Transport a non-living object', baseLevel: 4,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
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
      final engine = SpellEngine(allSpells: [], allModifiers: const []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 3,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'deleted-modifier': ['deleted-option']},
        requisites: const [],
      );

      expect(breakdown.level, 3);
    });

    test('the breakdown lists base, parameters, requisites and modifiers', () {
      final engine = SpellEngine(allSpells: [], allModifiers: const []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 3,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
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
    ResolvedSpell buildSpell(String id, String technique, String form, String name, int baseLevel) {
      final effect = BaseEffect(
        id: 'e$id', technique: technique, form: form,
        description: name, baseLevel: baseLevel,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final record = Spell(
        id: id,
        name: name,
        baseEffectId: effect.id,
        rangeId: _range.id,
        durationId: _duration.id,
        targetId: _target.id,
        requisites: [],
        provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      return ResolvedSpell(
        record: record, baseEffect: effect, range: _range, duration: _duration, target: _target);
    }

    test('returns only spells with matching Technique+Form', () {
      final spell1 = buildSpell('1', 'Creo', 'Ignem', 'Pillar of Fire', 10);
      final spell2 = buildSpell('2', 'Creo', 'Ignem', 'Fireball', 5);
      final spell3 = buildSpell('3', 'Muto', 'Corpus', 'Transform Body', 5);

      final engine = SpellEngine(allSpells: [spell1, spell2, spell3]);

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
      );

      final similar = engine.findSimilarSpells('Creo', 'Ignem', referenceLevel: 22);

      // Closest to 22 is 20 (diff 2), then 10 (diff 12), then 50 (diff 28)
      expect(similar.map((s) => s.id).toList(), ['20', '10', '50']);
    });

    test('excludes unresolved spells rather than dereferencing their null catalog fields', () {
      final resolved = buildSpell('1', 'Creo', 'Ignem', 'Pillar of Fire', 10);
      // Unresolved via a null `range` (its rangeId no longer resolves to
      // anything, e.g. the parameter was deleted after this spell was
      // saved) while `baseEffect` stays set — so technique/form (derived
      // from baseEffect) still match the query and this spell would reach
      // the sort comparator if not for the `isResolved &&` guard. The
      // `isResolved &&` guard in findSimilarSpells must filter it out
      // *before* the comparator's `baseEffect!`/`range!`/`duration!`/
      // `target!` derefs ever run on it — otherwise this is a null-check-
      // operator crash reachable from the Create tab's Calculate button.
      final orphanEffect = BaseEffect(
        id: 'e-orphan', technique: 'Creo', form: 'Ignem',
        description: 'Orphan', baseLevel: 10,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final orphan = ResolvedSpell(
        record: Spell(
          id: 'orphan',
          name: 'Orphan',
          baseEffectId: orphanEffect.id,
          rangeId: 'gone',
          durationId: _duration.id,
          targetId: _target.id,
          requisites: const [],
          provenance: Provenance(source: PublicationSource.userCreated),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        baseEffect: orphanEffect,
        range: null,
        duration: _duration,
        target: _target,
      );

      final engine = SpellEngine(allSpells: [resolved, orphan]);

      // referenceLevel forces the sort/comparator path to run.
      final similar = engine.findSimilarSpells('Creo', 'Ignem', referenceLevel: 10);

      expect(similar.any((s) => s.id == 'orphan'), isFalse);
      expect(similar.map((s) => s.id).toList(), ['1']);
    });

    test('drops an uncomputable spell rather than throwing out of the sort', () {
      // Base 5 with a -5 adjustment: five steps down from level 5 lands on 0,
      // which is below both 1 and where it started, so it has no level at
      // all. calculateSpellLevel throws for it — same construction as
      // spell_library_bloc_test.dart's `uncomputableSpell`. Resolved (so it
      // isn't caught by the `isResolved &&` filter already covered above),
      // it must instead be dropped by the comparator's own guard: a spell
      // whose level is unknowable cannot be "similar to level 10".
      final computable = buildSpell('1', 'Creo', 'Ignem', 'Pillar of Fire', 5);
      final uncomputableEffect = BaseEffect(
        id: 'e-uncomputable', technique: 'Creo', form: 'Ignem',
        description: 'Over-Discounted', baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final uncomputable = ResolvedSpell(
        record: Spell(
          id: 'uncomputable',
          name: 'Over-Discounted Spell',
          baseEffectId: uncomputableEffect.id,
          rangeId: _range.id,
          durationId: _duration.id,
          targetId: _target.id,
          requisites: const [],
          adjustments: [LevelAdjustment(magnitude: -5, note: 'far too generous')],
          provenance: Provenance(source: PublicationSource.userCreated),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        baseEffect: uncomputableEffect,
        range: _range,
        duration: _duration,
        target: _target,
      );

      final engine = SpellEngine(allSpells: [computable, uncomputable]);

      // referenceLevel forces the sort/comparator path to run.
      expect(
        () => engine.findSimilarSpells('Creo', 'Ignem', referenceLevel: 10),
        returnsNormally,
      );
      final similar = engine.findSimilarSpells('Creo', 'Ignem', referenceLevel: 10);
      expect(similar.map((s) => s.id).toList(), ['1']);
    });
  });

  group('adjustments', () {
    final baseEffect = BaseEffect(
      id: '1', technique: 'Creo', form: 'Ignem',
      description: 'test', baseLevel: 10,
      provenance: Provenance(source: PublicationSource.userCreated),
    );

    LevelBreakdown breakdownWith(List<LevelAdjustment> adjustments) =>
        SpellEngine(allSpells: const [], allModifiers: const []).calculateBreakdown(
          baseEffect: baseEffect,
          range: _range,
          duration: _duration,
          target: _target,
          selectedModifiers: const {},
          requisites: const [],
          adjustments: adjustments,
        );

    test('each adjustment contributes one labelled breakdown line', () {
      final labels = breakdownWith([
        LevelAdjustment(magnitude: 1, note: 'see through intervening material'),
        LevelAdjustment(magnitude: -1, note: 'because the old limb is needed'),
      ]).contributions.map((c) => c.label).toList();

      expect(labels, contains('Adjustment · see through intervening material'));
      expect(labels, contains('Adjustment · because the old limb is needed'));
    });

    test('a positive adjustment raises the level by 5 above the additive tier', () {
      // baseLevel 10, and _range/_duration/_target are all magnitude 0.
      expect(breakdownWith(const []).level, 10);
      expect(
          breakdownWith([LevelAdjustment(magnitude: 1, note: 'fancy')]).level, 15);
    });

    test('a negative adjustment lowers it by 5', () {
      expect(breakdownWith([LevelAdjustment(magnitude: -1, note: 'old limb')]).level,
          5);
    });

    test('a zero-magnitude adjustment shows a line but changes no level', () {
      final breakdown =
          breakdownWith([LevelAdjustment(magnitude: 0, note: 'cosmetic, free')]);
      expect(breakdown.level, 10);
      expect(breakdown.contributions.map((c) => c.label),
          contains('Adjustment · cosmetic, free'));
    });

    test('calculateSpellLevel agrees with calculateBreakdown on adjustments', () {
      // The two paths answer the same question and must not diverge.
      // calculateSpellLevel used to drop adjustments entirely, so
      // findSimilarSpells sorted *The Shadow of Human Life* as though it were
      // level 15 while its card displayed 40.
      final adjustments = [
        LevelAdjustment(magnitude: 2, note: 'the shadow acts on its own'),
        LevelAdjustment(magnitude: -1, note: 'because the old limb is needed'),
      ];
      final engine = SpellEngine(allSpells: const [], allModifiers: const []);

      final viaLevel = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        requisites: const [],
        adjustments: adjustments,
      );

      expect(viaLevel, breakdownWith(adjustments).level);
      // And that it is the adjusted number, not the unadjusted one: base 10
      // plus a net +1 magnitude above the additive tier.
      expect(viaLevel, 15);
      expect(viaLevel, isNot(breakdownWith(const []).level));
    });

    test('findSimilarSpells sorts by the adjusted level, not the bare one', () {
      // findSimilarSpells is the only caller of calculateSpellLevel, and this
      // is what the dropped parameter actually broke.
      ResolvedSpell spellWith(String id, int baseLevel, List<LevelAdjustment> adj) {
        final effect = BaseEffect(
          id: 'e$id', technique: 'Muto', form: 'Imaginem',
          description: 'test', baseLevel: baseLevel,
          provenance: Provenance(source: PublicationSource.userCreated),
        );
        return ResolvedSpell(
          record: Spell(
            id: id, name: id, baseEffectId: effect.id,
            rangeId: _range.id, durationId: _duration.id, targetId: _target.id,
            requisites: const [], adjustments: adj,
            provenance: Provenance(source: PublicationSource.userCreated),
            createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
          ),
          baseEffect: effect, range: _range, duration: _duration, target: _target,
        );
      }

      final adjusted = spellWith('adjusted', 15,
          [LevelAdjustment(magnitude: 5, note: 'the shadow acts on its own')]);
      final plain = spellWith('plain', 15, const []);
      final engine = SpellEngine(allSpells: [plain, adjusted]);

      final nearForty =
          engine.findSimilarSpells('Muto', 'Imaginem', referenceLevel: 40);

      expect(nearForty.first.id, 'adjusted');
    });
  });
}
