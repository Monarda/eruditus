# Eruditus Todo List

**Status:** Active development
**Last Updated:** 2026-07-28
**Base Effects:** ✅ Complete (604 effects extracted)

**Current goal:** every published spell in the Definitive Edition core rules is in
the spell library, with its computed level matching its printed level.

**Item numbers are stable IDs, not priority order.** Sections give priority;
numbers are never reused or renumbered, because specs, commits and other todo
items cross-reference them.

---

## The Goal, Measured

All 360 spells in Chapter 9 of `Ars-Magica-Open-License/reviewed/Ars Magica -
Definitive Edition (Core Rules).md` were parsed and each design line checked
against what the app can express today (audit run 2026-07-28).

**286 of 360 (79%) are expressible right now.** The remaining 74 fall into seven
families:

| Family | Spells | Item |
|---|---|---|
| General-level — base level is chosen, not fixed | 33 | **25** |
| Ad-hoc per-spell magnitude (`+1 fancy effect`) | 21 | **24** |
| Ritual only by storyguide ruling | 7 | 18 |
| Non-standard Range/Duration/Target | 6 | **26** |
| Guideline level absent from the rulebook's own table | 5 | **28** |
| Size ladder above +4 | 4 | 19 |
| Ward mechanics in the design line | 1 | 4 |

Families overlap, so the numbers sum to more than 74.

**A further finding: base-effect resolution needs human judgement 186 times.**
A design line names its guideline only by level (`Base level 15`), and Creo
Animal has four entries at level 15. Of the 324 spells with a numeric base,
133 resolve uniquely, 186 have 2+ candidates, and 5 have none. Automated text
matching does not close the 186 — see item 27's spec.

**Two things the audit confirmed need nothing further:**

- **The parameter catalog is complete.** Every Range, Duration and Target used
  by all 360 spells resolves against the 25 entries item 15 delivered.
- **The base-effect catalog is near-complete against the Definitive Edition** —
  604 entries against ~614 real DE guideline rows. The ~10 missing rows are
  item 22.

---

## A. Blocks the Library Import

Listed in dependency order. Item 27 is the next branch.

### 27. Published Spell Import Harness — ✅ COMPLETE (11/11 tasks)
**Spec:** `docs/superpowers/specs/2026-07-28-published-spell-import-design.md`
**Plan:** `docs/superpowers/plans/2026-07-28-published-spell-import.md`

- [x] Maintained, idempotent extractor at `scripts/spell_import/extract_spells.py`
      (`scripts/import/` in the original spec — `import` is a Python keyword,
      so the directory was renamed; the one deliberate spec deviation)
- [x] Hand-edited resolution ledger at `scripts/spell_import/resolutions.json`,
      recording each base-effect decision **and the candidate set it was made
      against** — so item 22's new guideline rows flag affected decisions as
      stale rather than letting them stand unexamined. 167 entries.
- [x] Five asset assertions: level equality, **Ritual agreement** (the oracle
      that does not depend on the base effect), resolution completeness,
      reference integrity, clean regeneration
- [x] Import the already-expressible spells (the library held 36 before this
      item; **250 after**, not the audit's estimated 286 — reconciled, not
      forced: 110 spells stay blocked with a documented reason each — 360
      total published spells accounted for exactly). See the "9 spells"
      and "2 of 3 design-line-less spells" notes below for the two blocker
      classes that account for the gap from 286.
- [x] Retire `loadSpellLibrary`'s hardcoded count — see item 5's note
- [x] Correct `Citation.page`'s doc comment: it promised page numbers arriving
      with "the spell-parsing work", but the reviewed markdown has no page
      markers, only prose cross-references. The promise could not be kept;
      doc comment corrected instead.
