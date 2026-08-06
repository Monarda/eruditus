import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/spell_template.dart';

void main() {
  SpellTemplate build() => SpellTemplate(
        id: 'tpl-pevi-demons-eternal-oblivion',
        name: "Demon's Eternal Oblivion",
        baseEffectId: 'pevi-G3',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        summary: 'Weakens and possibly destroys a creature with Infernal Might.',
        provenance: Provenance(
            source: PublicationSource.published,
            citations: [Citation(bookId: 'arm5-core')]),
      );

  test('round-trips through a map', () {
    final restored = SpellTemplate.fromMap(build().toMap());

    expect(restored.id, 'tpl-pevi-demons-eternal-oblivion');
    expect(restored.baseEffectId, 'pevi-G3');
    expect(restored.rangeId, 'range-voice');
  });

  test('carries no level of any kind', () {
    expect(build().toMap().containsKey('chosenBaseLevel'), isFalse);
    expect(build().toMap().containsKey('printedLevel'), isFalse);
  });
}
