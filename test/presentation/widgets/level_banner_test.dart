import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/presentation/widgets/level_banner.dart';

import '../../support/pump_app.dart';

void main() {
  const breakdown = LevelBreakdown(
    level: 10,
    rawLevel: 10,
    contributions: [
      LevelContribution(label: 'Base effect · image, two senses', magnitude: 2, isBase: true),
      LevelContribution(label: 'Range · Voice', magnitude: 2),
      LevelContribution(label: 'Duration · Momentary', magnitude: 0),
      LevelContribution(label: 'Material difficulty · Metal or gemstone', magnitude: 2),
    ],
  );

  Future<void> pump(WidgetTester tester, Widget banner) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, banner);
  }

  testWidgets('shows the level', (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.byKey(const Key('breakdown-total')), findsOneWidget);
    expect(find.text('Spell level'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('is collapsed by default, so the form keeps its room', (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    expect(find.text('Range · Voice'), findsNothing);
  });

  testWidgets('lists every contribution once expanded, base without a plus sign',
      (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Base effect · image, two senses'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Range · Voice'), findsOneWidget);
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+0'), findsOneWidget);
    expect(find.text('Material difficulty · Metal or gemstone'), findsOneWidget);
  });

  testWidgets('collapses again on a second tap', (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Range · Voice'), findsNothing);
  });

  testWidgets('does not show a magnitude total', (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    // The tier split that would explain a total is deferred, so showing the
    // total alone would invite "why isn't 2 + 4 = 6?".
    expect(find.textContaining('Total magnitude'), findsNothing);
  });

  testWidgets('does not show a Ritual minimum note when the floor did not apply',
      (tester) async {
    await pump(tester, const LevelBanner(breakdown: breakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ritual-minimum-note')), findsNothing);
  });

  testWidgets('shows a Ritual minimum note with the raw and floored levels when the floor applied',
      (tester) async {
    const flooredBreakdown = LevelBreakdown(
      level: 20,
      rawLevel: 2,
      contributions: [
        LevelContribution(label: 'Base effect · Heal a Light Wound to a plant', magnitude: 1, isBase: true),
        LevelContribution(label: 'Range · Touch', magnitude: 1),
      ],
    );

    await pump(tester, const LevelBanner(breakdown: flooredBreakdown));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ritual-minimum-note')), findsOneWidget);
    expect(find.text('Ritual minimum: raised from 2 to 20'), findsOneWidget);
  });

  testWidgets('caps the expanded detail against the height it is given, not the screen',
      (tester) async {
    // The banner is boxed to 200 logical px on a 3000px-tall view, so the two
    // rules give wildly different answers: 40% of the box is 80, 40% of the
    // screen is 1200. The old `MediaQuery.of(context).size.height` rule would
    // therefore have let this twelve-row detail render at its natural height
    // and blow the box -- the same shape of failure the creation screen hits
    // for real, where the banner is a non-flex Column child above an Expanded
    // ListView and a detail sized against the screen starves the form to zero.
    const tallBreakdown = LevelBreakdown(
      level: 30,
      rawLevel: 30,
      contributions: [
        LevelContribution(label: 'Base effect · Create flame', magnitude: 4, isBase: true),
        LevelContribution(label: 'Range · Voice', magnitude: 2),
        LevelContribution(label: 'Duration · Sun', magnitude: 2),
        LevelContribution(label: 'Target · Room', magnitude: 2),
        LevelContribution(label: 'Requisite · Rego, adding', magnitude: 1),
        LevelContribution(label: 'Requisite · Vim, adding', magnitude: 1),
        LevelContribution(label: 'Adjustment · unusually precise', magnitude: 1),
        LevelContribution(label: 'Adjustment · at a distance', magnitude: 1),
        LevelContribution(label: 'Complexity · Intricate design', magnitude: 1),
        LevelContribution(label: 'Material difficulty · Metal or gemstone', magnitude: 2),
        LevelContribution(label: 'Size · +1', magnitude: 1),
        LevelContribution(label: 'Penetration · +5', magnitude: 1),
      ],
    );

    await pump(tester, const SizedBox(
      height: 200,
      child: LevelBanner(breakdown: tallBreakdown),
    ));

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    final detail = find.descendant(
      of: find.byKey(const Key('level-banner')),
      matching: find.byType(SingleChildScrollView),
    );
    expect(tester.getSize(detail).height, 80.0);
    // The banner fits the box it was given, so a sibling sharing that space
    // still has room. Without the cap the Column inside overflows instead.
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('level-banner'))).height,
        lessThanOrEqualTo(200.0));
  });

  testWidgets('with no level, shows an em dash and the reason', (tester) async {
    await pump(tester, const LevelBanner(
      unavailableReason: 'Choose a base effect to see a level.',
    ));

    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.byKey(const Key('level-unavailable-reason')), findsOneWidget);
    expect(find.text('Choose a base effect to see a level.'), findsOneWidget);
  });

  testWidgets('with no level, offers no expand affordance', (tester) async {
    await pump(tester, const LevelBanner(
      unavailableReason: 'Choose a base effect to see a level.',
    ));

    expect(find.byKey(const Key('level-banner-toggle')), findsNothing);
  });
}
