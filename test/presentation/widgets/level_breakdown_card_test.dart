import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/presentation/widgets/level_breakdown_card.dart';

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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: LevelBreakdownCard(breakdown: breakdown)),
    ));
  }

  testWidgets('shows the calculated level', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('level-breakdown-card')), findsOneWidget);
    expect(find.byKey(const Key('breakdown-total')), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('lists every contribution, base without a plus sign', (tester) async {
    await pump(tester);

    expect(find.text('Base effect · image, two senses'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Range · Voice'), findsOneWidget);
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+0'), findsOneWidget);
    expect(find.text('Material difficulty · Metal or gemstone'), findsOneWidget);
  });

  testWidgets('does not show a magnitude total', (tester) async {
    await pump(tester);

    // The tier split that would explain a total is deferred, so showing the
    // total alone would invite "why isn't 2 + 4 = 6?".
    expect(find.textContaining('Total magnitude'), findsNothing);
  });
}
