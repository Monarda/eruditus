import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/presentation/widgets/modifiers_section.dart';
import 'package:eruditus/presentation/widgets/spell_card.dart';
import 'package:eruditus/utils/constants.dart';

class SpellCreationScreen extends StatelessWidget {
  final List<String> techniques;
  final List<String> forms;

  const SpellCreationScreen({
    super.key,
    required this.techniques,
    required this.forms,
  });

  @override
  Widget build(BuildContext context) {
    // Effects/parameters/special-factors are read live from ConfigurationBloc
    // (rather than taken as static constructor lists) so a custom item added
    // in the Settings tab becomes selectable here immediately, without an app
    // restart and without needing to leave/re-enter this tab. Whenever the
    // known special factors change, AvailableFactorsSynced keeps
    // SpellCreationBloc's SpellEngine in sync too, since the engine resolves
    // a selected factor's magnitude by id lookup and would otherwise not
    // recognize a newly added custom factor.
    return BlocListener<ConfigurationBloc, ConfigurationState>(
      listenWhen: (previous, current) =>
          previous.factors != current.factors || previous.modifiers != current.modifiers,
      listener: (context, configState) {
        context.read<SpellCreationBloc>().add(AvailableFactorsSynced(configState.factors));
        context.read<SpellCreationBloc>().add(AvailableModifiersSynced(configState.modifiers));
      },
      child: BlocConsumer<SpellCreationBloc, SpellCreationState>(
        listener: (context, state) {
          if (state.status == SpellCreationStatus.saved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"${state.savedSpell?.name}" saved to your library.')),
            );
          } else if (state.status == SpellCreationStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save spell: ${state.errorMessage}')),
            );
          }
        },
        builder: (context, state) {
          final bloc = context.read<SpellCreationBloc>();
          final draft = state.draft;
          final configState = context.watch<ConfigurationBloc>().state;

          final effectsForSelection = configState.effects
              .where((e) => e.technique == draft.technique && e.form == draft.form)
              .toList();
          final factorsForSelection = configState.factors
              .where((f) => f.technique == draft.technique && f.form == draft.form)
              .toList();
          final modifiersForSelection = configState.modifiers
              .where((m) => m.scope.appliesTo(
                    technique: draft.technique,
                    form: draft.form,
                    baseEffectId: draft.baseEffect?.id,
                  ))
              .toList();

          final isSaving = state.status == SpellCreationStatus.saving;
          final showResultsBlock = state.status == SpellCreationStatus.calculated ||
              isSaving ||
              state.status == SpellCreationStatus.error;

          return Scaffold(
            appBar: AppBar(title: const Text('Create Spell')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('technique-dropdown'),
                  decoration: const InputDecoration(labelText: 'Technique'),
                  initialValue: draft.technique,
                  items: techniques
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) bloc.add(TechniqueSelected(value));
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('form-dropdown'),
                  decoration: const InputDecoration(labelText: 'Form'),
                  initialValue: draft.form,
                  items: forms
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) bloc.add(FormSelected(value));
                  },
                ),
                const SizedBox(height: 8),
                if (effectsForSelection.isNotEmpty)
                  DropdownButtonFormField<BaseEffect>(
                    key: const Key('base-effect-dropdown'),
                    decoration: const InputDecoration(labelText: 'Base Effect'),
                    initialValue: draft.baseEffect,
                    items: effectsForSelection
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text('${e.description} (Base ${e.baseLevel})'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) bloc.add(BaseEffectSelected(value));
                    },
                  ),
                const SizedBox(height: 16),
                Text('Spell Parameters', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Every spell requires exactly one of each:', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                // Range dropdown
                _buildParameterDropdown(
                  key: const Key('range-dropdown'),
                  label: 'Range',
                  category: 'Range',
                  parameters: configState.parameters,
                  selectedParameter: draft.range?.parameter,
                  onChanged: (param) {
                    if (param != null) bloc.add(RangeSelected(param));
                  },
                ),
                const SizedBox(height: 12),
                // Duration dropdown
                _buildParameterDropdown(
                  key: const Key('duration-dropdown'),
                  label: 'Duration',
                  category: 'Duration',
                  parameters: configState.parameters,
                  selectedParameter: draft.duration?.parameter,
                  onChanged: (param) {
                    if (param != null) bloc.add(DurationSelected(param));
                  },
                ),
                const SizedBox(height: 12),
                // Target dropdown
                _buildParameterDropdown(
                  key: const Key('target-dropdown'),
                  label: 'Target',
                  category: 'Target',
                  parameters: configState.parameters,
                  selectedParameter: draft.target?.parameter,
                  onChanged: (param) {
                    if (param != null) bloc.add(TargetSelected(param));
                  },
                ),
                const SizedBox(height: 16),
                _buildRequisitesSection(context, bloc, draft),
                const SizedBox(height: 16),
                ModifiersSection(
                  modifiers: modifiersForSelection,
                  selected: draft.selectedModifiers,
                  onSelect: (modifierId, optionId) =>
                      bloc.add(ModifierOptionSelected(modifierId, optionId)),
                  onDeselect: (modifierId, optionId) =>
                      bloc.add(ModifierOptionDeselected(modifierId, optionId)),
                ),
                if (factorsForSelection.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Special Factors', style: Theme.of(context).textTheme.titleMedium),
                  ...factorsForSelection.map((f) => CheckboxListTile(
                        title: Text('${f.name} (+${f.magnitude})'),
                        subtitle: Text(f.description),
                        value: draft.selectedSpecialFactorIds.contains(f.id),
                        onChanged: (selected) {
                          bloc.add(SpecialFactorToggled(f.id, selected ?? false));
                        },
                      )),
                ],
                const SizedBox(height: 16),
                if (state.validationErrors.isNotEmpty)
                  ...state.validationErrors.map(
                    (e) => Text(e, style: const TextStyle(color: Colors.red)),
                  ),
                if (showResultsBlock)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Calculated Spell Level: ${state.calculatedLevel}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('calculate-button'),
                  onPressed: () => bloc.add(const SpellCalculated()),
                  child: const Text('Calculate & View Suggestions'),
                ),
                if (showResultsBlock) ...[
                  const SizedBox(height: 16),
                  Text('Similar Spells', style: Theme.of(context).textTheme.titleMedium),
                  if (state.suggestions.isEmpty)
                    const Text('No similar spells found.')
                  else
                    ...state.suggestions.map(
                      (s) => SpellCard(spell: s, level: state.suggestionLevels[s.id]),
                    ),
                  if (state.status == SpellCreationStatus.error)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        state.errorMessage ?? 'Failed to save spell.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('discard-button'),
                          onPressed: isSaving ? null : () => bloc.add(const SpellDiscarded()),
                          child: const Text('Discard'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('save-button'),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = await showDialog<String>(
                                    context: context,
                                    builder: (dialogContext) => const _SaveSpellDialog(),
                                  );
                                  if (name != null && name.isNotEmpty) {
                                    bloc.add(SpellSaveRequested(name));
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save to Library'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// The Arts selectable as a requisite: every Technique and Form except the
  /// spell's own two, which are what the requisite would be a requisite *to*.
  /// ArsArts and ArsForms overlap on Vim, so the union is de-duplicated.
  static List<String> _selectableRequisiteArts(SpellDraft draft) {
    return <String>{...ArsArts.all, ...ArsForms.all}
        .where((art) => art != draft.technique && art != draft.form)
        .toList()
      ..sort();
  }

  Widget _buildRequisitesSection(
    BuildContext context,
    SpellCreationBloc bloc,
    SpellDraft draft,
  ) {
    final taken = draft.requisites.map((r) => r.art).toSet();
    final available =
        _selectableRequisiteArts(draft).where((art) => !taken.contains(art)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Requisites', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Free requisites cost nothing; adding requisites cost +1 magnitude each.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (draft.requisites.isEmpty)
          const Text('No requisites.')
        else
          ...draft.requisites.map(
            (req) => Padding(
              key: Key('requisite-row-${req.art}'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(req.art)),
                  DropdownButton<RequisiteKind>(
                    key: Key('requisite-kind-${req.art}'),
                    value: req.kind,
                    items: RequisiteKind.values
                        .map((kind) => DropdownMenuItem(
                              value: kind,
                              child: Text(
                                kind == RequisiteKind.adding ? 'Adding (+1)' : 'Free (+0)',
                              ),
                            ))
                        .toList(),
                    onChanged: (kind) {
                      if (kind != null) {
                        bloc.add(RequisiteKindChanged(req.art, kind.name));
                      }
                    },
                  ),
                  IconButton(
                    key: Key('requisite-remove-${req.art}'),
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove ${req.art} requisite',
                    onPressed: () => bloc.add(RequisiteRemoved(req.art)),
                  ),
                ],
              ),
            ),
          ),
        if (available.isNotEmpty)
          // A plain DropdownButton, not a DropdownButtonFormField: this is an
          // action picker, not a field holding a value. Selecting an art moves
          // it into the requisites list and therefore out of `available`, so a
          // FormField's retained selection would match no remaining item and
          // trip Flutter's "exactly one item with value" assertion on the next
          // rebuild. Pinning value to null keeps the hint showing and leaves
          // nothing to go stale.
          DropdownButton<String>(
            key: const Key('requisite-add-dropdown'),
            value: null,
            hint: const Text('Add requisite'),
            isExpanded: true,
            items: available
                .map((art) => DropdownMenuItem(value: art, child: Text(art)))
                .toList(),
            // New requisites default to free, the cheaper and more common
            // case; the user can promote one to adding via its kind dropdown.
            onChanged: (art) {
              if (art != null) {
                bloc.add(RequisiteAdded(art, RequisiteKind.free.name));
              }
            },
          ),
      ],
    );
  }

  Widget _buildParameterDropdown({
    required Key key,
    required String label,
    required String category,
    required List<Parameter> parameters,
    required Parameter? selectedParameter,
    required Function(Parameter?) onChanged,
  }) {
    final categoryParameters =
        parameters.where((p) => p.category == category).toList();

    return DropdownButtonFormField<Parameter>(
      key: key,
      decoration: InputDecoration(labelText: label),
      initialValue: selectedParameter,
      items: categoryParameters
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text('${p.name} (+${p.magnitude})'),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SaveSpellDialog extends StatefulWidget {
  const _SaveSpellDialog();

  @override
  State<_SaveSpellDialog> createState() => _SaveSpellDialogState();
}

class _SaveSpellDialogState extends State<_SaveSpellDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name Your Spell'),
      content: TextField(
        key: const Key('spell-name-field'),
        controller: _controller,
        decoration: const InputDecoration(hintText: 'e.g., Pillar of Flames'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('confirm-save-button'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
