# Eruditus Todo List

**Status:** Active development · **Last updated:** 2026-08-17

**Every count, line reference and status claim below was re-verified on
2026-08-17** by running the extractor, both test suites and the integration
suite, and by reading the assets and code directly. Claims that survived are
stated plainly; the ones that had gone stale were corrected rather than
carried forward.

**Standing goal:** every published spell in the Definitive Edition core rules
is either (a) in the spell library with its computed level matching its
printed level, (b) a template whose caster-supplied choices are left open
(item 25/37), or (c) recorded as an exception spell with a citation-backed
reason the guidelines don't apply to it (item 46).

## How to read this file

- **Item numbers are stable IDs, not priority order.** They are never reused and
  never renumbered, because specs, commits and other items cross-reference them.
  **Section order is priority order.**
- **Sections 0 and A** are the work that matters now. **B/C/D** are open but off
  the critical path. **Completed** holds closed items reduced to the decisions,
  constraints and gotchas that still bind — follow the linked spec/plan for
  detail, and the git history for narrative.
- **Counts live in one place** (*Where the import stands*, below). Item bodies do
  not restate them.
- Each open item states what to decide or do, why, and which files it touches.
  Where an item says "decide", that decision has not been made — do not assume an
  answer from an adjacent item.

---

## Where the import stands

**Live extractor run, 2026-08-17** (`python -m scripts.spell_import.extract_spells`):

> **325 imported · 28 templates · 8 exceptions · 0 blocked · 0 unresolved**
> — plus `unreviewed: 3`, see below.

**Suite status, all run 2026-08-17 after item 13:**

| Suite | Command | Result |
|---|---|---|
| Dart | `flutter test` | **660 tests, green** |
| Python | `python -m unittest discover -s scripts/spell_import/tests -p "test_*.py"` | **316 tests, green** |
| Integration | `flutter test integration_test -d windows` | **8 tests, green** — and now run by CI, see item 6 |

**3 ledger entries carry an unreviewed candidate.** Item 55's migration
carried three Creo Vim decisions past `crvi-hohmc-G1` without a human
weighing it, and each entry says so in its own `unreviewedCandidates` field.
The extractor prints the count on every run. Clearing it is a re-read, and
belongs to item 32.

**Catalog sizes, counted from the assets today:**

| Asset | Entries | Note |
|---|---|---|
| `base_effects.json` | 609 | 50 General — 49 core plus item 17's one supplement row |
| `parameters.json` | 34 | 25 core (item 15) + 9 virtue-gated (item 17) |
| `modifiers.json` | 32 | |
| `spell_library.json` | 325 | |
| `spell_templates.json` | 28 | 27 extracted + 1 carried in from `hand_authored_templates.json` |
| `spell_exceptions.json` | 8 | item 46 |
| `resolutions.json` | 206 | item 32; 3 carry an unreviewed candidate |

**All 360 published Chapter 9 spells are still accounted for.** 325 + 28 + 8 =
361, one more than 360, because `tpl-crvi-faerie-chains-familiar-slave` comes
from *Houses of Hermes: Mystery Cults*, not Chapter 9. No spell is blocked;
the 3 unresolved ones are a ledger problem, not a modelling gap.

**Standing finding: base-effect resolution rests on human judgement, and most
of it is unverifiable by test.** A design line names its guideline only by
level (`Base level 15`), and e.g. Creo Animal has four entries at level 15.
Measured 2026-08-17 across all 206 ledger entries: **186 have candidates that
all share one base level**, so the printed-vs-computed assertion confirms the
base level and nothing more — those rest entirely on their written rationale.
Only 20 have candidates whose levels differ, where assertion 1 discriminates.
See item 32.

**Two things confirmed as needing nothing further:**
- **The parameter catalog is complete.** Every Range, Duration and Target used
  by all 360 published spells resolves against item 15's 25 core entries.
- **The base-effect catalog matches the rulebook bullet-for-bullet**, per art
  in both directions, asserted by
  `test_general_entries_match_the_rulebook_bullet_for_bullet` — which since
  item 55 compares only the rows that cite the core rulebook, so a supplement
  guideline is neither a surplus nor a shortfall. Item 22's list of missing
  rows is now closed on the evidence; see that item.

**What the goal does and does not cover.** The goal is *computed level matches
printed level*, and the rulebook prints `#### GENERAL` instead of a number for
General-level spells — so a General template **can never satisfy the goal as
stated**. Item 25 solved the modelling (the caster picks a level) and routed
those spells to `spell_templates.json`; making templates genuinely
instantiable was items 35/37's job. Likewise Ritual correctness (item 18) and
ward mechanics (item 4) are fidelity work on spells the import already counts —
`extract_spells.py` gates on neither.

---

## 0. Immediate Program of Work — the `spell.dart` Foundation

**Opened 2026-08-09.** Model work on `lib/models/spell.dart` and its immediate
neighbours. It sits above section A because items 35 and 37 changed the
*serialized shape* of a spell, and every spell imported before that decision had
to be rewritten after it. Deciding first was the cheaper order; it was not new
scope.

**Status: fully discharged — all 5 rows are answered, and all 5 changes (where
one was needed) have landed.**

| # | Item | Model change | Status |
|---|---|---|---|
| 1 | **40** | Give the non-prose invariants an enforcement home both construction paths share | ✅ COMPLETE 2026-08-16 |
| 2 | **37** + **35** | One `choices` map vs. three more bespoke `chosen*` fields | ✅ DONE 2026-08-14/15 |
| 3 | **13** | Tighten `validateSpellProse` to user-created spells too | ✅ DONE 2026-08-17 |
| 4 | **19** | `ModifierScope` gains a Target restriction | ✅ COMPLETE 2026-08-16 |
| 5 | **14**, **26** | Confirm *no* model change is needed, before anyone adds a field on assumption | **26**: confirmed, none needed. **14**: a model change **was** needed — a stored `ContainerMode` field — and it is now implemented and closed. See item 14 (`## Completed ✅`) |

Item 14 keeps its number; this table was the ordering question, not a second
home for it. Its answer went *against* the optimistic reading the item had
carried since 2026-08-09, so the implementation it guarded was real rather
than dismissable — and that implementation is now done. The 16 container rows
still needing a per-spell prose reading are a separate, non-blocking
follow-up: item 57.

---

## A. Blocks the Library Import

### 29. Open Follow-ups from the Import-Harness Review

Genuine findings from item 27's merge-readiness review. None blocked that merge;
all concern future safety or clarity. The cheap ones were fixed at the time
(the `_split_parts` punctuation family, the transport-distance mapping — see
items 43/45); what remains needs design judgement or more time.

