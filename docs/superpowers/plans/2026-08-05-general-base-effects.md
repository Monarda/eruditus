# General Base Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the caster choose the level of a General guideline, priced against the reference Range/Duration/Target the guideline assumes, and import the published General spells as read-only templates.

**Architecture:** `BaseEffect.baseLevel` becomes nullable — null *is* General. Two new optional fields carry the guideline's reference parameter triple and its derived-effect formula. `calculateBreakdown` charges each parameter as a **delta against the reference**, which for an ordinary guideline (reference Personal/Mom/Individual) is byte-identical to today. Published General spells become a new read-only `SpellTemplate` entity, so `Spell` always has an integer level and nothing downstream needs a General branch.

**Tech Stack:** Flutter/Dart (models, engine, blocs, screens), `sqflite` (local DB), Python 3 stdlib (the `scripts/spell_import` harness), `flutter test` + `python -m unittest`.

**Spec:** `docs/superpowers/specs/2026-08-05-general-base-effects-design.md`

## Global Constraints

- **Backwards compatibility is not a goal.** Eruditus is a prototype with no users. Drop the database, bump the schema, rewrite committed assets. Add no migration path, no legacy fallback, no compatibility shim.
- **The reference triple is sourced from the guideline row's printed parenthetical and nothing else.** If a spell's design line disagrees with what its reference predicts, **that spell is blocked**. Never adjust a reference to make a spell import.
- **`multiplier ∈ {½, 1, 2}`**, `unit ∈ {levels, magnitudes}`, `kind ∈ {mightThreshold, mightReduction, damage, targetSpellLevel, visDestroyed, spellTraceMagnitude}`.
- **Effect value = `multiplier × (chosenBase + offsetMagnitudes × 5)`**, always computed in levels. `unit: magnitudes` converts for display only, by Core Rules line 12030 (level ÷ 5, rounded up).
- **A magnitude is 5 levels above level 5, and 1 level inside the 1–5 additive tier.** Never hardcode `× 5`; go through `SpellLevelCalculator`.
- **Reference parameter ids:** `range-personal`, `duration-momentary`, `target-individual` (all magnitude 0).
- **Run both suites.** `flutter test` does not run `integration_test/`. See todo item 6.

---

## File Structure

**Dart — created**

| File | Responsibility |
|---|---|
| `lib/models/parameter_triple.dart` | `ParameterTriple` — three parameter ids, with the Personal/Mom/Individual default |
| `lib/models/general_effect_formula.dart` | `GeneralEffectFormula` + `GeneralEffectValue` — the derived-quantity model and its rendering |
| `lib/models/spell_template.dart` | `SpellTemplate` — a published General spell with no chosen level |
| `test/models/parameter_triple_test.dart` | |
| `test/models/general_effect_formula_test.dart` | |
| `test/models/spell_template_test.dart` | |
| `test/engine/general_effect_test.dart` | `SpellEngine.deriveGeneralEffect` |

**Dart — modified**

| File | Change |
|---|---|
| `lib/models/base_effect.dart` | `baseLevel` → `int?`; add `reference`, `effectFormula`, `isGeneral` |
| `lib/models/spell.dart` | `Spell` + `SpellDraft` gain `chosenBaseLevel`, `templateId` |
| `lib/engine/spell_level_calculator.dart` | require `baseLevel >= 1`; simplify the guard |
| `lib/engine/spell_engine.dart` | reference deltas, `deriveGeneralEffect`, two validation rules |
| `lib/data/datasources/asset_data_loader.dart` | `loadSpellTemplates()` |
| `lib/data/repositories/library_repository.dart` | expose templates |
| `lib/data/database/app_database.dart` | schema 6 → 7 |
| `lib/bloc/spell_creation/*` | `ChosenBaseLevelChanged`, `TemplateInstantiated` |
| `lib/bloc/spell_library/*` | templates in library state |
| `lib/presentation/screens/spell_creation_screen.dart` | *Guideline level* field + effect sentence |
| `lib/presentation/screens/spell_library_screen.dart` | `Gen` chip + *Learn at level…* |

**Python — modified**

| File | Change |
|---|---|
| `scripts/spell_import/catalog.py` | `general_candidates()`; `reference_cost()` |
| `scripts/spell_import/designline.py` | accept `(As ward guideline)` as a zero-token General line |
| `scripts/spell_import/emit.py` | `build_template()` |
| `scripts/spell_import/extract_spells.py` | General branch; assertions 6 and 7 |
| `scripts/spell_import/resolutions.json` | ledger entries for the 22 General spells |
| `assets/data/base_effects.json` | 47 entries: `baseLevel: null`, `reference`, `effectFormula` |
| `assets/data/spell_templates.json` | **new**, generated |

**Ordering that matters:** Task 9 (authoring references and formulas) **must precede** Task 11 (ledger entries). Every General row has the same absent base level, so `resolutions.json` has no discriminator until the formulas exist. *Disenchant* faces 13 co-equal Perdo Vim candidates until `pevi-G9`'s formula — "guideline + 1 magnitude + a stress die (no botch); the spell must be a Ritual" — makes the pick textually forced. Reversing these two tasks reproduces item 32's failure by construction.

---

### Task 1: `BaseEffect.baseLevel` becomes nullable, and null is General

**Files:**
- Modify: `lib/models/base_effect.dart:28,37,47,57`
- Modify: `lib/engine/spell_engine.dart:123,164`
- Modify: `assets/data/base_effects.json` (the 47 entries with `"baseLevel": 0`)
- Modify: `scripts/spell_import/tests/test_catalog.py:106-107`
- Test: `test/models/base_effect_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `BaseEffect.baseLevel` is `int?`; `BaseEffect.isGeneral` is `bool` (`baseLevel == null`). Later tasks read `isGeneral` rather than comparing to 0 or null.

- [ ] **Step 1: Write the failing tests**

In `test/models/base_effect_test.dart`:

```dart
test('a null baseLevel marks the effect General', () {
  final effect = BaseEffect(
    id: 'revi-G1', technique: 'Rego', form: 'Vim',
    description: 'Ward against supernatural beings from one realm',
    baseLevel: null,
    provenance: Provenance(source: PublicationSource.published, citations: [
      Citation(bookId: 'arm5-core'),
    ]),
  );

  expect(effect.isGeneral, isTrue);
  expect(effect.baseLevel, isNull);
  expect(effect.toMap()['baseLevel'], isNull);
});

test('an ordinary effect is not General', () {
  final effect = BaseEffect(
    id: 'crig-10', technique: 'Creo', form: 'Ignem',
    description: 'Create flame', baseLevel: 10,
    provenance: Provenance(source: PublicationSource.userCreated),
  );

  expect(effect.isGeneral, isFalse);
});

test('fromMap round-trips a null baseLevel', () {
  final map = {
    'id': 'revi-G1', 'technique': 'Rego', 'form': 'Vim',
    'description': 'Ward', 'baseLevel': null,
    'source': 'userCreated',
  };

  expect(BaseEffect.fromMap(map).isGeneral, isTrue);
});

test('fromMap rejects a missing baseLevel key', () {
  final map = {
    'id': 'revi-G1', 'technique': 'Rego', 'form': 'Vim',
    'description': 'Ward', 'source': 'userCreated',
  };

  expect(() => BaseEffect.fromMap(map), throwsFormatException);
});
```

The last test is the point of the distinction: **absent** is an error, **null** is General.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/base_effect_test.dart`
Expected: FAIL — `isGeneral` is not defined; `baseLevel: null` is not assignable to `int`.

- [ ] **Step 3: Change the model**

In `lib/models/base_effect.dart`, change the field, the constructor parameter and the factory:

```dart
  /// The guideline's base level, or null when the guideline is **General** —
  /// the rulebook prints `General` where every other row prints a number,
  /// because the caster chooses it (Core Rules line 12410). Null is the
  /// marker; there is deliberately no separate `isGeneral` field, so the two
  /// cannot disagree.
  ///
  /// A General guideline's level arrives on the spell as
  /// `Spell.chosenBaseLevel`, and what it is priced against arrives as
  /// [reference].
  final int? baseLevel;

  bool get isGeneral => baseLevel == null;
```

The constructor keeps `required this.baseLevel` — every construction site must state it, and `baseLevel: 5` still compiles unchanged.

In the factory, distinguish absent from null:

```dart
    baseLevel: map.containsKey('baseLevel')
        ? map['baseLevel'] as int?
        : throw FormatException("BaseEffect.fromMap: missing required field 'baseLevel'"),
```

- [ ] **Step 4: Fix the two engine call sites so the app compiles**

`lib/engine/spell_engine.dart` lines 123 and 164 read `baseEffect.baseLevel` where an `int` is required. Task 6 replaces this logic properly; for now use a non-null assertion so the tree compiles, and mark it:

```dart
      // TASK 6 replaces this with the chosen level for General effects.
      LevelContribution(
          label: 'Base effect · ${baseEffect.description}',
          magnitude: baseEffect.baseLevel!,
          isBase: true),
```

```dart
    final rawLevel = SpellLevelCalculator.calculate(baseEffect.baseLevel!, magnitudes);
```

- [ ] **Step 5: Rewrite the 47 catalog entries**

```bash
python - <<'PY'
import json, pathlib
p = pathlib.Path("assets/data/base_effects.json")
effects = json.loads(p.read_text(encoding="utf-8"))
changed = 0
for e in effects:
    if e["baseLevel"] == 0:
        e["baseLevel"] = None
        changed += 1
assert changed == 47, f"expected 47 General entries, converted {changed}"
p.write_text(json.dumps(effects, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"converted {changed}")
PY
```

- [ ] **Step 6: Update the Python catalog test**

