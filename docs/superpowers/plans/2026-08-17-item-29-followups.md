# Item 29 Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the three open bullets of todo item 29 — drop the ledger's
never-implemented "explicit override" promise, add the two missing Creo modifiers
with scopes that cannot double-count, and replace the stock Flutter README.

**Architecture:** Three independent changes sharing only a parent todo item. Part A
is documentation plus one characterization test; `Ledger.resolve()` is not modified.
Part B is catalog data plus test coverage in the file that already guards modifier
assets. Part C is one document.

**Tech Stack:** Flutter/Dart (app, `flutter test`), Python 3 stdlib only (extractor,
`unittest`), JSON assets under `assets/data/`.

## Global Constraints

- **Branch:** `feature/item-29-followups`, already created, spec already committed
  (`40ae168`). Do not create another branch.
- **Spec:** `docs/superpowers/specs/2026-08-17-item-29-followups-design.md`. Read it
  before Task 1.
- **Rulebook:** sibling checkout `c:\Development\personal\Ars-Magica-Open-License`,
  file `reviewed/Ars Magica - Definitive Edition (Core Rules).md`. `reviewed/` beats
  `wip/`. Every line number in this plan is into that file at the revision
  `scripts/spell_import/source.lock` pins (`9c6aee1`).
- **Python invocation:** always from the repo root, always as a module —
  `python -m scripts.spell_import.<name>`. There is no `pyproject.toml`; the
  extractor is stdlib-only and must stay that way.
- **No computed spell level may change.** The extractor must still report
  `325 imported · 28 templates · 8 exceptions · 0 blocked · 0 unresolved`, with
  `unreviewed: 3`.
- **Counts live in one place** — the todo's *Where the import stands* table. Do not
  restate them in the README.
- **Gotcha:** if `flutter test` fails with a permissions error on `sqlite3.dll`, the
  cause is stale `flutter_tester` processes holding the file. Kill them and re-run;
  it is not a real failure.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `scripts/spell_import/tests/test_ledger.py` | Modify | Add the override characterization test |
| `scripts/spell_import/ledger.py:105-110` | Modify | Turn a known-gap `NOTE` into a statement of design |
| `docs/superpowers/specs/2026-07-28-published-spell-import-design.md:203-206` | Modify | Drop the override promise, record the amendment |
| `test/data/asset_modifier_integrity_test.dart` | Modify | Extend the effectId guard; add the exclusion test; extend the scope map |
| `assets/data/modifiers.json` | Modify | Add two entries, narrow one |
| `README.md` | Replace | Orientation document |
| `.superpowers/todo.md` | Modify | Close item 29 and item 10's README bullet |

---

### Task 1: Drop the Ledger's Override Promise

**Files:**
- Modify: `scripts/spell_import/ledger.py:105-110`
- Modify: `docs/superpowers/specs/2026-07-28-published-spell-import-design.md:203-206`
- Test: `scripts/spell_import/tests/test_ledger.py`

**Interfaces:**
- Consumes: `ledger.Ledger.from_dict`, `ledger.StaleEntry`, and the module-level
  `build(entries)` helper already at the top of `test_ledger.py`.
- Produces: nothing later tasks depend on. Part A is self-contained.

**Why the test comes first even though it will pass:** this is a characterization
test — it pins behaviour that already exists so the dropped promise cannot creep
back. A test that never failed proves nothing, so Step 3 mutates `resolve()` to
confirm the test has teeth, then reverts. That is the same mutation-check discipline
the todo records for the `asset_data_loader_test.dart` collapse.

- [ ] **Step 1: Write the characterization test**

Add to `class ResolveTest` in `scripts/spell_import/tests/test_ledger.py`, directly
after `test_entry_for_an_unambiguous_spell_fails`:

```python
    def test_an_entry_may_not_override_a_sole_candidate(self):
        # Todo item 29, decided 2026-08-17. The import design spec once
        # promised an "explicit override" for exactly this shape -- one
        # candidate, and an entry naming a different id. `resolve` never
        # implemented it, and the promise was dropped rather than built.
        #
        # This reads like `test_chosen_id_must_be_among_the_candidates` with
        # a shorter list, and that is the point: the one-candidate case is
        # the override case, and it is the one somebody would be tempted to
        # special-case. Deleting this as a duplicate would delete the
        # decision.
        #
        # The rule: the ledger records a choice *among* the candidates a
        # spell's design line admits, never one against them. A sole
        # candidate that is the wrong guideline is a `base_effects.json`
        # bug, or an ExceptionSpell.
        book = build({
            "lib-cran-x": {
                "baseEffectId": "cran-5b",
                "candidates": ["cran-5a"],
                "rationale": "an override the ledger does not offer",
            }
        })
        with self.assertRaises(ledger.StaleEntry):
            book.resolve("lib-cran-x", ["cran-5a"])
```

- [ ] **Step 2: Run it and confirm it passes**

Run: `python -m unittest scripts.spell_import.tests.test_ledger -v`
Expected: PASS, 18 tests. The behaviour already exists; Step 3 proves the test
would notice if it stopped existing.

- [ ] **Step 3: Mutation-check the test**

Temporarily add one line to `Ledger.resolve()` in `scripts/spell_import/ledger.py`,
as the last statement of the `if len(candidates) == 1:` block — i.e. immediately
after `return candidates[0]`, at the same indentation as the `if entry is None:`
line above it:

```python
            return entry.base_effect_id  # MUTATION -- revert me
```

Run: `python -m unittest scripts.spell_import.tests.test_ledger -v`
Expected: **exactly one failure**, `test_an_entry_may_not_override_a_sole_candidate`,
reporting `StaleEntry not raised`. If any other test also fails, or if this one
passes, stop and re-read — the fixture is not isolating the override case.

Then **revert the mutation**: `git checkout scripts/spell_import/ledger.py`

- [ ] **Step 4: Rewrite the NOTE comment**

In `scripts/spell_import/ledger.py`, replace the comment currently at lines 105-110
(inside `resolve`, in the `if len(candidates) == 1:` block) — the block beginning
`# NOTE: an entry disagreeing with the sole candidate does NOT` and ending
`# message below only covers the "remove it" half of that.` — with:

```python
                # An entry disagreeing with the sole candidate does NOT reach
                # here: it falls through to the `not in candidates` check
                # below, which raises StaleEntry. That is the design, not a
                # gap (todo item 29, decided 2026-08-17). The ledger records
                # a choice *among* the candidates a spell's design line
                # admits, never one against them -- `candidates` is what lets
                # the build re-check a decision when the catalog moves, and a
                # choice outside its own candidate set cannot be re-checked
                # at all. A sole candidate that is the wrong guideline is a
                # base_effects.json bug, or an ExceptionSpell.
```

Leave every line of executable code untouched.

- [ ] **Step 5: Amend the import design spec**

In `docs/superpowers/specs/2026-07-28-published-spell-import-design.md`, replace
lines 203-206 — the paragraph beginning `Entries are required only where judgement`
— with:

```markdown
Entries are required only where judgement was exercised. An entry for an
unambiguous spell is rejected, to keep the ledger a record of decisions rather
than a second copy of the library. There is no override: the ledger records a
choice *among* the candidates a spell's design line admits, never one against
them. A spell whose sole candidate is the wrong guideline is evidence that
`base_effects.json` is wrong at that level, and is fixed there.

> **Amended 2026-08-17 (todo item 29).** This paragraph previously ended
> "— except as an explicit override, which needs a rationale like any other
> decision." `Ledger.resolve()` never implemented that promise. It was dropped
> rather than built: no entry in the ledger needs it, the cases it would serve
> already have homes (`adjustments`, and the exception-spell mechanism added
> later), and an entry whose choice lies outside its own candidate set defeats
> the staleness check that makes the ledger trustworthy. See
> `docs/superpowers/specs/2026-08-17-item-29-followups-design.md`.
```

- [ ] **Step 6: Run the full Python suite**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS, 317 tests (316 + the new one).

- [ ] **Step 7: Commit**

