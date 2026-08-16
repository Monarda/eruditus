# Unblock All 4 Remaining Blocked Spells Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clear `.superpowers/todo.md` item 25's last 4 permanently-blocked
spells — 3 via the base-effect analogy capability, 1 via the exception-spell
mechanism — so `--show-blocked` goes from 4 to 0.

**Architecture:** Pure importer + data work, no Dart model or engine change.
Task 1 extends `emit.build_template` with a small, generically-guarded
`chosen_slots` parameter. Task 2 adds a new `ANALOGY_BASE_EFFECTS` lookup
table to `extract_spells.py` that routes 3 spells to existing Vim-level
General base effects (instead of the Form-specific rows that don't exist or
don't fit) via the already-shipped `Spell`/`SpellTemplate.analogyRationale`
field. Task 3 adds the 4th spell to the existing `exceptions.EXCEPTION_SPELLS`
table (same mechanism 7 other spells already use) and retires the now-dead
`DESIGN_LINE_INCOMPLETE`/`GENERAL_BLOCKED` entries the first three tasks
leave behind.

**Tech Stack:** Python 3 (stdlib `unittest`), the existing
`scripts/spell_import/` importer pipeline.

## Global Constraints

- No Dart model, engine, or asset-schema change. `GeneralEffectFormula`,
  `ExceptionSpell`, and `analogyRationale` all already exist and ship on
  `main`.
- Every donor base effect id used below (`pevi-G2`, `revi-G2`, `pevi-G3`)
  must be passed through **unmodified** — no new catalog row, no formula
  override. Confirmed by the design spec's Decision 1.
- `test_general_entries_match_the_rulebook_bullet_for_bullet`
  (`scripts/spell_import/tests/test_general_catalog.py`) must still pass
  unmodified after every task — it is the constraint this whole plan routes
  around rather than violates.
- Regenerate `assets/data/spell_templates.json` and
  `assets/data/spell_exceptions.json` via
  `python -m scripts.spell_import.extract_spells --write` after each task
  that changes what the importer produces (Tasks 2 and 3) — never hand-edit
  either JSON file.
- Both suites must stay green after every task: `python -m unittest discover`
  (run from the repo root) and `flutter test`.
- Full spec: `docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md`.

---

### Task 1: `emit.build_template` gains a `chosen_slots` parameter

**Files:**
- Modify: `scripts/spell_import/emit.py:252-329` (the `build_template` function)
- Test: `scripts/spell_import/tests/test_emit.py` (the `OpenSlotEmissionTest` class, `scripts/spell_import/tests/test_emit.py:626-667`)

**Interfaces:**
- Consumes: `catalog_module.Catalog.open_slots(effect_id: str) -> list[str]`
  (`scripts/spell_import/catalog.py:91-100`, already exists) — returns the
  `OpenSlotKind` names a base effect declares open, or `[]`.
- Produces: `emit.build_template(..., chosen_slots: dict[str, str] | None = None)`
  — a new optional keyword parameter Task 2 will call with
  `{"specificType": "Creo Imaginem"}`. Any key whose kind the named base
  effect does not declare open is silently dropped (mirrors the existing
  `realm_by_spell_id` guard).

- [ ] **Step 1: Write the two failing tests**

Add to the `OpenSlotEmissionTest` class in
`scripts/spell_import/tests/test_emit.py`, directly after the existing
`test_realm_by_spell_id_defaults_to_empty_when_omitted` method (ends at
line 667):

```python
    def test_build_template_merges_caller_supplied_chosen_slots(self):
        design = designline.parse_design("(Base effect, +2 Voice)")
        block = _block("Test Spell", "Perdo", "Imaginem", None)
        template = emit.build_template(
            block, "pevi-G2", self.catalog, design,
            chosen_slots={"specificType": "Creo Imaginem"},
        )
        self.assertEqual(template["chosenSlots"], {"specificType": "Creo Imaginem"})

    def test_build_template_drops_a_chosen_slot_kind_the_effect_does_not_declare_open(self):
        # pevi-G3 has no openSlots at all -- a caller-supplied kind, if
        # passed, must not leak onto a guideline that never declared
        # anything open. Mirrors test_build_template_omits_chosenSlots_
        # when_the_effect_declares_no_open_slot above, for the new parameter.
        design = designline.parse_design("(Base spell, +1 Touch, +2 Sun)")
        block = _block("Demon's Eternal Oblivion", "Perdo", "Vim", None)
        template = emit.build_template(
            block, "pevi-G3", self.catalog, design,
            chosen_slots={"specificType": "something"},
        )
        self.assertNotIn("chosenSlots", template)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_emit.OpenSlotEmissionTest -v`

Expected: the two new tests `FAIL` with `TypeError: build_template() got an
unexpected keyword argument 'chosen_slots'`. The other 4 tests in the class
still `PASS`.

- [ ] **Step 3: Implement `chosen_slots` in `build_template`**

Replace `scripts/spell_import/emit.py:252-329` (the full `build_template`
function) with:

```python
def build_template(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
    realm_by_spell_id: dict[str, str] | None = None,
    analogy_rationale: str | None = None,
    chosen_slots: dict[str, str] | None = None,
) -> dict:
    """Build a `SpellTemplate.fromMap`-shaped entry for a General spell.

    Mirrors `build_spell`, minus `printedLevel` and the level arithmetic that
    field requires: a General block's `printed_level` is always `None`
    (that's what routes it here instead of to `build_spell`), so this
    function never reads it.
    """
    range_id = catalog.parameter_id("Range", _parameter_name(design, "range", block))
    duration_id = catalog.parameter_id("Duration", _parameter_name(design, "duration", block))
    target_id = catalog.parameter_id("Target", _parameter_name(design, "target", block))

    requisites: dict[str, str] = {}
    for token in design.tokens:
        if token.kind == "requisite" and token.label != "free":
            art = _resolve_requisite_label(token, block)
            requisites.setdefault(art, "adding" if token.magnitude else "free")
    for art in block.stat.requisite_arts:
        requisites.setdefault(art, "free")

    # The `lib-` slug is the ledger key (resolutions.json, KNOWN_UNRESOLVABLE);
    # the template's own id is that same slug with `tpl-` in place of `lib-`.
    # Derived from slug_id rather than a second slug function.
    slug = catalog_module.slug_id(block.technique, block.form, block.name)
    template_id = "tpl-" + slug.removeprefix("lib-")

    realm_by_spell_id = realm_by_spell_id or {}
    resolved_slots: dict[str, str] = {}
    realm = realm_by_spell_id.get(slug)
    if realm is not None and "realm" in catalog.open_slots(base_effect_id):
        resolved_slots["realm"] = realm
    # A caller-supplied override (e.g. extract_spells.ANALOGY_BASE_EFFECTS's
    # own "chosen_slots" entries) for a slot kind other than realm --
    # guarded the same way, against this base effect's own declared open
    # slots, so a stray kind is silently dropped rather than producing a
    # chosenSlots key validateSpellAgainstCatalog's check 7 would reject.
    if chosen_slots:
        open_kinds = catalog.open_slots(base_effect_id)
        for kind, value in chosen_slots.items():
            if kind in open_kinds:
                resolved_slots[kind] = value

    template = {
        "id": template_id,
        "name": block.name,
        "technique": block.technique,
        "form": block.form,
        "requisites": requisites,
        "source": "published",
        "selectedModifiers": _selected_modifiers(design, block, catalog),
        "baseEffectId": base_effect_id,
        "rangeId": range_id,
        "durationId": duration_id,
        "targetId": target_id,
        "summary": _template_summary(block),
    }

    description = _description(block)
    if description:
        template["description"] = description

    template["citations"] = [{"bookId": CORE_BOOK_ID}]

    adjustments = [
        {"magnitude": token.magnitude, "note": token.note}
        for token in design.tokens
        if token.kind == "adjustment"
    ]
    if adjustments:
        template["adjustments"] = adjustments

    if block.stat.is_ritual:
        template["ritualDeclaration"] = "lastingCreation"

    if resolved_slots:
        template["chosenSlots"] = resolved_slots

    if analogy_rationale is not None:
        template["analogyRationale"] = analogy_rationale

    return template
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_emit -v`

Expected: `OK`, all tests in the module pass, including the 2 new ones and
the 4 pre-existing `OpenSlotEmissionTest` tests (the rename from
`chosen_slots` to `resolved_slots` as the local variable must not change
their behavior).

- [ ] **Step 5: Run the full Python suite**

Run: `python -m unittest discover`

Expected: `OK`. This confirms the rename didn't break any other caller —
`build_template` has exactly one call site today
(`extract_spells.py:610-614`), and it doesn't pass `chosen_slots`, so its
behavior is unchanged.

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/emit.py scripts/spell_import/tests/test_emit.py
git commit -m "feat: emit.build_template accepts a chosen_slots override

Small, generically-guarded parameter Task 2 will use to pre-fill
Dispel the Phantom Image's specificType slot. Guarded the same way as
the existing realm_by_spell_id merge: a slot kind the named base
effect doesn't declare open is silently dropped."
```

---

### Task 2: Route 3 spells through `ANALOGY_BASE_EFFECTS`

**Files:**
- Modify: `scripts/spell_import/extract_spells.py`
  - New table after `DESIGN_LINE_INCOMPLETE` (currently ends `extract_spells.py:183`)
  - New routing branch inside the General-spell handling (`extract_spells.py:547-577`)
  - Remove `"lib-reim-restore-moved-image"` from `DESIGN_LINE_INCOMPLETE`
  - Remove 3 entries from `GENERAL_BLOCKED` (test file, see below)
- Modify: `assets/data/spell_templates.json` (regenerated, not hand-edited)
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: `emit.build_template(block, base_effect_id, catalog, design, realm_by_spell_id=..., analogy_rationale=..., chosen_slots=...)` from Task 1.
- Produces: 3 new entries in `report.templates` (via `extract_spells.run()`), each with a non-null `analogyRationale` and `technique`/`form` matching the spell's own printed Form.

- [ ] **Step 1: Write the failing tests**

Add a new test class to `scripts/spell_import/tests/test_extract.py`,
directly after the `NumberedOverrideLedgerAgreementTest` class (search for
`class NumberedOverrideLedgerAgreementTest`, insert after its last method):

```python
class AnalogyBaseEffectsTest(unittest.TestCase):
    """3 of item 25's 4 permanently-blocked spells resolve by pointing at an
    existing Vim-level General base effect instead of a (nonexistent or
    wrong) row in their own Form's table -- see
    docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.
    """

    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def _template(self, name: str) -> dict:
        return next(t for t in self.report.templates if t["name"] == name)

    def test_all_three_now_import_as_templates_not_blocked(self):
        names = {t["name"] for t in self.report.templates}
        blocked_names = {name for name, _ in self.report.blocked}
        for name in ("Dispel the Phantom Image", "Restore the Moved Image",
                     "Lay to Rest the Haunting Spirit"):
            self.assertIn(name, names, msg=name)
            self.assertNotIn(name, blocked_names, msg=name)

    def test_dispel_the_phantom_image_points_at_pevi_g2(self):
        template = self._template("Dispel the Phantom Image")
        self.assertEqual(template["baseEffectId"], "pevi-G2")
        self.assertEqual(template["technique"], "Perdo")
        self.assertEqual(template["form"], "Imaginem")
        self.assertTrue(template["analogyRationale"])
        self.assertEqual(template["chosenSlots"], {"specificType": "Creo Imaginem"})

    def test_restore_the_moved_image_points_at_revi_g2(self):
        template = self._template("Restore the Moved Image")
        self.assertEqual(template["baseEffectId"], "revi-G2")
        self.assertEqual(template["technique"], "Rego")
        self.assertEqual(template["form"], "Imaginem")
        self.assertTrue(template["analogyRationale"])
        self.assertNotIn("chosenSlots", template)

    def test_lay_to_rest_the_haunting_spirit_points_at_pevi_g3(self):
        template = self._template("Lay to Rest the Haunting Spirit")
        self.assertEqual(template["baseEffectId"], "pevi-G3")
        self.assertEqual(template["technique"], "Perdo")
        self.assertEqual(template["form"], "Mentem")
        self.assertTrue(template["analogyRationale"])
        self.assertNotIn("chosenSlots", template)
```

Also update `GENERAL_BLOCKED` (search for `GENERAL_BLOCKED = {`, around
`test_extract.py:295`): remove the 3 keys `"Dispel the Phantom Image"`,
`"Lay to Rest the Haunting Spirit"`, and `"Restore the Moved Image"`,
leaving only `"The Invisible Eye Revealed": "design line does not account
for the stat line",` (Task 3 removes that one). Add a comment line directly
above the remaining entry:

```python
    # Dispel the Phantom Image, Lay to Rest the Haunting Spirit and Restore
    # the Moved Image: WERE here until 2026-08-16, when they moved to
    # AnalogyBaseEffectsTest instead -- each now imports as a template via
    # ANALOGY_BASE_EFFECTS (scripts/spell_import/extract_spells.py), not
    # blocked at all. See
    # docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_extract.AnalogyBaseEffectsTest -v`

Expected: all 4 new tests `FAIL` — `StopIteration` from `_template()` (the
spells are still blocked, so `report.templates` doesn't contain them yet).

Run: `python -m unittest scripts.spell_import.tests.test_extract.GeneralBlockedStalenessTest -v`

Expected: `PASS` still (the 3 spells are still genuinely blocked at this
point — this test only starts guarding staleness once Step 3 makes them
import).

- [ ] **Step 3: Add `ANALOGY_BASE_EFFECTS` and route the 3 spells through it**

In `scripts/spell_import/extract_spells.py`, insert this new table
immediately after the `DESIGN_LINE_INCOMPLETE` dict's closing `}`
(currently `extract_spells.py:183`):

```python

# Spells whose own Technique/Form guideline table has no matching General
# row (or has one, but it's the wrong guideline) -- resolved by pointing at
# an existing Vim-level General row that generalizes the same mechanic with
# a magnitude offset, using the base-effect analogy capability
# (Spell/SpellTemplate.technique/.form + analogyRationale). See
# docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md
# for the full derivation of each entry, including the arithmetic that rules
# out The Invisible Eye Revealed from this same treatment (it's already a
# Vim spell -- see exceptions.EXCEPTION_SPELLS instead).
#
# Checked in extract_spells.run()'s General-spell branch before both the
# general_candidates-empty handling and DESIGN_LINE_INCOMPLETE, so it takes
# precedence over each for the spell ids listed here.
ANALOGY_BASE_EFFECTS: dict[str, dict] = {
    "lib-peim-dispel-phantom-image": {
        "base_effect_id": "pevi-G2",
        "rationale": (
            "Perdo Imaginem's own guideline table prints no General row. "
            "This spell's own text (\"Destroys the image from any one CrIm "
            "spell whose level you match or exceed on a stress die + the "
            "level of your spell\") is the Imaginem-scoped echo of Perdo "
            "Vim's own general \"dispel a specific type of effect\" "
            "guideline (pevi-G2), narrowed to Creo Imaginem and without "
            "pevi-G2's own +4 magnitude bonus -- the same shape Perdo Vim's "
            "Wind of Mundane Silence generalizes for any type/realm."
        ),
        "chosen_slots": {"specificType": "Creo Imaginem"},
    },
    "lib-reim-restore-moved-image": {
        "base_effect_id": "revi-G2",
        "rationale": (
            "Rego Imaginem's own General row (reim-G) is a ward -- this "
            "spell isn't one. This spell's own text (\"Cancels a ReIm spell "
            "... as long as you can match the spell's level on a stress die "
            "+ the level of your spell\") is the Imaginem-scoped echo of "
            "Rego Vim's general \"sustain or suppress a spell you cast\" "
            "guideline (revi-G2), narrowed to Rego Imaginem, trading "
            "revi-G2's +2 magnitude bonus for a stress-die factor revi-G2 "
            "doesn't have."
        ),
    },
    "lib-peme-lay-to-rest-haunting-spirit": {
        "base_effect_id": "pevi-G3",
        "rationale": (
            "Perdo Mentem's own guideline table prints no General row. "
            "This spell's own text (\"it loses a number of points from its "
            "Might equal to the level of this spell\") is the Mentem-scoped "
            "echo of Perdo Vim's general \"reduce target's Might Score\" "
            "guideline (pevi-G3), narrowed to ghosts/spirits and without "
            "pevi-G3's own +2 magnitude bonus."
        ),
    },
}
```

Then in the General-spell branch, insert a new routing check immediately
after the line that computes `general_candidates` and the blank line that
follows it (`extract_spells.py:547-551` reads, unchanged above and below
this insertion point):

```python
        if design.base_level is None or block.printed_level is None:
            spell_id = catalog_module.slug_id(block.technique, block.form, block.name)
            design_lines[spell_id] = design_text
            general_candidates = catalog.general_candidates(block.technique, block.form)

            if spell_id in ANALOGY_BASE_EFFECTS:
                analogy = ANALOGY_BASE_EFFECTS[spell_id]
                try:
                    templates.append(emit.build_template(
                        block, analogy["base_effect_id"], catalog, design,
                        realm_by_spell_id=REALM_BY_SPELL_ID,
                        analogy_rationale=analogy["rationale"],
                        chosen_slots=analogy.get("chosen_slots"),
                    ))
                except (designline.UnknownToken, KeyError) as error:
                    blocked.append((block.name, str(error)))
                continue

            if not general_candidates:
```

(The `if not general_candidates:` line already exists at
`extract_spells.py:552` — this step only adds the new `if spell_id in
ANALOGY_BASE_EFFECTS:` block directly above it, changing no other line in
that function.)

- [ ] **Step 4: Remove the now-superseded `DESIGN_LINE_INCOMPLETE` entry**

In `scripts/spell_import/extract_spells.py`, in the `DESIGN_LINE_INCOMPLETE`
dict (`extract_spells.py:175-183`), delete the
`"lib-reim-restore-moved-image"` entry:

```python
DESIGN_LINE_INCOMPLETE = {
    "lib-invi-invisible-eye-revealed":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    # Restore the Moved Image: WAS here until 2026-08-16, when it moved to
    # ANALOGY_BASE_EFFECTS instead -- it now imports as a template pointing
    # at revi-G2, not blocked. See
    # docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.
    # Wizard's Communion used to be here too. It now imports as an exception
    # spell (scripts/spell_import/exceptions.py) -- see
    # docs/superpowers/specs/2026-08-15-exception-spells-design.md.
}
```

**Leave `"lib-invi-invisible-eye-revealed"` in place — Task 3 removes it.**

- [ ] **Step 5: Run the new and updated tests**

Run: `python -m unittest scripts.spell_import.tests.test_extract -v`

Expected: `OK`. In particular:
- `AnalogyBaseEffectsTest`'s 4 tests now pass.
- `GeneralBlockedStalenessTest.test_every_recorded_general_blocker_still_blocks`
  passes (the 3 removed keys are gone from `GENERAL_BLOCKED`, so the test no
  longer expects them to block).
- `ExceptionSpellsDisjointnessTest` and `ExceptionSpellsTest` are unaffected
  (Task 3's spell isn't touched yet).
- `RegenerationTest` (`test_committed_library_matches_a_fresh_run` and its
  templates counterpart) **will now fail** — this is expected and Step 6
  below fixes it. If it's the only remaining failure, proceed to Step 6.

- [ ] **Step 6: Regenerate `assets/data/spell_templates.json`**

Run: `python -m scripts.spell_import.extract_spells --write`

Expected: prints an updated `templates: N` count (3 higher than before —
confirm by running `python -m scripts.spell_import.extract_spells
--show-blocked` before and after this step; the blocked count drops from 4
to 1). `git diff --stat assets/data/spell_templates.json` shows only
additions (3 new template objects), no changes to any existing entry.

- [ ] **Step 7: Run the full Python suite again**

Run: `python -m unittest discover`

Expected: `OK`, including `RegenerationTest` now that the asset matches a
fresh run.

- [ ] **Step 8: Run the Dart suite**

Run: `flutter test`

Expected: `All tests passed!`. In particular,
`test/data/published_spell_import_test.dart`'s assertions (including
assertion 6, `ReferenceOracleTest`'s equivalent, and check 8's rationale
requirement) pass against the 3 new templates without any Dart code change —
`analogyRationale` and diverging `technique`/`form` are exactly the shape
`validateSpellAgainstCatalog` already handles.

- [ ] **Step 9: Commit**

```bash
git add scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_extract.py assets/data/spell_templates.json
git commit -m "feat: unblock 3 spells via base-effect analogy to Vim guidelines

Dispel the Phantom Image (pevi-G2), Restore the Moved Image
(revi-G2), and Lay to Rest the Haunting Spirit (pevi-G3) now import
as templates, pointing at an existing Vim-level General base effect
instead of a nonexistent or wrong row in their own Form's table.

See docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md."
```

---

### Task 3: Add *The Invisible Eye Revealed* as an exception spell

**Files:**
- Modify: `scripts/spell_import/exceptions.py`
  - New `EXCEPTION_SPELLS` entry
  - Fix the stale cross-reference inside the existing `"Sight of the True Form"` entry
- Modify: `scripts/spell_import/extract_spells.py`
  - Empty out `DESIGN_LINE_INCOMPLETE` (its last entry)
  - Empty out the 3-spell preamble comment block's now-stale framing (`extract_spells.py:106-174`)
  - Update the `general_candidates` empty-branch comment (`extract_spells.py:552-577`)
- Modify: `assets/data/spell_exceptions.json` (regenerated, not hand-edited)
- Modify: `.superpowers/todo.md` (item 25's body, and the "Where the import stands" summary/table)
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: `emit.build_exception_spell(block, rationale: str) -> dict`
  (`scripts/spell_import/emit.py:743-774`, already exists and unchanged) —
  automatically invoked for any name in `exceptions.EXCEPTION_SPELLS` by the
  existing check at `extract_spells.py:493-497`, which runs before any of
  Task 2's or this task's other changes are ever reached.
- Produces: 1 new entry in `report.exceptions`, and `--show-blocked` reaches
  0.

- [ ] **Step 1: Write the failing tests**

In `scripts/spell_import/tests/test_extract.py`, update
`ExceptionSpellsTest.test_the_five_general_kind_exceptions_have_no_printed_level`
(currently lists 5 names) to include the 6th:

```python
    def test_the_six_general_kind_exceptions_have_no_printed_level(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        for name in ("Wizard's Communion", "Wizard's Vigil",
                     "Aegis of the Hearth", "Watching Ward",
                     "Sight of the True Form", "The Invisible Eye Revealed"):
            self.assertNotIn("printedLevel", by_name[name], msg=name)
```

(Renamed from `test_the_five_general_kind_exceptions_...` to
`test_the_six_general_kind_exceptions_...` — update the method name, not
just the body.)

Add one more assertion to `test_ids_use_the_exc_prefix`:

```python
    def test_ids_use_the_exc_prefix(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        self.assertEqual(by_name["Whispering Winds"]["id"], "exc-inau-whispering-winds")
        self.assertEqual(by_name["Wizard's Communion"]["id"], "exc-muvi-wizards-communion")
        self.assertEqual(
            by_name["The Invisible Eye Revealed"]["id"], "exc-invi-invisible-eye-revealed"
        )
```

Update `GENERAL_BLOCKED` (`test_extract.py`, same dict Task 2 already
trimmed): remove the last remaining key, `"The Invisible Eye Revealed"`,
leaving the dict empty. Replace its body with:

```python
GENERAL_BLOCKED: dict[str, str] = {}
# Ward against Faeries of the Mountain, Aegis of the Hearth, Wizard's Vigil,
# Watching Ward, Wizard's Communion, Sight of the True Form, Dispel the
# Phantom Image, Lay to Rest the Haunting Spirit, Restore the Moved Image,
# and The Invisible Eye Revealed all WERE here at one point or another --
# each now imports (as a template, an exception spell, or via
# ANALOGY_BASE_EFFECTS). Currently empty; the mechanism stays for the next
# spell that turns out to need it.
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_extract.ExceptionSpellsTest -v`

Expected: `test_the_six_general_kind_exceptions_have_no_printed_level` and
`test_ids_use_the_exc_prefix` both `FAIL` with `KeyError: 'The Invisible Eye
Revealed'` (not yet in `report.exceptions`).

Run: `python -m unittest scripts.spell_import.tests.test_extract.GeneralBlockedStalenessTest -v`

Expected: still `PASS` (the spell is still genuinely blocked at this point).

- [ ] **Step 3: Add the `EXCEPTION_SPELLS` entry**

In `scripts/spell_import/exceptions.py`, add a new entry to the
`EXCEPTION_SPELLS` dict, after the existing `"Sight of the True Form"` entry
(inside the same dict literal, before its closing `}`):

```python
    "The Invisible Eye Revealed": (
        "Design line prints \"(Base effect)\", General-kind, no printed "
        "level. Intellego Vim's own guideline table prints exactly one "
        "General row, invi-G (\"detect the traces of magic of negative "
        "magnitude up to the magnitude of the guideline used - 2\") -- a "
        "residual-trace-decay formula, confirmed the wrong guideline by "
        "checking the arithmetic, not just the wording: at level 20 invi-G "
        "computes a magnitude of 2, while this spell's own text (\"detects "
        "the use of Intellego spells of up to double the level of this "
        "spell\") needs a level threshold of 40 -- different "
        "GeneralEffectKind families (spellTraceMagnitude vs. "
        "targetSpellLevel), not a close-enough match. No other Form's "
        "guideline can substitute by analogy either: this spell is already "
        "Intellego Vim, the top of the analogy chain (see "
        "docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md). "
        "Same shape as Sight of the True Form: a matching InVi row was not "
        "attempted here for the identical reason -- "
        "test_general_entries_match_the_rulebook_bullet_for_bullet forbids it."
    ),
```

- [ ] **Step 4: Fix the stale cross-reference in `"Sight of the True Form"`'s entry**

Still in `scripts/spell_import/exceptions.py`, in the existing `"Sight of
the True Form"` entry, replace the final sentence:

Old text (end of that entry's string, currently reads):
```python
        "A matching row was built from this exact prose once (`inco-gen`, "
        "a targetSpellLevel guideline) and deliberately removed -- "
        "reconstructing rulebook content the table never printed, the same "
        "policy that keeps Dispel the Phantom Image, Lay to Rest the "
        "Haunting Spirit, Restore the Moved Image and The Invisible Eye "
        "Revealed blocked rather than exceptions (see todo item 25 for why "
        "those four stay blocked and this one does not)."
    ),
```

New text:
```python
        "A matching row was built from this exact prose once (`inco-gen`, "
        "a targetSpellLevel guideline) and deliberately removed -- "
        "reconstructing rulebook content the table never printed, the same "
        "policy that also governs The Invisible Eye Revealed's own entry "
        "just above, and that routed Dispel the Phantom Image, Restore the "
        "Moved Image and Lay to Rest the Haunting Spirit to an existing "
        "Vim-level guideline instead (see "
        "docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md)."
    ),
```

- [ ] **Step 5: Empty out `DESIGN_LINE_INCOMPLETE` in `extract_spells.py`**

In `scripts/spell_import/extract_spells.py`, replace the
`DESIGN_LINE_INCOMPLETE` dict (as left by Task 2's Step 4) with:

```python
# Currently empty -- both former entries now resolve elsewhere. Restore the
# Moved Image moved to ANALOGY_BASE_EFFECTS and The Invisible Eye Revealed
# moved to exceptions.EXCEPTION_SPELLS, both 2026-08-16. See
# docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.
# Wizard's Communion used to be here too, earlier -- it now imports as an
# exception spell (scripts/spell_import/exceptions.py) -- see
# docs/superpowers/specs/2026-08-15-exception-spells-design.md. The
# mechanism stays for the next spell whose design line is real but
# incomplete relative to its stat line.
DESIGN_LINE_INCOMPLETE: dict[str, str] = {}
```

- [ ] **Step 6: Update the two large comment blocks that still describe all 4 spells as blocked**

In `scripts/spell_import/extract_spells.py`, at the end of the long
preamble comment that precedes `DESIGN_LINE_INCOMPLETE` (the paragraph
ending "...confirmed 2026-08-16, does not change the classification
above." — directly before the `DESIGN_LINE_INCOMPLETE` declaration Step 5
just replaced), append one new paragraph:

```python
#
# ALL FOUR of the above resolved 2026-08-16, after this comment was
# written -- 3 via ANALOGY_BASE_EFFECTS (below), pointing at the existing
# Vim-level guideline each is a Form-specific echo of, and The Invisible
# Eye Revealed via exceptions.EXCEPTION_SPELLS, since it is already Vim
# itself and has nowhere more general to point to. The derivation above
# (why no *new* catalog row is the right answer) still stands -- it's the
# reason analogy/exception was the right mechanism, not a contradiction of
# it. See docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.
```

Then, in the `general_candidates` empty-branch comment
(`extract_spells.py:552-577` before Task 2's edits — the comment beginning
"Permanent, not a gap to fill:" that names *Dispel the Phantom Image* and
*Lay to Rest the Haunting Spirit*), append after its final sentence ("...for
why the pattern doesn't change this either."):

```python
                # Both resolved 2026-08-16 via ANALOGY_BASE_EFFECTS, checked
                # above before this branch is ever reached for their spell
                # ids -- this empty-candidates branch itself is unchanged
                # and still correct for any future spell with no analogy
                # entry. See
                # docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.
```

- [ ] **Step 7: Run the new and updated tests**

Run: `python -m unittest scripts.spell_import.tests.test_extract -v`

Expected: `OK`. In particular:
- `ExceptionSpellsTest`'s renamed and updated tests pass.
- `ExceptionSpellsStalenessTest` and `ExceptionSpellsDisjointnessTest` pass
  (the new entry's name is a real parsed spell, and its slug no longer
  appears in `DESIGN_LINE_INCOMPLETE`, which Step 5 emptied).
- `GeneralBlockedStalenessTest` passes trivially (`GENERAL_BLOCKED` is now
  empty).
- `RegenerationTest` (exceptions half) **will now fail** — expected, fixed
  by Step 8.

- [ ] **Step 8: Regenerate `assets/data/spell_exceptions.json`**

Run: `python -m scripts.spell_import.extract_spells --write`

Expected: prints an updated `exceptions: 8` (was 7). Confirm
`python -m scripts.spell_import.extract_spells --show-blocked` now reports
**0 blocked**. `git diff --stat assets/data/spell_exceptions.json` shows
only additions (1 new exception object).

- [ ] **Step 9: Run the full Python suite**

Run: `python -m unittest discover`

Expected: `OK`.

- [ ] **Step 10: Run the Dart suite**

Run: `flutter test`

Expected: `All tests passed!` — no Dart code changed in this task; this
confirms the regenerated `spell_exceptions.json` still satisfies every
existing asset-level assertion.

- [ ] **Step 11: Update `.superpowers/todo.md`**

Two edits:

1. In the "Where the import stands" summary near the top of the file,
   replace:
   ```
   > **325 imported · 24 emitted as templates · 7 recorded as exceptions · 4
   > blocked · 0 unresolved**
   > — 360 published spells in Chapter 9, all accounted for.
   ```
   with:
   ```
   > **325 imported · 27 emitted as templates · 8 recorded as exceptions · 0
   > blocked · 0 unresolved**
   > — 360 published spells in Chapter 9, all accounted for.
   ```

2. In item 25's body (search for `### 25. General-Level Spells`), replace
   the paragraph beginning "**Four of the 33 remain blocked, each for a
   reason unrelated to this item —**" through the end of the bullet list
   that follows it (down to, and including, the sentence ending "...does not
   change the classification above." and its four-spell derivation bullets)
   with:
   ```
   **All 33 now import — the last 4 unblocked 2026-08-16, via two different
   mechanisms.** (Was ten, then nine, then five, then four, per the earlier
   history below; the final four cleared together —
   see `docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md`.)

   - **3 unblocked via the base-effect analogy capability**
     (`Spell`/`SpellTemplate.technique`/`.form` + `analogyRationale`,
     `docs/superpowers/plans/2026-08-16-base-effect-analogy.md`): each is a
     Form-specific spell whose own guideline table has no matching General
     row, pointed instead at the existing Vim-level General row it's a
     narrower, un-offset echo of.
     - *Dispel the Phantom Image* (Perdo Imaginem) → `pevi-G2`
       ("dispel a specific type of effect"), narrowed to Creo Imaginem.
     - *Restore the Moved Image* (Rego Imaginem) → `revi-G2`
       ("sustain or suppress a spell you cast").
     - *Lay to Rest the Haunting Spirit* (Perdo Mentem) → `pevi-G3`
       ("reduce target's Might Score").
   - **1 unblocked as an exception spell**
     (`scripts/spell_import/exceptions.py`, the same mechanism as *Sight of
     the True Form* and 6 others): *The Invisible Eye Revealed* (Intellego
     Vim) is already a Vim spell itself, so there is no more-general
     guideline to point it at by analogy — confirmed by checking the
     arithmetic of its own Form's only General row (`invi-G`), which
     computes a structurally different quantity (a small residual-magnitude
     count, not a level threshold).
   ```
   (This keeps the earlier historical narrative in item 25's body — the
   "Four of the 33 remain blocked" framing and its per-spell derivation
   bullets are the specific text being replaced; the surrounding "What
   landed and still binds" section above it and the "Spec/Plan"/"Files"
   lines below it are unaffected.)

- [ ] **Step 12: Commit**

```bash
git add scripts/spell_import/exceptions.py scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_extract.py assets/data/spell_exceptions.json .superpowers/todo.md
git commit -m "feat: add The Invisible Eye Revealed as an exception spell

Closes out todo item 25 -- all 4 remaining blocked spells now import.
This one is already Intellego Vim itself (nowhere more general to
point to by analogy), and its own Form's only General row computes a
structurally different quantity, checked numerically not just by
wording.

See docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md."
```
