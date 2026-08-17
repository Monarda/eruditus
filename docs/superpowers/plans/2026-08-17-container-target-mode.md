# Container Target Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a spell record whether its container Target is *static* or *dynamic*, per the Definitive Edition's "Container Targets" sidebar, and backfill the 8 Circle wards the Magical Wards rule decides.

**Architecture:** Target *type* (object/container/sense) becomes catalog data on `Parameter`, read from `parameters.json`. The *mode* becomes a per-spell enum on `Spell`, `SpellTemplate` and `SpellDraft`, defaulting to `unstated`. A new validation check forbids a mode on a non-container Target; a separate derived predicate answers "does this spell still owe a ruling", and nothing calls it yet. The 8 ward backfill enters through a committed importer input, because `--write` regenerates both assets.

**Tech Stack:** Flutter/Dart (`flutter_bloc`, `bloc_test`, `mocktail`), Python 3 stdlib importer under `scripts/spell_import/`, sqflite.

**Spec:** `docs/superpowers/specs/2026-08-17-container-target-mode-design.md`

## Global Constraints

- The two mode words are the rulebook's own: enum constants are exactly `static` and `dynamic`, serialized via `.name`. Never rename them to `atCasting`/`ongoing`.
- `ContainerMode.unstated` means **"no decision recorded"**, never "no decision owed". Never add a `notApplicable` member — that state is derived.
- The mode is **level-neutral**. `SpellEngine`, `SpellLevelCalculator` and every level assertion must be untouched by this work.
- **Check 9 tests Target type only.** Momentary must not appear in it. Momentary belongs solely to `spellOwesContainerMode`.
- `target-bloodline` and `target-symbol` annotate as `object`. Bloodline behaves dynamically by its own built-in rule, which is *not* a per-spell choice — do not annotate it `container`.
- Backfill goes in `scripts/spell_import/container_modes.json` as a committed **input**. Never hand-edit `assets/data/spell_library.json` or `assets/data/spell_templates.json` — `--write` regenerates both.
- Full verification is three suites: `flutter test`, `flutter test integration_test/`, and `python -m unittest discover -s scripts/spell_import/tests -t .`. `flutter test` does **not** run `integration_test/`.
- This is a prototype: backward compatibility is not a goal. DB upgrades drop and rebuild.

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `lib/models/target_type.dart` (new) | `TargetType` enum + `targetTypeFromName` | 1 |
| `lib/models/parameter.dart` | Holds `targetType` | 1 |
| `assets/data/parameters.json` | Annotates all 14 Target rows | 1 |
| `lib/models/container_mode.dart` (new) | `ContainerMode` enum + `containerModeFromName` | 2 |
| `lib/models/spell.dart` | Field on `Spell`/`SpellDraft`; check 9; `spellOwesContainerMode` | 2, 3 |
| `lib/models/spell_template.dart` | Field on `SpellTemplate` | 2 |
| `lib/data/database/app_database.dart` | Schema version 8 → 9 | 2 |
| `lib/engine/spell_engine.dart` | Passes `target` to the validator | 3 |
| `lib/models/resolved_spell.dart` | Passes `target` to the validator | 3 |
| `lib/bloc/spell_creation/spell_creation_event.dart` | `ContainerModeSelected` | 4 |
| `lib/bloc/spell_creation/spell_creation_bloc.dart` | Handler, `TargetSelected` pruning, template copy | 4 |
| `lib/presentation/screens/spell_creation_screen.dart` | `_ContainerModeField` segmented control | 5 |
| `scripts/spell_import/catalog.py` | `Catalog.target_type()` | 6 |
| `scripts/spell_import/container_modes.json` (new) | The 8 ward rulings | 6 |
| `scripts/spell_import/extract_spells.py` | Loads and applies the rulings | 6 |
| `.superpowers/todo.md` | Closes item 14 | 7 |

---

### Task 1: Target type as catalog data

