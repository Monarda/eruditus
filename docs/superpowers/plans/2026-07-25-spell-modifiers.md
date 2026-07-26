# Spell Modifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `SpecialFactor` with a unified `Modifier` model that lets a caster choose magnitude-costing options (Size, material difficulty, unnatural context, transport distance, Imaginem complexity) scoped to the spell they are building.

**Architecture:** One data-driven mechanism, no plugin seam. A `Modifier` is a named set of `ModifierOption` rungs, each carrying a magnitude, bound to spells by a `ModifierScope` (technique / form / explicit effect ids) and selected either exclusively (`single`) or cumulatively (`multi`). `SpellEngine` resolves selected option ids to magnitudes and folds them into the existing magnitude list. Definitions ship as asset JSON.

**Tech Stack:** Flutter, Dart, flutter_bloc, equatable, sqflite / sqflite_common_ffi, mocktail, bloc_test, integration_test.

**Source spec:** `docs/superpowers/specs/2026-07-25-spell-modifiers-design.md`

## Global Constraints

- **Backward compatibility is not a goal.** No compatibility shims, no field read under two names in shipped code, no id frozen to preserve old references. (The temporary dual field in Tasks 4–10 is a build-ordering device to keep the suite green between tasks, not a shipped shim — it is deleted in Task 10.)
- **A dangling option id contributes 0 magnitude and must never throw.** `SpellLibraryBloc` computes a level for every saved spell on load; one bad reference would drop the whole Library tab into its error state.
- **Modifiers are optional.** No selection means no magnitude. Nothing forces a spell to declare a material.
- **Magnitude order does not matter.** `SpellLevelCalculator` reduces to `base + min(total, cap) + max(0, total − cap) × 5` where `cap = max(0, 5 - baseLevel)`. Append modifier magnitudes anywhere in the list.
- **No strategy/handler interface for modifier families.** All four families are `option → magnitude`; the mechanism is data plus one interpreter.
- **The test baseline is 5 failures, not 0.** 3 in `test/bloc/configuration_bloc_test.dart`, 2 in `test/data/datasources/asset_data_loader_test.dart`, caused by stale effect-count expectations predating the 604-effect extraction. Every task must end with exactly these 5 failing and no others.
- **`flutter test` does not run `integration_test/`.** Integration tests require `flutter test integration_test/<file> -d windows`. A widget-tree change is not verified by `flutter test` alone.
- **Mocked blocs emit no new state**, so mocked widget tests cannot observe post-interaction rebuilds. Behaviour that only manifests on re-render must be covered by driving states through a `StreamController` via `whenListen`, or in `integration_test/`.
- **Selection storage is `Map<String, List<String>>`** — `modifierId → optionIds` — on both `Spell` and `SpellDraft`.
- **Source field values** are exactly `'built-in'` and `'user-created'`.

---

## File Structure

**Created:**
- `lib/models/modifier.dart` — `ModifierSelectionMode`, `ModifierOption`, `ModifierScope`, `Modifier`
- `lib/engine/level_breakdown.dart` — `LevelContribution`, `LevelBreakdown`
- `lib/presentation/widgets/modifiers_section.dart` — collapsed/expandable modifier controls
- `lib/presentation/widgets/level_breakdown_card.dart` — itemised contributions panel
- `assets/data/modifiers.json` — the 17 definitions
- `test/models/modifier_test.dart`, `test/engine/level_breakdown_test.dart`, `test/presentation/widgets/modifiers_section_test.dart`, `test/data/asset_modifier_integrity_test.dart`

**Modified:** `lib/models/spell.dart`, `lib/engine/spell_engine.dart`, `lib/bloc/spell_creation/{spell_creation_bloc,spell_creation_event,spell_creation_state}.dart`, `lib/bloc/configuration/{configuration_bloc,configuration_event,configuration_state}.dart`, `lib/bloc/spell_library/spell_library_bloc.dart`, `lib/data/datasources/{asset_data_loader,local_configuration_datasource}.dart`, `lib/data/repositories/configuration_repository.dart`, `lib/data/database/app_database.dart`, `lib/presentation/screens/spell_creation_screen.dart`, `assets/data/spell_library.json`, `integration_test/spell_creation_flow_test.dart`

**Deleted (Task 10):** `lib/models/special_factor.dart`, `test/models/special_factor_test.dart`, `assets/data/special_factors.json`

---

### Task 1: Modifier model and scope predicate

**Files:**
- Create: `lib/models/modifier.dart`
- Test: `test/models/modifier_test.dart`

**Interfaces:**
- Consumes: `requireField<T>` from `lib/utils/map_serialization.dart`
- Produces: `ModifierSelectionMode { single, multi }`; `ModifierOption({required String id, required String label, String? description, required int magnitude, String? baseIndividual})`; `ModifierScope({String? technique, String? form, List<String> effectIds, List<String> excludeTechniques})` with `bool appliesTo({String? technique, String? form, String? baseEffectId})`; `Modifier({required String id, required String name, String? description, required ModifierSelectionMode selectionMode, required ModifierScope scope, required List<ModifierOption> options, required String source})` with `ModifierOption? optionById(String optionId)`. All three have `toMap()`/`fromMap()`.

`excludeTechniques` expresses the rulebook's "Intellego spells are not affected by Target size" — a Technique-wide exemption a positive `technique` match cannot represent. `baseIndividual` records what one Individual is for that option, which the Size ladder multiplies; it carries no magnitude.

- [ ] **Step 1: Write the failing test**

Create `test/models/modifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/modifier.dart';

Modifier _mod({
  ModifierSelectionMode mode = ModifierSelectionMode.single,
  ModifierScope scope = const ModifierScope(),
}) =>
    Modifier(
      id: 'terram-material',
      name: 'Material difficulty',
      description: 'Harder materials cost magnitudes',
      selectionMode: mode,
      scope: scope,
      options: [
        ModifierOption(id: 'mat-dirt', label: 'Dirt', magnitude: 0),
        ModifierOption(id: 'mat-stone', label: 'Stone or glass', magnitude: 1),
        ModifierOption(id: 'mat-metal', label: 'Metal or gemstone', magnitude: 2),
      ],
      source: 'built-in',
    );

void main() {
  group('ModifierOption', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final option = ModifierOption(
          id: 'mat-stone', label: 'Stone or glass', description: 'Harder than dirt', magnitude: 1);

      final restored = ModifierOption.fromMap(option.toMap());

      expect(restored.id, 'mat-stone');
      expect(restored.label, 'Stone or glass');
      expect(restored.description, 'Harder than dirt');
      expect(restored.magnitude, 1);
    });

    test('fromMap throws a clear FormatException when magnitude is missing', () {
      expect(
        () => ModifierOption.fromMap({'id': 'x', 'label': 'X'}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            allOf(contains('magnitude'), contains('ModifierOption')))),
      );
    });
  });

  group('ModifierScope.appliesTo', () {
    test('an empty scope applies to anything', () {
      const scope = ModifierScope();
      expect(scope.appliesTo(technique: 'Creo', form: 'Ignem', baseEffectId: 'e1'), isTrue);
    });

    test('form-only scope matches any technique with that form', () {
      const scope = ModifierScope(form: 'Terram');
      expect(scope.appliesTo(technique: 'Muto', form: 'Terram', baseEffectId: 'mute-1'), isTrue);
      expect(scope.appliesTo(technique: 'Creo', form: 'Terram', baseEffectId: 'crte-1'), isTrue);
      expect(scope.appliesTo(technique: 'Muto', form: 'Ignem', baseEffectId: 'x'), isFalse);
    });

    test('technique-only scope matches any form with that technique', () {
      const scope = ModifierScope(technique: 'Rego');
      expect(scope.appliesTo(technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4'), isTrue);
      expect(scope.appliesTo(technique: 'Creo', form: 'Terram', baseEffectId: 'crte-1'), isFalse);
    });

    test('technique and form together require both to match', () {
      const scope = ModifierScope(technique: 'Creo', form: 'Auram');
      expect(scope.appliesTo(technique: 'Creo', form: 'Auram', baseEffectId: 'crau-3a'), isTrue);
      expect(scope.appliesTo(technique: 'Creo', form: 'Ignem', baseEffectId: 'x'), isFalse);
      expect(scope.appliesTo(technique: 'Perdo', form: 'Auram', baseEffectId: 'x'), isFalse);
    });

    test('effectIds narrows to listed effects only', () {
      const scope = ModifierScope(effectIds: ['rrhe-10b', 'rrig-3c', 'rete-4']);
      expect(scope.appliesTo(technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4'), isTrue);
      expect(scope.appliesTo(technique: 'Rego', form: 'Terram', baseEffectId: 'rete-1'), isFalse);
    });

    test('effectIds does not match when no base effect is selected yet', () {
      const scope = ModifierScope(effectIds: ['rete-4']);
      expect(scope.appliesTo(technique: 'Rego', form: 'Terram', baseEffectId: null), isFalse);
    });

    test('excludeTechniques rejects a listed technique even when form matches', () {
      // "Intellego spells are not affected by Target size" — core rules.
      const scope = ModifierScope(form: 'Corpus', excludeTechniques: ['Intellego']);

      expect(scope.appliesTo(technique: 'Creo', form: 'Corpus', baseEffectId: 'e1'), isTrue);
      expect(scope.appliesTo(technique: 'Intellego', form: 'Corpus', baseEffectId: 'e1'), isFalse);
    });
  });

  group('Modifier', () {
    test('optionById returns the option, or null when absent', () {
      final modifier = _mod();
      expect(modifier.optionById('mat-stone')?.magnitude, 1);
      expect(modifier.optionById('no-such-option'), isNull);
    });

    test('toMap/fromMap round-trip preserves both selection modes', () {
      for (final mode in ModifierSelectionMode.values) {
        final restored = Modifier.fromMap(_mod(mode: mode).toMap());
        expect(restored.selectionMode, mode, reason: 'mode $mode did not survive the round-trip');
        expect(restored.options.length, 3);
        expect(restored.options[2].magnitude, 2);
      }
    });

    test('toMap/fromMap round-trip preserves scope', () {
      const scope = ModifierScope(
          technique: 'Rego',
          form: 'Terram',
          effectIds: ['rete-4'],
          excludeTechniques: ['Intellego']);
      final restored = Modifier.fromMap(_mod(scope: scope).toMap());

      expect(restored.scope.technique, 'Rego');
      expect(restored.scope.form, 'Terram');
      expect(restored.scope.effectIds, ['rete-4']);
      expect(restored.scope.excludeTechniques, ['Intellego']);
    });

    test('toMap/fromMap round-trip preserves an option baseIndividual', () {
      final modifier = Modifier(
        id: 'terram-material',
        name: 'Material difficulty',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
        options: [
          ModifierOption(
              id: 'mat-gemstone', label: 'Gemstone', magnitude: 2, baseIndividual: 'one cubic inch'),
        ],
        source: 'built-in',
      );

      final restored = Modifier.fromMap(modifier.toMap());

      expect(restored.optionById('mat-gemstone')?.baseIndividual, 'one cubic inch');
    });

    test('baseIndividual is null when an option does not define one', () {
      expect(_mod().optionById('mat-dirt')?.baseIndividual, isNull);
    });

    test('fromMap throws a FormatException naming the valid modes when selectionMode is unknown', () {
      final map = _mod().toMap();
      map['selectionMode'] = 'exclusive';

      expect(
        () => Modifier.fromMap(map),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            allOf(contains('exclusive'), contains('single'), contains('multi')))),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/modifier_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/models/modifier.dart': The system cannot find the file specified.`

- [ ] **Step 3: Write the implementation**

Create `lib/models/modifier.dart`:

