import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/presentation/screens/spell_library_screen.dart';

class MockSpellLibraryBloc extends MockBloc<SpellLibraryEvent, SpellLibraryState>
    implements SpellLibraryBloc {}

class FakeSpellLibraryEvent extends Fake implements SpellLibraryEvent {}

class FakeSpellLibraryState extends Fake implements SpellLibraryState {}

void main() {
  late MockSpellLibraryBloc bloc;

  final rangeParam = Parameter(id: 'p1', name: 'Voice', category: 'Range', magnitude: 0, source: 'published');
  final durationParam = Parameter(id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'published');
  final targetParam = Parameter(id: 'p3', name: 'Individual', category: 'Target', magnitude: 0, source: 'published');

  final effect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'test', baseLevel: 5, source: 'published',
  );

  ResolvedSpell buildSpell(String id, String name, {String source = 'published'}) {
    final record = Spell(
      id: id,
      name: name,
      baseEffectId: effect.id,
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const [],
      source: source, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    return ResolvedSpell(
        record: record, baseEffect: effect, range: rangeParam, duration: durationParam, target: targetParam);
  }

  final builtInSpell = buildSpell('built-1', 'Phantasm of the Talking Head');
  final userSpell = buildSpell('user-1', 'My Custom Fireball', source: 'user-created');

  setUpAll(() {
    registerFallbackValue(FakeSpellLibraryEvent());
    registerFallbackValue(FakeSpellLibraryState());
  });

  setUp(() {
    bloc = MockSpellLibraryBloc();
  });

  Future<void> pumpScreen(WidgetTester tester, SpellLibraryState state) async {
    whenListen(bloc, const Stream<SpellLibraryState>.empty(), initialState: state);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<SpellLibraryBloc>.value(value: bloc, child: const SpellLibraryScreen()),
    ));
  }

  testWidgets('shows both built-in and user spells when loaded', (tester) async {
    await pumpScreen(
      tester,
      SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [builtInSpell, userSpell]),
    );

    expect(find.text('My Custom Fireball'), findsOneWidget);
    expect(find.text('Phantasm of the Talking Head'), findsOneWidget);
  });

  testWidgets('shows each card\'s precomputed level from state.spellLevels', (tester) async {
    await pumpScreen(
      tester,
      SpellLibraryState(
        status: SpellLibraryStatus.loaded,
        allSpells: [builtInSpell, userSpell],
        spellLevels: const {'built-1': 5, 'user-1': 15},
      ),
    );

    expect(find.textContaining('Level 5'), findsOneWidget);
    expect(find.textContaining('Level 15'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while status is loading', (tester) async {
    await pumpScreen(tester, SpellLibraryState.initial());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('selecting the "My Spells" filter dispatches FilterChanged', (tester) async {
    await pumpScreen(
      tester,
      SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [builtInSpell, userSpell]),
    );

    await tester.tap(find.widgetWithText(RadioListTile<String>, 'My Spells'));
    await tester.pump();

    verify(() => bloc.add(const FilterChanged('My Spells'))).called(1);
  });

  testWidgets('typing in the search field dispatches SearchQueryChanged', (tester) async {
    await pumpScreen(
      tester,
      SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [builtInSpell, userSpell]),
    );

    await tester.enterText(find.byKey(const Key('search-field')), 'fireball');
    await tester.pump();

    verify(() => bloc.add(const SearchQueryChanged('fireball'))).called(1);
  });

  testWidgets('only shows spells present in visibleSpells (filter already applied by state)',
      (tester) async {
    await pumpScreen(
      tester,
      SpellLibraryState(
        status: SpellLibraryStatus.loaded,
        allSpells: [builtInSpell, userSpell],
        filter: 'My Spells',
      ),
    );

    expect(find.text('My Custom Fireball'), findsOneWidget);
    expect(find.text('Phantasm of the Talking Head'), findsNothing);
  });
}
