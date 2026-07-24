import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/base_effect.dart';

void main() {
  group('Spell Model', () {
    test('Spell.toMap and fromMap round-trip', () {
      final effect = BaseEffect(
        id: '1',
        technique: 'Creo',
        form: 'Ignem',
        description: 'Create flame',
        baseLevel: 10,
        source: 'built-in',
      );

      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: effect,
        parameters: [],
        selectedSpecialFactorIds: [],
        requiredRequisites: [],
        additionalRequisites: [],
        description: 'A test spell',
        source: 'user-created',
        createdAt: DateTime(2026, 7, 24),
        updatedAt: DateTime(2026, 7, 24),
      );

      final map = spell.toMap();
      final restored = Spell.fromMap(map);

      expect(restored.id, spell.id);
      expect(restored.name, spell.name);
      expect(restored.technique, spell.technique);
      expect(restored.form, spell.form);
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

      final draft = SpellDraft(
        technique: 'Muto',
        form: 'Corpus',
        baseEffect: effect,
      );

      final spell = draft.toSpell(name: 'My Spell', source: 'user-created');

      expect(spell.name, 'My Spell');
      expect(spell.source, 'user-created');
      expect(spell.technique, 'Muto');
      expect(spell.form, 'Corpus');
    });
  });
}