```dart
import 'package:eruditus/utils/map_serialization.dart';

enum ModifierSelectionMode { single, multi }

ModifierSelectionMode _selectionModeFromName(String name) {
  for (final mode in ModifierSelectionMode.values) {
    if (mode.name == name) return mode;
  }
  throw FormatException(
    "Modifier.fromMap: unknown selectionMode '$name' (expected one of: "
    "${ModifierSelectionMode.values.map((m) => m.name).join(', ')})",
  );
}

/// One rung of a modifier: a choice the caster can make, costing [magnitude].
///
/// [baseIndividual] records what one Individual is when this option is chosen
/// — "one cubic inch" for gemstones, "a single dose" for poisons. It is the
/// quantity a Size ladder multiplies, and carries no magnitude of its own.
class ModifierOption {
  final String id;
  final String label;
  final String? description;
  final int magnitude;
  final String? baseIndividual;

  ModifierOption({
    required this.id,
    required this.label,
    this.description,
    required this.magnitude,
    this.baseIndividual,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'description': description,
        'magnitude': magnitude,
        'baseIndividual': baseIndividual,
      };

  factory ModifierOption.fromMap(Map<String, dynamic> map) => ModifierOption(
        id: requireField<String>(map, 'id', 'ModifierOption'),
        label: requireField<String>(map, 'label', 'ModifierOption'),
        description: map['description'] as String?,
        magnitude: requireField<int>(map, 'magnitude', 'ModifierOption'),
        baseIndividual: map['baseIndividual'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ModifierOption && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Which spells a modifier is offered for. A null [technique] or [form] is a
/// wildcard; an empty [effectIds] means any effect within that technique/form.
///
/// [excludeTechniques] carves out Techniques the modifier never applies to,
/// which a positive [technique] match cannot express. The Size ladders use it
/// for Intellego, which the rules exempt from Target size across every Form.
class ModifierScope {
  final String? technique;
  final String? form;
  final List<String> effectIds;
  final List<String> excludeTechniques;

  const ModifierScope({
    this.technique,
    this.form,
    this.effectIds = const [],
    this.excludeTechniques = const [],
  });

  bool appliesTo({String? technique, String? form, String? baseEffectId}) {
    if (technique != null && excludeTechniques.contains(technique)) return false;
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
      };

  factory ModifierScope.fromMap(Map<String, dynamic> map) => ModifierScope(
        technique: map['technique'] as String?,
        form: map['form'] as String?,
        effectIds: List<String>.from(map['effectIds'] as List? ?? const []),
        excludeTechniques:
            List<String>.from(map['excludeTechniques'] as List? ?? const []),
      );
}

/// A named set of magnitude-costing options offered for a scoped set of spells.
/// [selectionMode] decides whether the options are exclusive or cumulative.
class Modifier {
  final String id;
  final String name;
  final String? description;
  final ModifierSelectionMode selectionMode;
  final ModifierScope scope;
  final List<ModifierOption> options;
  final String source; // 'built-in' or 'user-created'

  Modifier({
    required this.id,
    required this.name,
    this.description,
    required this.selectionMode,
    required this.scope,
    required this.options,
    required this.source,
  });

  ModifierOption? optionById(String optionId) {
    for (final option in options) {
      if (option.id == optionId) return option;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'selectionMode': selectionMode.name,
        'scope': scope.toMap(),
        'options': options.map((o) => o.toMap()).toList(),
        'source': source,
      };

  factory Modifier.fromMap(Map<String, dynamic> map) => Modifier(
        id: requireField<String>(map, 'id', 'Modifier'),
        name: requireField<String>(map, 'name', 'Modifier'),
        description: map['description'] as String?,
        selectionMode:
            _selectionModeFromName(requireField<String>(map, 'selectionMode', 'Modifier')),
        scope: ModifierScope.fromMap(
            requireField<Map<String, dynamic>>(map, 'scope', 'Modifier')),
        options: requireField<List>(map, 'options', 'Modifier')
            .map((o) => ModifierOption.fromMap(o as Map<String, dynamic>))
            .toList(),
        source: requireField<String>(map, 'source', 'Modifier'),
      );

  // Value equality by id — see BaseEffect for why this matters (reloaded
  // ConfigurationBloc state produces fresh, non-identical instances).
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Modifier && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/modifier_test.dart`
Expected: PASS — `All tests passed!` (13 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/models/modifier.dart test/models/modifier_test.dart
git commit -m "feat: add Modifier model with scoped, magnitude-bearing options"
```

---

### Task 2: Load modifiers from asset data

**Files:**
- Create: `assets/data/modifiers.json`
- Modify: `lib/data/datasources/asset_data_loader.dart`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: `Modifier.fromMap` (Task 1)
- Produces: `AssetDataLoader.loadModifiers()` returning `Future<List<Modifier>>`

This task ships only the 3 migrated complexity definitions. The remaining 15 arrive in Tasks 11–12, so the file has a real user from here on without blocking on rulebook extraction.

- [ ] **Step 1: Create the asset file**

Create `assets/data/modifiers.json`. The three groups below carry the same ids, descriptions and magnitudes as the current `special_factors.json` entries, so the 10 built-in spells that reference them keep their verified levels:

```json
[
  {
    "id": "crim-complexity",
    "name": "Complexity",
    "description": "Creo Imaginem complexity factors",
    "selectionMode": "multi",
    "scope": { "technique": "Creo", "form": "Imaginem", "effectIds": [], "excludeTechniques": [] },
    "source": "built-in",
    "options": [
      {
        "id": "crim-sensory-complexity",
        "label": "Increasing Sensory Complexity",
        "description": "Moving visual image or clear words instead of noise",
        "magnitude": 1
      },
      {
        "id": "crim-directed-image",
        "label": "Directed Image (Concentration)",
        "description": "Image moves or makes noise at your direction as you concentrate",
        "magnitude": 2
      },
      {
        "id": "crim-intricate-design",
        "label": "Intricate Design",
        "description": "Very intricate images, e.g. an intricately ornamented bridge",
        "magnitude": 1
      }
    ]
  },
  {
    "id": "peim-complexity",
    "name": "Complexity",
    "description": "Perdo Imaginem complexity factors",
    "selectionMode": "multi",
    "scope": { "technique": "Perdo", "form": "Imaginem", "effectIds": [], "excludeTechniques": [] },
    "source": "built-in",
    "options": [
      {
        "id": "peim-changing-image",
        "label": "Changing Image",
        "description": "Destroying or dulling an image that changes, rather than a static one",
        "magnitude": 1
      }
    ]
  },
  {
    "id": "reim-complexity",
    "name": "Complexity",
    "description": "Rego Imaginem complexity factors",
    "selectionMode": "multi",
    "scope": { "technique": "Rego", "form": "Imaginem", "effectIds": [], "excludeTechniques": [] },
    "source": "built-in",
    "options": [
      {
        "id": "reim-changing-image",
        "label": "Changing Image",
        "description": "Moving an image that changes, rather than a static one",
        "magnitude": 1
      },
      {
        "id": "reim-moved-image-matches",
        "label": "Moved Image Matches Changes",
        "description": "The moved image continues to match changes in the original",
        "magnitude": 1
      },
      {
        "id": "reim-additional-senses",
        "label": "Additional Senses Affected",
        "description": "Add one magnitude per additional sense beyond the guideline's default",
        "magnitude": 1
      }
    ]
  }
]
```

- [ ] **Step 2: Confirm the asset is already declared to Flutter**

Run: `grep -n "assets/data" pubspec.yaml`
Expected: a line registering the `assets/data/` directory. If it lists individual files rather than the directory, add `    - assets/data/modifiers.json` alongside the others.

- [ ] **Step 3: Write the failing test**

Append to `test/data/datasources/asset_data_loader_test.dart`, inside `main()`:

```dart
  test('loadModifiers loads the built-in modifier definitions', () async {
    final modifiers = await loader.loadModifiers();

    expect(modifiers, isNotEmpty);
    expect(modifiers.every((m) => m.source == 'built-in'), isTrue);

    final creoImaginem = modifiers.firstWhere((m) => m.id == 'crim-complexity');
    expect(creoImaginem.selectionMode, ModifierSelectionMode.multi);
    expect(creoImaginem.scope.technique, 'Creo');
    expect(creoImaginem.scope.form, 'Imaginem');
    expect(creoImaginem.optionById('crim-directed-image')?.magnitude, 2);
  });

  test('every modifier option id is unique across all modifiers', () async {
    final modifiers = await loader.loadModifiers();
    final ids = [for (final m in modifiers) for (final o in m.options) o.id];

    expect(ids.length, ids.toSet().length,
        reason: 'duplicate option ids would make selections ambiguous');
  });
```

Add to that file's imports:

```dart
import 'package:eruditus/models/modifier.dart';
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — `The method 'loadModifiers' isn't defined for the class 'AssetDataLoader'.`

- [ ] **Step 5: Add the loader method**

In `lib/data/datasources/asset_data_loader.dart`, add the import:

```dart
import 'package:eruditus/models/modifier.dart';
```

and the method, after `loadSpecialFactors`:

```dart
  Future<List<Modifier>> loadModifiers() async {
    final jsonString = await rootBundle.loadString('assets/data/modifiers.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => Modifier.fromMap(e as Map<String, dynamic>)).toList();
  }
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: 2 new tests PASS. The file still reports its 2 known pre-existing failures (`loadBaseEffects loads all 38 built-in base effects`, `every spell's referenced ids exist in the built-in catalogs`) — that is the documented baseline, not a regression.

- [ ] **Step 7: Commit**

```bash
git add assets/data/modifiers.json lib/data/datasources/asset_data_loader.dart test/data/datasources/asset_data_loader_test.dart
git commit -m "feat: load modifier definitions from asset data"
```

---

### Task 3: Persist and surface modifiers through configuration

**Files:**
- Modify: `lib/data/database/app_database.dart`, `lib/data/datasources/local_configuration_datasource.dart`, `lib/data/repositories/configuration_repository.dart`, `lib/bloc/configuration/configuration_state.dart`, `lib/bloc/configuration/configuration_bloc.dart`
- Test: `test/data/datasources/local_configuration_datasource_test.dart`, `test/data/repositories/configuration_repository_test.dart`

**Interfaces:**
- Consumes: `Modifier` (Task 1), `AssetDataLoader.loadModifiers()` (Task 2)
- Produces: `LocalConfigurationDatasource.insertCustomModifier(Modifier)`, `.deleteCustomModifier(String id)`, `.getAllCustomModifiers()`; `ConfigurationRepository.getAllModifiers()`; `ConfigurationState.modifiers` of type `List<Modifier>`

`ConfigurationState.factors` stays for now and is removed in Task 10.

- [ ] **Step 1: Write the failing datasource test**

Append to `test/data/datasources/local_configuration_datasource_test.dart`, inside `main()`:

```dart
  test('custom modifiers round-trip through the database', () async {
    final modifier = Modifier(
      id: 'custom-m1',
      name: 'House size rule',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(form: 'Terram'),
      options: [ModifierOption(id: 'custom-m1-big', label: 'Big', magnitude: 2)],
      source: 'user-created',
    );

    await datasource.insertCustomModifier(modifier);
    final all = await datasource.getAllCustomModifiers();

    expect(all.length, 1);
    expect(all.first.id, 'custom-m1');
    expect(all.first.scope.form, 'Terram');
    expect(all.first.optionById('custom-m1-big')?.magnitude, 2);

    await datasource.deleteCustomModifier('custom-m1');
    expect(await datasource.getAllCustomModifiers(), isEmpty);
  });
```

Add to that file's imports:

```dart
import 'package:eruditus/models/modifier.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/datasources/local_configuration_datasource_test.dart`
Expected: FAIL — `The method 'insertCustomModifier' isn't defined`.

- [ ] **Step 3: Add the schema and bump the version**

In `lib/data/database/app_database.dart`, change the version constant:

```dart
  static const int _databaseVersion = 2;
```

Add an `onUpgrade` immediately after the `onCreate` closure, inside `OpenDatabaseOptions`:

```dart
        // Backward compatibility is not a goal for this prototype. Rather than
        // translate stored spells whose shape has changed, drop everything and
        // rebuild: destructive, but self-healing and explicit, where a silent
        // schema mismatch would fail confusingly at read time.
        onUpgrade: (db, oldVersion, newVersion) async {
          for (final table in const [
            'spells',
            'custom_effects',
            'custom_parameters',
            'custom_factors',
            'custom_modifiers',
          ]) {
            await db.execute('DROP TABLE IF EXISTS $table');
          }
          await _createSchema(db);
        },
```

Extract the schema into a private static method so both paths share it. Replace the whole `onCreate:` closure with `onCreate: (db, version) => _createSchema(db),` and add this method to the `AppDatabase` class:

```dart
  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE spells (
        id TEXT PRIMARY KEY,
        name TEXT,
        technique TEXT NOT NULL,
        form TEXT NOT NULL,
        source TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_effects (
        id TEXT PRIMARY KEY,
        technique TEXT NOT NULL,
        form TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_parameters (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_factors (
        id TEXT PRIMARY KEY,
        technique TEXT NOT NULL,
        form TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_modifiers (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
  }
```

`custom_factors` is still created here because `SpecialFactor` is not removed until Task 10; that task deletes this statement and leaves the table only in the `onUpgrade` drop list.

- [ ] **Step 4: Add the datasource methods**

In `lib/data/datasources/local_configuration_datasource.dart`, add the import:

```dart
import 'package:eruditus/models/modifier.dart';
```

and the methods:

```dart
  Future<void> insertCustomModifier(Modifier modifier) async {
    await database.db.insert('custom_modifiers', {
      'id': modifier.id,
      'data': jsonEncode(modifier.toMap()),
    });
  }

  Future<void> deleteCustomModifier(String id) async {
    await database.db.delete('custom_modifiers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Modifier>> getAllCustomModifiers() async {
    final rows = await database.db.query('custom_modifiers');
    return rows
        .map((row) => Modifier.fromMap(jsonDecode(row['data'] as String) as Map<String, dynamic>))
        .toList();
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/datasources/local_configuration_datasource_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 6: Write the failing repository test**

Append to `test/data/repositories/configuration_repository_test.dart`, inside `main()`:

```dart
  test('getAllModifiers combines built-in and custom modifiers', () async {
    await repository.addCustomModifier(Modifier(
      id: 'custom-m1',
      name: 'House rule',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(form: 'Ignem'),
      options: [ModifierOption(id: 'custom-m1-a', label: 'A', magnitude: 1)],
      source: 'user-created',
    ));

    final all = await repository.getAllModifiers();

    expect(all.any((m) => m.id == 'crim-complexity'), isTrue, reason: 'built-in');
    expect(all.any((m) => m.id == 'custom-m1'), isTrue, reason: 'custom');
  });
```

Add the import `package:eruditus/models/modifier.dart` to that file.

- [ ] **Step 7: Add the repository methods**

In `lib/data/repositories/configuration_repository.dart`, add the import and:

```dart
  Future<List<Modifier>> getAllModifiers() async {
    final builtIn = await assetLoader.loadModifiers();
    final custom = await configDatasource.getAllCustomModifiers();
    return [...builtIn, ...custom];
  }

  Future<void> addCustomModifier(Modifier modifier) =>
      configDatasource.insertCustomModifier(modifier);
  Future<void> deleteCustomModifier(String id) =>
      configDatasource.deleteCustomModifier(id);
```

- [ ] **Step 8: Surface modifiers on ConfigurationState**

In `lib/bloc/configuration/configuration_state.dart`, add the import, a `final List<Modifier> modifiers;` field defaulting to `const []`, a `modifiers` parameter on the constructor and on `copyWith`, and add `modifiers` to `props`.

In `lib/bloc/configuration/configuration_bloc.dart`, load them in both `ConfigurationRequested` and `_reload`:

```dart
        final modifiers = await configRepository.getAllModifiers();
```

and pass `modifiers: modifiers` to both `emit(state.copyWith(...))` calls that set `status: ConfigurationStatus.loaded`.

- [ ] **Step 9: Add the add/delete events**

The spec keeps this plumbing as the seam user-authored modifiers will use later, so it is renamed rather than dropped. In `lib/bloc/configuration/configuration_event.dart`, add the import for `modifier.dart` and:

```dart
class CustomModifierAdded extends ConfigurationEvent {
  final Modifier modifier;
  const CustomModifierAdded(this.modifier);
  @override
  List<Object?> get props => [modifier];
}

class CustomModifierDeleted extends ConfigurationEvent {
  final String id;
  const CustomModifierDeleted(this.id);
  @override
  List<Object?> get props => [id];
}
```

In `lib/bloc/configuration/configuration_bloc.dart`, add the branches alongside the existing factor ones:

```dart
    } else if (event is CustomModifierAdded) {
      await configRepository.addCustomModifier(event.modifier);
      await _reload(emit);
    } else if (event is CustomModifierDeleted) {
      await configRepository.deleteCustomModifier(event.id);
      await _reload(emit);
```

- [ ] **Step 10: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

- [ ] **Step 11: Commit**

```bash
git add lib/data lib/bloc/configuration test/data
git commit -m "feat: persist and surface modifiers through the configuration layer"
```

---

### Task 4: Add selectedModifiers to Spell and SpellDraft

**Files:**
- Modify: `lib/models/spell.dart`, `assets/data/spell_library.json`
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Produces: `Spell.selectedModifiers` and `SpellDraft.selectedModifiers`, both `Map<String, List<String>>`; `SpellDraft.copyWith({Map<String, List<String>>? selectedModifiers, ...})`

`selectedSpecialFactorIds` remains alongside until Task 10 so every intermediate task leaves a compiling tree and a green suite.

- [ ] **Step 1: Write the failing test**

Append to `test/models/spell_test.dart`, inside the `'Spell Model'` group:

```dart
    test('selectedModifiers survives a toMap/fromMap round-trip', () {
      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        technique: 'Rego',
        form: 'Terram',
        baseEffect: BaseEffect(
          id: 'rete-4', technique: 'Rego', form: 'Terram',
          description: 'Transport a non-living object', baseLevel: 4, source: 'built-in',
        ),
        range: SelectedParameter(
          parameterId: 'p1',
          parameter: Parameter(id: 'p1', name: 'Voice', category: 'Range', magnitude: 2, source: 'built-in'),
        ),
        duration: SelectedParameter(
          parameterId: 'p2',
          parameter: Parameter(id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in'),
        ),
        target: SelectedParameter(
          parameterId: 'p3',
          parameter: Parameter(id: 'p3', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in'),
        ),
        selectedSpecialFactorIds: const [],
        selectedModifiers: const {
          'terram-material': ['mat-metal'],
          'rego-transport-distance': ['dist-500-paces'],
        },
        requisites: const [],
        source: 'user-created',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = Spell.fromMap(spell.toMap());

      expect(restored.selectedModifiers['terram-material'], ['mat-metal']);
      expect(restored.selectedModifiers['rego-transport-distance'], ['dist-500-paces']);
    });

    test('fromMap defaults selectedModifiers to an empty map when absent', () {
      final map = Spell(
        id: 'spell-2', technique: 'Creo', form: 'Ignem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Ignem',
          description: 'Create flame', baseLevel: 10, source: 'built-in',
        ),
        range: SelectedParameter(
          parameterId: 'p1',
          parameter: Parameter(id: 'p1', name: 'Personal', category: 'Range', magnitude: 0, source: 'built-in'),
        ),
        duration: SelectedParameter(
          parameterId: 'p2',
          parameter: Parameter(id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'built-in'),
        ),
        target: SelectedParameter(
          parameterId: 'p3',
          parameter: Parameter(id: 'p3', name: 'Individual', category: 'Target', magnitude: 0, source: 'built-in'),
        ),
        selectedSpecialFactorIds: const [],
        requisites: const [],
        source: 'built-in',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ).toMap();
      map.remove('selectedModifiers');

      expect(Spell.fromMap(map).selectedModifiers, isEmpty);
    });

    test('SpellDraft.copyWith replaces selectedModifiers wholesale', () {
      final draft = SpellDraft(
        technique: 'Rego',
        form: 'Terram',
        selectedModifiers: const {'terram-material': ['mat-stone']},
      );

      final updated = draft.copyWith(selectedModifiers: const {'terram-material': ['mat-metal']});

      expect(updated.selectedModifiers['terram-material'], ['mat-metal']);
      expect(draft.selectedModifiers['terram-material'], ['mat-stone'], reason: 'original unchanged');
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — `No named parameter with the name 'selectedModifiers'.`

- [ ] **Step 3: Add the field to Spell**

In `lib/models/spell.dart`, on `Spell`: add the field, constructor parameter, `toMap` entry and `fromMap` read.

```dart
  final Map<String, List<String>> selectedModifiers;
```

```dart
    this.selectedModifiers = const {},
```

In `toMap()`:

```dart
    'selectedModifiers': selectedModifiers.map((k, v) => MapEntry(k, v)),
```

In `fromMap`:

```dart
    selectedModifiers: (map['selectedModifiers'] as Map?)?.map(
          (k, v) => MapEntry(k as String, List<String>.from(v as List)),
        ) ??
        const {},
```

- [ ] **Step 4: Add the field to SpellDraft**

Add the same field to `SpellDraft` with a `Map<String, List<String>>? selectedModifiers` constructor parameter defaulting via `selectedModifiers = selectedModifiers ?? {}`, pass it through `toSpell()`, and add it to `copyWith` as `selectedModifiers ?? this.selectedModifiers`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/models/spell_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 6: Migrate the 10 built-in spells that reference factors**

Run this script to rewrite the asset, mapping each old factor id to its new modifier group:

```bash
python - <<'PY'
import json
path = 'assets/data/spell_library.json'
group = {
    'crim-sensory-complexity': 'crim-complexity',
    'crim-directed-image': 'crim-complexity',
    'crim-intricate-design': 'crim-complexity',
    'peim-changing-image': 'peim-complexity',
    'reim-changing-image': 'reim-complexity',
    'reim-moved-image-matches': 'reim-complexity',
    'reim-additional-senses': 'reim-complexity',
}
spells = json.load(open(path))
for spell in spells:
    selected = {}
    for option_id in spell.get('selectedSpecialFactorIds', []):
        selected.setdefault(group[option_id], []).append(option_id)
    spell['selectedModifiers'] = selected
json.dump(spells, open(path, 'w'), indent=2, ensure_ascii=False)
print('migrated', sum(1 for s in spells if s['selectedModifiers']), 'spells')
PY
```

Expected output: `migrated 10 spells`

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

- [ ] **Step 8: Commit**

```bash
git add lib/models/spell.dart assets/data/spell_library.json test/models/spell_test.dart
git commit -m "feat: add selectedModifiers to Spell and SpellDraft"
```

---

### Task 5: Structured level breakdown

**Files:**
- Create: `lib/engine/level_breakdown.dart`
- Modify: `lib/engine/spell_engine.dart`, `lib/bloc/spell_library/spell_library_bloc.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart`
- Test: `test/engine/level_breakdown_test.dart`, `test/engine/spell_engine_test.dart`

**Interfaces:**
- Consumes: `Modifier` (Task 1), `Spell.selectedModifiers` (Task 4)
- Produces: `LevelContribution({required String label, required int magnitude, bool isBase})`; `LevelBreakdown({required int level, required List<LevelContribution> contributions})`; `SpellEngine.allModifiers` (mutable field), `SpellEngine.updateModifiers(List<Modifier>)`, and `SpellEngine.calculateBreakdown({required BaseEffect baseEffect, required SelectedParameter range, required SelectedParameter duration, required SelectedParameter target, required List<String> selectedSpecialFactorIds, required Map<String, List<String>> selectedModifiers, required List<Requisite> requisites})` returning `LevelBreakdown`. The existing `calculateSpellLevel` stays and delegates to `calculateBreakdown(...).level`.

- [ ] **Step 1: Write the failing test**

Create `test/engine/level_breakdown_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';

void main() {
  test('LevelBreakdown exposes its level and contributions in order', () {
    const breakdown = LevelBreakdown(
      level: 10,
      contributions: [
        LevelContribution(label: 'Base effect · image, two senses', magnitude: 2, isBase: true),
        LevelContribution(label: 'Range · Voice', magnitude: 2),
        LevelContribution(label: 'Complexity · Intricate Design', magnitude: 1),
      ],
    );

    expect(breakdown.level, 10);
    expect(breakdown.contributions.first.isBase, isTrue);
    expect(breakdown.contributions.map((c) => c.magnitude).toList(), [2, 2, 1]);
  });

  test('magnitudeTotal sums every non-base contribution', () {
    const breakdown = LevelBreakdown(
      level: 10,
      contributions: [
        LevelContribution(label: 'Base', magnitude: 2, isBase: true),
        LevelContribution(label: 'Range', magnitude: 2),
        LevelContribution(label: 'Target', magnitude: 1),
      ],
    );

    expect(breakdown.magnitudeTotal, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/level_breakdown_test.dart`
Expected: FAIL — cannot find `lib/engine/level_breakdown.dart`.

- [ ] **Step 3: Create the breakdown types**

Create `lib/engine/level_breakdown.dart`:

```dart
/// One line of a spell's level calculation. [magnitude] holds the base level
/// when [isBase] is true, and a magnitude contribution otherwise.
class LevelContribution {
  final String label;
  final int magnitude;
  final bool isBase;

  const LevelContribution({
    required this.label,
    required this.magnitude,
    this.isBase = false,
  });
}

/// A spell's calculated level together with the sources that produced it.
class LevelBreakdown {
  final int level;
  final List<LevelContribution> contributions;

  const LevelBreakdown({required this.level, required this.contributions});

  /// Total magnitude from every non-base contribution. Not displayed in the
  /// UI — see the spec's UI section — but used by tests and by callers that
  /// need the magnitude sum without re-deriving it.
  int get magnitudeTotal => contributions
      .where((c) => !c.isBase)
      .fold(0, (sum, c) => sum + c.magnitude);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/level_breakdown_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Write the failing engine test**

Append to `test/engine/spell_engine_test.dart`, inside the `SpellEngine.calculateSpellLevel` group:

```dart
    test('an adding modifier option raises the level by its magnitude', () {
      final material = Modifier(
        id: 'terram-material',
        name: 'Material difficulty',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
        options: [
          ModifierOption(id: 'mat-dirt', label: 'Dirt', magnitude: 0),
          ModifierOption(id: 'mat-metal', label: 'Metal or gemstone', magnitude: 2),
        ],
        source: 'built-in',
      );
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: [material]);
      final baseEffect = BaseEffect(
        id: 'rete-4', technique: 'Rego', form: 'Terram',
        description: 'Transport a non-living object', baseLevel: 4, source: 'built-in',
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedSpecialFactorIds: const [],
        selectedModifiers: const {'terram-material': ['mat-metal']},
        requisites: const [],
      );

      // Base 4 leaves 1 point of additive capacity; the modifier's 2 magnitude
      // takes 1 additively and 1 at x5: 4 + 1 + 5 = 10.
      expect(breakdown.level, 10);
      expect(
        breakdown.contributions.any((c) => c.label.contains('Metal or gemstone') && c.magnitude == 2),
        isTrue,
      );
    });

    test('an unresolvable modifier option contributes 0 and does not throw', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: const []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 3, source: 'built-in',
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedSpecialFactorIds: const [],
        selectedModifiers: const {'deleted-modifier': ['deleted-option']},
        requisites: const [],
      );

      expect(breakdown.level, 3);
    });

    test('the breakdown lists base, parameters, requisites and modifiers', () {
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: const []);
      final baseEffect = BaseEffect(
        id: '1', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 3, source: 'built-in',
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedSpecialFactorIds: const [],
        selectedModifiers: const {},
        requisites: [Requisite(art: 'Auram', kind: RequisiteKind.adding)],
      );

      expect(breakdown.contributions.first.isBase, isTrue);
      expect(breakdown.contributions.first.magnitude, 3);
      expect(breakdown.contributions.any((c) => c.label.startsWith('Range')), isTrue);
      expect(breakdown.contributions.any((c) => c.label.startsWith('Requisite')), isTrue);
    });