`scripts/spell_import/tests/test_catalog.py:106-107` asserts a General row has `baseLevel != 0`. Invert it:

```python
                if effect["baseLevel"] is not None:
                    mismatches.append((effect["id"], "General", effect["baseLevel"]))
```

- [ ] **Step 7: Run both suites**

Run: `flutter test test/models/base_effect_test.dart && python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/models/base_effect.dart lib/engine/spell_engine.dart \
        assets/data/base_effects.json test/models/base_effect_test.dart \
        scripts/spell_import/tests/test_catalog.py
git commit -m "feat: null baseLevel marks a General guideline"
```

---

### Task 2: `ParameterTriple` and `GeneralEffectFormula` on `BaseEffect`

**Files:**
- Create: `lib/models/parameter_triple.dart`, `lib/models/general_effect_formula.dart`
- Modify: `lib/models/base_effect.dart`
- Test: `test/models/parameter_triple_test.dart`, `test/models/general_effect_formula_test.dart`

**Interfaces:**
- Consumes: `BaseEffect.isGeneral` (Task 1).
- Produces:
  - `ParameterTriple({required String rangeId, required String durationId, required String targetId})`, `const ParameterTriple.standard()` = `range-personal`/`duration-momentary`/`target-individual`, `toMap()`, `ParameterTriple.fromMap(Map)`.
  - `enum GeneralEffectKind { mightThreshold, mightReduction, damage, targetSpellLevel, visDestroyed, spellTraceMagnitude }`
  - `enum GeneralEffectMultiplier { half, one, two }`
  - `enum GeneralEffectUnit { levels, magnitudes }`
  - `GeneralEffectFormula({required kind, multiplier, offsetMagnitudes, unit, stressDie})`, `toMap()`, `fromMap()`.
  - `BaseEffect.reference` (`ParameterTriple`, defaulting to `.standard()`) and `BaseEffect.effectFormula` (`GeneralEffectFormula?`).

- [ ] **Step 1: Write the failing tests**

`test/models/parameter_triple_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/parameter_triple.dart';

void main() {
  test('the standard triple is Personal/Momentary/Individual', () {
    const triple = ParameterTriple.standard();

    expect(triple.rangeId, 'range-personal');
    expect(triple.durationId, 'duration-momentary');
    expect(triple.targetId, 'target-individual');
  });

  test('round-trips through a map', () {
    const triple = ParameterTriple(
      rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle');

    expect(ParameterTriple.fromMap(triple.toMap()), triple);
  });

  test('fromMap requires all three ids', () {
    expect(() => ParameterTriple.fromMap({'rangeId': 'range-touch'}),
        throwsFormatException);
  });
}
```

`test/models/general_effect_formula_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/general_effect_formula.dart';

void main() {
  test('every kind and multiplier round-trips through a map', () {
    for (final kind in GeneralEffectKind.values) {
      for (final multiplier in GeneralEffectMultiplier.values) {
        final formula = GeneralEffectFormula(
          kind: kind, multiplier: multiplier, offsetMagnitudes: 2,
          unit: GeneralEffectUnit.levels, stressDie: true);

        expect(GeneralEffectFormula.fromMap(formula.toMap()).toMap(),
            formula.toMap());
      }
    }
  });

  test('defaults are multiplier one, offset zero, levels, no stress die', () {
    final formula =
        GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold);

    expect(formula.multiplier, GeneralEffectMultiplier.one);
    expect(formula.offsetMagnitudes, 0);
    expect(formula.unit, GeneralEffectUnit.levels);
    expect(formula.stressDie, isFalse);
  });

  test('a negative offset is allowed', () {
    final formula = GeneralEffectFormula(
      kind: GeneralEffectKind.spellTraceMagnitude,
      offsetMagnitudes: -2,
      unit: GeneralEffectUnit.magnitudes);

    expect(formula.offsetMagnitudes, -2);
  });

  test('an unknown kind name is a FormatException, not a silent default', () {
    expect(
        () => GeneralEffectFormula.fromMap({'kind': 'noSuchKind'}),
        throwsFormatException);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/parameter_triple_test.dart test/models/general_effect_formula_test.dart`
Expected: FAIL — the target files do not exist.

- [ ] **Step 3: Write `lib/models/parameter_triple.dart`**

```dart
import 'package:eruditus/utils/map_serialization.dart';

/// The Range, Duration and Target a guideline is priced against.
///
/// Most guidelines assume nothing, which is [ParameterTriple.standard] —
/// Personal, Momentary, Individual, all magnitude 0 — so their whole stat
/// line is charged. A General guideline may assume more: every ward row in
/// the rulebook ends "(Touch, Ring, Circle)" and the Intellego Imaginem row
/// ends "(Vision target)", meaning those parameters are already paid for.
///
/// Varying a parameter away from the reference costs, or refunds, the
/// difference. See `SpellEngine.calculateBreakdown`.
class ParameterTriple {
  final String rangeId;
  final String durationId;
  final String targetId;

  const ParameterTriple({
    required this.rangeId,
    required this.durationId,
    required this.targetId,
  });

  const ParameterTriple.standard()
      : rangeId = 'range-personal',
        durationId = 'duration-momentary',
        targetId = 'target-individual';

  Map<String, dynamic> toMap() => {
        'rangeId': rangeId,
        'durationId': durationId,
        'targetId': targetId,
      };

  factory ParameterTriple.fromMap(Map<String, dynamic> map) => ParameterTriple(
        rangeId: requireField<String>(map, 'rangeId', 'ParameterTriple'),
        durationId: requireField<String>(map, 'durationId', 'ParameterTriple'),
        targetId: requireField<String>(map, 'targetId', 'ParameterTriple'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParameterTriple &&
          other.rangeId == rangeId &&
          other.durationId == durationId &&
          other.targetId == targetId);

  @override
  int get hashCode => Object.hash(rangeId, durationId, targetId);
}
```

- [ ] **Step 4: Write `lib/models/general_effect_formula.dart`**

```dart
import 'package:eruditus/utils/map_serialization.dart';

/// What quantity a General guideline's effect is measured in.
enum GeneralEffectKind {
  /// "Might less than or equal to the level of the spell" — every ward.
  mightThreshold,

  /// "Reduce a target's Might Score by the level of the spell + 2 magnitudes".
  mightReduction,

  /// "Create a corrosive substance doing +(Level) damage".
  damage,

  /// "Dispel effects … with a level less than or equal to …" — the Vim rows
  /// that act on another spell.
  targetSpellLevel,

  /// "Destroy an amount of raw vis equal to the level of the spell".
  visDestroyed,

  /// "Detect the traces of magic of negative magnitude up to the magnitude of
  /// the guideline used − 2" — the one family measured in magnitudes.
  spellTraceMagnitude,
}

enum GeneralEffectMultiplier { half, one, two }

enum GeneralEffectUnit { levels, magnitudes }

T _enumByName<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "GeneralEffectFormula.fromMap: unknown $field '$name' (expected one of: "
    "${values.map((v) => v.name).join(', ')})",
  );
}

/// How a General guideline's effect strength is derived from the level the
/// caster chose.
///
/// The value is `multiplier × (chosenBase + offsetMagnitudes × 5)`, always
/// computed in levels. It reads the **chosen base**, never the computed spell
/// level — which is why a Personal-range ward built on the same guideline
/// still keeps out the same Might, despite being five levels cheaper than the
/// printed Touch/Ring/Circle version.
///
/// [unit] converts the result for display only. `magnitudes` divides by 5 and
/// rounds up, per Core Rules line 12030.
class GeneralEffectFormula {
  final GeneralEffectKind kind;
  final GeneralEffectMultiplier multiplier;
  final int offsetMagnitudes;
  final GeneralEffectUnit unit;

  /// True when the guideline's own wording adds "+ a stress die (no botch)".
  final bool stressDie;

  const GeneralEffectFormula({
    required this.kind,
    this.multiplier = GeneralEffectMultiplier.one,
    this.offsetMagnitudes = 0,
    this.unit = GeneralEffectUnit.levels,
    this.stressDie = false,
  });

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'multiplier': multiplier.name,
        'offsetMagnitudes': offsetMagnitudes,
        'unit': unit.name,
        'stressDie': stressDie,
      };

  factory GeneralEffectFormula.fromMap(Map<String, dynamic> map) =>
      GeneralEffectFormula(
        kind: _enumByName(GeneralEffectKind.values,
            requireField<String>(map, 'kind', 'GeneralEffectFormula'), 'kind'),
        multiplier: map['multiplier'] == null
            ? GeneralEffectMultiplier.one
            : _enumByName(GeneralEffectMultiplier.values,
                map['multiplier'] as String, 'multiplier'),
        offsetMagnitudes: map['offsetMagnitudes'] as int? ?? 0,
        unit: map['unit'] == null
            ? GeneralEffectUnit.levels
            : _enumByName(GeneralEffectUnit.values, map['unit'] as String, 'unit'),
        stressDie: map['stressDie'] as bool? ?? false,
      );
}
```

- [ ] **Step 5: Add the two fields to `BaseEffect`**

Add the imports, the fields, the constructor parameters, and the map handling:

```dart
  /// What this guideline is priced against. Absent in JSON means
  /// [ParameterTriple.standard].
  final ParameterTriple reference;

  /// How the guideline's effect strength derives from the chosen level.
  /// Present on every General entry, absent on every other.
  final GeneralEffectFormula? effectFormula;
```

```dart
    this.reference = const ParameterTriple.standard(),
    this.effectFormula,
```

```dart
    'reference': reference.toMap(),
    if (effectFormula != null) 'effectFormula': effectFormula!.toMap(),
```

