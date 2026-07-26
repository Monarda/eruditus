import 'package:flutter/material.dart';

import 'package:eruditus/engine/level_breakdown.dart';

/// Itemises what produced a spell's level. Deliberately omits the magnitude
/// total and the additive-tier/multiplier split: both are deferred together,
/// because a total shown without the tier arithmetic raises a question only
/// the tier arithmetic answers.
class LevelBreakdownCard extends StatelessWidget {
  final LevelBreakdown breakdown;

  const LevelBreakdownCard({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('level-breakdown-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              key: const Key('breakdown-total'),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Calculated spell level',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${breakdown.level}',
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 12),
            ...breakdown.contributions.map((contribution) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(contribution.label)),
                      Text(contribution.isBase
                          ? '${contribution.magnitude}'
                          : '+${contribution.magnitude}'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
