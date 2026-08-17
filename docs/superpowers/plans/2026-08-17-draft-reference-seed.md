# Draft Reference Seed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A spell draft always shows a Range, Duration and Target, seeded from the selected guideline's own `reference` triple rather than left blank.

**Architecture:** One private static function in `SpellCreationBloc` re-seeds a draft's three parameter slots. A slot is re-seeded only when it is null, or when it still holds the *outgoing* guideline's reference value — i.e. the user never moved it off the seed. It is called from every draft-shaping handler except `TemplateInstantiated`, whose parameters are published data and survive verbatim. A prerequisite one-line fix in `main.dart` makes the parameter catalog available to the engine at construction, without which no seed id can resolve.

**Tech Stack:** Flutter, `flutter_bloc`, `bloc_test`, `mocktail`, `sqflite_common_ffi`.

**Spec:** [`docs/superpowers/specs/2026-08-17-draft-reference-seed-design.md`](../specs/2026-08-17-draft-reference-seed-design.md)

## Global Constraints

- **Do not build an is-this-explicit predicate on `BaseEffect.reference`.** The field already defaults to `ParameterTriple.standard()` in the constructor (`lib/models/base_effect.dart:122`) and again when absent from JSON (`:153-155`), so "the guideline's reference where explicit, standard otherwise" and "always `baseEffect.reference`" are the same rule. Write the second.
- **Both lookups degrade, never throw.** An unresolvable id or an out-of-Form-scope candidate leaves the slot exactly as it was.
- **Never seed `TemplateInstantiated`.** A template's parameters are published catalog data about that specific effect.
- **Existing tests must not be modified.** `test/bloc/spell_creation_bloc_test.dart`'s shared `spellEngine` is built as `SpellEngine(allSpells: const [])` with an empty `allParameters`, so every seed degrades to today's nulls there. That whole suite passing unchanged *is* the empty-catalog degradation test. New tests get their own engine.
- **Run tests with:** `flutter test test/bloc/spell_creation_bloc_test.dart`. If a run fails with a `sqlite3.dll` permissions error, that is stale `flutter_tester` processes holding the lock — kill them and re-run (`Get-Process flutter_tester -ErrorAction SilentlyContinue | Stop-Process -Force`).

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `lib/main.dart` | Modify `:68` | Pass the parameter catalog into `SpellEngine` at construction |
| `lib/bloc/spell_creation/spell_creation_bloc.dart` | Modify | The seed rule and its five call sites |
| `test/bloc/spell_creation_bloc_test.dart` | Append | All behavioural coverage, driven through the bloc |
| `.superpowers/todo.md` | Modify | Close item 60 and item 38's first bullet |

No new files. The rule is a bloc-private function alongside its four existing siblings (`_withPrunedModifiers`, `_withPrunedFormScopedParameters`, `_withRitualDeclaration`, `_prunedSlots`), matching the file's established pattern.

---

### Task 1: Give the engine its parameter catalog

Closes todo item 38's first bullet. This is a **prerequisite**: `SpellEngine.allParameters` defaults to `const []` (`lib/engine/spell_engine.dart:32`) and the only thing that ever fills it is `AvailableParametersSynced`, dispatched from a `BlocListener` in `SpellCreationScreen` whose `listenWhen` fires **only on change** (`lib/presentation/screens/spell_creation_screen.dart:44-50`). If `ConfigurationBloc` has already loaded its parameters before the Create tab first builds, that listener never fires and `allParameters` stays empty for the life of the app.

**Files:**
- Modify: `lib/main.dart:68`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing new. `SpellEngine.allParameters` is non-empty at app start, which every later task's seed depends on at runtime (not in tests, which pass their own).

**Verification note, stated honestly:** `main()` has no test harness in this repo. `test/widget_test.dart` builds `EruditusApp` from *mock* blocs and never runs `main()`, so there is no seam to assert against and this plan does not invent one. Verification here is `flutter analyze` plus reading the diff. Do not add a test for this step.

- [ ] **Step 1: Read the surrounding lines**

