# Spell Invariant Enforcement (Part A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the catalog-dependent spell invariants enforceable on every path that can produce or hold a `Spell`, not just the creation screen.

**Architecture:** One shared validator function beside `validateSpellProse` in `lib/models/spell.dart`, taking the record's pieces plus the catalog entries they resolve to. `SpellEngine.validateSpellDraft` delegates to it (draft path), `SpellRepository` calls it to block writes, `ResolvedSpell.problems` calls it for display, and a new assertion 7 runs it over the published assets. Supporting changes: `SpellResolver` starts carrying modifiers, `SpellRepository` gains a `ConfigurationRepository` so it can refresh before validating, and `AssetDataLoader` memoises its parses so that refresh is affordable.

**Tech Stack:** Dart / Flutter, `flutter_bloc`, `sqflite` (+ `sqflite_common_ffi` for tests), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-09-spell-invariant-enforcement-design.md`
**Todo item:** 40

## Global Constraints

- **Part B is out of scope.** `Spell.requisites` stays `List<Requisite>`. Check 4 (no duplicate requisite art) stays a runtime check and is *not* modelled away in this plan.
- **Existing validation error strings must not change.** `SpellEngine.validateSpellDraft`'s messages are asserted by existing tests. The validator must emit them verbatim: `'Choose a level for this General guideline'`, `'The chosen level must be at least 1'`, `"Requisite art cannot be the spell's own technique or form"`, `'Duplicate requisite art: <art>'`, `'Only one option may be selected for <modifier name>'`.
- **No unchecked write method on `SpellRepository`.** `saveAll` differs from `saveSpell` only in failure mode, never in whether it validates.
- **Backwards compatibility is not a goal.** No migration for already-stored invalid rows; the DB is droppable.
- **An unknown modifier id stays tolerated,** contributing 0, as `calculateBreakdown` already documents. Do not add a check for it.
- **Run `flutter test` after every task.** `flutter test` does **not** run `integration_test/` — that needs `flutter test integration_test/<file> -d windows`. See todo item 6.
- **Note:** `integration_test/spell_creation_flow_test.dart` has 2 of 5 tests failing on `main` before this work starts (todo item 6). Do not treat those two as regressions; do confirm the count stays at 2.

## Three refinements to the spec, decided during planning and execution

1. **The validator needs an `isTemplate` flag.** The spec says checks 1 and 2 do not apply to templates, but a `SpellTemplate` built on a General guideline legitimately has no chosen level — so running check 1 over `spell_templates.json` would fail every General template. The validator therefore takes `bool isTemplate = false`, which skips checks 1 and 2.
2. **`SpellResolver.modifiers` is required; `ResolvedSpell.modifiers` defaults to `const []`.** The resolver is the production construction path and must not be able to forget modifiers. `ResolvedSpell` is constructed directly only by test fixtures (21 sites), where an empty modifier list is accurate rather than a bypass.
3. **Checks 3 and 4 interact; they are not independent passes.** Discovered 2026-08-09 during Task 3: this plan originally specified checks 3 ("requisite art cannot match the spell's own Technique/Form") and 4 ("no duplicate requisite art") as two fully independent single-pass checks — and that version is a **self-contradiction**, confirmed by hand-tracing and by an independent task reviewer. `generalEffect()` (Rego Vim) with two `Requisite(art: 'Rego', ...)` entries produces **4** problems under the independent-passes algorithm (1 general-level + 2× check 3 + 1× check 4), but this plan's own `'problems accumulate rather than short-circuiting'` test asserted `problems.length == 2`. No implementation of the originally-specified algorithm can pass the originally-specified test.
   **Ruling (human, 2026-08-09): suppress the redundant check-3 message when the same requisite art is already flagged as a duplicate by check 4.** A two-pass algorithm first collects arts that appear more than once, then on the report pass skips the "cannot be the spell's own technique or form" message for any requisite whose art is in that set — the duplicate message alone still fires. This is not merely cosmetic: a user who deduplicates down to one copy of that requisite still sees check 3 fire normally on the remaining single instance, so no problem is permanently hidden, only de-duplicated while the redundant row exists. Confirmed by the 2026-08-09 published-asset scan (0 spells have any duplicate-art or self-technique-art violation today) that this changes no currently-shipped spell's validation outcome — the fork only matters for malformed data that cannot exist in the shipped assets today.
   **Corrected algorithm** (supersedes the checks-3/4 code shown originally in Task 3, Step 3, below):
   ```dart
     // 3 and 4. A requisite naming the spell's own Art is meaningless, and the
     //    same Art twice is contradictory. The two checks interact: when an art
     //    is both self-matching and duplicated, only the duplicate message
     //    fires -- the self-match message would be redundant noise about the
     //    same offending row. Deduplicating down to one copy re-exposes check 3
     //    on the remaining instance, so nothing is permanently hidden.
     final seenArts = <String>{};
     final duplicateArts = <String>{};
     for (final requisite in requisites) {
       if (!seenArts.add(requisite.art)) duplicateArts.add(requisite.art);
     }

     seenArts.clear();
     for (final requisite in requisites) {
       if ((requisite.art == effect.technique || requisite.art == effect.form) &&
           !duplicateArts.contains(requisite.art)) {
         problems.add("Requisite art cannot be the spell's own technique or form");
       }
       if (!seenArts.add(requisite.art)) {
         problems.add('Duplicate requisite art: ${requisite.art}');
       }
     }
   ```
   **Test coverage requirement added by this ruling:** a requisite matching the spell's own Technique/Form that is *not* duplicated must still produce the check-3 message — the original brief's test suite covered the duplicated+self-matching case only by accident (via the contradiction above) and never covered the plain, non-duplicated self-match case in isolation. Task 3 must include this test regardless of which task closes the ruling.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `lib/data/datasources/asset_data_loader.dart` | Modify | Memoise asset parses; DRY the six near-identical loaders |
| `lib/models/spell.dart` | Modify | Add `validateSpellAgainstCatalog` beside `validateSpellProse` |
| `lib/data/spell_resolver.dart` | Modify | Carry modifiers; populate `ResolvedSpell.modifiers` |
| `lib/models/resolved_spell.dart` | Modify | Add `modifiers` field and `problems` getter |
| `lib/engine/spell_engine.dart` | Modify | `validateSpellDraft` delegates to the validator |
| `lib/data/repositories/spell_repository.dart` | Modify | Refresh, validate, block; add `saveAll` |
| `lib/models/invalid_spell_exception.dart` | Create | The exception writes throw |
| `lib/data/services/backup_service.dart` | Modify | Reorder import; use `saveAll`; report rejections |
| `lib/presentation/screens/backup_screen.dart` | Modify | Surface rejected spells |
| `lib/main.dart` | Modify | Wire modifiers into the resolver, config into the repository |
| `test/data/published_spell_import_test.dart` | Modify | Assertion 7 |

---

### Task 1: Memoise `AssetDataLoader`

**Files:**
- Modify: `lib/data/datasources/asset_data_loader.dart`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AssetDataLoader.loadBaseEffects()`, `loadParameters()`, `loadModifiers()`, `loadSpellLibrary()`, `loadSpellTemplates()`, `loadBooks()` — unchanged signatures, now returning the *same* list instance on repeat calls. Lists are unmodifiable.

