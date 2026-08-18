# HoH:MC Catalog Rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the five Sensory Magic Targets and two Glamour guidelines from *Houses of Hermes: Mystery Cults*, together with the Intellego exclusion those Targets carry and the bloc changes that exclusion makes necessary.

**Architecture:** `ParameterScope` gains a negative Technique axis mirroring `ModifierScope.excludeTechniques`. Because a Target becomes Technique-scoped for the first time, `TechniqueSelected` must start pruning out-of-scope parameters, which it has never done. The catalog rows land last, so no intermediate commit ships scoped data the UI does not yet filter.

**Tech Stack:** Dart / Flutter, `flutter_bloc`, `bloc_test`, `equatable`. JSON assets under `assets/data/`.

**Spec:** `docs/superpowers/specs/2026-08-18-hohmc-catalog-rows-design.md`
**Sub-project A of three.** B (parser + 14 spells) and C (36 Faerie guidelines) are filed by Task 4, not built here.

## Global Constraints

- **Never run `dart format` in this repo.** Formatting is hand-maintained and the
  formatter is not clean here. Indent by hand and check your diff with
  `git diff -w` to confirm you changed only what you meant to.
- **Never reformat committed JSON assets.** `parameters.json` is pretty-printed
  with 2-space indentation; `base_effects.json` stores **one compact object per
  line**. Match each file's existing style exactly. After editing either, run
  `git diff --numstat` and confirm the added-line count is exactly what you
  intended — 5 objects' worth for parameters, exactly 2 lines for base effects.
- **`flutter analyze` must exit 0.** Run it before every commit.
- **Full suite command:** `flutter test`. Baseline on this branch is **721
  tests** passing.
- If `flutter test` reports a **sqlite3.dll permissions error**, that is stale
  `flutter_tester.exe` processes holding the DLL, not a real permissions
  problem. Kill them and re-run: `taskkill /F /IM flutter_tester.exe`
- Comments in this codebase carry reasoning, not restatement. Every comment
  below is given in full — write it as given rather than paraphrasing.
- **Task order is load-bearing.** The data rows land in Task 3, after the UI
  filters on Technique in Task 2. Reversing them produces a commit where a
  Target is scoped but unfiltered, which trips
  `DropdownButtonFormField`'s assertion that its value appears in its items.

---

## File Structure

No files are created. Modified:

- `lib/models/parameter.dart` — `ParameterScope` gains `excludeTechniques`;
  `appliesTo` gains a Technique argument; `toMap`/`fromMap` carry the field.
- `lib/bloc/spell_creation/spell_creation_bloc.dart` — pruning helper renamed
  and taught both axes; `TechniqueSelected` calls it; `_withSeededParameters`'
  `seed()` passes the Technique.
- `lib/presentation/screens/spell_creation_screen.dart` — the parameter dropdown
  filters on Technique; its three callers pass it.
- `assets/data/parameters.json` — 5 rows.
- `assets/data/base_effects.json` — 2 rows.
- `test/models/parameter_test.dart`, `test/bloc/spell_creation_bloc_test.dart`,
  `test/data/datasources/asset_data_loader_test.dart`,
  `test/bloc/configuration_bloc_test.dart`,
  `test/data/repositories/configuration_repository_test.dart`.
- `.superpowers/todo.md`.

---

### Task 1: `ParameterScope` gains a Technique exclusion

**Files:**
- Modify: `lib/models/parameter.dart:5-26` (the whole `ParameterScope` class)
- Test: `test/models/parameter_test.dart` (add beside the existing scope tests
  at `:238-251`)

**Interfaces:**
- Produces: `ParameterScope({List<String> forms, List<String> excludeTechniques})`
  and `bool appliesTo({String? technique, String? form})`. Tasks 2 and 3 use
  both. The `technique` argument is **named and optional**, so the three
  existing `appliesTo(form: ...)` call sites keep compiling untouched — Task 2
  updates them deliberately, not because the compiler forces it.

- [ ] **Step 1: Write the failing tests**

Add to `test/models/parameter_test.dart`, immediately after the existing
`ParameterScope` group's last test (the one asserting
`scope.appliesTo(form: null)` is `isFalse`, at `:250`). Keep them inside that
same group.

