# Rules Fidelity

### 4b. Intensity/Damage Modifiers
- [ ] **4b.1** Muto/Perdo Ignem: add 1 magnitude per 5 points fire damage exceeds +5
- **No published spell needs it.** The one that motivated this item, *Ward
  against Heat and Flames*, turned out to be **Rego** Ignem and to have a real
  catalog mechanism already (`rego-ignem-fire-intensity`); it was wired up
  2026-08-15 and imports. What's left is genuinely Muto/Perdo only — a
  display/derivation question in the same shape as item 42.
- **Item 25 retired the General-row half** (`GeneralEffectKind.damage`).


### 4c. Level-Dependent Might Reduction
- [ ] **4c.1** Muto/Perdo Ignem/Auram: elemental Might reduced by spell **level**, not magnitude
- **No published spell's level depends on this** — it describes runtime effect, not
  cost. Display concern only. Item 25 retired the General-row half
  (`GeneralEffectKind.mightReduction`).


### 50. `size-terram` on an Intellego Spell — Rulebook-Printed Exception to the `excludeTechniques` Rule

Found 2026-08-16 investigating item 19's final-review follow-up (a proposed
corpus-level guard: every selected modifier should be in scope for its own
spell/template). Writing that guard immediately failed on one spell.

- [ ] **50.1** Decide how to model *Sense the Feet that Tread the Earth* (InTe 30,
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
- [ ] **20.1** Decide whether every "Create X" guideline should carry
      `RitualRequirement.suggested`, as the Creo healing guidelines now do
- **Rationale:** Core Rules line 12176 — "An item made with Creo only lasts for the
  duration of the spell, unless the spell was a Momentary Ritual" — makes creation
  as much a lasting-thing case as healing.
- **The audit supports leaving it.** Hundreds of entries across ten Forms; the
  checkbox already defaults on for *every* Creo + Momentary draft, and all 32
  derivable Ritual spells derive correctly without it. The flag would add
  explanatory text only.


### 21. Creo Mentem Memory Restoration
- [ ] **21.1** Decide whether `crme-4b`, `crme-5b` and `crme-10a` ("Restore a memory … to a
      fresh state") are Momentary-Creo-lasting-thing cases
- **Context:** the Ritual sweep's criterion arguably reaches them, but the approved
  scope was Creo *bodily* healing across Animal, Corpus and Herbam, and the
  healing-suspension rule at line 13415 does not cover memory. All three are flagged
  "Variable base level" — **but they are rung entries with real integer levels, not
  General entries, so item 25 does not reach them.**


### 12. Out-of-Scope Effects Handling
- [ ] **12.1** Create filtering/tagging UI for flagged effects (variable base levels,
      ritual-only, etc.)
- [ ] **12.2** User guidance: explain which effects don't fit the calculation model yet
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

- [ ] **22.1** **One bullet unaccounted for:** Muto Aquam General — *"Convert part of a
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

- [ ] **4.1** Add a ward type field to `BaseEffect`
- [ ] **4.2** Level threshold: a ward affects creatures whose Might is below the spell's
      level — **display it, do not compute a different level from it**
- [ ] **4.3** UI section for ward configuration
- **13 published ward spells; 8 are General-level**, and for those the ward threshold
  *is* the chosen level, already supplied by `deriveGeneralEffect`
  (`GeneralEffectKind.mightThreshold`). What remains is the ward-type field and its
  display, not the threshold math.


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

- [ ] **42.1** Decide the display mechanism: likely a read-only derived field shown wherever
      a poison/disease guideline is used, computed as `base Ease Factor + rate ×
      magnitudes above the guideline's own base level` — needs its own design.
- **Only one base effect touches disease today** (`peco-20b`, "Inflict a major
  disease"); Creo/Muto Aquam's poison guidelines already have 5 rows each
  (`craq-5a/10b/15/20/25a`, `muaq-2b/3a/4c/5c/10b`) encoding the wound-severity
  table, separate from this formula.
- **Files:** `lib/engine/spell_engine.dart` (or wherever `effectFormula` is
  rendered), `assets/data/base_effects.json`


### 63. The Ritual Default Is Form-Blind, and Imaginem/Mentem Pay for It

**Opened 2026-08-18.** `SpellDraft.isEligibleForLastingCreationDeclaration`
(`lib/models/spell.dart:517-518`) is exactly
`technique == 'Creo' && duration?.id == 'duration-momentary'` — it never looks
at the Form. So `_withRitualDeclaration`
(`lib/bloc/spell_creation/spell_creation_bloc.dart:725-735`) defaults **every**
Momentary Creo spell to `RitualDeclaration.lastingCreation`, and a Momentary
**Creo Imaginem** or **Creo Mentem** spell is auto-declared a Ritual.

That is very unlikely to be right. The lasting-creation rule is about bringing
something into being that persists after the magic ends; a Momentary image or a
Momentary mental effect does not leave a created *thing* behind, and neither
Form is a plausible Ritual by default. The two most affected Forms are the two
where the default is most often wrong.

- [ ] **63.1** **Establish the ruling before touching the predicate.** Find what the
      Definitive Edition actually says about which Creo effects at Momentary
      require a Ritual (see the rulebook checkout — `reviewed/` is
      authoritative). The fix hinges on whether the rule is "Creo except
      Imaginem/Mentem", "Creo of a *material* Form", or something the
      guideline itself should carry rather than the Technique/Duration pair.
- [ ] **63.2** **Decide where the knowledge belongs.** A hardcoded Form exclusion list
      in `isEligibleForLastingCreationDeclaration` is the cheap fix and the
      same shape of hardcoding that made this wrong in the first place. The
      alternative — a flag on the base effect / guideline, so the catalog
      states it as data — is the direction item 14's design argued for when it
      hit the same "make the kind catalog data" question for Target kinds.
- [ ] **63.3** **Check what a changed default does to already-saved spells.**
      `_withRitualDeclaration` leaves `storyguideRuling` alone, but any user
      spell saved with the auto-applied `lastingCreation` keeps it; those rows
      would need to be either re-derived or left as an explicit user choice.
      Note the prototype rule: dropping the DB is free if that is cleaner.
- **Files:** `lib/models/spell.dart:517-518`,
  `lib/bloc/spell_creation/spell_creation_bloc.dart:725-735`
- **See also:** item 14 (the "make it catalog data" precedent)
