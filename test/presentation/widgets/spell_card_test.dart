import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/presentation/widgets/spell_card.dart';

void main() {
  final rangeParam = Parameter(id: 'p1', name: 'Voice', category: 'Range', magnitude: 0, source: 'published');
  final durationParam = Parameter(id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'published');
  final targetParam = Parameter(id: 'p3', name: 'Individual', category: 'Target', magnitude: 0, source: 'published');
  final effect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'test', baseLevel: 10, source: 'published',
  );
  final personalParam =
      Parameter(id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0, source: 'published');
  final momentaryParam =
      Parameter(id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'published');
  final individualParam =
      Parameter(id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0, source: 'published');

  ResolvedSpell buildSpell({
    String? name,
    PublicationSource source = PublicationSource.published,
    String? summary,
    String? description,
  }) {
    final record = Spell(
      id: '1',
      name: name,
      baseEffectId: effect.id,
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const [],
      summary: summary,
      description: description,
      provenance: Provenance(
        source: source,
        citations: source == PublicationSource.published ? const [Citation(bookId: 'arm5-core')] : const [],
      ),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    return ResolvedSpell(
        record: record, baseEffect: effect, range: rangeParam, duration: durationParam, target: targetParam);
  }

  testWidgets('shows spell name, technique+form, level, and Published badge', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(
          spell: buildSpell(name: 'Pillar of Fire', summary: 'Test summary.'),
          level: 25,
        ),
      ),
    ));

    expect(find.text('Pillar of Fire'), findsOneWidget);
    expect(find.textContaining('Creo Ignem'), findsOneWidget);
    expect(find.textContaining('Level 25'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
  });

  testWidgets('shows "My Spell" badge for user-created spells', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(spell: buildSpell(name: 'My Fireball', source: PublicationSource.userCreated)),
      ),
    ));

    expect(find.text('My Spell'), findsOneWidget);
  });

  testWidgets('falls back to "Untitled Technique Form" when name is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(spell: buildSpell(name: null, summary: 'Test summary.'))),
    ));

    expect(find.text('Untitled Creo Ignem'), findsOneWidget);
  });

  testWidgets('shows the spell description when present', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(
          spell: buildSpell(name: 'Pillar of Fire', description: 'A wall of roaring flame.'),
          level: 25,
        ),
      ),
    ));

    expect(find.text('A wall of roaring flame.'), findsOneWidget);
  });

  testWidgets('renders no description text when description is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(
          spell: buildSpell(name: 'Pillar of Fire', source: PublicationSource.userCreated),
          level: 25,
        ),
      ),
    ));

    // Only the title Text should match; no stray empty description widget.
    expect(find.text(''), findsNothing);
  });

  testWidgets('tapping the card invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(
          spell: buildSpell(name: 'Test', source: PublicationSource.userCreated),
          onTap: () => tapped = true,
        ),
      ),
    ));

    await tester.tap(find.byType(SpellCard));
    expect(tapped, isTrue);
  });

  testWidgets('an unresolved spell is shown as unavailable with no level', (tester) async {
    final record = Spell(
      id: 'orphan',
      name: 'Orphaned Spell',
      baseEffectId: 'deleted-custom-effect',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    // Base effect missing, parameters present — exactly what a deleted custom
    // effect leaves behind.
    final unresolved = ResolvedSpell(
      record: record,
      baseEffect: null,
      range: personalParam,
      duration: momentaryParam,
      target: individualParam,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(spell: unresolved)),
    ));

    expect(find.byKey(const Key('spell-card-unresolved')), findsOneWidget);
    expect(find.text('Orphaned Spell'), findsOneWidget);
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(find.textContaining('deleted-custom-effect'), findsOneWidget);
    expect(find.textContaining('Level'), findsNothing);
  });
}