Read `lib/main.dart:42-75`. Note that `await configRepository.getAllParameters()` is *already* called at `:50` to build `SpellResolver`, so this change costs one argument and no new I/O.

- [ ] **Step 2: Hoist the parameter list and pass it to the engine**

Replace:

```dart
  final resolver = SpellResolver(
    effects: await configRepository.getAllEffects(),
    parameters: await configRepository.getAllParameters(),
    modifiers: await configRepository.getAllModifiers(),
  );
```

with:

```dart
  // Hoisted out of the SpellResolver call below so SpellEngine can share it.
  // The engine resolves a guideline's reference parameter by id, both to
  // charge Range/Duration/Target as a delta and to seed a new draft at that
  // reference. Its only other filler is AvailableParametersSynced, dispatched
  // from a BlocListener whose listenWhen fires on *change* -- so if
  // ConfigurationBloc has already loaded by the time the Create tab first
  // builds, that listener never fires and allParameters would stay empty for
  // the life of the app. See todo items 38 and 60.
  final allParameters = await configRepository.getAllParameters();
  final resolver = SpellResolver(
    effects: await configRepository.getAllEffects(),
    parameters: allParameters,
    modifiers: await configRepository.getAllModifiers(),
  );
```

Then replace `:68`:

```dart
  final spellEngine = SpellEngine(allSpells: allSpells);
```

with:

```dart
  final spellEngine = SpellEngine(allSpells: allSpells, allParameters: allParameters);
```

- [ ] **Step 3: Verify it analyzes clean**

Run: `flutter analyze lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 4: Verify nothing else regressed**

Run: `flutter test`
Expected: all tests pass, same count as before the change.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "fix: give SpellEngine its parameter catalog at construction

allParameters defaulted to const [] and was filled only by a BlocListener
whose listenWhen fires on change, so it could stay empty for the life of
the app -- silently skipping a General ward guideline's reference discount
in the Library tab, and blocking any draft seeding. Closes todo item 38's
first bullet.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: The seed rule, and the three empty-draft paths

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart` (add imports; add two helpers; change the constructor, `SpellDiscarded` at `:328-329`, and the post-save reset at `:512-515`)
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `SpellEngine.allParameters` (`List<Parameter>`), non-empty at runtime after Task 1.
- Produces, for Tasks 3 and 4:
  - `static SpellDraft _seedParameters(SpellDraft draft, ParameterTriple previousReference, List<Parameter> parameters)`
  - `SpellDraft _withSeededParameters(SpellDraft draft, ParameterTriple previousReference)` — instance wrapper supplying `spellEngine.allParameters`
  - `static ParameterTriple _referenceOf(SpellDraft draft)` — `draft.baseEffect?.reference ?? const ParameterTriple.standard()`
  - `SpellDraft _emptySeededDraft()` — a fresh `SpellDraft()` (new id) seeded at the standard triple

- [ ] **Step 1: Write the failing tests**

Append to `test/bloc/spell_creation_bloc_test.dart`, inside `main()`, after the existing `SpellDiscarded` tests (around `:565`). These need their own engine and catalog — do **not** touch the shared `spellEngine` built in `setUp`.

```dart
  // --- todo item 60: a draft starts at its guideline's own reference triple ---
  //
  // A separate engine from the shared `spellEngine` above, which is
  // deliberately built with an empty allParameters: every existing test in
  // this file therefore still exercises the "catalog unavailable, seed
  // degrades to null" path, and only the tests below see a catalog.

  Parameter seedParam(String id, String name, String category, int magnitude,
          {TargetType? targetType, ParameterScope scope = const ParameterScope()}) =>
      Parameter(
        id: id, name: name, category: category, magnitude: magnitude,
        targetType: targetType, scope: scope,
        provenance: Provenance(
            source: PublicationSource.published,
            citations: const [Citation(bookId: 'arm5-core')]),
      );

  final personal = seedParam('range-personal', 'Personal', 'Range', 0);
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

  final seedCatalog = [personal, touch, voice, momentary, ring, fire,
      individual, circle, room];

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
    provenance: Provenance(source: PublicationSource.published),
  );

  // No `reference` at all -- falls back to ParameterTriple.standard(), like
  // 596 of the 609 catalog entries.
  final plainEffect = BaseEffect(
    id: 'plain-1', technique: 'Creo', form: 'Ignem',
    description: 'Create flame', baseLevel: 10,
    provenance: Provenance(source: PublicationSource.published),
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
```