**Files:**
- Create: `lib/models/target_type.dart`
- Modify: `lib/models/parameter.dart`
- Modify: `assets/data/parameters.json`
- Test: `test/models/parameter_test.dart`, `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Produces: `enum TargetType { object, container, sense }`; `TargetType targetTypeFromName(String name, String className)`; `Parameter.targetType` of type `TargetType?`.

- [ ] **Step 1: Write the failing tests**

Append to `test/models/parameter_test.dart` (inside the existing top-level `main()`, as a new group):

```dart
  group('targetType', () {
    Map<String, dynamic> base() => {
          'id': 'target-room',
          'name': 'Room',
          'category': 'Target',
          'magnitude': 2,
          'source': 'published',
          'citations': [
            {'bookId': 'arm5-core'}
          ],
        };

    test('parses all three kinds', () {
      for (final kind in TargetType.values) {
        final parameter =
            Parameter.fromMap({...base(), 'targetType': kind.name});
        expect(parameter.targetType, kind);
      }
    });

    test('is null when absent, which is how a Range or Duration row reads', () {
      final parameter = Parameter.fromMap({
        ...base(),
        'id': 'duration-sun',
        'name': 'Sun',
        'category': 'Duration',
      });
      expect(parameter.targetType, isNull);
    });

    test('throws on an unknown kind rather than defaulting', () {
      expect(
        () => Parameter.fromMap({...base(), 'targetType': 'volume'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trips through toMap, and omits the key when null', () {
      final annotated =
          Parameter.fromMap({...base(), 'targetType': 'container'});
      expect(annotated.toMap()['targetType'], 'container');

      final bare = Parameter.fromMap(base());
      expect(bare.toMap().containsKey('targetType'), isFalse);
    });
  });
```

Add the import at the top of the same file:

```dart
import 'package:eruditus/models/target_type.dart';
```

Append to `test/data/datasources/asset_data_loader_test.dart` (a new top-level `test`, beside the existing `requiresVirtue` one):

```dart
  test('every Target declares a targetType, and exactly four are containers',
      () async {
    final parameters = await loader.loadParameters();
    final targets = parameters.where((p) => p.category == 'Target').toList();

    // Hardcoded like the requiresRitual test above, and for the same reason:
    // parameters.json is small and hand-maintained, so a count that drifts
    // silently is the failure mode worth catching.
    expect(targets.length, 14);

    for (final target in targets) {
      expect(target.targetType, isNotNull,
          reason: '${target.id} has no targetType — every Target needs one, '
              'or check 9 silently stops applying to it');
    }

    final containers = targets
        .where((p) => p.targetType == TargetType.container)
        .map((p) => p.id)
        .toSet();
    expect(containers, {
      'target-circle',
      'target-room',
      'target-structure',
      'target-boundary',
    });

    // Bloodline is an object Target that carries its own ongoing rule (a
    // spell "applies to all members of the bloodline born during its
    // duration"), which is the Target's behaviour and not a per-spell design
    // choice. Pinned so nobody later "fixes" it into a container.
    expect(
      parameters.firstWhere((p) => p.id == 'target-bloodline').targetType,
      TargetType.object,
    );
    // Symbol is "essentially a large Group" (Houses of Hermes: Mystery Cults).
    expect(
      parameters.firstWhere((p) => p.id == 'target-symbol').targetType,
      TargetType.object,
    );
  });
```

Add the import at the top of that file:

```dart
import 'package:eruditus/models/target_type.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/parameter_test.dart test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — `target_type.dart` does not exist, so compilation fails.

- [ ] **Step 3: Create the enum**

Create `lib/models/target_type.dart`:

```dart
/// Which of the rulebook's three kinds of Target a parameter is.
///
/// Core Rules line 12120: "There are three types of target: objects,
/// containers, and senses." Each Target then states its own kind (Individual
/// 12122, Circle 12124, Part 12128, Group 12130, Room 12132, Structure 12136,
/// Boundary 12138, senses 12152-12160).
///
/// Only a [container] Target has the static/dynamic distinction — see
/// `ContainerMode`. An [object] Target is always static (12246), and a
/// [sense] Target grants information rather than affecting a volume, so
/// neither offers the choice.
enum TargetType { object, container, sense }

TargetType targetTypeFromName(String name, String className) {
  for (final value in TargetType.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown targetType '$name' (expected one of: "
    "${TargetType.values.map((t) => t.name).join(', ')})",
  );
}
```

- [ ] **Step 4: Add the field to `Parameter`**

In `lib/models/parameter.dart`, add the import:

```dart
import 'package:eruditus/models/target_type.dart';
```

Add the field after `scope` (around line 48):

```dart
  /// Which of the rulebook's three kinds of Target this is, or null when this
  /// parameter is not a Target at all (every Range and Duration row).
  ///
  /// Nullable rather than defaulted: "this is not a Target" and "this is a
  /// Target of unknown kind" are different, and only the first should be
  /// silent. A Target with no annotation is a data bug, caught by
  /// `asset_data_loader_test.dart`, not papered over here.
  ///
  /// Read by `validateSpellAgainstCatalog`'s check 9 and by the creation
  /// screen, which offers the container-mode control only for a container.
  final TargetType? targetType;
```

Add to the constructor parameter list, after `this.scope = const ParameterScope(),`:

```dart
    this.targetType,
```

Add to `toMap`, after the `requiresVirtue` line:

```dart
    if (targetType != null) 'targetType': targetType!.name,
```

Add to `fromMap`, after the `requiresVirtue` line:

```dart
    targetType: map['targetType'] == null
        ? null
        : targetTypeFromName(map['targetType'] as String, 'Parameter'),
```

- [ ] **Step 5: Annotate all 14 Target rows in `assets/data/parameters.json`**

Add a `"targetType"` key to each Target row, immediately after its `"magnitude"`. Exact assignments — this is a transcription of the rulebook, not a judgement, so use these values verbatim:

| id | targetType |
|---|---|
| `target-individual` | `object` |
| `target-part` | `object` |
| `target-group` | `object` |
| `target-bloodline` | `object` |
| `target-symbol` | `object` |
| `target-circle` | `container` |
| `target-room` | `container` |
| `target-structure` | `container` |
| `target-boundary` | `container` |
| `target-taste` | `sense` |
| `target-touch` | `sense` |
| `target-smell` | `sense` |
| `target-hearing` | `sense` |
| `target-vision` | `sense` |

Do **not** add the key to any Range or Duration row.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/models/parameter_test.dart test/data/datasources/asset_data_loader_test.dart`
Expected: PASS

- [ ] **Step 7: Run the full Dart suite**

Run: `flutter test`
Expected: PASS. `Parameter` gained an optional field with a null default, so no existing construction site changes.

- [ ] **Step 8: Commit**

```bash
git add lib/models/target_type.dart lib/models/parameter.dart assets/data/parameters.json test/models/parameter_test.dart test/data/datasources/asset_data_loader_test.dart
git commit -m "feat: annotate Targets with the rulebook's object/container/sense kind"
```

---

### Task 2: The `ContainerMode` field

**Files:**
- Create: `lib/models/container_mode.dart`
- Modify: `lib/models/spell.dart` (`Spell` fields/`toMap`/`fromMap`; `SpellDraft` field/`toSpell`/`copyWith`)
- Modify: `lib/models/spell_template.dart`
- Modify: `lib/data/database/app_database.dart:7`
- Test: `test/models/spell_test.dart`, `test/models/spell_template_test.dart`, `test/models/spell_draft_copy_with_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `enum ContainerMode { unstated, static, dynamic }`; `ContainerMode containerModeFromName(String name, String className)`; `Spell.containerMode`, `SpellTemplate.containerMode`, `SpellDraft.containerMode`, all non-null `ContainerMode` defaulting to `ContainerMode.unstated`; `SpellDraft.copyWith({ContainerMode? containerMode})`.

- [ ] **Step 1: Write the failing tests**

Append to `test/models/spell_test.dart` as a new group inside `main()`. Use whatever fixture helper that file already provides for building a valid `Spell`; the shape below shows the assertions, and `containerMode` is the only field under test:

```dart
  group('containerMode', () {
    test('defaults to unstated', () {
      expect(buildSpell().containerMode, ContainerMode.unstated);
    });

    test('round-trips through toMap/fromMap', () {
      for (final mode in ContainerMode.values) {
        final restored =
            Spell.fromMap(buildSpell(containerMode: mode).toMap());
        expect(restored.containerMode, mode);
      }
    });

    test('serializes to the rulebook words', () {
      expect(buildSpell(containerMode: ContainerMode.static).toMap()['containerMode'],
          'static');
      expect(buildSpell(containerMode: ContainerMode.dynamic).toMap()['containerMode'],
          'dynamic');
    });

    test('a record with no containerMode key reads as unstated', () {
      final map = buildSpell().toMap()..remove('containerMode');
      expect(Spell.fromMap(map).containerMode, ContainerMode.unstated);
    });

    test('throws on an unknown stored value rather than defaulting', () {
      final map = buildSpell().toMap()..['containerMode'] = 'ongoing';
      expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
    });
  });
```

Append the equivalent group to `test/models/spell_template_test.dart`, using that file's own template fixture and `SpellTemplate.fromMap`, asserting the same five behaviours.

Append to `test/models/spell_draft_copy_with_test.dart`:

```dart
  test('copyWith sets the container mode, and omitting it preserves one', () {
    final stated = SpellDraft().copyWith(containerMode: ContainerMode.dynamic);
    expect(stated.containerMode, ContainerMode.dynamic);

    // Omitted means "keep", which is what lets every other handler copyWith
    // the draft without clobbering a stated mode.
    expect(stated.copyWith(summary: 'x').containerMode, ContainerMode.dynamic);

    // Passing unstated explicitly is how TargetSelected clears it. Unlike the
    // nullable fields, this needs no _unset sentinel: unstated is a real
    // non-null value, so `?? this.containerMode` cannot swallow it.
    expect(
      stated.copyWith(containerMode: ContainerMode.unstated).containerMode,
      ContainerMode.unstated,
    );
  });
```

Add to each of the three test files:

```dart
import 'package:eruditus/models/container_mode.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/spell_test.dart test/models/spell_template_test.dart test/models/spell_draft_copy_with_test.dart`
Expected: FAIL — `container_mode.dart` does not exist.

- [ ] **Step 3: Create the enum**

Create `lib/models/container_mode.dart`:

```dart
/// Whether a container-target spell is static or dynamic.
///
/// Core Rules, the "Container Targets" sidebar, section "Static and Dynamic
/// Targets" (lines 12242-12252). Both words are the rulebook's own.
///
/// [static] — affects valid targets inside the container at the moment of
/// casting, and keeps affecting them even if they leave, and even if the
/// container ceases to exist (12246). A static Circle spell still ends if the
/// circle is broken.
///
/// [dynamic] — affects valid targets while they are in the container. One
/// that leaves stops being affected, one that enters or re-enters starts
/// being affected, and the spell ends early if the container ceases to exist
/// (12248).
///
/// [unstated] means **no decision was recorded**, never "no decision is
/// owed" — whether a spell owes one is derived by `spellOwesContainerMode`.
/// That distinction is exactly what keeps the outstanding set findable when
/// spells gain characters and the mode becomes required. Do not add a
/// `notApplicable` member.
///
/// The mode is fixed when the spell is designed and cannot be changed by the
/// casting magus (12250), which is why it lives on the record. Two spells with
/// identical Technique, Form, Range, Duration and Target can differ in it
/// (12252), which is why it cannot be derived. It is level-neutral.
///
/// `static` and `dynamic` are built-in identifiers in Dart, but both are legal
/// as enum constants and `.name` yields exactly the rulebook's words.
enum ContainerMode { unstated, static, dynamic }

ContainerMode containerModeFromName(String name, String className) {
  for (final value in ContainerMode.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown containerMode '$name' (expected one of: "
    "${ContainerMode.values.map((m) => m.name).join(', ')})",
  );
}
```

- [ ] **Step 4: Add the field to `Spell`**

In `lib/models/spell.dart`, add the import:

```dart
import 'package:eruditus/models/container_mode.dart';
```

Add the field to `Spell`, beside `ritualDeclaration` (around line 261):

```dart
  /// Whether this spell's container Target is static or dynamic. Meaningful
  /// only when [targetId] names a container Target — enforced by
  /// `validateSpellAgainstCatalog`'s check 9.
  ///
  /// Follows [RitualDeclaration]'s path deliberately: an enum with a neutral
  /// member, carried by the model and the built-in library before any UI sets
  /// it, so that making it required later needs no migration. See todo item 14.
  final ContainerMode containerMode;
```

Add to the constructor, after `this.ritualDeclaration = RitualDeclaration.none,`:

```dart
    this.containerMode = ContainerMode.unstated,
```

Add to `toMap`, after the `'ritualDeclaration'` entry:

```dart
        'containerMode': containerMode.name,
```

Add to `fromMap`, after the `ritualDeclaration` entry:

```dart
        containerMode: map['containerMode'] == null
            ? ContainerMode.unstated
            : containerModeFromName(
                requireField<String>(map, 'containerMode', 'Spell'), 'Spell'),
```

- [ ] **Step 5: Add the field to `SpellDraft`**

Still in `lib/models/spell.dart`. Add the field beside `ritualDeclaration` (around line 401):

```dart
  ContainerMode containerMode;
```

Add to the constructor, after `this.ritualDeclaration = RitualDeclaration.none,`:

```dart
    this.containerMode = ContainerMode.unstated,
```

Add to `toSpell`'s `Spell(...)` call, after `ritualDeclaration: ritualDeclaration,`:

```dart
      containerMode: containerMode,
```

Add to `copyWith`'s parameter list, after `RitualDeclaration? ritualDeclaration,`:

```dart
    ContainerMode? containerMode,
```

Add to `copyWith`'s `SpellDraft(...)` call, after the `ritualDeclaration` line:

```dart
      containerMode: containerMode ?? this.containerMode,
```

No `_unset` sentinel: `unstated` is a real non-null value, so passing it explicitly sets it, and `null` unambiguously means "omitted".

- [ ] **Step 6: Add the field to `SpellTemplate`**

In `lib/models/spell_template.dart`, add the import:

```dart
import 'package:eruditus/models/container_mode.dart';
```

Add the field after `ritualDeclaration` (line 41):

```dart
  /// See [Spell.containerMode] — identical contract. Carried here because 8
  /// of the built-in Circle wards are templates.
  final ContainerMode containerMode;
```

Add to the constructor, after `this.ritualDeclaration = RitualDeclaration.none,`:

```dart
    this.containerMode = ContainerMode.unstated,
```

Add to `toMap`, after the `'ritualDeclaration'` entry:

```dart
        'containerMode': containerMode.name,
```

Add to `fromMap`, after the `ritualDeclaration` entry:

```dart
        containerMode: map['containerMode'] == null
            ? ContainerMode.unstated
            : containerModeFromName(
                requireField<String>(map, 'containerMode', 'SpellTemplate'),
                'SpellTemplate'),
```

- [ ] **Step 7: Bump the database schema version**

In `lib/data/database/app_database.dart`, change line 7:

```dart
  static const int _databaseVersion = 9;
```

Append this paragraph to the existing block comment above `onUpgrade`, after the v8 paragraph:

```
        // The v9 bump adds `containerMode` to the `spells` blob. Additive like
        // v5/v6/v7 — `Spell.fromMap` defaults a missing key to
        // `ContainerMode.unstated` — so this one could have been translated by
        // a silent per-field default. Dropped anyway under the same policy:
        // backward compatibility is not a goal for this prototype, and a
        // silent per-field default is one more implicit behavior to maintain
        // forever. `SpellTemplate` gained the same field, but templates are
        // asset-only and never persisted here, so there is nothing to migrate.
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/models/spell_test.dart test/models/spell_template_test.dart test/models/spell_draft_copy_with_test.dart test/data/database/app_database_migration_test.dart`
Expected: PASS. If `app_database_migration_test.dart` hardcodes the version number, update it to 9.

- [ ] **Step 9: Run the full Dart suite**

Run: `flutter test`
Expected: PASS. Every new field has a default, so no existing construction site changes.

- [ ] **Step 10: Commit**

```bash
git add lib/models/container_mode.dart lib/models/spell.dart lib/models/spell_template.dart lib/data/database/app_database.dart test/models/spell_test.dart test/models/spell_template_test.dart test/models/spell_draft_copy_with_test.dart test/data/database/app_database_migration_test.dart
git commit -m "feat: store a container mode on spells, templates and drafts"
```

---

### Task 3: Check 9 and the ownership predicate

**Files:**
- Modify: `lib/models/spell.dart` (`validateSpellAgainstCatalog` signature + check 9; new `spellOwesContainerMode`; hoist `_momentaryDurationId`)
- Modify: `lib/engine/spell_engine.dart:83-93`
- Modify: `lib/models/resolved_spell.dart:74-84`
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Consumes: `TargetType` (Task 1), `ContainerMode` (Task 2).
- Produces: `validateSpellAgainstCatalog` gains `required Parameter? target` and `required ContainerMode containerMode`; `bool spellOwesContainerMode({required Parameter? target, required Parameter? duration, required ContainerMode mode})`.

- [ ] **Step 1: Write the failing tests**

Append to `test/models/spell_test.dart`. The existing `validateSpellAgainstCatalog` group has a local `validate(...)` helper around line 732 — extend it with `Parameter? target` and `ContainerMode containerMode = ContainerMode.unstated` parameters that it forwards, then add:

```dart
  group('check 9: container mode belongs only to a container Target', () {
    Parameter targetOfType(String id, TargetType type) => Parameter(
          id: id,
          name: id,
          category: 'Target',
          magnitude: 0,
          targetType: type,
          provenance: const Provenance(source: PublicationSource.published),
        );

    test('accepts either mode on a container Target', () {
      for (final mode in [ContainerMode.static, ContainerMode.dynamic]) {
        expect(
          validate(
            target: targetOfType('target-room', TargetType.container),
            containerMode: mode,
          ),
          isEmpty,
        );
      }
    });

    test('rejects a stated mode on an object Target', () {
      expect(
        validate(
          target: targetOfType('target-group', TargetType.object),
          containerMode: ContainerMode.dynamic,
        ),
        contains(contains('container mode applies only to a container Target')),
      );
    });

    test('rejects a stated mode on a sense Target', () {
      expect(
        validate(
          target: targetOfType('target-vision', TargetType.sense),
          containerMode: ContainerMode.static,
        ),
        contains(contains('container mode applies only to a container Target')),
      );
    });

    test('unstated is accepted on every Target kind', () {
      for (final type in TargetType.values) {
        expect(
          validate(
            target: targetOfType('target-x', type),
            containerMode: ContainerMode.unstated,
          ),
          isEmpty,
        );
      }
    });

    test('an unresolvable Target skips the check rather than reporting it', () {
      // Matches check 5's treatment of an unresolvable modifier: a null here
      // means the catalog could not resolve the id, which is a different
      // problem reported elsewhere (ResolvedSpell.isResolved).
      expect(
        validate(target: null, containerMode: ContainerMode.dynamic),
        isEmpty,
      );
    });

    test('a Momentary Duration does not make a stated mode invalid', () {
      // Momentary belongs to spellOwesContainerMode, not here. The rulebook
      // constrains the Target kind and nothing else, so stating a mode on a
      // Momentary container spell is vacuous, not wrong. If this test ever
      // starts failing, check 9 has grown a Duration clause it must not have.
      expect(
        validate(
          target: targetOfType('target-room', TargetType.container),
          containerMode: ContainerMode.static,
        ),
        isEmpty,
      );
    });
  });

  group('spellOwesContainerMode', () {
    Parameter param(String id, {String category = 'Target', TargetType? type}) =>
        Parameter(
          id: id,
          name: id,
          category: category,
          magnitude: 0,
          targetType: type,
          provenance: const Provenance(source: PublicationSource.published),
        );

    final room = param('target-room', type: TargetType.container);
    final group_ = param('target-group', type: TargetType.object);
    final sun = param('duration-sun', category: 'Duration');
    final momentary = param('duration-momentary', category: 'Duration');

    test('true for a container Target, a non-Momentary Duration and no mode', () {
      expect(
        spellOwesContainerMode(
            target: room, duration: sun, mode: ContainerMode.unstated),
        isTrue,
      );
    });

    test('false once a mode is stated', () {
      for (final mode in [ContainerMode.static, ContainerMode.dynamic]) {
        expect(
          spellOwesContainerMode(target: room, duration: sun, mode: mode),
          isFalse,
        );
      }
    });

    test('false for a non-container Target', () {
      expect(
        spellOwesContainerMode(
            target: group_, duration: sun, mode: ContainerMode.unstated),
        isFalse,
      );
    });

    test('false for a Momentary Duration', () {
      // Nothing can enter a container during a duration that does not elapse,
      // so the two designs are indistinguishable and no ruling is owed. This
      // is the case a later reader is most likely to get wrong.
      expect(
        spellOwesContainerMode(
            target: room, duration: momentary, mode: ContainerMode.unstated),
        isFalse,
      );
    });

    test('false when either parameter is unresolvable', () {
      expect(
        spellOwesContainerMode(
            target: null, duration: sun, mode: ContainerMode.unstated),
        isFalse,
      );
      expect(
        spellOwesContainerMode(
            target: room, duration: null, mode: ContainerMode.unstated),
        isFalse,
      );
    });
  });
```

Note the last assertion: a null `duration` yields **false**, because `null != 'duration-momentary'` would otherwise make an unresolvable duration look like an owed ruling. Implement accordingly.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — `spellOwesContainerMode` is undefined and `validate` does not accept the new arguments.

- [ ] **Step 3: Hoist the Momentary id to file scope**

In `lib/models/spell.dart`, delete this line from inside `SpellDraft` (line 435):

```dart
  static const String _momentaryDurationId = 'duration-momentary';
```

and add it at file scope, just above `validateSpellAgainstCatalog`:

```dart
/// Shared by [SpellDraft.isEligibleForLastingCreationDeclaration] and
/// [spellOwesContainerMode] — both ask whether a Duration is Momentary, and
/// two copies of the id would drift.
const String _momentaryDurationId = 'duration-momentary';
```

`SpellDraft.isEligibleForLastingCreationDeclaration` keeps referring to `_momentaryDurationId` unchanged — same file, same privacy scope.

- [ ] **Step 4: Extend the validator signature and add check 9**

In `lib/models/spell.dart`, add two parameters to `validateSpellAgainstCatalog`, after `required Map<String, String> chosenSlots,`:

```dart
  required Parameter? target,
  required ContainerMode containerMode,
```

Both are `required` so no caller can silently skip check 9; `target` is nullable so an unresolvable id is tolerated rather than fatal.

Add check 9 immediately before `return problems;` (after check 8):

```dart
  // 9. Only a container Target has the static/dynamic distinction at all —
  //    Core Rules line 12120 names the three kinds, and the "Container
  //    Targets" sidebar (12238) gives the choice to containers alone. A mode
  //    stated on an object or sense Target is meaningless stored data, the
  //    same class of bug check 2 catches for a stray chosenBaseLevel.
  //
  //    A null target skips this, matching check 5's tolerance of an
  //    unresolvable modifier: an id the catalog cannot resolve is a different
  //    problem, reported by ResolvedSpell.isResolved.
  //
  //    Momentary deliberately does NOT appear here. A Momentary container
  //    spell cannot distinguish the two designs, so it owes no ruling — but
  //    that is spellOwesContainerMode's question, and stating a mode anyway is
  //    vacuous rather than wrong. This check tests the Target kind and nothing
  //    else, because that is all the rulebook constrains.
  if (containerMode != ContainerMode.unstated &&
      target != null &&
      target.targetType != TargetType.container) {
    problems.add(
      'A container mode applies only to a container Target, and '
      '${target.name} is not one',
    );
  }
```

Add the imports at the top of the file:

```dart
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/target_type.dart';
```

(`container_mode.dart` was already added in Task 2; add only `target_type.dart` if so.)

- [ ] **Step 5: Add `spellOwesContainerMode`**

In `lib/models/spell.dart`, immediately after `validateSpellAgainstCatalog`:

```dart
/// Does this spell still owe a static/dynamic ruling?
///
/// True when the Target is a container, the Duration is not Momentary, and no
/// mode has been recorded. Derived rather than stored: all three inputs are
/// catalog data, so a stored "not applicable" would be storing derivable data —
/// which is exactly what the id-reference normalization removed.
///
/// A Momentary container spell owes nothing: nothing can enter a container
/// during a duration that does not elapse, so the two designs are
/// indistinguishable. An unresolvable Target or Duration also owes nothing —
/// there is not enough information to say, and `ResolvedSpell.isResolved`
/// already reports the unresolvable id.
///
/// **Nothing calls this yet, deliberately.** The mode is optional until spells
/// belong to a character, at which point every spell owes a decision. This is
/// the hook that work flips to a requirement, and pinning the rule in tests now
/// is cheaper than re-deriving it from the rulebook later. See todo item 14.
bool spellOwesContainerMode({
  required Parameter? target,
  required Parameter? duration,
  required ContainerMode mode,
}) =>
    mode == ContainerMode.unstated &&
    target?.targetType == TargetType.container &&
    duration != null &&
    duration.id != _momentaryDurationId;
```

- [ ] **Step 6: Update the two production call sites**

In `lib/engine/spell_engine.dart`, add to the `validateSpellAgainstCatalog(...)` call at line 83, after `chosenSlots: draft.chosenSlots,`:

```dart
        target: draft.target,
        containerMode: draft.containerMode,
```

In `lib/models/resolved_spell.dart`, add to the call at line 74, after `chosenSlots: record.chosenSlots,`:

```dart
      target: target,
      containerMode: record.containerMode,
```

`target` there is the already-resolved `Parameter?` the class exposes; do not re-look it up.

- [ ] **Step 7: Update the remaining test call sites**

Run `flutter test` and fix every compile error from a `validateSpellAgainstCatalog` call missing the two new arguments. There are roughly ten, across `test/models/spell_test.dart` and `test/data/published_spell_import_test.dart`. This is mechanical: pass the spell's resolved target parameter where one is available, and `target: null, containerMode: ContainerMode.unstated` where the test is about an unrelated check.

In `test/data/published_spell_import_test.dart`, pass the **real** resolved target and the row's own `containerMode` — that file is where check 9 is enforced over the built-in library and templates, since `isTemplate: true` appears only in tests and templates never reach this function in production.

- [ ] **Step 8: Run the full Dart suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/models/spell.dart lib/engine/spell_engine.dart lib/models/resolved_spell.dart test/models/spell_test.dart test/data/published_spell_import_test.dart
git commit -m "feat: reject a container mode on a non-container Target (check 9)"
```

---

### Task 4: Bloc wiring

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_event.dart`
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart:147-155` (`TargetSelected`), plus the `TemplateInstantiated` handler
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `ContainerMode` (Task 2), `TargetType` (Task 1), `SpellDraft.copyWith({ContainerMode? containerMode})` (Task 2).
- Produces: `class ContainerModeSelected extends SpellCreationEvent` with `final ContainerMode mode`.

- [ ] **Step 1: Write the failing tests**

Append to `test/bloc/spell_creation_bloc_test.dart`, following that file's existing `blocTest` conventions:

```dart
  group('ContainerModeSelected', () {
    blocTest<SpellCreationBloc, SpellCreationState>(
      'stores the mode on the draft',
      build: buildBloc,
      act: (bloc) => bloc.add(const ContainerModeSelected(ContainerMode.dynamic)),
      expect: () => [
        isA<SpellCreationState>().having(
            (s) => s.draft.containerMode, 'containerMode', ContainerMode.dynamic),
      ],
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'does not recompute the breakdown — the mode is level-neutral',
      build: buildBloc,
      seed: () => seededCalculatedState(),
      act: (bloc) => bloc.add(const ContainerModeSelected(ContainerMode.static)),
      verify: (bloc) {
        // Identity, not non-nullness: copyWith preserves the old breakdown by
        // construction, so `isNotNull` would pass even if the handler
        // recomputed. Only `same` proves nothing was recalculated.
        expect(bloc.state.breakdown, same(seededCalculatedState().breakdown));
      },
    );
  });

  group('TargetSelected prunes the container mode', () {
    blocTest<SpellCreationBloc, SpellCreationState>(
      'clears a stated mode when the new Target is not a container',
      build: buildBloc,
      seed: () => stateWithDraft(draftWithContainerTargetAndMode(
        mode: ContainerMode.dynamic,
      )),
      act: (bloc) => bloc.add(TargetSelected(individualTarget)),
      verify: (bloc) =>
          expect(bloc.state.draft.containerMode, ContainerMode.unstated),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'keeps a stated mode when moving between two container Targets',
      build: buildBloc,
      seed: () => stateWithDraft(draftWithContainerTargetAndMode(
        mode: ContainerMode.dynamic,
      )),
      act: (bloc) => bloc.add(TargetSelected(structureTarget)),
      verify: (bloc) =>
          expect(bloc.state.draft.containerMode, ContainerMode.dynamic),
    );
  });

  blocTest<SpellCreationBloc, SpellCreationState>(
    'TemplateInstantiated copies the template container mode',
    build: buildBloc,
    act: (bloc) => bloc.add(TemplateInstantiated(
      wardTemplate, // containerMode: ContainerMode.dynamic
    )),
    verify: (bloc) =>
        expect(bloc.state.draft.containerMode, ContainerMode.dynamic),
  );
```

Build `individualTarget`, `structureTarget` and `wardTemplate` with that file's existing fixture helpers. `individualTarget` must carry `targetType: TargetType.object`, `structureTarget` `targetType: TargetType.container`, and `wardTemplate` must be a `SpellTemplate` with `targetId: 'target-circle'` and `containerMode: ContainerMode.dynamic`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL — `ContainerModeSelected` is undefined.

- [ ] **Step 3: Add the event**

In `lib/bloc/spell_creation/spell_creation_event.dart`, add the import and the class:

```dart
import 'package:eruditus/models/container_mode.dart';
```

```dart
/// The caster's static/dynamic choice for a container Target.
///
/// Draft-only and never recomputes the breakdown: the mode is level-neutral,
/// so recalculating on selection would be pure waste — the same reasoning
/// SummaryChanged carries.
class ContainerModeSelected extends SpellCreationEvent {
  final ContainerMode mode;

  const ContainerModeSelected(this.mode);

  @override
  List<Object?> get props => [mode];
}
```

- [ ] **Step 4: Handle the event and prune on `TargetSelected`**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, add the imports:

```dart
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/target_type.dart';
```

Replace the `TargetSelected` branch at lines 147-155 with:

```dart
    } else if (event is TargetSelected) {
      // The only Technique/Form/BaseEffect/Target handler that didn't prune
      // stale modifier selections — size-mentem's Target exclusion made that
      // a live bug rather than a theoretical gap. See todo item 19.
      //
      // The container mode is pruned here too, for a sharper reason. Unlike
      // the summary (item 13), which is scoped to nothing, the mode is scoped
      // to the Target: a mode stated under Room and left behind under
      // Individual is precisely what validateSpellAgainstCatalog's check 9
      // rejects, so the save would fail with no visible cause. Conditional on
      // the *new* Target's kind, so Room -> Structure keeps the choice.
      final keepsMode = event.parameter.targetType == TargetType.container;
      final draft = _withPrunedModifiers(state.draft.copyWith(
        target: event.parameter,
        containerMode: keepsMode ? null : ContainerMode.unstated,
      ));
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
      ));
```

Add a new branch beside the other draft-only handlers:

```dart
    } else if (event is ContainerModeSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(containerMode: event.mode),
      ));
