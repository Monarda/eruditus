import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';

class SpellCreationScreen extends StatelessWidget {
  final List<String> techniques;
  final List<String> forms;
  final List<BaseEffect> availableEffects;
  final List<Parameter> availableParameters;
  final List<SpecialFactor> availableFactors;

  const SpellCreationScreen({
    super.key,
    required this.techniques,
    required this.forms,
    required this.availableEffects,
    required this.availableParameters,
    required this.availableFactors,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpellCreationBloc, SpellCreationState>(
      builder: (context, state) {
        final bloc = context.read<SpellCreationBloc>();
        final draft = state.draft;

        final effectsForSelection = availableEffects
            .where((e) => e.technique == draft.technique && e.form == draft.form)
            .toList();
        final factorsForSelection = availableFactors
            .where((f) => f.technique == draft.technique && f.form == draft.form)
            .toList();

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
                items: availableParameters
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
              if (state.status == SpellCreationStatus.calculated)
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
            ],
          ),
        );
      },
    );
  }
}