Note the post-save test relies on `plainEffect` being saveable: Creo/Ignem matches the Technique/Form selected, and the seeded Personal/Momentary/Individual completes the draft, so `toSpell` finds no missing fields. Because `plainEffect` is not in the test `SpellResolver`'s effect list, the save path may reject it — if it does, add `plainEffect` to the `SpellResolver(effects: [...])` list in `setUp` alongside `creoIgnemEffect`; that is additive and breaks nothing.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "seeded"`
Expected: FAIL. The initial-state test fails with `range` null; the two `blocTest`s fail their `.having` matchers on null parameters.

- [ ] **Step 3: Add the imports**

At the top of `lib/bloc/spell_creation/spell_creation_bloc.dart`, add alongside the existing model imports:

```dart
import 'package:eruditus/models/parameter_triple.dart';
```

`collection` (for `firstWhereOrNull`), `parameter.dart`, `target_type.dart` and `container_mode.dart` are already imported.

- [ ] **Step 4: Add the two helpers**

Add near the other draft-shaping helpers, after `_withPrunedFormScopedParameters` (around `:388`):

```dart
  /// The reference triple [draft]'s guideline is priced against, or the
  /// standard Personal/Momentary/Individual when no guideline is selected.
  ///
  /// [BaseEffect.reference] already *defaults* to `ParameterTriple.standard()`
  /// -- in the constructor (`base_effect.dart:122`) and again when the field
  /// is absent from JSON (`:153-155`). So "the guideline's reference where
  /// explicit, the fixed default otherwise" and "always `baseEffect.reference`"
  /// are the same rule, and this is the second one. There is deliberately no
  /// is-this-explicit predicate; see todo item 60.
  static ParameterTriple _referenceOf(SpellDraft draft) =>
      draft.baseEffect?.reference ?? const ParameterTriple.standard();

  /// Moves [draft]'s Range/Duration/Target to the zero point its
  /// (already-updated) guideline is priced against.
  ///
  /// A slot is re-seeded only when it is null, or when it still holds
  /// [previousReference]'s value for that slot -- i.e. the user never moved it
  /// off the seed. A parameter chosen deliberately survives a guideline
  /// switch. Evaluated one slot at a time, so a caster who picked a Target
  /// keeps it while their untouched Range and Duration follow the new
  /// guideline. That is the same shape of answer BaseEffectSelected already
  /// gives for `chosenBaseLevel` above: a keep-or-clear rule reasoned from
  /// what the value still means, rather than a blanket policy either way.
  ///
  /// It matters because `_parameterContribution` charges each parameter as a
  /// *delta* from the reference. A ward guideline (Touch/Ring/Circle) left at
  /// the blank-draft default contributes -1, -2, 0, which can drive the level
  /// below 1 and tell the caster their spell is broken -- when all that
  /// happened is that the app never put them at the guideline's own start.
  ///
  /// Both lookups degrade rather than throw. An id that does not resolve
  /// leaves the slot untouched, so with an empty [parameters] every slot stays
  /// null -- exactly the behaviour before this rule existed. A candidate out
  /// of scope for the draft's Form is skipped for the same reason
  /// _withPrunedFormScopedParameters exists: writing one in would trip
  /// DropdownButtonFormField's assertion that its value appear in `items`.
  /// No catalog reference names a Form-scoped parameter today, but a custom
  /// guideline could.
  ///
  /// `containerMode` is pruned here rather than at each call site, because
  /// every handler that can re-seed a Target can strand a mode. `keepsMode` is
  /// computed from the *resulting* Target, not from whether the seed changed
  /// it: when the seed leaves the Target alone, a mode can only be set if that
  /// Target is already a container (ContainerModeSelected is the only path
  /// that sets one, and TargetSelected prunes it otherwise), so the check is a
  /// no-op in exactly the cases where nothing moved.
  static SpellDraft _seedParameters(
    SpellDraft draft,
    ParameterTriple previousReference,
    List<Parameter> parameters,
  ) {
    final next = _referenceOf(draft);

    Parameter? seed(Parameter? current, String previousId, String nextId) {
      if (current != null && current.id != previousId) return current;
      final candidate = parameters.firstWhereOrNull((p) => p.id == nextId);
      if (candidate == null || !candidate.scope.appliesTo(form: draft.form)) {
        return current;
      }
      return candidate;
    }

    final target = seed(draft.target, previousReference.targetId, next.targetId);
    final keepsMode = target?.targetType == TargetType.container;

    return draft.copyWith(
      range: seed(draft.range, previousReference.rangeId, next.rangeId),
      duration: seed(draft.duration, previousReference.durationId, next.durationId),
      target: target,
      containerMode: keepsMode ? null : ContainerMode.unstated,
    );
  }

  /// [_seedParameters] against the engine's live parameter catalog.
  SpellDraft _withSeededParameters(SpellDraft draft, ParameterTriple previousReference) =>
      _seedParameters(draft, previousReference, spellEngine.allParameters);

  /// A fresh, empty draft -- new id, no guideline -- seeded at the standard
  /// reference triple. The draft every "start over" path resets to.
  SpellDraft _emptySeededDraft() =>
      _seedParameters(SpellDraft(), const ParameterTriple.standard(), spellEngine.allParameters);
```

