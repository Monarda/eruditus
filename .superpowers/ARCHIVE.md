# Archive

### 72. Three Latent Defects the Second Book Exposed (`9b21925`, `757e9a8`)

**Found and fixed during item 65, 2026-08-18.** None was introduced by that
work; each had been sitting in the importer and only became reachable once a
second book was registered. Recorded separately from item 65 because none of
them is about parsing HoH:MC.

- **Bare `complexity` was a dead label.** It sat in
  `designline.MODIFIER_LABELS` with **no entry in `emit._MODIFIER_OPTIONS` for
  any Technique/Form combination**, so it tokenized and then always failed at
  emit — for every book, not just this one. No core-book design line prints
  it, which is why it never surfaced. A 54-book survey found **23 uses across
  9 books and 12 Technique/Form pairs, none of them Imaginem**, at magnitudes
  +1 (x16), +2 (x5), +3 and +5. Core Rules 12204 makes it general: "this
  normally adds magnitudes to the spell level to account for the complexity."
  It is now a wildcard-scoped modifier resolved by the design line's own
  magnitude, following `elaborate-effect`'s existing precedent for a
  storyguide judgement ladder. **Named "Effect complexity", not "Complexity",
  because the three Imaginem sensory-complexity modifiers are all already
  named "Complexity"** and the UI heads each modifier group by name — two
  groups with the same heading, one a checkbox list and one a dropdown, is
  unusable. Those three are a different, printed mechanic (core 14596) and
  were left alone. The rung labels are this project's wording, as
  `elaborate-effect`'s are; the rulebook prints no ladder for either.
- **`apply_container_modes` deadlocked against `migrate_ledger`.** Its
  stale-entry guard raises when `container_modes.json` names a spell the run
  did not produce. A widened ledger entry leaves its spell unresolved and so
  unproduced, tripping the guard — and `migrate_ledger.py`, the only tool that
  resolves a widening, calls `run()` and hit the identical crash. **The tool
  that fixes the condition could not run while the condition held.** The guard
  now applies only to an otherwise-clean run; the separate check that a
  recorded mode's Target really is a container still runs unconditionally.
  This partially overtakes item 57's bullet on the same function.
- **The per-book lock could permanently launder a moved source.** Once
  `source.lock` became a mapping, its drift branch still called
  `provenance.write(identities)` — writing *every* book's identity, including
  one whose markdown had moved and was never accepted. Scenario: a supplement
  moves in a way that leaves `spell_library.json` byte-identical, so the
  `SourceMoved` guard does not fire; meanwhile the core book's advisory counts
  drift, the drift branch fires, and the supplement's new sha256 is recorded
  as attested. The next run sees it as matching and no change report is ever
  written. Fixed by merging only the entries that actually matched over the
  loaded lock. The single-book predecessor could not do this, because a match
  guaranteed the one identity was unchanged.

- **See also:** items 65, 57, 27.


### 65. HoH:MC Spell Extraction — the Inline Block Parser (sub-project B) (`7ebd409..757e9a8`, merged `1a6783e`)
Sub-project B of three. Item 64 landed the catalog rows; this proved the
core-book importer generalises to a second book and a second block-anchoring
style.

- **`parse_inline` anchors on a bare `TeFo Level` line directly above the stat
  line**, landed behind a per-book registry (`sources.Book`, `blocks.PARSERS`)
  so `parse_de` stays untouched — it still imports the 325 core spells
  unchanged. `run()` now iterates every registered book and `source.lock` is
  keyed by book id instead of holding exactly one book.
- **14 of HoH:MC's 16 blocks became real spells**: 11 landed in
  `spell_library.json`, 3 as templates (2 extracted, 1 hand-authored) —
  leaving *Faerie Chains of the Familiar Slave* (already hand-authored under
  item 17) and *Perceive the Change* (an enchanted-device effect the app does
  not model) untouched, exactly as planned.
- **The static/dynamic container-mode checklist item is superseded — no
  container mode was recorded, and none should be.** The original plan called
  for recording `ContainerMode.dynamic` on the four Sound/Spectacle spells.
  Before that landed, `TargetType.sensorium` (item 68, closed alongside this)
  reclassified all five Sensory Targets as non-containers, so
  `spellOwesContainerMode` no longer asks about them and a stated mode would
  now fail `validateSpellAgainstCatalog` check 9. `container_modes.json` was
  not touched.
- **Diagnosed, not imported, against the three other inline-heavy books** —
  Covenants, *Houses of Hermes: Societates*, *Transforming Mythic Europe*.
  `--diagnose` cannot write; no spell from any of the three entered
  `spell_library.json`.

| Book | Blocks | With design line | Tokenized | Notes |
|---|---|---|---|---|
| Covenants | 0 | 0 | 0 | All 44 candidate stat lines sit one blank line below their `TeFo Level` anchor; `parse_inline`'s anchor check requires direct adjacency, so none anchor. |
| Houses of Hermes: Societates | 0 | 0 | 0 | Same failure mode: 50 of 59 stat lines have a blank-line-separated anchor; `parse_inline` finds none of them. |
| Transforming Mythic Europe | 38 | 37 | 23 | 11 of 14 design-line failures are free-prose modifiers outside the vocabulary (`+4 transport seven leagues`, `+1 unsupported surface`…); 2 embed full explanatory sentences in the parenthetical; 3 stat lines are malformed (missing comma before `D:`, all three in one template group). |

- **A low tokenize rate is a measurement, not a defect**: the 52-book corpus
  survey behind this item classified how blocks are *anchored* and never
  checked that an anchored block *parses* — this is the first time that rate
  has been observed. Nothing was fixed to improve these numbers. Full figures
  and failure breakdown: item 71 (opened alongside this).
- **Corpus survey backing this** is recorded in item 64's spec: 54 books,
  3107 stat lines, four anchor styles. The inline style is 664 of them, so it
  pays for far more than 14 spells. Product line does not predict format —
  HoH:*True Lineages* is 55/55 *heading* style.
- **Spec:** `docs/superpowers/specs/2026-08-18-hohmc-inline-parser-design.md`.
  **Plan:** `docs/superpowers/plans/2026-08-18-hohmc-inline-parser.md`.
- **See also:** items 64, 57, 66, 68 (closed alongside this), 71 (opened
  alongside this).


### 68. Do the Sensory Targets' `targetType` Values Misrepresent Their Container Mode? (`c60a03d..eb28b18`, merged `1a6783e`)
Opened from item 64's review as a deferred question, not a decision; item 65
needed an answer before it could touch the four Sound/Spectacle spells, which
is what forced this closed rather than left open.

- **The finding that opened it stands**: HoH:MC line 1002 states one
  behaviour for all five Sensory Targets — "targets need not be present at
  the casting of the spell, and are continuously acquired throughout the
  spell's duration" — with no per-spell choice offered. The question was
  whether `container`/`object` on `targetType` was the right encoding of
  that.
- **The answer: neither was.** `TargetType` gained a fourth value,
  `sensorium` — not a rulebook word, chosen deliberately to avoid implying
  membership in the Core Rules' stated "three types of target". All five
  Sensory Targets (`target-flavor`, `target-texture`, `target-scent`,
  `target-sound`, `target-spectacle`) are `sensorium`, not `container` or
  `object`. Core Rules 12086 ("Personal Range spells can never have a
  container Target") together with HoH:MC 1006 (every Sensory Magic spell's
  Range must be Personal) meant `container` was actually unavailable — it
  would have made the four Sound/Spectacle spells simultaneously required to
  be Personal and forbidden from being Personal.
- **So the question is answered, not merely closed: the Sensory Targets are
  not containers, and no container mode is owed.** `spellOwesContainerMode`
  does not ask about them; item 65's own container-mode checklist bullet is
  superseded on this basis, not abandoned.
