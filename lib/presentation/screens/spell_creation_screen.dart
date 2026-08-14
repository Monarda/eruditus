import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/presentation/widgets/level_breakdown_card.dart';
import 'package:eruditus/presentation/widgets/modifiers_section.dart';
import 'package:eruditus/presentation/widgets/ritual_section.dart';
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
    // Effects/parameters/modifiers are read live from ConfigurationBloc
    // (rather than taken as static constructor lists) so a custom item added
    // in the Settings tab becomes selectable here immediately, without an app
    // restart and without needing to leave/re-enter this tab. Whenever the
    // known modifiers or parameters change, AvailableModifiersSynced /
    // AvailableParametersSynced keep SpellCreationBloc's SpellEngine in sync
    // too: the engine resolves a selected modifier option's magnitude by id
    // lookup, and a General guideline's reference parameter the same way,
    // and would otherwise not recognize a newly added custom one.
    return BlocListener<ConfigurationBloc, ConfigurationState>(
      listenWhen: (previous, current) =>
          previous.modifiers != current.modifiers || previous.parameters != current.parameters,
      listener: (context, configState) {
        context.read<SpellCreationBloc>().add(AvailableModifiersSynced(configState.modifiers));
        context.read<SpellCreationBloc>().add(AvailableParametersSynced(configState.parameters));
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
                    // Base effect descriptions can be long, and a Form switch
                    // swaps in a differently-sized list on the very next
                    // rebuild. Without isExpanded, the field sizes itself to
                    // its widest item's intrinsic width, which briefly
                    // overflows the row during that transition (caught by
                    // the real-bloc pruning integration test in Task 14).
                    isExpanded: true,
                    items: effectsForSelection
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                // A General guideline has no baseLevel to print
                                // (Core Rules leaves that row's level to the
                                // caster) -- printing the literal null would
                                // read as "(Base null)". The numbered case is
                                // untouched: existing tests pin its exact text.
                                '${e.description} (${e.isGeneral ? 'General' : 'Base ${e.baseLevel}'})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) bloc.add(BaseEffectSelected(value));
                    },
                  ),
                if (draft.baseEffect?.isGeneral ?? false) ...[
                  const SizedBox(height: 8),
                  // Controlled, because it is externally settable: picking
                  // "Learn at level…" on a template in the Library tab
                  // (TemplateInstantiated) can set a *new* General base
                  // effect with chosenBaseLevel reset to null while this
                  // screen's widget state survives underneath main.dart's
                  // IndexedStack. isGeneral stays true across that swap, so
                  // the `if` above never flips and this field's Element is
                  // never torn down -- an uncontrolled field would never
                  // re-read initialValue and would keep showing whatever the
                  // previous guideline's level was typed as.
                  _GuidelineLevelField(
                    value: draft.chosenBaseLevel,
                    onChanged: (value) => bloc.add(ChosenBaseLevelChanged(value)),
                  ),
                  if (state.generalEffectSentence != null)
                    Text(state.generalEffectSentence!, key: const Key('general-effect-sentence')),
                ],
                if (draft.baseEffect?.openSlots.contains(OpenSlotKind.realm) ?? false) ...[
                  const SizedBox(height: 8),
                  // ValueKey forces a fresh Element (and a fresh initialValue
                  // read) whenever the chosen realm changes out from under
                  // this field -- e.g. TemplateInstantiated setting a new
                  // pre-filled value while this screen's widget state
                  // survives underneath main.dart's IndexedStack. A dropdown
                  // has no in-progress typing state to lose, unlike
                  // _GuidelineLevelField's text field, so a full StatefulWidget
                  // isn't needed here -- keying by value is sufficient.
                  DropdownButtonFormField<String>(
                    key: ValueKey('chosen-realm-field-${draft.chosenSlots['realm']}'),
                    decoration: const InputDecoration(labelText: 'Realm'),
                    initialValue: draft.chosenSlots['realm'],
                    items: const ['Divine', 'Faerie', 'Infernal', 'Magic']
                        .map((realm) => DropdownMenuItem(value: realm, child: Text(realm)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) bloc.add(OpenSlotChosen('realm', value));
                    },
                  ),
                ],
                if (draft.baseEffect?.openSlots.contains(OpenSlotKind.form) ?? false) ...[
                  const SizedBox(height: 8),
                  // Same ValueKey rationale as the realm dropdown above --
                  // forces a fresh initialValue read on external change
                  // (template instantiation) without needing a StatefulWidget.
                  DropdownButtonFormField<String>(
                    key: ValueKey('chosen-form-field-${draft.chosenSlots['form']}'),
                    decoration: const InputDecoration(labelText: 'Form'),
                    initialValue: draft.chosenSlots['form'],
                    items: ArsForms.all
                        .map((form) => DropdownMenuItem(value: form, child: Text(form)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) bloc.add(OpenSlotChosen('form', value));
                    },
                  ),
                ],
                if (draft.baseEffect?.openSlots.contains(OpenSlotKind.specificType) ?? false) ...[
                  const SizedBox(height: 8),
                  _SpecificTypeField(
                    key: const Key('chosen-specific-type-field'),
                    value: draft.chosenSlots['specificType'],
                    onChanged: (value) => bloc.add(OpenSlotChosen('specificType', value)),
                  ),
                ],
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
                  selectedParameter: draft.range,
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
                  selectedParameter: draft.duration,
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
                  selectedParameter: draft.target,
                  onChanged: (param) {
                    if (param != null) bloc.add(TargetSelected(param));
                  },
                ),
                const SizedBox(height: 16),
                _buildRequisitesSection(context, bloc, draft),
                const SizedBox(height: 16),
                _buildAdjustmentsSection(context, bloc, draft),
                const SizedBox(height: 16),
                ModifiersSection(
                  modifiers: modifiersForSelection,
                  selected: draft.selectedModifiers,
                  onSelect: (modifierId, optionId) =>
                      bloc.add(ModifierOptionSelected(modifierId, optionId)),
                  onDeselect: (modifierId, optionId) =>
                      bloc.add(ModifierOptionDeselected(modifierId, optionId)),
                ),
                const SizedBox(height: 16),
                RitualSection(
                  // Gated the same as LevelBreakdownCard below: state.breakdown
                  // is carried forward by copyWith across edits made after
                  // Calculate, so without this gate the banner would keep
                  // showing a reason computed for a draft the user has since
                  // changed (e.g. still reading "Year duration" after Duration
                  // was switched to Sun).
                  ritualStatus: showResultsBlock
                      ? (state.breakdown?.ritualStatus ?? const RitualStatus.notRitual())
                      : const RitualStatus.notRitual(),
                  declaration: draft.ritualDeclaration,
                  showDeclarationCheckbox: draft.isEligibleForLastingCreationDeclaration,
                  durationName: draft.duration?.name ?? '',
                  targetName: draft.target?.name ?? '',
                  guidelineIsSuggested: draft.baseEffect?.ritualRequirement ==
                      RitualRequirement.suggested,
                  onDeclarationChanged: (declaration) =>
                      bloc.add(RitualDeclarationChanged(declaration)),
                ),
                const SizedBox(height: 16),
                if (state.validationErrors.isNotEmpty)
                  ...state.validationErrors.map(
                    (e) => Text(e, style: const TextStyle(color: Colors.red)),
                  ),
                if (showResultsBlock && state.breakdown != null)
                  LevelBreakdownCard(breakdown: state.breakdown!),
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
                      (s) => SpellCard(
                        entry: s,
                        level: state.suggestionLevels[s.id],
                        isRitual: state.ritualSuggestionIds.contains(s.id),
                        // Missing here would mean a suggested spell built on
                        // a General guideline shows no "Gen" chip, unlike the
                        // Library screen's template cards -- the same badge
                        // should read the same way everywhere it appears.
                        isGeneral: s.baseEffect?.isGeneral ?? false,
                      ),
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
    final taken = draft.requisites.keys.toSet();
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
          ...draft.requisites.entries.map(
            (entry) => Padding(
              key: Key('requisite-row-${entry.key}'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  DropdownButton<RequisiteKind>(
                    key: Key('requisite-kind-${entry.key}'),
                    value: entry.value,
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
                        bloc.add(RequisiteKindChanged(entry.key, kind.name));
                      }
                    },
                  ),
                  IconButton(
                    key: Key('requisite-remove-${entry.key}'),
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove ${entry.key} requisite',
                    onPressed: () => bloc.add(RequisiteRemoved(entry.key)),
                  ),
                ],
              ),
            ),
          ),
        if (available.isNotEmpty)
          // A plain DropdownButton, not a DropdownButtonFormField: this is an
          // action picker, not a field holding a value. Selecting an art moves
          // it into the requisites map and therefore out of `available`, so a
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

  /// The band the adjustment stepper may reach.
  ///
  /// The published corpus spans -1 (*The Severed Limb Made Whole*) to +4, so
  /// this is deliberately much wider — a house rule should not be blocked by
  /// an arbitrary bound. What it does stop is an unbounded stepper: before
  /// this, six taps on a fresh row reached -6, and any spell that far under
  /// its base level has no computable level at all. The buttons disable at
  /// the bound rather than swallowing taps, so the limit is visible.
  static const int _minAdjustmentMagnitude = -5;
  static const int _maxAdjustmentMagnitude = 10;

  Widget _buildAdjustmentsSection(
    BuildContext context,
    SpellCreationBloc bloc,
    SpellDraft draft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Adjustments', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'A one-off magnitude with the prose that justifies it, positive or negative.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (draft.adjustments.isEmpty)
          const Text('No adjustments.')
        else
          for (var index = 0; index < draft.adjustments.length; index++)
            Padding(
              key: Key('adjustment-row-$index'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    key: Key('adjustment-decrement-$index'),
                    icon: const Icon(Icons.remove),
                    tooltip: 'Decrease magnitude',
                    onPressed:
                        draft.adjustments[index].magnitude <= _minAdjustmentMagnitude
                            ? null
                            : () => bloc.add(AdjustmentUpdated(
                                  index,
                                  draft.adjustments[index].magnitude - 1,
                                  draft.adjustments[index].note,
                                )),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${draft.adjustments[index].magnitude}',
                      key: Key('adjustment-magnitude-$index'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    key: Key('adjustment-increment-$index'),
                    icon: const Icon(Icons.add),
                    tooltip: 'Increase magnitude',
                    onPressed:
                        draft.adjustments[index].magnitude >= _maxAdjustmentMagnitude
                            ? null
                            : () => bloc.add(AdjustmentUpdated(
                                  index,
                                  draft.adjustments[index].magnitude + 1,
                                  draft.adjustments[index].note,
                                )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdjustmentNoteField(
                      key: ValueKey('adjustment-note-$index'),
                      note: draft.adjustments[index].note,
                      onCommitted: (note) => bloc.add(AdjustmentUpdated(
                        index,
                        draft.adjustments[index].magnitude,
                        note,
                      )),
                    ),
                  ),
                  IconButton(
                    key: Key('adjustment-remove-$index'),
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove adjustment',
                    onPressed: () => bloc.add(AdjustmentRemoved(index)),
                  ),
                ],
              ),
            ),
        OutlinedButton.icon(
          key: const Key('adjustment-add-button'),
          onPressed: () => bloc.add(const AdjustmentAdded()),
          icon: const Icon(Icons.add),
          label: const Text('Add adjustment'),
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

/// The level field for a General guideline (`BaseEffect.isGeneral`).
///
/// Controlled, because [value] can change out from under this field: picking
/// "Learn at level…" on a *different* General template (TemplateInstantiated)
/// sets a new General base effect with `chosenBaseLevel: null` while this
/// screen's widget state survives underneath main.dart's IndexedStack, so the
/// field's Element is reused rather than recreated (see the doc comment above
/// this widget's call site).
///
/// [didUpdateWidget] resyncs the controller under exactly one condition:
/// `int.tryParse(_controller.text) != widget.value`. Working through why that
/// condition, and no other, is the whole point of this widget:
///  - User types "20" -> the bloc echoes chosenBaseLevel back as 20 ->
///    parse("20") == 20 -> equal -> **not** overwritten. If this fought every
///    incoming value the field would never hold what was just typed.
///  - User types "abc" -> tryParse gives null -> the draft is (still) null ->
///    equal -> **not** overwritten, so a partial or invalid entry is left
///    alone rather than snapped back to empty mid-edit.
///  - User clears the field -> "" parses to null, draft null -> equal ->
///    untouched.
///  - A template swap sets the draft to null while the text still reads "20"
///    -> 20 != null -> **overwritten** to "". This is the one case the
///    condition exists to catch, and the only one where the text should move
///    out from under the user.
class _GuidelineLevelField extends StatefulWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _GuidelineLevelField({required this.value, required this.onChanged});

  @override
  State<_GuidelineLevelField> createState() => _GuidelineLevelFieldState();
}

class _GuidelineLevelFieldState extends State<_GuidelineLevelField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void didUpdateWidget(covariant _GuidelineLevelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (int.tryParse(_controller.text) != widget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('chosen-base-level-field'),
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Guideline level',
        helperText: 'General guidelines have no fixed level — you choose it.',
      ),
      onChanged: (value) => widget.onChanged(int.tryParse(value)),
    );
  }
}