- [ ] **Step 5: Seed the initial state**

The constructor's `super(...)` cannot reference `this`, but *can* reference a constructor parameter. Change the field to an explicit assignment:

```dart
  SpellCreationBloc({
    required SpellEngine spellEngine,
    required this.spellRepository,
  })  : spellEngine = spellEngine,
        // The first thing the Create tab renders. Seeded here rather than in
        // SpellCreationState.initial(), which has no catalog to resolve ids
        // against -- and must not gain one, since TemplateInstantiated builds
        // on it and its parameters must survive verbatim.
        super(SpellCreationState.initial().copyWith(
          draft: _seedParameters(
              SpellDraft(), const ParameterTriple.standard(), spellEngine.allParameters),
        )) {
```

Leave the existing `on<SpellCreationEvent>(...)` registration and its comment block untouched.

- [ ] **Step 6: Check for a lint on the explicit field assignment**

Run: `flutter analyze lib/bloc/spell_creation/spell_creation_bloc.dart`
Expected: `No issues found!`

If `prefer_initializing_formals` fires, the parameter genuinely cannot be an initializing formal — `super(...)` needs to read it, and `this.spellEngine` is not in scope there. Suppress it on that line with the reason:

```dart
    // ignore: prefer_initializing_formals
    // `this.spellEngine` cannot be used: super(...) below must read the engine
    // to seed the initial draft, and `this` is out of scope in an initializer.
    required SpellEngine spellEngine,
```

- [ ] **Step 7: Seed the two reset paths**

Replace `SpellDiscarded`'s handler (`:328-329`):

```dart
    } else if (event is SpellDiscarded) {
      emit(SpellCreationState.initial());
    }
```

with:

```dart
    } else if (event is SpellDiscarded) {
      emit(SpellCreationState.initial().copyWith(draft: _emptySeededDraft()));
    }
```

Replace the post-save reset (`:512-515`):

```dart
      emit(SpellCreationState.initial().copyWith(
        status: SpellCreationStatus.saved,
        savedSpell: spell,
      ));
```

with:

```dart
      emit(SpellCreationState.initial().copyWith(
        status: SpellCreationStatus.saved,
        savedSpell: spell,
        draft: _emptySeededDraft(),
      ));
```

Leave `TemplateInstantiated` (`:319-323`) alone. It passes its own `draft:` to `copyWith`, so it is already unaffected — and must stay that way.