```

- [ ] **Step 5: Copy the mode on template instantiation**

In the `TemplateInstantiated` handler, add `containerMode` alongside the existing `ritualDeclaration` / `analogyRationale` / `summary` copies:

```dart
        containerMode: template.containerMode,
```

Without this, instantiating a ward template silently drops the `dynamic` the Task 6 backfill records.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS

- [ ] **Step 7: Run the full Dart suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_event.dart lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: select a container mode, and prune it when the Target changes"
```

---

### Task 5: The creation-screen control

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart` (after the Target dropdown at `:242-252`; new private widget beside `_SummaryField`)
- Test: `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: `ContainerModeSelected` (Task 4), `SpellDraft.containerMode` (Task 2), `Parameter.targetType` (Task 1).
- Produces: a `SegmentedButton<ContainerMode>` under `Key('container-mode-field')`.

- [ ] **Step 1: Write the failing tests**

Append to `test/presentation/screens/spell_creation_screen_test.dart`, following its existing pump/scroll conventions:

```dart
  testWidgets('the container mode control appears only for a container Target',
      (tester) async {
    await pumpCreationScreen(tester);

    await selectTarget(tester, 'Individual');
    expect(find.byKey(const Key('container-mode-field')), findsNothing);

    await selectTarget(tester, 'Room');
    // scrollUntilVisible against the screen's own scrollable, keyed
    // 'spell-creation-scroll' — a bare find would be ambiguous, because every
    // TextField on this screen builds its own Scrollable.
    await tester.scrollUntilVisible(
      find.byKey(const Key('container-mode-field')),
      100,
      scrollable: find.byKey(const Key('spell-creation-scroll')),
    );
    expect(find.byKey(const Key('container-mode-field')), findsOneWidget);
  });

  testWidgets('choosing a segment dispatches ContainerModeSelected',
      (tester) async {
    await pumpCreationScreen(tester);
    await selectTarget(tester, 'Room');
    await tester.scrollUntilVisible(
      find.byKey(const Key('container-mode-field')),
      100,
      scrollable: find.byKey(const Key('spell-creation-scroll')),
    );

    await tester.tap(find.text('Dynamic'));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const ContainerModeSelected(ContainerMode.dynamic)))
        .called(1);
  });
```

