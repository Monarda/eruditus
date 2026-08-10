# Eruditus Todo List

**Status:** Active development · **Last updated:** 2026-08-09

**Standing goal:** every published spell in the Definitive Edition core rules is
in the spell library, with its computed level matching its printed level.

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

Last extractor run, 2026-08-07 (`python -m scripts.spell_import.extract_spells`):

> **285 imported · 23 emitted as templates · 52 blocked · 0 unresolved**
> — 360 published spells in Chapter 9, all accounted for.

**Before prioritising among items 19/26/28/35/37/39, re-run with
`--show-blocked`.** The per-family breakdown below dates from the 2026-07-28
manual audit and has been partially overtaken; `--show-blocked` prints the
current per-spell reasons and is the authority.

| Blocker family | Spells | Item |
|---|---|---|
| Guideline level absent from the rulebook's own table | 5 | **28** |
| Genuinely ambiguous ledger resolution | 4 | **39** |
| Size ladder above +4 | 4 | **19** |
| Non-standard Range/Duration/Target (mechanism done, spells still blocked) | 6 | **26** |
| General-level, each blocked for an unrelated reason | 10 | see item **25** |
| Unmodelled per-spell mechanisms (no words / no gestures / Techniques and Forms) | 3 | see item **24** |
| No printed design line and no legitimate derivation | 2 | permanent — see item **27** |

**What the goal does and does not cover.** The goal is *computed level matches
printed level*, and the rulebook prints `#### GENERAL` instead of a number for
General-level spells — so a General template **can never satisfy the goal as
stated**. Item 25 solved the modelling (the caster picks a level) and routed those
spells to `spell_templates.json`. Making templates genuinely instantiable is items
35/37's job, and is a different goal from this one. Likewise, Ritual correctness
(item 18) and ward mechanics (item 4) are fidelity work on spells the import
already counts — `extract_spells.py` gates on neither.

**Standing finding: base-effect resolution needs human judgement 186 times.** A
design line names its guideline only by level (`Base level 15`), and e.g. Creo
Animal has four entries at level 15. Of the 324 spells with a numeric base, 133
resolve uniquely, 186 have 2+ candidates, 5 have none. Automated text matching
does not close the 186 — hence the hand-edited ledger (item 27) and the audit
discipline in items 32 and 39.

**Two things confirmed as needing nothing further:**
- **The parameter catalog is complete.** Every Range, Duration and Target used by
  all 360 spells resolves against item 15's 25 entries.
- **The base-effect catalog is near-complete** — 611 entries against the
  Definitive Edition's own bullets, verified per art in both directions by
  `test_general_entries_match_the_rulebook_bullet_for_bullet`. The ~10 known
  missing rows are item 22.

---

## 0. Immediate Program of Work — the `spell.dart` Foundation

**Opened 2026-08-09.** Model work on `lib/models/spell.dart` and its immediate
neighbours. It sits above section A because items 35 and 37 will change the
*serialized shape* of a spell, and every spell imported before that decision has
to be rewritten after it. Deciding first is the cheaper order; it is not new
scope.

Ordered. Each row says what it changes in the model.

| # | Item | Model change |
|---|---|---|
| 1 | **40** | Give the non-prose invariants an enforcement home both construction paths share |
| 2 | **37** + **35** | One `choices` map vs. three more bespoke `chosen*` fields — the decision, then the implementation |
| 3 | **13** | Tighten `validateSpellProse` to user-created spells too (waits on the creation-screen input) |
| 4 | **19** | `ModifierScope` gains a Target restriction — `modifier.dart`, same foundation |
| 5 | **14**, **26** | Confirm *no* model change is needed, before anyone adds a field on assumption |

Items 13, 14, 19, 26, 35 and 37 keep their numbers and live in their own sections;
this table is the ordering, not a second home for them.

### 40. Model Invariants Have Only One Enforcement Path

- [x] **Decide what an invalid spell does — DECIDED 2026-08-09 by the user:
      it blocks.** Rejected at the boundary (save, restore, import) rather than
      degraded into a level-less card the way an *unresolved* spell is.
      **Flagged as revisitable** — the two cases may want to converge later, and
      blocking is the more conservative starting point, not a settled principle.
      Backwards compatibility is not a goal and the DB is droppable, so there is
      deliberately **no migration story** for rows already stored invalid.
- [x] Decide where an invariant that needs *resolved catalog data* is enforced,
      so `Spell.fromMap` and `SpellDraft.toSpell` cannot disagree the way they
      currently can — **DONE 2026-08-09 (Part A of the enforcement-path plan,
      `docs/superpowers/plans/2026-08-09-spell-invariant-enforcement.md`).**
      `SpellResolver`/`ResolvedSpell` (`lib/data/spell_resolver.dart`,
      `lib/models/resolved_spell.dart`) is the enforcement home, mirroring
      `validateSpellProse` one layer down: a shared `validateSpellAgainstCatalog`
      function (`lib/models/spell.dart`) is the one enforcement path, called from
      `ResolvedSpell.problems` and from `SpellEngine.validateSpellDraft`, and
      `SpellRepository` (`lib/data/repositories/spell_repository.dart`) validates
      through it before every write. Two spec refinements made during planning:
      the validator takes an `isTemplate` flag (templates skip the "General
      needs a chosen level" and "chosen level present" checks, which don't apply
      to a record whose whole purpose is to have its level supplied later); and
      `modifiers` is now a **required** catalog on `SpellResolver` but stays
      **defaulted** on `ResolvedSpell`, so existing test/call sites that
      construct a `ResolvedSpell` without needing validation are unaffected.
- [x] Apply the answer to the three catalog-dependent invariants below —
      **DONE 2026-08-09.** All three (General ⇒ chosen level, duplicate/self
      requisite art, single-selection-mode modifier cardinality) are now among
      `validateSpellAgainstCatalog`'s 5 checks. One suppression rule needed a
      human ruling: the plan's own literal spec and its own test contradicted
      each other on duplicate-art vs. self-matching-Technique/Form, settled as
      check 3 (self-match) suppressed when an art is already flagged as a
      duplicate by check 4. `SpellEngine.validateSpellDraft`
      (`lib/engine/spell_engine.dart`) now delegates to the shared validator
      instead of its own separate checks, and `ResolvedSpell` gained a
      `problems` field (`lib/models/resolved_spell.dart`) surfacing the
      validator's output — deliberately *not* collapsed into `isResolved`:
      `isResolved` stays a can-I-compute gate, `problems` means it computes but
      must not be trusted. `SpellRepository.saveSpell`/`updateSpell` throw
      `InvalidSpellException` (new: `lib/models/invalid_spell_exception.dart`)
      on an invalid write; the new `saveAll` reports rejects instead of
      throwing, used by `BackupService.importFromJson` so one bad spell in a
      restore doesn't abort the rest. **Remaining open checkbox below (the
      `requisites` reshape, Part B) is out of scope for this plan.**
- [x] Reshape `requisites` from `List<Requisite>` to a map keyed by art —
      **the one invariant fixed by modelling rather than validation.** Duplicate
      arts are representable only because the field is a list; a map makes them
      unrepresentable, needing no validator, no enforcement point and no test.
      **DONE 2026-08-10 (Part B of the requisites reshape, completed via Task 3
      of the plan).** The Dart model was reshaped in Task 1, the Python importer
      and regenerated JSON assets in Task 2, and both test suites confirmed
      together in Task 3.
- [x] Add a build-time assertion over `spell_library.json` for the three
      catalog-dependent invariants — **assertion 7**, alongside the four in
      `test/data/published_spell_import_test.dart`. A violation in the asset is a
      build-time importer bug, identical for every user and unfixable by them;
      with blocking as the runtime behaviour, this test is what stops a broken
      library tab shipping. Measured 2026-08-09: 0 violations across all 294
      spells, so it goes green on the day it lands and stands as a regression
      guard thereafter. **DONE 2026-08-09** — landed in
      `test/data/published_spell_import_test.dart`, asserting
      `validateSpellAgainstCatalog` reports zero problems across all 294
      published spells and 23 templates; green as predicted.
- [ ] **Surface `ResolvedSpell.problems` in the Library card — the "degrading"
      half of the blocking-vs-degrading decision has no UI yet.** Flagged by
      Part A's final whole-branch review (2026-08-09,
      `.superpowers/sdd/2026-08-09-spell-invariant-enforcement/final-review-report.md`,
      finding M4). The design doc named "Library renders an invalid card" as
      `problems`' consumer, but no task in the plan added that UI, so a spell
      that becomes invalid *after* being written (write-time blocking cannot
      cover this — only a later catalog change can) is currently invisible:
      `problems` is computed and correct but has no visible effect anywhere in
      the app. Not a defect in what shipped — a plan-scope gap worth tracking
      so it isn't silently dropped when Part B closes this item.

**What is true today.** `validateSpellProse` (`spell.dart:24-36`) exists precisely
so the two construction paths cannot drift, and it is called from the `Spell`
constructor, so both paths get it. **Three further invariants got no such
treatment** — they live only in `SpellEngine.validateSpellDraft`, reachable only
from the creation screen:

- General guideline ⇒ `chosenBaseLevel` present and `>= 1` (`spell_engine.dart:67-73`)
- no duplicate requisite art; no requisite equal to the spell's own Technique or
  Form (`spell_engine.dart:88-97`)
- a `selectionMode: single` modifier carries at most one option (`spell_engine.dart:99-105`)

`Spell.fromMap` (`spell.dart:132-164`) applies none of the three, so a hand-edited
asset, a restored backup, or an importer bug produces a `Spell` that constructs
cleanly and is wrong.

**The failure is silent, by two decisions that are each correct alone.**
`calculateBreakdown` throws `ArgumentError` on a General spell with no chosen
level (`spell_engine.dart:149-155`), and `SpellLibraryBloc` catches per spell and
`continue`s (`spell_library_bloc.dart:53-65`) so one bad row cannot redden the
whole tab. Together: a card renders with no level and no error anywhere.