- [ ] **Step 8: Run the new tests**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "seeded"`
Expected: PASS, 3 tests.

- [ ] **Step 9: Run the whole suite**

Run: `flutter test`
Expected: all pass. In particular every pre-existing test in `spell_creation_bloc_test.dart` still passes untouched, because its shared `spellEngine` has an empty catalog and the seed degrades to null.

- [ ] **Step 10: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: seed an empty draft at the standard reference triple

The initial state, Discard and the post-save reset now start with
Personal/Momentary/Individual rather than three blank dropdowns. Adds
the seed rule itself; the guideline-switch adopt follows.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Adopt the new guideline's reference on `BaseEffectSelected`

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart:89-122`
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `_withSeededParameters(SpellDraft, ParameterTriple)` and `_referenceOf(SpellDraft)` from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests**

Append after Task 2's tests. The helpers (`seedParam`, `wardEffect`, `plainEffect`, `seedingBloc`, and the parameter values) are already in scope from Task 2 — do not redeclare them.

```dart
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
    'the adopt is per-slot: an untouched Range and Duration follow the new '
    'guideline while a chosen Target stays',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(BaseEffectSelected(wardEffect));  // -> touch / ring / circle
      bloc.add(TargetSelected(room));            // deliberately off the seed
      bloc.add(BaseEffectSelected(plainEffect)); // reference: standard
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-momentary')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-room'),
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "guideline"`
Expected: FAIL — the parameters keep their pre-selection values because `BaseEffectSelected` does not seed yet.

- [ ] **Step 3: Wire the seed into `BaseEffectSelected`**

In the `event is BaseEffectSelected` branch (`:89`), capture the outgoing reference first, then wrap the `copyWith` in `_withSeededParameters` **inside** `_withPrunedModifiers`:

```dart
    } else if (event is BaseEffectSelected) {
      // Captured before the draft moves: the seed keeps any parameter the user
      // moved off this triple, and re-seeds the ones they never touched.
      final previousReference = _referenceOf(state.draft);
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(_withSeededParameters(
          state.draft.copyWith(
            baseEffect: event.effect,
            // KEEP VERBATIM: the existing `templateId: null`,
            // `analogyRationale: null`, the conditional `chosenBaseLevel`, and
            // `chosenSlots: _prunedSlots(...)` arguments, together with the
            // long comment block explaining each. This step adds the two
            // wrapper calls only.
          ),
          previousReference,
        )),
        reapplyDefault: true,
      );
```

Order matters and is not incidental: `_withSeededParameters` must run before `_withPrunedModifiers`, which filters by `targetId`, and before `_withRitualDeclaration`, which reads `duration.id == momentary`. Do not reorder them.

Leave every existing argument to `copyWith` — `templateId`, `analogyRationale`, `chosenBaseLevel`, `chosenSlots` — and their comments exactly as they are.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "guideline"`
Expected: PASS.

- [ ] **Step 5: Run the whole suite**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: adopt a guideline's reference triple on BaseEffectSelected

Per-slot, and only where the parameter still holds the outgoing
guideline's reference -- a deliberately chosen one survives. A ward
guideline now starts at Touch/Ring/Circle instead of three magnitudes
below its own zero point.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Seed on `TechniqueSelected` and `FormSelected`

Both clear the guideline, so both return an untouched draft to the standard triple. `FormSelected` additionally refills a parameter its own `_withPrunedFormScopedParameters` just nulled — the same blank dropdown this work exists to eliminate, reached by a different door.

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart:44-69` and `:70-88`
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `_withSeededParameters(SpellDraft, ParameterTriple)` and `_referenceOf(SpellDraft)` from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests**

Append after Task 3's tests. `seedParam`, `fire`, `wardEffect`, `seedingBloc` and the parameter values are already in scope.

```dart
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
    'TemplateInstantiated keeps the template parameters verbatim, unseeded',
    build: seedingBloc,
    act: (bloc) => bloc.add(TemplateInstantiated(ResolvedTemplate(
      record: SpellTemplate(
        id: 'tpl-seed', name: 'Voiced Ward', baseEffectId: 'ward-1',
        technique: 'Rego', form: 'Ignem',
        rangeId: 'range-voice', durationId: 'duration-ring', targetId: 'target-room',
        requisites: const {},
        summary: 'A published template whose parameters must survive verbatim.',
        provenance: Provenance(source: PublicationSource.published),
      ),
      baseEffect: wardEffect,
      range: voice, duration: ring, target: room,
      modifiers: const [],
    ))),
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-voice')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-room'),
    ],
  );
```

