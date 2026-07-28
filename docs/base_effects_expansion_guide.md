# Base Effects Full Expansion Guide (Auram–Vim)

## Overview

This guide documents the procedure to complete the base effects extraction from all 50 Ars Magica 5e Guideline sections. **Animal and Aquam are complete** (commit `8ca3c9c`, 145 effects). **Remaining work: 8 Forms (Auram–Vim).**

Estimated effort: ~2–3 hours to extract all remaining guidelines manually, or can be automated with a Dart script.

---

## Remaining Forms to Extract

| Form | Technique Count | Approx Effects | Notes |
|------|-----------------|-----------------|-------|
| **Auram** | 5 (Creo, Intellego, Muto, Perdo, Rego) | ~35 | Weather, air, wind; includes general ward |
| **Corpus** | 5 | ~35 | Healing, disease, characteristics, aging; ritualistic healing notes |
| **Herbam** | 5 | ~30 | Plant creation, control, destruction; wood/plant products |
| **Ignem** | 5 | ~35 | Fire, light, heat; includes intensity modifiers |
| **Imaginem** | 5 | ~30 | Illusions, sensory manipulation; ⚠️ complexity modifiers |
| **Mentem** | 5 | ~30 | Emotions, memory, mind control; includes requisites |
| **Terram** | 5 | ~30 | Earth, stone, metal; includes material-type modifiers |
| **Vim** | 5 | ~25 | Magic detection, dispel, summon; ⚠️ conditional effects |
| **TOTAL** | 40 | ~250 | **~395 total when complete** |

---

## Extraction Procedure (Manual)

### Step 1: Read Guidelines Section from Rulebook

For each Technique+Form (e.g., Creo Auram):

1. Open the rulebook at the Guidelines section (see offsets below)
2. Read the level table (e.g., levels 1, 2, 3, 5, 10, 15, 20, 25, etc.)
3. For each level, create one JSON entry per bullet point

### Step 2: Generate JSON Entries

Template for each effect:

```json
{
  "id": "[technique-abbr][form-abbr]-[level][letter]",
  "technique": "[Technique Name]",
  "form": "[Form Name]",
  "description": "[Guideline text]",
  "baseLevel": [level],
  "source": "built-in"
}
```

**ID scheme:**
- Creo Auram, level 1, first effect → `crau-1` (no letter)
- Creo Auram, level 1, second effect → `crau-1b` (add letter suffix)
- Intellego Auram, level 15 → `inau-15`
- etc.

### Step 3: Flag Out-of-Scope Effects

Before committing, check each effect against patterns in `docs/base_effects_out_of_scope.md`:

- **Variable base** → add `"notes": "Variable base; see out_of_scope.md"`
- **Level-dependent damage** (e.g., "damage +(Level)") → add `"notes": "level-dependent damage"`
- **Complexity modifiers** (Creo Imaginem) → add `"notes": "Complexity modifiers may apply per spell prose"`
- **Ritual-only** → add to description if rulebook marks it
- **Conditional wards** (Rego general) → add `"notes": "General entry; level depends on creature Might"`

### Step 4: Run Tests & Update Counts

After adding each Form's ~30–35 effects:

1. Run `flutter test test/data/repositories/configuration_repository_test.dart`
2. Update the expected counts in that test:
   - `expect(all.length, XXX)` where XXX = total built-in + 1 custom
   - Second test expects XXX - 1 (just built-in)

3. Run full suite: `flutter test -r compact`
4. Verify `flutter analyze` shows no new issues

---

## Rulebook Offsets (for Read Tool)

Use these offsets when reading the rulebook MD file to locate each Guidelines section:

```
Creo Auram:       offset 13112, limit 70
Intellego Auram:  offset 13226, limit 40
Muto Auram:       offset 13263, limit 50
Perdo Auram:      offset 13316, limit 35
Rego Auram:       offset 13352, limit 60

Creo Corpus:      offset 13413, limit 70
Intellego Corpus: offset 13520, limit 60
Muto Corpus:      offset 13579, limit 60
Perdo Corpus:     offset 13715, limit 65
Rego Corpus:      offset 13810, limit 60

Creo Herbam:      offset 13919, limit 60
Intellego Herbam: offset 13985, limit 45
Muto Herbam:      offset 14034, limit 60
Perdo Herbam:     offset 14099, limit 50
Rego Herbam:      offset 14149, limit 80

Creo Ignem:       offset 14253, limit 70
Intellego Ignem:  offset 14343, limit 45
Muto Ignem:       offset 14391, limit 50
Perdo Ignem:      offset 14450, limit 60
Rego Ignem:       offset 14512, limit 70

Creo Imaginem:    offset 14583, limit 80 ⚠️ complexity modifiers
Intellego Imaginem: offset 14646, limit 65
Muto Imaginem:    offset 14705, limit 45
Perdo Imaginem:   offset 14756, limit 65
Rego Imaginem:    offset 14828, limit 65

Creo Mentem:      offset 14902, limit 65
Intellego Mentem: offset 14970, limit 60
Muto Mentem:      offset 15033, limit 60
Perdo Mentem:     offset 15096, limit 65
Rego Mentem:      offset 15175, limit 70

Creo Terram:      offset 15287, limit 40
Intellego Terram: offset 15331, limit 70
Muto Terram:      offset 15409, limit 60
Perdo Terram:     offset 15473, limit 60
Rego Terram:      offset 15534, limit 70

Creo Vim:         offset 15665, limit 45
Intellego Vim:    offset 15713, limit 75
Muto Vim:         offset 15789, limit 75
Perdo Vim:        offset 15873, limit 40
Rego Vim:         offset 15916, limit 60
```

