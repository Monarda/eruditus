import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/target_type.dart';
import 'package:eruditus/presentation/widgets/level_banner.dart';
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
                    targetId: draft.target?.id,
                  ))
              .toList();

          final isSaving = state.status == SpellCreationStatus.saving;
          // Narrowed from the old showResultsBlock, which gated the level card
          // and the Save/Discard row too. Only the suggestions are still worth
          // a button (findSimilarSpells plus a calculateBreakdown per
          // candidate); the level is a pure function of the draft and is now
          // always on screen.
          //
          // `calculated` is the marker that the user asked for suggestions and
          // no edit has superseded them: every editing handler emits `editing`,
          // so a list computed against an older level stops being shown. The
          // save lifecycle destroys that marker -- pressing Save moves the
          // status to `saving` and then `saved`/`error` -- which is why the old
          // gate named those statuses too. Reading them as "show the
          // suggestions" was safe only while Save itself sat behind Calculate.
          // Save renders unconditionally now, so a failed save on a
          // never-calculated draft flipped the whole block open and
          // materialised a "Similar Spells" heading over "No similar spells
          // found.", an empty section the user never asked for and one standing
          // between them and the error they did need. So those two statuses no
          // longer *open* the section; they only preserve a list some Calculate
          // actually produced, which is what stops a save taking the
          // suggestions away from under a user who did press the button.
          //
          // `isNotEmpty` is an exact test for that, not a heuristic:
          // SpellCreationBloc's emit funnel empties all three suggestion fields
          // whenever the recomputed breakdown differs from the one already in
          // state. The level moving is the right trigger rather than the draft
          // moving, because a suggestion asserts "similar to level N" and only
          // N can falsify it -- which also covers the case a draft-based
          // predicate missed, a catalog sync moving the level with the draft
          // untouched. So a non-empty list here is always one calculated
          // against the level on screen. It is load-bearing rather than
          // belt-and-braces -- once the save lifecycle has overwritten
          // `calculated`, the list itself is the only remaining evidence that
          // the user ever asked.
          //
          // Note what that does *not* claim. A level-neutral edit -- a summary,
          // a container mode -- leaves the list in state, so a non-empty list
          // is not evidence the draft is unedited, only that its level is
          // unchanged. Nothing here needs the stronger claim: such an edit
          // emits `editing`, which closes the section by the first clause
          // anyway, and if a save then fails the list reopens still valid,
          // measured against a level that never moved. The save dialog's own
          // summary is the same case -- it rebuilds the draft, and only the
          // prose in it.
          final showSuggestions = state.status == SpellCreationStatus.calculated ||
              ((isSaving || state.status == SpellCreationStatus.error) &&
                  state.suggestions.isNotEmpty);

          return Scaffold(
            appBar: AppBar(title: const Text('Create Spell')),
            // The LayoutBuilder exists for the banner alone. A Column lays its
            // non-flex children out with an *unbounded* main-axis constraint,
            // so a LayoutBuilder inside LevelBanner would be told its height
            // may be infinite and could not size its expanded detail against
            // the body it shares with the ListView below. Measuring the body
            // here and handing it down as a real maxHeight is what lets the
            // banner cap itself; see its build method for why the cap must be a
            // fraction of the body rather than of MediaQuery.size.
            body: LayoutBuilder(
              builder: (context, bodyConstraints) => Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: bodyConstraints.maxHeight),
                  child: LevelBanner(
                    breakdown: state.breakdown,
                    unavailableReason: state.levelUnavailableReason,
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const Key('spell-creation-scroll'),
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
                                      '${e.description} (${e.isGeneral ? 'General' : 'Base ${e.baseLevel}'}'
                                      '${e.requiresVirtue == null ? '' : ', requires ${e.requiresVirtue}'})',
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
                        technique: draft.technique,
                        form: draft.form,
                        onChanged: (param) {
                          if (param != null) bloc.add(RangeSelected(param));
                        },
                        peerTarget: draft.target,
                        locked: draft.target?.requiresRangeId != null,
                      ),
                      if (draft.target?.requiresRangeId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${draft.target!.name} requires this Range '
                          '(Houses of Hermes: Mystery Cults, Sensory Magic).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Duration dropdown
                      _buildParameterDropdown(
                        key: const Key('duration-dropdown'),
                        label: 'Duration',
                        category: 'Duration',
                        parameters: configState.parameters,
                        selectedParameter: draft.duration,
                        technique: draft.technique,
                        form: draft.form,
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
                        technique: draft.technique,
                        form: draft.form,
                        onChanged: (param) {
                          if (param != null) bloc.add(TargetSelected(param));
                        },
                        peerRange: draft.range,
                      ),
                      if (draft.target?.targetType == TargetType.container) ...[
                        const SizedBox(height: 12),
                        _ContainerModeField(
                          value: draft.containerMode,
                          targetName: draft.target!.name,
                          onChanged: (mode) => bloc.add(ContainerModeSelected(mode)),
                        ),
                      ],
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
                        // Ungated, unlike before: this used to be forced to
                        // notRitual outside the results block because state.breakdown
                        // was a snapshot carried forward across edits, so the banner
                        // could keep showing a reason computed for a draft the user
                        // had since changed. The breakdown is recomputed on every
                        // emit now, so there is no stale value left to guard against.
                        ritualStatus: state.breakdown?.ritualStatus ?? const RitualStatus.notRitual(),
                        declaration: draft.ritualDeclaration,
                        showLastingCreationOption: draft.isEligibleForLastingCreationDeclaration,
                        rangeName: draft.range?.name ?? '',
                        durationName: draft.duration?.name ?? '',
                        targetName: draft.target?.name ?? '',
                        guidelineIsSuggested: draft.baseEffect?.ritualRequirement ==
                            RitualRequirement.suggested,
                        onDeclarationChanged: (declaration) =>
                            bloc.add(RitualDeclarationChanged(declaration)),
                      ),
                      const SizedBox(height: 16),
                      _SummaryField(
                        key: const Key('summary-field'),
                        value: draft.summary,
                        onChanged: (value) => bloc.add(SummaryChanged(value)),
                      ),
                      if (state.validationErrors.isNotEmpty)
                        ...state.validationErrors.map(
                          (e) => Text(e, style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        key: const Key('calculate-button'),
                        onPressed: () => bloc.add(const SpellCalculated()),
                        child: const Text('Find Similar Spells'),
                      ),
                      if (showSuggestions) ...[
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
                              // Same reasoning as the Gen chip above: this is the
                              // other ResolvedSpell -> SpellCard call site (see
                              // SpellLibraryScreen's), and a flawed suggestion
                              // should read as flawed here too, not just in the
                              // Library.
                              problems: s.problems,
                            ),
                          ),
                      ],
                      // Gated on its own status, outside the block above. It
                      // used to sit inside, which was safe only while the block
                      // and the Save button opened together: a failed save on a
                      // never-calculated draft would otherwise have to open the
                      // whole suggestions section just to render this one line.
                      // It reads as a note on the Save button directly below it
                      // rather than as a tail on the suggestions list, which is
                      // what it always was.
                      if (state.status == SpellCreationStatus.error)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            state.errorMessage ?? 'Failed to save spell.',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      // Outside the suggestions block, unlike before. Discard used
                      // to render only alongside the suggestions, so before the
                      // first button press there was no way to abandon a draft at
                      // all -- the one control whose whole purpose is escaping a
                      // draft you do not want was unreachable until you had asked
                      // for suggestions on it.
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
                              // Disabled with no level as well as mid-save. An
                              // affordance only -- SpellCreationBloc validates the
                              // draft independently on SpellSaveRequested -- but a
                              // draft with no computable level has nothing to save,
                              // and the banner pinned above already says what is
                              // missing, so offering the dialog would only lead to a
                              // rejection the user could have been spared.
                              onPressed: isSaving || state.breakdown == null
                                  ? null
                                  : () async {
                                      final hasProse =
                                          (draft.summary ?? '').trim().isNotEmpty ||
                                              (draft.description ?? '').trim().isNotEmpty;
                                      final result =
                                          await showDialog<({String name, String? summary})>(
                                        context: context,
                                        builder: (dialogContext) =>
                                            _SaveSpellDialog(requiresSummary: !hasProse),
                                      );
                                      if (result != null && result.name.isNotEmpty) {
                                        bloc.add(SpellSaveRequested(result.name,
                                            summary: result.summary));
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
                  ),
                ),
              ],
              ),
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
    required String? technique,
    required String? form,
    required Function(Parameter?) onChanged,
    Parameter? peerRange,
    Parameter? peerTarget,
    bool locked = false,
  }) {
    final categoryParameters = parameters
        .where((p) =>
            p.category == category &&
            p.scope.appliesTo(technique: technique, form: form) &&
            _compatibleWithPeers(p, peerRange: peerRange, peerTarget: peerTarget))
        .toList();

    return DropdownButtonFormField<Parameter>(
      key: key,
      decoration: InputDecoration(labelText: label),
      initialValue: selectedParameter,
      items: categoryParameters
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.requiresVirtue == null
                    ? '${p.name} (+${p.magnitude})'
                    : '${p.name} (+${p.magnitude}, requires ${p.requiresVirtue})'),
              ))
          .toList(),
      onChanged: locked ? null : onChanged,
    );
  }
}

