# Target Restriction on ModifierScope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `ModifierScope` a Target axis (`excludeTargets`) so `size-mentem` stops applying to Individual-target Mentem spells, and wire that check all the way through the creation-screen picker and the bloc's pruning logic so a stale selection can't survive a Target change either.

**Architecture:** One additive field (`excludeTargets: List<String>`) and one additive optional parameter (`appliesTo({..., String? targetId})`) on the existing `ModifierScope` model, mirroring the existing `excludeTechniques` carve-out exactly. Four call sites thread the new `targetId` through: the creation screen's modifier picker, `SpellEngine.pruneModifierSelections`, and — the actual bug fix — `SpellCreationBloc`'s `TargetSelected` handler, which today is the only Technique/Form/BaseEffect/Target change handler that never prunes stale selections.

**Tech Stack:** Dart / Flutter, `flutter_test` + `bloc_test` + `mocktail`.

## Global Constraints

- No new `validateSpellAgainstCatalog` check — scope conformance at save time stays an unenforced, pre-existing gap across all of `ModifierScope`'s axes (see spec's Out of Scope).
- `excludeTargets` only — no positive `allowedTargets` field; only one exclusion case is known (`size-mentem` excludes `target-individual`).
- `assets/data/modifiers.json` is hand-maintained catalog data, not importer output — no Python changes anywhere in this plan.
- Reference spec: `docs/superpowers/specs/2026-08-16-modifier-target-scope-design.md`.

---

### Task 1: `ModifierScope.excludeTargets` and `appliesTo()`'s `targetId` parameter

**Files:**
- Modify: `lib/models/modifier.dart:60-104` (the `ModifierScope` class and its doc comment)
- Test: `test/models/modifier_test.dart`

**Interfaces:**
- Produces: `ModifierScope.excludeTargets` (`List<String>`, defaults `const []`); `ModifierScope.appliesTo({String? technique, String? form, String? baseEffectId, String? targetId})`.

- [ ] **Step 1: Write the failing tests**

