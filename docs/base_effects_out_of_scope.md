# Base Effects: Out-of-Scope Patterns for MVP

## Overview

During extraction of all 50 Ars Magica 5e Guideline sections, **~10 effects** were identified that don't fit the current `BaseEffect` model (base level + magnitude). These are documented here for future work.

The current model assumes:
- One base level per Technique+Form combination
- Guideline entries = discrete base levels
- Magnitude adjustments applied via Range/Duration/Target parameters

## Patterns That Don't Fit

### 1. Variable Base Level
**Count:** ~1–2 effects  
**Example:** Intellego Imaginem — "Sight of the True Form (Variable base)"

**Issue:** The base level depends on what the spell needs to see through. No fixed base level exists; the guideline text says "depends on target."

**Scope:** Cannot represent without a new `baseLevel` field type. Currently `baseLevel` is an integer.

**Affected Forms:**
- Intellego Imaginem (1 effect)

---

### 2. Complexity-Stacking Modifiers (Creo Imaginem pattern)
**Count:** ~5–7 effects  
**Example:**
- Base 1–5 senses, then "Increasing the complexity of a sensory perception...adds an additional level of magnitude"
- "Making an image move or make noise at your direction as you concentrate adds two levels of magnitude"

**Issue:** The base is simple (1–5 senses), but **additional factors add magnitudes on top**, not via the Range/Duration/Target system. The rulebook prose says modifiers add magnitudes, not that you use spell parameters to scale the base.

**Current model assumption:** base effect + (Range + Duration + Target adjustments) = final level

**Reality:** base effect + (Range + Duration + Target adjustments) + (Creo Imaginem complexity modifiers) = final level

**Scope:** Creo Imaginem's complexity modifiers are conceptually similar to parameters but documented differently in the rules. The calculation is transparent (add N magnitudes for each extra sense, +2 for directed movement), but the current UI doesn't expose "complexity" as a selectable parameter.

**Affected Forms:**
- Creo Imaginem (most effects at base levels 1–5)

---

### 3. Level-Dependent Scaling (Creo Aquam, Muto Aquam)
**Count:** ~3–5 effects  
**Example:**
- Creo Aquam general: "Create a corrosive substance doing +(Level) damage"
- Muto Aquam: "Each magnitude added to the level of the spell adds 3 to the Ease Factor"

**Issue:** The effect's **power scales with the spell's final level**, not a fixed amount. Damage = +[Spell Level]. Ease Factor increases by 3 per magnitude.

**Scope:** These are guidelines describing a scaling relationship, not a fixed effect. Cannot be represented as "base level X creates Y damage" — the damage *is* the level.

**Affected Forms:**
- Creo Aquam (general entry; affects poison creation)
- Muto Aquam (general entry; affects poison Ease Factor scaling)
- Creo Auram (notes on creating phenomena in unnatural fashions: "+1 magnitude," "+2 magnitudes," "+4 magnitudes")

---

### 4. Conditional Wards (Rego family — General entries)
**Count:** ~8 general entries (1 per Technique+Form ward)  
**Example:** Rego Corpus general — "Ward against creatures associated with Corpus from one realm (Divine, Faerie, Infernal, or Magic) with Might less than or equal to the level of the spell"

**Issue:** The effect's **power depends on the creature's Might vs. spell level** at runtime. Not a fixed effect at a fixed level; the guideline describes a conditional rule.

**Scope:** Current MVP treats base effects as static descriptions. Wards are static ("use this base effect at level 15, and it wards creatures with Might ≤ 15"). The description is accurate but doesn't capture the conditional nature — the spell *adapts* based on what it faces.

**Mitigation:** Current JSON includes these as-is with `"notes": "General entry; level depends on creature Might"`. Descriptively correct, but the UI can't expose "pick any level based on your defensive need."

**Affected Forms:**
- Rego Animal (general)
- Rego Aquam (general)
- Rego Auram (general)
- Rego Corpus (general)
- Rego Herbam (general)
- Rego Ignem (general)
- Rego Imaginem (general)
- Rego Mentem (general)
- Rego Terram (general)
- Rego Vim (general)

---

### 5. Magnitude-Ladder Modifiers (Rego transport distance)
**Count:** ~3–4 effects  
**Example:** Rego Animal level 10 — "Transport an animal instantly up to 5 paces (add 1 magnitude to increase the distance to 50 paces, 2 magnitudes for 500 paces, 3 magnitudes for 1 league, 4 magnitudes for seven leagues, and 5 magnitudes to a place for which you have an Arcane Connection)"