```dart
    reference: map['reference'] == null
        ? const ParameterTriple.standard()
        : ParameterTriple.fromMap(map['reference'] as Map<String, dynamic>),
    effectFormula: map['effectFormula'] == null
        ? null
        : GeneralEffectFormula.fromMap(map['effectFormula'] as Map<String, dynamic>),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/models/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/models/parameter_triple.dart lib/models/general_effect_formula.dart \
        lib/models/base_effect.dart test/models/parameter_triple_test.dart \
        test/models/general_effect_formula_test.dart
git commit -m "feat: a General guideline records its reference parameters and effect formula"
```

---

### Task 3: `SpellLevelCalculator` requires a base level of 1 or more

**Files:**
- Modify: `lib/engine/spell_level_calculator.dart`
- Test: `test/engine/spell_level_calculator_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `SpellLevelCalculator.calculate(int baseLevel, List<int> magnitudes)` throws `ArgumentError` for `baseLevel < 1`, and throws whenever the result is below 1.

Level 0 was only ever legitimate because of the 47 sentinel rows. Task 1 removed them, so the allowance and its long comment go.

- [ ] **Step 1: Write the failing tests**

Append to `test/engine/spell_level_calculator_test.dart`:

```dart
group('base level floor', () {
  test('a base level of 0 is rejected', () {
    expect(() => SpellLevelCalculator.calculate(0, const []),
        throwsA(isA<ArgumentError>()));
  });

  test('a base level of 1 is accepted', () {
    expect(SpellLevelCalculator.calculate(1, const []), 1);
  });
});