```

Add to that file's imports:

```dart
import 'package:eruditus/models/modifier.dart';
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — `No named parameter with the name 'allModifiers'.`

- [ ] **Step 7: Implement the engine changes**

In `lib/engine/spell_engine.dart`, add imports for `level_breakdown.dart` and `modifier.dart`, add the field and constructor parameter:

```dart
  List<Modifier> allModifiers;
```

```dart
  SpellEngine({
    required this.allSpells,
    required this.allSpecialFactors,
    this.allModifiers = const [],
  });

  void updateModifiers(List<Modifier> modifiers) {
    allModifiers = modifiers;
  }
```

Add the breakdown method, and reduce `calculateSpellLevel` to a delegation:

```dart
  LevelBreakdown calculateBreakdown({
    required BaseEffect baseEffect,
    required SelectedParameter range,
    required SelectedParameter duration,
    required SelectedParameter target,
    required List<String> selectedSpecialFactorIds,
    required Map<String, List<String>> selectedModifiers,
    required List<Requisite> requisites,
  }) {
    final contributions = <LevelContribution>[
      LevelContribution(
          label: 'Base effect · ${baseEffect.description}',
          magnitude: baseEffect.baseLevel,
          isBase: true),
      LevelContribution(
          label: 'Range · ${range.parameter.name}', magnitude: range.parameter.magnitude),
      LevelContribution(
          label: 'Duration · ${duration.parameter.name}', magnitude: duration.parameter.magnitude),
      LevelContribution(
          label: 'Target · ${target.parameter.name}', magnitude: target.parameter.magnitude),
    ];

    for (final requisite in requisites) {
      contributions.add(LevelContribution(
          label: 'Requisite · ${requisite.art}, ${requisite.kind.name}',
          magnitude: requisite.magnitude));
    }

    // A selected id that no longer resolves (a factor or modifier deleted
    // after the spell was saved) contributes 0 rather than throwing. See
    // SpellLibraryBloc.LibraryRequested, which computes this for every saved
    // spell and would otherwise drop the Library tab into its error state.
    for (final id in selectedSpecialFactorIds) {
      for (final factor in allSpecialFactors.where((f) => f.id == id).take(1)) {
        contributions.add(
            LevelContribution(label: 'Factor · ${factor.name}', magnitude: factor.magnitude));
      }
    }

    selectedModifiers.forEach((modifierId, optionIds) {
      for (final modifier in allModifiers.where((m) => m.id == modifierId).take(1)) {
        for (final optionId in optionIds) {
          final option = modifier.optionById(optionId);
          if (option == null) continue;
          contributions.add(LevelContribution(
              label: '${modifier.name} · ${option.label}', magnitude: option.magnitude));
        }
      }
    });

    final magnitudes = [
      for (final contribution in contributions)
        if (!contribution.isBase) contribution.magnitude,
    ];

    return LevelBreakdown(
      level: SpellLevelCalculator.calculate(baseEffect.baseLevel, magnitudes),
      contributions: contributions,
    );
  }

  int calculateSpellLevel({
    required BaseEffect baseEffect,
    required SelectedParameter range,
    required SelectedParameter duration,
    required SelectedParameter target,
    required List<String> selectedSpecialFactorIds,
    Map<String, List<String>> selectedModifiers = const {},
    required List<Requisite> requisites,
  }) =>
      calculateBreakdown(
        baseEffect: baseEffect,
        range: range,
        duration: duration,
        target: target,
        selectedSpecialFactorIds: selectedSpecialFactorIds,
        selectedModifiers: selectedModifiers,
        requisites: requisites,
      ).level;
```