```dart
    test('excludeTechniques hides the parameter from that Technique only', () {
      const scope = ParameterScope(excludeTechniques: ['Intellego']);
      expect(scope.appliesTo(technique: 'Intellego'), isFalse);
      expect(scope.appliesTo(technique: 'Creo'), isTrue);
      // An unset Technique cannot exclude: the user has not chosen one yet,
      // and hiding every Sensory Target until they do would be wrong.
      expect(scope.appliesTo(technique: null), isTrue);
    });

    test('the Technique exclusion beats an otherwise-matching Forms list', () {
      // The two rules cannot be collapsed into one positive match, which is
      // why the negative list exists and why it is tested first.
      const scope = ParameterScope(forms: ['Ignem'], excludeTechniques: ['Intellego']);
      expect(scope.appliesTo(technique: 'Creo', form: 'Ignem'), isTrue);
      expect(scope.appliesTo(technique: 'Intellego', form: 'Ignem'), isFalse);
    });

    test('excludeTechniques survives a toMap/fromMap round trip', () {
      const scope = ParameterScope(forms: ['Ignem'], excludeTechniques: ['Intellego']);
      final restored = ParameterScope.fromMap(scope.toMap());
      expect(restored.forms, ['Ignem']);
      expect(restored.excludeTechniques, ['Intellego']);
    });
```

- [ ] **Step 2: Run them and verify they fail**

Run: `flutter test test/models/parameter_test.dart`

Expected: **FAIL to compile** — `ParameterScope` has no `excludeTechniques`
parameter and `appliesTo` takes no `technique`. A compile error is the correct
red here; there is no partial implementation to produce a runtime failure.

- [ ] **Step 3: Replace the `ParameterScope` class**

In `lib/models/parameter.dart`, replace the whole class and its doc comment
(`:5-26`) with:

```dart
/// Which Forms a parameter is offered for, and which Techniques it is never
/// offered for. An empty [forms] means unrestricted.
///
/// [excludeTechniques] carves out Techniques the parameter never applies to,
/// mirroring [ModifierScope.excludeTechniques] and added for the same shape of
/// rule: HoH:MC's five Sensory Magic Targets, which the book forbids on any
/// spell employing Intellego, "even as a requisite" -- the requisite half needs
/// a validation check rather than a scope field, and is todo item 67.
///
/// One list is positive and the other negative because that is how each rule is
/// written, not by accident: Fire is offered *for* Ignem and Imaginem, while a
/// Sensory Target is offered for everything *except* Intellego. A positive
/// Technique list could not express the second without naming all four others.
class ParameterScope {
  final List<String> forms;
  final List<String> excludeTechniques;
  const ParameterScope({this.forms = const [], this.excludeTechniques = const []});

  // technique and form are nullable, not required, matching
  // ModifierScope.appliesTo -- draft.technique and draft.form are String?
  // (unset until the user picks one), and a Form-restricted parameter must stay
  // hidden until it does. An empty forms list short-circuits before the null
  // check, so an unrestricted parameter is unaffected by an unset Form.
  //
  // An unset *Technique* is the opposite case and excludes nothing: hiding
  // every Sensory Target before the user has chosen a Technique would hide
  // them from the four Techniques that may use them.
  //
  // Exclusion is tested before the positive match, matching ModifierScope's
  // ordering, because a Forms match cannot overrule "never on this Technique".
  bool appliesTo({String? technique, String? form}) {
    if (technique != null && excludeTechniques.contains(technique)) return false;
    return forms.isEmpty || forms.contains(form);
  }

  Map<String, dynamic> toMap() => {'forms': forms, 'excludeTechniques': excludeTechniques};

  factory ParameterScope.fromMap(Map<String, dynamic>? map) => ParameterScope(
        forms: map == null ? const [] : List<String>.from(map['forms'] as List? ?? const []),
        excludeTechniques: map == null
            ? const []
            : List<String>.from(map['excludeTechniques'] as List? ?? const []),
      );
}
```

Note `fromMap` defaults the new key to an empty list, so the 34 existing
`parameters.json` rows — none of which carry it — deserialize unchanged.

- [ ] **Step 4: Run the tests and the analyzer**

```bash
flutter test test/models/parameter_test.dart
flutter analyze
```

Expected: all PASS, analyzer 0. The three pre-existing `appliesTo(form: ...)`
tests at `:240-250` must still pass untouched — the new argument is optional.

- [ ] **Step 5: Run the full suite**

Run: `flutter test`

Expected: 724 passing (721 baseline + 3 new). Nothing else should move: no
production call site passes a Technique yet, so behaviour is unchanged.

- [ ] **Step 6: Commit**

```bash
git diff -w --stat
git add lib/models/parameter.dart test/models/parameter_test.dart
git commit -m "feat: ParameterScope can exclude a Technique"
```

Body:

```
ModifierScope has had excludeTechniques since the Size ladders needed to
exempt Intellego across every Form. ParameterScope's doc comment said to
add the axis when real evidence demanded it; HoH:MC's five Sensory Magic
Targets, which the book forbids on any Intellego spell, are that
evidence.

Model only -- no caller passes a Technique yet, and no catalog row sets
the field, so nothing changes behaviourally. Both follow.
```

---

### Task 2: The Technique reaches the scope check, and a pruned Target drops its mode

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart` — the helper at
  `:604-613`, its call site in `FormSelected` at `:271`, `TechniqueSelected` at
  `:206-228`, and `seed()` inside `_withSeededParameters` at `:677`
- Modify: `lib/presentation/screens/spell_creation_screen.dart` — the dropdown
  builder at `:677-688` and its three callers at `:281`, `:294`, `:307`
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `ParameterScope.appliesTo({String? technique, String? form})` from
  Task 1.
- Produces: `SpellDraft _withPrunedScopedParameters(SpellDraft draft)` —
  renamed from `_withPrunedFormScopedParameters`, now prunes on both axes.
  Task 3's catalog rows rely on this being in place first.

- [ ] **Step 1: Write the failing tests**

Add to `test/bloc/spell_creation_bloc_test.dart`. Put them in a new group at the
end of the file, before its final closing `});` if the file ends inside a group,
otherwise at top level beside the other `blocTest` groups.

The fixture is local: no catalog row carries `excludeTechniques` until Task 3,
and these tests should not depend on one that will exist later.

```dart
  group('a Technique change prunes parameters it puts out of scope', () {
    // A stand-in for HoH:MC's Sound, which Task 3 adds: a container Target the
    // rulebook forbids on Intellego spells. Built here rather than read from
    // the catalog so this behaviour is pinned independently of the data.
    final sensoryTarget = Parameter(
      id: 'target-sound-test',
      name: 'Sound',
      category: 'Target',
      magnitude: 3,
      targetType: TargetType.container,
      scope: const ParameterScope(excludeTechniques: ['Intellego']),
      // Provenance's constructor rejects a published source with no
      // citations, so this cites the book the real Target comes from.
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-hohmc')],
      ),
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
```

If `ContainerMode`, `TargetType`, `Parameter`, `Provenance`, `Citation` or
`PublicationSource` are not already imported by that test file, add the imports
— check the file's existing import block first, since most are likely present.

- [ ] **Step 2: Run them and verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "prunes parameters it puts out of scope"`

Expected: the **first FAILS** — `TechniqueSelected` does not prune at all
today, so `draft.target` is still the Sensory Target. The **second PASSES**
already, for the trivial reason that nothing prunes anything; it is there to
stop the fix over-pruning, and it is the assertion that would break if the new
pruning were keyed to the wrong axis.

- [ ] **Step 3: Rename the helper and teach it both axes**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, replace the helper at
`:604-613`:

```dart
  SpellDraft _withPrunedFormScopedParameters(SpellDraft draft) {
    Parameter? pruneIfOutOfScope(Parameter? parameter) =>
        parameter != null && !parameter.scope.appliesTo(form: draft.form) ? null : parameter;

    return draft.copyWith(
      range: pruneIfOutOfScope(draft.range),
      duration: pruneIfOutOfScope(draft.duration),
      target: pruneIfOutOfScope(draft.target),
    );
  }
```

with:

```dart
  SpellDraft _withPrunedScopedParameters(SpellDraft draft) {
    Parameter? pruneIfOutOfScope(Parameter? parameter) =>
        parameter != null &&
                !parameter.scope.appliesTo(technique: draft.technique, form: draft.form)
            ? null
            : parameter;

    return draft.copyWith(
      range: pruneIfOutOfScope(draft.range),
      duration: pruneIfOutOfScope(draft.duration),
      target: pruneIfOutOfScope(draft.target),
    );
  }

  // No containerMode handling here, deliberately. Every caller wraps this in
  // _withSeededParameters, whose final copyWith sets
  // `containerMode: keepsMode ? null : ContainerMode.unstated` from the
  // *resulting* Target -- so a Target pruned to null always reaches a mode
  // clear one call later. todo item 58 recorded a stranded mode as a latent
  // hole here; the draft-reference-seed work (8143c8e) closed it before this
  // change, and a clear in this helper would be unreachable code.
```

Also update the helper's doc comment above it: the sentence ending
"…since the dropdown filters its items by the new Form's scope" should read
"…by the new Technique's and Form's scope", and the opening "one Form must not
survive a change to a Form it isn't offered for" should read "one Technique or
Form must not survive a change to one it isn't offered for".

- [ ] **Step 4: Point the two existing references at the new name**

`FormSelected` at `:271` calls `_withPrunedFormScopedParameters(` — rename to
`_withPrunedScopedParameters(`. A doc comment at `:649` also names it
("skipped for the same reason _withPrunedFormScopedParameters exists") — update
that spelling too.

Confirm none remain:

```bash
grep -n "_withPrunedFormScopedParameters" lib/bloc/spell_creation/spell_creation_bloc.dart
```

Expected: no output.

- [ ] **Step 5: Make `TechniqueSelected` prune**

In the `TechniqueSelected` branch (`:206-228`), wrap the `state.draft.copyWith(...)`
in the helper, exactly as `FormSelected` does. The block currently opens:

```dart
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(_withSeededParameters(
          state.draft.copyWith(
            technique: event.technique,
```

and must become:

```dart
      final draft = _withRitualDeclaration(
        _withPrunedModifiers(_withSeededParameters(
          _withPrunedScopedParameters(state.draft.copyWith(
            technique: event.technique,
```

The closing parenthesis of that `copyWith` needs one more `)` to match — find
the line reading `          ),` that closes it (just before `          previousReference,`)
and make it `          )),`.

- [ ] **Step 6: Pass the Technique in `seed()`**

In `_withSeededParameters`, at `:677`, replace:

```dart
          !candidate.scope.appliesTo(form: draft.form)) {
```

with:

```dart
          !candidate.scope.appliesTo(technique: draft.technique, form: draft.form)) {
```

Without this, re-seeding could reinstate a Target the Technique forbids
immediately after the helper pruned it.

- [ ] **Step 7: Filter the dropdown on Technique**

In `lib/presentation/screens/spell_creation_screen.dart`, add a parameter to
`_buildParameterDropdown` (`:677-684`). Its signature currently includes
`required String? form,` — add directly above it:

```dart
    required String? technique,
```

and change the filter at `:686-688`:

```dart
    final categoryParameters = parameters
        .where((p) => p.category == category && p.scope.appliesTo(form: form))
        .toList();
```

to:

```dart
    final categoryParameters = parameters
        .where((p) =>
            p.category == category && p.scope.appliesTo(technique: technique, form: form))
        .toList();
```

Then in each of the three callers (`:281` Range, `:294` Duration, `:307`
Target), add `technique: draft.technique,` directly above the existing
`form: draft.form,` line.

- [ ] **Step 8: Run the tests and the analyzer**

```bash
flutter test test/bloc/spell_creation_bloc_test.dart
flutter analyze
```

Expected: both new tests PASS, analyzer 0, and the rest of the bloc suite
unchanged. If a pre-existing test fails, the likely cause is Step 5's
parenthesis edit — check `git diff -w` on `TechniqueSelected` before assuming
the test is wrong.

- [ ] **Step 9: Run the full suite**

Run: `flutter test`

Expected: 726 passing (724 after Task 1, plus 2). Widget tests must stay green:
no catalog row sets `excludeTechniques` yet, so the dropdowns offer exactly what
they offered before.

- [ ] **Step 10: Commit**

```bash
git diff -w --stat
git add lib/bloc/spell_creation/spell_creation_bloc.dart lib/presentation/screens/spell_creation_screen.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "fix: a Technique change prunes parameters it forbids, and their mode"
```

Body:

```
_withPrunedFormScopedParameters was called from FormSelected alone,
because no parameter had ever been Technique-scoped. HoH:MC's Sensory
Targets are, so TechniqueSelected has to prune too, and the helper is
renamed for the axis it gained.

No containerMode change: every caller wraps this helper in
_withSeededParameters, which already clears a stranded mode from the
resulting Target. todo item 58 recorded that hole as latent; 8143c8e
closed it, and a clear here would be unreachable.
```

---

### Task 3: The catalog rows

**Files:**
- Modify: `assets/data/parameters.json` (append 5 objects before the closing `]`)
- Modify: `assets/data/base_effects.json` (append 2 lines before the closing `]`)
- Test: `test/data/datasources/asset_data_loader_test.dart`,
  `test/bloc/configuration_bloc_test.dart`,
  `test/data/repositories/configuration_repository_test.dart`

**Interfaces:**
- Consumes: `excludeTechniques` from Task 1 and the filtering from Task 2. Both
  must be in place — these rows are the first data that exercises either.
- Produces: parameter ids `target-flavor`, `target-texture`, `target-scent`,
  `target-sound`, `target-spectacle`; base effect ids `crim-hohmc-10`,
  `muim-hohmc-10`.

- [ ] **Step 1: Write the failing tests**

Add to `test/data/datasources/asset_data_loader_test.dart`, after the existing
parameter-count test at `:42`:

```dart
  test('the five Sensory Magic Targets load with their stated ladder', () async {
    // The magnitudes are the whole content of these rows and the book gives
    // them only by equivalence (Flavor to Individual, Texture to Part, Scent to
    // Group, Sound to Structure, Spectacle to Boundary), so a silent typo in
    // one produces spells that compute a plausible wrong level. Each was
    // reconciled against a printed HoH:MC design line -- see the spec.
    final parameters = await AssetDataLoader().loadParameters();
    final byId = {for (final p in parameters) p.id: p};

    const expected = <String, (int, TargetType)>{
      'target-flavor': (0, TargetType.object),
      'target-texture': (1, TargetType.object),
      'target-scent': (2, TargetType.object),
      'target-sound': (3, TargetType.container),
      'target-spectacle': (4, TargetType.container),
    };

    for (final entry in expected.entries) {
      final parameter = byId[entry.key];
      expect(parameter, isNotNull, reason: '${entry.key} missing from parameters.json');
      expect(parameter!.magnitude, entry.value.$1, reason: '${entry.key} magnitude');
      expect(parameter.targetType, entry.value.$2, reason: '${entry.key} targetType');
      expect(parameter.category, 'Target');
      expect(parameter.requiresVirtue, 'Sensory Magic');
      // The rule this carries: HoH:MC forbids these Targets on any spell
      // employing Intellego.
      expect(parameter.scope.excludeTechniques, ['Intellego'], reason: '${entry.key} scope');
    }
  });

  test('the two Glamour guidelines load, gated on the Glamour Mystery', () async {
    // muim-hohmc-10 is the only base level any HoH:MC spell needs that the core
    // catalog cannot supply -- Ball of Abysmal Music, (Base 10, +2 Voice).
    final effects = await AssetDataLoader().loadBaseEffects();
    final byId = {for (final e in effects) e.id: e};

    for (final id in ['crim-hohmc-10', 'muim-hohmc-10']) {
      final effect = byId[id];
      expect(effect, isNotNull, reason: '$id missing from base_effects.json');
      expect(effect!.baseLevel, 10, reason: '$id baseLevel');
      expect(effect.form, 'Imaginem', reason: '$id form');
      expect(effect.requiresVirtue, 'Glamour', reason: '$id requiresVirtue');
    }
    expect(byId['crim-hohmc-10']!.technique, 'Creo');
    expect(byId['muim-hohmc-10']!.technique, 'Muto');
  });
```

Check the file's existing tests for how it constructs the loader and whether
`TargetType` is imported; match whatever idiom is already there rather than the
`AssetDataLoader()` spelling above if it differs.

- [ ] **Step 2: Run them and verify they fail**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`

Expected: both new tests **FAIL** on the first `isNotNull` — none of the seven
ids exists yet. The pre-existing count tests also fail only *after* Step 3; right
now they still pass.

- [ ] **Step 3: Add the five parameters**

In `assets/data/parameters.json`, insert these five objects immediately after
the final `target-symbol` object's closing `},` — that is, add a comma after the
current last object and put these before the file's closing `]`. Match the
existing 2-space indentation exactly:

```json
  {
    "id": "target-flavor",
    "name": "Flavor",
    "category": "Target",
    "magnitude": 0,
    "targetType": "object",
    "requiresVirtue": "Sensory Magic",
    "scope": {
      "forms": [],
      "excludeTechniques": [
        "Intellego"
      ]
    },
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  },
  {
    "id": "target-texture",
    "name": "Texture",
    "category": "Target",
    "magnitude": 1,
    "targetType": "object",
    "requiresVirtue": "Sensory Magic",
    "scope": {
      "forms": [],
      "excludeTechniques": [
        "Intellego"
      ]
    },
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  },
  {
    "id": "target-scent",
    "name": "Scent",
    "category": "Target",
    "magnitude": 2,
    "targetType": "object",
    "requiresVirtue": "Sensory Magic",
    "scope": {
      "forms": [],
      "excludeTechniques": [
        "Intellego"
      ]
    },
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  },
  {
    "id": "target-sound",
    "name": "Sound",
    "category": "Target",
    "magnitude": 3,
    "targetType": "container",
    "requiresVirtue": "Sensory Magic",
    "scope": {
      "forms": [],
      "excludeTechniques": [
        "Intellego"
      ]
    },
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  },
  {
    "id": "target-spectacle",
    "name": "Spectacle",
    "category": "Target",
    "magnitude": 4,
    "targetType": "container",
    "requiresVirtue": "Sensory Magic",
    "scope": {
      "forms": [],
      "excludeTechniques": [
        "Intellego"
      ]
    },
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  }
```

None sets `requiresRitual` — Sensory Targets carry no ritual requirement, unlike
`target-symbol` above them.

- [ ] **Step 4: Add the two base effects**

`base_effects.json` stores **one compact object per line**. Append these two
lines immediately before the closing `]`, adding a comma to the current last
line:

```json
  {"id": "crim-hohmc-10", "technique": "Creo", "form": "Imaginem", "description": "Create a glamour", "baseLevel": 10, "source": "published", "citations": [{"bookId": "arm5-hohmc"}], "requiresVirtue": "Glamour"},
  {"id": "muim-hohmc-10", "technique": "Muto", "form": "Imaginem", "description": "Change a target into glamour (requisite of the Form of the target required)", "baseLevel": 10, "source": "published", "citations": [{"bookId": "arm5-hohmc"}], "requiresVirtue": "Glamour"}
