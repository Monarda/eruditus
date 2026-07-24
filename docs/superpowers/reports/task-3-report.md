# Task 3: Spell Engine (Validation, Level Calculation & Suggestion Logic) - Implementation Report

**Status:** DONE_WITH_CONCERNS

## Summary

Implemented `SpellEngine`, the business-logic layer that validates spell drafts,
calculates a spell's level by combining a `BaseEffect` with parameter, special-factor,
and additional-requisite magnitudes (delegating the arithmetic to Task 2's
`SpellLevelCalculator`), and finds similar existing spells for the suggestion feature.
Followed TDD throughout: wrote the failing test file first, confirmed it failed to
compile (no `SpellEngine` class), implemented the engine exactly as specified in the
task brief, then reran to confirm all tests pass.

## What Was Implemented

### Files Created

1. **`lib/engine/spell_engine.dart`** — `SpellEngine` class with:
   - `validateSpellDraft(SpellDraft draft) -> List<String>`: returns human-readable
     error messages for missing technique, form, or base effect; empty list means valid.
   - `calculateSpellLevel({required BaseEffect baseEffect, required List<SelectedParameter> parameters, required List<String> selectedSpecialFactorIds, required List<AdditionalRequisite> additionalRequisites}) -> int`:
     collects magnitudes from parameters, special factors (resolved by ID against the
     `allSpecialFactors` catalog passed into the constructor, via `firstWhere` which
     throws `StateError` on an unknown ID — fail-fast, consistent with Task 1's
     `fromMap` pattern), and additional requisites, then delegates the actual two-tier
     math to `SpellLevelCalculator.calculate(baseEffect.baseLevel, magnitudes)`.
   - `findSimilarSpells(String technique, String form, {int? referenceLevel}) -> List<Spell>`:
     filters `allSpells` by matching Technique+Form, and when `referenceLevel` is
     supplied, sorts by absolute level difference (closest first), computing each
     candidate's level via `calculateSpellLevel`.

2. **`test/engine/spell_engine_test.dart`** — 10 tests covering:
   - `validateSpellDraft`: missing technique, missing form, missing base effect, and
     a fully valid draft (empty errors).
   - `calculateSpellLevel`: base effect alone, parameter magnitudes ("Eyes of the Cat"),
     special-factor magnitudes resolved by ID, and additional-requisite magnitudes.
   - `findSimilarSpells`: filtering by Technique+Form, and sort-by-closeness-to-
     `referenceLevel` with deliberately unsorted input.

Both files were transcribed exactly from the task brief
(`.superpowers/sdd/task-3-brief.md`), which had already been corrected by the
controller to remove a duplicate `SpellDraft` stub and fill in the previously-missing
`calculateSpellLevel` implementation. No changes were needed to the brief's code —
it compiled and passed as written against the actual Task 1 models
(`lib/models/spell.dart`, `base_effect.dart`, `parameter.dart`, `special_factor.dart`,
`requisite.dart`) and Task 2's `SpellLevelCalculator`.

## Test Results

### Test Command
```bash
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
cd C:\Users\idf53\Development\personal\arsm\eruditus
flutter test test/engine/spell_engine_test.dart -v
```

### Step 2 — Confirmed red (before implementation)
Running the above with only the test file in place (no `lib/engine/spell_engine.dart`)
failed to compile, as expected:
```
test/engine/spell_engine_test.dart:110:22: Error: Method not found: 'SpellEngine'.
test/engine/spell_engine_test.dart:127:22: Error: Method not found: 'SpellEngine'.
test/engine/spell_engine_test.dart:163:22: Error: Method not found: 'SpellEngine'.
test/engine/spell_engine_test.dart:176:22: Error: Method not found: 'SpellEngine'.
00:00 +0 -1: Some tests failed.
...
test package returned with exit code 1
```

### Step 4 — Confirmed green (after implementation)
```
00:00 +0: SpellEngine.validateSpellDraft fails if technique not selected
00:00 +1: SpellEngine.validateSpellDraft fails if form not selected
00:00 +2: SpellEngine.validateSpellDraft fails if base effect not selected
00:00 +3: SpellEngine.validateSpellDraft passes for valid draft
00:00 +4: SpellEngine.calculateSpellLevel computes level from base effect alone (no parameters/factors/requisites)
00:00 +5: SpellEngine.calculateSpellLevel includes parameter magnitudes
00:00 +6: SpellEngine.calculateSpellLevel includes special factor magnitudes resolved by ID
00:00 +7: SpellEngine.calculateSpellLevel includes additional requisite magnitudes
00:00 +8: SpellEngine.findSimilarSpells returns only spells with matching Technique+Form
00:00 +9: SpellEngine.findSimilarSpells sorts by closeness to referenceLevel when provided
00:00 +10: All tests passed!
```
**Result:** All 10 tests passing (exit code 0).

### Full-suite regression check
```bash
flutter test
```
Result: **43 tests passed, 0 failed** (all of Task 1's model tests, Task 2's
calculator tests, the new Task 3 engine tests, and the default widget smoke test).

## Concerns

1. **Concurrent writes to the same repository from another process.** While this
   task was in progress, another process/session committed unrelated changes to the
   same working tree (the Flutter platform scaffold — `android/`, `ios/`, `linux/`,
   `macos/`, `windows/`, `web/`, `main.dart`, `widget_test.dart` — and later
   `pubspec.yaml`/`pubspec.lock` dependency additions), authored as "Ivan Finch"
   with a `Co-Authored-By: Claude Haiku 4.5` trailer, at commit `d0227ef` ("chore:
   commit Flutter project scaffold") and `4ddd796` ("chore: add sqflite,
   flutter_bloc, and supporting dependencies"). My `git add lib/engine/spell_engine.dart
   test/engine/spell_engine_test.dart` ran concurrently with that process's own
   `git add`/commit, and my two files ended up folded into commit `d0227ef` instead
   of getting their own commit with the message specified in the task brief (Step 5).
   I verified `git diff HEAD -- lib/engine/spell_engine.dart test/engine/spell_engine_test.dart`
   is empty — the committed content is byte-for-byte what I wrote and tested — but the
   commit message for those two files reads "chore: commit Flutter project scaffold"
   rather than the SpellEngine-specific message from the brief. I did not rewrite
   history (no `--amend`, no force-push) per the git safety rules. Flagging this so
   the controller is aware the commit trail doesn't cleanly attribute this task's
   work, even though the code itself is correct, tested, and unmodified since.
2. Per the brief's explicit design note, an unknown ID in `selectedSpecialFactorIds`
   causes `firstWhere` to throw an uncaught `StateError` rather than being handled
   gracefully — this is intentional (fail-fast on a data-integrity bug) and matches
   Task 1's established pattern, not a defect.

## Commit Information

The implementation is present, unmodified, and passing tests at the current `HEAD`:

**HEAD commit hash:** `4ddd796` (`4ddd7964f7b7f084c4d62403f4910a6ffa3385e1`)

**Commit that actually introduced `lib/engine/spell_engine.dart` and
`test/engine/spell_engine_test.dart`:** `d0227ef` ("chore: commit Flutter project
scaffold") — see Concerns above for why this doesn't carry the Task 3-specific
commit message from the brief.

I did not create a separate commit for just these two files since, by the time I
went to commit, they were already committed (with identical content) by the
concurrent process described above, and `git status` showed a clean tree for these
paths.
