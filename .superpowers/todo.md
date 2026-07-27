# Eruditus Todo List

**Status:** Active development  
**Last Updated:** 2026-07-27  
**Base Effects:** ✅ Complete (604 effects extracted)

---

## Next Up (item numbers are IDs, not priority order)

1. **Item 15** — add the missing core-rulebook parameters. Blocks 14, and the
   catalog is wrong today, not merely incomplete.
2. **Item 14** — container targets: at-casting vs. subsequently-entering.
3. **Item 13** — summary/description entry for user-created spells.

---

## High Priority Fixes

### 15. Add All Core-Rulebook Parameters — ⚠️ DO THIS FIRST
The catalog holds **17** parameters. The ArM5 core rulebook defines **25**, and
one existing entry is misnamed. This is a correctness problem, not just a gap:
spells that need Ring, Circle or Eye cannot currently be expressed at all.

- [ ] **Range — add Eye (+1).** The rulebook pairs it with Touch: "Touch and Eye
      are the same 'level' of range", listed as `Touch/Eye`. Not interchangeable
      with Touch, just equal in magnitude.
- [ ] **Duration — add Ring (+2)** (paired with Sun) **and Year (+4)**.
- [ ] **Target — add Circle (+0)** (paired with Individual) **and the four
      missing magical senses: Taste (+0), Touch (+1), Smell (+2), Hearing (+3).**
      The senses are Intellego targets, each equivalent to a standard target:
      Taste=Individual, Touch=Part, Smell=Group, Hearing=Structure,
      Vision=Boundary. Vision is already present and correct.
- [ ] **Rename `Bound` → `Boundary`.** The rulebook name is Boundary. The id
      (`target-bound`) may keep its spelling or change — backward compatibility
      is not a goal, and no built-in spell currently uses it.
- [ ] Verify the 30 built-in spells still calculate correctly after the rename
- **Two constraints the model cannot express yet — decide how to handle:**
  - **Year duration and Boundary target are ritual-only.** The rulebook is
    explicit: "A spell with this duration must be ritual" (Year) and "A spell
    with this target must be a ritual" (Boundary). There is no ritual flag on
    `Parameter` or `Spell` today. This overlaps todo item 4's "Ritual-Only
    Constraints" — either add the flag here, or add these two parameters
    knowingly unconstrained and let item 4 close it. **Vision is deliberately
    NOT ritual** ("unlike Boundary, it does not require Ritual magic"), so the
    flag must sit on the parameter, not be inferred from magnitude.
  - **Target `Touch` collides by name with Range `Touch`.** Harmless in the data
    (ids are category-scoped: `range-touch` vs `target-touch`) but the creation
    screen's dropdowns show bare names, so both will read "Touch" in different
    pickers. Confirm that is acceptable or disambiguate the label.
- **Source:** `Ars-Magica-Open-License/raw-md/Ars Magica 5e - Core Rules.md`,
  section "Ranges, Durations, Targets" (~line 7840) and "Magical Senses".
- **Files:**
  - `assets/data/parameters.json` (8 new entries, 1 rename)
  - `test/data/datasources/asset_data_loader_test.dart` (the parameter count is
    a hardcoded `17` — update it, and consider whether it should stay a literal;
    it is a small hand-curated list, so a literal is defensible)

### 1. Spell Constraint: One of Each Parameter
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

### 2. Requisites UI & Integration
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
- **Follow-up not done here:** the level preview shows the total only; it does
  not itemise which magnitude came from requisites vs parameters vs factors.

