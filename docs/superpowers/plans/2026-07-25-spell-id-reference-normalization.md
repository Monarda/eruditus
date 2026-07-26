# Spell Id-Reference Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `Spell`'s embedded copies of `BaseEffect` and `Parameter` with plain id references, resolved into a `ResolvedSpell` at the repository boundary, so a spell's catalog data has exactly one source of truth.

**Architecture:** `Spell` becomes a normalized persistence record holding only ids (`baseEffectId`, `rangeId`, `durationId`, `targetId`, plus the already-id-based `selectedModifiers`). `SpellResolver` joins a record against the effect/parameter catalogs to produce a `ResolvedSpell`, which is what the engine, blocs and UI consume. Repositories hydrate on read. An id that no longer resolves yields an unresolved `ResolvedSpell` that still lists but reports no level, rather than throwing or vanishing.

**Tech Stack:** Flutter, Dart, flutter_bloc, equatable, sqflite / sqflite_common_ffi, mocktail, bloc_test, integration_test.

**Origin:** This plan has no separate design spec. The design was settled directly in conversation: three options were weighed (pure id-reference hydrated at the repository boundary; pure id-reference resolved at point of use; generated-but-still-embedded snapshots), and the first was chosen. The deletion policy below was decided by the user, overriding an initial recommendation to block deletes instead.

## Global Constraints

- **Backward compatibility is not a goal** — neither for the API nor for stored data. No compatibility shims, no field read under two names, no id frozen to preserve an old reference. Stored spells from before this change are expected to be destroyed by the migration, not translated.
- **Deleting a custom base effect (or parameter) is permitted and invalidates every spell that used it.** This is the user's explicit decision. Deletion is never blocked, and affected spells are neither silently deleted nor silently repaired — they remain in the library, visibly marked invalid, with no calculated level.
- **A dangling id must never throw and must never take down the Library tab.** `SpellLibraryBloc` computes a level for every saved spell on load; one bad reference must degrade exactly one spell. This matches the existing dangling-modifier-option precedent in `SpellEngine.calculateBreakdown`.
- **The single source of truth for catalog data is `base_effects.json` / `parameters.json` (plus their user-created rows).** After this change, no spell record may contain a `description`, `baseLevel`, `magnitude`, `technique`, `form`, `name` or `category` copied from a catalog entry.
- **`selectedModifiers` keeps its current shape** — `Map<String, List<String>>` of `modifierId → [optionIds]`. It is already a pure id reference and is the precedent the rest of this change follows. Do not restructure it.
- **Source field values** are exactly `'built-in'` and `'user-created'`.
- **The suite is 207/207 green before this work starts, and must be green at every task boundary.** There is no pre-existing-failure allowance in this plan. Mid-task the tree may not compile — that is expected inside Task 2 — but no commit may leave a red suite behind.
- **`flutter test` does not run `integration_test/`.** That needs `flutter test integration_test/<file> -d windows`.
- **Do not run `flutter analyze` and `flutter test` concurrently** — they contend over `build/`.

---

## File Structure

**Created:**
- `lib/models/resolved_spell.dart` — `ResolvedSpell`, the hydrated view of a `Spell` record joined to its catalog entries
- `lib/data/spell_resolver.dart` — `SpellResolver`, the pure join from record + catalogs to `ResolvedSpell`
- `test/models/resolved_spell_test.dart`, `test/data/spell_resolver_test.dart`

**Modified:** `lib/models/parameter.dart` (delete `SelectedParameter`), `lib/models/spell.dart`, `lib/engine/spell_engine.dart`, `lib/data/repositories/{spell_repository,library_repository}.dart`, `lib/data/datasources/local_spell_datasource.dart`, `lib/data/database/app_database.dart`, `lib/bloc/spell_library/{spell_library_bloc,spell_library_state}.dart`, `lib/bloc/spell_creation/{spell_creation_bloc,spell_creation_state}.dart`, `lib/presentation/widgets/spell_card.dart`, `lib/data/services/backup_service.dart`, `lib/main.dart`, `assets/data/spell_library.json`, plus the test files named per task.

## A note on task sizing

Task 2 is large and monolithic on purpose. Dart will not compile a partially-flipped model: the moment `Spell` loses its embedded `BaseEffect`, every consumer breaks, and `ResolvedSpell` cannot even be written until `Spell` has the id fields it reads. `@Skip` does not help — it defers *runtime* assertions, not compile errors. Staging this into smaller green-at-each-boundary tasks is therefore not possible without inventing throwaway scaffolding. Task 1 is separable and genuinely reduces Task 2's surface, so it stands alone; Task 3 is separable because it only adds coverage.

---

### Task 1: Collapse `SelectedParameter` into `Parameter`

**Files:**
- Modify: `lib/models/parameter.dart`, `lib/models/spell.dart`, `lib/engine/spell_engine.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart`, `lib/presentation/screens/spell_creation_screen.dart`, `assets/data/spell_library.json`
- Test: `test/models/parameter_test.dart`, `test/models/spell_test.dart`, plus the fixture files in Step 7

**Interfaces:**
- Produces: `Spell.range`, `Spell.duration`, `Spell.target` and the matching `SpellDraft` fields are `Parameter` (not `SelectedParameter`). `SelectedParameter` no longer exists. `SpellEngine.calculateBreakdown` and `calculateSpellLevel` take `required Parameter range, duration, target`.