- [ ] **Step 8: Pass selections through the two existing callers**

In `lib/bloc/spell_library/spell_library_bloc.dart`, add `selectedModifiers: s.selectedModifiers,` to the `calculateSpellLevel` call.

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, add `selectedModifiers: state.draft.selectedModifiers,` to both the draft's `calculateSpellLevel` call and the per-suggestion one (using `s.selectedModifiers` for the latter).

- [ ] **Step 9: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

- [ ] **Step 10: Commit**

```bash
git add lib/engine lib/bloc test/engine
git commit -m "feat: calculate a structured level breakdown including modifiers"
```

---

### Task 6: Validation and pruning of modifier selections

**Files:**
- Modify: `lib/engine/spell_engine.dart`
- Test: `test/engine/spell_engine_test.dart`

**Interfaces:**
- Produces: `SpellEngine.pruneModifierSelections({required Map<String, List<String>> selectedModifiers, String? technique, String? form, String? baseEffectId})` returning `Map<String, List<String>>`; a new validation error string `'Only one option may be selected for <name>'`

- [ ] **Step 1: Write the failing test**

Append to `test/engine/spell_engine_test.dart`, inside the `SpellEngine.validateSpellDraft` group:

```dart
    test('fails when a single-select modifier has more than one option chosen', () {
      final material = Modifier(
        id: 'terram-material',
        name: 'Material difficulty',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
        options: [
          ModifierOption(id: 'mat-stone', label: 'Stone', magnitude: 1),
          ModifierOption(id: 'mat-metal', label: 'Metal', magnitude: 2),
        ],
        source: 'built-in',
      );
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: [material]);
      final draft = SpellDraft(
        technique: 'Rego',
        form: 'Terram',
        baseEffect: BaseEffect(
          id: 'rete-4', technique: 'Rego', form: 'Terram',
          description: 'Transport', baseLevel: 4, source: 'built-in',
        ),
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'terram-material': ['mat-stone', 'mat-metal']},
      );

      expect(engine.validateSpellDraft(draft),
          contains('Only one option may be selected for Material difficulty'));
    });

    test('a multi-select modifier with several options chosen is valid', () {
      final complexity = Modifier(
        id: 'crim-complexity',
        name: 'Complexity',
        selectionMode: ModifierSelectionMode.multi,
        scope: const ModifierScope(technique: 'Creo', form: 'Imaginem'),
        options: [
          ModifierOption(id: 'a', label: 'A', magnitude: 1),
          ModifierOption(id: 'b', label: 'B', magnitude: 1),
        ],
        source: 'built-in',
      );
      final engine = SpellEngine(allSpells: [], allSpecialFactors: [], allModifiers: [complexity]);
      final draft = SpellDraft(
        technique: 'Creo',
        form: 'Imaginem',
        baseEffect: BaseEffect(
          id: 'e1', technique: 'Creo', form: 'Imaginem',
          description: 'Image', baseLevel: 2, source: 'built-in',
        ),
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'crim-complexity': ['a', 'b']},
      );

      expect(engine.validateSpellDraft(draft), isEmpty);
    });
  });

  group('SpellEngine.pruneModifierSelections', () {
    final material = Modifier(
      id: 'terram-material',
      name: 'Material difficulty',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
      options: [ModifierOption(id: 'mat-metal', label: 'Metal', magnitude: 2)],
      source: 'built-in',
    );
    final distance = Modifier(
      id: 'rego-transport-distance',
      name: 'Transport distance',
      selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(effectIds: ['rete-4']),
      options: [ModifierOption(id: 'dist-500', label: '500 paces', magnitude: 2)],
      source: 'built-in',
    );
    final engine = SpellEngine(
        allSpells: [], allSpecialFactors: [], allModifiers: [material, distance]);

    test('keeps selections whose modifier still applies', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'terram-material': ['mat-metal']},
        technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4',
      );

      expect(pruned, {'terram-material': ['mat-metal']});
    });

    test('drops selections stranded by a Form change', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'terram-material': ['mat-metal']},
        technique: 'Rego', form: 'Ignem', baseEffectId: null,
      );

      expect(pruned, isEmpty);
    });

    test('drops effect-scoped selections stranded by a base effect change', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'rego-transport-distance': ['dist-500']},
        technique: 'Rego', form: 'Terram', baseEffectId: 'rete-1',
      );

      expect(pruned, isEmpty);
    });

    test('drops selections whose modifier no longer exists at all', () {
      final pruned = engine.pruneModifierSelections(
        selectedModifiers: const {'deleted-modifier': ['x']},
        technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4',
      );

      expect(pruned, isEmpty);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — `The method 'pruneModifierSelections' isn't defined`.

