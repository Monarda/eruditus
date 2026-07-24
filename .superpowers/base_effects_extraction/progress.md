# Base Effects Extraction Progress Ledger

**Start date:** 2026-07-24  
**Current branch:** main  
**Total target:** 8 Forms (Auram–Vim), ~250 effects, ~395 total when complete

## Completed Forms

- [x] Animal (commit 5935242, 30 effects)
- [x] Aquam (commit 8ca3c9c, 115 effects)
- [x] Auram (commit 6542d05, 41 effects)
- [x] Corpus (commit 5fafdb3, 98 effects)
- [x] Herbam (commit 26fe212, 49 effects)
- [x] Ignem (commit b78a1a7, 70 effects)

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

**Herbam (commit 26fe212)**
- Rego Herbam general: conditional ward (Might vs level)
- Rego Herbam level 10: magnitude ladder for transport distance

**Ignem (commit b78a1a7)**
- Creo Ignem level 25: ritual-only (fire elemental creation)
- Muto Ignem general: level-dependent Might reduction for fire elementals
- Muto Ignem: intensity modifier (for every 5 points fire damage exceeds +5, add 1 magnitude)
- Perdo Ignem general: level-dependent Might reduction
- Perdo Ignem: intensity modifier (similar to Muto)
- Rego Ignem general: conditional ward (Might vs level)
- Rego Ignem level 3: magnitude ladder for transport distance
- Rego Ignem levels 15-40: wards with fixed damage thresholds (+5, +10, +15, +20, +25, +30)

---

## Test Results

- Configuration repository test: expect(all.length, 404) ✅ passing (403 built-in + 1 custom)
- Full test suite: 131/136 passing (5 asset-loader validation failures—pre-existing, not related to extraction)

---

## Status Summary (as of 2026-07-24, end of session 1)

**Progress:** 6 of 8 Forms complete (75%)  
**Extracted:** 403 base effects (from 50 Technique+Form combinations)  
**Remaining:** 3 Forms (Imaginem, Mentem, Terram, Vim) estimated ~115 effects → ~518 total on completion  
**Last commit:** b78a1a7 (Ignem)

## Notes for Resume (Session 2+)

If context compacts before completion:
1. Check git log to find last committed Form: `git log --oneline | head -20`
2. Identify next Form from todo list (should be Imaginem)
3. Read rulebook offsets from `docs/base_effects_expansion_guide.md` lines 111–134
4. Extract effects following the same pattern as prior Forms
5. Update test expectations to [prior total] + [new form effects]
6. Run configuration_repository_test to verify count
7. Commit with message format: `feat: add [Form] base effects ([N] effects)`
8. Update this progress.md before extracting next Form

**Current procedures:** `docs/base_effects_expansion_guide.md`  
**Rulebook:** `C:\Users\idf53\Development\personal\arsm\Ars-Magica-Open-License\reviewed\Ars Magica - Definitive Edition (Core Rules).md`  
**Offsets for remaining Forms:**
- Creo Imaginem: offset 14646, limit 80
- Intellego Imaginem: offset 14705, limit 65
- Muto Imaginem: offset 14756, limit 45
- Perdo Imaginem: offset 14828, limit 65
- Rego Imaginem: offset 14902, limit 70
(See expansion guide for Mentem, Terram, Vim offsets)