`SelectedParameter` is a two-field wrapper whose `parameterId` is read only in tests, and only to assert it equals `parameter.id`. It carries no information the `Parameter` doesn't. Removing it first shrinks the surface Task 2 has to touch.

- [ ] **Step 1: Write the failing test**

Append to `test/models/spell_test.dart` inside the `'Spell Model'` group:

```dart
    test('spell parameter fields are plain Parameters, not wrappers', () {
      final voice = Parameter(
        id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2, source: 'built-in');
      final momentary = Parameter(
        id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in');
      final individual = Parameter(
        id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in');

      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        technique: 'Creo',
        form: 'Ignem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Ignem',
          description: 'Create flame', baseLevel: 10, source: 'built-in'),
        range: voice,
        duration: momentary,
        target: individual,
        requisites: const [],
        source: 'user-created',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = Spell.fromMap(spell.toMap());

      expect(restored.range.id, 'range-voice');
      expect(restored.range.magnitude, 2);
      expect(restored.duration.id, 'duration-momentary');
      expect(restored.target.id, 'target-individual');
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — the `range:` argument is a `Parameter` where `SelectedParameter` is required.

- [ ] **Step 3: Delete `SelectedParameter`**

In `lib/models/parameter.dart`, delete the entire `SelectedParameter` class (from `class SelectedParameter {` to its closing brace). Keep `Parameter` exactly as it is.

- [ ] **Step 4: Change `Spell` and `SpellDraft` to hold `Parameter`**

In `lib/models/spell.dart`, change the three `Spell` field declarations from `final SelectedParameter range;` to `final Parameter range;` (likewise `duration`, `target`), and the three on `SpellDraft` from `SelectedParameter? range;` to `Parameter? range;`.

`toMap()`'s three entries stay `'range': range.toMap()` — `Parameter.toMap()` already produces the right object. In `fromMap`, replace each `SelectedParameter.fromMap(...)`:

```dart
    range: Parameter.fromMap(requireField<Map<String, dynamic>>(map, 'range', 'Spell')),
    duration: Parameter.fromMap(requireField<Map<String, dynamic>>(map, 'duration', 'Spell')),
    target: Parameter.fromMap(requireField<Map<String, dynamic>>(map, 'target', 'Spell')),
```

In `SpellDraft.copyWith`, change the three casts from `as SelectedParameter?` to `as Parameter?`.

- [ ] **Step 5: Update the engine, creation bloc and screen**

In `lib/engine/spell_engine.dart`, change every `required SelectedParameter range,` / `duration,` / `target,` declaration (in both `calculateBreakdown` and `calculateSpellLevel`) to `required Parameter range,` etc. Inside `calculateBreakdown`, the three contribution lines lose the `.parameter` hop:

```dart
      LevelContribution(label: 'Range · ${range.name}', magnitude: range.magnitude),
      LevelContribution(label: 'Duration · ${duration.name}', magnitude: duration.magnitude),
      LevelContribution(label: 'Target · ${target.name}', magnitude: target.magnitude),
```

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, the `RangeSelected` / `DurationSelected` / `TargetSelected` branches currently wrap the event's parameter. Store it directly instead:

```dart
    } else if (event is RangeSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(range: event.parameter),
      ));
```

Apply the same shape to the other two branches, deleting the now-unused `final selectedParam = SelectedParameter(...)` lines.

In `lib/presentation/screens/spell_creation_screen.dart`, the three `_buildParameterDropdown(... selectedParameter: draft.range?.parameter ...)` calls become `selectedParameter: draft.range` (likewise `draft.duration`, `draft.target`).

- [ ] **Step 6: Flatten the asset file's parameter shape**

```bash
python - <<'PY'
import json
path = 'assets/data/spell_library.json'
spells = json.load(open(path))
for s in spells:
    for key in ('range', 'duration', 'target'):
        s[key] = s[key]['parameter']
json.dump(spells, open(path, 'w'), indent=2, ensure_ascii=False)
print('flattened', len(spells), 'spells')
PY
```

Expected output: `flattened 30 spells`

- [ ] **Step 7: Update test fixtures**

Every fixture changes from `SelectedParameter(parameterId: 'p1', parameter: someParam)` to just `someParam`. Apply to: `test/bloc/spell_creation_bloc_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/data/datasources/local_spell_datasource_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/data/repositories/spell_repository_test.dart`, `test/data/services/backup_service_test.dart`, `test/engine/spell_engine_test.dart`, `test/models/spell_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/presentation/widgets/spell_card_test.dart`.

In `test/engine/spell_engine_test.dart`, the `_sp(...)` helper changes shape:

```dart
Parameter _sp(String id, String name, String category) =>
    Parameter(id: id, name: name, category: category, magnitude: 0, source: 'built-in');