```

Then confirm you added exactly two lines and reformatted nothing:

```bash
git diff --numstat assets/data/base_effects.json
```

Expected: `3	1	assets/data/base_effects.json` — two new lines plus the
comma-modified previous last line.

- [ ] **Step 5: Update the three count assertions**

These are deliberate drift detectors, not obstacles:

- `test/data/datasources/asset_data_loader_test.dart:42` — `expect(parameters.length, 34);` → `39`
- `test/bloc/configuration_bloc_test.dart:57` — `'parameters.length', 34` → `39`
- `test/data/repositories/configuration_repository_test.dart:45` — `expect(all.length, 610);` → `612`, and its trailing comment `// 609 built-in (10 Forms) + 1 custom` → `// 611 built-in (10 Forms) + 1 custom`
- `test/data/repositories/configuration_repository_test.dart:59` — `expect(all.length, 609);` → `611`

- [ ] **Step 6: Run the tests and the analyzer**

```bash
flutter test
flutter analyze
```

Expected: 728 passing (726 after Task 2, plus 2), analyzer 0.

If a widget test fails here, that is a real signal, not noise: it means a
dropdown is offering or hiding something unexpectedly, and Task 2's filtering is
what to check.

- [ ] **Step 7: Verify the new rows behave in the app's own terms**

