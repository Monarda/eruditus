# Task 1 Report: Data Models - Spell & Related Classes

**Status:** DONE

## What Was Implemented

All required data model files have been created with complete implementations from the plan specification:

### Files Created

1. **lib/utils/constants.dart**
   - `ArsArts` class with six Arts constants (Creo, Intellego, Muto, Perdo, Rego, Vim)
   - `ArsForms` class with ten Forms constants (Animal, Aquam, Auram, Corpus, Herbam, Ignem, Imaginem, Mentem, Terram, Vim)

2. **lib/models/base_effect.dart**
   - `BaseEffect` class with id, technique, form, description, baseLevel, and source fields
   - Full serialization via `toMap()` and `fromMap()` factory

3. **lib/models/parameter.dart**
   - `Parameter` class with id, name, category, magnitude, and source fields
   - `SelectedParameter` class wrapping Parameter with parameterId
   - Both have complete serialization/deserialization

4. **lib/models/special_factor.dart**
   - `SpecialFactor` class with id, technique, form, name, description, magnitude, and source
   - Full serialization support

5. **lib/models/requisite.dart**
   - `RequiredRequisite` class for required arts
   - `AdditionalRequisite` class with magnitude field (defaulting to 1)
   - Both classes fully serializable

6. **lib/models/spell.dart**
   - `Spell` class with all required fields: id, name, technique, form, baseEffect, parameters, selectedSpecialFactorIds, requiredRequisites, additionalRequisites, description, source, createdAt, updatedAt
   - Comprehensive serialization supporting nested objects and lists
   - `SpellDraft` class for in-progress spell creation with mutable fields
   - `SpellDraft.toSpell()` factory for converting draft to finalized Spell with timestamps

### Test File Created

**test/models/spell_test.dart**
- Test for Spell serialization round-trip (toMap/fromMap)
- Test for SpellDraft conversion to Spell
- Tests verify preservation of all critical fields

## Implementation Details

All code was transcribed exactly from the plan specification:
- All 8 classes have matching serialization/deserialization interfaces
- Types are preserved through Map conversions (proper casting with `as` operators)
- Nested objects and lists are properly handled
- DateTime objects use ISO8601 string format for serialization
- Optional fields are properly handled with null-coalescing operators

## Commit Information

```
Commit Hash: 4beb972
Message: feat: add data models for spells, effects, parameters, requisites

Files Changed: 7
- lib/models/base_effect.dart (new)
- lib/models/parameter.dart (new)
- lib/models/requisite.dart (new)
- lib/models/special_factor.dart (new)
- lib/models/spell.dart (new)
- lib/utils/constants.dart (new)
- test/models/spell_test.dart (new)

Total Lines Added: 366
```

## Test Verification Status

**Verified by controller (not the implementer):** The implementer could not find `flutter` on PATH. Flutter SDK is actually installed at `C:\Users\idf53\Development\SDKs\flutter\flutter\bin` — it is just not on the default PATH in this environment. The controller added it to PATH and ran the tests directly:

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test test/models/spell_test.dart -v
```

Result: `00:00 +2: All tests passed!` (exit code 0)
- Spell Model Spell.toMap and fromMap round-trip — PASS
- Spell Model SpellDraft.toSpell creates Spell with current timestamp — PASS

**Action for all future task dispatches:** prepend `export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"` before any `flutter` command.

## Code Quality Checks

- All classes follow Dart naming conventions
- Immutability is properly implemented in data models
- Serialization preserves type information
- Factory constructors handle null safety with proper null-coalescing
- Code matches the exact specification from the plan

## Next Steps

Task 1 is complete. Ready for:
- Task 2: Spell Level Calculator implementation
- Integration with spell engine and repositories
- Flutter testing once environment is available

All deliverables from Task 1 have been completed as specified in the plan.

## Fix Round 1: Review Findings

**Status:** DONE

Three Important-severity code review findings were raised against the Task 1 data models and have been fixed following TDD (tests written/extended first, confirmed failing against the old implementation, then implementation fixed, then re-verified passing).

### Finding 1: Unsafe deserialization in all `fromMap` factories