```

In `test/models/parameter_test.dart`, delete the `SelectedParameter` group entirely.

- [ ] **Step 8: Run the full suite**

Run: `flutter test`
Expected: `All tests passed!` (the total drops by the two deleted `SelectedParameter` tests and gains one, so ~206).

- [ ] **Step 9: Commit**

```bash
git add lib test assets/data/spell_library.json
git commit -m "refactor: collapse SelectedParameter into Parameter"
```

---

### Task 2: Flip `Spell` to an id-only record and hydrate at the repository boundary

**Files:**
- Create: `lib/models/resolved_spell.dart`, `lib/data/spell_resolver.dart`, `test/models/resolved_spell_test.dart`, `test/data/spell_resolver_test.dart`
- Modify: `lib/models/spell.dart`, `lib/engine/spell_engine.dart`, `lib/data/repositories/{spell_repository,library_repository}.dart`, `lib/data/datasources/local_spell_datasource.dart`, `lib/data/database/app_database.dart`, `lib/bloc/spell_library/{spell_library_bloc,spell_library_state}.dart`, `lib/bloc/spell_creation/{spell_creation_bloc,spell_creation_state}.dart`, `lib/presentation/widgets/spell_card.dart`, `lib/data/services/backup_service.dart`, `lib/main.dart`, `assets/data/spell_library.json`
- Test: `test/models/spell_test.dart`, `test/data/datasources/{asset_data_loader_test,local_spell_datasource_test}.dart`, `test/data/repositories/{spell_repository_test,library_repository_test}.dart`, `test/data/services/backup_service_test.dart`, `test/bloc/{spell_library_bloc_test,spell_creation_bloc_test}.dart`, `test/engine/spell_engine_test.dart`, `test/presentation/widgets/spell_card_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`

**Interfaces:**
- Consumes: `Parameter` (Task 1)
- Produces:
  - `Spell({required String id, String? name, required String baseEffectId, required String rangeId, required String durationId, required String targetId, Map<String, List<String>> selectedModifiers = const {}, required List<Requisite> requisites, String? description, required String source, required DateTime createdAt, required DateTime updatedAt})` — no `technique`, `form`, or catalog objects.
  - `ResolvedSpell({required Spell record, BaseEffect? baseEffect, Parameter? range, Parameter? duration, Parameter? target})` with `isResolved`, `unresolvedReferences`, `technique`, `form`, and delegating getters `id`, `name`, `description`, `source`, `createdAt`, `updatedAt`, `selectedModifiers`, `requisites`.
  - `SpellResolver({required List<BaseEffect> effects, required List<Parameter> parameters})` with `ResolvedSpell resolve(Spell)` and `List<ResolvedSpell> resolveAll(Iterable<Spell>)`.
  - `SpellRepository({required LocalSpellDatasource datasource, required SpellResolver resolver})`; reads return `ResolvedSpell`, writes take `Spell`.
  - `LibraryRepository({required AssetDataLoader assetLoader, required SpellRepository spellRepository, required SpellResolver resolver})` returning `List<ResolvedSpell>`.
  - `SpellEngine({required List<ResolvedSpell> allSpells, List<Modifier> allModifiers})`; `findSimilarSpells` returns `List<ResolvedSpell>`.
  - `SpellCard({required ResolvedSpell spell, int? level, VoidCallback? onTap})`.

The tree will not compile between Steps 1 and 15. That is expected — see "A note on task sizing" above. Work through the analyzer; do not commit until Step 16 is green.

- [ ] **Step 1: Rewrite `Spell` as a record**

In `lib/models/spell.dart`, replace the `Spell` class entirely:

```dart
/// A saved spell, stored as references into the effect/parameter catalogs.
///
/// This record deliberately holds no copy of any catalog data — no
/// description, base level, magnitude, technique or form. Those are looked up
/// through [SpellResolver] on read, so there is exactly one source of truth and
/// no way for a spell to disagree with the catalog it was built from.
class Spell {
  final String id;
  final String? name;
  final String baseEffectId;
  final String rangeId;
  final String durationId;
  final String targetId;
  final Map<String, List<String>> selectedModifiers;
  final List<Requisite> requisites;
  final String? description;
  final String source; // "built-in" or "user-created"
  final DateTime createdAt;
  final DateTime updatedAt;