```bash
python -c "import sys; sys.path.insert(0,'scripts'); from spell_import import catalog as C; c=C.Catalog.load(); print('MuIm base 10 candidates:', c.candidates('Muto','Imaginem',10)); print('parameter id for Target/Sound:', c.parameter_id('Target','Sound'))"
```

Expected: `['muim-hohmc-10']` and `target-sound`. The first returns `[]` today
and is the assertion sub-project B depends on.

- [ ] **Step 8: Commit**

```bash
git diff -w --stat
git add assets/data/parameters.json assets/data/base_effects.json test/
git commit -m "feat: HoH:MC's Sensory Magic Targets and Glamour guidelines"
```

Body:

```
Five Targets and two guidelines from Houses of Hermes: Mystery Cults.
The book gives the Target magnitudes only by equivalence -- Flavor to
Individual, Texture to Part, Scent to Group, Sound to Structure,
Spectacle to Boundary -- so each was reconciled against a printed design
line before being written down.

targetType follows those printed equivalences rather than the core sense
ladder, which matches sense-for-sense and magnitude-for-magnitude but
means the opposite thing: a core sense Target grants the caster a sense,
and HoH:MC forbids Intellego precisely because that is the other
feature.

muim-hohmc-10 is the only base level any HoH:MC spell needs that the
core catalog cannot supply.
```

