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
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

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
        source: 'user-created',
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
    source: 'published',
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
            source: 'published',
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
}
