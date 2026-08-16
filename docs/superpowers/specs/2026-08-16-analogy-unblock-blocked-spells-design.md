# Unblock 3 of the 4 Remaining Blocked Spells via Base-Effect Analogy — Design

**Status:** Approved (decisions confirmed by the user 2026-08-16, see "Decisions" below)

## Goal

Use the base-effect analogy capability (`Spell`/`SpellTemplate.technique`/`.form` +
`analogyRationale`, merged to `main` 2026-08-16,
`docs/superpowers/plans/2026-08-16-base-effect-analogy.md`) to unblock 3 of the
4 spells `.superpowers/todo.md` item 25 documents as permanently blocked:

- *Dispel the Phantom Image* (Perdo Imaginem)
- *Restore the Moved Image* (Rego Imaginem)
- *Lay to Rest the Haunting Spirit* (Perdo Mentem)

*The Invisible Eye Revealed* (Intellego Vim) is explicitly **out of scope** —
see "Why the 4th spell stays blocked" below.

This is importer + data work only. No Dart model or engine change: the
`GeneralEffectFormula` machinery (`targetSpellLevel`, `mightReduction`,
`offsetMagnitudes`, `stressDie`) that renders each donor guideline's effect
sentence already exists and needs nothing new.

## Background: why these three are blocked today

All three are General-guideline spells (rulebook heading `#### GENERAL`, design
line `(Base effect)`, no printed numeric level) whose own Technique+Form
guideline table has no row that actually describes their mechanic:

- **Perdo Imaginem's and Perdo Mentem's own tables print no General row at
  all.** *Dispel the Phantom Image* and *Lay to Rest the Haunting Spirit* hit
  `extract_spells.py`'s `general_candidates` **empty** branch and are
  unconditionally blocked (`extract_spells.py:552-577`).
- **Rego Imaginem's table prints one General row, but it's the wrong
  guideline.** `reim-G` is Rego Imaginem's *ward* guideline (Touch/Ring/Circle
  against a supernatural realm) — *Restore the Moved Image* isn't a ward. This
  spell is listed in `DESIGN_LINE_INCOMPLETE`
  (`extract_spells.py:175-183`) and unconditionally blocked.

Each of the three is a Form-specific, un-tabulated echo of a mechanic the
Definitive Edition *does* generalize — with a magnitude offset — at the Vim
level:

| Spell | Own text (paraphrased) | Vim donor | Vim's own text |
|---|---|---|---|
| *Dispel the Phantom Image* | Destroys a CrIm spell's image, matched on a stress die + this spell's level | `pevi-G2` | Dispel a specific type of effect, level ≤ this spell's level + **4 magnitudes** + stress die |
| *Restore the Moved Image* | Cancels a ReIm spell, matched on a stress die + this spell's level | `revi-G2` | Sustain/suppress a spell you cast, level ≤ this spell's level + **2 magnitudes** |
| *Lay to Rest the Haunting Spirit* | Reduces a spirit's Might by this spell's level | `pevi-G3` | Reduce target's Might by this spell's level + **2 magnitudes** |

Building a *new* catalog row in each spell's own Form (`peim-gen`, `reim-gen2`,
`peme-gen`) was tried before (for `peme-G`/`inco-gen`, a different spell) and
reverted: `test_general_catalog.GeneralCatalogTest.
test_general_entries_match_the_rulebook_bullet_for_bullet` holds the catalog
to the rulebook's own printed guideline bullets, in both directions,
permanently. That constraint is exactly what the analogy feature exists to
route around — the spell keeps its own real Technique/Form, but its
`baseEffectId` points at the existing Vim row, with `analogyRationale`
recording the derivation.

## Decisions

Three judgment calls, confirmed by the user 2026-08-16:

