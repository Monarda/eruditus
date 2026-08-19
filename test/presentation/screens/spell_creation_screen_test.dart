import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/general_effect_formula.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/target_type.dart';
import 'package:eruditus/presentation/screens/spell_creation_screen.dart';
import 'package:eruditus/utils/constants.dart';

import '../../support/bloc_factories.dart';

/// The screen's own ListView.
///
/// `scrollUntilVisible` with no `scrollable:` requires exactly one Scrollable
/// in the tree, and every TextField builds one -- so the always-present
/// summary field makes the bare form ambiguous. `find.byType(Scrollable).first`
/// is unreliable once more than one screen's worth of Scrollables can be in
/// the tree (see the same problem solved in the integration test), so this
/// anchors on the ListView's own key instead -- `.first` because the summary
/// field's own internal EditableText Scrollable is also a descendant of the
/// keyed ListView, and would otherwise tie for the match. No dependency on
/// setUp state, so this is a plain top-level final rather than reassigned
/// per-test.
final screenScrollable = find
    .descendant(of: find.byKey(const Key('spell-creation-scroll')), matching: find.byType(Scrollable))
    .first;

void main() {
  late MockSpellCreationBloc bloc;
  late MockConfigurationBloc configBloc;

  final creoIgnemEffect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'Create flame', baseLevel: 10,
    provenance: Provenance(source: PublicationSource.userCreated),
  );
  final voiceParam = Parameter(
      id: 'p1', name: 'Voice', category: 'Range', magnitude: 2,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final durationParam = Parameter(
      id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final targetParam = Parameter(
      id: 'p3', name: 'Individual', category: 'Target', magnitude: 8,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  // Same Technique/Form as creoIgnemEffect, so both appear together in one
  // dropdown -- letting a single test prove the numbered case is untouched
  // while the General case now reads correctly (Correction 1).
  final generalWardEffect = BaseEffect(
    id: 'rean-gen', technique: 'Creo', form: 'Ignem',
    description: 'Ward against beings associated with Animal', baseLevel: null,
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );
  final generalRealmEffect = BaseEffect(
    id: 'revi-G1', technique: 'Rego', form: 'Vim',
    description: 'Ward against beings from one realm', baseLevel: null,
    openSlots: const [OpenSlotKind.realm],
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );
  final formSlotEffect = BaseEffect(
    id: 'muvi-G3', technique: 'Muto', form: 'Vim',
    description: 'Totally change spell', baseLevel: null,
    openSlots: const [OpenSlotKind.form],
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );
  final specificTypeSlotEffect = BaseEffect(
    id: 'pevi-G2', technique: 'Perdo', form: 'Vim',
    description: 'Dispel effects of a specific type', baseLevel: null,
    openSlots: const [OpenSlotKind.specificType],
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );
  final eitherSlotEffect = BaseEffect(
    id: 'pevi-G10', technique: 'Perdo', form: 'Vim',
    description: 'Dispel specific enchantment type', baseLevel: null,
    openSlots: const [OpenSlotKind.form, OpenSlotKind.specificType],
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );

  late Parameter range;
  late Parameter duration;
  late Parameter target;

  setUpAll(registerBlocFallbackValues);

  setUp(() {
    range = voiceParam;
    duration = durationParam;
    target = targetParam;
  });

  /// The screen is a lazily-built ListView, so widgets below the fold are
  /// never constructed and finders can't see them. Giving the test surface
  /// enough height for the whole form keeps every section in the tree,
  /// instead of each test having to scroll to whatever it asserts on.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    SpellCreationState state, {
    ConfigurationState? configState,
  }) async {
    useTallSurface(tester);
    bloc = mockSpellCreationBloc(initialState: state);
    configBloc = mockConfigurationBloc(
      initialState: configState ??
          ConfigurationState(
            status: ConfigurationStatus.loaded,
            effects: [creoIgnemEffect],
            parameters: [voiceParam],
          ),
    );
    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SpellCreationBloc>.value(value: bloc),
          BlocProvider<ConfigurationBloc>.value(value: configBloc),
        ],
        child: const SpellCreationScreen(
          techniques: ArsArts.all,
          forms: ArsForms.all,
        ),
      ),
    ));
  }

  testWidgets('selecting a technique dispatches TechniqueSelected', (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());

    await tester.tap(find.byKey(const Key('technique-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Creo').last);
    await tester.pumpAndSettle();

    verify(() => bloc.add(const TechniqueSelected('Creo'))).called(1);
  });

  testWidgets('selecting a form dispatches FormSelected', (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());

    await tester.tap(find.byKey(const Key('form-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ignem').last);
    await tester.pumpAndSettle();

    verify(() => bloc.add(const FormSelected('Ignem'))).called(1);
  });

  testWidgets('selecting a base effect dispatches BaseEffectSelected when one is available',
      (tester) async {
    final draftState = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem'),
    );
    await pumpScreen(tester, draftState);

    await tester.tap(find.byKey(const Key('base-effect-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create flame (Base 10)').last);
    await tester.pumpAndSettle();

    verify(() => bloc.add(BaseEffectSelected(creoIgnemEffect))).called(1);
  });

  testWidgets('tapping the calculate button dispatches SpellCalculated', (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());

    await tester.tap(find.byKey(const Key('calculate-button')));
    await tester.pump();

    verify(() => bloc.add(const SpellCalculated())).called(1);
  });

  testWidgets('renders validation errors when present', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(),
      validationErrors: const [
        'Technique must be selected',
        'Form must be selected',
        'Base effect must be selected',
      ],
    );
    await pumpScreen(tester, state);

    expect(find.text('Technique must be selected'), findsOneWidget);
    expect(find.text('Form must be selected'), findsOneWidget);
    expect(find.text('Base effect must be selected'), findsOneWidget);
  });

  testWidgets('renders the level with no calculation, and its detail on demand',
      (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
      ),
      breakdown: const LevelBreakdown(
        level: 20,
        rawLevel: 20,
        contributions: [
          LevelContribution(label: 'Base effect · Create flame', magnitude: 10, isBase: true),
          LevelContribution(label: 'Range · Voice', magnitude: 2),
        ],
      ),
    );
    await pumpScreen(tester, state);

    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.text('20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('level-banner-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Range · Voice'), findsOneWidget);
  });

  testWidgets('renders the level placeholder before anything is chosen', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.initial,
      draft: SpellDraft(),
      levelUnavailableReason: 'Choose a base effect to see a level.',
    );
    await pumpScreen(tester, state);

    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.text('Choose a base effect to see a level.'), findsOneWidget);
  });

  testWidgets('Discard is reachable before any button press', (tester) async {
    // The escape hatch that did not exist: Discard rendered only inside the
    // results block, so before the first Calculate there was no way to
    // abandon a draft at all.
    await pumpScreen(tester, SpellCreationState.initial());

    await tester.tap(find.byKey(const Key('discard-button')));
    await tester.pump();

    verify(() => bloc.add(const SpellDiscarded())).called(1);
  });

  testWidgets('Save is offered before any button press, but disabled with no level',
      (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());

    final saveButton = tester.widget<ElevatedButton>(find.byKey(const Key('save-button')));
    expect(saveButton.onPressed, isNull,
        reason: 'no level means nothing saveable, and the banner already says why');
  });

  testWidgets('Save is enabled once there is a level', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
      ),
      breakdown: const LevelBreakdown(level: 20, rawLevel: 20, contributions: []),
    );
    await pumpScreen(tester, state);

    final saveButton = tester.widget<ElevatedButton>(find.byKey(const Key('save-button')));
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('suggestions stay behind the button', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
      ),
      breakdown: const LevelBreakdown(level: 20, rawLevel: 20, contributions: []),
    );
    await pumpScreen(tester, state);

    expect(find.text('Similar Spells'), findsNothing,
        reason: 'the level is live but findSimilarSpells is the expensive half');
    expect(find.text('Find Similar Spells'), findsOneWidget);
  });

  testWidgets(
      'editing the draft replaces the Ritual banner with the recomputed breakdown, '
      'leaving no stale reason on screen', (tester) async {
    // Regression test, restated for the live level. The banner used to be
    // gated on the results block because state.breakdown was a snapshot
    // carried forward across edits, and an edit could leave "Ritual: Year
    // duration" on screen over a Momentary draft. SpellCreationBloc now
    // recomputes the breakdown on every emit, so the fix is the emit itself
    // rather than a gate: what must be proved is that the section renders
    // whatever ritualStatus the *current* breakdown carries.
    //
    // Deliberately two plain pumps rather than the StreamController this test
    // used to use. That machinery earns its keep only where a defect appears
    // solely on the rebuild that follows a change (the requisite add-dropdown
    // crash below, where a FormField holds state across it). Nothing here
    // holds state across a rebuild any more -- RitualSection is stateless and
    // reads its status from the breakdown it is handed on every build -- so a
    // second static state proves exactly what a streamed one would, and says
    // so without implying a rebuild-only route that no longer exists.
    final yearParam = Parameter(
        id: 'p-year', name: 'Year', category: 'Duration', magnitude: 4,
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

    final catalog = ConfigurationState(
      status: ConfigurationStatus.loaded,
      effects: [creoIgnemEffect],
      parameters: [voiceParam, yearParam, durationParam, targetParam],
    );

    await pumpScreen(
      tester,
      SpellCreationState(
        status: SpellCreationStatus.calculated,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
          range: range, duration: yearParam, target: target,
        ),
        breakdown: const LevelBreakdown(
          level: 20,
          rawLevel: 20,
          ritualStatus: RitualStatus([RitualReason.ritualOnlyDuration]),
          contributions: [
            LevelContribution(label: 'Base effect · Create flame', magnitude: 10, isBase: true),
          ],
        ),
      ),
      configState: catalog,
    );

    expect(find.byKey(const Key('ritual-banner')), findsOneWidget);
    expect(find.textContaining('Year duration'), findsOneWidget);

    // The user switches Duration away from Year. What SpellCreationBloc's
    // _emit funnel produces is a *recomputed* breakdown for the new draft --
    // no longer a Ritual, and no longer floored to 20 -- not the Year
    // snapshot carried forward.
    await pumpScreen(
      tester,
      SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
          range: range, duration: durationParam, target: target,
        ),
        breakdown: const LevelBreakdown(
          level: 12,
          rawLevel: 12,
          contributions: [
            LevelContribution(label: 'Base effect · Create flame', magnitude: 10, isBase: true),
          ],
        ),
      ),
      configState: catalog,
    );

    // No stale "Ritual: Year duration" over a Momentary draft -- and, unlike
    // before, the level itself stays on screen throughout, which is the whole
    // point of todo item 59.
    expect(find.byKey(const Key('ritual-banner')), findsNothing);
    expect(find.textContaining('Year duration'), findsNothing);
    expect(find.byKey(const Key('level-banner')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  group('the save lifecycle does not open the suggestions section', () {
    // Save renders unconditionally now, so `saving` and `error` are reachable
    // on a draft that was never calculated. The old gate read either status as
    // "show the results block", which materialised a "Similar Spells" heading
    // over "No similar spells found." above the save error -- an empty section
    // the user never asked for, standing between them and the one message they
    // did need. These three pin both directions: the section must not open on
    // a save, and must not close on one either.
    final completeDraft = SpellDraft(
      technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
      range: voiceParam, duration: durationParam, target: targetParam,
    );
    const liveBreakdown = LevelBreakdown(level: 20, rawLevel: 20, contributions: []);

    testWidgets('a save failure on a never-calculated draft shows the error and no '
        'Similar Spells heading', (tester) async {
      await pumpScreen(
        tester,
        SpellCreationState(
          status: SpellCreationStatus.error,
          draft: completeDraft,
          breakdown: liveBreakdown,
          errorMessage: 'disk full',
        ),
      );
      await tester.scrollUntilVisible(
          find.byKey(const Key('save-button')), 200, scrollable: screenScrollable);

      expect(find.text('disk full'), findsOneWidget);
      expect(find.text('Similar Spells'), findsNothing);
      expect(find.text('No similar spells found.'), findsNothing);
    });

    testWidgets('a save failure after a successful Calculate still shows both',
        (tester) async {
      // The regression in the other direction: narrowing the gate to
      // `calculated` alone would take the suggestions away the instant the
      // user pressed Save on them.
      final suggestionRecord = Spell(
        id: 's1',
        name: 'Pillar of Fire',
        baseEffectId: creoIgnemEffect.id,
        technique: 'Creo',
        form: 'Ignem',
        rangeId: voiceParam.id,
        durationId: durationParam.id,
        targetId: targetParam.id,
        requisites: const {},
        description: 'A roaring pillar of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final suggestion = ResolvedSpell(
          record: suggestionRecord, baseEffect: creoIgnemEffect,
          range: voiceParam, duration: durationParam, target: targetParam);

      await pumpScreen(
        tester,
        SpellCreationState(
          status: SpellCreationStatus.error,
          draft: completeDraft,
          breakdown: liveBreakdown,
          errorMessage: 'disk full',
          suggestions: [suggestion],
          suggestionLevels: const {'s1': 10},
        ),
      );
      await tester.scrollUntilVisible(
          find.byKey(const Key('save-button')), 200, scrollable: screenScrollable);

      expect(find.text('disk full'), findsOneWidget);
      expect(find.text('Similar Spells'), findsOneWidget);
      expect(find.text('Pillar of Fire'), findsOneWidget);
    });

    testWidgets('the saving state on a never-calculated draft shows no Similar Spells '
        'heading', (tester) async {
      await pumpScreen(
        tester,
        SpellCreationState(
          status: SpellCreationStatus.saving,
          draft: completeDraft,
          breakdown: liveBreakdown,
        ),
      );
      await tester.scrollUntilVisible(
          find.byKey(const Key('save-button')), 200, scrollable: screenScrollable);

      expect(find.text('Similar Spells'), findsNothing);
      expect(find.text('No similar spells found.'), findsNothing);
    });
  });

  testWidgets('shows suggestions with their level and description when status is calculated',
      (tester) async {
    final suggestionRecord = Spell(
      id: 's1',
      name: 'Pillar of Fire',
      baseEffectId: creoIgnemEffect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: voiceParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const {},
      description: 'A roaring pillar of flame.',
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final suggestion = ResolvedSpell(
      record: suggestionRecord, baseEffect: creoIgnemEffect,
      range: voiceParam, duration: durationParam, target: targetParam);
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      suggestions: [suggestion],
      suggestionLevels: const {'s1': 10},
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.text('Pillar of Fire'), 200, scrollable: screenScrollable);

    expect(find.text('Pillar of Fire'), findsOneWidget);
    expect(find.textContaining('Level 10'), findsWidgets);
    expect(find.text('A roaring pillar of flame.'), findsOneWidget);
  });

  testWidgets('a suggestion built on a General guideline shows the Gen chip', (tester) async {
    final generalSuggestionRecord = Spell(
      id: 's-gen',
      name: 'Ward against the Undying',
      baseEffectId: generalWardEffect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: voiceParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const {},
      description: 'A ward against beings associated with Animal.',
      chosenBaseLevel: 20,
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final generalSuggestion = ResolvedSpell(
      record: generalSuggestionRecord, baseEffect: generalWardEffect,
      range: voiceParam, duration: durationParam, target: targetParam);
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      suggestions: [generalSuggestion],
      suggestionLevels: const {'s-gen': 20},
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.text('Ward against the Undying'), 200, scrollable: screenScrollable);

    expect(find.byKey(const Key('general-chip')), findsOneWidget);
  });

  testWidgets('a suggestion with catalog problems shows the Needs review chip', (tester) async {
    final flawedSuggestionRecord = Spell(
      id: 's-flawed',
      name: 'Miscast Pillar',
      baseEffectId: creoIgnemEffect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: voiceParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      // A requisite naming the spell's own Technique is exactly what
      // validateSpellAgainstCatalog's check 3 rejects -- the simplest way to
      // get a genuinely non-empty ResolvedSpell.problems for this fixture,
      // the same fixture shape spell_library_screen_test.dart uses for the
      // Library screen's equivalent test.
      requisites: const {'Creo': RequisiteKind.adding},
      description: 'A flawed pillar of flame.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final flawedSuggestion = ResolvedSpell(
      record: flawedSuggestionRecord, baseEffect: creoIgnemEffect,
      range: voiceParam, duration: durationParam, target: targetParam);
    // Sanity check on the fixture itself, not the screen.
    expect(flawedSuggestion.problems, isNotEmpty);
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      suggestions: [flawedSuggestion],
      suggestionLevels: const {'s-flawed': 10},
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.text('Miscast Pillar'), 200, scrollable: screenScrollable);

    expect(find.byKey(const Key('needs-review-chip')), findsOneWidget);
    expect(find.byKey(const Key('spell-card-invalid')), findsOneWidget);
  });

  testWidgets('tapping discard dispatches SpellDiscarded', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('discard-button')), 200, scrollable: screenScrollable);

    await tester.tap(find.byKey(const Key('discard-button')));
    await tester.pump();

    verify(() => bloc.add(const SpellDiscarded())).called(1);
  });

  // Supersedes the old 'saving with a name dispatches SpellSaveRequested'
  // test: that draft also had no summary, so under the mandatory-summary
  // dialog it would have blocked on a save it never filled in. This covers
  // the same path -- a summary-less draft saved through the dialog -- while
  // also exercising the new summary field.
  testWidgets('the save dialog asks for a summary when the draft has none', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      // Save is offered unconditionally now, but disabled without a level, so
      // a fixture that exercises the dialog has to carry the breakdown a
      // complete draft like this one really would.
      breakdown: const LevelBreakdown(level: 20, rawLevel: 20, contributions: []),
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200, scrollable: screenScrollable);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save-dialog-summary-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('spell-name-field')), 'My Fireball');
    await tester.enterText(find.byKey(const Key('save-dialog-summary-field')), 'A jet of flame.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-save-button')));
    await tester.pumpAndSettle();

    verify(() => bloc.add(
        const SpellSaveRequested('My Fireball', summary: 'A jet of flame.'))).called(1);
  });

  testWidgets('the save dialog asks only for a name when the draft has a summary',
      (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
        summary: 'Already written.',
      ),
      // As above: Save is disabled without a level, so the dialog can only be
      // reached from a draft that has one.
      breakdown: const LevelBreakdown(level: 20, rawLevel: 20, contributions: []),
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200, scrollable: screenScrollable);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save-dialog-summary-field')), findsNothing);

    await tester.enterText(find.byKey(const Key('spell-name-field')), 'My Fireball');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-save-button')));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const SpellSaveRequested('My Fireball'))).called(1);
  });

  testWidgets('the save dialog blocks confirmation until both fields are filled',
      (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      // Save is offered unconditionally now, but disabled without a level, so
      // a fixture that exercises the dialog has to carry the breakdown a
      // complete draft like this one really would.
      breakdown: const LevelBreakdown(level: 20, rawLevel: 20, contributions: []),
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200, scrollable: screenScrollable);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('spell-name-field')), 'My Fireball');
    await tester.pumpAndSettle();

    final confirm = tester.widget<ElevatedButton>(find.byKey(const Key('confirm-save-button')));
    expect(confirm.onPressed, isNull);
  });

  testWidgets('shows a success SnackBar when a save completes', (tester) async {
    final savedSpell = Spell(
      id: 'saved-1',
      name: 'My Fireball',
      baseEffectId: creoIgnemEffect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: voiceParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const {},
      summary: 'Conjures a bolt of flame.',
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    useTallSurface(tester);
    final states = Stream.fromIterable([
      SpellCreationState(status: SpellCreationStatus.saving, draft: SpellDraft()),
      SpellCreationState(
        status: SpellCreationStatus.saved,
        draft: SpellDraft(),
        savedSpell: savedSpell,
      ),
    ]);
    bloc = mockSpellCreationBloc(
      initialState: SpellCreationState(status: SpellCreationStatus.saving, draft: SpellDraft()),
      states: states,
    );
    configBloc = mockConfigurationBloc(
      initialState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [voiceParam],
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SpellCreationBloc>.value(value: bloc),
          BlocProvider<ConfigurationBloc>.value(value: configBloc),
        ],
        child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
      ),
    ));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('My Fireball'), findsWidgets);
  });

  testWidgets('shows an error SnackBar and keeps the draft visible when saving fails',
      (tester) async {
    useTallSurface(tester);
    final states = Stream.fromIterable([
      SpellCreationState(
        status: SpellCreationStatus.error,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
        errorMessage: 'disk full',
      ),
    ]);
    bloc = mockSpellCreationBloc(
      initialState: SpellCreationState(
        status: SpellCreationStatus.saving,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      ),
      states: states,
    );
    configBloc = mockConfigurationBloc(
      initialState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [voiceParam],
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SpellCreationBloc>.value(value: bloc),
          BlocProvider<ConfigurationBloc>.value(value: configBloc),
        ],
        child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
      ),
    ));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('disk full'), findsWidgets);
    // The Save/Discard controls are still present so the user isn't
    // stranded and can retry.
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200, scrollable: screenScrollable);
    expect(find.byKey(const Key('save-button')), findsOneWidget);
    expect(find.byKey(const Key('discard-button')), findsOneWidget);
  });

  testWidgets('Save and Discard are disabled while a save is in flight', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.saving,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200, scrollable: screenScrollable);

    final saveButton = tester.widget<ElevatedButton>(find.byKey(const Key('save-button')));
    final discardButton = tester.widget<OutlinedButton>(find.byKey(const Key('discard-button')));

    expect(saveButton.onPressed, isNull);
    expect(discardButton.onPressed, isNull);
  });

  testWidgets('shows the base effect list from ConfigurationBloc, not a static constructor list',
      (tester) async {
    final customEffect = BaseEffect(
      id: 'custom-e1', technique: 'Creo', form: 'Ignem',
      description: 'My custom fire effect', baseLevel: 3,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    await pumpScreen(
      tester,
      SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem'),
      ),
      configState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect, customEffect],
        parameters: const [],
      ),
    );

    await tester.tap(find.byKey(const Key('base-effect-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('My custom fire effect (Base 3)'), findsOneWidget);
  });

  testWidgets(
      'the base effect dropdown prints (General) for a General guideline, leaving the '
      'numbered case byte-identical', (tester) async {
    await pumpScreen(
      tester,
      SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem'),
      ),
      configState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect, generalWardEffect],
        parameters: const [],
      ),
    );

    await tester.tap(find.byKey(const Key('base-effect-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Create flame (Base 10)'), findsOneWidget);
    expect(
      find.text('Ward against beings associated with Animal (General)'),
      findsOneWidget,
    );
  });

  group('chosen base level field (General guidelines)', () {
    testWidgets('is absent when the selected base effect is numbered', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect),
      );
      await pumpScreen(tester, state);

      expect(find.byKey(const Key('chosen-base-level-field')), findsNothing);
    });

    testWidgets('is present when the selected base effect is General', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: generalWardEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalWardEffect],
          parameters: const [],
        ),
      );

      expect(find.byKey(const Key('chosen-base-level-field')), findsOneWidget);
    });

    testWidgets(
        'entering a level dispatches ChosenBaseLevelChanged, and the effect sentence '
        'renders once the bloc reports one', (tester) async {
      // A mocked bloc never emits on `add`, so proving the sentence actually
      // renders needs a real state to arrive afterward -- same technique the
      // Ritual-banner and adjustments-list regression tests above use.
      useTallSurface(tester);
      final stateController = StreamController<SpellCreationState>();
      addTearDown(stateController.close);

      final initial = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: generalWardEffect),
      );
      bloc = mockSpellCreationBloc(initialState: initial, states: stateController.stream);
      configBloc = mockConfigurationBloc(
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalWardEffect],
          parameters: const [],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: bloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      await tester.enterText(find.byKey(const Key('chosen-base-level-field')), '20');
      verify(() => bloc.add(const ChosenBaseLevelChanged(20))).called(1);

      expect(find.byKey(const Key('general-effect-sentence')), findsNothing);

      // What the real bloc would emit in response to that event.
      stateController.add(SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem', baseEffect: generalWardEffect, chosenBaseLevel: 20),
        generalEffectSentence: 'Affects beings with Might 20 or less',
      ));
      await tester.pump();

      expect(find.byKey(const Key('general-effect-sentence')), findsOneWidget);
      expect(find.text('Affects beings with Might 20 or less'), findsOneWidget);
    });

    // Regression test for Correction 4: TemplateInstantiated sets a new
    // (also General) base effect and chosenBaseLevel: null while the Create
    // tab's widget state survives underneath an IndexedStack. isGeneral never
    // flips false, so the field's Element is never torn down and an
    // uncontrolled TextFormField would never re-read initialValue -- it would
    // keep showing the level typed for the *previous* guideline over a draft
    // that now holds null.
    testWidgets(
        'a template swap (new General base effect, null chosenBaseLevel) clears a level '
        'typed for the previous guideline', (tester) async {
      useTallSurface(tester);
      final stateController = StreamController<SpellCreationState>();
      addTearDown(stateController.close);

      final otherGeneralEffect = BaseEffect(
        id: 'rean-gen-2', technique: 'Creo', form: 'Ignem',
        description: 'Ward against beings associated with Aquam', baseLevel: null,
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
      );

      final initial = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: generalWardEffect),
      );
      bloc = mockSpellCreationBloc(initialState: initial, states: stateController.stream);
      configBloc = mockConfigurationBloc(
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalWardEffect, otherGeneralEffect],
          parameters: const [],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: bloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      await tester.enterText(find.byKey(const Key('chosen-base-level-field')), '20');
      await tester.pump();
      expect(find.text('20'), findsOneWidget);

      // What TemplateInstantiated's handler emits: a different General base
      // effect and chosenBaseLevel reset to null. The field's `if` guard
      // (isGeneral) never flips, so its Element survives this rebuild.
      stateController.add(SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: otherGeneralEffect),
      ));
      await tester.pump();

      expect(
        tester.widget<TextFormField>(find.byKey(const Key('chosen-base-level-field'))).controller?.text,
        '',
      );
      expect(find.text('20'), findsNothing);
    });

    // The sync condition (int.tryParse(text) != draft.value) must not fight
    // the user's own typing: entering "2" makes the field read "2" and the
    // draft (echoed back by the bloc) become 2, which is equal under that
    // comparison and so must not be overwritten before "0" is typed too.
    testWidgets('typing "2" then "0" is not fought back to leave the field reading "20"',
        (tester) async {
      useTallSurface(tester);
      final stateController = StreamController<SpellCreationState>();
      addTearDown(stateController.close);

      final initial = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: generalWardEffect),
      );
      bloc = mockSpellCreationBloc(initialState: initial, states: stateController.stream);
      configBloc = mockConfigurationBloc(
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalWardEffect],
          parameters: const [],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: bloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      await tester.enterText(find.byKey(const Key('chosen-base-level-field')), '2');
      // The real bloc echoes the parsed value straight back onto the draft.
      stateController.add(SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
            technique: 'Creo', form: 'Ignem', baseEffect: generalWardEffect, chosenBaseLevel: 2),
      ));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('chosen-base-level-field')), '20');
      stateController.add(SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
            technique: 'Creo', form: 'Ignem', baseEffect: generalWardEffect, chosenBaseLevel: 20),
      ));
      await tester.pump();

      expect(find.text('20'), findsOneWidget);
    });
  });

  group('chosen realm field (open realm slot)', () {
    // The widget's key is a ValueKey suffixed with the current chosen realm
    // (e.g. 'chosen-realm-field-null'), not a plain Key -- see the widget's
    // own doc comment for why. A plain find.byKey(const Key(...)) would never
    // match, so match structurally on the key's string value instead.
    Finder findRealmField() => find.byWidgetPredicate((w) =>
        w is DropdownButtonFormField<String> &&
        (w.key as ValueKey).value.toString().startsWith('chosen-realm-field'));

    testWidgets('is absent when the selected base effect declares no open slot', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect),
      );
      await pumpScreen(tester, state);

      expect(findRealmField(), findsNothing);
    });

    testWidgets('is present when the selected base effect declares an open realm slot',
        (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Rego', form: 'Vim', baseEffect: generalRealmEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalRealmEffect],
          parameters: const [],
        ),
      );

      expect(findRealmField(), findsOneWidget);
    });

    testWidgets('picking a realm dispatches OpenSlotChosen', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Rego', form: 'Vim', baseEffect: generalRealmEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalRealmEffect],
          parameters: const [],
        ),
      );

      await tester.tap(findRealmField());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Infernal').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const OpenSlotChosen('realm', 'Infernal'))).called(1);
    });

    testWidgets('a pre-filled chosenSlots value shows as the initial selection', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Rego', form: 'Vim', baseEffect: generalRealmEffect,
          chosenSlots: const {'realm': 'Faerie'},
        ),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalRealmEffect],
          parameters: const [],
        ),
      );

      expect(find.text('Faerie'), findsOneWidget);
    });
  });

  group('chosen form field (open form slot)', () {
    // Same ValueKey-suffix rationale as the realm dropdown's findRealmField
    // helper above -- the widget's key is a ValueKey suffixed with the
    // current chosen form, not a plain Key, so match structurally on the
    // key's string value instead.
    Finder findFormField() => find.byWidgetPredicate((w) =>
        w is DropdownButtonFormField<String> &&
        (w.key as ValueKey).value.toString().startsWith('chosen-form-field'));

    testWidgets('is absent when the selected base effect declares no open slot', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect),
      );
      await pumpScreen(tester, state);

      expect(findFormField(), findsNothing);
    });

    testWidgets('is present when the selected base effect declares an open form slot',
        (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Muto', form: 'Vim', baseEffect: formSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, formSlotEffect],
          parameters: const [],
        ),
      );

      expect(findFormField(), findsOneWidget);
    });

    testWidgets('picking a Form dispatches OpenSlotChosen', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Muto', form: 'Vim', baseEffect: formSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, formSlotEffect],
          parameters: const [],
        ),
      );

      await tester.tap(findFormField());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignem').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const OpenSlotChosen('form', 'Ignem'))).called(1);
    });
  });

  group('chosen specific type field (open specificType slot)', () {
    testWidgets('is absent when the selected base effect declares no open slot', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect),
      );
      await pumpScreen(tester, state);

      expect(find.byKey(const Key('chosen-specific-type-field')), findsNothing);
    });

    testWidgets('is present when the selected base effect declares an open specificType slot',
        (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Perdo', form: 'Vim', baseEffect: specificTypeSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, specificTypeSlotEffect],
          parameters: const [],
        ),
      );

      expect(find.byKey(const Key('chosen-specific-type-field')), findsOneWidget);
    });

    testWidgets('typing a value dispatches OpenSlotChosen', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Perdo', form: 'Vim', baseEffect: specificTypeSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, specificTypeSlotEffect],
          parameters: const [],
        ),
      );

      await tester.enterText(
          find.byKey(const Key('chosen-specific-type-field')), 'Hermetic Terram magic');

      verify(() => bloc.add(const OpenSlotChosen('specificType', 'Hermetic Terram magic')))
          .called(1);
    });

    testWidgets(
        'a chosenSlots value set after the initial build reaches the field '
        '(the didUpdateWidget resync path)', (tester) async {
      useTallSurface(tester);
      final stateController = StreamController<SpellCreationState>();
      addTearDown(stateController.close);

      final initial = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Perdo', form: 'Vim', baseEffect: specificTypeSlotEffect),
      );
      bloc = mockSpellCreationBloc(initialState: initial, states: stateController.stream);
      configBloc = mockConfigurationBloc(
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, specificTypeSlotEffect],
          parameters: const [],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: bloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      expect(find.text('Hermetic Terram magic'), findsNothing);

      // What the real bloc would emit after OpenSlotChosen('specificType', ...)
      // -- pushed onto the SAME widget tree, so this exercises
      // _SpecificTypeFieldState.didUpdateWidget, not just the constructor's
      // initial controller seed.
      stateController.add(SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Perdo', form: 'Vim', baseEffect: specificTypeSlotEffect,
          chosenSlots: const {'specificType': 'Hermetic Terram magic'},
        ),
      ));
      await tester.pump();

      expect(find.text('Hermetic Terram magic'), findsOneWidget);
    });
  });

  group('either/or open slot (form or specificType)', () {
    testWidgets('both controls render when the effect declares both kinds', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Perdo', form: 'Vim', baseEffect: eitherSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, eitherSlotEffect],
          parameters: const [],
        ),
      );

      expect(find.byWidgetPredicate((w) =>
          w is DropdownButtonFormField<String> &&
          (w.key as ValueKey).value.toString().startsWith('chosen-form-field')),
          findsOneWidget);
      expect(find.byKey(const Key('chosen-specific-type-field')), findsOneWidget);
    });
  });

  group('requisites section', () {
    SpellCreationState draftWith(Map<String, RequisiteKind> requisites) => SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(
            technique: 'Creo',
            form: 'Ignem',
            baseEffect: creoIgnemEffect,
            requisites: requisites,
          ),
        );

    testWidgets('shows an empty-state message when the draft has no requisites',
        (tester) async {
      await pumpScreen(tester, draftWith(const {}));
      await tester.scrollUntilVisible(find.text('Requisites'), 200, scrollable: screenScrollable);

      expect(find.text('No requisites.'), findsOneWidget);
    });

    testWidgets('selecting an art from the add dropdown dispatches RequisiteAdded as free',
        (tester) async {
      await pumpScreen(tester, draftWith(const {}));
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-add-dropdown')), 200, scrollable: screenScrollable);

      await tester.tap(find.byKey(const Key('requisite-add-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auram').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const RequisiteAdded('Auram', 'free'))).called(1);
    });

    testWidgets("the add dropdown offers neither the spell's own technique nor its form",
        (tester) async {
      await pumpScreen(tester, draftWith(const {}));
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-add-dropdown')), 200, scrollable: screenScrollable);

      // Creo and Ignem already appear on screen as the selected technique and
      // form, so a bare find.text would match those rather than the menu.
      // Compare counts across opening the menu instead: an offered art adds
      // one more Text, an excluded one leaves the count unchanged.
      final creoBefore = find.text('Creo').evaluate().length;
      final ignemBefore = find.text('Ignem').evaluate().length;

      await tester.tap(find.byKey(const Key('requisite-add-dropdown')));
      await tester.pumpAndSettle();

      // Creo is the technique and Ignem the form, so neither may be offered --
      // the engine rejects such a draft in validateSpellDraft.
      expect(find.text('Creo').evaluate().length, creoBefore);
      expect(find.text('Ignem').evaluate().length, ignemBefore);
      // A valid art is offered, proving the menu did open.
      expect(find.text('Auram'), findsOneWidget);
    });

    testWidgets('an already-selected art is not offered again in the add dropdown',
        (tester) async {
      await pumpScreen(
        tester,
        draftWith({'Auram': RequisiteKind.free}),
      );
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-add-dropdown')), 200, scrollable: screenScrollable);

      await tester.tap(find.byKey(const Key('requisite-add-dropdown')));
      await tester.pumpAndSettle();

      // Auram appears once, in its existing row, but not as a re-addable option.
      expect(find.text('Auram'), findsOneWidget);
    });

    testWidgets('changing a requisite kind dispatches RequisiteKindChanged', (tester) async {
      await pumpScreen(
        tester,
        draftWith({'Auram': RequisiteKind.free}),
      );
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-kind-Auram')), 200, scrollable: screenScrollable);

      await tester.tap(find.byKey(const Key('requisite-kind-Auram')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adding (+1)').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const RequisiteKindChanged('Auram', 'adding'))).called(1);
    });

    testWidgets('tapping remove dispatches RequisiteRemoved', (tester) async {
      await pumpScreen(
        tester,
        draftWith({'Auram': RequisiteKind.adding}),
      );
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-remove-Auram')), 200, scrollable: screenScrollable);

      await tester.tap(find.byKey(const Key('requisite-remove-Auram')));
      await tester.pump();

      verify(() => bloc.add(const RequisiteRemoved('Auram'))).called(1);
    });

    // Regression test for the crash seen in the running app: picking an art
// moves it out of the add dropdown's items, and a DropdownButtonFormField
    // (a FormField, holding its selection internally) is then left with a
    // value that matches no item, tripping Flutter's "exactly one item with
    // [DropdownButton]'s value" assertion on the next rebuild.
    //
    // The other tests here use a mock bloc whose state never changes, so that
    // rebuild never happens and they cannot catch this. Drive the two states
    // through a controller instead, reproducing the real bloc's emit.
    testWidgets('adding a requisite survives the rebuild that removes it from the add dropdown',
        (tester) async {
      useTallSurface(tester);
      final stateController = StreamController<SpellCreationState>();
      addTearDown(stateController.close);

      SpellCreationState stateWith(Map<String, RequisiteKind> requisites) => SpellCreationState(
            status: SpellCreationStatus.editing,
            draft: SpellDraft(
              technique: 'Creo',
              form: 'Ignem',
              baseEffect: creoIgnemEffect,
              requisites: requisites,
            ),
          );

      bloc = mockSpellCreationBloc(
        initialState: stateWith(const {}),
        states: stateController.stream,
      );
      configBloc = mockConfigurationBloc(
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect],
          parameters: [voiceParam],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: bloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      await tester.tap(find.byKey(const Key('requisite-add-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auram').last);
      await tester.pumpAndSettle();

      // What the real bloc emits in response: Auram is now a requisite, so it
      // is no longer offered in the add dropdown.
      stateController.add(stateWith({'Auram': RequisiteKind.free}));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('requisite-row-Auram')), findsOneWidget);
    });

    testWidgets('renders a row per requisite when several are present', (tester) async {
      await pumpScreen(
        tester,
        draftWith({
          'Auram': RequisiteKind.free,
          'Terram': RequisiteKind.adding,
          'Rego': RequisiteKind.adding,
        }),
      );
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-row-Auram')), 200, scrollable: screenScrollable);

      expect(find.byKey(const Key('requisite-row-Auram')), findsOneWidget);
      expect(find.byKey(const Key('requisite-row-Terram')), findsOneWidget);
      expect(find.byKey(const Key('requisite-row-Rego')), findsOneWidget);
      expect(find.text('No requisites.'), findsNothing);
    });
  });

  group('adjustments section', () {
    SpellCreationState stateWithMagnitude(int magnitude) => SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(
            id: 'draft-1',
            adjustments: [LevelAdjustment(magnitude: magnitude, note: 'a note')],
          ),
        );

    IconButton stepper(WidgetTester tester, String key) =>
        tester.widget<IconButton>(find.byKey(Key(key)));

    testWidgets('the magnitude stepper is enabled inside its band', (tester) async {
      await pumpScreen(tester, stateWithMagnitude(0));

      expect(stepper(tester, 'adjustment-decrement-0').onPressed, isNotNull);
      expect(stepper(tester, 'adjustment-increment-0').onPressed, isNotNull);
    });

    testWidgets('the decrement button is disabled at the floor', (tester) async {
      // Unbounded before this: six taps on a fresh row reached -6, and the
      // spell it produced had no computable level. Disabled at the bound, not
      // silently ignoring the tap.
      await pumpScreen(tester, stateWithMagnitude(-5));

      expect(stepper(tester, 'adjustment-decrement-0').onPressed, isNull);
      expect(stepper(tester, 'adjustment-increment-0').onPressed, isNotNull);
    });

    testWidgets('the increment button is disabled at the ceiling', (tester) async {
      await pumpScreen(tester, stateWithMagnitude(10));

      expect(stepper(tester, 'adjustment-increment-0').onPressed, isNull);
      expect(stepper(tester, 'adjustment-decrement-0').onPressed, isNotNull);
    });

    testWidgets('removing a row leaves the surviving notes on the right rows',
        (tester) async {
      // A mocked bloc emits no new state, so an interaction never triggers the
      // rebuild — which is exactly how the add-requisite crash stayed invisible
      // to six passing widget tests (todo item 6). Drive real states through a
      // controller so the rebuild actually happens.
      useTallSurface(tester);
      final controller = StreamController<SpellCreationState>.broadcast();
      addTearDown(controller.close);

      SpellCreationState stateWith(List<String> notes) => SpellCreationState(
            status: SpellCreationStatus.editing,
            draft: SpellDraft(
              id: 'draft-1',
              adjustments: [
                for (var i = 0; i < notes.length; i++)
                  LevelAdjustment(magnitude: i + 1, note: notes[i]),
              ],
            ),
          );

      final initial = stateWith(['first', 'second', 'third']);
      bloc = mockSpellCreationBloc(initialState: initial, states: controller.stream);
      configBloc = mockConfigurationBloc(
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect],
          parameters: [voiceParam],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: bloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(
            techniques: ArsArts.all,
            forms: ArsForms.all,
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('second'), findsOneWidget);

      // Now the middle row goes away.
      final after = stateWith(['first', 'third']);
      when(() => bloc.state).thenReturn(after);
      controller.add(after);
      await tester.pump();
      await tester.pump();

      expect(find.text('first'), findsOneWidget);
      expect(find.text('third'), findsOneWidget);
      expect(find.text('second'), findsNothing,
          reason: 'a stale TextEditingController would keep rendering the '
              'removed row’s text against a surviving row');
    });
  });

  testWidgets('a Form-scoped parameter is hidden from the dropdown on a non-matching Form',
      (tester) async {
    final fireParam = Parameter(
      id: 'duration-fire', name: 'Fire', category: 'Duration', magnitude: 3,
      requiresRitual: true,
      requiresVirtue: 'Faerie Magic',
      scope: const ParameterScope(forms: ['Ignem', 'Imaginem']),
      provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
    );
    final draftState = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(technique: 'Creo', form: 'Terram'),
    );
    await pumpScreen(
      tester,
      draftState,
      configState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [durationParam, fireParam],
      ),
    );

    await tester.tap(find.byKey(const Key('duration-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Fire (+3, requires Faerie Magic)'), findsNothing);
  });

  testWidgets('a Form-scoped parameter appears in the dropdown on a matching Form',
      (tester) async {
    final fireParam = Parameter(
      id: 'duration-fire', name: 'Fire', category: 'Duration', magnitude: 3,
      requiresRitual: true,
      requiresVirtue: 'Faerie Magic',
      scope: const ParameterScope(forms: ['Ignem', 'Imaginem']),
      provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
    );
    final draftState = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem'),
    );
    await pumpScreen(
      tester,
      draftState,
      configState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [durationParam, fireParam],
      ),
    );

    await tester.tap(find.byKey(const Key('duration-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Fire (+3, requires Faerie Magic)'), findsOneWidget);
  });

  testWidgets('a Virtue-gated base effect shows a requirement note in the dropdown',
      (tester) async {
    final gatedEffect = BaseEffect(
      id: 'crvi-hohmc-G1', technique: 'Creo', form: 'Vim',
      description: 'Bind a supernatural creature as a temporary familiar',
      baseLevel: null,
      requiresVirtue: 'Faerie Magic',
      ritualRequirement: RitualRequirement.required,
      effectFormula: const GeneralEffectFormula(
          kind: GeneralEffectKind.mightThreshold, offsetMagnitudes: -3),
      provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-hohmc')]),
    );
    final draftState = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(technique: 'Creo', form: 'Vim'),
    );
    await pumpScreen(
      tester,
      draftState,
      configState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [gatedEffect],
        parameters: [voiceParam],
      ),
    );

    await tester.tap(find.byKey(const Key('base-effect-dropdown')));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Bind a supernatural creature as a temporary familiar (General, requires Faerie Magic)'),
      findsOneWidget,
    );
  });

  testWidgets('typing a summary dispatches SummaryChanged', (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());
    await tester.scrollUntilVisible(find.byKey(const Key('summary-field')), 200, scrollable: screenScrollable);

    await tester.enterText(find.byKey(const Key('summary-field')), 'A jet of flame.');
    await tester.pump();

    verify(() => bloc.add(const SummaryChanged('A jet of flame.'))).called(1);
  });

  testWidgets('the summary field shows the draft summary', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(summary: 'Seeded from a template.'),
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('summary-field')), 200, scrollable: screenScrollable);

    expect(find.text('Seeded from a template.'), findsOneWidget);
  });

  testWidgets(
      'the draft resetting to SpellCreationState.initial() after a save clears the summary '
      'field (the didUpdateWidget resync path)', (tester) async {
    useTallSurface(tester);
    final stateController = StreamController<SpellCreationState>();
    addTearDown(stateController.close);

    final initial = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(summary: 'Seeded from a template.'),
    );
    bloc = mockSpellCreationBloc(initialState: initial, states: stateController.stream);
    configBloc = mockConfigurationBloc(
      initialState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [voiceParam],
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SpellCreationBloc>.value(value: bloc),
          BlocProvider<ConfigurationBloc>.value(value: configBloc),
        ],
        child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
      ),
    ));
    await tester.scrollUntilVisible(find.byKey(const Key('summary-field')), 200, scrollable: screenScrollable);

    expect(find.text('Seeded from a template.'), findsOneWidget);

    // What the real bloc emits after a successful save -- pushed onto the
    // SAME widget tree, so this exercises _SummaryFieldState.didUpdateWidget,
    // not just the constructor's initial controller seed.
    stateController.add(SpellCreationState.initial());
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('summary-field')), 200, scrollable: screenScrollable);

    expect(find.text('Seeded from a template.'), findsNothing);
  });

  group('container mode field', () {
    // targetParam (top of file) is the pre-existing 'Individual' fixture and
    // carries no targetType (null), so it already stands in for a
    // non-container Target -- only a fresh container fixture is needed here.
    final roomTarget = Parameter(
      id: 'p-target-room', name: 'Room', category: 'Target', magnitude: 10,
      targetType: TargetType.container,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

    SpellCreationState stateWithTarget(Parameter? selectedTarget) => SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(
            technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
            range: range, duration: duration, target: selectedTarget,
          ),
        );

    Future<void> pumpWithTargetCatalog(
        WidgetTester tester, StreamController<SpellCreationState> controller) async {
      useTallSurface(tester);
      bloc = mockSpellCreationBloc(
        initialState: stateWithTarget(null),
        states: controller.stream,
      );
      configBloc = mockConfigurationBloc(
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect],
          parameters: [voiceParam, durationParam, targetParam, roomTarget],
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: bloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));
    }

    // Drives the Target dropdown to [param], then pushes the state the real
    // bloc's TargetSelected handler would emit -- the mocked bloc used
    // elsewhere in this file never updates its exposed state on `add`, so
    // proving the conditional control reacts to a Target change needs a real
    // state stream, the same technique the Ritual-banner and summary-resync
    // tests above use.
    Future<void> selectTarget(WidgetTester tester,
        StreamController<SpellCreationState> controller, Parameter param) async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('target-dropdown')),
        100,
        scrollable: screenScrollable,
      );
      await tester.tap(find.byKey(const Key('target-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${param.name} (+${param.magnitude})').last);
      await tester.pumpAndSettle();
      controller.add(stateWithTarget(param));
      await tester.pump();
    }

    testWidgets('the container mode control appears only for a container Target',
        (tester) async {
      final controller = StreamController<SpellCreationState>();
      addTearDown(controller.close);
      await pumpWithTargetCatalog(tester, controller);

      await selectTarget(tester, controller, targetParam);
      expect(find.byKey(const Key('container-mode-field')), findsNothing);

      await selectTarget(tester, controller, roomTarget);
      // scrollUntilVisible against the screen's own scrollable -- a bare find
      // would be ambiguous, because every TextField on this screen builds its
      // own Scrollable. screenScrollable (top of file) anchors on the
      // ListView's key and picks its own Scrollable descendant.
      await tester.scrollUntilVisible(
        find.byKey(const Key('container-mode-field')),
        100,
        scrollable: screenScrollable,
      );
      expect(find.byKey(const Key('container-mode-field')), findsOneWidget);
    });

    testWidgets('choosing a segment dispatches ContainerModeSelected', (tester) async {
      final controller = StreamController<SpellCreationState>();
      addTearDown(controller.close);
      await pumpWithTargetCatalog(tester, controller);
      await selectTarget(tester, controller, roomTarget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('container-mode-field')),
        100,
        scrollable: screenScrollable,
      );

      await tester.tap(find.text('Dynamic'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const ContainerModeSelected(ContainerMode.dynamic)))
          .called(1);
    });
  });

  group('peer-aware dropdowns', () {
    // range-personal: forbids a container Target (Core Rules 12086).
    final rangePersonal = Parameter(
      id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0,
      forbidsTargetTypes: const [TargetType.container],
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
    // target-sound: a HoH:MC Sensory Target, dictates Range Personal (HoH:MC 1006).
    final targetSound = Parameter(
      id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 5,
      targetType: TargetType.sensorium,
      requiresRangeId: 'range-personal',
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-hohmc')]));
    final targetRoom = Parameter(
      id: 'target-room', name: 'Room', category: 'Target', magnitude: 10,
      targetType: TargetType.container,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
    final targetIndividual = Parameter(
      id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 8,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

    testWidgets('a Range dictated by the Target is not editable', (tester) async {
      // Pump the creation screen and select Sound as the Target first,
      // following the setup the neighbouring tests use.
      final draftState = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
          range: rangePersonal, duration: duration, target: targetSound,
        ),
      );
      await pumpScreen(
        tester,
        draftState,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect],
          parameters: [voiceParam, rangePersonal, durationParam, targetSound],
        ),
      );

      final dropdown = tester.widget<DropdownButtonFormField<Parameter>>(
        find.byKey(const Key('range-dropdown')),
      );
      expect(dropdown.onChanged, isNull);
    });

    testWidgets(
        'container Targets are still offered while Personal Range is chosen '
        '(the forbidding direction of check 10 is deliberately not filtered '
        'here -- see _compatibleWithPeers)', (tester) async {
      // Pump the creation screen with Personal already selected as the
      // Range -- this is also the app's own default draft state
      // (ParameterTriple.standard()), so a filter hiding Room here would
      // hide it for every fresh spell.
      final draftState = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
          range: rangePersonal, duration: duration,
        ),
      );
      await pumpScreen(
        tester,
        draftState,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect],
          parameters: [
            voiceParam, rangePersonal, durationParam, targetRoom, targetIndividual,
          ],
        ),
      );

      // DropdownButtonFormField doesn't expose its `items` as a public
      // field in this Flutter version (only `onChanged` is), so the items
      // are read the same way the "Form-scoped parameter" test above does:
      // open the menu and check which item texts are present.
      await tester.tap(find.byKey(const Key('target-dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('Room (+10)'), findsOneWidget);
      expect(find.text('Individual (+8)'), findsOneWidget);
    });

    testWidgets(
        'a directly-constructed state -- Personal Range with a container '
        'Target already selected -- renders both dropdowns without throwing',
        (tester) async {
      // No bloc path produces this pair, which is exactly why the state is
      // constructed directly here rather than driven through the bloc. There
      // is no load-a-saved-spell-for-editing path -- no such event exists in
      // spell_creation_event.dart, and SpellCreationScreen's constructor
      // takes only techniques/forms -- and templates come only from
      // assetLoader.loadSpellTemplates(), which assertion 7 checks against
      // checks 10/11 for every template (see the bloc's own comment on that
      // seeding). RangeSelected clears the Target, TargetSelected clears the
      // Range, and (as of todo item 74) _seedParameters refuses a seed that
      // would land on it. This test is a widget-level regression pin against
      // re-introducing the old pre-emptive dropdown filter: it tried to
      // pre-empt core 12086 (a container Target under a Personal Range) by
      // dropping the conflicting choice from each dropdown's `items` --
      // while `initialValue` still held it, since neither dropdown's
      // initialValue was ever filtered. That tripped DropdownButtonFormField's
      // "exactly one item with value" assertion on both dropdowns at once.
      // Check 10 is still enforced (by validateSpellAgainstCatalog and by the
      // bloc's own pruning on selection), just not by hiding the option
      // pre-emptively.
      final draftState = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
          range: rangePersonal, duration: duration, target: targetRoom,
        ),
      );

      await pumpScreen(
        tester,
        draftState,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect],
          parameters: [
            voiceParam, rangePersonal, durationParam, targetRoom, targetIndividual,
          ],
        ),
      );

      expect(tester.takeException(), isNull);

      final rangeDropdown = tester.widget<DropdownButtonFormField<Parameter>>(
        find.byKey(const Key('range-dropdown')),
      );
      expect(rangeDropdown.initialValue, rangePersonal);

      final targetDropdown = tester.widget<DropdownButtonFormField<Parameter>>(
        find.byKey(const Key('target-dropdown')),
      );
      expect(targetDropdown.initialValue, targetRoom);

      // The selected values render in the closed fields themselves, not
      // just internally.
      expect(find.text('Personal (+0)'), findsOneWidget);
      expect(find.text('Room (+10)'), findsOneWidget);
    });
  });
}
