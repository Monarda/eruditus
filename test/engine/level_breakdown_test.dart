import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/ritual_status.dart';

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

  group('value equality', () {
    test('two structurally identical contributions are equal', () {
      expect(
        const LevelContribution(label: 'Range · Voice', magnitude: 2),
        const LevelContribution(label: 'Range · Voice', magnitude: 2),
      );
    });

    test('contributions differing in any field are not equal', () {
      expect(
        const LevelContribution(label: 'Range · Voice', magnitude: 2),
        isNot(const LevelContribution(label: 'Range · Voice', magnitude: 3)),
      );
      expect(
        const LevelContribution(label: 'Base', magnitude: 2, isBase: true),
        isNot(const LevelContribution(label: 'Base', magnitude: 2)),
      );
    });

    test('two structurally identical ritual statuses are equal', () {
      expect(
        const RitualStatus([RitualReason.lastingCreation]),
        const RitualStatus([RitualReason.lastingCreation]),
      );
      expect(const RitualStatus.notRitual(), const RitualStatus([]));
    });

    test('two separately built but identical breakdowns are equal', () {
      // The property Task 4's emit funnel depends on: it rebuilds the
      // breakdown on every event, so an edit that does not move the level
      // must produce a breakdown that compares *equal* to the previous one.
      // Without this, SpellCreationState (which lists breakdown in props)
      // would look changed on every single emit.
      LevelBreakdown build() => const LevelBreakdown(
            level: 20,
            rawLevel: 20,
            ritualStatus: RitualStatus([RitualReason.lastingCreation]),
            contributions: [
              LevelContribution(label: 'Base effect · Create flame', magnitude: 10, isBase: true),
              LevelContribution(label: 'Range · Voice', magnitude: 2),
            ],
          );

      expect(build(), build());
    });

    test('breakdowns differing only in a nested contribution are not equal', () {
      const a = LevelBreakdown(
        level: 20, rawLevel: 20,
        contributions: [LevelContribution(label: 'Range · Voice', magnitude: 2)],
      );
      const b = LevelBreakdown(
        level: 20, rawLevel: 20,
        contributions: [LevelContribution(label: 'Range · Touch', magnitude: 1)],
      );

      expect(a, isNot(b));
    });
  });
}
