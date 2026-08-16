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
      rangeName: 'Touch',
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
      rangeName: 'Touch',
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
      rangeName: 'Touch',
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

  testWidgets('names the range reason in the banner', (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([RitualReason.ritualOnlyRange]),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: false,
      rangeName: 'Symbol',
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final banner = tester.widget<Text>(find
        .descendant(
            of: find.byKey(const Key('ritual-banner')), matching: find.byType(Text))
        .first);
    expect(banner.data, contains('Symbol range'));
  });

  testWidgets('explains the healing case when the guideline is suggested',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([RitualReason.lastingCreation]),
      declaration: RitualDeclaration.lastingCreation,
      showLastingCreationOption: true,
      rangeName: 'Touch',
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
      rangeName: 'Touch',
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
      rangeName: 'Touch',
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
      rangeName: 'Touch',
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-radio-none')));
    expect(reported, [RitualDeclaration.none]);
  });

  testWidgets('the "not declared" radio is selected when declaration is none',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: true,
      rangeName: 'Touch',
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final context = tester.element(find.byKey(const Key('ritual-radio-none')));
    expect(
      RadioGroup.maybeOf<RitualDeclaration>(context)?.groupValue,
      RitualDeclaration.none,
    );
  });

  testWidgets(
      'the "creates something lasting" radio is selected when declaration is lastingCreation',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.lastingCreation,
      showLastingCreationOption: true,
      rangeName: 'Touch',
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final context =
        tester.element(find.byKey(const Key('ritual-radio-lastingCreation')));
    expect(
      RadioGroup.maybeOf<RitualDeclaration>(context)?.groupValue,
      RitualDeclaration.lastingCreation,
    );
  });

  testWidgets(
      'the "storyguide ruling" radio is selected when declaration is storyguideRuling',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.storyguideRuling,
      showLastingCreationOption: false,
      rangeName: 'Touch',
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final context =
        tester.element(find.byKey(const Key('ritual-radio-storyguideRuling')));
    expect(
      RadioGroup.maybeOf<RitualDeclaration>(context)?.groupValue,
      RitualDeclaration.storyguideRuling,
    );
  });

  testWidgets(
      'renders and selects the "creates something lasting" radio for an ineligible draft that already carries the declaration',
      (tester) async {
    // Regression for Finding 1: a template-instantiated draft (e.g.
    // Disenchant, Perdo Vim) can carry declaration: lastingCreation while
    // showLastingCreationOption is false, because TemplateInstantiated
    // copies the catalog's declaration verbatim. The tile must still
    // render and show as selected, or the declaration becomes
    // unrecoverable the instant the user touches this control.
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.lastingCreation,
      showLastingCreationOption: false,
      rangeName: 'Touch',
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final tile = find.byKey(const Key('ritual-radio-lastingCreation'));
    expect(tile, findsOneWidget);
    expect(
      RadioGroup.maybeOf<RitualDeclaration>(tester.element(tile))?.groupValue,
      RitualDeclaration.lastingCreation,
    );
  });
}
