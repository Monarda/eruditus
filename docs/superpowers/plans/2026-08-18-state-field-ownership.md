# State Field Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the last two `SpellCreationState` fields under the `_emit` funnel, so every field of the state follows a written rule and none is hand-maintained across handlers.

**Architecture:** `SpellCreationBloc._emit` is the single funnel every emit in the bloc passes through; it already recomputes the level from the draft and invalidates stale suggestion/validation state. Two fields sit outside it. `generalEffectSentence` becomes a third funnel-computed field alongside `breakdown` and `levelUnavailableReason`, deleting five hand-maintained handler call sites. `savedSpell` adopts `errorMessage`'s one-shot rule: `copyWith` stops carrying it forward and `_emit` re-passes it.

**Tech Stack:** Dart / Flutter, `flutter_bloc`, `bloc_test`, `equatable`.

**Spec:** `docs/superpowers/specs/2026-08-18-state-field-ownership-design.md`
**Todo item:** 62.

## Global Constraints

- **Never run `dart format` in this repo.** Formatting is hand-maintained and the
  formatter is not clean here. Indent by hand and check your diff with
  `git diff -w` to confirm you changed only what you meant to.
- **`flutter analyze` must exit 0.** Run it before every commit.
- **Full suite command:** `flutter test`. It must stay green (662 tests at the
  time of writing).
- If `flutter test` reports a **sqlite3.dll permissions error**, that is stale
  `flutter_tester.exe` processes holding the DLL, not a real permissions
  problem. Kill them and re-run: `taskkill /F /IM flutter_tester.exe`
- Comments in this codebase carry reasoning, not restatement. Every comment you
  edit below is given in full — write it as given rather than paraphrasing.
- Task 1 is **behaviour-preserving**. Its test is a characterization test and
  passes both before and after the refactor. Do not fake a red step for it; the
  plan says exactly when to expect green.
- Task 2 is the **only** behaviour change in this plan, and its test does go red
  first.

---

## File Structure

No files are created. Four are modified:

- `lib/bloc/spell_creation/spell_creation_bloc.dart` — `_emit`'s doc comment and
  its `copyWith`; five handler call sites deleted; one stale comment in
  `TemplateInstantiated` corrected.
- `lib/bloc/spell_creation/spell_creation_state.dart` — `copyWith`'s
  `savedSpell` line and two comments; a doc comment on the `savedSpell` field.
- `test/bloc/spell_creation_bloc_test.dart` — two tests added.
- `.superpowers/todo.md` — item 62 closed.

---

### Task 1: `generalEffectSentence` becomes funnel-computed

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart` (doc comment at
  `:82-88`; `copyWith` at `:105-107`; call sites at `:232`, `:255`, `:295`,
  `:302`, `:518`; comment at `:510-513`)
- Modify: `lib/bloc/spell_creation/spell_creation_state.dart` (comment at
  `:120-126`)
- Test: `test/bloc/spell_creation_bloc_test.dart` (add to the
  `General guideline level (ChosenBaseLevelChanged / generalEffectSentence)`
  group, which starts at `:1775`)

**Interfaces:**
- Consumes: `String? _generalEffectSentenceFor(SpellDraft draft)` — already
  exists at `spell_creation_bloc.dart:534`, unchanged by this task.
- Produces: nothing new. After this task `_emit` writes `generalEffectSentence`
  on every pass and no handler passes it.

- [ ] **Step 1: Write the characterization test**

Add this as the last test inside the existing
`group('General guideline level (ChosenBaseLevelChanged / generalEffectSentence)', ...)`
in `test/bloc/spell_creation_bloc_test.dart` — after the
`'generalEffectSentence goes back to null after a non-General effect is selected'`
test (ends `:1912`) and before the group's closing `});`. It uses `wardGuideline`,
declared at the top of that group, and `rangeParam`, a top-level fixture in the
file.

```dart
    blocTest<SpellCreationBloc, SpellCreationState>(
      'generalEffectSentence survives an edit that moves neither of its inputs',
      // The funnel recomputes it on every emit now, rather than copyWith
      // carrying it forward, so every event is a fresh chance to get it wrong
      // -- including the great majority that touch neither the base effect nor
      // the chosen level. RangeSelected stands for all of them.
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(wardGuideline))
        ..add(const ChosenBaseLevelChanged(20))
        ..add(RangeSelected(rangeParam)),
      verify: (bloc) => expect(bloc.state.generalEffectSentence, contains('20')),
    );
