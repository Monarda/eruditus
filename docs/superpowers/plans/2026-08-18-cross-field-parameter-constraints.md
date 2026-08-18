# Cross-Field Parameter Constraints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one parameter choice able to forbid or force another's value, so
Core Rules 12086 ("Personal Range spells can never have a container Target") is
enforced and HoH:MC's Sensory Magic restrictions become expressible.

**Architecture:** Two new `Parameter` fields, one per operator — `forbidsTargetTypes`
(forbidding) and `requiresRangeId` (forcing) — plus a fourth `TargetType` value that
reclassifies the five Sensory Targets and thereby closes item 68 without any forcing
mechanism. Three validation checks guard the record path; bidirectional pruning in
`SpellCreationBloc` guards the draft path; the UI filters peers and locks a forced Range.

**Tech Stack:** Dart / Flutter, `flutter_bloc`, JSON assets under `assets/data/`,
`flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-18-cross-field-parameter-constraints-design.md`

## Global Constraints

- **Never run `dart format`.** Hand-indent to match surrounding code and verify with
  `git diff -w`. (Repo convention; formatting is not clean here.)
- **`flutter analyze` must end at exit 0** after every task.
- **`assets/data/parameters.json` stores one compact object per line.** Do not
  reformat it. After editing, verify with `git diff --numstat` that only the intended
  number of lines changed.
- **Line citations in this plan are from the *current* `reviewed/` rulebook file.**
  Citations already in the codebase are exactly 8 lines low (todo item 70). Do not
  "reconcile" new numbers down to match old ones.
- **If `flutter test` fails with a sqlite3.dll permissions error**, that is stale
  `flutter_tester` processes holding a lock, not a real permissions problem. Kill them
  and re-run.
- **Test fixture style, used verbatim throughout this plan.** `test/models/spell_test.dart`
  builds its fixtures inline, with no shared helper:
  ```dart
  final effect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'test', baseLevel: 1,
    provenance: Provenance(source: PublicationSource.userCreated),
  );
  ```
  `Parameter` fixtures use the same `Provenance(source: ...)` constructor. There is no
  `Provenance.userCreated()` shorthand — do not invent one.
- **Rulebook checkout:** `c:\Development\personal\Ars-Magica-Open-License\`, `reviewed/`
  is authoritative.
- Commit after every task. Do not squash tasks together.

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `lib/models/target_type.dart` | Adds `sensorium`; doc comment carries the whole justification | 1 |
| `assets/data/parameters.json` | 5 rows change kind; `range-personal` gains a forbid list; 5 rows gain a required Range | 1, 2, 3 |
| `lib/models/parameter.dart` | `forbidsTargetTypes`, `requiresRangeId`, serialization; `ParameterScope` doc records the requisite reading | 2, 3, 4 |
| `lib/models/spell.dart` | Checks 10, 11, 12; `range` joins the signature | 2, 3, 4 |
| `lib/engine/spell_engine.dart`, `lib/models/resolved_spell.dart` | Pass `range` through | 2 |
| `lib/bloc/spell_creation/spell_creation_bloc.dart` | Bidirectional pruning | 5 |
| `lib/presentation/screens/spell_creation_screen.dart` | Peer-aware dropdowns, locked Range | 6 |
| `test/data/published_spell_import_test.dart` | Corpus drift guard (assertion 7, already exists) | 2, 7 |

**Note on the corpus guard.** `test/data/published_spell_import_test.dart`'s
"assertion 7" already loops every library spell and every template through
`validateSpellAgainstCatalog`. Checks 10, 11 and 12 therefore cover the whole corpus
**for free**, provided that call site passes a real resolved Range. Task 2 Step 6 is
where that happens, and getting it wrong silently disables the guard.

---

### Task 1: `TargetType.sensorium` and the five Sensory rows

Closes todo item 68 and unblocks item 65. Do this task first — item 65's importer must
not run against the old classification.

**Files:**
- Modify: `lib/models/target_type.dart:1-12`
- Modify: `assets/data/parameters.json` (5 rows)
- Test: `test/data/datasources/asset_data_loader_test.dart:58-71`,
  `test/models/parameter_test.dart`, `test/models/spell_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `TargetType.sensorium`, serialized as the string `"sensorium"` by the
  existing `targetTypeFromName` / `.name` round-trip.

- [ ] **Step 1: Update the existing drift-detector test to expect the new kind**

In `test/data/datasources/asset_data_loader_test.dart`, replace the `expected` map at
lines 65-71:

