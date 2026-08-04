# Level Adjustments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Model the per-spell magnitude adjustments the rulebook assigns in prose — as one globally-scoped "Elaborate effect" Modifier for the nine spells that share a reason, and a free-text `(magnitude, note)` list for what is genuinely unique.

**Architecture:** Two mechanisms, deliberately separate. The Modifier is ordinary catalog data and needs no new code path. The adjustments are a new `List<LevelAdjustment>` on `Spell`/`SpellDraft`, fed into the existing magnitude pipeline so the level calculator and breakdown handle them like any other contribution. The extractor maps design-line tokens onto both via **closed tables**, never a catch-all.

**Tech Stack:** Dart/Flutter (models, engine, bloc, UI, sqflite), Python 3.13 stdlib (the import harness).

**Spec:** `docs/superpowers/specs/2026-08-04-level-adjustments-design.md`

## Global Constraints

- **Python 3.13, standard library only.** No new dependencies. Dart: no new pub packages.
- **Python tests:** `python -m unittest discover -s scripts/spell_import/tests -t .` from the repo root. `-t .` matters — modules import as `scripts.spell_import.*`.
- **Dart tests:** `flutter test` from the repo root. It does **not** run `integration_test/`.
- **`assets/data/spell_library.json` changes in exactly one task (Task 7).** In every other task it must be byte-identical — check `git status --porcelain` before committing.
- **The extractor uses closed tables, never a catch-all.** An unrecognised `+N <prose>` token must keep blocking its spell. Absorbing unknown tokens as adjustments would import real mechanisms (`+2 metal/gems`, `+1 requisite`, `+2 for up to +15 damage`) with a correct computed level and wrong modelling — invisible to the level test and permanent in the asset.
- **Never compute an adjustment magnitude from `printed − computed`.** That makes assertion 1 tautological. Hand-derived values are literals.
- **Determinism is load-bearing.** `test_two_runs_are_byte_identical` must keep passing.
- Shell is Git Bash (POSIX). Use heredocs for commit messages, never PowerShell here-strings.
- Branch `feature/level-adjustments`, spec already committed at `37a83c8`.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/models/level_adjustment.dart` | The `(magnitude, note)` value type and its serialization. Nothing else. |
| `test/models/level_adjustment_test.dart` | Its round-trip and invariants. |

**Modified:**

| File | Change |
|---|---|
| `lib/models/spell.dart` | `adjustments` field on `Spell` and `SpellDraft`, serialization, `copyWith` |
| `lib/engine/spell_level_calculator.dart` | Permit negative magnitudes; guard the resulting level instead |
| `lib/engine/spell_engine.dart` | One `LevelContribution` per adjustment |
| `lib/data/database/app_database.dart` | Schema version 5 → 6 |
| `assets/data/modifiers.json` | The `elaborate-effect` entry |
| `lib/bloc/spell_creation/spell_creation_event.dart` | Three adjustment events |
| `lib/bloc/spell_creation/spell_creation_bloc.dart` | Their handlers |
| `lib/presentation/screens/spell_creation_screen.dart` | The adjustment rows |
| `scripts/spell_import/designline.py` | Depth-aware splitting; elaborate and adjustment tables |
| `scripts/spell_import/emit.py` | Map both onto the emitted spell |
| `scripts/spell_import/extract_spells.py` | The one hand-derived magnitude |

---

### Task 1: `LevelAdjustment` model, spell fields, schema bump

**Files:**
- Create: `lib/models/level_adjustment.dart`
- Create: `test/models/level_adjustment_test.dart`
- Modify: `lib/models/spell.dart`
- Modify: `lib/data/database/app_database.dart:6`
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Consumes: `requireField<T>(map, key, context)` from `lib/utils/map_serialization.dart`.
- Produces: `LevelAdjustment({required int magnitude, required String note})` with `.toMap()`, `LevelAdjustment.fromMap(Map<String, dynamic>)`, value equality. `Spell.adjustments` and `SpellDraft.adjustments`, both `List<LevelAdjustment>`, defaulting to empty, serialized under the key `'adjustments'`.

- [ ] **Step 1: Write the failing tests**

Create `test/models/level_adjustment_test.dart`:

```dart
import 'package:eruditus/models/level_adjustment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelAdjustment', () {
    test('round-trips through toMap/fromMap', () {
      final adjustment = LevelAdjustment(magnitude: 1, note: 'fancy effect');
      expect(LevelAdjustment.fromMap(adjustment.toMap()), adjustment);
    });

    test('accepts a negative magnitude', () {
      // The Severed Limb Made Whole charges -1 because the old limb is needed.
      final adjustment =
          LevelAdjustment(magnitude: -1, note: 'because the old limb is needed');
      expect(adjustment.magnitude, -1);
      expect(LevelAdjustment.fromMap(adjustment.toMap()), adjustment);
    });

    test('accepts a zero magnitude, because some notes record that a thing is free', () {
      final adjustment = LevelAdjustment(
          magnitude: 0, note: 'mist is a purely cosmetic effect and thus is free');
      expect(adjustment.magnitude, 0);
    });

    test('rejects an empty note, because the note is the justification', () {
      expect(() => LevelAdjustment(magnitude: 1, note: '   '),
          throwsA(isA<FormatException>()));
    });

    test('fromMap rejects a missing magnitude', () {
      expect(() => LevelAdjustment.fromMap({'note': 'x'}),
          throwsA(isA<FormatException>()));
    });

    test('two adjustments with the same magnitude and note are equal', () {
      expect(LevelAdjustment(magnitude: 2, note: 'n'),
          LevelAdjustment(magnitude: 2, note: 'n'));
    });
  });
}
```

Append to `test/models/spell_test.dart`, inside its existing top-level `main`. This follows the construction that file already uses at line 14 — a `userCreated` spell, which needs no summary or description:

```dart
  test('Spell round-trips its adjustments', () {
    final spell = Spell(
      id: 'spell-adj',
      name: 'Test Spell',
      baseEffectId: '1',
      rangeId: 'param-voice',
      durationId: 'param-sun',
      targetId: 'param-individual',
      requisites: const [],
      adjustments: [
        LevelAdjustment(magnitude: -1, note: 'because the old limb is needed'),
        LevelAdjustment(magnitude: 0, note: 'purely cosmetic and thus free'),
      ],
      description: 'A test spell',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    expect(Spell.fromMap(spell.toMap()).adjustments, spell.adjustments);
  });

  test('a Spell whose map has no adjustments key parses as an empty list', () {
    final spell = Spell(
      id: 'spell-none',
      name: 'Test Spell',
      baseEffectId: '1',
      rangeId: 'param-voice',
      durationId: 'param-sun',
      targetId: 'param-individual',
      requisites: const [],
      description: 'A test spell',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final map = spell.toMap()..remove('adjustments');

    expect(Spell.fromMap(map).adjustments, isEmpty);
  });
```

Add `import 'package:eruditus/models/level_adjustment.dart';` to that file.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/level_adjustment_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'eruditus/models/level_adjustment.dart'`.

- [ ] **Step 3: Create the model**

`lib/models/level_adjustment.dart`:

```dart
import 'package:eruditus/utils/map_serialization.dart';

/// A one-off magnitude assigned to a single spell, with the prose justifying it.
///
/// Deliberately not a [Modifier]. A Modifier is a reusable catalog choice,
/// scoped to a Technique, Form or set of effects, picked from a fixed ladder.
/// An adjustment is unique to one spell and carries free text that no
/// vocabulary would capture — "because the spell allows growth or two kinds of
/// shrinking".
///
/// [magnitude] may be negative: *The Severed Limb Made Whole* charges -1
/// because the old limb is needed. It may also be zero, because some design
/// lines record that something is explicitly *free* — *Frosty Breath of the
/// Spoken Lie* notes that its mist is purely cosmetic. Such an entry changes no
/// level but must survive, because the note is the point.
class LevelAdjustment {
  final int magnitude;
  final String note;

  LevelAdjustment({required this.magnitude, required this.note}) {
    if (note.trim().isEmpty) {
      throw const FormatException(
          'LevelAdjustment: note must not be empty — the note is the justification');
    }
  }

  Map<String, dynamic> toMap() => {'magnitude': magnitude, 'note': note};

  factory LevelAdjustment.fromMap(Map<String, dynamic> map) => LevelAdjustment(
        magnitude: requireField<int>(map, 'magnitude', 'LevelAdjustment'),
        note: requireField<String>(map, 'note', 'LevelAdjustment'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LevelAdjustment &&
          other.magnitude == magnitude &&
          other.note == note);

  @override
  int get hashCode => Object.hash(magnitude, note);

  @override
  String toString() => 'LevelAdjustment($magnitude, $note)';
}
```

- [ ] **Step 4: Add the field to `Spell`**

In `lib/models/spell.dart`, add the import, then:

- field, beside `requisites` (line ~54): `final List<LevelAdjustment> adjustments;`
- constructor parameter: `this.adjustments = const [],`
- in `toMap()`, after the `requisites` line: `'adjustments': adjustments.map((a) => a.toMap()).toList(),`
- in `fromMap`, mirroring the `requisites` block exactly:

```dart
        adjustments: (map['adjustments'] as List?)
                ?.map((a) => LevelAdjustment.fromMap(a as Map<String, dynamic>))
                .toList() ??
            const [],
```

- [ ] **Step 5: Add the field to `SpellDraft`**

Same file. Add `List<LevelAdjustment> adjustments;` beside its `requisites`, default it to `[]` in the constructor body the way `requisites` is defaulted, pass it through `toSpell()`, and add it to `copyWith` following the existing `List<Requisite>? requisites` parameter pattern.

- [ ] **Step 6: Bump the schema version**

`lib/data/database/app_database.dart:6` — change `static const int _databaseVersion = 5;` to `6`, and extend the comment block above `onUpgrade` with one sentence in the same voice as the v4/v5 notes:

```
        // The v6 bump adds `adjustments` to the `spells` blob. Additive, like
        // v5, and dropped anyway under the same policy: backward compatibility
        // is not a goal here, and a silent per-field default is one more
        // implicit behavior to maintain forever.
```

The table DDL does not change — only the JSON shape inside `data`.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/models/`
Expected: PASS.

- [ ] **Step 8: Run the full Dart suite and confirm the asset is untouched**

Run: `flutter test`
Then: `git status --porcelain` — `assets/data/spell_library.json` must **not** appear.

- [ ] **Step 9: Commit**

```bash
git add lib/models/level_adjustment.dart lib/models/spell.dart \
        lib/data/database/app_database.dart test/models/
git commit -m "$(cat <<'EOF'
feat: add LevelAdjustment and carry it on Spell and SpellDraft

A one-off magnitude with the prose justifying it, for the published
spells whose design lines assign one. Negative and zero magnitudes are
both permitted: The Severed Limb Made Whole charges -1, and Frosty Breath
of the Spoken Lie records that its mist is explicitly free.

An empty note is rejected, because the note is the entire justification.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Permit negative magnitudes in the level calculator

This is the one change touching shared code every spell flows through. It deserves its own gate.

**Files:**
- Modify: `lib/engine/spell_level_calculator.dart`
- Test: `test/engine/spell_level_calculator_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `SpellLevelCalculator.calculate(int baseLevel, List<int> magnitudes) -> int`, unchanged signature, now accepting negative entries in `magnitudes` and throwing `ArgumentError` when the computed level would fall below 1.

- [ ] **Step 1: Find and read the existing test**

Run: `grep -rn "must not be negative\|SpellLevelCalculator" test/ | head`

An existing test almost certainly asserts that a negative magnitude throws. That test encodes the invariant this task deliberately reverses, so it must be **replaced**, not deleted silently. Read it before changing anything and note in your report what it asserted.

- [ ] **Step 2: Write the failing tests**

In `test/engine/spell_level_calculator_test.dart`, remove the assertion that a negative magnitude throws, and add:

```dart
    test('a negative magnitude subtracts 5 above the additive tier', () {
      // The Severed Limb Made Whole: base 25, so additive capacity is already 0.
      expect(SpellLevelCalculator.calculate(25, [1, -1]), 25);
      expect(SpellLevelCalculator.calculate(25, [-1]), 20);
    });

    test('a negative magnitude subtracts 1 inside the additive tier', () {
      // Below level 5 a magnitude is worth 1, so removing one takes 1 back.
      expect(SpellLevelCalculator.calculate(3, [1]), 4);
      expect(SpellLevelCalculator.calculate(3, [1, -1]), 3);
      expect(SpellLevelCalculator.calculate(3, [-1]), 2);
    });

    test('a negative magnitude crossing out of the multiplier tier lands on 5', () {
      expect(SpellLevelCalculator.calculate(5, [1]), 10);
      expect(SpellLevelCalculator.calculate(5, [1, -1]), 5);
    });

    test('subtracting restores additive capacity, so the next add is worth 1 again', () {
      // base 3 (capacity 2) -> +1 -> 4 (capacity 1) -> -1 -> 3 (capacity 2)
      // -> +2 -> 5, not 3 + 1 + 5.
      expect(SpellLevelCalculator.calculate(3, [1, -1, 2]), 5);
    });

    test('throws when the result would fall below 1', () {
      expect(() => SpellLevelCalculator.calculate(5, [-1, -1, -1, -1, -1]),
          throwsArgumentError);
    });

    test('a negative base level still throws', () {
      expect(() => SpellLevelCalculator.calculate(-1, const []), throwsArgumentError);
    });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/engine/spell_level_calculator_test.dart`
Expected: FAIL — `Invalid argument (magnitudes[1]): Magnitude must not be negative`.

- [ ] **Step 4: Rewrite `calculate`**

```dart
class SpellLevelCalculator {
  /// Combines a base level with a list of magnitudes.
  ///
  /// Below level 5 the rulebook's steps are 1, 2, 3, 4, 5 — so a magnitude
  /// inside that additive tier is worth 1 level, not 5. Above it, each
  /// magnitude is worth 5.
  ///
  /// Negative magnitudes are permitted: one published spell, *The Severed Limb
  /// Made Whole*, charges -1 because the old limb is needed. They mirror the
  /// positive rule — worth 1 while the spell sits inside the additive tier,
  /// 5 above it — and restore the additive capacity they give back, so that
  /// `[1, -1]` is always a no-op regardless of base level.
  static int calculate(int baseLevel, List<int> magnitudes) {
    if (baseLevel < 0) {
      throw ArgumentError.value(
        baseLevel,
        'baseLevel',
        'Base level must not be negative',
      );
    }

    int level = baseLevel;
    int additiveCapacity = (5 - baseLevel).clamp(0, double.infinity).toInt();

    for (final magnitude in magnitudes) {
      if (magnitude >= 0) {
        final additivePortion = magnitude.clamp(0, additiveCapacity);
        final multiplierPortion = magnitude - additivePortion;

        level += additivePortion;
        additiveCapacity -= additivePortion;
        level += (multiplierPortion * 5);
      } else {
        for (var step = 0; step < -magnitude; step++) {
          if (level <= 5) {
            level -= 1;
            additiveCapacity += 1;
          } else {
            level -= 5;
          }
        }
      }
    }

    if (level < 1) {
      throw ArgumentError.value(
        level,
        'magnitudes',
        'Adjustments reduced the spell below level 1',
      );
    }

    return level;
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/engine/`
Expected: PASS.

- [ ] **Step 6: Run the full Dart suite**

Run: `flutter test`
Expected: PASS. If any other test fails, it depended on the old invariant — read it, and report what it was asserting rather than adjusting it to fit.

- [ ] **Step 7: Commit**

```bash
git add lib/engine/spell_level_calculator.dart test/engine/spell_level_calculator_test.dart
git commit -m "$(cat <<'EOF'
feat: permit negative magnitudes in the level calculator

One published spell needs it: The Severed Limb Made Whole charges -1
because the old limb is needed. The old invariant rejected any negative
magnitude outright.

Negatives mirror the positive rule -- worth 1 inside the additive tier
below level 5, worth 5 above it -- and restore the capacity they give
back, so [1, -1] is a no-op at any base level. The guard moves from
"no magnitude may be negative" to "the result must be at least 1".

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: One breakdown contribution per adjustment

**Files:**
- Modify: `lib/engine/spell_engine.dart:83-128`
- Test: `test/engine/spell_engine_test.dart`

**Interfaces:**
- Consumes: `LevelAdjustment` (Task 1), the calculator's negative support (Task 2).
- Produces: `SpellEngine.calculateBreakdown(...)` gains a named parameter `List<LevelAdjustment> adjustments = const []`. Each adjustment yields one `LevelContribution(label: 'Adjustment · <note>', magnitude: <magnitude>)`.

- [ ] **Step 1: Write the failing test**

Append to `test/engine/spell_engine_test.dart`. It already defines the `_sp(...)` parameter helper and `_range`/`_duration`/`_target` at lines 13-19; reuse them:

```dart
  group('adjustments', () {
    final baseEffect = BaseEffect(
      id: '1', technique: 'Creo', form: 'Ignem',
      description: 'test', baseLevel: 10,
      provenance: Provenance(source: PublicationSource.userCreated),
    );

    LevelBreakdown breakdownWith(List<LevelAdjustment> adjustments) =>
        SpellEngine(allModifiers: const []).calculateBreakdown(
          baseEffect: baseEffect,
          range: _range,
          duration: _duration,
          target: _target,
          selectedModifiers: const {},
          requisites: const [],
          adjustments: adjustments,
        );

    test('each adjustment contributes one labelled breakdown line', () {
      final labels = breakdownWith([
        LevelAdjustment(magnitude: 1, note: 'see through intervening material'),
        LevelAdjustment(magnitude: -1, note: 'because the old limb is needed'),
      ]).contributions.map((c) => c.label).toList();

      expect(labels, contains('Adjustment · see through intervening material'));
      expect(labels, contains('Adjustment · because the old limb is needed'));
    });

    test('a positive adjustment raises the level by 5 above the additive tier', () {
      // baseLevel 10, and _range/_duration/_target are all magnitude 0.
      expect(breakdownWith(const []).level, 10);
      expect(
          breakdownWith([LevelAdjustment(magnitude: 1, note: 'fancy')]).level, 15);
    });

    test('a negative adjustment lowers it by 5', () {
      expect(breakdownWith([LevelAdjustment(magnitude: -1, note: 'old limb')]).level,
          5);
    });

    test('a zero-magnitude adjustment shows a line but changes no level', () {
      final breakdown =
          breakdownWith([LevelAdjustment(magnitude: 0, note: 'cosmetic, free')]);
      expect(breakdown.level, 10);
      expect(breakdown.contributions.map((c) => c.label),
          contains('Adjustment · cosmetic, free'));
    });
  });
```

Two things to confirm against the file as you write this: the `SpellEngine` constructor's exact parameter name for its modifier list, and whether `LevelBreakdown` exposes the computed level as `.level` or under another name. Adjust the two references if they differ — everything else stands.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — no named parameter `adjustments`.

- [ ] **Step 3: Add the parameter and the contributions**

In `calculateBreakdown`'s signature, after `required List<Requisite> requisites,`:

```dart
    List<LevelAdjustment> adjustments = const [],
```

After the `for (final requisite in requisites)` loop:

```dart
    // Adjustments are magnitudes like any other, so they flow into the same
    // calculator call below and need no special case there.
    for (final adjustment in adjustments) {
      contributions.add(LevelContribution(
          label: 'Adjustment · ${adjustment.note}',
          magnitude: adjustment.magnitude));
    }
```

Add the import for `level_adjustment.dart`.

- [ ] **Step 4: Pass adjustments from every caller**

Run: `grep -rn "calculateBreakdown(" lib/ test/ | grep -v "LevelBreakdown calculateBreakdown"`

For each call site that has a `Spell` or `SpellDraft` in hand, pass `adjustments: spell.adjustments`. The parameter defaults to empty, so a missed call site compiles and silently drops adjustments — that is why this step enumerates them rather than relying on the compiler.

- [ ] **Step 5: Run the tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/engine/spell_engine.dart test/engine/spell_engine_test.dart
git commit -m "$(cat <<'EOF'
feat: show one breakdown line per level adjustment

Adjustments enter the same contribution list as parameters, requisites
and modifiers, so they reach the calculator through the existing path and
need no special case in it.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: The `elaborate-effect` Modifier

**Files:**
- Modify: `assets/data/modifiers.json`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: a modifier with id `elaborate-effect` and option ids `elaborate-effect-none`, `elaborate-effect-minor`, `elaborate-effect-considerable`, `elaborate-effect-extensive` at magnitudes 0, 1, 2, 3. Task 6 maps design-line wordings onto these exact ids.

- [ ] **Step 1: Write the failing test**

Append to `test/data/datasources/asset_data_loader_test.dart`:

```dart
    test('the elaborate-effect modifier is globally scoped with a 0-3 ladder', () {
      final modifiers = await AssetDataLoader().loadModifiers();
      final elaborate = modifiers.firstWhere((m) => m.id == 'elaborate-effect');

      expect(elaborate.scope.technique, isNull,
          reason: 'the rule applies to any Technique');
      expect(elaborate.scope.form, isNull, reason: 'the rule applies to any Form');
      expect(elaborate.selectionMode, ModifierSelectionMode.single);
      expect(elaborate.options.map((o) => o.magnitude).toList(), [0, 1, 2, 3]);
    });
```

Match the surrounding tests' async style — that file already loads assets, so copy its `setUp`/`await` idiom rather than inventing one.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — `Bad state: No element`.

- [ ] **Step 3: Add the catalog entry**

Append to `assets/data/modifiers.json`. Copy the `citations` and `source` field shapes from the existing `creo-auram-unnatural` entry in the same file rather than guessing them:

```json
{
  "id": "elaborate-effect",
  "name": "Elaborate effect",
  "description": "The storyguide charges magnitudes when an effect is more elaborate than its guideline describes",
  "selectionMode": "single",
  "scope": {
    "technique": null,
    "form": null,
    "effectIds": [],
    "excludeTechniques": []
  },
  "source": "published",
  "options": [
    {
      "id": "elaborate-effect-none",
      "label": "As the guideline describes",
      "magnitude": 0
    },
    {
      "id": "elaborate-effect-minor",
      "label": "Slightly more elaborate",
      "magnitude": 1
    },
    {
      "id": "elaborate-effect-considerable",
      "label": "Considerably more elaborate",
      "magnitude": 2
    },
    {
      "id": "elaborate-effect-extensive",
      "label": "Extensively more elaborate",
      "magnitude": 3
    }
  ]
}
```

This is the catalog's **first** globally-scoped modifier — every existing entry is scoped by Technique, Form or `effectIds`. That is intended: the rule genuinely applies to any spell, so it appears in every spell's creation UI.

- [ ] **Step 4: Run the tests**

Run: `flutter test`
Expected: PASS. Note that some tests derive counts from the raw JSON — if a count assertion fails, it is self-healing by design and the failure means something else.

- [ ] **Step 5: Confirm the asset is untouched**

Run: `git status --porcelain` — `assets/data/spell_library.json` must not appear. `modifiers.json` should.

- [ ] **Step 6: Commit**

```bash
git add assets/data/modifiers.json test/data/datasources/asset_data_loader_test.dart
git commit -m "$(cat <<'EOF'
feat: add the globally-scoped Elaborate effect modifier

Nine published spells give one reason in nine wordings -- fancy effect,
complex effect, special effect, additional effect, elaborate design. One
catalog entry covers them all, so the "would pollute the catalog with
single-use entries" objection does not apply.

The catalog's first entry with a null Technique and Form: the rule is
general, so it is offered on every spell.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Adjustment rows in the creation screen

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_event.dart`
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart`
- Modify: `lib/presentation/screens/spell_creation_screen.dart`
- Test: `test/bloc/spell_creation_bloc_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: `LevelAdjustment` (Task 1), `SpellDraft.adjustments` (Task 1).
- Produces: `AdjustmentAdded()`, `AdjustmentRemoved(int index)`, `AdjustmentUpdated(int index, int magnitude, String note)`.

- [ ] **Step 1: Write the failing bloc tests**

Append to `test/bloc/spell_creation_bloc_test.dart`, matching its existing `blocTest` style:

The file builds its bloc as `SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository)` using fixtures already defined at the top — reuse that exact expression:

```dart
  blocTest<SpellCreationBloc, SpellCreationState>(
    'AdjustmentAdded appends a zero-magnitude row',
    build: () => SpellCreationBloc(
        spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc.add(const AdjustmentAdded()),
    verify: (bloc) {
      expect(bloc.state.draft.adjustments.length, 1);
      expect(bloc.state.draft.adjustments.first.magnitude, 0);
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
    'an out-of-range index is ignored rather than throwing',
    build: () => SpellCreationBloc(
        spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc
      ..add(const AdjustmentRemoved(0))
      ..add(const AdjustmentUpdated(3, 1, 'nowhere')),
    verify: (bloc) => expect(bloc.state.draft.adjustments, isEmpty),
  );
```

An added row starts at magnitude 0 with a placeholder note, because `LevelAdjustment` rejects an empty note. Use the literal `'(describe this adjustment)'` as that placeholder, in both the bloc and the test.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL — `AdjustmentAdded` is not defined.

- [ ] **Step 3: Add the events**

In `lib/bloc/spell_creation/spell_creation_event.dart`, following the `RequisiteAdded`/`RequisiteRemoved` pattern:

```dart
class AdjustmentAdded extends SpellCreationEvent {
  const AdjustmentAdded();
  @override
  List<Object?> get props => const [];
}

class AdjustmentRemoved extends SpellCreationEvent {
  final int index;
  const AdjustmentRemoved(this.index);
  @override
  List<Object?> get props => [index];
}

class AdjustmentUpdated extends SpellCreationEvent {
  final int index;
  final int magnitude;
  final String note;
  const AdjustmentUpdated(this.index, this.magnitude, this.note);
  @override
  List<Object?> get props => [index, magnitude, note];
}
```

Adjustments are keyed by index, unlike requisites which key on `art`, because an adjustment has no natural key.

- [ ] **Step 4: Add the handlers**

This bloc does **not** use `on<Event>` registrations — it is a single `if / else if` chain on the event type. Add three more branches after the `RequisiteKindChanged` branch, following the shape of the `RequisiteAdded` branch exactly:

```dart
    } else if (event is AdjustmentAdded) {
      final updated = [
        ...state.draft.adjustments,
        LevelAdjustment(magnitude: 0, note: '(describe this adjustment)'),
      ];
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    } else if (event is AdjustmentRemoved) {
      // Index-keyed, so a stale index from a rebuild-in-flight must be
      // ignored rather than throwing RangeError into the bloc.
      if (event.index < 0 || event.index >= state.draft.adjustments.length) return;
      final updated = [...state.draft.adjustments]..removeAt(event.index);
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    } else if (event is AdjustmentUpdated) {
      if (event.index < 0 || event.index >= state.draft.adjustments.length) return;
      final updated = [...state.draft.adjustments];
      updated[event.index] =
          LevelAdjustment(magnitude: event.magnitude, note: event.note);
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(adjustments: updated),
      ));
    }
```

Every branch builds a **new list** rather than mutating the existing one, matching how `RequisiteAdded` does it — a mutated list would not compare unequal, and the state would not emit.

Add the `level_adjustment.dart` import.

- [ ] **Step 5: Run the bloc tests**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS.

- [ ] **Step 6: Add the UI section**

In `spell_creation_screen.dart`, add an "Adjustments" section modelled on the existing requisites section: an empty-state message, one row per adjustment (a magnitude stepper permitting negatives, a note `TextFormField`, a remove button), and an add button dispatching `AdjustmentAdded`.

**Two things this list needs that the requisites section does not:**

- Each row's `TextFormField` needs a `Key` derived from its index (`ValueKey('adjustment-note-$index')`), so Flutter does not reuse a controller across rows when one is removed mid-list.
- The note field must dispatch `AdjustmentUpdated` on submit/focus-loss rather than on every keystroke, or every character re-emits state and rebuilds the list.

- [ ] **Step 7: Write the re-render widget test**

This is the test that matters. Append to `test/presentation/screens/spell_creation_screen_test.dart`, reusing that file's existing mock-bloc setup and its `pumpWidget` helper for the creation screen:

```dart
    testWidgets('removing a row leaves the surviving notes on the right rows',
        (tester) async {
      // A mocked bloc emits no new state, so an interaction never triggers the
      // rebuild — which is exactly how the add-requisite crash stayed invisible
      // to six passing widget tests (todo item 6). Drive real states through a
      // controller so the rebuild actually happens.
      final controller = StreamController<SpellCreationState>.broadcast();
      addTearDown(controller.close);

      SpellCreationState stateWith(List<String> notes) => SpellCreationState(
            status: SpellCreationStatus.editing,
            draft: SpellDraft(
              id: 'draft-1',
              adjustments: [
                for (var i = 0; i < notes.length; i++)
                  LevelAdjustment(magnitude: i + 1, note: notes[i]),
              ],
            ),
          );

      final initial = stateWith(['first', 'second', 'third']);
      when(() => mockBloc.state).thenReturn(initial);
      whenListen(mockBloc, controller.stream, initialState: initial);

      await tester.pumpWidget(/* the file's creation-screen pump helper */);
      await tester.pump();
      expect(find.text('second'), findsOneWidget);

      // Now the middle row goes away.
      final after = stateWith(['first', 'third']);
      when(() => mockBloc.state).thenReturn(after);
      controller.add(after);
      await tester.pump();

      expect(find.text('first'), findsOneWidget);
      expect(find.text('third'), findsOneWidget);
      expect(find.text('second'), findsNothing,
          reason: 'a stale TextEditingController would keep rendering the '
              'removed row’s text against a surviving row');
    });
```

Two things to reconcile against the file as you write it: its existing mock-bloc variable name and `pumpWidget` helper (substitute them for `mockBloc` and the marked call), and whether it already imports `dart:async` and `bloc_test`'s `whenListen`. Add whichever imports are missing.

If the file's mock setup makes `whenListen` impractical, cover this in `integration_test/` instead and say so explicitly in your report. **Do not** substitute a single-state test that asserts a row renders — that passes without exercising the rebuild, and proves nothing about the failure this guards.

- [ ] **Step 8: Run the Dart suite**

Run: `flutter test`
Expected: PASS. Then run the integration suite if you added a test there: `flutter test integration_test/ -d windows`.

- [ ] **Step 9: Commit**

```bash
git add lib/bloc/spell_creation/ lib/presentation/screens/spell_creation_screen.dart \
        test/bloc/spell_creation_bloc_test.dart \
        test/presentation/screens/spell_creation_screen_test.dart
git commit -m "$(cat <<'EOF'
feat: let the creation screen add, edit and remove level adjustments

Rows are keyed by index because an adjustment has no natural key, unlike
a requisite which keys on its art. Each note field carries an index-derived
Key so Flutter does not reuse a controller across rows when one is removed
mid-list, and the re-render case is covered by driving real states through
the mocked bloc rather than pumping a single state.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Extractor — depth-aware splitting, and two closed tables

**Files:**
- Modify: `scripts/spell_import/designline.py`
- Modify: `scripts/spell_import/emit.py`
- Test: `scripts/spell_import/tests/test_designline.py`

**Interfaces:**
- Consumes: the `elaborate-effect` option ids (Task 4).
- Produces: `Token` gains kinds `"elaborate"` and `"adjustment"`; adjustment tokens carry `.note` holding the raw pre-strip text. `emit.build_spell` emits `adjustments` and the `elaborate-effect` selection.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/spell_import/tests/test_designline.py`:

```python
class SplittingTest(unittest.TestCase):
    def test_a_comma_inside_parentheses_does_not_split_a_token(self):
        design = designline.parse_design(
            "(Base 1, +1 Touch, +4 Year, +1 Size (for a total of +4 Size, including "
            "the +3 from the guideline))"
        )
        labels = [t.label for t in design.tokens]
        self.assertIn("Size", labels)
        self.assertNotIn("including the +3 from the guideline", labels)


class ElaborateEffectTest(unittest.TestCase):
    def test_each_known_wording_becomes_an_elaborate_token(self):
        for text, magnitude in [
            ("(Base 3, +1 Touch, +1 fancy effect)", 1),
            ("(Base 3, +1 Touch, +2 fancy effect)", 2),
            ("(Base 4, +1 Eye, +1 complex effect)", 1),
            ("(Base 25, +3 Moon, +1 for special effect)", 1),
            ("(Base 5, +1 Touch, +1 additional effect)", 1),
            ("(Base 10, +1 Touch, +3 elaborate design)", 3),
        ]:
            with self.subTest(text=text):
                tokens = [t for t in designline.parse_design(text).tokens
                          if t.kind == "elaborate"]
                self.assertEqual(len(tokens), 1)
                self.assertEqual(tokens[0].magnitude, magnitude)


class AdjustmentTest(unittest.TestCase):
    def test_an_allow_listed_token_becomes_an_adjustment(self):
        design = designline.parse_design(
            "(Base 25, +1 Touch, -1 because the old limb is needed)"
        )
        adj = [t for t in design.tokens if t.kind == "adjustment"]
        self.assertEqual(len(adj), 1)
        self.assertEqual(adj[0].magnitude, -1)
        self.assertEqual(adj[0].note, "because the old limb is needed")

    def test_the_note_keeps_text_that_parenthetical_stripping_would_remove(self):
        design = designline.parse_design(
            "(Base 2, +1 Touch, +2 Special (based on Concentration))"
        )
        adj = [t for t in design.tokens if t.kind == "adjustment"]
        self.assertEqual(adj[0].note, "Special (based on Concentration)")

    def test_an_unlisted_token_still_raises(self):
        # The allow-list is closed on purpose: absorbing unknown tokens would
        # import real mechanisms as free text, with a correct level and wrong
        # modelling. See the spec's "an allow-list, never a catch-all".
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 4, +2 for up to +15 damage)")
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 5, +2 metal/gems)")
```

- [ ] **Step 2: Run to verify failure**

Run: `python -m unittest scripts.spell_import.tests.test_designline -v`
Expected: FAIL — `AttributeError: 'Token' object has no attribute 'note'` and the elaborate/adjustment tokens raising `UnknownToken`.

- [ ] **Step 3: Replace the splitter with a depth-aware one**

In `designline.py`, replace the `_PARENTHETICAL.sub` + `re.split` pair in `parse_design` with a splitter that never breaks inside parentheses, and keep both forms of each part:

```python
def _split_parts(text: str) -> list[tuple[str, str]]:
    """Split on top-level commas and periods, keeping raw and stripped forms.

    Parentheticals must survive splitting for two reasons: a bracketed aside
    can itself contain a comma ("+1 Size (for a total of +4 Size, including
    ...)"), which the old blanket strip-then-split turned into two bogus
    tokens; and for adjustment tokens the aside IS the content -- "+2 Special
    (based on Concentration)" carries all its meaning in the bracket.

    Returns (raw, stripped) pairs. Tokenising reads `stripped`; adjustment
    notes read `raw`.
    """
    parts: list[tuple[str, str]] = []
    depth = 0
    current: list[str] = []

    for index, char in enumerate(text):
        if char == "(":
            depth += 1
        elif char == ")":
            depth = max(0, depth - 1)

        at_boundary = char in ",." and depth == 0 and (
            index + 1 >= len(text) or text[index + 1].isspace()
        )
        if at_boundary:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)

    parts.append("".join(current))

    result = []
    for part in parts:
        raw = part.strip()
        if not raw:
            continue
        result.append((raw, _PARENTHETICAL.sub("", raw).strip()))
    return result
```

In `parse_design`, strip the outer brackets as today, then use `_split_parts(inner)`. Match the base term against the first pair's *stripped* form, and tokenise each remaining pair's stripped form while keeping its raw form available.

**This is the riskiest edit in the plan.** It changes how every design line is split, so it could alter existing spells' parsing. `RegenerationTest` is the guard: if any currently-imported spell changes, the committed asset stops matching a fresh run and that test fails. Do not proceed past Step 6 with it failing.

- [ ] **Step 4: Add `note` to `Token` and the two tables**

Add an optional `note: str | None = None` field to the `Token` dataclass. Then, above `parse_design`:

```python
# Nine spells give one reason in nine wordings. Each maps to the
# `elaborate-effect` modifier; the magnitude comes from the printed token.
ELABORATE_LABELS = frozenset({
    "fancy effect",
    "complex effect",
    "for special effect",
    "additional effect",
    "elaborate design",
})

# Closed allow-list of per-spell adjustments, matched exactly. Anything not
# here keeps blocking its spell -- absorbing unknown "+N <prose>" tokens
# would import real mechanisms (metal/gems, damage scaling, requisites) with
# a correct computed level and wrong modelling, invisible to the level test.
ADJUSTMENT_LABELS = frozenset({
    "for shape and primary motivation",
    "see through intervening material",
    "to allow various shapes",
    "for slightly unnatural control",
    "because the spell allows growth or two kinds of shrinking",
    "because the old limb is needed",
    "Special",
    "Special based on Mom",
})
```

In the token loop, after the magnitude and label are parsed, check `ELABORATE_LABELS` first, then `ADJUSTMENT_LABELS` (emitting a token whose `note` is the raw part with its leading `+N `/`-N ` removed), then fall through to the existing parameter/modifier/requisite handling, and finally `raise UnknownToken`.

- [ ] **Step 5: Map both onto the emitted spell in `emit.py`**

In `build_spell`, add the adjustments list:

```python
    adjustments = [
        {"magnitude": token.magnitude, "note": token.note}
        for token in design.tokens
        if token.kind == "adjustment"
    ]
    if adjustments:
        spell["adjustments"] = adjustments
```

Only set the key when non-empty, so spells without adjustments keep their current serialized shape.

In `_selected_modifiers`, handle the `elaborate` kind by selecting the option at the token's magnitude:

```python
    _ELABORATE_OPTIONS = {
        0: "elaborate-effect-none",
        1: "elaborate-effect-minor",
        2: "elaborate-effect-considerable",
        3: "elaborate-effect-extensive",
    }
```

Raise `designline.UnknownToken` for a magnitude outside that map rather than defaulting, so an unexpected value blocks its spell instead of importing a wrong one.

- [ ] **Step 6: Run the Python suite**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS, including `RegenerationTest`. If `RegenerationTest` fails, the splitter change altered an existing spell — investigate before going further; do not run `--write`.

- [ ] **Step 7: Confirm the asset is untouched and commit**

Run: `git status --porcelain` — `assets/data/spell_library.json` must **not** appear yet.

```bash
git add scripts/spell_import/designline.py scripts/spell_import/emit.py \
        scripts/spell_import/tests/test_designline.py
git commit -m "$(cat <<'EOF'
feat: recognise elaborate-effect and per-spell adjustment tokens

Splitting is now parenthesis-aware. The old code stripped every bracketed
aside before splitting on commas, which both broke "+1 Size (for a total
of +4 Size, including ...)" into bogus tokens and destroyed the content of
"+2 Special (based on Concentration)" -- where the bracket carries all the
meaning.

Both new tables are closed. An unrecognised "+N <prose>" token still
blocks its spell, because absorbing unknown tokens would import real
mechanisms as free text with a correct level and wrong modelling.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Hand-derive one magnitude, then regenerate the asset

**Files:**
- Modify: `scripts/spell_import/extract_spells.py`
- Modify: `assets/data/spell_library.json` (generated)
- Modify: `scripts/spell_import/source.lock`, `scripts/spell_import/import_report.md` (generated)
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: the regenerated library.

- [ ] **Step 1: Find the printed level and compute the gap by hand**

Run:

```bash
python - <<'PY'
from scripts.spell_import import blocks, sources
lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
for b in blocks.parse_de(lines):
    if b.name in {"The Shadow of Human Life", "Mists of Change"}:
        print(b.name, "| printed:", b.printed_level, "| stat:", b.stat)
        print("   design:", b.design_line)
PY
```

Work out by hand what magnitude makes *The Shadow of Human Life* compute to its printed level, and **write down the arithmetic in your report**.

**Do not compute it in code as `printed − computed`.** That would make assertion 1 tautological for this spell — computed would equal printed by construction, and the test could never fail. The value is a literal, checked *by* the level test.

*Mists of Change* is not derivable: its stat line carries `D: Sun & Year`, two durations, which no adjustment expresses. Leave it blocked.

- [ ] **Step 2: Write the failing test**

Append to `scripts/spell_import/tests/test_extract.py`:

```python
class HandDerivedAdjustmentTest(unittest.TestCase):
    def test_the_shadow_of_human_life_imports(self):
        report = extract_spells.run(write=False)
        self.assertIn("The Shadow of Human Life", {s["name"] for s in report.spells})

    def test_mists_of_change_stays_blocked_on_its_two_durations(self):
        # D: Sun & Year -- two durations, which no adjustment can express.
        report = extract_spells.run(write=False)
        self.assertIn("Mists of Change", {name for name, _ in report.blocked})
```

- [ ] **Step 3: Add the hand-derived entry**

In `extract_spells.py`, beside the existing `HAND_DERIVED` dict, add a constant in the same documented style — a mapping from spell name to the adjustment magnitude, with a comment giving the arithmetic you worked out in Step 1 and stating that the value is a literal checked by assertion 1, never derived from the level gap.

Apply it in `run()` where the design tokens are turned into the emitted spell.

- [ ] **Step 4: Run the suite**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: the two new tests PASS. `RegenerationTest` will now **fail** — the extractor produces more spells than the committed asset holds. That is expected and is what the next step resolves.

- [ ] **Step 5: Regenerate, and read the report**

```bash
python -m scripts.spell_import.extract_spells --write --accept-source
```

The `--accept-source` flag is required because this run changes the asset. Then:

```bash
cat scripts/spell_import/import_report.md
git diff --stat assets/data/spell_library.json
```

**Read the report before committing.** It lists every spell that moved from blocked to imported and every spell whose level or modelling changed. Check specifically that no spell you did not expect has *changed* — added spells are the point, but a changed existing spell means the Task 6 splitter altered something. Put the report's contents in your task report.

- [ ] **Step 6: Run both suites**

```bash
python -m unittest discover -s scripts/spell_import/tests -t .
flutter test
```

Expected: both PASS. The Dart asset assertions now verify the new spells' levels, which is what checks the hand-derived magnitude.

- [ ] **Step 7: Commit**

```bash
git add scripts/spell_import/extract_spells.py \
        scripts/spell_import/tests/test_extract.py \
        scripts/spell_import/source.lock \
        scripts/spell_import/import_report.md \
        assets/data/spell_library.json
git commit -m "$(cat <<'EOF'
feat: import the spells unblocked by level adjustments

Hand-derives the one magnitude the rulebook states as prose without a
number, for The Shadow of Human Life. The value is a literal with its
arithmetic recorded, never computed from printed minus computed -- that
would make the level assertion tautological for this spell.

Mists of Change stays blocked: its stat line carries two durations,
which no adjustment can express.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Final verification

- [ ] **Both suites green**

```bash
python -m unittest discover -s scripts/spell_import/tests -t .
flutter test
```

- [ ] **The blocked count actually moved**

```bash
python -m scripts.spell_import.extract_spells
```

Record the imported/blocked/unresolved numbers. Before this branch they were 250 / 110 / 0. The new numbers are the deliverable's measure — no target is set, because several of these spells may carry a second blocker.

- [ ] **Update `.superpowers/todo.md`**

Mark item 24 complete with what landed, and item 26 complete-except-for the two spells that need item 25 and a stat-line fix. Add to item 29's list: *Ball of Abysmal Flame* needs `;` handling in the design-line splitter. Reference the spec and this plan.

```bash
git add .superpowers/todo.md
git commit -m "$(cat <<'EOF'
docs: record items 24 and 26 as complete

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```