**Why this cannot simply move into the constructor.** `Spell` deliberately holds
`baseEffectId`, not `BaseEffect` (`spell.dart:38-43`: "this record deliberately
holds no copy of any catalog data"). It cannot see `isGeneral`, so the invariant
is **uncheckable at the model boundary by construction**. The enforcement home
must be somewhere holding both the record and the catalog —
`SpellResolver`/`ResolvedSpell` is the natural candidate, mirroring what
`validateSpellProse` does one layer down. **That choice is the work here.**

**Measured 2026-08-09 — latent, not live.** All 294 spells in
`assets/data/spell_library.json`, scanned against `base_effects.json` and
`modifiers.json`: **0 violations**. So this is foundation work, not a bug fix.
Note the General invariant is currently unreachable from published data at all —
`spell_library.json` holds zero `chosenBaseLevel` keys (item 25 routed General
published spells to `spell_templates.json`, and `SpellTemplate` has no such field,
asserted by `spell_template_test.dart:30`). Only a user-created spell or a
restored backup can carry one, which is exactly the path with no asset test over
it.

Items 35/37 add up to three more caster-supplied slots with the same "valid only
against the resolved guideline" character. Settling the home now gives them
somewhere to put their validation; settling it later retrofits four slots instead
of one. Same shape as item 32 one layer down: checks that pass by construction,
correctness resting elsewhere.

- **Files:** `lib/models/spell.dart`, `lib/models/resolved_spell.dart`,
  `lib/engine/spell_engine.dart`, `lib/models/spell_template.dart`

---

## A. Blocks the Library Import

### 28. Guideline Levels Absent from the Rulebook's Own Table

- [ ] Decide how to handle spells citing a base-effect level the table does not
      list, but which is **recoverable from documented prose rules**

**5 published spells.** All recoverable; none genuinely missing:

- *Infernal Smoke of Death* (MuAu 40) — MuAu General "Transform air into a gas
  doing +**level** damage" at +25 damage; base = 25
- *Fog of Confusion* (MuAu 45) — MuAu base 3 plus the Muto Auram prose rule
  "Transforming only one property of air generally lowers the level by one
  magnitude"; base = 3 − 1 = 2
- *Wizard's Icy Grip* (PeIg 30) — Perdo Ignem damage-scaling rule (prose above the
  table); base derived from +20 damage
- *The Enigma's Gift* (CrVi 30) — base 20 (prose rule TBD)
- *Sense of the Lingering Magic* (InVi 30) — base 10 (prose rule TBD)

**Options:**
1. Add the 5 derived rows to the catalog with notes recording their prose rules
   (simplest and most maintainable; the catalog is already extracted, not printed,
   data)
2. Model the prose rules in the modifier system (generalises; needs real design)
3. Let item 24's ad-hoc adjustments absorb the difference from the nearest printed
   rung (works, but less transparent about the rule)

Options 1 and 3 unblock all 5; option 2 also documents the rules for reuse.

**This is not item 22.** Item 22 is rows genuinely absent from the Definitive
Edition. These 5 are derivable from stated prose. These are exactly the 5 "zero
base-effect candidates" spells the harness reports.

### 39. Ambiguous Ledger Resolutions Needing a Rules Decision

- [ ] Decide each of the 4 spells below against a reading its own candidate
      guidelines textually **force** — not "the most general-sounding" one — and
      record the rationale in `resolutions.json`

**4 published spells** have 2-3 candidates at their computed level, with no catalog
gap and no missing data; the ambiguity is in the rulebook prose. Each was resolved
once during item 27, then pulled when review found the rationale was picking the
most general-sounding candidate rather than a forced one:

- *Tracks of the Faerie Glow* (`lib-inte-tracks-faerie-glow`) — `inte-4a` vs `inte-4b`
- *Sense the Feet that Thread the Earth* (`lib-inte-sense-feet-that-thread-earth`)
  — same pair, same shape
- *Crystal Dart* (`lib-mute-crystal-dart`) — `mute-3a`/`3b`/`3c`, stone-vs-crystal
  boundary
- *Conjuration of the Indubitable Cold* (`lib-peig-conjuration-indubitable-cold`)
  — `peig-4a`/`4b`/`4c`, three co-equally-supported readings

**Different from item 28**, not a duplicate: there the correct row is missing and
needs adding; here every candidate already exists and is individually plausible,
and the work is close reading. **Not a harness blocker** — `KNOWN_UNRESOLVABLE` in
`extract_spells.py` routes all 4 to `blocked` rather than `unresolved`.

**See also item 32**, which applies the same discipline to entries that *did* make
it into the ledger.

- **Files:** `scripts/spell_import/resolutions.json`

### 26. Non-standard Ranges, Durations and Targets — mechanism DECIDED, spells still blocked

**Decided:** covered by item 24's adjustments; no `Special` parameters were added.
`designline.ADJUSTMENT_LABELS` carries `Special (based on Concentration)`,
`Special (equivalent to Boundary)` and `Special based on Mom`, matched on the
token's *bracketed* text rather than the bare word `Special`, because the corpus
hides two different mechanisms (a nonstandard Duration and a nonstandard Target)
behind that one word.

**In section 0 only as a "confirm no model change" check.** `rangeId` /
`durationId` / `targetId` are `required String` catalog ids, so a `Special`
Duration looks like a model gap. It is not: the recommended fix — resolve `Special`
to the parameter the adjustment is "based on" — is a `parameters.json` entry plus
importer work, with `spell.dart` untouched.

**None of the six import yet, each for a second reason:**

- [ ] **A `Special` Duration has nothing to resolve to.** `D: Spec` / `D: Special`
      is not in `parameters.json`, so `emit._parameter_name` raises. Most likely
      answer: the parameter the adjustment is "based on", read off the adjustment's
      own note. Affects *Wind at the Back*, *Trackless Step*
      (`+2 Special (based on Concentration)`), *The Earth Split Asunder*
      (`+1 Special based on Mom`), and *Watching Ward* (`Duration is non-standard`,
      numberless; General-level, so item 25 no longer blocks it — this item is its
      sole blocker). *Trackless Step* has a ledger entry, `rete-2b`.
- [ ] *The Bountiful Feast* (`+4 Special (equivalent to Boundary)`) — allow-listed,
      but the same design line has unbalanced brackets so the later `+1 Size (for a
      total of ...` token never closes. **A splitter fix — see item 29's
      `_split_parts` bullet, which should fix this and the `;` case in one pass.**
- **Deliberately left blocked:** *Mists of Change* prints `D: Sun & Year`. Two
  durations in one stat line contradicts item 1's rules-correct one-Duration
  invariant; it also prints a numberless "slightly nonstandard effect". **Do not
  weaken the model for one spell.**

- **Spec/Plan:** `docs/superpowers/specs/2026-08-04-level-adjustments-design.md`,
  `docs/superpowers/plans/2026-08-04-level-adjustments.md`

### 19. Size-Ladder Ceiling

**Its architecture half is in section 0** — the `ModifierScope` Target restriction
is model work on `modifier.dart`, the same foundation as item 40. The +5 rung is
ordinary data work and does not need to travel with it.

- [ ] Every Size ladder in `modifiers.json` stops at +4 (×10,000); 4 published
      spells need +5
- [ ] Decide: add one rung, or make the ladder open-ended? The rulebook's rule is
      `+1 magnitude = ×10 size` with **no stated ceiling**, so the ceiling is an
      artifact of the MVP, not of the rules
- [ ] Add a Target restriction to `ModifierScope` (`excludeTargets` or
      `allowedTargets`) and check it in `appliesTo()` alongside the existing
      technique/form/effectIds checks

**The 4 blocked spells:** *Wrath of Whirling Winds and Water* (CrAu 40), *Rain of
Oil* (MuAu 50), *Curse of the Haunted Forest* (MuHe 40), *Poisoning the Will*
(PeMe 40).

**⚠️ Mentem's Size exemption is narrower than the code enforces.** Definitive
Edition line 14900: "Minds do not have a size, so size modifiers do not apply to
Mentem effects with **Individual targets**. However, minds can be counted, so for
Groups you still need to boost the size to affect more people."

- **Verified 2026-08-09:** the `size-mentem` modifier correctly exists in the data
  and the test, because Mentem *can* take Size for Group/Room/Structure/Boundary
  targets. The published spell import test expects it.
- **The gap is architectural:** `ModifierScope` has no Target field, so
  `size-mentem` applies to all Mentem spells. Its description says "Applies when
  targeting multiple minds via area targets", but nothing enforces that — a user
  could apply it to an Individual Mentem spell.
- **For now:** item 24's adjustments can absorb any difference on *Poisoning the
  Will*; its Boundary target makes it ineligible for scoped sizing under the
  current architecture anyway.

**Related deferred work:** the Spell Modifiers spec deferred sizing for Part,
Group, Room, Structure and Boundary targets entirely (its ladders assume
Individual). *Poisoning the Will* is the first published spell to need it.

### 29. Open Follow-ups from the Import-Harness Review

Genuine findings from item 27's merge-readiness review. None blocked that merge;
all concern future safety or clarity. The cheap high-value ones were fixed at the
time; what remains needs design judgement or more time.

- [ ] **Decide on the ledger's "explicit override" promise.** The spec says an
      entry disagreeing with an unambiguous spell's sole candidate is valid "as an
      explicit override, which needs a rationale like any other decision" — but
      `ledger.py`'s `resolve()` has no path where that succeeds; it always raises
      `StaleEntry`. The `UnnecessaryEntry` message was corrected to stop promising
      the impossible; the decision — implement the override, or drop the promise
      from the spec — is open.
- [ ] **Fix `designline._split_parts` for both malformed design lines in one pass.**
      - *Ball of Abysmal Flame* prints `(Base 25, +2 Voice; the ball appearing to
        shoot from your hand is a cosmetic effect)` — a semicolon where every other
        spell uses a comma, so the magnitude is never separated from the trailing
        prose and the whole thing fails `_TOKEN`. Splitting on `;` at depth 0
        alongside `,` and `.` is the obvious fix; **check the corpus for a `;` that
        is not a token boundary before making it unconditional.**
      - *The Bountiful Feast*'s unbalanced brackets (item 26). Same function, same
        shape, one spell each.
- [ ] **Add the 3 missing modifiers to `modifiers.json`** — Creo Aquam unnatural
      liquids, Creo Herbam treatment, Perdo Herbam live wood. Found by a
      preamble-vs-catalog-vs-`emit.py` audit on 2026-08-07 (full report in
      scratchpad). That audit also confirmed 9 modifiers systematically wired, 2
      wired that session (Creo Auram unnatural, Terram materials), and 2 wired but
      not yet unblocking any spell (`aquam-base-individual`,
      `rego-transport-distance`).