Use whatever helpers that file already defines for pumping the screen and driving the Target dropdown; `pumpCreationScreen` and `selectTarget` above stand for them.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: FAIL — no widget carries `Key('container-mode-field')`.

- [ ] **Step 3: Add the widget**

In `lib/presentation/screens/spell_creation_screen.dart`, add the imports:

```dart
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/target_type.dart';
```

Add this private widget beside `_SummaryField` (after line 794):

```dart
/// The static/dynamic choice for a container Target (Core Rules' "Container
/// Targets" sidebar).
///
/// Stateless, unlike [_SummaryField] and [_GuidelineLevelField]: there is no
/// controller to resync, because a segmented button reads its selection
/// straight from [value] on every build.
///
/// [ContainerMode.unstated] is a visible, selectable segment rather than an
/// absence, because it is a real stored value — deferring the decision should
/// be something the user does, not something that happens by not noticing a
/// control.
class _ContainerModeField extends StatelessWidget {
  final ContainerMode value;
  final String targetName;
  final ValueChanged<ContainerMode> onChanged;

  const _ContainerModeField({
    required this.value,
    required this.targetName,
    required this.onChanged,
  });

  static const Map<ContainerMode, String> _labels = {
    ContainerMode.unstated: 'Not stated',
    ContainerMode.static: 'Static',
    ContainerMode.dynamic: 'Dynamic',
  };

  String get _helper {
    switch (value) {
      case ContainerMode.unstated:
        return 'Not recorded. The rulebook fixes this when the spell is '
            'designed, so it is worth deciding.';
      case ContainerMode.static:
        return 'Affects whatever is in the $targetName when cast, and keeps '
            'affecting it even after it leaves.';
      case ContainerMode.dynamic:
        return 'Affects whatever is in the $targetName at the time. Leaving '
            'ends the effect; entering starts it.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Container behaviour',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        SegmentedButton<ContainerMode>(
          key: const Key('container-mode-field'),
          segments: ContainerMode.values
              .map((mode) =>
                  ButtonSegment(value: mode, label: Text(_labels[mode]!)))
              .toList(),
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
        const SizedBox(height: 4),
        Text(_helper, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
```