Added a shared helper, `T requireField<T>(Map<String, dynamic> map, String key, String className)`, in a new file `lib/utils/map_serialization.dart`. It reads `map[key]`, and if the value is `null` or not an instance of `T`, throws a `FormatException` naming the class, the field, the expected type, and the actual runtime type (or `null`).

Applied to every required-field read in:
- `lib/models/base_effect.dart` (`BaseEffect.fromMap`) — id, technique, form, description, baseLevel, source
- `lib/models/parameter.dart` (`Parameter.fromMap`, `SelectedParameter.fromMap`) — id, name, category, magnitude, source, parameterId, parameter (nested map)
- `lib/models/special_factor.dart` (`SpecialFactor.fromMap`) — id, technique, form, name, description, magnitude, source
- `lib/models/requisite.dart` (`RequiredRequisite.fromMap`, `AdditionalRequisite.fromMap`) — art (required); `magnitude` on `AdditionalRequisite` stays optional via the existing null-coalescing pattern per the finding's instruction
- `lib/models/spell.dart` (`Spell.fromMap`) — id, technique, form, baseEffect (nested map), source, createdAt, updatedAt; `DateTime.parse` now only ever receives a guaranteed non-null `String`, so a bad/missing `createdAt`/`updatedAt` now fails with a clear `FormatException` before reaching `DateTime.parse`. Optional fields (`name`, `description`) and list fields (which already default to `[]` when absent) were left as-is per the finding's guidance.

### Finding 2: Unguarded null-assertions in `SpellDraft.toSpell()`

`lib/models/spell.dart` — `SpellDraft.toSpell()` now first collects any of `technique`, `form`, `baseEffect` that are null into a `missingFields` list, and if non-empty throws a `StateError` naming exactly which field(s) are missing, e.g. `"Cannot convert SpellDraft to Spell: technique, form are not set"`. Only after that check does it resolve the non-null locals and construct the `Spell`.

### Finding 3: Thin test coverage

Split model tests into per-model files under `test/models/` (kept `spell_test.dart` for `Spell`/`SpellDraft`, since those two are tightly coupled):

- `test/models/base_effect_test.dart` (new) — round-trip on every field; `FormatException` on missing field; `FormatException` on wrong-type field.
- `test/models/parameter_test.dart` (new) — `Parameter` round-trip on every field + missing-field `FormatException`; `SelectedParameter` round-trip verifying the nested `Parameter` survives + missing-field `FormatException`.
- `test/models/special_factor_test.dart` (new) — round-trip on every field; missing-field `FormatException`.
- `test/models/requisite_test.dart` (new) — `RequiredRequisite` round-trip + missing-field `FormatException`; `AdditionalRequisite` round-trip, default `magnitude` (1) when absent, and missing-`art` `FormatException`.
- `test/models/spell_test.dart` (rewritten) — the `Spell` round-trip test now populates non-empty `parameters` (2 `SelectedParameter`s with distinct nested `Parameter`s), `selectedSpecialFactorIds`, `requiredRequisites`, and `additionalRequisites`, and asserts every field on the restored `Spell`, including `baseEffect`'s fields, `description`, `source`, `createdAt`, `updatedAt`, and full contents/order of every list. Added: a `Spell.fromMap` missing-required-field `FormatException` test; and four new `SpellDraft.toSpell()` tests covering `StateError` when `technique`, `form`, or `baseEffect` is missing individually, plus one asserting all three names appear when all three are missing.

Total: 21 tests across `test/models/`, up from 2.

### Files changed

- `lib/utils/map_serialization.dart` (new)
- `lib/models/base_effect.dart`
- `lib/models/parameter.dart`
- `lib/models/special_factor.dart`
- `lib/models/requisite.dart`
- `lib/models/spell.dart`
- `test/models/base_effect_test.dart` (new)
- `test/models/parameter_test.dart` (new)
- `test/models/special_factor_test.dart` (new)
- `test/models/requisite_test.dart` (new)
- `test/models/spell_test.dart` (rewritten)

### Test command and output

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
cd "C:\Users\idf53\Development\personal\arsm\eruditus"
flutter test test/models/ -v
```

Result: `00:07 +21: All tests passed!` (exit code 0). `flutter analyze lib/models lib/utils test/models` also reports `No issues found!`.

### Commit

```
Commit Hash: 7f73275
Message: fix: address code review findings from Task 1 (data models)
```