- [ ] **Decide on the ledger's "explicit override" promise.** The spec says an
      entry disagreeing with an unambiguous spell's sole candidate is valid "as an
      explicit override, which needs a rationale like any other decision" — but
      `ledger.py`'s `resolve()` has no path where that succeeds; it always raises
      `StaleEntry` (verified 2026-08-17, `ledger.py:75-99`, where a comment says
      so outright). The decision — implement the override, or drop the promise
      from the spec — is open.
- [ ] **Add the 2 still-missing modifiers to `modifiers.json`** — Creo Aquam
      unnatural liquids, Creo Herbam treatment. **Corrected 2026-08-17: this was
      3, and Perdo Herbam live wood has since landed** (`perdo-herbam-live-wood`).
      Note `muto-herbam-treated-material` exists but is Muto, not the Creo
      treatment row.
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
- [ ] **`README.md` is still the stock Flutter template** (verified 2026-08-17)
      and never mentions `scripts/spell_import/`.

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

---

## B. Deferred by Design — Derived Outputs

Not import blockers. Both stay as descriptive text on the spell, which is what the
rulebook itself does. **Why these are together:** each reads the *final computed
level* and produces a different quantity from it — a genuinely different shape from
`option → magnitude`, and the point the Spell Modifiers spec identified as where a
code seam earns its place.

### 4b. Intensity/Damage Modifiers
- [ ] Muto/Perdo Ignem: add 1 magnitude per 5 points fire damage exceeds +5
- **No published spell needs it.** The one that motivated this item, *Ward
  against Heat and Flames*, turned out to be **Rego** Ignem and to have a real
  catalog mechanism already (`rego-ignem-fire-intensity`); it was wired up
  2026-08-15 and imports. What's left is genuinely Muto/Perdo only — a
  display/derivation question in the same shape as item 42.
- **Item 25 retired the General-row half** (`GeneralEffectKind.damage`).

### 4c. Level-Dependent Might Reduction
- [ ] Muto/Perdo Ignem/Auram: elemental Might reduced by spell **level**, not magnitude
- **No published spell's level depends on this** — it describes runtime effect, not
  cost. Display concern only. Item 25 retired the General-row half
  (`GeneralEffectKind.mightReduction`).

### 31. Real Per-Spell Summaries — Ledger-Authored
- [ ] Author real per-spell summaries into a committed ledger keyed by spell id —
      the same pattern as `resolutions.json`, because the extractor is
      deterministic stdlib Python and cannot summarise prose
- **Why:** summaries are currently the description truncated to 400 characters,
  which duplicates the description rather than summarising it.
- **Deferred by the human partner** until all core-rulebook spells import, so the
  work is done once against the full set.
- **Do the `" Level N."` suffix removal at the same time.** It is vestigial —
  nothing reads `RegExp(r'Level (\d+)\.$')` anymore; both former readers use the
  typed `printedLevel` field. Removing it from `emit._summary` rewrites every
  summary, which is why it waits for this item rather than a code dependency.
- **Files:** `scripts/spell_import/emit.py` (`_summary`), a new summary ledger
  alongside `scripts/spell_import/resolutions.json`, `assets/data/spell_library.json`

### 32. Audit `resolutions.json` — no Test Can Check It
- [ ] **Start with the 3 entries that name their own gap.** Item 55's migration
      carried `lib-crvi-restore-faded-threads`,
      `lib-crvi-shell-false-determinations` and `lib-crvi-shell-opaque-mysteries`
      past `crvi-hohmc-G1` without weighing it, and each records that in
      `unreviewedCandidates`. Reading the familiar-binding guideline against
      those three rationales and clearing the field is the smallest possible
      instance of this item's whole job — and the only part of it the extractor
      currently reports.
- [ ] Re-read every entry against its spell's published text and its candidate
      guidelines' wording
- [x] **Record which entries carry the risk — measured 2026-08-17 rather than
      estimated.** Of 206 entries, **186 have candidates that all share one base
      level** and 20 do not. The 186 are the ones no automated check can reach.
      Recording the split *per entry* in the ledger file itself is still worth
      doing, so the risky subset is visible while editing.
- **A demonstrated failure, not a theoretical one.**
  `lib-reim-image-from-wizard-torn` shipped for months pointing at `reim-15b`,
  *"Summon a disembodied spirit associated with Imaginem"*. The spell summons
  nothing — it relocates the caster's own image — and its rationale argued "no
  Arcane Connection involved" when the spell's own text says *"you must use an
  Arcane Connection to yourself"*. Corrected in `cf0b40b`.
- **Why nothing caught it:** both candidates are base level 15 — which is why the
  extractor could not disambiguate them — so assertion 1 computed the printed 35
  either way; assertion 3 saw an entry present; assertion 4 saw the id resolve.
  Every automated check passed.
- **The rule this establishes:** when an ambiguous spell's candidates share a base
  level, the printed-vs-computed assertion confirms the base level and nothing
  more. Those entries rest entirely on their written rationale.
- **The same holds for every General entry, for a related reason.** A General base
  effect has no fixed level to check against — `chosenBaseLevel` comes from the
  caster — so assertion 1 cannot discriminate a wrong General guideline at all.
  Assertion 6 (`test_general_catalog.py:163`) is the only automated check standing
  between an entry and a wrong General pick.
- **Item 39's *Conjuration of the Indubitable Cold* pick is a deliberate member of
  the 186** — both candidates share base level 4 and the choice between them was
  made arbitrarily on the grounds that it is cosmetic. Re-reading it should
  confirm that reasoning, not the pick.
- **Files:** `scripts/spell_import/resolutions.json`

---

## C. Not on the Critical Path

Real work, none of it blocking the import.

### 6. Widget-Test Coverage Hole *(was: "…from the Real-Bloc Hang" — see the correction)*

- [ ] Create a test helper with bloc factories — **both kinds**, see the
      correction below: mocked blocs for state-driven assertions, and
      **real blocs with faked repositories** for anything testing a rebuild.
      Nine test files currently hand-roll their own `MockBloc` subclasses and
      `registerFallbackValue` blocks (verified 2026-08-17).
- [ ] Document the resulting rule (below) somewhere a test author will see it.
- [ ] One script/alias running all three suites, so "tests pass" means all of
      them. Nothing of the kind exists — `tool/setup_web.dart` is the only
      tooling in the repo.
