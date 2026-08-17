import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/parameter_triple.dart';
import 'package:eruditus/models/requisite.dart' show RequisiteKind;
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart' show SpellDraft;
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/target_type.dart';

class SpellCreationBloc extends Bloc<SpellCreationEvent, SpellCreationState> {
  final SpellEngine spellEngine;
  final SpellRepository spellRepository;

  // All events are funneled through a single handler (registered on the base
  // `SpellCreationEvent` type) with a sequential transformer, for the same
  // reason as SpellLibraryBloc/ConfigurationBloc: flutter_bloc's default
  // behavior processes events of *different* types concurrently (each
  // `on<E>()` call sets up its own independent subscription), which would let
  // a synchronous SpellDiscarded race ahead of an in-flight, asynchronous
  // SpellSaveRequested and interleave states unpredictably (e.g. a discard
  // getting clobbered by a save that was already in flight). Sequential
  // processing here guarantees events are applied strictly in arrival order.
  SpellCreationBloc({
    required this.spellEngine,
    required this.spellRepository,
  }) : super(_initialState(spellEngine)) {
    on<SpellCreationEvent>(
      _onEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  /// The first thing the Create tab renders: an empty draft seeded at the
  /// standard reference triple, already carrying the reason it has no level.
  ///
  /// A static method taking the engine, rather than an instance one, for the
  /// same reason [_emptySeeded] is: `super(...)` runs before `this` exists, so
  /// the constructor cannot reach [_emit] even though it needs exactly what
  /// [_emit] does. Seeded here rather than in SpellCreationState.initial(),
  /// which has no catalog to resolve ids against -- and must not gain one,
  /// since TemplateInstantiated builds on it and its parameters must survive
  /// verbatim.
  static SpellCreationState _initialState(SpellEngine engine) {
    final draft = _emptySeeded(engine.allParameters);
    final preview = engine.previewLevel(draft);
    return SpellCreationState.initial().copyWith(
      draft: draft,
      breakdown: preview.breakdown,
      levelUnavailableReason: preview.unavailableReason,
    );
  }

  /// Emits [next] with its level recomputed from its own draft.
  ///
  /// **Every emit in this bloc goes through here.** That is the whole point:
  /// the level is a pure function of the draft, so no handler should have to
  /// remember to refresh it, and none can forget. Before this, an edit emitted
  /// `status: editing` and the screen hid the level card until the user pressed
  /// Calculate again -- so the number a caster designs towards was absent
  /// exactly while they were designing (todo item 59), and two level-neutral
  /// events hid it for no reason at all (todo item 58).
  ///
  /// Recomputing unconditionally is cheap: [SpellEngine.previewLevel] walks a
  /// handful of contributions. The expensive half -- findSimilarSpells and a
  /// calculateBreakdown per candidate -- stays behind SpellCalculated.
  ///
  /// A level-neutral edit produces an *equal* breakdown rather than the same
  /// instance, which is why LevelBreakdown, LevelContribution and RitualStatus
  /// carry value equality: SpellCreationState lists breakdown in its props, and
  /// identity comparison would make every state here look changed.
  ///
  /// It also clears [SpellCreationState.validationErrors] whenever the draft
  /// moves -- see the `draftChanged` comment below.
  void _emit(Emitter<SpellCreationState> emit, SpellCreationState next) {
    final preview = spellEngine.previewLevel(next.draft);

    // Whether this emit rebuilt the draft. SpellDraft has no value equality, so
    // `!=` here is identity: true exactly when a handler produced a new draft
    // (they all go through `state.draft.copyWith(...)` or build a fresh one),
    // and false when a handler emitted a status/errors change over the draft it
    // was given. That is precisely the distinction needed below, and it stays
    // correct if SpellDraft ever gains value equality -- an edit that changed
    // nothing has nothing to invalidate either.
    final draftChanged = next.draft != state.draft;

    emit(next.copyWith(
      breakdown: preview.breakdown,
      levelUnavailableReason: preview.unavailableReason,
      // Re-passed rather than omitted, and it is the only field that needs to
      // be. SpellCreationState.copyWith deliberately does *not* carry
      // errorMessage forward -- every emit clears a stale error unless the
      // handler re-states one -- and that rule is written for handler emits,
      // not for this pass-through. Omitted here, the copyWith that attaches the
      // level would silently swallow the message _handleSpellSaveRequested's
      // catch branch had just set, and a failed save would render an error
      // status with nothing to show for it. Every other field either carries
      // forward via `??` or through the `_unset` sentinel.
      errorMessage: next.errorMessage,
      // Validation errors describe the draft they were computed from, so they
      // cannot outlive it. Nothing else cleared them: every edit handler omits
      // the field, copyWith carries it forward, and only a successful
      // SpellCalculated ever reset it -- so saving an incomplete draft, reading
      // "Target must be selected" in red, and then picking a Target left the
      // red text still demanding a Target. Reachable without a Calculate only
      // because Save now renders unconditionally, which is what makes it this
      // task's to fix.
      //
      // This clears; it never populates. Validation stays behind the two button
      // presses on purpose -- its messages render as red "this is broken" text,
      // and recomputing them per keystroke would flag every half-built draft as
      // broken (todo item 59). So an edit that fixes only some of the errors
      // drops all of them rather than showing a stale subset; the user gets the
      // remainder back, computed against the draft they actually have, on their
      // next press. `null` is copyWith's "leave it alone".
      validationErrors: draftChanged ? const <String>[] : null,
      // The same rule as validationErrors above, and it applies harder here.
      // A validation error at least describes the draft in front of you; a
      // suggestion carries a precomputed level (suggestionLevels) that was
      // chosen for being *similar to* a level this draft no longer has, so an
      // edit does not merely date the list, it falsifies the comparison the
      // list exists to make. Before this, an edit only appeared to clear them:
      // the screen stopped showing the section on `status: editing` while the
      // list sat in state, and a save started after that edit put it back --
      // the status moves to saving/error, which the screen must read as "keep
      // showing a calculated list" so a save does not take the suggestions
      // away from a user who did press the button.
      //
      // All three together, not just `suggestions`. They are written by one
      // handler in one emit and keyed to that one list: suggestionLevels and
      // ritualSuggestionIds are maps from the ids in `suggestions`, so leaving
      // them behind an emptied list would keep exactly the stale numbers
      // (a level of 60 against a draft since edited to 70) with nothing left
      // to make them reachable -- dead state that reads as live if anything
      // ever indexes it again.
      //
      // Like validationErrors, this clears and never populates: only
      // SpellCalculated fills these, and its own emit passes no draft, so the
      // predicate is false there and the list survives the emit that built it.
      suggestions: draftChanged ? const <ResolvedSpell>[] : null,
      suggestionLevels: draftChanged ? const <String, int>{} : null,
      ritualSuggestionIds: draftChanged ? const <String>{} : null,
    ));
  }

  Future<void> _onEvent(SpellCreationEvent event, Emitter<SpellCreationState> emit) async {
    if (event is TechniqueSelected) {
      final previousReference = _referenceOf(state.draft);
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(_withSeededParameters(
          state.draft.copyWith(
            technique: event.technique,
            baseEffect: null,
            // A chosen level or template link both point at the base effect
            // that just disappeared -- neither can survive it, for the same
            // reason pruneModifierSelections drops a stranded modifier rather
            // than let it keep affecting the level invisibly. analogyRationale
            // is the same shape as templateId here: it explains why *this*
            // draft's Technique/Form diverged from the base effect that just
            // disappeared, so it cannot survive either -- left in place, a
            // stale rationale can permanently trip check 8's "matches, but a
            // rationale is still set" branch with no UI path to clear it.
            chosenBaseLevel: null,
            templateId: null,
            chosenSlots: const {},
            analogyRationale: null,
          ),
          previousReference,
        )),
        reapplyDefault: false,
      );
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is FormSelected) {
      final previousReference = _referenceOf(state.draft);
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(_withSeededParameters(
          _withPrunedFormScopedParameters(state.draft.copyWith(
            form: event.form,
            baseEffect: null,
            chosenBaseLevel: null,
            templateId: null,
            chosenSlots: const {},
            // See TechniqueSelected above: analogyRationale cannot outlive the
            // base effect it was explaining a divergence from.
            analogyRationale: null,
          )),
          previousReference,
        )),
        reapplyDefault: false,
      );
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is BaseEffectSelected) {
      // Captured before the draft moves: the seed keeps any parameter the
      // user moved off this triple, and re-seeds the ones they never touched.
      final previousReference = _referenceOf(state.draft);
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(_withSeededParameters(
          state.draft.copyWith(
            baseEffect: event.effect,
            // A template link asserts lineage to the *previous* base effect;
            // it cannot survive a change to a new one, General or not.
            templateId: null,
            // Same reasoning as templateId, unconditionally: analogyRationale
            // explains why the draft's Technique/Form diverged from the
            // *previous* base effect specifically. That explanation cannot be
            // assumed to describe a divergence from the newly-selected effect
            // too -- even when the new effect's Technique/Form still happens
            // to differ from the draft's own, the stored prose was written
            // about the old guideline, not this one. Instantiating a fresh
            // by-analogy template (TemplateInstantiated) is the only path that
            // sets it again, with a rationale actually about the effect it
            // names.
            analogyRationale: null,
            // Deliberate: unlike Technique/Form, a chosen level isn't tied to
            // one specific General guideline -- it's "spell level N", equally
            // meaningful against whichever General guideline is selected. Only
            // clear it when the new effect isn't General at all; forcing a
            // re-type on every guideline switch would be friction with no
            // correctness gain.
            chosenBaseLevel: event.effect.isGeneral ? state.draft.chosenBaseLevel : null,
            chosenSlots: _prunedSlots(state.draft.chosenSlots, event.effect),
          ),
          previousReference,
        )),
        reapplyDefault: true,
      );
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is ChosenBaseLevelChanged) {
      final draft = state.draft.copyWith(chosenBaseLevel: event.level);
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is OpenSlotChosen) {
      final updated = {...state.draft.chosenSlots, event.kind: event.value};
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(chosenSlots: updated),
      ));
    } else if (event is RangeSelected) {
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(range: event.parameter),
      ));
    } else if (event is DurationSelected) {
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withRitualDeclaration(
          state.draft.copyWith(duration: event.parameter),
          reapplyDefault: true,
        ),
      ));
    } else if (event is TargetSelected) {
      // The only Technique/Form/BaseEffect/Target handler that didn't prune
      // stale modifier selections — size-mentem's Target exclusion made that
      // a live bug rather than a theoretical gap. See todo item 19.
      //
      // The container mode is pruned here too, for a sharper reason. Unlike
      // the summary (item 13), which is scoped to nothing, the mode is scoped
      // to the Target: a mode stated under Room and left behind under
      // Individual is precisely what validateSpellAgainstCatalog's check 9
      // rejects, so the save would fail with no visible cause. Conditional on
      // the *new* Target's kind, so Room -> Structure keeps the choice.
      final keepsMode = _isContainer(event.parameter);
      final draft = _withPrunedModifiers(state.draft.copyWith(
        target: event.parameter,
        containerMode: keepsMode ? null : ContainerMode.unstated,
      ));
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
      ));
    } else if (event is ContainerModeSelected) {
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(containerMode: event.mode),
      ));
    } else if (event is RequisiteAdded) {
      final kind = event.kind == 'adding' ? RequisiteKind.adding : RequisiteKind.free;
      final updated = {...state.draft.requisites, event.art: kind};
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is RequisiteRemoved) {
      final updated = Map<String, RequisiteKind>.from(state.draft.requisites)
        ..remove(event.art);
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is RequisiteKindChanged) {
      final kind = event.newKind == 'adding' ? RequisiteKind.adding : RequisiteKind.free;
      final updated = {...state.draft.requisites, event.art: kind};
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is AdjustmentAdded) {
      final updated = [
        ...state.draft.adjustments,
        LevelAdjustment(magnitude: 0, note: '(describe this adjustment)'),
      ];
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    } else if (event is AdjustmentRemoved) {
      // Index-keyed, so a stale index from a rebuild-in-flight must be
      // ignored rather than throwing RangeError into the bloc.
      if (event.index < 0 || event.index >= state.draft.adjustments.length) return;
      final updated = [...state.draft.adjustments]..removeAt(event.index);
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    } else if (event is AdjustmentUpdated) {
      if (event.index < 0 || event.index >= state.draft.adjustments.length) return;
      final existing = state.draft.adjustments[event.index];
      // LevelAdjustment rejects a blank note, and the note field commits on
      // every focus loss — so select-all, delete, tab away arrives here as an
      // empty note. Constructing one would throw FormatException out of this
      // handler: no state emitted, the field left showing empty while the
      // draft still held the old value, and the user's next edit operating on
      // stale data. Keep the note the draft already has instead; the magnitude
      // in the event is still honoured.
      final note = event.note.trim().isEmpty ? existing.note : event.note;
      final updated = [...state.draft.adjustments];
      updated[event.index] = LevelAdjustment(magnitude: event.magnitude, note: note);
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    } else if (event is SummaryChanged) {
      // Draft only, and no pruning on the way out -- prose is scoped to no
      // Technique, Form or guideline, so nothing it touches can go stale.
      // The funnel still recomputes the level, as it does for every event;
      // prose cannot move it, so the recomputed breakdown compares equal and
      // the level does not blink while the field is typed (todo item 58).
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(summary: event.summary),
      ));
    } else if (event is ModifierOptionSelected) {
      final modifier =
          spellEngine.allModifiers.where((m) => m.id == event.modifierId).firstOrNull;
      final current = state.draft.selectedModifiers[event.modifierId] ?? const <String>[];
      final updated = modifier?.selectionMode == ModifierSelectionMode.single
          ? [event.optionId]
          : [...current.where((id) => id != event.optionId), event.optionId];
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(selectedModifiers: {
          ...state.draft.selectedModifiers,
          event.modifierId: updated,
        }),
      ));
    } else if (event is ModifierOptionDeselected) {
      final remaining = (state.draft.selectedModifiers[event.modifierId] ?? const <String>[])
          .where((id) => id != event.optionId)
          .toList();
      final updated = {...state.draft.selectedModifiers};
      if (remaining.isEmpty) {
        updated.remove(event.modifierId);
      } else {
        updated[event.modifierId] = remaining;
      }
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(selectedModifiers: updated),
      ));
    } else if (event is AvailableModifiersSynced) {
      spellEngine.updateModifiers(event.modifiers);
      // Re-emits the current state so the funnel recomputes the level against
      // the new catalog. A selected modifier whose magnitude only just became
      // resolvable changes the level, and with the level live that has to show
      // immediately rather than at the next unrelated edit. When nothing moves,
      // the recomputed state compares equal and Bloc emits nothing.
      _emit(emit, state);
    } else if (event is AvailableParametersSynced) {
      spellEngine.updateParameters(event.parameters);
      // The same re-emit, for a different reason than the modifiers above. A
      // parameter catalog change moves the level through _parameterById, which
      // resolves the *reference* triple each parameter is charged as a delta
      // from: a ward guideline referencing Touch scores its Range differently
      // once Touch resolves than while it does not. The draft has not changed,
      // but what the engine makes of it has.
      _emit(emit, state);
    } else if (event is RitualDeclarationChanged) {
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(ritualDeclaration: event.declaration),
      ));
    } else if (event is TemplateInstantiated) {
      final template = event.template;
      // The repository never hands out an unresolved template for this
      // purpose in normal use, but a stale reference (a custom effect or
      // parameter deleted between the Library screen's load and the tap)
      // can still reach here. There is nothing to build a draft from, so
      // emit nothing rather than seed one missing a baseEffect/range/
      // duration/target -- the same "degrade, don't half-build" policy
      // ResolvedTemplate/ResolvedSpell already follow.
      if (!template.isResolved) return;

      // A fresh SpellDraft (constructed, not copyWith-ed off state.draft), so
      // it gets a new id -- the in-progress draft, if any, is abandoned
      // rather than mutated in place.
      final draft = _withPrunedModifiers(SpellDraft(
        technique: template.technique,
        form: template.form,
        baseEffect: template.baseEffect,
        range: template.range,
        duration: template.duration,
        target: template.target,
        selectedModifiers: template.selectedModifiers,
        requisites: template.requisites,
        adjustments: template.adjustments,
        summary: template.summary,
        description: template.description,
        // Verbatim, NOT run through _withRitualDeclaration. A template's
        // declaration is published catalog data about *this* effect, not
        // something to re-derive from the draft's current Technique/
        // Duration -- Disenchant (Perdo Vim, Momentary) declares
        // lastingCreation, and _withRitualDeclaration only reapplies that
        // default for Creo + Momentary, so routing it through there would
        // silently strip a Ritual status the guideline actually has.
        ritualDeclaration: template.ritualDeclaration,
        containerMode: template.containerMode,
        templateId: template.id,
        chosenSlots: template.chosenSlots,
        analogyRationale: template.analogyRationale,
      ));

      // From SpellCreationState.initial(), not state.copyWith(...): stale
      // suggestions left over from whatever the user was doing before must not
      // follow them into the new spell. The level halves are not carried over
      // either, but they need no clearing here: the funnel overwrites both
      // from this draft on the way out.
      _emit(emit, SpellCreationState.initial().copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
    } else if (event is SpellCalculated) {
      _handleSpellCalculated(emit);
    } else if (event is SpellSaveRequested) {
      await _handleSpellSaveRequested(event, emit);
    } else if (event is SpellDiscarded) {
      _emit(emit, SpellCreationState.initial().copyWith(draft: _emptySeededDraft()));
    }
  }

  /// The sentence [SpellCreationState.generalEffectSentence] should carry for
  /// [draft], or null when there is none to show. Delegates to
  /// SpellEngine.deriveGeneralEffect, which already covers "not General", "no
  /// formula" and "no level chosen yet" -- this just also covers "no base
  /// effect at all", which deriveGeneralEffect can't take a null for.
  String? _generalEffectSentenceFor(SpellDraft draft) {
    final baseEffect = draft.baseEffect;
    if (baseEffect == null) return null;
    return spellEngine
        .deriveGeneralEffect(baseEffect: baseEffect, chosenBaseLevel: draft.chosenBaseLevel)
        ?.sentence;
  }

  /// Drops any `chosenSlots` entry [effect] no longer declares open — the
  /// map-keyed sibling of `chosenBaseLevel: null`'s clearing above. `null`
  /// [effect] (Technique/Form changed, base effect cleared) drops everything.
  Map<String, String> _prunedSlots(Map<String, String> slots, BaseEffect? effect) {
    if (effect == null) return const {};
    final openKindNames = effect.openSlots.map((k) => k.name).toSet();
    return Map.fromEntries(
      slots.entries.where((entry) => openKindNames.contains(entry.key)),
    );
  }

  SpellDraft _withPrunedModifiers(SpellDraft draft) => draft.copyWith(
        selectedModifiers: spellEngine.pruneModifierSelections(
          selectedModifiers: draft.selectedModifiers,
          technique: draft.technique,
          form: draft.form,
          baseEffectId: draft.baseEffect?.id,
          targetId: draft.target?.id,
        ),
      );

  /// Nulls out any of [SpellDraft.range]/[SpellDraft.duration]/[SpellDraft.target]
  /// that are no longer valid for [draft]'s (already-updated) Form.
  ///
  /// A Form-scoped parameter (e.g. Fire, Ignem/Imaginem only) selected under
  /// one Form must not survive a change to a Form it isn't offered for --
  /// exactly the same principle as pruneModifierSelections dropping a
  /// stranded modifier rather than let it keep affecting the level
  /// invisibly. Left in place, DropdownButtonFormField's own assertion that
  /// its value be present in `items` would fail, since the dropdown filters
  /// its items by the new Form's scope. Only the parameters that actually go
  /// out of scope are cleared; one still valid for the new Form is left
  /// untouched.
  SpellDraft _withPrunedFormScopedParameters(SpellDraft draft) {
    Parameter? pruneIfOutOfScope(Parameter? parameter) =>
        parameter != null && !parameter.scope.appliesTo(form: draft.form) ? null : parameter;

    return draft.copyWith(
      range: pruneIfOutOfScope(draft.range),
      duration: pruneIfOutOfScope(draft.duration),
      target: pruneIfOutOfScope(draft.target),
    );
  }

  /// The reference triple [draft]'s guideline is priced against, or the
  /// standard Personal/Momentary/Individual when no guideline is selected.
  ///
  /// [BaseEffect.reference] already *defaults* to `ParameterTriple.standard()`
  /// -- in the constructor (`base_effect.dart:122`) and again when the field
  /// is absent from JSON (`:153-155`). So "the guideline's reference where
  /// explicit, the fixed default otherwise" and "always `baseEffect.reference`"
  /// are the same rule, and this is the second one. There is deliberately no
  /// is-this-explicit predicate; see todo item 60.
  static ParameterTriple _referenceOf(SpellDraft draft) =>
      draft.baseEffect?.reference ?? const ParameterTriple.standard();

  /// Moves [draft]'s Range/Duration/Target to the zero point its
  /// (already-updated) guideline is priced against.
  ///
  /// A slot is re-seeded only when it is null, or when it still holds
  /// [previousReference]'s value for that slot -- i.e. the user never moved it
  /// off the seed. A parameter chosen deliberately survives a guideline
  /// switch. Evaluated one slot at a time, so a caster who picked a Target
  /// keeps it while their untouched Range and Duration follow the new
  /// guideline. That is the same shape of answer BaseEffectSelected already
  /// gives for `chosenBaseLevel` above: a keep-or-clear rule reasoned from
  /// what the value still means, rather than a blanket policy either way.
  ///
  /// It matters because `_parameterContribution` charges each parameter as a
  /// *delta* from the reference. A ward guideline (Touch/Ring/Circle) left at
  /// the blank-draft default contributes -1, -2, 0, which can drive the level
  /// below 1 and tell the caster their spell is broken -- when all that
  /// happened is that the app never put them at the guideline's own start.
  ///
  /// Both lookups degrade rather than throw. An id that does not resolve
  /// leaves the slot untouched, so with an empty [parameters] every slot stays
  /// null -- exactly the behaviour before this rule existed. A candidate out
  /// of scope for the draft's Form, or filed under the wrong category, is
  /// skipped for the same reason _withPrunedFormScopedParameters exists:
  /// writing one in would trip DropdownButtonFormField's assertion that its
  /// value appear in `items`. Both checks mirror _buildParameterDropdown's own
  /// filter (`p.category == category && p.scope.appliesTo(form: form)`) --
  /// the seed writes straight into the same field that dropdown reads, so a
  /// candidate it would never have offered must never land there either. No
  /// catalog reference names a Form-scoped or wrong-category parameter today,
  /// but a custom guideline could.
  ///
  /// `containerMode` is pruned here rather than at each call site, because
  /// every handler that can re-seed a Target can strand a mode. `keepsMode` is
  /// computed from the *resulting* Target, not from whether the seed changed
  /// it: when the seed leaves the Target alone, a mode can only be set if that
  /// Target is already a container (ContainerModeSelected is the only path
  /// that sets one, and TargetSelected prunes it otherwise), so the check is a
  /// no-op in exactly the cases where nothing moved.
  static SpellDraft _seedParameters(
    SpellDraft draft,
    ParameterTriple previousReference,
    List<Parameter> parameters,
  ) {
    final next = _referenceOf(draft);

    Parameter? seed(Parameter? current, String previousId, String nextId, String category) {
      if (current != null && current.id != previousId) return current;
      final candidate = parameters.firstWhereOrNull((p) => p.id == nextId);
      if (candidate == null ||
          candidate.category != category ||
          !candidate.scope.appliesTo(form: draft.form)) {
        return current;
      }
      return candidate;
    }

    final target = seed(draft.target, previousReference.targetId, next.targetId, 'Target');
    final keepsMode = _isContainer(target);

    return draft.copyWith(
      range: seed(draft.range, previousReference.rangeId, next.rangeId, 'Range'),
      duration: seed(draft.duration, previousReference.durationId, next.durationId, 'Duration'),
      target: target,
      containerMode: keepsMode ? null : ContainerMode.unstated,
    );
  }

  /// Whether [parameter] is a container Target -- the one property both
  /// TargetSelected and [_seedParameters] need to decide whether a stated
  /// `containerMode` can survive landing on it.
  static bool _isContainer(Parameter? parameter) => parameter?.targetType == TargetType.container;

  /// [_seedParameters] against the engine's live parameter catalog.
  SpellDraft _withSeededParameters(SpellDraft draft, ParameterTriple previousReference) =>
      _seedParameters(draft, previousReference, spellEngine.allParameters);

  /// A fresh, empty draft -- new id, no guideline -- seeded at the standard
  /// reference triple. The draft every "start over" path resets to.
  SpellDraft _emptySeededDraft() => _emptySeeded(spellEngine.allParameters);

  /// [_emptySeededDraft] without an instance -- the constructor's `super(...)`
  /// argument runs before `this` exists, so it cannot call the instance
  /// method above even though it needs the same draft.
  static SpellDraft _emptySeeded(List<Parameter> parameters) =>
      _seedParameters(SpellDraft(), const ParameterTriple.standard(), parameters);

  /// Re-derives [SpellDraft.ritualDeclaration] after a change to Technique,
  /// Form, base effect or Duration.
  ///
  /// A `lastingCreation` declaration is a statement about *this* effect at
  /// *this* Duration; when either moves out of eligibility the statement has
  /// become false and must go, exactly as pruneModifierSelections drops a
  /// stranded modifier rather than let it keep affecting the level invisibly.
  ///
  /// A `storyguideRuling` is never touched. It is not invalidated by changing
  /// Duration, Technique, Form, or base effect — the declaration is a
  /// judgement call independent of the spell's configuration, and the
  /// three-way RitualSection control now lets a user set it directly.
  SpellDraft _withRitualDeclaration(SpellDraft draft, {required bool reapplyDefault}) {
    if (draft.ritualDeclaration == RitualDeclaration.storyguideRuling) return draft;

    if (!draft.isEligibleForLastingCreationDeclaration) {
      return draft.copyWith(ritualDeclaration: RitualDeclaration.none);
    }
    if (reapplyDefault) {
      return draft.copyWith(ritualDeclaration: RitualDeclaration.lastingCreation);
    }
    return draft;
  }

  void _handleSpellCalculated(Emitter<SpellCreationState> emit) {
    final errors = spellEngine.validateSpellDraft(state.draft);
    if (errors.isNotEmpty) {
      _emit(emit, state.copyWith(status: SpellCreationStatus.editing, validationErrors: errors));
      return;
    }

    // The funnel already computed this draft's breakdown, and validateSpellDraft
    // returning empty just re-ran the same calculation over the same draft --
    // so it is non-null here by construction. Reading it beats a third identical
    // call whose only product is the reference level below.
    final level = state.breakdown!.level;

    final candidateSuggestions = spellEngine.findSimilarSpells(
      state.draft.technique!,
      state.draft.form!,
      referenceLevel: level,
    );

    // Precompute each suggestion's own level and Ritual status (reusing
    // SpellEngine's single calculateBreakdown implementation rather than
    // duplicating the magnitude-summing/Ritual-deriving logic) so cards can
    // display both, matching the library screen's chip.
    //
    // findSimilarSpells already drops a same-Technique-Form spell it cannot
    // compute a level for (adjustments/magnitudes driving it below level 1 —
    // see the comparator there), but this loop guards independently rather
    // than trusting that upstream filtering: a spell reaching here that still
    // throws is dropped from `suggestions` outright, not kept as a level-less
    // card. Unlike the Library screen (which shows every saved spell and so
    // degrades an uncomputable one to a missing-level row), every entry here
    // exists to be compared against the just-calculated level — a spell with
    // no level cannot be "similar to level N", so it is not a suggestion.
    final suggestionLevels = <String, int>{};
    final ritualSuggestionIds = <String>{};
    final suggestions = <ResolvedSpell>[];
    for (final s in candidateSuggestions) {
      try {
        final suggestionBreakdown = spellEngine.calculateBreakdown(
          baseEffect: s.baseEffect!, chosenBaseLevel: s.record.chosenBaseLevel,
          range: s.range!, duration: s.duration!, target: s.target!,
          selectedModifiers: s.selectedModifiers, requisites: s.requisites,
          adjustments: s.adjustments,
          ritualDeclaration: s.ritualDeclaration,
        );
        suggestionLevels[s.id] = suggestionBreakdown.level;
        if (suggestionBreakdown.ritualStatus.isRitual) ritualSuggestionIds.add(s.id);
        suggestions.add(s);
      } on ArgumentError {
        continue;
      }
    }

    _emit(emit, state.copyWith(
      status: SpellCreationStatus.calculated,
      validationErrors: const [],
      suggestions: suggestions,
      suggestionLevels: suggestionLevels,
      ritualSuggestionIds: ritualSuggestionIds,
    ));
  }

  Future<void> _handleSpellSaveRequested(
    SpellSaveRequested event,
    Emitter<SpellCreationState> emit,
  ) async {
    // Save used to render only after a successful Calculate, so the draft
    // reaching here had already been validated. It renders unconditionally now
    // (todo item 59), which makes this the only thing between an invalid draft
    // and the repository. The screen also disables the button while there is no
    // level, but that is an affordance, not a gate -- a dispatched event has to
    // be safe on its own.
    final errors = spellEngine.validateSpellDraft(state.draft);
    if (errors.isNotEmpty) {
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        validationErrors: errors,
      ));
      return;
    }

    _emit(emit, state.copyWith(status: SpellCreationStatus.saving));

    // One event, one atomic save. Dispatching SummaryChanged and then
    // SpellSaveRequested would leave the draft half-updated if the second
    // never arrived. Computed outside the try so the catch branch below can
    // also emit it: the dialog-supplied summary lives only on this local
    // `draft`, never on `state.draft`, so re-emitting `state` on failure
    // would silently drop it and leave a retry finding the dialog empty.
    final draft = event.summary == null
        ? state.draft
        : state.draft.copyWith(summary: event.summary);

    try {
      final spell = draft.toSpell(name: event.name, source: PublicationSource.userCreated);
      await spellRepository.saveSpell(spell);

      // Reset to a fresh, empty draft (with a newly generated id) rather than
      // reusing the just-saved draft/id. This both (a) gives the user a
      // ready-to-go form for their next spell, matching the "Save" action
      // reading as "this spell is done, start the next one" rather than
      // "keep editing the same one", and (b) structurally prevents the
      // previous crash: a subsequent SpellSaveRequested can no longer collide
      // on the same primary key, since the draft backing it is always new.
      _emit(emit, SpellCreationState.initial().copyWith(
        status: SpellCreationStatus.saved,
        savedSpell: spell,
        draft: _emptySeededDraft(),
      ));
    } catch (e) {
      _emit(emit, state.copyWith(
        draft: draft,
        status: SpellCreationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
