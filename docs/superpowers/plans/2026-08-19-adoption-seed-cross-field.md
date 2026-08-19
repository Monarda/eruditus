# Adoption's Seed Yields to a Conflicting Peer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `SpellCreationBloc._seedParameters` from seeding a Range/Target pair that `validateSpellAgainstCatalog`'s checks 10 and 11 reject, closing todo item 74.

**Architecture:** `_seedParameters` keeps seeding each slot independently, then reconciles: if the resulting Range/Target pair conflicts under check 10 (Core Rules 12086 — a Personal Range forbids a container Target) or check 11 (HoH:MC 1006 — a Sensory Target requires Personal Range), both slots revert to their pre-adoption values. A new private static predicate `_rangeTargetConflict` mirrors those two checks. Duration is untouched — it carries no cross-field constraint. A corpus test guards the one data invariant the revert relies on.

**Tech Stack:** Flutter/Dart, `bloc_test`, `flutter_test`, `mocktail`, `sqflite_common_ffi`.

**Spec:** `docs/superpowers/specs/2026-08-19-adoption-seed-cross-field-design.md`

## Global Constraints

- **Never run `dart format`.** It is not clean on this repo. Hand-indent to match surrounding code and verify with `git diff -w`.
- **`flutter analyze` must exit 0** before every commit.
- If `flutter test` reports a `sqlite3.dll` permissions error, it is stale `flutter_tester` processes holding the file. Kill them (`taskkill /F /IM flutter_tester.exe`) and re-run — it is not a real permissions problem.
- Citations in code comments mirror the codebase's existing (8-low) core-rules numbering: write `12086`, not `12094`. Item 70 owns the bulk correction.
- Do not change `validateSpellAgainstCatalog` or checks 10/11. The validator was never the gap; it already refuses the save.
- Do not add a user-visible explanation that a seed was suppressed. That is item 56's territory.

---

### Task 1: `_seedParameters` refuses a seed that contradicts its peer

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart` (the `_seedParameters` doc comment around lines 687-726, its body around lines 727-753, and `_isContainer` around line 758)
- Test: `test/bloc/spell_creation_bloc_test.dart` (the seeding fixture block around lines 843-890, and the test at line 974)

**Interfaces:**
- Consumes: `Parameter.forbidsTargetTypes` (`List<TargetType>`), `Parameter.requiresRangeId` (`String?`), `Parameter.targetType` (`TargetType?`), `Parameter.id` (`String`) — all already on the model.
- Produces: `static bool _rangeTargetConflict(Parameter? range, Parameter? target)` on `SpellCreationBloc`. Private; nothing outside this file consumes it. Task 2 re-states the same two conditions independently against catalog data and must **not** try to call it.

- [ ] **Step 1: Add a second ward fixture to the seeding test block**

In `test/bloc/spell_creation_bloc_test.dart`, immediately after the existing `plainEffect` declaration (around line 887, just before `SpellCreationBloc seedingBloc() =>`), add:

```dart
  // A second guideline carrying the same Touch/Ring/Circle reference. Shape B
  // below needs the draft to already sit on a ward reference -- that is the
  // only way a chosen Personal Range reads as deliberate, since Personal is
  // also the standard reference value the comparison would call untouched.
  final wardEffect2 = BaseEffect(
    id: 'ward-2', technique: 'Rego', form: 'Aquam',
    description: 'Ward against water', baseLevel: 5,
    reference: const ParameterTriple(
        rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle'),
    provenance: Provenance(
        source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
  );
```

- [ ] **Step 2: Rewrite the test that currently pins the illegal state**

Replace the whole `blocTest` at `test/bloc/spell_creation_bloc_test.dart:973-989` — the one named `'the adopt is per-slot: an untouched Range and Duration follow the new guideline while a chosen Target stays'` — with:

```dart
  blocTest<SpellCreationBloc, SpellCreationState>(
    // Shape A of todo item 74. The Duration assertion is the point of the
    // "per-slot" half: the Range seed is refused, but Duration has no
    // cross-field constraint and must still follow the new guideline.
    'the adopt is per-slot, and a Range seed that a chosen Target forbids is '
    'not written',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(BaseEffectSelected(wardEffect));  // -> touch / ring / circle
      bloc.add(TargetSelected(room));            // deliberately off the seed
      bloc.add(BaseEffectSelected(plainEffect)); // reference: standard
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>()
          // Personal + Room is what check 10 rejects, so the Range keeps its
          // pre-adoption value instead of following the new guideline.
          .having((s) => s.draft.range?.id, 'draft.range', 'range-touch')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-momentary')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-room'),
    ],
  );