/// Whether [candidate] can be chosen given the peer Range/Target already
/// selected. Mirrors checks 10 and 11. The bloc is what enforces them
/// (`RangeSelected`/`TargetSelected` prune); this only stops the dropdown
/// offering a choice that would immediately be undone.
bool _compatibleWithPeers(
  Parameter candidate, {
  Parameter? peerRange,
  Parameter? peerTarget,
}) {
  if (candidate.category == 'Target') {
    final kind = candidate.targetType;
    if (peerRange != null &&
        kind != null &&
        peerRange.forbidsTargetTypes.contains(kind)) {
      return false;
    }
  }
  if (candidate.category == 'Range') {
    final required = peerTarget?.requiresRangeId;
    if (required != null && candidate.id != required) return false;
    final kind = peerTarget?.targetType;
    if (kind != null && candidate.forbidsTargetTypes.contains(kind)) return false;
  }
  return true;
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

/// The spell's own summary.
///
/// A real [StatefulWidget] owning its controller, for the same reason as
/// [_SpecificTypeField]: an uncontrolled [TextFormField] seeds itself from
/// `initialValue` once and never resyncs. That resync is load-bearing here,
/// not decorative -- a successful save resets the draft to
/// `SpellCreationState.initial()`, and without it this field would keep
/// showing the saved spell's summary over an empty draft.
class _SummaryField extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _SummaryField({super.key, required this.value, required this.onChanged});

  @override
  State<_SummaryField> createState() => _SummaryFieldState();
}