  Spell({
    required this.id,
    this.name,
    required this.baseEffectId,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    required this.requisites,
    this.description,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'baseEffectId': baseEffectId,
        'rangeId': rangeId,
        'durationId': durationId,
        'targetId': targetId,
        'selectedModifiers': selectedModifiers,
        'requisites': requisites.map((r) => r.toMap()).toList(),
        'description': description,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Spell.fromMap(Map<String, dynamic> map) => Spell(
        id: requireField<String>(map, 'id', 'Spell'),
        name: map['name'] as String?,
        baseEffectId: requireField<String>(map, 'baseEffectId', 'Spell'),
        rangeId: requireField<String>(map, 'rangeId', 'Spell'),
        durationId: requireField<String>(map, 'durationId', 'Spell'),
        targetId: requireField<String>(map, 'targetId', 'Spell'),
        selectedModifiers: (map['selectedModifiers'] as Map?)?.map(
              (k, v) => MapEntry(k as String, List<String>.from(v as List)),
            ) ??
            const {},
        requisites: (map['requisites'] as List?)
                ?.map((r) => Requisite.fromMap(r as Map<String, dynamic>))
                .toList() ??
            [],
        description: map['description'] as String?,
        source: requireField<String>(map, 'source', 'Spell'),
        createdAt: DateTime.parse(requireField<String>(map, 'createdAt', 'Spell')),
        updatedAt: DateTime.parse(requireField<String>(map, 'updatedAt', 'Spell')),
      );
}
```

- [ ] **Step 2: Make `SpellDraft.toSpell` emit ids**

`SpellDraft` keeps holding real objects — the creation screen's dropdowns select them, and its `technique`/`form` fields drive which base effects are offered before one is chosen. Only `toSpell` changes. `technique`/`form` leave the missing-field check because a saved spell's technique and form are implied by its base effect:

```dart
  Spell toSpell({required String name, required String source}) {
    final missingFields = <String>[
      if (baseEffect == null) 'baseEffect',
      if (range == null) 'range',
      if (duration == null) 'duration',
      if (target == null) 'target',
    ];
    if (missingFields.isNotEmpty) {
      throw StateError(
        'Cannot convert SpellDraft to Spell: ${missingFields.join(', ')} '
        '${missingFields.length == 1 ? 'is' : 'are'} not set',
      );
    }

    return Spell(
      id: id,
      name: name,
      baseEffectId: baseEffect!.id,
      rangeId: range!.id,
      durationId: duration!.id,
      targetId: target!.id,
      selectedModifiers: selectedModifiers,
      requisites: requisites,
      description: description,
      source: source,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
```

- [ ] **Step 3: Write the failing `ResolvedSpell` test**

Create `test/models/resolved_spell_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

void main() {
  final effect = BaseEffect(
    id: 'creim-2', technique: 'Creo', form: 'Imaginem',
    description: 'Create an image that affects two senses', baseLevel: 2, source: 'built-in');
  final voice = Parameter(
    id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2, source: 'built-in');
  final momentary = Parameter(
    id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in');
  final individual = Parameter(
    id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in');

  Spell record() => Spell(
        id: 'spell-1',
        name: 'Phantasm',
        baseEffectId: 'creim-2',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        description: 'A face on a wall. Level 10.',
        source: 'built-in',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('a fully resolved spell exposes catalog data through delegating getters', () {
    final resolved = ResolvedSpell(
      record: record(), baseEffect: effect, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isTrue);
    expect(resolved.unresolvedReferences, isEmpty);
    expect(resolved.id, 'spell-1');
    expect(resolved.name, 'Phantasm');
    expect(resolved.source, 'built-in');
    expect(resolved.description, 'A face on a wall. Level 10.');
    // Derived from the base effect, never stored separately, so they cannot
    // disagree with it.
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
  });

  test('a missing base effect makes the spell unresolved and names the reference', () {
    final resolved = ResolvedSpell(
      record: record(), baseEffect: null, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['creim-2']);
    expect(resolved.technique, isNull);
    expect(resolved.form, isNull);
    // The record survives intact so the spell can still be listed and re-saved.
    expect(resolved.id, 'spell-1');
    expect(resolved.name, 'Phantasm');
  });

  test('every missing reference is reported, not just the first', () {
    final resolved = ResolvedSpell(
      record: record(), baseEffect: null, range: null, duration: momentary, target: null);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences,
        containsAll(['creim-2', 'range-voice', 'target-individual']));
    expect(resolved.unresolvedReferences, isNot(contains('duration-momentary')));
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/models/resolved_spell_test.dart`
Expected: FAIL — cannot find `lib/models/resolved_spell.dart`.

- [ ] **Step 5: Create `ResolvedSpell`**

Create `lib/models/resolved_spell.dart`:

```dart
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/spell.dart';

/// A [Spell] record joined to the catalog entries its ids refer to.
///
/// The record is the persisted truth; the catalog objects are looked up fresh
/// on every load. Any of them may be null when the id no longer resolves —
/// which happens when a user deletes a custom base effect or parameter a saved
/// spell was built on. Such a spell is not repaired and not discarded: it stays
/// listed, reports [isResolved] false, and yields no calculated level.
class ResolvedSpell {
  final Spell record;
  final BaseEffect? baseEffect;
  final Parameter? range;
  final Parameter? duration;
  final Parameter? target;

  const ResolvedSpell({
    required this.record,
    this.baseEffect,
    this.range,
    this.duration,
    this.target,
  });

  bool get isResolved =>
      baseEffect != null && range != null && duration != null && target != null;

  /// The ids that failed to resolve, in record order. Empty when [isResolved].
  List<String> get unresolvedReferences => [
        if (baseEffect == null) record.baseEffectId,
        if (range == null) record.rangeId,
        if (duration == null) record.durationId,
        if (target == null) record.targetId,
      ];

  // Derived from the resolved base effect rather than stored on the record, so
  // a spell can never claim a technique its own base effect disagrees with.
  String? get technique => baseEffect?.technique;
  String? get form => baseEffect?.form;

  String get id => record.id;
  String? get name => record.name;
  String? get description => record.description;
  String get source => record.source;
  DateTime get createdAt => record.createdAt;
  DateTime get updatedAt => record.updatedAt;
  Map<String, List<String>> get selectedModifiers => record.selectedModifiers;
  List<Requisite> get requisites => record.requisites;
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/models/resolved_spell_test.dart`
Expected: PASS (3 tests). This file's import graph is models-only, so it compiles and passes even while the blocs and UI are still broken.

- [ ] **Step 7: Write the failing `SpellResolver` test**

Create `test/data/spell_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';

void main() {
  final effect = BaseEffect(
    id: 'creim-2', technique: 'Creo', form: 'Imaginem',
    description: 'Create an image that affects two senses', baseLevel: 2, source: 'built-in');
  final voice = Parameter(
    id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2, source: 'built-in');
  final momentary = Parameter(
    id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in');
  final individual = Parameter(
    id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in');

  final resolver = SpellResolver(
    effects: [effect], parameters: [voice, momentary, individual]);

  Spell record({String baseEffectId = 'creim-2', String rangeId = 'range-voice'}) => Spell(
        id: 'spell-1',
        name: 'Phantasm',
        baseEffectId: baseEffectId,
        rangeId: rangeId,
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        source: 'built-in',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('resolve joins a record to its catalog entries', () {
    final resolved = resolver.resolve(record());

    expect(resolved.isResolved, isTrue);
    expect(resolved.baseEffect?.description, 'Create an image that affects two senses');
    expect(resolved.range?.magnitude, 2);
    expect(resolved.technique, 'Creo');
  });

  test('an unknown base effect id resolves to null without throwing', () {
    final resolved = resolver.resolve(record(baseEffectId: 'deleted-custom-effect'));

    expect(resolved.isResolved, isFalse);
    expect(resolved.baseEffect, isNull);
    expect(resolved.unresolvedReferences, ['deleted-custom-effect']);
    // The other three still resolve — one bad id degrades one field.
    expect(resolved.range?.id, 'range-voice');
  });

  test('an unknown parameter id resolves to null without throwing', () {
    final resolved = resolver.resolve(record(rangeId: 'deleted-custom-parameter'));

    expect(resolved.isResolved, isFalse);
    expect(resolved.range, isNull);
    expect(resolved.baseEffect?.id, 'creim-2');
  });

  test('resolveAll resolves each record independently', () {
    final resolved = resolver.resolveAll([record(), record(baseEffectId: 'gone')]);

    expect(resolved.length, 2);
    expect(resolved[0].isResolved, isTrue);
    expect(resolved[1].isResolved, isFalse);
  });

  test('resolveAll on an empty catalog yields unresolved spells rather than throwing', () {
    final empty = SpellResolver(effects: const [], parameters: const []);

    final resolved = empty.resolveAll([record()]);

    expect(resolved.single.isResolved, isFalse);
    expect(resolved.single.unresolvedReferences.length, 4);
  });
}
```

- [ ] **Step 8: Run test to verify it fails**

Run: `flutter test test/data/spell_resolver_test.dart`
Expected: FAIL — cannot find `lib/data/spell_resolver.dart`.

- [ ] **Step 9: Create `SpellResolver`**

Create `lib/data/spell_resolver.dart`:

```dart
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

/// Joins [Spell] records to the catalogs their ids refer to.
///
/// Lookups are index-backed because [resolveAll] runs over the whole library on
/// every Library tab load, against a 604-entry effect catalog.
///
/// An id with no matching entry yields null rather than throwing: a spell built
/// on a since-deleted custom effect must still list (marked unresolved) instead
/// of taking down the whole Library tab.
class SpellResolver {
  final Map<String, BaseEffect> _effectsById;
  final Map<String, Parameter> _parametersById;

  SpellResolver({
    required List<BaseEffect> effects,
    required List<Parameter> parameters,
  })  : _effectsById = {for (final e in effects) e.id: e},
        _parametersById = {for (final p in parameters) p.id: p};

  ResolvedSpell resolve(Spell record) => ResolvedSpell(
        record: record,
        baseEffect: _effectsById[record.baseEffectId],
        range: _parametersById[record.rangeId],
        duration: _parametersById[record.durationId],
        target: _parametersById[record.targetId],
      );

  List<ResolvedSpell> resolveAll(Iterable<Spell> records) =>
      records.map(resolve).toList();
}
```

- [ ] **Step 10: Run test to verify it passes**

Run: `flutter test test/data/spell_resolver_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 11: Rewrite the asset file to id form, and verify it resolves**

```bash
python - <<'PY'
import json
path = 'assets/data/spell_library.json'
spells = json.load(open(path))
for s in spells:
    s['baseEffectId'] = s.pop('baseEffect')['id']
    s['rangeId'] = s.pop('range')['id']
    s['durationId'] = s.pop('duration')['id']
    s['targetId'] = s.pop('target')['id']
    s.pop('technique', None)
    s.pop('form', None)
json.dump(spells, open(path, 'w'), indent=2, ensure_ascii=False)
print('normalized', len(spells), 'spells')
PY
```

Expected output: `normalized 30 spells`. This relies on Task 1 having already flattened `range`/`duration`/`target` to bare parameter objects.

Then verify every reference resolves:

```bash
python - <<'PY'
import json
spells = json.load(open('assets/data/spell_library.json'))
effects = {e['id'] for e in json.load(open('assets/data/base_effects.json'))}
params = {p['id'] for p in json.load(open('assets/data/parameters.json'))}
bad = []
for s in spells:
    if s['baseEffectId'] not in effects:
        bad.append((s['id'], 'baseEffectId', s['baseEffectId']))
    for key in ('rangeId', 'durationId', 'targetId'):
        if s[key] not in params:
            bad.append((s['id'], key, s[key]))
print('unresolvable references:', bad if bad else 'NONE')
print('spells:', len(spells))
PY
```

Expected: `unresolvable references: NONE` and `spells: 30`. If anything is listed, the asset id is wrong and must be corrected — do not loosen the resolver to tolerate it.

- [ ] **Step 12: Drop the unused columns and bump the schema**

In `lib/data/datasources/local_spell_datasource.dart`, remove `technique` and `form` from `_toRow`:

```dart
  Map<String, Object?> _toRow(Spell spell) => {
        'id': spell.id,
        'name': spell.name,
        'source': spell.source,
        'data': jsonEncode(spell.toMap()),
        'created_at': spell.createdAt.toIso8601String(),
        'updated_at': spell.updatedAt.toIso8601String(),
      };
```

In `lib/data/database/app_database.dart`, change `_databaseVersion` to `3` and drop the two columns from the `spells` table in `_createSchema`:

```dart
    await db.execute('''
      CREATE TABLE spells (
        id TEXT PRIMARY KEY,
        name TEXT,
        source TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
```

The existing `onUpgrade` already drops every table and re-runs `_createSchema`, so the version bump alone triggers it. Nothing queries by technique or form in SQL (`findSimilarSpells` filters in memory), so no query path is lost.

- [ ] **Step 13: Hydrate in the repositories**

Replace `lib/data/repositories/spell_repository.dart` entirely:

```dart
import 'package:eruditus/data/datasources/local_spell_datasource.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

class SpellRepository {
  final LocalSpellDatasource datasource;
  final SpellResolver resolver;

  SpellRepository({required this.datasource, required this.resolver});

  // Writes take the record; reads return it joined to the catalogs.
  Future<void> saveSpell(Spell spell) => datasource.insertSpell(spell);
  Future<void> updateSpell(Spell spell) => datasource.updateSpell(spell);
  Future<void> deleteSpell(String id) => datasource.deleteSpell(id);

  Future<ResolvedSpell?> getSpellById(String id) async {
    final record = await datasource.getSpellById(id);
    return record == null ? null : resolver.resolve(record);
  }

  Future<List<ResolvedSpell>> getAllUserSpells() async =>
      resolver.resolveAll(await datasource.getAllSpells());
}
```

In `lib/data/repositories/library_repository.dart`: add imports for `spell_resolver.dart` and `resolved_spell.dart`, add a `final SpellResolver resolver;` field with a `required this.resolver` constructor parameter, change `List<Spell>? _cachedBuiltInSpells;` to `List<ResolvedSpell>?`, change every `Future<List<Spell>>` return type to `Future<List<ResolvedSpell>>`, and resolve when filling the cache:

```dart
  Future<List<ResolvedSpell>> getBuiltInSpells() async {
    _cachedBuiltInSpells ??= resolver.resolveAll(await assetLoader.loadSpellLibrary());
    return _cachedBuiltInSpells!;
  }
```

The `searchSpells` and `filterBySource` bodies need no change — they read only `.name` and `.source`, both delegated by `ResolvedSpell`.

- [ ] **Step 14: Update the engine, blocs and card**

In `lib/engine/spell_engine.dart`, add the `resolved_spell.dart` import, change `final List<Spell> allSpells;` to `final List<ResolvedSpell> allSpells;`, and rewrite `findSimilarSpells` to skip unresolved spells (they have no level to sort by):

```dart
  List<ResolvedSpell> findSimilarSpells(String technique, String form, {int? referenceLevel}) {
    final matches = allSpells
        .where((s) => s.isResolved && s.technique == technique && s.form == form)
        .toList();

    if (referenceLevel != null) {
      matches.sort((a, b) {
        final levelA = calculateSpellLevel(
          baseEffect: a.baseEffect!, range: a.range!, duration: a.duration!, target: a.target!,
          selectedModifiers: a.selectedModifiers, requisites: a.requisites,
        );
        final levelB = calculateSpellLevel(
          baseEffect: b.baseEffect!, range: b.range!, duration: b.duration!, target: b.target!,
          selectedModifiers: b.selectedModifiers, requisites: b.requisites,
        );
        return (levelA - referenceLevel).abs().compareTo((levelB - referenceLevel).abs());
      });
    }

    return matches;
  }
```

The `!` assertions are safe because the `where` filters to `isResolved` first.

In `lib/bloc/spell_library/spell_library_bloc.dart`, omit unresolved spells from the level map:

```dart
        final spells = await libraryRepository.getAllSpells();
        final levels = <String, int>{
          for (final s in spells)
            // An unresolved spell has no base effect to calculate from. It is
            // omitted rather than defaulted to 0, so the card can tell
            // "invalid" apart from "genuinely level 0".
            if (s.isResolved)
              s.id: spellEngine.calculateSpellLevel(
                baseEffect: s.baseEffect!, range: s.range!, duration: s.duration!,
                target: s.target!, selectedModifiers: s.selectedModifiers,
                requisites: s.requisites,
              ),
        };
```

In `lib/bloc/spell_library/spell_library_state.dart`, swap the import to `resolved_spell.dart` and change `allSpells`, `visibleSpells` and `copyWith`'s parameter to `List<ResolvedSpell>`.

In `lib/bloc/spell_creation/spell_creation_state.dart`, change `final List<Spell> suggestions;` to `List<ResolvedSpell>` (plus `copyWith` and the import). `savedSpell` stays `Spell?` — it is the record just written, not a catalog join.

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, the per-suggestion level map reads through resolved fields (safe for the same reason as above):

```dart
    final suggestionLevels = <String, int>{
      for (final s in suggestions)
        s.id: spellEngine.calculateSpellLevel(
          baseEffect: s.baseEffect!, range: s.range!, duration: s.duration!, target: s.target!,
          selectedModifiers: s.selectedModifiers, requisites: s.requisites,
        ),
    };
```

In `lib/presentation/widgets/spell_card.dart`, swap the import to `resolved_spell.dart`, change the field to `final ResolvedSpell spell;`, and render the unresolved case:

```dart
  @override
  Widget build(BuildContext context) {
    final isInvalid = !spell.isResolved;
    final title = spell.name ?? 'Untitled ${spell.technique} ${spell.form}';
    final String subtitle;
    if (isInvalid) {
      // The catalog entry this spell was built on no longer exists (a custom
      // effect or parameter the user deleted). Say so plainly rather than
      // showing a half-empty card or hiding the spell.
      subtitle = 'Unavailable — missing ${spell.unresolvedReferences.join(', ')}';
    } else {
      subtitle = level != null
          ? '${spell.technique} ${spell.form} • Level $level'
          : '${spell.technique} ${spell.form}';
    }
    final description = spell.description;
    final hasDescription = description != null && description.isNotEmpty;

    return Card(
      key: isInvalid ? const Key('spell-card-unresolved') : null,
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle,
                style: isInvalid
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null),
            if (hasDescription)
              Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Chip(label: Text(spell.source == 'built-in' ? 'Built-in' : 'My Spell')),
      ),
    );
  }
```

- [ ] **Step 15: Wire the resolver through composition and fix the backup service**

In `lib/main.dart`, build the resolver from the loaded catalogs and pass it to both repositories. Read the existing construction order first and slot these in where `configRepository` is already available:

```dart
  final resolver = SpellResolver(
    effects: await configRepository.getAllEffects(),
    parameters: await configRepository.getAllParameters(),
  );
  final spellRepository = SpellRepository(
      datasource: LocalSpellDatasource(database: database), resolver: resolver);
  final libraryRepository = LibraryRepository(
      assetLoader: assetLoader, spellRepository: spellRepository, resolver: resolver);
```

Add `import 'package:eruditus/data/spell_resolver.dart';`.

In `lib/data/services/backup_service.dart`, `exportToJson` now receives `ResolvedSpell`s, so export the underlying record:

```dart
      'spells': userSpells.map((s) => s.record.toMap()).toList(),
```

`importFromJson` needs no change — it already calls `Spell.fromMap` and `saveSpell`, both of which still speak records. A backup now stores ids rather than embedded catalog data; since the backup already carries `customEffects` and `customParameters`, a full round-trip still restores everything.

- [ ] **Step 16: Update every remaining fixture**

Each `Spell(...)` fixture drops `technique`, `form`, `baseEffect`, `range`, `duration`, `target` in favour of four ids:

```dart
    Spell(
      id: 'user-1',
      name: 'My Fireball',
      baseEffectId: 'e1',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      source: 'user-created',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    )
```

Apply to `test/models/spell_test.dart`, `test/data/datasources/local_spell_datasource_test.dart`, `test/data/services/backup_service_test.dart`, `test/data/repositories/spell_repository_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/bloc/spell_creation_bloc_test.dart`, `test/presentation/widgets/spell_card_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`. Delete the `technique`/`form` round-trip assertions in `test/models/spell_test.dart` — those fields no longer exist on the record, and `ResolvedSpell`'s derivation of them is covered by `test/models/resolved_spell_test.dart`.

Tests constructing a repository now pass a resolver:

```dart
    final assetLoader = AssetDataLoader();
    final resolver = SpellResolver(
      effects: await assetLoader.loadBaseEffects(),
      parameters: await assetLoader.loadParameters(),
    );
    spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database), resolver: resolver);
```

Apply to `test/data/repositories/spell_repository_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/bloc/spell_creation_bloc_test.dart`, `test/data/services/backup_service_test.dart`.

Tests constructing `SpellEngine(allSpells: [...])` or `SpellCard(spell: ...)` wrap their fixture:

```dart
    final suggestion = ResolvedSpell(
      record: suggestionRecord, baseEffect: creoIgnemEffect,
      range: rangeParam, duration: durationParam, target: targetParam);
```

Apply to `test/bloc/spell_creation_bloc_test.dart`, `test/engine/spell_engine_test.dart`, `test/presentation/widgets/spell_card_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`.

In `test/data/datasources/asset_data_loader_test.dart`, the id-integrity loop reads the new fields:

```dart
    for (final spell in spells) {
      expect(effectIds.contains(spell.baseEffectId), isTrue,
          reason: '${spell.name}: baseEffect id ${spell.baseEffectId} not in base_effects.json');
      for (final id in [spell.rangeId, spell.durationId, spell.targetId]) {
        expect(parameterIds.contains(id), isTrue,
            reason: '${spell.name}: parameter id $id not in parameters.json');
      }
    }
```

and the calculated-vs-stated test looks magnitudes up through the catalogs:

```dart
    final effects = await loader.loadBaseEffects();
    final parameters = await loader.loadParameters();
    final effectsById = {for (final e in effects) e.id: e};
    final parametersById = {for (final p in parameters) p.id: p};

    for (final spell in spells) {
      final statedLevel = levelStatedInDescription(spell);
      final baseEffect = effectsById[spell.baseEffectId]!;

      final magnitudes = [
        parametersById[spell.rangeId]!.magnitude,
        parametersById[spell.durationId]!.magnitude,
        parametersById[spell.targetId]!.magnitude,
        for (final entry in spell.selectedModifiers.entries)
          for (final optionId in entry.value)
            modifiers.firstWhere((m) => m.id == entry.key).optionById(optionId)!.magnitude,
        ...spell.requisites.map((r) => r.magnitude),
      ];

      expect(SpellLevelCalculator.calculate(baseEffect.baseLevel, magnitudes), statedLevel,
          reason: '${spell.name}: calculated level does not match the stated level');
    }
```

- [ ] **Step 17: Run everything**

Run: `flutter analyze`
Expected: no issues beyond the three pre-existing infos (`sqflite_common_ffi` import in `main.dart`, two `unnecessary_underscores` in `modifiers_section_test.dart`).

Run: `flutter test`
Expected: `All tests passed!`

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: `All tests passed!` (3 tests). If the integration tests construct repositories directly, they need the same `resolver:` argument as the unit tests.

- [ ] **Step 18: Commit**

```bash
git add lib test integration_test assets/data/spell_library.json
git commit -m "refactor: store spells as id references resolved at the repository boundary"
```

---

### Task 3: Cover the invalid-spell path end to end

**Files:**
- Modify: `test/presentation/widgets/spell_card_test.dart`, `integration_test/spell_creation_flow_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–2.

The deletion-invalidates-spells policy is the one genuinely new behaviour in this plan, and it only manifests once a deletion propagates through a reload. Mocked widget tests cannot observe that, which is why it also gets real-bloc coverage.

- [ ] **Step 1: Write the failing widget test**

Append to `test/presentation/widgets/spell_card_test.dart`. Declare `personalParam`, `momentaryParam` and `individualParam` alongside that file's existing fixtures if not already present:

```dart
  testWidgets('an unresolved spell is shown as unavailable with no level', (tester) async {
    final record = Spell(
      id: 'orphan',
      name: 'Orphaned Spell',
      baseEffectId: 'deleted-custom-effect',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const [],
      source: 'user-created',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    // Base effect missing, parameters present — exactly what a deleted custom
    // effect leaves behind.
    final unresolved = ResolvedSpell(
      record: record,
      baseEffect: null,
      range: personalParam,
      duration: momentaryParam,
      target: individualParam,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(spell: unresolved)),
    ));

    expect(find.byKey(const Key('spell-card-unresolved')), findsOneWidget);
    expect(find.text('Orphaned Spell'), findsOneWidget);
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(find.textContaining('deleted-custom-effect'), findsOneWidget);
    expect(find.textContaining('Level'), findsNothing);
  });
```

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: PASS. A pass here confirms Task 2 Step 14's rendering rather than driving new code; Step 3 is where genuinely new coverage begins. If it fails, the card's unresolved branch was not implemented as specified — fix it before continuing.

- [ ] **Step 3: Add the real-bloc integration test**

Append a fourth `testWidgets` to `integration_test/spell_creation_flow_test.dart`, following the construction preamble of the existing three (real `AppDatabase`, real repositories, real `SpellResolver`, real blocs, `EruditusApp`):

```dart
      // Author a custom base effect, build a spell on it, then delete the
      // effect. The user has accepted that this invalidates the spell — it must
      // stay listed and clearly marked, not vanish and not crash the tab.
      final customEffect = BaseEffect(
        id: 'custom-integration-effect',
        technique: 'Creo',
        form: 'Ignem',
        description: 'A custom effect for the integration test',
        baseLevel: 5,
        source: 'user-created',
      );
      await configRepository.addCustomEffect(customEffect);

      await spellRepository.saveSpell(Spell(
        id: 'spell-on-custom-effect',
        name: 'Spell On Custom Effect',
        baseEffectId: customEffect.id,
        rangeId: 'range-personal',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        source: 'user-created',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      final libraryListView = find.descendant(
        of: find.byType(SpellLibraryScreen), matching: find.byType(ListView));
      final libraryScrollable = find.descendant(
        of: libraryListView, matching: find.byType(Scrollable));

      await tester.scrollUntilVisible(
          find.text('Spell On Custom Effect'), 200.0, scrollable: libraryScrollable);
      await tester.pumpAndSettle();

      expect(find.text('Spell On Custom Effect'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Delete the effect out from under it and reload the library.
      await configRepository.deleteCustomEffect(customEffect.id);
      spellLibraryBloc.add(const LibraryRequested());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Spell On Custom Effect'), 200.0, scrollable: libraryScrollable);
      await tester.pumpAndSettle();

      // Still listed, now visibly unavailable, and the tab is intact.
      expect(tester.takeException(), isNull);
      expect(find.text('Spell On Custom Effect'), findsOneWidget);
      expect(find.textContaining('Unavailable'), findsOneWidget);

      await database.close();
```

**Expect this to fail on the first run, and read the failure carefully.** The resolver built at startup holds a snapshot of the catalogs, so `LibraryRequested` alone will re-read spells but resolve them against the *stale* catalog, and the spell will still appear resolved. That is a real gap in Task 2's wiring, not a test bug. Fix it by rebuilding the resolver when the configuration changes — the same seam `AvailableModifiersSynced` already uses to keep `SpellEngine` current. Record the fix in your report.

- [ ] **Step 4: Run the integration suite**

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: `All tests passed!` (4 tests).

- [ ] **Step 5: Run the unit suite**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib test integration_test
git commit -m "test: cover the invalid-spell path when a custom effect is deleted"
```

---

## Notes for the executor

- **Every commit must leave `flutter test` green.** Inside Task 2 the tree will not compile for a stretch — that is expected and unavoidable (see "A note on task sizing"), but do not commit until Step 17 passes.
- **`flutter test` never runs `integration_test/`.** Re-run the integration suite before any commit that changes the widget tree, the resolver, or the repositories.
- **Do not run `flutter analyze` and `flutter test` concurrently** — they contend over `build/` and produce a spurious `sqlite3.dll` lock error.
- **If a `flutter test` run fails with a `sqlite3.dll` lock**, an orphaned `flutter_tester.exe` is holding it. Kill it and re-run.
- **`python3` is a broken Windows Store alias in this environment; use `python`.**
- **Do not soften the resolver to make a bad asset id pass.** Task 2 Step 11 exists to catch exactly that; if it reports an unresolvable reference, the data is wrong.
- **Task 3 Step 3 is expected to fail first.** Its failure exposes a real staleness gap in the resolver's lifetime. Fix the wiring, not the test.
