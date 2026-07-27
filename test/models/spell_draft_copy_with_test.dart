import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart';

void main() {
  test('SpellDraft.copyWith preserves id and unspecified fields, overrides given ones', () {
    final effect = BaseEffect(
      id: '1', technique: 'Creo', form: 'Ignem',
      description: 'Create flame', baseLevel: 10,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    final draft = SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: effect);

    final updated = draft.copyWith(form: 'Corpus');

    expect(updated.id, draft.id);
    expect(updated.technique, 'Creo');
    expect(updated.form, 'Corpus');
    expect(updated.baseEffect, effect);
  });

  test('SpellDraft.copyWith(baseEffect: null) explicitly clears baseEffect to null', () {
    final effect = BaseEffect(
      id: '1', technique: 'Creo', form: 'Ignem',
      description: 'Create flame', baseLevel: 10,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    final draft = SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: effect);

    final updated = draft.copyWith(baseEffect: null);

    expect(updated.baseEffect, isNull);
  });

  test('SpellDraft.copyWith() with no baseEffect argument preserves the existing baseEffect', () {
    final effect = BaseEffect(
      id: '1', technique: 'Creo', form: 'Ignem',
      description: 'Create flame', baseLevel: 10,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    final draft = SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: effect);

    final updated = draft.copyWith(form: 'Corpus');

    expect(updated.baseEffect, effect);
  });

  test('copyWith replaces ritualDeclaration and preserves it when omitted', () {
    final draft = SpellDraft(ritualDeclaration: RitualDeclaration.lastingCreation);

    expect(
      draft.copyWith(ritualDeclaration: RitualDeclaration.none).ritualDeclaration,
      RitualDeclaration.none,
    );
    expect(draft.copyWith(technique: 'Creo').ritualDeclaration,
        RitualDeclaration.lastingCreation);
  });
}
