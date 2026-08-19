# Model

### 47. Multiple Base Effects in Spell Creation — Combined Guidelines

**Not on the critical path** — item 39 handled its one published case with a
narrow, importer-only mechanism. But that case is real, and a user designing
their own spell has no way to do what *Conjuration of the Indubitable Cold* does.

- [ ] **47.1** Let a spell draft record more than one base effect, restricted to guidelines
      matching the spell's own Technique/Form **or** that of one of its requisites
      (mirroring how the Requisites section treats requisite Arts as legitimately
      contributing an effect, not just a cost)
- [ ] **47.2** The **highest-level** base effect among those chosen is recorded as
      `baseEffectId` and drives the calculation, per the rulebook's own rule:
      *"the base Arts and level for the spell are those for the highest-level
      effect it has"* (Requisites, Core Rules)
    - **Open question:** is "free" (item 39's answer) general, or only true when
      both guidelines share a level? The Requisites section's rule for
      *unequal*-level combinations charges extra ("each requisite adds at least one
      magnitude" when it "would do significantly less" without it) — a general
      feature likely needs that branch too.
- [ ] **47.3** The other chosen base effect(s) recorded as **structured data** — a
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

- [ ] **53.1** Decide whether `SpellEngine` needs a nested-computation capability, or every
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

- [ ] **54.1** Decide how to model a requisite whose Art is chosen per-casting rather than
      fixed by the spell/template
- **Not urgent:** the template ships with `requisites: {}` and the gap noted in its
  own `description`; no arithmetic is wrong, the requisite is simply absent from the
  computed breakdown.
- **Files:** `lib/models/requisite.dart`, `lib/models/spell_template.dart`,
  `lib/models/spell.dart`
- **Spec:** `docs/superpowers/specs/2026-08-16-virtue-gated-parameters-design.md` ("Out of Scope")


### 57. The Remaining 16 Container Rows Still Owe a Static/Dynamic Ruling

**Opened 2026-08-17, split off item 14 on close.** Item 14 backfilled the 8
Circle wards `dynamic` from one shared Magical Wards rationale, and 5 Momentary
container rows are left unset on purpose (the distinction is vacuous when
nothing can enter during a duration that doesn't elapse). The other 16 have no
shared rule to lean on — each needs its own printed description read against
the "Container Targets" sidebar's static/dynamic test.

- [ ] **57.1** Read each of the 16 rows' printed description and decide static or
      dynamic, citing the specific line that settles it (a shared "container
      target, ward-like" rationale is not enough — item 14's wards case only
      worked because all 8 cite the same rule)
- [ ] **57.2** Record each ruling in `scripts/spell_import/container_modes.json`,
      the same file the 8 wards used, with a rationale apiece
- [ ] **57.3** `spellOwesContainerMode` (`lib/models/spell.dart`) is the predicate that
      identifies which spells still need this — a container Target, not
      Momentary, and `containerMode` still `unstated`
- **See also:** item 14 (closed, `## Completed ✅`)


### 67. The Sensory Magic Restrictions the Model Cannot Yet Express

**Opened 2026-08-18, from item 64's review.** HoH:MC lines 1006-1012 put seven
restrictions on Sensory Magic spells (not six — the book's bullet list runs to
seven; the Intellego bullet is fairly split into two below, own-Technique and
requisite, but two other bullets had gone unrecorded entirely). Item 64
implemented one — Intellego on the spell's own Technique. An earlier draft of
its spec dismissed the ones it considered with a single reason — "the app has
no Virtue model" — which is true of three and false of two; this item records
the accurate position so the tractable ones stay visible. **Both of the
tractable bullets below are now implemented** (2026-08-19, the cross-field
constraints branch); the one bullet still open is storyguide judgment, not a
capability gap — see item 56.

- [x] **67.1** **No Intellego *as a requisite*.** Item 64's `excludeTechniques` covers
      only the spell's own Technique. The book says "even as a requisite", which
      needs a validation check over `draft.requisites` — a different mechanism
      from a scope field, which is why it was not folded in.
      **✅ DONE 2026-08-19 via check 12.** Implemented reading the *same*
      `scope.excludeTechniques` list rather than a parallel field — and check
      12 enforces **both** halves of HoH:MC 1009's sentence at the validation
      layer: the spell's own Technique, and each entry in `draft.requisites`.
      `ParameterScope.appliesTo` filtering the excluded Technique out of the
      picker sits on top of that as a convenience, not as the guarantee — the
      importer and already-saved records never pass through a picker, which is
      what the check is for. (The own-Technique arm was added by the branch's
      whole-branch review, which caught that leaving that half to the picker
      left those two readers unguarded.)
- [x] **67.2** **The Range must be Personal.** The reasoning this bullet was opened
      with — "No capability exists: no parameter constrains another
      parameter's value today," and that a mechanism "for five rows is
      disproportionate" — is now obsolete, not merely resolved, and is
      recorded here only so it is not mistaken for still standing. **✅ DONE
      2026-08-19 via check 11.** Item 70's Core Rules 12086 finding (Personal
      Range forbids a container Target, unconditionally, for every spell) was
      the same capability read the other way, and it is universal rather than
      five-rows-only — so the mechanism was proportionate after all, designed
      from 12086 with these five Sensory Targets as secondary beneficiaries,
      not the justification. `Parameter.requiresRangeId` now expresses
      HoH:MC 1006's rule; `SpellCreationBloc` prunes Range and Target against
      each other in both directions, and the creation screen narrows the Range
      list to the one a Target dictates and locks it, with a line saying why.
      **The forbidding direction is deliberately NOT filtered in the UI** —
      that was built, then removed by the whole-branch review: filtering it hid
      all four container Targets in the default Personal-Range state (every
      fresh draft seeds `range-personal`) and made the bloc's own
      yield-to-the-peer resolution unreachable from the app. Do not re-add it;
      the bloc resolves that conflict. **One further seam
      remains**: the guideline-adoption path (`_seedParameters`) does not
      participate in that pruning — recorded as item 74 rather than fixed
      here, since closing it is a design decision (which field yields on a
      guideline-driven conflict), not an implementation detail.
- [ ] **67.3** **The Form must suit the sensory medium** ("An Ignem spell cannot be
      transmitted by sound"). Storyguide judgment by the book's own wording, so
      display work — belongs with item 56's rules hints, not enforcement. **The
      only bullet left open in this item.**
- **Won't do, recorded so they are not re-litigated:** not investable into
  magical items (the app models no enchantments — the same reason item 65
  excludes *Perceive the Change*); non-initiates cannot learn them, and the
  Heartbeast Ability adds to the Lab Total (no character model, no lab totals);
  the magus must create a taste, texture, scent, sound, or spectacle that
  transmits the spell and must continue to radiate it to affect new targets
  (descriptive of what choosing the Target already means, not a separate
  structured constraint); and the spell can only affect a being capable of
  sensing the caster that way, so non-living objects cannot be affected (no
  creature/character model to check a being's senses against).
- **Files:** `lib/models/spell.dart` (the validation checks),
  `lib/models/parameter.dart`
- **See also:** items 64, 56, 17, 70 (the Core Rules 12086 finding that
  justified the Range-must-be-Personal mechanism)


### 69. Constraint-Handling Pains Deferred From the Cross-Field Design Discussion

**Opened 2026-08-18.** A design
discussion on the growing family of "if X then Y must (not) be Z" rules
identified four distinct pains. **Cross-field value constraints** (one
selection forcing another field's value — items 67/68's Range-must-be-Personal
and dynamic-by-rule) was chosen as the one to solve now and gets its own
design. The other three were judged real but not primary; recorded here so
they are considered deliberately later rather than rediscovered:

- [ ] **69.1** **Per-rule sprawl.** Every new rule touches catalog JSON + model + bloc
      pruning + validation + tests as bespoke code. Worth revisiting if the
      per-book marginal cost keeps growing: is there one declarative place a
      rule could be stated once, with the pruning/validation/UI consequences
      following automatically?
- [ ] **69.2** **Auditability.** Rules are scattered across four mechanisms
      (availability scoping, derivation, validation checks, display hints), so
      "does the app enforce HoH:MC line 1008?" takes five files to answer.
      A registry or taxonomy — every rulebook constraint with one findable
      statement, even if implementations stay bespoke — would also give item 36's
      audit a natural home.
- [ ] **69.3** **Data-driven rules.** Constraints live partly in code, so a new book
      (or user-authored content) cannot add one without Dart changes — the
      same argument that made `scope`/`requiresVirtue` catalog data. Only
      worth it once the constraint vocabulary has stabilised; premature while
      each new book still adds a new *kind* of constraint.
- **See also:** items 67, 68 (the chosen pain's first instances), 56 (display
  hints), 36 (catalog audit)