- [ ] **Step 4: Render it under the Target dropdown**

Immediately after the Target `_buildParameterDropdown(...)` block (which ends at line 252), insert:

```dart
                if (draft.target?.targetType == TargetType.container) ...[
                  const SizedBox(height: 12),
                  _ContainerModeField(
                    value: draft.containerMode,
                    targetName: draft.target!.name,
                    onChanged: (mode) => bloc.add(ContainerModeSelected(mode)),
                  ),
                ],
```

This mirrors the conditional open-slot fields at `:202-209` — the qualifier renders directly beneath the thing it qualifies.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Run the full Dart suite**

Run: `flutter test`
Expected: PASS. If an existing test now fails on an ambiguous `scrollUntilVisible`, give it the `scrollable: find.byKey(const Key('spell-creation-scroll'))` argument — the screen grew a widget, and a bare finder matches every `TextField`'s own `Scrollable`.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/spell_creation_screen.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: offer the container mode choice for a container Target"
```

---

### Task 6: The importer backfill

**Files:**
- Modify: `scripts/spell_import/catalog.py` (new `Catalog.target_type`)
- Create: `scripts/spell_import/container_modes.json`
- Modify: `scripts/spell_import/extract_spells.py` (path const, loader, applier, wiring at `:860`)
- Regenerate: `assets/data/spell_library.json`, `assets/data/spell_templates.json`
- Test: `scripts/spell_import/tests/test_catalog.py`, `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: `targetType` in `parameters.json` (Task 1); the `containerMode` key `Spell.fromMap`/`SpellTemplate.fromMap` read (Task 2).
- Produces: `Catalog.target_type(parameter_id) -> str | None`; `extract_spells.container_modes() -> dict[str, dict]`; `extract_spells.apply_container_modes(rows, catalog, modes) -> None`; exceptions `UnknownContainerModeSpell` and `NotAContainerTarget`.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/spell_import/tests/test_catalog.py`:

```python
class TargetTypeTest(unittest.TestCase):
    def setUp(self):
        self.catalog = catalog.Catalog.load()

    def test_returns_the_kind_for_a_target(self):
        self.assertEqual(self.catalog.target_type("target-room"), "container")
        self.assertEqual(self.catalog.target_type("target-group"), "object")
        self.assertEqual(self.catalog.target_type("target-vision"), "sense")

    def test_returns_none_for_a_non_target_parameter(self):
        self.assertIsNone(self.catalog.target_type("duration-sun"))

    def test_returns_none_for_an_unknown_id(self):
        self.assertIsNone(self.catalog.target_type("target-nowhere"))
