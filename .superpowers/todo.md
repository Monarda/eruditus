# Eruditus Todo List

**Status:** Active development  
**Last Updated:** 2026-07-24  
**Base Effects:** ✅ Complete (604 effects extracted)

---

## High Priority Fixes

### 1. Spell Constraint: One of Each Parameter
- [ ] Add validation that each spell has exactly ONE Range
- [ ] Add validation that each spell has exactly ONE Duration  
- [ ] Add validation that each spell has exactly ONE Target
- **Rationale:** Ars Magica rules: spells have single Range/Duration/Target, modifiers scale level instead
- **Impact:** Affects spell_creation_bloc, spell model validation, UI constraints
- **Files:** 
  - `lib/models/spell.dart` (add validation)
  - `lib/bloc/spell_creation/spell_creation_bloc.dart` (enforce in logic)
  - `lib/presentation/screens/spell_creation_screen.dart` (UI restrictions)

### 2. Size Feature (MVP)
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

### 3. Asset Data Loader Test Failures (Pre-existing)
- [ ] Fix 5 failing tests in `test/data/datasources/asset_data_loader_test.dart`
- **Rationale:** Tests reference old base effect IDs that changed during extraction
- **Impact:** Doesn't block app, but test suite noise
- **Fix Approach:** Update test expectations to match 604 new effect IDs

---

## Medium Priority

### 4. Real Bloc Hang in Widget Tests
- [ ] Document workaround: mock Blocs in widget tests, use integration_test for real E2E
- [ ] Create widget test helper with mock bloc factories
- **Context:** Real Bloc hangs forever under flutter_tester; known Bloc limitation
- **Files:** Test helpers, widget test templates

### 5. Spell Export/Backup Validation
- [ ] Validate imported spells conform to new constraints (one Range/Duration/Target)
- [ ] Add migration for legacy spell saves (if any)
- [ ] Test backup round-trip (export → import)

### 6. UI: Disable Multi-Select for Range/Duration/Target
- [ ] Update UI to prevent selecting multiple Range options
- [ ] Update UI to prevent selecting multiple Duration options
- [ ] Update UI to prevent selecting multiple Target options
- **Impact:** Spell creation screen readability/UX

---

## Low Priority / Nice-to-Have

### 7. Documentation
- [ ] Update README: mention base effects extraction is complete
- [ ] Add Size feature guide to docs
- [ ] Document Aquam sub-type limitations (MVP context)

### 8. Performance
- [ ] Optimize base effects JSON (currently 604 effects, all loaded at startup)
- [ ] Consider lazy-loading or caching strategy if app grows

### 9. Out-of-Scope Effects Handling
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