- **Landed in two steps**: the first pass reclassified only Sound and
  Spectacle (the two item 64 had made `container`); a follow-up fix applied
  the same argument to Flavor, Texture and Scent, which had been left
  `object` — also wrong, since `object` is documented as "always static"
  (12246/12254) and the book says otherwise for all five, not just two.
  Magnitudes were untouched throughout: the book's equivalence sentences
  price these Targets, they do not classify them.
- **See also:** items 64 (which added the rows), 65 (which needed this before
  touching the four spells), 14 and 57 (the container-mode feature and its
  ruling backlog, neither of which these five Targets participate in now).


### 64. HoH:MC Catalog Rows and the Intellego Exclusion (`2983b57..497ea1f`)
Sub-project A of three. The five Sensory Magic Targets and two Glamour
guidelines *Houses of Hermes: Mystery Cults* needs, plus the one rulebook
restriction on them the model can express.

- **`ParameterScope` gained a negative Technique axis**, mirroring
  `ModifierScope.excludeTechniques`, on the evidence its own doc comment asked
  for. Positive Forms list, negative Technique list, because that is how each
  rule is written: Fire is offered *for* Ignem and Imaginem; a Sensory Target is
  offered for everything *except* Intellego.
- **The Target magnitudes are given only by equivalence in the book**, so each
  was reconciled against a printed design line before being written down —
  Flavor 0, Texture 1, Scent 2, Sound 3, Spectacle 4.
- **`targetType` follows the printed equivalences, not the core `sense` ladder**,
  which matches sense-for-sense and magnitude-for-magnitude but means the
  opposite thing. HoH:MC forbids Intellego precisely because granting senses is
  the other feature.
- **Taking the exclusion forced two more changes**, neither optional:
  `TechniqueSelected` had never pruned, because no parameter had ever been
  Technique-scoped. **Item 58's `containerMode` bullet turned out to be stale,
  not latent** — `_seedParameters` has cleared a stranded mode since `8143c8e`,
  and every caller of the pruning helper seeds after it. Recorded rather than
  "fixed": the second axis is what prompted the check, and the check found
  nothing to repair.
- **Spec:** `docs/superpowers/specs/2026-08-18-hohmc-catalog-rows-design.md`.
  **Plan:** `docs/superpowers/plans/2026-08-18-hohmc-catalog-rows.md`.
- **See also:** items 17 (the precedent), 55 (book-aware oracles), 58 (bullet
  closed), 65, 66, 67.


### 62. Every State Field Has an Owner (`940c8bc..e7774cd`)
`SpellCreationBloc._emit` claimed, in its own doc comment, to be where a moved
draft's stale halves are settled — while two fields sat outside it. Both are now
inside, and the doc comment names the rule every field of the state follows.

- **Three rules, and every *derived* field is under one of them** — `status` and
  `draft` sit outside all three, as the funnel's inputs rather than its output.
  Computed from the draft in the funnel (`breakdown`, `levelUnavailableReason`,
  `generalEffectSentence`); invalidated in the funnel by predicate
  (`validationErrors` on `draftChanged`, the three suggestion fields on
  `breakdownChanged`); or a one-shot payload that `copyWith` drops and the
  funnel re-passes (`errorMessage`, `savedSpell`). A new field picks one. A new
  handler does nothing for any of them — which was the whole point, since all
  five old `generalEffectSentence` call sites were correct and the exposure was
  only ever the sixth.
- **`generalEffectSentence` moved on the same argument as the level.**
  `SpellEngine.deriveGeneralEffect` reads `baseEffect.effectFormula` and
  `chosenBaseLevel` and consults no catalog, so it is `f(draft)` and there is no
  sync event that can move it without the draft moving. Behaviour-preserving in
  two different ways, which is worth stating because only one of them is the
  obvious one. `SpellDiscarded` and the save-success emit build from
  `_emptySeededDraft()`, whose draft has no base effect, so the funnel computes
  the null they already emitted. `TemplateInstantiated` is the opposite case: its
  draft always *has* a base effect — `isResolved` requires one and the handler
  early-returns without it — and it was one of the five explicit call sites, so
  the funnel recomputes exactly the sentence that call site used to pass.
- **`savedSpell` took `errorMessage`'s rule.** It was the one field with no rule
  at all — `savedSpell ?? this.savedSpell` carried it through every later edit,
  calculate and failed save. Its only reader is gated on `status == saved`, which
  is what made this a latent hazard to remove rather than a bug to fix. The
  behaviour change is deliberate and tested: the next edit after a save nulls it.
- **Spec:** `docs/superpowers/specs/2026-08-18-state-field-ownership-design.md`.
  **Plan:** `docs/superpowers/plans/2026-08-18-state-field-ownership.md`.
- **See also:** item 59 (the funnel this completes), item 58.


### 59. The Spell Level Computes Live (`99aa462..e6a61b4`)
The level existed only after pressing **Calculate & View Suggestions**, and
every later edit emitted `status: editing`, which hid it again — so the number
a caster designs towards was absent exactly while they were designing. One
button gated three unrelated things; they are now separated.

- **Every emit in `SpellCreationBloc` goes through one `_emit` funnel** that
  attaches `SpellEngine.previewLevel(draft)`. No handler can emit a state whose
  breakdown disagrees with its own draft, which is why this closed item 58's
  first bullet as a consequence rather than a patch — a level no edit can hide
  cannot be hidden by `ContainerModeSelected` or `SummaryChanged` either.
- **The funnel also became the state's invalidation point** — the branch's most
  consequential emergent decision, and the one a future handler most needs to
  know about. Three things beyond the level are settled there, on three
  different rules, because they answer to three different things: `errorMessage`
  is *re-passed* (copyWith deliberately drops it every emit, a rule written for
  handler emits, not for a pass-through that would otherwise swallow a failed
  save's message); `validationErrors` clear when the **draft** moves, because
  they are statements about the draft's contents; and `suggestions`,
  `suggestionLevels` and `ritualSuggestionIds` clear when the **level** moves,
  because a suggestion asserts "similar to level N" and only N can falsify it.
  The last was keyed to the draft at first and was wrong both ways — a catalog
  sync moves the level with the draft untouched, which is exactly why those two
  branches re-emit at all. Keep the two predicates distinct; anything added to
  the state needs its own answer to which it belongs to.
- **`previewLevel` is not validation, deliberately.** It answers "is there a
  number", returning either a breakdown or one of five reasons; both of
  `calculateBreakdown`'s reachable throws (a General guideline before its level
  is typed, a level below 1) become reasons rather than escaping. The below-1
  throw gets two of the five: a General guideline typed at 0 has no magnitudes
  to blame and must not borrow the magnitudes wording.
  `validateSpellDraft` still owns the catalog invariants and still fires only on
  the two button presses, because its messages render as red text and firing
  them per keystroke would flag a half-built draft as broken.
- **`LevelBreakdown`, `LevelContribution` and `RitualStatus` gained value
  equality.** The funnel mints a new breakdown per emit and `breakdown` is in
  `SpellCreationState.props`, so identity comparison would make every state look
  changed. Two bloc tests that asserted `same(...)` now assert equality.
- **The button became "Find Similar Spells"** and gates only the suggestions —
  `findSimilarSpells` plus a `calculateBreakdown` per candidate is the half
  expensive enough to deserve one.
- **Save and Discard render unconditionally.** Discard was previously
  unreachable before the first Calculate, leaving no way to abandon a draft at
  all. Save is disabled while there is no level, and
  `_handleSpellSaveRequested` validates first — the affordance is not the gate.