---

### Task 4: File the follow-on work and correct item 58's bullet

**Files:**
- Modify: `.superpowers/todo.md`

**Interfaces:**
- Consumes: the three commits from Tasks 1-3.
- Produces: item 64 (this work, closed), items 65 and 66 (sub-projects B and
  C), item 67 (the deferred restrictions), and item 58's bullet corrected.

- [ ] **Step 1: Run the full suite and record the count**

```bash
flutter test
flutter analyze
```

Expected: 728 passing, analyzer 0. Record the actual number — you need it in
Step 5.

- [ ] **Step 2: Correct item 58's `_withPrunedFormScopedParameters` bullet**

In `.superpowers/todo.md`, find item 58's bullet beginning
"**A latent hole in `_withPrunedFormScopedParameters`**". Leave its text intact
— it is the record of the prediction — and append this to the end of that
bullet, matching the style item 58's first bullet uses for its own closure
("**✅ DONE 2026-08-17 via item 59.**"). Note what it says: the bullet was
already stale when item 64 began, and item 64 is what revealed that, not what
fixed it. Do not credit this branch with the fix.

```markdown
      **✅ ALREADY CLOSED — verified 2026-08-18 during item 64.** Not latent:
      stale. `_seedParameters` ends with
      `containerMode: keepsMode ? null : ContainerMode.unstated`, computed from
      the *resulting* Target, and every caller of the pruning helper wraps it in
      `_withSeededParameters` — so a Target pruned to null always reaches a mode
      clear one call later. `git log -S` dates that line to `8143c8e`, the
      draft-reference-seed work, which landed after this bullet was written.
      Item 64 gave the helper a second axis and looked for the hole to confirm
      it; there was none to fix.
```