```

Append to `scripts/spell_import/tests/test_extract.py`:

```python
class ContainerModesTest(unittest.TestCase):
    def setUp(self):
        self.catalog = catalog_module.Catalog.load()

    def _rows(self):
        return [
            {"id": "lib-a", "targetId": "target-circle"},
            {"id": "lib-b", "targetId": "target-group"},
        ]

    def test_stamps_the_mode_onto_the_row_it_names(self):
        rows = self._rows()
        extract_spells.apply_container_modes(
            rows, self.catalog, {"lib-a": {"mode": "dynamic", "rationale": "x"}}
        )
        self.assertEqual(rows[0]["containerMode"], "dynamic")

    def test_leaves_unnamed_rows_alone(self):
        rows = self._rows()
        extract_spells.apply_container_modes(
            rows, self.catalog, {"lib-a": {"mode": "dynamic", "rationale": "x"}}
        )
        self.assertNotIn("containerMode", rows[1])

    def test_raises_on_an_id_no_run_produced(self):
        with self.assertRaises(extract_spells.UnknownContainerModeSpell):
            extract_spells.apply_container_modes(
                self._rows(),
                self.catalog,
                {"lib-ghost": {"mode": "static", "rationale": "x"}},
            )

    def test_raises_when_the_target_is_not_a_container(self):
        with self.assertRaises(extract_spells.NotAContainerTarget):
            extract_spells.apply_container_modes(
                self._rows(),
                self.catalog,
                {"lib-b": {"mode": "dynamic", "rationale": "x"}},
            )
