import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/presentation/widgets/spell_card.dart';

class SpellLibraryScreen extends StatefulWidget {
  const SpellLibraryScreen({super.key});

  @override
  State<SpellLibraryScreen> createState() => _SpellLibraryScreenState();
}

class _SpellLibraryScreenState extends State<SpellLibraryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SpellLibraryBloc>().add(const LibraryRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spell Library')),
      body: BlocBuilder<SpellLibraryBloc, SpellLibraryState>(
        builder: (context, state) {
          final bloc = context.read<SpellLibraryBloc>();

          if (state.status == SpellLibraryStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  key: const Key('search-field'),
                  decoration: const InputDecoration(labelText: 'Search spells...'),
                  onChanged: (value) => bloc.add(SearchQueryChanged(value)),
                ),
              ),
              RadioGroup<String>(
                groupValue: state.filter,
                onChanged: (value) {
                  if (value != null) bloc.add(FilterChanged(value));
                },
                child: Row(
                  children: ['All', 'Built-in', 'My Spells'].map((filter) {
                    return Expanded(
                      child: RadioListTile<String>(
                        title: Text(filter),
                        value: filter,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView(
                  children: state.visibleSpells
                      .map((s) => SpellCard(spell: s, level: state.spellLevels[s.id]))
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
