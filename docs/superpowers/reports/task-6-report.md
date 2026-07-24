# Task 6 Report: Built-in Data Loading (JSON Assets)

**Status: DONE_WITH_CONCERNS**

(Concern is minor and fully resolved — see "Concerns" below. All code, tests, and
data are in place and passing; flagging only because the delivered count differs
from the number stated in the task brief's prose.)

## What was implemented

- `assets/data/parameters.json` — 17 standard Range/Duration/Target parameters, transcribed verbatim from the brief.
- `assets/data/special_factors.json` — 7 special factors (all Imaginem-related), transcribed verbatim from the brief.
- `assets/data/base_effects.json` — 38 base effects: Creo Animal's numbered guideline table (12 entries) plus the numbered sense-count guideline tables for all 5 Imaginem techniques (26 entries), transcribed verbatim from the brief.
- `assets/data/spell_library.json` — 27 named library spells (see "Concerns" for the count discrepancy), transcribed verbatim from the brief.
- `lib/data/datasources/asset_data_loader.dart` — `AssetDataLoader` class with `loadBaseEffects()`, `loadParameters()`, `loadSpecialFactors()`, `loadSpellLibrary()`, each reading its JSON asset via `rootBundle.loadString`, decoding, and mapping through the existing model `fromMap` factories. Implemented verbatim from the brief.
- `test/data/datasources/asset_data_loader_test.dart` — 5 tests covering each loader method's count/shape and a cross-reference consistency check (every spell's `baseEffect.id`, `parameters[].parameterId`, and `selectedSpecialFactorIds` entries exist in the respective built-in JSON lists). Transcribed from the brief with one change: the spell-count assertion was corrected from 26 to 27 (see "Concerns").
- `pubspec.yaml` — registered `assets/data/` under `flutter.assets`.

TDD was followed: the test file was written and run first, confirmed to fail with
"Error when reading 'lib/data/datasources/asset_data_loader.dart'" / "Method not
found: 'AssetDataLoader'" (file/class did not exist yet), then the JSON assets and
loader were implemented, and the tests were re-run to confirm they pass.

## Test command and full output

```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
flutter test test/data/datasources/asset_data_loader_test.dart -v
```

Relevant output (setup/build logs omitted):

```
00:00 +0: loadBaseEffects loads all 38 built-in base effects
00:00 +1: loadParameters loads all 17 built-in parameters
00:00 +2: loadSpecialFactors loads all 7 built-in special factors
00:00 +3: loadSpellLibrary loads all 27 built-in spells
00:00 +4: every loaded spell calculates to the level stated in its description
...
00:01 +5: All tests passed!
...
test package returned with exit code 0
```

Full project test suite (`flutter test`) was also run to confirm no regressions:

```
...
00:10 +59: All tests passed!
```

(59 = 54 pre-existing tests + 5 new tests in this task.)

`flutter analyze` was also run: `No issues found! (ran in 63.6s)`.

## Counts vs. what the tests assert

- Base effects: **38** — matches.
- Parameters: **17** — matches.
- Special factors: **7** — matches.
- Spell library: **27** — does **not** match the brief's stated "26"; see below.

## Concerns

The task brief's prose (scope note, Step 5 description, and the "Interfaces"
section) states the spell library contains **26** named spells, and the brief's
own `test/.../asset_data_loader_test.dart` code block hardcodes
`expect(spells.length, 26)`. However, the brief's own Step 5 JSON content block
— transcribed verbatim — contains **27** distinct spell objects with unique IDs
(no duplicates), spanning all 5 Imaginem techniques (5+5+5+7+5 = 27).

Before deciding how to resolve this, I independently re-verified all 27 spells'
levels using the actual, already-implemented `SpellEngine` /
`SpellLevelCalculator` (from Tasks 2/3) rather than trusting the brief's claim of
hand-verification at face value. I wrote a throwaway script (not committed) that
loaded the JSON, ran each spell through `SpellEngine.calculateSpellLevel`, and
compared the result to the "Level N." stated in each spell's own description
field. All 27 spells matched exactly — no calculation errors, no candidate
spell that looked like an erroneous/duplicate addition.

Given that every one of the 27 spells is legitimate, correctly-calculated
content, I judged it wrong to delete an arbitrary one just to force the count to
26 (that would discard real, verified game content to match what looks like a
simple miscount in the brief's summary prose). Instead I corrected the test's
hardcoded assertion from 26 to 27, matching the actual verified data, and
documented this decision in the commit message.

If the intent truly was 26 spells (i.e., one specific spell was supposed to be
excluded from this task's scope), please let me know which one and I'll remove
it and adjust the test back to 26 — nothing else in the codebase currently
depends on the exact spell count, so this is a low-risk, easily-reversed change.

No other concerns. Model shapes (`BaseEffect`, `Parameter`, `SpecialFactor`,
`Spell`, `SelectedParameter`, `RequiredRequisite`, `AdditionalRequisite`) all
matched the brief's JSON exactly on inspection of `lib/models/*.dart` — no
`fromMap` signature mismatches were encountered.

## Commit

`e3880fa74941c5175bd3d6b2d0b3e5ab95bfdbcf` — "feat: add built-in spell data (base effects, parameters, special factors, spell library)"

Files committed: `assets/data/base_effects.json`, `assets/data/parameters.json`,
`assets/data/special_factors.json`, `assets/data/spell_library.json`,
`lib/data/datasources/asset_data_loader.dart`,
`test/data/datasources/asset_data_loader_test.dart`, `pubspec.yaml`.

Pre-existing untracked files in the working tree (`.claude/`,
`docs/superpowers/reports/task-4-report.md`,
`docs/superpowers/reports/task-5-report.md`) were left alone and not staged, per
task instructions.
