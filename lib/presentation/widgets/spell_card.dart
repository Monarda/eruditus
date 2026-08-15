import 'package:flutter/material.dart';

import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/publication_source.dart';

class SpellCard extends StatelessWidget {
  final LibraryEntry entry;
  final int? level;
  final VoidCallback? onTap;

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

  /// Rendered inside the card below the ListTile, e.g. the Library screen's
  /// *Learn at level…* button for a template. Empty by default so ordinary
  /// spell cards (which have no actions) are unchanged.
  final List<Widget> actions;

  const SpellCard({
    super.key,
    required this.entry,
    this.level,
    this.onTap,
    this.isRitual = false,
    this.isGeneral = false,
    this.isException = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isInvalid = !entry.isResolved;
    // An unresolved spell (see below) has a null technique/form too, since
    // both are derived from the (possibly null) resolved baseEffect. Reachable
    // via BackupService.importFromJson, which calls Spell.fromMap directly on
    // user-supplied JSON where `name` is optional: without this branch a
    // nameless, unresolved spell would render the literal string
    // "Untitled null null".
    final title = entry.name ??
        (isInvalid ? 'Untitled spell' : 'Untitled ${entry.technique} ${entry.form}');
    final String subtitle;
    if (isInvalid) {
      // The catalog entry this spell was built on no longer exists (a custom
      // effect or parameter the user deleted). Say so plainly rather than
      // showing a half-empty card or hiding the spell.
      subtitle = 'Unavailable — missing ${entry.unresolvedReferences.join(', ')}';
    } else {
      subtitle = level != null
          ? '${entry.technique} ${entry.form} • Level $level'
          : '${entry.technique} ${entry.form}';
    }
    // Prefer the paraphrase; fall back to the verbatim rulebook text. A
    // published spell always has at least one of them; a user-created spell may
    // have neither, in which case the blurb is simply omitted.
    final blurb = entry.summary ?? entry.description;
    final hasBlurb = blurb != null && blurb.isNotEmpty;

    return Card(
      key: isInvalid ? const Key('spell-card-unresolved') : null,
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
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      key: Key('ritual-chip'),
                      label: Text('Ritual'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (isGeneral)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      key: Key('general-chip'),
                      label: Text('Gen'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (isException)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      key: Key('exception-chip'),
                      label: Text('Exception'),
                      visualDensity: VisualDensity.compact,
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
                  Text(blurb, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: Chip(
                label: Text(
                    entry.source == PublicationSource.published ? 'Published' : 'My Spell')),
          ),
          if (actions.isNotEmpty) ...actions,
        ],
      ),
    );
  }
}
