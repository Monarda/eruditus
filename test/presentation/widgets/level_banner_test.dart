import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/presentation/widgets/level_banner.dart';

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

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: banner)));
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