```dart
    const expected = <String, (int, TargetType)>{
      'target-flavor': (0, TargetType.sensorium),
      'target-texture': (1, TargetType.sensorium),
      'target-scent': (2, TargetType.sensorium),
      'target-sound': (3, TargetType.sensorium),
      'target-spectacle': (4, TargetType.sensorium),
    };
```

All five change, not only Sound and Spectacle. HoH:MC 1002 states the
continuously-acquired behaviour for *all five*, and `object` carries static semantics
(core 12254), so Flavor/Texture/Scent were equally misclassified.

Replace the comment above it (lines 58-61) so it no longer implies the kinds follow
the magnitude equivalences:

```dart
    // The magnitudes still follow the book's printed equivalences (Flavor to
    // Individual, Texture to Part, Scent to Group, Sound to Structure,
    // Spectacle to Boundary), because those sentences price the Target. They
    // do not classify it -- all five are `sensorium`. See the 2026-08-18
    // cross-field-parameter-constraints spec.
```

- [ ] **Step 2: Add the round-trip test**

In `test/models/parameter_test.dart`, inside the `Parameter` group:

```dart
    test('targetType round-trips the sensorium kind', () {
      final parameter = Parameter(
        id: 'target-sound',
        name: 'Sound',
        category: 'Target',
        magnitude: 3,
        targetType: TargetType.sensorium,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final restored = Parameter.fromMap(parameter.toMap());

      expect(restored.targetType, TargetType.sensorium);
    });

    test('targetTypeFromName still rejects an unknown kind', () {
      expect(
        () => targetTypeFromName('anima', 'Parameter'),
        throwsA(isA<FormatException>()),
      );
    });
```

- [ ] **Step 3: Add the two free-consequence tests**

These pin the behaviours Decision 1 gets without new machinery. In
`test/models/spell_test.dart`, in the group covering `spellOwesContainerMode` and
check 9 respectively (read the file to find them; do not create a new group):

```dart
    test('a sensorium Target owes no container-mode ruling', () {
      final sound = Parameter(
        id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 3,
        targetType: TargetType.sensorium,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final sun = Parameter(
        id: 'duration-sun', name: 'Sun', category: 'Duration', magnitude: 2,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      expect(
        spellOwesContainerMode(
          target: sound, duration: sun, mode: ContainerMode.unstated),
        isFalse,
      );
    });

    test('check 9 rejects a container mode stated on a sensorium Target', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final sound = Parameter(
        id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 3,
        targetType: TargetType.sensorium,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        target: sound,
        containerMode: ContainerMode.dynamic,
        modifiers: const [],
      );

      expect(problems, hasLength(1));
      expect(problems.single, contains('container mode'));
    });
```

**Do not add a `range:` argument yet** — it does not exist until Task 2, which will
come back and add it to these two calls along with every other call site.

- [ ] **Step 4: Run the tests to verify they fail**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart test/models/parameter_test.dart test/models/spell_test.dart`
Expected: FAIL — `sensorium` is not defined on `TargetType`, so these are compile
errors rather than assertion failures. That is the expected first failure.

- [ ] **Step 5: Add the enum value and rewrite the doc comment**

Replace `lib/models/target_type.dart` lines 1-12 with:

```dart
/// Which kind of Target a parameter is.
///
/// The core rules enumerate three — line 12128: "There are three types of
/// target: objects, containers, and senses" — and [object], [container] and
/// [sense] are the rulebook's own words. [sensorium] deliberately is not. It
/// is this catalog's own name for a fourth kind the core rules do not
/// describe, carrying HoH:MC's five Sensory Magic Targets, which that book
/// itself says "were imperfectly melded to Hermetic Theory, remaining a
/// Mystery of House Bjornaer" (HoH:MC 1000). A name that looked quoted would
/// misrepresent where the kind comes from.
///
/// **[sense] and [sensorium] are opposites, and the distinction is
/// load-bearing.** A [sense] Target grants *the caster* a magical sense. A
/// [sensorium] Target affects *those who sense the caster* — "anyone sensing
/// the Bjornaer magus through the specified sense becomes a target of the
/// spell" (HoH:MC 1002). HoH:MC 1009 forbids Intellego on a [sensorium] spell
/// precisely because magical-sense spells "fill that role", so collapsing the
/// two would erase the reason for that rule.
///
/// **Why the Sensory Targets are not [container].** HoH:MC 1006 requires every
/// Sensory Magic spell's Range to be Personal, and Core Rules 12086 forbids a
/// Personal-Range spell from having a container Target. Classifying them as
/// containers makes every such spell both required to be Personal and
/// forbidden from being Personal. Core 12252 also names the containers
/// exhaustively — "Circle, Room, Structure, and Boundary".
///
/// Only a [container] Target has the static/dynamic distinction — see
/// `ContainerMode`. An [object] Target is always static (12254). A [sense]
/// Target grants information rather than affecting a volume. A [sensorium]
/// Target acquires its targets continuously by the Target's own rule (HoH:MC
/// 1002), so there is no per-spell choice to offer and none is.
///
/// Line numbers here are the *current* `reviewed/` file's. Citations elsewhere
/// in this codebase are 8 lines low — todo item 70.
enum TargetType { object, container, sense, sensorium }
```

- [ ] **Step 6: Change the five rows in `parameters.json`**

Change `"targetType"` from `"object"` to `"sensorium"` on `target-flavor`,
`target-texture`, `target-scent`; and from `"container"` to `"sensorium"` on
`target-sound`, `target-spectacle`. Change nothing else on those lines — magnitudes,
`requiresVirtue` and `scope` all stay exactly as they are.

- [ ] **Step 7: Verify only five lines changed**

Run: `git diff --numstat assets/data/parameters.json`
Expected: `5	5	assets/data/parameters.json`

- [ ] **Step 8: Run the full suite**

Run: `flutter test`
Expected: PASS. If anything else fails, it is asserting the old classification — read
it before changing it, and confirm it is not a real regression.

- [ ] **Step 9: Verify analysis is clean**

Run: `flutter analyze`
Expected: exit 0, "No issues found!"

- [ ] **Step 10: Commit**

```bash
git add lib/models/target_type.dart assets/data/parameters.json test/
git commit -m "feat: the Sensory Targets are a fourth kind, not containers

