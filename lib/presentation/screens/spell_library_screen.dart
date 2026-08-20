import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/models/resolved_exception.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/presentation/widgets/spell_card.dart';

// The filter list's *values* ('All' | 'Published' | 'My Spells') are also the
// comparison keys SpellLibraryState.filter checks against
// (spell_library_state.dart:48,65,82) -- they stay these literal English
// strings on purpose, never localised, so filtering keeps working under
// every locale. Only the label each RadioListTile *displays* is localised,
// via this mapping, so the two are decoupled: the key an event carries is
// never the same value as the text a caster reads.
const _filterKeys = ['All', 'Published', 'My Spells'];

String _filterLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'Published':
      return l10n.published;
    case 'My Spells':
      return l10n.mySpells;
    default:
      return l10n.filterAll;
  }
}

class SpellLibraryScreen extends StatefulWidget {
  // Lets a caller move focus to the Create tab once a template has been
  // turned into a draft (see "Learn at level…" below). Optional: this screen
  // has no route to _MainTabView's tab index on its own, and existing widget
  // tests build a bare SpellLibraryScreen with nothing to switch to.
  final VoidCallback? onTemplateLearned;

  const SpellLibraryScreen({super.key, this.onTemplateLearned});

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.spellLibraryTitle)),
      body: BlocBuilder<SpellLibraryBloc, SpellLibraryState>(
        builder: (context, state) {
          final bloc = context.read<SpellLibraryBloc>();

          if (state.status == SpellLibraryStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final templates = state.visibleTemplates;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  key: const Key('search-field'),
                  decoration: InputDecoration(labelText: l10n.searchSpellsHint),
                  onChanged: (value) => bloc.add(SearchQueryChanged(value)),
                ),
              ),
              RadioGroup<String>(
                groupValue: state.filter,
                onChanged: (value) {
                  if (value != null) bloc.add(FilterChanged(value));
                },
                child: Row(
                  children: _filterKeys.map((filter) {
                    return Expanded(
                      child: RadioListTile<String>(
                        title: Text(_filterLabel(l10n, filter)),
                        value: filter,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    // Templates get their own section above the spells rather
                    // than a sort control (there is none on this screen) or a
                    // merge into one list -- a General guideline has no level
                    // of its own, so it reads oddly interleaved among leveled
                    // spells. Omitted entirely when empty, rather than a
                    // heading over nothing.
                    if (templates.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(l10n.generalSpellsHeader),
                      ),
                      ...templates.map((t) => _TemplateCard(
                            template: t,
                            onTemplateLearned: widget.onTemplateLearned,
                          )),
                    ],
                    ...state.visibleSpells.map((s) => SpellCard(
                          entry: s,
                          level: state.spellLevels[s.id],
                          isRitual: state.ritualSpellIds.contains(s.id),
                          problems: s.problems,
                        )),
                    // Exceptions get their own section below the leveled
                    // spells, the same reasoning as the Templates section
                    // above them: these six are curiosities the rulebook
                    // itself says don't follow guideline design, not the
                    // primary actionable content this screen exists for.
                    // Omitted entirely when empty, matching the Templates
                    // section's own convention.
                    if (state.visibleExceptions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(l10n.exceptionsHeader),
                      ),
                      ...state.visibleExceptions.map((e) => _ExceptionCard(entry: e)),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One General template's card, with its "Learn at level…" action.
///
/// A separate widget rather than inlined in the ListView's map: the button's
/// onPressed needs `context.read<SpellCreationBloc>()`, and that lookup has
/// to happen below `SpellLibraryScreen.build` rather than at its top, because
/// the five pre-existing widget tests provide only a SpellLibraryBloc and
/// would fail a lookup made before any template exists to need one.
class _TemplateCard extends StatelessWidget {
  final ResolvedTemplate template;
  final VoidCallback? onTemplateLearned;

  const _TemplateCard({required this.template, this.onTemplateLearned});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SpellCard(
      entry: template,
      isGeneral: true,
      actions: [
        // There is nothing to build a draft from when the template's own
        // catalog references don't resolve (SpellCreationBloc's
        // TemplateInstantiated handler already refuses such a template), so
        // the button that would ask for one is withheld rather than offered
        // and then silently doing nothing.
        if (template.isResolved)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: Key('learn-${template.id}'),
              onPressed: () {
                context.read<SpellCreationBloc>().add(TemplateInstantiated(template));
                onTemplateLearned?.call();
              },
              child: Text(l10n.learnAtLevel),
            ),
          ),
      ],
    );
  }
}

/// One exception spell's card. No `isGeneral` chip and no action — an
/// exception spell is never instantiable, whether or not it happens to
/// print a level (SpellCard already renders a null [level] as plain
/// "Technique Form" with no level suffix, so the four General-kind
/// exceptions need no special-casing here).
class _ExceptionCard extends StatelessWidget {
  final ResolvedException entry;

  const _ExceptionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return SpellCard(
      entry: entry,
      level: entry.printedLevel,
      isException: true,
      rationale: entry.rationale,
    );
  }
}
