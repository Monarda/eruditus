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
        range: SelectedParameter(parameterId: voiceParam.id, parameter: voiceParam),
        duration: SelectedParameter(parameterId: sunParam.id, parameter: sunParam),
        target: SelectedParameter(parameterId: individualParam.id, parameter: individualParam),
        selectedSpecialFactorIds: ['sf-1', 'sf-2'],
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

      expect(restored.range.parameterId, voiceParam.id);
      expect(restored.range.parameter.name, voiceParam.name);
      expect(restored.range.parameter.category, voiceParam.category);
      expect(restored.range.parameter.magnitude, voiceParam.magnitude);
      expect(restored.range.parameter.source, voiceParam.source);

      expect(restored.duration.parameterId, sunParam.id);
      expect(restored.duration.parameter.name, sunParam.name);
      expect(restored.duration.parameter.category, sunParam.category);
      expect(restored.duration.parameter.magnitude, sunParam.magnitude);

      expect(restored.target.parameterId, individualParam.id);
      expect(restored.target.parameter.name, individualParam.name);
      expect(restored.target.parameter.category, individualParam.category);

      expect(restored.selectedSpecialFactorIds, ['sf-1', 'sf-2']);

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
          'parameterId': 'p1',
          'parameter': {
            'id': 'p1',
            'name': 'Momentary',
            'category': 'Duration',
            'magnitude': 0,
            'source': 'built-in',
          },
        },
        'target': {
          'parameterId': 'p2',
          'parameter': {
            'id': 'p2',
            'name': 'Individual',
            'category': 'Target',
            'magnitude': 10,
            'source': 'built-in',
          },
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
      final range = SelectedParameter(
        parameterId: 'range-personal',
        parameter: Parameter(id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0, source: 'built-in'),
      );
      final duration = SelectedParameter(
        parameterId: 'duration-momentary',
        parameter: Parameter(id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in'),
      );
      final target = SelectedParameter(
        parameterId: 'target-individual',
        parameter: Parameter(id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 10, source: 'built-in'),
      );

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
  });
}