### 3. Size Feature (MVP) — ✅ COMPLETE
- [x] Add Size magnitude parameter to spell model
- [x] Add Size selection to spell creation UI
- [x] Update spell level calculation: base + (Technique modifiers) + (Form modifiers) + (Parameters) + **Size**
- [x] Document Aquam gap: only 1 of 5 sub-Individual types per Form in MVP
- **Rationale:** Ars Magica 5e core mechanic; Size affects target count/scope
- **Status:** ✅ COMPLETE (delivered by the Spell Modifiers plan, Task 11)
- **Implementation — note it did NOT land the way this item originally anticipated.**
  There is no bespoke `size` field on `Spell`. Size is modelled as ordinary
  scoped Modifiers, so it needed no model change at all beyond the
  `selectedModifiers` map that was already there:
  - 8 Size ladders in `assets/data/modifiers.json` (`size-animal`, `size-aquam`,
    `size-auram`, `size-corpus`, `size-herbam`, `size-ignem`, `size-imaginem`,
    `size-terram`), each 5 options: Base Individual (+0) then ×10/×100/×1,000/
    ×10,000 at +1…+4
  - Each is Form-scoped and excludes Intellego, so the ladder only appears on
    spells where Size is meaningful. Mentem and Vim deliberately have none.
  - Selection is stored in `Spell.selectedModifiers` as id references, rendered
    by the shared modifiers section, and its magnitude feeds the level through
    the normal modifier path in `SpellEngine.calculateBreakdown` — no special
    case in the calculator.
- **Aquam gap — closed as documented, not as fixed.** The Form has 5
  base-Individual sub-types (water/liquids/poisons/blood/wine); `size-aquam`
  carries exactly one, recorded in its base option's `baseIndividual` field as
  "a pool five paces across, two paces deep". The other four remain out of
  scope, as the MVP intended. See the standing note at the foot of this file.

### 4. Resolve Out-of-Scope Base Effects (~200 effects)
- [ ] **Variable Base Levels** — Some effects have non-linear level progressions (e.g., Perdo Imaginem levels 2,3,4,5,10; Creo Mentem levels 3,4,5,10,30-55)
  - [ ] Design model extension for level-dependent base levels
  - [ ] Update UI to handle effects with multiple valid base levels
  - [ ] Refactor calculator to pick appropriate base level based on spell context

- [ ] **Magnitude Ladders** — Transport/distance scales (Rego Aquam, Rego Ignem, Rego Terram: 5p→50p→500p→1 league→7 leagues→Arcane Connection)
  - [ ] Add magnitude ladder field to BaseEffect model
  - [ ] Calculate multiplier based on distance target selection
  - [ ] Update spell creation UI with distance picker

- [ ] **Conditional Wards** — Might-level-dependent effects (Rego entries: ward against creatures with Might ≤ spell level)
  - [ ] Add ward type field to BaseEffect
  - [ ] Calculate level multiplier: (base + parameters) must exceed target Might
  - [ ] New UI section for ward configuration

- [ ] **Ritual-Only Constraints** — Some effects require Ritual duration (Creo Corpus healing, Creo Ignem/Auram elemental creation)
  - [ ] Add ritual-only flag to BaseEffect
  - [ ] Validate in spell creation: if ritual-only, force Duration = Ritual
  - [ ] Display warning in UI

- [ ] **Complexity-Stacking Modifiers** — Sensory/movement/intricacy add magnitudes (Creo Imaginem: +1/+2 for complexity, +2 for movement control, +1 for intricacy)
  - [ ] Design modifier system (separate from special factors)
  - [ ] Add complexity selector to UI
  - [ ] Update level calculation with dynamic modifiers

- [ ] **Characteristic Point Scaling** — Creo Mentem levels tied to Characteristic targets (level 30→+0, 35→+1, 40→+2, etc.)
  - [ ] Generalize as "target-dependent base levels"
  - [ ] Add target selector to spell creation for affected effects
  - [ ] Calculate base level from target

- [ ] **Material Difficulty Scaling** — Terram effects: +1 for stone/glass, +2 for metal/gemstone (applied to all Terram techniques)
  - [ ] Add material selector to base effect configuration
  - [ ] Calculate level based on material choice
  - [ ] UI for material selection in spell creation