- [ ] **Extend `emit.build_spell`'s modifier mapping to `rego-transport-distance`.**
      `_selected_modifiers` maps only `size`-kind tokens to `modifiers.json` today.
      `rego-transport-distance` is already scoped in `modifiers.json` to exactly
      `rete-4` / `rehe-10b` / `reig-3c`. This is what would unblock *Hermes' Portal*
      (see item 27). **Expect
      `HandDerivedTest.test_the_two_non_derivable_spells_stay_correctly_blocked` to
      start failing on purpose, and update it** — do not be surprised by it.
- [ ] **Collapse the duplicated level sum in `asset_data_loader_test.dart`.** Its
      "every loaded spell calculates to the level stated in its description" builds
      its own magnitude list rather than calling `SpellEngine.calculateBreakdown`,
      and item 24 had to add `spell.adjustments` to it. Two hand-maintained copies
      of the same sum will drift again; `published_spell_import_test.dart`'s
      assertion 1 already calls the engine.
- [ ] **`catalog._STOPWORDS` still contains `"phantasm"`,** a content word, not a
      stopword. **No longer a harmless no-op:** three Phantasm spells now import
      with it stripped from their ids — `lib-crim-human-form` and
      `lib-crim-talking-head` both lost it; `lib-crim-phantasmal-animal` kept it
      only because "Phantasmal" is not the listed token. Removing it would rename
      two committed ids, so this is an asset change with migration weight.
- [ ] `README.md` is still the stock Flutter template and never mentions
      `scripts/spell_import/`.

**CI notes that bind — read before touching the workflows.**

- Two workflows answer deliberately different questions.
  `.github/workflows/tests.yml` runs on push to `main` and every PR, **pinned**: it
  reads the rulebook revision from `source.lock` and clones the rulebook at exactly
  that commit, so upstream churn can never redden a PR. It runs `python -m unittest
  discover` **and `flutter test`** — the Dart half is the point, since a regression
  reintroducing the `selectedModifiers: {}` bug passes every Python test and only
  the Dart-side assertion 1 catches it. `.github/workflows/rulebook-freshness.yml`
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
rulebook itself does. **Why these two are together:** both read the *final computed
level* and produce a different quantity from it — a genuinely different shape from
`option → magnitude`, and the point the Spell Modifiers spec identified as where a
code seam earns its place.

### 4b. Intensity/Damage Modifiers
- [ ] Muto/Perdo Ignem: add 1 magnitude per 5 points fire damage exceeds +5
- **Only 1 published spell touches this in a design line** — *Ward against Heat and
  Flames* (`+2 for up to +15 damage`), which item 24 already expresses.
- **Item 25 retired the General-row half.** `GeneralEffectKind.damage` covers the
  General catalog entries whose output depends on the chosen level; what remains is
  non-General, fixed-base fire damage.

### 4c. Level-Dependent Might Reduction
- [ ] Muto/Perdo Ignem/Auram: elemental Might reduced by spell level
- [ ] Note that Might reduction = spell **level**, not magnitude
- **No published spell's level depends on this** — it describes runtime effect, not
  cost. Display concern only.
- **Item 25 retired the General-row half** — `GeneralEffectKind.mightReduction`
  reads the chosen level and prints it (`spell_engine.dart:425`).

### 31. Real Per-Spell Summaries — Ledger-Authored
- [ ] Author real per-spell summaries into a committed ledger keyed by spell id —
      the same pattern as `resolutions.json`, because the extractor is
      deterministic stdlib Python and cannot summarise prose
- **Why:** summaries are currently the description truncated to 400 characters,
  which duplicates the description rather than summarising it.
- **Deferred by the human partner** until all core-rulebook spells import, so the
  work is done once against the full set.
- **Do the `" Level N."` suffix removal at the same time.** It is vestigial —
  nothing in the repo reads `RegExp(r'Level (\d+)\.$')` anymore; both former readers
  now use the typed `printedLevel` field. Removing it from `emit._summary` rewrites
  every summary, which is why it waits for this item rather than for a code
  dependency.
- **Files:** `scripts/spell_import/emit.py` (`_summary`), a new summary ledger
  alongside `scripts/spell_import/resolutions.json`,
  `assets/data/spell_library.json`

### 32. Audit `resolutions.json` — no Test Can Check It
- [ ] Re-read every entry against its spell's published text and its candidate
      guidelines' wording
- [ ] Consider recording, per entry, whether its candidates differ in base level —
      the ones that do not are the entries carrying all the risk
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
  more. Those entries rest entirely on their written rationale. True of all seven
  entries added for the level-adjustments branch, by construction.
- **The same holds for every General entry, for a related reason.** A General base
  effect has no fixed level to check against — `chosenBaseLevel` comes from the
  caster — so assertion 1 cannot discriminate a wrong General guideline at all.
  Assertion 6 is the only automated check standing between an entry and a wrong
  General pick; every General entry rests on its rationale plus assertion 6.
- **Files:** `scripts/spell_import/resolutions.json`

---

## C. Not on the Critical Path

Real work, none of it blocking the import.

### 6. Real Bloc Hang in Widget Tests — and the coverage hole it creates
- [ ] Document the workaround: mock Blocs in widget tests, use `integration_test/`
      for real E2E
- [ ] Create a widget test helper with mock bloc factories
- [ ] **Run integration tests as part of verification, not just `flutter test`**
- [ ] Consider one script/alias running both suites, so "tests pass" means both
- **Context:** a real Bloc hangs forever under flutter_tester; known Bloc limitation.
- **Two failures already traced to this:**
  1. `flutter test` does **not** run `integration_test/` — those need a device
     (`flutter test integration_test/... -d windows`), so the suite rots silently. A
     broken end-to-end test went unnoticed across several "suite is green" checks
     because the file simply never ran.
  2. **Mocked blocs cannot catch re-render bugs.** A mock emits no new state, so the
     rebuild after an interaction never happens. The add-requisite crash
     (`DropdownButtonFormField` holding a value no longer in its `items`) was
     invisible to 6 passing widget tests for exactly this reason. When the failure
     mode *is* "what happens on re-render", drive states through a
     `StreamController` on the mock, or cover it in `integration_test/`.
- **⚠️ The suite is red right now — 2 of 5 fail** (found 2026-08-06):
  - `spell_creation_flow_test.dart:179` — "end-to-end: create a spell matching an
    existing Technique+Form, see suggestions, save it, and find it in the library"
  - `spell_creation_flow_test.dart:537` — "end-to-end: a spell built on a custom
    effect stays listed and marked unavailable after that effect is deleted"

  Both are `StateError: Bad state: No element` inside
  `WidgetController.dragUntilVisible` / `scrollUntilVisible` — the finder cannot
  locate the widget it is asked to scroll to. Most likely environment-dependent
  (window size, DPI or font metrics on this Windows runner), but unconfirmed.
  **Not caused by the General base effects branch** — verified by running the
  identical command in throwaway worktrees at `b901c09` and `6d84a14`: same two
  tests, same traces, same 3-pass/2-fail split at all three commits.
  **Fix these before adding to the suite** — a red suite cannot tell anyone their
  change broke something, which is how it rotted twice.
- **Files:** test helpers, widget test templates, `integration_test/`

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells conform to the one-Range/Duration/Target constraint
- [ ] Add migration for legacy spell saves (if any)
- [x] Test backup round-trip (export → import)
- [x] **Known gap — CLOSED 2026-08-09 by item 40's Part A plan (Task 7),
      `docs/superpowers/plans/2026-08-09-spell-invariant-enforcement.md`.**
      `test/data/services/backup_service_test.dart`'s "backup round-trip" now
      calls through the real `BackupService.exportToJson`/`importFromJson`
      instead of duplicating `spell_test.dart`'s serialization round-trip. The
      same task also reordered `BackupService.importFromJson` to import custom
      effects and parameters before spells (so a spell built on a custom effect
      from the same backup isn't wrongly rejected) and switched it to
      `SpellRepository.saveAll`, so one invalid spell no longer aborts the whole
      restore; `BackupImportResult` gained `rejectedSpells`/`spellsRejected`,
      surfaced in the backup screen's status message.
- [ ] **Custom modifiers are absent from backup entirely.** Flagged by Part
      A's final whole-branch review (2026-08-09,
      `.superpowers/sdd/2026-08-09-spell-invariant-enforcement/final-review-report.md`,
      recommendation 3). `BackupService.exportToJson` carries only
      `customEffects` and `customParameters` — no `customModifiers`. This now
      interacts with item 40's validation: a restored spell that selected a
      custom modifier resolves to nothing on import (the modifier id isn't in
      the catalog), so check 5 (single-selection cardinality) is silently
      skipped for it and the spell imports unvalidated on that axis.
      Consistent with the existing "unknown modifier id is tolerated"
      constraint — **not a regression** — but the backup gap itself should be
      closed alongside the rest of this item.

### 9. Spell Tags / Library Organisation — half done
- [x] `tags` field on the Spell model — landed in commit `c4242d6`; `Spell.tags` is
      a `List<String>`, serialized and persisted
- [ ] Assign tags when creating or editing a spell
- [ ] Filter/browse the library by tag
- [ ] Support multiple tags per spell, and combine tag filters with the existing
      search + source filters
- [ ] Decide: free-text, a curated vocabulary, or free-text with suggestions from
      existing tags
- **Model and persistence are done — what remains is purely UI.** No schema change
  needed, contrary to this item's original wording.
- **Rationale:** thematic grouping the Technique/Form axes can't express. A spell
  that raises a castle is both "defensive" and "architecture"; neither is derivable
  from Creo/Terram. Value rises sharply now the library holds 285+ spells rather
  than 36.
- **Files:** `lib/presentation/screens/spell_library_screen.dart` (tag filter UI),
  `lib/presentation/screens/spell_creation_screen.dart` (tag entry),
  `lib/bloc/spell_library/` (filter events/state)

### 13. Summary/Description Entry for User-Created Spells
**In section 0** — the smallest item in it: `validateSpellProse` is already the
correctly-shared validator, so the model change is deleting one
`source == PublicationSource.published` guard (`spell.dart:32`). Gated on the UI
input landing first.