The `ResolvedTemplate`/`SpellTemplate` constructor arguments must match the existing `TemplateInstantiated` tests in this file — read one first (search for `TemplateInstantiated` around `:1008`) and mirror its exact shape rather than trusting the sketch above.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "Form"`
then: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "Technique clears"`
Expected: FAIL for the first two; the "still-in-scope" and `TemplateInstantiated` tests should already PASS — they assert behaviour that must *not* change, so a failure there means the seed is over-reaching.

- [ ] **Step 3: Wire the seed into `TechniqueSelected`**

```dart
    if (event is TechniqueSelected) {
      final previousReference = _referenceOf(state.draft);
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(_withSeededParameters(
          state.draft.copyWith(
            technique: event.technique,
            baseEffect: null,
            // KEEP VERBATIM: the existing `chosenBaseLevel: null`,
            // `templateId: null`, `chosenSlots: const {}`,
            // `analogyRationale: null` arguments and the long comment block
            // above them explaining why each cannot outlive the base effect.
            // This step adds the two wrapper calls only.
          ),
          previousReference,
        )),
        reapplyDefault: false,
      );
```

- [ ] **Step 4: Wire the seed into `FormSelected`**

The seed goes **outside** `_withPrunedFormScopedParameters` and **inside** `_withPrunedModifiers`: the prune creates the null the seed then fills, and both read the already-updated `draft.form`.

```dart
    } else if (event is FormSelected) {
      final previousReference = _referenceOf(state.draft);
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(_withSeededParameters(
          _withPrunedFormScopedParameters(state.draft.copyWith(
            form: event.form,
            baseEffect: null,
            // KEEP VERBATIM: the existing `chosenBaseLevel: null`,
            // `templateId: null`, `chosenSlots: const {}`,
            // `analogyRationale: null` arguments and their comment. This step
            // adds the two wrapper calls only.
          )),
          previousReference,
        )),
        reapplyDefault: false,
      );
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS, including every pre-existing test in the file.

- [ ] **Step 6: Run the whole suite and analyze**

Run: `flutter test && flutter analyze`
Expected: all tests pass; `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: seed parameters on Technique and Form changes too

Both clear the guideline, so an untouched draft returns to the standard
triple. FormSelected additionally refills a Form-scoped Duration its own
prune just nulled -- the same blank dropdown, reached by another door.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Close the todo entries

**Files:**
- Modify: `.superpowers/todo.md`

**Interfaces:**
- Consumes: the commits from Tasks 1-4.
- Produces: nothing.

- [ ] **Step 1: Get the commit hash for the item 38 fix**

Run: `git log --oneline -5`
Note the hash of the "give SpellEngine its parameter catalog" commit (Task 1) and of the item 60 work.

- [ ] **Step 2: Close item 38's first bullet**

In `.superpowers/todo.md`, find the bullet beginning `- [ ] **`SpellEngine.allParameters` starts empty` (around `:549`). Change `- [ ]` to `- [x]` and append to the end of the bullet, matching the file's existing done-marker style (see item 10's `- [x] Update README — DONE 2026-08-17 (`97d316c`, see item 29)`):

```
      **DONE 2026-08-17** (`<hash>`, with item 60) — `main.dart` now hoists
      `getAllParameters()` and passes it to `SpellEngine` at construction.
```

- [ ] **Step 3: Replace item 60's body with a pointer**

Replace the whole of `### 60. A Draft Should Start at Its Guideline's Own Reference Triple` (`:742-797`) with the two-line form item 61 uses:

```markdown
### 60. A Draft Should Start at Its Guideline's Own Reference Triple
**✅ COMPLETE 2026-08-17** — see `## Completed ✅`.
```

- [ ] **Step 4: Add the completed entry**

Insert into the `## Completed ✅` section (`:949`), immediately before `### 61.` so the numbering reads down:

```markdown
### 60. Drafts Seed From Their Guideline's Reference Triple (`<hash>`)
`SpellDraft` left Range/Duration/Target null, so every empty draft showed
three blank dropdowns — and a ward guideline priced against Touch/Ring/Circle
started three magnitudes *below* its own zero point, since
`_parameterContribution` charges each parameter as a delta from the reference.
One private static `_seedParameters` now re-seeds all three, called from the
initial state, `SpellDiscarded`, the post-save reset, `BaseEffectSelected`,
`TechniqueSelected` and `FormSelected`.

- **A slot is re-seeded only when it is null or still holds the *outgoing*
  guideline's reference value** — the decided answer to the item's one open
  question. A deliberately chosen parameter survives a guideline switch;
  evaluated per slot, so a chosen Target stays while an untouched Range and
  Duration follow. No "touched" flag: it is a value comparison against data
  already in hand.
- **No is-this-explicit predicate, deliberately.** `BaseEffect.reference`
  already defaults to `ParameterTriple.standard()` in both the constructor and
  the JSON factory, so "explicit reference, else standard" and "always
  `reference`" are the same rule. Item 38's worry that the model cannot tell
  an authored Personal/Momentary/Individual from an unauthored one is real and
  irrelevant here, because both readings seed identically.
- **13 of 609 entries carry an explicit `reference`** — 12 wards at
  Touch/Ring/Circle, `inim-G` at Personal/Momentary/Vision. The other 596 seed
  to standard, which is why the wards are the only place it is observable.
- **`containerMode` is pruned inside the seed, not at each call site**, because
  every handler that can re-seed a Target can strand a mode. Computed from the
  resulting Target, which is a no-op when nothing moved.
- **`TemplateInstantiated` is never seeded.** A template's parameters are
  published catalog data about that specific effect.
- **Also closed item 38's first bullet**, as a hard prerequisite: `main.dart`
  built `SpellEngine` with no parameters and the only filler was a
  `listenWhen` listener that fires on *change*, so the catalog could stay empty
  for the life of the app and no seed id would resolve.
- **`FormSelected` now refills a `duration-fire` its own prune nulled** — the
  same blank dropdown, reached by a different door. The one Form-scoped
  parameter in the catalog.
```

- [ ] **Step 5: Verify the cross-references still resolve**

Run: `grep -n "item 60\|items 60" .superpowers/todo.md`
Expected: item 59's two references (`:716`, `:740`) still point at a real heading. They do — the heading survives, only the body is replaced. Leave item 59 untouched; it is still open.

- [ ] **Step 6: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close todo item 60 and item 38's first bullet

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Deviation From the Spec, Recorded

The spec's testing section listed the seed rule's cases as unit tests of a pure function. This plan drives all of them **through the bloc** instead, because `_seedParameters` is private and adding a public seam purely for tests would put API surface on the bloc file for no behavioural gain. Every case the spec listed is reachable through a bloc event, and each has a test:

| Spec case | Where |
|---|---|
| adopt-when-untouched | Task 3, `'selecting a ward guideline adopts…'` |
| keep-when-chosen | Task 3, `'a deliberately chosen parameter survives…'` |
| per-field mixed | Task 3, `'the adopt is per-slot…'` |
| null-fill | Task 2, all three empty-draft tests |
| empty-catalog degradation | the entire pre-existing suite, whose engine has no catalog |
| out-of-scope candidate skipped | Task 3, `'…Form-scoped parameter out of scope…'` |
| initial / Discard / post-save seeded | Task 2 |
| Technique / Form return to standard | Task 4 |
| `FormSelected` refills a pruned `duration-fire` | Task 4 |
| `TemplateInstantiated` verbatim | Task 4 |
| `target-circle` → `target-individual` clears mode | Task 3 |
| container → container keeps mode | Task 3 |
| adopting Ring drops `lastingCreation` | Task 3 |
| `main.dart` wiring | Task 1 — **no test**, stated openly there: `main()` has no harness in this repo and this plan does not invent one |
