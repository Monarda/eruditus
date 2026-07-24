import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/presentation/widgets/spell_card.dart';

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
      listenWhen: (previous, current) => previous.factors != current.factors,
      listener: (context, configState) {
        context.read<SpellCreationBloc>().add(AvailableFactorsSynced(configState.factors));
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
                Text('Parameters', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: draft.parameters
                      .map((p) => Chip(
                            label: Text('${p.parameter.name} (+${p.parameter.magnitude})'),
                            onDeleted: () => bloc.add(ParameterRemoved(p.parameterId)),
                          ))
                      .toList(),
                ),
                DropdownButtonFormField<Parameter>(
                  key: const Key('parameter-dropdown'),
                  decoration: const InputDecoration(labelText: 'Add Parameter'),
                  initialValue: null,
                  items: configState.parameters
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.category}: ${p.name} (+${p.magnitude})'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) bloc.add(ParameterAdded(value));
                  },
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
