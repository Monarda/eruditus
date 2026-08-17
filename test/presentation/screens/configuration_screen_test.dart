import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/presentation/screens/configuration_screen.dart';

import '../../support/bloc_factories.dart';

void main() {
  late MockConfigurationBloc bloc;

  setUpAll(registerBlocFallbackValues);

  Future<void> pumpScreen(WidgetTester tester, ConfigurationState state) async {
    bloc = mockConfigurationBloc(initialState: state);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<ConfigurationBloc>.value(value: bloc, child: const ConfigurationScreen()),
    ));
  }

  ConfigurationState loadedState({List<BaseEffect> effects = const []}) => ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: effects,
        parameters: const [],
      );

  testWidgets('shows Effects, Parameters tabs', (tester) async {
    await pumpScreen(tester, loadedState());

    expect(find.text('Effects'), findsOneWidget);
    expect(find.text('Parameters'), findsOneWidget);
  });

  testWidgets('renders custom effects present in state', (tester) async {
    final customEffect = BaseEffect(
      id: 'custom-1', technique: 'Creo', form: 'Ignem',
      description: 'My custom effect', baseLevel: 7,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    await pumpScreen(tester, loadedState(effects: [customEffect]));

    expect(find.text('My custom effect'), findsOneWidget);
  });

  testWidgets('a General effect shows "General" rather than "Base null"', (tester) async {
    final generalEffect = BaseEffect(
      id: 'rean-gen', technique: 'Rego', form: 'Animal',
      description: 'Ward against beings associated with Animal', baseLevel: null,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    await pumpScreen(tester, loadedState(effects: [generalEffect]));

    expect(find.textContaining('General'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('the add-effect dialog rejects a base level below 1', (tester) async {
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

    await tester.enterText(find.byKey(const Key('new-effect-description')), 'A degenerate effect');
    // A custom effect has no way to author a GeneralEffectFormula, so 0 is
    // not "General" here -- it is simply an invalid guideline level, and
    // SpellLevelCalculator.calculate rejects it as soon as a spell built on
    // this effect is calculated. The dialog must reject it up front instead.
    await tester.enterText(find.byKey(const Key('new-effect-level')), '0');

    await tester.tap(find.byKey(const Key('confirm-add-effect')));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(any(that: isA<CustomEffectAdded>())));
    // The dialog stays open rather than silently discarding the input.
    expect(find.byKey(const Key('confirm-add-effect')), findsOneWidget);
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
          .having((e) => e.effect.provenance.source, 'source', PublicationSource.userCreated),
    ))).called(1);
  });
}