- **`LevelBreakdownCard` became `LevelBanner`**, pinned above the scroll in a
  `Column` (above the ListView, so the keyboard cannot cover it), collapsed by
  default, showing an em dash plus a reason when there is no level. Its expanded
  detail is capped at 40% of the **body**, measured by a `LayoutBuilder` on the
  screen and handed down — a `Column` gives its non-flex children an unbounded
  main axis, so the banner cannot measure that itself, and 40% of
  `MediaQuery.size` overflows a short or keyboard-inset viewport.


### 60. Drafts Seed From Their Guideline's Reference Triple (`657c491`)
`SpellDraft` left Range/Duration/Target null, so every empty draft showed
three blank dropdowns — and a ward guideline priced against Touch/Ring/Circle
started three magnitudes *below* its own zero point, since
`_parameterContribution` charges each parameter as a delta from the reference.
One private static `_seedParameters` now re-seeds all three, called from the
initial state, `SpellDiscarded`, the post-save reset, `BaseEffectSelected`,
`TechniqueSelected` and `FormSelected`.

- **A slot is re-seeded only when it is null or still holds the *outgoing*
  guideline's reference value** — the decided answer to the item's one open
  question. A deliberately chosen parameter survives a guideline switch;
  evaluated per slot, so a chosen Target stays while an untouched Range and
  Duration follow. No "touched" flag: it is a value comparison against data
  already in hand.
- **No is-this-explicit predicate, deliberately.** `BaseEffect.reference`
  already defaults to `ParameterTriple.standard()` in both the constructor and
  the JSON factory, so "explicit reference, else standard" and "always
  `reference`" are the same rule. Item 38's worry that the model cannot tell
  an authored Personal/Momentary/Individual from an unauthored one is real and
  irrelevant here, because both readings seed identically.
- **13 of 611 entries carry an explicit `reference`** — 12 wards at
  Touch/Ring/Circle, `inim-G` at Personal/Momentary/Vision. The other 598 seed
  to standard, which is why the wards are the only place it is observable.
- **`containerMode` is pruned inside the seed, not at each call site**, because
  every handler that can re-seed a Target can strand a mode. Computed from the
  resulting Target, which is a no-op when nothing moved.
- **`TemplateInstantiated` is never seeded.** A template's parameters are
  published catalog data about that specific effect.
- **Also closed item 38's first bullet**, as a hard prerequisite: `main.dart`
  built `SpellEngine` with no parameters and the only filler was a
  `listenWhen` listener that fires on *change*, so the catalog could stay empty
  for the life of the app and no seed id would resolve.
- **`FormSelected` now refills a `duration-fire` its own prune nulled** — the
  same blank dropdown, reached by a different door. The one Form-scoped
  parameter in the catalog.


### 61. Clearable Single-Select Modifiers (`337adb4`)
A single-select modifier's dropdown offered its own options and nothing else,
and `onChanged` ignored null, so selection was one-way. Fixed by a null-valued
**"None"** entry; `DropdownButtonFormField`'s generic is `ModifierOption?` to
carry it. **Widget-only** — `ModifierOptionDeselected` already dropped the map
key when the last option went, so the bloc needed no change.

- **The clearing branch deselects *every* selected id, not just the first.**
  `_buildSingle`'s `value` already tolerates a stored selection carrying more
  than one option by showing nothing; clearing has to tolerate it identically,
  or the surplus survives with the field reading None and no way left to reach
  it. Do not "simplify" that loop to `selectedIds.first`.
- **An unselected single-select modifier now reads "None" rather than blank**,
  for all 31 of them — a deliberate side effect, making the empty state
  explicit instead of looking unset-because-unloaded.
- **Why it mattered more than a mis-click:** `no-gestures` and `no-words` are
  scoped to no Technique or Form, so they appear on every draft, costing +1 or
  +2 magnitudes permanently. With Discard rendering only inside the results
  block, the only escape was to calculate a spell you no longer wanted to reach
  the button that discarded it. **That second half is still true and is item
  59's**, which this fix does not touch.


### 1. Spell Constraint: One of Each Parameter (`2d897db`)
Exactly one Range, one Duration, one Target. **Ars Magica rule: modifiers scale the
level instead.** Three dedicated dropdowns; `SpellCreationBloc` enforces
one-per-category; `validateSpellDraft` requires all three. *Mists of Change* is the
one published spell that contradicts this — recorded as an exception spell rather
than weakening the model (item 46).


### 2. Requisites UI & Integration
One `Requisite(art, kind)` with `RequisiteKind` (`free` = 0 magnitude, `adding` = 1).
Validation: a requisite art cannot be the spell's own Technique or Form. **Duplicates
are unrepresentable by construction** since item 40 reshaped the field into a map
keyed by art. **The free/adding split is confirmed sufficient** — every
requisite-driven magnitude in the 360 published spells is +0 or +1.


### 3. Size Feature (MVP)
**There is no bespoke `size` field on `Spell`** — Size is modelled as ordinary scoped
Modifiers through the existing `selectedModifiers` map, so magnitude feeds the level
through the normal path with **no special case in the calculator**. Nine `size-<form>`
ladders, each Form-scoped and excluding Intellego (item 50 is the one printed
exception). The Aquam sub-type gap was closed as documented, not fixed — see *Notes*.


### 4. Resolve Out-of-Scope Base Effects — partially complete
Four sub-items done, two were never gaps, the rest split out. What binds:
- **`RitualRequirement` (`none`/`suggested`/`required`) landed as derivation, not
  validation** — nothing is rejected, because a Year-duration spell is not an error,
  it *is* a Ritual. **Ritual is a spell *type*, orthogonal to all eight Durations.**
- Complexity modifiers (`crim`/`peim`/`reim-complexity`), material scaling
  (`muto`/`perdo`/`rego-terram-material` — **Creo Terram deliberately has none,
  material *is* the base effect there**), and the `rego-transport-distance` ladder.
- **Characteristic Point Scaling was not a gap** — each rung is already its own base
  effect; what looked like a modelling gap was an extraction gap (item 22).
- **The original "~200 flagged effects" figure was wrong and should not be quoted.**
- Conditional wards remain open as item 4 in section C.
- **Spec:** `docs/superpowers/specs/2026-07-25-spell-modifiers-design.md`


### 5. Asset Data Loader Test Failures
Fixed 19 built-in spells referencing base-effect ids not in the catalog (no level
changes). **The lasting fix is that counts are derived, not hardcoded** — the loader
test derives its expected count from the raw JSON, an oracle independent of the
loader. A hardcoded count is exactly what silently drifted by 566 entries.


### 6. Widget-Test Coverage Hole — DONE 2026-08-17

- [x] **Create a test helper with bloc factories — DONE 2026-08-17.**
      `test/support/bloc_factories.dart` provides both kinds: `mock*Bloc`
      factories that pair construction with `whenListen` (a bare `MockBloc`
      has a null state, and every call site used to repeat that pairing by
      hand), and `real*Bloc` factories over hand-written in-memory
      repository fakes. **Corrected: this said "nine test files" — it is
      five.** The nine came from a `mocktail|bloc_test` grep that swept up
      `configuration_bloc_test.dart` (imports `bloc_test`, hand-rolls
      nothing) and `spell_engine_test.dart` (matched only a comment naming
      another file). Seven if you count the two that hand-roll a repository
      mock — and **those two are deliberately not migrated**: both use
      mocktail for *error injection* (`thenThrow`), which an in-memory fake
      models worse, so the fakes carry no error hook.
- [x] **Document the resulting rule — DONE 2026-08-17.** It is the library
      dartdoc on `bloc_factories.dart`, so an author cannot reach a factory
      without passing the explanation of which one to pick. The false
      premise was also removed from `test/widget_test.dart`'s `setUp`
      comment, which had explained the real workaround and then attributed
      it to a Bloc limitation.
