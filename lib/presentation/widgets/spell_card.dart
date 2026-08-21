import 'package:flutter/material.dart';

import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell_validation_error.dart';
import 'package:eruditus/models/text_provenance.dart';
import 'package:eruditus/presentation/format/contribution_formatter.dart';
import 'package:eruditus/presentation/widgets/sourced_text_view.dart';

class SpellCard extends StatelessWidget {
  final LibraryEntry entry;
  final int? level;
  final VoidCallback? onTap;

  /// A short "why this card exists outside the normal computed path" note
  /// — currently only set by an exception-spell card. Rendered as an extra
  /// line below the summary/description blurb, when present.
  final String? rationale;

  /// Precomputed by the caller, which owns the SpellEngine. The card never
  /// derives it — same reason `level` is passed in rather than calculated here.
  final bool isRitual;

  /// True for a General guideline, which has no fixed level of its own —
  /// distinct from [isRitual], which is a property of an already-leveled
  /// spell. Mirrors [isRitual]'s "precomputed by the caller" treatment: a
  /// LibraryEntry has no field a General template and a Ritual spell could
  /// share, so both are supplied rather than derived here.
  final bool isGeneral;

  /// True for an [ExceptionSpell] — a spell the rulebook itself says
  /// guideline arithmetic doesn't apply to. Distinct from [isGeneral]:
  /// an exception spell is never instantiable, whether or not it happens to
  /// print a level.
  final bool isException;

  /// Catalog-validity problems on the underlying record -- a sibling of
  /// [LibraryEntry.isResolved], not a substitute for it: [isResolved] means
  /// "can a level even be computed", this means "the level computes but the
  /// combination breaks a rule". Only `ResolvedSpell` exposes this today
  /// (`ResolvedSpell.problems`), so it is precomputed by the caller rather
  /// than read from [entry] directly -- the same way [isRitual]/[isGeneral]/
  /// [rationale] already are. Rendered only when [LibraryEntry.isResolved]
  /// is true; ignored otherwise, leaving the unresolved branch below
  /// untouched.
  final List<SpellValidationError> problems;

  /// Rendered inside the card below the ListTile, e.g. the Library screen's
  /// *Learn at level…* button for a template. Empty by default so ordinary
  /// spell cards (which have no actions) are unchanged.
  final List<Widget> actions;

  const SpellCard({
    super.key,
    required this.entry,
    this.level,
    this.onTap,
    this.rationale,
    this.isRitual = false,
    this.isGeneral = false,
    this.isException = false,
    this.problems = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isInvalid = !entry.isResolved;
    final hasProblems = entry.isResolved && problems.isNotEmpty;
    // An unresolved spell (see below) has a null technique/form too, since
    // both are derived from the (possibly null) resolved baseEffect. Reachable
    // via BackupService.importFromJson, which calls Spell.fromMap directly on
    // user-supplied JSON where `name` is optional: without this branch a
    // nameless, unresolved spell would render the literal string
    // "Untitled null null".
    final title = entry.name ??
        (isInvalid
            ? l10n.untitledSpell
            : l10n.untitledSpellOfArts(entry.technique!, entry.form!));
    final String subtitle;
    if (isInvalid) {
      // The catalog entry this spell was built on no longer exists (a custom
      // effect or parameter the user deleted). Say so plainly rather than
      // showing a half-empty card or hiding the spell.
      subtitle = l10n.spellCardUnavailable(entry.unresolvedReferences.join(', '));
    } else {
      // hasProblems doesn't change *whether* a level renders, only whether
      // it's flagged: the breakdown genuinely computed, so unlike the
      // isInvalid branch above there is a real number to show.
      final levelSuffix = hasProblems ? l10n.spellCardUnverifiedSuffix : '';
      subtitle = level != null
          ? l10n.spellCardArtsAndLevel(entry.technique!, entry.form!, level!, levelSuffix)
          : l10n.spellCardArtsOnly(entry.technique!, entry.form!);
    }
    // Prefer the summary; fall back to the description. Both are the book's
    // own words for a published spell today; item 31 is what makes the
    // summary a real paraphrase. See sourcedFrom.
    // validateSpellProse's rule is unconditional (todo item 13), so every
    // entry is guaranteed a non-blank summary or description -- but that
    // guarantee is about the pair together, not about summary alone: a
    // template can be instantiated with both, then have its summary cleared
    // back to '' before save, leaving a real description behind it. `??`
    // only falls through on null, so an empty-string summary must be treated
    // as absent explicitly or that description would never render.
    final summary = entry.summary;
    final preferSummary = summary != null && summary.trim().isNotEmpty;
    // entry.sourcedSummary/sourcedDescription only exist on ResolvedSpell
    // (todo item 79.3 task 2) -- LibraryEntry itself, and the
    // ResolvedTemplate/ResolvedException that also implement it, expose only
    // the plain String getters. Those two render as SourcedText.authored,
    // identical to the plain Text they rendered before this change, until a
    // future item gives templates and exceptions the same provenance-aware
    // getters ResolvedSpell has.
    final blurbText = preferSummary ? summary : entry.description;
    // A local so `is ResolvedSpell` can promote it -- `entry` itself is a
    // field access, which Dart's flow analysis won't narrow.
    final resolvedEntry = entry;
    final blurb = blurbText == null
        ? null
        : resolvedEntry is ResolvedSpell
            ? (preferSummary ? resolvedEntry.sourcedSummary : resolvedEntry.sourcedDescription)
            : SourcedText.authored(blurbText);
    final hasBlurb = blurb != null && blurb.text.isNotEmpty;

    return Card(
      key: isInvalid
          ? const Key('spell-card-unresolved')
          : (hasProblems ? const Key('spell-card-invalid') : null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: onTap,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(title)),
                if (isRitual)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      key: const Key('ritual-chip'),
                      label: Text(l10n.ritualChip),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (isGeneral)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      key: const Key('general-chip'),
                      label: Text(l10n.generalChip),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (isException)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      key: const Key('exception-chip'),
                      label: Text(l10n.exceptionChip),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (hasProblems)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      key: const Key('needs-review-chip'),
                      label: Text(l10n.needsReview),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      labelStyle:
                          TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(subtitle,
                    style: isInvalid
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null),
                if (hasBlurb)
                  SourcedTextView(
                    blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // The card is already tappable; a marker here would be a
                    // second gesture target inside one list row.
                    showMarker: false,
                  ),
                if (hasProblems)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      problems.map((p) => formatValidationError(l10n, p)).join('; '),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (rationale != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      rationale!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            trailing: Chip(
                label: Text(
                    entry.source == PublicationSource.published ? l10n.published : l10n.mySpell)),
          ),
          if (actions.isNotEmpty) ...actions,
        ],
      ),
    );
  }
}
