import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';

void main() {
  group('Spell Model', () {
    test('Spell.toMap and fromMap round-trip preserves every field', () {
      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        baseEffectId: '1',
        rangeId: 'param-voice',
        durationId: 'param-sun',
        targetId: 'param-individual',
        requisites: [
          Requisite(art: 'Vim', kind: RequisiteKind.free),
          Requisite(art: 'Mentem', kind: RequisiteKind.free),
          Requisite(art: 'Auram', kind: RequisiteKind.adding),
          Requisite(art: 'Terram', kind: RequisiteKind.adding),
        ],
        description: 'A test spell',
        source: 'user-created',
        createdAt: DateTime(2026, 7, 24, 12, 30),
        updatedAt: DateTime(2026, 7, 25, 8, 15),
      );

      final map = spell.toMap();
      final restored = Spell.fromMap(map);

      expect(restored.id, spell.id);
      expect(restored.name, spell.name);
      expect(restored.baseEffectId, spell.baseEffectId);
      expect(restored.rangeId, spell.rangeId);
      expect(restored.durationId, spell.durationId);
      expect(restored.targetId, spell.targetId);
      expect(restored.description, spell.description);
      expect(restored.source, spell.source);
      expect(restored.createdAt, spell.createdAt);
      expect(restored.updatedAt, spell.updatedAt);

      expect(restored.requisites.length, 4);
      expect(restored.requisites[0].art, 'Vim');
      expect(restored.requisites[0].kind, RequisiteKind.free);
      expect(restored.requisites[0].magnitude, 0);
      expect(restored.requisites[1].art, 'Mentem');
      expect(restored.requisites[1].kind, RequisiteKind.free);
      expect(restored.requisites[2].art, 'Auram');
      expect(restored.requisites[2].kind, RequisiteKind.adding);
      expect(restored.requisites[2].magnitude, 1);
      expect(restored.requisites[3].art, 'Terram');
      expect(restored.requisites[3].kind, RequisiteKind.adding);
    });

    test('fromMap throws a clear FormatException when a required field is missing', () {
      final map = {
        'id': 'spell-1',
        // 'rangeId' missing
        'baseEffectId': '1',
        'durationId': 'p1',
        'targetId': 'p2',
        'source': 'user-created',
        'createdAt': DateTime(2026, 7, 24).toIso8601String(),
        'updatedAt': DateTime(2026, 7, 24).toIso8601String(),
      };

      expect(
        () => Spell.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('rangeId'), contains('Spell')),
          ),
        ),
      );
    });

    test('SpellDraft.toSpell creates Spell with current timestamp', () {
      final effect = BaseEffect(
        id: '1',
        technique: 'Muto',
        form: 'Corpus',
        description: 'Transform body',
        baseLevel: 5,
        source: 'built-in',
      );
      final range = Parameter(id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0, source: 'built-in');
      final duration = Parameter(id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in');
      final target = Parameter(id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 10, source: 'built-in');

      final draft = SpellDraft(
        technique: 'Muto',
        form: 'Corpus',
        baseEffect: effect,
        range: range,
        duration: duration,
        target: target,
      );

      final spell = draft.toSpell(name: 'My Spell', source: 'user-created');

      expect(spell.name, 'My Spell');
      expect(spell.source, 'user-created');
      expect(spell.baseEffectId, effect.id);
      expect(spell.rangeId, range.id);
      expect(spell.durationId, duration.id);
      expect(spell.targetId, target.id);
    });

    test('SpellDraft.toSpell throws StateError when range is not set', () {
      final draft = SpellDraft(
        technique: 'Muto',
        form: 'Corpus',
        baseEffect: BaseEffect(
          id: '1',
          technique: 'Muto',
          form: 'Corpus',
          description: 'Transform body',
          baseLevel: 5,
          source: 'built-in',
        ),
        duration: Parameter(id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in'),
        target: Parameter(id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 10, source: 'built-in'),
      );

      expect(
        () => draft.toSpell(name: 'My Spell', source: 'user-created'),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('range')),
        ),
      );
    });

    test('SpellDraft.toSpell throws StateError when baseEffect is not set', () {
      final draft = SpellDraft(
        technique: 'Muto',
        form: 'Corpus',
      );

      expect(
        () => draft.toSpell(name: 'My Spell', source: 'user-created'),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('baseEffect')),
        ),
      );
    });

    test('SpellDraft.toSpell throws StateError naming all missing fields', () {
      final draft = SpellDraft();

      expect(
        () => draft.toSpell(name: 'My Spell', source: 'user-created'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('baseEffect'), contains('range'), contains('duration'), contains('target')),
          ),
        ),
      );
    });

    test('selectedModifiers survives a toMap/fromMap round-trip', () {
      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        baseEffectId: 'rete-4',
        rangeId: 'p1',
        durationId: 'p2',
        targetId: 'p3',
        selectedModifiers: const {
          'terram-material': ['mat-metal'],
          'rego-transport-distance': ['dist-500-paces'],
        },
        requisites: const [],
        source: 'user-created',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = Spell.fromMap(spell.toMap());

      expect(restored.selectedModifiers['terram-material'], ['mat-metal']);
      expect(restored.selectedModifiers['rego-transport-distance'], ['dist-500-paces']);
    });

    test('fromMap defaults selectedModifiers to an empty map when absent', () {
      final map = Spell(
        id: 'spell-2',
        baseEffectId: 'e1',
        rangeId: 'p1',
        durationId: 'p2',
        targetId: 'p3',
        requisites: const [],
        source: 'built-in',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ).toMap();
      map.remove('selectedModifiers');

      expect(Spell.fromMap(map).selectedModifiers, isEmpty);
    });

    test('SpellDraft.copyWith replaces selectedModifiers wholesale', () {
      final draft = SpellDraft(
        technique: 'Rego',
        form: 'Terram',
        selectedModifiers: const {'terram-material': ['mat-stone']},
      );

      final updated = draft.copyWith(selectedModifiers: const {'terram-material': ['mat-metal']});

      expect(updated.selectedModifiers['terram-material'], ['mat-metal']);
      expect(draft.selectedModifiers['terram-material'], ['mat-stone'], reason: 'original unchanged');
    });
  });
}
