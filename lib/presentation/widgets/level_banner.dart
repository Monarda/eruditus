import 'package:flutter/material.dart';

import 'package:eruditus/engine/level_breakdown.dart';

/// The spell's level, pinned above the creation form and outside its scroll.
///
/// **Always on screen, and never hidden by an edit.** [breakdown] null means
/// the draft cannot produce a level yet, and [unavailableReason] fills the slot
/// the number would occupy. This is the whole point of todo item 59: before it,
/// the level appeared only after a button press and every subsequent edit hid
/// it again, so the number a caster designs towards was absent exactly while
/// they were designing.
///
/// Pinned rather than left in the scroll because the form runs from Technique
/// down to Summary -- an inline card is off-screen precisely when the caster is
/// editing the fields at the top. Placed *above* the ListView in a Column, so
/// the on-screen keyboard (which insets from the bottom) can never cover it.
///
/// Collapsed by default. The contribution list runs to a dozen rows on a spell
/// with several modifiers, requisites and adjustments, which pinned open would
/// swallow the form -- so the header is always visible and the detail is one
/// tap away, capped at 40% of the height this banner is given, with its own
/// scroll.
///
/// Deliberately omits the magnitude total and the additive-tier/multiplier
/// split: both are deferred together, because a total shown without the tier
/// arithmetic raises a question only the tier arithmetic answers.
class LevelBanner extends StatefulWidget {
  final LevelBreakdown? breakdown;
  final String? unavailableReason;

  const LevelBanner({super.key, this.breakdown, this.unavailableReason});

  @override
  State<LevelBanner> createState() => _LevelBannerState();
}

class _LevelBannerState extends State<LevelBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final breakdown = widget.breakdown;
    final reason = widget.unavailableReason;

    // LayoutBuilder rather than MediaQuery, because the cap has to be a
    // fraction of the space this banner was actually handed, not of the device.
    // `MediaQuery.of(context).size.height` is the whole screen: it counts the
    // app bar, the status bar and the space the on-screen keyboard is
    // occupying, none of which the banner can use. The design asked for 40% of
    // the *body*, and on a short or landscape viewport -- or any viewport with
    // the keyboard up -- 40% of the screen is a good deal more than 40% of the
    // body. The banner is a non-flex child of the creation screen's Column, so
    // an expanded detail that big makes the Column's fixed children taller than
    // the body, starving the Expanded ListView to zero height and overflowing
    // the Column. `constraints.maxHeight` is the body, keyboard inset already
    // applied by Scaffold -- handed down by a LayoutBuilder on the screen,
    // because a Column gives its non-flex children an unbounded main axis and
    // this one would otherwise never see a real number.
    //
    // An unbounded height produces an infinite cap, and that is the right
    // answer rather than a missing fallback: a parent imposing no limit has
    // nothing for the banner to overflow.
    return LayoutBuilder(builder: (context, constraints) {
      return Material(
        key: const Key('level-banner'),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                key: const Key('breakdown-total'),
                children: [
                  Expanded(
                    child: Text('Spell level',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text(breakdown == null ? '—' : '${breakdown.level}',
                      style: Theme.of(context).textTheme.headlineSmall),
                  // No breakdown means nothing to expand, so no control offering
                  // to -- a disabled chevron would imply detail is being withheld
                  // when there is simply none yet.
                  if (breakdown != null)
                    IconButton(
                      key: const Key('level-banner-toggle'),
                      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                      tooltip: _expanded ? 'Hide the breakdown' : 'Show the breakdown',
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                ],
              ),
              if (reason != null)
                Text(
                  reason,
                  key: const Key('level-unavailable-reason'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (breakdown != null && _expanded)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
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
                        // The floor is deliberately not a LevelContribution (see
                        // the class doc on ritualMinimumApplied), so a
                        // raw-level-2 calculation that displays as 20 needs its
                        // own line explaining the gap -- otherwise the
                        // contributions above visibly fail to sum to the total.
                        if (breakdown.ritualMinimumApplied)
                          Padding(
                            key: const Key('ritual-minimum-note'),
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Ritual minimum: raised from ${breakdown.rawLevel} to ${breakdown.level}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
