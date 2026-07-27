import 'package:flutter/material.dart';

import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/publication_source.dart';

class SpellCard extends StatelessWidget {
  final ResolvedSpell spell;
  final int? level;
  final VoidCallback? onTap;

  /// Precomputed by the caller, which owns the SpellEngine. The card never
  /// derives it — same reason `level` is passed in rather than calculated here.
  final bool isRitual;

  const SpellCard(
      {super.key, required this.spell, this.level, this.onTap, this.isRitual = false});

  @override
  Widget build(BuildContext context) {
    final isInvalid = !spell.isResolved;
    // An unresolved spell (see below) has a null technique/form too, since
    // both are derived from the (possibly null) resolved baseEffect. Reachable
    // via BackupService.importFromJson, which calls Spell.fromMap directly on
    // user-supplied JSON where `name` is optional: without this branch a
    // nameless, unresolved spell would render the literal string
    // "Untitled null null".
    final title = spell.name ??
        (isInvalid ? 'Untitled spell' : 'Untitled ${spell.technique} ${spell.form}');
    final String subtitle;
    if (isInvalid) {
      // The catalog entry this spell was built on no longer exists (a custom
      // effect or parameter the user deleted). Say so plainly rather than
      // showing a half-empty card or hiding the spell.
      subtitle = 'Unavailable — missing ${spell.unresolvedReferences.join(', ')}';
    } else {
      subtitle = level != null
          ? '${spell.technique} ${spell.form} • Level $level'
          : '${spell.technique} ${spell.form}';
    }
    // Prefer the paraphrase; fall back to the verbatim rulebook text. A
    // published spell always has at least one of them; a user-created spell may
    // have neither, in which case the blurb is simply omitted.
    final blurb = spell.summary ?? spell.description;
    final hasBlurb = blurb != null && blurb.isNotEmpty;

    return Card(
      key: isInvalid ? const Key('spell-card-unresolved') : null,
      child: ListTile(
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
                spell.source == PublicationSource.published ? 'Published' : 'My Spell')),
      ),
    );
  }
}