```bash
git add scripts/spell_import/ledger.py scripts/spell_import/tests/test_ledger.py docs/superpowers/specs/2026-07-28-published-spell-import-design.md
git commit -m "docs: drop the ledger's unimplemented explicit-override promise

The import spec promised an override resolve() never had. Dropped rather
than built: nothing needs it, adjustments and ExceptionSpell cover the
cases it would serve, and a choice outside its own candidate set defeats
the staleness check. Pinned by a mutation-checked test.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Make the effectId Guard Check Art Agreement

**Files:**
- Test: `test/data/asset_modifier_integrity_test.dart:125-135`

**Interfaces:**
- Consumes: `AssetDataLoader.loadModifiers()`, `AssetDataLoader.loadBaseEffects()`,
  `BaseEffect.technique`, `BaseEffect.form`, `ModifierScope.effectIds`.
- Produces: the guard Task 3's narrowed scopes rely on. Task 3 must not start until
  this is committed.

This task lands before the data change on purpose: narrowing a modifier by id is
only safe once a typo fails the build.

- [ ] **Step 1: Replace the existing test**

In `test/data/asset_modifier_integrity_test.dart`, replace the whole
`test('every scoped effectId refers to a real base effect', ...)` block (lines
125-135) with:

```dart
  test('every scoped effectId refers to a real base effect of the scoped Art', () async {
    final modifiers = await loader.loadModifiers();
    final byId = {for (final e in await loader.loadBaseEffects()) e.id: e};

    for (final modifier in modifiers) {
      for (final id in modifier.scope.effectIds) {
        final effect = byId[id];
        // `fail` returns Never, which promotes `effect` to non-null below.
        // `expect(effect, isNotNull)` would not, and every later line would
        // need a `!`.
        if (effect == null) {
          fail('${modifier.id} references unknown base effect $id');
        }
        // Existence alone would accept crhe-1b on a Creo Animal modifier.
        // A null side of a scope is a deliberate wildcard — the transport
        // ladder spans five Forms — so only a stated Technique or Form is
        // held to agree.
        if (modifier.scope.technique != null) {
          expect(effect.technique, modifier.scope.technique,
              reason: '${modifier.id} is scoped to ${modifier.scope.technique} '
                  'but $id is ${effect.technique}');
        }
        if (modifier.scope.form != null) {
          expect(effect.form, modifier.scope.form,
              reason: '${modifier.id} is scoped to ${modifier.scope.form} '
                  'but $id is ${effect.form}');
        }
      }
    }
  });
```

- [ ] **Step 2: Run it and confirm it passes**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: PASS, 14 tests (the count today, verified). Every scope in the catalog
already agrees; this step confirms the rewrite did not break the half that existed.

- [ ] **Step 3: Mutation-check the new half**

Temporarily edit `assets/data/modifiers.json`: in the `rego-ignem-fire-intensity`
entry, add `"rete-4"` to `effectIds`. That id exists, so the old assertion would have
accepted it; it is Rego **Terram**, so the new one must reject it.

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: FAIL, with reason `rego-ignem-fire-intensity is scoped to Ignem but rete-4
is Terram`.

Then revert: `git checkout assets/data/modifiers.json`

- [ ] **Step 4: Commit**

```bash
git add test/data/asset_modifier_integrity_test.dart
git commit -m "test: hold a modifier's scoped effectIds to its own Technique and Form

Existence alone accepted a Herbam row on a Creo Animal modifier. Null
scope sides stay wildcards, since the transport ladder spans five Forms.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Add the Two Modifiers and Retrofit the Animal Scope

**Files:**
- Modify: `assets/data/modifiers.json`
- Test: `test/data/asset_modifier_integrity_test.dart`

**Interfaces:**
- Consumes: Task 2's agreement guard.
- Produces: modifier ids `creo-aquam-unnatural` and `creo-herbam-treated-product`;
  option ids `creo-aquam-unnatural-{none,slight,very}` and
  `creo-herbam-treated-product-{treated,processed}`.

Rulebook basis, quoted so no lookup is needed:

- Creo Aquam, line 12806: *"Slightly unnatural liquids are one magnitude harder than
  water, very unnatural liquids are two magnitudes harder, and require a Muto
  requisite."*
- Creo Herbam, line 13931: *"To create treated Herbam products (for example, cut
  timber, a vegetarian meal, or linen or cotton cloth) add one magnitude to the level
  necessary to create the equivalent amount of unworked living or dead plants. To
  create treated and processed Herbam products (for example, clothes or furniture),
  add two magnitudes."*
- Creo Animal, line 12470: the same rule for *"the level necessary to create the
  equivalent amount of **dead** animal."*