1. **Formula fidelity: use each Vim donor's formula unmodified**, including
   its `offsetMagnitudes`/`stressDie`. None of the three published spells'
   own text matches the donor bullet-for-bullet (each is a slightly narrower,
   one-off version), and the shipped schema has no per-spell formula-override
   field — building one is out of scope for this fix. The resulting template
   expresses the *generalized* Vim-analogy rule (available to a caster
   inventing a *new* spell from it), not a literal reproduction of the one
   canonical spell's abbreviated numbers. This matches how every other
   General template in the corpus already works: the template carries the
   guideline's formula, not one example spell's specific wording.
2. **Pre-fill `chosenSlots.specificType = "Creo Imaginem"`** for *Dispel the
   Phantom Image* (`pevi-G2` has an open `specificType` slot). Its own text
   unambiguously commits to it ("any one CrIm spell"), unlike a genuinely
   open template — the same reasoning `REALM_BY_SPELL_ID` already applies to
   wards whose text names a specific realm (e.g. *Circular Ward against
   Demons* → `"Infernal"`).
3. **Scope stays at 3 of 4** — *The Invisible Eye Revealed* is not touched
   this round.

### Why the 4th spell stays blocked

*The Invisible Eye Revealed* is printed under **Intellego Vim → GENERAL** —
it is *already* a Vim spell. The analogy mechanism unblocks a Form-specific
spell by pointing it at a *more general* guideline one Technique/Form up the
chain (Form → Vim). There is nothing more general than Vim to point to. Its
own table's only General row, `invi-G` ("detect spell traces of negative
magnitude"), is a real but different mechanic (residual traces of *past*
magic, not detecting a *live* spying spell) — already excluded as the wrong
candidate via `KNOWN_UNRESOLVABLE`-equivalent handling
(`DESIGN_LINE_INCOMPLETE["lib-invi-invisible-eye-revealed"]`). Building a new
InVi catalog row for its actual mechanic is exactly what
`test_general_entries_match_the_rulebook_bullet_for_bullet` forbids. This
spell's status in `.superpowers/todo.md` item 25 does not change.

## Implementation

All changes in `scripts/spell_import/extract_spells.py` and
`scripts/spell_import/emit.py`; regenerate `assets/data/spell_templates.json`.

### 1. New table: `ANALOGY_BASE_EFFECTS`

In `extract_spells.py`, alongside `NUMBERED_OVERRIDES`/`HAND_DERIVED`:

```python
# Spells whose own Technique/Form guideline table has no matching General
# row, resolved instead by pointing at an existing Vim-level General row
# that generalizes the same mechanic with a magnitude offset -- see
# docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.
# Checked before the general_candidates empty/DESIGN_LINE_INCOMPLETE
# handling below, so it takes precedence over both.
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

(All three `lib-` slugs above are confirmed exact — verified directly via
`catalog_module.slug_id(technique, form, name)` for each spell, 2026-08-16.)

### 2. Route the three spells through it

In `extract_spells.py`'s General-spell branch, immediately after computing
`general_candidates` (`extract_spells.py:550`) and before the `if not
general_candidates:` check:

```python
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
```

This takes precedence over both the empty-`general_candidates` block (which
currently blocks *Dispel the Phantom Image* / *Lay to Rest the Haunting
Spirit* unconditionally) and `DESIGN_LINE_INCOMPLETE` (which currently blocks
*Restore the Moved Image*). Remove
`"lib-reim-restore-moved-image"` from `DESIGN_LINE_INCOMPLETE`
(`extract_spells.py:176-177`) — it's now handled here instead, and a stale
entry would be dead code. **Leave `"lib-invi-invisible-eye-revealed"` in
`DESIGN_LINE_INCOMPLETE` untouched.**

### 3. `emit.build_template` gains a `chosen_slots` parameter

`scripts/spell_import/emit.py:252-329`. New optional parameter, merged
alongside the existing `realm_by_spell_id`-derived slot, guarded the same way
(only applied if the base effect actually declares that slot open — mirrors
the existing `"realm" in catalog.open_slots(base_effect_id)` guard at
`emit.py:288`):

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
    ...
    realm_by_spell_id = realm_by_spell_id or {}
    resolved_slots: dict[str, str] = {}
    realm = realm_by_spell_id.get(slug)
    if realm is not None and "realm" in catalog.open_slots(base_effect_id):
        resolved_slots["realm"] = realm
    if chosen_slots:
        open_kinds = catalog.open_slots(base_effect_id)
        resolved_slots.update({
            kind: value for kind, value in chosen_slots.items()
            if kind in open_kinds
        })
    ...
    if resolved_slots:
        template["chosenSlots"] = resolved_slots
```

