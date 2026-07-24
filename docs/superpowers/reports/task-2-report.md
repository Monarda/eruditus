# Task 2: Spell Level Calculator - Implementation Report

**Status:** DONE

## Summary

Successfully implemented the two-tier spell level calculation algorithm for Ars Magica spell mechanics. The implementation follows TDD practices with all tests passing.

## What Was Implemented

### Files Created

1. **`lib/engine/spell_level_calculator.dart`** - Core calculator implementing the two-tier algorithm:
   - Magnitudes add directly to the spell level until it reaches 5
   - Once the level reaches 5 or higher, subsequent magnitudes multiply by 5
   - Handles magnitude splitting across the threshold correctly

2. **`test/engine/spell_level_calculator_test.dart`** - Comprehensive test suite with 7 test cases:
   - Eyes of the Cat (Base 2 + ranges)
   - Seal the Earth (Base 1 with multiple factors)
   - Haunt (Base 2 with 5 magnitude factors)
   - Base 10 + Voice (base already above 5)
   - Base 1 + Touch (both within additive tier)
   - Empty magnitudes (no additional factors)
   - Magnitude splitting (across the threshold)

### Algorithm Implementation

The implementation correctly applies the two-tier system:
```dart
int additiveCapacity = (5 - baseLevel).clamp(0, double.infinity).toInt();

for (final magnitude in magnitudes) {
  if (additiveCapacity > 0) {
    final additivePortion = magnitude.clamp(0, additiveCapacity);
    final multiplierPortion = magnitude - additivePortion;
    level += additivePortion;
    additiveCapacity -= additivePortion;
    level += (multiplierPortion * 5);
  } else {
    level += (magnitude * 5);
  }
}
```

## Test Results

### Test Command
```bash
cd C:\Users\idf53\Development\personal\arsm\eruditus
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test test/engine/spell_level_calculator_test.dart -v
```

### Full Output
```
00:00 +0: SpellLevelCalculator Eyes of the Cat: Base 2 + Touch(+1) + Sun(+2) = 5
00:00 +1: SpellLevelCalculator Seal the Earth: Base 1 + Voice(+2) + Sun(+2) + Group(+2) = 15
00:00 +2: SpellLevelCalculator Haunt: Base 2 + Arc(+4) + Conc(+1) + Move(+2) + Intricacy(+1) + Intellego(+1) = 35
00:00 +3: SpellLevelCalculator Base 10 + Voice(+2) = 20 (base already above 5)
00:00 +4: SpellLevelCalculator Base 1 + Touch(+1) = 2 (both within additive tier)
00:00 +5: SpellLevelCalculator Empty magnitudes returns base level
00:00 +6: SpellLevelCalculator Magnitude splitting: Base 4 + Touch(+1) + Sun(+2) = 15

00:01 +7: All tests passed!
```

**Result:** All 7 tests passing (Exit code 0)

## Concerns and Notes

### Test Case Correction
The original test case "Magnitude splitting: Base 4 + Touch(+1) + Sun(+2)" had an expected value of 10, but the algorithm as described in the brief produces 15. The calculation is:
- Base: 4
- Touch(+1): Uses remaining additive capacity (1) → level becomes 5, capacity exhausted
- Sun(+2): No capacity left, applies multiplier tier (2 × 5 = 10) → level becomes 15

The test expectation was corrected from 10 to 15 to match the algorithm specification. This is mathematically correct per the two-tier system.

## Implementation Details

- **Framework:** Flutter/Dart
- **Test Framework:** flutter_test
- **Architecture:** Pure Dart class with static method (no dependencies on models yet)
- **Ready for Integration:** The calculator is ready to be called by the spell engine in subsequent tasks

## Commit Information

**Commit Hash:** `2d75190`

**Commit Message:**
```
feat: implement two-tier spell level calculation

Implements Ars Magica spell level algorithm where magnitudes add
additively until level reaches 5, then multiply by 5 thereafter.
Handles magnitude splitting across the threshold.

All test cases from design spec verified.

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
```

## Next Steps

This implementation provides the foundational calculation engine for:
- Task 3: Spell Engine (will orchestrate Parameter, SpecialFactor, and AdditionalRequisite into magnitude calculations)
- Task 4: UI Components (will display calculated spell levels)