- [ ] Add a summary input (and optionally a description input) to the creation screen
- [ ] Carry the text on the save event so it reaches `SpellDraft` → `Spell`
- [ ] Tighten the summary-or-description invariant to apply to **both** sources
- [ ] Update the invariant tests and the spec's "interim" note
- **Why user-created spells are exempt today:** the Spell Provenance work split
  `description` into `summary` (paraphrase) and `description` (verbatim rulebook
  text) and required at least one on published spells. The creation screen collects
  nothing but a name — `SpellSaveRequested(name)` carries no prose — so an
  unconditional rule would have rejected every user-created spell on save.
- **The model is already ready.** `SpellDraft` carries both and `toSpell` passes
  both through. Purely presentational: an input widget plus an event.
- **Files:** `lib/presentation/screens/spell_creation_screen.dart`,
  `lib/bloc/spell_creation/spell_creation_event.dart`,
  `lib/bloc/spell_creation/spell_creation_bloc.dart`, `lib/models/spell.dart`
- **Spec:** `docs/superpowers/specs/2026-07-27-spell-provenance-and-tags-design.md`

### 14. Container Targets: At-Casting vs. Subsequently-Entering
**In section 0 only as a "confirm no model change" check.** Read the rulebook's
"Ranges, Durations, Targets" and "Magical Wards" sections and settle the ⚠️ note
below **before anyone adds a field on the assumption that a user-facing choice is
needed.**

- [ ] Model whether a container-target spell affects only what is inside **at the
      moment of casting**, or also whatever **enters later**
- [ ] Expose the choice in the UI, only when the selected Target is a container
- [ ] Validate the choice is absent for non-container targets
- [ ] Decide whether it affects the calculated level, or is purely descriptive
- **Rationale:** the two readings are different spells. A Room-target spell that
  cleanses everyone present is not the same as one that cleanses everyone who walks
  in for the rest of its Duration. Nothing records which was meant.
- **Container targets today:** `target-room` (+2), `target-structure` (+3),
  `target-boundary` (+4), `target-circle` (+0).
- **⚠️ The rulebook may already answer this, collapsing the whole item.** ArM5 core
  defines the behaviour *per target*:
  - **Group:** "The things in the Group when the spell is cast are affected for the
    entire duration, even if they split up. Things that join the Group during the
    spell duration are **not** affected." — fixed at casting, stated outright.
  - **Circle:** a ward "prevent[s] things warded against that are within the circle
    from leaving, and prevent[s] things warded against that are outside from
    **entering**." — explicitly ongoing.
  - Room, Structure and Boundary are defined spatially without settling it.

  So this may be a **property of the Target parameter** — a `parameters.json`
  annotation plus display, with no `Spell` field, no schema bump and no UI control
  at all. If only Room/Structure/Boundary are genuinely ambiguous, scope shrinks to
  those three.
- **No published core spell is blocked by this** — a fidelity improvement.
- **Open design questions:** boolean or enum (`atCasting`/`ongoing`)? On `Spell`
  directly, or as a property of the target selection (tidier, but there is no
  "target selection" object — the spell holds a bare `targetId`)? Is it implied by
  the Target/Duration pairing (Circle+Ring implying ongoing), and therefore
  derivable rather than stored? Storing derivable data is exactly what the
  id-reference normalization removed.
- **Files:** `lib/models/spell.dart`, `assets/data/parameters.json`,
  `lib/presentation/screens/spell_creation_screen.dart`,
  `lib/bloc/spell_creation/`, `lib/data/database/app_database.dart` (if stored)

### 16. Short Forms for Parameter Names
- [ ] Decide whether parameters need a short display form at all — **confirm a real
      layout is constrained before building anything**
- [ ] If so, add an optional `shortName` to `Parameter`, falling back to `name`
- [ ] Add a small widget picking the longest form that fits the available width
- **Check the need first.** These names appear mostly in dropdowns, where width is
  rarely tight and substituting text makes selection confusing. More likely
  candidates are the spell card or the level-breakdown chips — measure first. **The
  rulebook itself abbreviates in exactly one place: the spell stat line
  (`R: Touch, D: Sun, T: Ind`).** If the app ever renders that line, that is the
  constrained widget.
- **Do NOT encode alternatives as inline markup** (e.g. `"B/ound/ary"`):
  presentation inside domain data means search, comparison, backup export and tests
  must all strip markup first, and one missed call site shows a user `B/ound/ary` in
  an exported file; it can only express prefix truncation ("Arcane Connection" →
  "Arc" works, → "AC" does not); and **`/` already means something else here** — the
  rulebook uses it for equal-difficulty pairings (`Touch/Eye`, `Sun/Ring`,
  `Group/Room`, `Individual/Circle`).
- **Precedent:** `Book` carries `title` *and* `abbreviation` as separate fields. The
  wider precedent is CLDR, which models wide/abbreviated/narrow as named forms,
  never as markup.
- **Flutter has no built-in string-alternatives system.** `FittedBox` scales glyphs;
  `TextOverflow.ellipsis` truncates crudely; `auto_size_text` is third-party and
  shrinks the font. The real mechanism is `LayoutBuilder` + `TextPainter`
  measurement with your own selection logic.
- **Note:** `Bound` → `Boundary` was a *data error* fixed by item 15, not evidence
  that abbreviations are needed.
- **Files:** `lib/models/parameter.dart`, `assets/data/parameters.json`

### 17. Virtue-Gated Parameters: Merinita Faerie Magic and Symbolic Magic
**Blocked on one model gap: there is no way to record that a parameter requires a
specific Mystery Virtue** — which implies a character/Virtue model the app does not
have at all (it models spells and catalog data, no characters). **Do not attempt
this until the Virtue-gating mechanism exists.** The ritual-only half is already
done (`Parameter.requiresRitual`, item 4).

**Not a blocker for the core-rules import** — no core spell uses these parameters,
by definition. Relevant only when supplement spells are added.

- [ ] Add a `requiresVirtue`-style field once a Virtue-gating mechanism is designed
- [ ] Add the 6 Faerie Magic parameters below
- [ ] Add the 3 Symbolic Magic parameters below

