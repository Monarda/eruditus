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
      // Two *distinct* instances, deliberately. The constructor calls here are
      // not `const` and are not in a const context, so each allocates rather
      // than being canonicalized to one shared instance -- which is what makes
      // the equality assertions below test Equatable rather than tautologically
      // comparing an object with itself. The `identical` check on the next line
      // is what pins that; it is the test's own proof, not a formality.
      final a = LevelContribution(label: 'Range · Voice', magnitude: 1 + 1);
      final b = LevelContribution(label: 'Range · Voice', magnitude: 2);

      expect(identical(a, b), isFalse);
      expect(a, b);
    });

    test('contributions differing in any field are not equal', () {
      final a = LevelContribution(label: 'Range · Voice', magnitude: 1 + 1);
      final b = LevelContribution(label: 'Range · Voice', magnitude: 1 + 2);
      expect(a, isNot(b));

      final c = LevelContribution(label: 'Base', magnitude: 2, isBase: true);
      final d = LevelContribution(label: 'Base', magnitude: 2);
      expect(c, isNot(d));
    });

    test('two structurally identical ritual statuses are equal', () {
      // Non-const calls again, so these are two instances holding two lists.
      // See the first test in this group for why that matters.
      final a = RitualStatus([RitualReason.lastingCreation]);
      final b = RitualStatus([RitualReason.lastingCreation]);

      expect(identical(a, b), isFalse);
      expect(a, b);
    });

    test('two separately built but identical breakdowns are equal', () {
      // The property Task 4's emit funnel depends on: it rebuilds the
      // breakdown on every event, so an edit that does not move the level
      // must produce a breakdown that compares *equal* to the previous one.
      // This test uses runtime-built objects to ensure two distinct instances
      // compare equal by value via Equatable, not by identity.
      LevelBreakdown build() => LevelBreakdown(
            level: 10 + 10,
            rawLevel: 20,
            ritualStatus: RitualStatus([RitualReason.lastingCreation]),
            contributions: [
              LevelContribution(label: 'Base effect · Create flame', magnitude: 5 * 2, isBase: true),
              LevelContribution(label: 'Range · Voice', magnitude: 1 + 1),
            ],
          );

      final a = build();
      final b = build();
      expect(identical(a, b), isFalse);
      expect(a, b);
    });

    test('breakdowns differing only in a nested contribution are not equal', () {
      final a = LevelBreakdown(
        level: 20, rawLevel: 20,
        contributions: [LevelContribution(label: 'Range · Voice', magnitude: 2)],
      );
      final b = LevelBreakdown(
        level: 20, rawLevel: 20,
        contributions: [LevelContribution(label: 'Range · Touch', magnitude: 1)],
      );

      expect(a, isNot(b));
    });
  });
}
