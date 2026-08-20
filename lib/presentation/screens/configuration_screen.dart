import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/utils/constants.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ConfigurationBloc>().add(const ConfigurationRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.configurationTitle),
          bottom: TabBar(tabs: [
            Tab(text: l10n.effectsTabLabel),
            Tab(text: l10n.parametersTabLabel),
          ]),
        ),
        body: BlocBuilder<ConfigurationBloc, ConfigurationState>(
          builder: (context, state) {
            final bloc = context.read<ConfigurationBloc>();
            if (state.status == ConfigurationStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return TabBarView(
              children: [
                _EffectsTab(
                  effects: state.effects,
                  onDelete: (id) => bloc.add(CustomEffectDeleted(id)),
                  onAdd: (e) => bloc.add(CustomEffectAdded(e)),
                ),
                _ParametersTab(
                  parameters: state.parameters,
                  onDelete: (id) => bloc.add(CustomParameterDeleted(id)),
                  onAdd: (p) => bloc.add(CustomParameterAdded(p)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EffectsTab extends StatelessWidget {
  final List<BaseEffect> effects;
  final void Function(String id) onDelete;
  final void Function(BaseEffect effect) onAdd;

  const _EffectsTab({required this.effects, required this.onDelete, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: ListView(
        children: effects.map((e) {
          final isCustom = e.provenance.source == PublicationSource.userCreated;
          return ListTile(
            title: Text(e.description),
            // A General guideline has no baseLevel to print (the caster
            // chooses it) -- the literal null would otherwise read as
            // "Base null". Mirrors the same guard in the base-effect dropdown
            // on the creation screen.
            subtitle: Text(
              e.isGeneral
                  ? l10n.effectSummaryGeneral(e.technique, e.form)
                  : l10n.effectSummaryLeveled(e.technique, e.form, e.baseLevel!),
            ),
            trailing: isCustom
                ? IconButton(
                    key: Key('delete-effect-${e.id}'),
                    icon: const Icon(Icons.delete),
                    onPressed: () => onDelete(e.id),
                  )
                : Text(l10n.published),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-effect-button'),
        onPressed: () async {
          final result = await showDialog<BaseEffect>(
            context: context,
            builder: (_) => const _AddEffectDialog(),
          );
          if (result != null) onAdd(result);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddEffectDialog extends StatefulWidget {
  const _AddEffectDialog();

  @override
  State<_AddEffectDialog> createState() => _AddEffectDialogState();
}

class _AddEffectDialogState extends State<_AddEffectDialog> {
  String? _technique;
  String? _form;
  final _descriptionController = TextEditingController();
  final _levelController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addCustomEffect),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('new-effect-technique'),
              decoration: InputDecoration(labelText: l10n.techniqueLabel),
              items: ArsArts.all.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _technique = v),
            ),
            DropdownButtonFormField<String>(
              key: const Key('new-effect-form'),
              decoration: InputDecoration(labelText: l10n.formLabel),
              items: ArsForms.all.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() => _form = v),
            ),
            TextField(
              key: const Key('new-effect-description'),
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.descriptionLabel),
            ),
            TextField(
              key: const Key('new-effect-level'),
              controller: _levelController,
              decoration: InputDecoration(labelText: l10n.baseLevel),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancelButton)),
        ElevatedButton(
          key: const Key('confirm-add-effect'),
          onPressed: () {
            final level = int.tryParse(_levelController.text);
            // A custom effect is never General (there is no UI here to
            // author a GeneralEffectFormula), so its baseLevel must be a real
            // guideline number. SpellLevelCalculator.calculate now rejects
            // any baseLevel below 1 -- it used to tolerate 0 only because the
            // catalog briefly overloaded 0 as the "General" marker before
            // BaseEffect.isGeneral switched to null. Reject it here too, or a
            // level-0 custom effect creates fine and then throws the first
            // time a spell built on it is calculated.
            if (_technique == null ||
                _form == null ||
                _descriptionController.text.isEmpty ||
                level == null ||
                level < 1) {
              return;
            }
            Navigator.of(context).pop(BaseEffect(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              technique: _technique!,
              form: _form!,
              description: _descriptionController.text,
              baseLevel: level,
              provenance: Provenance(source: PublicationSource.userCreated),
            ));
          },
          child: Text(l10n.addButton),
        ),
      ],
    );
  }
}

class _ParametersTab extends StatelessWidget {
  final List<Parameter> parameters;
  final void Function(String id) onDelete;
  final void Function(Parameter parameter) onAdd;

  const _ParametersTab({required this.parameters, required this.onDelete, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: ListView(
        children: parameters.map((p) {
          final isCustom = p.provenance.source == PublicationSource.userCreated;
          return ListTile(
            title: Text(p.name),
            subtitle: Text(l10n.parameterCategoryAndMagnitude(p.category, p.magnitude)),
            trailing: isCustom
                ? IconButton(
                    key: Key('delete-parameter-${p.id}'),
                    icon: const Icon(Icons.delete),
                    onPressed: () => onDelete(p.id),
                  )
                : Text(l10n.published),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-parameter-button'),
        onPressed: () async {
          final result = await showDialog<Parameter>(
            context: context,
            builder: (_) => const _AddParameterDialog(),
          );
          if (result != null) onAdd(result);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddParameterDialog extends StatefulWidget {
  const _AddParameterDialog();

  @override
  State<_AddParameterDialog> createState() => _AddParameterDialogState();
}

class _AddParameterDialogState extends State<_AddParameterDialog> {
  static const _categories = ['Range', 'Duration', 'Target'];

  String? _category;
  final _nameController = TextEditingController();
  final _magnitudeController = TextEditingController();

  // The dropdown's *values* stay these literal English strings on purpose --
  // they become Parameter.category, which is compared by value elsewhere
  // (e.g. spell_creation_screen.dart's `candidate.category == 'Range'`), the
  // same catalog vocabulary a published Parameter's category already uses.
  // Only the label each item *displays* is localised (via the existing
  // slotRange/slotDuration/slotTarget keys), so the two stay decoupled.
  String _categoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Range':
        return l10n.slotRange;
      case 'Duration':
        return l10n.slotDuration;
      default:
        return l10n.slotTarget;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addCustomParameter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('new-parameter-name'),
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.nameLabel),
          ),
          DropdownButtonFormField<String>(
            key: const Key('new-parameter-category'),
            decoration: InputDecoration(labelText: l10n.categoryLabel),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(_categoryLabel(l10n, c))))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          TextField(
            key: const Key('new-parameter-magnitude'),
            controller: _magnitudeController,
            decoration: InputDecoration(labelText: l10n.magnitudeLabel),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancelButton)),
        ElevatedButton(
          key: const Key('confirm-add-parameter'),
          onPressed: () {
            final magnitude = int.tryParse(_magnitudeController.text);
            if (_category == null || _nameController.text.isEmpty || magnitude == null) return;
            Navigator.of(context).pop(Parameter(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text,
              category: _category!,
              magnitude: magnitude,
              provenance: Provenance(source: PublicationSource.userCreated),
            ));
          },
          child: Text(l10n.addButton),
        ),
      ],
    );
  }
}