(Renaming the existing local `chosen_slots` variable to `resolved_slots`
avoids a name collision with the new parameter — exact naming is an
implementation detail for the plan.)

### 4. Update the surrounding comment blocks

`extract_spells.py:106-183` (the `REALM_BY_SPELL_ID`/`DESIGN_LINE_INCOMPLETE`
preambles) currently describe all four spells as a single permanently-blocked
family. Rewrite to state plainly: 3 of the 4 now resolve via
`ANALOGY_BASE_EFFECTS` (with a pointer to this spec), and *The Invisible Eye
Revealed* is the one that remains — because it's already Vim, not because
the reasoning doesn't extend to it. Do the same for the `general_candidates`
empty-branch comment (`extract_spells.py:552-577`), which currently names
*Dispel the Phantom Image* and *Lay to Rest the Haunting Spirit* as
permanently blocked.

### 5. `.superpowers/todo.md` item 25

Once verified, update item 25's body: move the three from "remain blocked"
into a new "✅ unblocked via base-effect analogy, 2026-08-16" note (mirroring
how items 46/28/39 record their closures), citing this spec and the base
effect analogy plan. *The Invisible Eye Revealed* keeps its existing
"permanent, settled" documentation, trimmed to no longer imply the other
three share its fate.

### 6. Regenerate and verify

`python -m scripts.spell_import.extract_spells --write`, then:

- `--show-blocked` count drops from 4 to 1 (only *The Invisible Eye
  Revealed* remains).
- The three new templates appear in `assets/data/spell_templates.json`, each
  with `technique`/`form` matching the spell's own printed Form (not the
  donor's), a non-null `analogyRationale`, and (for *Dispel the Phantom
  Image* only) `chosenSlots: {"specificType": "Creo Imaginem"}`.
- Both test suites green: `python -m unittest discover`, `flutter test`.
- `test_general_entries_match_the_rulebook_bullet_for_bullet` still passes
  unmodified — no new catalog row is added, only new pointers to existing
  rows.

## Testing

- Python: extend `scripts/spell_import/tests/test_extract.py` with one case
  per newly-unblocked spell, asserting the produced template's
  `baseEffectId`, `technique`/`form`, non-null `analogyRationale`, and (for
  *Dispel the Phantom Image*) `chosenSlots`.
- A Python unit test for `emit.build_template`'s new `chosen_slots`
  parameter: the open-slot guard (unknown slot kind silently dropped),
  matching the existing `realm_by_spell_id` guard's test coverage.
- No new Dart tests are needed — `validateSpellAgainstCatalog`'s check 8
  (rationale required exactly when technique/form diverges) and the existing
  `published_spell_import_test.dart` assertions already cover the resulting
  templates once the asset is regenerated, the same way they cover every
  other General template.

## Out of scope

- *The Invisible Eye Revealed* (see above).
- The 4 candidate spells this session's earlier base-effect-analogy plan
  scoped out (`.superpowers/todo.md` item 48's own "explicitly not done"
  note) are unaffected — this spec's 3 spells are a *different* set from
  that plan's originally-motivating 4.
- Creation-screen UI for picking a cross-Form base effect — still deferred,
  unchanged from the merged plan's scope.
