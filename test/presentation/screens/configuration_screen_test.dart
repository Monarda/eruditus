import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/presentation/screens/configuration_screen.dart';

class MockConfigurationBloc extends MockBloc<ConfigurationEvent, ConfigurationState>
    implements ConfigurationBloc {}

class FakeConfigurationEvent extends Fake implements ConfigurationEvent {}

class FakeConfigurationState extends Fake implements ConfigurationState {}

void main() {
  late MockConfigurationBloc bloc;

  setUpAll(() {
    registerFallbackValue(FakeConfigurationEvent());
    registerFallbackValue(FakeConfigurationState());
  });

  setUp(() {
    bloc = MockConfigurationBloc();
  });

  Future<void> pumpScreen(WidgetTester tester, ConfigurationState state) async {
    whenListen(bloc, const Stream<ConfigurationState>.empty(), initialState: state);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<ConfigurationBloc>.value(value: bloc, child: const ConfigurationScreen()),
    ));
  }

  ConfigurationState loadedState({List<BaseEffect> effects = const []}) => ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: effects,
        parameters: const [],
        factors: const [],
      );

  testWidgets('shows Effects, Parameters, Special Factors tabs', (tester) async {
    await pumpScreen(tester, loadedState());

    expect(find.text('Effects'), findsOneWidget);
    expect(find.text('Parameters'), findsOneWidget);
    expect(find.text('Special Factors'), findsOneWidget);
  });

  testWidgets('renders custom effects present in state', (tester) async {
    final customEffect = BaseEffect(
      id: 'custom-1', technique: 'Creo', form: 'Ignem',
      description: 'My custom effect', baseLevel: 7, source: 'user-created',
    );
    await pumpScreen(tester, loadedState(effects: [customEffect]));

    expect(find.text('My custom effect'), findsOneWidget);
  });

  testWidgets('filling the add-effect dialog dispatches CustomEffectAdded with the entered values',
      (tester) async {
    await pumpScreen(tester, loadedState());

    await tester.tap(find.byKey(const Key('add-effect-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-effect-technique')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Creo').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-effect-form')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ignem').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('new-effect-description')), 'My custom effect');
    await tester.enterText(find.byKey(const Key('new-effect-level')), '7');

    await tester.tap(find.byKey(const Key('confirm-add-effect')));
    await tester.pumpAndSettle();

    verify(() => bloc.add(any(
      that: isA<CustomEffectAdded>()
          .having((e) => e.effect.technique, 'technique', 'Creo')
          .having((e) => e.effect.form, 'form', 'Ignem')
          .having((e) => e.effect.description, 'description', 'My custom effect')
          .having((e) => e.effect.baseLevel, 'baseLevel', 7)
          .having((e) => e.effect.source, 'source', 'user-created'),
    ))).called(1);
  });
}