- [ ] **Step 3: Open item 64 for this work**

Add to the `## Completed ✅` section, at the top, immediately after its intro
paragraph and before the newest existing entry:

```markdown
### 64. HoH:MC Catalog Rows and the Intellego Exclusion (`<first>..<last>`)
Sub-project A of three. The five Sensory Magic Targets and two Glamour
guidelines *Houses of Hermes: Mystery Cults* needs, plus the one rulebook
restriction on them the model can express.

- **`ParameterScope` gained a negative Technique axis**, mirroring
  `ModifierScope.excludeTechniques`, on the evidence its own doc comment asked
  for. Positive Forms list, negative Technique list, because that is how each
  rule is written: Fire is offered *for* Ignem and Imaginem; a Sensory Target is
  offered for everything *except* Intellego.
- **The Target magnitudes are given only by equivalence in the book**, so each
  was reconciled against a printed design line before being written down —
  Flavor 0, Texture 1, Scent 2, Sound 3, Spectacle 4.
- **`targetType` follows the printed equivalences, not the core `sense` ladder**,
  which matches sense-for-sense and magnitude-for-magnitude but means the
  opposite thing. HoH:MC forbids Intellego precisely because granting senses is
  the other feature.
- **Taking the exclusion forced two more changes**, neither optional:
  `TechniqueSelected` had never pruned, because no parameter had ever been
  Technique-scoped. **Item 58's `containerMode` bullet turned out to be stale,
  not latent** — `_seedParameters` has cleared a stranded mode since `8143c8e`,
  and every caller of the pruning helper seeds after it. Recorded rather than
  "fixed": the second axis is what prompted the check, and the check found
  nothing to repair.
- **Spec:** `docs/superpowers/specs/2026-08-18-hohmc-catalog-rows-design.md`.
  **Plan:** `docs/superpowers/plans/2026-08-18-hohmc-catalog-rows.md`.
- **See also:** items 17 (the precedent), 55 (book-aware oracles), 58 (bullet
  closed), 65, 66, 67.
```

Replace `<first>..<last>` with the range from `git log --oneline -4`: the Task 1
commit through the Task 3 commit.

- [ ] **Step 4: Open items 65, 66 and 67**

Add these three to the open-items area, immediately after item 63's block and
before the `---` that precedes `## Completed ✅`:

```markdown
### 65. HoH:MC Spell Extraction — the Inline Block Parser (sub-project B)

**Opened 2026-08-18.** Item 65 landed the catalog rows; this is the work they
were for, and the real test of whether the core-book importer generalises.

`blocks.parse_de` anchors on `### Creo Animal Spells` + `#### LEVEL 20` +
`##### Name`. HoH:MC uses `##### Name` followed by `MuAn 15` on the next line,
much of it inside blockquotes. **Zero of its 16 blocks are visible to the
current parser.** `run()` also hard-codes `sources.DE_TITLE` and `source.lock`
holds exactly one book.

- [ ] **Add `parse_inline` behind a per-book registry.** Leave `parse_de`
      untouched — it imports 325 working spells. Strip blockquote prefixes;
      anchor on the `TeFo Level` line.
- [ ] **Extract the 14 spells.** 16 blocks less *Faerie Chains of the Familiar
      Slave* (hand-authored, item 17) and *Perceive the Change*, which is an
      enchanted-device effect: `Pen 0, constant effect`, costing `+1 two
      uses/day, +3 environmental trigger`. The app models no enchantments.