**Merinita: Faerie Magic** — Core Rules, "Mysteries" chapter (not *Houses of Hermes:
Mystery Cults*, where the rest of the House's content lives). Initiates of the
Faerie Magic Outer Mystery only:

| Name | Type | Level | Note |
|---|---|---|---|
| Road | Range | = Voice | affects anyone/anything on the same road or path |
| Bargain | Duration | = Year + 3 magnitudes | ritual; enforces a bargain, max Year once triggered |
| Fire | Duration | = Moon | Ignem/Imaginem only; lasts until the targeted fire goes out |
| Until (Condition) | Duration | = Year | ritual; lasts until a specified condition is met |
| Year + 1 | Duration | = Year | ritual; a year and a day, by elapsed time not season |
| Bloodline | Target | = Structure | affects all blood descendants of the immediate target |

**Symbolic Magic** — *Houses of Hermes: Mystery Cults*, House Merinita chapter.
Initiates of the Symbolic Magic Major Folk Mystery. All three are always ritual and
require a physical symbolic charm representing the target, built from at least 3
charms (9 for using all three together):

| Name | Type | Level | Note |
|---|---|---|---|
| Symbol | Range | = Arcane Connection | affects anything the symbol uniquely identifies |
| Symbol | Duration | = Year | lasts as long as the physical symbol survives intact |
| Symbol | Target | = Boundary | affects everything the symbol represents, within range |

- **Files:** `lib/models/parameter.dart`, `assets/data/parameters.json`
- **Spec:** `docs/superpowers/specs/2026-07-27-parameters-and-provenance-design.md`
  ("Deferred Work")

### 18. Storyguide-Ruling UI for Rituals
Fidelity work on already-imported spells, **not an import blocker** — nothing in
`extract_spells.py` gates on Ritual correctness, so these 7 spells import or
template today, just with an incomplete `RitualDeclaration`.

- [ ] Expose `RitualDeclaration.storyguideRuling`, which the model supports and
      three built-in spells already use, but no control sets
- [ ] Revisit `SpellCreationBloc._withRitualDeclaration` so the two declaration
      kinds stay distinguishable once both are user-settable
- **Rationale:** Core Rules line 12352 lets the troupe declare any spell a Ritual.
  The Creo+Momentary-only checkbox cannot express that.
- **The 7 non-derivable Ritual spells** (of 39 Ritual-flagged published spells, 32
  derive today from Year duration, Boundary target, level > 50, or the
  Creo+Momentary checkbox): *Curse of the Ravenous Swarm* (CrAn 50), *Neptune's
  Wrath* (ReAq 40), *Breath of the Open Sky* (CrAu 40), *Rain of Oil* (MuAu 50),
  *Incantation of Summoning the Dead* (ReMe 40), *Disenchant* (PeVi Gen), *Watching
  Ward* (ReVi Gen).
- **Some may want a guideline flag rather than a ruling.** Three carry the reason in
  their own design line (`ritual because it has a really major effect`, `ritual for
  large effect`, `ritual because of spectacular effect`) — that is a storyguide
  ruling. The two Vim Generals may be guideline-level.
- **Spec:** `docs/superpowers/specs/2026-07-27-ritual-spells-design.md`

### 20. Creo Creation `suggested` Ritual Sweep
- [ ] Decide whether every "Create X" guideline should carry
      `RitualRequirement.suggested`, as the Creo healing guidelines now do
- **Rationale:** Core Rules line 12176 — "An item made with Creo only lasts for the
  duration of the spell, unless the spell was a Momentary Ritual" — makes creation
  exactly as much a lasting-thing case as healing.
- **The audit supports leaving it.** Skipped deliberately: it is hundreds of entries
  across all ten Forms, the checkbox already defaults on for *every* Creo + Momentary
  draft, and all 32 derivable Ritual spells derive correctly without it. The flag
  would add explanatory text only.

### 21. Creo Mentem Memory Restoration
- [ ] Decide whether `crme-4b`, `crme-5b` and `crme-10a` ("Restore a memory … to a
      fresh state") are Momentary-Creo-lasting-thing cases
- **Context:** the Ritual sweep's criterion arguably reaches them, but the approved
  scope was Creo *bodily* healing across Animal, Corpus and Herbam, and the
  healing-suspension rule at line 13415 does not cover memory. All three are flagged
  "Variable base level" — **but they are rung entries with real integer levels, not
  General entries, so item 25 does not reach them.** (Renamed from
  `creem-4b`/`creem-5b`/`creem-10a` when the base-effect id scheme was corrected.)

### 12. Out-of-Scope Effects Handling
- [ ] Create filtering/tagging UI for flagged effects (variable base levels,
      ritual-only, etc.)
- [ ] User guidance: explain which effects don't fit the calculation model yet
- **Re-measure scope before planning.** The audits reduced the original "~200 flagged
  effects" figure to section B's two genuinely uncomputable families, and items 24/25
  have landed since.

### 22. Catalog Extraction Gaps
**Not an import blocker** — none of the 360 published spells cite these missing
rows. Catalog completeness against the rulebook.

- [ ] **Creo Animal** — L35 "Increase a Characteristic to one above average",
      L40 "Cause an animal to reach full maturity in a moment",
      L45 "…three above average", L55 "…five above average"
      (re-verify against the DE table at line 12468; the original research was done
      against the 5e core rules and the DE rows may differ)
- [ ] **Creo Corpus** — L70 "Raise the dead, to a point (see *The Shadow of Life
      Renewed*)"
- [ ] **Rego Animal** — General "Create a circle warding against animals from one
      realm … with Might less than the level"
- [ ] **Rego Mentem** — General "Ward against spirits belonging to one realm … with
      a Might less than the level"
- [ ] **Muto Aquam** — General "Convert part of a water elemental's body into
      another type of water"
- [ ] **Muto Terram** — General "Convert part of an earth elemental's body into
      another type of earth"
- **The four General rows need the full General shape when added** — a `reference`
  and an `effectFormula` (`GeneralEffectFormula`) alongside `baseLevel: null`,
  matching the other 49 entries. Not a bare zero-level row.
- **⚠️ This item should end with the catalog rebuilt from `reviewed/`, not with ten
  rows patched onto a raw-OCR base.** The 604 base effects were extracted from what
  was `raw-md/Ars Magica 5e - Core Rules.md` (since removed upstream; retrievable via
  `git -C <rulebook> show 8b6c4d6^:"raw-md/Ars Magica 5e - Core Rules.md"`), while a
  reviewed Definitive Edition exists. See *Notes* for the source-precedence rule.
- **⚠️ Any rebuild must reproduce all 611 entries** and re-run item 34's bullet-count
  comparison first — see item 34's still-open sub-item.

### 23. Ritual Spells Review — Remaining Cosmetic/Test-Hygiene Findings
None affect correctness.

- [ ] **JSON formatting inconsistency in `assets/data/spell_library.json`** — the 5
      Ritual spells added by that branch use multi-line citation formatting; other
      built-ins use compact single-line. Reformat if a pass over this file happens
      for any other reason.
- [ ] **A widget test title promises more than it asserts** — one test from the
      Ritual Spells work (`test/presentation/widgets/*` or
      `test/presentation/screens/spell_creation_screen_test.dart`; not pinned down
      further). Find it, then narrow the title or extend the assertions.
- [ ] **The "no accidental Ritual" regression guard only checks
      `ritualDeclaration`**, not a full breakdown recompute — it could miss a case
      where `ritualDeclaration == none` but `RitualStatus`-derived reasons (a
      guideline flag, the >50 threshold) still fire. Assert on a recomputed
      `LevelBreakdown.ritualStatus.isRitual` instead.

### 37. A Template Has Open Slots Beyond Its Level — Realm, Form, "Specific Type"
**In section 0, jointly with item 35.** Raised 2026-08-07 from *Wizard's Reach
(Form)*: the Form must be chosen before the template can become a spell, exactly as
the level must be. **This generalises item 35** (realm is one slot of several) for
part of the corpus; the part it does not cover is a different mechanism. Both are
named so they can be designed together; [[35]] stays as the realm instance.

- **Case 1 — the guideline itself leaves a slot open.** Measured: **20 of the 49
  General bullets (41%)**. By slot kind: **realm** ~15 (*"beings … from one
  supernatural realm (Divine, Faerie, Infernal, or Magic)"*, and PeVi's *"any
  supernatural effect of one realm"*); **"a specific type"** 4 (PeVi bullets 2, 7, 10
  and ReVi 5 — the rulebook's own examples are *"Hermetic Terram magic, or Shamanic
  spirit control magic"*); **Form** 2 (PeVi 10's *"a particular Hermetic Form"*, PeVi
  11's *"a given Form"*). Filling the slot is part of choosing the guideline; the
  slot is a property of the catalog row.
  - **⚠️ Reconcile first:** item 35 counted 14 General realm entries, this scan finds
    15 (adding `pevi-G5`). One of the two counts is wrong.
- **Case 2 — the guideline says nothing and the *spell* comes in ten versions.**
  Three Muto Vim spells: *Mirror of Opposition (form)* (*"There are ten versions of
  this spell, each affecting spells of one of the Hermetic forms"*), *Wizard's Boost
  (Form)*, *Wizard's Reach (Form)*. `muvi-G1/G2/G3` mention Form nowhere — they are
  Form-agnostic and the restriction belongs to the published spell. *Unravelling the
  Fabric of (Form)* looks like this group by its name but is **case 1**: `pevi-G2` is
  *"Dispel effects of a specific type"* and the Form is that slot being filled.
- **Scope of the bracketed-name pattern:** exactly 4 spells carry a
  `(Form)`/`(form)` placeholder, all 4 General, and **0 of the imported ordinary
  spells do**. No Technique placeholder exists. So case 2 is small and closed; case 1
  is large and open.
- **Same problem as item 25.** A template is a published spell with the caster's
  choices left open; instantiating means supplying them. Item 25 supplies the level;
  this supplies everything else. **If the model grows a general `choices` map, all
  three axes fit it; if each axis gets a bespoke field, there will be three.**
- **The observable that makes case 1 recoverable:** the chosen value is visible in
  the published prose and is often the only thing distinguishing two otherwise
  identical spells — *"No **magical** beast whose **Magic** Might…"* against *"No
  water **faerie** whose **Faerie** Might…"*, same guideline, level and stat line.
- **Open question, unanswered:** is "a specific type" a closed set (like realm's four
  or Form's ten) or free text? PeVi 7's *"a specific type of supernatural effect"*
  reads open-ended, which would be a different UI affordance from a four-way or
  ten-way picker.

**Three model findings arguing the `choices`-map fork is decided *before* either
axis is implemented:**

- **A bespoke field is not one field.** Each nullable slot costs an
  `Object? x = _unset` sentinel in `SpellDraft.copyWith` (`spell.dart:262-294`), a
  clear-on-switch branch in `spell_creation_bloc.dart` (`:49`, `:64`, `:87`), and a
  conditional in the creation screen (`spell_creation_screen.dart:154`).
  `chosenBaseLevel` pays this once; realm, Form and "specific type" would pay it
  three more times.
- **Realm cannot reuse `chosenBaseLevel`'s plumbing, because it is not
  General-only.** `revi-5` and `revi-15` are ordinary fixed-level rows with an open
  realm. Every existing guard — validation, clear-on-switch, the UI's `if` — keys on
  `isGeneral`, and none of them transfer.
- **`SpellTemplate` has nowhere to hold the legal *set*.** Item 35 wants the template
  to carry the choices rather than a value; `spell_template.dart` is a `Spell` minus
  `chosenBaseLevel`/`printedLevel`/`templateId` and has no slot concept. Whatever
  shape is chosen lands on both types together.
- **The migration argument is decisive.** Either shape works functionally; they
  differ in when the cost falls. Choosing *after* 35 and 37 are implemented rewrites
  the serialized form of `spell_library.json`, `spell_templates.json` and every DB
  blob a second time.

### 35. A Guideline's Realm Is a Choice, Like Its Level
**Generalised by item 37; design the two together** — see item 37 for the model
findings that bear on both. The realm measurements here remain the authority for
that slice, subject to the 14-vs-15 reconciliation item 37 flags.

- [ ] Decide where the chosen realm lives — most likely `Spell.chosenRealm` alongside
      `chosenBaseLevel`, with `SpellTemplate` carrying the *set* of legal choices
      rather than a value
- [ ] Decide whether the realm is part of validation (a ward with no realm chosen is
      not yet a spell) — the level answer was yes, and the argument looks identical
- [ ] Decide whether the import reads the realm out of published prose, or leaves
      imported wards realm-less
- [ ] Check whether "one realm" is the only such axis (item 37 says no)
- **What was noticed.** Sixteen catalog entries leave a realm open, phrased *"from
  one supernatural realm (Divine, Faerie, Infernal, or Magic)"*. Fourteen are General
  — all twelve wards, plus `pevi-G6` (reduce the casting total for all powers of one
  realm) and `pevi-G12` (dispel Magic Resistance aligned to one Realm). **Two are
  ordinary Rego Vim rows, `revi-5` and `revi-15`** — so this is **not** a General-only
  problem, which is why it was not folded into item 25.
- **Why it matters concretely.** The realm is what tells two otherwise identical
  spells apart. *Ward against the Beasts of Legend* and a hypothetical infernal
  equivalent would share a guideline, a level and a Touch/Ring/Circle stat line and
  differ only in realm. The rulebook makes the choice visible in the published prose,
  so it is recoverable from the corpus, not invented.
- **Files:** `lib/models/spell.dart`, `lib/models/spell_template.dart`,
  `lib/engine/spell_engine.dart` (validation), the creation UI

### 36. Audit the Catalog's `description` Fields Against the Rulebook
Raised 2026-08-07. One confirmed defect, fixed in `2338430`; the question is how many
more there are.

- **The defect.** `pevi-G2`'s description read *"Dispel specific effect type **with
  Intellego spell** …"*. The rulebook row contains no Intellego at all — *"…with a
  level less than or equal to the level + 4 magnitudes of **the Vim spell** + a
  stress die (no botch)"*. The word almost certainly bled from the row's first
  bullet, which does mention Intellego.
- **Why it matters more than a typo.** These descriptions are what the app shows when
  a user picks a guideline, and what an agent reads when resolving a spell. A
  description that misstates its guideline can drive a wrong ledger pick that no test
  can catch.
- **Why existing audits missed it.** Item 34 compared bullet *counts* per
  technique/form/level in both directions and never compared *content*. Counts can
  match perfectly while every description is wrong.
- **Checked so far:** a per-bullet scan for Art names appearing in a description but
  not in its own rulebook bullet, across all 49 General entries — exactly one hit,
  `pevi-G2`. A narrow probe: it catches fabricated Art references and nothing else.
- **Not checked:** the other 562 entries, and every kind of drift that is not an Art
  name — wrong thresholds, dropped conditions, merged clauses, inverted senses.
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
- **Only 1 spell has ward mechanics in its design line** — *Break the Oncoming Wave*
  (`ward, so the target is the warded Individual, not the water`). The other 12 need
  nothing beyond item 25.

### 33. Write-Only Columns on the `spells` Table — MAYBE, revisit when relevant
Filed as a *maybe*: nothing is wrong today. Pick this up only when a task lands in
this area — most likely item 9 (tag filtering) or item 7 (backup validation). **Do
not do it on its own.**

- [ ] Decide whether to drop `name`, `source`, `created_at` and `updated_at` from the
      `spells` table, or to start using them
- **What was found.** `spells` is `(id, name, source, data, created_at, updated_at)`,
  where `data` holds the whole serialized `Spell` as JSON. `LocalSpellDatasource._toRow`
  writes both the projected columns *and* the blob from the same object, but every
  read goes through `jsonDecode(row['data'])` and every query is either
  `where: 'id = ?'` or a bare `query('spells')` with no `WHERE` and no `ORDER BY`.
  Those four columns are **write-only duplication**: drift risk, no benefit.
- **The blob is the right design here and should stay.** The table holds **only
  user-created spells** (published ones load from `assets/data/spell_library.json`);
  `Spell` carries four nested collections (`requisites`, `adjustments`, `tags`,
  `selectedModifiers` as a `Map<String, List<String>>`) whose normalization means
  four or five join tables serving queries nothing issues; and **the interesting
  joins are impossible in SQL anyway** — `baseEffectId`, `rangeId` and the rest point
  into JSON assets, not tables, so "every spell using guideline `pevi-G3`" can never
  be a SQL join in this design.
- **If per-spell predicates ever outgrow Dart-side filtering**, the fix is a
  generated column or an index on a JSON path — not a schema rewrite.
- **Files:** `lib/data/database/app_database.dart` (the `spells` DDL),
  `lib/data/datasources/local_spell_datasource.dart` (`_toRow`)

### 38. Open Follow-ups from item 25's Whole-Branch Review
None of this blocks anything — item 25's code and data are correct and 445 Dart tests
pass. Same shape as item 29. Found by an Opus-run multi-angle `code-review --max` of
`feature/general-base-effects` vs `main` (six independent reviewer passes), each
finding re-verified against source before being recorded.

- [ ] **`SpellEngine.allParameters` starts empty and is populated only by a listener
      scoped to the Create screen.** `SpellEngine(allSpells: allSpells)` (`main.dart`)
      defaults `allParameters` to `const []` (`spell_engine.dart:32`); it is filled
      only via `AvailableParametersSynced`, dispatched from `SpellCreationScreen`'s
      `BlocListener<ConfigurationBloc, …>`. `main.dart`'s `IndexedStack` builds the
      Library tab eagerly at app start, so `SpellLibraryBloc` can call
      `calculateBreakdown` for a saved General ward-type spell before that sync lands.
      Then `_parameterById(referenceId)` (`spell_engine.dart:49`,
      `_parameterContribution` at `:240`) returns null and the reference discount is
      silently skipped — the spell is momentarily overcharged the raw magnitude
      instead of the delta against its guideline's reference, with no error surfaced.
      Not observed with today's shipped library (no built-in spell both uses a ward
      guideline and picks a non-reference R/D/T), but nothing prevents it for the
      first user-saved spell that does. **Fix:** seed `allParameters` from
      `ConfigurationRepository` synchronously at construction (`main.dart`, alongside
      `allSpells`) rather than waiting for a bloc round-trip.
- [ ] **Duplicated join/filter logic between `Spell`'s path and `SpellTemplate`'s
      parallel path.** All real, none urgent; worth collapsing **before a third
      catalog-referencing record type shows up**:
      - `SpellResolver.resolve`/`resolveAll` and `resolveTemplate`/
        `resolveAllTemplates` (`spell_resolver.dart:46-66`) perform an identical
        four-field id lookup, differing only in wrapper type.
      - `SpellLibraryState.visibleSpells`/`visibleTemplates`
        (`spell_library_state.dart:40-69`) run an identical
        filter-by-source-then-substring pipeline. (Its "My Spells" branch on
        `visibleTemplates` always returning empty is **not** dead code — a template is
        published catalog data and can never be user-created.)
      - `ResolvedSpell`/`ResolvedTemplate` duplicate the same
        `isResolved`/`unresolvedReferences`/`technique`/`form` derivation and the same
        pass-through getters; only the `LibraryEntry` interface is shared.
        - **Filed here 2026-08-09 by item 40's design.** That item adds a
          third parallel notion, `ResolvedSpell.problems`, deliberately *not*
          merged with `isResolved` because the two answer different questions:
          `isResolved` is a **can-I-compute gate** (the four catalog ids are
          null, so `calculateBreakdown` cannot run at all), while `problems`
          means the level computes but must not be trusted. Collapsing the
          family into one concept — with a severity, if one is still needed —
          belongs to this cleanup: rationalising `LibraryEntry`'s contract
          once across three notions and two types beats doing it for two now
          and three later. **Do not merge them without preserving the compute
          gate** — `spell_library_bloc.dart:44` depends on it.
      - `emit.py`'s `build_template` (144-207) mirrors `build_spell` (80-141)
        near-verbatim for range/duration/target lookup, requisites, citations,
        adjustments and ritual declaration — its own docstring says "mirrors
        `build_spell`" without factoring the shared part out.
      - `extract_spells.py`'s General-guideline branch (255-291) duplicates the
        ordinary ledger-resolution pipeline below it (300-332), and the two have
        **already drifted**: `DESIGN_LINE_INCOMPLETE` exists only on the General side,
        though nothing about that check is General-specific.
      - A generic mixin/base class on the Dart side (parametrized on the record's four
        catalog-id fields) and a shared `_common_fields`-style helper on the Python
        side would collapse each pair to one implementation.
- [ ] **Efficiency, all in the Library-load path, none correctness-affecting.**
      Of the three sub-problems found by the review, one is now fixed and two
      remain open:
      - **FIXED 2026-08-09** (item 40 Part A, Task 1,
        `docs/superpowers/plans/2026-08-09-spell-invariant-enforcement.md`):
        `getTemplates()` re-reading and re-parsing `spell_templates.json` from
        the asset bundle on every call, unlike `getBuiltInSpells`, which cached
        the parse. `AssetDataLoader` (`lib/data/datasources/asset_data_loader.dart`)
        now memoises the `Future` for every asset load, including
        `loadSpellTemplates()`, so concurrent/repeated callers share one parse
        and `LibraryRepository.getTemplates()` only triggers the actual read
        once.
      - **Still open:** `SpellLibraryBloc._onEvent` (`spell_library_bloc.dart:36-37`)
        awaits `getAllSpells()` then `getTemplates()` sequentially, each
        independently calling `LibraryRepository._refreshResolver()` — two
        catalog reloads where one would do, on **every** Library tab visit
        (`main.dart`'s bottom nav re-requests on every visit, by design).
        `Future.wait` and one resolver refresh fix this cheaply.
      - **Still open:** `SpellEngine._parameterById` (`spell_engine.dart:49`)
        linear-scans instead of using a map, unlike `SpellResolver`'s own id
        maps.
- [ ] **`deriveGeneralEffect` silently returns null when a negative
      `offsetMagnitudes` drives the value below 1** (the `on ArgumentError { return
      null; }` branch), and `validateSpellDraft` does not check this independently of
      the overall spell level — so a General guideline with a negative offset, chosen
      low enough, saves successfully with a blank effect sentence and no validation
      error. No current catalog entry has a negative `offsetMagnitudes`. A known
      deferral in the spec, recorded here so it is not lost.
- [ ] **`TemplateInstantiated` silently discards an in-progress, unsaved draft.**
      Deliberate (a stale breakdown/suggestions/calculated level must not follow the
      user into a new spell), but there is no confirmation prompt. Worth a "discard
      changes?" prompt if it becomes a reported annoyance.
- [ ] **36 of the 49 General catalog entries omit an explicit `reference` triple**,
      falling back to `ParameterTriple.standard()` (Personal/Momentary/Individual)
      rather than stating it. Correct where the guideline genuinely is
      Personal/Momentary/Individual, but the fallback cannot distinguish "explicitly
      so" from "field just wasn't authored". A natural extension of item 32 should
      confirm each of the 36 against its own rulebook row. **One specific candidate:**
      `crvi-G4`'s `effectFormula` codes `offsetMagnitudes: -1` (matching its extracted
      description, "less than guideline magnitude -1"), but its one template's
      verbatim prose (*Restore the Faded Threads*) reads "up to the magnitude of this
      spell –3". Low confidence either is wrong — they may describe different
      quantities (a guideline threshold vs. a per-spell magnitude) — but it is exactly
      what item 32 exists to check.
- [ ] **Two latent, unexercised gaps in the Python import pipeline**, neither hit by
      the current 611-entry corpus:
      - `extract_spells.py`'s General routing (`design.base_level is None or
        block.printed_level is None`) treats *either* side being absent as "General",
        so a spell under a `#### GENERAL` heading whose design line nonetheless parses
        a concrete numeric base has that number silently discarded in favour of
        `general_candidates()`.
      - `emit.py`'s `_selected_modifiers` "size" token branch has no
        duplicate-selection guard, unlike the structurally identical
        `elaborate-effect` branch just above it, even though every `size-<form>`
        modifier is `selectionMode: single`. Only matters for a design line printing
        two size tokens for one spell — none currently does.

---

## D. Low Priority / Nice-to-Have

### 10. Documentation
- [ ] Update README (see also item 29 — it is still the stock Flutter template)
- [ ] Add a Size feature guide to docs
- [ ] Document the Aquam sub-type limitation (see *Notes*)

### 11. Performance
- [ ] Optimize base effects JSON (611 effects, all loaded at startup)
- [ ] Consider lazy loading or caching if the app grows
- **Re-measure now that the library holds 285+ spells**, each computing a level on
  load. This item's premise is only now testable. See also item 38's Library-load
  efficiency bullet.

---

## Completed ✅

Closed items, reduced to the decisions and constraints that still bind. Follow the
linked spec/plan or git history for detail.

### 34. Guidelines Missing From the Catalog — ✅ FIXED (2026-08-06, `8a70889`, `87ac754`)
- [x] Compared every guideline table in the rulebook against `base_effects.json`
      bullet by bullet, restored 4 missing General and 5 missing ordinary guidelines,
      and removed 2 invented rows
- [ ] **Still open: nobody knows why the extraction dropped them.** The producing
      script is not in the tree — `scripts/spell_import/catalog.py` only *reads*
      `base_effects.json`. **If item 22 rebuilds this asset it must reproduce all 611
      entries, and the bullet-count comparison is the test to run first.**
- **Final state: 24 arts, 49 General bullets, 49 General entries; 611 entries total**
  (604 → 613 → 611; General 47 → 51 → 49; wards 10 → 12).
- **Two failure modes**, which is why a single-cause fix would have missed half: a
  multi-bullet row keeping only its first bullet (`rean-gen`, `muaq-gen`, `cran-35`,
  `cran-40`, `cran-50`), and a row dropped entirely (Muto Terram General, Creo Animal
  45 and 55). `reme-G` was a third variant: two bullets *merged* into one description
  reading "beings associated with Mentem **or spirits**".
- **The audit initially ran in one direction only, and the other direction had two
  hits.** `peme-G` and `inco-gen` existed in arts whose guideline tables print no
  General row at all (Perdo Mentem runs 3–25, Intellego Corpus 3–35); each was a
  spell's own effect text read backwards into a guideline — precisely the failure item
  32 is about.
- **The standing check is now a test, not an audit.**
  `test_general_entries_match_the_rulebook_bullet_for_bullet` parses the guideline
  tables and compares **per art**, in both directions. Per art matters: a dropped
  bullet in one art and an invented row in another cancel out in a single total, which
  is very nearly what had happened.
- **Consequence:** Rego Animal and Rego Mentem now have *two* General candidates each,
  so spells in those arts need a recorded ledger pick instead of auto-resolving.
- **Files:** `assets/data/base_effects.json`,
  `scripts/spell_import/tests/test_general_catalog.py`,
  `test/data/repositories/configuration_repository_test.dart`

### 30. Rulebook Source Provenance — ✅ COMPLETE (workflow commit `77c8b01`)
Records which rulebook revision produced `assets/data/spell_library.json`, via
deterministic sha256 provenance in a committed sidecar (`source.lock`), never in the
asset itself.

**What binds going forward:**
- `ARS_RULEBOOK_ROOT` overrides the rulebook location (used by CI). `raw-md` handling
  was retired when that folder was deleted upstream.
- `provenance.py` computes/stores/compares source identity (sha256 + advisory git
  metadata); `report.py` diffs two asset lists into readable markdown; both are
  testable with **zero rulebook dependency**.
- `import_report.md` is the committed human-readable record of the last adoption that
  changed the asset.
- `RegenerationTest`'s failure message is drift-aware: it distinguishes "source moved"
  from "asset was hand-edited" by checking `source.lock`.
- **`--write` is gated on `--accept-source`**, ordered behind the unresolved/problems
  guards — adopting upstream changes is explicit.
- **Spec/Plan:** `docs/superpowers/specs/2026-08-03-rulebook-source-provenance-design.md`,
  `docs/superpowers/plans/2026-08-03-rulebook-source-provenance.md`

### 27. Published Spell Import Harness — ✅ COMPLETE
The harness is what makes every other mechanism *verifiable*: each one is checked
against every spell it touches, and a regression anywhere in the engine surfaces
immediately.

- **The extractor** is maintained and idempotent at
  `scripts/spell_import/extract_spells.py` (`scripts/import/` in the spec — `import`
  is a Python keyword, so the directory was renamed; the one deliberate spec
  deviation). `--show-blocked` prints per-spell blocked reasons.
- **The ledger** is hand-edited at `scripts/spell_import/resolutions.json` and records
  each base-effect decision **and the candidate set it was made against**, so item
  22's new guideline rows flag affected decisions as stale rather than letting them
  stand unexamined.
- **Asset assertions:** level equality, **Ritual agreement** (the oracle that does not
  depend on the base effect), resolution completeness, reference integrity, clean
  regeneration — plus assertion 6, added by item 25 for General picks.
- **`loadSpellLibrary`'s hardcoded count was retired** — derive counts from the raw
  JSON, as `asset_data_loader_test.dart` already does (item 5).
- **`Citation.page` cannot carry page numbers.** Its doc comment promised them "with
  the spell-parsing work", but the reviewed markdown has no page markers, only prose
  cross-references. Comment corrected; do not re-promise it.
- **Three spells print no design line. Only one has a legitimate derivation:**
  - *Enchantment of the Scrying Pool* (InAq 30, line 12900) — ✅ derived
    `(Base 5, +1 Touch, +4 Year)`, base effect `inaq-5` (sole candidate). Imported.
  - *Whispering Winds* (InAu 15, line 13251) — ❌ **permanently blocked.** InAu's only
    base levels are 1/2/4/15; with Sight(3)/Conc(1)/Ind(0) fixed by the stat line, no
    real base level + real magnitude token reproduces 15 without inventing a requisite
    the text does not support. The spell's own prose says why: "fits poorly into the
    normal framework of Hermetic magic."
  - *Hermes' Portal* (ReTe 75, line 15638) — ❌ blocked on infrastructure, not rules.
    `rete-4` ("Transport a non-living object…") needs `rego-transport-distance` at its
    top rung plus 2 magnitudes of size to reach 75, and `emit.build_spell` maps only
    `size`-kind tokens today. **See item 29's extension bullet** — that would resolve
    this spell. Its printed `(Mercurian Ritual)` marker corroborates it is
    non-standard.
  - (Five further spells lack a design line but are General-level and belong to item
    25: *Ward against the Beasts of Legend*, *Sight of the True Form*, *Ward against
    Faeries of the Mountain*, *Wizard's Vigil*, *Aegis of the Hearth*.)
- **The one open checklist line was split out on 2026-08-07** into **item 28** (zero
  candidates — a catalog/prose-rule gap) and **item 39** (genuine ambiguity — a
  reading decision), because the two need different kinds of decision and were getting
  lost bundled under one line inside an item flagged complete.
- **Spec/Plan:** `docs/superpowers/specs/2026-07-28-published-spell-import-design.md`,
  `docs/superpowers/plans/2026-07-28-published-spell-import.md`

### 25. General-Level Spells — base level is chosen, not fixed — ✅ COMPLETE
Absorbed item 4's "Variable Base Levels" bullet, which badly understated it: the Spell
Modifiers spec correctly established that most `"Variable base level"` notes are
informational rung entries, but that reasoning does not reach **General entries**,
where there is no ladder and no correct integer, because the level *is* the caster's
choice. 33 published spells are General-level, including **every Vim spell and every
ward**.

**What landed and still binds:**
- `GeneralEffectFormula` on `BaseEffect` (a reference R/D/T plus a `GeneralEffectKind`
  and an offset); 49 General catalog entries carry `baseLevel: null`.
- `calculateBreakdown` substitutes `chosenBaseLevel` for the guideline's base. **The
  chosen level enters `SpellLevelCalculator`'s additive/multiplicative split exactly
  as the guideline's base would have** — that was the design-heavy question and this
  is the answer.
- Validation (`spell_engine.dart:67-72`) rejects both a missing chosen level
  (`'Choose a level for this General guideline'`) and one below 1 (`'The chosen level
  must be at least 1'`). **Neither computes a silent zero.**
- `chosen-base-level-field` in the creation screen, shown only while the selected
  effect `isGeneral`; the bloc clears `chosenBaseLevel` on any switch away from
  General (`spell_creation_bloc.dart:87` — only General→General preserves it).
- `_effectSentence` prints a breakdown line per `GeneralEffectKind`
  (`spell_engine.dart:422-431`).
- Published General spells emit to `spell_templates.json`, not `spell_library.json`.

**Ten of the 33 remain blocked, each for a reason unrelated to this item:**
- **No design line printed (4):** *Aegis of the Hearth*, *Wizard's Vigil*, *Sight of
  the True Form*, *Ward against Faeries of the Mountain*.
- **Design line prints `(Base effect)` but the stat line costs magnitudes (2):**
  *Restore the Moved Image*, *The Invisible Eye Revealed*.
- **No General base effect for that Technique/Form (2):** *Lay to Rest the Haunting
  Spirit*, *Dispel the Phantom Image*.
- **Design line disclaims guideline arithmetic (1):** *Wizard's Communion* — "a
  remnant of Mercurian rituals."
- **Unrecognised token (1):** *Watching Ward* — a `Special`-Duration problem, **item
  26's**.

- **Spec/Plan:** `docs/superpowers/specs/2026-08-05-general-base-effects-design.md`,
  `docs/superpowers/plans/2026-08-05-general-base-effects.md`
- **Files:** `lib/models/base_effect.dart`, `lib/engine/spell_engine.dart`,
  `lib/bloc/spell_creation/spell_creation_bloc.dart`,
  `lib/presentation/screens/spell_creation_screen.dart`,
  `assets/data/base_effects.json`, `scripts/spell_import/`,
  `integration_test/spell_creation_flow_test.dart`

### 24. Ad-hoc Level Adjustments — ✅ COMPLETE
21 published spells carry a one-off magnitude the storyguide assigned with a prose
justification. **No catalog entry can ever cover these** — they are per-spell, not
per-guideline.

**What landed and still binds:**
- A `LevelAdjustment` model — a list of `(magnitude, note)` on `Spell` and
  `SpellDraft` — one repeatable UI row in the creation screen, and one breakdown line
  per adjustment showing the note.
- **Negative magnitudes are allowed.** `SpellLevelCalculator` mirrors the positive
  rule (worth 1 inside the additive tier, 5 above it) and restores the additive
  capacity it gives back, so `[1, -1]` is a no-op at any base level. *The Severed Limb
  Made Whole* is the one published spell that needs it.
- **Two token families, not one.** The recurring wordings (`fancy effect`, `complex
  effect`, `for special effect`, `additional effect`, `elaborate design`) became a
  real globally-scoped `elaborate-effect` catalog Modifier, because they *are*
  reusable. Only genuinely per-spell prose became adjustments, matched against a
  **closed allow-list** (`designline.ADJUSTMENT_LABELS`) — so an unmodelled mechanism
  keeps blocking its spell instead of importing at a correct level with wrong
  modelling.
- **One hand-derived magnitude.** *The Shadow of Human Life* prints "for a very
  elaborate effect" with no number; the literal 5 and its arithmetic live in
  `extract_spells.HAND_DERIVED_ADJUSTMENT`, checked by assertion 1 rather than derived
  from it.
- **Do not confuse adjustments with Modifiers.** A Modifier is a *reusable catalog
  choice* scoped to a technique/form/effect. Adjustments are unique to one spell and
  would pollute the catalog with 21 single-use entries.

**Three spells stay deliberately blocked** — each is a real unmodelled mechanism, not
a one-off note, so none is in the allow-list: *The Kiss of Death* (`+2 for no words`),
*Black Whisper* (`+1 for not needing to gesture`), *Sight of the Active Magics*
(`+2 Techniques and Forms`).

- **Spec/Plan:** `docs/superpowers/specs/2026-08-04-level-adjustments-design.md`,
  `docs/superpowers/plans/2026-08-04-level-adjustments.md`

### 15. Add All Core-Rulebook Parameters — ✅ COMPLETE (`c835d0a`)
The catalog held **17** parameters; the core rulebook defines **25**, and one entry was
misnamed. A correctness problem, not just a gap — spells needing Ring, Circle or Eye
could not be expressed at all.

- [x] **Range — Eye (+1).** The rulebook pairs it with Touch ("Touch and Eye are the
      same 'level' of range", listed `Touch/Eye`). Equal in magnitude, **not
      interchangeable**.
- [x] **Duration — Ring (+2)** (paired with Sun) **and Year (+4)**
- [x] **Target — Circle (+0)** (paired with Individual) **and the four missing magical
      senses:** Taste (+0), Touch (+1), Smell (+2), Hearing (+3). The senses are
      Intellego targets, each equivalent to a standard target: Taste=Individual,
      Touch=Part, Smell=Group, Hearing=Structure, Vision=Boundary. Vision was already
      present and correct.
- [x] **Renamed `Bound` → `Boundary`**, id `target-boundary`
- **Independently confirmed complete by the audit:** every Range, Duration and Target
  used by all 360 published spells resolves against these 25 entries.
- **Two constraints were explicitly decided, not left open:**
  - **Ritual-only gating (Year, Boundary)** — resolved by `Parameter.requiresRitual`
    (item 4); those two are exactly the entries flagged `requiresRitual: true`. Item
    17 still needs the *Virtue*-gating half.
  - **Target `Touch` / Range `Touch` name collision — left as-is.** Harmless: ids are
    category-scoped (`range-touch` vs `target-touch`) and the creation screen's
    dropdowns filter by category, so the two never share a picker.
- **Spec/Plan:** `docs/superpowers/specs/2026-07-27-parameters-and-provenance-design.md`,
  `docs/superpowers/plans/2026-07-27-parameters-and-provenance.md`

### 4. Resolve Out-of-Scope Base Effects — ⚠️ PARTIALLY COMPLETE
Audited sub-item by sub-item on 2026-07-28: four done, two were never real gaps, three
moved to their own items.

- [x] **Ritual-Only Constraints** — landed as `RitualRequirement`
      (`none`/`suggested`/`required`), 7 required and 38 suggested entries, plus the
      `RitualSection` banner. **Landed as derivation, not validation:** nothing is
      rejected, because a Year-duration spell is not an error, it *is* a Ritual. This
      sub-item's original wording ("force Duration = Ritual") was wrong — **Ritual is
      a spell *type*, orthogonal to all eight Durations.**
- [x] **Complexity-Stacking Modifiers** — `crim-complexity` (3 options),
      `peim-complexity` (1), `reim-complexity` (3), migrating the old special factors.
      Covers 11 published spells.
- [x] **Material Difficulty Scaling** — `muto-terram-material`,
      `perdo-terram-material`, `rego-terram-material` (5 options each, also carrying
      `baseIndividual`). Covers 10 published spells. **Creo Terram deliberately has
      none — material *is* the base effect there.**
- [x] **Magnitude Ladders** — `rego-transport-distance` (6 rungs, 5 paces → Arcane
      Connection), scoped by `effectIds` to `rehe-10b`, `reig-3c`, `rete-4`.
- [x] **Characteristic Point Scaling** — ⚪ **not a gap.** Each rung is already its own
      base effect (`crme-30` … `crme-55`); choosing "to no more than +2" *is* choosing
      `crme-40`. What looked like a modelling gap was an extraction gap in Creo Animal
      only — now item 22.
- **Variable Base Levels** → item **25** · **Conditional Wards** → item **4**
  (section C) · **Intensity/Damage** → item **4b** · **Level-Dependent Might
  Reduction** → item **4c**
- **Two modifier families landed that this item never listed:**
  `creo-auram-unnatural` (4 rungs, covers 11 published spells) and
  `aquam-base-individual` (5 sub-types, all magnitude 0).
- **The original "~200 flagged effects" figure was wrong and should not be quoted.**
  The Spell Modifiers audit reduced it to 23 effects across 4 modifier families; the
  2026-07-28 audit reduced the genuinely uncomputable remainder to section B's two
  families.
- **Spec:** `docs/superpowers/specs/2026-07-25-spell-modifiers-design.md`

### 3. Size Feature (MVP) — ✅ COMPLETE
- **It did not land the way this item anticipated.** There is **no bespoke `size`
  field on `Spell`** — Size is modelled as ordinary scoped Modifiers, needing no model
  change beyond the `selectedModifiers` map that already existed.
- 8 Size ladders in `assets/data/modifiers.json`, each 5 options: Base Individual (+0)
  then ×10/×100/×1,000/×10,000 at +1…+4. Each is Form-scoped and excludes Intellego.
  Magnitude feeds the level through the normal modifier path — **no special case in
  the calculator.**
- **Two limitations became real blockers and moved to item 19:** the +4 ceiling, and
  the Mentem exemption being implemented Form-wide when the rulebook states it only
  for Individual targets.
- **The Aquam gap was closed as documented, not fixed** — see *Notes*.

### 2. Requisites UI & Integration — ✅ COMPLETE (`feature/requisites-ui`)
- One `Requisite(art, kind)` with a `RequisiteKind` enum (`free` = 0 magnitude,
  `adding` = 1), replacing RequiredRequisite/AdditionalRequisite. `Spell`/`SpellDraft`
  carry a single `requisites` list under one `requisites` key. *(Item 40 will reshape
  this list into a map keyed by art.)*
- Validation: a requisite art cannot be the spell's own Technique or Form, and no
  duplicates. The add dropdown offers the de-duplicated union of ArsArts + ArsForms
  minus the spell's own Technique and Form, minus already-chosen arts.
- **The free/adding split is confirmed sufficient by the audit** — every
  requisite-driven magnitude in the 360 published spells is +0 or +1.

### 1. Spell Constraint: One of Each Parameter — ✅ COMPLETE (`2d897db`)
Exactly one Range, one Duration, one Target. **Ars Magica rule: spells have a single
Range/Duration/Target; modifiers scale the level instead.** Three dedicated dropdowns;
`SpellCreationBloc` enforces one-per-category in `ParameterAdded`;
`SpellEngine.validateSpellDraft` requires all three. *(Item 26's *Mists of Change* is
the one published spell that contradicts this — it stays blocked.)*

### 5. Asset Data Loader Test Failures — ✅ COMPLETE
- Fixed 19 built-in spells whose embedded `baseEffect` referenced ids not in
  `base_effects.json`. No level changes — every corrected pair has an identical
  `baseLevel`.
- **Made the counts self-healing rather than just updating them:** the loader test
  derives its expected count from `base_effects.json`'s raw entry count (an oracle
  independent of the loader itself); the bloc tests derive their baseline via
  `AssetDataLoader().loadBaseEffects()` once in `setUpAll`. **`base_effects.json` is
  bulk-extracted and grows unpredictably; a hardcoded count is exactly what silently
  drifted by 566 entries.**

### 8. UI: Disable Multi-Select for Range/Duration/Target — ✅ OBSOLETE
Superseded by item 1, which replaced multi-select with three dedicated dropdowns.
Selecting multiple Ranges, Durations or Targets is no longer representable.

### Base Effect Extraction — ✅ COMPLETE
604 base effects extracted (Animal 30 · Aquam 115 · Auram 41 · Corpus 98 · Herbam 49 ·
Ignem 70 · Imaginem 38 · Mentem 58 · Terram 51 · Vim 54); out-of-scope patterns
documented; Flutter desktop setup fixed (`sqflite_common_ffi` init). Catalog now
stands at 611 entries after item 34.

---

## Notes — standing constraints

**Source of truth for the import:**
`Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md`,
Chapter 9 (lines 12020–16004).

**Source precedence:** the rulebook repo holds the same book in `reviewed/` and `wip/`,
in descending quality. **Always resolve `reviewed` → `wip` and stop at the first hit.**
Filenames differ between folders, so match on book title. (`raw-md/` was unreviewed OCR
and also carried two alternate core-rules copies; it has been removed upstream.) The
604 base effects came from `raw-md` — item 22 reconciles the two.

**Aquam MVP limitation:** the Aquam Form has 5 distinct base-Individual sub-types
(water/liquids/poisons/blood/wine), each with slightly different guideline
progressions. The Size MVP supports one sub-type per spell via `aquam-base-individual`,
recorded in its base option's `baseIndividual` field. Mixed sub-types within Size
calculations are deferred.

**Prototype, not production:** backwards compatibility is not a goal and the database
is droppable, so a serialized-shape change needs no migration story. Correctness beats
compatibility.

**Verification rule of thumb:** a change to a screen's widget tree is **not** verified
by `flutter test` alone — `flutter test` does not run `integration_test/`. Run both.
See item 6, and note that the integration suite is currently red.