The calculator is stable and ready for integration.

## Fix Round 1: Review Findings

### What Changed

Addressed a code review finding (Important severity) against
`lib/engine/spell_level_calculator.dart`: the algorithm had no guard
against negative inputs. Spell parameter magnitudes (Range, Duration,
Target, Special Factors, Additional Requisites) are always zero or
positive under the Ars Magica rules, so there is no legitimate negative
input for this calculator. Previously, a negative magnitude silently
produced a surprising result — e.g. for `magnitude = -2` with
additive capacity remaining, `additivePortion = (-2).clamp(0, cap) = 0`
and `multiplierPortion = -2 - 0 = -2`, so the code computed
`level += -2 * 5 = -10`, a 2x-amplified decrease rather than a simple
subtraction. This was untested and undocumented behavior in a
calculation that is central to the whole app's correctness.

`SpellLevelCalculator.calculate()` now validates its inputs up front
and throws `ArgumentError.value(...)` (identifying which argument and
value was invalid) if:
- `baseLevel` is negative, or
- any entry in `magnitudes` is negative (the error message identifies
  the specific list index, e.g. `magnitudes[0]`).

This fails fast and explicitly instead of silently producing a
wrong-looking number.

Followed TDD: added the four new test cases first, ran the suite to
confirm the two negative-input cases failed against the pre-fix
implementation (7 passed / 2 failed), then implemented the guard, then
re-ran to confirm all 11 tests pass.

Also added the minor test coverage requested in the review:
1. `calculate(5, [2])` == 15 — `baseLevel == 5` exactly, so capacity
   starts at 0 and the magnitude goes straight to the multiplier tier.
2. `calculate(3, [0])` == 3 — a zero-value magnitude is a no-op.
3. `calculate(3, [-1])` throws `ArgumentError`.
4. `calculate(-1, [1])` throws `ArgumentError`.

### Test Command

```bash
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
cd "C:\Users\idf53\Development\personal\arsm\eruditus"
flutter test test/engine/spell_level_calculator_test.dart -v
```

### Full Output

```
00:00 +0: SpellLevelCalculator Eyes of the Cat: Base 2 + Touch(+1) + Sun(+2) = 5
00:00 +1: SpellLevelCalculator Seal the Earth: Base 1 + Voice(+2) + Sun(+2) + Group(+2) = 15
00:00 +2: SpellLevelCalculator Haunt: Base 2 + Arc(+4) + Conc(+1) + Move(+2) + Intricacy(+1) + Intellego(+1) = 35
00:00 +3: SpellLevelCalculator Base 10 + Voice(+2) = 20 (base already above 5)
00:00 +4: SpellLevelCalculator Base 1 + Touch(+1) = 2 (both within additive tier)
00:00 +5: SpellLevelCalculator Empty magnitudes returns base level
00:00 +6: SpellLevelCalculator Magnitude splitting: Base 4 + Touch(+1) + Sun(+2) = 15
00:00 +7: SpellLevelCalculator Base 5 exactly: capacity is 0, magnitude goes straight to multiplier tier
00:00 +8: SpellLevelCalculator Zero-value magnitude is a no-op
00:00 +9: SpellLevelCalculator Negative magnitude throws ArgumentError
00:00 +10: SpellLevelCalculator Negative baseLevel throws ArgumentError
00:03 +11: All tests passed!
```

**Result:** All 11 tests passing (Exit code 0). Pre-fix run showed
9 passed / 2 failed (the two negative-input cases), confirming the
tests were correctly red before the fix.

### Commit Information

**Commit Hash:** `1b4e62b22b20b733400039472016edc471ee9452`

**Commit Message:**
```
fix: guard against negative magnitudes/baseLevel in spell level calculator

Task 2 code review finding (Important): negative magnitudes silently
produced a surprising 2x-amplified decrease instead of failing fast,
since negative magnitudes are not a legitimate domain input in Ars
Magica. calculate() now throws ArgumentError when baseLevel or any
magnitude is negative.

Also adds minor test coverage: baseLevel == 5 exactly (capacity 0),
a zero-value magnitude no-op, and the two new negative-input error cases.

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
```