- [x] **Run integration tests as part of verification — DONE 2026-08-17.**
      `tests.yml` gained an `integration` job. It is a separate job on
      `windows-latest` because the suite needs a device and that is the only
      configuration it has ever run in; the rationale, including what switching
      to Linux would cost, is commented in the workflow. Verified by running
      CI's exact command locally: `flutter test integration_test -d windows`,
      **8 of 8 green**. Note the *directory* form, so a second integration file
      is picked up without editing the workflow.

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

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells conform to the one-Range/Duration/Target constraint
- [ ] Add migration for legacy spell saves (if any)
- [ ] **Custom modifiers are absent from backup entirely.** Verified 2026-08-17:
      `BackupService.exportToJson` carries `customEffects` and `customParameters`
      only, though `app_database.dart` has a `custom_modifiers` table. A restored
      spell that selected a custom modifier resolves to nothing on import, so
      check 5 (single-selection cardinality) is silently skipped and the spell
      imports unvalidated on that axis. Consistent with the existing "unknown
      modifier id is tolerated" constraint — **not a regression** — but the gap
      should be closed with the rest of this item.
- **Round-trip coverage is done** (item 40 Task 7): the backup test calls through
  the real `exportToJson`/`importFromJson`; import now loads custom effects and
  parameters *before* spells, and uses `SpellRepository.saveAll`, so one invalid
  spell no longer aborts a restore (`BackupImportResult.rejectedSpells`).

### 9. Spell Tags / Library Organisation — half done
- [x] `tags` field on the Spell model (`c4242d6`) — `List<String>`, serialized and persisted
- [ ] Assign tags when creating or editing a spell
- [ ] Filter/browse the library by tag
- [ ] Support multiple tags per spell, and combine tag filters with the existing
      search + source filters
- [ ] Decide: free-text, a curated vocabulary, or free-text with suggestions from
      existing tags
- **Model and persistence are done — what remains is purely UI.** No schema change
  needed. Verified 2026-08-17: no screen references `tags`, and 0 of the 325
  published spells carry any.
- **Rationale:** thematic grouping the Technique/Form axes can't express. A spell
  that raises a castle is both "defensive" and "architecture"; neither is derivable
  from Creo/Terram. Value rises sharply now the library holds 325 spells.
- **Files:** `lib/presentation/screens/spell_library_screen.dart` (tag filter UI),
  `lib/presentation/screens/spell_creation_screen.dart` (tag entry),
  `lib/bloc/spell_library/` (filter events/state)

### 47. Multiple Base Effects in Spell Creation — Combined Guidelines

**Not on the critical path** — item 39 handled its one published case with a
narrow, importer-only mechanism. But that case is real, and a user designing
their own spell has no way to do what *Conjuration of the Indubitable Cold* does.

- [ ] Let a spell draft record more than one base effect, restricted to guidelines
      matching the spell's own Technique/Form **or** that of one of its requisites
      (mirroring how the Requisites section treats requisite Arts as legitimately
      contributing an effect, not just a cost)
