import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/presentation/widgets/ritual_section.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets(
      'shows the declaration control even for an ordinary spell, hides the banner',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: false,
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    expect(find.byKey(const Key('ritual-banner')), findsNothing);
    expect(find.byKey(const Key('ritual-radio-none')), findsOneWidget);
    expect(find.byKey(const Key('ritual-radio-lastingCreation')), findsNothing);
    expect(find.byKey(const Key('ritual-radio-storyguideRuling')), findsOneWidget);
  });

  testWidgets(
      'shows the "creates something lasting" option only when the draft is Creo + Momentary',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    expect(find.byKey(const Key('ritual-radio-lastingCreation')), findsOneWidget);
  });

  testWidgets('names every reason in the banner', (tester) async {
    // Aegis of the Hearth: Year duration and Boundary target.
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([
        RitualReason.ritualOnlyDuration,
        RitualReason.ritualOnlyTarget,
      ]),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: false,
      durationName: 'Year',
      targetName: 'Boundary',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final banner = tester.widget<Text>(find
        .descendant(
            of: find.byKey(const Key('ritual-banner')), matching: find.byType(Text))
        .first);
    expect(banner.data, contains('Year duration'));
    expect(banner.data, contains('Boundary target'));
  });

  testWidgets('explains the healing case when the guideline is suggested',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([RitualReason.lastingCreation]),
      declaration: RitualDeclaration.lastingCreation,
      showLastingCreationOption: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: true,
      onDeclarationChanged: (_) {},
    )));

    expect(find.textContaining('suspends'), findsOneWidget);
  });

  testWidgets('selecting "creates something lasting" reports lastingCreation',
      (tester) async {
    final reported = <RitualDeclaration>[];

    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-radio-lastingCreation')));
    expect(reported, [RitualDeclaration.lastingCreation]);
  });

  testWidgets('selecting "storyguide ruling" reports storyguideRuling',
      (tester) async {
    final reported = <RitualDeclaration>[];

    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.lastingCreation,
      showLastingCreationOption: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-radio-storyguideRuling')));
    expect(reported, [RitualDeclaration.storyguideRuling]);
  });

  testWidgets('selecting "not declared" reports none', (tester) async {
    final reported = <RitualDeclaration>[];

    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.storyguideRuling,
      showLastingCreationOption: false,
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-radio-none')));
    expect(reported, [RitualDeclaration.none]);
  });
}