**Issue:** Distance is a **discrete magnitude ladder**, not continuous. Selecting "transport 500 paces" adds exactly 2 magnitudes; there's no in-between.

**Scope:** This *could* be represented as a parameter choice (e.g., "Distance: base 5 paces / 50 / 500 / 1 league / 7 leagues / Arcane Connection"), but it's not currently exposed in the UI. The current model treats this as a description-only note.

**Mitigation:** JSON includes these with description notes. The user can select parameters in the spell-creation UI, and the rulebook's magnitude ladder is transparent for manual calculation.

**Affected Forms:**
- Rego Animal (level 10)
- Rego Aquam (level 4)
- Rego Terram (level 4)
- Rego Ignem (level 3 transport, level 5–15 projectile damage ladder)

---

### 6. Ritual-Only Effects (Creo Corpus, Creo Aquam, etc.)
**Count:** ~5–10 effects  
**Example:** Creo Corpus healing — "Unless otherwise noted, a healing spell cast other than as a Momentary Duration Ritual actually suspends the healing process..."

**Issue:** The effect's **validity depends on Duration choice** (must be Momentary Ritual). No explicit guideline flag; noted in prose above the table.

**Scope:** Cannot be represented in the `BaseEffect` model alone. The effect is "valid" only under certain Duration conditions. The app doesn't validate Duration choices against effect prerequisites.

**Mitigation:** Descriptions are accurate but don't capture the constraint. Manual user discipline required: if you select a Creo Corpus healing effect with a non-Ritual Duration, the spell won't work per the rules.

**Affected Forms:**
- Creo Corpus (healing effects)
- Creo Animal (healing effects)
- Creo Aquam (water elemental creation — Ritual)
- Creo Auram (air elemental creation — Ritual)
- Creo Herbam (various effects — Ritual variants)
- Creo Ignem (fire elemental creation — Ritual)
- Creo Terram (precious metals, gemstones, earth elemental — Ritual)
- Creo Vim (several effects marked Ritual in spell examples)

---

## Recommendation for Future Work

### Immediate (before expanding to full 50 guidelines)
- ✅ Document effects in `base_effects_out_of_scope.md` (this file)
- ✅ Tag affected entries in JSON with `"notes"` field
- ✅ Test MVP with Animal+Aquam subset

### Short-term (Size feature + full 50 guidelines)
- Add `baseLevel: null` support for variable-base effects (e.g., Intellego Imaginem Sight of the True Form)
- Add `"ritualOnly": true` flag to `BaseEffect` model
- Add a `Duration` validator in the spell-creation flow that warns if a Ritual-only effect is selected with a non-Ritual Duration

### Medium-term (spell-editing phase, after MVP)
- Expose Creo Imaginem complexity as a selectable parameter
- Expose Rego transport-distance magnitude ladder as a parameter choice
- Add a `"conditionalLevel"` or `"conditional"` field for ward effects to document the Might vs. level dependency

### Long-term (post-MVP)
- Support level-dependent effects like Creo Aquam damage formula: `damage = Math.floor(spellLevel / 5)`
- Surface Ease Factor scaling (Muto Aquam poison formula)
- Create a "spell modifier" flow for effects that require special calculation

---

## Test Impact

Current extraction (Animal + Aquam) affects:
- **Creo Aquam general:** 1 effect (level-dependent damage)
- **Muto Aquam general:** 1 effect (level-dependent damage + Ease Factor scaling)
- **Perdo Aquam general:** 1 effect (level-dependent destruction)
- **Rego Aquam general:** 1 effect (conditional ward)

These are marked with `"notes"` in the JSON. Tests should pass; descriptions are accurate for manual reference.

Full expansion (50 guidelines) will add:
- **Rego general entries:** 8 more conditional wards (Animal, Auram, Corpus, Herbam, Ignem, Imaginem, Mentem, Terram, Vim)
- **Creo Imaginem:** ~5 effects with complexity-modifier documentation
- **Ritual-only effects:** ~10 effects across Creo Corpus, Animal, Aquam, Auram, Herbam, Ignem, Terram, Vim
- **Intellego Imaginem:** 1 variable-base effect (Sight of the True Form)
- **Rego transport ladders:** 3 more (Animal, Terram, plus Ignem projectile damage)

All documented in JSON descriptions; all testable as-is.

---

## Files Modified

- `assets/data/base_effects.json` — tagged out-of-scope effects with `"notes"`
- `docs/base_effects_out_of_scope.md` — this file (documentation only, no code impact)
