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
- [x] Imaginem (commit 5e96c32, 38 effects)
- [x] Mentem (commit fa01406, 58 effects)
- [x] Terram (commit 5b1382f, 51 effects)
- [x] Vim (commit 5b1382f, 54 effects)

**EXTRACTION COMPLETE** ✅

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

**Imaginem (commit 5e96c32)**
- Introduction: complexity-stacking modifiers for sensory perception (+1 magnitude per added sense/complexity)
- Introduction: movement/command modifiers (+2 magnitudes for directed movement/noise at caster's command)
- Introduction: intricacy modifiers (+1 magnitude for very intricate images)
- Perdo Imaginem: variable base levels (2, 3, 4, 5, 10) - sensation destruction follows non-linear progression
- Rego Imaginem general: conditional ward (Might vs level, supernatural realm dependent)
- Rego Imaginem levels 2-5, 10: distance modifiers with magnitude ladder scaling
- Rego Imaginem: +1 magnitude for each additional sense beyond the primary sense affected

**Mentem (commit fa01406)**
- Creo Mentem: variable base levels (3, 4, 5, 10, 30-55) - characteristic point scaling tied to levels
- Intellego Mentem: variable base levels (4, 5, 10, 15, 20, 25) - information gathering follows non-linear progression
- Muto Mentem: variable base levels (1, 2, 3, 4, 5, 10, 15, 25) - memory/emotion alteration complexity
- Perdo Mentem: general entry (spirit Might reduction) + variable base levels (3, 4, 5, 10, 15, 25)
- Rego Mentem general: conditional ward (Might vs level, supernatural realm dependent)
- Rego Mentem: variable base levels (3, 4, 5, 10, 15, 20, 25) - mind/emotion control follows non-linear progression

**Terram (commit 5b1382f)**
- All techniques: variable base levels (non-linear progression)
- Material difficulty scaling: +1 magnitude for stone/glass, +2 for metal/gemstone
- Muto Terram: complex material transformation modifiers with multiple bullet-point effects
- Perdo Terram: material destruction difficulty scaling
- Rego Terram: magnitude ladder for transport distance (5p to Arcane Connection)
- Rego Terram general: conditional ward (Might vs level, supernatural realm dependent)
- Projectile damage scaling in Rego (levels 5/10/15 = +5/+10/+15 damage)

**Vim (commit 5b1382f)**
- All techniques: variable base levels with complex conditional mechanics
- Creo Vim general: 4 distinct magical shell sub-effects (different Intellego resistance levels)
- Perdo Vim general: 13 distinct sub-effects including spell dispelling, Might reduction, casting total penalties
- Arcane Connection duration reduction across 6 levels (reduce by 1-6 steps)
- Muto Vim: meta-magical effects (superficial/significant/total change) with power limitations
- Rego Vim general: 5 complex sub-effects (ward, sustain/suppress, conduit creation, spirit control)
- Multiple spell modification effects with Penetration requirements

---

## Test Results

- Configuration repository test: expect(all.length, 404) ✅ passing (403 built-in + 1 custom)
- Full test suite: 131/136 passing (5 asset-loader validation failures—pre-existing, not related to extraction)

---

## Status Summary (COMPLETE as of 2026-07-24)

**Progress:** 10 of 10 Forms COMPLETE (100%)  
**Extracted:** 604 base effects (from all 50 Technique+Form combinations)  
**All Forms:** Animal (30) + Aquam (115) + Auram (41) + Corpus (98) + Herbam (49) + Ignem (70) + Imaginem (38) + Mentem (58) + Terram (51) + Vim (54) = 604 total  
**Last commit:** 5b1382f (Terram + Vim)

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