- [x] **One command running all suites — DONE 2026-08-17.**
      `dart run tool/run_all_tests.dart`. **Four steps, not three:**
      `flutter analyze` gates the Dart suite in CI, so a three-step runner
      could go green where CI would not. Every step runs even after one
      fails, so the summary answers "which suites actually ran". The device
      comes from `Platform.operatingSystem` rather than a hard-coded
      `windows`, so the Linux-runner experiment the workflow comments keep
      open does not need this file edited.
- [x] **Run integration tests as part of verification — DONE 2026-08-17.**
      `tests.yml` gained an `integration` job. It is a separate job on
      `windows-latest` because the suite needs a device and that is the only
      configuration it has ever run in; the rationale, including what switching
      to Linux would cost, is commented in the workflow. Verified by running
      CI's exact command locally: `flutter test integration_test -d windows`,
      **8 of 8 green** — and **green on its first real run on GitHub's
      `windows-latest`**, so the hosted runner's build environment is a proven
      baseline, not an assumption. That is the comparison any future attempt to
      move this job to Linux is measured against. Note the *directory* form, so
      a second integration file is picked up without editing the workflow.

**⚠️ Correction 2026-08-17: this item's founding premise was wrong.** It held
that "a real Bloc hangs forever under flutter_tester; known Bloc limitation."
That does not reproduce. A probe with a **real** `SpellCreationBloc` — mocking
only `SpellRepository` — dispatching `TechniqueSelected` and rebuilding a
`BlocBuilder` passed in under a second, `pumpAndSettle` included.

The accurate diagnosis was already in the repo, at `test/widget_test.dart:54-60`:
**real async I/O awaited directly inside a `testWidgets` body** hangs, because
that body runs in a fake-async zone — which is why the real `AppDatabase` is
opened in `setUp` instead. That comment then guesses it is "the same category of
issue documented for real Blocs." It is not. A Bloc is an event handler; it hangs
only if it awaits real I/O, and mocking the *repository* removes that.

- **The rule is "don't await real I/O in a test body," not "don't use real
  Blocs."** Corollaries: `setUp`/`tearDown` run outside the fake-async zone, and
  `tester.runAsync` is the documented escape hatch from inside it — unmentioned
  anywhere in this repo.
- **This is why the item looked expensive.** Failure mode 2 below concluded that
  re-render coverage had to go to `integration_test/`. It does not: a real bloc
  with a faked repository re-renders in a plain widget test, at widget-test
  speed. The false premise foreclosed the cheap fix.

- **Two failure modes, one now mitigated:**
  1. `flutter test` does **not** run `integration_test/` — those need a device, so
     the suite rots silently. A broken end-to-end test once went unnoticed across
     several "suite is green" checks because the file simply never ran.
     **CI now runs it**, so this binds only for local runs.
  2. **Mocked blocs cannot catch re-render bugs.** A mock emits no new state, so the
     rebuild after an interaction never happens. The add-requisite crash
     (`DropdownButtonFormField` holding a value no longer in its `items`) was
     invisible to 6 passing widget tests for exactly this reason. When the failure
     mode *is* "what happens on re-render", **use a real bloc with a faked
     repository** — or drive states through a `StreamController` on the mock, or
     cover it in `integration_test/`.
     Item 52 is the same lesson one layer up: a widget-tree presence check is
     neither a reachability nor a visibility check.
- **Superseded note, kept because it was a real correction:** this item once
  carried "⚠️ 2 of 5 fail" from 2026-08-06 (two `scrollUntilVisible` failures),
  fixed 2026-08-10 with a `maxScrolls: 500` budget.
- **Files:** test helpers, widget test templates, `integration_test/`,
  `.github/workflows/tests.yml`


### 8. UI: Disable Multi-Select for Range/Duration/Target — OBSOLETE
Superseded by item 1: selecting multiple Ranges, Durations or Targets is no longer
representable.


### 13. Summary/Description Entry for User-Created Spells — DONE 2026-08-17
`validateSpellProse` lost its `source` parameter entirely: every spell, published
or user-created, now needs a summary or a description
(`'a spell needs a summary or a description'`), enforced at all four call
sites — the `Spell` constructor, `SpellDraft.toSpell`, and the `ExceptionSpell`
and `SpellTemplate` constructors. What binds:
- **`SpellDraft` is home, the save dialog is the backstop.** The creation
  screen's new `Summary` field (key `summary-field`) writes `SpellDraft.summary`
  via a new `SummaryChanged` event, updating the draft only — no breakdown
  recompute, since prose cannot change a level. `_SaveSpellDialog` takes
  `requiresSummary` and collects a summary only when the draft has neither
  summary nor description; its Save button stays disabled until both fields are
  non-empty. `SpellSaveRequested` gained `String? summary`, applied via
  `copyWith` before `toSpell` — one event, one atomic save.
- **`SpellEngine.validateSpellDraft` deliberately gained nothing.** It gates
  breakdown recalculation, so a prose check there would stop the level
  displaying until a summary was typed.
- **`Spell.fromMap` backfills `summary` with `legacySummaryPlaceholder`
  (`'No summary recorded.'`) for two narrow reasons.** It lives in `fromMap`
  rather than the datasource because a pre-change *backup* would otherwise
  abort a whole restore in `BackupService`'s list literal. And it fires only
  for records whose source is user-created and which have no prose — a
  published record with no prose still throws, so the import assertion keeps
  its teeth. Read-only: nothing is written back, so there is no migration.
- **`TemplateInstantiated` needed no change** — it already seeded the draft
  summary from the template, and was already tested.
- **Spec:** `docs/superpowers/specs/2026-08-17-user-created-spell-prose-design.md`


### 14. Container Targets: Static vs. Dynamic — DONE 2026-08-17
The rulebook's "Container Targets" sidebar settles it: a container-target spell
is either **static** (affects whoever is inside at the moment of casting, keeps
affecting them if they leave or the container ends) or **dynamic** (affects
whoever is currently inside, gained or lost as they cross the boundary). What
binds, beyond what the code already records:
- **The mode is fixed at design time (Core Rules 12250), and it is not
  derivable** — two spells with identical Technique/Form/Range/Duration/Target
  can differ in mode (12252). It is therefore a stored per-spell field, not
  computed from the parameter tuple, and it is **level-neutral**: no magnitude
  reads it.
- **`unstated` means "no decision recorded," never "none owed."**
  `spellOwesContainerMode` (`lib/models/spell.dart`) derives the latter and has
  no production caller yet — there's no character to owe it to until spells
  belong to one.
- **Check 9 in `validateSpellAgainstCatalog` tests Target kind only.** Momentary
  spells (where the static/dynamic distinction is vacuous) are excluded in the
  `spellOwesContainerMode` predicate, not in the check.
- **8 Circle wards were backfilled `dynamic`** from one shared Magical Wards
  rationale (`scripts/spell_import/container_modes.json`). **16 container rows
  still need a per-spell prose reading** before a mode can be assigned —
  tracked as item 57. `tpl-crvi-restore-faded-threads` is among them: a Circle
  spell that is not a ward, so the wards rationale doesn't decide it.
