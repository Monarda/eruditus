# Eruditus Todo List

**Status:** Active development  
**Last Updated:** 2026-07-24  
**Base Effects:** ✅ Complete (604 effects extracted)

---

## High Priority Fixes

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
- [ ] Add requisites section to spell creation screen
- [ ] Allow selecting multiple Forms as additional requisites
- [ ] Validate: requisite Forms cannot be the primary Form
- [ ] Display requisite magnitude contribution in level preview
- [ ] Differentiate Required vs Additional requisites in UI (if both types needed)
- **Current State:** Model + engine support requisites (each = +1 magnitude), but **no UI**
- **Impact:** SpellCreationScreen needs new widget, spell_creation_bloc integration
- **Files:**
  - `lib/presentation/screens/spell_creation_screen.dart` (add requisite widget)
  - `lib/presentation/widgets/` (new requisite_selector widget)
  - `lib/bloc/spell_creation/spell_creation_bloc.dart` (add requisite events)

### 3. Size Feature (MVP)
- [ ] Add Size magnitude parameter to spell model
- [ ] Add Size selection to spell creation UI
- [ ] Update spell level calculation: base + (Technique modifiers) + (Form modifiers) + (Parameters) + **Size**
- [ ] Document Aquam gap: only 1 of 5 sub-Individual types per Form in MVP
- **Rationale:** Ars Magica 5e core mechanic; Size affects target count/scope
- **Impact:** Modifies SpellEngine.calculateSpellLevel(), UI, spell save/load
- **Aquam Context:** Form has 5 base-Individual types (water/liquids/poisons/blood/wine) but MVP only handles one per spell
- **Files:**
  - `lib/models/spell.dart` (add size field)
  - `lib/engine/spell_engine.dart` (level calculation)
  - `lib/presentation/screens/spell_creation_screen.dart` (UI widget)
  - Configuration for Size magnitudes + Aquam sub-type limits

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

### 5. Asset Data Loader Test Failures (Pre-existing)
- [ ] Fix 5 failing tests in `test/data/datasources/asset_data_loader_test.dart`
- **Rationale:** Tests reference old base effect IDs that changed during extraction
- **Impact:** Doesn't block app, but test suite noise
- **Fix Approach:** Update test expectations to match 604 new effect IDs

---

## Medium Priority

### 6. Real Bloc Hang in Widget Tests
- [ ] Document workaround: mock Blocs in widget tests, use integration_test for real E2E
- [ ] Create widget test helper with mock bloc factories
- **Context:** Real Bloc hangs forever under flutter_tester; known Bloc limitation
- **Files:** Test helpers, widget test templates

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells conform to new constraints (one Range/Duration/Target)
- [ ] Add migration for legacy spell saves (if any)
- [ ] Test backup round-trip (export → import)

### 8. UI: Disable Multi-Select for Range/Duration/Target
- [ ] Update UI to prevent selecting multiple Range options
- [ ] Update UI to prevent selecting multiple Duration options
- [ ] Update UI to prevent selecting multiple Target options
- **Impact:** Spell creation screen readability/UX

---

## Low Priority / Nice-to-Have

### 9. Documentation
- [ ] Update README: mention base effects extraction is complete
- [ ] Add Size feature guide to docs
- [ ] Document Aquam sub-type limitations (MVP context)

### 10. Performance
- [ ] Optimize base effects JSON (currently 604 effects, all loaded at startup)
- [ ] Consider lazy-loading or caching strategy if app grows

### 11. Out-of-Scope Effects Handling
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