```

- [ ] **Step 3: Add the two shapes no existing test covers**

Immediately after the test from Step 2, add:

```dart
  blocTest<SpellCreationBloc, SpellCreationState>(
    // Shape B of todo item 74, the forbidding direction reached from the other
    // side: the seed wants to write the container Target, and a deliberate
    // Personal Range is what forbids it. RangeSelected(personal) is only
    // *deliberate* because the outgoing reference named Touch.
    'a container Target seed that a chosen Personal Range forbids is not written',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(BaseEffectSelected(wardEffect)); // -> touch / ring / circle
      bloc.add(RangeSelected(personal));        // clears Circle; off the seed
      bloc.add(BaseEffectSelected(wardEffect2));// reference: touch / ring / circle
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.target, 'draft.target', isNull)
          // Duration carries no cross-field constraint and still adopts.
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring')
          .having((s) => s.draft.containerMode, 'draft.containerMode',
              ContainerMode.unstated),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    // Shape C of todo item 74 -- the regression no value comparison can see.
    // TargetSelected(sound) sets range-personal itself, to satisfy check 11.
    // range-personal is also the standard reference value, so the seed cannot
    // tell that bloc-written Range apart from an untouched slot and would
    // re-seed it to Touch, out from under the Target that required it.
    'a Range seed is not written over the Range a Sensory Target requires',
    build: seedingBloc,
    act: (bloc) {
      bloc.add(TargetSelected(sound));          // forces Range -> Personal
      bloc.add(BaseEffectSelected(wardEffect)); // reference: touch / ring / circle
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.range?.id, 'draft.range', 'range-personal')
          .having((s) => s.draft.target?.id, 'draft.target', 'target-sound')
          .having((s) => s.draft.duration?.id, 'draft.duration', 'duration-ring'),
    ],
  );
```

- [ ] **Step 4: Run the three tests to verify they fail**

```bash
flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "is not written"
```

Expected: **3 tests, all FAIL.**
- Shape A fails on `draft.range`: `'range-personal'` where `'range-touch'` is expected.
- Shape B fails on `draft.target`: `target-circle` where `null` is expected.
- Shape C fails on `draft.range`: `'range-touch'` where `'range-personal'` is expected.

If any of the three *passes* at this point, stop — the fixture or `act` sequence is wrong and the test is not exercising the path it claims.

- [ ] **Step 5: Add the conflict predicate**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, directly below the existing `_isContainer` declaration (around line 758), add:

```dart
  /// Whether [range] and [target] are the pair validateSpellAgainstCatalog
  /// rejects -- check 10's forbidding direction (core 12086: a Personal Range
  /// can never take a container Target) and check 11's forcing one (HoH:MC
  /// 1006: each Sensory Target requires Personal Range).
  ///
  /// Mirrors both checks' null tolerance deliberately: an absent slot conflicts
  /// with nothing, because a missing parameter is ResolvedSpell.isResolved's
  /// problem rather than this rule's. RangeSelected and TargetSelected keep
  /// their own inline logic -- they do not merely detect a conflict, they
  /// resolve it asymmetrically (TargetSelected forces the required Range and
  /// lets that win over the forbidding direction; RangeSelected clears the
  /// Target), so only this detecting half is common to all three call sites.
  static bool _rangeTargetConflict(Parameter? range, Parameter? target) {
    if (range == null || target == null) return false;
    final kind = target.targetType;
    if (kind != null && range.forbidsTargetTypes.contains(kind)) return true;
    final required = target.requiresRangeId;
    return required != null && range.id != required;
  }