- [ ] **Step 1: Write the failing exclusion test**

Add to `test/data/asset_modifier_integrity_test.dart`, immediately after the
`'the Rego Ignem fire-intensity modifier is scoped to controlling rows, not the ward
table'` test it is modelled on:

```dart
  test('the treated-product modifiers skip rows that already price treatment', () async {
    final modifiers = await loader.loadModifiers();
    final herbam = modifiers.firstWhere((m) => m.id == 'creo-herbam-treated-product');
    final animal = modifiers.firstWhere((m) => m.id == 'creo-animal-treated-product');

    expect(herbam.scope.effectIds..sort(), ['crhe-1b', 'crhe-1c', 'crhe-3a']);
    expect(animal.scope.effectIds..sort(), ['cran-10a', 'cran-5a']);

    expect(
      herbam.scope.appliesTo(technique: 'Creo', form: 'Herbam', baseEffectId: 'crhe-2a'),
      isFalse,
      reason: 'crhe-2a "Create a processed plant product" is crhe-1b with the '
          'treated rule already applied — levels 1-5 are the additive tier, so '
          'one magnitude is one level. Offering the modifier there double-counts',
    );
    for (final living in ['cran-5b', 'cran-10b', 'cran-15c', 'cran-50']) {
      expect(
        animal.scope.appliesTo(technique: 'Creo', form: 'Animal', baseEffectId: living),
        isFalse,
        reason: '$living creates a living animal, and the rule prices treatment '
            'against the level to create an equivalent amount of dead animal',
      );
    }
    expect(
      herbam.scope.appliesTo(technique: 'Creo', form: 'Herbam', baseEffectId: 'crhe-1b'),
      isTrue,
      reason: 'the rule has to still apply somewhere',
    );
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: FAIL — `Bad state: No element`, because `creo-herbam-treated-product` does
not exist yet.

- [ ] **Step 3: Add `creo-aquam-unnatural` to the catalog**

In `assets/data/modifiers.json`, insert this object immediately **after** the
`creo-auram-unnatural` entry (the one ending `"citations": [ { "bookId": "arm5-core" } ]`
around line 475), keeping the file's existing one-line-per-option formatting:

```json
  {
    "id": "creo-aquam-unnatural",
    "name": "Unnatural liquid",
    "description": "How unlike a natural liquid the created liquid is. Distinct from craq-4a's unnatural shape, and from aquam-base-individual, which sets what one Individual is and costs nothing",
    "selectionMode": "single",
    "scope": { "technique": "Creo", "form": "Aquam", "effectIds": [], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "creo-aquam-unnatural-none", "label": "A liquid found in nature", "magnitude": 0 },
      { "id": "creo-aquam-unnatural-slight", "label": "Slightly unnatural liquid", "magnitude": 1 },
      {
        "id": "creo-aquam-unnatural-very",
        "label": "Very unnatural liquid",
        "description": "Requires a Muto requisite",
        "magnitude": 2
      }
    ],
    "citations": [ { "bookId": "arm5-core" } ]
  },
```

- [ ] **Step 4: Add `creo-herbam-treated-product` and retrofit the Animal scope**

Still in `assets/data/modifiers.json`:

**(a)** Insert this object immediately **after** the `creo-animal-treated-product`
entry, so the three treated/worked-material entries stay adjacent:

```json
  {
    "id": "creo-herbam-treated-product",
    "name": "Treated Plant Product",
    "description": "Creating a treated, or treated and processed, plant product adds magnitudes",
    "selectionMode": "single",
    "scope": { "technique": "Creo", "form": "Herbam", "effectIds": ["crhe-1b", "crhe-1c", "crhe-3a"], "excludeTechniques": [] },
    "source": "published",
    "options": [
      { "id": "creo-herbam-treated-product-treated", "label": "Treated (e.g. cut timber, linen cloth, a vegetarian meal)", "magnitude": 1 },
      { "id": "creo-herbam-treated-product-processed", "label": "Treated and processed (e.g. clothes, furniture)", "magnitude": 2 }
    ],
    "citations": [{ "bookId": "arm5-core" }]
  },
```

**(b)** In the existing `creo-animal-treated-product` entry, change the `scope` line
from:

```json
    "scope": { "technique": "Creo", "form": "Animal", "effectIds": [], "excludeTechniques": [] },