Core 12086 forbids a Personal-Range spell from having a container Target, and
HoH:MC 1006 requires every Sensory Magic spell's Range to be Personal. The
container classification made all five contradictory. Closes todo item 68."
```

---

### Task 2: `forbidsTargetTypes` and check 10

**Files:**
- Modify: `lib/models/parameter.dart`
- Modify: `lib/models/spell.dart:92-105` and the new check
- Modify: `lib/engine/spell_engine.dart:83-95`, `lib/models/resolved_spell.dart:74-86`
- Modify: `assets/data/parameters.json` (`range-personal`)
- Test: `test/models/spell_test.dart`, plus every existing call site

**Interfaces:**
- Consumes: `TargetType.sensorium` from Task 1.
- Produces:
  - `Parameter.forbidsTargetTypes` — `List<TargetType>`, defaults `const []`,
    JSON key `forbidsTargetTypes` holding `TargetType.name` strings.
  - `validateSpellAgainstCatalog` gains `required Parameter? range`.

- [ ] **Step 1: Write the failing tests**

In `test/models/spell_test.dart`, in the group covering `validateSpellAgainstCatalog`:

```dart
    test('check 10: Personal Range with a container Target is rejected', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final personal = Parameter(
        id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0,
        forbidsTargetTypes: const [TargetType.container],
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final room = Parameter(
        id: 'target-room', name: 'Room', category: 'Target', magnitude: 2,
        targetType: TargetType.container,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: personal,
        target: room,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );

      expect(problems, hasLength(1));
      expect(problems.single, contains('Personal'));
      expect(problems.single, contains('Room'));
    });

    test('check 10: Personal Range with a sensorium Target is valid', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final personal = Parameter(
        id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0,
        forbidsTargetTypes: const [TargetType.container],
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final sound = Parameter(
        id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 3,
        targetType: TargetType.sensorium,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: personal,
        target: sound,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );

      expect(problems, isEmpty);
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — compile error: `range` is not a named parameter of
`validateSpellAgainstCatalog`, and `forbidsTargetTypes` is not a named parameter of
`Parameter`.

- [ ] **Step 3: Add the `Parameter` field**

In `lib/models/parameter.dart`, in the `Parameter` class beside `targetType`:

```dart
  /// Target kinds this parameter may never be combined with.
  ///
  /// Only `range-personal` sets it, from Core Rules 12086: "Personal Range
  /// spells can never have a container Target (such as Circle, Room, or
  /// Structure)."
  ///
  /// Keyed on [TargetType], not on target ids, because that is how the rule is
  /// written — "such as" is illustrative, and Boundary is a container too
  /// (12146). Keying on the kind covers Boundary and any future container row
  /// with no data edit.
  ///
  /// The *forbidding* half of the cross-field pair; [requiresRangeId] is the
  /// forcing half. They are separate fields because a "must not" has no value
  /// to impose and can only remove options, while a "must" can be auto-set.
  final List<TargetType> forbidsTargetTypes;
```

Add `this.forbidsTargetTypes = const [],` among the optional named parameters of the
constructor.

In `toMap`, after the `targetType` line:

```dart
    if (forbidsTargetTypes.isNotEmpty)
      'forbidsTargetTypes': forbidsTargetTypes.map((t) => t.name).toList(),
```

In `fromMap`:

```dart
    forbidsTargetTypes: (map['forbidsTargetTypes'] as List?)
            ?.map((n) => targetTypeFromName(n as String, 'Parameter'))
            .toList() ??
        const [],
```

Reusing `targetTypeFromName` means an unknown kind throws the same `FormatException`
as a bad `targetType` rather than being silently dropped.

- [ ] **Step 4: Add `range` to the signature and write check 10**

In `lib/models/spell.dart`, add immediately before `required Parameter? target,`:

```dart
  required Parameter? range,
```

Add check 10 after check 9, before `return problems;`:

```dart
  // 10. Core Rules 12086: "Personal Range spells can never have a container
  //     Target (such as Circle, Room, or Structure)." The first constraint in
  //     this catalog where one parameter forbids another's value, rather than
  //     forcing Ritual status or removing an option from a picker.
  //
  //     A null Range or Target skips this, matching check 9's tolerance: an id
  //     the catalog cannot resolve is ResolvedSpell.isResolved's problem, not
  //     this function's. Not wrapped in `if (!isTemplate)` — a template's Range
  //     and Target are as fully its own as a spell's, and nothing about
  //     instantiation supplies a Range.
  final targetKind = target?.targetType;
  if (range != null &&
      targetKind != null &&
      range.forbidsTargetTypes.contains(targetKind)) {
    problems.add(
      '${range.name} Range cannot be combined with ${target!.name}, '
      'which is a ${targetKind.name} Target',
    );
  }
```

- [ ] **Step 5: Update the two production call sites**

`lib/engine/spell_engine.dart`, in the call around line 83, beside `target: draft.target,`:

```dart
        range: draft.range,
```

`lib/models/resolved_spell.dart`, in the call at line 74, beside `target: target,`:

```dart
      range: range,
```

- [ ] **Step 6: Update the test call sites — and keep the corpus guard live**

`flutter analyze` names all of them: `test/models/spell_test.dart` (lines 738, 931,
953, 975, 997 before your additions) and `test/data/published_spell_import_test.dart`
(lines 182, 206, 275, 331, 348).

In `test/models/spell_test.dart`, existing tests that do not concern Range pass
`range: null`, which skips check 10 exactly as `target: null` skips check 9.

**In `test/data/published_spell_import_test.dart` assertion 7, do NOT pass null.**
That test is the corpus-wide guard — it already loops every library spell and every
template through this function, which is how checks 10, 11 and 12 get corpus coverage
without a new test. Pass the resolved Range, mirroring how the call already resolves
the Target:

```dart
        range: parameters[spell.rangeId],
```

and in the template loop:

```dart
        range: parameters[template.rangeId],
```

Passing `range: null` here would compile, pass, and silently disable the guard.

Run: `flutter analyze`
Expected: exit 0 once every call site passes `range`.

- [ ] **Step 7: Add the catalog data**

In `assets/data/parameters.json`, on the `range-personal` row only, add after
`"magnitude": 0,` and before `"source"`:

```json
"forbidsTargetTypes": ["container"],
```

- [ ] **Step 8: Run the tests and verify the diff**

Run: `flutter test`
Expected: PASS — including assertion 7, which now exercises check 10 over all 325
library spells and 28 templates. All were verified to have zero violations before this
plan was written, so a failure here means a genuine contradiction was introduced.

Run: `git diff --numstat assets/data/parameters.json`
Expected: `1	1	assets/data/parameters.json`

- [ ] **Step 9: Commit**

```bash
git add lib/ assets/data/parameters.json test/
git commit -m "feat: a Range can forbid a Target kind (core 12086)

Check 10, and the first cross-field constraint in the catalog: Personal Range
can never take a container Target. Assertion 7 now covers it corpus-wide."
```

---

### Task 3: `requiresRangeId` and check 11

**Files:**
- Modify: `lib/models/parameter.dart`, `lib/models/spell.dart`
- Modify: `assets/data/parameters.json` (5 rows)
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Consumes: `range` in the validation signature, from Task 2.
- Produces: `Parameter.requiresRangeId` — `String?`, JSON key `requiresRangeId`.

- [ ] **Step 1: Write the failing tests**

```dart
    test('check 11: a Sensory Target with a non-Personal Range is rejected', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final voice = Parameter(
        id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final sound = Parameter(
        id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 3,
        targetType: TargetType.sensorium,
        requiresRangeId: 'range-personal',
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: voice,
        target: sound,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );

      expect(problems, hasLength(1));
      expect(problems.single, contains('Sound'));
      expect(problems.single, contains('range-personal'));
    });

    test('check 11: a Sensory Target with the Range it requires is valid', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final personal = Parameter(
        id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0,
        forbidsTargetTypes: const [TargetType.container],
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final sound = Parameter(
        id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 3,
        targetType: TargetType.sensorium,
        requiresRangeId: 'range-personal',
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: personal,
        target: sound,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );

      expect(problems, isEmpty);
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — `requiresRangeId` is not a named parameter of `Parameter`.

- [ ] **Step 3: Add the field**

In `lib/models/parameter.dart`:

```dart
  /// The Range this parameter's spell must use, or null when it dictates none.
  ///
  /// Only the five HoH:MC Sensory Magic Targets set it, to `range-personal`,
  /// from HoH:MC 1006: "The Range must be Personal."
  ///
  /// The *forcing* half of the cross-field pair — see [forbidsTargetTypes] for
  /// the forbidding half and why they are separate. Named for the `requires*`
  /// family ([requiresRitual], [requiresVirtue]) with the `Id` suffix marking a
  /// catalog reference, as `rangeId`/`durationId`/`targetId` do elsewhere.
  ///
  /// Unlike [requiresVirtue], which is informational because the app has no
  /// character model, this one *is* enforced: check 11 rejects a mismatch and
  /// `SpellCreationBloc` sets and locks the Range.
  final String? requiresRangeId;
```

Add `this.requiresRangeId,` to the constructor.

In `toMap`, beside the other conditional keys:

```dart
    if (requiresRangeId != null) 'requiresRangeId': requiresRangeId,
```

In `fromMap`:

```dart
    requiresRangeId: map['requiresRangeId'] as String?,
```

- [ ] **Step 4: Write check 11**

In `lib/models/spell.dart`, directly after check 10:

```dart
  // 11. The forcing direction: a Target that dictates its spell's Range.
  //     HoH:MC 1006 requires every Sensory Magic spell's Range to be Personal.
  //     The creation screen sets and locks the Range, so a live draft cannot
  //     reach this — but the importer and already-saved records never pass
  //     through a dropdown, which is what this check is for.
  //
  //     The message names the required *id* rather than a display name,
  //     deliberately: this function has no parameter catalog to resolve
  //     against (check 5 resolves modifiers only because it is handed the
  //     list), and the only reader who sees this message is looking at record
  //     data, for whom the id is the more useful string. Check 7 sets the same
  //     precedent when it cannot describe a slot kind.
  final requiredRangeId = target?.requiresRangeId;
  if (requiredRangeId != null && range != null && range.id != requiredRangeId) {
    problems.add(
      '${target!.name} requires the Range "$requiredRangeId", '
      'but this spell uses ${range.name}',
    );
  }
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/models/spell_test.dart`
Expected: PASS

- [ ] **Step 6: Add the catalog data**

Add `"requiresRangeId": "range-personal",` to all five Sensory Target rows in
`assets/data/parameters.json`, after `"requiresVirtue"` and before `"scope"`.

- [ ] **Step 7: Verify the diff and run everything**

Run: `git diff --numstat assets/data/parameters.json`
Expected: `5	5	assets/data/parameters.json`

Run: `flutter test && flutter analyze`
Expected: PASS, exit 0

- [ ] **Step 8: Commit**

```bash
git add lib/ assets/data/parameters.json test/models/spell_test.dart
git commit -m "feat: a Target can require a Range (HoH:MC 1006)

Check 11. Closes todo item 67's Range-must-be-Personal bullet."
```

---

### Task 4: Check 12 — Intellego as a requisite

**Files:**
- Modify: `lib/models/spell.dart`, `lib/models/parameter.dart:5-17`
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Consumes: `ParameterScope.excludeTechniques`, which already exists and already holds
  `["Intellego"]` on the five rows.
- Produces: no new API. This check gives existing data a second meaning.

- [ ] **Step 1: Write the failing tests**

```dart
    test('check 12: an Intellego requisite on a Sensory Target is rejected', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final sound = Parameter(
        id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 3,
        targetType: TargetType.sensorium,
        scope: const ParameterScope(excludeTechniques: ['Intellego']),
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {'Intellego': RequisiteKind.free},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: null,
        target: sound,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );

      expect(problems, hasLength(1));
      expect(problems.single, contains('Intellego'));
      expect(problems.single, contains('Sound'));
    });

    test('check 12: a requisite the Target does not exclude is valid', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final sound = Parameter(
        id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 3,
        targetType: TargetType.sensorium,
        scope: const ParameterScope(excludeTechniques: ['Intellego']),
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {'Muto': RequisiteKind.free},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: null,
        target: sound,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );

      expect(problems, isEmpty);
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — the first test expects 1 problem and gets 0.

- [ ] **Step 3: Write check 12**

In `lib/models/spell.dart`, directly after check 11:

```dart
  // 12. HoH:MC 1009: a Sensory Magic spell "cannot employ the Technique of
  //     Intellego, even as a requisite." The scope field already keeps these
  //     Targets out of the picker for an Intellego *spell*; this reaches the
  //     other half of the same sentence.
  //
  //     Reads `scope.excludeTechniques` rather than adding a field, because
  //     that list already carries exactly the right Techniques for the only
  //     rule of this shape. ParameterScope's doc comment records that this is
  //     now the field's meaning.
  final excludedByTarget = target?.scope.excludeTechniques ?? const <String>[];
  for (final art in requisites.keys) {
    if (excludedByTarget.contains(art)) {
      problems.add(
        '${target!.name} cannot be used on a spell with a $art requisite',
      );
    }
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/models/spell_test.dart`
Expected: PASS

- [ ] **Step 5: Record the widened meaning on `ParameterScope`**

In `lib/models/parameter.dart`, the `ParameterScope` doc comment currently ends its
`excludeTechniques` paragraph with "the requisite half needs a validation check rather
than a scope field, and is todo item 67". Replace that clause with:

```dart
/// spell employing Intellego, "even as a requisite". **Both halves of that
/// sentence now read this one list:** [appliesTo] keeps the parameter out of
/// the picker for an excluded Technique, and check 12 in `spell.dart` rejects
/// an excluded Technique appearing among the spell's requisites. If a future
/// parameter ever needs to exclude a Technique while permitting it as a
/// requisite, that is when this field splits in two — not before.
```

- [ ] **Step 6: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS, exit 0

- [ ] **Step 7: Commit**

```bash
git add lib/ test/models/spell_test.dart
git commit -m "feat: a Target's excluded Techniques bar requisites too (HoH:MC 1009)

Check 12. Closes todo item 67's Intellego-requisite bullet."
```

---

### Task 5: Bidirectional pruning in the bloc

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart:340-344` (`RangeSelected`),
  `:353-372` (`TargetSelected`)
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `Parameter.forbidsTargetTypes`, `Parameter.requiresRangeId`.
- Produces: the invariant that no emitted draft violates check 10 or 11.

Range, Duration and Target are **peers** — unlike `ParameterScope`'s Technique/Form
axes, where the trigger is chosen upstream. That is why pruning runs both ways. The
rule is: **the field just edited wins; conflicting peers yield** — the same rule
`TargetSelected` already applies to `containerMode` at `:364-368`.

**`SpellDraft.copyWith` semantics, confirmed at `spell.dart:568-607`:** `range`,
`duration` and `target` use an `_unset` sentinel, so **passing an explicit `null`
clears them** and passing the current value is a no-op. `containerMode` uses plain
`??`, so **`null` means "leave alone"** and `ContainerMode.unstated` is how you clear
it. Both idioms appear below; they are not interchangeable.

- [ ] **Step 1: Write the failing tests**

Read the neighbouring tests first and match their setup — the file has an established
way of building the bloc and its catalog, and these must use the same one. The
parameters referenced below (`personal`, `room`, `voice`, `sound`) must be present in
whatever catalog the test bloc is given; add them to that fixture if absent.

```dart
    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting Personal Range clears a container Target and its mode',
      build: buildBloc,
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
      build: buildBloc,
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
      build: buildBloc,
      act: (bloc) => bloc
        ..add(RangeSelected(voice))
        ..add(TargetSelected(sound)),
      verify: (bloc) {
        expect(bloc.state.draft.range?.id, 'range-personal');
        expect(bloc.state.draft.target, sound);
      },
    );
```

The mode assertion in the first test is the one that fails against a plausible
implementation clearing only the Target — item 58's lesson.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL — the Target survives, the Range survives, the Range is not set.

- [ ] **Step 3: Implement `RangeSelected` pruning**

Replace the `RangeSelected` branch (lines 340-344):

```dart
    } else if (event is RangeSelected) {
      // Range and Target are peers, so this prunes in the opposite direction
      // from _withPrunedScopedParameters, whose Technique/Form axes are always
      // upstream. Core 12086 is the rule: a Personal Range forbids a container
      // Target. The field just edited wins and the conflicting peer yields —
      // the same rule TargetSelected applies to containerMode below.
      //
      // The mode is cleared with the Target rather than left behind: a mode
      // outliving its Target reattaches to the next container chosen, which is
      // what check 9 then rejects with no visible cause (todo item 58).
      final targetKind = state.draft.target?.targetType;
      final clearsTarget = targetKind != null &&
          event.parameter.forbidsTargetTypes.contains(targetKind);
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(
          range: event.parameter,
          // Explicit null clears (the _unset sentinel); passing the current
          // value is a no-op.
          target: clearsTarget ? null : state.draft.target,
          // null here means "leave alone" -- containerMode uses `??`.
          containerMode: clearsTarget ? ContainerMode.unstated : null,
        ),
      ));
