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
      rangeId: voiceParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const [],
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
      rangeId: voiceParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const [],
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

  group('requisites section', () {
    SpellCreationState draftWith(List<Requisite> requisites) => SpellCreationState(
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
      await pumpScreen(tester, draftWith(const []));
      await tester.scrollUntilVisible(find.text('Requisites'), 200);

      expect(find.text('No requisites.'), findsOneWidget);
    });

    testWidgets('selecting an art from the add dropdown dispatches RequisiteAdded as free',
        (tester) async {
      await pumpScreen(tester, draftWith(const []));
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-add-dropdown')), 200);

      await tester.tap(find.byKey(const Key('requisite-add-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auram').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const RequisiteAdded('Auram', 'free'))).called(1);
    });

    testWidgets("the add dropdown offers neither the spell's own technique nor its form",
        (tester) async {
      await pumpScreen(tester, draftWith(const []));
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
        draftWith([Requisite(art: 'Auram', kind: RequisiteKind.free)]),
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
        draftWith([Requisite(art: 'Auram', kind: RequisiteKind.free)]),
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
        draftWith([Requisite(art: 'Auram', kind: RequisiteKind.adding)]),
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

      SpellCreationState stateWith(List<Requisite> requisites) => SpellCreationState(
            status: SpellCreationStatus.editing,
            draft: SpellDraft(
              technique: 'Creo',
              form: 'Ignem',
              baseEffect: creoIgnemEffect,
              requisites: requisites,
            ),
          );

      whenListen(bloc, stateController.stream, initialState: stateWith(const []));
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
      stateController.add(stateWith([Requisite(art: 'Auram', kind: RequisiteKind.free)]));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('requisite-row-Auram')), findsOneWidget);
    });

    testWidgets('renders a row per requisite when several are present', (tester) async {
      await pumpScreen(
        tester,
        draftWith([
          Requisite(art: 'Auram', kind: RequisiteKind.free),
          Requisite(art: 'Terram', kind: RequisiteKind.adding),
          Requisite(art: 'Rego', kind: RequisiteKind.adding),
        ]),
      );
      await tester.scrollUntilVisible(find.byKey(const Key('requisite-row-Auram')), 200);

      expect(find.byKey(const Key('requisite-row-Auram')), findsOneWidget);
      expect(find.byKey(const Key('requisite-row-Terram')), findsOneWidget);
      expect(find.byKey(const Key('requisite-row-Rego')), findsOneWidget);
      expect(find.text('No requisites.'), findsNothing);
    });
  });
}