```

Add to `RunTest` in the same file, which already holds a `report` from a full `run(write=False)`:

```python
    def test_the_eight_circle_wards_carry_a_dynamic_container_mode(self):
        wards = {
            "lib-rean-circle-beast-warding",
            "tpl-rean-ward-against-beasts-legend",
            "tpl-reaq-ward-against-faeries-waters",
            "tpl-reau-ward-against-faeries-air",
            "tpl-rehe-ward-against-faeries-wood",
            "tpl-reme-ring-warding-against-spirits",
            "tpl-rete-ward-against-faeries-mountain",
            "tpl-revi-circular-ward-against-demons",
        }
        rows = {
            row["id"]: row
            for row in list(self.report.spells) + list(self.report.templates)
        }
        for ward in wards:
            self.assertEqual(rows[ward].get("containerMode"), "dynamic", ward)

    def test_restore_the_faded_threads_stays_unstated(self):
        # A Circle spell the Magical Wards rule does not decide, because it is
        # not a ward. Guessing at it is exactly what the backfill must not do.
        rows = {row["id"]: row for row in self.report.templates}
        self.assertNotIn(
            "containerMode", rows["tpl-crvi-restore-faded-threads"]
        )
```

Add whatever import of `catalog_module` and `extract_spells` that file needs at the top; it already imports `extract_spells`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: FAIL — `Catalog.target_type` and `apply_container_modes` do not exist.

- [ ] **Step 3: Add `Catalog.target_type`**

In `scripts/spell_import/catalog.py`, add to `class Catalog` beside `parameter_id` (line 122):

```python
    def target_type(self, parameter_id: str) -> str | None:
        """The rulebook's kind for a Target: "object", "container" or "sense".

        None for a Range or Duration row, for an unknown id, and for a Target
        that has not been annotated. The Dart-side assertion in
        `asset_data_loader_test.dart` is what forbids the last case; treating
        it as None here means an un-annotated Target simply never matches
        "container", which fails loudly at the call site rather than silently
        stamping a mode onto the wrong row.
        """
        for parameter in self.parameters:
            if parameter["id"] == parameter_id:
                return parameter.get("targetType")
        return None
```

- [ ] **Step 4: Create the backfill input**

Create `scripts/spell_import/container_modes.json`:

```json
{
  "lib-rean-circle-beast-warding": {
    "mode": "dynamic",
    "rationale": "Magical Wards (Core Rules 12166): a ward with a Circle target prevents warded things inside from leaving and warded things outside from entering. That is the dynamic reading — membership changes over the duration."
  },
  "tpl-rean-ward-against-beasts-legend": {
    "mode": "dynamic",
    "rationale": "Magical Wards (Core Rules 12166): a ward with a Circle target prevents warded things inside from leaving and warded things outside from entering. That is the dynamic reading — membership changes over the duration."
  },
  "tpl-reaq-ward-against-faeries-waters": {
    "mode": "dynamic",
    "rationale": "Magical Wards (Core Rules 12166): a ward with a Circle target prevents warded things inside from leaving and warded things outside from entering. That is the dynamic reading — membership changes over the duration."
  },
  "tpl-reau-ward-against-faeries-air": {
    "mode": "dynamic",
    "rationale": "Magical Wards (Core Rules 12166): a ward with a Circle target prevents warded things inside from leaving and warded things outside from entering. That is the dynamic reading — membership changes over the duration."
  },
  "tpl-rehe-ward-against-faeries-wood": {
    "mode": "dynamic",
    "rationale": "Magical Wards (Core Rules 12166): a ward with a Circle target prevents warded things inside from leaving and warded things outside from entering. That is the dynamic reading — membership changes over the duration."
  },
  "tpl-reme-ring-warding-against-spirits": {
    "mode": "dynamic",
    "rationale": "Magical Wards (Core Rules 12166): a ward with a Circle target prevents warded things inside from leaving and warded things outside from entering. That is the dynamic reading — membership changes over the duration."
  },
  "tpl-rete-ward-against-faeries-mountain": {
    "mode": "dynamic",
    "rationale": "Magical Wards (Core Rules 12166): a ward with a Circle target prevents warded things inside from leaving and warded things outside from entering. That is the dynamic reading — membership changes over the duration."
  },
  "tpl-revi-circular-ward-against-demons": {
    "mode": "dynamic",
    "rationale": "Magical Wards (Core Rules 12166): a ward with a Circle target prevents warded things inside from leaving and warded things outside from entering. That is the dynamic reading — membership changes over the duration."
  }
}
```

Exactly these 8 ids and no others. `tpl-crvi-restore-faded-threads` is a Circle spell but **not** a ward, so the Magical Wards rule does not reach it and it must stay absent.

- [ ] **Step 5: Load and apply the input**

In `scripts/spell_import/extract_spells.py`, add the path constant beside `HAND_AUTHORED_TEMPLATES_PATH` (line 33):

```python
CONTAINER_MODES_PATH = ledger_module.LEDGER_PATH.with_name("container_modes.json")
```

Add the exceptions and functions beside `hand_authored_templates` (after line 620):

```python
class UnknownContainerModeSpell(Exception):
    """A container_modes.json entry names a spell no run produced."""


