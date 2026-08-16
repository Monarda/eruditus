import 'package:flutter/material.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/ritual_declaration.dart';

/// The Ritual controls of the spell creation form: a non-interactive banner
/// listing every reason the spell is a Ritual, and a three-way declaration
/// control for the two cases the rulebook leaves to a person's judgement
/// (Core Rules line 12350 onward).
///
/// The banner and the declaration control are independent and both can be on
/// screen at once. A Creo/Momentary/Boundary spell is already forced by its
/// Target; the banner says so and the declaration control stays live and
/// harmless.
class RitualSection extends StatelessWidget {
  final RitualStatus ritualStatus;
  final RitualDeclaration declaration;

  /// True when the draft is Creo with Momentary duration -- the only
  /// configuration the "Creates something lasting" option is offered for
  /// (Core Rules line 12351). The "Storyguide ruling" option has no such
  /// gate: line 12352 lets the troupe declare *any* spell a Ritual.
  final bool showLastingCreationOption;

  /// The selected parameters' own names, so the banner can say "Year duration"
  /// without RitualReason having to hardcode which parameters are ritual-only.
  final String rangeName;
  final String durationName;
  final String targetName;

  /// True when the chosen guideline is [RitualRequirement.suggested], which
  /// forces nothing but changes what a non-Ritual casting actually does.
  final bool guidelineIsSuggested;

  final ValueChanged<RitualDeclaration> onDeclarationChanged;

  const RitualSection({
    super.key,
    required this.ritualStatus,
    required this.declaration,
    required this.showLastingCreationOption,
    required this.rangeName,
    required this.durationName,
    required this.targetName,
    required this.guidelineIsSuggested,
    required this.onDeclarationChanged,
  });

  String _describe(RitualReason reason) => switch (reason) {
        RitualReason.ritualOnlyRange => '$rangeName range',
        RitualReason.ritualOnlyDuration => '$durationName duration',
        RitualReason.ritualOnlyTarget => '$targetName target',
        RitualReason.exceedsMaxFormulaicLevel =>
          'level above ${RitualStatus.maxFormulaicLevel}',
        RitualReason.guideline => 'the guideline requires it',
        RitualReason.lastingCreation => 'it creates something lasting',
        RitualReason.storyguideRuling => 'storyguide ruling',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ritualStatus.isRitual)
          Card(
            key: const Key('ritual-banner'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Ritual: ${ritualStatus.reasons.map(_describe).join('; ')}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        RadioGroup<RitualDeclaration>(
          groupValue: declaration,
          onChanged: (value) {
            if (value != null) onDeclarationChanged(value);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RadioListTile<RitualDeclaration>(
                key: Key('ritual-radio-none'),
                value: RitualDeclaration.none,
                title: Text('Not declared'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (showLastingCreationOption ||
                  declaration == RitualDeclaration.lastingCreation)
                RadioListTile<RitualDeclaration>(
                  key: const Key('ritual-radio-lastingCreation'),
                  value: RitualDeclaration.lastingCreation,
                  title: const Text('This creates something lasting'),
                  subtitle: Text(
                    guidelineIsSuggested
                        // Core Rules line 13415.
                        ? 'Cast as anything other than a Momentary Ritual, this '
                            'suspends the healing rather than completing it.'
                        : 'A Momentary Creo spell that is not a Ritual creates '
                            'something that vanishes as the magic ends.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              const RadioListTile<RitualDeclaration>(
                key: Key('ritual-radio-storyguideRuling'),
                value: RitualDeclaration.storyguideRuling,
                title:
                    Text('Storyguide ruling: too spectacular to be freely available'),
                subtitle: Text(
                  "At the troupe's discretion — not something the guideline "
                  'determines (Core Rules line 12352).',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
