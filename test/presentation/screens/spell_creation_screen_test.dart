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
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
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
    description: 'Create flame', baseLevel: 10, source: 'built-in',
  );
  final voiceParam = Parameter(id: 'p1', name: 'Voice', category: 'Range', magnitude: 2, source: 'built-in');
  final durationParam = Parameter(id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in');
  final targetParam = Parameter(id: 'p3', name: 'Individual', category: 'Target', magnitude: 8, source: 'built-in');

  late SelectedParameter _range;
  late SelectedParameter _duration;
  late SelectedParameter _target;

  setUpAll(() {
    registerFallbackValue(FakeSpellCreationEvent());
    registerFallbackValue(FakeSpellCreationState());
    registerFallbackValue(FakeConfigurationEvent());
    registerFallbackValue(FakeConfigurationState());
  });

  setUp(() {
    bloc = MockSpellCreationBloc();
    configBloc = MockConfigurationBloc();
    _range = SelectedParameter(parameterId: 'p1', parameter: voiceParam);
    _duration = SelectedParameter(parameterId: 'p2', parameter: durationParam);
    _target = SelectedParameter(parameterId: 'p3', parameter: targetParam);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    SpellCreationState state, {
    ConfigurationState? configState,
  }) async {
    whenListen(bloc, const Stream<SpellCreationState>.empty(), initialState: state);
    whenListen(
      configBloc,
      const Stream<ConfigurationState>.empty(),
      initialState: configState ??
          ConfigurationState(
            status: ConfigurationStatus.loaded,
            effects: [creoIgnemEffect],
            parameters: [voiceParam],
            factors: const [],
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

  testWidgets('renders the calculated spell level when status is calculated', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: _range, duration: _duration, target: _target),
      calculatedLevel: 20,
    );
    await pumpScreen(tester, state);

    expect(find.text('Calculated Spell Level: 20'), findsOneWidget);
  });

  testWidgets('does not render the calculated-level card before calculation', (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());

    expect(find.textContaining('Calculated Spell Level'), findsNothing);
  });

  testWidgets('shows suggestions with their level and description when status is calculated',
      (tester) async {
    final suggestion = Spell(
      id: 's1', name: 'Pillar of Fire', technique: 'Creo', form: 'Ignem',
      baseEffect: creoIgnemEffect,
      range: SelectedParameter(parameterId: 'p1', parameter: voiceParam),
      duration: SelectedParameter(parameterId: 'p2', parameter: durationParam),
      target: SelectedParameter(parameterId: 'p3', parameter: targetParam),
      selectedSpecialFactorIds: const [],
      requisites: const [],
      description: 'A roaring pillar of flame.',
      source: 'built-in', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: _range, duration: _duration, target: _target),
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
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: _range, duration: _duration, target: _target),
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
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: _range, duration: _duration, target: _target),
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
      id: 'saved-1', name: 'My Fireball', technique: 'Creo', form: 'Ignem',
      baseEffect: creoIgnemEffect,
      range: SelectedParameter(parameterId: 'p1', parameter: voiceParam),
      duration: SelectedParameter(parameterId: 'p2', parameter: durationParam),
      target: SelectedParameter(parameterId: 'p3', parameter: targetParam),
      selectedSpecialFactorIds: const [],
      requisites: const [],
      source: 'user-created', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
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
        factors: const [],
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
    final states = Stream.fromIterable([
      SpellCreationState(
        status: SpellCreationStatus.error,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: _range, duration: _duration, target: _target),
        calculatedLevel: 10,
        errorMessage: 'disk full',
      ),
    ]);
    whenListen(
      bloc,
      states,
      initialState: SpellCreationState(
        status: SpellCreationStatus.saving,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: _range, duration: _duration, target: _target),
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
        factors: const [],
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
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: _range, duration: _duration, target: _target),
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
      description: 'My custom fire effect', baseLevel: 3, source: 'user-created',
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
        factors: const [],
      ),
    );

    await tester.tap(find.byKey(const Key('base-effect-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('My custom fire effect (Base 3)'), findsOneWidget);
  });
}