```

- [ ] **Step 4: Implement `TargetSelected` pruning**

In the `TargetSelected` branch, keep the existing comment block, then replace the
`final keepsMode = ...` / `final draft = ...` lines with:

```dart
      // A Target may dictate its Range (HoH:MC 1006, the Sensory Targets) or be
      // forbidden by the Range already chosen (core 12086). The first wins over
      // the second: a Target that names its own Range cannot conflict with it.
      final requiredRangeId = event.parameter.requiresRangeId;
      final currentRange = state.draft.range;
      final Parameter? nextRange;
      if (requiredRangeId != null) {
        nextRange = spellEngine.allParameters
                .firstWhereOrNull((p) => p.id == requiredRangeId) ??
            currentRange;
      } else if (currentRange != null &&
          event.parameter.targetType != null &&
          currentRange.forbidsTargetTypes.contains(event.parameter.targetType)) {
        nextRange = null;
      } else {
        nextRange = currentRange;
      }

      final keepsMode = _isContainer(event.parameter);
      final draft = _withPrunedModifiers(state.draft.copyWith(
        target: event.parameter,
        range: nextRange,
        containerMode: keepsMode ? null : ContainerMode.unstated,
      ));
```

`spellEngine.allParameters` is the catalog the bloc already uses — see
`_emptySeededDraft` at `:716` and `_seedParameters` at `:679-685`, which resolves ids
the same way. `firstWhereOrNull` comes from `package:collection`, already imported and
already used at `:685`.

- [ ] **Step 5: Run to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS

- [ ] **Step 6: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS, exit 0

- [ ] **Step 7: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: Range and Target prune each other

Peers, unlike the Technique/Form scope axes, so pruning runs both ways. The
field just edited wins; conflicting peers yield."
```