- [ ] **Step 3: Implement validation and pruning**

In `lib/engine/spell_engine.dart`, add to the end of `validateSpellDraft` before `return errors;`:

```dart
    draft.selectedModifiers.forEach((modifierId, optionIds) {
      for (final modifier in allModifiers.where((m) => m.id == modifierId).take(1)) {
        if (modifier.selectionMode == ModifierSelectionMode.single && optionIds.length > 1) {
          errors.add('Only one option may be selected for ${modifier.name}');
        }
      }
    });
```

and add the pruning method:

```dart
  /// Drops any selection whose modifier no longer applies to the draft. A
  /// stranded selection would otherwise keep contributing magnitude invisibly
  /// after the caster changes Technique, Form or base effect.
  Map<String, List<String>> pruneModifierSelections({
    required Map<String, List<String>> selectedModifiers,
    String? technique,
    String? form,
    String? baseEffectId,
  }) {
    final kept = <String, List<String>>{};
    selectedModifiers.forEach((modifierId, optionIds) {
      for (final modifier in allModifiers.where((m) => m.id == modifierId).take(1)) {
        if (modifier.scope.appliesTo(
            technique: technique, form: form, baseEffectId: baseEffectId)) {
          kept[modifierId] = optionIds;
        }
      }
    });
    return kept;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/engine/spell_engine.dart test/engine/spell_engine_test.dart
git commit -m "feat: validate single-select modifiers and prune stranded selections"
```

---

### Task 7: Modifier selection events and pruning in SpellCreationBloc

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_event.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart`, `lib/bloc/spell_creation/spell_creation_state.dart`
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `SpellEngine.pruneModifierSelections`, `SpellEngine.calculateBreakdown` (Tasks 5–6)
- Produces: `ModifierOptionSelected(String modifierId, String optionId)`, `ModifierOptionDeselected(String modifierId, String optionId)`, `AvailableModifiersSynced(List<Modifier> modifiers)`; `SpellCreationState.breakdown` of type `LevelBreakdown?`

- [ ] **Step 1: Write the failing test**

Append to `test/bloc/spell_creation_bloc_test.dart`, inside `main()`:

```dart
  final materialModifier = Modifier(
    id: 'terram-material',
    name: 'Material difficulty',
    selectionMode: ModifierSelectionMode.single,
    scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
    options: [
      ModifierOption(id: 'mat-stone', label: 'Stone', magnitude: 1),
      ModifierOption(id: 'mat-metal', label: 'Metal', magnitude: 2),
    ],
    source: 'built-in',
  );
  final reteEffect = BaseEffect(
    id: 'rete-4', technique: 'Rego', form: 'Terram',
    description: 'Transport a non-living object', baseLevel: 4, source: 'built-in',
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'ModifierOptionSelected on a single-select modifier replaces the previous option',
    build: () => SpellCreationBloc(
      spellEngine: SpellEngine(
          allSpells: const [], allSpecialFactors: const [], allModifiers: [materialModifier]),
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
        allSpecialFactors: const [],
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
            source: 'built-in',
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
          allSpells: const [], allSpecialFactors: const [], allModifiers: [materialModifier]),
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
          allSpells: const [], allSpecialFactors: const [], allModifiers: [materialModifier]),
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
          allSpells: const [], allSpecialFactors: const [], allModifiers: [materialModifier]),
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
```

Add to that file's imports:

```dart
import 'package:eruditus/models/modifier.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL — `Undefined name 'ModifierOptionSelected'.`

- [ ] **Step 3: Add the events**

In `lib/bloc/spell_creation/spell_creation_event.dart`, add the import for `modifier.dart` and:

```dart
class ModifierOptionSelected extends SpellCreationEvent {
  final String modifierId;
  final String optionId;
  const ModifierOptionSelected(this.modifierId, this.optionId);
  @override
  List<Object?> get props => [modifierId, optionId];
}

class ModifierOptionDeselected extends SpellCreationEvent {
  final String modifierId;
  final String optionId;
  const ModifierOptionDeselected(this.modifierId, this.optionId);
  @override
  List<Object?> get props => [modifierId, optionId];
}

/// Dispatched whenever ConfigurationBloc's known modifiers change, so the
/// SpellEngine's option-magnitude lookup stays in sync without a restart.
class AvailableModifiersSynced extends SpellCreationEvent {
  final List<Modifier> modifiers;
  const AvailableModifiersSynced(this.modifiers);
  @override
  List<Object?> get props => [modifiers];
}
```

- [ ] **Step 4: Add breakdown to the state**

In `lib/bloc/spell_creation/spell_creation_state.dart`, add the import for `level_breakdown.dart`, a `final LevelBreakdown? breakdown;` field, its constructor parameter, its `copyWith` parameter, and add it to `props`.

- [ ] **Step 5: Handle the events and prune**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, add a private helper:

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

Wrap the drafts produced by the three scope-changing handlers. For `TechniqueSelected`:

```dart
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withPrunedModifiers(
            state.draft.copyWith(technique: event.technique, baseEffect: null)),
      ));
```

Apply the same wrapping in the `FormSelected` and `BaseEffectSelected` branches.

Add the new branches before `SpellCalculated`:

```dart
    } else if (event is ModifierOptionSelected) {
      final modifier =
          spellEngine.allModifiers.where((m) => m.id == event.modifierId).firstOrNull;
      final current = state.draft.selectedModifiers[event.modifierId] ?? const <String>[];
      final updated = modifier?.selectionMode == ModifierSelectionMode.single
          ? [event.optionId]
          : [...current.where((id) => id != event.optionId), event.optionId];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(selectedModifiers: {
          ...state.draft.selectedModifiers,
          event.modifierId: updated,
        }),
      ));
    } else if (event is ModifierOptionDeselected) {
      final remaining = (state.draft.selectedModifiers[event.modifierId] ?? const <String>[])
          .where((id) => id != event.optionId)
          .toList();
      final updated = {...state.draft.selectedModifiers};
      if (remaining.isEmpty) {
        updated.remove(event.modifierId);
      } else {
        updated[event.modifierId] = remaining;
      }
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(selectedModifiers: updated),
      ));
    } else if (event is AvailableModifiersSynced) {
      spellEngine.updateModifiers(event.modifiers);
```

`firstOrNull` comes from `dart:collection`'s iterable extensions — add `import 'package:collection/collection.dart';` if the analyzer reports it missing, and add `collection` to `pubspec.yaml` dependencies if it is not already a direct dependency.

In `_handleSpellCalculated`, replace the `calculateSpellLevel` call with `calculateBreakdown`, and emit both:

```dart
    final breakdown = spellEngine.calculateBreakdown(
      baseEffect: state.draft.baseEffect!,
      range: state.draft.range!,
      duration: state.draft.duration!,
      target: state.draft.target!,
      selectedSpecialFactorIds: state.draft.selectedSpecialFactorIds,
      selectedModifiers: state.draft.selectedModifiers,
      requisites: state.draft.requisites,
    );
    final level = breakdown.level;
```

and add `breakdown: breakdown,` to the `emit(state.copyWith(status: SpellCreationStatus.calculated, ...))` call.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

- [ ] **Step 8: Commit**

```bash
git add lib/bloc/spell_creation test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: add modifier selection events with scope-aware pruning"
```

---

### Task 8: Modifiers section widget

**Files:**
- Create: `lib/presentation/widgets/modifiers_section.dart`
- Modify: `lib/presentation/screens/spell_creation_screen.dart`
- Test: `test/presentation/widgets/modifiers_section_test.dart`

**Interfaces:**
- Consumes: `Modifier`, `ModifierSelectionMode` (Task 1); `ModifierOptionSelected`, `ModifierOptionDeselected` (Task 7)
- Produces: `ModifiersSection({required List<Modifier> modifiers, required Map<String, List<String>> selected, required void Function(String modifierId, String optionId) onSelect, required void Function(String modifierId, String optionId) onDeselect})`

Widget keys: `modifiers-summary`, `modifiers-expand-toggle`, `modifier-dropdown-<modifierId>`, `modifier-checkbox-<optionId>`.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/modifiers_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/presentation/widgets/modifiers_section.dart';

