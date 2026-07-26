// Regression coverage for the "custom config doesn't reach Create until
// restart" bug: SpellCreationScreen must read effects/parameters/factors
// live from ConfigurationBloc, so something added via ConfigurationBloc (as
// happens in the Settings tab) becomes selectable here without rebuilding
// the widget tree from scratch.
//
// Widget tests in this project mock blocs rather than using real ones (see
// the real-bloc-widget-test-hang note in other test files/CLAUDE memory: a
// real Bloc's event pipeline hangs indefinitely under this project's
// flutter_tester). So instead of driving a real ConfigurationBloc end to
// end, this test uses a controllable StreamController fed to a
// MockConfigurationBloc: it dispatches CustomParameterAdded on the mock
// (verifying the screen would trigger exactly that event were it wired to a
// real bloc/dialog), then pushes the state a real ConfigurationBloc would
// emit after reloading with the new parameter included -- exercising the
// screen's *reactive rendering* of that seam without needing a second
// pumpWidget call.
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
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';
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
  setUpAll(() {
    registerFallbackValue(FakeSpellCreationEvent());
    registerFallbackValue(FakeSpellCreationState());
    registerFallbackValue(FakeConfigurationEvent());
    registerFallbackValue(FakeConfigurationState());
  });

  final creoIgnemEffect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'Create flame', baseLevel: 10, source: 'built-in',
  );

  testWidgets(
    'a parameter added via ConfigurationBloc becomes selectable in SpellCreationScreen '
    'without reconstructing the widget',
    (tester) async {
      // The screen is a lazily-built ListView, so a section below the fold is
      // never constructed and finders can't see it. Give the surface enough
      // height for the whole form.
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spellCreationBloc = MockSpellCreationBloc();
      final configBloc = MockConfigurationBloc();
      final configController = StreamController<ConfigurationState>();
      addTearDown(configController.close);

      final initialConfigState = ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: const [],
        factors: const [],
      );

      whenListen(
        spellCreationBloc,
        const Stream<SpellCreationState>.empty(),
        initialState: SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(technique: 'Creo', form: 'Ignem'),
        ),
      );
      whenListen(configBloc, configController.stream, initialState: initialConfigState);

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: spellCreationBloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      // The custom parameter doesn't exist yet.
      expect(find.textContaining('Custom Reach'), findsNothing);

      final customParameter = Parameter(
        id: 'custom-p1', name: 'Custom Reach', category: 'Range', magnitude: 4,
        source: 'user-created',
      );

      // Dispatch the same event a real "Add Parameter" dialog in the
      // Settings tab would dispatch on ConfigurationBloc.
      configBloc.add(CustomParameterAdded(customParameter));
      verify(() => configBloc.add(CustomParameterAdded(customParameter))).called(1);

      // Simulate ConfigurationBloc's reload-after-add completing, without
      // rebuilding/re-pumping the SpellCreationScreen widget itself.
      configController.add(ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [customParameter],
        factors: const [],
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('range-dropdown')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Custom Reach'), findsOneWidget);
    },
  );

  testWidgets(
    'a special factor added via ConfigurationBloc becomes selectable and its magnitude '
    'resolves in SpellEngine without an app restart',
    (tester) async {
      // The screen is a lazily-built ListView, so a section below the fold is
      // never constructed and finders can't see it. Give the surface enough
      // height for the whole form.
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spellCreationBloc = MockSpellCreationBloc();
      final configBloc = MockConfigurationBloc();
      final configController = StreamController<ConfigurationState>();
      addTearDown(configController.close);

      final initialConfigState = ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: const [],
        factors: const [],
      );

      whenListen(
        spellCreationBloc,
        const Stream<SpellCreationState>.empty(),
        initialState: SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(technique: 'Creo', form: 'Ignem'),
        ),
      );
      whenListen(configBloc, configController.stream, initialState: initialConfigState);

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: spellCreationBloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      expect(find.textContaining('Custom Complexity'), findsNothing);

      final customFactor = SpecialFactor(
        id: 'custom-f1', technique: 'Creo', form: 'Ignem',
        name: 'Custom Complexity', description: 'A homebrewed complexity factor',
        magnitude: 2, source: 'user-created',
      );

      configBloc.add(CustomFactorAdded(customFactor));
      verify(() => configBloc.add(CustomFactorAdded(customFactor))).called(1);

      configController.add(ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: const [],
        factors: [customFactor],
      ));
      await tester.pump();

      // The new factor is now shown as a selectable checkbox for the
      // current Technique+Form.
      expect(find.textContaining('Custom Complexity'), findsOneWidget);

      // AvailableFactorsSynced should have been dispatched to
      // SpellCreationBloc with the updated factors list so its SpellEngine
      // can resolve the new factor's magnitude by id (rather than throwing
      // "Bad state: no element" the next time it's selected and
      // calculated).
      verify(() => spellCreationBloc.add(AvailableFactorsSynced([customFactor]))).called(1);
    },
  );
}