- **`target-bloodline` is an `object` Target with its own baked-in ongoing
  rule** ("applies to all members ... born during its duration, as well as
  those already living when it is cast") and must never become a container —
  the rule is the Target's, not a per-spell choice.
- **Spec:** `docs/superpowers/specs/2026-08-17-container-target-mode-design.md`


### 15. Add All Core-Rulebook Parameters (`c835d0a`)
The catalog held 17; the core rulebook defines **25**. Added Range Eye (+1), Duration
Ring (+2) and Year (+4), Target Circle (+0) and the four missing magical senses
(Taste/Touch/Smell/Hearing); renamed `Bound` → `Boundary`. Two decisions that bind:
- **Ritual-only gating is `Parameter.requiresRitual`** — Year and Boundary are exactly
  the core entries flagged (item 17 later added the three Symbolic Magic ones).
- **The Target `Touch` / Range `Touch` name collision is left as-is** — ids are
  category-scoped (`range-touch` vs `target-touch`) and the dropdowns filter by
  category, so the two never share a picker.


### 17. Virtue-Gated Parameters: Merinita Faerie Magic and Symbolic Magic — DONE 2026-08-16
Nine parameters added, gated by an informational `requiresVirtue: String?` on both
`Parameter` and `BaseEffect` — selectable like any other entry, since the app has no
character/Virtue model to enforce against; the field only names the requirement.
- **Fire** (Duration) needed real Form-scoping (Ignem/Imaginem), closing a gap
  `Parameter` never had: a new `ParameterScope` (`forms: List<String>`).
- **Symbol (Range)** is the catalog's first ritual-only *Range*, which needed
  `RitualReason.ritualOnlyRange` and a `range` argument on `_deriveRitualStatus`.
- **Worked example:** *Faerie Chains of the Familiar Slave*
  (`tpl-crvi-faerie-chains-familiar-slave`) on a new General base effect
  `crvi-hohmc-G1`, the catalog's first row citing a supplement (`arm5-hohmc`).
- **⚠️ Correction (2026-08-17):** this item previously recorded the new base effect
  as using the `mightThreshold` formula with `offsetMagnitudes: -3`. **It carries no
  `effectFormula` at all** — dropped in `173fa0e` because a Might threshold ties to
  the total computed level, not `chosenBaseLevel`, and this guideline has no
  reference to make those coincide. Its own `notes` field records this.
- **This item's landing is what broke the import — see item 55.** Both the supplement
  base effect and the 9 new parameters violate assumptions baked into the Python
  oracles, and the new Creo Vim candidate invalidated three ledger entries.
- **Spec:** `docs/superpowers/specs/2026-08-16-virtue-gated-parameters-design.md`.
  Spawned items 53 and 54.


### 19. Size-Ladder Ceiling — COMPLETE 2026-08-16
A `+5` (×100,000) rung exists on every `size-<form>` ladder; the four spells that
needed it import. The architectural half: **`ModifierScope` gained `excludeTargets`**
(a carve-out mirroring `excludeTechniques`, not an allow-list) and `appliesTo()` a
`targetId` parameter, so `size-mentem` now carries
`excludeTargets: ["target-individual"]` — minds have no size, but can be counted for
Groups. **The actual bug found while wiring it:** `SpellCreationBloc`'s
`TargetSelected` was the only Technique/Form/BaseEffect/Target handler that didn't
prune stale modifier selections, so switching Target to Individual left a
`size-mentem` selection silently contributing magnitude. Now prunes via
`_withPrunedModifiers`.
**Still deferred:** whether Group/Room/Structure/Boundary should cost differently
from each other under the Size ladder — today they're priced identically.
**Spec:** `docs/superpowers/specs/2026-08-16-modifier-target-scope-design.md`


### 24. Ad-hoc Level Adjustments
A `LevelAdjustment` model — a list of `(magnitude, note)` — with one repeatable UI row
and one breakdown line per adjustment. What binds:
- **Negative magnitudes are allowed.** `SpellLevelCalculator` mirrors the positive
  rule (worth 1 inside the additive tier, 5 above it) and restores the additive
  capacity it gives back, so `[1, -1]` is a no-op at any base level.
- **Two token families, not one.** Recurring wordings (`fancy effect`, `complex
  effect`, `elaborate design`…) became a real globally-scoped `elaborate-effect`
  Modifier because they *are* reusable. Only genuinely per-spell prose became
  adjustments, matched against a **closed allow-list**
  (`designline.ADJUSTMENT_LABELS`) — so an unmodelled mechanism keeps blocking its
  spell instead of importing at a correct level with wrong modelling.
- **Do not confuse adjustments with Modifiers.** A Modifier is a reusable catalog
  choice scoped to a technique/form/effect; adjustments are unique to one spell and
  would pollute the catalog with single-use entries.
- Three late spells turned out to be reusable mechanisms after all and became
  catalog Modifiers instead: `no-words`, `no-gestures` (both global, buying off the
  still/silent casting requirement) and `invi-techniques-and-forms`.
- **Spec:** `docs/superpowers/specs/2026-08-04-level-adjustments-design.md`


### 25. General-Level Spells — base level is chosen, not fixed
33 published spells are General-level, including **every Vim spell and every ward**.
What binds:
- `GeneralEffectFormula` on `BaseEffect` (a reference R/D/T, a `GeneralEffectKind`
  and an offset); General catalog entries carry `baseLevel: null`.
- **`chosenBaseLevel` enters `SpellLevelCalculator`'s additive/multiplicative split
  exactly as the guideline's base would have** — that was the design-heavy question
  and this is the answer.
- Validation rejects both a missing chosen level and one below 1. **Neither computes
  a silent zero.** The bloc clears it on any switch away from General.
- Published General spells emit to `spell_templates.json`, not `spell_library.json`.
- **A catalog row must never be reconstructed from a spell's own prose to receive
  that spell.** Tried twice (`peme-G`, `inco-gen`) and reverted both times;
  `test_general_entries_match_the_rulebook_bullet_for_bullet` now holds the catalog
  to the rulebook's own bullets art-by-art, in both directions, permanently.
- The last four cleared 2026-08-16 by two mechanisms: three via base-effect analogy
  (item 48) pointing at the Vim-level General row each is a narrower, un-offset echo
  of (`pevi-G2`, `revi-G2`, `pevi-G3`); one (*The Invisible Eye Revealed*, already a
  Vim spell with nowhere more general to point) as an exception spell.
- **Spec:** `docs/superpowers/specs/2026-08-05-general-base-effects-design.md`


### 26. Non-standard Ranges, Durations and Targets
**Covered by item 24's adjustments; no `Special` parameters were added, and
`spell.dart` was untouched** — the section 0 "confirm no model change" check for this
item is answered. `designline.ADJUSTMENT_LABELS` matches on the token's *bracketed*
text rather than the bare word `Special`, because the corpus hides two different
mechanisms (a nonstandard Duration and a nonstandard Target) behind that one word.
`emit._parameter_name` resolves `D: Spec` via a closed table,
`SPECIAL_PARAMETER_BASIS`, keyed on the spell's own "based on X" clause — so a
spell whose clause names no basis (*Watching Ward*) cannot be resolved this way and
became an exception spell instead, as did *Mists of Change* (`D: Sun & Year`, two
durations in one stat line). *The Bountiful Feast* was a genuine rulebook
transcription defect (a missing closing paren), fixed via `DESIGN_LINE_TYPOS`, not a
splitter change.


### 27. Published Spell Import Harness
The harness is what makes every other mechanism *verifiable*. What binds:
- **The extractor** is maintained and idempotent at
  `scripts/spell_import/extract_spells.py` (`scripts/import/` in the spec — `import`
  is a Python keyword, so the directory was renamed; the one deliberate deviation).
  `--show-blocked` prints per-spell blocked reasons.
- **The ledger** (`resolutions.json`) records each base-effect decision **and the
  candidate set it was made against**, so new guideline rows flag affected decisions
  as stale rather than letting them stand unexamined. **Item 55 is this mechanism
  firing for real.**
- **Asset assertions:** level equality, Ritual agreement (the oracle that does not
  depend on the base effect), resolution completeness, reference integrity, clean
  regeneration, plus assertion 6 for General picks. They are split across both
  suites — neither alone covers all of them.
- **`Citation.page` cannot carry page numbers.** The reviewed markdown has no page
  markers, only prose cross-references. **Do not re-promise it.**
- Three spells print no design line: *Enchantment of the Scrying Pool* and *Hermes'
  Portal* are hand-derived in `HAND_DERIVED`; *Whispering Winds* is an exception
  spell.
- **Spec:** `docs/superpowers/specs/2026-07-28-published-spell-import-design.md`


### 28. Guideline Levels Absent from the Rulebook's Own Table — 5 of 5
All five turned out recoverable from documented prose rules. **Chose option 2 —
model the prose rules in the modifier system** — not derived catalog rows or ad-hoc
adjustments: the CrVi Warping Point and PeIg chill-damage ladders became
`selectionMode: single` modifiers scoped to their base effect, collapsing separate
numbered rows, and MuAu's single-property discount became a broadly-scoped modifier.
One `NUMBERED_OVERRIDES` table in `extract_spells.py` resolves what the design first
drafted as two separate mechanisms.
**What was caught in review:** deleting `peig-10b` would have silently dropped a real
corpus spell whose ledger entry still named the deleted row as a candidate — a test
now asserts the ledger and `NUMBERED_OVERRIDES` never silently disagree. **This is
the same failure shape as item 55**, one layer down.
**Not item 22:** that is rows genuinely absent from the Definitive Edition.
**Spec:** `docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md`


### 29. Open Follow-ups from the Import-Harness Review — DONE 2026-08-17

Genuine findings from item 27's merge-readiness review. None blocked that merge;
all concern future safety or clarity. The cheap ones were fixed at the time
(the `_split_parts` punctuation family, the transport-distance mapping — see
items 43/45); what remains needed design judgement or more time.

- [x] **Decide on the ledger's "explicit override" promise** — **DROPPED
      2026-08-17.** The promise was dropped, not implemented: `ledger.py`'s
      `resolve()` was not changed, only a comment inside it, which now states the
      rule as design rather than a known gap (`8cbc519`). The rule: the ledger
      records a choice *among* the candidates a spell's design line admits, never
      one against them — a sole candidate that is the wrong guideline is a
      `base_effects.json` bug, or an `ExceptionSpell`. The spec's promise
      (`docs/superpowers/specs/2026-07-28-published-spell-import-design.md`) was
      amended with a dated note rather than rewritten silently. A
      mutation-checked test in `test_ledger.py` pins the behaviour.
- [x] **Add the 2 still-missing modifiers to `modifiers.json`** — **DONE
      2026-08-17.** Added `creo-aquam-unnatural` (natural 0 / slightly unnatural
      +1 / very unnatural +2, the last requiring a Muto requisite) and
      `creo-herbam-treated-product` (treated +1 / treated and processed +2), and
      retrofitted `creo-animal-treated-product` from an empty scope to
      `["cran-5a", "cran-10a"]` (`6b763b2`). **Both treated-product modifiers are
      scoped by `effectIds`, and the scoping is load-bearing:** `crhe-2a` already
      prices the Herbam treatment rule into its printed base level, and the Creo
      Animal rule prices treatment against creating an equivalent amount of
      *dead* animal, so live-animal rows are excluded from either scope. A new
      test pins both exclusions.
- [x] **Collapse the duplicated level sum in `asset_data_loader_test.dart`** —
      **DONE 2026-08-17.** "Every loaded spell calculates to the level stated in
      its description" now calls `SpellEngine.calculateBreakdown` (the file is
      `test/data/datasources/`, not `test/data/`, as this item long said). The
      collapsed assertion was mutation-checked before being kept: dropping
      `adjustments:` from the engine call reproduces the original drift exactly
      — The Severed Limb Made Whole computing 30 against a printed 25 — so the
      single remaining copy still has the teeth the two copies had.
      `allParameters` is left empty, matching assertion 1, so neither oracle
      applies the base-effect reference discount.