In `test/models/modifier_test.dart`, add two new tests inside the `'ModifierScope.appliesTo'` group, right after the existing `'excludeTechniques rejects a listed technique even when form matches'` test (after line 94, before the group's closing `});`):

```dart
    test('excludeTargets rejects a listed target even when technique/form match', () {
      // "Size modifiers do not apply to Mentem effects with Individual
      // targets" — core rules line 14900.
      const scope = ModifierScope(form: 'Mentem', excludeTargets: ['target-individual']);

      expect(scope.appliesTo(technique: 'Creo', form: 'Mentem', targetId: 'target-group'), isTrue);
      expect(scope.appliesTo(technique: 'Creo', form: 'Mentem', targetId: 'target-individual'), isFalse);
    });

    test('a null targetId does not trigger excludeTargets', () {
      const scope = ModifierScope(form: 'Mentem', excludeTargets: ['target-individual']);
      expect(scope.appliesTo(technique: 'Creo', form: 'Mentem', targetId: null), isTrue);
    });
```

Then update the existing `'toMap/fromMap round-trip preserves scope'` test (lines 113-125) to also cover `excludeTargets`:

```dart
    test('toMap/fromMap round-trip preserves scope', () {
      const scope = ModifierScope(
          technique: 'Rego',
          form: 'Terram',
          effectIds: ['rete-4'],
          excludeTechniques: ['Intellego'],
          excludeTargets: ['target-individual']);
      final restored = Modifier.fromMap(_mod(scope: scope).toMap());

      expect(restored.scope.technique, 'Rego');
      expect(restored.scope.form, 'Terram');
      expect(restored.scope.effectIds, ['rete-4']);
      expect(restored.scope.excludeTechniques, ['Intellego']);
      expect(restored.scope.excludeTargets, ['target-individual']);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/modifier_test.dart`
Expected: FAIL — `excludeTargets` and the `targetId` parameter don't exist yet (compile error naming both).

- [ ] **Step 3: Implement `excludeTargets` and the `targetId` check**

In `lib/models/modifier.dart`, replace the `ModifierScope` class and its doc comment (lines 60-104) with:

```dart
/// Which spells a modifier is offered for. A null [technique] or [form] is a
/// wildcard; an empty [effectIds] means any effect within that technique/form.
///
/// [excludeTechniques] carves out Techniques the modifier never applies to,
/// which a positive [technique] match cannot express. The Size ladders use it
/// for Intellego, which the rules exempt from Target size across every Form.
///
/// [excludeTargets] is the same shape for Target ids: the Mentem Size ladder
/// excludes `target-individual`, since minds have no size for an Individual
/// target but can still be counted for Group/Room/Structure/Boundary.
class ModifierScope {
  final String? technique;
  final String? form;
  final List<String> effectIds;
  final List<String> excludeTechniques;
  final List<String> excludeTargets;

  const ModifierScope({
    this.technique,
    this.form,
    this.effectIds = const [],
    this.excludeTechniques = const [],
    this.excludeTargets = const [],
  });

  bool appliesTo(
      {String? technique, String? form, String? baseEffectId, String? targetId}) {
    if (technique != null && excludeTechniques.contains(technique)) return false;
    if (targetId != null && excludeTargets.contains(targetId)) return false;
    if (this.technique != null && this.technique != technique) return false;
    if (this.form != null && this.form != form) return false;
    if (effectIds.isNotEmpty &&
        (baseEffectId == null || !effectIds.contains(baseEffectId))) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() => {
        'technique': technique,
        'form': form,
        'effectIds': effectIds,
        'excludeTechniques': excludeTechniques,
        'excludeTargets': excludeTargets,
      };

  factory ModifierScope.fromMap(Map<String, dynamic> map) => ModifierScope(
        technique: map['technique'] as String?,
        form: map['form'] as String?,
        effectIds: List<String>.from(map['effectIds'] as List? ?? const []),
        excludeTechniques:
            List<String>.from(map['excludeTechniques'] as List? ?? const []),
        excludeTargets:
            List<String>.from(map['excludeTargets'] as List? ?? const []),
      );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/modifier_test.dart`
Expected: PASS, all tests in the file green.

- [ ] **Step 5: Commit**

```bash
git add lib/models/modifier.dart test/models/modifier_test.dart
git commit -m "feat: add excludeTargets to ModifierScope

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `size-mentem` excludes `target-individual` in the catalog

**Files:**
- Modify: `assets/data/modifiers.json:494-504` (the `size-mentem` entry's `scope`)
- Test: `test/data/asset_modifier_integrity_test.dart`

**Interfaces:**
- Consumes: `ModifierScope.excludeTargets`, `appliesTo(targetId:)` (Task 1).

- [ ] **Step 1: Write the failing test**

In `test/data/asset_modifier_integrity_test.dart`, add a new test right after the existing `'no Size ladder is offered for Intellego'` test (after line 46, before the next test):

```dart
  test('size-mentem excludes Individual targets, since minds have no size', () async {
    final modifiers = await loader.loadModifiers();
    final sizeMentem = modifiers.firstWhere((m) => m.id == 'size-mentem');

    expect(sizeMentem.scope.excludeTargets, contains('target-individual'));
    expect(
      sizeMentem.scope.appliesTo(
          technique: null, form: 'Mentem', baseEffectId: 'any', targetId: 'target-individual'),
      isFalse,
    );
    expect(
      sizeMentem.scope.appliesTo(
          technique: null, form: 'Mentem', baseEffectId: 'any', targetId: 'target-group'),
      isTrue,
    );
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: FAIL — `sizeMentem.scope.excludeTargets` is empty, so `contains('target-individual')` fails.

- [ ] **Step 3: Add `excludeTargets` to the catalog entry**

In `assets/data/modifiers.json`, change the `size-mentem` entry's `scope` block (lines 499-504) from:

```json
    "scope": {
      "technique": null,
      "form": "Mentem",
      "effectIds": [],
      "excludeTechniques": ["Intellego"]
    },
```

to:

```json
    "scope": {
      "technique": null,
      "form": "Mentem",
      "effectIds": [],
      "excludeTechniques": ["Intellego"],
      "excludeTargets": ["target-individual"]
    },
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: PASS, all tests in the file green.

- [ ] **Step 5: Commit**

```bash
git add assets/data/modifiers.json test/data/asset_modifier_integrity_test.dart
git commit -m "fix: exclude target-individual from size-mentem's scope

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: `SpellEngine.pruneModifierSelections` gains `targetId`

**Files:**
- Modify: `lib/engine/spell_engine.dart:336-355`
- Test: `test/engine/spell_engine_test.dart:599-660`

**Interfaces:**
- Consumes: `ModifierScope.appliesTo(targetId:)` (Task 1).
- Produces: `SpellEngine.pruneModifierSelections({required Map<String, List<String>> selectedModifiers, String? technique, String? form, String? baseEffectId, String? targetId})`.

- [ ] **Step 1: Write the failing tests**

In `test/engine/spell_engine_test.dart`, extend the `'SpellEngine.pruneModifierSelections'` group's setup (lines 599-623) to add a Target-scoped modifier fixture and rebuild `engine` with it. Replace:

```dart
    final distance = Modifier(
      id: 'rego-transport-distance',
      name: 'Transport distance',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(effectIds: ['rete-4']),
      options: [ModifierOption(id: 'dist-500', label: '500 paces', magnitude: 2)],
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
    );
    final engine = SpellEngine(
        allSpells: [], allModifiers: [material, distance]);
```

with:

```dart
    final distance = Modifier(
      id: 'rego-transport-distance',
      name: 'Transport distance',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(effectIds: ['rete-4']),
      options: [ModifierOption(id: 'dist-500', label: '500 paces', magnitude: 2)],
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
    );
    final sizeMentem = Modifier(
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
    final engine = SpellEngine(
        allSpells: [], allModifiers: [material, distance, sizeMentem]);
```

Then add two new tests inside the same group, right after `'drops selections whose modifier no longer exists at all'` (after line 659, before the group's closing `});`):

```dart
    test('keeps a Target-scoped selection when the target is not excluded', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'size-mentem': ['size-mentem-1']},
        technique: 'Creo', form: 'Mentem', baseEffectId: null,
        targetId: 'target-group',
      );

      expect(pruned, {'size-mentem': ['size-mentem-1']});
    });

    test('drops a selection stranded by a Target change to an excluded target', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'size-mentem': ['size-mentem-1']},
        technique: 'Creo', form: 'Mentem', baseEffectId: null,
        targetId: 'target-individual',
      );

      expect(pruned, isEmpty);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — `pruneModifierSelections` doesn't accept a `targetId` argument (compile error).

- [ ] **Step 3: Add `targetId` to `pruneModifierSelections`**

In `lib/engine/spell_engine.dart`, replace `pruneModifierSelections` (lines 336-355) with:

```dart
  /// Drops any selection whose modifier no longer applies to the draft. A
  /// stranded selection would otherwise keep contributing magnitude invisibly
  /// after the caster changes Technique, Form, base effect or Target.
  Map<String, List<String>> pruneModifierSelections({
    required Map<String, List<String>> selectedModifiers,
    String? technique,
    String? form,
    String? baseEffectId,
    String? targetId,
  }) {
    final kept = <String, List<String>>{};
    selectedModifiers.forEach((modifierId, optionIds) {
      for (final modifier in allModifiers.where((m) => m.id == modifierId).take(1)) {
        if (modifier.scope.appliesTo(
            technique: technique,
            form: form,
            baseEffectId: baseEffectId,
            targetId: targetId)) {
          kept[modifierId] = optionIds;
        }
      }
    });
    return kept;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: PASS, all tests in the file green.

- [ ] **Step 5: Commit**

```bash
git add lib/engine/spell_engine.dart test/engine/spell_engine_test.dart
git commit -m "feat: thread targetId through pruneModifierSelections

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: `SpellCreationBloc` prunes on Target change

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart:146-150` (the `TargetSelected` handler) and `lib/bloc/spell_creation/spell_creation_bloc.dart:324-331` (`_withPrunedModifiers`)
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `SpellEngine.pruneModifierSelections(targetId:)` (Task 3).

- [ ] **Step 1: Write the failing tests**

In `test/bloc/spell_creation_bloc_test.dart`, add fixtures right after `reteEffect` (after line 704, before the `blocTest` that starts at line 706):

```dart
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
```

Then add two new `blocTest`s, right after the `'changing Form prunes a selection the new Form does not offer'` test (after line 807, before the `'SpellCalculated exposes a breakdown listing the selected modifier'` test):

```dart
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL on `'changing Target to one excluded by scope prunes a selection that depended on it'` — `selectedModifiers` still contains `size-mentem` because `TargetSelected` doesn't prune yet. The second new test passes already (nothing to prune), which is expected and fine.

- [ ] **Step 3: Wire pruning into `_withPrunedModifiers` and the `TargetSelected` handler**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, replace `_withPrunedModifiers` (lines 324-331):

```dart
  SpellDraft _withPrunedModifiers(SpellDraft draft) => draft.copyWith(
        selectedModifiers: spellEngine.pruneModifierSelections(
          selectedModifiers: draft.selectedModifiers,
          technique: draft.technique,
          form: draft.form,
          baseEffectId: draft.baseEffect?.id,
        ),
      );
```

with:

```dart
  SpellDraft _withPrunedModifiers(SpellDraft draft) => draft.copyWith(
        selectedModifiers: spellEngine.pruneModifierSelections(
          selectedModifiers: draft.selectedModifiers,
          technique: draft.technique,
          form: draft.form,
          baseEffectId: draft.baseEffect?.id,
          targetId: draft.target?.id,
        ),
      );
```

Then replace the `TargetSelected` handler (lines 146-150):

```dart
    } else if (event is TargetSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(target: event.parameter),
      ));
```

with:

```dart
    } else if (event is TargetSelected) {
      // The only Technique/Form/BaseEffect/Target handler that didn't prune
      // stale modifier selections — size-mentem's Target exclusion made that
      // a live bug rather than a theoretical gap. See todo item 19.
      final draft = _withPrunedModifiers(state.draft.copyWith(target: event.parameter));
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
      ));
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS, all tests in the file green.

- [ ] **Step 5: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "fix: prune modifier selections when Target changes

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Creation-screen picker filters by Target

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart:69-75`
- Test: `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`

**Interfaces:**
- Consumes: `ModifierScope.appliesTo(targetId:)` (Task 1).

- [ ] **Step 1: Write the failing tests**

In `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`, add fixtures right after `creoIgnemEffect` (after line 69, before the first `testWidgets`):

```dart
  final sizeMentemModifier = Modifier(
    id: 'size-mentem',
    name: 'Mentem Size Ladder',
    selectionMode: ModifierSelectionMode.single,
    scope: const ModifierScope(form: 'Mentem', excludeTargets: ['target-individual']),
    options: [ModifierOption(id: 'size-mentem-1', label: 'Up to 10x base', magnitude: 1)],
    provenance: Provenance(source: PublicationSource.userCreated),
  );
  final individualTarget = Parameter(
    id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 8,
    provenance: Provenance(source: PublicationSource.userCreated),
  );
  final groupTarget = Parameter(
    id: 'target-group', name: 'Group', category: 'Target', magnitude: 10,
    provenance: Provenance(source: PublicationSource.userCreated),
  );
```

Then add two new `testWidgets` cases, right before the file's closing `}` (after line 229, i.e. after the `'a custom modifier added via ConfigurationBloc...'` test's closing `);`):

```dart
  testWidgets(
    'a modifier excluding Individual is absent from the picker when Target is Individual',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spellCreationBloc = MockSpellCreationBloc();
      final configBloc = MockConfigurationBloc();

      whenListen(
        spellCreationBloc,
        const Stream<SpellCreationState>.empty(),
        initialState: SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(technique: 'Creo', form: 'Mentem', target: individualTarget),
        ),
      );
      whenListen(
        configBloc,
        const Stream<ConfigurationState>.empty(),
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          modifiers: [sizeMentemModifier],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: spellCreationBloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      // ModifiersSection renders nothing at all (not even the expand toggle)
      // when its filtered modifier list is empty.
      expect(find.byKey(const Key('modifiers-expand-toggle')), findsNothing);
      expect(find.textContaining('Mentem Size Ladder'), findsNothing);
    },
  );

  testWidgets(
    'the same modifier is offered once Target is Group',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spellCreationBloc = MockSpellCreationBloc();
      final configBloc = MockConfigurationBloc();

      whenListen(
        spellCreationBloc,
        const Stream<SpellCreationState>.empty(),
        initialState: SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(technique: 'Creo', form: 'Mentem', target: groupTarget),
        ),
      );
      whenListen(
        configBloc,
        const Stream<ConfigurationState>.empty(),
        initialState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          modifiers: [sizeMentemModifier],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SpellCreationBloc>.value(value: spellCreationBloc),
            BlocProvider<ConfigurationBloc>.value(value: configBloc),
          ],
          child: const SpellCreationScreen(techniques: ArsArts.all, forms: ArsForms.all),
        ),
      ));

      expect(find.byKey(const Key('modifiers-expand-toggle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
      await tester.pump();

      expect(find.textContaining('Mentem Size Ladder'), findsOneWidget);
    },
  );
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`
Expected: FAIL on the first new test — `modifiersForSelection` doesn't filter by Target yet, so `size-mentem` is offered even for an Individual target and the expand toggle is present.

- [ ] **Step 3: Filter the picker by `targetId`**

In `lib/presentation/screens/spell_creation_screen.dart`, replace the `modifiersForSelection` computation (lines 69-75):

```dart
          final modifiersForSelection = configState.modifiers
              .where((m) => m.scope.appliesTo(
                    technique: draft.technique,
                    form: draft.form,
                    baseEffectId: draft.baseEffect?.id,
                  ))
              .toList();
```

with:

```dart
          final modifiersForSelection = configState.modifiers
              .where((m) => m.scope.appliesTo(
                    technique: draft.technique,
                    form: draft.form,
                    baseEffectId: draft.baseEffect?.id,
                    targetId: draft.target?.id,
                  ))
              .toList();
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`
Expected: PASS, all tests in the file green.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/spell_creation_screen.dart test/presentation/screens/spell_creation_screen_configuration_sync_test.dart
git commit -m "fix: filter the modifier picker by the draft's Target

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Full regression pass and close out todo item 19

**Files:**
- Modify: `.superpowers/todo.md` (item 19's header, its Target-restriction checkbox, and the Mentem-exemption callout)

**Interfaces:** None — documentation only.

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: PASS, 0 failures. If anything outside the five files touched above fails, stop and investigate before continuing — it means this change had an effect not covered by this plan's own tests.

- [ ] **Step 2: Update `.superpowers/todo.md` item 19's header**

Change:

```
### 19. Size-Ladder Ceiling
```

to:

```
### 19. Size-Ladder Ceiling — ✅ COMPLETE (2026-08-16)
```

- [ ] **Step 3: Close out the Target-restriction checkbox**

Change:

```
- [ ] Add a Target restriction to `ModifierScope` (`excludeTargets` or
      `allowedTargets`) and check it in `appliesTo()` alongside the existing
      technique/form/effectIds checks — **still open**, verified 2026-08-15
      against `lib/models/modifier.dart`: `ModifierScope.appliesTo()` still
      takes only `technique`/`form`/`baseEffectId`, no target parameter
```

to:

```
- [x] Add a Target restriction to `ModifierScope` (`excludeTargets`, not an
      allow-list — mirrors the existing `excludeTechniques` carve-out) and
      check it in `appliesTo()` alongside the existing
      technique/form/effectIds checks — **✅ DONE 2026-08-16.**
      `ModifierScope` gained `excludeTargets` and `appliesTo()` a `targetId`
      parameter; `size-mentem` now carries
      `excludeTargets: ["target-individual"]`. Wired all the way through:
      the creation screen's picker filters by `draft.target?.id`, and
      `SpellCreationBloc`'s `TargetSelected` handler now prunes stale
      selections via `_withPrunedModifiers` — previously the only
      Technique/Form/BaseEffect/Target handler that didn't prune, which was
      the actual bug (switching Target to Individual left a stale
      `size-mentem` selection silently contributing magnitude). See
      `docs/superpowers/specs/2026-08-16-modifier-target-scope-design.md`.
```

- [ ] **Step 4: Resolve the Mentem-exemption callout**

Change:

```
**⚠️ Mentem's Size exemption is narrower than the code enforces.** Definitive
Edition line 14900: "Minds do not have a size, so size modifiers do not apply to
Mentem effects with **Individual targets**. However, minds can be counted, so for
Groups you still need to boost the size to affect more people."

- **Verified 2026-08-09:** the `size-mentem` modifier correctly exists in the data
  and the test, because Mentem *can* take Size for Group/Room/Structure/Boundary
  targets. The published spell import test expects it.
- **The gap is architectural:** `ModifierScope` has no Target field, so
  `size-mentem` applies to all Mentem spells. Its description says "Applies when
  targeting multiple minds via area targets", but nothing enforces that — a user
  could apply it to an Individual Mentem spell.
- **For now:** item 24's adjustments can absorb any difference on *Poisoning the
  Will*; its Boundary target makes it ineligible for scoped sizing under the
  current architecture anyway.
```

to:

```
**✅ Mentem's Size exemption is now enforced, not just documented.** Definitive
Edition line 14900: "Minds do not have a size, so size modifiers do not apply to
Mentem effects with **Individual targets**. However, minds can be counted, so for
Groups you still need to boost the size to affect more people."

- **Verified 2026-08-09:** the `size-mentem` modifier correctly exists in the data
  and the test, because Mentem *can* take Size for Group/Room/Structure/Boundary
  targets. The published spell import test expects it.
- **The architectural gap is closed 2026-08-16:** `ModifierScope.excludeTargets`
  plus `appliesTo()`'s new `targetId` parameter enforce the exemption —
  `size-mentem` is unselectable, and pruned if already selected, once Target is
  Individual, rather than relying on its description text alone.
- *Poisoning the Will*'s Boundary target remains outside scoped sizing for a
  separate, still-deferred reason — see *Related deferred work* below,
  unchanged by this fix.
```

- [ ] **Step 5: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close out todo item 19's Target-restriction checkbox

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
