import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/presentation/widgets/spell_card.dart';

void main() {
  Spell buildSpell({String? name, String source = 'built-in', String? description}) => Spell(
        id: '1',
        name: name,
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Ignem',
          description: 'test', baseLevel: 10, source: 'built-in',
        ),
        parameters: const [],
        selectedSpecialFactorIds: const [],
        requiredRequisites: const [],
        additionalRequisites: const [],
        description: description,
        source: source,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  testWidgets('shows spell name, technique+form, level, and Built-in badge', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(spell: buildSpell(name: 'Pillar of Fire'), level: 25)),
    ));

    expect(find.text('Pillar of Fire'), findsOneWidget);
    expect(find.textContaining('Creo Ignem'), findsOneWidget);
    expect(find.textContaining('Level 25'), findsOneWidget);
    expect(find.text('Built-in'), findsOneWidget);
  });

  testWidgets('shows "My Spell" badge for user-created spells', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(spell: buildSpell(name: 'My Fireball', source: 'user-created')),
      ),
    ));

    expect(find.text('My Spell'), findsOneWidget);
  });

  testWidgets('falls back to "Untitled Technique Form" when name is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(spell: buildSpell(name: null))),
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
      home: Scaffold(body: SpellCard(spell: buildSpell(name: 'Pillar of Fire'), level: 25)),
    ));

    // Only the title Text should match; no stray empty description widget.
    expect(find.text(''), findsNothing);
  });

  testWidgets('tapping the card invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(spell: buildSpell(name: 'Test'), onTap: () => tapped = true),
      ),
    ));

    await tester.tap(find.byType(SpellCard));
    expect(tapped, isTrue);
  });
}
