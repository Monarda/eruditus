import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/general_effect_formula.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/presentation/screens/spell_creation_screen.dart';
import 'package:eruditus/utils/constants.dart';

class MockSpellCreationBloc
    extends MockBloc<SpellCreationEvent, SpellCreationState>
    implements SpellCreationBloc {}

class MockConfigurationBloc
    extends MockBloc<ConfigurationEvent, ConfigurationState>
    implements ConfigurationBloc {}

class FakeSpellCreationEvent extends Fake implements SpellCreationEvent {}

class FakeSpellCreationState extends Fake implements SpellCreationState {}

class FakeConfigurationEvent extends Fake implements ConfigurationEvent {}

class FakeConfigurationState extends Fake implements ConfigurationState {}

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

  setUpAll(() {
    registerFallbackValue(FakeSpellCreationEvent());
    registerFallbackValue(FakeSpellCreationState());
    registerFallbackValue(FakeConfigurationEvent());
    registerFallbackValue(FakeConfigurationState());
  });

  setUp(() {
    bloc = MockSpellCreationBloc();
    configBloc = MockConfigurationBloc();
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
    whenListen(bloc, const Stream<SpellCreationState>.empty(), initialState: state);
    whenListen(
      configBloc,
      const Stream<ConfigurationState>.empty(),
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

  testWidgets('renders the level breakdown when status is calculated', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
      ),
      calculatedLevel: 20,
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

    expect(find.byKey(const Key('level-breakdown-card')), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('Range · Voice'), findsOneWidget);
  });

  testWidgets('does not render the calculated-level card before calculation', (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());

    expect(find.byKey(const Key('level-breakdown-card')), findsNothing);
  });

  testWidgets(
      'editing the draft after Calculate hides the stale Ritual banner rather than '
      'leaving its old reason on screen', (tester) async {
    // Regression test: state.breakdown is carried forward by copyWith across
    // edits (breakdown ?? this.breakdown), so a mock bloc whose state never
    // changes cannot catch this -- the bug only appears on the rebuild that
    // follows an edit. Drive two real states through a controller instead,
    // exactly as the "requisite survives the rebuild" test above does for the
    // analogous add-dropdown bug.
    useTallSurface(tester);
    final stateController = StreamController<SpellCreationState>();
    addTearDown(stateController.close);

    final yearParam = Parameter(
        id: 'p-year', name: 'Year', category: 'Duration', magnitude: 4,
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

    final calculatedState = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: yearParam, target: target,
      ),
      calculatedLevel: 20,
      breakdown: const LevelBreakdown(
        level: 20,
        rawLevel: 20,
        ritualStatus: RitualStatus([RitualReason.ritualOnlyDuration]),
        contributions: [
          LevelContribution(label: 'Base effect · Create flame', magnitude: 10, isBase: true),
        ],
      ),
    );

    whenListen(bloc, stateController.stream, initialState: calculatedState);
    whenListen(
      configBloc,
      const Stream<ConfigurationState>.empty(),
      initialState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [voiceParam, yearParam, durationParam, targetParam],
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

    expect(find.byKey(const Key('ritual-banner')), findsOneWidget);
    expect(find.textContaining('Year duration'), findsOneWidget);

    // The user changes Duration after Calculate. The bloc reverts status to
    // editing (as it does for any editing event) but, per
    // SpellCreationState.copyWith, the stale breakdown from the Year
    // calculation still rides along on the new state.
    stateController.add(SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: durationParam, target: target,
      ),
      breakdown: calculatedState.breakdown,
    ));
    await tester.pump();

    // The level card is correctly gated already; the banner must now be too,
    // rather than falsely reading "Ritual: Year duration" for a Momentary draft.
    expect(find.byKey(const Key('level-breakdown-card')), findsNothing);
    expect(find.byKey(const Key('ritual-banner')), findsNothing);
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
      calculatedLevel: 10,
      suggestions: [suggestion],
      suggestionLevels: const {'s1': 10},
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.text('Pillar of Fire'), 200);

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
      calculatedLevel: 10,
      suggestions: [generalSuggestion],
      suggestionLevels: const {'s-gen': 20},
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.text('Ward against the Undying'), 200);

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
      calculatedLevel: 10,
      suggestions: [flawedSuggestion],
      suggestionLevels: const {'s-flawed': 10},
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.text('Miscast Pillar'), 200);

    expect(find.byKey(const Key('needs-review-chip')), findsOneWidget);
    expect(find.byKey(const Key('spell-card-invalid')), findsOneWidget);
  });

  testWidgets('tapping discard dispatches SpellDiscarded', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      calculatedLevel: 10,
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('discard-button')), 200);

    await tester.tap(find.byKey(const Key('discard-button')));
    await tester.pump();

    verify(() => bloc.add(const SpellDiscarded())).called(1);
  });

  testWidgets('saving with a name dispatches SpellSaveRequested', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      calculatedLevel: 10,
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('spell-name-field')), 'My Fireball');
    await tester.tap(find.byKey(const Key('confirm-save-button')));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const SpellSaveRequested('My Fireball'))).called(1);
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
    whenListen(
      bloc,
      states,
      initialState: SpellCreationState(status: SpellCreationStatus.saving, draft: SpellDraft()),
    );
    whenListen(
      configBloc,
      const Stream<ConfigurationState>.empty(),
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
        calculatedLevel: 10,
        errorMessage: 'disk full',
      ),
    ]);
    whenListen(
      bloc,
      states,
      initialState: SpellCreationState(
        status: SpellCreationStatus.saving,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
        calculatedLevel: 10,
      ),
    );
    whenListen(
      configBloc,
      const Stream<ConfigurationState>.empty(),
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
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200);
    expect(find.byKey(const Key('save-button')), findsOneWidget);
    expect(find.byKey(const Key('discard-button')), findsOneWidget);
  });

  testWidgets('Save and Discard are disabled while a save is in flight', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.saving,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      calculatedLevel: 10,
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200);

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
      whenListen(bloc, stateController.stream, initialState: initial);
      whenListen(
        configBloc,
        const Stream<ConfigurationState>.empty(),
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
      whenListen(bloc, stateController.stream, initialState: initial);
      whenListen(
        configBloc,
        const Stream<ConfigurationState>.empty(),
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
      whenListen(bloc, stateController.stream, initialState: initial);
      whenListen(
        configBloc,
        const Stream<ConfigurationState>.empty(),
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
      whenListen(bloc, stateController.stream, initialState: initial);
      whenListen(
        configBloc,
        const Stream<ConfigurationState>.empty(),
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
      await tester.scrollUntilVisible(find.text('Requisites'), 200);

      expect(find.text('No requisites.'), findsOneWidget);
    });

    testWidgets('selecting an art from the add dropdown dispatches RequisiteAdded as free',
        (tester) async {
      await pumpScreen(tester, draftWith(const {}));
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-add-dropdown')), 200);

      await tester.tap(find.byKey(const Key('requisite-add-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auram').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const RequisiteAdded('Auram', 'free'))).called(1);
    });

    testWidgets("the add dropdown offers neither the spell's own technique nor its form",
        (tester) async {
      await pumpScreen(tester, draftWith(const {}));
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-add-dropdown')), 200);

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
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-add-dropdown')), 200);

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
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-kind-Auram')), 200);

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
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-remove-Auram')), 200);

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

      whenListen(bloc, stateController.stream, initialState: stateWith(const {}));
      whenListen(
        configBloc,
        const Stream<ConfigurationState>.empty(),
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
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-row-Auram')), 200);

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
      when(() => bloc.state).thenReturn(initial);
      whenListen(bloc, controller.stream, initialState: initial);
      whenListen(
        configBloc,
        const Stream<ConfigurationState>.empty(),
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
          citations: const [Citation(bookId: 'arm5-houses-hermes-mystery-cults')]),
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
}