- [ ] **Intensity/Damage Modifiers** — Muto/Perdo Ignem: add 1 magnitude per 5 points fire damage exceeds +5
  - [ ] Design intensity modifier as dynamic calculation
  - [ ] Link to fire damage special factor
  - [ ] Update level preview in real-time

- [ ] **Level-Dependent Might Reduction** — Muto/Perdo Ignem/Auram: elemental Might reduced by spell level
  - [ ] Tag effects as "Might-reduction type"
  - [ ] Note that Might reduction = spell level (not magnitude)
  - [ ] Document in UI

**Total Flagged Effects by Form:**
- Creo: 12+ (characteristic scaling, complexity, ritual)
- Intellego: 8+ (variable levels)
- Muto: 25+ (complexity, material, intensity, Might reduction)
- Perdo: 20+ (variable levels, intensity, Might reduction)
- Rego: 30+ (magnitude ladders, wards, conditional effects)
- Vim: 54 (all effects: complex meta-magical mechanics)

**Suggested Approach:**
1. Pick one pattern category (e.g., magnitude ladders)
2. Extend BaseEffect model with new field
3. Update SpellEngine.calculateSpellLevel() to handle it
4. Add UI widget for that pattern
5. Test with affected effects
6. Repeat for next category

### 5. Asset Data Loader Test Failures (Pre-existing) — ✅ COMPLETE
- [x] Fixed the id-mismatch failure: 19 built-in spells' embedded `baseEffect` referenced ids that don't exist in `base_effects.json` (e.g. `crim-2` vs the real `creim-2`, and 14 spells across Intellego/Muto/Perdo/Rego Imaginem whose ids were entirely made up, merging two real catalog entries into one nonexistent id). Corrected all 19 to reference the real matching entry, picked by each spell's own flavor text. No level changes — every corrected pair has an identical `baseLevel`.
- [x] Fixed the stale-count failures: `test/data/datasources/asset_data_loader_test.dart`'s `loadBaseEffects` count and `test/bloc/configuration_bloc_test.dart`'s 3 effect-count assertions hardcoded `38`, stale since the 604-effect extraction. Rather than just updating the number, made both self-healing: the loader test now derives its expected count from `base_effects.json`'s raw entry count directly (an oracle independent of the loader itself); the bloc tests derive their baseline via `AssetDataLoader().loadBaseEffects()` once in `setUpAll`. Deliberately left `loadParameters` (17) and `loadSpellLibrary` (30) as literals — both are small, hand-curated lists changed in deliberate reviewed batches, not bulk-extracted, and haven't gone stale.
- **Rationale:** `base_effects.json` is bulk-extracted and grows unpredictably across many commits; a hardcoded count is exactly what silently drifted by 566 entries
- **Impact:** Full suite now at 207 passed, 0 failed
- **Result:** No further action needed on this item

---

## Medium Priority

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
- **Files:** Test helpers, widget test templates, `integration_test/`

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells conform to new constraints (one Range/Duration/Target)
- [ ] Add migration for legacy spell saves (if any)
- [ ] Test backup round-trip (export → import)

### 8. UI: Disable Multi-Select for Range/Duration/Target
- [ ] Update UI to prevent selecting multiple Range options
- [ ] Update UI to prevent selecting multiple Duration options
- [ ] Update UI to prevent selecting multiple Target options
- **Impact:** Spell creation screen readability/UX

### 9. Spell Tags / Library Organisation
- [ ] Add a `tags` field to the Spell model (free-form list of strings)
- [ ] Allow assigning tags when creating or editing a spell
- [ ] Filter/browse the library by tag
- [ ] Support multiple tags per spell, and combining tag filters with existing search + source filters
- [ ] Decide whether tags are free-text, a curated vocabulary, or free-text with suggestions from existing tags
- **Rationale:** Thematic grouping that the Technique/Form axes can't express. A spell that raises a castle is both "defensive" and "architecture"; neither is derivable from Creo/Terram.
- **Current State:** Library supports search by name and filter by source only — no user-defined grouping
- **Impact:** Model + persistence change (tags need a table or serialised column), plus library filter UI
- **Files:**
  - `lib/models/spell.dart` (add tags field, toMap/fromMap)
  - `lib/data/database/app_database.dart` (schema + migration for existing saves)
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
**Do this directly after the Spell Provenance and Tags work — both change the `Spell` model, and doing them together avoids a second migration.**