```

- [ ] **Step 6: Reconcile the seeded pair**

In the same file, replace the body of `_seedParameters` from the `final target = seed(...)` line through the closing `);` of the `return draft.copyWith(...)` (around lines 745-753) with:

```dart
    var range = seed(draft.range, previousReference.rangeId, next.rangeId, 'Range');
    var target = seed(draft.target, previousReference.targetId, next.targetId, 'Target');

    // This helper is the third path that writes the Range/Target pair, after
    // RangeSelected and TargetSelected, and it is the one that did not prune.
    // Seeding one slot while a deliberate choice survives in the other can land
    // on exactly the combination checks 10 and 11 reject -- so a seed that would
    // contradict its peer is not written, and both slots keep their pre-adoption
    // values. That narrows "an untouched slot follows the new guideline"; it
    // carves no exception into "a deliberate choice survives a guideline switch".
    //
    // Reverting *both* slots is the same thing as reverting whichever slot the
    // seed moved, because an unmoved slot already holds its pre-adoption value.
    // That pair is always a legal landing place: the constructor seeds the
    // standard triple (Personal forbids only container, Individual is an object
    // Target naming no Range), and every other path that emits a pair prunes it.
    // See todo item 74.
    if (_rangeTargetConflict(range, target)) {
      range = draft.range;
      target = draft.target;
    }

    // Computed from the Target that actually lands, not the seed candidate.
    final keepsMode = _isContainer(target);

    return draft.copyWith(
      range: range,
      duration: seed(draft.duration, previousReference.durationId, next.durationId, 'Duration'),
      target: target,
      containerMode: keepsMode ? null : ContainerMode.unstated,
    );
```

Note `copyWith` uses an `_unset` sentinel (`lib/models/spell.dart:645-669`), so passing a slot's current value — null or not — is a genuine no-op and cannot accidentally clear a slot.

- [ ] **Step 7: Extend the `_seedParameters` doc comment**

In the same file, find the paragraph in `_seedParameters`'s doc comment that begins `/// A slot is re-seeded only when it is null, or when it still holds` (around line 690). Directly after that paragraph's closing sentence (`... rather than a blanket policy either way.`), insert:

```dart
  /// One exception to the per-slot evaluation, because Range and Target are not
  /// independent: if the seeded pair would violate check 10 or check 11, both
  /// slots keep their pre-adoption values rather than adopting. The seed is a
  /// convenience for untouched slots; it does not get to build a state the
  /// validator would refuse to save. See [_rangeTargetConflict] and todo item 74.
```

- [ ] **Step 8: Run the three tests to verify they pass**

```bash
flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "is not written"
```

Expected: **3 tests, all PASS.**

- [ ] **Step 9: Run the whole bloc suite for regressions**

```bash
flutter test test/bloc/spell_creation_bloc_test.dart
```

Expected: **all PASS.** These four neighbours were traced against the change and must not move — if any fails, the reconcile is firing where no conflict exists:
- `'a container mode survives a seed that lands on another container Target'` — lands on Touch + Room, which neither check forbids.
- `'changing Technique clears a container mode stranded by the Target re-seed'` — lands on Personal + Individual.
- `'selecting a ward guideline adopts its Touch/Ring/Circle reference…'` — lands on Touch + Circle.
- `'a deliberately chosen parameter survives a guideline switch'` — nothing seeds; lands on Voice + Room.

- [ ] **Step 10: Verify formatting and analysis**

```bash
git diff -w --stat
flutter analyze
```

Expected: `git diff -w --stat` shows real content changes (not whitespace-only churn), and `flutter analyze` exits 0 with **No issues found**. Do **not** run `dart format`.

- [ ] **Step 11: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -F - <<'MSG'
fix: adoption's seed yields to a conflicting Range/Target peer

_seedParameters was the third path that writes the Range/Target pair and
the only one that did not prune, so a guideline switch could seed
range-personal beside a deliberately chosen container Target -- the
combination check 10 exists to reject. Two further shapes were reachable:
a chosen Personal Range meeting a ward guideline's Circle, and a Sensory
Target whose Target-forced Personal Range the value comparison cannot tell
from an untouched slot.