```

to:

```json
    "scope": { "technique": "Creo", "form": "Animal", "effectIds": ["cran-5a", "cran-10a"], "excludeTechniques": [] },
```

- [ ] **Step 5: Extend the scope map**

In the existing `'every new additive modifier loads with its stated Technique and
Form'` test, add two rows to `expectedScopes`:

```dart
      'creo-aquam-unnatural': ('Creo', 'Aquam'),
      'creo-herbam-treated-product': ('Creo', 'Herbam'),
```

and two magnitude assertions beside the ones already at the end of that test:

```dart
    expect(modifiers.firstWhere((m) => m.id == 'creo-aquam-unnatural').options.map((o) => o.magnitude).toList(), [0, 1, 2]);
    expect(modifiers.firstWhere((m) => m.id == 'creo-herbam-treated-product').options.map((o) => o.magnitude).toList(), [1, 2]);
```

- [ ] **Step 6: Run the modifier integrity file**

Run: `flutter test test/data/asset_modifier_integrity_test.dart`
Expected: PASS, 15 tests.

- [ ] **Step 7: Prove no computed level moved**

Run: `flutter test`
Expected: PASS, 662 tests (661 + the new exclusion test).

Run: `python -m scripts.spell_import.extract_spells`
Expected: `325 imported · 28 templates · 8 exceptions · 0 blocked · 0 unresolved`,
`unreviewed: 3`. No published spell selects either new modifier, so any movement here
means something else broke.

- [ ] **Step 8: Commit**

```bash
git add assets/data/modifiers.json test/data/asset_modifier_integrity_test.dart
git commit -m "feat: catalog Creo Aquam unnatural liquids and Creo Herbam treated products

Closes the last two modifier gaps from item 29. Both are scoped so they
cannot double-count: crhe-2a already prices the Herbam treatment rule,
and the Animal rule prices against dead animal, so live-animal rows are
out. creo-animal-treated-product is retrofitted to match its sibling.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Replace the README

**Files:**
- Modify: `README.md` (replace all 18 lines)

**Interfaces:**
- Consumes: nothing. Produces: nothing.

**Every command below must be run before the commit.** A README nobody executed is
the failure mode being fixed. If a command's real output disagrees with the text,
change the text, not the claim.

- [ ] **Step 1: Verify each command the README will claim**

Run each, and note the actual result:

```bash
flutter test
python -m unittest discover -s scripts/spell_import/tests -t .
flutter test integration_test -d windows
python -m scripts.spell_import.extract_spells
```

- [ ] **Step 2: Write the README**

Replace the entire contents of `README.md` with:

```markdown
# Eruditus

A spell-design calculator for **Ars Magica** (Definitive Edition), built in Flutter.

A spell's level is computed from a base-effect guideline plus its Range, Duration and
Target, any modifiers it selects, and any storyguide adjustments — the arithmetic the
rulebook prints as `(Base 4, +1 Touch, +1 Conc, +3 size)`. Eruditus holds the
published guideline catalogs, computes that level, and lets you design your own
spells against the same rules.

## Layout

| Path | What lives there |
|---|---|
| `lib/models/` | The domain types — `Spell`, `BaseEffect`, `Parameter`, `Modifier` |
| `lib/engine/` | `SpellEngine`, which turns a draft into a `LevelBreakdown` |
| `lib/bloc/`, `lib/presentation/` | State management and the Flutter UI |
| `assets/data/` | The catalogs: base effects, parameters, modifiers, books, and the published spell library, templates and exceptions |
| `scripts/spell_import/` | The Python extractor that builds the spell library from the rulebook, and `resolutions.json`, its hand-written decision ledger |
| `test/`, `integration_test/` | Dart unit/widget tests, and end-to-end tests |

## Running

```bash
flutter pub get
flutter run
```

## Tests

Three suites, answering deliberately different questions. Run all three before
merging.

```bash
# Dart — the model, the engine, and the computed level of every published spell
flutter test

# Python — the extractor: parsing the rulebook, resolving guidelines, emitting assets
python -m unittest discover -s scripts/spell_import/tests -t .

# Integration — the app end to end
flutter test integration_test -d windows
```

