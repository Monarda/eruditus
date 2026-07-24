import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/spell.dart';

void main() {
  test('SpellDraft.copyWith preserves id and unspecified fields, overrides given ones', () {
    final effect = BaseEffect(
      id: '1', technique: 'Creo', form: 'Ignem',
      description: 'Create flame', baseLevel: 10, source: 'built-in',
    );
    final draft = SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: effect);

    final updated = draft.copyWith(form: 'Corpus');

    expect(updated.id, draft.id);
    expect(updated.technique, 'Creo');
    expect(updated.form, 'Corpus');
    expect(updated.baseEffect, effect);
  });
}