---

### Task 6: Peer-aware dropdowns and the locked Range

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart:281-320`, `:684-709`
- Test: `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: the bloc invariant from Task 5. The UI reflects it; it does not enforce it.

- [ ] **Step 1: Write the failing widget tests**

Follow the existing setup in that file for pumping the screen — note it sets a
1200×5000 view at `:143-148`; match it rather than introducing another size.

```dart
    testWidgets('a Range dictated by the Target is not editable', (tester) async {
      // Pump the creation screen and select Sound as the Target first,
      // following the setup the neighbouring tests use.
      final dropdown = tester.widget<DropdownButtonFormField<Parameter>>(
        find.byKey(const Key('range-dropdown')),
      );
      expect(dropdown.onChanged, isNull);
    });

    testWidgets('container Targets are hidden while Personal Range is chosen',
        (tester) async {
      // Pump the creation screen and select Personal as the Range first.
      final dropdown = tester.widget<DropdownButtonFormField<Parameter>>(
        find.byKey(const Key('target-dropdown')),
      );
      final ids = dropdown.items!.map((i) => i.value!.id).toList();
      expect(ids, isNot(contains('target-room')));
      expect(ids, contains('target-individual'));
    });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: FAIL — `onChanged` is non-null, and `target-room` is present.

- [ ] **Step 3: Give `_buildParameterDropdown` peer awareness**

Add three optional named parameters to the signature at `:684-689`:

```dart
    Parameter? peerRange,
    Parameter? peerTarget,
    bool locked = false,