- [ ] Model whether a container-target spell affects only what is inside **at the moment of casting**, or also whatever **enters later**
- [ ] Expose the choice in the spell creation UI, shown only when the selected Target is a container
- [ ] Validate that the choice is absent for non-container targets, so it cannot be set meaninglessly
- [ ] Decide whether the choice affects the calculated level, or is purely descriptive
- **Rationale:** The two readings are different spells. A Room-target spell that
  cleanses everyone present is not the same as one that cleanses everyone who
  walks in for the rest of its Duration. Nothing in the model currently records
  which was meant, so the app cannot tell them apart.
- **Container targets in the catalog today:** `target-room` (Room, +2),
  `target-structure` (Structure, +3), `target-bound` (Bound, +4).
- **Blocked by item 15.** The **Circle** Target and **Ring** Duration are absent
  from `parameters.json` entirely and are the canonical "affects what crosses
  the boundary" case. Item 15 adds them; do that first rather than adding them
  piecemeal here.
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
  - `assets/data/parameters.json` (Circle target, Ring duration)
  - `lib/presentation/screens/spell_creation_screen.dart` (conditional control)
  - `lib/bloc/spell_creation/` (event + state for the choice)
  - `lib/data/database/app_database.dart` (schema bump if the field is stored)

### 16. Short Forms for Parameter Names
**Decide alongside item 15** — that item already edits all 25 parameter entries,
so populating a short form there is nearly free, whereas doing it later means a
second pass over the same file.

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
  breakdown chips — measure before building.
- **Files:** `lib/models/parameter.dart`, `assets/data/parameters.json`,
  wherever a constrained widget turns out to be

---

## Low Priority / Nice-to-Have

### 10. Documentation
- [ ] Update README: mention base effects extraction is complete
- [ ] Add Size feature guide to docs
- [ ] Document Aquam sub-type limitations (MVP context)

### 11. Performance
- [ ] Optimize base effects JSON (currently 604 effects, all loaded at startup)
- [ ] Consider lazy-loading or caching strategy if app grows

### 12. Out-of-Scope Effects Handling
- [ ] Create filtering/tagging UI for flagged effects (variable base levels, ritual-only, etc.)
- [ ] User guidance: explain which effects don't fit the calculation model yet
- **Current State:** ~200 effects flagged with notes documenting out-of-scope patterns

---

## Completed ✅

- [x] Extract all 604 base effects (Ars Magica 5e Guidelines)
  - [x] Animal (30)
  - [x] Aquam (115)
  - [x] Auram (41)
  - [x] Corpus (98)
  - [x] Herbam (49)
  - [x] Ignem (70)
  - [x] Imaginem (38)
  - [x] Mentem (58)
  - [x] Terram (51)
  - [x] Vim (54)
- [x] Document out-of-scope patterns
- [x] Fix Flutter desktop setup (sqflite_common_ffi initialization)

---

## Notes

**Aquam MVP Limitation:**  
The Aquam Form has 5 distinct base-Individual sub-types (water/liquids/poisons/blood/wine), each with slightly different guideline progressions. The Size feature MVP will only support one sub-type per spell. Full support (allowing mixed sub-types within Size calculations) is deferred.

**Out-of-Scope Patterns:**  
~200 base effects don't fit the current level calculation model (variable base levels, magnitude ladders, conditional wards, ritual-only constraints, intensity modifiers). These are flagged in the database for future implementation. App still shows them, but they won't calculate correctly until the model is extended.
