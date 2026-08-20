import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/engine/contribution_source.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/general_effect_formula.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/parameter_triple.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_template.dart';
import 'package:eruditus/models/spell_validation_error.dart';
import 'package:eruditus/models/target_type.dart';

class MockSpellRepository extends Mock implements SpellRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(Spell(
      id: 'fallback',
      baseEffectId: 'fb',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1',
      durationId: 'p2',
      targetId: 'p3',
      requisites: const {},
      summary: 'Fallback spell for mocktail argument matching.',
      provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    ));
  });

  late AppDatabase database;
  late SpellRepository spellRepository;
  late SpellEngine spellEngine;

  final creoIgnemEffect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'Create flame', baseLevel: 10,
    provenance: Provenance(source: PublicationSource.userCreated),
  );
  final rangeParam = Parameter(
      id: 'p1', name: 'Voice', category: 'Range', magnitude: 2,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final durationParam = Parameter(
      id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final targetParam = Parameter(
      id: 'p3', name: 'Individual', category: 'Target', magnitude: 8,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final resolver = SpellResolver(
      effects: [creoIgnemEffect],
      parameters: [rangeParam, durationParam, targetParam],
      modifiers: const [],
    );
    final configRepository = ConfigurationRepository(
      assetLoader: AssetDataLoader(),
      configDatasource: LocalConfigurationDatasource(database: database),
    );
    spellRepository = SpellRepository(
      datasource: LocalSpellDatasource(database: database),
      resolver: resolver,
      configRepository: configRepository,
    );
    spellEngine = SpellEngine(allSpells: const []);
  });

  tearDown(() async {
    await database.close();
  });

  blocTest<SpellCreationBloc, SpellCreationState>(
    'emits editing state with technique set when TechniqueSelected is added',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc.add(const TechniqueSelected('Creo')),
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having((s) => s.draft.technique, 'draft.technique', 'Creo'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated emits validation errors when draft is incomplete',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc.add(const SpellCalculated()),
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having((s) => s.validationErrors, 'validationErrors', isNotEmpty),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated emits calculated level and no errors when draft is valid',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellCalculated());
    },
    skip: 6,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          // Base 10 already exceeds the additive-tier cap of 5, so all of
          // Range(+2) + Duration(+0) + Target(+8) = 10 magnitude falls in the
          // multiplier tier: 10 + (10 * 5) = 60.
          .having((s) => s.breakdown?.level, 'breakdown.level', 60)
          .having((s) => s.validationErrors, 'validationErrors', isEmpty),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated precomputes a level for each suggestion, keyed by spell id',
    build: () {
      final suggestionRecord = Spell(
        id: 'suggestion-1',
        name: 'Pillar of Fire',
        baseEffectId: creoIgnemEffect.id,
        technique: 'Creo',
        form: 'Ignem',
        rangeId: rangeParam.id,
        durationId: durationParam.id,
        targetId: targetParam.id,
        requisites: const {},
        summary: 'Raises a pillar of flame.',
        provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final suggestion = ResolvedSpell(
        record: suggestionRecord, baseEffect: creoIgnemEffect,
        range: rangeParam, duration: durationParam, target: targetParam);
      return SpellCreationBloc(
        spellEngine: SpellEngine(allSpells: [suggestion]),
        spellRepository: spellRepository,
      );
    },
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellCalculated());
    },
    skip: 6,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          .having((s) => s.suggestions.map((sp) => sp.id), 'suggestions ids', ['suggestion-1'])
          // Same base effect + parameters as the draft: base 10 + (10 magnitude * 5) = 60.
          .having((s) => s.suggestionLevels['suggestion-1'], 'suggestionLevels[suggestion-1]', 60),
    ],
  );

  // The suggestion fixture the two tests below share: same Technique/Form as
  // the draft they are calculated against, so findSimilarSpells returns it.
  SpellCreationBloc blocWithOneSuggestion() {
    final suggestionRecord = Spell(
      id: 'suggestion-1',
      name: 'Pillar of Fire',
      baseEffectId: creoIgnemEffect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const {},
      summary: 'Raises a pillar of flame.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final suggestion = ResolvedSpell(
      record: suggestionRecord, baseEffect: creoIgnemEffect,
      range: rangeParam, duration: durationParam, target: targetParam);
    return SpellCreationBloc(
      spellEngine: SpellEngine(allSpells: [suggestion]),
      spellRepository: spellRepository,
    );
  }

  void calculateAValidDraft(SpellCreationBloc bloc) {
    bloc.add(const TechniqueSelected('Creo'));
    bloc.add(const FormSelected('Ignem'));
    bloc.add(BaseEffectSelected(creoIgnemEffect));
    bloc.add(RangeSelected(rangeParam));
    bloc.add(DurationSelected(durationParam));
    bloc.add(TargetSelected(targetParam));
    bloc.add(const SpellCalculated());
  }

  blocTest<SpellCreationBloc, SpellCreationState>(
    'an edit after SpellCalculated clears the suggestions it produced, and their '
    'companion maps, while the level is recomputed',
    // Each suggestion carries a precomputed level that was compared against a
    // reference level this draft no longer has, so the edit does not merely
    // date the list, it falsifies the comparison the list exists to make. Left
    // uncleared, the list only *looked* gone: the screen hid it on
    // `status: editing` while it sat in state, and a save started after the
    // edit put it back on screen (the status moves to saving/error, which the
    // screen has to read as "keep showing a calculated list" so a save does not
    // take the suggestions away from under someone who did press the button).
    //
    // The funnel's predicate is the level moving, not the draft moving, so this
    // test's edit is chosen to do both -- see the two tests after it for the
    // cases where they come apart.
    build: blocWithOneSuggestion,
    act: (bloc) {
      calculateAValidDraft(bloc);
      // A different Duration: a real draft change, and one that moves the
      // level, so the recomputation is visible in the same emit.
      bloc.add(DurationSelected(Parameter(
          id: 'p-sun', name: 'Sun', category: 'Duration', magnitude: 2,
          provenance: Provenance(
              source: PublicationSource.published,
              citations: const [Citation(bookId: 'arm5-core')]))));
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having((s) => s.suggestions, 'suggestions', isEmpty)
          .having((s) => s.suggestionLevels, 'suggestionLevels', isEmpty)
          .having((s) => s.ritualSuggestionIds, 'ritualSuggestionIds', isEmpty)
          // The level is not merely retained, it is recomputed: the point of
          // clearing the suggestions is that they no longer describe this
          // draft, and the thing that does describe it must still be there.
          .having((s) => s.breakdown, 'breakdown', isNotNull)
          .having((s) => s.breakdown?.level, 'breakdown.level', 70),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a catalog sync that moves the level clears the suggestions, though the draft '
    'never changed',
    // The case the old draft-based predicate could not see, and the reason the
    // funnel now clears on the breakdown instead. AvailableParametersSynced
    // re-emits the *same* state object: the draft is untouched and only the
    // engine's catalog moved, so `draftChanged` was false and all three
    // suggestion fields survived a recomputed breakdown -- a list of spells
    // chosen for being near level 60, sitting under a banner reading 55.
    //
    // The guideline below is priced against a Touch Range, the shape every ward
    // row in the catalog has. Its reference id resolves to nothing while the
    // parameter catalog is empty, so the draft's Voice Range is charged its
    // full 2 magnitudes; once `p-touch` (magnitude 1) arrives, the same Range
    // is charged the delta of 1, and the level drops from 60 to 55 with no
    // event having touched the draft at all.
    build: blocWithOneSuggestion,
    act: (bloc) {
      final wardEffect = BaseEffect(
        id: 'e-ward', technique: 'Creo', form: 'Ignem',
        description: 'Ward against flame', baseLevel: 10,
        reference: const ParameterTriple(
          rangeId: 'p-touch', durationId: 'duration-momentary',
          targetId: 'target-individual'),
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final touchParam = Parameter(
        id: 'p-touch', name: 'Touch', category: 'Range', magnitude: 1,
        provenance: Provenance(
            source: PublicationSource.published,
            citations: const [Citation(bookId: 'arm5-core')]),
      );

      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(wardEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellCalculated());
      bloc.add(AvailableParametersSynced(
          [rangeParam, durationParam, targetParam, touchParam]));
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          // Still `calculated`: the sync re-emits the state it was given, so
          // nothing but the level and the invalidated fields moves. That is
          // what makes this dangerous -- the screen would have gone on showing
          // the section.
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          .having((s) => s.suggestions, 'suggestions', isEmpty)
          .having((s) => s.suggestionLevels, 'suggestionLevels', isEmpty)
          .having((s) => s.ritualSuggestionIds, 'ritualSuggestionIds', isEmpty)
          // Recomputed, not merely retained: base 10 + (Range 2-1 + Duration 0
          // + Target 8) * 5 = 55, down from the 60 the suggestions were chosen
          // against.
          .having((s) => s.breakdown?.level, 'breakdown.level', 55)
          // The draft is the same object the Calculate ran on -- proof the
          // clear cannot have come from a draft change.
          .having((s) => s.draft.range?.id, 'draft.range.id', 'p1'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a level-neutral edit after SpellCalculated leaves the suggestions alone',
    // The other side of moving the predicate off the draft, and intentional.
    // Prose is scoped to nothing and cannot move the level, so the list is
    // still a list of spells near *this* level. The screen hides the section
    // anyway while the status is `editing`; what this buys is that a save which
    // then fails -- and a save dialog's summary rebuilds the draft exactly like
    // this -- reopens it with a list that was never invalidated.
    build: blocWithOneSuggestion,
    act: (bloc) {
      calculateAValidDraft(bloc);
      bloc.add(const SummaryChanged('A pillar of flame, but described better.'));
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having((s) => s.draft.summary, 'draft.summary',
              'A pillar of flame, but described better.')
          .having((s) => s.suggestions.map((sp) => sp.id), 'suggestions ids', ['suggestion-1'])
          .having((s) => s.suggestionLevels, 'suggestionLevels', isNotEmpty)
          .having((s) => s.breakdown?.level, 'breakdown.level', 60),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated does not clear the suggestions it just produced',
    // The reverse guard on the clears above, and the ordering the whole change
    // rests on. _handleSpellCalculated emits `state.copyWith(...)`, so the
    // funnel recomputes the breakdown from the same draft against the same
    // catalogs that produced `state.breakdown` on the previous pass -- equal by
    // value, so `breakdownChanged` is false and the list survives the emit that
    // built it. A clear that fired here would empty the suggestions on the very
    // event that computes them, and the symptom would be an always-empty
    // Similar Spells section rather than a stale one. ritualSuggestionIds has
    // the same guard in the Ritual-suggestion test below, which asserts a
    // populated set straight out of SpellCalculated.
    build: blocWithOneSuggestion,
    act: calculateAValidDraft,
    skip: 6,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          .having((s) => s.suggestions.map((sp) => sp.id), 'suggestions ids', ['suggestion-1'])
          .having((s) => s.suggestionLevels, 'suggestionLevels', isNotEmpty),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated flags a Ritual suggestion in ritualSuggestionIds, leaving a non-Ritual one out',
    build: () {
      final yearDuration = Parameter(
        id: 'p2-year', name: 'Year', category: 'Duration', magnitude: 5,
        requiresRitual: true,
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      // A separate, low-level effect/target so this suggestion's raw level
      // stays well under the Ritual >50 threshold — it must be non-Ritual by
      // construction, not just by not carrying a `requiresRitual` parameter.
      final lowEffect = BaseEffect(
        id: 'e-low', technique: 'Creo', form: 'Ignem',
        description: 'Warm a small object', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final zeroTarget = Parameter(
        id: 'p3-zero', name: 'Personal-ish', category: 'Target', magnitude: 0,
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      final ritualRecord = Spell(
        id: 'ritual-suggestion',
        name: 'Endless Flame',
        baseEffectId: creoIgnemEffect.id,
        technique: 'Creo',
        form: 'Ignem',
        rangeId: rangeParam.id,
        durationId: yearDuration.id,
        targetId: targetParam.id,
        requisites: const {},
        summary: 'A flame that never goes out.',
        provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final ordinaryRecord = Spell(
        id: 'ordinary-suggestion',
        name: 'Warmth of the Hearth',
        baseEffectId: lowEffect.id,
        technique: 'Creo',
        form: 'Ignem',
        rangeId: rangeParam.id,
        durationId: durationParam.id,
        targetId: zeroTarget.id,
        requisites: const {},
        summary: 'A small, comforting warmth.',
        provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final ritualSuggestion = ResolvedSpell(
        record: ritualRecord, baseEffect: creoIgnemEffect,
        range: rangeParam, duration: yearDuration, target: targetParam);
      final ordinarySuggestion = ResolvedSpell(
        record: ordinaryRecord, baseEffect: lowEffect,
        range: rangeParam, duration: durationParam, target: zeroTarget);
      return SpellCreationBloc(
        spellEngine: SpellEngine(allSpells: [ritualSuggestion, ordinarySuggestion]),
        spellRepository: spellRepository,
      );
    },
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellCalculated());
    },
    skip: 6,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          .having((s) => s.ritualSuggestionIds, 'ritualSuggestionIds', {'ritual-suggestion'}),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // Regression test for the residual finding: a saved spell whose
    // adjustments drive it below level 1 has no computable level (same
    // construction as spell_library_bloc_test.dart's `uncomputableSpell`),
    // and calculateSpellLevel/calculateBreakdown throw for it. This engine
    // holds only that one candidate, so findSimilarSpells' sort never calls
    // its comparator at all (Dart's List.sort skips the comparator on a
    // one-element list) — the comparator guard is instead pinned by
    // spell_engine_test.dart's own regression test, which uses two
    // candidates to force it to run. What this test pins is the second
    // guard: before this fix, the per-suggestion calculateBreakdown loop
    // right after findSimilarSpells in _handleSpellCalculated had no
    // try/catch, so pressing Calculate for the same Technique+Form broke the
    // Create tab every time. It must survive and simply omit the bad spell
    // from `suggestions` instead — a spell with no level cannot be "similar
    // to" the one just calculated.
    'SpellCalculated survives when the engine holds an uncomputable spell of the same Technique and Form',
    build: () {
      final uncomputableRecord = Spell(
        id: 'uncomputable-1',
        name: 'Over-Discounted Spell',
        baseEffectId: creoIgnemEffect.id,
        technique: 'Creo',
        form: 'Ignem',
        rangeId: rangeParam.id,
        durationId: durationParam.id,
        targetId: targetParam.id,
        requisites: const {},
        adjustments: [LevelAdjustment(magnitude: -20, note: 'far too generous')],
        summary: 'Discounted so far it has no computable level.',
        provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final uncomputable = ResolvedSpell(
        record: uncomputableRecord, baseEffect: creoIgnemEffect,
        range: rangeParam, duration: durationParam, target: targetParam);
      return SpellCreationBloc(
        spellEngine: SpellEngine(allSpells: [uncomputable]),
        spellRepository: spellRepository,
      );
    },
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellCalculated());
    },
    skip: 6,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          // Base 10 + (10 magnitude * 5) = 60, same as the plain-draft test
          // above — proves the handler still reaches a normal calculated
          // state rather than throwing out of the bloc.
          .having((s) => s.breakdown?.level, 'breakdown.level', 60)
          .having((s) => s.validationErrors, 'validationErrors', isEmpty)
          // The uncomputable spell is dropped, not kept as a level-less
          // suggestion card.
          .having((s) => s.suggestions, 'suggestions', isEmpty)
          .having((s) => s.suggestionLevels.containsKey('uncomputable-1'), 'suggestionLevels',
              isFalse),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellSaveRequested saves the spell and emits saving then saved',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('My Fireball', summary: 'A jet of flame.'));
    },
    skip: 6,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.saved)
          .having((s) => s.savedSpell?.name, 'savedSpell.name', 'My Fireball'),
    ],
    verify: (_) async {
      final saved = await spellRepository.getAllUserSpells();
      expect(saved.length, 1);
      expect(saved.first.name, 'My Fireball');
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'savedSpell does not outlive the save it describes',
    // It is the payload of `status: saved`, exactly as errorMessage is the
    // payload of `status: error`: meaningful in the emit that writes it, stale
    // in every emit after. The snack bar reads it from a listener gated on that
    // status; nothing else may find it still sitting there one edit later.
    //
    // The follow-up event is added without waiting, which is safe and is half
    // the point: the bloc processes events strictly in arrival order, so this
    // RangeSelected lands on the state the completed save emitted.
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('My Fireball', summary: 'A jet of flame.'));
      bloc.add(RangeSelected(rangeParam));
    },
    wait: const Duration(milliseconds: 300),
    verify: (bloc) async {
      // That the save actually succeeded, so a save that merely failed cannot
      // pass this test by leaving savedSpell null for the wrong reason.
      final saved = await spellRepository.getAllUserSpells();
      expect(saved.length, 1);
      expect(bloc.state.status, SpellCreationStatus.editing);
      expect(bloc.state.savedSpell, isNull);
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a summary supplied at save time reaches the saved spell',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('My Fireball', summary: 'A jet of flame.'));
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.savedSpell?.summary, 'savedSpell.summary', 'A jet of flame.'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a draft summary survives a save that supplies none',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SummaryChanged('Typed while building.'));
      bloc.add(const SpellSaveRequested('My Fireball'));
    },
    skip: 8,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.savedSpell?.summary, 'savedSpell.summary', 'Typed while building.'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellSaveRequested resets to a fresh, empty draft after a successful save',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('My Fireball', summary: 'A jet of flame.'));
    },
    skip: 6,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.saved)
          .having((s) => s.draft.technique, 'draft.technique (reset)', isNull)
          .having((s) => s.draft.form, 'draft.form (reset)', isNull)
          .having((s) => s.draft.baseEffect, 'draft.baseEffect (reset)', isNull),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // Regression test for the pre-fix crash: the old handler had no
    // try/catch and always reused the same draft.id across saves, so a
    // second SpellSaveRequested hit sqflite's UNIQUE constraint (default
    // ConflictAlgorithm.abort) and threw, uncaught, straight out of the bloc.
    // Post-fix, a successful save resets to a fresh draft (new id), so
    // filling in and saving a second spell inserts a second, independent
    // row instead of colliding -- and this test would fail with an unhandled
    // exception if that were not the case.
    'save, then fill in and save again: both persist as distinct spells with no thrown error',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) async {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('First Spell', summary: 'A jet of flame.'));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      bloc.add(const TechniqueSelected('Rego'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(BaseEffect(
        id: 'e2', technique: 'Rego', form: 'Ignem',
        description: 'Redirect flame', baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      )));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('Second Spell', summary: 'Redirects flame elsewhere.'));
    },
    wait: const Duration(milliseconds: 300),
    verify: (_) async {
      final saved = await spellRepository.getAllUserSpells();
      expect(saved.length, 2);
      expect(saved.map((s) => s.name), containsAll(['First Spell', 'Second Spell']));
      expect(saved.map((s) => s.id).toSet().length, 2); // distinct ids, no collision
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellSaveRequested emits an error status (not a thrown exception) when the repository fails',
    build: () {
      final repo = MockSpellRepository();
      when(() => repo.saveSpell(any())).thenThrow(Exception('disk full'));
      return SpellCreationBloc(spellEngine: spellEngine, spellRepository: repo);
    },
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('Doomed Spell', summary: 'A jet of flame.'));
    },
    skip: 6,
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', contains('disk full'))
          // The in-progress draft is preserved (not reset) on failure, so the
          // user doesn't lose their work and can retry.
          .having((s) => s.draft.technique, 'draft.technique (preserved)', 'Creo')
          // The summary the save dialog collected must survive the failure
          // too -- it was applied to a local `draft`, not to state.draft,
          // so the error branch must emit that local draft rather than
          // state.draft, or a retry finds the dialog empty again.
          .having((s) => s.draft.summary, 'draft.summary (dialog-supplied, preserved on error)',
              'A jet of flame.'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // SpellDraft.toSpell throws StateError when validateSpellProse rejects a
    // draft with neither summary nor description -- normally unreachable
    // through the screen, since the save dialog always collects a summary
    // first when the draft has none, but the bloc's own handler must still
    // degrade to an error status rather than let that StateError escape
    // uncaught, the same contract the repository-failure test above pins.
    'SpellSaveRequested with no summary over a prose-less draft emits an error status '
    'instead of letting toSpell\'s StateError escape',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('Prose-less Spell'));
    },
    skip: 6,
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', contains('summary or a description')),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'TechniqueSelected clears a previously selected baseEffect',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const TechniqueSelected('Rego'));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.technique, 'draft.technique', 'Rego')
          .having((s) => s.draft.baseEffect, 'draft.baseEffect', isNull),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'FormSelected clears a previously selected baseEffect',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(const FormSelected('Corpus'));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.form, 'draft.form', 'Corpus')
          .having((s) => s.draft.baseEffect, 'draft.baseEffect', isNull),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellDiscarded resets to a fresh initial state',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const SpellDiscarded());
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.initial),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // All events go through a single on<SpellCreationEvent>() handler with a
    // sequential (asyncExpand) transformer, so a synchronous SpellDiscarded
    // dispatched right behind an async SpellSaveRequested cannot race ahead
    // of it -- it is guaranteed to be processed only after the save's saving
    // -> saved emissions have both landed. This exercises the exact
    // save/discard interleaving Issue 4 was concerned about.
    'SpellDiscarded dispatched immediately after SpellSaveRequested is processed strictly after '
    'the save completes, never racing ahead of it',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('Raced Spell', summary: 'A jet of flame.'));
      bloc.add(const SpellDiscarded());
    },
    skip: 6,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.saved)
          .having((s) => s.savedSpell?.name, 'savedSpell.name', 'Raced Spell'),
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.initial),
    ],
    verify: (_) async {
      final saved = await spellRepository.getAllUserSpells();
      expect(saved.length, 1);
      expect(saved.first.name, 'Raced Spell');
    },
  );

  // --- todo item 60: a draft starts at its guideline's own reference triple ---
  //
  // A separate engine from the shared `spellEngine` above, which is
  // deliberately built with an empty allParameters: every existing test in
  // this file therefore still exercises the "catalog unavailable, seed
  // degrades to null" path, and only the tests below see a catalog.

  Parameter seedParam(String id, String name, String category, int magnitude,
          {TargetType? targetType, ParameterScope scope = const ParameterScope(),
          List<TargetType> forbidsTargetTypes = const [], String? requiresRangeId}) =>
      Parameter(
        id: id, name: name, category: category, magnitude: magnitude,
        targetType: targetType, scope: scope,
        forbidsTargetTypes: forbidsTargetTypes, requiresRangeId: requiresRangeId,
        provenance: Provenance(
            source: PublicationSource.published,
            citations: const [Citation(bookId: 'arm5-core')]),
      );

  // Core 12086: a Personal Range forbids a container Target.
  final personal = seedParam('range-personal', 'Personal', 'Range', 0,
      forbidsTargetTypes: const [TargetType.container]);
  final touch = seedParam('range-touch', 'Touch', 'Range', 1);
  final voice = seedParam('range-voice', 'Voice', 'Range', 2);
  final momentary = seedParam('duration-momentary', 'Momentary', 'Duration', 0);
  final ring = seedParam('duration-ring', 'Ring', 'Duration', 2);
  final fire = seedParam('duration-fire', 'Fire', 'Duration', 1,
      scope: const ParameterScope(forms: ['Ignem', 'Imaginem']));
  final individual = seedParam('target-individual', 'Individual', 'Target', 0,
      targetType: TargetType.object);
  final circle = seedParam('target-circle', 'Circle', 'Target', 0,
      targetType: TargetType.container);
  final room = seedParam('target-room', 'Room', 'Target', 2,
      targetType: TargetType.container);
  // HoH:MC 1006: a Sensory Target requires Personal Range.
  final sound = seedParam('target-sound', 'Sound', 'Target', 2,
      targetType: TargetType.sensorium, requiresRangeId: 'range-personal');

  final seedCatalog = [personal, touch, voice, momentary, ring, fire,
      individual, circle, room, sound];

  // Reference Touch/Ring/Circle -- the shape all 12 ward guidelines carry.
  //
  // Deliberately given a numeric baseLevel rather than being General like the
  // real ward rows. Nothing in the seed rule reads `isGeneral`, and a General
  // entry would drag in an effectFormula and a chosenBaseLevel that these
  // tests would have to satisfy for no gain.
  final wardEffect = BaseEffect(
    id: 'ward-1', technique: 'Rego', form: 'Ignem',
    description: 'Ward against fire', baseLevel: 5,
    reference: const ParameterTriple(
        rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle'),
    provenance: Provenance(
        source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
  );

  // No `reference` at all -- falls back to ParameterTriple.standard(), like
  // 598 of the 611 catalog entries.
  final plainEffect = BaseEffect(
    id: 'plain-1', technique: 'Creo', form: 'Ignem',
    description: 'Create flame', baseLevel: 10,
    provenance: Provenance(
        source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
  );

  // A second guideline carrying the same Touch/Ring/Circle reference. Shape B
  // below needs the draft to already sit on a ward reference -- that is the
  // only way a chosen Personal Range reads as deliberate, since Personal is
  // also the standard reference value the comparison would call untouched.
  final wardEffect2 = BaseEffect(
    id: 'ward-2', technique: 'Rego', form: 'Aquam',
    description: 'Ward against water', baseLevel: 5,
    reference: const ParameterTriple(
        rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle'),
    provenance: Provenance(
        source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
  );

  SpellCreationBloc seedingBloc() => SpellCreationBloc(
        spellEngine: SpellEngine(allSpells: const [], allParameters: seedCatalog),
        spellRepository: spellRepository,
      );

  test('the initial state is seeded at the standard reference triple', () {
    final bloc = seedingBloc();
    expect(bloc.state.draft.range?.id, 'range-personal');
    expect(bloc.state.draft.duration?.id, 'duration-momentary');
    expect(bloc.state.draft.target?.id, 'target-individual');
    bloc.close();
  });

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellDiscarded resets to a draft seeded at the standard reference triple',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(RangeSelected(voice));
      bloc.add(const SpellDiscarded());
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.initial)
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-momentary')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-individual'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'the post-save reset is seeded at the standard reference triple',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(plainEffect));
      bloc.add(RangeSelected(voice));
      bloc.add(const SpellSaveRequested('Seeded Spell', summary: 'A jet of flame.'));
    },
    skip: 4,
    wait: const Duration(milliseconds: 300),
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.saved)
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-momentary')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-individual'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'selecting a ward guideline adopts its Touch/Ring/Circle reference when the '
    'draft is still at the previous guideline reference',
    build: seedingBloc,
    act: (bloc) => bloc.add(BaseEffectSelected(wardEffect)),
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-touch')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-circle'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a deliberately chosen parameter survives a guideline switch',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(RangeSelected(voice));
      bloc.add(DurationSelected(ring));
      bloc.add(TargetSelected(room));
      bloc.add(BaseEffectSelected(wardEffect));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-voice')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-room'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // Shape A of todo item 74. The Duration assertion is the point of the
    // "per-slot" half: the Range seed is refused, but Duration has no
    // cross-field constraint and must still follow the new guideline.
    'the adopt is per-slot, and a Range seed that a chosen Target forbids is '
    'not written',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(BaseEffectSelected(wardEffect));  // -> touch / ring / circle
      bloc.add(TargetSelected(room));            // deliberately off the seed
      bloc.add(BaseEffectSelected(plainEffect)); // reference: standard
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>()
          // Personal + Room is what check 10 rejects, so the Range keeps its
          // pre-adoption value instead of following the new guideline.
          .having((s) => s.draft.range?.id, 'draft.range', 'range-touch')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-momentary')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-room'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // Shape B of todo item 74, the forbidding direction reached from the other
    // side: the seed wants to write the container Target, and a deliberate
    // Personal Range is what forbids it. RangeSelected(personal) is only
    // *deliberate* because the outgoing reference named Touch.
    'a container Target seed that a chosen Personal Range forbids is not written',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(BaseEffectSelected(wardEffect)); // -> touch / ring / circle
      bloc.add(RangeSelected(personal));        // clears Circle; off the seed
      bloc.add(BaseEffectSelected(wardEffect2));// reference: touch / ring / circle
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.target, 'draft.target', isNull)
          // Duration carries no cross-field constraint and still adopts.
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring')
          .having((s) => s.draft.containerMode, 'draft.containerMode',
              ContainerMode.unstated),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // Shape C of todo item 74 -- the regression no value comparison can see.
    // TargetSelected(sound) sets range-personal itself, to satisfy check 11.
    // range-personal is also the standard reference value, so the seed cannot
    // tell that bloc-written Range apart from an untouched slot and would
    // re-seed it to Touch, out from under the Target that required it.
    'a Range seed is not written over the Range a Sensory Target requires',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(TargetSelected(sound));          // forces Range -> Personal
      bloc.add(BaseEffectSelected(wardEffect)); // reference: touch / ring / circle
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-sound')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'adopting a non-container Target clears a container mode stated under the old one',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(BaseEffectSelected(wardEffect)); // Target -> Circle (container)
      bloc.add(const ContainerModeSelected(ContainerMode.dynamic));
      bloc.add(BaseEffectSelected(plainEffect)); // Target -> Individual (object)
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.target?.id, 'draft.target', 'target-individual')
          .having((s) => s.draft.containerMode, 'draft.containerMode',
              ContainerMode.unstated),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // TechniqueSelected/FormSelected never touched containerMode before the
    // reference-seed rule; only BaseEffectSelected has a test for it above.
    // This pins the same clearing behaviour reached through TechniqueSelected's
    // re-seed: without it, validateSpellAgainstCatalog's check 9 would reject
    // the save with no visible cause.
    'changing Technique clears a container mode stranded by the Target re-seed',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(BaseEffectSelected(wardEffect)); // Target -> Circle (container)
      bloc.add(const ContainerModeSelected(ContainerMode.dynamic));
      bloc.add(const TechniqueSelected('Creo')); // guideline cleared, Target -> Individual (object)
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.target?.id, 'draft.target', 'target-individual')
          .having((s) => s.draft.containerMode, 'draft.containerMode',
              ContainerMode.unstated),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a container mode survives a seed that lands on another container Target',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(TargetSelected(room));
      bloc.add(const ContainerModeSelected(ContainerMode.dynamic));
      bloc.add(BaseEffectSelected(wardEffect)); // Target stays Room (chosen)
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.target?.id, 'draft.target', 'target-room')
          .having((s) => s.draft.containerMode, 'draft.containerMode',
              ContainerMode.dynamic),
    ],
  );

  group('Range and Target prune each other', () {
    // Peers, unlike the Technique/Form scope axes: neither is upstream of
    // the other, so pruning has to run both ways -- the field just edited
    // wins and the conflicting peer yields.

    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting Personal Range clears a container Target and its mode',
      build: seedingBloc,
      act: (bloc) => bloc
        ..add(TargetSelected(room))
        ..add(const ContainerModeSelected(ContainerMode.static))
        ..add(RangeSelected(personal)),
      verify: (bloc) {
        expect(bloc.state.draft.target, isNull);
        expect(bloc.state.draft.containerMode, ContainerMode.unstated);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting a container Target clears a Personal Range',
      build: seedingBloc,
      act: (bloc) => bloc
        ..add(RangeSelected(personal))
        ..add(TargetSelected(room)),
      verify: (bloc) {
        expect(bloc.state.draft.range, isNull);
        expect(bloc.state.draft.target, room);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting a Sensory Target sets the Range it requires',
      build: seedingBloc,
      act: (bloc) => bloc
        ..add(RangeSelected(voice))
        ..add(TargetSelected(sound)),
      verify: (bloc) {
        expect(bloc.state.draft.range?.id, 'range-personal');
        expect(bloc.state.draft.target, sound);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting a Range that conflicts with a Target-forced Range clears the Target',
      // sound forces Range to Personal (requiresRangeId). Picking Touch next
      // -- a Range sound never named -- must not leave sound behind: that
      // pairing is exactly what check 11 rejects.
      build: seedingBloc,
      act: (bloc) => bloc
        ..add(TargetSelected(sound))
        ..add(RangeSelected(touch)),
      verify: (bloc) {
        expect(bloc.state.draft.range, touch);
        expect(bloc.state.draft.target, isNull);
        expect(bloc.state.draft.containerMode, ContainerMode.unstated);
      },
    );
  });

  blocTest<SpellCreationBloc, SpellCreationState>(
    'adopting Ring drops a lastingCreation declaration, which is only true at Momentary',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));   // Creo + Momentary seed
      bloc.add(BaseEffectSelected(wardEffect));    // -> Duration Ring
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring')
          .having((s) => s.draft.ritualDeclaration, 'draft.ritualDeclaration',
              RitualDeclaration.none),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a guideline whose reference names a Form-scoped parameter out of scope for '
    'the draft is not adopted',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(const FormSelected('Aquam'));
      bloc.add(BaseEffectSelected(BaseEffect(
        id: 'fire-ref', technique: 'Creo', form: 'Ignem',
        description: 'Priced against Fire duration', baseLevel: 5,
        reference: const ParameterTriple(
            rangeId: 'range-personal',
            durationId: 'duration-fire',
            targetId: 'target-individual'),
        provenance: Provenance(source: PublicationSource.userCreated),
      )));
    },
    skip: 1,
    expect: () => [
      // Fire is Ignem/Imaginem only; the draft is Aquam, so the seed is
      // skipped and the Momentary already there is left alone.
      isA<SpellCreationState>()
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-momentary'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'changing Technique clears the guideline and returns an untouched draft to '
    'the standard reference triple',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(BaseEffectSelected(wardEffect)); // -> touch / ring / circle
      bloc.add(const TechniqueSelected('Creo')); // guideline cleared
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.baseEffect, 'draft.baseEffect', isNull)
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-momentary')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-individual'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'changing Form refills a Form-scoped Duration it just pruned',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(const FormSelected('Ignem'));
      bloc.add(DurationSelected(fire)); // Fire is Ignem/Imaginem only
      bloc.add(const FormSelected('Aquam'));
    },
    skip: 2,
    expect: () => [
      // Pruned out of scope, then refilled by the seed rather than left blank.
      isA<SpellCreationState>()
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-momentary'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'changing Form leaves a deliberately chosen, still-in-scope parameter alone',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(RangeSelected(voice));
      bloc.add(const FormSelected('Aquam'));
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-voice'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // rangeId is deliberately 'range-personal' -- the standard triple's own
    // Range value -- rather than another off-seed choice like voice. If
    // TemplateInstantiated were ever wired through _withSeededParameters (the
    // regression this test exists to catch), previousReference would be the
    // standard triple, this Range would look untouched, and the seed would
    // overwrite it with wardEffect's reference Range (Touch). Duration and
    // Target keep off-standard values so the test still covers "a chosen
    // value survives" alongside "the standard-looking one isn't rewritten".
    'TemplateInstantiated keeps the template parameters verbatim, unseeded',
    build: seedingBloc,
    act: (bloc) => bloc.add(TemplateInstantiated(ResolvedTemplate(
      record: SpellTemplate(
        id: 'tpl-seed', name: 'Voiced Ward', baseEffectId: 'ward-1',
        technique: 'Rego', form: 'Ignem',
        rangeId: 'range-personal', durationId: 'duration-ring', targetId: 'target-room',
        summary: 'A published template whose parameters must survive verbatim.',
        provenance: Provenance(source: PublicationSource.published,
            citations: const [Citation(bookId: 'arm5-core')]),
      ),
      baseEffect: wardEffect,
      range: personal, duration: ring, target: room,
    ))),
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-room'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'RequisiteAdded appends a requisite of the given kind',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const RequisiteAdded('Auram', 'free'));
      bloc.add(const RequisiteAdded('Terram', 'adding'));
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>().having(
        (s) => s.draft.requisites.entries.map((e) => '${e.key}:${e.value.name}'),
        'requisites',
        ['Auram:free', 'Terram:adding'],
      ),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'RequisiteKindChanged flips only the named art, leaving the others alone',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const RequisiteAdded('Auram', 'free'));
      bloc.add(const RequisiteAdded('Terram', 'free'));
      bloc.add(const RequisiteKindChanged('Terram', 'adding'));
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>().having(
        (s) => s.draft.requisites.entries.map((e) => '${e.key}:${e.value.name}'),
        'requisites',
        ['Auram:free', 'Terram:adding'],
      ),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'RequisiteRemoved drops only the named art',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const RequisiteAdded('Auram', 'free'));
      bloc.add(const RequisiteAdded('Terram', 'adding'));
      bloc.add(const RequisiteRemoved('Auram'));
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>().having(
        (s) => s.draft.requisites.keys,
        'requisites',
        ['Terram'],
      ),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'an adding requisite raises the calculated level by one magnitude',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const RequisiteAdded('Auram', 'adding'));
      bloc.add(const SpellCalculated());
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          // Base 10 exceeds the additive cap, so the parameters' 10 magnitude
          // plus the requisite's 1 all fall in the multiplier tier:
          // 10 + (11 * 5) = 65, i.e. 5 more than the same draft without it.
          .having((s) => s.breakdown?.level, 'breakdown.level', 65),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a free requisite leaves the calculated level unchanged',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const RequisiteAdded('Auram', 'free'));
      bloc.add(const SpellCalculated());
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          // Same 60 as the no-requisite case: a free requisite adds 0.
          .having((s) => s.breakdown?.level, 'breakdown.level', 60),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated reports a requisite that duplicates the spell\'s own form',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const RequisiteAdded('Ignem', 'adding'));
      bloc.add(const SpellCalculated());
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having(
            (s) => s.validationErrors,
            'validationErrors',
            contains(const RequisiteIsOwnArt()),
          ),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'AvailableModifiersSynced updates the SpellEngine so a newly available custom '
    'modifier resolves during SpellCalculated instead of being ignored',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(allSpells: const []),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      final newModifier = Modifier(
        id: 'custom-1',
        name: 'Custom Complexity',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Creo', form: 'Ignem'),
        options: [ModifierOption(id: 'opt-1', label: 'Custom', magnitude: 3)],
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(AvailableModifiersSynced([newModifier]));
      bloc.add(const ModifierOptionSelected('custom-1', 'opt-1'));
      bloc.add(const SpellCalculated());
    },
    skip: 6,
    expect: () => [
      isA<SpellCreationState>().having(
          (s) => s.draft.selectedModifiers['custom-1'], 'selectedModifiers', ['opt-1']),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          // Base 10 already exceeds the additive-tier cap of 5, so all of
          // Range(+2) + Duration(+0) + Target(+8) + Custom(+3) = 13 magnitude
          // falls in the multiplier tier: 10 + (13 * 5) = 75.
          .having((s) => s.breakdown?.level, 'breakdown.level', 75),
    ],
  );

  final materialModifier = Modifier(
    id: 'terram-material',
    name: 'Material difficulty',
    selectionMode: ModifierSelectionMode.single,
    scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
    options: [
      ModifierOption(id: 'mat-stone', label: 'Stone', magnitude: 1),
      ModifierOption(id: 'mat-metal', label: 'Metal', magnitude: 2),
    ],
    provenance: Provenance(
      source: PublicationSource.published,
      citations: const [Citation(bookId: 'arm5-core')],
    ),
  );
  final reteEffect = BaseEffect(
    id: 'rete-4', technique: 'Rego', form: 'Terram',
    description: 'Transport a non-living object', baseLevel: 4,
    provenance: Provenance(source: PublicationSource.userCreated),
  );

  final sizeMentemModifier = Modifier(
    id: 'size-mentem',
    name: 'Size',
    selectionMode: ModifierSelectionMode.single,
    scope: const ModifierScope(form: 'Mentem', excludeTargets: ['target-individual']),
    options: [ModifierOption(id: 'size-mentem-1', label: 'Up to 10x base', magnitude: 1)],
    provenance: Provenance(
      source: PublicationSource.published,
      citations: const [Citation(bookId: 'arm5-core')],
    ),
  );
  final individualTarget = Parameter(
      id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 8,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final groupTarget = Parameter(
      id: 'target-group', name: 'Group', category: 'Target', magnitude: 10,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

  blocTest<SpellCreationBloc, SpellCreationState>(
    'ModifierOptionSelected on a single-select modifier replaces the previous option',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(
          allSpells: const [], allModifiers: [materialModifier]),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Rego'));
      bloc.add(const FormSelected('Terram'));
      bloc.add(BaseEffectSelected(reteEffect));
      bloc.add(const ModifierOptionSelected('terram-material', 'mat-stone'));
      bloc.add(const ModifierOptionSelected('terram-material', 'mat-metal'));
    },
    skip: 4,
    expect: () => [
      isA<SpellCreationState>().having(
        (s) => s.draft.selectedModifiers['terram-material'],
        'selectedModifiers',
        ['mat-metal'],
      ),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'ModifierOptionSelected on a multi-select modifier appends',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(
        allSpells: const [],
        allModifiers: [
          Modifier(
            id: 'crim-complexity',
            name: 'Complexity',
            selectionMode: ModifierSelectionMode.multi,
            scope: const ModifierScope(technique: 'Creo', form: 'Imaginem'),
            options: [
              ModifierOption(id: 'a', label: 'A', magnitude: 1),
              ModifierOption(id: 'b', label: 'B', magnitude: 1),
            ],
            provenance: Provenance(
              source: PublicationSource.published,
              citations: const [Citation(bookId: 'arm5-core')],
            ),
          ),
        ],
      ),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Imaginem'));
      bloc.add(const ModifierOptionSelected('crim-complexity', 'a'));
      bloc.add(const ModifierOptionSelected('crim-complexity', 'b'));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>().having(
          (s) => s.draft.selectedModifiers['crim-complexity'], 'selectedModifiers', ['a', 'b']),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'ModifierOptionDeselected removes the option and drops the key when empty',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(
          allSpells: const [], allModifiers: [materialModifier]),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Rego'));
      bloc.add(const FormSelected('Terram'));
      bloc.add(BaseEffectSelected(reteEffect));
      bloc.add(const ModifierOptionSelected('terram-material', 'mat-metal'));
      bloc.add(const ModifierOptionDeselected('terram-material', 'mat-metal'));
    },
    skip: 4,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.selectedModifiers, 'selectedModifiers', isEmpty),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'changing Form prunes a selection the new Form does not offer',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(
          allSpells: const [], allModifiers: [materialModifier]),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Rego'));
      bloc.add(const FormSelected('Terram'));
      bloc.add(BaseEffectSelected(reteEffect));
      bloc.add(const ModifierOptionSelected('terram-material', 'mat-metal'));
      bloc.add(const FormSelected('Ignem'));
    },
    skip: 4,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.selectedModifiers, 'selectedModifiers (pruned)', isEmpty),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'changing Target to one excluded by scope prunes a selection that depended on it',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(
          allSpells: const [], allModifiers: [sizeMentemModifier]),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Mentem'));
      bloc.add(const ModifierOptionSelected('size-mentem', 'size-mentem-1'));
      bloc.add(TargetSelected(individualTarget));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.selectedModifiers, 'selectedModifiers (pruned)', isEmpty),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'changing Target to one still allowed by scope keeps the selection',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(
          allSpells: const [], allModifiers: [sizeMentemModifier]),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Mentem'));
      bloc.add(const ModifierOptionSelected('size-mentem', 'size-mentem-1'));
      bloc.add(TargetSelected(groupTarget));
    },
    skip: 3,
    expect: () => [
      isA<SpellCreationState>().having(
        (s) => s.draft.selectedModifiers['size-mentem'],
        'selectedModifiers',
        ['size-mentem-1'],
      ),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SpellCalculated exposes a breakdown listing the selected modifier',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(
          allSpells: const [], allModifiers: [materialModifier]),
      spellRepository: spellRepository,
    ),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Rego'));
      bloc.add(const FormSelected('Terram'));
      bloc.add(BaseEffectSelected(reteEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const ModifierOptionSelected('terram-material', 'mat-metal'));
      bloc.add(const SpellCalculated());
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.calculated)
          .having(
            (s) => s.breakdown?.contributions.any((c) =>
                c.source is ModifierContribution &&
                (c.source as ModifierContribution).optionLabel.contains('Metal')),
            'breakdown mentions the modifier',
            isTrue,
          ),
    ],
  );

  group('ritual declaration', () {
    final momentary = Parameter(
      id: 'duration-momentary', name: 'Momentary', category: 'Duration',
      magnitude: 0, provenance: Provenance(source: PublicationSource.userCreated),
    );
    final sun = Parameter(
      id: 'duration-sun', name: 'Sun', category: 'Duration',
      magnitude: 2, provenance: Provenance(source: PublicationSource.userCreated),
    );
    final suggestedHealing = BaseEffect(
      id: 'crco-35a', technique: 'Creo', form: 'Corpus',
      description: 'Heal all wounds', baseLevel: 35,
      ritualRequirement: RitualRequirement.suggested,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    final plainCreo = BaseEffect(
      id: 'crte-15a', technique: 'Creo', form: 'Terram',
      description: 'Create precious metal', baseLevel: 15,
      provenance: Provenance(source: PublicationSource.userCreated),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'defaults to lastingCreation for any Creo + Momentary draft',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(BaseEffectSelected(plainCreo)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.lastingCreation),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'defaults to lastingCreation for a suggested healing effect too',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(BaseEffectSelected(suggestedHealing)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.lastingCreation),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'does not default for a non-Creo technique',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Perdo'))
        ..add(DurationSelected(momentary)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'does not default for a non-Momentary duration',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(sun)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'respects an explicit clear and does not re-tick on an unrelated event',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(const RitualDeclarationChanged(RitualDeclaration.none))
        ..add(const FormSelected('Terram')),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'prunes lastingCreation when the draft leaves Creo + Momentary',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(DurationSelected(sun)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'prunes lastingCreation when the technique leaves Creo',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(const TechniqueSelected('Muto')),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'never prunes a storyguideRuling',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Perdo'))
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(DurationSelected(sun)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'never prunes a storyguideRuling on TechniqueSelected',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(const TechniqueSelected('Creo')),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'never prunes a storyguideRuling on FormSelected',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(const FormSelected('Terram')),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'never prunes a storyguideRuling on BaseEffectSelected',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(BaseEffectSelected(plainCreo)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    // The first two events establish the lastingCreation default -- see
    // 'defaults to lastingCreation for any Creo + Momentary draft' above,
    // which proves that premise directly.
    blocTest<SpellCreationBloc, SpellCreationState>(
      'switching from lastingCreation to storyguideRuling replaces the declaration',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    // The first two events establish the lastingCreation default -- see
    // 'defaults to lastingCreation for any Creo + Momentary draft' above,
    // which proves that premise directly.
    blocTest<SpellCreationBloc, SpellCreationState>(
      'an explicit clear from storyguideRuling reports none, not the lastingCreation default',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(const RitualDeclarationChanged(RitualDeclaration.none)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );
  });

  blocTest<SpellCreationBloc, SpellCreationState>(
    'AdjustmentAdded appends a zero-magnitude row',
    build: () => SpellCreationBloc(
        spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc.add(const AdjustmentAdded()),
    verify: (bloc) {
      expect(bloc.state.draft.adjustments.length, 1);
      expect(bloc.state.draft.adjustments.first.magnitude, 0);
      // LevelAdjustment rejects a blank note, so the new row cannot start
      // empty. This literal is what the note field shows until the user types
      // over it, and what AdjustmentUpdated falls back to when the user
      // clears the field.
      expect(bloc.state.draft.adjustments.first.note, '(describe this adjustment)');
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'AdjustmentUpdated replaces the row at that index',
    build: () => SpellCreationBloc(
        spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc
      ..add(const AdjustmentAdded())
      ..add(const AdjustmentUpdated(0, -1, 'because the old limb is needed')),
    verify: (bloc) {
      expect(bloc.state.draft.adjustments.first.magnitude, -1);
      expect(bloc.state.draft.adjustments.first.note,
          'because the old limb is needed');
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'AdjustmentRemoved drops only that row and keeps the rest in order',
    build: () => SpellCreationBloc(
        spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc
      ..add(const AdjustmentAdded())
      ..add(const AdjustmentUpdated(0, 1, 'first'))
      ..add(const AdjustmentAdded())
      ..add(const AdjustmentUpdated(1, 2, 'second'))
      ..add(const AdjustmentRemoved(0)),
    verify: (bloc) {
      expect(bloc.state.draft.adjustments.map((a) => a.note).toList(), ['second']);
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'AdjustmentUpdated with a blank note keeps the previous note instead of throwing',
    // The note field commits on every focus loss, so select-all, delete, tab
    // away arrives as AdjustmentUpdated(0, 0, ''). LevelAdjustment rejects a
    // blank note, and constructing one here threw FormatException out of the
    // handler: no state emitted, the field showing empty over a draft that
    // still held the old value, and the next edit operating on stale data.
    build: () => SpellCreationBloc(
        spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc
      ..add(const AdjustmentAdded())
      ..add(const AdjustmentUpdated(0, -1, 'because the old limb is needed'))
      ..add(const AdjustmentUpdated(0, -1, '')),
    verify: (bloc) {
      expect(bloc.state.draft.adjustments.first.note,
          'because the old limb is needed');
      expect(bloc.state.draft.adjustments.first.magnitude, -1);
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a whitespace-only note is blank too, and the magnitude in the event still applies',
    build: () => SpellCreationBloc(
        spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc
      ..add(const AdjustmentAdded())
      ..add(const AdjustmentUpdated(0, 1, 'see through intervening material'))
      ..add(const AdjustmentUpdated(0, 2, '   ')),
    verify: (bloc) {
      expect(bloc.state.draft.adjustments.first.note,
          'see through intervening material');
      expect(bloc.state.draft.adjustments.first.magnitude, 2);
    },
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'an out-of-range index is ignored rather than throwing',
    build: () => SpellCreationBloc(
        spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc
      ..add(const AdjustmentRemoved(0))
      ..add(const AdjustmentUpdated(3, 1, 'nowhere')),
    verify: (bloc) => expect(bloc.state.draft.adjustments, isEmpty),
  );

  group('General guideline level (ChosenBaseLevelChanged / generalEffectSentence)', () {
    // Modeled on test/engine/general_effect_test.dart's wardGuideline: a
    // ward, whose strength is simply the chosen base level (pevi-G4-ish
    // mightThreshold, multiplier one, no offset).
    final wardGuideline = BaseEffect(
      id: 'rean-gen', technique: 'Rego', form: 'Animal',
      description: 'Ward against beings associated with Animal',
      baseLevel: null,
      reference: const ParameterTriple(
          rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle'),
      provenance: Provenance(source: PublicationSource.published,
          citations: [Citation(bookId: 'arm5-core')]),
      effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
    );

    // A second, distinct General guideline, so "switch to a different
    // General guideline" is actually a different BaseEffect and not just a
    // re-selection of the same one.
    final anotherGeneralGuideline = BaseEffect(
      id: 'peco-gen', technique: 'Perdo', form: 'Corpus',
      description: 'General guideline for test',
      baseLevel: null,
      provenance: Provenance(source: PublicationSource.published,
          citations: [Citation(bookId: 'arm5-core')]),
      effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightReduction),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'ChosenBaseLevelChanged sets draft.chosenBaseLevel once a General guideline is selected',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(wardGuideline))
        ..add(const ChosenBaseLevelChanged(20)),
      verify: (bloc) => expect(bloc.state.draft.chosenBaseLevel, 20),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'ChosenBaseLevelChanged(null) actually clears the level -- the path the screen '
      'takes when the user empties the field -- rather than no-op-ing',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(wardGuideline))
        ..add(const ChosenBaseLevelChanged(20))
        ..add(const ChosenBaseLevelChanged(null)),
      verify: (bloc) => expect(bloc.state.draft.chosenBaseLevel, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting a non-General effect afterwards clears chosenBaseLevel',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(wardGuideline))
        ..add(const ChosenBaseLevelChanged(20))
        ..add(BaseEffectSelected(creoIgnemEffect)),
      verify: (bloc) => expect(bloc.state.draft.chosenBaseLevel, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting a different General effect afterwards keeps chosenBaseLevel',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(wardGuideline))
        ..add(const ChosenBaseLevelChanged(20))
        ..add(BaseEffectSelected(anotherGeneralGuideline)),
      verify: (bloc) => expect(bloc.state.draft.chosenBaseLevel, 20),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'TechniqueSelected clears both chosenBaseLevel and templateId',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(baseEffect: wardGuideline, chosenBaseLevel: 20, templateId: 'tpl-1'),
      ),
      act: (bloc) => bloc.add(const TechniqueSelected('Muto')),
      verify: (bloc) {
        expect(bloc.state.draft.chosenBaseLevel, isNull);
        expect(bloc.state.draft.templateId, isNull);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'FormSelected clears both chosenBaseLevel and templateId',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(baseEffect: wardGuideline, chosenBaseLevel: 20, templateId: 'tpl-1'),
      ),
      act: (bloc) => bloc.add(const FormSelected('Corpus')),
      verify: (bloc) {
        expect(bloc.state.draft.chosenBaseLevel, isNull);
        expect(bloc.state.draft.templateId, isNull);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'BaseEffectSelected clears a previously set templateId',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      // SpellCreationState.status is required, so (unlike the plan's Task 13
      // snippet) this must pass one -- see Correction 4.
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(templateId: 'tpl-1'),
      ),
      act: (bloc) => bloc.add(BaseEffectSelected(creoIgnemEffect)),
      verify: (bloc) => expect(bloc.state.draft.templateId, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'generalEffectSentence is null when a General guideline is selected but no level is chosen yet',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(BaseEffectSelected(wardGuideline)),
      verify: (bloc) => expect(bloc.state.generalEffectSentence, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'generalEffectSentence mentions the derived threshold once a General guideline '
      'and a level are both set',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(wardGuideline))
        ..add(const ChosenBaseLevelChanged(20)),
      verify: (bloc) {
        // mightThreshold, multiplier one, no offset: the threshold is simply
        // the chosen level -- "Affects beings with Might 20 or less".
        expect(bloc.state.generalEffectSentence, isNotNull);
        expect(bloc.state.generalEffectSentence, contains('20'));
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'generalEffectSentence goes back to null after a non-General effect is selected',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(wardGuideline))
        ..add(const ChosenBaseLevelChanged(20))
        ..add(BaseEffectSelected(creoIgnemEffect)),
      verify: (bloc) => expect(bloc.state.generalEffectSentence, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'generalEffectSentence survives an edit that moves neither of its inputs',
      // The funnel recomputes it on every emit now, rather than copyWith
      // carrying it forward, so every event is a fresh chance to get it wrong
      // -- including the great majority that touch neither the base effect nor
      // the chosen level. RangeSelected stands for all of them.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(wardGuideline))
        ..add(const ChosenBaseLevelChanged(20))
        ..add(RangeSelected(rangeParam)),
      verify: (bloc) => expect(bloc.state.generalEffectSentence, contains('20')),
    );
  });

  group('Open slots (OpenSlotChosen)', () {
    final realmSlotGuideline = BaseEffect(
      id: 'revi-G1', technique: 'Rego', form: 'Vim',
      description: 'Ward against beings from one realm', baseLevel: null,
      openSlots: const [OpenSlotKind.realm],
      reference: const ParameterTriple(
          rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle'),
      provenance: Provenance(source: PublicationSource.published,
          citations: [Citation(bookId: 'arm5-core')]),
      effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'OpenSlotChosen sets the named key in draft.chosenSlots',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(realmSlotGuideline))
        ..add(const OpenSlotChosen('realm', 'Infernal')),
      verify: (bloc) => expect(bloc.state.draft.chosenSlots, {'realm': 'Infernal'}),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting a different base effect prunes chosenSlots keys the new effect does not declare open',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(realmSlotGuideline))
        ..add(const OpenSlotChosen('realm', 'Infernal'))
        ..add(BaseEffectSelected(creoIgnemEffect)),
      verify: (bloc) => expect(bloc.state.draft.chosenSlots, isEmpty),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'TechniqueSelected clears chosenSlots, same as chosenBaseLevel',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(realmSlotGuideline))
        ..add(const OpenSlotChosen('realm', 'Infernal'))
        ..add(const TechniqueSelected('Perdo')),
      verify: (bloc) => expect(bloc.state.draft.chosenSlots, isEmpty),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'TemplateInstantiated copies the template chosenSlots onto the new draft',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) {
        final template = SpellTemplate(
          id: 'tpl-1', name: 'Circular Ward against Demons',
          baseEffectId: realmSlotGuideline.id,
          technique: 'Rego',
          form: 'Vim',
          rangeId: 'p1', durationId: 'p2', targetId: 'p3',
          chosenSlots: const {'realm': 'Infernal'},
          description: 'No being from the chosen realm can affect those targeted by the spell.',
          provenance: Provenance(source: PublicationSource.published,
              citations: const [Citation(bookId: 'arm5-core')]),
        );
        final resolved = ResolvedTemplate(
          record: template,
          baseEffect: realmSlotGuideline,
          range: rangeParam, duration: durationParam, target: targetParam,
        );
        bloc.add(TemplateInstantiated(resolved));
      },
      verify: (bloc) => expect(bloc.state.draft.chosenSlots, {'realm': 'Infernal'}),
    );
  });

  group('TemplateInstantiated', () {
    // The real ward template (Correction 4) -- built by hand, not loaded from
    // the asset file, per the same rule as the other fixtures in this file.
    final touchParam = Parameter(
      id: 'range-touch', name: 'Touch', category: 'Range', magnitude: 1,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final ringParam = Parameter(
      id: 'duration-ring', name: 'Ring', category: 'Duration', magnitude: 2,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final circleParam = Parameter(
      id: 'target-circle', name: 'Circle', category: 'Target', magnitude: 1,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final wardBaseEffect = BaseEffect(
      id: 'reaq-gen', technique: 'Rego', form: 'Aquam',
      description: 'Ward against beings associated with Aquam',
      baseLevel: null,
      reference: const ParameterTriple(
          rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle'),
      provenance: Provenance(source: PublicationSource.published,
          citations: [Citation(bookId: 'arm5-core')]),
      effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
    );
    final wardTemplateRecord = SpellTemplate(
      id: 'tpl-reaq-ward-against-faeries-waters',
      name: 'Ward against Faeries of the Waters',
      baseEffectId: 'reaq-gen',
      technique: 'Rego',
      form: 'Aquam',
      rangeId: 'range-touch',
      durationId: 'duration-ring',
      targetId: 'target-circle',
      description: 'No water faerie whose Faerie Might is equal to or less than '
          'the level of the spell can affect those targeted by the spell.',
      provenance: Provenance(source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
      // ritualDeclaration omitted -> RitualDeclaration.none, as on the real asset.
      // A Circle Target (target-circle) is a container, so this template
      // carries a real static/dynamic decision -- proves TemplateInstantiated
      // copies it rather than silently dropping it (Task 6's backfill records
      // dynamic for the real asset).
      containerMode: ContainerMode.dynamic,
    );
    final wardTemplate = ResolvedTemplate(
      record: wardTemplateRecord,
      baseEffect: wardBaseEffect,
      range: touchParam,
      duration: ringParam,
      target: circleParam,
    );

    // The real Disenchant template (Correction 4/5): Perdo Vim, General,
    // Touch/Momentary/Individual, and it declares lastingCreation on the
    // asset itself -- despite not being Creo + Momentary, the one case
    // _withRitualDeclaration would normally default it for. Proves the
    // handler takes the declaration verbatim rather than re-deriving it.
    final individualParam = Parameter(
      id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final disenchantBaseEffect = BaseEffect(
      id: 'pevi-G9', technique: 'Perdo', form: 'Vim',
      description: 'Dispel Hermetic enchantment',
      baseLevel: null,
      ritualRequirement: RitualRequirement.required,
      provenance: Provenance(source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
      effectFormula: const GeneralEffectFormula(
          kind: GeneralEffectKind.targetSpellLevel, offsetMagnitudes: 1, stressDie: true),
    );
    final disenchantTemplateRecord = SpellTemplate(
      id: 'tpl-pevi-disenchant',
      name: 'Disenchant',
      baseEffectId: 'pevi-G9',
      technique: 'Perdo',
      form: 'Vim',
      rangeId: 'range-touch',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      description: 'Destroy a Hermetic magic item\'s enchantments permanently.',
      provenance: Provenance(source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
      ritualDeclaration: RitualDeclaration.lastingCreation,
    );
    final disenchantTemplate = ResolvedTemplate(
      record: disenchantTemplateRecord,
      baseEffect: disenchantBaseEffect,
      range: touchParam,
      duration: durationParam,
      target: individualParam,
    );

    final unresolvedTemplate = ResolvedTemplate(
      record: wardTemplateRecord,
      baseEffect: null,
      range: touchParam,
      duration: ringParam,
      target: circleParam,
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'sets baseEffect, range, duration, target, technique, form, summary, description and '
      'templateId, but leaves chosenBaseLevel null -- the one thing the user is there to supply',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(TemplateInstantiated(wardTemplate)),
      verify: (bloc) {
        final draft = bloc.state.draft;
        expect(draft.baseEffect, wardBaseEffect);
        expect(draft.range, touchParam);
        expect(draft.duration, ringParam);
        expect(draft.target, circleParam);
        expect(draft.technique, 'Rego');
        expect(draft.form, 'Aquam');
        expect(draft.summary, wardTemplateRecord.summary);
        expect(draft.description, wardTemplateRecord.description);
        expect(draft.templateId, 'tpl-reaq-ward-against-faeries-waters');
        expect(draft.chosenBaseLevel, isNull);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'copies the template containerMode onto the new draft',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(TemplateInstantiated(wardTemplate)),
      verify: (bloc) => expect(bloc.state.draft.containerMode, ContainerMode.dynamic),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'gives the draft a fresh id, not the id of whatever draft was in progress',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(id: 'in-progress-draft-id', technique: 'Creo'),
      ),
      act: (bloc) => bloc.add(TemplateInstantiated(wardTemplate)),
      verify: (bloc) => expect(bloc.state.draft.id, isNot('in-progress-draft-id')),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'clears a previous calculation',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.calculated,
        draft: SpellDraft(),
      ),
      act: (bloc) => bloc.add(TemplateInstantiated(wardTemplate)),
      verify: (bloc) => expect(bloc.state.breakdown, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      // Every other base-effect-changing handler runs the draft through
      // _withRitualDeclaration, which would wipe this since Perdo Vim +
      // Momentary is not Creo + Momentary (Correction 5). A template's
      // declaration is published catalog data, taken verbatim.
      "tpl-pevi-disenchant's lastingCreation declaration survives instantiation",
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(TemplateInstantiated(disenchantTemplate)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.lastingCreation),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'an unresolved template (null baseEffect) emits nothing, rather than seeding a '
      'half-built draft',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(TemplateInstantiated(unresolvedTemplate)),
      expect: () => <SpellCreationState>[],
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'generalEffectSentence is null immediately after instantiation, and a following '
      'ChosenBaseLevelChanged produces one',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(TemplateInstantiated(wardTemplate))
        ..add(const ChosenBaseLevelChanged(20)),
      expect: () => [
        isA<SpellCreationState>().having(
            (s) => s.generalEffectSentence, 'generalEffectSentence (right after instantiation)',
            isNull),
        isA<SpellCreationState>()
            .having((s) => s.draft.chosenBaseLevel, 'draft.chosenBaseLevel', 20)
            .having((s) => s.generalEffectSentence, 'generalEffectSentence (after level chosen)',
                isNotNull),
      ],
    );

    // Regression test for the by-analogy templates added alongside this
    // capability (Dispel the Phantom Image, Restore the Moved Image, Lay to
    // Rest the Haunting Spirit): the real tpl-peim-dispel-phantom-image
    // template/pevi-G2 base effect, hand-built here per this group's own
    // convention rather than loaded from the asset file. Its baseEffectId
    // (pevi-G2, Perdo Vim) diverges from its own Technique/Form (Perdo
    // Imaginem) -- exactly the analogy shape check 8 in
    // validateSpellAgainstCatalog polices -- so this catches a regression of
    // the analogyRationale field never reaching the instantiated draft.
    final dispelPhantomImageBaseEffect = BaseEffect(
      id: 'pevi-G2', technique: 'Perdo', form: 'Vim',
      description:
          'Dispel effects of a specific type (level <= Vim spell level +4 magnitudes + stress)',
      baseLevel: null,
      provenance: Provenance(source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
      effectFormula: const GeneralEffectFormula(
          kind: GeneralEffectKind.targetSpellLevel, offsetMagnitudes: 4, stressDie: true),
      openSlots: const [OpenSlotKind.specificType],
    );
    const dispelPhantomImageRationale =
        "Perdo Imaginem's own guideline table prints no General row. This spell's own text "
        '("Destroys the image from any one CrIm spell whose level you match or exceed on a '
        'stress die + the level of your spell") is the Imaginem-scoped echo of Perdo Vim\'s '
        'own general "dispel a specific type of effect" guideline (pevi-G2), narrowed to '
        "Creo Imaginem and without pevi-G2's own +4 magnitude bonus -- the same shape Perdo "
        "Vim's Wind of Mundane Silence generalizes for any type/realm.";
    final dispelPhantomImageTemplateRecord = SpellTemplate(
      id: 'tpl-peim-dispel-phantom-image',
      name: 'Dispel the Phantom Image',
      baseEffectId: 'pevi-G2',
      technique: 'Perdo',
      form: 'Imaginem',
      rangeId: 'range-voice',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      summary: 'Destroys the image from any one CrIm spell whose level you match or exceed '
          'on a stress die + the level of your spell.',
      description: 'Destroys the image from any one CrIm spell whose level you match or '
          'exceed on a stress die + the level of your spell.',
      provenance: Provenance(source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
      chosenSlots: const {'specificType': 'Creo Imaginem'},
      analogyRationale: dispelPhantomImageRationale,
    );
    final dispelPhantomImageTemplate = ResolvedTemplate(
      record: dispelPhantomImageTemplateRecord,
      baseEffect: dispelPhantomImageBaseEffect,
      range: rangeParam,
      duration: durationParam,
      target: individualParam,
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'an analogy template (technique/form diverging from its base effect) carries its '
      "analogyRationale onto the new draft, and the draft calculates cleanly -- doesn't get "
      "stuck with check 8's unexplained-divergence error",
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(TemplateInstantiated(dispelPhantomImageTemplate))
        ..add(const ChosenBaseLevelChanged(20))
        ..add(const SpellCalculated()),
      verify: (bloc) {
        expect(bloc.state.draft.analogyRationale, dispelPhantomImageRationale);
        expect(bloc.state.draft.technique, 'Perdo');
        expect(bloc.state.draft.form, 'Imaginem');
        expect(bloc.state.validationErrors, isEmpty);
        expect(bloc.state.status, SpellCreationStatus.calculated);
        expect(bloc.state.breakdown, isNotNull);
      },
    );

    // Regression test for the bug this fix closes: analogyRationale is set
    // by TemplateInstantiated (above), but nothing cleared it again once the
    // divergence it explains stops existing. A base effect whose own
    // Technique/Form is Perdo/Imaginem -- matching the draft's own
    // Technique/Form left over from the by-analogy template -- makes
    // check 8's *other* branch fire (analogyRationale set, but Technique/
    // Form no longer diverges) unless BaseEffectSelected clears it too.
    final peimMatchingBaseEffect = BaseEffect(
      id: 'peim-fixed', technique: 'Perdo', form: 'Imaginem',
      description: 'Destroy an image', baseLevel: 5,
      provenance: Provenance(source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'BaseEffectSelected clears a stale analogyRationale once the newly-selected '
      "effect's own Technique/Form matches the draft's -- otherwise the draft is stuck "
      "with check 8's unexplained-decoration error, with no UI path to clear it",
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(TemplateInstantiated(dispelPhantomImageTemplate))
        ..add(BaseEffectSelected(peimMatchingBaseEffect)),
      verify: (bloc) {
        expect(bloc.state.draft.analogyRationale, isNull);
        final errors = spellEngine.validateSpellDraft(bloc.state.draft);
        expect(
          errors.any((e) => e is AnalogyRationaleUnwanted),
          isFalse,
        );
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'TechniqueSelected clears a stale analogyRationale along with baseEffect/templateId',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(TemplateInstantiated(dispelPhantomImageTemplate))
        ..add(const TechniqueSelected('Rego')),
      verify: (bloc) => expect(bloc.state.draft.analogyRationale, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'FormSelected clears a stale analogyRationale along with baseEffect/templateId',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(TemplateInstantiated(dispelPhantomImageTemplate))
        ..add(const FormSelected('Aquam')),
      verify: (bloc) => expect(bloc.state.draft.analogyRationale, isNull),
    );
  });

  group('Form-scoped parameters (FormSelected)', () {
    // A test-local Fire-like Duration parameter, scoped to Ignem/Imaginem
    // only -- mirrors the real duration-fire entry in parameters.json.
    final fireLikeDuration = Parameter(
      id: 'p2-fire', name: 'Fire', category: 'Duration', magnitude: 3,
      scope: const ParameterScope(forms: ['Ignem', 'Imaginem']),
      provenance: Provenance(source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'FormSelected clears a Form-scoped Duration that is out of scope for the new Form',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem',
          range: rangeParam, duration: fireLikeDuration, target: targetParam,
        ),
      ),
      // Fire is only offered for Ignem/Imaginem; Terram is neither, so the
      // stranded selection must be cleared rather than left dangling for a
      // dropdown whose items no longer include it.
      act: (bloc) => bloc.add(const FormSelected('Terram')),
      verify: (bloc) => expect(bloc.state.draft.duration, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'FormSelected leaves an unscoped Duration (e.g. Momentary) untouched across a Form change',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem',
          range: rangeParam, duration: durationParam, target: targetParam,
        ),
      ),
      act: (bloc) => bloc.add(const FormSelected('Terram')),
      verify: (bloc) => expect(bloc.state.draft.duration, durationParam),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'FormSelected keeps a Form-scoped Duration that is still in scope for the new Form',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Creo', form: 'Ignem',
          range: rangeParam, duration: fireLikeDuration, target: targetParam,
        ),
      ),
      // Imaginem is still in Fire's scope, so the selection must survive.
      act: (bloc) => bloc.add(const FormSelected('Imaginem')),
      verify: (bloc) => expect(bloc.state.draft.duration, fireLikeDuration),
    );
  });

  group('SummaryChanged', () {
    blocTest<SpellCreationBloc, SpellCreationState>(
      'SummaryChanged writes the text to the draft',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(const SummaryChanged('A jet of flame.')),
      expect: () => [
        isA<SpellCreationState>()
            .having((s) => s.status, 'status', SpellCreationStatus.editing)
            .having((s) => s.draft.summary, 'draft.summary', 'A jet of flame.'),
      ],
    );

    late LevelBreakdown breakdownBeforeSummary;

    blocTest<SpellCreationBloc, SpellCreationState>(
      'SummaryChanged leaves the breakdown at an equal value',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () {
        // Start with a state that has been calculated, so we have a baseline
        // breakdown to verify doesn't change when SummaryChanged runs.
        breakdownBeforeSummary = spellEngine.calculateBreakdown(
          baseEffect: creoIgnemEffect,
          chosenBaseLevel: null,
          range: rangeParam,
          duration: durationParam,
          target: targetParam,
          selectedModifiers: const {},
          requisites: const {},
          adjustments: const [],
          ritualDeclaration: RitualDeclaration.none,
        );
        return SpellCreationState(
          status: SpellCreationStatus.calculated,
          draft: SpellDraft(
            technique: 'Creo',
            form: 'Ignem',
            baseEffect: creoIgnemEffect,
            range: rangeParam,
            duration: durationParam,
            target: targetParam,
          ),
          breakdown: breakdownBeforeSummary,
        );
      },
      act: (bloc) => bloc.add(const SummaryChanged('A jet of flame.')),
      verify: (bloc) {
        expect(bloc.state.breakdown, isNotNull,
            reason: 'the fixture must actually produce a breakdown, or this test proves nothing');
        expect(bloc.state.draft.summary, 'A jet of flame.');
        // Value, not identity (this used to assert `same`). The emit funnel
        // rebuilds the breakdown on every event, so what matters is that a
        // level-neutral edit lands on an equal one -- prose cannot move a
        // level, and the level must not blink out while it is typed.
        // This is todo item 58's first bullet.
        expect(bloc.state.breakdown, breakdownBeforeSummary);
        expect(bloc.state.levelUnavailableReason, isNull);
      },
    );
  });

  group('ContainerModeSelected', () {
    blocTest<SpellCreationBloc, SpellCreationState>(
      'stores the mode on the draft',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(const ContainerModeSelected(ContainerMode.dynamic)),
      expect: () => [
        isA<SpellCreationState>().having(
            (s) => s.draft.containerMode, 'containerMode', ContainerMode.dynamic),
      ],
    );

    late LevelBreakdown breakdownBeforeContainerMode;

    blocTest<SpellCreationBloc, SpellCreationState>(
      'leaves the breakdown at an equal value — the mode is level-neutral',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () {
        breakdownBeforeContainerMode = spellEngine.calculateBreakdown(
          baseEffect: creoIgnemEffect,
          chosenBaseLevel: null,
          range: rangeParam,
          duration: durationParam,
          target: targetParam,
          selectedModifiers: const {},
          requisites: const {},
          adjustments: const [],
          ritualDeclaration: RitualDeclaration.none,
        );
        return SpellCreationState(
          status: SpellCreationStatus.calculated,
          draft: SpellDraft(
            technique: 'Creo',
            form: 'Ignem',
            baseEffect: creoIgnemEffect,
            range: rangeParam,
            duration: durationParam,
            target: targetParam,
          ),
          breakdown: breakdownBeforeContainerMode,
        );
      },
      act: (bloc) => bloc.add(const ContainerModeSelected(ContainerMode.static)),
      verify: (bloc) {
        expect(bloc.state.breakdown, isNotNull,
            reason: 'the fixture must actually produce a breakdown, or this test proves nothing');
        expect(bloc.state.draft.containerMode, ContainerMode.static);
        // See the SummaryChanged test above: the container mode is
        // level-neutral, so the recomputed breakdown must compare equal.
        expect(bloc.state.breakdown, breakdownBeforeContainerMode);
        expect(bloc.state.levelUnavailableReason, isNull);
      },
    );
  });

  group('TargetSelected prunes the container mode', () {
    final individualTarget = Parameter(
      id: 'p3-individual', name: 'Individual', category: 'Target', magnitude: 8,
      targetType: TargetType.object,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final roomTarget = Parameter(
      id: 'p3-room', name: 'Room', category: 'Target', magnitude: 10,
      targetType: TargetType.container,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final structureTarget = Parameter(
      id: 'p3-structure', name: 'Structure', category: 'Target', magnitude: 12,
      targetType: TargetType.container,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'clears a stated mode when the new Target is not a container',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(target: roomTarget, containerMode: ContainerMode.dynamic),
      ),
      act: (bloc) => bloc.add(TargetSelected(individualTarget)),
      verify: (bloc) =>
          expect(bloc.state.draft.containerMode, ContainerMode.unstated),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'keeps a stated mode when moving between two container Targets',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      seed: () => SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(target: roomTarget, containerMode: ContainerMode.dynamic),
      ),
      act: (bloc) => bloc.add(TargetSelected(structureTarget)),
      verify: (bloc) =>
          expect(bloc.state.draft.containerMode, ContainerMode.dynamic),
    );
  });

  group('SpellCreationState.copyWith clearing', () {
    test('an omitted breakdown is carried forward, an explicit null clears it', () {
      const breakdown = LevelBreakdown(level: 20, rawLevel: 20, contributions: []);
      final withBreakdown = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(),
        breakdown: breakdown,
      );

      expect(withBreakdown.copyWith(status: SpellCreationStatus.saving).breakdown, breakdown,
          reason: 'an emit that says nothing about the level must not wipe it');
      expect(withBreakdown.copyWith(breakdown: null).breakdown, isNull,
          reason: 'a draft going incomplete must be able to clear the level');
    });

    test('an omitted reason is carried forward, an explicit null clears it', () {
      final withReason = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(),
        levelUnavailableReason: LevelUnavailableReason.noBaseEffect,
      );

      expect(withReason.copyWith(status: SpellCreationStatus.saving).levelUnavailableReason,
          LevelUnavailableReason.noBaseEffect);
      expect(withReason.copyWith(levelUnavailableReason: null).levelUnavailableReason, isNull);
    });
  });

  group('the level is live', () {
    test('the initial state already explains why there is no level', () {
      final bloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      addTearDown(bloc.close);

      expect(bloc.state.breakdown, isNull);
      expect(bloc.state.levelUnavailableReason, LevelUnavailableReason.noBaseEffect);
    });

    blocTest<SpellCreationBloc, SpellCreationState>(
      'a complete draft has a level with no button press at all',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(RangeSelected(rangeParam))
        ..add(DurationSelected(durationParam))
        ..add(TargetSelected(targetParam)),
      verify: (bloc) {
        expect(bloc.state.status, SpellCreationStatus.editing,
            reason: 'no SpellCalculated was ever dispatched');
        expect(bloc.state.breakdown, isNotNull);
        expect(bloc.state.levelUnavailableReason, isNull);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'an edit that empties the draft clears the level and says why',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(RangeSelected(rangeParam))
        ..add(DurationSelected(durationParam))
        ..add(TargetSelected(targetParam))
        // Clears baseEffect (spell_creation_bloc.dart:57), so the level goes
        // with it rather than lingering as a number for a spell that no
        // longer has a guideline.
        ..add(const TechniqueSelected('Perdo')),
      verify: (bloc) {
        expect(bloc.state.breakdown, isNull);
        expect(bloc.state.levelUnavailableReason, LevelUnavailableReason.noBaseEffect);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'discarding resets to a draft that explains itself',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(const SpellDiscarded()),
      verify: (bloc) {
        expect(bloc.state.breakdown, isNull);
        expect(bloc.state.levelUnavailableReason, LevelUnavailableReason.noBaseEffect);
      },
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'saving an invalid draft emits its errors and writes nothing',
      // With Save no longer sitting behind Calculate, this guard is the only
      // thing between an incomplete draft and the repository.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc.add(const SpellSaveRequested('Pillar of Flames')),
      verify: (bloc) {
        expect(bloc.state.validationErrors, isNotEmpty);
        expect(bloc.state.status, SpellCreationStatus.editing);
        expect(bloc.state.savedSpell, isNull);
      },
    );
  });

  group('validation errors do not outlive the draft they described', () {
    blocTest<SpellCreationBloc, SpellCreationState>(
      'a rejected save clears its errors on the next edit that fixes them',
      // The errors were computed from a draft that no longer exists. Left in
      // place they contradict what the user is now looking at: save an
      // incomplete draft, read "Target must be selected" in red, pick a
      // Target, and the red text still says to pick a Target. The pattern
      // predates this task, but an unconditional Save is what makes it
      // reachable without a Calculate.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(RangeSelected(rangeParam))
        ..add(DurationSelected(durationParam))
        // No Target yet, so the save is rejected rather than written.
        ..add(const SpellSaveRequested('Pillar of Flames'))
        ..add(TargetSelected(targetParam)),
      skip: 5,
      expect: () => [
        isA<SpellCreationState>()
            .having((s) => s.status, 'status', SpellCreationStatus.editing)
            .having((s) => s.validationErrors, 'validationErrors',
                contains(const TargetMissing())),
        isA<SpellCreationState>()
            .having((s) => s.draft.target, 'draft.target', targetParam)
            .having((s) => s.validationErrors, 'validationErrors (cleared by the edit)', isEmpty),
      ],
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'a SpellCalculated that produces errors keeps them -- the emit carrying them does not clear them',
      // The reverse guard on the test above. Clearing is conditional on the
      // draft having actually moved, so the emit that *reports* errors -- which
      // leaves the draft alone -- must not wipe them on the way out.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(const SpellCalculated()),
      skip: 3,
      expect: () => [
        isA<SpellCreationState>()
            .having((s) => s.status, 'status', SpellCreationStatus.editing)
            .having((s) => s.validationErrors, 'validationErrors',
                contains(const RangeMissing())),
      ],
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'an edit that does not fix the errors still clears them, rather than showing a stale subset',
      // Deliberately not "recompute the errors on every edit": validation stays
      // behind the two button presses (its messages render as red text, and
      // firing them per keystroke would flag a half-built draft as broken --
      // todo item 59). The funnel only ever clears. The user gets them back,
      // recomputed against the draft they now have, on their next press.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(const FormSelected('Ignem'))
        ..add(BaseEffectSelected(creoIgnemEffect))
        ..add(const SpellSaveRequested('Pillar of Flames'))
        // Fixes neither the missing Duration nor the missing Target.
        ..add(RangeSelected(rangeParam)),
      skip: 4,
      expect: () => [
        isA<SpellCreationState>()
            .having((s) => s.draft.range, 'draft.range', rangeParam)
            .having((s) => s.validationErrors, 'validationErrors', isEmpty),
      ],
    );
  });

  group('a Technique change prunes parameters it puts out of scope', () {
    // A stand-in for HoH:MC's Sound: a sensorium Target the rulebook forbids
    // on Intellego spells. Built here rather than read from the catalog so
    // this behaviour is pinned independently of the data.
    final sensoryTarget = Parameter(
      id: 'target-sound-test',
      name: 'Sound',
      category: 'Target',
      magnitude: 3,
      targetType: TargetType.sensorium,
      scope: const ParameterScope(excludeTechniques: ['Intellego']),
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-hohmc')]),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'a Target the new Technique forbids is dropped',
      // Left in place it is a value the dropdown no longer offers, and
      // DropdownButtonFormField asserts its value appears in its items --
      // the failure _withPrunedScopedParameters exists to prevent.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(TargetSelected(sensoryTarget))
        ..add(const TechniqueSelected('Intellego')),
      verify: (bloc) => expect(bloc.state.draft.target, isNull),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'a Target the new Technique still allows is left alone',
      // The helper must prune only what actually went out of scope, the same
      // guarantee its Form axis already gives.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(TargetSelected(sensoryTarget))
        ..add(const TechniqueSelected('Muto')),
      verify: (bloc) => expect(bloc.state.draft.target?.id, 'target-sound-test'),
    );
  });
}