```

- [ ] **Step 2: Run it and confirm it passes**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "survives an edit that moves neither of its inputs"`

Expected: **PASS.**

This is deliberate and is not a broken TDD cycle. The behaviour is already
correct — today `copyWith` carries the sentence forward across `RangeSelected`.
The test exists to pin that behaviour *before* the mechanism changes underneath
it, so that if the funnel recomputes wrongly in Step 4 this test is what catches
it. If it fails here, stop: something is wrong with the fixtures, not with the
refactor you have not done yet.

- [ ] **Step 3: Commit the test on its own**

```bash
git add test/bloc/spell_creation_bloc_test.dart
git commit -m "test: pin generalEffectSentence across a level-neutral edit"
```

Committing it separately is what makes it a characterization test rather than a
test written to fit the implementation: the next commit changes the mechanism
with this assertion already standing.

- [ ] **Step 4: Move the recomputation into the funnel**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, add one line to `_emit`'s
`emit(next.copyWith(...))`, immediately after `levelUnavailableReason`:

```dart
      breakdown: preview.breakdown,
      levelUnavailableReason: preview.unavailableReason,
      // The third field computed here, and the newest. Like the level it is a
      // pure function of the draft -- SpellEngine.deriveGeneralEffect reads
      // baseEffect.effectFormula and chosenBaseLevel and consults no catalog,
      // so there is no sync event that can move it without the draft moving --
      // and like the level, no handler should have to remember it and none can
      // forget. It was recomputed at five handler call sites until todo item
      // 62. All five were correct, which is exactly why the sixth was the risk.
      generalEffectSentence: _generalEffectSentenceFor(next.draft),
```

- [ ] **Step 5: Delete the five handler call sites**

Delete the line `generalEffectSentence: _generalEffectSentenceFor(draft),` from
each of these five handlers. Each currently reads:

```dart
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
        generalEffectSentence: _generalEffectSentenceFor(draft),
      ));
```

and must become:

```dart
      _emit(emit, state.copyWith(
        status: SpellCreationStatus.editing,
        draft: draft,
      ));
```

The five, by event, at their pre-edit line numbers (these shift as you delete, so
work bottom-up or search for the text): `TechniqueSelected` `:232`,
`FormSelected` `:255`, `BaseEffectSelected` `:295`, `ChosenBaseLevelChanged`
`:302`, `TemplateInstantiated` `:518`. The fifth differs slightly — it is
`SpellCreationState.initial().copyWith(`, not `state.copyWith(` — but the line to
delete is identical.

Verify you got all five and no more:

```bash
grep -n "generalEffectSentence\|_generalEffectSentenceFor" lib/bloc/spell_creation/spell_creation_bloc.dart
```

Expected afterwards: exactly four hits — the doc-comment mention you are about to
rewrite (in the `:82-88` region), the new `_emit` line, and the
`_generalEffectSentenceFor` declaration with its own doc comment.

- [ ] **Step 6: Rewrite `_emit`'s doc comment to state all three rules**

The comment currently ends by naming `generalEffectSentence` as the exception.
That pointer is what this task removes. In
`lib/bloc/spell_creation/spell_creation_bloc.dart`, replace this passage
(`:82-88`):

```dart
  /// It is also this state's invalidation point: it clears
  /// [SpellCreationState.validationErrors] whenever the draft moves, and the
  /// three suggestion fields whenever the *level* moves. Those are two
  /// different predicates on purpose -- see the two comments below. (One field
  /// it deliberately does not own is `generalEffectSentence`, still recomputed
  /// at its handlers' call sites; see todo item 62.)
```

with:

```dart
  /// It is also this state's invalidation point: it clears
  /// [SpellCreationState.validationErrors] whenever the draft moves, and the
  /// three suggestion fields whenever the *level* moves. Those are two
  /// different predicates on purpose -- see the two comments below.
  ///
  /// Between them, this funnel and [SpellCreationState.copyWith] leave every
  /// field of the state under exactly one of three rules, with none of them
  /// hand-maintained across handlers (todo item 62):
  ///
  ///   * **Computed here, from the draft** -- `breakdown`,
  ///     `levelUnavailableReason`, `generalEffectSentence`. Pure functions of
  ///     `next.draft`, recomputed unconditionally on every pass. A handler
  ///     never passes one, and passing one would be overwritten.
  ///   * **Invalidated here** -- `validationErrors` on `draftChanged`, the
  ///     three suggestion fields on `breakdownChanged`. Cleared by predicate,
  ///     never populated here; only the handler that computes them fills them.
  ///   * **One-shot payloads** -- `errorMessage`. copyWith does not carry it
  ///     forward, so it is readable only in the emit that writes it, which is
  ///     why it is re-passed below.
  ///
  /// A new field belongs to one of the three. A new *handler* need do nothing
  /// about any of them.
```

Note the third bullet lists only `errorMessage` for now. Task 2 adds
`savedSpell` to it; leaving it out here keeps this commit honest about what is
true after this commit.

- [ ] **Step 7: Correct the now-stale comment in `TemplateInstantiated`**

The comment above that handler's emit says the funnel overwrites *both* level
halves. It now overwrites three fields, and this handler just stopped passing
the third. In `lib/bloc/spell_creation/spell_creation_bloc.dart` (`:510-513`),
replace:

```dart
      // From SpellCreationState.initial(), not state.copyWith(...): stale
      // suggestions left over from whatever the user was doing before must not
      // follow them into the new spell. The level halves are not carried over
      // either, but they need no clearing here: the funnel overwrites both
      // from this draft on the way out.
```

with:

```dart
      // From SpellCreationState.initial(), not state.copyWith(...): stale
      // suggestions left over from whatever the user was doing before must not
      // follow them into the new spell. The level halves and the general-effect
      // sentence are not carried over either, but they need no clearing here:
      // the funnel computes all three from this draft on the way out.
```

- [ ] **Step 8: Correct the `_unset` rationale on the state field**

`SpellCreationState.copyWith`'s comment justifies the sentinel by saying only
four handlers recompute the field. No handler does now. In
`lib/bloc/spell_creation/spell_creation_state.dart` (`:120-126`), replace:

```dart
      // Unlike errorMessage, generalEffectSentence must be *clearable*
      // without being wiped on every emit: only the four handlers that can
      // change baseEffect or chosenBaseLevel ever recompute it, and every
      // other emit needs to carry the existing value forward untouched. A
      // plain `?? this.generalEffectSentence` can't tell "omitted" from
      // "explicitly cleared to null" apart, so this uses the same
      // `_unset`-sentinel trick as SpellDraft.copyWith.
```

with:

```dart
      // Unlike errorMessage, generalEffectSentence must be *clearable* rather
      // than merely droppable, for the same reason breakdown above is: the
      // emit funnel writes it on every pass, from the draft, and "this draft
      // has no sentence" is a real answer it has to be able to give. A plain
      // `?? this.generalEffectSentence` cannot tell "omitted" from "explicitly
      // cleared to null" apart, and would strand a General guideline's
      // strength on screen after the guideline itself had been replaced. Same
      // `_unset`-sentinel trick as SpellDraft.copyWith.
```

- [ ] **Step 9: Run the tests and the analyzer**

```bash
flutter test test/bloc/spell_creation_bloc_test.dart
flutter analyze
```

Expected: all bloc tests PASS (including the four `generalEffectSentence` tests —
the three that existed plus the one from Step 1), analyzer exits 0 with no new
warnings. Nothing in the suite should need editing; if a test now fails, the
refactor changed behaviour and you should stop and work out why rather than
adjust the test.

- [ ] **Step 10: Check the diff and commit**

```bash
git diff -w --stat
git add lib/bloc/spell_creation/spell_creation_bloc.dart lib/bloc/spell_creation/spell_creation_state.dart
git commit -m "refactor: the emit funnel owns generalEffectSentence"
```

Use a body that says what the commit does *not* do, since a reviewer will look
for the bug and there isn't one:

```
The sentence is f(draft) exactly as the level is -- deriveGeneralEffect
reads baseEffect.effectFormula and chosenBaseLevel and no catalog -- so
it moves into _emit alongside the level, and five handlers stop passing
it.

Behaviour-preserving: all 25 handlers were checked. The three that build
from initial() emit over a draft with no baseEffect, where the funnel
computes the null they already emitted; the save-failure emit moves only
summary. The value is structural. It makes the sixth handler impossible
to get wrong, and _emit's doc comment true rather than nearly true.
```

---

### Task 2: `savedSpell` becomes a one-shot payload

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_state.dart` (field at `:47`;
  `copyWith` at `:111`)
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart` (`_emit`'s
  `copyWith`, at the `errorMessage` line; the doc-comment bullet from Task 1
  Step 6)
- Test: `test/bloc/spell_creation_bloc_test.dart` (add after the
  `'SpellSaveRequested saves the spell and emits saving then saved'` test, which
  ends at `:540`)

**Interfaces:**
- Consumes: nothing from Task 1. The two tasks touch adjacent lines but are
  independent; Task 1's doc-comment bullet is amended here, so do Task 1 first
  or expect a trivial merge.
- Produces: after this task, `SpellCreationState.savedSpell` is non-null only in
  a state emitted by the save-success branch of `_handleSpellSaveRequested`.

- [ ] **Step 1: Write the failing test**

Add to `test/bloc/spell_creation_bloc_test.dart`, immediately after the
`'SpellSaveRequested saves the spell and emits saving then saved'` test. All
fixtures used (`creoIgnemEffect`, `rangeParam`, `durationParam`, `targetParam`)
are the same top-level ones that test uses.

```dart
  blocTest<SpellCreationBloc, SpellCreationState>(
    'savedSpell does not outlive the save it describes',
    // It is the payload of `status: saved`, exactly as errorMessage is the
    // payload of `status: error`: meaningful in the emit that writes it, stale
    // in every emit after. The snack bar reads it from a listener gated on that
    // status; nothing else may find it still sitting there one edit later.
    //
    // The follow-up event is added without waiting, which is safe and is half
    // the point: the bloc processes events strictly in arrival order, so this
    // RangeSelected lands on the state the completed save emitted.
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('My Fireball', summary: 'A jet of flame.'));
      bloc.add(RangeSelected(rangeParam));
    },
    wait: const Duration(milliseconds: 300),
    verify: (bloc) async {
      // That the save actually succeeded, so a save that merely failed cannot
      // pass this test by leaving savedSpell null for the wrong reason.
      final saved = await spellRepository.getAllUserSpells();
      expect(saved.length, 1);
      expect(bloc.state.status, SpellCreationStatus.editing);
      expect(bloc.state.savedSpell, isNull);
    },
  );
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "does not outlive the save it describes"`

Expected: **FAIL** on the last assertion — `Expected: null`, `Actual: Spell:<...My Fireball...>`.
The first two assertions pass; `copyWith` carries the spell forward across the
`RangeSelected`, which is the behaviour being changed.

- [ ] **Step 3: Stop carrying it forward in `copyWith`**

In `lib/bloc/spell_creation/spell_creation_state.dart`, replace the line
`savedSpell: savedSpell ?? this.savedSpell,` (`:111`) with:

```dart
      // The same rule as errorMessage below, for the same reason: a payload for
      // the status that carries it, not state. Not carried forward, so it is
      // readable only in the emit that writes it -- the save-success emit,
      // whose `status: saved` is what the snack bar's listener is gated on.
      // Carried forward, as it was until todo item 62, it survived every later
      // edit, calculate and failed save, and any read not gated on that status
      // got whatever had last been saved this session.
      savedSpell: savedSpell,
```

- [ ] **Step 4: Document the field**

In the same file, replace the bare field declaration at `:47`:

```dart
  final Spell? savedSpell;
```

with:

```dart
  /// The spell the save that produced this state wrote, and only that.
  ///
  /// Non-null exactly in the state the save-success branch emits, alongside
  /// `status: saved` — [copyWith] does not carry it forward, so the next emit
  /// of any kind drops it. Same rule as [errorMessage], and for the same
  /// reason: both are payloads for a status, not state that accumulates.
  final Spell? savedSpell;
```