The seed now reconciles: if the resulting pair violates check 10 or 11,
both slots keep their pre-adoption values. Duration is unaffected.

Closes item 74.1, 74.2, 74.3 and 74.5.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
```

---

### Task 2: A corpus guard on base effect reference triples

**Files:**
- Test: `test/data/published_spell_import_test.dart` (add after assertion 7, which ends around line 232)

**Interfaces:**
- Consumes: `AssetDataLoader.loadBaseEffects()`, `AssetDataLoader.loadParameters()` — both already used by assertion 7 in this file. `BaseEffect.reference` is a non-nullable `ParameterTriple` defaulting to `ParameterTriple.standard()`, with `rangeId` / `durationId` / `targetId` string fields.
- Produces: nothing consumed elsewhere.

**Why this task exists:** Task 1's revert lands on the pre-adoption pair, which is clean by induction — *unless* a base effect's own reference triple is self-contradictory, in which case both slots seed together into a conflict and reverting cannot help. That is a data invariant, not a bloc concern; the bloc silently repairing bad catalog data would hide the bug. All 612 rows pass today (599 with no explicit reference, 12 wards at Touch/Ring/Circle, 1 at Personal/Momentary/Vision), so this test is green on arrival and guards the next supplement.

- [ ] **Step 1: Write the assertion**

Add to `test/data/published_spell_import_test.dart`, immediately after the closing `});` of `'assertion 7: every published spell and template satisfies the catalog invariants'`:

```dart
  test('assertion 8: no base effect reference triple contradicts checks 10 and 11', () async {
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final failures = <String>[];

    // Checked directly rather than routed through validateSpellAgainstCatalog:
    // a reference triple is not a spell, and fabricating a plausible one per
    // effect would bury the only two checks that read the pair. The two
    // conditions below are checks 10 and 11 verbatim.
    //
    // This guards SpellCreationBloc._seedParameters (todo item 74). When the
    // seed adopts a guideline it can write both slots at once, and its revert
    // path assumes the pre-adoption pair was legal -- which holds for every
    // pair the bloc itself produces, but says nothing about a reference triple
    // authored into the catalog. A self-contradictory one is a data bug, and
    // must fail here rather than be silently repaired in the bloc.
    for (final effect in await loader.loadBaseEffects()) {
      final range = parameters[effect.reference.rangeId];
      final target = parameters[effect.reference.targetId];
      if (range == null || target == null) {
        failures.add('${effect.id}: reference names an unresolvable Range or Target');
        continue;
      }

      final kind = target.targetType;
      if (kind != null && range.forbidsTargetTypes.contains(kind)) {
        failures.add(
            '${effect.id}: ${range.name} Range with ${target.name}, a ${kind.name} Target');
      }

      final required = target.requiresRangeId;
      if (required != null && range.id != required) {
        failures.add(
            '${effect.id}: ${target.name} requires "$required", '
            'but the reference names ${range.id}');
      }
    }

    expect(failures, isEmpty,
        reason: 'base effect reference triples the seed could not safely adopt:\n'
            '${failures.join('\n')}');
  });
```

- [ ] **Step 2: Run it and confirm it passes against the real catalog**

```bash
flutter test test/data/published_spell_import_test.dart --plain-name "assertion 8"
```

Expected: **1 test, PASS.** Unlike Task 1's tests this one is green immediately — it pins a property the catalog already has. If it fails, do not weaken the test: the named base effect row is genuinely contradictory and is a real finding to report.

- [ ] **Step 3: Prove the assertion can actually fail**

Temporarily change the ward reference in `assets/data/base_effects.json` for one row — find the first entry whose `reference` names `"targetId": "target-circle"` and change its `"rangeId"` from `"range-touch"` to `"range-personal"`. Re-run:

```bash
flutter test test/data/published_spell_import_test.dart --plain-name "assertion 8"
```

Expected: **FAIL**, naming that effect id with `Personal Range with Circle, a container Target`.

Then revert the asset and confirm it is clean:

```bash
git checkout -- assets/data/base_effects.json
git status --short assets/data/base_effects.json
```

Expected: `git status --short` prints nothing.

- [ ] **Step 4: Run the full import suite and analyze**

```bash
flutter test test/data/published_spell_import_test.dart
flutter analyze
```

Expected: all tests PASS, `flutter analyze` exits 0 with **No issues found**.

- [ ] **Step 5: Commit**

```bash
git add test/data/published_spell_import_test.dart
git commit -F - <<'MSG'
test: assertion 8 — no base effect reference triple self-contradicts

