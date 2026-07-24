# Base Effects Extraction Progress Ledger

**Start date:** 2026-07-24  
**Current branch:** main  
**Total target:** 8 Forms (Auram–Vim), ~250 effects, ~395 total when complete

## Completed Forms

- [x] Animal (commit 5935242, 30 effects)
- [x] Aquam (commit 8ca3c9c, 115 effects)
- [x] Auram (commit 6542d05, 41 effects)
- [x] Corpus (commit 5fafdb3, 98 effects)

## In Progress / To Do

- [ ] Ignem (~35 effects)
- [ ] Imaginem (~30 effects)
- [ ] Mentem (~30 effects)
- [ ] Terram (~30 effects)
- [ ] Vim (~25 effects)

---

## Extraction Sessions

### Session 1 (2026-07-24 - current)

**Starting effect count:** 145 (Animal+Aquam, from commit 8ca3c9c)  
**Task:** Extract Auram (5 Technique+Form)

#### Auram Status

- **Creo Auram** — Not started
- **Intellego Auram** — Not started
- **Muto Auram** — Not started
- **Perdo Auram** — Not started
- **Rego Auram** — Not started

---

## Out-of-Scope Patterns Encountered

(Updated as extraction proceeds)

### Previous (Animal+Aquam)
- Creo Aquam general: level-dependent damage (damage = +Level)
- Muto Aquam general: level-dependent Ease Factor (3 + 3×magnitudes)
- Perdo Aquam general: level-dependent destruction
- Rego Aquam general: conditional ward (Might vs level)

### New (Auram—Vim)

**Auram (commit 6542d05)**
- Creo/Muto/Perdo Auram general: magnitude modifiers for unnatural contexts (+1/+2/+4 magnitudes)
- Creo Auram level 25: ritual-only (air elemental creation)
- Muto Auram general: level-dependent damage (gas doing +level damage) and level-dependent Might reduction
- Perdo Auram general: level-dependent Might reduction
- Rego Auram general: conditional ward (Might vs level)

**Corpus (commit 5fafdb3)**
- Creo Corpus (healing): ritual-only flags for healing spells (must be Momentary Duration unless otherwise noted)
- Intellego Corpus general: variable base level ("Sight of the True Form" depends on transformation complexity)
- Rego Corpus: transport entries with magnitude ladders (5p/50p/500p/1league/7leagues/Arcane Connection)

---

## Test Results

- Configuration repository test: expect(all.length, 146) ✅ passing
- Full test suite: 131/136 passing (5 asset-loader validation failures—not blocking)

---

## Notes for Resume

If context compacts before completion:
1. Check git log to find last committed Form
2. Resume at next Form in the todo list
3. Update this ledger before extracting each new Form
4. Run tests after each Form's extraction to verify count matches
5. Commit with message: `feat: add [Form] base effects ([N] effects)`

Current procedures documented in: `docs/base_effects_expansion_guide.md`  
Rulebook offset table: `docs/base_effects_expansion_guide.md` lines 86–134
