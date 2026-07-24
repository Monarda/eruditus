import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuration'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Effects'),
            Tab(text: 'Parameters'),
            Tab(text: 'Special Factors'),
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
                _FactorsTab(
                  factors: state.factors,
                  onDelete: (id) => bloc.add(CustomFactorDeleted(id)),
                  onAdd: (f) => bloc.add(CustomFactorAdded(f)),
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
    return Scaffold(
      body: ListView(
        children: effects.map((e) {
          final isCustom = e.source == 'user-created';
          return ListTile(
            title: Text(e.description),
            subtitle: Text('${e.technique} ${e.form} • Base ${e.baseLevel}'),
            trailing: isCustom
                ? IconButton(
                    key: Key('delete-effect-${e.id}'),
                    icon: const Icon(Icons.delete),
                    onPressed: () => onDelete(e.id),
                  )
                : const Text('Built-in'),
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
    return AlertDialog(
      title: const Text('Add Custom Effect'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('new-effect-technique'),
              decoration: const InputDecoration(labelText: 'Technique'),
              items: ArsArts.all.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _technique = v),
            ),
            DropdownButtonFormField<String>(
              key: const Key('new-effect-form'),
              decoration: const InputDecoration(labelText: 'Form'),
              items: ArsForms.all.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() => _form = v),
            ),
            TextField(
              key: const Key('new-effect-description'),
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              key: const Key('new-effect-level'),
              controller: _levelController,
              decoration: const InputDecoration(labelText: 'Base Level'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          key: const Key('confirm-add-effect'),
          onPressed: () {
            final level = int.tryParse(_levelController.text);
            if (_technique == null || _form == null || _descriptionController.text.isEmpty || level == null) {
              return;
            }
            Navigator.of(context).pop(BaseEffect(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              technique: _technique!,
              form: _form!,
              description: _descriptionController.text,
              baseLevel: level,
              source: 'user-created',
            ));
          },
          child: const Text('Add'),
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
    return Scaffold(
      body: ListView(
        children: parameters.map((p) {
          final isCustom = p.source == 'user-created';
          return ListTile(
            title: Text(p.name),
            subtitle: Text('${p.category} • Magnitude +${p.magnitude}'),
            trailing: isCustom
                ? IconButton(
                    key: Key('delete-parameter-${p.id}'),
                    icon: const Icon(Icons.delete),
                    onPressed: () => onDelete(p.id),
                  )
                : const Text('Built-in'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Parameter'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('new-parameter-name'),
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          DropdownButtonFormField<String>(
            key: const Key('new-parameter-category'),
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          TextField(
            key: const Key('new-parameter-magnitude'),
            controller: _magnitudeController,
            decoration: const InputDecoration(labelText: 'Magnitude'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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
              source: 'user-created',
            ));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _FactorsTab extends StatelessWidget {
  final List<SpecialFactor> factors;
  final void Function(String id) onDelete;
  final void Function(SpecialFactor factor) onAdd;

  const _FactorsTab({required this.factors, required this.onDelete, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: factors.map((f) {
          final isCustom = f.source == 'user-created';
          return ListTile(
            title: Text('${f.name} (+${f.magnitude})'),
            subtitle: Text('${f.technique} ${f.form} • ${f.description}'),
            trailing: isCustom
                ? IconButton(
                    key: Key('delete-factor-${f.id}'),
                    icon: const Icon(Icons.delete),
                    onPressed: () => onDelete(f.id),
                  )
                : const Text('Built-in'),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-factor-button'),
        onPressed: () async {
          final result = await showDialog<SpecialFactor>(
            context: context,
            builder: (_) => const _AddFactorDialog(),
          );
          if (result != null) onAdd(result);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddFactorDialog extends StatefulWidget {
  const _AddFactorDialog();

  @override
  State<_AddFactorDialog> createState() => _AddFactorDialogState();
}

class _AddFactorDialogState extends State<_AddFactorDialog> {
  String? _technique;
  String? _form;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _magnitudeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Special Factor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('new-factor-technique'),
              decoration: const InputDecoration(labelText: 'Technique'),
              items: ArsArts.all.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _technique = v),
            ),
            DropdownButtonFormField<String>(
              key: const Key('new-factor-form'),
              decoration: const InputDecoration(labelText: 'Form'),
              items: ArsForms.all.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() => _form = v),
            ),
            TextField(
              key: const Key('new-factor-name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              key: const Key('new-factor-description'),
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              key: const Key('new-factor-magnitude'),
              controller: _magnitudeController,
              decoration: const InputDecoration(labelText: 'Magnitude'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          key: const Key('confirm-add-factor'),
          onPressed: () {
            final magnitude = int.tryParse(_magnitudeController.text);
            if (_technique == null || _form == null || _nameController.text.isEmpty ||
                _descriptionController.text.isEmpty || magnitude == null) {
              return;
            }
            Navigator.of(context).pop(SpecialFactor(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              technique: _technique!,
              form: _form!,
              name: _nameController.text,
              description: _descriptionController.text,
              magnitude: magnitude,
              source: 'user-created',
            ));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
