import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/presentation/screens/about_screen.dart';
import 'package:eruditus/presentation/screens/configuration_screen.dart';
import 'package:flutter/material.dart';

import '../../support/bloc_factories.dart';
import '../../support/pump_app.dart';

/// Drives the real ConfigurationScreen through a mocked bloc, the same shape
/// `configuration_screen_test.dart` already uses.
void main() {
  setUpAll(registerBlocFallbackValues);

  Future<void> pumpScreen(WidgetTester tester) async {
    final bloc = mockConfigurationBloc(
      initialState: const ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [],
        parameters: [],
      ),
    );
    await pumpApp(
      tester,
      const ConfigurationScreen(),
      providers: [BlocProvider<ConfigurationBloc>.value(value: bloc)],
      wrapInScaffold: false,
    );
  }

  testWidgets('the settings screen offers a route to the licences', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('open-about')), findsOneWidget);
  });

  testWidgets('tapping it opens the About screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('open-about')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
  });
}