class NotAContainerTarget(Exception):
    """A container_modes.json entry names a spell whose Target is not a container."""


def container_modes() -> dict[str, dict]:
    """Hand-authored static/dynamic rulings, keyed by spell id.

    A committed *input*, not an output: `--write` regenerates both
    spell_library.json and spell_templates.json, so a mode written into either
    asset would be destroyed on the next run. Same role as
    hand_authored_templates.json.
    """
    if not CONTAINER_MODES_PATH.is_file():
        return {}
    return json.loads(CONTAINER_MODES_PATH.read_text(encoding="utf-8"))


def apply_container_modes(
    rows: list[dict], catalog: catalog_module.Catalog, modes: dict[str, dict]
) -> None:
    """Stamp hand-authored container modes onto the rows they name, in place.

    Every entry must land. An id no run produced, or one whose Target is not a
    container, raises rather than being skipped: a silently-ignored entry is a
    decision that looks recorded and isn't, which is the whole failure mode
    this file exists to avoid.
    """
    by_id = {row["id"]: row for row in rows}

    unknown = sorted(set(modes) - set(by_id))
    if unknown:
        raise UnknownContainerModeSpell(
            "container_modes.json names spells no run produced: "
            + ", ".join(unknown)
        )

    for spell_id, entry in modes.items():
        row = by_id[spell_id]
        target_id = row["targetId"]
        if catalog.target_type(target_id) != "container":
            raise NotAContainerTarget(
                f"{spell_id}: container mode '{entry['mode']}' recorded, but "
                f"its Target {target_id} is not a container"
            )
        row["containerMode"] = entry["mode"]
```

Wire it in `run()`, immediately after line 860's `templates.extend(hand_authored_templates())`:

```python
    # One call across both lists: an id lives in exactly one of them, so
    # checking each separately would report every template id as unknown to
    # the spells pass. `spells + templates` is a new list of the *same* dicts,
    # so mutating through it mutates the rows that get serialized.
    apply_container_modes(spells + templates, catalog, container_modes())
```

- [ ] **Step 6: Run the Python tests to verify they pass**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS

- [ ] **Step 7: Regenerate the assets**

Run: `python -m scripts.spell_import.extract_spells --write`
Expected: `assets/data/spell_library.json` and `assets/data/spell_templates.json` each gain a `"containerMode": "dynamic"` key on their ward rows — 1 and 7 rows respectively.

Verify exactly 8 rows changed and nothing else did:

```bash
git diff --stat assets/data/
git diff assets/data/ | grep -c '^+.*containerMode'
```

Expected: `8`. If the run reports a moved source, stop and report it — do **not** pass `--accept-source` to force it.

- [ ] **Step 8: Run all three suites**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Run: `flutter test`
Run: `flutter test integration_test/`
Expected: all PASS. The Dart assertion suite now sees 8 rows carrying a mode; check 9 accepts them because Circle is a container.

- [ ] **Step 9: Commit**

```bash
git add scripts/spell_import/catalog.py scripts/spell_import/container_modes.json scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_catalog.py scripts/spell_import/tests/test_extract.py assets/data/spell_library.json assets/data/spell_templates.json
git commit -m "feat: backfill the eight Circle wards as dynamic, from a committed input"
```

---

### Task 7: Close item 14

**Files:**
- Modify: `.superpowers/todo.md`

**Interfaces:**
- Consumes: the completed work of Tasks 1-6.
- Produces: nothing code-facing.

- [ ] **Step 1: Move item 14 to the Completed section**

Cut the `### 14. Container Targets: Static vs. Dynamic` entry from section C and add it to `## Completed ✅`, reduced to what still binds. Keep exactly these facts, which the code does not record on its own:

- The mode is fixed when the spell is designed (Core Rules 12250) and two spells with identical Te/Fo/R/D/T can differ in it (12252) — so it is stored, not derived, and it is level-neutral.
- `unstated` means "no decision recorded", never "none owed". `spellOwesContainerMode` derives the latter and has no production caller until spells belong to a character.
- Check 9 tests Target kind only; Momentary lives in the predicate, not the check.
- 8 Circle wards were backfilled `dynamic` from one shared rationale. **16 rows still need a per-spell prose reading**, and `scripts/spell_import/container_modes.json` is where those rulings go. `tpl-crvi-restore-faded-threads` is among the 16 — a Circle spell that is not a ward.
- `target-bloodline` is an `object` Target carrying its own ongoing rule; it must not become a container.

- [ ] **Step 2: Update the section 0 table**

In the row-5 cell of the `## 0. Immediate Program of Work` table, change item 14's status from "answered 2026-08-17 — a model change **is** needed" to note that it is now implemented and closed, and update the surrounding prose so section 0 reads as fully discharged.

- [ ] **Step 3: Add the follow-up for the remaining 16**

Add a new item to section C recording that 16 container rows still owe a static/dynamic ruling, that each needs its printed description read, that the rulings go in `container_modes.json` with a rationale apiece, and that `spellOwesContainerMode` is the predicate that identifies them. Cross-reference item 14.

- [ ] **Step 4: Verify every item number still resolves**

Run: `grep -c '^### ' .superpowers/todo.md`
Confirm item 14 appears exactly once, and that the new follow-up item takes the next free number (57 — item 56 is the rules-hints item).

- [ ] **Step 5: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close item 14, file the remaining sixteen container rulings"
```

---

## Self-Review

**Spec coverage.** Decision 1 → Task 1. Decision 2 → Task 2. Decision 3 → Task 2 (no `notApplicable` member) and Task 3 (`spellOwesContainerMode`). Decision 4 → Task 3, both halves. Decision 5 → Task 3 steps 4/6/7. Decision 6 → Task 4 step 4. Decision 7 → Task 4 step 5. Decision 8 → Task 6. Storage section → Task 2 step 7. UI section → Task 5. Every test listed in the spec's Testing section appears in a task. No gaps.

**Type consistency.** `TargetType` / `targetTypeFromName` / `Parameter.targetType` are defined in Task 1 and used with those exact names in Tasks 3, 4, 5, 6. `ContainerMode` / `containerModeFromName` / `.containerMode` are defined in Task 2 and used unchanged in Tasks 3, 4, 5. `spellOwesContainerMode`'s signature in Task 3's test matches its implementation in the same task. `Catalog.target_type` returns `str | None` and is compared against the string `"container"` in Task 6, consistent with `parameters.json` storing the enum's `.name`.

**Known churn, called out so it isn't mistaken for breakage.** Task 3 step 7 touches ~10 test call sites; that is expected, not a defect. Task 5 step 6 may require adding an explicit `scrollable:` to existing widget tests, for the reason recorded there.