void main() {
  final material = Modifier(
    id: 'terram-material',
    name: 'Material difficulty',
    selectionMode: ModifierSelectionMode.single,
    scope: const ModifierScope(form: 'Terram'),
    options: [
      ModifierOption(id: 'mat-stone', label: 'Stone or glass', magnitude: 1),
      ModifierOption(id: 'mat-metal', label: 'Metal or gemstone', magnitude: 2),
    ],
    source: 'built-in',
  );
  final complexity = Modifier(
    id: 'crim-complexity',
    name: 'Complexity',
    selectionMode: ModifierSelectionMode.multi,
    scope: const ModifierScope(technique: 'Creo', form: 'Imaginem'),
    options: [ModifierOption(id: 'crim-intricate-design', label: 'Intricate Design', magnitude: 1)],
    source: 'built-in',
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<Modifier> modifiers,
    Map<String, List<String>> selected = const {},
    void Function(String, String)? onSelect,
    void Function(String, String)? onDeselect,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModifiersSection(
          modifiers: modifiers,
          selected: selected,
          onSelect: onSelect ?? (_, __) {},
          onDeselect: onDeselect ?? (_, __) {},
        ),
      ),
    ));
  }

  testWidgets('renders nothing when no modifier applies', (tester) async {
    await pump(tester, modifiers: const []);

    expect(find.byKey(const Key('modifiers-summary')), findsNothing);
  });

  testWidgets('collapsed summary shows the selected count and total magnitude', (tester) async {
    await pump(
      tester,
      modifiers: [material],
      selected: const {'terram-material': ['mat-metal']},
    );

    expect(find.byKey(const Key('modifiers-summary')), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    // Collapsed by default: the controls are not built yet.
    expect(find.byKey(const Key('modifier-dropdown-terram-material')), findsNothing);
  });

  testWidgets('collapsed summary shows +0 when nothing is selected', (tester) async {
    await pump(tester, modifiers: [material]);

    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('+0'), findsOneWidget);
  });

  testWidgets('expanding reveals a dropdown for single mode', (tester) async {
    await pump(tester, modifiers: [material]);

    await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('modifier-dropdown-terram-material')), findsOneWidget);
  });

  testWidgets('expanding reveals checkboxes for multi mode', (tester) async {
    await pump(tester, modifiers: [complexity]);

    await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('modifier-checkbox-crim-intricate-design')), findsOneWidget);
  });

  testWidgets('choosing a dropdown option invokes onSelect', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      modifiers: [material],
      onSelect: (modifierId, optionId) => calls.add('$modifierId/$optionId'),
    );

    await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('modifier-dropdown-terram-material')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metal or gemstone (+2)').last);
    await tester.pumpAndSettle();

    expect(calls, ['terram-material/mat-metal']);
  });

  testWidgets('unticking a checkbox invokes onDeselect', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      modifiers: [complexity],
      selected: const {'crim-complexity': ['crim-intricate-design']},
      onDeselect: (modifierId, optionId) => calls.add('$modifierId/$optionId'),
    );

    await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('modifier-checkbox-crim-intricate-design')));
    await tester.pumpAndSettle();

    expect(calls, ['crim-complexity/crim-intricate-design']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/modifiers_section_test.dart`
Expected: FAIL — cannot find `lib/presentation/widgets/modifiers_section.dart`.

- [ ] **Step 3: Implement the widget**

Create `lib/presentation/widgets/modifiers_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:eruditus/models/modifier.dart';

/// The Modifiers section of the spell creation form. Collapsed by default: the
/// summary row carries the selected count and the total magnitude, so a
/// selection pruned by a scope change still moves something the caster can see
/// without expanding.
class ModifiersSection extends StatefulWidget {
  final List<Modifier> modifiers;
  final Map<String, List<String>> selected;
  final void Function(String modifierId, String optionId) onSelect;
  final void Function(String modifierId, String optionId) onDeselect;

  const ModifiersSection({
    super.key,
    required this.modifiers,
    required this.selected,
    required this.onSelect,
    required this.onDeselect,
  });

  @override
  State<ModifiersSection> createState() => _ModifiersSectionState();
}

class _ModifiersSectionState extends State<ModifiersSection> {
  bool _expanded = false;

  int get _selectedCount =>
      widget.selected.values.fold(0, (sum, options) => sum + options.length);

  int get _totalMagnitude {
    var total = 0;
    for (final modifier in widget.modifiers) {
      for (final optionId in widget.selected[modifier.id] ?? const <String>[]) {
        total += modifier.optionById(optionId)?.magnitude ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.modifiers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('modifiers-expand-toggle'),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            key: const Key('modifiers-summary'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modifiers', style: Theme.of(context).textTheme.titleMedium),
                      Text('$_selectedCount selected',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('+$_totalMagnitude', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.modifiers.map((modifier) =>
              modifier.selectionMode == ModifierSelectionMode.single
                  ? _buildSingle(modifier)
                  : _buildMulti(modifier)),
      ],
    );
  }

  Widget _buildSingle(Modifier modifier) {
    final selectedIds = widget.selected[modifier.id] ?? const <String>[];
    // Guard against a stored single-select selection carrying more than one
    // option: the dropdown asserts on a value matching no single item.
    final value = selectedIds.length == 1 ? modifier.optionById(selectedIds.first) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<ModifierOption>(
        key: Key('modifier-dropdown-${modifier.id}'),
        decoration: InputDecoration(labelText: modifier.name),
        initialValue: value,
        items: modifier.options
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text('${option.label} (+${option.magnitude})'),
                ))
            .toList(),
        onChanged: (option) {
          if (option != null) widget.onSelect(modifier.id, option.id);
        },
      ),
    );
  }

  Widget _buildMulti(Modifier modifier) {
    final selectedIds = widget.selected[modifier.id] ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(modifier.name, style: Theme.of(context).textTheme.bodyMedium),
        ...modifier.options.map((option) => CheckboxListTile(
              key: Key('modifier-checkbox-${option.id}'),
              title: Text('${option.label} (+${option.magnitude})'),
              subtitle: option.description == null ? null : Text(option.description!),
              value: selectedIds.contains(option.id),
              onChanged: (isSelected) {
                if (isSelected ?? false) {
                  widget.onSelect(modifier.id, option.id);
                } else {
                  widget.onDeselect(modifier.id, option.id);
                }
              },
            )),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/widgets/modifiers_section_test.dart`
Expected: PASS — `All tests passed!` (7 tests)

- [ ] **Step 5: Wire it into the screen**

In `lib/presentation/screens/spell_creation_screen.dart`, add imports for `modifiers_section.dart` and `modifier.dart`. Compute the applicable modifiers next to `factorsForSelection`:

```dart
          final modifiersForSelection = configState.modifiers
              .where((m) => m.scope.appliesTo(
                    technique: draft.technique,
                    form: draft.form,
                    baseEffectId: draft.baseEffect?.id,
                  ))
              .toList();
```

Insert the section immediately after `_buildRequisitesSection(context, bloc, draft)`:

```dart
                const SizedBox(height: 16),
                ModifiersSection(
                  modifiers: modifiersForSelection,
                  selected: draft.selectedModifiers,
                  onSelect: (modifierId, optionId) =>
                      bloc.add(ModifierOptionSelected(modifierId, optionId)),
                  onDeselect: (modifierId, optionId) =>
                      bloc.add(ModifierOptionDeselected(modifierId, optionId)),
                ),
```

Extend the existing `BlocListener<ConfigurationBloc, ConfigurationState>` so modifier changes also reach the engine:

```dart
      listenWhen: (previous, current) =>
          previous.factors != current.factors || previous.modifiers != current.modifiers,
      listener: (context, configState) {
        context.read<SpellCreationBloc>().add(AvailableFactorsSynced(configState.factors));
        context.read<SpellCreationBloc>().add(AvailableModifiersSynced(configState.modifiers));
      },
```

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others. If `spell_creation_screen_test.dart` or `spell_creation_screen_configuration_sync_test.dart` now fail on a missing `AvailableModifiersSynced` verification, add `registerFallbackValue` coverage as those files already do for other events.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation test/presentation/widgets/modifiers_section_test.dart
git commit -m "feat: add collapsible modifiers section to the spell creation screen"
```

---

### Task 9: Level breakdown card

**Files:**
- Create: `lib/presentation/widgets/level_breakdown_card.dart`
- Modify: `lib/presentation/screens/spell_creation_screen.dart`
- Test: `test/presentation/widgets/level_breakdown_card_test.dart`

**Interfaces:**
- Consumes: `LevelBreakdown`, `LevelContribution` (Task 5)
- Produces: `LevelBreakdownCard({required LevelBreakdown breakdown})`

Widget keys: `level-breakdown-card`, `breakdown-total`.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/level_breakdown_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/presentation/widgets/level_breakdown_card.dart';

void main() {
  const breakdown = LevelBreakdown(
    level: 10,
    contributions: [
      LevelContribution(label: 'Base effect · image, two senses', magnitude: 2, isBase: true),
      LevelContribution(label: 'Range · Voice', magnitude: 2),
      LevelContribution(label: 'Duration · Momentary', magnitude: 0),
      LevelContribution(label: 'Material difficulty · Metal or gemstone', magnitude: 2),
    ],
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: LevelBreakdownCard(breakdown: breakdown)),
    ));
  }

  testWidgets('shows the calculated level', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('level-breakdown-card')), findsOneWidget);
    expect(find.byKey(const Key('breakdown-total')), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('lists every contribution, base without a plus sign', (tester) async {
    await pump(tester);

    expect(find.text('Base effect · image, two senses'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Range · Voice'), findsOneWidget);
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+0'), findsOneWidget);
    expect(find.text('Material difficulty · Metal or gemstone'), findsOneWidget);
  });

  testWidgets('does not show a magnitude total', (tester) async {
    await pump(tester);

    // The tier split that would explain a total is deferred, so showing the
    // total alone would invite "why isn't 2 + 4 = 6?".
    expect(find.textContaining('Total magnitude'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/level_breakdown_card_test.dart`
Expected: FAIL — cannot find `lib/presentation/widgets/level_breakdown_card.dart`.

- [ ] **Step 3: Implement the widget**

Create `lib/presentation/widgets/level_breakdown_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:eruditus/engine/level_breakdown.dart';

/// Itemises what produced a spell's level. Deliberately omits the magnitude
/// total and the additive-tier/multiplier split: both are deferred together,
/// because a total shown without the tier arithmetic raises a question only
/// the tier arithmetic answers.
class LevelBreakdownCard extends StatelessWidget {
  final LevelBreakdown breakdown;

  const LevelBreakdownCard({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('level-breakdown-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              key: const Key('breakdown-total'),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Calculated spell level',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${breakdown.level}',
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 12),
            ...breakdown.contributions.map((contribution) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(contribution.label)),
                      Text(contribution.isBase
                          ? '${contribution.magnitude}'
                          : '+${contribution.magnitude}'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/widgets/level_breakdown_card_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Replace the plain level card on the screen**

In `lib/presentation/screens/spell_creation_screen.dart`, add the import and replace the existing `if (showResultsBlock) Card(... 'Calculated Spell Level: ${state.calculatedLevel}' ...)` block with:

```dart
                if (showResultsBlock && state.breakdown != null)
                  LevelBreakdownCard(breakdown: state.breakdown!),
```

- [ ] **Step 6: Update the screen tests that assert the old text**

`test/presentation/screens/spell_creation_screen_test.dart` has a test asserting `find.text('Calculated Spell Level: 20')`. The card no longer renders that string. Replace that test with:

```dart
  testWidgets('renders the level breakdown when status is calculated', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
      ),
      calculatedLevel: 20,
      breakdown: const LevelBreakdown(
        level: 20,
        contributions: [
          LevelContribution(label: 'Base effect · Create flame', magnitude: 10, isBase: true),
          LevelContribution(label: 'Range · Voice', magnitude: 2),
        ],
      ),
    );
    await pumpScreen(tester, state);

    expect(find.byKey(const Key('level-breakdown-card')), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('Range · Voice'), findsOneWidget);
  });
```

and add the import:

```dart
import 'package:eruditus/engine/level_breakdown.dart';
```

The neighbouring test `does not render the calculated-level card before calculation` asserts `find.textContaining('Calculated Spell Level')` finds nothing; change its finder to `find.byKey(const Key('level-breakdown-card'))`.

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation test/presentation
git commit -m "feat: show an itemised level breakdown instead of a bare total"
```

---

### Task 10: Remove SpecialFactor

**Files:**
- Delete: `lib/models/special_factor.dart`, `test/models/special_factor_test.dart`, `assets/data/special_factors.json`
- Modify: `lib/models/spell.dart`, `lib/engine/spell_engine.dart`, `lib/bloc/spell_creation/*`, `lib/bloc/configuration/*`, `lib/data/datasources/*`, `lib/data/repositories/configuration_repository.dart`, `lib/presentation/screens/spell_creation_screen.dart`, `assets/data/spell_library.json`, and every test file referencing `SpecialFactor`

**Interfaces:**
- Produces: no `SpecialFactor` type, no `selectedSpecialFactorIds` field, no `factors` on `ConfigurationState`, no `allSpecialFactors` on `SpellEngine`

The 16 test files listed by `grep -rl "SpecialFactor" test/` all need updating. This is a single mechanical task because Dart will not compile a partially removed type.

- [ ] **Step 1: Confirm the current baseline before deleting anything**

Run: `flutter test 2>&1 | tail -8`
Expected: exactly the 5 documented pre-existing failures. Record the number so Step 6 can be compared against it.

- [ ] **Step 2: Remove the field from the spell assets**

```bash
python - <<'PY'
import json
path = 'assets/data/spell_library.json'
spells = json.load(open(path))
for spell in spells:
    spell.pop('selectedSpecialFactorIds', None)
json.dump(spells, open(path, 'w'), indent=2, ensure_ascii=False)
print('cleaned', len(spells), 'spells')
PY
```

Expected output: `cleaned 27 spells`

- [ ] **Step 3: Delete the model, its test and the old asset**

```bash
git rm lib/models/special_factor.dart test/models/special_factor_test.dart assets/data/special_factors.json
```

- [ ] **Step 4: Remove every remaining reference**

Work through the analyzer until clean. The removals are:

- `lib/models/spell.dart` — drop the `selectedSpecialFactorIds` field, constructor parameter, `toMap` entry, `fromMap` read, `toSpell` pass-through and `copyWith` parameter from both `Spell` and `SpellDraft`.
- `lib/engine/spell_engine.dart` — drop the `allSpecialFactors` field, its constructor parameter, `updateSpecialFactors`, the `selectedSpecialFactorIds` parameters on `calculateBreakdown` and `calculateSpellLevel`, and the factor loop inside `calculateBreakdown`.
- `lib/bloc/spell_creation/spell_creation_event.dart` — delete `SpecialFactorToggled` and `AvailableFactorsSynced`.
- `lib/bloc/spell_creation/spell_creation_bloc.dart` — delete those two branches and the `selectedSpecialFactorIds` arguments.
- `lib/bloc/configuration/configuration_state.dart` — delete the `factors` field, parameter, `copyWith` entry and `props` entry.
- `lib/bloc/configuration/configuration_event.dart` — delete `CustomFactorAdded` and `CustomFactorDeleted`.
- `lib/bloc/configuration/configuration_bloc.dart` — delete those branches and the `getAllSpecialFactors` loads.
- `lib/data/datasources/asset_data_loader.dart` — delete `loadSpecialFactors`.
- `lib/data/datasources/local_configuration_datasource.dart` — delete the three custom-factor methods.
- `lib/data/repositories/configuration_repository.dart` — delete `getAllSpecialFactors`, `addCustomFactor`, `deleteCustomFactor`.
- `lib/data/database/app_database.dart` — drop `custom_factors` from `_createSchema` (leave it in the `onUpgrade` drop list, which is what removes it from existing databases).
- `lib/bloc/spell_library/spell_library_bloc.dart` and `lib/presentation/screens/spell_creation_screen.dart` — drop the factor arguments, the Special Factors UI block and the `AvailableFactorsSynced` dispatch.

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 5: Update the test files**

Run `grep -rl "SpecialFactor\|selectedSpecialFactorIds" test/ integration_test/` and update each. Fixtures constructing `Spell` simply drop the `selectedSpecialFactorIds:` argument; fixtures constructing `SpellEngine` drop `allSpecialFactors:`. The Imaginem behaviour previously covered via factors is now covered by the `crim-complexity` modifier from Task 2.

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: the same 5 pre-existing failures recorded in Step 1, and no others.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: remove SpecialFactor in favour of the unified Modifier model"
```

---

### Task 11: Size ladder definitions

**Files:**
- Modify: `assets/data/modifiers.json`
- Test: `test/data/asset_modifier_integrity_test.dart`

**Interfaces:**
- Produces: 8 modifier definitions with ids `size-<form-lowercase>`, each scoped `{"technique": null, "form": "<Form>", "effectIds": [], "excludeTechniques": ["Intellego"]}`, `selectionMode: "single"`; plus `aquam-base-individual`

**Extraction source:** `C:\Users\idf53\Development\personal\arsm\Ars-Magica-Open-License\reviewed\Ars Magica - Definitive Edition (Core Rules).md`. Read `## Targets and Sizes` (around line 12264) and the `#### Base Individuals` reference table (around line 23277). Locate them with `grep -n` rather than trusting the line numbers, then read the passage with `sed -n 'START,ENDp'` — the file is 25,800 lines and cannot be read whole.

Three rules from that text govern this task, and each contradicts an assumption an earlier draft of this plan made:

1. **The ladder is universal, not per-Form.** "Adding one magnitude (five levels) to the spell multiplies the maximum size of its target by ten." Every ladder therefore runs +0 (base Individual), +1 (×10), +2 (×100), +3 (×1000), +4 (×10,000). Only the *label* of the base rung differs by Form. Do not invent per-Form magnitudes.
2. **Mentem and Vim get no ladder.** Both read "Size modifiers don't apply to … effects with Individual targets." Hence 8, not 10.
3. **Intellego is exempt across every Form**, via `excludeTechniques`.

Every ladder's first rung is the base Individual at magnitude 0, so "no size increase" is selectable rather than requiring an empty selection.

Aquam additionally gets `aquam-base-individual`, a single-select modifier whose five options are **all magnitude 0** — the sub-type fixes what one Individual is, it does not change the level. Terram's equivalent is folded into the material modifiers in Task 12, because there the material choice both costs difficulty and sets the base Individual.

- [ ] **Step 1: Write the failing integrity test**

Create `test/data/asset_modifier_integrity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = AssetDataLoader();

  // Mentem and Vim: "Size modifiers don't apply to ... effects with
  // Individual targets" — core rules, Base Individuals table.
  const sizeExemptForms = ['Mentem', 'Vim'];

  test('every Form except Mentem and Vim has exactly one Size ladder', () async {
    final modifiers = await loader.loadModifiers();
    final sizeLadders = modifiers.where((m) => m.id.startsWith('size-')).toList();

    expect(sizeLadders.length, ArsForms.all.length - sizeExemptForms.length);
    for (final form in ArsForms.all) {
      final ladder = sizeLadders.where((m) => m.scope.form == form);
      if (sizeExemptForms.contains(form)) {
        expect(ladder, isEmpty, reason: '$form is exempt from Size');
        continue;
      }
      expect(ladder.length, 1, reason: '$form should have exactly one Size ladder');
      expect(ladder.first.scope.technique, isNull,
          reason: 'Size applies regardless of Technique, bar the exclusion below');
      expect(ladder.first.selectionMode, ModifierSelectionMode.single);
    }
  });

  test('no Size ladder is offered for Intellego', () async {
    final modifiers = await loader.loadModifiers();

    for (final ladder in modifiers.where((m) => m.id.startsWith('size-'))) {
      expect(ladder.scope.excludeTechniques, contains('Intellego'),
          reason: '${ladder.id}: Intellego spells are not affected by Target size');
      expect(
        ladder.scope.appliesTo(
            technique: 'Intellego', form: ladder.scope.form, baseEffectId: 'any'),
        isFalse,
      );
    }
  });

  test('every Size ladder uses the universal x10 magnitude progression', () async {
    final modifiers = await loader.loadModifiers();

    for (final ladder in modifiers.where((m) => m.id.startsWith('size-'))) {
      final magnitudes = ladder.options.map((o) => o.magnitude).toList();
      expect(magnitudes, List.generate(magnitudes.length, (i) => i),
          reason: '${ladder.id}: adding one magnitude multiplies size by ten, so '
              'rungs must run 0, 1, 2, ... — magnitudes are not per-Form');
    }
  });

  test('every Size ladder names its base Individual on the first rung', () async {
    final modifiers = await loader.loadModifiers();

    for (final ladder in modifiers.where((m) => m.id.startsWith('size-'))) {
      expect(ladder.options.first.baseIndividual, isNotNull,
          reason: '${ladder.id} must say what one Individual is');
    }
  });

  test('Aquam base Individual sub-types carry no magnitude', () async {
    final modifiers = await loader.loadModifiers();
    final aquam = modifiers.firstWhere((m) => m.id == 'aquam-base-individual');

    expect(aquam.options.length, 5);
    expect(aquam.options.every((o) => o.magnitude == 0), isTrue,
        reason: 'a sub-type fixes what one Individual is; it does not change the level');
    expect(aquam.options.every((o) => o.baseIndividual != null), isTrue);
  });

  test('every modifier option id is unique across all modifiers', () async {
    final modifiers = await loader.loadModifiers();
    final ids = [for (final m in modifiers) for (final o in m.options) o.id];

    expect(ids.length, ids.toSet().length);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: FAIL — `Expected: <10> Actual: <0>`.

- [ ] **Step 3: Add the eight Size ladders**

Add 8 entries to `assets/data/modifiers.json`, one for each Form in `ArsForms.all` except Mentem and Vim — so Animal, Aquam, Auram, Corpus, Herbam, Ignem, Imaginem and Terram. Every ladder is identical in structure and magnitudes; only the base rung's `label` and `baseIndividual` change:

```json
  {
    "id": "size-corpus",
    "name": "Size",
    "description": "Each magnitude multiplies the maximum size of the target by ten",
    "selectionMode": "single",
    "scope": {
      "technique": null,
      "form": "Corpus",
      "effectIds": [],
      "excludeTechniques": ["Intellego"]
    },
    "source": "built-in",
    "options": [
      {
        "id": "size-corpus-0",
        "label": "Base Individual",
        "baseIndividual": "an adult human being, up to Size +1",
        "magnitude": 0
      },
      { "id": "size-corpus-1", "label": "Up to 10x base", "magnitude": 1 },
      { "id": "size-corpus-2", "label": "Up to 100x base", "magnitude": 2 },
      { "id": "size-corpus-3", "label": "Up to 1,000x base", "magnitude": 3 },
      { "id": "size-corpus-4", "label": "Up to 10,000x base", "magnitude": 4 }
    ]
  }
```

Base Individuals, taken verbatim from the rulebook's `#### Base Individuals` table:

| Form | `baseIndividual` |
|---|---|
| Animal | a pony-sized animal, Size +1 or lower |
| Aquam | see `aquam-base-individual` below — use "a pool five paces across, two paces deep" for the water default |
| Auram | a weather phenomenon the area inside a standard Boundary |
| Corpus | an adult human being, up to Size +1 |
| Herbam | a plant one pace in each direction |
| Ignem | a large campfire or the hearthfire of a great hall |
| Imaginem | an adult human being — an illusion that size, producing that much noise |
| Terram | see the material modifiers in Task 12 — use "ten cubic paces" for the sand/dirt default |

- [ ] **Step 4: Add the Aquam base-Individual sub-types**

Aquam's five sub-types change what one Individual is without changing the level, so every option is magnitude 0:

```json
  {
    "id": "aquam-base-individual",
    "name": "Liquid type",
    "description": "Which liquid the spell works on, which sets what one Individual is",
    "selectionMode": "single",
    "scope": { "technique": null, "form": "Aquam", "effectIds": [], "excludeTechniques": [] },
    "source": "built-in",
    "options": [
      {
        "id": "aquam-base-water",
        "label": "Water",
        "baseIndividual": "a pool five paces across, two paces deep",
        "magnitude": 0
      },
      {
        "id": "aquam-base-natural",
        "label": "Naturally-occurring liquids",
        "baseIndividual": "a pool two paces across, one pace deep",
        "magnitude": 0
      },
      {
        "id": "aquam-base-processed",
        "label": "Processed liquids",
        "baseIndividual": "a pool one pace across, half a pace deep",
        "magnitude": 0
      },
      {
        "id": "aquam-base-dangerous",
        "label": "Dangerous liquids",
        "baseIndividual": "a puddle half a pace across, a fifth of a pace deep",
        "magnitude": 0
      },
      {
        "id": "aquam-base-poison",
        "label": "Poisons",
        "baseIndividual": "a single dose",
        "magnitude": 0
      }
    ]
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

- [ ] **Step 7: Commit**

```bash
git add assets/data/modifiers.json test/data/asset_modifier_integrity_test.dart
git commit -m "feat: add Size ladders and Aquam base-Individual sub-types"
```

---

### Task 12: Material, unnatural-context and distance definitions

**Files:**
- Modify: `assets/data/modifiers.json`
- Test: `test/data/asset_modifier_integrity_test.dart`

**Interfaces:**
- Produces: `muto-terram-material`, `perdo-terram-material`, `rego-terram-material`, `creo-auram-unnatural`, `rego-transport-distance`

Material difficulty deliberately excludes Creo Terram, whose 5 effects (`crte-1` sand, `crte-3` stone/glass, `crte-5` base metal, `crte-15a` precious metal, `crte-25a` gemstone) model material as the base effect. Scoping to Terram as a whole would wrongly offer a material modifier on top of "Create base metal".

Each material modifier carries **5 options, not 3**: for Terram the material choice is a single axis with two consequences — it costs difficulty magnitude *and* fixes what one Individual is. Base metal, precious metal and gemstone all cost +2 but have base Individuals of one cubic foot, a tenth of that, and one cubic inch respectively, so they cannot be collapsed into a single "metal or gemstone" rung.

- [ ] **Step 1: Write the failing test**

Append to `test/data/asset_modifier_integrity_test.dart`:

```dart
  test('material difficulty covers Muto, Perdo and Rego Terram but not Creo', () async {
    final modifiers = await loader.loadModifiers();
    final material = modifiers.where((m) => m.id.endsWith('-terram-material')).toList();

    expect(material.length, 3);
    expect(material.map((m) => m.scope.technique).toSet(), {'Muto', 'Perdo', 'Rego'});
    expect(material.every((m) => m.scope.form == 'Terram'), isTrue);
    expect(
      material.any((m) => m.scope.appliesTo(technique: 'Creo', form: 'Terram', baseEffectId: 'crte-5')),
      isFalse,
      reason: 'Creo Terram models material as the base effect',
    );
  });

  test('the distance ladder is scoped to its three transport effects', () async {
    final modifiers = await loader.loadModifiers();
    final distance = modifiers.firstWhere((m) => m.id == 'rego-transport-distance');

    expect(distance.scope.effectIds..sort(), ['rete-4', 'rrhe-10b', 'rrig-3c']);
    expect(distance.scope.technique, isNull);
    expect(distance.scope.form, isNull);
  });

  test('every scoped effectId refers to a real base effect', () async {
    final modifiers = await loader.loadModifiers();
    final effectIds = (await loader.loadBaseEffects()).map((e) => e.id).toSet();

    for (final modifier in modifiers) {
      for (final id in modifier.scope.effectIds) {
        expect(effectIds.contains(id), isTrue,
            reason: '${modifier.id} references unknown base effect $id');
      }
    }
  });

  test('rete-4 draws all three of Size, material and distance', () async {
    final modifiers = await loader.loadModifiers();
    final applicable = modifiers
        .where((m) => m.scope.appliesTo(
            technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4'))
        .map((m) => m.id)
        .toList();

    expect(applicable, containsAll(['size-terram', 'rego-terram-material', 'rego-transport-distance']));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: FAIL — `Expected: <3> Actual: <0>`.

- [ ] **Step 3: Add the five definitions**

Append to `assets/data/modifiers.json`. Repeat the material block three times with ids `muto-terram-material`, `perdo-terram-material` and `rego-terram-material`, changing only the id and `scope.technique`; the option ids must differ per block to stay globally unique:

```json
  {
    "id": "rego-terram-material",
    "name": "Material",
    "description": "Base levels are quoted for dirt; harder materials cost magnitudes. The material also sets what one Individual is.",
    "selectionMode": "single",
    "scope": { "technique": "Rego", "form": "Terram", "effectIds": [], "excludeTechniques": [] },
    "source": "built-in",
    "options": [
      {
        "id": "rego-terram-material-dirt",
        "label": "Sand, dirt, mud or clay",
        "baseIndividual": "ten cubic paces",
        "magnitude": 0
      },
      {
        "id": "rego-terram-material-stone",
        "label": "Stone or glass",
        "baseIndividual": "one cubic pace",
        "magnitude": 1
      },
      {
        "id": "rego-terram-material-base-metal",
        "label": "Base metal",
        "baseIndividual": "one cubic foot",
        "magnitude": 2
      },
      {
        "id": "rego-terram-material-precious-metal",
        "label": "Precious metal",
        "baseIndividual": "one tenth of a cubic foot",
        "magnitude": 2
      },
      {
        "id": "rego-terram-material-gemstone",
        "label": "Gemstone",
        "baseIndividual": "one cubic inch",
        "magnitude": 2
      }
    ]
  },
  {
    "id": "creo-auram-unnatural",
    "name": "Unnatural context",
    "description": "Creating a phenomenon in an unnatural fashion costs magnitudes",
    "selectionMode": "single",
    "scope": { "technique": "Creo", "form": "Auram", "effectIds": [], "excludeTechniques": [] },
    "source": "built-in",
    "options": [
      { "id": "creo-auram-unnatural-none", "label": "Natural for the season and place", "magnitude": 0 },
      { "id": "creo-auram-unnatural-slight", "label": "Slightly unnatural", "magnitude": 1 },
      { "id": "creo-auram-unnatural-very", "label": "Very unnatural", "magnitude": 2 },
      { "id": "creo-auram-unnatural-highly", "label": "Highly unnatural", "magnitude": 4 }
    ]
  },
  {
    "id": "rego-transport-distance",
    "name": "Transport distance",
    "description": "The base level covers 5 paces; greater distances cost magnitudes",
    "selectionMode": "single",
    "scope": { "technique": null, "form": null, "effectIds": ["rrhe-10b", "rrig-3c", "rete-4"], "excludeTechniques": [] },
    "source": "built-in",
    "options": [
      { "id": "rego-distance-5-paces", "label": "Up to 5 paces", "magnitude": 0 },
      { "id": "rego-distance-50-paces", "label": "Up to 50 paces", "magnitude": 1 },
      { "id": "rego-distance-500-paces", "label": "Up to 500 paces", "magnitude": 2 },
      { "id": "rego-distance-1-league", "label": "Up to 1 league", "magnitude": 3 },
      { "id": "rego-distance-7-leagues", "label": "Up to 7 leagues", "magnitude": 4 },
      { "id": "rego-distance-arcane", "label": "Somewhere you have an Arcane Connection", "magnitude": 5 }
    ]
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

- [ ] **Step 6: Commit**

```bash
git add assets/data/modifiers.json test/data/asset_modifier_integrity_test.dart
git commit -m "feat: add material, unnatural-context and transport-distance modifiers"
```

---

### Task 13: Terram spells in the built-in library

**Files:**
- Modify: `assets/data/spell_library.json`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Extraction source:** `C:\Users\idf53\Development\personal\arsm\Ars-Magica-Open-License\reviewed\Ars Magica - Definitive Edition (Core Rules).md`. Find the Terram spell list with `grep -n "^##.*Terram Spells"` and read the entries with `sed -n 'START,ENDp'`; take each spell's published level verbatim. All 27 existing library spells are Imaginem, so without these the asset-level "calculated level matches stated level" test never exercises a single-select modifier, Form-only scoping, or 7 of the 8 Size ladders.

Choose 3–4 spells covering: one with a material selection, one with a Size selection, and one carrying both. Each spell's `description` must end with `Level N.` so the existing calculated-vs-stated test can parse it.

- [ ] **Step 1: Write the failing test**

Append to `test/data/datasources/asset_data_loader_test.dart`:

```dart
  test('the library covers more than one Form', () async {
    final spells = await loader.loadSpellLibrary();
    final forms = spells.map((s) => s.form).toSet();

    expect(forms.length, greaterThan(1),
        reason: 'a single-Form library cannot exercise Form-scoped modifiers');
    expect(forms, contains('Terram'));
  });

  test('at least one library spell selects a single-select modifier', () async {
    final spells = await loader.loadSpellLibrary();
    final modifiers = await loader.loadModifiers();
    final singleIds = modifiers
        .where((m) => m.selectionMode == ModifierSelectionMode.single)
        .map((m) => m.id)
        .toSet();

    expect(
      spells.any((s) => s.selectedModifiers.keys.any(singleIds.contains)),
      isTrue,
    );
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — `a single-Form library cannot exercise Form-scoped modifiers`.

- [ ] **Step 3: Add the spells**

Append 3–4 entries to `assets/data/spell_library.json` using the same shape as the existing entries, with `"form": "Terram"`, real base-effect ids from `assets/data/base_effects.json`, and `selectedModifiers` referencing the ids added in Tasks 11–12. At least one must be built on `rete-4` so it carries Size, material and distance together.

- [ ] **Step 4: Verify the stated levels compute**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: the two new tests PASS. `every loaded spell calculates to the level stated in its description` must not newly fail — if it does, a stated level and its selected magnitudes disagree and the spell data is wrong.

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

- [ ] **Step 6: Commit**

```bash
git add assets/data/spell_library.json test/data/datasources/asset_data_loader_test.dart
git commit -m "feat: add Terram spells so the library exercises scoped modifiers"
```

---

### Task 14: Integration coverage for pruning

**Files:**
- Modify: `integration_test/spell_creation_flow_test.dart`

Pruning only manifests on the rebuild that follows a scope change. Mocked widget tests emit no new state, so they are structurally incapable of catching it — the same blind spot that let the add-requisite crash through 6 passing widget tests. This test drives the real bloc.

- [ ] **Step 1: Write the failing test**

Append a new `testWidgets` to `integration_test/spell_creation_flow_test.dart`, following the construction preamble of the existing tests in that file (opening an in-memory `AppDatabase`, building the repositories, engine and three blocs, and pumping `EruditusApp`). Load modifiers into the engine as the app does:

```dart
      final spellEngine = SpellEngine(
        allSpells: allSpells,
        allModifiers: await configRepository.getAllModifiers(),
      );
```

Then the body:

```dart
      Future<void> scrollTo(Finder finder) async {
        await tester.scrollUntilVisible(finder, 200.0,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('technique-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rego').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('form-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terram').last);
      await tester.pumpAndSettle();

      // Expand and choose a material, which only Terram offers.
      await scrollTo(find.byKey(const Key('modifiers-expand-toggle')));
      await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
      await tester.pumpAndSettle();

      await scrollTo(find.byKey(const Key('modifier-dropdown-rego-terram-material')));
      await tester.tap(find.byKey(const Key('modifier-dropdown-rego-terram-material')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Base metal (+2)').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await scrollTo(find.byKey(const Key('modifiers-summary')));
      expect(find.text('+2'), findsOneWidget);

      // Switching Form strands that selection; it must be pruned, and the
      // badge must fall back to +0 rather than silently keeping the magnitude.
      await tester.tap(find.byKey(const Key('form-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignem').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await scrollTo(find.byKey(const Key('modifiers-summary')));
      expect(find.text('+2'), findsNothing);
      expect(find.byKey(const Key('modifier-dropdown-rego-terram-material')), findsNothing);

      await database.close();
```

- [ ] **Step 2: Run the integration suite**

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: FAIL if pruning or the badge is wrong; PASS once correct. Both pre-existing integration tests must also still pass.

- [ ] **Step 3: Fix anything the test catches**

If the badge still reads `+2` after the Form change, the pruning helper is not wired into the `FormSelected` branch — revisit Task 7 Step 5.

- [ ] **Step 4: Run both suites**

Run: `flutter test`
Expected: the 5 documented pre-existing failures and no others.

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: `All tests passed!` (3 tests)

- [ ] **Step 5: Commit**

```bash
git add integration_test/spell_creation_flow_test.dart
git commit -m "test: cover modifier pruning with a real bloc"
```

---

## Notes for the executor

- **The 5 pre-existing failures are the bar, not zero.** Treating a run as clean because it is "mostly green" will hide a regression. Compare the failing set, not just the count.
- **`flutter test` never runs `integration_test/`.** Task 14 is the only place integration coverage is added, but any task that changes the widget tree should re-run the integration suite before its commit.
- **Do not run `flutter analyze` and `flutter test` concurrently.** They contend over `build/`, which produces both a spurious 12-minute analyze and a `sqlite3.dll` file-lock error. Run them in sequence.
- **If a `flutter test` run fails with a `sqlite3.dll` lock**, an orphaned `flutter_tester.exe` is holding it. Kill it and re-run.
