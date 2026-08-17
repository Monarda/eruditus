import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';

import 'bloc_factories.dart';

void main() {
  testWidgets(
    'a real bloc over a fake repository rebuilds the tree after an event',
    (tester) async {
      // The point of the test: constructed inline in the test body, with no
      // await. A real repository here would hang the fake-async zone.
      final bloc = realSpellCreationBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<SpellCreationBloc>.value(
          value: bloc,
          child: BlocBuilder<SpellCreationBloc, SpellCreationState>(
            builder: (context, state) => Text(
              state.draft.technique ?? 'no technique',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ));

      expect(find.text('no technique'), findsOneWidget);

      bloc.add(const TechniqueSelected('Creo'));
      await tester.pumpAndSettle();

      // A mocked bloc emits no new state, so this assertion is the one a mock
      // structurally cannot make fail.
      expect(find.text('Creo'), findsOneWidget);
    },
  );
}