class _SummaryFieldState extends State<_SummaryField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(covariant _SummaryField oldWidget) {
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
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Summary',
        helperText: 'Required. Shown on this spell\'s card in your library.',
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// The static/dynamic choice for a container Target (Core Rules' "Container
/// Targets" sidebar).
///
/// Stateless, unlike [_SummaryField] and [_GuidelineLevelField]: there is no
/// controller to resync, because a segmented button reads its selection
/// straight from [value] on every build.
///
/// [ContainerMode.unstated] is a visible, selectable segment rather than an
/// absence, because it is a real stored value — deferring the decision should
/// be something the user does, not something that happens by not noticing a
/// control.
class _ContainerModeField extends StatelessWidget {
  final ContainerMode value;
  final String targetName;
  final ValueChanged<ContainerMode> onChanged;

  const _ContainerModeField({
    required this.value,
    required this.targetName,
    required this.onChanged,
  });

  static const Map<ContainerMode, String> _labels = {
    ContainerMode.unstated: 'Not stated',
    ContainerMode.static: 'Static',
    ContainerMode.dynamic: 'Dynamic',
  };

  String get _helper {
    switch (value) {
      case ContainerMode.unstated:
        return 'Not recorded. The rulebook fixes this when the spell is '
            'designed, so it is worth deciding.';
      case ContainerMode.static:
        return 'Affects whatever is in the $targetName when cast, and keeps '
            'affecting it even after it leaves.';
      case ContainerMode.dynamic:
        return 'Affects whatever is in the $targetName at the time. Leaving '
            'ends the effect; entering starts it.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Container behaviour',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        SegmentedButton<ContainerMode>(
          key: const Key('container-mode-field'),
          segments: ContainerMode.values
              .map((mode) =>
                  ButtonSegment(value: mode, label: Text(_labels[mode]!)))
              .toList(),
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
        const SizedBox(height: 4),
        Text(_helper, style: Theme.of(context).textTheme.bodySmall),
      ],
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
  /// Whether to collect a summary as well as a name. True when the draft
  /// carries no prose at all -- the summary-or-description rule has to be
  /// satisfied by the time this spell is constructed, and this dialog is the
  /// last point at which it can be.
  final bool requiresSummary;

  const _SaveSpellDialog({required this.requiresSummary});

  @override
  State<_SaveSpellDialog> createState() => _SaveSpellDialogState();
}

class _SaveSpellDialogState extends State<_SaveSpellDialog> {
  final _nameController = TextEditingController();
  final _summaryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (!widget.requiresSummary || _summaryController.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name Your Spell'),
      // Two fields now, not one -- a short viewport with the keyboard up
      // could otherwise overflow the non-scrolling Column below.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('spell-name-field'),
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'e.g., Pillar of Flames'),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.requiresSummary) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('save-dialog-summary-field'),
              controller: _summaryController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Summary',
                hintText: 'What does this spell do?',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('confirm-save-button'),
          // Trimmed to match _canSave's own gate (which trims before checking
          // isNotEmpty) -- otherwise a name or summary of all-whitespace could
          // pass the gate but land untrimmed in the saved record.
          onPressed: _canSave
              ? () => Navigator.of(context).pop((
                  name: _nameController.text.trim(),
                  summary: widget.requiresSummary ? _summaryController.text.trim() : null,
                ))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
