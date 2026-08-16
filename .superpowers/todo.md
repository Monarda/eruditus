# Eruditus Todo List

**Status:** Active development · **Last updated:** 2026-08-16

**Standing goal:** every published spell in the Definitive Edition core rules
is either (a) in the spell library with its computed level matching its
printed level, or (b) recorded as an exception spell with a citation-backed
reason the guidelines don't apply to it. See item 46.

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

Last extractor run, 2026-08-16 (`python -m scripts.spell_import.extract_spells`):

> **325 imported · 27 emitted as templates · 8 recorded as exceptions · 0
> blocked · 0 unresolved**
> — 360 published spells in Chapter 9, all accounted for.

**Verified against a live `--show-blocked` run, not carried forward by
arithmetic** — the table below was re-derived spell-by-spell against that
output, after eight rounds of 2026-08-15 fixes plus item 24's, item 39's and
item 28's closing fixes (all 2026-08-16): item 28's Group A/B guideline
derivations; item 29's splitter fixes (6 spells: *Wings of the Soaring Wind*,
*Stone to Falling Dust*, *Deluge of Rushing and Dashing*, *Ice of Drowning*,
*Frosty Breath of the Spoken Lie*, *Ball of Abysmal Flame*); *Ward against
Faeries of the Mountain* (its own text names both its guideline and its
realm via a cross-reference to *Ward against Faeries of the Waters* — see
item 27's correction); item 44 plus two more verified-low-risk fixes done
alongside it (5 spells: *Obliteration of the Metallic Barrier*, *Phantasmal
Fire*, *The Eye of the Sage*, *Ward against Heat and Flames*, *Break the
Oncoming Wave* — see items 44, 4b, 4); item 39's close reading (3 of 4
spells: *Tracks of the Faerie Glow*, *Sense the Feet that Tread the Earth*,
*The Crystal Dart*); item 18's three ritual-justification clauses (3
spells: *Curse of the Ravenous Swarm*, *Neptune's Wrath*, *Breath of the Open
Sky*); and Bucket B's 5 import-blocker fixes (*Wind at the Back*, *Trackless
Step* and *The Earth Split Asunder* via item 26's `SPECIAL_PARAMETER_BASIS`
resolution of `Special` Duration/Target; *The Bountiful Feast* via item 26's
`DESIGN_LINE_TYPOS` fix for its missing closing paren; and *Hermes' Portal*
via item 45's transport-distance tokenizer fix); item 46's seven exception
spells (*Wizard's Communion*, *Wizard's Vigil*, *Aegis of the Hearth*,
*Whispering Winds*, *Watching Ward*, *Mists of Change*, *Sight of the True
Form*), which have their own row in the table below rather than counting
toward the blocked total; item 24's closing fix (*The Kiss of Death*, *Black
Whisper*, *Sight of the Active Magics*, 2026-08-16); item 39's closing fix
(*Conjuration of the Indubitable Cold*, 2026-08-16 — see its corrected
section: not actually a "which one is right" ambiguity, a model gap); and
item 28's closing fix (*Sense of the Lingering Magic*, 2026-08-16 — three
prior readings called it an unstated combination rule; a fourth found it was
an ordinary `NUMBERED_OVERRIDES` case); and item 25's 2026-08-16 closure of
its last 4 General-level spells (see the table's General-level row below).
Every one of the 360 published spells now maps to exactly one row below;
none are unaccounted for, and none are currently blocked.

| Blocker family | Spells | Item |
|---|---|---|
| Guideline level absent from the rulebook's own table | 0 | **28** — corrected from 5: all 5 now import, the last (*Sense of the Lingering Magic*) 2026-08-16 |
| Genuinely ambiguous ledger resolution | 0 | **39** — corrected from 4: 3 of 4 had a forced discriminator after all, fixed 2026-08-15; *Conjuration of the Indubitable Cold* now imports too, 2026-08-16 — it was never a "which one is right" tie, both candidates share the same base level, so it's routed through the ledger like any other multi-candidate spell and the second guideline is recorded as a free (magnitude-0) adjustment. See item 39's corrected body |
| Size ladder above +4 | 0 | **19** — corrected from 4: a +5 rung now exists on every `size-<form>` ladder and all 4 spells import; the architectural gap (no Target restriction on `ModifierScope`) is unrelated and now closed too, see item 19 |
| Non-standard Range/Duration/Target (mechanism done, spells still blocked) | 0 | **26** — corrected from 2: *Watching Ward* and *Mists of Change* both now import as exception spells (item 46) rather than staying blocked |
| General-level, all 4 sharing one root cause: a mechanic only generalized at the Vim level, never tabulated per-Form | 0 | see item **25** — corrected from 8, then 4: *Aegis of the Hearth*, *Wizard's Vigil*, *Wizard's Communion* and *Sight of the True Form* import as exception spells (item 46). **The last 4 (*Dispel the Phantom Image*, *Restore the Moved Image*, *Lay to Rest the Haunting Spirit*, *The Invisible Eye Revealed*) resolved together 2026-08-16 via two mechanisms** — 3 via the base-effect analogy capability, each pointed at the existing Vim-level guideline it's a Form-specific, un-offset echo of (Perdo Vim's "dispel"/"reduce Might", Rego Vim's "sustain or suppress"); and 1 (*The Invisible Eye Revealed*, already Vim itself, nowhere more general to point to) as an exception spell — folded into the 8-exception count in the Table total below. See item 25's body for the derivation of each |
| Unmodelled per-spell mechanisms (no words / no gestures / Techniques and Forms) | 0 | **24** — corrected from 3: all 3 now import as `no-words`/`no-gestures`/`invi-techniques-and-forms` catalog Modifiers, done 2026-08-16 |
| No printed design line and no legitimate derivation | 0 | see item **27** — corrected from 1: *Whispering Winds* now imports as an exception spell (item 46) rather than staying permanently blocked |
| `_split_parts`/`_TOKEN` punctuation edge cases | 0 | **29** — corrected from 1: *Ball of Abysmal Flame*'s semicolon now splits, done 2026-08-15. *The Bountiful Feast*'s unbalanced brackets turned out to be a different bug (a genuine rulebook typo, item 26's family above), fixed separately and not via this function |
| Non-standard requisite-magnitude phrasing | 0 | **44** — done 2026-08-15, all 3 import |
| Ritual-justification clause not yet allow-listed | 0 | **18** — corrected from 3: all 3 (*Curse of the Ravenous Swarm*, *Neptune's Wrath*, *Breath of the Open Sky*) now allow-listed and import, done 2026-08-15 |
| Genuinely unwired mechanisms with no owning item | 0 | *Break the Oncoming Wave* (item **4**) and *Ward against Heat and Flames* (item **4b**) both fixed 2026-08-15 |
| Rulebook says guideline arithmetic doesn't apply at all | 7 | item **46**: *Wizard's Communion*, *Wizard's Vigil*, *Aegis of the Hearth*, *Whispering Winds*, *Watching Ward*, *Mists of Change*, *Sight of the True Form* |

**Table total: 0 blocked, plus 8 exception spells (not blockers) —
7 in the item 46 row below and 1 (*The Invisible Eye Revealed*) folded into
the General-level row above via item 25's 2026-08-16 closure — reconciled to
the live counts.** The previous version of this table summed to 34 out of a
then-52 while implying full coverage; every row above now maps to specific,
named spells, not just a count.

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

### 28. Guideline Levels Absent from the Rulebook's Own Table — ✅ COMPLETE, 5 of 5 (2026-08-16)

**Correction to the original framing below: all 5 turned out recoverable.**
4 of 5 were derived from documented prose rules and imported 2026-08-15; the
5th (*Sense of the Lingering Magic*) was investigated three separate times
and left blocked as "genuinely not derivable... without an unstated
combination rule" each time — until a fourth, closer read found the rule was
never a combination at all. Design/plan:
`docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md`,
`docs/superpowers/plans/2026-08-15-guideline-level-derivation.md`.

- [x] Chose **option 2** (model the prose rules in the modifier system), not
      option 1 (derived catalog rows) or option 3 (ad-hoc adjustments) — the CrVi
      Warping Point and PeIg chill-damage ladders now live as `size-animal`-style
      `selectionMode: single` modifiers scoped to their base effect
      (`crvi-5a`/`peig-5b`, collapsing what were separate numbered rows
      `crvi-10a`/`crvi-15a`/`peig-10b`), and MuAu's single-property discount as a
      new broadly-scoped modifier (`technique`/`form`, no `effectIds`)
- [x] Unified what the design first drafted as two separate resolution
      mechanisms (a ladder-rung table for Group A, a `GENERAL_LEVEL_BY_SPELL_ID`
      table for Group B) into **one** `NUMBERED_OVERRIDES` table in
      `extract_spells.py`, once grounding against the real code found both
      groups hit the identical `catalog.candidates(...)` empty-result path
- [x] *Infernal Smoke of Death* (MuAu 40) — MuAu General "+**level** damage" at
      +25 damage; base = 25. First library spell built on a General guideline
      with a baked-in `chosenBaseLevel` rather than routed to an open template —
      surfaced two latent Dart test-oracle gaps (`asset_data_loader_test.dart`,
      `published_spell_import_test.dart`) that had never seen this case before
- [x] *Fog of Confusion* (MuAu 45) — MuAu base 3 minus the Muto Auram prose rule
      "Transforming only one property of air generally lowers the level by one
      magnitude"; base = 3 − 1 = 2
- [x] *Wizard's Icy Grip* (PeIg 30, not 25 as first guessed while writing the
      plan — corrected against the rulebook's own `#### LEVEL 30` heading) —
      Perdo Ignem's "every 5 points the damage exceeds +5 adds one magnitude"
      rule; the chill-damage ladder's 4th rung (+20 damage)
- [x] *The Enigma's Gift* (CrVi 30) — the Warping Point ladder's 4th rung (the
      spell's own prose says "four Warping Points"); base 20 (ladder prints
      5/10/15 for 1/2/3 points, refactored into one row + a 4-rung modifier)
- [x] *Sense of the Lingering Magic* (InVi 30) — **✅ RESOLVED 2026-08-16,
      not a combination rule after all.** Built on `invi-G`, the InVi General
      row ("Detect the traces of magic of negative magnitude up to the
      magnitude of the guideline used −2"), chosen at level 10:
      `(10 + -2×5)/5 = 0`, exactly the spell's own "the residue must be of
      at least zero magnitude" — the printed threshold, not a paraphrase.
      "Even from weak spells" and "presence and power of active
      spells... does not grant any information apart from the power" both
      restate the intro paragraph's base-detection capability, not an extra
      "+1 magnitude for Hermetic identification" spend (which the spell's
      own "does not grant... apart from the power" clause rules out
      explicitly). Now a `NUMBERED_OVERRIDES` entry, same shape as *Infernal
      Smoke of Death* two rows above — see that table's comment in
      `extract_spells.py`. A negative-magnitude safety concern was raised for
      the ladders during design and closed with zero new code —
      `SpellEngine.calculateBreakdown` already throws below level 1
      regardless of contribution source (verified by reading the code, not
      assumed)
- **What was caught in review.** Task 1's per-task review found deleting
  `peig-10b` would have silently dropped a real corpus spell ("Soothe the
  Raging Flames") on regeneration — its ledger entry in `resolutions.json`
  still recorded the now-deleted row as a candidate. The final whole-branch
  review added a lasting guard against a similar future drift: a test
  asserting the ledger and `NUMBERED_OVERRIDES` never silently disagree.
- **This was not item 22.** Item 22 is rows genuinely absent from the
  Definitive Edition. 4 of these 5 turned out derivable from stated prose; the
  investigation is what settled which one wasn't.
- **Files:** `assets/data/base_effects.json`, `assets/data/modifiers.json`,
  `scripts/spell_import/emit.py`, `scripts/spell_import/extract_spells.py`,
  `scripts/spell_import/resolutions.json`, `assets/data/spell_library.json`

### 39. Ambiguous Ledger Resolutions Needing a Rules Decision — ✅ COMPLETE, 4 of 4 (2026-08-16)

**All 4 of the original 4 turned out to have a resolution after all.**
Re-read each against its candidates' exact wording, not the most
general-sounding one — same discipline item 27's pulled first pass violated.

- [x] *Tracks of the Faerie Glow* (`lib-inte-tracks-faerie-glow`) → **`inte-4a`**.
      It makes tracks glow for normal eyesight to boost a Tracking roll — no
      seeing is involved, the same discriminator already governing
      `lib-inte-eyes-eons`'s inte-4a pick. It also continues this corpus's own
      R:Per/D:Conc/T:Vision + "Learn X property" pattern one level up from *Eyes
      of the Treacherous Terrain* and *The Miner's Keen Eye* (both base 2,
      "learn one visible property"): those learn a visible property, this one
      needs magic, matching inte-4a's "mundane" tier. Not `inte-4b` (seeing an
      object and its surroundings).
- [x] *Sense the Feet that Tread the Earth* (`lib-inte-sense-feet-that-tread-earth`)
      → **`inte-4a`**, same pair, same discriminator: the spell's own verb is
      "feel", not "see" — entirely tactile, no vision of any kind.
- [x] *Crystal Dart* (`lib-mute-crystal-dart`) → **`mute-3c`**. Turns solid
      stone into a solid crystal dart — the only level-3 Muto Terram guideline
      built for a solid-to-solid earth-family change (not `mute-3a`'s
      state-of-being change or `mute-3b`'s wrong state of matter). The design
      line's own arithmetic (`Base 3, +2 Voice, +1 Rego requisite` = exactly the
      printed level 10) has no room for the "+1/+2 magnitude for a different
      material" surcharge the guidelines' own note requires for any *other*
      material pair, so the transformation must be the one `mute-3c` already
      prices at base 3 without surcharge: "dirt to stone, or vice versa". The
      `Req: Rego` is for the dart's flight and strike, not the material change,
      and doesn't bear on this pick.
- [x] *Conjuration of the Indubitable Cold* (`lib-peig-conjuration-indubitable-cold`)
      → **`peig-4b`, plus `peig-4c` recorded separately — ✅ RECLASSIFIED
      2026-08-16, was "still genuinely ambiguous" through three prior
      readings.** The user's own rules instinct broke this open: `peig-4b`
      and `peig-4c` were never a "which one is right" tie — the spell's own
      text matches both close to verbatim simultaneously ("all nonliving
      things are chilled thoroughly" / "all living things ... lose one
      Fatigue level"), and both are printed at the *same base level* (4). A
      pick between them changes nothing about the computed level, which is
      what made every prior reading treat it as unresolvable — that
      reasoning was measuring the wrong risk. The rulebook's Requisites
      section states the closest analogue outright: *"the base Arts and
      level for the spell are those for the highest-level effect it
      has"* — written for an added Art, not a same-Technique/Form guideline,
      but the same "does not raise the cost" logic applies once both
      guidelines share a level. (`peig-4a`'s "extinguish" is still excluded
      on its own separate, textual grounds — contradicted by the spell's own
      text for anything bigger than a campfire, the *level 3* guideline, not
      level 4.)

      **What changed:** `peig-4b` goes through `resolutions.json` like any
      other multi-candidate spell, chosen arbitrarily since the choice is
      cosmetic (either candidate computes identically). `peig-4c` is
      recorded as a magnitude-0 `LevelAdjustment` — real, UI-visible data (a
      breakdown line with a note), not silently dropped — via the new
      `extract_spells.COMBINED_BASE_EFFECTS` table and `emit.build_spell`'s
      new `extra_adjustment` parameter. `KNOWN_UNRESOLVABLE` is now empty;
      the mechanism stays for a future spell that turns out to be a genuine,
      no-forced-discriminator tie.

      **This fix is one-off, importer-only — a user designing their own
      spell has no way to combine base effects this way. See item 47.**

**Different from item 28**, not a duplicate: there the correct row is missing and
needs adding; here every candidate already exists and is individually plausible,
and the work is close reading. **Not a harness blocker** — `KNOWN_UNRESOLVABLE` in
`extract_spells.py` would route a spell here to `blocked` rather than
`unresolved`, but is currently empty.

**See also item 32**, which applies the same discipline to entries that *did* make
it into the ledger.

- **Files:** `scripts/spell_import/resolutions.json`, `scripts/spell_import/extract_spells.py`,
  `scripts/spell_import/emit.py` (`build_spell`'s `extra_adjustment` parameter, for
  *Conjuration of the Indubitable Cold*'s combined base effects)

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

- [x] **A `Special` Duration has nothing to resolve to — ✅ DONE 2026-08-15 for 3
      of 4.** `emit._parameter_name` now resolves `D: Spec`/`D: Special` via a
      closed table, `SPECIAL_PARAMETER_BASIS`, keyed on the spell's own "based on
      X" adjustment clause. *Wind at the Back*, *Trackless Step* and *The Earth
      Split Asunder* all import now. **`Watching Ward` does not and will not
      via this mechanism** — its own clause, `Duration is non-standard`, names no
      basis at all (no "based on X"), so there is nothing to resolve it to
      without guessing. **✅ It now imports as an exception spell instead,
      2026-08-16 — see item 46.**
- [x] *The Bountiful Feast* — ✅ DONE 2026-08-15. **Correction: this was never a
      `_split_parts` bug** — the printed line is genuinely missing its outer
      closing paren (a rulebook transcription defect, verified directly against
      the reviewed Definitive Edition markdown), not oddly-but-validly nested
      brackets. Fixed via a `DESIGN_LINE_TYPOS` entry, the same mechanism as
      *Ward against Heat and Flames*'s `"+1Touch"`, not a `_split_parts` change.
      Base effect `crhe-1a`, forced by the design line's own "+3 from the
      guideline" note (the only one of 5 candidates with a stated Size bonus).
- **✅ Now an exception spell, 2026-08-16 — see item 46.** *Mists of Change*
  prints `D: Sun & Year`. Two durations in one stat line contradicts item 1's
  rules-correct one-Duration invariant; it also prints a numberless "slightly
  nonstandard effect". The model was correctly never weakened for this one
  spell — it is recorded outside the model instead, via ExceptionSpell's
  free-text Range/Duration/Target.

- **Spec/Plan:** `docs/superpowers/specs/2026-08-04-level-adjustments-design.md`,
  `docs/superpowers/plans/2026-08-04-level-adjustments.md`

### 19. Size-Ladder Ceiling — ✅ COMPLETE (2026-08-16)

**Its architecture half is in section 0** — the `ModifierScope` Target restriction
is model work on `modifier.dart`, the same foundation as item 40. The +5 rung is
ordinary data work and does not need to travel with it.

**Both halves are now done.** Checked 2026-08-15: every
`size-<form>` ladder in `modifiers.json` (all 9 Forms, Mentem included) now
carries a `+5` (×100,000) option, and all 4 originally-blocked spells import
using it — nobody had ticked the checkbox, but the data already reflects the
"add one rung" answer. The architectural gap below is closed too, 2026-08-16 —
see the third checkbox.

- [x] Every Size ladder in `modifiers.json` stops at +4 (×10,000); 4 published
      spells need +5 — **done, undated**: a `+5` rung exists on every ladder as
      of the 2026-08-15 check; no spell needs it blocked
- [x] Decide: add one rung, or make the ladder open-ended? — **answered by the
      data: one rung was added**, not an open-ended scheme
- [x] Add a Target restriction to `ModifierScope` (`excludeTargets`, not an
      allow-list — mirrors the existing `excludeTechniques` carve-out) and
      check it in `appliesTo()` alongside the existing
      technique/form/effectIds checks — **✅ DONE 2026-08-16.**
      `ModifierScope` gained `excludeTargets` and `appliesTo()` a `targetId`
      parameter; `size-mentem` now carries
      `excludeTargets: ["target-individual"]`. Wired all the way through:
      the creation screen's picker filters by `draft.target?.id`, and
      `SpellCreationBloc`'s `TargetSelected` handler now prunes stale
      selections via `_withPrunedModifiers` — previously the only
      Technique/Form/BaseEffect/Target handler that didn't prune, which was
      the actual bug (switching Target to Individual left a stale
      `size-mentem` selection silently contributing magnitude). See
      `docs/superpowers/specs/2026-08-16-modifier-target-scope-design.md`.

**No spell is blocked by this item anymore.** *Wrath of Whirling Winds and
Water* (CrAu 40), *Rain of Oil* (MuAu 50), *Curse of the Haunted Forest* (MuHe
40) and *Poisoning the Will* (PeMe 40) all import today, each selecting its
Form's `-5` option. The correctness gap below (Mentem's Size exemption) is
closed too, 2026-08-16 — never an import blocker to begin with.

**✅ Mentem's Size exemption is now enforced, not just documented.** Definitive
Edition line 14900: "Minds do not have a size, so size modifiers do not apply to
Mentem effects with **Individual targets**. However, minds can be counted, so for
Groups you still need to boost the size to affect more people."

- **Verified 2026-08-09:** the `size-mentem` modifier correctly exists in the data
  and the test, because Mentem *can* take Size for Group/Room/Structure/Boundary
  targets. The published spell import test expects it.
- **The architectural gap is closed 2026-08-16:** `ModifierScope.excludeTargets`
  plus `appliesTo()`'s new `targetId` parameter enforce the exemption —
  `size-mentem` is unselectable, and pruned if already selected, once Target is
  Individual, rather than relying on its description text alone.
- *Poisoning the Will* already selects `size-mentem-5` at a Boundary target and
  computes correctly to its printed level — this fix doesn't touch it. What's
  still deferred is a separate, broader question: whether Group/Room/Structure/
  Boundary should cost differently from each other under the Size ladder (today
  they're priced identically); see *Related deferred work* below, unchanged by
  this fix.

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
      - **✅ DONE 2026-08-15 — the semicolon case.** *Ball of Abysmal Flame* prints
        `(Base 25, +2 Voice; the ball appearing to shoot from your hand is a
        cosmetic effect)` — a semicolon where every other spell uses a comma, so
        the magnitude was never separated from the trailing prose and the whole
        thing failed `_TOKEN`. `_split_parts` now splits on `;` at depth 0
        alongside `,` and `.`. **Checked the corpus first, as required:** every
        design line in Chapter 9 was scanned for a `;`, and this is the *only*
        one in the whole chapter that contains one — so an unconditional split
        was safe, no conditional logic needed. (The rulebook's own
        `**Range: X; Duration: Y;**`-style guideline headers also use `;`, but
        those never reach `_split_parts` — it only ever sees text captured by
        blocks.py's `_DESIGN` line match, i.e. the `(Base ...)` line itself, not
        the guideline preamble.) The trailing clause itself needed its own entry
        in `designline.TRAILING_CONTINUATION_LABELS` (below the same discipline
        as the four fixes already there). **Surfaced one new base-effect
        ambiguity**, once the line could finally be tokenized: `crig-25a`
        ("Create a fire doing +30 damage") vs. `crig-25b` ("Create a fire
        elemental..."). Forced, not guessed — the spell's own text states "+30
        damage" verbatim against `crig-25a`'s description, and `crig-25b` is
        independently ruled out by being Ritual-only where the spell's stat line
        carries no Ritual marker at all. Recorded in `resolutions.json`. Blocked
        count 25 → 24.
      - *The Bountiful Feast*'s unbalanced brackets (item 26). **✅ DONE
        2026-08-15 — not via this function.** This was never a `_split_parts`
        bug: the printed line is genuinely missing its outer closing paren (a
        rulebook transcription defect), not oddly-but-validly nested brackets.
        Fixed via a `DESIGN_LINE_TYPOS` entry, the same narrowly-scoped mechanism
        as *Ward against Heat and Flames*'s `"+1Touch"` typo, not a change to
        `_split_parts` itself (which could silently misparse a different,
        genuinely-nested case elsewhere).
      - **✅ DONE 2026-08-15 — 4 more real corpus instances of this same family,
        fixed in one pass, all against a comma rather than `;` or brackets:**
        *Wings of the Soaring Wind* (`+2, highly unnatural` — the magnitude and
        its label separated by a comma, fixed by
        `designline._merge_comma_split_magnitudes`, plus recognising "highly
        unnatural" as the Creo Auram guideline's own "very unnatural" tier in
        `emit.py`); *Ice of Drowning*, *Frosty Breath of the Spoken Lie*, *Deluge
        of Rushing and Dashing* (each ends in a bare, comma-separated
        explanatory clause with no magnitude of its own — "changing the water to
        ice", "mist is a purely cosmetic effect and thus is free", "so that the
        whole stream floods" — fixed via a new closed allow-list,
        `designline.TRAILING_CONTINUATION_LABELS`, deliberately not a blanket
        "unsigned clause = free" rule because that would also have silently
        swallowed the *ritual*-justification clauses on other still-blocked
        spells — see item 18's correction). *Stone to Falling Dust*'s `+2
        metal/gems` was fixed alongside these (not a splitter bug — the token
        parsed fine, it just wasn't a recognised label — but it was pinned by
        the same two tests). All 5 now import; `resolutions.json` gained 3 new
        entries for the ones that then hit a genuine base-effect ambiguity once
        parsing succeeded (`lib-craq-deluge-rushing-and-dashing`,
        `lib-reaq-ice-drowning`, `lib-inme-frosty-breath-spoken-lie`). Blocked
        count 39 → 34. Files: `scripts/spell_import/designline.py`,
        `scripts/spell_import/emit.py`,
        `scripts/spell_import/tests/test_designline.py`,
        `scripts/spell_import/resolutions.json`,
        `assets/data/spell_library.json`.
- [ ] **Add the 3 missing modifiers to `modifiers.json`** — Creo Aquam unnatural
      liquids, Creo Herbam treatment, Perdo Herbam live wood. Found by a
      preamble-vs-catalog-vs-`emit.py` audit on 2026-08-07 (full report in
      scratchpad). That audit also confirmed 9 modifiers systematically wired, 2
      wired that session (Creo Auram unnatural, Terram materials), and 2 wired but
      not yet unblocking any spell (`aquam-base-individual`,
      `rego-transport-distance`).
- [x] **Extend `emit.build_spell`'s modifier mapping to `rego-transport-distance`.**
      **Superseded 2026-08-15 by items 43/45**, not by this bullet's original
      plan: `_handle_magnitude_dependent_modifier` already had a mapping block
      for `rego-transport-distance` (this bullet's premise that no mapping
      existed was stale by the time anyone looked), it just used the wrong
      option-id prefix — item 43 fixed that. What actually still blocks
      *Hermes' Portal* (see item 27) is one layer earlier: `designline.py`'s
      tokenizer doesn't recognize the distance labels at all, so `parse_design`
      never gets far enough to reach `emit.py`'s mapping — tracked as item
      **45**. `HandDerivedTest.test_the_two_non_derivable_spells_stay_correctly_blocked`
      is still green; nothing changed that test's outcome yet.
      **Update 2026-08-15: item 45 itself is now done, not just opened** — the
      tokenizer gap is closed and *Hermes' Portal* imports as `rete-4`. See
      item 45 and item 27's own entry for the full derivation.
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

### 44. Bare/Non-standard Requisite-Magnitude Phrasing — ✅ DONE 2026-08-15

Raised 2026-08-15, from an audit of the "uncategorised" third of the blocked
list. Three published spells cost a requisite's magnitude in prose `_REQUISITE`
(`designline.py`) didn't recognise — a parser gap, not a modelling gap: the
underlying mechanism (`Requisite`/`RequisiteKind.adding`, item 2) already
supported a costed requisite fully.

- [x] Two of the three (a trailing justification, an art name mid-phrase) got a
      closed allow-list, `designline.REQUISITE_LABEL_ARTS`, keyed by exact label
      text — the same discipline as `ADJUSTMENT_LABELS`
- [x] The third (a bare `+1 requisite`, no art at all) needed a different
      mechanism: `designline.py` never sees the `Req:` line, so it can't resolve
      which art the magnitude belongs to. It now emits a `Token` with an empty
      label (`_BARE_REQUISITE`), resolved in `emit.py`'s new
      `_resolve_requisite_label`, which reads `block.stat.requisite_arts` and
      raises rather than guesses if that list doesn't have exactly one entry
- [x] Re-ran `--show-blocked` and confirmed all 3 spells import with the
      printed level matching the computed one (assertion 1) — no ledger entry
      was needed for any of the three (each had a unique base-level candidate)

**The 3 spells**, corrected against the real rulebook headings (the table below
originally guessed The Eye of the Sage's Technique+Form from its `Req:` line,
which was wrong — the requisite art is not the base art):

| Spell | Base Technique+Form | `Req:` | Failing label |
|---|---|---|---|
| *Obliteration of the Metallic Barrier* (PeTe 20) | Perdo Terram | Rego | `Rego to fling the fragments away` |
| *Phantasmal Fire* (CrIm 20) | Creo Imaginem | Ignem | `for light from Ignem requisite` |
| *The Eye of the Sage* (InCo 30) | Intellego Corpus | Imaginem | `requisite` (bare) |

**Why this was its own item, not item 24's.** Item 24 is per-spell prose the
importer deliberately never models (no words, no gestures, Techniques and
Forms) because there is no printed magnitude to derive from and guessing would
be wrong. These 3 were the opposite case: the magnitude *was* printed
(`+1 Rego`, `+1 for light...`, `+1 requisite`), the mechanism was fully modelled
already, and only the label's wording was unrecognised — the same shape as item
29's punctuation fixes, not item 24's judgement calls.

- **Files:** `scripts/spell_import/designline.py`,
  `scripts/spell_import/emit.py`,
  `scripts/spell_import/tests/test_designline.py`,
  `scripts/spell_import/tests/test_emit.py`,
  `assets/data/spell_library.json`

---

## B. Deferred by Design — Derived Outputs

Not import blockers. Both stay as descriptive text on the spell, which is what the
rulebook itself does. **Why these two are together:** both read the *final computed
level* and produce a different quantity from it — a genuinely different shape from
`option → magnitude`, and the point the Spell Modifiers spec identified as where a
code seam earns its place.

### 4b. Intensity/Damage Modifiers
- [ ] Muto/Perdo Ignem: add 1 magnitude per 5 points fire damage exceeds +5
- **The one published spell that motivated this item is no longer blocked, and
  wasn't Muto/Perdo Ignem to begin with.** *Ward against Heat and Flames* is
  **Rego** Ignem, `+2 for up to +15 damage`, and it turned out to already have a
  real catalog mechanism — `rego-ignem-fire-intensity` (`assets/data/
  modifiers.json`), scoped to `reig-4` among others, magnitude 2 = the
  `-15` option. **Fixed 2026-08-15**: `emit.py`'s
  `_handle_magnitude_dependent_modifier` now maps this exact label to that
  option; `designline.MODIFIER_LABELS` recognises the token. The spell imports.
  (The earlier "item 24 already expresses [it]" note was wrong — item 24 is
  per-spell adjustments with no catalog mechanism; this is a real, reusable,
  already-catalogued modifier that just wasn't wired up.)
- **What's still open, and now genuinely scoped to Muto/Perdo Ignem**: no
  published spell currently needs it (the one that did is fixed above), so this
  remains real but not import-blocking — a display/derivation question in the
  same shape as item 42.
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

### 47. Multiple Base Effects in Spell Creation — Combined Guidelines

**Not on the critical path — item 39 already handled its one published
case with a narrow, one-off mechanism, not a general feature.** But that
case is real, and a user designing their own spell has no way to do what
*Conjuration of the Indubitable Cold* does.

- [ ] Let a spell draft record more than one base effect, restricted to
      guidelines matching the spell's own Technique/Form **or** the
      Technique/Form of one of its requisites (mirroring how the Requisites
      section already treats requisite Arts as legitimately contributing an
      effect, not just a cost)
- [ ] The **highest-level** base effect among those chosen is recorded as
      `baseEffectId` and drives the calculation, per the rulebook's own
      stated rule for combining effects across Arts: *"the base Arts and
      level for the spell are those for the highest-level effect it
      has"* (Requisites, Core Rules) — the closest the rulebook comes to a
      general rule for this, though it's written for an added Art, not a
      second guideline under the same Technique/Form
    - **Open question:** is "free" (item 39's answer) actually general, or
      only true when both guidelines share a level? The Requisites section's
      own rule for *unequal*-level combinations charges extra ("each
      requisite adds at least one magnitude" when it "would do significantly
      less" without it) — a general feature likely needs that branch too,
      not just the same-level case item 39 hard-coded
- [ ] The other chosen base effect(s) are recorded as **structured data**,
      not just a hand-typed note — a `List<String>` of base-effect ids reads
      better than free text, since the UI can render each one's own
      `description` straight from `base_effects.json` instead of a
      paraphrase the user has to keep in sync by hand
- **Decide first: extend `adjustments` (`List<LevelAdjustment>`,
  `lib/models/spell.dart`), or add a dedicated field?** Item 39's importer
  fix reused a magnitude-0 `LevelAdjustment` because it only had to solve one
  spell with no UI; overloading that field for a real, repeatable UI feature
  would leave "achieves another guideline for free" indistinguishable from
  "storyguide subtracts a magnitude for narrative reasons" — two different
  concepts sharing one shape by accident.
- **No published spell is currently blocked by lacking this** — item 39's
  one known case already imports via
  `extract_spells.COMBINED_BASE_EFFECTS`/`emit.build_spell`'s
  `extra_adjustment` parameter. This item is about the creation screen, not
  the importer.
- **Files:** `lib/models/spell.dart` (`Spell`, `SpellDraft`),
  `lib/engine/spell_engine.dart`, `lib/bloc/spell_creation/`,
  `lib/presentation/screens/spell_creation_screen.dart`
- **See also:** item 39 (the one published spell that motivated this)

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
Fidelity work on already-imported spells, **now true of all 7** — the three that
were blocked at time of writing are fixed; what remains is genuinely just the UI
work below.

**✅ DONE 2026-08-15 — the tokenizing half of the correction below.**
*Curse of the Ravenous Swarm*, *Neptune's Wrath* and *Breath of the Open Sky* now
import/template with an incomplete `RitualDeclaration`, same as the other 4. Fixed
in `designline.py`, not `emit.py`: their ritual-justification clauses (`ritual
because it has a really major effect`, `ritual for large effect`, `ritual because
of spectacular effect`) and Curse of the Ravenous Swarm's own upstream `for a
swarm weighing as much as one thousand pigs` are now in
`designline.TRAILING_CONTINUATION_LABELS`, same shape as item 29's fixes and the
same discipline — a closed allow-list, checked against each spell's own printed
level, not a blanket "unsigned clause = free" rule. Curse of the Ravenous Swarm
also needed a second fix: its `+1 extra effect from requisite` (Req: Rego on the
stat line) is a bare-requisite phrasing `_BARE_REQUISITE` didn't recognise, now
folded into `_BARE_REQUISITE_LABELS` alongside "+1 requisite" (item 44's bare
case) — same resolve-against-the-sole-Req:-art mechanism in `emit.py`. All three
computed levels match their printed levels (CrAn 50, ReAq 40, CrAu 40); no new
base-effect ambiguity. **Nothing in `extract_spells.py` gates on Ritual
correctness specifically** — this fix only got the 3 spells as far as importing
with the same incomplete `RitualDeclaration` the other 4 already had; it did not
touch `storyguideRuling`, which is still what the checklist below is about.
Files: `scripts/spell_import/designline.py`, `scripts/spell_import/emit.py`,
`scripts/spell_import/tests/test_designline.py`, `assets/data/spell_library.json`.

- [x] Expose `RitualDeclaration.storyguideRuling`, which the model supports and
      three built-in spells already use, but no control sets
- [x] Revisit `SpellCreationBloc._withRitualDeclaration` so the two declaration
      kinds stay distinguishable once both are user-settable
- **✅ DONE 2026-08-16.** `RitualSection`'s single lasting-creation checkbox is
  now a three-way `RadioGroup<RitualDeclaration>` (Not declared / Creates
  something lasting / Storyguide ruling: too spectacular to be freely
  available), wired through the existing `RitualDeclarationChanged` event —
  no new event type needed. The "Creates something lasting" option is still
  gated to Creo + Momentary (`showLastingCreationOption`, renamed from
  `showDeclarationCheckbox`); the storyguide-ruling option is always shown,
  since line 12352 lets the troupe declare *any* spell a Ritual. Exploration
  found `_withRitualDeclaration` already special-cased `storyguideRuling`
  correctly (returns the draft untouched before checking lasting-creation
  eligibility at all) — that path was previously only reachable via template
  data, never live user input. 5 new bloc regression tests exercise it under
  real events (`TechniqueSelected`/`FormSelected`/`BaseEffectSelected`
  survival, direct `lastingCreation`→`storyguideRuling` replacement, explicit
  clear to `none`) and all passed immediately, confirming no bloc logic
  change was needed. Files: `lib/presentation/widgets/ritual_section.dart`,
  `lib/presentation/screens/spell_creation_screen.dart`,
  `test/presentation/widgets/ritual_section_test.dart`,
  `integration_test/spell_creation_flow_test.dart`,
  `test/bloc/spell_creation_bloc_test.dart`. Spec:
  `docs/superpowers/specs/2026-08-16-storyguide-ruling-ui-design.md`. Plan:
  `docs/superpowers/plans/2026-08-16-storyguide-ruling-ui.md`.
- **Correction to the checklist bullet above and to the design spec's own
  premise:** the final whole-branch review checked `assets/data/spell_library.json`
  directly and found **zero** spells carry `ritualDeclaration: storyguideRuling`
  — *Curse of the Ravenous Swarm*, *Neptune's Wrath* and *Breath of the Open
  Sky* all carry `lastingCreation` instead, which item 43's fix (2026-08-15)
  never touched. "three built-in spells already use it" was wrong when
  written; `storyguideRuling` has no catalog coverage at all as of this fix,
  only the new UI path to set it by hand. The review also flagged that
  *Curse of the Ravenous Swarm* (Creo Animal, Moon duration) plainly doesn't
  "create something lasting", so its `lastingCreation` value looks like a
  placeholder from whoever imported it. **Root-caused and reclassifying
  deferred to [[49]]**, not this item — a Python-import-pipeline bug, not a
  UI concern.
- **Also found live by the same review:** `TemplateInstantiated` copies a
  template's `ritualDeclaration` verbatim (deliberately, for cases like
  Disenchant), so a draft can carry `lastingCreation` while ineligible for
  that radio option (Disenchant is Perdo, not Creo). The UI now widens the
  option's visibility to cover this case too, so the declaration is never
  silently unselectable or a one-way clear. Fixed in the same branch, before
  merge.
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

### 49. `emit.py` Mistags Ritual Declarations by Blanket-Assigning `lastingCreation`
Found 2026-08-16 while closing [[18]]'s UI checklist (surfaced independently by
a human read of *Curse of the Ravenous Swarm*'s own design line, and confirmed
by the branch's final review reading `assets/data/spell_library.json` directly).

- [x] Stop `scripts/spell_import/emit.py` from unconditionally stamping
      `ritualDeclaration: "lastingCreation"` onto every Ritual-flagged spell —
      it did this in two places, `build_spell` and `build_template`
      (`if block.stat.is_ritual: spell["ritualDeclaration"] = "lastingCreation"`,
      and the identical line for `template[...]`), with no regard for *why*
      the spell is a Ritual.
- [x] Correctly classify the spells whose Ritual status is **only**
      derivable from the declaration — [[18]]'s "7 non-derivable Ritual
      spells" list: *Curse of the Ravenous Swarm* (CrAn 50), *Neptune's
      Wrath* (ReAq 40), *Breath of the Open Sky* (CrAu 40) are now
      `storyguideRuling`, not `lastingCreation` — each spell's own design
      line already carried the condition-6 justification verbatim (`ritual
      because it has a really major effect`, `ritual for large effect`,
      `ritual because of spectacular effect`; tokenized as trailing
      continuations by `designline.TRAILING_CONTINUATION_LABELS`, but never
      read for their *content*, until now). *Rain of Oil* (MuAu 50),
      *Incantation of Summoning the Dead* (ReMe 40), *Disenchant* (PeVi Gen),
      and *Watching Ward* (ReVi Gen) are **not** covered by this fix — those
      four never carried either declaration to begin with, so there was
      nothing to reclassify; [[18]] speculated the two Vim Generals "may be
      guideline-level" rather than either declared kind, which is a
      different, still-open fix (a `ritualRequirement` on the base effect,
      not a per-spell declaration).
- ✅ **DONE 2026-08-16.** `emit.py` now carries a closed, exact-name
  `STORYGUIDE_RULING_SPELLS` table (same discipline as `HAND_DERIVED`/
  `EXCEPTION_SPELLS`) and a `_ritual_declaration(block)` helper that both
  `build_spell` and `build_template` call instead of the blanket assignment.
  8 new tests in `scripts/spell_import/tests/test_emit.py`
  (`RitualDeclarationEmissionTest`) pin the default, the override, and the
  table's exact membership. `assets/data/spell_library.json` regenerated via
  `python -m scripts.spell_import.extract_spells --write` — same counts
  (imported 325, templates 27, exceptions 8, blocked 0) and a 3-line diff,
  exactly the 3 spells' `ritualDeclaration` field
  (`spell_templates.json`/`spell_exceptions.json` unchanged). Python suite
  (288 tests, run as module rather than via `discover` — see note below) and
  `flutter test` (571 tests) both green.
- ~~**Note on running the Python suite:** `python -m unittest discover -s
  scripts/spell_import/tests` fails to import `test_general_catalog.py`...~~
  **Fixed 2026-08-16.** Root cause: `test_general_catalog.py` was the only
  file under `scripts/spell_import/tests/` importing via `from .. import
  ...`; all 13 siblings use `from scripts.spell_import import ...`, which is
  what survives `unittest discover`'s module loading. Switched the one
  outlier to match — `python -m unittest discover -s
  scripts/spell_import/tests -p "test_*.py"` now runs all 296 tests clean.
- **Not a behavior bug for the other 32 Ritual-flagged spells.** Their
  `isRitual` already derives independently (Year duration, Boundary target,
  level > 50, or a guideline requirement), so a wrong stored declaration
  never changed their computed level or `RitualStatus.isRitual` — only these
  3 spells' in-app Ritual banners previously said something the rulebook's
  own text contradicted.

### 50. `size-terram` on an Intellego Spell — Rulebook-Printed Exception to the `excludeTechniques` Rule

Found 2026-08-16 investigating item 19's final-review follow-up (a proposed
corpus-level guard: every selected modifier should be in scope for its own
spell/template). Writing that guard immediately failed on one spell,
unrelated to item 19's own Target work.

- [ ] Decide how to model *Sense the Feet that Tread the Earth* (InTe 30,
      `lib-inte-sense-feet-that-tread-earth`), whose own printed design line —
      "(Base 4, +1 Touch, +1 Conc, +1 Part, +3 size)" (rulebook line 15402) —
      applies a Size magnitude despite being Intellego, contradicting the
      general rule modeled as `excludeTechniques: ["Intellego"]` on every
      `size-<form>` modifier (Core Rules line 12288/23232: "Intellego spells
      are not affected by Target size").
- **Verified the arithmetic is load-bearing, not incidental.** Base 4 +
  Touch(1) + Conc(1) + Part(1) + size-terram-3(3) = 6 magnitude-units; the
  first fills the additive tier (base 4→5), the remaining 5 apply at ×5:
  4+1+25=30, exactly the printed level. Without the Size selection the spell
  computes to 15, not 30.
- **Confirmed narrow, not systemic.** The only other two spells built on the
  same base effect (`inte-4a`) — *Eyes of the Eons*, *Tracks of the Faerie
  Glow* — select no modifiers at all. Across the entire 325-spell/27-template
  corpus, this is the *only* Intellego spell selecting any `size-<form>`
  modifier — the corpus-level guard (below) reports exactly one failure.
- **Considered and rejected: item 46's `ExceptionSpell` mechanism.** The
  spell's own prose ("...does not fit well into Hermetic theory") closely
  echoes *Wizard's Communion*'s exception rationale ("does not perfectly fit
  into the guidelines of Hermetic theory") — a real, notable parallel. But
  `ExceptionSpell` exists specifically for spells with **no computable
  arithmetic** (no design line, or an R/D/T shape the model can't express).
  This spell has neither problem: its design line is complete,
  standard-shaped, and sums to the printed level exactly. Routing it through
  `ExceptionSpell` would discard a correct computed breakdown for free-text
  rationale — a worse representation of a spell that already works.
- **The real gap: `ModifierScope` has no per-spell granularity.** Its axes
  are technique/form/effectIds/excludeTechniques/excludeTargets (item 19) —
  all catalog-level, none keyed to an individual spell or base effect id
  alone (an `effectIds`-based override would open the door for *any* future
  `inte-4a` spell, not just this one printed one — broader than the evidence
  supports). Whatever mechanism is chosen needs to answer that precisely, not
  approximately.
- **A related discovery, already fixed separately:** the spell's name was
  transcribed as "...Thread the Earth" in the reviewed Definitive Edition's
  own heading (line 15399) — contradicted by that same file's own generated
  index (line 24019, anchors to `...tread-the-earth`) and by two other
  sourcebooks in the same checkout (*Against the Dark*, *Legends of Hermes*),
  both consistently "Tread". Corrected via a new `SPELL_NAME_TYPOS` table in
  `extract_spells.py` (same discipline as `DESIGN_LINE_TYPOS`), applied
  before slug_id generation so the id changed too; `resolutions.json`'s
  ledger key and `test_ledger.py`'s independent-reparse guard were updated to
  match. Unrelated to the Size question above — noted here only because both
  were found investigating the same spell in the same session.
- **The guard test to add once this is resolved** — written, verified to
  correctly catch exactly this one case, then reverted rather than committed
  failing:
  ```dart
  test('assertion 8: every selected modifier is in scope for its own spell or template', () async {
    final modifiers = {for (final m in await loader.loadModifiers()) m.id: m};
    final failures = <String>[];

    void checkScope({
      required String label,
      required String technique,
      required String form,
      required String baseEffectId,
      required String targetId,
      required Map<String, List<String>> selectedModifiers,
    }) {
      for (final modifierId in selectedModifiers.keys) {
        final modifier = modifiers[modifierId];
        if (modifier == null) continue; // assertion 4 already covers this
        final inScope = modifier.scope.appliesTo(
          technique: technique, form: form,
          baseEffectId: baseEffectId, targetId: targetId,
        );
        if (!inScope) {
          failures.add('$label: $modifierId is out of scope for '
              '$technique $form / $baseEffectId / $targetId');
        }
      }
    }

    for (final spell in await loader.loadSpellLibrary()) {
      checkScope(label: spell.name ?? spell.id, technique: spell.technique,
          form: spell.form, baseEffectId: spell.baseEffectId,
          targetId: spell.targetId, selectedModifiers: spell.selectedModifiers);
    }
    for (final template in await loader.loadSpellTemplates()) {
      checkScope(label: template.name, technique: template.technique,
          form: template.form, baseEffectId: template.baseEffectId,
          targetId: template.targetId, selectedModifiers: template.selectedModifiers);
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
  ```
- **Files:** `lib/models/modifier.dart` (`ModifierScope`, if a new axis is
  needed), `assets/data/modifiers.json` (`size-terram`'s scope, if a
  targeted override is chosen), `test/data/published_spell_import_test.dart`
  (the guard above, once the model question is settled).

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

### 37. A Template Has Open Slots Beyond Its Level — Realm, Form, "Specific Type" — ✅ DONE 2026-08-15
**In section 0, jointly with item 35.** Raised 2026-08-07 from *Wizard's Reach
(Form)*: the Form must be chosen before the template can become a spell, exactly as
the level must be. **This generalises item 35** (realm is one slot of several) for
part of the corpus; the part it does not cover is a different mechanism. Both are
named so they can be designed together; [[35]] stays as the realm instance.

**Both parts shipped.** Designed in
`docs/superpowers/specs/2026-08-10-open-guideline-slots-design.md`.

- **Part A (realm) — DONE 2026-08-14**, via
  `docs/superpowers/plans/2026-08-10-open-guideline-slots-part-a.md`: the generic
  `OpenSlotKind`/`chosenSlots` mechanism (model, validation checks 6/7, bloc, UI) plus
  a full, working realm instance — 17 catalog entries annotated, a hand-verified
  `REALM_BY_SPELL_ID` table (not a prose scan — one was tried and demonstrably
  misfires on the real corpus, see the spec's Decision 7) feeds 6 real corpus
  templates their `chosenSlots`.
- **Part B (Form + "a specific type" + the 3 case-2 Muto Vim spells) — DONE
  2026-08-15**, via
  `docs/superpowers/plans/2026-08-14-open-guideline-slots-part-b.md`: 7 more
  catalog entries annotated (`pevi-G2/7/10/11`, `revi-G5`, `muvi-G2/G3` —
  `muvi-G1` deliberately excluded, its only corpus user never mentions Form), a
  Form dropdown and a specificType free-text field added to the creation screen.
  **No resolution table was needed for Part B at all** — unlike most of Part A's
  realm entries, every real corpus template on these 7 guidelines is genuinely
  case-2 (none commits to one value in its own prose), so asset regeneration
  produced a byte-identical `spell_templates.json`, confirmed by the Python
  suite's `RegenerationTest`, not just a git diff. The mechanism took Part B
  with zero reshaping, exactly as Decision 8 predicted (see the spec's
  Decision 13 for the full implementation-time confirmation).

- **Case 1 — the guideline itself leaves a slot open.** Measured: **20 of the 49
  General bullets (41%)**. By slot kind: **realm** ~15 (*"beings … from one
  supernatural realm (Divine, Faerie, Infernal, or Magic)"*, and PeVi's *"any
  supernatural effect of one realm"*); **"a specific type"** 4 (PeVi bullets 2, 7, 10
  and ReVi 5 — the rulebook's own examples are *"Hermetic Terram magic, or Shamanic
  spirit control magic"*); **Form** 2 (PeVi 10's *"a particular Hermetic Form"*, PeVi
  11's *"a given Form"*). Filling the slot is part of choosing the guideline; the
  slot is a property of the catalog row.
  - **✅ Reconciled 2026-08-10:** 15 was correct, not 14 — item 35's original count
    used a JSON keyword search whose stored description for `pevi-G5` drops the
    words "of one realm" during extraction (an item-22-shaped gap). Reading the
    rulebook prose directly gives 15 General + 2 fixed-level (`revi-5`, `revi-15`) =
    **17 catalog entries with an open realm slot**, the authoritative count (design
    spec Decision 1).
- **Case 2 — the guideline says nothing and the *spell* comes in ten versions.**
  Three Muto Vim spells: *Mirror of Opposition (form)* (*"There are ten versions of
  this spell, each affecting spells of one of the Hermetic forms"*), *Wizard's Boost
  (Form)*, *Wizard's Reach (Form)*. `muvi-G1/G2/G3` mention Form nowhere — they are
  Form-agnostic and the restriction belongs to the published spell.
  - **✅ Corrected 2026-08-15, during Part B implementation:** *Unravelling the
    Fabric of (Form)* was originally guessed here as case 1 ("the Form is that
    slot being filled"). Checking its actual prose during implementation showed
    it's **also case 2**: *"There are 10 variants that cover each Hermetic Form,
    and a number of much rarer variants for different kinds of non-Hermetic
    magic"* — a family, not one committed value, same as the three Muto Vim
    spells. `pevi-G2` got `openSlots: [specificType]` (not `form`); a Form name
    is simply a valid free-text value for that slot when a caster picks one.
  - Also found during Part B: `muvi-G2` is shared by the Form-restricted spells
    above **and** by *The Sorcerer's Fork* (already in the corpus, genuinely
    Form-agnostic prose). Declaring the slot per-guideline anyway was a
    deliberate, human-approved decision (design spec Decision 12) — see [[37]].
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
- **✅ Decided 2026-08-10, implemented 2026-08-15:** free text, not a closed
  set — the rulebook gives illustrative examples ("could be X, or Y"), not an
  exhaustive list; a closed set risks rejecting a legitimate type it didn't happen
  to list (design spec Decision 4).

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

### 35. A Guideline's Realm Is a Choice, Like Its Level — ✅ DONE 2026-08-14
**Generalised by item 37; designed the two together**, then implemented as item 37's
Part A — see [[37]] for the shipped mechanism (both parts now done).

- [x] Decide where the chosen realm lives — **not `Spell.chosenRealm`**, as first
      guessed here: a general `chosenSlots: Map<String, String>` on
      `Spell`/`SpellDraft`/`SpellTemplate`, keyed by slot kind, absorbs all three
      axes (and `pevi-G10`'s either/or) for one plumbing cost instead of three
      (design spec Decisions 2/3)
- [x] Decide whether the realm is part of validation — yes, checks 6 (mandatory,
      unless declared open by the effect) and 7 (stray-kind rejection) in
      `validateSpellAgainstCatalog`
- [x] Decide whether the import reads the realm out of published prose — yes, but
      via a **hand-verified table** (`REALM_BY_SPELL_ID`), not a scan: a scan was
      tried and demonstrably misfires on the real corpus (design spec Decision 7)
- [x] Check whether "one realm" is the only such axis — no, confirmed and shipped
      generically: `OpenSlotKind` also carries `form`/`specificType` for Part B
- **What was noticed.** Seventeen catalog entries leave a realm open (see item 37's
  reconciled count above), phrased *"from one supernatural realm (Divine, Faerie,
  Infernal, or Magic)"*. Fifteen are General — all twelve wards, plus `pevi-G5`,
  `pevi-G6` (reduce the casting total for all powers of one realm) and `pevi-G12`
  (dispel Magic Resistance aligned to one Realm). **Two are ordinary Rego Vim rows,
  `revi-5` and `revi-15`** — so this is **not** a General-only problem, which is why
  it was not folded into item 25.
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
  (`ward, so the target is the warded Individual, not the water`). **Its import
  blocker is fixed (2026-08-15)**: those three trailing comma-clauses are now in
  `designline.TRAILING_CONTINUATION_LABELS`, and its own base-effect ambiguity
  (Rego Aquam, base 5, 4 candidates) resolved to `reaq-5a` ("ward against mundane
  water" — the only warding candidate of the four, matching the design line's own
  word "ward"; see `resolutions.json`). It imports today. The other 12 need nothing
  beyond item 25. What's left of this item is purely the ward-type display field
  above, still open.

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

### 41. Row-Duplication Ladders Across the Catalog (item 28's shape, elsewhere)

Raised 2026-08-15, after item 28 shipped, when the user asked whether other
Technique+Form pairs have the same "separate numbered row per rung" shape that
item 28 refactored for Creo Vim's Warping Point ladder and Perdo Ignem's
chill-damage ladder. A systematic scan of `assets/data/base_effects.json`
found 13 more families with the identical shape. **None currently block any
corpus spell** — unlike item 28's original 5, every spell referencing these
rows today lands on an exact existing row. The value here is item 28's *other*
goal: decluttering the spell-creation UI (fewer near-duplicate base-effect rows
to pick from) and future-proofing against a spell that eventually needs an
in-between level. See [[35]]/[[37]] and item 28's own design/plan
(`docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md`) for
the refactor pattern to mirror: delete the redundant rows, add one
`selectionMode: single` ladder modifier (like `warping-point-burst`/
`chill-damage`), re-verify every corpus/ledger reference to the deleted rows
(item 28's Task 1 caught a real near-miss doing exactly this for `peig-10b`).

**13 families found:**

| Technique+Form | Rows | 2nd axis? | Notes |
|---|---|---|---|
| Creo Ignem damage | `crig-4a/5a/10a/15/20a/25a` (6 rows, levels 4-25, +5 to +30 damage) | — | Irregular first step (4→5 is +1 level not +5, matches the book exactly) |
| Creo Ignem "unnatural shape" | `crig-5b/10b/20b` (3 rows) | **Yes** — crossed with the damage axis above at the same levels | No level-15 rung exists (matches the book, not a gap) |
| Rego Ignem wards-vs-fire | `reig-15b/20/25/30/35/40` (6 rows, +5 to +30 damage warded) | — | Perfectly regular. Distinct from the Rego Ignem fire-intensity modifier in the additive-track spec (item 3 there) — a different guideline entirely |
| Rego Terram hurled projectile | `rete-5d/10/15b` (3 rows, +5/+10/+15 damage) | — | Perfectly regular, book's table stops at 15 |
| Rego Corpus teleport distance | `reco-10d/15d/20a/25a/30/35` (6 rows) | — | Same underlying rule as the already-shipped `rego-transport-distance` modifier (see the additive-track spec's item 1 scope fix) — Corpus's version was digitized as rows instead of being added to that modifier's scope |
| Creo Animal/Corpus/Mentem characteristic increase | `cran-30b..55`, `crco-30b..55`, `crme-30..55` (6 rows each, 3 Forms) | — | Same mechanic repeated per-form — one shared modifier pattern, not three parallel ladders |
| Creo Animal/Corpus Recovery bonus | `cran-1..20b` (8 rows), `crco-1a..15b` (7 rows) | — | Two-phase irregular first step in both, matches each Form's own book table; Corpus stops at 15, Animal continues to 20 |
| Muto Corpus Soak bonus | `muco-5a/10b/15/20b/25b` (5 rows) | — | Perfectly regular |
| Intellego Vim detect-magnitude threshold | `invi-1a/2a/3a/4a` (4 rows) | — | Irregular steps (−2,−2,−3), matches the book |
| Creo/Intellego/Muto Imaginem senses | `crim-1..5`, `inim-1a..5`, `muim-1..4` (+ `muim-5`, confirmed a **false positive** — a distinct top-end guideline, not "5 sensations") | — | Regular where genuine |
| Perdo Vim AC-duration-steps | `pevi-5/10/15/20/25/30` (6 rows) | — | Perfectly regular, same style as the already-shipped Warping-Point-burst |
| Creo Vim decay-steps | `crvi-5b/10b/15b` (3 rows) | Sits in the same table cells as the already-refactored Warping-Point-burst guideline | Item 28's own design spec explicitly considered and declined to touch this — a conscious prior decision worth revisiting or reaffirming, not an oversight |

**Also found:** `rean-10b` (Rego Animal) and `reaq-4b` (Rego Aquam) state the
*same* transport-distance formula as the already-shipped `rego-transport-distance`
modifier but are missing from its `effectIds` — this specific one-line fix is
small enough it was folded into the additive-track spec instead
(`docs/superpowers/specs/2026-08-15-additive-guideline-modifiers-design.md`,
item 1), not left here.

**Confirmed false positives, not part of this list:** Wound-severity rows
(Light/Medium/Heavy/Incapacitating) across every Form, Creo Ignem's
light-equivalence rows (moonlight/candlelight/torchlight), Rego Auram's
weather-intensity tiers, Muto Ignem's natural-vs-unnatural transformation rows
— all read as near-duplicates under fuzzy text matching but are each a
qualitatively distinct guideline in the book, not a hidden numeric ladder.

- **Files:** `assets/data/base_effects.json`, `assets/data/modifiers.json`,
  `assets/data/spell_library.json` (re-verify every corpus reference per
  family before deleting its rows)

### 42. Derived Ease Factor Display for Poison/Disease Guidelines

Raised 2026-08-15, alongside item 41, then split out as a separate item because
it isn't the same *kind* of gap. Perdo Corpus (disease) and Creo/Muto Aquam
(poison) each state a rule like *"Each magnitude added to the level of the
spell adds 3 to the Ease Factor"* — this is not a modifier a caster selects; it's
a **passive consequence of the spell's final level**, however that level was
reached (Size, Duration, any other modifier). Modeling it as a
`selectionMode: single` modifier (the pattern items 28 and 41 use) would be
modeling the wrong mechanism — it's closer to `craq-gen`'s `effectFormula`
mechanism (a value derived from the chosen/final level and displayed, not
selected) than to anything in the modifier system.

- [ ] Decide the display mechanism: likely a read-only derived field shown
      wherever a poison/disease guideline is used, computed as
      `base Ease Factor + (rate) × (magnitudes above the guideline's own base
      level)` — needs its own design, not a small addition to an existing one.
- **Only one base effect touches disease today** (`peco-20b`, "Inflict a major
  disease"); Creo/Muto Aquam's poison guidelines already have 5 rows each
  (`craq-5a/10b/15/20/25a`, `muaq-2b/3a/4c/5c/10b`) encoding the wound-severity
  table, separate from this formula.
- **Files:** likely `lib/engine/spell_engine.dart` or wherever `effectFormula`
  is currently rendered/derived, `assets/data/base_effects.json` (adding the
  formula rate to `peco-20b` and the Aquam poison rows)

### 43. `emit.py`'s `rego-transport-distance` Option-Id Mapping Is Stale — ✅ DONE 2026-08-15

Found 2026-08-15 during the additive-guideline-modifiers final review — a
pre-existing bug, unrelated to that branch's own changes, spotted only
because the review re-checked every consumer of the modifier whose scope it
widened. `scripts/spell_import/emit.py`'s `_handle_magnitude_dependent_modifier`
mapped `rego-transport-distance`'s distance choice to option ids
`rego-transport-distance-5-paces` … `-arcane`, but the modifier's actual
option ids in `assets/data/modifiers.json` are `rego-distance-5-paces` …
`rego-distance-arcane`. `_option_exists` therefore always failed for this
modifier. Fixed the id prefix (6 dict values) and the comment's stale
`reaq-5, rean-5` (never-real ids) to `rean-10b, reaq-4b`.

**Reachability caveat found while fixing, not closed by this fix:**
`designline.py`'s `MODIFIER_LABELS` allow-list does not recognize the
distance-ladder labels ("distance", "50 paces", etc.) as modifier-kind
tokens at all, so `designline.parse_design` rejects them with
`UnknownToken` before `emit.py`'s (now-correct) mapping is ever reached.
This is a separate, larger, pre-existing gap — independently documented in
`extract_spells.py`'s `HAND_DERIVED` comment on *Hermes' Portal*, which
calls wiring it up "a real fix, just a different and larger one than
'correct this string'". Tracked separately as item **45**. The regression
test added here (`TransportDistanceEmissionTest` in
`scripts/spell_import/tests/test_emit.py`) proves the id-mapping table
itself is now correct by constructing `designline.Design`/`Token` objects
directly, bypassing the tokenizer gap rather than depending on it closing.
Confirmed no import counts moved (`311/24/25/0` before and after) — this
modifier is genuinely still unreachable end-to-end until item 45 lands.

- **Files:** `scripts/spell_import/emit.py`, `scripts/spell_import/tests/test_emit.py`

### 45. Design-Line Tokenizer Doesn't Recognize Transport-Distance Labels — ✅ DONE 2026-08-15

Found 2026-08-15 while fixing item 43. `designline.MODIFIER_LABELS` (a
closed allow-list deciding which printed design-line labels tokenize as
`kind="modifier"` at all) has no entries for `"distance"`, `"arcane
connection"`, `"5 paces"`, `"50 paces"`, `"500 paces"`, `"1 league"`, or
`"7 leagues"` — so even with item 43's id-prefix fix landed, no real design
line can reach `rego-transport-distance` yet; `parse_design` itself raises
`UnknownToken` first. `extract_spells.py`'s `HAND_DERIVED` comment on
*Hermes' Portal* (R: Arc, D: Year, T: Ind, level 75) already names this as
the reason that spell is left permanently blocked rather than derived via
`rete-4`'s distance ladder at its top rung.

Unlike item 43, this needs a real design decision, not a mechanical string
fix: which of the 7 labels to accept, whether "distance" (bare, no
qualifier) should map to anything or always raise, and whether adding
these labels is enough on its own to unblock *Hermes' Portal* end-to-end
or whether its 35-level gap (see item 27) needs something else besides.

- [x] **Decided:** the 6 concrete distance-ladder labels (5/50/500 paces, 1/7
      leagues, arcane connection), checked against the whole corpus first.
      Bare `"distance"` deliberately excluded — it names no real option in
      `rego-transport-distance`'s own table, so it keeps failing at the
      tokenizer rather than succeeding here and failing one layer deeper in
      `emit.py` with a near-identical message.
- [x] Wired via `designline.MODIFIER_LABELS`.
- [x] **Confirmed: sufficient on its own, no other gap.** The magnitude
      arithmetic (4 base + 4 Arc + 4 Year + 5 arcane-connection modifier + 2
      size = 19 magnitudes) reaches level 75 exactly. *Hermes' Portal* now
      imports as `rete-4`.
- **Files:** `scripts/spell_import/designline.py`, `scripts/spell_import/extract_spells.py`

### 46. Exception Spells — ✅ DONE 2026-08-16, extended to 7

Six published spells share a failure mode distinct from every other blocked
spell: the rulebook itself, in the spell's own printed text, says guideline
arithmetic doesn't apply — not a missing catalog row, not an ambiguous
resolution, a genuine "this was never designed that way." *Wizard's
Communion*, *Wizard's Vigil* and *Aegis of the Hearth* (General-kind, no
printed level, moved out of item 25); *Whispering Winds* (moved out of item
27); *Watching Ward* and *Mists of Change* (moved out of item 26).

**A seventh, different in kind, moved in the same day:** *Sight of the True
Form*, out of item 25. Not rulebook-disclaimed and not schema-mismatched —
the original two shapes this item designed for — but a third: its General
guideline genuinely isn't printed in Intellego Corpus's own table (verified,
not assumed), and a catalog row reconstructed from its prose was already
tried once (`inco-gen`) and reverted as fabrication. `exceptions.py`'s module
docstring documents this third shape; item 25's body explains why the same
reasoning does *not* extend to that item's remaining four (they were also
checked, 2026-08-16, and the user's choice was exception-spell treatment for
this one spell only, not a blanket extension).

- [x] A new `ExceptionSpell`/`ResolvedException` model pair, parallel to how
      `SpellTemplate` sits alongside `Spell` — free-text Range/Duration/
      Target instead of catalog references, a required `rationale` citation
      instead of computed arithmetic, no `SpellLevelCalculator` involvement.
      No common parent class with `Spell`/`SpellTemplate` — `lib/models` has
      zero `extends` relationships, and the one field most worth sharing
      (R/D/T) is exactly the field that can't be identical between typed and
      free-text shapes.
- [x] A closed, exact-name table, `scripts/spell_import/exceptions.py`'s
      `EXCEPTION_SPELLS`, intercepted as the very first check in
      `extract_spells.py`'s import loop, before any design-line
      tokenization — these seven spells never route through
      `build_spell`/`build_template`.
- [x] A third `SpellLibraryScreen` section, below Templates and Spells,
      reusing `SpellCard`/`LibraryEntry` via one new chip. No instantiation
      action — these are read-only canon records.
- [x] The standing goal statement amended to carve out this category
      explicitly, rather than silently failing to cover these real spells.

**Spec/Plan:** `docs/superpowers/specs/2026-08-15-exception-spells-design.md`
(the original six — its exclusion list for *Dispel the Phantom Image*, *Lay
to Rest the Haunting Spirit*, *Restore the Moved Image*, *The Invisible Eye
Revealed* and *Sight of the True Form* is now known to rest on a since-
falsified assumption for the first four; see item 25),
`docs/superpowers/plans/2026-08-16-exception-spells.md`

### 48. Base Effect Analogy — model + pipeline capability — ✅ DONE 2026-08-16

**Spec:** `docs/superpowers/specs/2026-08-16-base-effect-analogy-design.md`

`Spell` and `SpellTemplate` gained their own `technique`/`form` (stored, no
longer derived from the base effect) and an optional `analogyRationale`
(required non-null exactly when they differ from the resolved base effect's
own technique/form). `ResolvedSpell`/`ResolvedTemplate` now read the stored
fields, so a by-analogy spell displays under its own real Technique/Form
instead of the borrowed one. `validateSpellAgainstCatalog` gained an 8th
check enforcing the invariant. The Python importer emits both new fields on
every spell and template; every one of the 325 spells and 27 templates in
the committed assets was regenerated to carry them.

**Explicitly not done in this item — separate follow-ups:**
- ✅ done 2026-08-16, see item 25 — Actually unblocking *Restore the Moved
  Image*, *Dispel the Phantom Image*, *The Invisible Eye Revealed*, *Lay to
  Rest the Haunting Spirit* with a real analogy reference (3 via base-effect
  analogy, 1 — *The Invisible Eye Revealed* — via the exception spell
  mechanism instead).
- Creation-screen UI for picking a cross-Form base effect interactively.
- ✅ fixed 2026-08-16 — `SpellDraft` now carries `analogyRationale`,
  threaded through `toSpell()`, `SpellEngine.validateSpellDraft`, and
  `SpellCreationBloc`'s `TemplateInstantiated` handler (seeded from
  `template.analogyRationale`), so instantiating a by-analogy
  `SpellTemplate` from the Library now validates and calculates cleanly.
  Regression test in `test/bloc/spell_creation_bloc_test.dart`'s
  `TemplateInstantiated` group, built on the real
  `tpl-peim-dispel-phantom-image` template.

- **Files:** `lib/models/spell.dart`, `lib/models/spell_template.dart`,
  `lib/models/resolved_spell.dart`, `lib/models/resolved_template.dart`,
  `lib/engine/spell_engine.dart`, `scripts/spell_import/emit.py`,
  `scripts/spell_import/extract_spells.py`,
  `test/data/published_spell_import_test.dart`,
  `assets/data/spell_library.json`, `assets/data/spell_templates.json`

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
- **Three spells print no design line. Two have a legitimate derivation:**
  - *Enchantment of the Scrying Pool* (InAq 30, line 12900) — ✅ derived
    `(Base 5, +1 Touch, +4 Year)`, base effect `inaq-5` (sole candidate). Imported.
  - *Whispering Winds* (InAu 15, line 13251) — ✅ **now imports as an exception
    spell, 2026-08-16 — see item 46.** InAu's only base levels are 1/2/4/15;
    with Sight(3)/Conc(1)/Ind(0) fixed by the stat line, no real base level +
    real magnitude token reproduces 15 without inventing a requisite the
    text does not support. The spell's own prose says why, and its design
    line prints the literal marker `(Unique spell)`.
  - *Hermes' Portal* (ReTe 75, line 15638) — ✅ **derived, no longer blocked.**
    `rete-4` ("Transport a non-living object…") needs `rego-transport-distance` at its
    top rung plus 2 magnitudes of size to reach 75. **Corrected 2026-08-15:**
    `emit.build_spell`'s mapping was fixed by item 43, and `designline.py`'s
    tokenizer now produces the distance-kind token to feed it — **item 45 is
    done**, and it was the only remaining gap: hand-derived design line
    `(Base 4, +4 Arc, +4 Year, +5 arcane connection, +2 size)` computes to
    level 75 exactly. Imported as `rete-4`. Its printed `(Mercurian Ritual)`
    marker corroborates it is non-standard.
  - (At the time this item closed, five further spells lacked a design line and were
    General-level, belonging to item 25: *Ward against the Beasts of Legend*, *Sight
    of the True Form*, *Ward against Faeries of the Mountain*, *Wizard's Vigil*,
    *Aegis of the Hearth*. Two have since been recovered and import today: *Ward
    against the Beasts of Legend* (item 35/37's realm-slot work) and *Ward against
    Faeries of the Mountain* (2026-08-15 — its own text names both its guideline and
    its realm by cross-referencing *Ward against Faeries of the Waters*; see item
    27's correction and `extract_spells.HAND_DERIVED`). *Sight of the True Form*
    remains blocked under item 25; *Wizard's Vigil* and *Aegis of the Hearth*
    moved out 2026-08-16, now importing as exception spells instead — item 46.)
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

**All 33 now import — the last 4 unblocked 2026-08-16, via two different
mechanisms.** (Was ten, then nine, then five, then four, per the earlier
history below; the final four cleared together —
see `docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md`.)

- **3 unblocked via the base-effect analogy capability**
  (`Spell`/`SpellTemplate.technique`/`.form` + `analogyRationale`,
  `docs/superpowers/plans/2026-08-16-base-effect-analogy.md`): each is a
  Form-specific spell whose own guideline table has no matching General
  row, pointed instead at the existing Vim-level General row it's a
  narrower, un-offset echo of.
  - *Dispel the Phantom Image* (Perdo Imaginem) → `pevi-G2`
    ("dispel a specific type of effect"), narrowed to Creo Imaginem.
  - *Restore the Moved Image* (Rego Imaginem) → `revi-G2`
    ("sustain or suppress a spell you cast").
  - *Lay to Rest the Haunting Spirit* (Perdo Mentem) → `pevi-G3`
    ("reduce target's Might Score").
- **1 unblocked as an exception spell**
  (`scripts/spell_import/exceptions.py`, the same mechanism as *Sight of
  the True Form* and 6 others): *The Invisible Eye Revealed* (Intellego
  Vim) is already a Vim spell itself, so there is no more-general
  guideline to point it at by analogy — confirmed by checking the
  arithmetic of its own Form's only General row (`invi-G`), which
  computes a structurally different quantity (a small residual-magnitude
  count, not a level threshold).
- **Re-derived 2026-08-16, not a new finding — all four were already settled
  by `docs/superpowers/plans/2026-08-05-general-base-effects.md`,
  independently re-confirmed against the reviewed rulebook text while
  investigating whether item 24's close cleared any of them too. A catalog
  row built from a spell's own prose, to receive a spell whose art prints no
  matching guideline bullet, was tried for two spells in this family
  (`peme-G` for *Lay to Rest the Haunting Spirit*, `inco-gen` for *Sight of
  the True Form*) and deliberately removed —
  `test_general_catalog.GeneralCatalogTest.test_general_entries_match_the_rulebook_bullet_for_bullet`
  now holds the catalog to the rulebook's own General bullets art-by-art, in
  both directions, permanently. **Why these four stayed blocked while Sight
  of the True Form became an exception spell first, 2026-08-16:** the user's
  earlier explicit choice was to convert only the spell actually raised, not
  extend the same reasoning to its siblings by inference — until later the
  same day, when the two mechanisms above (analogy for three, exception for
  the fourth) closed all four on their own merits, not because the earlier
  reasoning had been wrong (it wasn't, identically) but because nobody had
  yet chosen to act on it for them. See `extract_spells.DESIGN_LINE_INCOMPLETE`'s
  and the `general_candidates` branch's comments for the per-spell
  citations.**
- **✅ Wizard's Communion moved to item 46, 2026-08-16** — it now imports as
  an exception spell rather than staying blocked on its disclaimed
  guideline arithmetic ("a remnant of Mercurian rituals").
- **✅ Watching Ward moved to item 46, 2026-08-16** — it now imports as an
  exception spell rather than staying blocked on its `Special`-Duration
  problem.
- **✅ Sight of the True Form moved to item 46, 2026-08-16** — it now imports
  as an exception spell, for a third reason item 46's original two shapes
  didn't cover: its General guideline is genuinely absent from Intellego
  Corpus's own table (`inco-gen`, built from this exact spell's prose, was
  already tried and reverted). See item 46's body.

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

**The last three, previously deliberately blocked, now import — 2026-08-16.** Each
turned out to be a real, reusable mechanism rather than a one-off note, once checked
against the rulebook's own citations: *The Kiss of Death* (`+2 for no words`) and
*Black Whisper* (`+1 for not needing to gesture`) buy off the still/silent casting
requirement the same way Quiet Casting/Still Casting Mastery do at the Mastery-ability
layer, confirmed globally-scoped (not tied to either spell's own Technique/Form) —
now catalog Modifiers `no-words`/`no-gestures`. *Sight of the Active Magics*
(`+2 Techniques and Forms`) is unrelated: it reveals which Technique/Form is active in
a detected magical aura, on top of the base detection effect *Sense of the Lingering
Magic* already covers — now `invi-techniques-and-forms`, Intellego Vim-scoped. Wiring:
`designline.MODIFIER_LABELS`, `emit._MODIFIER_OPTIONS`, `assets/data/modifiers.json`.
Black Whisper also needed a `resolutions.json` entry (`lib-peme-black-whisper` →
`peme-15c`, "Drive a person insane") once its design line stopped raising
`UnknownToken` and reached base-effect resolution for the first time.

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
the one published spell that contradicts this — recorded as an exception spell
instead of weakening the model, item 46.)*

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
See item 6. As of 2026-08-10 the integration suite is green (7/7) — the two
`scrollUntilVisible` calls that fell behind the library's growth to 294 spells +
23 templates now carry a `maxScrolls: 500` budget.