- [ ] **Rule static/dynamic for the four spells using Sound or Spectacle** —
      *Clarion Call of the War Horse*, *The Rooster's Crow*, *Brilliance of the
      Eagle's Plumage*, *Closed Mouth of the Nightwalker*. Both Targets are
      containers, so `spellOwesContainerMode` says they owe one. See item 57.
- [ ] **Validate the parser against the other inline books as a diagnostic, not
      an import.** Covenants (42/44 inline), HoH:Societates (50/59),
      Transforming Mythic Europe (68/84). **No spell from any book but HoH:MC
      enters `spell_library.json` in this pass** — otherwise "validation"
      quietly becomes a 600-spell import. Problems in other books are
      identified and logged; only cheap resolutions land, of the kind
      `_normalize_stat_line` already precedents. Expect a long log; that is the
      honest outcome, not a fault.
- **Corpus survey backing this** is recorded in item 64's spec: 54 books, 3107
  stat lines, four anchor styles. The inline style is 664 of them, so it pays
  for far more than 14 spells. Product line does not predict format —
  HoH:*True Lineages* is 55/55 *heading* style.
- **Files:** `scripts/spell_import/blocks.py`, `sources.py`,
  `extract_spells.py`, `source.lock`
- **See also:** items 64, 57, 66

### 66. HoH:MC's 36 Faerie "Animae" Guidelines (sub-project C)

**Opened 2026-08-18.** A bulk catalog sweep, deliberately separated from item 65
so it cannot block the spells: only 1 of HoH:MC's 38 new guidelines is used by
any of its example spells, and item 64 already added that one.

The table is regular — `### <Form>` → `#### <Technique> <Form>` →
`**Level N:** <description>`, at `Ars Magica 5e - Houses of Hermes - Mystery
Cults.md:3464-3620` — 36 Creo/Muto "create or change a faerie" rows across the
ten Forms, all gated on Faerie Magic.

- [ ] Decide whether to extract by script or hand-author. The core base-effect
      extraction is the precedent for the former; item 17's single row for the
      latter.
- [ ] Set `requiresVirtue: "Faerie Magic"` on every row, matching
      `crvi-hohmc-G1`.
- [ ] Check the ids against the `<te><fo>-hohmc-<level>` convention item 64 used,
      and against item 41's row-duplication concerns.
- **See also:** items 64, 65, 17

### 67. The Sensory Magic Restrictions the Model Cannot Yet Express

**Opened 2026-08-18, from item 64's review.** HoH:MC lines 1005-1011 put six
restrictions on Sensory Magic spells. Item 65 implemented one. An earlier draft
of its spec dismissed all six with a single reason — "the app has no Virtue
model" — which is true of three and false of two; this item records the accurate
position so the tractable ones stay visible.

- [ ] **No Intellego *as a requisite*.** Item 65's `excludeTechniques` covers
      only the spell's own Technique. The book says "even as a requisite", which
      needs a validation check over `draft.requisites` — a different mechanism
      from a scope field, which is why it was not folded in.
- [ ] **The Range must be Personal.** No capability exists: no parameter
      constrains another parameter's value today. Building a general
      cross-parameter mechanism for five rows is disproportionate, so this needs
      a design decision before any code.
- [ ] **The Form must suit the sensory medium** ("An Ignem spell cannot be
      transmitted by sound"). Storyguide judgment by the book's own wording, so
      display work — belongs with item 56's rules hints, not enforcement.
- **Won't do, recorded so they are not re-litigated:** not investable into
  magical items (the app models no enchantments — the same reason item 65
  excludes *Perceive the Change*); non-initiates cannot learn them, and the
  Heartbeast Ability adds to the Lab Total (no character model, no lab totals).
- **Files:** `lib/models/spell.dart` (the validation checks),
  `lib/models/parameter.dart`
- **See also:** items 64, 56, 17
```

- [ ] **Step 5: Update the test count in the todo header**

`.superpowers/todo.md`'s status table has a Dart row reading
`**721 tests, green**`. Change it to the count you measured in Step 1, and check
the provenance line above the table still reads accurately for the Dart row —
it should say the Dart figure was re-run 2026-08-18 after item 64.

- [ ] **Step 6: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close item 64, open items 65, 66 and 67"
```

---

## Verification

```bash
flutter test
flutter analyze
grep -n "_withPrunedFormScopedParameters" lib/
python -c "import sys; sys.path.insert(0,'scripts'); from spell_import import catalog as C; print(C.Catalog.load().candidates('Muto','Imaginem',10))"
```

Expected: 728 passing; analyzer 0; the grep silent (the old helper name is gone);
and `['muim-hohmc-10']`, which is what sub-project B will depend on.