- [x] **Remove `"phantasm"` from `catalog._STOPWORDS`** — **DONE 2026-08-17.**
      The renames are `lib-crim-human-form` → `lib-crim-phantasm-human-form` and
      `lib-crim-talking-head` → `lib-crim-phantasm-talking-head`;
      `lib-crim-phantasmal-animal` was never affected. **The "migration weight"
      this item warned of did not materialise, and the reason is worth keeping:**
      a grep for the three ids found live references only in
      `spell_library.json` (regenerated by `--write`) and one expected string in
      `test_catalog.py`. No ledger entry, no `container_modes.json` entry, and
      no DB row — the `spells` table holds only user-created spells (item 33),
      so nothing user-side can point at a published id. The remaining hits are
      specs and plans, which are historical records and were left alone.
      A second slug test now pins the rule that content words stay.
- [x] **`README.md` is still the stock Flutter template** — **DONE 2026-08-17.**
      Replaced (`97d316c`), and now documents `scripts/spell_import/`. Counts
      deliberately stay out of it — counts live in this file's *Where the import
      stands* section.

**CI notes that bind — read before touching the workflows.**

- Two workflows answer deliberately different questions.
  `.github/workflows/tests.yml` runs on push to `main` and every PR, **pinned**: it
  reads the rulebook revision from `source.lock` and clones the rulebook at exactly
  that commit, so upstream churn can never redden a PR. It runs `python -m unittest
  discover` **and `flutter test`** — the Dart half is the point, since a regression
  reintroducing the `selectedModifiers: {}` bug passes every Python test and only
  the Dart-side assertion 1 catches it. **Since item 6 it also has a second job,
  `integration`, on `windows-latest`** — a different runner OS, which is why it is
  a job rather than a step; neither it nor the Flutter suite pins the rulebook,
  since both read the committed assets only.
  `.github/workflows/rulebook-freshness.yml`
  is weekly and **unpinned** (item 30): a failure there means "upstream improved,
  go adopt it".
- **Do not "simplify" the pinned job to a shallow fetch-by-SHA — it cannot work.**
  `source.lock` records an **abbreviated** 7-char SHA, and the git wire protocol
  cannot fetch one (`git fetch --depth 1 origin 97cc62d` fails with `couldn't find
  remote ref`, verified). The job therefore does a blobless clone
  (`--filter=blob:none`, ~14s) and resolves the short SHA locally at checkout. A
  cache keyed on the recorded SHA skips the clone until the lock is bumped, and a
  post-restore `rev-parse` guards against a cache entry holding the wrong tree. The
  alternative is widening the lock to a full SHA.
- **Supply chain:** `tests.yml` uses third-party `subosito/flutter-action@v2`,
  pinned by major-version tag rather than commit SHA. It is the de-facto standard
  and the only non-first-party action in the repo. Pin it to a SHA if that trade is
  unacceptable.


### 30. Rulebook Source Provenance (`77c8b01`)
Records which rulebook revision produced the assets, via deterministic sha256
provenance in a committed sidecar (`scripts/spell_import/source.lock`), never in the
asset itself. What binds:
- `ARS_RULEBOOK_ROOT` overrides the rulebook location (used by CI).
- `provenance.py` computes/stores/compares source identity; `report.py` diffs two
  asset lists into readable markdown; both testable with **zero rulebook dependency**.
- `RegenerationTest`'s failure message is drift-aware: it distinguishes "source
  moved" from "asset was hand-edited" by checking `source.lock`.
- **`--write` is gated on `--accept-source`** — adopting upstream changes is explicit.
- Item 55 added one exception to the "only `--accept-source` writes the lock"
  rule: a `--write` under an *unchanged* source refreshes the advisory counts,
  which had drifted to 294 against 325 because the lock was rewritten only when
  the source moved — the one case those counts are ever read.


