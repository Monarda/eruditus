import 'package:flutter/material.dart';

import 'package:eruditus/models/spell.dart';

class SpellCard extends StatelessWidget {
  final Spell spell;
  final int? level;
  final VoidCallback? onTap;

  const SpellCard({super.key, required this.spell, this.level, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = spell.name ?? 'Untitled ${spell.technique} ${spell.form}';
    final subtitle = level != null
        ? '${spell.technique} ${spell.form} • Level $level'
        : '${spell.technique} ${spell.form}';

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Chip(label: Text(spell.source == 'built-in' ? 'Built-in' : 'My Spell')),
      ),
    );
  }
}
