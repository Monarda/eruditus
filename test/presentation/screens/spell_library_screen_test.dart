import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/resolved_exception.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_template.dart';
import 'package:eruditus/presentation/screens/spell_library_screen.dart';

class MockSpellLibraryBloc extends MockBloc<SpellLibraryEvent, SpellLibraryState>
    implements SpellLibraryBloc {}

class MockSpellCreationBloc extends MockBloc<SpellCreationEvent, SpellCreationState>
    implements SpellCreationBloc {}

class FakeSpellLibraryEvent extends Fake implements SpellLibraryEvent {}

class FakeSpellLibraryState extends Fake implements SpellLibraryState {}

class FakeSpellCreationEvent extends Fake implements SpellCreationEvent {}

class FakeSpellCreationState extends Fake implements SpellCreationState {}

void main() {
  late MockSpellLibraryBloc bloc;

  final rangeParam = Parameter(
      id: 'p1', name: 'Voice', category: 'Range', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final durationParam = Parameter(
      id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final targetParam = Parameter(
      id: 'p3', name: 'Individual', category: 'Target', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

  final effect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'test', baseLevel: 5,
    provenance: Provenance(source: PublicationSource.userCreated),
  );

  ResolvedSpell buildSpell(String id, String name,
      {PublicationSource source = PublicationSource.published}) {
    // description is verbatim rulebook text and is never offered to users
    // (only summary is) -- a user-created fixture must carry summary
    // instead, or it builds a shape the app itself cannot produce.
    final isUserCreated = source == PublicationSource.userCreated;
    final record = Spell(
      id: id,
      name: name,
      baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const {},
      summary: isUserCreated ? 'A test spell.' : null,
      description: isUserCreated ? null : 'A test spell.',
      provenance: Provenance(
        source: source,
        citations: source == PublicationSource.published
            ? const [Citation(bookId: 'arm5-core')]
            : const [],
      ),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    return ResolvedSpell(
        record: record, baseEffect: effect, range: rangeParam, duration: durationParam, target: targetParam);
  }

  final builtInSpell = buildSpell('built-1', 'Phantasm of the Talking Head');
  final userSpell = buildSpell('user-1', 'My Custom Fireball', source: PublicationSource.userCreated);

  ResolvedTemplate buildTemplate(String id, String name, {bool resolved = true}) {
    final record = SpellTemplate(
      id: id,
      name: name,
      baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      description: 'A test template.',
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    return ResolvedTemplate(
      record: record,
      baseEffect: resolved ? effect : null,
      range: rangeParam,
      duration: durationParam,
      target: targetParam,
    );
  }

  ResolvedException buildException(String id, String name) {
    final record = ExceptionSpell(
      id: id,
      name: name,
      technique: 'Muto',
      form: 'Vim',
      range: 'Voice',
      duration: 'Mom',
      target: 'Group',
      description: 'A test exception.',
      rationale: 'Test rationale.',
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    return ResolvedException(record: record);
  }

  setUpAll(() {
    registerFallbackValue(FakeSpellLibraryEvent());
    registerFallbackValue(FakeSpellLibraryState());
    registerFallbackValue(FakeSpellCreationEvent());
    registerFallbackValue(FakeSpellCreationState());
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

  // The template section reaches for SpellCreationBloc only where its "Learn
  // at level…" button is built (see Step 3's note on the brief), so this is a
  // second helper rather than a change to pumpScreen above -- the five
  // existing tests above prove that lookup stays lazy by continuing to pump
  // with only a SpellLibraryBloc in scope.
  Future<void> pumpScreenWithCreationBloc(
    WidgetTester tester,
    SpellLibraryState state, {
    MockSpellCreationBloc? creationBloc,
    VoidCallback? onTemplateLearned,
  }) async {
    whenListen(bloc, const Stream<SpellLibraryState>.empty(), initialState: state);
    final resolvedCreationBloc = creationBloc ?? MockSpellCreationBloc();
    whenListen(resolvedCreationBloc, const Stream<SpellCreationState>.empty(),
        initialState: SpellCreationState.initial());
    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SpellLibraryBloc>.value(value: bloc),
          BlocProvider<SpellCreationBloc>.value(value: resolvedCreationBloc),
        ],
        child: SpellLibraryScreen(onTemplateLearned: onTemplateLearned),
      ),
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

  testWidgets('threads ResolvedSpell.problems onto the rendered card', (tester) async {
    final record = Spell(
      id: 'flawed-1',
      name: 'Flawed Ward',
      baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      // A requisite naming the spell's own Technique is exactly what
      // validateSpellAgainstCatalog's check 3 rejects -- the simplest way to
      // get a genuinely non-empty ResolvedSpell.problems for this fixture.
      requisites: const {'Creo': RequisiteKind.adding},
      // A summary, not a description: description is verbatim rulebook text
      // and is never offered to users, so a user-created spell carrying one
      // is a shape this app cannot produce.
      summary: 'A test spell.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final flawed = ResolvedSpell(
        record: record, baseEffect: effect, range: rangeParam, duration: durationParam, target: targetParam);
    // Sanity check on the fixture itself, not the screen -- if this ever
    // fails, the fixture stopped producing a real problem and the test below
    // would pass for the wrong reason.
    expect(flawed.problems, isNotEmpty);

    await pumpScreen(
      tester,
      SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [flawed]),
    );

    expect(find.byKey(const Key('spell-card-invalid')), findsOneWidget);
    expect(find.byKey(const Key('needs-review-chip')), findsOneWidget);
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

  group('General templates section', () {
    testWidgets('renders templates above the spells, under a heading', (tester) async {
      final template = buildTemplate('tpl-1', 'Ward against Faeries of the Waters');
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(
          status: SpellLibraryStatus.loaded,
          allSpells: [builtInSpell],
          templates: [template],
        ),
      );

      expect(find.text('General spells — learn at any level'), findsOneWidget);
      expect(find.text('Ward against Faeries of the Waters'), findsOneWidget);
      expect(find.text('Phantasm of the Talking Head'), findsOneWidget);

      // The heading, and every template card, must sit above the spells.
      final headingY = tester.getTopLeft(find.text('General spells — learn at any level')).dy;
      final templateY = tester.getTopLeft(find.text('Ward against Faeries of the Waters')).dy;
      final spellY = tester.getTopLeft(find.text('Phantasm of the Talking Head')).dy;
      expect(headingY, lessThan(templateY));
      expect(templateY, lessThan(spellY));
    });

    testWidgets(
        'tapping "Learn at level…" dispatches TemplateInstantiated and invokes onTemplateLearned',
        (tester) async {
      final template = buildTemplate('tpl-1', 'Ward against Faeries of the Waters');
      var learned = false;
      final creationBloc = MockSpellCreationBloc();
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(status: SpellLibraryStatus.loaded, templates: [template]),
        creationBloc: creationBloc,
        onTemplateLearned: () => learned = true,
      );

      await tester.tap(find.byKey(Key('learn-${template.id}')));
      await tester.pump();

      verify(() => creationBloc.add(TemplateInstantiated(template))).called(1);
      expect(learned, isTrue);
    });

    testWidgets('an unresolved template offers no "Learn at level…" button', (tester) async {
      final unresolved = buildTemplate('tpl-1', 'Broken Template', resolved: false);
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(status: SpellLibraryStatus.loaded, templates: [unresolved]),
      );

      expect(find.text('Broken Template'), findsOneWidget);
      expect(find.byKey(Key('learn-${unresolved.id}')), findsNothing);
      expect(find.text('Learn at level…'), findsNothing);
    });

    testWidgets('a state with no templates renders no heading and no empty section',
        (tester) async {
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [builtInSpell]),
      );

      expect(find.text('General spells — learn at any level'), findsNothing);
    });
  });

  group('Exceptions section', () {
    testWidgets('renders exceptions below the spells, under a heading', (tester) async {
      final template = buildTemplate('tpl-1', 'Ward against Faeries of the Waters');
      final exception = buildException('exc-1', "Wizard's Communion");
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(
          status: SpellLibraryStatus.loaded,
          allSpells: [builtInSpell],
          templates: [template],
          exceptions: [exception],
        ),
      );

      expect(find.text('Exceptions — recorded from the rulebook directly, not derived from the guidelines'),
          findsOneWidget);
      expect(find.text("Wizard's Communion"), findsOneWidget);
      expect(find.byKey(const Key('exception-chip')), findsOneWidget);
      expect(find.text('Test rationale.'), findsOneWidget);

      final spellY = tester.getTopLeft(find.text('Phantasm of the Talking Head')).dy;
      final templateY = tester.getTopLeft(find.text('Ward against Faeries of the Waters')).dy;
      final exceptionY = tester.getTopLeft(find.text("Wizard's Communion")).dy;
      expect(spellY, lessThan(exceptionY));
      expect(templateY, lessThan(exceptionY));
    });

    testWidgets('an exception card offers no instantiation action', (tester) async {
      final exception = buildException('exc-1', "Wizard's Communion");
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(status: SpellLibraryStatus.loaded, exceptions: [exception]),
      );

      expect(find.text('Learn at level…'), findsNothing);
      expect(find.byKey(const Key('general-chip')), findsNothing);
    });

    testWidgets('a state with no exceptions renders no heading and no empty section',
        (tester) async {
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [builtInSpell]),
      );

      expect(
          find.text('Exceptions — recorded from the rulebook directly, not derived from the guidelines'),
          findsNothing);
    });
  });
}