- [ ] **Step 5: Re-pass it through the funnel**

`_emit` builds `next.copyWith(...)`, so a field `copyWith` no longer carries
forward is dropped by the funnel unless re-passed — the same trap the existing
`errorMessage` comment describes. That comment also claims errorMessage is the
only such field, which stops being true here.

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, replace this block inside
`_emit`'s `emit(next.copyWith(`:

```dart
      // Re-passed rather than omitted, and it is the only field that needs to
      // be. SpellCreationState.copyWith deliberately does *not* carry
      // errorMessage forward -- every emit clears a stale error unless the
      // handler re-states one -- and that rule is written for handler emits,
      // not for this pass-through. Omitted here, the copyWith that attaches the
      // level would silently swallow the message _handleSpellSaveRequested's
      // catch branch had just set, and a failed save would render an error
      // status with nothing to show for it. Every other field either carries
      // forward via `??` or through the `_unset` sentinel.
      errorMessage: next.errorMessage,
```

with:

```dart
      // The two one-shot payloads, re-passed rather than omitted, and the only
      // fields that need to be. SpellCreationState.copyWith deliberately
      // carries neither forward -- every emit clears a stale error, and a stale
      // saved spell, unless the handler re-states one -- and that rule is
      // written for handler emits, not for this pass-through. Omitted here, the
      // copyWith that attaches the level would silently swallow whichever one
      // _handleSpellSaveRequested had just set: its catch branch's message, so
      // a failed save renders an error status with nothing to show for it, or
      // its success branch's spell, so the snack bar names nothing. Every other
      // field either carries forward via `??` or through the `_unset` sentinel.
      errorMessage: next.errorMessage,
      savedSpell: next.savedSpell,
```

- [ ] **Step 6: Add `savedSpell` to the doc comment's third rule**

Task 1 Step 6 left the third bullet naming only `errorMessage`. In the same
file, in `_emit`'s doc comment, replace:

```dart
  ///   * **One-shot payloads** -- `errorMessage`. copyWith does not carry it
  ///     forward, so it is readable only in the emit that writes it, which is
  ///     why it is re-passed below.
```

with:

```dart
  ///   * **One-shot payloads** -- `errorMessage`, `savedSpell`. copyWith
  ///     carries neither forward, so each is readable only in the emit that
  ///     writes it, which is why both are re-passed below.
```

- [ ] **Step 7: Run the test and verify it passes**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart --plain-name "does not outlive the save it describes"`

Expected: PASS.

- [ ] **Step 8: Run the whole bloc suite and the analyzer**

```bash
flutter test test/bloc/spell_creation_bloc_test.dart
flutter analyze
```

Expected: all PASS, analyzer 0. Pay particular attention to
`spell_creation_bloc_test.dart:2606` (`expect(bloc.state.savedSpell, isNull)`
after a rejected save) and the `savedSpell?.name` / `savedSpell?.summary`
assertions around `:534-578` and `:783` — all of them assert on the state the
save itself emitted, so all should still pass untouched. If one fails, the funnel
is not re-passing the field; re-check Step 5.

- [ ] **Step 9: Check the diff and commit**

```bash
git diff -w --stat
git add lib/bloc/spell_creation/spell_creation_state.dart lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "fix: savedSpell does not outlive the save it describes"
```

Body:

```
It was the one state field with no invalidation rule of any kind: once a
save wrote one, copyWith's `??` carried it through every later edit,
calculate and failed save. Nothing reads it in that window today -- the
snack bar is gated on status == saved -- which is what made it safe to
fix now rather than a bug to fix later.

It takes errorMessage's rule, which it should always have had: a payload
for the status that carries it, dropped by copyWith and re-passed by the
funnel. Both one-shot fields now sit under one comment.
```

---

### Task 3: Close item 62

**Files:**
- Modify: `.superpowers/todo.md` (item 62 at `:860`; `## Completed ✅` section at
  `:903`; test count at `:47`)

**Interfaces:**
- Consumes: the two commits from Tasks 1 and 2.
- Produces: nothing consumed by later work.

- [ ] **Step 1: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: all tests PASS — 664 now, the 662 baseline plus this plan's two — and
analyzer 0. Record the actual number you see; you need it in Step 4. If the
sqlite3.dll error appears, see Global Constraints.

