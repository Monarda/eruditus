# Guideline Level Derivation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unblock 4 of item 28's 5 spells (`The Enigma's Gift`, `Wizard's Icy Grip`, `Fog of Confusion`, `Infernal Smoke of Death`) by modeling their guidelines' own stated rules as modifier ladders and a hand-verified importer-resolution table; give the 5th (`Sense of the Lingering Magic`) a blocked reason that reflects investigation instead of silence.

**Architecture:** Two independent catalog changes (Creo Vim's Warping Point ladder, Perdo Ignem's chill-damage ladder — both collapsing existing numbered rows into a base effect + a `size-*`-style modifier ladder) plus one new broadly-scoped modifier (Muto Auram's single-property discount), then one shared importer-resolution table (`NUMBERED_OVERRIDES`) that routes exactly 4 named spells to `build_spell` with an explicit base effect, an optional General-guideline level, and optional modifier selections — mirroring `HAND_DERIVED`/`HAND_DERIVED_ADJUSTMENT`'s existing hand-verified-table precedent in the same file.

**Tech Stack:** Dart/Flutter (`lib/`, `test/`), Python 3 (`scripts/spell_import/`, `scripts/spell_import/tests/`).

## Global Constraints

- No migration story needed (prototype stage, DB droppable — project convention).
- `assets/data/base_effects.json` edits must be surgical single-line edits/deletions, preserving the file's existing one-line-per-entry format exactly — read each target line's exact current text before editing it, never `json.load`/`json.dump` the whole file (a prior task in the open-guideline-slots work made exactly this mistake and it was caught and reverted before review).
- `assets/data/modifiers.json` is pretty-printed (2-space indent, one modifier per multi-line block) — new entries should match that formatting, not be minified.
- Every corpus id/slug used in code must be verified against the real files during implementation, not assumed from this plan's text — this plan's own research already found and corrected one such assumption (the resolution mechanism itself) after checking the real `extract_spells.py` control flow.
- `build_spell`'s two new parameters (`chosen_base_level`, `override_modifiers`) must be optional and defaulted — every pre-existing call site and test in `test_emit.py` must keep compiling and passing unchanged, the same lesson the open-guideline-slots Part A/B plans already learned about `realm_by_spell_id`.
- Zero corpus spells currently reference any of the 5 catalog rows this plan deletes or repurposes (`crvi-10a`, `crvi-15a`, `peig-10b`, and the descriptions of `crvi-5a`/`peig-5b`) — verified directly against `spell_library.json`/`spell_templates.json` during design. If re-verification during implementation finds this is no longer true, stop and report rather than proceeding.
- `source.lock`'s pinned rulebook revision is unchanged — asset regeneration uses `--write` alone, never `--accept-source`.
- A negative-magnitude modifier option needs no new safety code — `SpellEngine.calculateBreakdown` already throws when the total level drops below 1, regardless of contribution source (verified by reading `spell_engine.dart` directly during design, not assumed).

---

## File Structure

| File | Responsibility |
|---|---|
| `assets/data/base_effects.json` | `crvi-5a`/`peig-5b` descriptions generalized; `crvi-10a`, `crvi-15a`, `peig-10b` deleted. |
| `assets/data/modifiers.json` | 3 new modifiers: `warping-point-burst`, `chill-damage`, `single-property-transformation`. |
| `scripts/spell_import/extract_spells.py` | `NUMBERED_OVERRIDES` table; the numbered-resolution path checks it before blocking; `Sense of the Lingering Magic`'s blocked reason updated. |
| `scripts/spell_import/emit.py` | `build_spell` gains `chosen_base_level`/`override_modifiers` optional parameters. |
| `assets/data/spell_library.json` | Regenerated: 4 more spells imported. |
| Every affected test file | New/updated tests per task. |

---

### Task 1: Catalog ladders and the discount modifier

**Files:**
- Modify: `assets/data/base_effects.json`
- Modify: `assets/data/modifiers.json`
- Test: `test/engine/spell_engine_test.dart`

**Interfaces:**
- Produces: `crvi-5a` (`baseLevel: 5`, generalized description), modifier `warping-point-burst` (options `warping-point-burst-1..4`, magnitudes 0-3, scoped to `effectIds: ["crvi-5a"]`); `peig-5b` (`baseLevel: 5`, generalized description), modifier `chill-damage` (options `chill-damage-5/10/15/20`, magnitudes 0-3, scoped to `effectIds: ["peig-5b"]`); modifier `single-property-transformation` (one option, magnitude -1, scoped to `technique: "Muto", form: "Auram"`, no `effectIds`).
- Consumes: nothing from other tasks.

- [ ] **Step 1: Write failing `SpellEngine` tests for both ladders and the discount**

Add to `test/engine/spell_engine_test.dart`, in a new group near the existing Terram-material modifier tests (search for `'a multi-select modifier with several options chosen is valid'` to find the right neighborhood):

```dart
  group('guideline level ladders (item 28)', () {
    test('the Warping Point ladder reaches level 20 at its 4th rung', () {
      final warping = Modifier(
        id: 'warping-point-burst',
        name: 'Warping Points',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Creo', form: 'Vim', effectIds: ['crvi-5a']),
        options: [
          ModifierOption(id: 'warping-point-burst-1', label: 'One Warping Point', magnitude: 0),
          ModifierOption(id: 'warping-point-burst-2', label: 'Two Warping Points', magnitude: 1),
          ModifierOption(id: 'warping-point-burst-3', label: 'Three Warping Points', magnitude: 2),
          ModifierOption(id: 'warping-point-burst-4', label: 'Four Warping Points', magnitude: 3),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [warping]);
      final baseEffect = BaseEffect(
        id: 'crvi-5a', technique: 'Creo', form: 'Vim',
        description: 'Create a burst of magic that gives the target Warping Points',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'warping-point-burst': ['warping-point-burst-4']},
        requisites: const {},
      );

      expect(breakdown.level, 20);
    });

    test('the chill-damage ladder reaches level 20 at +20 damage', () {
      final chill = Modifier(
        id: 'chill-damage',
        name: 'Chill Damage',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Perdo', form: 'Ignem', effectIds: ['peig-5b']),
        options: [
          ModifierOption(id: 'chill-damage-5', label: '+5 damage', magnitude: 0),
          ModifierOption(id: 'chill-damage-10', label: '+10 damage', magnitude: 1),
          ModifierOption(id: 'chill-damage-15', label: '+15 damage', magnitude: 2),
          ModifierOption(id: 'chill-damage-20', label: '+20 damage', magnitude: 3),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [chill]);
      final baseEffect = BaseEffect(
        id: 'peig-5b', technique: 'Perdo', form: 'Ignem',
        description: 'Chill a person, taking damage that scales with the spell\'s level',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {'chill-damage': ['chill-damage-20']},
        requisites: const {},
      );

      expect(breakdown.level, 20);
    });

    test('the single-property discount lowers level by one magnitude below the additive tier', () {
      final discount = Modifier(
        id: 'single-property-transformation',
        name: 'Single Property',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Muto', form: 'Auram'),
        options: [
          ModifierOption(
              id: 'single-property-transformation-yes',
              label: 'Transforms only one property', magnitude: -1),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [discount]);
      final baseEffect = BaseEffect(
        id: 'muau-3', technique: 'Muto', form: 'Auram',
        description: 'Transform an amount of air into another form of air',
        baseLevel: 3,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {
          'single-property-transformation': ['single-property-transformation-yes']
        },
        requisites: const {},
      );

      expect(breakdown.level, 2);
    });

    test('a negative-magnitude modifier that drives the level below 1 throws, same as any other contribution', () {
      final discount = Modifier(
        id: 'single-property-transformation',
        name: 'Single Property',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Muto', form: 'Auram'),
        options: [
          ModifierOption(
              id: 'single-property-transformation-yes',
              label: 'Transforms only one property', magnitude: -1),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final engine = SpellEngine(allSpells: [], allModifiers: [discount]);
      final baseEffect = BaseEffect(
        id: 'muau-test-1', technique: 'Muto', form: 'Auram',
        description: 'Test effect at the floor', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      expect(
        () => engine.calculateBreakdown(
          baseEffect: baseEffect,
          range: _range, duration: _duration, target: _target,
          selectedModifiers: const {
            'single-property-transformation': ['single-property-transformation-yes']
          },
          requisites: const {},
        ),
        throwsArgumentError,
      );
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — `crvi-5a`'s description doesn't match yet (cosmetic, will pass once Step 3 lands) and the modifiers referenced don't exist in the *catalog* yet, though these particular tests construct their own synthetic `Modifier`/`BaseEffect` fixtures rather than loading the real catalog, so they should actually already pass once Step 3's arithmetic is correct — the point of this step is confirming they fail for the *expected* reason (the base effect's own description text doesn't match what Step 3 will write) before Step 3, not that the calculation itself is wrong. Read the actual failure output and confirm it's the description mismatch, not a magnitude/level mismatch, before proceeding.

- [ ] **Step 3: Refactor the catalog data**

In `assets/data/base_effects.json`, first read the exact current lines for `crvi-5a`, `crvi-10a`, `crvi-15a`, `peig-5b`, `peig-10b` (do not assume their content — read the file). Then:

- Change `crvi-5a`'s `"description"` value from `"Create burst of magic giving target one Warping Point"` to `"Create a burst of magic that gives the target Warping Points"` — a single-line edit, touching no other field on that line.
- Delete the `crvi-10a` and `crvi-15a` lines entirely.
- Change `peig-5b`'s `"description"` value from `"Chill a person so that they take +5 damage"` to `"Chill a person, taking damage that scales with the spell's level"` — a single-line edit.
- Delete the `peig-10b` line entirely.

Verify `git diff --stat assets/data/base_effects.json` afterward shows exactly 5 changed lines (2 edited, 3 deleted) — if it shows anywhere near the file's full line count, you have accidentally reformatted the file; revert (`git checkout -- assets/data/base_effects.json`) and redo as pure text edits.

In `assets/data/modifiers.json`, add three new entries (this file is pretty-printed — match its existing 2-space-indent style, not a single line):

```json
  {
    "id": "warping-point-burst",
    "name": "Warping Points",
    "description": "Each magnitude gives the target one more Warping Point",
    "selectionMode": "single",
    "scope": { "technique": "Creo", "form": "Vim", "effectIds": ["crvi-5a"], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "warping-point-burst-1", "label": "One Warping Point", "magnitude": 0 },
      { "id": "warping-point-burst-2", "label": "Two Warping Points", "magnitude": 1 },
      { "id": "warping-point-burst-3", "label": "Three Warping Points", "magnitude": 2 },
      { "id": "warping-point-burst-4", "label": "Four Warping Points", "magnitude": 3 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
  {
    "id": "chill-damage",
    "name": "Chill Damage",
    "description": "Every 5 points the damage exceeds +5 adds one magnitude",
    "selectionMode": "single",
    "scope": { "technique": "Perdo", "form": "Ignem", "effectIds": ["peig-5b"], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "chill-damage-5", "label": "+5 damage", "magnitude": 0 },
      { "id": "chill-damage-10", "label": "+10 damage", "magnitude": 1 },
      { "id": "chill-damage-15", "label": "+15 damage", "magnitude": 2 },
      { "id": "chill-damage-20", "label": "+20 damage", "magnitude": 3 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
  {
    "id": "single-property-transformation",
    "name": "Single Property",
    "description": "Transforming only one property of air lowers the level by one magnitude",
    "selectionMode": "single",
    "scope": { "technique": "Muto", "form": "Auram", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "single-property-transformation-yes", "label": "Transforms only one property", "magnitude": -1 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  }
```

Read an existing modifier entry's exact field order/structure first (e.g. `size-animal`) and match it precisely — this repo's existing modifiers all include `excludeTechniques` in `scope` even when empty, so include it too, rather than omitting the key.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: PASS

- [ ] **Step 5: Write and run a Python catalog test confirming the deletions and edits**

Add to `scripts/spell_import/tests/test_catalog.py`, alongside the existing `open_slots` tests:

```python
    def test_crvi_ladder_is_collapsed_to_one_row(self):
        catalog = catalog_module.Catalog.load()
        ids = {e["id"] for e in catalog.base_effects}
        self.assertIn("crvi-5a", ids)
        self.assertNotIn("crvi-10a", ids)
        self.assertNotIn("crvi-15a", ids)

    def test_peig_ladder_is_collapsed_to_one_row(self):
        catalog = catalog_module.Catalog.load()
        ids = {e["id"] for e in catalog.base_effects}
        self.assertIn("peig-5b", ids)
        self.assertNotIn("peig-10b", ids)
```

Run: `python -m unittest scripts.spell_import.tests.test_catalog -v`
Expected: PASS

- [ ] **Step 6: Run the full Dart suite and the full Python suite**

Run: `flutter test`
Run: `ARS_RULEBOOK_ROOT=<path to the sibling rulebook checkout, if running from a nested worktree> python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`
Expected: both PASS. If any pre-existing Python test references `crvi-10a`, `crvi-15a`, or `peig-10b` by id, it will now fail — fix that test to reference `crvi-5a`/`peig-5b` instead, since this task's whole point is that those ids no longer exist.

- [ ] **Step 7: Commit**

```bash
git add assets/data/base_effects.json assets/data/modifiers.json test/engine/spell_engine_test.dart scripts/spell_import/tests/test_catalog.py
git commit -m "feat: model the Warping Point and chill-damage ladders, add the single-property discount"
```

---

### Task 2: Importer resolution — `NUMBERED_OVERRIDES`

**Files:**
- Modify: `scripts/spell_import/emit.py`
- Modify: `scripts/spell_import/extract_spells.py`
- Test: `scripts/spell_import/tests/test_emit.py`
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: `crvi-5a`, `peig-5b`, `muau-3`, `muau-gen`, and the three new modifiers (Task 1).
- Produces: `build_spell(..., chosen_base_level: int | None = None, override_modifiers: dict[str, list[str]] | None = None)`; `extract_spells.NUMBERED_OVERRIDES: dict[str, dict]`.

- [ ] **Step 1: Write failing tests for `build_spell`'s two new parameters**

Read `scripts/spell_import/tests/test_emit.py`'s `GeneralTemplateEmissionTest` class first (its `_build` helper and `setUpClass` pattern) — mirror it exactly, using the real catalog via `catalog_module.Catalog.load()`, not a synthetic one. Add a new class:

```python
class NumberedOverrideEmissionTest(unittest.TestCase):
    """`build_spell`'s chosen_base_level/override_modifiers parameters --
    the wiring NUMBERED_OVERRIDES (extract_spells.py) uses to resolve a
    design line whose numeric base has no exact catalog match. See this
    file's own docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md
    for why these are needed.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def test_chosen_base_level_is_emitted_only_when_provided(self):
        design = designline.parse_design("(Base 25, +2 Voice, +1 Conc)")
        block = _block("Infernal Smoke of Death", "Muto", "Auram", 40)
        spell = emit.build_spell(
            block, "muau-gen", self.catalog, design, chosen_base_level=25,
        )
        self.assertEqual(spell["chosenBaseLevel"], 25)

    def test_chosen_base_level_is_omitted_when_not_provided(self):
        design = designline.parse_design("(Base 3, +1 Touch, +1 Dia)")
        block = _block("Taint Something", "Creo", "Vim", 3)
        spell = emit.build_spell(block, "crvi-3", self.catalog, design)
        self.assertNotIn("chosenBaseLevel", spell)

    def test_override_modifiers_are_merged_into_selectedModifiers(self):
        design = designline.parse_design("(Base 20, +2 Voice)")
        block = _block("The Enigma's Gift", "Creo", "Vim", 30)
        spell = emit.build_spell(
            block, "crvi-5a", self.catalog, design,
            override_modifiers={"warping-point-burst": ["warping-point-burst-4"]},
        )
        self.assertEqual(
            spell["selectedModifiers"]["warping-point-burst"],
            ["warping-point-burst-4"],
        )

    def test_override_modifiers_default_to_no_change_when_not_provided(self):
        design = designline.parse_design("(Base 3, +1 Touch, +1 Dia)")
        block = _block("Taint Something", "Creo", "Vim", 3)
        spell = emit.build_spell(block, "crvi-3", self.catalog, design)
        self.assertEqual(spell["selectedModifiers"], {})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_emit.NumberedOverrideEmissionTest -v`
Expected: FAIL — `build_spell` doesn't accept either new parameter yet.

- [ ] **Step 3: Add the two parameters to `build_spell`**

In `scripts/spell_import/emit.py`, add to `build_spell`'s signature, after the existing `realm_by_spell_id` parameter:

```python
def build_spell(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
    realm_by_spell_id: dict[str, str] | None = None,
    chosen_base_level: int | None = None,
    override_modifiers: dict[str, list[str]] | None = None,
) -> dict:
```

Immediately after the existing `spell = {...}` dict literal and its `slug = spell["id"]` line, before the existing `realm_by_spell_id = realm_by_spell_id or {}` block, add:

```python
    if override_modifiers:
        spell["selectedModifiers"] = {**spell["selectedModifiers"], **override_modifiers}
```

Add this alongside the existing conditional-key statements near the end of the function (grouped with `if chosen_slots: spell["chosenSlots"] = chosen_slots`):

```python
    if chosen_base_level is not None:
        spell["chosenBaseLevel"] = chosen_base_level
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_emit.NumberedOverrideEmissionTest -v`
Expected: PASS

- [ ] **Step 5: Write failing integration tests using the real corpus**

Read `scripts/spell_import/tests/test_extract.py`'s `HandDerivedTest` and `HandDerivedAdjustmentTest` classes first — mirror their `extract_spells.run(write=False)` + `setUpClass` pattern exactly, since this table is architecturally the same kind of thing `HAND_DERIVED`/`HAND_DERIVED_ADJUSTMENT` already are. Add a new class:

```python
class NumberedOverrideTest(unittest.TestCase):
    """The 4 spells item 28's design spec resolves via NUMBERED_OVERRIDES --
    see docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md.
    """

    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def test_all_four_spells_now_import(self):
        names = {s["name"] for s in self.report.spells}
        for name in [
            "The Enigma's Gift",
            "Wizard's Icy Grip",
            "Fog of Confusion",
            "Infernal Smoke of Death",
        ]:
            self.assertIn(name, names)

    def test_infernal_smoke_of_death_carries_its_general_level(self):
        spell = next(s for s in self.report.spells if s["name"] == "Infernal Smoke of Death")
        self.assertEqual(spell["baseEffectId"], "muau-gen")
        self.assertEqual(spell["chosenBaseLevel"], 25)

    def test_the_enigmas_gift_carries_its_ladder_selection(self):
        spell = next(s for s in self.report.spells if s["name"] == "The Enigma's Gift")
        self.assertEqual(spell["baseEffectId"], "crvi-5a")
        self.assertEqual(
            spell["selectedModifiers"]["warping-point-burst"], ["warping-point-burst-4"]
        )
        self.assertNotIn("chosenBaseLevel", spell)

    def test_wizards_icy_grip_carries_its_ladder_selection(self):
        spell = next(s for s in self.report.spells if s["name"] == "Wizard's Icy Grip")
        self.assertEqual(spell["baseEffectId"], "peig-5b")
        self.assertEqual(spell["selectedModifiers"]["chill-damage"], ["chill-damage-20"])

    def test_fog_of_confusion_carries_its_discount(self):
        spell = next(s for s in self.report.spells if s["name"] == "Fog of Confusion")
        self.assertEqual(spell["baseEffectId"], "muau-3")
        self.assertEqual(
            spell["selectedModifiers"]["single-property-transformation"],
            ["single-property-transformation-yes"],
        )
```

- [ ] **Step 6: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_extract.NumberedOverrideTest -v`
Expected: FAIL — all 4 spells still blocked, `NUMBERED_OVERRIDES` doesn't exist yet.

- [ ] **Step 7: Add `NUMBERED_OVERRIDES` and wire it into the resolution path**

In `scripts/spell_import/extract_spells.py`, add near `HAND_DERIVED_ADJUSTMENT` (matching its comment density and per-entry arithmetic justification exactly — this is the same class of hand-verified table):

```python
# A published spell whose design line's numeric base has no exact catalog
# match, but resolves to a real base effect once a human reads the
# guideline text: either a General guideline this specific spell commits to
# one level of (Core Rules line 12414 says the guideline itself stays
# open-ended; this published spell already made the choice, in print,
# once), or a numbered guideline's own ladder rung one step past what the
# table prints. Verified once per entry against the rulebook, never
# inferred -- "no numbered match" alone doesn't distinguish the two cases,
# which is why this is a hand-verified table rather than an automatic
# "no match -> assume General" heuristic. See
# docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md.
#
# Infernal Smoke of Death (Muto Auram, printed LEVEL 40, "Base 25, +2 Voice,
# +1 Conc"): built on muau-gen, the MuAu General row ("Transform air into a
# gas doing +level damage") -- +25 corrosion damage matches base 25 exactly.
#
# The Enigma's Gift (Creo Vim, printed LEVEL 30, "Base 20, +2 Voice"): the
# CrVi Warping Point ladder prints levels 5/10/15 (1/2/3 Warping Points);
# the spell's own prose says "four Warping Points", the ladder's 4th rung.
#
# Wizard's Icy Grip (Perdo Ignem, printed LEVEL 30, "Base 20, +2 Voice"):
# the PeIg preamble states "for every five points the damage exceeds +5,
# add one magnitude" -- levels 5/10 already print +5/+10 damage; +20 damage
# is the same rule three magnitudes past the +5 baseline.
#
# Fog of Confusion (Muto Auram, printed LEVEL 45, "Base 2, +1 Touch, +4
# Year, +4 Size, +1 Imaginem requisite, +1 Rego requisite"): the MuAu
# preamble states "transforming only one property of air generally lowers
# the level by one magnitude" -- muau-3 (base 3) minus that one magnitude
# is exactly 2.
NUMBERED_OVERRIDES: dict[str, dict] = {
    "lib-muau-infernal-smoke-death": {
        "base_effect_id": "muau-gen",
        "chosen_base_level": 25,
        "modifiers": {},
    },
    "lib-crvi-enigmas-gift": {
        "base_effect_id": "crvi-5a",
        "chosen_base_level": None,
        "modifiers": {"warping-point-burst": ["warping-point-burst-4"]},
    },
    "lib-peig-wizards-icy-grip": {
        "base_effect_id": "peig-5b",
        "chosen_base_level": None,
        "modifiers": {"chill-damage": ["chill-damage-20"]},
    },
    "lib-muau-fog-confusion": {
        "base_effect_id": "muau-3",
        "chosen_base_level": None,
        "modifiers": {"single-property-transformation": ["single-property-transformation-yes"]},
    },
}
```

Find the numbered-resolution path (search for `candidates = catalog.candidates(block.technique, block.form, design.base_level)`). Immediately after that line, before the existing `if not candidates:` block, insert:

```python
        if not candidates and spell_id in NUMBERED_OVERRIDES:
            override = NUMBERED_OVERRIDES[spell_id]
            try:
                spells.append(emit.build_spell(
                    block, override["base_effect_id"], catalog, design,
                    realm_by_spell_id=REALM_BY_SPELL_ID,
                    chosen_base_level=override["chosen_base_level"],
                    override_modifiers=override["modifiers"],
                ))
            except (designline.UnknownToken, KeyError) as error:
                blocked.append((block.name, str(error)))
            continue

```

(Leave the existing `if not candidates: blocked.append(...)` block immediately below unchanged — it's the fallback for a slug not in the table.)

- [ ] **Step 8: Update `Sense of the Lingering Magic`'s blocked reason**

This spell has zero numbered candidates and no `NUMBERED_OVERRIDES` entry (it's deliberately absent — see this plan's design spec, "The spell that doesn't resolve"), so it falls through to the existing generic blocked message. Give it a specific one instead. Add a small table near `NUMBERED_OVERRIDES`:

```python
# Spells with a genuine catalog gap that isn't derivable from the
# guideline text -- different from NUMBERED_OVERRIDES (resolved) and from
# KNOWN_UNRESOLVABLE (candidates exist, the choice among them is
# ambiguous). See this plan's design spec for why this one specifically
# doesn't resolve.
LEVEL_NEEDS_RULES_DECISION: dict[str, str] = {
    "lib-inte-sense-lingering-magic": (
        "base 10 does not derive from InVi's numbered table (tops at 5) or "
        "General row without an unstated combination rule"
    ),
}
```

Immediately after the `if not candidates and spell_id in NUMBERED_OVERRIDES:` block from Step 7 (and still before the existing generic `if not candidates:` block), insert:

```python
        if not candidates and spell_id in LEVEL_NEEDS_RULES_DECISION:
            blocked.append(
                (block.name, f"needs a rules decision: {LEVEL_NEEDS_RULES_DECISION[spell_id]}")
            )
            continue

```

Verify the exact slug first — do not assume `"lib-inte-sense-lingering-magic"` is correct without checking `catalog_module.slug_id("Intellego", "Vim", "Sense of the Lingering Magic")` (Intellego → `in`, Vim → `vi`) directly.

- [ ] **Step 9: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_extract.NumberedOverrideTest -v`
Expected: PASS

- [ ] **Step 10: Write and run a test confirming `Sense of the Lingering Magic`'s new reason**

Add to `test_extract.py`, near `NumberedOverrideTest`:

```python
class LevelNeedsRulesDecisionTest(unittest.TestCase):
    def test_sense_of_the_lingering_magic_blocks_with_a_specific_reason(self):
        report = extract_spells.run(write=False)
        reasons = dict(report.blocked)
        self.assertIn("Sense of the Lingering Magic", reasons)
        self.assertIn("needs a rules decision", reasons["Sense of the Lingering Magic"])
```

Run: `python -m unittest scripts.spell_import.tests.test_extract.LevelNeedsRulesDecisionTest -v`
Expected: PASS

- [ ] **Step 11: Run the full Python suite**

Run: `python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`
Expected: PASS — this includes every pre-existing `test_extract.py` test that counts blocked/imported spells (e.g. any test asserting a total blocked count); update any such count to reflect 4 fewer blocked spells (now imported) with `Sense of the Lingering Magic` still counted as blocked either way.

- [ ] **Step 12: Commit**

```bash
git add scripts/spell_import/emit.py scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_emit.py scripts/spell_import/tests/test_extract.py
git commit -m "feat: resolve 4 spells via NUMBERED_OVERRIDES, give the 5th a specific blocked reason"
```

---

### Task 3: Regenerate assets and verify

**Files:**
- Modify: `assets/data/spell_library.json`

**Interfaces:**
- Consumes: everything from Tasks 1 and 2.

- [ ] **Step 1: Run the importer's write flow**

Run: `python -m scripts.spell_import.extract_spells --write` (set `ARS_RULEBOOK_ROOT` first if running from a nested worktree).

- [ ] **Step 2: Verify the diff contains exactly the 4 new spells, nothing else**

Run: `git diff --stat assets/data/spell_library.json`

Expected: an increase of exactly 4 entries. Confirm no existing entry's content changed — spot-check by running `git diff assets/data/spell_library.json` and confirming every changed hunk is either a whole-new-entry insertion or the file's own sort-order shuffle from the new entries landing alphabetically (`serialize()` sorts by id), not a modification to an existing spell's fields.

- [ ] **Step 3: Verify the counts**

Run: `python -m scripts.spell_import.extract_spells --show-blocked`

Expected: `imported : 298` (294 + 4), `templates: 23` (unchanged), `blocked : 39` (43 − 4), `unresolved: 0`. Confirm `Sense of the Lingering Magic` still appears in the blocked list, now under its new "needs a rules decision" reason rather than the generic one.

- [ ] **Step 4: Run the full Dart suite, integration suite, and Python suite**

Run: `flutter test`
Run: `flutter test integration_test/ -d windows`
Run: `python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`

Expected: all PASS — including any test that asserts a hardcoded total spell count elsewhere (e.g. `asset_data_loader_test.dart`, if it derives its expected count from the asset rather than a live oracle — check whether it needs updating for the new total of 298, or already computes its expectation dynamically from the loaded asset).

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add assets/data/spell_library.json
git commit -m "chore: regenerate spell_library.json with the 4 newly-resolved spells"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1 covers the spec's Group A data (both ladders + the discount modifier) and Decision 4's safety-net proof. Task 2 covers the unified `NUMBERED_OVERRIDES` mechanism (Design section "One resolution mechanism, not two") and the 5th spell's updated reason. Task 3 covers the corpus verification the spec's Testing section calls for. Every named spell in the spec's Problem section has a task step that either resolves it or explicitly updates its blocked reason.
- **Type consistency:** `chosen_base_level`/`override_modifiers` (Python, snake_case) map to `chosenBaseLevel`/merged-into-`selectedModifiers` (the JSON wire shape, camelCase) consistently across Tasks 2 and 3 — no task introduces a third naming variant.
- **No placeholders:** every step carries real, complete code, grounded directly against the current `extract_spells.py`/`emit.py`/`test_extract.py`/`test_emit.py` control flow (not assumed from the design spec's earlier, less-verified draft) — including the one real correction this plan's own research made to the design spec before writing tasks (unifying what the spec first described as two separate mechanisms).
