# Task 4 Report: Database Schema & Local Spell Datasource

**Status:** DONE

## What I implemented

Followed the task brief exactly (`.superpowers/sdd/task-4-brief.md`), using TDD:

1. **`test/data/datasources/local_spell_datasource_test.dart`** — created first, verbatim from the brief. Uses `sqflite_common_ffi` with `databaseFactoryFfi` and `inMemoryDatabasePath` for isolated in-memory DB per test. Covers: insert+getById, getById returns null for unknown id, getAllSpells returns all inserted spells, updateSpell persists changes, deleteSpell removes the row.
2. **`lib/data/database/app_database.dart`** — `AppDatabase` class with a static `open({String? path})` factory that opens (or creates, via `onCreate`) a SQLite database with four tables: `spells` (id, name, technique, form, source, data, created_at, updated_at), `custom_effects`, `custom_parameters`, `custom_factors` (the latter three reserved for Task 5's `LocalConfigurationDatasource`). Also exposes `close()`.
3. **`lib/data/datasources/local_spell_datasource.dart`** — `LocalSpellDatasource` with CRUD for the `spells` table only: `insertSpell`, `updateSpell`, `deleteSpell`, `getSpellById`, `getAllSpells`. Each row stores the full `Spell` as a JSON blob in the `data` column (`jsonEncode(spell.toMap())` / `Spell.fromMap(jsonDecode(...))`) plus flat `id`/`name`/`technique`/`form`/`source`/`created_at`/`updated_at` columns for filtering without deserializing.

Before implementing, I verified the existing `Spell` and `BaseEffect` models (`lib/models/spell.dart`, `lib/models/base_effect.dart`) match the constructor/field usage in the brief's test — they do (no changes needed to Task 1's models).

## Test command and output

Step 2 (confirm failing before implementation) — ran:
```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
cd C:\Users\idf53\Development\personal\arsm\eruditus
flutter test test/data/datasources/local_spell_datasource_test.dart -v
```
Result: compile errors as expected — `'AppDatabase' isn't a type.`, `'LocalSpellDatasource' isn't a type.` — confirming the test genuinely exercises not-yet-written code. Exit code 1.

Step 5 (after implementation) — ran the same command again:
```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
cd C:\Users\idf53\Development\personal\arsm\eruditus
flutter test test/data/datasources/local_spell_datasource_test.dart -v
```
Full relevant output:
```
00:00 +0: (setUpAll)
00:00 +0: insertSpell then getSpellById returns the spell
00:00 +1: getSpellById returns null for unknown id
00:00 +2: getAllSpells returns all inserted spells
00:00 +3: updateSpell persists changes
00:00 +4: deleteSpell removes the spell
00:00 +5: (tearDownAll)
00:01 +5: All tests passed!
test package returned with exit code 0
```
All 5 tests pass.

Also ran the full suite to check for regressions:
```
export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"
cd C:\Users\idf53\Development\personal\arsm\eruditus
flutter test
```
Result: `00:08 +48: All tests passed!` (48 total tests across the project, exit code 0) — the 5 new datasource tests plus all prior Task 1–3 tests (models, spell level calculator, spell engine, widget smoke test) still pass.

## Concerns

None. This was a mechanical implementation matching the brief's exact, pre-validated SQL and Dart code. The `custom_effects`/`custom_parameters`/`custom_factors` tables are created but have no datasource yet — that's explicitly Task 5's responsibility per the brief, not an oversight here.

## Commit

`40c6661` — "feat: add SQLite database schema and local spell datasource"

Files committed (only the three specified in Step 6):
- `lib/data/database/app_database.dart`
- `lib/data/datasources/local_spell_datasource.dart`
- `test/data/datasources/local_spell_datasource_test.dart`

An untracked `.claude/` directory was present in the working tree before I started and was left untouched/unstaged, per instructions.
