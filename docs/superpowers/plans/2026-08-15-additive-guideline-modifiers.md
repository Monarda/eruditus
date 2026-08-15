# Additive Guideline Modifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 7 new modifiers and one scope fix to `assets/data/modifiers.json` so a user designing a new spell can select rulebook-stated scaling rules (fire intensity, treated animal/plant products, live-wood destruction, precise air manipulation, extended transport distance) that currently have no representation in the catalog at all.

**Architecture:** Reuses the two modifier shapes item 28 already established — a multi-rung `selectionMode: single` ladder (mirrors `chill-damage`) for a repeating "+N per +M" formula, and a single-option binary rider (mirrors `single-property-transformation`) for a flat "+1 magnitude if condition" rule. Every new modifier is broadly scoped (`technique`/`form` set, `effectIds` empty) since none of these rules are pinned to one specific base-effect row. No `base_effects.json` changes, no importer changes — this plan touches only `assets/data/modifiers.json`, one Dart test file, and one Python test file.

**Tech Stack:** Dart/Flutter (`lib/`, `test/`), Python 3 (`scripts/spell_import/tests/`).

## Global Constraints

- No migration story needed (prototype stage, DB droppable — project convention).
- `assets/data/modifiers.json` is pretty-printed (2-space indent, one modifier per multi-line block, single-line compact `scope`/`options` sub-objects) — new entries must match that formatting exactly, not be minified. New entries are appended after the current last entry (`single-property-transformation`); its closing `}` on line 578 needs a trailing comma added when a new entry follows it.
- Every rulebook quote and line number used in code comments has already been verified fresh against `C:/Development/personal/Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md` during planning (all of the design spec's approximate line numbers were confirmed exactly correct) — use the verbatim wording given in each task step, not the design spec's paraphrases.
- **Correction to the design spec, found during planning:** the spec's Architecture section grouped Muto Herbam's treated-material rule with Creo Animal's as a "2-tier ladder." The verbatim rulebook text (line 14036) states only **one** tier ("add one magnitude" — no second, higher tier exists anywhere in that guideline). Muto Herbam is implemented here as a single-option binary rider (same shape as items 6-8), not a 2-tier ladder. Only Creo Animal genuinely has two named tiers.
- Perdo Auram's rule (line 13318) says "raises the magnitude by **at least** one level" — a floor, not a fixed cap. Implemented as a flat `+1` binary rider anyway, per the design spec's Architecture decision; the "at least" nuance is recorded in the modifier's `description` field so it isn't silently lost.
- The fire-intensity rules (Muto Ignem, Rego Ignem) are stated as unbounded in the rulebook (no cap given). Both are implemented with exactly 4 rungs, mirroring `chill-damage`'s existing rung count and rate (+5/+10/+15/+20 damage) exactly, since it's the same formula ("for every five points the damage exceeds +5, add one magnitude") already given that treatment for Perdo Ignem.
- Neither `rean-10b` nor `reaq-4b` (the two ids being added to `rego-transport-distance`'s scope) is referenced by any spell in `assets/data/spell_library.json` today — confirmed by direct grep during planning. The scope fix cannot change any existing spell's behavior.

---

## File Structure

| File | Responsibility |
|---|---|
| `assets/data/modifiers.json` | One scope-fix edit (`rego-transport-distance`); 7 new modifier entries appended at the end. |
| `test/engine/spell_engine_test.dart` | New test group, `'additive guideline modifiers'`, one test per new modifier confirming its level arithmetic. |
| `scripts/spell_import/tests/test_catalog.py` | One new test confirming the `rego-transport-distance` scope fix. |

---

### Task 1: Modifier catalog data and Dart engine tests

**Files:**
- Modify: `assets/data/modifiers.json`
- Test: `test/engine/spell_engine_test.dart`

**Interfaces:**
- Produces: 7 new modifier ids (`muto-ignem-fire-intensity`, `rego-ignem-fire-intensity`, `creo-animal-treated-product`, `muto-herbam-treated-material`, `perdo-herbam-live-wood`, `perdo-auram-precision`, `rego-auram-precision`) plus the widened `rego-transport-distance` scope (`effectIds` gains `rean-10b`, `reaq-4b`).
- Consumes: nothing from other tasks.

- [ ] **Step 1: Write failing `SpellEngine` tests for all 7 new modifiers**

Add to `test/engine/spell_engine_test.dart` a new group, inserted immediately after the existing `group('guideline level ladders (item 28)', () { ... });` closes (that group currently closes at line 360, right before `group('SpellEngine.pruneModifierSelections', ...)` at line 362 — insert the new group between them):

```dart
  group('additive guideline modifiers', () {
    test('the Muto Ignem fire-intensity ladder reaches level 20 at +20 damage', () {
      final fireIntensity = Modifier(
        id: 'muto-ignem-fire-intensity',
        name: 'Fire Intensity',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Muto', form: 'Ignem', effectIds: []),
        options: [
          ModifierOption(id: 'muto-ignem-fire-intensity-5', label: '+5 damage', magnitude: 0),
          ModifierOption(id: 'muto-ignem-fire-intensity-10', label: '+10 damage', magnitude: 1),
          ModifierOption(id: 'muto-ignem-fire-intensity-15', label: '+15 damage', magnitude: 2),
          ModifierOption(id: 'muto-ignem-fire-intensity-20', label: '+20 damage', magnitude: 3),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [fireIntensity]);
      final baseEffect = BaseEffect(
        id: 'muig-test', technique: 'Muto', form: 'Ignem',
        description: 'Change the intensity of an existing fire',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'muto-ignem-fire-intensity': ['muto-ignem-fire-intensity-20']},
        requisites: const {},
      );

      expect(breakdown.level, 20);
    });

    test('the Rego Ignem fire-intensity ladder reaches level 20 at +20 damage', () {
      final fireIntensity = Modifier(
        id: 'rego-ignem-fire-intensity',
        name: 'Fire Intensity',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Rego', form: 'Ignem', effectIds: []),
        options: [
          ModifierOption(id: 'rego-ignem-fire-intensity-5', label: '+5 damage', magnitude: 0),
          ModifierOption(id: 'rego-ignem-fire-intensity-10', label: '+10 damage', magnitude: 1),
          ModifierOption(id: 'rego-ignem-fire-intensity-15', label: '+15 damage', magnitude: 2),
          ModifierOption(id: 'rego-ignem-fire-intensity-20', label: '+20 damage', magnitude: 3),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [fireIntensity]);
      final baseEffect = BaseEffect(
        id: 'reig-test', technique: 'Rego', form: 'Ignem',
        description: 'Control the intensity of an existing fire',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'rego-ignem-fire-intensity': ['rego-ignem-fire-intensity-20']},
        requisites: const {},
      );

      expect(breakdown.level, 20);
    });

    test('the Creo Animal treated-product modifier adds 2 magnitudes for "treated and processed"', () {
      final treatedProduct = Modifier(
        id: 'creo-animal-treated-product',
        name: 'Treated Animal Product',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Creo', form: 'Animal', effectIds: []),
        options: [
          ModifierOption(id: 'creo-animal-treated-product-treated', label: 'Treated (e.g. leather, cloth)', magnitude: 1),
          ModifierOption(id: 'creo-animal-treated-product-processed', label: 'Treated and processed (e.g. a leather jacket)', magnitude: 2),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [treatedProduct]);
      final baseEffect = BaseEffect(
        id: 'cran-test', technique: 'Creo', form: 'Animal',
        description: 'Create a dead animal product',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {
          'creo-animal-treated-product': ['creo-animal-treated-product-processed']
        },
        requisites: const {},
      );

      expect(breakdown.level, 15);
    });

    test('the Muto Herbam treated-material modifier adds one magnitude', () {
      final treatedMaterial = Modifier(
        id: 'muto-herbam-treated-material',
        name: 'Treated Material',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Muto', form: 'Herbam', effectIds: []),
        options: [
          ModifierOption(id: 'muto-herbam-treated-material-yes', label: 'Treated or finished material', magnitude: 1),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [treatedMaterial]);
      final baseEffect = BaseEffect(
        id: 'muhe-test', technique: 'Muto', form: 'Herbam',
        description: 'Change a plant into an unworked, natural plant',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {
          'muto-herbam-treated-material': ['muto-herbam-treated-material-yes']
        },
        requisites: const {},
      );

      expect(breakdown.level, 10);
    });

    test('the Perdo Herbam live-wood modifier adds one magnitude', () {
      final liveWood = Modifier(
        id: 'perdo-herbam-live-wood',
        name: 'Live Wood',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Perdo', form: 'Herbam', effectIds: []),
        options: [
          ModifierOption(id: 'perdo-herbam-live-wood-yes', label: 'Destroys live wood', magnitude: 1),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [liveWood]);
      final baseEffect = BaseEffect(
        id: 'pehe-test', technique: 'Perdo', form: 'Herbam',
        description: 'Destroy an amount of dead wood',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'perdo-herbam-live-wood': ['perdo-herbam-live-wood-yes']},
        requisites: const {},
      );

      expect(breakdown.level, 10);
    });

    test('the Perdo Auram precision modifier adds one magnitude', () {
      final precision = Modifier(
        id: 'perdo-auram-precision',
        name: 'Precise Destruction',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Perdo', form: 'Auram', effectIds: []),
        options: [
          ModifierOption(id: 'perdo-auram-precision-yes', label: 'Destroys air with great precision', magnitude: 1),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [precision]);
      final baseEffect = BaseEffect(
        id: 'peau-test', technique: 'Perdo', form: 'Auram',
        description: 'Destroy an amount of air',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'perdo-auram-precision': ['perdo-auram-precision-yes']},
        requisites: const {},
      );

      expect(breakdown.level, 10);
    });

    test('the Rego Auram precision modifier adds one magnitude', () {
      final precision = Modifier(
        id: 'rego-auram-precision',
        name: 'Precise Control',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Rego', form: 'Auram', effectIds: []),
        options: [
          ModifierOption(id: 'rego-auram-precision-yes', label: 'Controls air with great strength or precision', magnitude: 1),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [precision]);
      final baseEffect = BaseEffect(
        id: 'reau-test', technique: 'Rego', form: 'Auram',
        description: 'Control an amount of air',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'rego-auram-precision': ['rego-auram-precision-yes']},
        requisites: const {},
      );

      expect(breakdown.level, 10);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: all 7 new tests FAIL (the modifiers they construct are synthetic in-memory objects, not loaded from the catalog, so the failure is NOT about missing catalog data — read the actual failure output. If a test fails for a reason other than an assertion mismatch on `breakdown.level`, e.g. a compile error, fix that first before proceeding; the arithmetic itself should already be correct since these tests build their own `Modifier`/`BaseEffect` fixtures exactly like the existing `chill-damage`/`single-property-transformation` tests already do — so a real failure here most likely means a typo in the test code, not a design problem).

- [ ] **Step 3: Add the 7 modifiers to the catalog and fix the scope hole**

First, read `assets/data/modifiers.json`'s exact current lines 478–493 (the `rego-transport-distance` entry) and lines 567–579 (the `single-property-transformation` entry and closing `]`) to confirm they still match what's below — the file may have changed since planning.

Edit line 482 (inside the `rego-transport-distance` entry) from:
```json
    "scope": { "technique": null, "form": null, "effectIds": ["rehe-10b", "reig-3c", "rete-4"], "excludeTechniques": [] },
```
to:
```json
    "scope": { "technique": null, "form": null, "effectIds": ["rehe-10b", "reig-3c", "rete-4", "rean-10b", "reaq-4b"], "excludeTechniques": [] },
```

Then, add a trailing comma to the `single-property-transformation` entry's closing `}` (currently the last entry in the file, with no trailing comma), and append these 7 entries immediately after it, before the file's closing `]`:

```json
  {
    "id": "muto-ignem-fire-intensity",
    "name": "Fire Intensity",
    "description": "Every 5 points the fire's damage exceeds +5 adds one magnitude",
    "selectionMode": "single",
    "scope": { "technique": "Muto", "form": "Ignem", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "muto-ignem-fire-intensity-5", "label": "+5 damage", "magnitude": 0 },
      { "id": "muto-ignem-fire-intensity-10", "label": "+10 damage", "magnitude": 1 },
      { "id": "muto-ignem-fire-intensity-15", "label": "+15 damage", "magnitude": 2 },
      { "id": "muto-ignem-fire-intensity-20", "label": "+20 damage", "magnitude": 3 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
  {
    "id": "rego-ignem-fire-intensity",
    "name": "Fire Intensity",
    "description": "Every 5 points the fire's damage exceeds +5 adds one magnitude",
    "selectionMode": "single",
    "scope": { "technique": "Rego", "form": "Ignem", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "rego-ignem-fire-intensity-5", "label": "+5 damage", "magnitude": 0 },
      { "id": "rego-ignem-fire-intensity-10", "label": "+10 damage", "magnitude": 1 },
      { "id": "rego-ignem-fire-intensity-15", "label": "+15 damage", "magnitude": 2 },
      { "id": "rego-ignem-fire-intensity-20", "label": "+20 damage", "magnitude": 3 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
  {
    "id": "creo-animal-treated-product",
    "name": "Treated Animal Product",
    "description": "Creating a treated, or treated and processed, animal product adds magnitudes",
    "selectionMode": "single",
    "scope": { "technique": "Creo", "form": "Animal", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "creo-animal-treated-product-treated", "label": "Treated (e.g. leather, cloth)", "magnitude": 1 },
      { "id": "creo-animal-treated-product-processed", "label": "Treated and processed (e.g. a leather jacket)", "magnitude": 2 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
  {
    "id": "muto-herbam-treated-material",
    "name": "Treated Material",
    "description": "Changing a plant into treated or finished material adds one magnitude",
    "selectionMode": "single",
    "scope": { "technique": "Muto", "form": "Herbam", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "muto-herbam-treated-material-yes", "label": "Treated or finished material", "magnitude": 1 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
  {
    "id": "perdo-herbam-live-wood",
    "name": "Live Wood",
    "description": "Destroying live wood instead of dead wood adds one magnitude",
    "selectionMode": "single",
    "scope": { "technique": "Perdo", "form": "Herbam", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "perdo-herbam-live-wood-yes", "label": "Destroys live wood", "magnitude": 1 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
  {
    "id": "perdo-auram-precision",
    "name": "Precise Destruction",
    "description": "Destroying air with great precision raises the magnitude by at least one level",
    "selectionMode": "single",
    "scope": { "technique": "Perdo", "form": "Auram", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "perdo-auram-precision-yes", "label": "Destroys air with great precision", "magnitude": 1 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
  {
    "id": "rego-auram-precision",
    "name": "Precise Control",
    "description": "Controlling air with great strength or precision raises the magnitude by one level",
    "selectionMode": "single",
    "scope": { "technique": "Rego", "form": "Auram", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "rego-auram-precision-yes", "label": "Controls air with great strength or precision", "magnitude": 1 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  }
```

Verify `git diff --stat assets/data/modifiers.json` afterward shows roughly 85 inserted lines (the 7 new entries) and 2 changed lines (the scope edit, and the trailing comma added to `single-property-transformation`'s closing `}`) — nothing close to the file's full 578-line count. If it looks like the whole file was reformatted, revert (`git checkout -- assets/data/modifiers.json`) and redo as pure text edits.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: PASS (all 7 new tests, plus the pre-existing ones in the file)

- [ ] **Step 5: Run the full Dart suite and `flutter analyze`**

Run: `flutter test`
Run: `flutter analyze`
Expected: both clean — `flutter test` all passing, `flutter analyze` "No issues found."

- [ ] **Step 6: Commit**

```bash
git add assets/data/modifiers.json test/engine/spell_engine_test.dart
git commit -m "feat: add 7 additive guideline modifiers, widen rego-transport-distance scope"
```

---

### Task 2: Python verification of the scope fix

**Files:**
- Test: `scripts/spell_import/tests/test_catalog.py`

**Interfaces:**
- Consumes: the widened `rego-transport-distance` scope from Task 1.

- [ ] **Step 1: Write a failing test confirming the widened scope**

Read `scripts/spell_import/tests/test_catalog.py`'s existing ladder tests first
(search for `test_crvi_ladder_is_collapsed_to_one_row` — it and
`test_peig_ladder_is_collapsed_to_one_row` are the last two methods in the
`CandidatesTest` class, right before `class ExistingIdsTest` begins) to match
its exact style — the file imports the module as `from scripts.spell_import
import catalog` (not `catalog_module`), and each test calls
`catalog.Catalog.load()` fresh. Add this as a third method in that same
`CandidatesTest` class, immediately after `test_peig_ladder_is_collapsed_to_one_row`:

```python
    def test_rego_transport_distance_scope_covers_all_five_forms(self):
        catalog_inst = catalog.Catalog.load()
        modifier = next(
            m for m in catalog_inst.modifiers if m["id"] == "rego-transport-distance"
        )
        self.assertEqual(
            set(modifier["scope"]["effectIds"]),
            {"rehe-10b", "reig-3c", "rete-4", "rean-10b", "reaq-4b"},
        )
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python -m unittest scripts.spell_import.tests.test_catalog.CandidatesTest.test_rego_transport_distance_scope_covers_all_five_forms -v`
Expected: FAIL — the scope only has 3 ids until Task 1's edit lands (this test should already pass once Task 1 is merged; run it now to confirm it would have caught the gap before Task 1 existed, then move on).

- [ ] **Step 3: Run the test to verify it passes**

Run: `python -m unittest scripts.spell_import.tests.test_catalog.CandidatesTest.test_rego_transport_distance_scope_covers_all_five_forms -v`
Expected: PASS (Task 1 already landed the scope fix, so this should pass immediately)

- [ ] **Step 4: Run the full Python suite**

Run: `ARS_RULEBOOK_ROOT=<path to the sibling rulebook checkout, if running from a nested worktree> python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`
Expected: PASS — no other test should be affected, since this task only widens a modifier's scope and no importer/extraction code path reads `modifiers.json` at all today.

- [ ] **Step 5: Commit**

```bash
git add scripts/spell_import/tests/test_catalog.py
git commit -m "test: verify rego-transport-distance's widened scope"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1 covers all 8 scope items (the transport-distance fix plus 7 new modifiers) and both modifier shapes from the spec's Architecture section. Task 2 covers the spec's Testing section requirement for a scope-fix verification test. The spec's "What this does not do" section (row-duplication refactors, Ease Factor display, exhaustive prose scan) has no corresponding task, as intended — those are explicitly out of scope.
- **Correction made during planning:** the spec's Architecture section described Muto Herbam as a 2-tier ladder alongside Creo Animal; grounding against the verbatim rulebook text found only one tier exists for Muto Herbam. Implemented as a binary rider instead, recorded in Global Constraints above.
- **Type consistency:** every modifier id used in Task 1's JSON matches the id used in that same task's Dart tests exactly (no cross-task drift possible — both live in Task 1). Task 2 references `rego-transport-distance` and its exact final `effectIds` set, matching Task 1's Step 3 edit verbatim.
- **No placeholders:** every step carries complete, real code — all 7 modifier JSON entries, all 7 Dart tests, and the Python test are written in full, not summarized or referenced as "similar to."