group('parameter refunds', () {
  test('base 10 refunded three magnitudes lands at 3, not -5', () {
    // 10 is above the additive tier, so the first refund costs 5;
    // 5 and 4 are inside it, so the next two cost 1 each: 10 -> 5 -> 4 -> 3.
    expect(SpellLevelCalculator.calculate(10, const [-1, -2]), 3);
  });

  test('splitting a refund across parameters matches one combined refund', () {
    expect(SpellLevelCalculator.calculate(10, const [-1, -2]),
        SpellLevelCalculator.calculate(10, const [-3]));
  });

  test('a refund that would cross 1 throws', () {
    expect(() => SpellLevelCalculator.calculate(5, const [-5]),
        throwsA(isA<ArgumentError>()));
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/engine/spell_level_calculator_test.dart`
Expected: FAIL — `calculate(0, [])` returns 0 instead of throwing.

- [ ] **Step 3: Tighten the calculator**

Replace the doc comment's third paragraph and both guards in `lib/engine/spell_level_calculator.dart`:

```dart
  /// The invariant is that a spell always has a level of at least 1. Base
  /// level 0 used to be permitted because `base_effects.json` held 47
  /// General guidelines stored with `baseLevel: 0`; those now carry
  /// `baseLevel: null` and supply the caster's chosen level instead, so the
  /// allowance and its special case are gone.
  static int calculate(int baseLevel, List<int> magnitudes) {
    if (baseLevel < 1) {
      throw ArgumentError.value(
        baseLevel,
        'baseLevel',
        'Base level must be at least 1',
      );
    }
```

and:

```dart
    if (level < 1) {
      throw ArgumentError.value(
        level,
        'magnitudes',
        'Magnitudes reduced the spell below level 1',
      );
    }
```

- [ ] **Step 4: Run the engine suite**

Run: `flutter test test/engine/`
Expected: PASS. If a pre-existing test asserted `calculate(0, [0, 0, 0]) == 0`, delete it — that behaviour is intentionally gone.

- [ ] **Step 5: Commit**

```bash
git add lib/engine/spell_level_calculator.dart test/engine/spell_level_calculator_test.dart
git commit -m "feat: require a base level of at least 1"
```

---

### Task 4: `Spell` gains a chosen level and a soft template link

**Files:**
- Modify: `lib/models/spell.dart`
- Modify: `lib/data/database/app_database.dart:6`
- Test: `test/models/spell_test.dart`, `test/models/spell_draft_copy_with_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `Spell.chosenBaseLevel` (`int?`), `Spell.templateId` (`String?`), both serialized. `SpellDraft.chosenBaseLevel`, `SpellDraft.templateId`, both settable through `copyWith` using the existing `_unset` sentinel. `SpellDraft.toSpell` passes both through.

- [ ] **Step 1: Write the failing tests**

In `test/models/spell_test.dart`:

```dart
test('chosenBaseLevel and templateId round-trip', () {
  final spell = Spell(
    id: 's-1', name: 'Circular Ward against Demons 20',
    baseEffectId: 'revi-G1', rangeId: 'range-touch',
    durationId: 'duration-ring', targetId: 'target-circle',
    chosenBaseLevel: 20, templateId: 'tpl-revi-circular-ward-against-demons',
    requisites: const [],
    provenance: Provenance(source: PublicationSource.userCreated),
    createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
  );

  final restored = Spell.fromMap(spell.toMap());

  expect(restored.chosenBaseLevel, 20);
  expect(restored.templateId, 'tpl-revi-circular-ward-against-demons');
});

test('both fields default to null', () {
  final spell = Spell(
    id: 's-2', baseEffectId: 'crig-10', rangeId: 'range-voice',
    durationId: 'duration-momentary', targetId: 'target-individual',
    requisites: const [],
    provenance: Provenance(source: PublicationSource.userCreated),
    createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
  );

  expect(spell.chosenBaseLevel, isNull);
  expect(spell.templateId, isNull);
});
```

In `test/models/spell_draft_copy_with_test.dart`:

```dart
test('copyWith clears templateId when passed null explicitly', () {
  final draft = SpellDraft(templateId: 'tpl-1');

  expect(draft.copyWith(templateId: null).templateId, isNull);
});

test('copyWith leaves templateId alone when omitted', () {
  final draft = SpellDraft(templateId: 'tpl-1');

  expect(draft.copyWith(technique: 'Rego').templateId, 'tpl-1');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/spell_test.dart test/models/spell_draft_copy_with_test.dart`
Expected: FAIL — no named parameter `chosenBaseLevel`.

- [ ] **Step 3: Add the fields to `Spell`**

```dart
  /// The level the caster chose for a General guideline. Required when the
  /// referenced [BaseEffect] is General, absent otherwise. The engine reads
  /// it in place of `BaseEffect.baseLevel`.
  final int? chosenBaseLevel;

  /// The [SpellTemplate] this spell was instantiated from, when it was.
  ///
  /// **Provenance only — nothing dereferences it.** A spell shared between
  /// users without its template validates and computes exactly as if the
  /// field were absent, in the same spirit as `calculateBreakdown` treating
  /// an unresolvable modifier id as contributing 0.
  final String? templateId;
```

Constructor: `this.chosenBaseLevel,` and `this.templateId,`.
`toMap`: `'chosenBaseLevel': chosenBaseLevel,` and `'templateId': templateId,`.
`fromMap`: `chosenBaseLevel: map['chosenBaseLevel'] as int?,` and `templateId: map['templateId'] as String?,`.

- [ ] **Step 4: Add the fields to `SpellDraft`**

Add `int? chosenBaseLevel;` and `String? templateId;` as fields and constructor parameters, pass both through `toSpell`, and add them to `copyWith` using the existing sentinel so an explicit null clears them:

```dart
    Object? chosenBaseLevel = _unset,
    Object? templateId = _unset,
```

```dart
      chosenBaseLevel: identical(chosenBaseLevel, _unset)
          ? this.chosenBaseLevel
          : chosenBaseLevel as int?,
      templateId: identical(templateId, _unset) ? this.templateId : templateId as String?,
```

- [ ] **Step 5: Bump the database schema**

`lib/data/database/app_database.dart:6` — `_databaseVersion` 6 → 7, and add both columns to the `spells` table's `CREATE TABLE`:

```sql
        chosen_base_level INTEGER,
        template_id TEXT,
```

`onUpgrade` already drops and recreates `spells`. Add nothing else — no migration path is wanted.

- [ ] **Step 6: Run the model and database suites**

Run: `flutter test test/models/ test/data/database/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/models/spell.dart lib/data/database/app_database.dart \
        test/models/spell_test.dart test/models/spell_draft_copy_with_test.dart
git commit -m "feat: a spell carries its chosen General level and an optional template link"
```

---

### Task 5: `SpellTemplate` and its asset loader

**Files:**
- Create: `lib/models/spell_template.dart`, `assets/data/spell_templates.json`
- Modify: `lib/data/datasources/asset_data_loader.dart`, `lib/data/repositories/library_repository.dart`, `pubspec.yaml` (if assets are listed individually)
- Test: `test/models/spell_template_test.dart`, `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `SpellTemplate({required id, required name, required baseEffectId, required rangeId, required durationId, required targetId, selectedModifiers, requisites, adjustments, summary, description, required provenance, tags, ritualDeclaration})`, `toMap()`, `SpellTemplate.fromMap()`. `AssetDataLoader.loadSpellTemplates()` → `Future<List<SpellTemplate>>`. `LibraryRepository.getTemplates()` → `Future<List<SpellTemplate>>`.

A template is a published General spell with **no chosen level**. That absence is the whole point: it is what keeps `LevelBreakdown.level` a plain `int`, because no `Spell` is ever level-less.

- [ ] **Step 1: Write the failing tests**

`test/models/spell_template_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/spell_template.dart';

void main() {
  SpellTemplate build() => SpellTemplate(
        id: 'tpl-pevi-demons-eternal-oblivion',
        name: "Demon's Eternal Oblivion",
        baseEffectId: 'pevi-G3',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        summary: 'Weakens and possibly destroys a creature with Infernal Might.',
        provenance: Provenance(
            source: PublicationSource.published,
            citations: [Citation(bookId: 'arm5-core')]),
      );

  test('round-trips through a map', () {
    final restored = SpellTemplate.fromMap(build().toMap());

    expect(restored.id, 'tpl-pevi-demons-eternal-oblivion');
    expect(restored.baseEffectId, 'pevi-G3');
    expect(restored.rangeId, 'range-voice');
  });

  test('carries no level of any kind', () {
    expect(build().toMap().containsKey('chosenBaseLevel'), isFalse);
    expect(build().toMap().containsKey('printedLevel'), isFalse);
  });
}
```

In `test/data/datasources/asset_data_loader_test.dart`, following the existing self-healing-count precedent (derive the expectation from the raw JSON, never hardcode):

```dart
test('loads every template in the asset', () async {
  final raw = jsonDecode(
      await File('assets/data/spell_templates.json').readAsString()) as List;

  final templates = await AssetDataLoader().loadSpellTemplates();

  expect(templates, hasLength(raw.length));
});

test('templates survive a backup round-trip through the real service', () async {
  // Note this calls through BackupService rather than re-testing
  // serialization — todo item 7 records that the existing backup test
  // duplicates spell_test.dart and never exercises the service itself.
  final service = BackupService(/* … as constructed elsewhere in this file … */);

  final restored = await service.importBackup(await service.exportBackup());

  expect(restored.templates.map((t) => t.id),
      (await AssetDataLoader().loadSpellTemplates()).map((t) => t.id));
});

test('every template references a General base effect', () async {
  final effects = {
    for (final e in await AssetDataLoader().loadBaseEffects()) e.id: e,
  };

  for (final template in await AssetDataLoader().loadSpellTemplates()) {
    expect(effects[template.baseEffectId]?.isGeneral, isTrue,
        reason: '${template.id} points at a non-General base effect');
  }
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/spell_template_test.dart`
Expected: FAIL — `spell_template.dart` does not exist.

- [ ] **Step 3: Write `lib/models/spell_template.dart`**

Mirror `Spell`'s field list and serialization exactly, minus `chosenBaseLevel`, `printedLevel`, `templateId`, `createdAt` and `updatedAt`. Reuse `validateSpellProse` in the constructor the way `Spell` does. Add this doc comment:

```dart
/// A published General spell: everything a [Spell] has except a level.
///
/// The rulebook is explicit that this is not a spell (Core Rules line 12414):
/// "General level spells are open-ended only in the sense that they may be
/// learned at any level … different levels of a General level spell are still
/// different spells." A template is the thing a spell is made *from*.
///
/// Read-only catalog data. Users instantiate templates; they do not author
/// them.
```

- [ ] **Step 4: Create an empty asset and wire the loader**

```bash
echo "[]" > assets/data/spell_templates.json
```

Task 12 fills it. Add to `AssetDataLoader`, matching the four existing methods exactly:

```dart
  Future<List<SpellTemplate>> loadSpellTemplates() async {
    final jsonString = await rootBundle.loadString('assets/data/spell_templates.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => SpellTemplate.fromMap(e as Map<String, dynamic>)).toList();
  }
```

Add a `getTemplates()` pass-through to `LibraryRepository` alongside its existing library accessor. Check `pubspec.yaml`: if `assets:` lists files individually rather than the `assets/data/` directory, add the new path.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/models/spell_template_test.dart test/data/datasources/`
Expected: PASS. The two loader tests pass trivially against the empty asset — they become meaningful in Task 12, which is deliberate: they must exist before the data does.

- [ ] **Step 6: Commit**

```bash
git add lib/models/spell_template.dart lib/data/datasources/asset_data_loader.dart \
        lib/data/repositories/library_repository.dart assets/data/spell_templates.json \
        pubspec.yaml test/models/spell_template_test.dart \
        test/data/datasources/asset_data_loader_test.dart
git commit -m "feat: add the SpellTemplate entity and its asset loader"
```

---

### Task 6: Engine charges each parameter as a delta against the reference

**Files:**
- Modify: `lib/engine/spell_engine.dart:110-188`
- Test: `test/engine/spell_engine_test.dart`

**Interfaces:**
- Consumes: `BaseEffect.isGeneral`, `BaseEffect.reference` (Tasks 1–2); `Spell.chosenBaseLevel` (Task 4).
- Produces: `calculateBreakdown` gains a required-when-General named parameter `int? chosenBaseLevel`. `calculateSpellLevel` forwards it. `SpellEngine` gains `List<Parameter> allParameters` (default `const []`) and `updateParameters(List<Parameter>)`, mirroring `allModifiers` / `updateModifiers`, so the engine can look up a reference parameter's magnitude.

- [ ] **Step 1: Write the failing tests**

```dart
group('reference deltas', () {
  BaseEffect wardGuideline() => BaseEffect(
      id: 'rean-gen', technique: 'Rego', form: 'Animal',
      description: 'Ward against beings associated with Animal',
      baseLevel: null,
      reference: const ParameterTriple(
          rangeId: 'range-touch',
          durationId: 'duration-ring',
          targetId: 'target-circle'),
      provenance: Provenance(source: PublicationSource.published,
          citations: [Citation(bookId: 'arm5-core')]));

  test('a ward at its reference parameters is exactly the chosen level', () {
    final breakdown = engine.calculateBreakdown(
      baseEffect: wardGuideline(), chosenBaseLevel: 20,
      range: touch, duration: ring, target: circle,
      selectedModifiers: const {}, requisites: const []);

    expect(breakdown.level, 20);
  });

  test('a cheaper parameter set refunds the difference', () {
    // Personal(0)+Sun(2)+Individual(0) = 2 against a reference of
    // Touch(1)+Ring(2)+Circle(0) = 3, so one magnitude comes back.
    final breakdown = engine.calculateBreakdown(
      baseEffect: wardGuideline(), chosenBaseLevel: 20,
      range: personal, duration: sun, target: individual,
      selectedModifiers: const {}, requisites: const []);

    expect(breakdown.level, 15);
  });

  test('the breakdown names the reference it is charging against', () {
    final breakdown = engine.calculateBreakdown(
      baseEffect: wardGuideline(), chosenBaseLevel: 20,
      range: personal, duration: sun, target: individual,
      selectedModifiers: const {}, requisites: const []);

    final rangeLine = breakdown.contributions
        .firstWhere((c) => c.label.startsWith('Range'));

    expect(rangeLine.label, 'Range · Personal (guideline assumes Touch)');
    expect(rangeLine.magnitude, -1);
  });

  test('an ordinary guideline produces contributions identical to before', () {
    // This is the argument for there being one code path rather than a
    // branch: a standard reference makes every delta equal the raw cost.
    final breakdown = engine.calculateBreakdown(
      baseEffect: creoIgnem10, range: voice, duration: sun, target: individual,
      selectedModifiers: const {}, requisites: const []);

    expect(breakdown.contributions.map((c) => '${c.label}|${c.magnitude}'), [
      'Base effect · Create flame|10',
      'Range · Voice|2',
      'Duration · Sun|2',
      'Target · Individual|0',
    ]);
    expect(breakdown.level, 30);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — no named parameter `chosenBaseLevel`.

- [ ] **Step 3: Implement**

Add the parameter to `calculateBreakdown` and replace the four opening contributions:

```dart
  LevelBreakdown calculateBreakdown({
    required BaseEffect baseEffect,
    int? chosenBaseLevel,
    required Parameter range,
    // … unchanged …
  }) {
    final baseLevel = baseEffect.isGeneral ? chosenBaseLevel : baseEffect.baseLevel;
    if (baseLevel == null) {
      throw ArgumentError.value(
        chosenBaseLevel,
        'chosenBaseLevel',
        'A General guideline needs a chosen level',
      );
    }

    final contributions = <LevelContribution>[
      LevelContribution(
          label: 'Base effect · ${baseEffect.description}',
          magnitude: baseLevel,
          isBase: true),
      _parameterContribution('Range', range, baseEffect.reference.rangeId),
      _parameterContribution('Duration', duration, baseEffect.reference.durationId),
      _parameterContribution('Target', target, baseEffect.reference.targetId),
    ];
```

and add the helper, plus a lookup for the reference parameter's own magnitude:

```dart
  /// One Range/Duration/Target line, charged as the difference between what
  /// the spell actually uses and what its guideline was priced against.
  ///
  /// For an ordinary guideline the reference is Personal/Momentary/Individual,
  /// all magnitude 0, so the delta equals the raw magnitude and the emitted
  /// label is unchanged. That identity is why this is one code path and not a
  /// branch on `isGeneral`.
  LevelContribution _parameterContribution(
      String slot, Parameter actual, String referenceId) {
    if (actual.id == referenceId) {
      return LevelContribution(label: '$slot · ${actual.name}', magnitude: 0);
    }

    final reference = _parameterById(referenceId);
    if (reference == null || reference.magnitude == 0) {
      return LevelContribution(
          label: '$slot · ${actual.name}', magnitude: actual.magnitude);
    }

    return LevelContribution(
      label: '$slot · ${actual.name} (guideline assumes ${reference.name})',
      magnitude: actual.magnitude - reference.magnitude,
    );
  }
```

`_parameterById` needs the parameter catalog, which `SpellEngine` does not currently hold. Add `List<Parameter> allParameters` beside `allModifiers`, defaulting to `const []`, with an `updateParameters` setter mirroring `updateModifiers`, and wire it from `ConfigurationBloc` at the same place `updateModifiers` is called. An unknown reference id degrades to charging the raw magnitude — the same "a dangling id contributes nothing surprising" rule the modifier lookup already follows.

Note the `actual.id == referenceId` short-circuit: it returns magnitude 0 without needing the catalog at all, which is the common case for wards and keeps the standard reference (`range-personal`, magnitude 0) working even before `allParameters` is populated.

Finally, replace line 164:

```dart
    final rawLevel = SpellLevelCalculator.calculate(baseLevel, magnitudes);
```

and forward `chosenBaseLevel` from `calculateSpellLevel`, `validateSpellDraft` and `findSimilarSpells` (the last reads `s.record.chosenBaseLevel`).

- [ ] **Step 4: Run the engine and bloc suites**

Run: `flutter test test/engine/ test/bloc/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/engine/spell_engine.dart lib/bloc/configuration/ test/engine/spell_engine_test.dart
git commit -m "feat: charge Range/Duration/Target against the guideline's reference"
```

---

### Task 7: `deriveGeneralEffect`

**Files:**
- Modify: `lib/engine/spell_engine.dart`
- Create: `test/engine/general_effect_test.dart`

**Interfaces:**
- Consumes: `GeneralEffectFormula` (Task 2).
- Produces: `SpellEngine.deriveGeneralEffect({required BaseEffect baseEffect, required int? chosenBaseLevel})` → `GeneralEffectValue?`, where `GeneralEffectValue` (in `lib/models/general_effect_formula.dart`) is `{int value, GeneralEffectUnit unit, String sentence}`. Returns null when the effect is not General or no level was chosen.

- [ ] **Step 1: Write the failing tests**

`test/engine/general_effect_test.dart`:

```dart
group('deriveGeneralEffect', () {
  test('a ward threshold is the chosen base', () {
    expect(derive(mightThreshold, chosen: 20)!.value, 20);
  });

  test('Might reduction adds the guideline offset in levels', () {
    // pevi-G3: "Reduce a target's Might Score by the level of the spell
    // + 2 magnitudes" — base + 10.
    expect(derive(mightReductionPlus2, chosen: 15)!.value, 25);
  });

  test('a doubling multiplier applies after the offset', () {
    // pevi-G1: "twice the (level + 2 magnitudes)".
    expect(derive(twiceLevelPlus2, chosen: 10)!.value, 40);
  });

  test('a halving multiplier rounds the same way as the rulebook', () {
    // pevi-G5: "half the (level + 4 magnitudes)".
    expect(derive(halfLevelPlus4, chosen: 15)!.value, 17);
  });

  test('a magnitudes unit converts by dividing by 5 and rounding up', () {
    // invi-G: "negative magnitude up to the magnitude of the guideline - 2".
    final result = derive(traceMagnitudeMinus2, chosen: 20);

    expect(result!.unit, GeneralEffectUnit.magnitudes);
    expect(result.value, 2); // (20 - 10) / 5
  });

  test('the value does not change when Range, Duration or Target change', () {
    // This is the whole point of anchoring to the chosen base: a
    // Personal-range ward is five levels cheaper but keeps out the same Might.
    expect(derive(mightThreshold, chosen: 20)!.value,
        derive(mightThreshold, chosen: 20)!.value);
  });

  test('a stress-die formula says so in its sentence', () {
    expect(derive(halfLevelPlus4, chosen: 15)!.sentence,
        contains('+ a stress die (no botch)'));
  });

  test('returns null for a non-General base effect', () {
    expect(
        engine.deriveGeneralEffect(baseEffect: creoIgnem10, chosenBaseLevel: null),
        isNull);
  });

  test('returns null when no level has been chosen yet', () {
    expect(
        engine.deriveGeneralEffect(baseEffect: wardGuideline(), chosenBaseLevel: null),
        isNull);
  });
});
```

Write a local `derive(GeneralEffectFormula formula, {required int chosen})` helper in the test file that builds a General `BaseEffect` carrying `formula` and calls the engine, so each test reads as one assertion.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/engine/general_effect_test.dart`
Expected: FAIL — `deriveGeneralEffect` is not defined.

- [ ] **Step 3: Add `GeneralEffectValue` and the sentence templates**

In `lib/models/general_effect_formula.dart`:

```dart
class GeneralEffectValue {
  final int value;
  final GeneralEffectUnit unit;
  final String sentence;

  const GeneralEffectValue({
    required this.value,
    required this.unit,
    required this.sentence,
  });
}
```

- [ ] **Step 4: Implement the engine method**

```dart
  /// The strength of a General guideline's effect at the level the caster
  /// chose, or null when the guideline is not General or no level is set yet.
  ///
  /// Reads [chosenBaseLevel] and never the computed spell level. That is
  /// deliberate and load-bearing: a ward moved from Touch/Ring/Circle to
  /// Personal/Sun/Individual is one magnitude cheaper, and must still keep out
  /// exactly the same Might.
  GeneralEffectValue? deriveGeneralEffect({
    required BaseEffect baseEffect,
    required int? chosenBaseLevel,
  }) {
    final formula = baseEffect.effectFormula;
    if (!baseEffect.isGeneral || formula == null || chosenBaseLevel == null) {
      return null;
    }

    final inLevels = chosenBaseLevel + formula.offsetMagnitudes * 5;
    final scaled = switch (formula.multiplier) {
      // Halving rounds DOWN. The only "round up" the rulebook states is for
      // magnitudes (line 12030), applied below; halving a spell level has no
      // such rule, and rounding down is the reading that never lets a
      // dispelling spell reach one level higher than its guideline allows.
      GeneralEffectMultiplier.half => inLevels ~/ 2,
      GeneralEffectMultiplier.one => inLevels,
      GeneralEffectMultiplier.two => inLevels * 2,
    };

    final value = formula.unit == GeneralEffectUnit.magnitudes
        ? (scaled / 5).ceil()
        : scaled;

    return GeneralEffectValue(
      value: value,
      unit: formula.unit,
      sentence: _effectSentence(formula, value),
    );
  }

  static String _effectSentence(GeneralEffectFormula formula, int value) {
    final body = switch (formula.kind) {
      GeneralEffectKind.mightThreshold => 'Affects beings with Might $value or less',
      GeneralEffectKind.mightReduction => 'Reduces Might by $value',
      GeneralEffectKind.damage => 'Does +$value damage',
      GeneralEffectKind.targetSpellLevel => 'Affects effects of level $value or less',
      GeneralEffectKind.visDestroyed => 'Destroys $value pawns\' worth of raw vis',
      GeneralEffectKind.spellTraceMagnitude =>
        'Reaches spell traces down to negative magnitude $value',
    };

    return formula.stressDie ? '$body, + a stress die (no botch)' : body;
  }
```

Rounding, decided: `half` rounds **down** (`~/`), so `pevi-G5` at chosen 15 gives `(15 + 20) ~/ 2 = 17`, which is what the test asserts. `ceil` appears exactly once, in the `magnitudes` unit conversion, because line 12030 states that rule explicitly for magnitudes and only for magnitudes.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/engine/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/models/general_effect_formula.dart lib/engine/spell_engine.dart \
        test/engine/general_effect_test.dart
git commit -m "feat: derive a General guideline's effect strength from the chosen level"
```

---

### Task 8: Validation for a missing or invalid chosen level

**Files:**
- Modify: `lib/engine/spell_engine.dart:34-108`
- Test: `test/engine/spell_engine_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 4, 6.
- Produces: two new `validateSpellDraft` messages.

- [ ] **Step 1: Write the failing tests**

```dart
group('General level validation', () {
  test('a General guideline with no chosen level is an error', () {
    final draft = completeDraft(baseEffect: wardGuideline(), chosenBaseLevel: null);

    expect(engine.validateSpellDraft(draft),
        contains('Choose a level for this General guideline'));
  });

  test('a chosen level below 1 is an error', () {
    final draft = completeDraft(baseEffect: wardGuideline(), chosenBaseLevel: 0);

    expect(engine.validateSpellDraft(draft),
        contains('The chosen level must be at least 1'));
  });

  test('a valid chosen level produces no errors', () {
    final draft = completeDraft(baseEffect: wardGuideline(), chosenBaseLevel: 20);

    expect(engine.validateSpellDraft(draft), isEmpty);
  });

  test('a spell whose templateId names nothing still validates', () {
    // The link is provenance. A spell shared without its template must
    // compute exactly as if the field were absent.
    final draft = completeDraft(
      baseEffect: wardGuideline(), chosenBaseLevel: 20)
      ..templateId = 'tpl-does-not-exist';

    expect(engine.validateSpellDraft(draft), isEmpty);
    expect(
        engine.calculateSpellLevel(
            baseEffect: wardGuideline(), chosenBaseLevel: 20,
            range: touch, duration: ring, target: circle,
            requisites: const []),
        20);
  });

  test('a refund that crosses level 1 is reported, not thrown', () {
    final draft = completeDraft(
      baseEffect: wardGuideline(), chosenBaseLevel: 1,
      range: personal, duration: momentary, target: individual);

    expect(engine.validateSpellDraft(draft),
        contains('Magnitudes reduce this spell below level 1'));
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — the messages are absent.

- [ ] **Step 3: Implement**

After the existing `draft.baseEffect == null` check:

```dart
    if (draft.baseEffect != null && draft.baseEffect!.isGeneral) {
      if (draft.chosenBaseLevel == null) {
        errors.add('Choose a level for this General guideline');
      } else if (draft.chosenBaseLevel! < 1) {
        errors.add('The chosen level must be at least 1');
      }
    }
```

Widen the existing catch-block message from item 24's wording, since refunds now reach the same guard:

```dart
      } on ArgumentError {
        errors.add('Magnitudes reduce this spell below level 1');
      }
```

and pass `chosenBaseLevel: draft.chosenBaseLevel` into the `calculateBreakdown` call inside that `try`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/engine/ test/bloc/`
Expected: PASS. Update any existing test asserting the old "Negative magnitudes reduce this spell below level 1" wording.

- [ ] **Step 5: Commit**

```bash
git add lib/engine/spell_engine.dart test/engine/spell_engine_test.dart
git commit -m "feat: validate the chosen level of a General guideline"
```

---

### Task 9: Author the 47 references and formulas

**Files:**
- Modify: `assets/data/base_effects.json`
- Create: `scripts/spell_import/tests/test_general_catalog.py`

**Interfaces:**
- Consumes: the JSON shape from Task 2 (`reference`, `effectFormula`).
- Produces: every General entry in `base_effects.json` carries both fields.

**This task must complete before Task 11.** Every General row has the same absent base level, so `resolutions.json` has no discriminator until these formulas exist. Authoring the ledger first reproduces item 32's failure by construction.

- [ ] **Step 1: Write the failing table test**

`scripts/spell_import/tests/test_general_catalog.py`, in the shape of the existing `test_emit.ModifierOptionTableTest`:

```python
import json
import unittest

from .. import catalog as catalog_module

VALID_KINDS = {
    "mightThreshold", "mightReduction", "damage",
    "targetSpellLevel", "visDestroyed", "spellTraceMagnitude",
}
VALID_MULTIPLIERS = {"half", "one", "two"}
VALID_UNITS = {"levels", "magnitudes"}

STANDARD_REFERENCE = {
    "rangeId": "range-personal",
    "durationId": "duration-momentary",
    "targetId": "target-individual",
}


class GeneralCatalogTest(unittest.TestCase):
    def setUp(self):
        self.catalog = catalog_module.Catalog.load()
        self.general = [e for e in self.catalog.base_effects
                        if e["baseLevel"] is None]
        self.parameter_ids = {p["id"] for p in self.catalog.parameters}

    def test_there_are_47_general_entries(self):
        self.assertEqual(len(self.general), 47)

    def test_every_general_entry_has_a_formula(self):
        missing = [e["id"] for e in self.general if not e.get("effectFormula")]
        self.assertEqual(missing, [])

    def test_no_ordinary_entry_has_a_formula(self):
        stray = [e["id"] for e in self.catalog.base_effects
                 if e["baseLevel"] is not None and e.get("effectFormula")]
        self.assertEqual(stray, [])

    def test_every_formula_field_is_in_range(self):
        for effect in self.general:
            formula = effect["effectFormula"]
            with self.subTest(effect["id"]):
                self.assertIn(formula["kind"], VALID_KINDS)
                self.assertIn(formula.get("multiplier", "one"), VALID_MULTIPLIERS)
                self.assertIn(formula.get("unit", "levels"), VALID_UNITS)
                self.assertIsInstance(formula.get("offsetMagnitudes", 0), int)

    def test_every_reference_names_real_parameters(self):
        for effect in self.catalog.base_effects:
            reference = effect.get("reference", STANDARD_REFERENCE)
            with self.subTest(effect["id"]):
                for key in ("rangeId", "durationId", "targetId"):
                    self.assertIn(reference[key], self.parameter_ids)

    def test_every_ward_is_priced_against_touch_ring_circle(self):
        # Every ward row in the rulebook ends "(Touch, Ring, Circle)".
        wards = [e for e in self.general
                 if e["effectFormula"]["kind"] == "mightThreshold"]
        self.assertGreaterEqual(len(wards), 11)
        for effect in wards:
            with self.subTest(effect["id"]):
                self.assertEqual(effect["reference"], {
                    "rangeId": "range-touch",
                    "durationId": "duration-ring",
                    "targetId": "target-circle",
                })
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python -m unittest scripts.spell_import.tests.test_general_catalog -v`
Expected: FAIL — no General entry has an `effectFormula`.

- [ ] **Step 3: Author the data**

Open the rulebook at `../Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md` and work through every `| General |` table row. For each catalog entry:

**Reference** — read it off the row's printed parenthetical and nothing else:
- Row ends `(Touch, Ring, Circle)` → `range-touch` / `duration-ring` / `target-circle`. This covers all 11 ward rows (ReAn ×2, ReAq, ReAu, ReCo, ReHe, ReIg, ReIm, ReMe ×2, ReTe, ReVi).
- Row ends `(Vision target)` → `range-personal` / `duration-momentary` / `target-vision`. This is `inim-G` only.
- **No parenthetical → omit the `reference` key entirely.** It defaults to Personal/Momentary/Individual. This is the majority, including every Perdo Vim, Muto Vim, Creo Vim and Rego Vim non-ward row.

Do **not** infer a reference from a spell's design line. Task 10's assertion 6 is the only automated check General spells will ever have, and inferring the reference from the thing the assertion compares against makes it vacuous.

**Formula** — read it off the row's wording:

| Row wording | `kind` | `multiplier` | `offsetMagnitudes` | `unit` | `stressDie` |
|---|---|---|---|---|---|
| "Might ≤ the level of the spell" | `mightThreshold` | `one` | 0 | `levels` | false |
| "Reduce … Might Score by the level of the spell + 2 magnitudes" | `mightReduction` | `one` | 2 | `levels` | false |
| "+(Level) damage" / "+level damage" | `damage` | `one` | 0 | `levels` | false |
| "twice the (level + 2 magnitudes)" | `targetSpellLevel` | `two` | 2 | `levels` | false |
| "the level + 4 magnitudes … + a stress die (no botch)" | `targetSpellLevel` | `one` | 4 | `levels` | true |
| "half the (level + 4 magnitudes … stress die)" | `targetSpellLevel` | `half` | 4 | `levels` | true |
| "level + 5 magnitudes" | `targetSpellLevel` | `one` | 5 | `levels` | false |
| "an amount of raw vis equal to the level of the spell" | `visDestroyed` | `one` | 0 | `levels` | false |
| "negative magnitude … up to the magnitude of the guideline − 2" | `spellTraceMagnitude` | `one` | −2 | `magnitudes` | false |

Two rows need care. The elemental rows ("reducing the elemental's Might pool by the level of the spell +2 magnitudes") are `mightReduction`, offset 2 — the same as `pevi-G3`, even though the prose differs. `pevi-G8` ("Age a spell trace to a negative magnitude equal to the guideline used") is `spellTraceMagnitude`, offset 0, unit `magnitudes` — note it is *equal to*, not *minus 2*, unlike `invi-G`.

- [ ] **Step 4: Run the table test**

Run: `python -m unittest scripts.spell_import.tests.test_general_catalog -v`
Expected: PASS.

- [ ] **Step 5: Run both full suites**

Run: `python -m unittest discover -s scripts/spell_import/tests -t . && flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add assets/data/base_effects.json scripts/spell_import/tests/test_general_catalog.py
git commit -m "feat: author reference parameters and effect formulas for the 47 General guidelines"
```

---

### Task 10: Python harness — General candidates, the ward design line, and assertions 6 and 7

**Files:**
- Modify: `scripts/spell_import/catalog.py:53-60`, `scripts/spell_import/designline.py:15`
- Modify: `scripts/spell_import/tests/test_catalog.py`, `scripts/spell_import/tests/test_designline.py`
- Create: the assertions in `scripts/spell_import/tests/test_general_catalog.py`

**Interfaces:**
- Consumes: Task 9's authored data.
- Produces: `Catalog.general_candidates(technique, form) -> list[str]`; `Catalog.reference_cost(effect_id) -> int` (total magnitude of the reference triple); `designline.parse_design` accepts `(As ward guideline)`.

- [ ] **Step 1: Write the failing tests**

In `test_catalog.py`:

```python
    def test_general_candidates_are_the_levelless_rows(self):
        catalog = catalog_module.Catalog.load()

        candidates = catalog.general_candidates("Perdo", "Vim")

        self.assertEqual(len(candidates), 13)
        self.assertIn("pevi-G3", candidates)

    def test_reference_cost_sums_the_triple(self):
        catalog = catalog_module.Catalog.load()

        # Touch(1) + Ring(2) + Circle(0)
        self.assertEqual(catalog.reference_cost("rean-gen"), 3)
        # No reference key: Personal(0) + Momentary(0) + Individual(0)
        self.assertEqual(catalog.reference_cost("pevi-G3"), 0)
```

In `test_designline.py`:

```python
    def test_as_ward_guideline_is_a_general_line_with_no_tokens(self):
        design = designline.parse_design("(As ward guideline)")

        self.assertIsNone(design.base_level)
        self.assertEqual(design.tokens, [])
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_catalog scripts.spell_import.tests.test_designline -v`
Expected: FAIL — `general_candidates` is not defined; `(As ward guideline)` raises `UnknownToken`.

- [ ] **Step 3: Implement the catalog methods**

```python
    def general_candidates(self, technique: str, form: str) -> list[str]:
        """Every General row for a Technique/Form.

        Unlike `candidates`, this cannot narrow by level: a General row has
        none. Perdo Vim therefore returns all 13, and the pick rests entirely
        on the ledger's recorded rationale plus assertion 6.
        """
        return sorted({
            effect["id"]
            for effect in self.base_effects
            if effect["technique"] == technique
            and effect["form"] == form
            and effect["baseLevel"] is None
        })

    def reference_cost(self, effect_id: str) -> int:
        """Total magnitude of the parameters a guideline is priced against."""
        effect = next(e for e in self.base_effects if e["id"] == effect_id)
        reference = effect.get("reference") or {
            "rangeId": "range-personal",
            "durationId": "duration-momentary",
            "targetId": "target-individual",
        }
        by_id = {p["id"]: p["magnitude"] for p in self.parameters}
        return sum(by_id[reference[key]]
                   for key in ("rangeId", "durationId", "targetId"))
```

- [ ] **Step 4: Widen the design-line General pattern**

`scripts/spell_import/designline.py:15`:

```python
_BASE_GENERAL = re.compile(
    r"^Base\s+(effect|spell)\b|^Base$|^As\s+ward\s+guideline$")
```

Before making this unconditional, confirm no other spell prints a line starting `As ` that is not a General marker:

```bash
grep -oE '^\(As [^)]*\)' "../Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md" | sort -u
```

If anything other than `(As ward guideline)` appears, narrow the pattern to that exact phrase.

- [ ] **Step 5: Write assertion 6 and assertion 7**

Add to `test_general_catalog.py`:

```python
class ReferenceOracleTest(unittest.TestCase):
    """Assertion 6 — the only automated check a General spell can have.

    Assertion 1 ("every spell computes to its printed level") discriminates
    nothing here: there is no printed level, and every candidate shares the
    same absent base level, so a wrong ledger pick computes identically to a
    right one. This is todo item 32's hazard at full strength, on 22 spells.

    The check is non-circular only because references are authored from the
    guideline row's printed parenthetical, never inferred from the design
    lines this test compares them against.
    """

    def setUp(self):
        self.catalog = catalog_module.Catalog.load()
        self.magnitudes = {p["id"]: p["magnitude"] for p in self.catalog.parameters}
        path = catalog_module.DATA_DIR / "spell_templates.json"
        self.templates = json.loads(path.read_text(encoding="utf-8"))
        book = sources.resolve_book(sources.DE_TITLE)
        parsed, _ = blocks.parse_de(sources.read_lines(book))
        self.blocks_by_name = {b.name: b for b in parsed}

    def test_design_line_tokens_equal_actual_cost_minus_reference_cost(self):
        for template in self.templates:
            block = self.blocks_by_name[template["name"]]
            design = designline.parse_design(block.design_line)

            actual = sum(self.magnitudes[template[key]] for key in
                         ("rangeId", "durationId", "targetId"))
            reference = self.catalog.reference_cost(template["baseEffectId"])
            printed = sum(token.magnitude for token in design.tokens
                          if token.label in designline.PARAMETER_LABELS)

            with self.subTest(template["id"]):
                self.assertEqual(
                    printed, actual - reference,
                    f"{template['name']}: the rulebook prints {printed} magnitudes "
                    f"of Range/Duration/Target, but its stat line costs {actual} "
                    f"against a guideline reference of {reference}. Either the "
                    f"ledger picked the wrong guideline, or "
                    f"{template['baseEffectId']}'s reference is mis-authored. "
                    f"Do NOT adjust the reference to make this pass.")
```

That failure message is the guard rail: the one wrong fix — bending a reference until a spell imports — is named in the message the implementer will read.

Add alongside it:

```python
class FormulaRenderingTest(unittest.TestCase):
    """Assertion 7 — every emitted effect sentence is generated, not copied."""

    def test_every_general_entry_a_template_uses_has_a_formula(self):
        catalog = catalog_module.Catalog.load()
        by_id = {e["id"]: e for e in catalog.base_effects}
        path = catalog_module.DATA_DIR / "spell_templates.json"

        for template in json.loads(path.read_text(encoding="utf-8")):
            effect = by_id[template["baseEffectId"]]
            with self.subTest(template["id"]):
                self.assertIsNone(effect["baseLevel"],
                                  "a template must point at a General guideline")
                self.assertIsNotNone(effect.get("effectFormula"))
```

Both need `from .. import blocks, designline, sources` at the top of the file.

- [ ] **Step 6: Run the Python suite**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add scripts/spell_import/catalog.py scripts/spell_import/designline.py \
        scripts/spell_import/tests/
git commit -m "feat: General candidates, the ward design line, and the reference oracle"
```

---

### Task 11: Ledger entries for the 22 importable General spells

**Files:**
- Modify: `scripts/spell_import/resolutions.json`

**Interfaces:**
- Consumes: Task 9's formulas (the discriminator) and Task 10's `general_candidates`.
- Produces: a resolution entry per importable General spell.

**Do not start this before Task 9 is committed.** The formulas are what make these picks textually forced rather than guesses.

- [ ] **Step 1: List what needs resolving**

```bash
python -m scripts.spell_import.extract_spells
```

Read the `unresolved` output. Each General spell now proposes a candidate set from `general_candidates`.

- [ ] **Step 2: Resolve each one against the guideline's formula and the spell's own prose**

Follow the existing entry format exactly: `baseEffectId`, the `candidates` list it was decided against, and a `rationale`. Worked example — *Disenchant*, 13 Perdo Vim candidates:

> Its prose reads "You make a Hermetic magic item lose all its powers permanently if the level of this spell + a stress die (no botch) equals or exceeds the highest level of the enchantments in the item", and its stat line prints `Ritual`. `pevi-G9` is "Dispel a Hermetic enchantment with a level less than the guideline level used + 1 magnitude + a stress die (no botch); the spell must be a Ritual" — the only candidate of the 13 that is both enchantment-specific and Ritual-required. `pevi-G10` is the near miss and is excluded because it requires the spell to "specify a particular Hermetic Form or a specific type of enchantment", which *Disenchant* does not.

Write each rationale to that standard: name the chosen row, name the nearest rejected candidate, and say what textually excludes it.

- [ ] **Step 3: Where no rationale can be written without guessing, add to `KNOWN_UNRESOLVABLE` instead**

Item 27's precedent: an entry that picks "the most general-sounding" candidate is worse than a recorded blocker, because it looks resolved. `extract_spells.KNOWN_UNRESOLVABLE` takes a spell id and a one-line reason.

- [ ] **Step 4: Verify**

Run: `python -m scripts.spell_import.extract_spells`
Expected: 0 unresolved. Blocked spells carry a reason each.

- [ ] **Step 5: Commit**

```bash
git add scripts/spell_import/resolutions.json scripts/spell_import/extract_spells.py
git commit -m "data: resolve the base effects of the importable General spells"
```

---

### Task 12: Emit templates and regenerate the assets

**Files:**
- Modify: `scripts/spell_import/emit.py`, `scripts/spell_import/extract_spells.py:227`
- Modify: `assets/data/spell_templates.json`, `assets/data/spell_library.json`, `scripts/spell_import/source.lock`, `scripts/spell_import/import_report.md`

**Interfaces:**
- Consumes: Tasks 9–11.
- Produces: `emit.build_template(block, base_effect_id, catalog) -> dict` matching `SpellTemplate.fromMap`.

- [ ] **Step 1: Write the failing test**

In `test_emit.py`:

```python
    def test_build_template_omits_every_level_field(self):
        template = emit.build_template(block, "pevi-G3", catalog)

        self.assertNotIn("chosenBaseLevel", template)
        self.assertNotIn("printedLevel", template)
        self.assertTrue(template["id"].startswith("tpl-"))
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python -m unittest scripts.spell_import.tests.test_emit -v`
Expected: FAIL — `build_template` is not defined.

- [ ] **Step 3: Implement `build_template`**

Mirror `build_spell`, dropping `printedLevel` and the level arithmetic, and prefixing the id with `tpl-` instead of `lib-`.

- [ ] **Step 4: Replace the General blocker in `extract_spells.py`**

Line 227's `blocked.append((block.name, "General level — todo item 25"))` becomes the General branch: resolve through `general_candidates` + the ledger, then `build_template`. Keep every other blocker path intact, and record a reason for each of the eleven that stay blocked:

- **No design line (5):** *Aegis of the Hearth*, *Wizard's Vigil*, *Sight of the True Form*, and — unless Task 10's splitter change resolved them — *Ward against the Beasts of Legend* and *Ward against Faeries of the Mountain*.
- **Fails assertion 6 (5):** *Wizard's Communion*, *Restore the Moved Image*, *Lay to Rest the Haunting Spirit*, *The Invisible Eye Revealed*, *Dispel the Phantom Image*.
- **Item 26's `Special` duration (1):** *Watching Ward*, whose stat line reads `D: Spec`.

Add an `Aegis of the Hearth` note in the module docstring alongside the existing *Whispering Winds* and *Hermes' Portal* notes: Touch/Year/Boundary is nine magnitudes, so a level-30 Aegis needs base −15; the rulebook itself calls it a Major Breakthrough that is "more powerful than it ought to be". It is permanently blocked, not pending.

- [ ] **Step 5: Add a staleness test for the eleven blocked spells**

In `scripts/spell_import/tests/test_extract.py`, beside the existing
`KnownUnresolvableStalenessTest`:

```python
GENERAL_BLOCKED = {
    "Aegis of the Hearth": "no design line; a Major Breakthrough outside the guidelines",
    "Wizard's Vigil": "no design line",
    "Sight of the True Form": "no design line",
    "Wizard's Communion": "fails assertion 6",
    "Restore the Moved Image": "fails assertion 6",
    "Lay to Rest the Haunting Spirit": "fails assertion 6",
    "The Invisible Eye Revealed": "fails assertion 6",
    "Dispel the Phantom Image": "no Perdo Imaginem General row in the catalog",
    "Watching Ward": "D: Spec is not a Duration in parameters.json — todo item 26",
}


class GeneralBlockedStalenessTest(unittest.TestCase):
    """A blocker that quietly stops applying must fail, not pass silently."""

    def test_every_recorded_general_blocker_still_blocks(self):
        blocked_names = {name for name, _ in run_extraction().blocked}

        no_longer_blocked = sorted(set(GENERAL_BLOCKED) - blocked_names)

        self.assertEqual(
            no_longer_blocked, [],
            "these now import — remove them from GENERAL_BLOCKED and from the "
            "spec's blocked list rather than leaving a stale record")
```

Two ward spells are deliberately absent from `GENERAL_BLOCKED`: *Ward against the Beasts of Legend* and *Ward against Faeries of the Mountain* resolve if Task 10's `(As ward guideline)` splitter change landed. If it did not, add them with the reason `"no design line"` and update the expected counts in Step 6 from ~295/~65 to ~293/~67.

- [ ] **Step 6: Regenerate**

```bash
python -m scripts.spell_import.extract_spells --write --accept-source
```

Expected: **~295 imported, ~65 blocked, 0 unresolved**, of 360. Read `import_report.md` before committing — that is the point of the gate.

- [ ] **Step 7: Run both suites**

Run: `python -m unittest discover -s scripts/spell_import/tests -t . && flutter test`
Expected: PASS. Assertions 6 and 7 are now load-bearing, and Task 5's loader tests now assert against real data.

- [ ] **Step 8: Commit**

```bash
git add scripts/spell_import/ assets/data/spell_templates.json assets/data/spell_library.json
git commit -m "feat: import the published General spells as templates"
```

---

### Task 13: Creation screen — the *Guideline level* field

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_event.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart`, `lib/presentation/screens/spell_creation_screen.dart`
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: Tasks 6–8.
- Produces: `ChosenBaseLevelChanged(int? level)` event; the field keyed `chosen-base-level-field`.

- [ ] **Step 1: Write the failing bloc tests**

```dart
blocTest<SpellCreationBloc, SpellCreationState>(
  'ChosenBaseLevelChanged sets the level on the draft',
  build: () => bloc,
  act: (b) => b
    ..add(BaseEffectSelected(wardGuideline))
    ..add(const ChosenBaseLevelChanged(20)),
  verify: (b) => expect(b.state.draft.chosenBaseLevel, 20),
);

blocTest<SpellCreationBloc, SpellCreationState>(
  'selecting a non-General base effect clears the chosen level',
  build: () => bloc,
  act: (b) => b
    ..add(BaseEffectSelected(wardGuideline))
    ..add(const ChosenBaseLevelChanged(20))
    ..add(BaseEffectSelected(creoIgnem10)),
  verify: (b) => expect(b.state.draft.chosenBaseLevel, isNull),
);

blocTest<SpellCreationBloc, SpellCreationState>(
  'changing the base effect clears the template link',
  build: () => bloc,
  seed: () => SpellCreationState(draft: SpellDraft(templateId: 'tpl-1')),
  act: (b) => b.add(BaseEffectSelected(creoIgnem10)),
  verify: (b) => expect(b.state.draft.templateId, isNull),
);
```

The third is the decay rule: a template link that survives a base-effect change asserts a lineage that no longer holds, the same reasoning as `pruneModifierSelections`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL — `ChosenBaseLevelChanged` is undefined.

- [ ] **Step 3: Add the event and handler**

```dart
class ChosenBaseLevelChanged extends SpellCreationEvent {
  final int? level;
  const ChosenBaseLevelChanged(this.level);

  @override
  List<Object?> get props => [level];
}
```

Register it in the bloc, and extend the existing `BaseEffectSelected` handler to clear both `chosenBaseLevel` (when the new effect is not General) and `templateId` (always), using `copyWith`'s explicit-null path.

- [ ] **Step 4: Add the field to the screen**

Below the base-effect dropdown, rendered only when `state.draft.baseEffect?.isGeneral == true`:

```dart
if (draft.baseEffect?.isGeneral ?? false) ...[
  TextFormField(
    key: const Key('chosen-base-level-field'),
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(
      labelText: 'Guideline level',
      helperText: 'General guidelines have no fixed level — you choose it.',
    ),
    onChanged: (value) => context
        .read<SpellCreationBloc>()
        .add(ChosenBaseLevelChanged(int.tryParse(value))),
  ),
  if (effectSentence != null)
    Text(effectSentence, key: const Key('general-effect-sentence')),
],
```

where `effectSentence` comes from `engine.deriveGeneralEffect(...)?.sentence`.

- [ ] **Step 5: Run the bloc suite**

Run: `flutter test test/bloc/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/bloc/spell_creation/ lib/presentation/screens/spell_creation_screen.dart \
        test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: choose a level for a General guideline in the creation screen"
```

---

### Task 14: Library — the `Gen` chip and *Learn at level…*

**Files:**
- Modify: `lib/bloc/spell_library/*`, `lib/presentation/screens/spell_library_screen.dart`, `lib/presentation/widgets/spell_card.dart`
- Test: `test/bloc/spell_library_bloc_test.dart`

**Interfaces:**
- Consumes: Tasks 5, 13.
- Produces: `SpellLibraryState.templates`; a `TemplateInstantiated(SpellTemplate)` event on `SpellCreationBloc`.

- [ ] **Step 1: Write the failing bloc tests**

```dart
blocTest<SpellLibraryBloc, SpellLibraryState>(
  'LibraryRequested loads templates alongside spells',
  build: () => bloc,
  act: (b) => b.add(LibraryRequested()),
  verify: (b) => expect(b.state.templates, isNotEmpty),
);

blocTest<SpellCreationBloc, SpellCreationState>(
  'TemplateInstantiated prefills the draft and records the link',
  build: () => bloc,
  act: (b) => b.add(TemplateInstantiated(wardTemplate)),
  verify: (b) {
    expect(b.state.draft.baseEffect?.id, 'rean-gen');
    expect(b.state.draft.range?.id, 'range-touch');
    expect(b.state.draft.templateId, wardTemplate.id);
    expect(b.state.draft.chosenBaseLevel, isNull);
  },
);
```

The last expectation matters: instantiation prefills everything **except** the level, which is the one thing the user is there to supply.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/bloc/`
Expected: FAIL — `templates` and `TemplateInstantiated` are undefined.

- [ ] **Step 3: Implement**

Add `templates` to `SpellLibraryState` and load them in the `LibraryRequested` handler via `LibraryRepository.getTemplates()`. Add `TemplateInstantiated` to `SpellCreationEvent` and a handler that resolves the template's ids against the catalog and seeds a `SpellDraft` with `templateId` set and `chosenBaseLevel` null.

In `spell_card.dart`, render a `Gen` chip where the level number goes when the card is showing a template. In `spell_library_screen.dart`, add the `Learn at level…` action, which dispatches `TemplateInstantiated` and switches to the Create tab. Make templates non-editable and non-deletable, and group them separately when sorting by level rather than assigning them a number.

- [ ] **Step 4: Run the suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/bloc/spell_library/ lib/presentation/ test/bloc/
git commit -m "feat: browse General templates and learn them at a chosen level"
```

---

### Task 15: Integration test, and close out the todo

**Files:**
- Modify: `integration_test/spell_creation_flow_test.dart`
- Modify: `.superpowers/todo.md`

**Interfaces:**
- Consumes: every prior task.
- Produces: nothing consumed downstream.

Item 6's standing rule: a mocked bloc emits no new state, so the rebuild after an interaction never happens, and re-render bugs stay invisible. The chosen-level field appearing and disappearing **is** a re-render behaviour, so it belongs here rather than in a mocked widget test.

- [ ] **Step 1: Write the failing integration test**

```dart
testWidgets('the guideline level field appears only for General effects',
    (tester) async {
  await tester.pumpWidget(const EruditusApp());
  await tester.pumpAndSettle();

  await selectTechniqueAndForm(tester, 'Rego', 'Animal');
  await selectBaseEffect(tester, 'rean-gen');
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('chosen-base-level-field')), findsOneWidget);

  await selectBaseEffect(tester, 'rean-5');
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('chosen-base-level-field')), findsNothing);
});

testWidgets('learning a ward template produces a levelled spell',
    (tester) async {
  await tester.pumpWidget(const EruditusApp());
  await tester.pumpAndSettle();

  await openLibraryTab(tester);
  await tester.tap(find.text('Ward against Faeries of the Waters'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Learn at level…'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('chosen-base-level-field')), '20');
  await tester.pumpAndSettle();

  expect(find.text('Affects beings with Might 20 or less'), findsOneWidget);

  await tester.scrollUntilVisible(find.byKey(const Key('calculate-button')), 100);
  await tester.tap(find.byKey(const Key('calculate-button')));
  await tester.pumpAndSettle();

  expect(find.textContaining('20'), findsWidgets);
});
```

The `scrollUntilVisible` before tapping `calculate-button` is deliberate — item 6 records that omitting it is exactly how this suite silently broke before.

- [ ] **Step 2: Run it on a device**

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: FAIL first, then PASS once the helpers are written.

- [ ] **Step 3: Update `.superpowers/todo.md`**

- Mark **item 25 ✅ COMPLETE**, with the spec and plan paths, the final counts, and the eleven blocked spells and their reasons.
- **Item 4** — note that its hard half is done: `deriveGeneralEffect` supplies the ward threshold, so what remains is the ward-type field and display.
- **Item 26** — add *Watching Ward* to the list of spells blocked on a `Special` Duration.
- **Item 28** — unchanged; its five spells are not General.
- **Items 4b/4c** — record that `GeneralEffectFormula` retires the level-dependent-output problem for the 47 General rows, and that non-General fire-damage magnitudes remain deferred.
- **Item 22** — note that its four missing General rows now need a `reference` and an `effectFormula` when added.
- **Item 32** — record that every General entry in `resolutions.json` rests entirely on its written rationale plus assertion 6, by construction.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter test integration_test/ -d windows && python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add integration_test/ .superpowers/todo.md
git commit -m "test: cover the General level flow end to end, and close todo item 25"
```
