# Dangling Factor Fix Report

## Status: DONE

Fixed the Important-severity finding: `SpellEngine.calculateSpellLevel` threw
`StateError` ("No element") when a spell's `selectedSpecialFactorIds`
contained an id no longer present in `allSpecialFactors` (e.g. a custom
special factor deleted in Settings after a spell that selected it was
saved). That crash was reachable from `SpellLibraryBloc.LibraryRequested`
(caught, but dropped the *entire* Library tab into its error state, hiding
every spell) and from `SpellCreationBloc`'s `findSimilarSpells` level-sort
(uncaught).

Commit: `53b025f` — "fix: make calculateSpellLevel tolerate dangling special
factor ids"

## Root cause

`lib/engine/spell_engine.dart`, `calculateSpellLevel` (previously lines
55-60):

```dart
...selectedSpecialFactorIds.map((id) =>
    allSpecialFactors.firstWhere((f) => f.id == id).magnitude),
```

`firstWhere` with no `orElse` throws `StateError` if no element matches.
Deleting a custom special factor in the Configuration/Settings tab does not
cascade to spells that already reference it by id, so a saved spell can
carry a permanently-dangling id. `SpellLibraryBloc.LibraryRequested` (added
in commit `a27db5c`) computes a level for every spell in the library inside
one try/catch, so this one bad reference took down the whole tab.

## Fix and reasoning

Chose: **treat an unresolved special factor id as contributing 0 magnitude**
(equivalent to filtering it out of the summed list before totaling), rather
than crashing.

```dart
final magnitudes = <int>[
  ...parameters.map((p) => p.parameter.magnitude),
  // A selected factor id that no longer resolves against
  // allSpecialFactors (e.g. a custom factor the user deleted in Settings
  // after saving a spell that referenced it) contributes 0 magnitude
  // rather than throwing. ...
  for (final id in selectedSpecialFactorIds)
    for (final f in allSpecialFactors.where((f) => f.id == id).take(1))
      f.magnitude,
  ...additionalRequisites.map((r) => r.magnitude),
];
```

This is a single-pass lookup (`where(...).take(1)`, lazily evaluated — no
separate "does it exist" pass followed by a second `firstWhere`), and keeps
the same flat "list of magnitudes summed together" shape the
`parameters`/`additionalRequisites` lines already use, rather than
introducing a different idiom (e.g. a helper method or `orElse: () => null`
plus a null-check) just for this one case. Semantically: a factor that no
longer exists can't sensibly contribute a nonzero, made-up magnitude, and 0
is the same "doesn't affect the total" value the codebase already treats an
absent optional component as (an empty `parameters`/`additionalRequisites`
list contributes nothing either). This does **not** change the two-tier
level-calculation math for the normal case — every id that *does* resolve is
summed exactly as before; only the previously-throwing unresolved case
changes behavior, from crash to "count as 0."

`findSimilarSpells`'s internal level-sort calls the same
`calculateSpellLevel`, so it's fixed by the same change — no separate patch
needed there.

## Tests added

- `test/engine/spell_engine_test.dart` → new test in the
  `SpellEngine.calculateSpellLevel` group: `'treats a dangling special
  factor id (deleted after the spell was saved) as 0 magnitude instead of
  throwing'`. Engine constructed with an empty `allSpecialFactors` list,
  `selectedSpecialFactorIds: ['deleted-factor-id']`; asserts `level == 2`
  (Base 2 + 0, base effect alone) with no thrown exception.
- `test/bloc/spell_library_bloc_test.dart` → new `blocTest`:
  `'LibraryRequested loads successfully even when a saved spell references a
  deleted special factor id'`. Saves a user spell with
  `selectedSpecialFactorIds: ['no-longer-exists']` (via the `setUp` param,
  since `bloc_test`'s `build` callback must stay synchronous) alongside the
  existing seeded `user-1` spell, then asserts `LibraryRequested` reaches
  `SpellLibraryStatus.loaded` (not `error`) with `allSpells.length == 29` and
  `spellLevels['user-dangling'] == 5` — i.e. the exact user-visible blast
  radius from the finding (whole tab staying usable, not just the engine not
  throwing).

## Verification

- `flutter test`: **136/136 passing** (134 pre-existing + 2 new, 0
  regressions). Confirmed with a clean, non-concurrent run after an earlier
  concurrent `analyze`+`test` invocation produced a transient, file-contention
  false failure (`configuration_bloc_test.dart` / `spell_library_bloc_test.dart`
  "loading: failing") that a subsequent isolated run did not reproduce.
- `flutter analyze`: **No issues found!** (no new warnings; the 2
  pre-existing `deprecated_member_use` info-level warnings in
  `spell_library_screen.dart` are unrelated, out-of-scope, and untouched by
  this change).

## Scope note

`lib/presentation/screens/spell_library_screen.dart` had pre-existing
uncommitted modifications in the working tree at the start of this task
(unrelated to this fix — not touched or included in this commit). Only
`lib/engine/spell_engine.dart`, `test/engine/spell_engine_test.dart`, and
`test/bloc/spell_library_bloc_test.dart` were staged and committed.

## Concerns

None. Fix is minimal, matches existing summing idiom, doesn't alter the
resolved-id math path, and both the narrow engine-level crash and the
broader Library-tab blast radius are covered by regression tests.