**Source:** `C:\Users\idf53\Development\personal\arsm\Ars-Magica-Open-License\reviewed\Ars Magica - Definitive Edition (Core Rules).md`

---

## Automated Extraction Option

Instead of manual extraction, you can write a Dart script to:

1. Parse the rulebook MD file (regex or regex-based table extraction)
2. Extract each Guidelines table automatically
3. Generate JSON entries with proper ID scheme
4. Flag out-of-scope patterns with notes
5. Append to `assets/data/base_effects.json`
6. Validate against existing entries to avoid duplicates

**Estimated effort:** ~1 hour to write + debug the script, saves ~1.5 hours on manual work.

**Script location:** Could live at `scripts/extract_base_effects.dart`

---

## Commit Strategy

Recommend committing by Form to ease review and testing:

1. `feat: add Auram base effects (35 effects)` — test + commit
2. `feat: add Corpus base effects (35 effects)` — test + commit
3. `feat: add Herbam base effects (30 effects)` — test + commit
4. `feat: add Ignem base effects (35 effects)` — test + commit
5. `feat: add Imaginem base effects (30 effects, ⚠️ complexity notes)` — test + commit
6. `feat: add Mentem base effects (30 effects)` — test + commit
7. `feat: add Terram base effects (30 effects)` — test + commit
8. `feat: add Vim base effects (25 effects)` — test + commit

Alternatively, one large commit: `feat: complete base_effects.json with all 50 Guidelines (395 total effects)`

---

## Testing Checklist Per Form

After adding each Form (or the full set):

- [ ] `flutter test test/data/repositories/configuration_repository_test.dart` passes (effect count updated)
- [ ] `flutter test -r compact` shows all 136+ tests passing
- [ ] `flutter analyze` shows no new warnings
- [ ] No duplicate IDs in JSON (use `jq` to check: `jq -r '.[].id' assets/data/base_effects.json | sort | uniq -d`)
- [ ] Spot-check 3–5 entries against the rulebook to verify accuracy

---

## Known Issues & Flags

### Creo Imaginem (Complexity Modifiers)
The rulebook prose says: "Increasing the complexity of a sensory perception...adds an additional level of magnitude."
These are tricky to model in the current `BaseEffect` structure. Each effect is documented, but the UI doesn't yet expose "complexity" as a selectable parameter.

**Action:** Tag with `"notes": "Complexity modifiers per spell prose (see out_of_scope.md)"`

### Vim Conditional Effects
Many Vim entries describe conditional or level-dependent behavior (e.g., "ward creatures with Might ≤ spell level").
The effect is correct as written; just flag it for awareness.

**Action:** Tag with `"notes": "Conditional effect; see out_of_scope.md"`

### Ritual-Only Effects
Several Creo and other Techniques have effects that only work if cast as a Ritual.
Currently noted in descriptions but not enforced by the model.

**Action:** Add `"ritualOnly": true` flag to model (future work) or document in description.

---

## Final Validation

Once all 50 Forms are done:

1. Total count: `jq 'length' assets/data/base_effects.json` should return ~395
2. Run all tests: `flutter test` (should pass 136+)
3. Compare against rulebook spot-check (pick 10 random effects, verify against source)
4. Review `docs/base_effects_out_of_scope.md` to ensure flags are accurate
5. Final commit message should note: "Complete extraction of all 50 Ars Magica 5e Guidelines (50 Technique+Form combinations)"

---

## Next Step

**Choose one:**

1. **Manual extraction** — read this guide, follow the offsets, extract by Form, commit incrementally
2. **Automated extraction** — write a Dart script to parse the rulebook and generate JSON automatically
3. **Hybrid** — script handles the parsing; you review and commit by Form

Recommend **automated script** if you're comfortable with Dart; otherwise, **manual extraction by Form** is straightforward and gives you direct familiarity with all 50 Guidelines.
