import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';

void main() {
  group('Spell Model', () {
    test('Spell.toMap and fromMap round-trip preserves every field, including nested objects', () {
      final effect = BaseEffect(
        id: '1',
        technique: 'Creo',
        form: 'Ignem',
        description: 'Create flame',
        baseLevel: 10,
        source: 'built-in',
      );

      final voiceParam = Parameter(
        id: 'param-voice',
        name: 'Voice',
        category: 'Range',
        magnitude: 2,
        source: 'built-in',
      );
      final sunParam = Parameter(
        id: 'param-sun',
        name: 'Sun',
        category: 'Duration',
        magnitude: 3,
        source: 'built-in',
      );
      final individualParam = Parameter(
        id: 'param-individual',
        name: 'Individual',
        category: 'Target',
        magnitude: 10,
        source: 'built-in',
      );

      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: effect,
        range: voiceParam,
        duration: sunParam,
        target: individualParam,
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
      expect(restored.technique, spell.technique);
      expect(restored.form, spell.form);
      expect(restored.description, spell.description);
      expect(restored.source, spell.source);
      expect(restored.createdAt, spell.createdAt);
      expect(restored.updatedAt, spell.updatedAt);

      expect(restored.baseEffect.id, effect.id);
      expect(restored.baseEffect.technique, effect.technique);
      expect(restored.baseEffect.form, effect.form);
      expect(restored.baseEffect.description, effect.description);
      expect(restored.baseEffect.baseLevel, effect.baseLevel);
      expect(restored.baseEffect.source, effect.source);

      expect(restored.range.id, voiceParam.id);
      expect(restored.range.name, voiceParam.name);
      expect(restored.range.category, voiceParam.category);
      expect(restored.range.magnitude, voiceParam.magnitude);
      expect(restored.range.source, voiceParam.source);

      expect(restored.duration.id, sunParam.id);
      expect(restored.duration.name, sunParam.name);
      expect(restored.duration.category, sunParam.category);
      expect(restored.duration.magnitude, sunParam.magnitude);

      expect(restored.target.id, individualParam.id);
      expect(restored.target.name, individualParam.name);
      expect(restored.target.category, individualParam.category);

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
        // 'range' missing
        'technique': 'Creo',
        'form': 'Ignem',
        'baseEffect': {
          'id': '1',
          'technique': 'Creo',
          'form': 'Ignem',
          'description': 'Create flame',
          'baseLevel': 10,
          'source': 'built-in',
        },
        'duration': {
          'id': 'p1',
          'name': 'Momentary',
          'category': 'Duration',
          'magnitude': 0,
          'source': 'built-in',
        },
        'target': {
          'id': 'p2',
          'name': 'Individual',
          'category': 'Target',
          'magnitude': 10,
          'source': 'built-in',
        },
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
            allOf(contains('range'), contains('Spell')),
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
      expect(spell.technique, 'Muto');
      expect(spell.form, 'Corpus');
    });

    test('SpellDraft.toSpell throws StateError when technique is not set', () {
      final draft = SpellDraft(
        form: 'Corpus',
        baseEffect: BaseEffect(
          id: '1',
          technique: 'Muto',
          form: 'Corpus',
          description: 'Transform body',
          baseLevel: 5,
          source: 'built-in',
        ),
      );

      expect(
        () => draft.toSpell(name: 'My Spell', source: 'user-created'),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('technique')),
        ),
      );
    });

    test('SpellDraft.toSpell throws StateError when form is not set', () {
      final draft = SpellDraft(
        technique: 'Muto',
        baseEffect: BaseEffect(
          id: '1',
          technique: 'Muto',
          form: 'Corpus',
          description: 'Transform body',
          baseLevel: 5,
          source: 'built-in',
        ),
      );

      expect(
        () => draft.toSpell(name: 'My Spell', source: 'user-created'),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('form')),
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
            allOf(contains('technique'), contains('form'), contains('baseEffect')),
          ),
        ),
      );
    });

    test('selectedModifiers survives a toMap/fromMap round-trip', () {
      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        technique: 'Rego',
        form: 'Terram',
        baseEffect: BaseEffect(
          id: 'rete-4', technique: 'Rego', form: 'Terram',
          description: 'Transport a non-living object', baseLevel: 4, source: 'built-in',
        ),
        range: Parameter(id: 'p1', name: 'Voice', category: 'Range', magnitude: 2, source: 'built-in'),
        duration: Parameter(id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in'),
        target: Parameter(id: 'p3', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in'),
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
        id: 'spell-2', technique: 'Creo', form: 'Ignem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Ignem',
          description: 'Create flame', baseLevel: 10, source: 'built-in',
        ),
        range: Parameter(id: 'p1', name: 'Personal', category: 'Range', magnitude: 0, source: 'built-in'),
        duration: Parameter(id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in'),
        target: Parameter(id: 'p3', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in'),
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

    test('spell parameter fields are plain Parameters, not wrappers', () {
      final voice = Parameter(
        id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2, source: 'built-in');
      final momentary = Parameter(
        id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in');
      final individual = Parameter(
        id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in');

      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Ignem',
          description: 'Create flame', baseLevel: 10, source: 'built-in'),
        range: voice,
        duration: momentary,
        target: individual,
        requisites: const [],
        source: 'user-created',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = Spell.fromMap(spell.toMap());

      expect(restored.range.id, 'range-voice');
      expect(restored.range.magnitude, 2);
      expect(restored.duration.id, 'duration-momentary');
      expect(restored.target.id, 'target-individual');
    });
  });
}
