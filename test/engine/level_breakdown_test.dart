import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';

void main() {
  test('LevelBreakdown exposes its level and contributions in order', () {
    const breakdown = LevelBreakdown(
      level: 10,
      rawLevel: 10,
      contributions: [
        LevelContribution(label: 'Base effect · image, two senses', magnitude: 2, isBase: true),
        LevelContribution(label: 'Range · Voice', magnitude: 2),
        LevelContribution(label: 'Complexity · Intricate Design', magnitude: 1),
      ],
    );

    expect(breakdown.level, 10);
    expect(breakdown.contributions.first.isBase, isTrue);
    expect(breakdown.contributions.map((c) => c.magnitude).toList(), [2, 2, 1]);
  });

  test('magnitudeTotal sums every non-base contribution', () {
    const breakdown = LevelBreakdown(
      level: 10,
      rawLevel: 10,
      contributions: [
        LevelContribution(label: 'Base', magnitude: 2, isBase: true),
        LevelContribution(label: 'Range', magnitude: 2),
        LevelContribution(label: 'Target', magnitude: 1),
      ],
    );

    expect(breakdown.magnitudeTotal, 3);
  });
}