- [ ] The **highest-level** base effect among those chosen is recorded as
      `baseEffectId` and drives the calculation, per the rulebook's own rule:
      *"the base Arts and level for the spell are those for the highest-level
      effect it has"* (Requisites, Core Rules)
    - **Open question:** is "free" (item 39's answer) general, or only true when
      both guidelines share a level? The Requisites section's rule for
      *unequal*-level combinations charges extra ("each requisite adds at least one
      magnitude" when it "would do significantly less" without it) — a general
      feature likely needs that branch too.
- [ ] The other chosen base effect(s) recorded as **structured data** — a
      `List<String>` of base-effect ids, so the UI can render each one's own
      `description` from `base_effects.json` instead of a hand-synced paraphrase
- **Decide first: extend `adjustments` (`List<LevelAdjustment>`), or add a
  dedicated field?** Item 39's importer fix reused a magnitude-0 `LevelAdjustment`
  because it only had to solve one spell with no UI; overloading that field for a
  real UI feature would leave "achieves another guideline for free" indistinguishable
  from "storyguide subtracts a magnitude for narrative reasons".
- **Files:** `lib/models/spell.dart` (`Spell`, `SpellDraft`),
  `lib/engine/spell_engine.dart`, `lib/bloc/spell_creation/`,
  `lib/presentation/screens/spell_creation_screen.dart`
- **See also:** item 39

### 53. Bargain Duration's Nested Level Computation
Found 2026-08-16 while landing item 17. **Bargain** (Duration, Faerie Magic) does
not fit `Parameter`'s flat `magnitude` model: its true level is *"calculate the
level of the spell that takes effect when the bargain is broken, and add three
magnitudes"* (Core Rules line 10038) — a nested spell-level computation
`SpellEngine` has no mechanism for. Same shape as *Mists of Change*'s
two-Durations-at-once `ExceptionSpell` (item 46).

- [ ] Decide whether `SpellEngine` needs a nested-computation capability, or every
      real Bargain spell must be modeled as an `ExceptionSpell` instead
- **Not urgent:** no published spell using Bargain has been found; `duration-bargain`
  is cataloged with `magnitude: 4` (Year's value) as a documented simplification,
  informational only until a real spell needs it. Verified 2026-08-17.
- **Files:** `lib/engine/spell_engine.dart`, `lib/models/exception_spell.dart`
- **Spec:** `docs/superpowers/specs/2026-08-16-virtue-gated-parameters-design.md` ("Out of Scope")

### 54. Open/Variable Requisites (Per-Casting, Not Per-Catalog-Entry)
Found 2026-08-16 landing item 17's worked example, *Faerie Chains of the Familiar
Slave*. Its own requisite — *"a Technique and Form appropriate to the creature's
nature and physical form"* — is chosen at casting, not fixed by the catalog entry,
but `SpellTemplate.requisites`/`Spell.requisites` only support fixed `{Art: kind}`
pairs. Same shape of gap as item 50's `ModifierScope` granularity problem.

- [ ] Decide how to model a requisite whose Art is chosen per-casting rather than
      fixed by the spell/template
- **Not urgent:** the template ships with `requisites: {}` and the gap noted in its
  own `description`; no arithmetic is wrong, the requisite is simply absent from the
  computed breakdown.
- **Files:** `lib/models/requisite.dart`, `lib/models/spell_template.dart`,
  `lib/models/spell.dart`
- **Spec:** `docs/superpowers/specs/2026-08-16-virtue-gated-parameters-design.md` ("Out of Scope")

### 16. Short Forms for Parameter Names
- [ ] Decide whether parameters need a short display form at all — **confirm a real
      layout is constrained before building anything**
- [ ] If so, add an optional `shortName` to `Parameter`, falling back to `name`
- [ ] Add a small widget picking the longest form that fits the available width
- **Check the need first.** These names appear mostly in dropdowns, where width is
  rarely tight and substituting text makes selection confusing. More likely
  candidates are the spell card or the level-breakdown chips — measure first. **The
  rulebook abbreviates in exactly one place: the spell stat line
  (`R: Touch, D: Sun, T: Ind`).** If the app ever renders that line, that is the
  constrained widget.
- **Do NOT encode alternatives as inline markup** (e.g. `"B/ound/ary"`):
  presentation inside domain data means search, comparison, backup export and tests
  must all strip markup first; it can only express prefix truncation ("Arcane
  Connection" → "Arc" works, → "AC" does not); and **`/` already means something
  else here** — the rulebook uses it for equal-difficulty pairings (`Touch/Eye`,
  `Sun/Ring`, `Group/Room`, `Individual/Circle`).
- **Precedent:** `Book` carries `title` *and* `abbreviation` as separate fields; the
  wider precedent is CLDR, which models wide/abbreviated/narrow as named forms.
- **Flutter has no built-in string-alternatives system.** `FittedBox` scales glyphs;
  `TextOverflow.ellipsis` truncates crudely; `auto_size_text` shrinks the font. The
  real mechanism is `LayoutBuilder` + `TextPainter` with your own selection logic.
- **Note:** `Bound` → `Boundary` was a *data error* fixed by item 15, not evidence
  that abbreviations are needed. No `shortName` exists today (verified 2026-08-17).
- **Files:** `lib/models/parameter.dart`, `assets/data/parameters.json`

### 18. Storyguide-Ruling UI for Rituals — remaining questions only

The UI half is **✅ DONE 2026-08-16**: `RitualSection` is a three-way
`RadioGroup<RitualDeclaration>` (Not declared / Creates something lasting /
Storyguide ruling), wired through the existing `RitualDeclarationChanged` event.
The "Creates something lasting" option stays gated to Creo + Momentary; the
storyguide-ruling option is always shown, since Core Rules line 12352 lets the
troupe declare *any* spell a Ritual. `_withRitualDeclaration` already handled
`storyguideRuling` correctly — 5 new bloc regression tests passed immediately,
confirming no bloc change was needed. `TemplateInstantiated` copies a template's
declaration verbatim (deliberately, for cases like *Disenchant*), so the option's
visibility was widened to cover an ineligible-but-carried declaration rather than
letting it become a one-way clear.
Spec: `docs/superpowers/specs/2026-08-16-storyguide-ruling-ui-design.md`.

- [ ] **Decide whether the two Vim Generals want a guideline flag rather than a
      per-spell ruling.** *Disenchant* (PeVi Gen) and *Watching Ward* (ReVi Gen)
      carry no declaration at all and are Ritual for reasons that look
      guideline-level — that would be a `ritualRequirement` on the base effect, not
      a declaration. The other 5 of the 7 non-derivable Ritual spells are settled:
      3 became `storyguideRuling` via item 49, and *Rain of Oil* / *Incantation of
      Summoning the Dead* derive independently.
- **Of 39 Ritual-flagged published spells, 32 derive today** from Year duration,
  Boundary target, level > 50, or the Creo+Momentary declaration. Current
  declaration spread in the asset (verified 2026-08-17): 30 `lastingCreation`,
  3 `storyguideRuling`, 292 none.
- **Spec:** `docs/superpowers/specs/2026-07-27-ritual-spells-design.md`

### 50. `size-terram` on an Intellego Spell — Rulebook-Printed Exception to the `excludeTechniques` Rule

Found 2026-08-16 investigating item 19's final-review follow-up (a proposed
corpus-level guard: every selected modifier should be in scope for its own
spell/template). Writing that guard immediately failed on one spell.

- [ ] Decide how to model *Sense the Feet that Tread the Earth* (InTe 30,
      `lib-inte-sense-feet-that-tread-earth`), whose own printed design line —
      "(Base 4, +1 Touch, +1 Conc, +1 Part, +3 size)" (rulebook line 15402) —
      applies a Size magnitude despite being Intellego, contradicting the general
      rule modeled as `excludeTechniques: ["Intellego"]` on every `size-<form>`
      modifier (Core Rules line 12288/23232: "Intellego spells are not affected by
      Target size"). Still true in the asset as of 2026-08-17: the spell selects
      `size-terram-3` at `target-part`.
- **The arithmetic is load-bearing, not incidental.** Base 4 + Touch(1) + Conc(1)
  + Part(1) + size-terram-3(3) = 6 magnitude-units; the first fills the additive
  tier (base 4→5), the remaining 5 apply at ×5: 4+1+25=30, exactly the printed
  level. Without the Size selection it computes to 15.
- **Confirmed narrow, not systemic.** The only other two spells on `inte-4a`
  (*Eyes of the Eons*, *Tracks of the Faerie Glow*) select no modifiers at all;
  across the whole corpus this is the only Intellego spell selecting any
  `size-<form>` modifier.
- **Considered and rejected: item 46's `ExceptionSpell` mechanism.** That exists
  for spells with **no computable arithmetic**. This spell's design line is
  complete, standard-shaped and sums exactly; routing it through `ExceptionSpell`
  would discard a correct breakdown for free text.
- **The real gap: `ModifierScope` has no per-spell granularity.** Its axes are
  technique/form/effectIds/excludeTechniques/excludeTargets — all catalog-level.
  An `effectIds`-based override would open the door for *any* future `inte-4a`
  spell, broader than the evidence supports.
- **The guard test to add once this is resolved** — assertion 8, "every selected
  modifier is in scope for its own spell or template". It was written, verified to
  catch exactly this one case, then reverted rather than committed failing; the
  Dart asset suite currently has assertions 1, 2, 3, 4 and 7 only. Rebuild it as a
  loop over `spell_library.json` + `spell_templates.json` calling
  `modifier.scope.appliesTo(technique:, form:, baseEffectId:, targetId:)` and
  collecting failures.
- **Files:** `lib/models/modifier.dart`, `assets/data/modifiers.json`,
  `test/data/published_spell_import_test.dart`

### 20. Creo Creation `suggested` Ritual Sweep
- [ ] Decide whether every "Create X" guideline should carry
      `RitualRequirement.suggested`, as the Creo healing guidelines now do
- **Rationale:** Core Rules line 12176 — "An item made with Creo only lasts for the
  duration of the spell, unless the spell was a Momentary Ritual" — makes creation
  as much a lasting-thing case as healing.
- **The audit supports leaving it.** Hundreds of entries across ten Forms; the
  checkbox already defaults on for *every* Creo + Momentary draft, and all 32
  derivable Ritual spells derive correctly without it. The flag would add
  explanatory text only.

### 21. Creo Mentem Memory Restoration
- [ ] Decide whether `crme-4b`, `crme-5b` and `crme-10a` ("Restore a memory … to a
      fresh state") are Momentary-Creo-lasting-thing cases
- **Context:** the Ritual sweep's criterion arguably reaches them, but the approved
  scope was Creo *bodily* healing across Animal, Corpus and Herbam, and the
  healing-suspension rule at line 13415 does not cover memory. All three are flagged
  "Variable base level" — **but they are rung entries with real integer levels, not
  General entries, so item 25 does not reach them.**

### 12. Out-of-Scope Effects Handling
- [ ] Create filtering/tagging UI for flagged effects (variable base levels,
      ritual-only, etc.)
- [ ] User guidance: explain which effects don't fit the calculation model yet
- **Re-measure scope before planning.** The audits reduced the original "~200 flagged
  effects" figure to section B's two genuinely uncomputable families, and items 24/25
  have landed since.

### 22. Catalog Extraction Gaps — ✅ effectively closed; one question remains

**Re-verified 2026-08-17 and the checklist is done.** Every row this item listed
as missing now exists in `base_effects.json`, restored by item 34: Creo Animal's
characteristic ladder (`cran-35b` one above average, `cran-45`, `cran-55`) and
maturity ladder (`cran-40b` "in a moment"), `crco-70` "Raise the dead",
`rean-gen` and `reme-G` (the two General wards), and `mute-gen` (earth
elemental). The original list was researched against the 5e core rules, and this
item warned the DE rows might differ — they do, which is why the level→text
pairings above don't match the item's original wording.

- [ ] **One bullet unaccounted for:** Muto Aquam General — *"Convert part of a
      water elemental's body into another type of water"*. `muaq-gen` instead
      reads "Change a liquid into a liquid that does +(Level) points of damage".
      Confirm against the DE's own Muto Aquam table before adding anything;
      `test_general_entries_match_the_rulebook_bullet_for_bullet` passes for Muto
      Aquam in both directions, which is evidence the DE prints only the one
      bullet and the elemental row is a 5e-only artifact.
- **⚠️ If this item ever ends in a rebuild, rebuild from `reviewed/`, not by
  patching a raw-OCR base.** The catalog was extracted from what was
  `raw-md/Ars Magica 5e - Core Rules.md` (since removed upstream; retrievable via
  `git -C <rulebook> show 8b6c4d6^:"raw-md/Ars Magica 5e - Core Rules.md"`), while
  a reviewed Definitive Edition exists. See *Notes* for the source-precedence rule.
  **Any rebuild must reproduce the full catalog and re-run item 34's bullet-count
  comparison first.**

### 23. Ritual Spells Review — Remaining Test-Hygiene Findings
None affect correctness.

- [ ] **A widget test title promises more than it asserts** — one test from the
      Ritual Spells work (`test/presentation/widgets/*` or
      `test/presentation/screens/spell_creation_screen_test.dart`; not pinned down
      further). Find it, then narrow the title or extend the assertions.
- [ ] **The "no accidental Ritual" regression guard only checks
      `ritualDeclaration`**, not a full breakdown recompute — it could miss a case
      where `ritualDeclaration == none` but `RitualStatus`-derived reasons (a
      guideline flag, the >50 threshold) still fire. Assert on a recomputed
      `LevelBreakdown.ritualStatus.isRitual` instead.
- **✅ The JSON formatting bullet is resolved** — regeneration normalized
  `spell_library.json`; all 325 entries share one format (verified 2026-08-17).

### 36. Audit the Catalog's `description` Fields Against the Rulebook
Raised 2026-08-07. One confirmed defect, fixed in `2338430`; the question is how many
more there are.

- **The defect.** `pevi-G2`'s description read *"Dispel specific effect type **with
  Intellego spell** …"*. The rulebook row contains no Intellego at all — the word
  almost certainly bled from the row's first bullet, which does mention Intellego.
- **Why it matters more than a typo.** These descriptions are what the app shows when
  a user picks a guideline, and what an agent reads when resolving a spell. A
  description that misstates its guideline can drive a wrong ledger pick that no test
  can catch — item 32's failure mode.
- **Why existing audits missed it.** Item 34 compared bullet *counts* per
  technique/form/level in both directions and never compared *content*. Counts can
  match perfectly while every description is wrong.
- **Checked so far:** a per-bullet scan for Art names appearing in a description but
  not in its own rulebook bullet, across all General entries — exactly one hit.
  A narrow probe: it catches fabricated Art references and nothing else.
- **Not checked:** the remaining ~560 entries, and every kind of drift that is not an
  Art name — wrong thresholds, dropped conditions, merged clauses, inverted senses.
  `inte-30a`/`inte-30b` are a known benign case of one bullet deliberately split into
  two entries, so a strict one-to-one comparison must tolerate that.
- **Suggested approach:** align each entry to its bullet positionally (the ordering
  already matches — item 34's fix relies on it), then diff the numbers and the modal
  verbs first; those carry the arithmetic.

### 4. Conditional Wards *(the last open piece of the original item 4)*
Display-fidelity work, **not an import blocker** — wards already import and compute
correctly via item 25's General mechanism.

- [ ] Add a ward type field to `BaseEffect`
- [ ] Level threshold: a ward affects creatures whose Might is below the spell's
      level — **display it, do not compute a different level from it**
- [ ] UI section for ward configuration
- **13 published ward spells; 8 are General-level**, and for those the ward threshold
  *is* the chosen level, already supplied by `deriveGeneralEffect`
  (`GeneralEffectKind.mightThreshold`). What remains is the ward-type field and its
  display, not the threshold math.

### 33. Write-Only Columns on the `spells` Table — MAYBE, revisit when relevant
Filed as a *maybe*: nothing is wrong today. Pick this up only when a task lands in
this area — most likely item 9 (tag filtering) or item 7 (backup validation). **Do
not do it on its own.**

- [ ] Decide whether to drop `name`, `source`, `created_at` and `updated_at` from the
      `spells` table, or to start using them
- **What was found** (still true 2026-08-17). `spells` is
  `(id, name, source, data, created_at, updated_at)`, where `data` holds the whole
  serialized `Spell` as JSON. `_toRow` writes both the projected columns *and* the
  blob from the same object, but every read goes through `jsonDecode(row['data'])`
  and every query is either `where: 'id = ?'` or a bare `query('spells')`. Those four
  columns are **write-only duplication**: drift risk, no benefit.
- **The blob is the right design here and should stay.** The table holds **only
  user-created spells** (published ones load from the asset); `Spell` carries four
  nested collections whose normalization means four or five join tables serving
  queries nothing issues; and **the interesting joins are impossible in SQL anyway** —
  `baseEffectId`, `rangeId` and the rest point into JSON assets, not tables.
- **If per-spell predicates ever outgrow Dart-side filtering**, the fix is a generated
  column or an index on a JSON path — not a schema rewrite.
- **Files:** `lib/data/database/app_database.dart`,
  `lib/data/datasources/local_spell_datasource.dart`

### 38. Open Follow-ups from item 25's Whole-Branch Review
None of this blocks anything. Found by an Opus-run multi-angle `code-review --max`
of `feature/general-base-effects`, each finding re-verified against source.

- [ ] **`SpellEngine.allParameters` starts empty and is populated only by a listener
      scoped to the Create screen.** Verified 2026-08-17: `spell_engine.dart:32`
      defaults it to `const []`, filled only via `AvailableParametersSynced` from
      `SpellCreationScreen`'s `BlocListener`. `main.dart`'s `IndexedStack` builds the
      Library tab eagerly at app start, so `SpellLibraryBloc` can call
      `calculateBreakdown` for a saved General ward-type spell before that sync
      lands. Then `_parameterById` returns null and the reference discount is
      silently skipped — the spell is momentarily overcharged, with no error
      surfaced. Not reachable from today's shipped library, but nothing prevents it
      for the first user-saved spell that does. **Fix:** seed `allParameters` from
      `ConfigurationRepository` synchronously in `main.dart`.
- [ ] **Duplicated join/filter logic between `Spell`'s path and `SpellTemplate`'s.**
      All real, none urgent; worth collapsing **before a third catalog-referencing
      record type shows up** (`ExceptionSpell` already made it three):
      - `SpellResolver.resolve`/`resolveAll` vs. `resolveTemplate`/`resolveAllTemplates`
        — identical four-field id lookup, differing only in wrapper type.
      - `SpellLibraryState.visibleSpells`/`visibleTemplates` — identical
        filter-by-source-then-substring pipeline. (Its "My Spells" branch on
        `visibleTemplates` always returning empty is **not** dead code — a template
        is published catalog data and can never be user-created.)
      - `ResolvedSpell`/`ResolvedTemplate` duplicate `isResolved`/
        `unresolvedReferences`/`technique`/`form` and the pass-through getters.
        **Do not merge `problems` into `isResolved` without preserving the compute
        gate** — `isResolved` means "the four catalog ids resolved, so a level can be
        computed at all"; `problems` means it computes but must not be trusted.
        `spell_library_bloc.dart:45` depends on the gate.
      - `emit.py`'s `build_template` mirrors `build_spell` near-verbatim; its own
        docstring says so without factoring the shared part out.
      - `extract_spells.py`'s General branch duplicates the ordinary
        ledger-resolution pipeline below it, and the two have **already drifted**:
        `DESIGN_LINE_INCOMPLETE` exists only on the General side though nothing about
        it is General-specific.
- [ ] **Efficiency, all in the Library-load path, none correctness-affecting.**
      (`AssetDataLoader`'s repeated `spell_templates.json` parse was the third
      sub-problem and is fixed — every asset load is now memoised.)
      - `SpellLibraryBloc._onEvent` (`:36-38`, verified 2026-08-17) awaits
        `getAllSpells()`, `getTemplates()` and `getExceptions()` sequentially, each
        independently calling `LibraryRepository._refreshResolver()` — **three**
        catalog reloads where one would do (item 46 added the third), on **every**
        Library tab visit. `Future.wait` plus one resolver refresh fixes it cheaply.
      - `SpellEngine._parameterById` (`:49-50`) linear-scans instead of using a map,
        unlike `SpellResolver`'s own id maps.
- [ ] **`deriveGeneralEffect` silently returns null when a negative
      `offsetMagnitudes` drives the value below 1**, and `validateSpellDraft` does not
      check this independently of the overall spell level — so such a guideline,
      chosen low enough, saves with a blank effect sentence and no validation error.
      No current catalog entry has a negative `offsetMagnitudes`.
- [ ] **`TemplateInstantiated` silently discards an in-progress, unsaved draft.**
      Deliberate (a stale breakdown must not follow the user into a new spell), but
      there is no confirmation prompt. Worth one if it becomes a reported annoyance.
- [ ] **37 of the 50 General catalog entries omit an explicit `reference` triple**
      (recounted 2026-08-17; was "36 of 49" before item 17 added one more without a
      reference), falling back to `ParameterTriple.standard()` rather than stating it.
      The fallback cannot distinguish "explicitly Personal/Momentary/Individual" from
      "field just wasn't authored". A natural extension of item 32. **One specific
      candidate:** `crvi-G4`'s formula codes `offsetMagnitudes: -1` while its one
      template's verbatim prose (*Restore the Faded Threads*) reads "up to the
      magnitude of this spell –3". Low confidence either is wrong — they may describe
      different quantities — but it is exactly what item 32 exists to check. **That
      template is also one of the three entries carrying an unreviewed candidate
      after item 55's migration, so it wants one re-read, not two.**
- [ ] **Two latent gaps in the Python import pipeline**, neither hit by the current
      corpus:
      - `extract_spells.py`'s General routing (`design.base_level is None or
        block.printed_level is None`) treats *either* side being absent as "General",
        so a spell under a `#### GENERAL` heading whose design line parses a concrete
        numeric base has that number silently discarded.
      - `emit.py`'s `_selected_modifiers` "size" token branch has no
        duplicate-selection guard, unlike the structurally identical
        `elaborate-effect` branch above it, though every `size-<form>` modifier is
        `selectionMode: single`.

### 41. Row-Duplication Ladders Across the Catalog (item 28's shape, elsewhere)

Raised 2026-08-15 when the user asked whether other Technique+Form pairs have the
"separate numbered row per rung" shape item 28 refactored. A systematic scan found
13 more families. **None blocks any corpus spell** — every spell referencing these
rows lands on an exact existing row. The value is item 28's *other* goal:
decluttering the base-effect picker and future-proofing against a spell that needs
an in-between level.

**The refactor pattern to mirror** (from item 28's spec,
`docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md`): delete
the redundant rows, add one `selectionMode: single` ladder modifier (like
`warping-point-burst`/`chill-damage`), then **re-verify every corpus and ledger
reference to the deleted rows** — item 28's Task 1 caught a real near-miss doing
exactly this for `peig-10b`.

| Technique+Form | Rows | Notes |
|---|---|---|
| Creo Ignem damage | `crig-4a/5a/10a/15/20a/25a` | Irregular first step (4→5), matches the book |
| Creo Ignem "unnatural shape" | `crig-5b/10b/20b` | Crossed with the damage axis at the same levels; no level-15 rung in the book |
| Rego Ignem wards-vs-fire | `reig-15b/20/25/30/35/40` | Regular. Distinct from the Rego Ignem fire-intensity modifier |
| Rego Terram hurled projectile | `rete-5d/10/15b` | Regular, book's table stops at 15 |
| Rego Corpus teleport distance | `reco-10d/15d/20a/25a/30/35` | Same rule as `rego-transport-distance`, digitized as rows instead |
| Creo Animal/Corpus/Mentem characteristic increase | `cran-*`, `crco-*`, `crme-*` (6 rows each) | One shared modifier pattern, not three parallel ladders |
| Creo Animal/Corpus Recovery bonus | `cran-1..20b`, `crco-1a..15b` | Two-phase irregular first step in both, matches each Form's table |
| Muto Corpus Soak bonus | `muco-5a/10b/15/20b/25b` | Regular |
| Intellego Vim detect-magnitude threshold | `invi-1a/2a/3a/4a` | Irregular steps (−2,−2,−3), matches the book |
| Creo/Intellego/Muto Imaginem senses | `crim-1..5`, `inim-1a..5`, `muim-1..4` | `muim-5` confirmed a false positive |
| Perdo Vim AC-duration-steps | `pevi-5/10/15/20/25/30` | Regular |
| Creo Vim decay-steps | `crvi-5b/10b/15b` | Item 28's spec explicitly declined to touch this — a conscious prior decision to revisit or reaffirm, not an oversight |

**Confirmed false positives, not part of this list:** wound-severity rows across
every Form, Creo Ignem's light-equivalence rows, Rego Auram's weather-intensity
tiers, Muto Ignem's natural-vs-unnatural rows — each is a qualitatively distinct
guideline, not a hidden numeric ladder.

- **Files:** `assets/data/base_effects.json`, `assets/data/modifiers.json`,
  `assets/data/spell_library.json`, `scripts/spell_import/resolutions.json`

### 42. Derived Ease Factor Display for Poison/Disease Guidelines

Perdo Corpus (disease) and Creo/Muto Aquam (poison) each state a rule like *"Each
magnitude added to the level of the spell adds 3 to the Ease Factor"* — not a
modifier a caster selects, but a **passive consequence of the spell's final
level**, however that level was reached. Modeling it as a `selectionMode: single`
modifier (items 28/41's pattern) would model the wrong mechanism; it's closer to
`effectFormula` (a value derived and displayed, not selected).

- [ ] Decide the display mechanism: likely a read-only derived field shown wherever
      a poison/disease guideline is used, computed as `base Ease Factor + rate ×
      magnitudes above the guideline's own base level` — needs its own design.
- **Only one base effect touches disease today** (`peco-20b`, "Inflict a major
  disease"); Creo/Muto Aquam's poison guidelines already have 5 rows each
  (`craq-5a/10b/15/20/25a`, `muaq-2b/3a/4c/5c/10b`) encoding the wound-severity
  table, separate from this formula.
- **Files:** `lib/engine/spell_engine.dart` (or wherever `effectFormula` is
  rendered), `assets/data/base_effects.json`

### 57. The Remaining 16 Container Rows Still Owe a Static/Dynamic Ruling

**Opened 2026-08-17, split off item 14 on close.** Item 14 backfilled the 8
Circle wards `dynamic` from one shared Magical Wards rationale, and 5 Momentary
container rows are left unset on purpose (the distinction is vacuous when
nothing can enter during a duration that doesn't elapse). The other 16 have no
shared rule to lean on — each needs its own printed description read against
the "Container Targets" sidebar's static/dynamic test.

- [ ] Read each of the 16 rows' printed description and decide static or
      dynamic, citing the specific line that settles it (a shared "container
      target, ward-like" rationale is not enough — item 14's wards case only
      worked because all 8 cite the same rule)
- [ ] Record each ruling in `scripts/spell_import/container_modes.json`,
      the same file the 8 wards used, with a rationale apiece
- [ ] `spellOwesContainerMode` (`lib/models/spell.dart`) is the predicate that
      identifies which spells still need this — a container Target, not
      Momentary, and `containerMode` still `unstated`
- **See also:** item 14 (closed, `## Completed ✅`)

---

## D. Low Priority / Nice-to-Have

### 10. Documentation
- [ ] Update README (see also item 29 — it is still the stock Flutter template)
- [ ] Add a Size feature guide to docs
- [ ] Document the Aquam sub-type limitation (see *Notes*)

### 11. Performance
- [ ] Optimize base effects JSON (609 effects, all loaded at startup)
- [ ] Consider lazy loading or caching if the app grows
- **Re-measure now the library holds 325 spells**, each computing a level on load.
  This item's premise is only now testable. See also item 38's efficiency bullet.

### 56. Rules Hints — What a Choice Means, and Where It Comes From

**Opened 2026-08-17, from item 14's brainstorm.** A general gap, not a bug: the
creation screen offers choices whose rulebook meaning is invisible. The user
sees a name and a magnitude and has to already know the rules. Pure UI work, no
model change, no fidelity risk — deferred on purpose.

**Concrete instances found so far.** These are examples of one need, not
separate items:

- **`target-bloodline` carries a built-in ongoing rule that nothing surfaces.**
  The spell "applies to all members of the bloodline born during its duration,
  as well as those already living when it is cast" (core 10046). A user picking
  it gets no hint. Found while writing item 14's spec, which deliberately does
  *not* give Bloodline a static/dynamic control — the behaviour is the Target's
  own rule, not a per-spell choice, so it is display work and belongs here.
- **Circle's "ends if the circle is broken"** — same class, and it interacts
  with Ring Duration in a way the two dropdowns never show.
- **`requiresVirtue` renders as bare label text** ("Bloodline (+3, requires
  Faerie Magic)") and `requiresRitual` renders as nothing at all in the
  dropdown. Both are informational only — there is no character/Virtue model
  (`parameter.dart:40-44`) — but the *reason* is unexplained.
- **Item 14's segmented control ships its own one-off helper line.** That is the
  first instance of this pattern; if a general mechanism lands, fold it in
  rather than leaving one bespoke explainer behind.

**⚠️ The one decision that stops this being "pure UI."** Where does the hint
text live?
- **UI copy** — hardcoded strings beside each control. Genuinely pure UI, and
  what makes this deferrable, but hand-maintained and unable to cite anything.
- **Catalog data** — a new `Parameter`/`BaseEffect` field, importable and
  citable, but then it needs importer work and an extraction source, and it
  stops being a UI item.

Decide this first when picking the item up; the estimate swings entirely on it.

**⚠️ Citations cannot supply page numbers.** `Citation.page` is null for every
built-in entry and structurally cannot be filled: the reviewed rulebook markdown
carries no page markers, only prose cross-references, and `citation.dart:5-11`
records that an earlier promise to add them "could not be kept." So a hint may
name a **book and a section heading** — the markdown does have headings — never
a page. Do not plan a "see p. 112" affordance.

- **Files:** `lib/presentation/screens/spell_creation_screen.dart`,
  `lib/models/parameter.dart` and `assets/data/parameters.json` (only if the
  catalog-data route wins)

### 58. Container Target Mode — UX Seam Between the Bloc/UI Work and the Derived Predicate

**Opened 2026-08-17, from item 14's whole-branch final review.** Six follow-ups,
none blocking, all polish on the container-mode feature closed as item 14.

- [ ] **`ContainerModeSelected` hides the level breakdown.** It emits
      `status: SpellCreationStatus.editing`
      (`lib/bloc/spell_creation/spell_creation_bloc.dart:170`), and the screen
      gates the results block on `status == calculated`
      (`lib/presentation/screens/spell_creation_screen.dart:81-83`). Picking a
      mode makes the level card vanish and forces a recalculate, for a field
      the design calls level-neutral. **`SummaryChanged` has the identical
      wart** — fix both events together rather than leaving them inconsistent.
      The most user-visible of the six.
- [ ] **The control nudges a decision the model says is not owed.** It renders
      for any container Target (`spell_creation_screen.dart:255`), and on a
      Momentary container spell the helper line still reads "Not recorded… so
      it is worth deciding" (`:819`) even though `spellOwesContainerMode` says
      such a spell owes nothing and the importer deliberately leaves the 5
      Momentary rows unset. ⚠️ The obvious fix — the widget consulting
      `spellOwesContainerMode` — would give that predicate a **production
      caller**, which item 14's design deliberately withheld so it stays the
      hook a future character-library feature flips to a requirement. Needs a
      design decision first, not just a patch.
- [ ] **A user-authored custom Target can never carry a mode.**
      `lib/presentation/screens/configuration_screen.dart:285-291` builds a
      custom `Parameter` with no `targetType`, so the control never appears
      and check 9 would reject a mode on it anyway. Item 14's design cited
      exactly this case as the reason to make the kind catalog data.
      `requiresRitual`, `requiresVirtue` and `scope` are equally unsettable
      there already — fix the family, not just this field.
- [ ] **A latent hole in `_withPrunedFormScopedParameters`**
      (`lib/bloc/spell_creation/spell_creation_bloc.dart:379-388`): it can null
      the target without clearing `containerMode`, so a mode stated under Room
      could survive a Form change and reattach to the next container chosen.
      **Unreachable today** — `duration-fire` is the only Form-scoped
      parameter and no Target is scoped — but the helper is generic and
      `TargetSelected` is currently the only place the mode/Target coupling is
      maintained.
- [ ] **An importer id mismatch aborts before the diagnostics exist.**
      `apply_container_modes` raises at
      `scripts/spell_import/extract_spells.py:919`, before the run's report is
      assembled. If a spell named in `container_modes.json` later falls into
      `blocked`/`unresolved`, the operator sees
      `UnknownContainerModeSpell: names spells no run produced` — wrong in
      that case, since the run did produce the spell, just into another
      bucket — instead of the report explaining why it disappeared. Failing
      loudly is right; failing before the report exists is not.
- [ ] **The ward rationale does not engage the strongest counter-reading.** All
      8 entries in `container_modes.json` cite Core Rules 12166, but 12164
      says a ward's "target is the thing protected, rather than the things
      warded against" and 12168 says such wards "target the circle itself,
      which cannot leave the circle" — a reading under which the Target is
      fixed at casting, i.e. static. The branch's `dynamic` reading is right (a
      static ward would let a demon walk in after casting, contradicting
      12166), but whoever works item 57 will hit this tension on the first
      non-ward Circle spell. One sentence in the shared rationale addressing
      12164/12170 would pre-empt it. See item 57.
- Also worth a line: the segmented control is untested below 1200 logical px —
  `test/presentation/screens/spell_creation_screen_test.dart:143-148` sets a
  1200×5000 view, and the three labels ("Not stated", "Static", "Dynamic")
  will be tight on a 320dp phone.
- **See also:** item 14 (closed, `## Completed ✅`), item 57

---

## Completed ✅

Closed items, reduced to the decisions and constraints that still bind. Follow the
linked spec/plan or git history for detail.

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
stands at 609 today after items 34, 28 and 17.

---

## Notes — standing constraints

**Source of truth for the import:**
`Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md`,
Chapter 9 (lines 12020–16004). One supplement is also in the catalog as of item 17:
*Houses of Hermes: Mystery Cults* (`arm5-hohmc`).

**Source precedence:** the rulebook repo holds the same book in `reviewed/` and `wip/`,
in descending quality. **Always resolve `reviewed` → `wip` and stop at the first hit.**
Filenames differ between folders, so match on book title. (`raw-md/` was unreviewed OCR
and has been removed upstream.) The original base effects came from `raw-md` — item 22
reconciles the two.

**Aquam MVP limitation:** the Aquam Form has 5 distinct base-Individual sub-types
(water/liquids/poisons/blood/wine), each with slightly different guideline
progressions. The Size MVP supports one sub-type per spell via `aquam-base-individual`,
recorded in its base option's `baseIndividual` field. Mixed sub-types within Size
calculations are deferred.

**Prototype, not production:** backwards compatibility is not a goal and the database
is droppable, so a serialized-shape change needs no migration story. Correctness beats
compatibility.

**Verification rule of thumb:** a change to a screen's widget tree is **not** verified
by `flutter test` alone — `flutter test` does not run `integration_test/`, which needs
a device (`flutter test integration_test/... -d windows`). Run both, plus the Python
suite. All three commands and their current results are in *Where the import stands*.
