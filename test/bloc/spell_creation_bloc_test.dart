import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/data/database/app_database.dart';
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
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

class MockSpellRepository extends Mock implements SpellRepository {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(Spell(
      id: 'fallback',
      baseEffectId: 'fb',
      rangeId: 'p1',
      durationId: 'p2',
      targetId: 'p3',
      requisites: const [],
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
    );
    spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database), resolver: resolver);
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
          .having((s) => s.calculatedLevel, 'calculatedLevel', 60)
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
        rangeId: rangeParam.id,
        durationId: durationParam.id,
        targetId: targetParam.id,
        requisites: const [],
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
        rangeId: rangeParam.id,
        durationId: yearDuration.id,
        targetId: targetParam.id,
        requisites: const [],
        provenance: Provenance(source: PublicationSource.userCreated), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final ordinaryRecord = Spell(
        id: 'ordinary-suggestion',
        name: 'Warmth of the Hearth',
        baseEffectId: lowEffect.id,
        rangeId: rangeParam.id,
        durationId: durationParam.id,
        targetId: zeroTarget.id,
        requisites: const [],
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
        rangeId: rangeParam.id,
        durationId: durationParam.id,
        targetId: targetParam.id,
        requisites: const [],
        adjustments: [LevelAdjustment(magnitude: -20, note: 'far too generous')],
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
          .having((s) => s.calculatedLevel, 'calculatedLevel', 60)
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
      bloc.add(const SpellSaveRequested('My Fireball'));
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
    'SpellSaveRequested resets to a fresh, empty draft after a successful save',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('My Fireball'));
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
      bloc.add(const SpellSaveRequested('First Spell'));
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
      bloc.add(const SpellSaveRequested('Second Spell'));
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
      bloc.add(const SpellSaveRequested('Doomed Spell'));
    },
    skip: 6,
    expect: () => [
      isA<SpellCreationState>().having((s) => s.status, 'status', SpellCreationStatus.saving),
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', contains('disk full'))
          // The in-progress draft is preserved (not reset) on failure, so the
          // user doesn't lose their work and can retry.
          .having((s) => s.draft.technique, 'draft.technique (preserved)', 'Creo'),
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
      bloc.add(const SpellSaveRequested('Raced Spell'));
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
        (s) => s.draft.requisites.map((r) => '${r.art}:${r.kind.name}'),
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
        (s) => s.draft.requisites.map((r) => '${r.art}:${r.kind.name}'),
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
        (s) => s.draft.requisites.map((r) => r.art),
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
          .having((s) => s.calculatedLevel, 'calculatedLevel', 65),
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
          .having((s) => s.calculatedLevel, 'calculatedLevel', 60),
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
            contains("Requisite art cannot be the spell's own technique or form"),
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
          .having((s) => s.calculatedLevel, 'calculatedLevel', 75),
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
            (s) => s.breakdown?.contributions.any((c) => c.label.contains('Metal')),
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
      rangeId: 'range-touch',
      durationId: 'duration-ring',
      targetId: 'target-circle',
      description: 'No water faerie whose Faerie Might is equal to or less than '
          'the level of the spell can affect those targeted by the spell.',
      provenance: Provenance(source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
      // ritualDeclaration omitted -> RitualDeclaration.none, as on the real asset.
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
        calculatedLevel: 42,
      ),
      act: (bloc) => bloc.add(TemplateInstantiated(wardTemplate)),
      verify: (bloc) => expect(bloc.state.calculatedLevel, isNull),
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
  });
}
