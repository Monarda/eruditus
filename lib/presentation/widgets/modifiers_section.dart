import 'package:flutter/material.dart';

import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/models/modifier.dart';

/// The Modifiers section of the spell creation form. Collapsed by default: the
/// summary row carries the selected count and the total magnitude, so a
/// selection pruned by a scope change still moves something the caster can see
/// without expanding.
class ModifiersSection extends StatefulWidget {
  final List<Modifier> modifiers;
  final Map<String, List<String>> selected;
  final void Function(String modifierId, String optionId) onSelect;
  final void Function(String modifierId, String optionId) onDeselect;

  const ModifiersSection({
    super.key,
    required this.modifiers,
    required this.selected,
    required this.onSelect,
    required this.onDeselect,
  });

  @override
  State<ModifiersSection> createState() => _ModifiersSectionState();
}

class _ModifiersSectionState extends State<ModifiersSection> {
  bool _expanded = false;

  int get _selectedCount =>
      widget.selected.values.fold(0, (sum, options) => sum + options.length);

  int get _totalMagnitude {
    var total = 0;
    for (final modifier in widget.modifiers) {
      for (final optionId in widget.selected[modifier.id] ?? const <String>[]) {
        total += modifier.optionById(optionId)?.magnitude ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.modifiers.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('modifiers-expand-toggle'),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            key: const Key('modifiers-summary'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modifiers', style: Theme.of(context).textTheme.titleMedium),
                      Text(l10n.modifiersSelectedCount(_selectedCount),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('+$_totalMagnitude', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.modifiers.map((modifier) =>
              modifier.selectionMode == ModifierSelectionMode.single
                  ? _buildSingle(modifier, l10n)
                  : _buildMulti(modifier, l10n)),
      ],
    );
  }

  Widget _buildSingle(Modifier modifier, AppLocalizations l10n) {
    final selectedIds = widget.selected[modifier.id] ?? const <String>[];
    // Guard against a stored single-select selection carrying more than one
    // option: the dropdown asserts on a value matching no single item.
    final value = selectedIds.length == 1 ? modifier.optionById(selectedIds.first) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // Nullable, for the sake of the None entry below: without an item to
      // pick, a single-select modifier is a one-way choice -- and since
      // no-gestures and no-words are scoped to no Technique or Form, they
      // appear on every draft, where a mis-click would cost +1 or +2
      // magnitudes permanently. See todo item 61.
      child: DropdownButtonFormField<ModifierOption?>(
        key: Key('modifier-dropdown-${modifier.id}'),
        decoration: InputDecoration(labelText: modifier.name),
        initialValue: value,
        items: [
          const DropdownMenuItem<ModifierOption?>(value: null, child: Text('None')),
          ...modifier.options.map((option) => DropdownMenuItem<ModifierOption?>(
                value: option,
                child: Text(l10n.modifierOptionWithMagnitude(option.label, option.magnitude)),
              )),
        ],
        onChanged: (option) {
          if (option != null) {
            widget.onSelect(modifier.id, option.id);
            return;
          }
          // Every selected id, not just the first. `value` above already
          // tolerates a stored selection carrying more than one option by
          // showing nothing; clearing has to tolerate it too, or the surplus
          // would survive with the field reading None and no way left to
          // reach it. Deselecting nothing when nothing is selected falls out
          // of the same loop.
          for (final optionId in selectedIds) {
            widget.onDeselect(modifier.id, optionId);
          }
        },
      ),
    );
  }

  Widget _buildMulti(Modifier modifier, AppLocalizations l10n) {
    final selectedIds = widget.selected[modifier.id] ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(modifier.name, style: Theme.of(context).textTheme.bodyMedium),
        ...modifier.options.map((option) => CheckboxListTile(
              key: Key('modifier-checkbox-${option.id}'),
              title: Text(l10n.modifierOptionWithMagnitude(option.label, option.magnitude)),
              subtitle: option.description == null ? null : Text(option.description!),
              value: selectedIds.contains(option.id),
              onChanged: (isSelected) {
                if (isSelected ?? false) {
                  widget.onSelect(modifier.id, option.id);
                } else {
                  widget.onDeselect(modifier.id, option.id);
                }
              },
            )),
      ],
    );
  }
}