```

Replace the filter at `:690-693`:

```dart
    final categoryParameters = parameters
        .where((p) =>
            p.category == category &&
            p.scope.appliesTo(technique: technique, form: form) &&
            _compatibleWithPeers(p, peerRange: peerRange, peerTarget: peerTarget))
        .toList();
```

and the `onChanged:` line at `:707`:

```dart
      onChanged: locked ? null : onChanged,
```

A null `onChanged` is how `DropdownButtonFormField` renders as disabled, which is what
the test asserts.

Add this private top-level function to the same file:

```dart
/// Whether [candidate] can be chosen given the peer Range/Target already
/// selected. Mirrors checks 10 and 11. The bloc is what enforces them
/// (`RangeSelected`/`TargetSelected` prune); this only stops the dropdown
/// offering a choice that would immediately be undone.
bool _compatibleWithPeers(
  Parameter candidate, {
  Parameter? peerRange,
  Parameter? peerTarget,
}) {
  if (candidate.category == 'Target') {
    final kind = candidate.targetType;
    if (peerRange != null &&
        kind != null &&
        peerRange.forbidsTargetTypes.contains(kind)) {
      return false;
    }
  }
  if (candidate.category == 'Range') {
    final required = peerTarget?.requiresRangeId;
    if (required != null && candidate.id != required) return false;
    final kind = peerTarget?.targetType;
    if (kind != null && candidate.forbidsTargetTypes.contains(kind)) return false;
  }
  return true;
}
```

- [ ] **Step 4: Pass the peers at the call sites**

Range dropdown (`:281-292`) gains:

```dart
                        peerTarget: draft.target,
                        locked: draft.target?.requiresRangeId != null,