- [x] Hand-derive the breakdown for the **3 spells the rulebook prints no design
      line for**. Only 1 of 3 has a legitimate derivation:
      - *Enchantment of the Scrying Pool* (InAq 30, line 12900) — ✅ derived:
        `(Base 5, +1 Touch, +4 Year)`, base effect `inaq-5` (sole candidate,
        no ledger entry needed). Imported.
      - *Whispering Winds* (InAu 15, line 13251) — ❌ no legitimate
        derivation exists. InAu's only base levels are 1/2/4/15; with
        Sight(3)/Conc(1)/Ind(0) fixed by the stat line, no real base level +
        real magnitude token reproduces 15 without inventing a requisite the
        text doesn't support. The spell's own prose says why: "fits poorly
        into the normal framework of Hermetic magic." Stays blocked.
      - *Hermes' Portal* (ReTe 75, line 15638) — ❌ no derivation within the
        importer's current modelling. The thematically-right guideline
        (`rete-4`, "Transport a non-living object... add magnitudes for
        distance/Arcane Connection") needs the `rego-transport-distance`
        modifier at its top rung plus 2 magnitudes of size to reach 75 —
        `emit.build_spell` maps only `size`-kind modifier tokens to
        `modifiers.json` today (see `_selected_modifiers` in `emit.py`).
        Extending that mapping to `rego-transport-distance` (already scoped
        in `modifiers.json` to exactly `rete-4`/`rehe-10b`/`reig-3c`) is a
        real, scoped follow-up that would resolve this spell — not done
        here, since it's infrastructure work beyond "derive one string."
        Its own printed `(Mercurian Ritual)` marker corroborates it's
        non-standard. Stays blocked.
- [ ] **9 spells the ledger cannot resolve — needs a rules decision, not a
      ledger entry.** Found while filling `resolutions.json` (Task 10 of the
      harness's implementation plan). Two distinct shapes of blocker:
      - **Zero base-effect candidates at the computed level** (a catalog gap,
        not a spell problem — likely relevant to item 22's rebuild-from-`reviewed`
        work): `lib-muau-infernal-smoke-death`, `lib-muau-fog-confusion`,
        `lib-peig-wizards-icy-grip`, `lib-crvi-enigmas-gift`,
        `lib-invi-sense-lingering-magic`.
      - **Genuinely ambiguous between 2-3 candidates**, no textual
        discriminator strong enough to write a non-guessed rationale — each
        was actually resolved once, then pulled after a reviewer found the
        rationale was picking "the most general-sounding" candidate rather
        than a textually forced one: `lib-inte-tracks-faerie-glow` (`inte-4a`
        vs `inte-4b`), `lib-inte-sense-feet-that-thread-earth` (same pair,
        same shape of ambiguity), `lib-mute-crystal-dart` (`mute-3a`/`3b`/`3c`,
        stone-vs-crystal boundary), `lib-peig-conjuration-indubitable-cold`
        (`peig-4a`/`4b`/`4c`, three co-equally-supported readings).
      All 9 are excluded from the 250 spells the extractor currently
      imports (Task 10's `KNOWN_UNRESOLVABLE`/zero-candidate routing in
      `scripts/spell_import/extract_spells.py` blocks them explicitly rather
      than leaving them stuck as `unresolved`); they stay blocked until a
      human with the rules text and (for the first group) the corrected
      base-effect catalog can make the call.

**Final tally:** 250 imported, 110 blocked, 0 unresolved — 360 published
spells in the Definitive Edition core rules, all accounted for. Of the 110
blocked: 9 need a rules decision (the literal list above — 5 catalog gaps,
4 real ambiguity); *Whispering Winds* and *Hermes' Portal* are 2 more
blocked separately, under "no design line printed" (see the hand-derivation
item above — 7 spells share that reason: these 2 plus 5 General-level ones
belonging to item 25); the rest are mechanical
(General level → item 25; an unrecognised or unmapped design-line token —
mostly Imaginem complexity factors and Auram "unnatural" tokens, neither
modelled yet; a handful of genuinely malformed rulebook stat/design lines).
      (Five further spells lack a design line but are General-level, so they
      belong to item 25, not here: *Ward against the Beasts of Legend*,
      *Sight of the True Form*, *Ward against Faeries of the Mountain*,
      *Wizard's Vigil*, *Aegis of the Hearth*.)
- **Rationale for doing this first:** the harness is what makes items 24, 25 and
  the rest *verifiable*. Without it each new mechanism is checked by hand against
  a handful of examples. With it, every mechanism is checked against every spell
  it touches, and a regression anywhere in the engine surfaces immediately.
- **It also does not block on any of them.** It can run against the expressible
  291 the day it lands, and the count rises as each blocker clears — which makes
  it a live progress meter for this whole section.
- **Precedent:** `test/data/datasources/asset_data_loader_test.dart` already
  derives its expected effect count from the raw JSON rather than hardcoding it
  (item 5). Take the same self-healing approach here.

### 24. Ad-hoc Level Adjustments — **NEW, not previously recorded**
- [ ] Add a list of `(magnitude, note)` adjustments to `Spell` and `SpellDraft`
- [ ] One repeatable UI row in the creation screen (magnitude stepper + note)
- [ ] One line per adjustment in the level breakdown, showing the note
- [ ] Decide whether a negative magnitude is allowed — at least one published
      spell needs it
- **Rationale:** 21 published spells carry a one-off magnitude the storyguide
  assigned with a prose justification. **No catalog entry can ever cover these** —
  they are per-spell, not per-guideline. Examples:
  - `+1 fancy effect` — *Treading the Ashen Path*, *Creeping Chasm*,
    *The Earth Split Asunder*; `+2 fancy effect` — *Teeth of the Earth Mother*
  - `+3 elaborate design` — *Conjuring the Mystic Tower*
  - `-1 because the old limb is needed` — *The Severed Limb Made Whole*
    (the only negative adjustment found)
  - `+2 for no words` — *The Kiss of Death*;
    `+1 for not needing to gesture` — *Black Whisper*
  - `+1 for shape and primary motivation` — *Hunter's Sense*;
    `+1 see through intervening material` — *The Miner's Keen Eye*;
    `+2 Techniques and Forms` — *Sight of the Active Magics*
  - `+1 complex effect` — *Weight of a Thousand Hells*;
    `+1 for special effect` — *The Silent Vigil*
- **Best value-to-effort ratio in this file.** No research, no catalog work, no
  rulebook derivation — a model field, one UI control, one breakdown line.
- **Item 26 probably folds into this.** `+2 Special (based on Concentration)`
  reads as an adjustment with a note, not as a new parameter.
- **Do not confuse this with Modifiers.** A Modifier is a *reusable catalog
  choice* scoped to a technique/form/effect. These are unique to one spell and
  would pollute the catalog with 21 single-use entries.
- **Files:** `lib/models/spell.dart`, `lib/engine/spell_engine.dart`,
  `lib/presentation/screens/spell_creation_screen.dart`,
  `lib/bloc/spell_creation/`, `lib/data/database/app_database.dart` (schema bump)

### 25. General-Level Spells — base level is chosen, not fixed
**Absorbs item 4's "Variable Base Levels" bullet, which understated this badly.**

- [ ] Model a base effect whose level the caster chooses (47 catalog entries
      carry `baseLevel: 0` today — a General entry computes as `0 + magnitudes`,
      which is simply wrong)
- [ ] Level input in the creation screen, shown only for General entries
- [ ] Engine: the chosen level replaces the guideline's base in
      `calculateBreakdown`
- [ ] Decide what the breakdown line reads for a chosen base
- [ ] Validate: a General entry with no chosen level is an error, not a zero
- **33 published spells are General-level**, including **every Vim spell** and
  **every ward**. This is the gate on the whole of Vim (54 catalog effects) and
  on item 4's conditional wards.
- **Why item 4 got this wrong.** The Spell Modifiers spec correctly established
  that most `"Variable base level"` notes are informational — each rung of a
  guideline ladder was extracted as its own effect with a correct integer level.
  That reasoning does not reach the **General entries**, where there is no ladder
  and no correct integer, because the level *is* the caster's choice. The spec's
  own count of "one genuinely variable base level" counted rungs, not Generals.
- **This is the only remaining item in this section needing real design.** The
  open question is how a chosen level interacts with
  `SpellLevelCalculator`'s additive-tier/multiplier split — magnitudes are added
  to a base, and here the base arrives from the user rather than the catalog.
- **Files:** `lib/models/base_effect.dart`, `lib/engine/spell_engine.dart`,
  `lib/engine/spell_level_calculator.dart`, `assets/data/base_effects.json`
  (the 47 zero-level entries), creation screen + bloc

### 26. Non-standard Ranges, Durations and Targets — **NEW, not previously recorded**
- [ ] Decide whether these need a mechanism at all, or are covered by item 24
- **6 published spells** build a parameter out of a standard one rather than
  using it directly:
  - `+2 Special (based on Concentration)` — *Wind at the Back*, *Trackless Step*
  - `+1 Special based on Mom` — *The Earth Split Asunder*
  - `+4 Special (equivalent to Boundary)` — *The Bountiful Feast*
  - `Duration is non-standard` — *Watching Ward*
  - `D: Sun & Year` — one spell carries two durations
- **Recommendation: fold into item 24 rather than extending the parameter
  catalog.** Five of the six are one-offs with prose justification, which is
  exactly item 24's shape. Adding six `Special` parameters would make them
  selectable on every spell, where they are meaningless. *Watching Ward* and the
  `Sun & Year` case may still want a look — check them before folding.

### 28. Guideline Levels Absent from the Rulebook's Own Table — **NEW**
- [ ] Decide how a spell cites a guideline level the table does not list
- **5 published spells** name a base level with no corresponding row, derived
  instead from a **prose rule stated above the table**:
  - *Infernal Smoke of Death* (MuAu 40) needs MuAu base 25; the table stops at 10
  - *Fog of Confusion* (MuAu 45) needs MuAu base 2; the table starts at 3
  - *Wizard's Icy Grip* (PeIg 30) needs PeIg base 20; the table stops at 10
  - *The Enigma's Gift* (CrVi 30) needs CrVi base 20
  - *Sense of the Lingering Magic* (InVi 30) needs InVi base 10
- **This is not item 22.** Those rows are genuinely absent from the Definitive
  Edition, not missed during extraction. Two prose rules generate them:
  - Muto Auram: "Transforming only one property of air generally lowers the
    level by one magnitude" — this is how *Fog of Confusion* reaches base 2
  - Perdo Ignem: "For every five points by which the fire's damage exceeds +5,
    add one magnitude" — the same rule as item 4b, applied to the base rather
    than to the spell
  The harmful-gas and chill-damage ladders are also extrapolated upward beyond
  their printed last rung.
- **Options worth weighing:** add the derived rows to the catalog as ordinary
  entries with a note recording the prose rule they came from (simplest, and
  the catalog already holds extracted rather than printed data); or model the
  prose rules; or let item 24's ad-hoc adjustments absorb the difference from
  the nearest printed rung.
- **Found by the 2026-07-28 audit** as the 5 spells whose `Base N` matched no
  catalog entry at all.

### 19. Size-Ladder Ceiling
- [ ] Every Size ladder in `modifiers.json` stops at +4 (×10,000); 4 published
      spells need +5
- [ ] Decide whether to add one rung or make the ladder open-ended — the
      rulebook's rule is `+1 magnitude = ×10 size` with no stated ceiling, so a
      fixed ceiling is an artifact of the MVP, not of the rules
- **The 4 blocked spells:** *Wrath of Whirling Winds and Water* (CrAu 40),
  *Rain of Oil* (MuAu 50), *Curse of the Haunted Forest* (MuHe 40),
  *Poisoning the Will* (PeMe 40).
- **⚠️ *Poisoning the Will* is Perdo Mentem, and Mentem deliberately has no Size
  ladder.** The exemption item 3 recorded is real but narrower than implemented:
  the rulebook exempts Mentem *for Individual targets*, and this spell is
  `T: Bound`. Adding a rung will not unblock it — decide separately whether
  Mentem gets a Boundary-scoped ladder, or whether this spell uses item 24.
- **Related deferred work:** the Spell Modifiers spec deferred sizing for Part,
  Group, Room, Structure and Boundary targets entirely (its ladders assume
  Individual). *Poisoning the Will* is the first published spell to need it.

### 18. Storyguide-Ruling UI for Rituals
- [ ] Expose `RitualDeclaration.storyguideRuling`, which the model supports and
      three built-in spells already use, but no control sets
- [ ] Revisit `SpellCreationBloc._withRitualDeclaration` so the two declaration
      kinds stay distinguishable once both are user-settable
- **Rationale:** Core Rules line 12352 lets the troupe declare any spell a
  Ritual. The Creo+Momentary-only checkbox cannot express them.
- **Count corrected by the audit: 7, not 4.** Of the 39 Ritual-flagged published
  spells, 32 are derivable today (Year duration, Boundary target, level > 50, or
  the Creo+Momentary checkbox). These 7 are not:
  *Curse of the Ravenous Swarm* (CrAn 50), *Neptune's Wrath* (ReAq 40),
  *Breath of the Open Sky* (CrAu 40), *Rain of Oil* (MuAu 50),
  *Incantation of Summoning the Dead* (ReMe 40), *Disenchant* (PeVi Gen),
  *Watching Ward* (ReVi Gen).
- **Some of the 7 may want a guideline flag instead of a ruling.** Three carry
  the reason in their own design line (`ritual because it has a really major
  effect`, `ritual for large effect`, `ritual because of spectacular effect`) —
  that is a storyguide ruling. The two Vim Generals may be guideline-level.
- **Spec:** `docs/superpowers/specs/2026-07-27-ritual-spells-design.md`

### 22. Catalog Extraction Gaps
Four Creo Animal rows, plus six more the Definitive Edition audit found.

- [ ] **Creo Animal** — L35 "Increase a Characteristic to one above average",
      L40 "Cause an animal to reach full maturity in a moment",
      L45 "…three above average", L55 "…five above average"
      (re-verify against the DE table at line 12468; the original research was
      done against the 5e core rules, and the DE rows may differ slightly)
- [ ] **Creo Corpus** — L70 "Raise the dead, to a point (see *The Shadow of Life
      Renewed*)"
- [ ] **Rego Animal** — General "Create a circle warding against animals from one
      realm … with Might less than the level"
- [ ] **Rego Mentem** — General "Ward against spirits belonging to one realm …
      with a Might less than the level"
- [ ] **Muto Aquam** — General "Convert part of a water elemental's body into
      another type of water"
- [ ] **Muto Terram** — General "Convert part of an earth elemental's body into
      another type of earth"
- **Context:** pure extraction gap, no design decisions. The four General rows
  are also item 25 cases once added.
- **Source precedence — the catalog is built from the wrong file.** The rulebook
  repo holds the same book in `reviewed/`, `wip/` and `raw-md/`, in descending
  quality. Always resolve `reviewed` → `wip` → `raw-md` and stop at the first
  hit; `raw-md` is unreviewed OCR (`tHe Bitten toad`, `infl icted`) and also
  carries two alternate core-rules copies and a file marked `DO NOT USE`.
  Filenames differ between folders, so match on book title.
  The 604 base effects came from `raw-md/Ars Magica 5e - Core Rules.md` while a
  reviewed Definitive Edition exists — so this item should end with the catalog
  rebuilt from `reviewed`, not with ten rows patched onto a raw-OCR base.

### 4. Conditional Wards *(the last open piece of the original item 4)*
- [ ] Add ward type field to BaseEffect
- [ ] Level threshold: a ward affects creatures whose Might is below the spell's
      level — display it, do not compute a different level from it
- [ ] UI section for ward configuration
- **Depends on item 25.** 13 published ward spells; 8 of them are General-level,
  and for those the ward threshold *is* the chosen level. Item 25 lands the hard
  half; what remains here is display.
- **Only 1 spell has ward mechanics in its design line** — *Break the Oncoming
  Wave* (`ward, so the target is the warded Individual, not the water`). The
  other 12 need nothing beyond item 25.
- **See item 4's full audit below** for the other eight sub-items' outcomes.

---

## B. Deferred by Design — Derived Outputs

Not blockers for the import. Both stay as descriptive text on the spell, which
is what the rulebook itself does.

### 4b. Intensity/Damage Modifiers
- [ ] Muto/Perdo Ignem: add 1 magnitude per 5 points fire damage exceeds +5
- **Only 1 published spell touches this in a design line** — *Ward against Heat
  and Flames* (`+2 for up to +15 damage`), which item 24 can express.

### 4c. Level-Dependent Might Reduction
- [ ] Muto/Perdo Ignem/Auram: elemental Might reduced by spell level
- [ ] Note that Might reduction = spell level (not magnitude)
- **No published spell's level depends on this** — it describes the spell's
  runtime effect, not its cost. Display concern only.

**Why these two are together:** both read the *final computed level* and produce
a different quantity from it. That is a genuinely different shape from
`option → magnitude`, and the Spell Modifiers spec explicitly identified it as
the point where a code seam earns its place. See that spec's "Deferred work,
recorded".

---

## C. Not on the Critical Path

Real work, none of it blocking the import.

### 6. Real Bloc Hang in Widget Tests — and the coverage hole it creates
- [ ] Document workaround: mock Blocs in widget tests, use integration_test for real E2E
- [ ] Create widget test helper with mock bloc factories
- [ ] **Run integration tests as part of verification, not just `flutter test`**
- [ ] Consider a single script/alias that runs both suites, so "tests pass" means both
- **Context:** Real Bloc hangs forever under flutter_tester; known Bloc limitation
- **Why the extra items matter — two failures already traced to this:**
  1. `flutter test` does **not** run `integration_test/`; those need a device
     (`flutter test integration_test/... -d windows`). So the integration suite
     rots silently. Task 1 broke the end-to-end test — it never selected the
     newly-mandatory Range/Duration/Target and tapped `calculate-button`
     without scrolling — and that went unnoticed across several "suite is
     green" checks, because the file simply never ran.
  2. Mocked blocs cannot catch re-render bugs. A mock emits no new state, so
     the rebuild after an interaction never happens. The add-requisite crash
     (`DropdownButtonFormField` left holding a value no longer in its `items`)
     was invisible to 6 passing widget tests for exactly this reason. When the
     failure mode *is* "what happens on re-render", either drive states through
     a `StreamController` on the mock, or cover it in `integration_test/`.
- **Verification rule of thumb:** a change to a screen's widget tree is not
  verified by `flutter test` alone — run the integration suite too.
- **Worth raising if item 27 grows an authoring pipeline** — a 360-spell asset
  test is exactly the kind of thing that must run in `flutter test`.
- **Files:** Test helpers, widget test templates, `integration_test/`

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells conform to new constraints (one Range/Duration/Target)
- [ ] Add migration for legacy spell saves (if any)
- [ ] Test backup round-trip (export → import)
- [ ] **Known gap (found in the Ritual Spells whole-branch review):**
      `test/data/services/backup_service_test.dart`'s "backup round-trip" test
      duplicates `spell_test.dart`'s serialization round-trip rather than
      calling through the real `BackupService` — the service itself is not
      actually exercised by that test. Not a regression from that branch (the
      service wasn't touched), but a pre-existing coverage hole this item
      should close along with the checkbox above.

### 9. Spell Tags / Library Organisation — **half done**
- [x] Add a `tags` field to the Spell model — **landed** with the Spell
      Provenance and Tags work (commit `c4242d6`); `Spell.tags` is a
      `List<String>`, serialized and persisted
- [ ] Allow assigning tags when creating or editing a spell
- [ ] Filter/browse the library by tag
- [ ] Support multiple tags per spell, and combining tag filters with existing search + source filters
- [ ] Decide whether tags are free-text, a curated vocabulary, or free-text with suggestions from existing tags
- **Rationale:** Thematic grouping that the Technique/Form axes can't express. A spell that raises a castle is both "defensive" and "architecture"; neither is derivable from Creo/Terram.
- **Model and persistence are done — what remains is purely UI.** No schema
  change needed, contrary to this item's original wording.
- **Rises in value once item 27 lands.** Browsing 360 spells by Technique/Form
  alone is a worse experience than browsing 36.
- **Files:**
  - `lib/presentation/screens/spell_library_screen.dart` (tag filter UI)
  - `lib/presentation/screens/spell_creation_screen.dart` (tag entry)
  - `lib/bloc/spell_library/` (filter-by-tag events/state)

### 13. Summary/Description Entry for User-Created Spells
- [ ] Add a summary input (and optionally a description input) to the spell creation screen
- [ ] Carry the text on the save event so it reaches `SpellDraft` → `Spell`
- [ ] Tighten the summary-or-description invariant to apply to **both** sources,
      not just published spells, once the UI can collect it
- [ ] Update the invariant tests and the spec's "interim" note when it lands
- **Rationale:** The Spell Provenance and Tags change split `description` into
  `summary` (paraphrase) and `description` (verbatim rulebook text), and requires
  at least one of them on published spells. User-created spells were exempted
  **only because the creation screen collects nothing but a name** —
  `SpellSaveRequested(name)` carries no prose, so an unconditional rule would have
  rejected every user-created spell on save.
- **The model is already ready.** `SpellDraft` carries `summary` and
  `description` and `toSpell` passes both through, so this is purely
  presentational: an input widget plus an event. No model or persistence change.
- **Files:**
  - `lib/presentation/screens/spell_creation_screen.dart` (input field)
  - `lib/bloc/spell_creation/spell_creation_event.dart` (carry the text on save)
  - `lib/bloc/spell_creation/spell_creation_bloc.dart` (set it on the draft)
  - `lib/models/spell.dart` (tighten the shared validator)
- **Spec:** `docs/superpowers/specs/2026-07-27-spell-provenance-and-tags-design.md`

### 14. Container Targets: At-Casting vs. Subsequently-Entering
**No longer blocked** — item 15 added the Circle Target and Ring Duration.

- [ ] Model whether a container-target spell affects only what is inside **at the moment of casting**, or also whatever **enters later**
- [ ] Expose the choice in the spell creation UI, shown only when the selected Target is a container
- [ ] Validate that the choice is absent for non-container targets, so it cannot be set meaninglessly
- [ ] Decide whether the choice affects the calculated level, or is purely descriptive
- **Rationale:** The two readings are different spells. A Room-target spell that
  cleanses everyone present is not the same as one that cleanses everyone who
  walks in for the rest of its Duration. Nothing in the model currently records
  which was meant, so the app cannot tell them apart.
- **Container targets in the catalog today:** `target-room` (Room, +2),
  `target-structure` (Structure, +3), `target-boundary` (Boundary, +4),
  `target-circle` (Circle, +0).
- **⚠️ The rulebook may already answer this, which could collapse the whole
  item.** ArM5 core defines the behaviour *per target*, rather than leaving it
  to the caster:
  - **Group:** "The things in the Group when the spell is cast are affected for
    the entire duration, even if they split up. Things that join the Group
    during the spell duration are **not** affected." — fixed at casting, stated
    outright.
  - **Circle:** a ward "prevent[s] things warded against that are within the
    circle from leaving, and prevent[s] things warded against that are outside
    from **entering**." — explicitly ongoing.
  - Room, Structure and Boundary are defined spatially ("everything within…")
    without settling the question either way.

  So the distinction may be a **property of the Target parameter**, derivable
  rather than stored — which would make this a data annotation on
  `parameters.json` plus a display concern, with no `Spell` field, no schema
  bump and no UI control at all. Read the rulebook's "Ranges, Durations,
  Targets" and "Magical Wards" sections before assuming a user-facing choice is
  needed. If it turns out only Room/Structure/Boundary are genuinely ambiguous,
  the scope shrinks to those three.
- **Note: no published core spell is blocked by this.** The audit found none of
  the 360 whose level or expressibility depends on the distinction — it is a
  fidelity improvement, not an import blocker. Worth doing after item 27, when
  360 spells make the ambiguity visible in the library.
- **Open design questions — worth brainstorming before planning:**
  - A boolean, or an enum (`atCasting` / `ongoing`)? An enum reads better at the
    call site and leaves room for a third case.
  - Does it live on `Spell` directly, or as a property of the target selection?
    The latter is tidier but there is no "target selection" object today — the
    spell holds a bare `targetId`.
  - Is the distinction genuinely a property of the *spell*, or is it implied by
    the Target/Duration pairing (Circle+Ring implying ongoing)? If implied, it
    may be derivable rather than stored — and storing derivable data is exactly
    what the id-reference normalization removed.
  - How should existing spells migrate? Backward compatibility is not a goal, so
    the three container-target built-ins can simply be re-authored.
- **Files:**
  - `lib/models/spell.dart` (the field, plus validation in the shared validator)
  - `assets/data/parameters.json` (target annotations, if derivable)
  - `lib/presentation/screens/spell_creation_screen.dart` (conditional control)
  - `lib/bloc/spell_creation/` (event + state for the choice)
  - `lib/data/database/app_database.dart` (schema bump if the field is stored)

### 16. Short Forms for Parameter Names
**The "decide alongside item 15" note is stale — item 15 shipped without this.**
Doing it now means a second pass over `parameters.json`, which was the cost the
original note tried to avoid. That does not make it wrong to do, only no longer
free.

- [ ] Decide whether parameters need a short display form at all — confirm a real
      layout is actually constrained before building anything
- [ ] If so, add an optional `shortName` to `Parameter`, falling back to `name`
- [ ] Add a small widget that picks the longest form fitting the available width

- **Do NOT encode alternatives as inline markup** (e.g. `"B/ound/ary"`):
  - It puts presentation inside domain data — search, comparison, backup export
    and tests would all need to strip markup first, and one missed call site
    shows a user `B/ound/ary` in an exported file.
  - It can only express prefix truncation. "Arcane Connection" → "Arc" works;
    → "AC" does not.
  - **`/` already means something else here.** The rulebook uses it for
    equal-difficulty pairings — `Touch/Eye`, `Sun/Ring`, `Group/Room`,
    `Individual/Circle`. Reusing it for abbreviation in the same catalog is a
    trap.
- **Precedent already in the codebase:** `Book` carries `title` *and*
  `abbreviation` as separate fields (added by the Spell Provenance work). Doing
  the same on `Parameter` follows house style rather than inventing a scheme.
  The wider precedent is CLDR, which models wide / abbreviated / narrow as named
  forms, never as markup.
- **Flutter has no built-in string-alternatives system.** `FittedBox` scales
  glyphs rather than substituting words; `TextOverflow.ellipsis` truncates
  crudely ("Bound…"); `auto_size_text` is third-party, not a dependency here, and
  shrinks the font rather than swapping text. The real mechanism is
  `LayoutBuilder` + `TextPainter` measurement with your own selection logic.
- **Note:** `Bound` → `Boundary` is a *data error* fixed by item 15, not a short
  form anyone chose. Do not treat it as evidence that abbreviations are needed.
- **Check the need first.** These names appear mostly in dropdowns, where width
  is rarely tight and substituting text makes selection confusing. If anything
  is genuinely constrained it is more likely the spell card or the level
  breakdown chips — measure before building. **The rulebook itself abbreviates
  in exactly one place: the spell stat line (`R: Touch, D: Sun, T: Ind`).** If
  the app ever renders that line, that is the constrained widget.
- **Files:** `lib/models/parameter.dart`, `assets/data/parameters.json`,
  wherever a constrained widget turns out to be

### 17. Virtue-Gated Parameters: Merinita Faerie Magic and Symbolic Magic
**Blocked on one remaining model gap.** The ritual-only flag half is done:
`Parameter.requiresRitual` landed on `feature/ritual-spells` (item 4), so
`Bargain`/`Until (Condition)`/`Year + 1`/the three Symbolic Magic parameters
below can be flagged ritual today. Still missing: some way to record that a
parameter requires a specific Mystery Virtue — which in turn implies a
character/Virtue model the app doesn't have at all (it only models spells and
catalog data, no characters). Do not attempt this until the Virtue-gating
mechanism exists.

**Not a blocker for the core-rules import** — no core spell uses these
parameters, by definition. Relevant only when supplement spells are added.

- [ ] Add a `requiresVirtue`-style field once a Virtue-gating mechanism is designed
- [x] Add the ritual-only flag — landed as `Parameter.requiresRitual`
      (branch `feature/ritual-spells`, item 4); shared groundwork, not
      specific to these 9 parameters
- [ ] Add the 6 Faerie Magic parameters below
- [ ] Add the 3 Symbolic Magic parameters below

**Merinita: Faerie Magic** — Core Rules, "Mysteries" chapter (not Houses of
Hermes: Mystery Cults, where the rest of the House's content lives). Granted to
initiates of the Faerie Magic Outer Mystery only:

| Name | Type | Level | Note |
|---|---|---|---|
| Road | Range | = Voice | affects anyone/anything on the same road or path |
| Bargain | Duration | = Year + 3 magnitudes | ritual; enforces a bargain, max Year once triggered |
| Fire | Duration | = Moon | Ignem/Imaginem only; lasts until the targeted fire goes out |
| Until (Condition) | Duration | = Year | ritual; lasts until a specified condition is met |
| Year + 1 | Duration | = Year | ritual; a year and a day, by elapsed time not season |
| Bloodline | Target | = Structure | affects all blood descendants of the immediate target |

**Symbolic Magic** — Houses of Hermes: Mystery Cults, House Merinita chapter.
Granted to initiates of the Symbolic Magic Major Folk Mystery. All three are
always ritual and require a physical symbolic charm representing the target,
built from at least 3 charms (9 for using all three together):

| Name | Type | Level | Note |
|---|---|---|---|
| Symbol | Range | = Arcane Connection | affects anything the symbol uniquely identifies |
| Symbol | Duration | = Year | lasts as long as the physical symbol survives intact |
| Symbol | Target | = Boundary | affects everything the symbol represents, within range |

- **Rationale:** Found during research for item 15's parameter catalog work.
  Real, citable content — not filed as "maybe later" but as "genuinely
  deferred pending groundwork," so the research isn't lost.
- **Files:** `lib/models/parameter.dart` (the gating field, once designed),
  `assets/data/parameters.json` (the 9 new entries)
- **Spec:** `docs/superpowers/specs/2026-07-27-parameters-and-provenance-design.md`
  ("Deferred Work" section)

### 20. Creo Creation `suggested` Ritual Sweep
- [ ] Decide whether every "Create X" guideline should carry
      `RitualRequirement.suggested`, as the Creo healing guidelines now do
- **Rationale:** Core Rules line 12176 — "An item made with Creo only lasts for
  the duration of the spell, unless the spell was a Momentary Ritual" — makes
  creation exactly as much a lasting-thing case as healing. Skipped deliberately
  because it is hundreds of entries across all ten Forms, and because the
  checkbox already defaults on for *every* Creo + Momentary draft, so nothing is
  incorrect without it. The flag would only add explanatory text.
- **The audit supports leaving it.** All 32 derivable Ritual spells already
  derive correctly without it.

### 21. Creo Mentem Memory Restoration
- [ ] Decide whether `crme-4b`, `crme-5b` and `crme-10a` (renamed from
      `creem-4b`/`creem-5b`/`creem-10a` when the base-effect id scheme was
      corrected — see the published-spell-import branch) ("Restore a memory
      … to a fresh state") are Momentary-Creo-lasting-thing cases
- **Context:** The Ritual sweep's criterion arguably reaches them, but the
  approved scope was Creo *bodily* healing across Animal, Corpus and Herbam, and
  the healing-suspension rule at line 13415 does not cover memory. All three are
  already flagged "Variable base level" — **but they are rung entries with real
  integer levels, not General entries, so item 25 does not reach them.**

### 12. Out-of-Scope Effects Handling
- [ ] Create filtering/tagging UI for flagged effects (variable base levels, ritual-only, etc.)
- [ ] User guidance: explain which effects don't fit the calculation model yet
- **Shrinks substantially once items 24 and 25 land.** The audit reduced the
  "~200 flagged effects" figure to two genuinely uncomputable families (section
  B), so this item's scope should be re-measured before it is planned.

### 23. Ritual Spells Review — Remaining Cosmetic/Test-Hygiene Findings
Three Minor findings from the Ritual Spells whole-branch review, left unfixed
as genuinely low-priority (5 of the review's 8 Minor findings were fixed
directly — see commit `ca3c28a`). None affect correctness.

- [ ] **JSON formatting inconsistency in `assets/data/spell_library.json`** —
      the 5 Ritual spells added by that branch use multi-line citation
      formatting; the other 31 built-in spells use compact single-line. Purely
      cosmetic; reformat the 5 to match if a pass over this file happens for
      any other reason. **Item 27 is exactly such a pass** — fold this in there.
- [ ] **A widget test title promises more than it asserts** — one test in
      the Ritual Spells work (`test/presentation/widgets/*` or
      `test/presentation/screens/spell_creation_screen_test.dart`; not pinned
      down further by the review) has a name broader than what it actually
      checks. Needs a pass to find and either narrow the title or extend the
      assertions.
- [ ] **The "no accidental Ritual" regression-guard loop only checks
      `ritualDeclaration`**, not a full breakdown recompute — it could in
      theory miss a case where `ritualDeclaration == none` but
      `RitualStatus`-derived reasons (e.g. a guideline flag or the >50
      threshold) still fire. Tighten it to assert on a recomputed
      `LevelBreakdown.ritualStatus.isRitual` instead of just the declaration
      field.
- **Rationale:** Recorded here rather than fixed immediately because none is a
  correctness bug — see `.superpowers/sdd/progress.md` in the (now-merged)
  `feature/ritual-spells` history for the full review context.

---

## D. Low Priority / Nice-to-Have

### 10. Documentation
- [ ] Update README: mention base effects extraction is complete
- [ ] Add Size feature guide to docs
- [ ] Document Aquam sub-type limitations (MVP context)

### 11. Performance
- [ ] Optimize base effects JSON (currently 604 effects, all loaded at startup)
- [ ] Consider lazy-loading or caching strategy if app grows
- **Re-measure after item 27.** A 360-spell library, each computing a level on
  load, is a real change to startup cost — this item's premise gets tested for
  the first time then.

---

## Completed ✅

### 15. Add All Core-Rulebook Parameters — ✅ COMPLETE
The catalog held **17** parameters; the ArM5 core rulebook defines **25**, and
one existing entry was misnamed. This was a correctness problem, not just a
gap: spells needing Ring, Circle or Eye could not be expressed at all.

- [x] **Range — add Eye (+1).** The rulebook pairs it with Touch: "Touch and Eye
      are the same 'level' of range", listed as `Touch/Eye`. Not interchangeable
      with Touch, just equal in magnitude.
- [x] **Duration — add Ring (+2)** (paired with Sun) **and Year (+4)**.
- [x] **Target — add Circle (+0)** (paired with Individual) **and the four
      missing magical senses: Taste (+0), Touch (+1), Smell (+2), Hearing (+3).**
      The senses are Intellego targets, each equivalent to a standard target:
      Taste=Individual, Touch=Part, Smell=Group, Hearing=Structure,
      Vision=Boundary. Vision was already present and correct.
- [x] **Rename `Bound` → `Boundary`.** The rulebook name is Boundary. Id changed
      to `target-boundary` (backward compatibility was not a goal, and no
      built-in spell used the old id).
- [x] Verify the built-in spells still calculate correctly after the rename —
      confirmed via the full asset test suite, plus a new demonstration spell
      ("Thoughts Within Babble," Intellego Mentem, Target: Hearing, Level 25)
      added specifically to exercise one of the new parameters end to end.
- **Status:** ✅ COMPLETE (commit `c835d0a`, branch `feature/parameters-and-provenance`)
- **Independently confirmed complete by the 2026-07-28 audit:** every Range,
  Duration and Target used by all 360 published core spells resolves against
  these 25 entries. No parameter work remains for the import.
- **The two open constraints were each explicitly decided, not left unresolved:**
  - **Ritual-only gating (Year, Boundary) — since resolved.**
    `Parameter.requiresRitual` landed on branch `feature/ritual-spells` (item
    4's "Ritual-Only Constraints"), and `Year`/`Boundary` are exactly the two
    entries flagged `requiresRitual: true`. See
    `docs/superpowers/specs/2026-07-27-ritual-spells-design.md`. Item 17's
    Merinita/Symbolic-Magic parameters still need the *Virtue*-gating half.
  - **Target `Touch` / Range `Touch` name collision — left as-is.** Harmless in
    the data (ids are category-scoped: `range-touch` vs `target-touch`); the
    creation screen's dropdowns filter by category, so the two never appear in
    the same picker. Not disambiguated.
- **Spec/Plan:** `docs/superpowers/specs/2026-07-27-parameters-and-provenance-design.md`,
  `docs/superpowers/plans/2026-07-27-parameters-and-provenance.md`
- **Files touched:** `assets/data/parameters.json` (25 entries), `assets/data/spell_library.json`
  (1 new spell), `lib/models/parameter.dart`, `test/data/datasources/asset_data_loader_test.dart`

### 1. Spell Constraint: One of Each Parameter — ✅ COMPLETE
- [x] Add validation that each spell has exactly ONE Range
- [x] Add validation that each spell has exactly ONE Duration
- [x] Add validation that each spell has exactly ONE Target
- **Rationale:** Ars Magica rules: spells have single Range/Duration/Target, modifiers scale level instead
- **Status:** ✅ COMPLETE (commit 2d897db)
- **Implementation:**
  - Redesigned UI with three dedicated dropdowns (Range, Duration, Target)
  - SpellCreationBloc enforces one-per-category in ParameterAdded handler
  - SpellEngine.validateSpellDraft() requires all three categories
  - Dropdown automatically replaces if same category selected again

### 8. UI: Disable Multi-Select for Range/Duration/Target — ✅ OBSOLETE
- **Superseded by item 1**, which replaced multi-select with three dedicated
  dropdowns. Selecting multiple Ranges, Durations or Targets is no longer
  representable in the UI at all, which is what this item asked for. Closed
  without separate work.

### 2. Requisites UI & Integration — ✅ COMPLETE
- [x] Add requisites section to spell creation screen
- [x] Allow selecting any number of Arts as requisites
- [x] Validate: requisite art cannot be the spell's own Technique or Form; no duplicate arts
- [x] Requisite magnitude feeds the calculated level (adding = +1, free = +0)
- [x] Differentiate free vs adding requisites in UI (per-row kind dropdown)
- **Status:** ✅ COMPLETE (branch `feature/requisites-ui`)
- **Implementation:**
  - Replaced RequiredRequisite/AdditionalRequisite with one `Requisite(art, kind)`
    and a `RequisiteKind` enum (`free` = 0 magnitude, `adding` = 1)
  - Spell/SpellDraft carry a single `requisites` list; serialization uses one
    `requisites` key, and all 27 built-in spells were migrated
  - Events: `RequisiteAdded(art, kind)` / `RequisiteRemoved(art)` /
    `RequisiteKindChanged(art, newKind)`
  - Art pool is the de-duplicated union of ArsArts + ArsForms minus the spell's
    own Technique and Form; already-chosen arts drop out of the add dropdown
- **The free/adding split is confirmed sufficient by the audit** — every
  requisite-driven magnitude in the 360 published spells is +0 or +1
  (`no cost for Intellego effect`, `+1 Rego effect`, `requisite free`).
- **Follow-up not done here:** the level preview shows the total only; it does
  not itemise which magnitude came from requisites vs parameters vs factors.
  *(Since resolved — the Spell Modifiers work added the itemised breakdown.)*

### 3. Size Feature (MVP) — ✅ COMPLETE
- [x] Add Size magnitude parameter to spell model
- [x] Add Size selection to spell creation UI
- [x] Update spell level calculation to include Size
- [x] Document Aquam gap: only 1 of 5 sub-Individual types per Form in MVP
- **Status:** ✅ COMPLETE (delivered by the Spell Modifiers plan, Task 11)
- **Implementation — it did NOT land the way this item originally anticipated.**
  There is no bespoke `size` field on `Spell`. Size is modelled as ordinary
  scoped Modifiers, so it needed no model change beyond the `selectedModifiers`
  map that was already there:
  - 8 Size ladders in `assets/data/modifiers.json`, each 5 options: Base
    Individual (+0) then ×10/×100/×1,000/×10,000 at +1…+4
  - Each is Form-scoped and excludes Intellego. Mentem and Vim deliberately have
    none.
  - Magnitude feeds the level through the normal modifier path — no special case
    in the calculator.
- **Aquam gap — closed as documented, not as fixed.** `size-aquam` carries one of
  the Form's 5 base-Individual sub-types, recorded in its base option's
  `baseIndividual` field. See the standing note at the foot of this file.
- **Two limitations became real blockers and moved to item 19:** the +4 ceiling,
  and the Mentem exemption being implemented Form-wide when the rulebook states
  it only for Individual targets.

### 4. Resolve Out-of-Scope Base Effects — ⚠️ PARTIALLY COMPLETE
Audited sub-item by sub-item on 2026-07-28. **Four done, two were never real
gaps, three remain open and have moved to their own sections above.**

- [x] **Ritual-Only Constraints** — ✅ COMPLETE (branch `feature/ritual-spells`)
  - [x] Ritual flag on BaseEffect — landed as `RitualRequirement`
        (`none`/`suggested`/`required`), 7 required and 38 suggested entries
  - [x] Validate in spell creation — landed as derivation, not validation:
        nothing is rejected, because a Year-duration spell is not an error,
        it is a Ritual
  - [x] Display warning in UI — landed as the `RitualSection` banner
  - **This sub-item's original wording was wrong.** It said "force Duration =
        Ritual". Ritual is a spell *type*, orthogonal to all eight Durations.
- [x] **Complexity-Stacking Modifiers** — ✅ COMPLETE. Landed as
      `crim-complexity` (3 options), `peim-complexity` (1), `reim-complexity`
      (3), migrating the old special factors. Covers 11 published spells.
- [x] **Material Difficulty Scaling** — ✅ COMPLETE. Landed as
      `muto-terram-material`, `perdo-terram-material`, `rego-terram-material`
      (5 options each, also carrying `baseIndividual`). Covers 10 published
      spells. Creo Terram deliberately has none — material *is* the base effect
      there.
- [x] **Magnitude Ladders** — ✅ COMPLETE. Landed as `rego-transport-distance`
      (6 rungs, 5 paces → Arcane Connection), scoped by `effectIds` to
      `rehe-10b`, `reig-3c`, `rete-4` (first two renamed from `rrhe-10b`/
      `rrig-3c` when the base-effect id scheme was corrected).
- [x] **Characteristic Point Scaling** — ⚪ NOT A GAP. Each rung is already its
      own base effect (`crme-30` … `crme-55`, renamed from `creem-30`…`creem-55`);
      choosing "to no more than +2" *is* choosing `crme-40`. What looked like
      a modelling gap was an
      extraction gap in Creo Animal only — now item 22.
- [ ] **Variable Base Levels** — → **moved to item 25**, and the sub-item badly
      understated it. Most `"Variable base level"` notes are informational rung
      entries, but 47 **General entries** have no correct integer level at all.
- [ ] **Conditional Wards** — → **remains as item 4** in section A, now
      dependent on item 25.
- [ ] **Intensity/Damage Modifiers** — → **moved to item 4b**, section B.
- [ ] **Level-Dependent Might Reduction** — → **moved to item 4c**, section B.

**Two modifier families landed that this item never listed:**
`creo-auram-unnatural` (4 rungs; covers 11 published spells) and
`aquam-base-individual` (5 sub-types, all magnitude 0).

**The original "~200 flagged effects" figure was wrong** and should not be
quoted. The Spell Modifiers spec's audit reduced it to 23 effects across 4
modifier families; the 2026-07-28 audit reduced the genuinely uncomputable
remainder to section B's two families.

**Spec:** `docs/superpowers/specs/2026-07-25-spell-modifiers-design.md`

### 5. Asset Data Loader Test Failures (Pre-existing) — ✅ COMPLETE
- [x] Fixed the id-mismatch failure: 19 built-in spells' embedded `baseEffect` referenced ids that don't exist in `base_effects.json` (e.g. `crim-2` vs the real `creim-2`, and 14 spells across Intellego/Muto/Perdo/Rego Imaginem whose ids were entirely made up, merging two real catalog entries into one nonexistent id). Corrected all 19 to reference the real matching entry, picked by each spell's own flavor text. No level changes — every corrected pair has an identical `baseLevel`.
- [x] Fixed the stale-count failures: `test/data/datasources/asset_data_loader_test.dart`'s `loadBaseEffects` count and `test/bloc/configuration_bloc_test.dart`'s 3 effect-count assertions hardcoded `38`, stale since the 604-effect extraction. Rather than just updating the number, made both self-healing: the loader test now derives its expected count from `base_effects.json`'s raw entry count directly (an oracle independent of the loader itself); the bloc tests derive their baseline via `AssetDataLoader().loadBaseEffects()` once in `setUpAll`.
- **Rationale:** `base_effects.json` is bulk-extracted and grows unpredictably across many commits; a hardcoded count is exactly what silently drifted by 566 entries
- **Impact:** Full suite now at 207 passed, 0 failed
- **Note for item 27:** `loadSpellLibrary`'s count was deliberately left as a
  literal, because the library was a small hand-curated list. Importing 360
  spells invalidates that reasoning — make it self-healing too.

### Base Effect Extraction
- [x] Extract all 604 base effects (Ars Magica 5e Guidelines)
  - [x] Animal (30) · Aquam (115) · Auram (41) · Corpus (98) · Herbam (49)
  - [x] Ignem (70) · Imaginem (38) · Mentem (58) · Terram (51) · Vim (54)
- [x] Document out-of-scope patterns
- [x] Fix Flutter desktop setup (sqflite_common_ffi initialization)

---

## Notes

**Aquam MVP Limitation:**
The Aquam Form has 5 distinct base-Individual sub-types (water/liquids/poisons/blood/wine), each with slightly different guideline progressions. The Size feature MVP supports one sub-type per spell via `aquam-base-individual`. Full support (mixed sub-types within Size calculations) is deferred.

**Source of truth for the import:**
`Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md`,
Chapter 9 (lines 12020–16004). Note that the 604 base effects were extracted from
`raw-md/Ars Magica 5e - Core Rules.md` — item 22 reconciles the two.

**Verification rule of thumb:** a change to a screen's widget tree is not
verified by `flutter test` alone — `flutter test` does not run
`integration_test/`. See item 6.