- [ ] **Step 2: Get the commit range**

```bash
git log --oneline -4
```

Note the two implementation commits' hashes. The range for the todo entry is
`<first-commit>..<last-commit>`, matching the form item 59 uses
(`99aa462..e6a61b4`).

- [ ] **Step 3: Move item 62 into `## Completed ✅`**

Delete the whole `### 62. Two SpellCreationState Fields the Emit Funnel Does Not
Own` block (`.superpowers/todo.md:860-901`, from the heading down to and
including its `**See also:**` line), and insert this at the top of the
`## Completed ✅` section — immediately after the "Closed items, reduced to the
decisions and constraints that still bind" paragraph and before
`### 59. The Spell Level Computes Live`, so the section stays newest-first:

```markdown
### 62. Every State Field Has an Owner (`<first-commit>..<last-commit>`)
`SpellCreationBloc._emit` claimed, in its own doc comment, to be where a moved
draft's stale halves are settled — while two fields sat outside it. Both are now
inside, and the doc comment names the rule every field of the state follows.

- **Three rules, and every field is under one of them.** Computed from the draft
  in the funnel (`breakdown`, `levelUnavailableReason`, `generalEffectSentence`);
  invalidated in the funnel by predicate (`validationErrors` on `draftChanged`,
  the three suggestion fields on `breakdownChanged`); or a one-shot payload that
  `copyWith` drops and the funnel re-passes (`errorMessage`, `savedSpell`). A new
  field picks one. A new handler does nothing for any of them — which was the
  whole point, since all five old `generalEffectSentence` call sites were correct
  and the exposure was only ever the sixth.
- **`generalEffectSentence` moved on the same argument as the level.**
  `SpellEngine.deriveGeneralEffect` reads `baseEffect.effectFormula` and
  `chosenBaseLevel` and consults no catalog, so it is `f(draft)` and there is no
  sync event that can move it without the draft moving. Behaviour-preserving, and
  recorded as such: the three handlers building from `initial()` emit over a
  draft with no base effect, where the funnel computes the null they already
  emitted.
- **`savedSpell` took `errorMessage`'s rule.** It was the one field with no rule
  at all — `savedSpell ?? this.savedSpell` carried it through every later edit,
  calculate and failed save. Its only reader is gated on `status == saved`, which
  is what made this a latent hazard to remove rather than a bug to fix. The
  behaviour change is deliberate and tested: the next edit after a save nulls it.
- **Spec:** `docs/superpowers/specs/2026-08-18-state-field-ownership-design.md`.
  **Plan:** `docs/superpowers/plans/2026-08-18-state-field-ownership.md`.
- **See also:** item 59 (the funnel this completes), item 58.
```

Replace `<first-commit>..<last-commit>` with the hashes from Step 2.

- [ ] **Step 4: Update the test count in the todo header**

`.superpowers/todo.md:47` reads:

```markdown
| Dart | `flutter test` | **662 tests, green** |
```

Change 662 to the count you recorded in Step 1.

- [ ] **Step 5: Check that item 62's other referrers still read correctly**

```bash
grep -rn "item 62" .superpowers/todo.md lib/ docs/
```

Expected: no hits in `lib/` — Task 1 Step 6 replaced the one `_emit` doc-comment
pointer to it, and Task 1 Step 4 and Task 2 Step 3 cite it as history rather than
as an open item, so those read as "until todo item 62" and need no change. Hits
in `docs/` (the spec and this plan) are fine. A hit in `.superpowers/todo.md`
outside the Completed entry you just wrote means an open item still points at 62
as open; fix that line to point at the closed entry.

- [ ] **Step 6: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close item 62 — every state field has an owner"
```

---

## Verification

After Task 3, the whole plan is verifiable in three commands:

```bash
flutter test
flutter analyze
grep -n "generalEffectSentence\|savedSpell" lib/bloc/spell_creation/spell_creation_bloc.dart
```

The last should show `generalEffectSentence` and `savedSpell` appearing in
`_emit` and its doc comment only, plus the `_generalEffectSentenceFor`
declaration — no handler mentions either field.