- [ ] **Step 1: Write the failing test**

Add to `test/data/datasources/asset_data_loader_test.dart`:

```dart
  test('repeat loads return the identical parsed list, not a re-parse', () async {
    final loader = AssetDataLoader();

    final first = await loader.loadBaseEffects();
    final second = await loader.loadBaseEffects();

    // Identity, not equality: a re-parse would produce an equal-but-distinct
    // list. ConfigurationRepository.getAllEffects delegates straight here and
    // is called by both SpellRepository._refreshResolver (every save) and
    // LibraryRepository._refreshResolver (every Library tab visit).
    expect(identical(first, second), isTrue);
  });

  test('a cached list cannot be mutated by one caller and seen by another', () async {
    final loader = AssetDataLoader();
    final effects = await loader.loadBaseEffects();

    expect(() => effects.clear(), throwsUnsupportedError);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — the identity test fails because each call re-parses; the mutation test fails because a plain `List` allows `clear()`.

- [ ] **Step 3: Implement the memoisation**

Replace the body of `lib/data/datasources/asset_data_loader.dart` with:

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/book.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_template.dart';

/// Loads the shipped JSON catalogs.
///
/// Every parse is memoised. Assets are immutable at runtime, so this needs no
/// invalidation story — the same reason `LibraryRepository.getBuiltInSpells`
/// already caches. Custom entries live in the database and are deliberately
/// **not** cached here; `ConfigurationRepository` reads those fresh on every
/// call, so the built-in half being memoised does not stale anything.
///
/// Without this, `ConfigurationRepository.getAllEffects` re-read and re-parsed
/// all 611 entries of `base_effects.json` from the bundle on every call — once
/// per save via `SpellRepository._refreshResolver`, and once per Library tab
/// visit via `LibraryRepository._refreshResolver`.
///
/// The Future is cached rather than its result, so two concurrent callers share
/// one parse instead of racing into two.
class AssetDataLoader {
  Future<List<BaseEffect>>? _baseEffects;
  Future<List<Parameter>>? _parameters;
  Future<List<Modifier>>? _modifiers;
  Future<List<Spell>>? _spellLibrary;
  Future<List<SpellTemplate>>? _spellTemplates;
  Future<List<Book>>? _books;

  Future<List<BaseEffect>> loadBaseEffects() =>
      _baseEffects ??= _load('assets/data/base_effects.json', BaseEffect.fromMap);

  Future<List<Parameter>> loadParameters() =>
      _parameters ??= _load('assets/data/parameters.json', Parameter.fromMap);

  Future<List<Modifier>> loadModifiers() =>
      _modifiers ??= _load('assets/data/modifiers.json', Modifier.fromMap);

  Future<List<Spell>> loadSpellLibrary() =>
      _spellLibrary ??= _load('assets/data/spell_library.json', Spell.fromMap);

  Future<List<SpellTemplate>> loadSpellTemplates() =>
      _spellTemplates ??=
          _load('assets/data/spell_templates.json', SpellTemplate.fromMap);

  Future<List<Book>> loadBooks() =>
      _books ??= _load('assets/data/books.json', Book.fromMap);

  /// Reads one JSON array asset and maps it through [fromMap].
  ///
  /// Returns an unmodifiable list: the result is shared between every caller,
  /// so one caller mutating it would corrupt the others' view.
  Future<List<T>> _load<T>(
    String path,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    final jsonString = await rootBundle.loadString(path);
    final list = jsonDecode(jsonString) as List<dynamic>;
    return List.unmodifiable(
      list.map((e) => fromMap(e as Map<String, dynamic>)),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: PASS

- [ ] **Step 5: Run the whole suite — the unmodifiable change is the risk**

Run: `flutter test`
Expected: PASS. If anything fails with `UnsupportedError`, a caller is mutating a loaded list in place. Fix the *caller* to copy first (`[...list]`) rather than reverting to a modifiable list — the sharing is the point.

- [ ] **Step 6: Commit**

```bash
git add lib/data/datasources/asset_data_loader.dart test/data/datasources/asset_data_loader_test.dart
git commit -m "perf: memoise AssetDataLoader parses

Assets are immutable at runtime, so each parse is cached with no
invalidation story. Removes a re-parse of all 611 base effects from every
ConfigurationRepository.getAllEffects call, which happens once per Library
tab visit today and will happen once per save once SpellRepository starts
refreshing before validating.

Also folds six near-identical loaders onto one generic _load helper."
```

---

### Task 2: `SpellResolver` carries modifiers

**Files:**
- Modify: `lib/data/spell_resolver.dart`
- Modify: `lib/models/resolved_spell.dart`
- Modify: `lib/main.dart`
- Test: `test/data/spell_resolver_test.dart`

**Interfaces:**
- Consumes: `AssetDataLoader.loadModifiers()` from Task 1.
- Produces:
  - `SpellResolver({required List<BaseEffect> effects, required List<Parameter> parameters, required List<Modifier> modifiers})`
  - `SpellResolver.updateCatalogs({required List<BaseEffect> effects, required List<Parameter> parameters, required List<Modifier> modifiers})`
  - `ResolvedSpell.modifiers` — `List<Modifier>`, defaulting to `const []`, holding the modifiers that `record.selectedModifiers.keys` resolve to.

- [ ] **Step 1: Write the failing test**

Add to `test/data/spell_resolver_test.dart`:

```dart
  test('resolve populates the modifiers the spell actually selects', () {
    final sizeTerram = Modifier(
      id: 'size-terram',
      name: 'Size (Terram)',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(form: 'Terram'),
      options: [ModifierOption(id: 'size-terram-0', label: 'Base', magnitude: 0)],
      provenance: Provenance(source: PublicationSource.published, citations: []),
    );
    final unrelated = Modifier(
      id: 'size-aquam',
      name: 'Size (Aquam)',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(form: 'Aquam'),
      options: [ModifierOption(id: 'size-aquam-0', label: 'Base', magnitude: 0)],
      provenance: Provenance(source: PublicationSource.published, citations: []),
    );

    final resolver = SpellResolver(
      effects: [testEffect],
      parameters: [testRange, testDuration, testTarget],
      modifiers: [sizeTerram, unrelated],
    );

    final resolved = resolver.resolve(
      buildSpell(selectedModifiers: {'size-terram': ['size-terram-0']}),
    );

    expect(resolved.modifiers.map((m) => m.id), ['size-terram']);
  });

  test('an unknown modifier id is skipped, not surfaced as null', () {
    final resolver = SpellResolver(
      effects: [testEffect],
      parameters: [testRange, testDuration, testTarget],
      modifiers: const [],
    );

    final resolved = resolver.resolve(
      buildSpell(selectedModifiers: {'no-such-modifier': ['x']}),
    );

    // Tolerated deliberately: calculateBreakdown treats an unresolvable
    // modifier id as contributing 0, and this work does not tighten that.
    expect(resolved.modifiers, isEmpty);
  });