/// The free-text field for [OpenSlotKind.specificType] -- "a specific type
/// of enchantment" per the rulebook's own illustrative-not-exhaustive
/// examples (design spec Decision 4), so this is text input, not a dropdown
/// like realm/Form.
///
/// A real [StatefulWidget], not a bare [TextFormField], for the same reason
/// as [_GuidelineLevelField]: an uncontrolled field seeds itself from
/// `initialValue` exactly once and never resyncs on a later external change
/// (e.g. `TemplateInstantiated` setting a new `chosenSlots` while this
/// screen's widget state survives underneath `main.dart`'s `IndexedStack`).
class _SpecificTypeField extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _SpecificTypeField({super.key, required this.value, required this.onChanged});

  @override
  State<_SpecificTypeField> createState() => _SpecificTypeFieldState();
}

class _SpecificTypeFieldState extends State<_SpecificTypeField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(covariant _SpecificTypeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != (widget.value ?? '')) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      decoration: const InputDecoration(labelText: 'Specific type'),
      onChanged: widget.onChanged,
    );
  }
}

/// The note field for one [LevelAdjustment] row.
///
/// Deliberately a private [StatefulWidget] rather than a bare
/// [TextFormField]: a `TextFormField` with no explicit `controller` seeds its
/// own internal controller from `initialValue` exactly once, at creation, and
/// never resyncs it on a later rebuild that hands the same keyed Element a
/// different `initialValue`. That is exactly what happens here when a row
/// above this one is removed: this row's index (and so its `Key`) now maps
/// to a different adjustment's note, but Flutter reuses the existing Element
/// rather than recreating it. Owning the controller explicitly and resyncing
/// it in [didUpdateWidget] whenever the incoming note differs from what the
/// controller currently shows keeps the field correct across such a
/// reshuffle, while leaving in-progress, uncommitted typing untouched (a
/// rebuild triggered by some other row's edit hands this row the same
/// [note] it already had, so no resync happens).
///
/// Commits on submit or focus loss, not on every keystroke, so typing a note
/// does not re-emit bloc state (and rebuild the whole list) per character.
class _AdjustmentNoteField extends StatefulWidget {
  final String note;
  final ValueChanged<String> onCommitted;

  const _AdjustmentNoteField({
    required Key key,
    required this.note,
    required this.onCommitted,
  }) : super(key: key);

  @override
  State<_AdjustmentNoteField> createState() => _AdjustmentNoteFieldState();
}

class _AdjustmentNoteFieldState extends State<_AdjustmentNoteField> {
  late final TextEditingController _controller = TextEditingController(text: widget.note);
  late final FocusNode _focusNode = FocusNode()..addListener(_handleFocusChange);

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  /// A blank note is not a valid [LevelAdjustment] — the note *is* the
  /// justification — so the bloc keeps the previous note rather than accept
  /// one. Restore the field to what the draft still holds instead of leaving
  /// it visibly empty over a value that did not change: keeping the old note
  /// can leave the bloc's state equal to the one before it, and an equal state
  /// is never emitted, so no rebuild would arrive to resync this controller.
  void _commit() {
    if (_controller.text.trim().isEmpty) {
      _controller.text = widget.note;
      return;
    }
    widget.onCommitted(_controller.text);
  }

  @override
  void didUpdateWidget(covariant _AdjustmentNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note != _controller.text) {
      _controller.text = widget.note;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: const InputDecoration(labelText: 'Note'),
      onFieldSubmitted: (_) => _commit(),
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