The seed's revert path assumes the pre-adoption Range/Target pair was
legal. That holds for every pair the bloc produces, but says nothing
about a reference triple authored into the catalog: a self-contradictory
one would seed both slots into a conflict at once, where reverting cannot
help. Guarded as a data invariant rather than repaired in the bloc.

All 612 rows pass today. Not one of item 74's sub-items -- a guard the
design added once shape B showed the seed can move both slots at once.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
```

---

### Task 3: Full verification, then close item 74

**Files:**
- Modify: `.superpowers/DECISIONS.md` (the **Bloc and state** section)
- Modify: `.superpowers/todo.md` (row 74 in the index table, and the `**Now:**` line)
- Modify: `.superpowers/themes/model.md` (remove item 74's body, around lines 193-235)
- Modify: `.superpowers/ARCHIVE.md` (add item 74's body)
- Modify: `.superpowers/STATUS.md` (Dart suite count)

**Interfaces:**
- Consumes: the merged result of Tasks 1 and 2.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Run all three suites**

```bash
flutter test
python -m unittest discover -s scripts/spell_import/tests -t .
flutter test integration_test -d windows
```

Expected: Dart **745 tests** green (742 before, plus shapes B and C and assertion 8 — shape A was rewritten, not added), Python **378** green, integration **8** green. Record the actual Dart figure; if it is not 745, reconcile the difference before continuing rather than editing STATUS.md to match.

- [ ] **Step 2: Amend the standing constraint in DECISIONS.md**

In `.superpowers/DECISIONS.md`, under **Bloc and state**, find the entry beginning `**A parameter slot is re-seeded only when it is null or still holds the *outgoing* guideline's reference value**`. Replace its final parenthetical sentence — `(Item 74 records the one path this does not yet reconcile with the Range/Target checks.)` — so the entry ends:

```markdown
There is no "touched" flag; it is a value comparison against data already in
hand.  *(items 60, 74)*

**One exception to the per-slot evaluation: a seed that would contradict its
peer is not written.** Range and Target are not independent, so if the seeded
pair violates check 10 or check 11, *both* slots keep their pre-adoption values.
Reverting both is identical to reverting whichever slot moved, and the
pre-adoption pair is always legal — the constructor seeds the standard triple
and every other path that emits a pair prunes it. This narrows "an untouched
slot follows the new guideline"; it carves no exception into "a deliberate
choice survives a guideline switch". A self-contradictory reference triple is
the one case reverting cannot fix, and is guarded by assertion 8 rather than
repaired in the bloc.  *(item 74)*
```

- [ ] **Step 3: Update STATUS.md**

In `.superpowers/STATUS.md`, change the Dart suite row from `**742 tests, green**` to the figure recorded in Step 1, and update the date on the `**Suite status:**` line to 2026-08-19.

- [ ] **Step 4: Close the item**

Use the `closing-an-item` skill for item 74. It extracts any still-binding constraints before the body is archived — Step 2 has already written the main one, so confirm the skill finds nothing further rather than assuming it will. The skill moves item 74's body from `.superpowers/themes/model.md` to `.superpowers/ARCHIVE.md`, flips its row in `.superpowers/todo.md` to `| 74 | — | closed | ARCHIVE.md | ... |`, and drops 74 from the `**Now:**` line.

- [ ] **Step 5: Commit**

```bash
git add .superpowers/
git commit -F - <<'MSG'
todo: close item 74 — adoption's seed yields to a conflicting peer

Distils the standing constraint into DECISIONS.md and archives the body.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
```