```

Target dropdown (`:309-320`) gains:

```dart
                        peerRange: draft.range,
```

The Duration dropdown (`:295-306`) gains nothing — no rule here constrains Duration.

- [ ] **Step 5: Add the reason line under a locked Range**

Directly after the Range dropdown's closing `),` at `:292`:

```dart
                      if (draft.target?.requiresRangeId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${draft.target!.name} requires this Range '
                          '(Houses of Hermes: Mystery Cults, Sensory Magic).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
```

- [ ] **Step 6: Run to verify they pass**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS, exit 0

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/spell_creation_screen.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: dropdowns respect peer constraints; a dictated Range locks"
```

---

### Task 7: Close the todo items

The corpus guard is already done — assertion 7 in
`test/data/published_spell_import_test.dart` gained coverage of all three checks in
Task 2, Step 6. This task is bookkeeping only.

**Files:**
- Modify: `.superpowers/todo.md`

- [ ] **Step 1: Confirm the corpus guard really is live**

Run: `flutter test test/data/published_spell_import_test.dart`
Expected: PASS.

Then confirm it is not passing vacuously — temporarily change `range-personal`'s
`forbidsTargetTypes` in `assets/data/parameters.json` to `["object"]`, re-run, and
confirm assertion 7 now **fails** naming real spells. **Revert that edit immediately**
and re-run to confirm green. A guard that cannot fail is not a guard.

- [ ] **Step 2: Close the todo items**

In `.superpowers/todo.md`:

- Move **item 68** to `## Completed ✅`, reduced to the decision that binds: the five
  Sensory Targets are `TargetType.sensorium`, because core 12086 plus HoH:MC 1006 make
  a container classification contradictory; magnitudes still follow the printed
  equivalences because those sentences price the Target rather than classify it.
- Tick **item 67**'s "No Intellego *as a requisite*" and "The Range must be Personal"
  bullets. Leave its "Form must suit the sensory medium" bullet open — that is item
  56's display work.
- In **item 65**, update the ⚠️ block added by `5ea41ec` to say the blocking change has
  landed, so the next reader is not warned off work that is now safe.
- Do **not** close item 69 or item 70. Item 70's other two bullets (the missing
  `size-vim` ladder, the +8 citation drift) are untouched by this work.

- [ ] **Step 3: Run the whole suite one last time**

Run: `flutter test && flutter analyze`
Expected: PASS, exit 0

- [ ] **Step 4: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close item 68 and item 67's two enforceable bullets"
```

---

## Notes for the reviewer

- **Task 1 is independently valuable and independently shippable.** It closes item 68
  and unblocks item 65 on its own, before any constraint machinery exists.
- **Task 2 Step 6 is the step to check carefully.** Passing `range: null` in
  `published_spell_import_test.dart` would compile, pass, and silently remove
  corpus-wide coverage of all three new checks. Step 1 of Task 7 exists to catch
  exactly that.
- **No spell's level changes anywhere in this plan.** `containerMode` and `targetType`
  are level-neutral and no magnitude is touched. If a level-related test starts
  failing, something is wrong.
