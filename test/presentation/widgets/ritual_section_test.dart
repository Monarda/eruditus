import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/presentation/widgets/ritual_section.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('hides both banner and checkbox for an ordinary spell',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showDeclarationCheckbox: false,
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    expect(find.byKey(const Key('ritual-banner')), findsNothing);
    expect(find.byKey(const Key('ritual-checkbox')), findsNothing);
  });

  testWidgets('shows the checkbox only when the draft is Creo + Momentary',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showDeclarationCheckbox: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    expect(find.byKey(const Key('ritual-checkbox')), findsOneWidget);
  });

  testWidgets('names every reason in the banner', (tester) async {
    // Aegis of the Hearth: Year duration and Boundary target.
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([
        RitualReason.ritualOnlyDuration,
        RitualReason.ritualOnlyTarget,
      ]),
      declaration: RitualDeclaration.none,
      showDeclarationCheckbox: false,
      durationName: 'Year',
      targetName: 'Boundary',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final banner = tester.widget<Text>(
        find.descendant(of: find.byKey(const Key('ritual-banner')), matching: find.byType(Text)).first);
    expect(banner.data, contains('Year duration'));
    expect(banner.data, contains('Boundary target'));
  });

  testWidgets('explains the healing case when the guideline is suggested',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([RitualReason.lastingCreation]),
      declaration: RitualDeclaration.lastingCreation,
      showDeclarationCheckbox: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: true,
      onDeclarationChanged: (_) {},
    )));

    expect(find.textContaining('suspends'), findsOneWidget);
  });

  testWidgets('ticking and clearing the checkbox reports the right declaration',
      (tester) async {
    final reported = <RitualDeclaration>[];

    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showDeclarationCheckbox: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-checkbox')));
    expect(reported, [RitualDeclaration.lastingCreation]);
  });
}