```

`test/data/spell_resolver_test.dart` already has effect/parameter fixtures — reuse them under whatever names it uses, and extend its spell-building helper to accept `selectedModifiers`:

```dart
  Spell buildSpell({Map<String, List<String>> selectedModifiers = const {}}) => Spell(
        id: 'test-spell',
        baseEffectId: testEffect.id,
        rangeId: testRange.id,
        durationId: testDuration.id,
        targetId: testTarget.id,
        selectedModifiers: selectedModifiers,
        requisites: const [],
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
```

Imports needed: `package:eruditus/models/modifier.dart`, `package:eruditus/models/provenance.dart`, `package:eruditus/models/publication_source.dart`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/spell_resolver_test.dart`
Expected: FAIL — `SpellResolver` has no `modifiers` parameter, `ResolvedSpell` has no `modifiers` getter.

- [ ] **Step 3: Add modifiers to `SpellResolver`**

In `lib/data/spell_resolver.dart`, add the import `package:eruditus/models/modifier.dart`, then:

```dart
  Map<String, BaseEffect> _effectsById;
  Map<String, Parameter> _parametersById;
  Map<String, Modifier> _modifiersById;

  SpellResolver({
    required List<BaseEffect> effects,
    required List<Parameter> parameters,
    required List<Modifier> modifiers,
  })  : _effectsById = {for (final e in effects) e.id: e},
        _parametersById = {for (final p in parameters) p.id: p},
        _modifiersById = {for (final m in modifiers) m.id: m};
```

Extend `updateCatalogs` the same way:

```dart
  void updateCatalogs({
    required List<BaseEffect> effects,
    required List<Parameter> parameters,
    required List<Modifier> modifiers,
  }) {
    _effectsById = {for (final e in effects) e.id: e};
    _parametersById = {for (final p in parameters) p.id: p};
    _modifiersById = {for (final m in modifiers) m.id: m};
  }
```

And populate the new field in `resolve`:

```dart
  ResolvedSpell resolve(Spell record) => ResolvedSpell(
        record: record,
        baseEffect: _effectsById[record.baseEffectId],
        range: _parametersById[record.rangeId],
        duration: _parametersById[record.durationId],
        target: _parametersById[record.targetId],
        modifiers: _selectedModifiers(record.selectedModifiers),
      );

  /// The catalog entries [selected]'s keys refer to, skipping ids that no
  /// longer resolve — `calculateBreakdown` already treats an unresolvable
  /// modifier id as contributing 0, and this preserves that.
  List<Modifier> _selectedModifiers(Map<String, List<String>> selected) => [
        for (final id in selected.keys)
          if (_modifiersById[id] case final modifier?) modifier,
      ];
```

`resolveTemplate` is deliberately left alone — `ResolvedTemplate` gains nothing here, because only `ResolvedSpell` grows a `problems` getter.

- [ ] **Step 4: Add the field to `ResolvedSpell`**

In `lib/models/resolved_spell.dart`, add the import `package:eruditus/models/modifier.dart` and the field:

```dart
  /// The catalog entries [Spell.selectedModifiers]' keys resolve to.
  ///
  /// Defaults to empty because the only direct constructions of this class
  /// outside [SpellResolver] are test fixtures, where "no modifiers" is
  /// accurate rather than a bypass. The production path is
  /// [SpellResolver.resolve], which always populates it.
  final List<Modifier> modifiers;
```

and add `this.modifiers = const [],` to the constructor.

- [ ] **Step 5: Update `main.dart`**

`lib/main.dart:44` — the resolver is built before any modifier list exists, so load one:

```dart
  final resolver = SpellResolver(
    effects: await configRepository.getAllEffects(),
    parameters: await configRepository.getAllParameters(),
    modifiers: await configRepository.getAllModifiers(),
  );
```

- [ ] **Step 6: Update `LibraryRepository._refreshResolver`**

`lib/data/repositories/library_repository.dart:39-47` — pass modifiers through:

```dart
    resolver.updateCatalogs(
      effects: await configRepository.getAllEffects(),
      parameters: await configRepository.getAllParameters(),
      modifiers: await configRepository.getAllModifiers(),
    );
```

- [ ] **Step 7: Fix the remaining construction sites**

Run: `flutter test`
Expected: compile errors at every `SpellResolver(...)` missing `modifiers`. There are ~18 sites across these files:

```
test/bloc/spell_creation_bloc_test.dart
test/bloc/spell_library_bloc_test.dart
test/data/spell_resolver_test.dart
test/data/repositories/library_repository_test.dart
test/data/repositories/spell_repository_test.dart
test/data/services/backup_service_test.dart
test/presentation/screens/backup_screen_test.dart
integration_test/spell_creation_flow_test.dart
```

Add `modifiers: const []` to each, except where the test is about modifiers (then pass the real list). `modifiers` is required rather than defaulted precisely so this sweep happens once and no production path can silently omit it.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/data/spell_resolver.dart lib/models/resolved_spell.dart lib/main.dart lib/data/repositories/library_repository.dart test integration_test
git commit -m "feat: SpellResolver carries modifiers

ResolvedSpell needs the modifiers its selectedModifiers keys refer to in
order to check selectionMode, which lives in the catalog rather than on the
record. Mirrors how the resolver already carries effect/range/duration/target.

modifiers is required on SpellResolver so no production path can omit it, and
defaulted on ResolvedSpell because its only direct constructions are fixtures."
```

---

### Task 3: The shared validator

**Files:**
- Modify: `lib/models/spell.dart`
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Consumes: `BaseEffect.isGeneral`, `BaseEffect.technique`, `BaseEffect.form`, `Modifier.selectionMode`, `Modifier.name`, `Requisite.art`.
- Produces:

```dart
List<String> validateSpellAgainstCatalog({
  required BaseEffect effect,
  required int? chosenBaseLevel,
  required List<Requisite> requisites,
  required Map<String, List<String>> selectedModifiers,
  required List<Modifier> modifiers,
  bool isTemplate = false,
});
```

Returns a list of human-readable problems; empty means valid.

- [ ] **Step 1: Write the failing tests**

Add to `test/models/spell_test.dart`. These fixtures assume helpers named `generalEffect()` and `fixedEffect()`; write them in the file if absent, following its existing fixture style.

```dart
  group('validateSpellAgainstCatalog', () {
    BaseEffect fixedEffect() => BaseEffect(
          id: 'crig-10a', technique: 'Creo', form: 'Ignem',
          description: 'A fire doing +10 damage', baseLevel: 10,
          provenance: Provenance(source: PublicationSource.published, citations: []),
        );

    BaseEffect generalEffect() => BaseEffect(
          id: 'revi-G1', technique: 'Rego', form: 'Vim',
          description: 'Ward against beings of one realm', baseLevel: null,
          provenance: Provenance(source: PublicationSource.published, citations: []),
        );

    Modifier singleChoice() => Modifier(
          id: 'size-ignem', name: 'Size (Ignem)',
          selectionMode: ModifierSelectionMode.single,
          scope: const ModifierScope(form: 'Ignem'),
          options: [
            ModifierOption(id: 'a', label: 'A', magnitude: 0),
            ModifierOption(id: 'b', label: 'B', magnitude: 1),
          ],
          provenance: Provenance(source: PublicationSource.published, citations: []),
        );

    List<String> validate({
      required BaseEffect effect,
      int? chosenBaseLevel,
      List<Requisite> requisites = const [],
      Map<String, List<String>> selectedModifiers = const {},
      List<Modifier> modifiers = const [],
      bool isTemplate = false,
    }) =>
        validateSpellAgainstCatalog(
          effect: effect,
          chosenBaseLevel: chosenBaseLevel,
          requisites: requisites,
          selectedModifiers: selectedModifiers,
          modifiers: modifiers,
          isTemplate: isTemplate,
        );

    test('a valid fixed-level spell has no problems', () {
      expect(validate(effect: fixedEffect()), isEmpty);
    });

    test('check 1: a General guideline with no chosen level is a problem', () {
      expect(validate(effect: generalEffect()),
          contains('Choose a level for this General guideline'));
    });

    test('check 1: a General guideline with a level below 1 is a problem', () {
      expect(validate(effect: generalEffect(), chosenBaseLevel: 0),
          contains('The chosen level must be at least 1'));
    });

    test('check 1: a General guideline with a valid level is fine', () {
      expect(validate(effect: generalEffect(), chosenBaseLevel: 20), isEmpty);
    });

    test('check 2: a chosen level on a non-General guideline is a problem', () {
      expect(validate(effect: fixedEffect(), chosenBaseLevel: 20),
          contains('A chosen base level applies only to a General guideline'));
    });

    test('check 3: a requisite equal to the spell own Technique is a problem', () {
      expect(
        validate(
          effect: fixedEffect(),
          requisites: [Requisite(art: 'Creo', kind: RequisiteKind.free)],
        ),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('check 3: a requisite equal to the spell own Form is a problem', () {
      expect(
        validate(
          effect: fixedEffect(),
          requisites: [Requisite(art: 'Ignem', kind: RequisiteKind.free)],
        ),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('check 4: a duplicate requisite art is a problem', () {
      expect(
        validate(
          effect: fixedEffect(),
          requisites: [
            Requisite(art: 'Rego', kind: RequisiteKind.free),
            Requisite(art: 'Rego', kind: RequisiteKind.adding),
          ],
        ),
        contains('Duplicate requisite art: Rego'),
      );
    });

    test('check 5: two options on a single-selection modifier is a problem', () {
      expect(
        validate(
          effect: fixedEffect(),
          selectedModifiers: {'size-ignem': ['a', 'b']},
          modifiers: [singleChoice()],
        ),
        contains('Only one option may be selected for Size (Ignem)'),
      );
    });

    test('check 5: one option on a single-selection modifier is fine', () {
      expect(
        validate(
          effect: fixedEffect(),
          selectedModifiers: {'size-ignem': ['a']},
          modifiers: [singleChoice()],
        ),
        isEmpty,
      );
    });

    test('an unknown modifier id is tolerated, matching calculateBreakdown', () {
      expect(
        validate(
          effect: fixedEffect(),
          selectedModifiers: {'no-such-modifier': ['a', 'b']},
          modifiers: [singleChoice()],
        ),
        isEmpty,
      );
    });

    test('isTemplate skips checks 1 and 2, which cannot apply to a template', () {
      // A General template legitimately has no chosen level -- supplying one is
      // what instantiating it means.
      expect(validate(effect: generalEffect(), isTemplate: true), isEmpty);
    });

    test('isTemplate still runs checks 3, 4 and 5', () {
      expect(
        validate(
          effect: fixedEffect(),
          requisites: [Requisite(art: 'Creo', kind: RequisiteKind.free)],
          isTemplate: true,
        ),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('problems accumulate rather than short-circuiting', () {
      final problems = validate(
        effect: generalEffect(),
        requisites: [
          Requisite(art: 'Rego', kind: RequisiteKind.free),
          Requisite(art: 'Rego', kind: RequisiteKind.adding),
        ],
      );
      expect(problems.length, 2);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — `validateSpellAgainstCatalog` is not defined.

- [ ] **Step 3: Implement the validator**

Add to `lib/models/spell.dart`, directly below `validateSpellProse`. Add imports for `modifier.dart`; `base_effect.dart` and `requisite.dart` are already imported.

```dart
/// The catalog-dependent invariants every spell must satisfy, stated once and
/// shared by every path that can produce or hold one — the same contract
/// [validateSpellProse] provides for prose.
///
/// Returns a list of human-readable problems; empty means valid. Problems
/// accumulate: a caller showing them to a user should see all of them at once.
///
/// **Why this is a free function taking pieces rather than a method on [Spell].**
/// [Spell] deliberately holds `baseEffectId` and not [BaseEffect], so it cannot
/// see `isGeneral`, the effect's technique/form, or a modifier's
/// `selectionMode`. Three of these five checks are therefore uncheckable from
/// inside the record. Taking the pieces (rather than a `ResolvedSpell`) is what
/// lets [SpellDraft] — which holds a bare `BaseEffect?`, never a resolved
/// wrapper — call the identical function, and avoids a circular import, since
/// `resolved_spell.dart` imports this file.
///
/// [isTemplate] skips checks 1 and 2. A `SpellTemplate` built on a General
/// guideline legitimately has no chosen level; supplying one is precisely what
/// instantiating the template means.
List<String> validateSpellAgainstCatalog({
  required BaseEffect effect,
  required int? chosenBaseLevel,
  required List<Requisite> requisites,
  required Map<String, List<String>> selectedModifiers,
  required List<Modifier> modifiers,
  bool isTemplate = false,
}) {
  final problems = <String>[];

  if (!isTemplate) {
    // 1. A General guideline's level comes from the caster, so it must be
    //    present and usable. Absent it, calculateBreakdown throws.
    if (effect.isGeneral) {
      if (chosenBaseLevel == null) {
        problems.add('Choose a level for this General guideline');
      } else if (chosenBaseLevel < 1) {
        problems.add('The chosen level must be at least 1');
      }
    } else if (chosenBaseLevel != null) {
      // 2. The converse. calculateBreakdown ignores a chosen level on a
      //    fixed-level guideline, so a stray one is silently meaningless
      //    stored data rather than a visible error.
      problems.add('A chosen base level applies only to a General guideline');
    }
  }

  // 3 and 4. A requisite naming the spell's own Art is meaningless, and the
  //    same Art twice is contradictory when the two carry different kinds.
  final seenArts = <String>{};
  for (final requisite in requisites) {
    if (requisite.art == effect.technique || requisite.art == effect.form) {
      problems.add("Requisite art cannot be the spell's own technique or form");
    }
    if (!seenArts.add(requisite.art)) {
      problems.add('Duplicate requisite art: ${requisite.art}');
    }
  }

  // 5. selectionMode lives on the catalog entry, not on the record, which is
  //    why this cannot be checked without the modifier list. An id that does
  //    not resolve is tolerated, matching calculateBreakdown's treatment of
  //    an unresolvable modifier as contributing 0.
  final modifiersById = {for (final modifier in modifiers) modifier.id: modifier};
  selectedModifiers.forEach((modifierId, optionIds) {
    final modifier = modifiersById[modifierId];
    if (modifier == null) return;
    if (modifier.selectionMode == ModifierSelectionMode.single &&
        optionIds.length > 1) {
      problems.add('Only one option may be selected for ${modifier.name}');
    }
  });

  return problems;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/spell_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/spell.dart test/models/spell_test.dart
git commit -m "feat: add validateSpellAgainstCatalog

The catalog-dependent spell invariants, stated once as a free function beside
validateSpellProse. Takes the record's pieces rather than a ResolvedSpell so
that SpellDraft can call the identical function and so resolved_spell.dart's
import of this file stays acyclic.

Adds one check the codebase did not have: a chosen base level on a
non-General guideline, which calculateBreakdown silently ignores today."
```

---

### Task 4: `ResolvedSpell.problems`

**Files:**
- Modify: `lib/models/resolved_spell.dart`
- Test: `test/models/resolved_spell_test.dart` (create if absent)

**Interfaces:**
- Consumes: `validateSpellAgainstCatalog` (Task 3), `ResolvedSpell.modifiers` (Task 2).
- Produces: `ResolvedSpell.problems` — `List<String>`, empty when the spell is valid or when `baseEffect` is null.

- [ ] **Step 1: Write the failing test**

```dart
  test('problems is empty for a valid spell', () {
    final resolved = ResolvedSpell(
      record: buildSpell(),
      baseEffect: fixedEffect(),
      range: testRange, duration: testDuration, target: testTarget,
    );
    expect(resolved.problems, isEmpty);
  });

  test('problems reports a General spell with no chosen level', () {
    final resolved = ResolvedSpell(
      record: buildSpell(baseEffectId: 'revi-G1'),
      baseEffect: generalEffect(),
      range: testRange, duration: testDuration, target: testTarget,
    );
    expect(resolved.problems, contains('Choose a level for this General guideline'));
  });

  test('problems is empty when the base effect does not resolve', () {
    // Nothing to validate against. isResolved already reports this, and it
    // answers a different question -- see the class doc.
    final resolved = ResolvedSpell(
      record: buildSpell(),
      baseEffect: null,
      range: testRange, duration: testDuration, target: testTarget,
    );
    expect(resolved.isResolved, isFalse);
    expect(resolved.problems, isEmpty);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/resolved_spell_test.dart`
Expected: FAIL — `problems` is not defined.

- [ ] **Step 3: Implement the getter**

Add to `lib/models/resolved_spell.dart`:

```dart
  /// The catalog-dependent invariants this spell breaks. Empty means none.
  ///
  /// **A sibling of [isResolved], not a replacement for it — the two answer
  /// different questions.** [isResolved] is a *can I compute* gate: the four
  /// catalog ids are null, so `calculateBreakdown` cannot run at all
  /// (`spell_library_bloc.dart` relies on exactly this). [problems] means the
  /// level computes fine but must not be trusted, because the record and its
  /// guideline disagree.
  ///
  /// Empty when [baseEffect] is null: there is nothing to validate against, and
  /// [isResolved] already reports that case.
  ///
  /// Whether these two notions should collapse into one is todo item 38's
  /// question, alongside the `ResolvedSpell`/`ResolvedTemplate` duplication.
  /// Do not merge them without preserving the compute gate.
  List<String> get problems {
    final effect = baseEffect;
    if (effect == null) return const [];
    return validateSpellAgainstCatalog(
      effect: effect,
      chosenBaseLevel: record.chosenBaseLevel,
      requisites: record.requisites,
      selectedModifiers: record.selectedModifiers,
      modifiers: modifiers,
    );
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/resolved_spell_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/resolved_spell.dart test/models/resolved_spell_test.dart
git commit -m "feat: ResolvedSpell.problems

The read side of invariant enforcement. A stored spell can become invalid
without anyone rewriting it -- change a custom modifier's selectionMode from
multi to single and every spell holding two options on it breaks -- so
write-time blocking alone cannot cover this.

Documented as a deliberate sibling of isResolved rather than a third
accidental notion; the two answer different questions."
```

---

### Task 5: `validateSpellDraft` delegates to the validator

**Files:**
- Modify: `lib/engine/spell_engine.dart:52-105`
- Test: `test/engine/spell_engine_test.dart`

**Interfaces:**
- Consumes: `validateSpellAgainstCatalog` (Task 3).
- Produces: no signature change. `SpellEngine.validateSpellDraft(SpellDraft)` still returns `List<String>`.

This is a behaviour-preserving refactor **plus** one new check reaching the draft path (check 2). Existing error strings must not change.

- [ ] **Step 1: Write the failing test**

Add to `test/engine/spell_engine_test.dart`:

```dart
    test('a chosen level on a non-General effect is rejected', () {
      final draft = completeDraft(
        baseEffect: fixedGuideline(),
        chosenBaseLevel: 20,
      );
      expect(
        engine.validateSpellDraft(draft),
        contains('A chosen base level applies only to a General guideline'),
      );
    });
```

`spell_engine_test.dart` defines `wardGuideline()` (General) at `:725` and `:803` but has no fixed-level fixture in the `validateSpellDraft` group. Add one beside the `:803` definition, matching its style:

```dart
    BaseEffect fixedGuideline() => BaseEffect(
          id: 'crig-10a',
          technique: 'Creo',
          form: 'Ignem',
          description: 'A fire doing +10 damage',
          baseLevel: 10,
          provenance: Provenance(source: PublicationSource.published, citations: []),
        );
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — no such message is produced.

- [ ] **Step 3: Replace the inline checks with a delegation**

In `lib/engine/spell_engine.dart`, delete the General block at `:67-73`, the requisite loop at `:88-97`, and the `selectedModifiers.forEach` at `:99-105`. In their place, after the null-checks for technique/form/baseEffect/range/duration/target, add:

```dart
    // The catalog-dependent invariants live in one place, shared with
    // SpellRepository's write-time block and ResolvedSpell.problems, so the
    // draft path and the record path cannot drift.
    if (draft.baseEffect != null) {
      errors.addAll(validateSpellAgainstCatalog(
        effect: draft.baseEffect!,
        chosenBaseLevel: draft.chosenBaseLevel,
        requisites: draft.requisites,
        selectedModifiers: draft.selectedModifiers,
        modifiers: allModifiers,
      ));
    }
```

Add the import for `validateSpellAgainstCatalog` if `spell.dart` is not already imported (it is — `SpellDraft` comes from there).

Keep the trailing `if (errors.isEmpty) { try { calculateBreakdown(...) } ... }` block exactly as it is.

- [ ] **Step 4: Run the engine tests**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: PASS, including the pre-existing tests that assert the old message strings verbatim.

- [ ] **Step 5: Run the whole suite — check 2 is newly reachable**

Run: `flutter test`
Expected: PASS. If a bloc or widget test fails with `'A chosen base level applies only to a General guideline'`, it is building a draft that sets `chosenBaseLevel` alongside a fixed-level effect. That is the bug this check exists to catch: fix the fixture, do not weaken the check.

- [ ] **Step 6: Commit**

```bash
git add lib/engine/spell_engine.dart test/engine/spell_engine_test.dart
git commit -m "refactor: validateSpellDraft delegates to validateSpellAgainstCatalog

Removes three inline checks that existed only on the creation-screen path.
The draft path and the record path now share one implementation, which is the
point of the exercise -- and the draft path gains check 2 for free."
```

---

### Task 6: `SpellRepository` blocks invalid writes

**Files:**
- Create: `lib/models/invalid_spell_exception.dart`
- Modify: `lib/data/repositories/spell_repository.dart`
- Modify: `lib/main.dart`
- Test: `test/data/repositories/spell_repository_test.dart`

**Interfaces:**
- Consumes: `validateSpellAgainstCatalog` (Task 3), `SpellResolver` with modifiers (Task 2), memoised `AssetDataLoader` (Task 1).
- Produces:
  - `InvalidSpellException(String spellId, List<String> problems)` with a `message` getter and `toString()` override.
  - `SpellRepository({required LocalSpellDatasource datasource, required SpellResolver resolver, required ConfigurationRepository configRepository})`
  - `saveSpell(Spell)` / `updateSpell(Spell)` — unchanged signatures, now throwing `InvalidSpellException`.

- [ ] **Step 1: Write the failing tests**

```dart
  test('saveSpell rejects a General spell with no chosen level', () async {
    final spell = buildSpell('bad-1', baseEffectId: 'revi-G1');  // a real General id

    expect(
      () => repository.saveSpell(spell),
      throwsA(isA<InvalidSpellException>().having(
        (e) => e.problems, 'problems',
        contains('Choose a level for this General guideline'),
      )),
    );
  });

  test('a rejected spell is not written', () async {
    final spell = buildSpell('bad-2', baseEffectId: 'revi-G1');

    try {
      await repository.saveSpell(spell);
    } on InvalidSpellException {
      // expected
    }

    expect(await repository.getSpellById('bad-2'), isNull);
  });

  test('saveSpell accepts a valid spell', () async {
    await repository.saveSpell(buildSpell('good-1'));
    expect(await repository.getSpellById('good-1'), isNotNull);
  });

  test('updateSpell rejects an invalid spell too', () async {
    await repository.saveSpell(buildSpell('good-2'));

    expect(
      () => repository.updateSpell(
        buildSpell('good-2', baseEffectId: 'revi-G1'),
      ),
      throwsA(isA<InvalidSpellException>()),
    );
  });

  test('a spell built on a just-added custom effect saves without a Library visit', () async {
    // The staleness case: SpellRepository refreshes for itself rather than
    // waiting for LibraryRepository to do it on a Library tab visit.
    await configRepository.addCustomEffect(customEffect('custom-1'));

    await repository.saveSpell(buildSpell('good-3', baseEffectId: 'custom-1'));

    expect(await repository.getSpellById('good-3'), isNotNull);
  });
```

Three supporting changes to the file:

1. `setUp` must build a `ConfigurationRepository` and pass it to `SpellRepository`. Keep a `late ConfigurationRepository configRepository;` alongside the existing `late SpellRepository repository;`.

```dart
    final assetLoader = AssetDataLoader();
    configRepository = ConfigurationRepository(
      assetLoader: assetLoader,
      configDatasource: LocalConfigurationDatasource(database: database),
    );
    final resolver = SpellResolver(
      effects: await configRepository.getAllEffects(),
      parameters: await configRepository.getAllParameters(),
      modifiers: await configRepository.getAllModifiers(),
    );
    repository = SpellRepository(
      datasource: LocalSpellDatasource(database: database),
      resolver: resolver,
      configRepository: configRepository,
    );
```

2. The existing `buildSpell(String id, {String? name})` needs a `baseEffectId` parameter, defaulting to a real fixed-level id:

```dart
  Spell buildSpell(String id, {String? name, String baseEffectId = 'crig-10a'}) => Spell(
        id: id,
        name: name,
        baseEffectId: baseEffectId,
        rangeId: 'range-touch',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
```

Keep the rest of the existing body if it differs — the point is the new parameter, not a rewrite.

3. A `customEffect` fixture:

```dart
  BaseEffect customEffect(String id) => BaseEffect(
        id: id,
        technique: 'Creo',
        form: 'Ignem',
        description: 'A custom effect',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
      );
```

`revi-G1` is a real General guideline in `base_effects.json` (Rego Vim), and `crig-10a` a real fixed-level one — both resolve against the catalog the test's resolver is built from, so these tests exercise real data rather than fixtures.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/repositories/spell_repository_test.dart`
Expected: FAIL — `InvalidSpellException` undefined; `SpellRepository` takes no `configRepository`.

- [ ] **Step 3: Create the exception**

`lib/models/invalid_spell_exception.dart`:

```dart
/// Thrown when a write is refused because the spell breaks a catalog-dependent
/// invariant — see `validateSpellAgainstCatalog`.
///
/// Blocking rather than degrading is a deliberate decision (spec decision 1),
/// flagged as revisitable: a spell that becomes invalid *after* it was written
/// is degraded instead, via `ResolvedSpell.problems`, because there is no write
/// to refuse in that case.
class InvalidSpellException implements Exception {
  final String spellId;
  final List<String> problems;

  InvalidSpellException(this.spellId, this.problems);

  String get message => 'Spell $spellId is invalid: ${problems.join('; ')}';

  @override
  String toString() => 'InvalidSpellException: $message';
}
```

- [ ] **Step 4: Implement the blocking repository**

Replace `lib/data/repositories/spell_repository.dart` with:

```dart
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/invalid_spell_exception.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

class SpellRepository {
  final LocalSpellDatasource datasource;
  final SpellResolver resolver;
  final ConfigurationRepository configRepository;

  SpellRepository({
    required this.datasource,
    required this.resolver,
    required this.configRepository,
  });

  // Writes take the record; reads return it joined to the catalogs.

  /// Writes [spell], refusing an invalid one.
  ///
  /// Throws [InvalidSpellException] rather than writing a record that breaks a
  /// catalog-dependent invariant. See [saveAll] for the batch path, which
  /// reports instead of throwing — it is not a bypass, it runs the same check.
  Future<void> saveSpell(Spell spell) async {
    await _assertValid(spell, refresh: true);
    await datasource.insertSpell(spell);
  }

  Future<void> updateSpell(Spell spell) async {
    await _assertValid(spell, refresh: true);
    await datasource.updateSpell(spell);
  }

  Future<void> deleteSpell(String id) => datasource.deleteSpell(id);

  /// Writes every valid spell in [spells] and returns the ones it refused.
  ///
  /// Refreshes the catalog **once** for the whole batch: nothing caches the
  /// database half of the catalog, so refreshing per spell would re-read it
  /// once per row. Same validator as [saveSpell], different failure mode —
  /// a backup should not lose good rows to one bad one.
  Future<List<InvalidSpellException>> saveAll(Iterable<Spell> spells) async {
    await _refreshResolver();

    final rejected = <InvalidSpellException>[];
    for (final spell in spells) {
      final problems = _problemsFor(spell);
      if (problems.isNotEmpty) {
        rejected.add(InvalidSpellException(spell.id, problems));
        continue;
      }
      final existing = await datasource.getSpellById(spell.id);
      if (existing == null) {
        await datasource.insertSpell(spell);
      } else {
        await datasource.updateSpell(spell);
      }
    }
    return rejected;
  }

  Future<ResolvedSpell?> getSpellById(String id) async {
    final record = await datasource.getSpellById(id);
    return record == null ? null : resolver.resolve(record);
  }

  Future<List<ResolvedSpell>> getAllUserSpells() async =>
      resolver.resolveAll(await datasource.getAllSpells());

  Future<void> _assertValid(Spell spell, {required bool refresh}) async {
    if (refresh) await _refreshResolver();
    final problems = _problemsFor(spell);
    if (problems.isNotEmpty) {
      throw InvalidSpellException(spell.id, problems);
    }
  }

  /// The record's problems, or empty when its base effect does not resolve.
  ///
  /// An unresolvable base effect is *not* a write-time error: it is what
  /// `ResolvedSpell.isResolved` already reports, and refusing the write would
  /// mean a user who deleted a custom effect could no longer save edits to the
  /// spells built on it.
  List<String> _problemsFor(Spell spell) => resolver.resolve(spell).problems;

  /// Brings the shared resolver up to date before validating against it.
  ///
  /// Mirrors `LibraryRepository._refreshResolver`, and reaches the same object:
  /// one `SpellResolver` instance is shared by both repositories (`main.dart`).
  /// Without this, a spell built on a custom effect added since the last
  /// Library tab visit would be refused for referring to an effect the
  /// resolver has not heard of.
  Future<void> _refreshResolver() async {
    resolver.updateCatalogs(
      effects: await configRepository.getAllEffects(),
      parameters: await configRepository.getAllParameters(),
      modifiers: await configRepository.getAllModifiers(),
    );
  }
}
```

- [ ] **Step 5: Wire `main.dart`**

`lib/main.dart:48` becomes:

```dart
  final spellRepository = SpellRepository(
    datasource: LocalSpellDatasource(database: database),
    resolver: resolver,
    configRepository: configRepository,
  );
```

- [ ] **Step 6: Fix the remaining construction sites**

Run: `flutter test`
Expected: compile errors at every `SpellRepository(...)`. There are 19 sites across these files:

```
test/bloc/spell_creation_bloc_test.dart
test/bloc/spell_library_bloc_test.dart
test/data/repositories/library_repository_test.dart
test/data/repositories/spell_repository_test.dart
test/data/services/backup_service_test.dart
test/presentation/screens/backup_screen_test.dart
test/widget_test.dart
integration_test/spell_creation_flow_test.dart
```

Each needs a `ConfigurationRepository(assetLoader: ..., configDatasource: LocalConfigurationDatasource(database: database))`. Several files already build one — reuse it rather than constructing a second.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test`
Expected: PASS

- [ ] **Step 8: Run the integration suite**

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: 3 pass, 2 fail — the same two `dragUntilVisible` failures todo item 6 records as pre-existing. Any *other* failure is a regression from this task.

- [ ] **Step 9: Commit**

```bash
git add lib/models/invalid_spell_exception.dart lib/data/repositories/spell_repository.dart lib/main.dart test integration_test
git commit -m "feat: SpellRepository refuses invalid writes

saveSpell and updateSpell now refresh the shared resolver, validate against
it, and throw InvalidSpellException rather than writing a record that breaks
a catalog invariant. saveAll is the batch path: same validator, reports
instead of throwing, and refreshes once for the whole batch.

SpellRepository gains a ConfigurationRepository so it can refresh for itself
instead of waiting for a Library tab visit to do it."
```

---

### Task 7: Backup restore reorders and reports

**Files:**
- Modify: `lib/data/services/backup_service.dart`
- Modify: `lib/presentation/screens/backup_screen.dart:39-41`
- Test: `test/data/services/backup_service_test.dart`

**Interfaces:**
- Consumes: `SpellRepository.saveAll` (Task 6).
- Produces: `BackupImportResult` gains `final List<InvalidSpellException> rejectedSpells;` and a `spellsRejected` count getter.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a spell built on a custom effect from the same backup imports', () async {
    // Regression: spells were written before the custom effects they depend
    // on, so this spell used to be validated against a catalog missing its
    // own effect.
    final json = jsonEncode({
      'version': '2.0',
      'exportDate': DateTime.now().toIso8601String(),
      'spells': [spellOnCustomEffect('s1', 'custom-1').toMap()],
      'customEffects': [customEffect('custom-1').toMap()],
      'customParameters': <Map<String, dynamic>>[],
    });

    final result = await service.importFromJson(json);

    expect(result.spellsImported, 1);
    expect(result.rejectedSpells, isEmpty);
  });

  test('an invalid spell is skipped and reported, and the good ones still land', () async {
    final json = jsonEncode({
      'version': '2.0',
      'exportDate': DateTime.now().toIso8601String(),
      'spells': [
        validSpell('good-1').toMap(),
        generalSpellWithNoChosenLevel('bad-1').toMap(),
        validSpell('good-2').toMap(),
      ],
      'customEffects': <Map<String, dynamic>>[],
      'customParameters': <Map<String, dynamic>>[],
    });

    final result = await service.importFromJson(json);

    expect(result.spellsImported, 2);
    expect(result.rejectedSpells.map((e) => e.spellId), ['bad-1']);
    expect(await spellRepository.getSpellById('good-2'), isNotNull);
  });

  test('round-trip through the real service preserves a valid spell', () async {
    // Closes todo item 7's coverage hole: the old round-trip test duplicated
    // spell_test.dart's serialization test and never called the service.
    await spellRepository.saveSpell(validSpell('rt-1'));

    final exported = await service.exportToJson();
    await spellRepository.deleteSpell('rt-1');
    final result = await service.importFromJson(exported);

    expect(result.spellsImported, 1);
    expect(await spellRepository.getSpellById('rt-1'), isNotNull);
  });
```

These four fixtures must be defined in the file. `crig-10a` and `revi-G1` are real catalog ids, so the spells resolve against real data:

```dart
  Spell _spell(String id, {required String baseEffectId, int? chosenBaseLevel}) => Spell(
        id: id,
        name: id,
        baseEffectId: baseEffectId,
        rangeId: 'range-touch',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        chosenBaseLevel: chosenBaseLevel,
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Spell validSpell(String id) => _spell(id, baseEffectId: 'crig-10a');

  /// Invalid: a General guideline with no level supplied (check 1).
  Spell generalSpellWithNoChosenLevel(String id) =>
      _spell(id, baseEffectId: 'revi-G1');

  Spell spellOnCustomEffect(String id, String effectId) =>
      _spell(id, baseEffectId: effectId);

  BaseEffect customEffect(String id) => BaseEffect(
        id: id,
        technique: 'Creo',
        form: 'Ignem',
        description: 'A custom effect',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated, citations: const []),
      );
```

The test file's `setUp` also needs the `SpellRepository` and `ConfigurationRepository` held as fields, since the tests reach for both — same shape as Task 6's step 1.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/services/backup_service_test.dart`
Expected: FAIL — `rejectedSpells` is not defined, and the custom-effect test fails on the ordering.

- [ ] **Step 3: Extend the result type**

In `lib/data/services/backup_service.dart`:

```dart
class BackupImportResult {
  final int spellsImported;
  final int effectsImported;
  final int parametersImported;

  /// Spells the import refused, each carrying its own reasons. A backup should
  /// not lose good rows to one bad one, so these are skipped and reported
  /// rather than aborting the import.
  final List<InvalidSpellException> rejectedSpells;

  BackupImportResult({
    required this.spellsImported,
    required this.effectsImported,
    required this.parametersImported,
    this.rejectedSpells = const [],
  });

  int get spellsRejected => rejectedSpells.length;
}
```

- [ ] **Step 4: Reorder the import and use `saveAll`**

Replace the body of `importFromJson` after the version check with:

```dart
    // Custom effects and parameters first: a spell in this backup may be built
    // on one of them, and validating that spell against a catalog that does not
    // yet contain its own effect would refuse it wrongly.
    var effectsImported = 0;
    for (final effectMap in (data['customEffects'] as List? ?? const [])) {
      final effect = BaseEffect.fromMap(effectMap as Map<String, dynamic>);
      await configRepository.deleteCustomEffect(effect.id);
      await configRepository.addCustomEffect(effect);
      effectsImported++;
    }

    var parametersImported = 0;
    for (final parameterMap in (data['customParameters'] as List? ?? const [])) {
      final parameter = Parameter.fromMap(parameterMap as Map<String, dynamic>);
      await configRepository.deleteCustomParameter(parameter.id);
      await configRepository.addCustomParameter(parameter);
      parametersImported++;
    }

    final spells = [
      for (final spellMap in (data['spells'] as List? ?? const []))
        Spell.fromMap(spellMap as Map<String, dynamic>),
    ];
    final rejected = await spellRepository.saveAll(spells);

    return BackupImportResult(
      spellsImported: spells.length - rejected.length,
      effectsImported: effectsImported,
      parametersImported: parametersImported,
      rejectedSpells: rejected,
    );
```

Add the import for `invalid_spell_exception.dart`. The old per-spell `getSpellById`/`updateSpell`/`saveSpell` branch is gone — `saveAll` does the insert-or-update itself.

- [ ] **Step 5: Surface rejections in the UI**

`lib/presentation/screens/backup_screen.dart:39-41` — extend the status message:

```dart
        _statusMessage = 'Imported ${result.spellsImported} spells, '
            '${result.effectsImported} effects, '
            '${result.parametersImported} parameters'
            '${result.spellsRejected == 0 ? '' : '. Skipped ${result.spellsRejected} '
                'invalid spell(s): ${result.rejectedSpells.map((e) => e.spellId).join(', ')}'}';
```

Match the existing string's trailing punctuation — read the surrounding lines before editing rather than assuming the fragment above ends the sentence.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/data/services/backup_service_test.dart test/presentation/screens/backup_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Run the whole suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/data/services/backup_service.dart lib/presentation/screens/backup_screen.dart test
git commit -m "fix: backup restore imports dependencies before dependants

Custom effects and parameters were written after the spells that may depend
on them, so a spell built on a custom effect from the same backup was
validated against a catalog missing its own effect. Effects and parameters
now go first.

Invalid spells are skipped and reported in BackupImportResult rather than
aborting the import or being written unchecked, and the backup screen names
them. Also adds a genuine round-trip test through BackupService, closing the
coverage hole todo item 7 records."
```

---

### Task 8: Assertion 7 over the published assets

**Files:**
- Modify: `test/data/published_spell_import_test.dart`

**Interfaces:**
- Consumes: `validateSpellAgainstCatalog` (Task 3), memoised `AssetDataLoader` (Task 1).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the test**

This one is expected to pass immediately — zero violations were measured across all 294 spells on 2026-08-09. It is a regression guard, not a red-to-green cycle. Add to `test/data/published_spell_import_test.dart`:

```dart
  test('assertion 7: every published spell and template satisfies the catalog invariants', () async {
    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final modifiers = await loader.loadModifiers();

    final failures = <String>[];

    for (final spell in await loader.loadSpellLibrary()) {
      final effect = effects[spell.baseEffectId];
      // Assertion 4 already covers an id that does not resolve.
      if (effect == null) continue;
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        chosenBaseLevel: spell.chosenBaseLevel,
        requisites: spell.requisites,
        selectedModifiers: spell.selectedModifiers,
        modifiers: modifiers,
      );
      if (problems.isNotEmpty) {
        failures.add('${spell.name} (${spell.id}): ${problems.join('; ')}');
      }
    }

    for (final template in await loader.loadSpellTemplates()) {
      final effect = effects[template.baseEffectId];
      if (effect == null) continue;
      // isTemplate: a General template legitimately has no chosen level --
      // supplying one is what instantiating it means. Checks 3, 4 and 5 do
      // still apply.
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        chosenBaseLevel: null,
        requisites: template.requisites,
        selectedModifiers: template.selectedModifiers,
        modifiers: modifiers,
        isTemplate: true,
      );
      if (problems.isNotEmpty) {
        failures.add('${template.name} (${template.id}): ${problems.join('; ')}');
      }
    }

    expect(failures, isEmpty,
        reason: 'published assets break catalog invariants:\n${failures.join('\n')}');
  });
```

Add the import for `package:eruditus/models/spell.dart` if the file does not already have it (it does).

- [ ] **Step 2: Run the test**

Run: `flutter test test/data/published_spell_import_test.dart`
Expected: PASS immediately. **If it fails, stop and investigate rather than adjusting the test** — it would mean the published assets carry a violation that the 2026-08-09 scan did not find, which is a genuine data bug.

- [ ] **Step 3: Verify the assertion can actually fail**

Temporarily add a requisite matching its own Form to one spell in `assets/data/spell_library.json`, re-run, confirm the test fails and names that spell, then revert the edit. A guard nobody has seen fail is not yet known to be a guard.

Run: `flutter test test/data/published_spell_import_test.dart`
Expected: FAIL naming the spell, then PASS again after `git checkout assets/data/spell_library.json`.

- [ ] **Step 4: Commit**

```bash
git add test/data/published_spell_import_test.dart
git commit -m "test: assertion 7, published assets satisfy the catalog invariants

Green on landing -- zero violations across all 294 spells and 23 templates.
It exists as a regression guard: a violation in the shipped asset is an
importer bug, identical for every user and unfixable by them, and with
blocking as the runtime behaviour it would be a broken Library tab.

Templates skip checks 1 and 2, which cannot apply to a record whose whole
purpose is to have its level supplied later."
```

---

### Task 9: Update the todo

**Files:**
- Modify: `.superpowers/todo.md`

- [ ] **Step 1: Mark item 40's part A checkboxes**

In section 0's item 40, tick the enforcement-home task and the assertion-7 task, and record the outcome in the item's style: which files changed, what the counts were, and that part B (the requisites reshape) is the remaining open checkbox. Note the two spec refinements made during planning — the `isTemplate` flag, and `modifiers` being required on `SpellResolver` but defaulted on `ResolvedSpell`.

- [ ] **Step 2: Note the closed item-7 gap**

Item 7's "Known gap" bullet — the backup round-trip test not calling through `BackupService` — is closed by Task 7. Tick it and cross-reference item 40.

- [ ] **Step 3: Note the closed item-38 efficiency bullet**

Item 38's efficiency bullet says `getTemplates()` re-reads and re-parses `spell_templates.json` on every call. Task 1 fixes that for every asset. Update the bullet to record what remains (the sequential `getAllSpells`/`getTemplates` awaits and `SpellEngine._parameterById`'s linear scan), rather than deleting it.

- [ ] **Step 4: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: record item 40 part A as complete"
```

---

## Verification

Before considering the plan done:

- [ ] `flutter test` — full suite green
- [ ] `flutter test integration_test/spell_creation_flow_test.dart -d windows` — 3 pass, 2 pre-existing failures, no new ones
- [ ] `python -m unittest discover` from the repo root — the Python import harness is untouched by part A, so it must be unchanged
- [ ] `python -m scripts.spell_import.extract_spells` — counts unchanged at 285 imported / 23 templates / 52 blocked / 0 unresolved. Part A changes no assets; a count change means something leaked.