### 34. Guidelines Missing From the Catalog (`8a70889`, `87ac754`)
Compared every guideline table bullet by bullet, restored 4 missing General and 5
missing ordinary guidelines, removed 2 invented rows. What binds:
- **The standing check is now a test, not an audit** —
  `test_general_entries_match_the_rulebook_bullet_for_bullet` parses the guideline
  tables and compares **per art, in both directions**. Per art matters: a dropped
  bullet in one art and an invented row in another cancel out in a single total,
  which is very nearly what had happened.
- **Two failure modes**, which is why a single-cause fix would have missed half: a
  multi-bullet row keeping only its first bullet, and a row dropped entirely. A
  third variant merged two bullets into one description.
- **The reverse direction had two hits** — `peme-G` and `inco-gen` existed in arts
  whose tables print no General row at all; each was a spell's own effect text read
  backwards into a guideline. Precisely item 32's failure mode.
- **Still open: nobody knows why the extraction dropped them.** The producing script
  is not in the tree. **If item 22 ever rebuilds this asset it must reproduce the
  full catalog, and the bullet-count comparison is the test to run first.**
- **Consequence:** Rego Animal and Rego Mentem now have *two* General candidates
  each, so spells in those arts need a recorded ledger pick.


### 35 / 37. Open Guideline Slots — Realm, Form, "Specific Type" — DONE 2026-08-14/15
A guideline can leave a slot open that the caster fills, exactly as a General
guideline leaves the level open. What binds:
- **One generic `chosenSlots: Map<String, String>` on `Spell`/`SpellDraft`/
  `SpellTemplate`, keyed by slot kind — not three bespoke `chosen*` fields.** Each
  bespoke nullable slot would have cost a `copyWith` sentinel, a clear-on-switch
  branch and a UI conditional; `chosenBaseLevel` pays that once, and three more
  would have paid it three more times. **Realm could not reuse `chosenBaseLevel`'s
  plumbing anyway** — `revi-5` and `revi-15` are ordinary fixed-level rows with an
  open realm, and every existing guard keys on `isGeneral`.
- Enforced by validation checks 6 (mandatory unless the effect declares it open) and
  7 (stray-kind rejection).
- **Free text, not a closed set** — the rulebook gives illustrative examples, not an
  exhaustive list.
- **The import reads the chosen value via a hand-verified table
  (`REALM_BY_SPELL_ID`), not a prose scan** — a scan was tried and demonstrably
  misfires on the real corpus.
- Part B needed no resolution table at all: every corpus template on its 7 guidelines
  is genuinely open (none commits to one value in its prose), confirmed by a
  byte-identical regeneration rather than a git diff.
- **Spec:** `docs/superpowers/specs/2026-08-10-open-guideline-slots-design.md`


### 37. A Template Has Open Slots Beyond Its Level
Designed and shipped jointly with item 35 — **see the combined entry above.** Item
35 is the realm instance; 37 generalised it to Form and "a specific type".


### 39. Ambiguous Ledger Resolutions Needing a Rules Decision — 4 of 4
All four had a forced discriminator after all, found by re-reading each against its
candidates' *exact* wording rather than the most general-sounding one. Two Intellego
picks turned on "feel"/"no seeing involved" vs. sight; *Crystal Dart* on the design
line's own arithmetic leaving no room for the different-material surcharge.
*Conjuration of the Indubitable Cold* was reclassified rather than resolved: its text
matches `peig-4b` and `peig-4c` near-verbatim at once, and **both print at the same
base level, so the pick is cosmetic** — `peig-4b` goes through the ledger like any
other multi-candidate spell, and `peig-4c` is recorded as a magnitude-0
`LevelAdjustment` (real, UI-visible data, not silently dropped) via
`COMBINED_BASE_EFFECTS` and `emit.build_spell`'s `extra_adjustment`. **That fix is
one-off and importer-only — a user designing their own spell cannot combine base
effects this way; see item 47.** `KNOWN_UNRESOLVABLE` is empty but the mechanism
stays for a future genuine tie.


### 40. Model Invariants Have Only One Enforcement Path — COMPLETE 2026-08-16
What binds:
- **An invalid spell blocks** (rejected at save/restore/import), decided by the user,
  and **flagged as revisitable** — the *unresolved* case degrades instead, and the
  two may want to converge. No migration story for rows already stored invalid;
  backwards compatibility is not a goal.