The Dart half is not optional cover for the Python half: a regression that drops a
spell's selected modifiers passes every Python test, and only the Dart-side
printed-level assertion catches it.

If `flutter test` reports a permissions error on `sqlite3.dll`, the cause is a stale
`flutter_tester` process holding the file. Kill it and re-run.

## The rulebook

The rulebook is **not** vendored here. The extractor reads it from a sibling checkout
of the Ars Magica Open License repository:

```
<parent>/Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md
```

`reviewed/` is authoritative; `wip/` is only a fallback for books not yet reviewed.
`scripts/spell_import/source.lock` records the exact rulebook revision, and CI clones
that revision so upstream edits can never redden an unrelated PR. A separate weekly
workflow checks the *unpinned* rulebook on purpose — a failure there means upstream
improved and the lock should be bumped.

To rebuild the spell library from the rulebook:

```bash
python -m scripts.spell_import.extract_spells          # report only
python -m scripts.spell_import.extract_spells --write  # rewrite the assets
```

## Provenance

The guideline and spell data in `assets/data/` is derived from Ars Magica material
published under the Ars Magica Open License. See the licence in the rulebook
repository for terms.

## Where to look next

- `.superpowers/todo.md` — open work, in priority order, with the standing
  constraints each item carries.
- `docs/superpowers/specs/` — the design record. Every non-trivial decision in this
  repo has a spec, and the specs explain *why* far better than the code does.
```

- [ ] **Step 3: Re-check the README against Step 1's output**

Read the file back. Every command in it must be one you ran in Step 1, spelled
identically. Confirm the `assets/data/` row names all seven files, and confirm no
count of spells, effects or tests appears anywhere in the document — counts live in
the todo.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: replace the stock Flutter README with a real one

Covers the layout, the three suites and what each is for, the sibling
rulebook checkout and its pinning, Open License provenance, and where the
todo and specs live. Every command in it was run first.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Close the Item in the Todo

**Files:**
- Modify: `.superpowers/todo.md`

**Interfaces:**
- Consumes: Tasks 1-4 complete and committed.

- [ ] **Step 1: Mark the three bullets done**

In section A, item 29, change the three open bullets to `- [x]` and rewrite each
body to what a later reader needs, in the style the file's other closed bullets use —
the decision and the constraint it leaves behind, not a narrative:

- The ledger bullet records that the promise was **dropped**, that `resolve()` was
  not changed, and that a test now pins it.
- The modifier bullet records the two ids added, and — the part worth keeping — that
  both treated-product modifiers are **scoped by `effectIds`** because `crhe-2a`
  already prices the Herbam rule and the Animal rule prices against dead animal.
- The README bullet records that it was replaced, and that counts deliberately stay
  out of it.

- [ ] **Step 2: Move item 29 to `## Completed ✅`**

All five of its bullets are now closed. Move the whole item, **including its "CI
notes that bind" block** — those are standing constraints on the workflows, not
tasks, and must survive the move verbatim.

- [ ] **Step 3: Close item 10's README bullet**

In section D, item 10, mark `Update README (see also item 29 — it is still the stock
Flutter template)` as `- [x]`, done 2026-08-17. Its other two bullets (the Size
feature guide, the Aquam sub-type limitation) stay open.

- [ ] **Step 4: Update the header date**

Set **Last updated** to `2026-08-17`. Do not touch the *Where the import stands*
counts — nothing in this plan moved them.

- [ ] **Step 5: Verify the whole tree one last time**

```bash
flutter test
python -m unittest discover -s scripts/spell_import/tests -t .
python -m scripts.spell_import.extract_spells
```

Expected: Dart 662 pass, Python 317 pass, and
`325 imported · 28 templates · 8 exceptions · 0 blocked · 0 unresolved`,
`unreviewed: 3`.

- [ ] **Step 6: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close item 29, and item 10's README bullet

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Verification Summary

| Suite | Command | Before | After |
|---|---|---|---|
| Dart | `flutter test` | 661 | 662 |
| Python | `python -m unittest discover -s scripts/spell_import/tests -t .` | 316 | 317 |
| Integration | `flutter test integration_test -d windows` | 8 | 8 |
| Extractor | `python -m scripts.spell_import.extract_spells` | 325/28/8/0/0 | unchanged |