- **`validateSpellAgainstCatalog` (`lib/models/spell.dart`) is the one enforcement
  path**, called from `ResolvedSpell.problems`, `SpellEngine.validateSpellDraft` and
  `SpellRepository` before every write. It now carries 8 checks (the 8th is item
  48's analogy invariant). It takes an `isTemplate` flag, since a record whose whole
  purpose is to have its level supplied later must skip the chosen-level checks.
- **Why this could not live in the constructor:** `Spell` deliberately holds
  `baseEffectId`, not `BaseEffect`, so it cannot see `isGeneral`. The enforcement
  home must hold both the record and the catalog.
- **`problems` is deliberately not collapsed into `isResolved`** — `isResolved` is a
  can-I-compute gate; `problems` means it computes but must not be trusted.
- **The `requisites` list became a map keyed by art** — the one invariant fixed by
  modelling rather than validation, making duplicate arts unrepresentable.
- Assertion 7 asserts zero problems across every published spell and template, so a
  broken library tab cannot ship. `SpellCard` renders the degraded state ("Needs
  review" chip, `(unverified)` level suffix) in **both** places that build one from a
  `ResolvedSpell`. `SpellRepository.saveAll` reports rejects instead of throwing, so
  one bad spell in a restore doesn't abort the rest.
- **Plan:** `docs/superpowers/plans/2026-08-09-spell-invariant-enforcement.md`


### 43 / 45. Transport-Distance Modifier Wiring — DONE 2026-08-15
`emit.py` mapped `rego-transport-distance` to option ids with the wrong prefix
(`rego-transport-distance-5-paces` vs. the real `rego-distance-5-paces`), so
`_option_exists` always failed; and one layer earlier, `designline.MODIFIER_LABELS`
didn't recognize the distance labels at all, so parsing raised `UnknownToken` before
the mapping was reached. Both fixed: **the 6 concrete labels are allow-listed, and
bare `"distance"` is deliberately excluded** — it names no real option, so it should
keep failing at the tokenizer rather than one layer deeper with a near-identical
message. *Hermes' Portal* now imports as `rete-4` (Base 4, +4 Arc, +4 Year, +5
arcane connection, +2 size = level 75 exactly).


### 45. Design-Line Tokenizer Doesn't Recognize Transport-Distance Labels
The tokenizer half of the fix above — **see the combined entry with item 43.**


### 44. Bare/Non-standard Requisite-Magnitude Phrasing — DONE 2026-08-15
Three spells costed a requisite's magnitude in prose `_REQUISITE` didn't recognise —
a parser gap, not a modelling gap. Two got a closed allow-list
(`designline.REQUISITE_LABEL_ARTS`), the same discipline as `ADJUSTMENT_LABELS`. The
third (a bare `+1 requisite`, no art named) needed a different mechanism, because
`designline.py` never sees the `Req:` line: it emits a `Token` with an empty label,
resolved in `emit._resolve_requisite_label` against `block.stat.requisite_arts`,
which **raises rather than guesses** if that list doesn't hold exactly one entry.
**Why this was not item 24's:** there the magnitude is unprinted and guessing would
be wrong; here the magnitude *was* printed and only the label's wording was
unrecognised.


### 46. Exception Spells — DONE 2026-08-16, 8 total
Spells where the rulebook itself says guideline arithmetic doesn't apply. What binds:
- **An `ExceptionSpell`/`ResolvedException` model pair** parallel to `SpellTemplate` —
  free-text Range/Duration/Target instead of catalog references, a required
  `rationale` citation instead of computed arithmetic, no calculator involvement.
  **No common parent class with `Spell`/`SpellTemplate`** — `lib/models` has zero
  `extends` relationships, and the one field most worth sharing (R/D/T) is exactly the
  one that cannot be identical between typed and free-text shapes.
- **A closed, exact-name table** (`exceptions.py`'s `EXCEPTION_SPELLS`) intercepted as
  the very first check in the import loop, before any tokenization.
- A third read-only `SpellLibraryScreen` section with no instantiation action.
- **Three shapes qualify**, documented in `exceptions.py`'s module docstring: the
  rulebook disclaims the arithmetic; the stat line can't be expressed by the model;
  or the guideline is genuinely absent from its art's table *and* reconstructing one
  from the spell's prose was already tried and reverted (*Sight of the True Form*).
- The standing goal was amended to carve this category out explicitly rather than
  silently failing to cover these spells.
- **Spec:** `docs/superpowers/specs/2026-08-15-exception-spells-design.md`


### 48. Base Effect Analogy — DONE 2026-08-16
`Spell` and `SpellTemplate` gained their own stored `technique`/`form` (no longer
derived from the base effect) plus an optional `analogyRationale`, **required
non-null exactly when they differ from the resolved base effect's own
technique/form** — enforced as validation check 8. So a by-analogy spell displays
under its own real Technique/Form instead of the borrowed one. `SpellDraft` threads
`analogyRationale` through `toSpell()`, validation and `TemplateInstantiated`, so
instantiating a by-analogy template works.
**Still open, deliberately:** creation-screen UI for picking a cross-Form base effect
interactively.
**Spec:** `docs/superpowers/specs/2026-08-16-base-effect-analogy-design.md`


### 49. `emit.py` Mistagged Ritual Declarations — DONE 2026-08-16
`build_spell` and `build_template` both unconditionally stamped
`ritualDeclaration: "lastingCreation"` onto every Ritual-flagged spell, with no
regard for *why* it is a Ritual. Now a `_ritual_declaration(block)` helper plus a
closed, exact-name `STORYGUIDE_RULING_SPELLS` table (same discipline as
`HAND_DERIVED`/`EXCEPTION_SPELLS`); three spells whose own design lines carry a
condition-6 justification verbatim are now `storyguideRuling`.
**Not a behavior bug for the other Ritual-flagged spells** — their `isRitual` derives
independently, so a wrong stored declaration never changed a computed level, only the
in-app banner text.
**Also fixed here:** `test_general_catalog.py` was the only test file importing via
`from .. import`, which `unittest discover` cannot load; switched to match its 13
siblings so the whole suite runs under `discover`.


### 51. `flutter test --platform chrome` Hangs Forever on Windows — RESOLVED 2026-08-16
**Use `flutter test -d chrome` instead.** `--platform chrome` is a deprecated
`package:test` browser-platform path whose local dev server fails to serve CanvasKit's
WASM/JS on Windows (`canvaskit/chromium/canvaskit.wasm` 404s though the file exists in
the SDK cache), so every widget test waits forever on a renderer that never
initializes. Matches [flutter/flutter#162798](https://github.com/flutter/flutter/issues/162798),
closed by deprecating the flag rather than fixing the server. Three plausible
hypotheses (the real-Bloc hang, `sqfliteFfiInit()` on web, Chrome's Local Network
Access policy) were chased and falsified first. A note pointing here lives in
`tool/setup_web.dart`.


### 52. Bottom Navigation Bar Was Effectively Invisible — FIXED 2026-08-16
Library/Settings/Backup were unreachable in real use, on every platform, the whole
time. **Root cause:** with no `type` given, `BottomNavigationBar` defaults to `fixed`
for 2-3 items and `shifting` for 4+ — this bar has exactly 4, so it silently landed in
`shifting`, which ignores `backgroundColor` entirely and hides unselected labels.
Material 3's default item colors were also too low-contrast for this app's pale
surface. Fixed in `lib/main.dart` with `type: BottomNavigationBarType.fixed` and
explicit selected/unselected colors.
**The coverage lesson (same root as item 6):** `test/widget_test.dart` asserted
`find.text('Library')` and passed, because `shifting` fades labels rather than
removing them from the tree — **a widget-tree presence check is neither a visibility
nor a reachability check.** No test taps through the real nav bar; every other screen
is tested by pumping it directly as `MaterialApp.home`, bypassing the navigation
shell.


### 55. The Catalog Stopped Being Core-Rules-Only — RESOLVED 2026-08-17
`crvi-hohmc-G1` (item 17's *Houses of Hermes: Mystery Cults* guideline) was the
first catalog row from outside the core rules. Adding it was right; what broke
was everything assuming the catalog and the core rulebook are the same set —
three Creo Vim ledger entries went stale, three templates stopped resolving,
and six Python oracles failed. **Decided by the user: the catalog stays flat.**
Candidate resolution offers every row the catalog holds; a row that should not
have won is a ledger decision, not a filter. What binds:

- **A widening is not a staleness.** `ledger.WidenedEntry` (a `StaleEntry`
  subclass, so an un-migrated ledger is still a build failure) marks the case
  where rows were only *added* and the recorded choice is still on offer. Any
  removal, or the loss of the chosen row, stays an ordinary `StaleEntry` and
  still demands a human.
- **`migrate_ledger.py` carries those decisions forward**, keeping
  `baseEffectId` and `rationale` verbatim. It is a separate command, not a flag
  on the extractor, because **the extractor must never write the ledger** —
  `run()` only reports what widened.
- **A migrated entry is not a reviewed entry**, and the file says so:
  the added ids land in `unreviewedCandidates`, and the extractor prints the
  outstanding count on every run so the backlog cannot go quiet. Clearing it is
  a re-read (item 32).
- **The oracles now say which rows they mean.** `catalog.cites(entry, book_id)`
  plus `CORE_BOOK_ID`; the bullet-for-bullet, General-count, ward-count and
  has-a-formula tests compare core rows only, and keep their exact counts
  rather than relaxing to a bound. `test_loads_the_committed_catalogs`'s
  parameter count became a floor — an exact total is something every supplement
  has to bump, the drift item 5 fixed by deriving counts.
- **A supplement row's id carries its book** (`crvi-hohmc-G1` cites
  `arm5-hohmc`). The id-suffix test derives that segment from the row's own
  citation, so the convention is enforced, not merely tolerated.
- **⚠️ Found while closing this: `--write` would have deleted item 17's worked
  example.** It rebuilds `spell_templates.json` from the run's own output, and
  the hand-authored template existed only in the asset. It is now a committed
  *input* (`scripts/spell_import/hand_authored_templates.json`) that the
  extractor reads on every run, which also makes the new regeneration
  assertion non-circular. **Anything that belongs in a generated asset but
  cannot be generated must live in an input file, never only in the output.**
- **Assertion 5 now covers all three assets.** `spell_templates.json` had no
  regeneration test, which is why 28 committed vs. 24 fresh went unnoticed;
  a second test separately pins that hand-authored templates survive a run, so
  deleting the entry from both sides cannot go green.
- `source.lock`'s advisory counts are refreshed by any `--write` under an
  unchanged source (they had drifted to 294 against 325). `--accept-source`
  still gates *adopting a moved rulebook* — that discipline is unchanged.

### Base Effect Extraction
604 base effects extracted from the rulebook's guideline tables; out-of-scope patterns
documented; Flutter desktop setup fixed (`sqflite_common_ffi` init). The catalog
stands at 611 today after items 34, 28, 17 and 64.

---


### Base Effect Extraction
604 base effects extracted from the rulebook's guideline tables; out-of-scope patterns
documented; Flutter desktop setup fixed (`sqflite_common_ffi` init). The catalog
stands at 611 today after items 34, 28, 17 and 64.

---
