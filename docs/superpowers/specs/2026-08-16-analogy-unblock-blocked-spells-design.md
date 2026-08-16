# Unblock All 4 Remaining Blocked Spells — Design

**Status:** Approved (decisions confirmed by the user 2026-08-16, see "Decisions"
below; extended 2026-08-16 to cover the 4th spell as an exception spell
rather than leaving it blocked); **scope reduced 2026-08-16 during
implementation** — see "Mid-implementation finding: `pevi-G2`'s offset is
suspect" below. This round now unblocks 3 of the 4 (2 via analogy, 1 via
exception); *Dispel the Phantom Image* is parked, still blocked, pending a
separate audit.

## Goal

Clear as much of `.superpowers/todo.md` item 25's "permanently blocked" list
as can be resolved with confidence, using two different mechanisms for two
genuinely different problems:

- **2 spells unblocked via the base-effect analogy capability**
  (`Spell`/`SpellTemplate.technique`/`.form` + `analogyRationale`, merged to
  `main` 2026-08-16, `docs/superpowers/plans/2026-08-16-base-effect-analogy.md`):
  - *Restore the Moved Image* (Rego Imaginem)
  - *Lay to Rest the Haunting Spirit* (Perdo Mentem)
- **1 spell recorded as an exception spell** (`scripts/spell_import/exceptions.py`,
  the same closed-table mechanism already used for *Sight of the True Form*
  and 6 others — `docs/superpowers/specs/2026-08-15-exception-spells-design.md`'s
  third shape, "the guideline was never printed in that Technique/Form's own
  table at all"):
  - *The Invisible Eye Revealed* (Intellego Vim) — see "The 4th spell: exception,
    not analogy" below for why it needs the other mechanism.
- **1 spell parked, still blocked:** *Dispel the Phantom Image* (Perdo
  Imaginem) — its analogy donor's own catalog data (`pevi-G2`) doesn't hold
  up under verification. See "Mid-implementation finding" below. Not a new
  permanent blocker verdict — item 25's existing "permanently blocked"
  framing for this one spell is now superseded by "blocked pending a
  `pevi-G2` data audit," a narrower, actionable gap.

This is importer + data work only, for both mechanisms. No Dart model or
engine change: the `GeneralEffectFormula` machinery (`targetSpellLevel`,
`mightReduction`, `offsetMagnitudes`, `stressDie`) that renders each donor
guideline's effect sentence, and `ExceptionSpell`/`build_exception_spell`,
both already exist and need nothing new at the model/engine layer.

## Mid-implementation finding: `pevi-G2`'s offset is suspect

Found while implementing Task 2, verifying `ReferenceOracleTest`'s failure
against all three planned analogy spells rather than just silencing it.

**`revi-G2` and `pevi-G3` (offset 2) check out.** Every existing template
built on either — *Demon's Eternal Oblivion* (`pevi-G3`, Voice = 2
magnitudes), *Maintaining the Demanding Spell* (`revi-G2`, Touch + Diameter
= 1+1 = 2 magnitudes), *Suppressing the Wizard's Handiwork* (`revi-G2`,
Touch + Concentration = 1+1 = 2 magnitudes) — invests exactly 2 magnitudes
of Range/Duration/Target, no matter which parameters it spends them on. That
isn't a coincidence repeating three times; it confirms the "+2 magnitudes"
these guidelines grant is calibrated against real spells that always spend
exactly that much reaching their target. *Restore the Moved Image* and *Lay
to Rest the Haunting Spirit* fit the same shape (both printed at Voice, 2
magnitudes) and are confirmed correct to route through `ANALOGY_BASE_EFFECTS`
using `revi-G2`/`pevi-G3` unmodified, per Decision 1.

**`pevi-G2` (offset 4) does not.** Its own worked example, *Unravelling the
Fabric of (Form)*, is built at Voice (2 magnitudes, matching its design
line's explicit "+2 Voice") — but its own prose states its dispel threshold
as *"spell level + 10 + stress die"*, and 10 is 2 magnitudes, not 4.
`pevi-G2`'s guideline-table row says "+4 magnitudes"; the one real spell
built on it behaves like +2. These can't both be right. Candidate
explanations, neither confirmed:
- `base_effects.json`'s `pevi-G2.effectFormula.offsetMagnitudes` is a
  pre-existing data error (should be `2`, not `4`) — from the earlier
  2026-08-05 general-base-effects plan, unrelated to this one.
- Something about how "+4 magnitudes" in the guideline table's abstract
  formula relates to "+10" in a concrete worked example isn't understood
  correctly yet — needs its own investigation before trusting either number.

**Decision (user, 2026-08-16): proceed with the 2 confirmed spells now,
park *Dispel the Phantom Image*.** It stays blocked — not as a new
permanent verdict, but pending a focused audit of `pevi-G2`'s
`offsetMagnitudes` (and, once that's resolved, of every other
`GeneralEffectFormula` entry the same 2026-08-05 plan produced, since this
was found by spot-checking, not an exhaustive pass). That audit is
out of scope for this plan. Task 1's `chosen_slots` parameter on
`emit.build_template` (built for this spell's `specificType` slot) stays
landed and independently tested — it just goes unused by this plan's data
for now, the same "wire the capability, don't exercise it yet" shape the
codebase already carries elsewhere (e.g. `TechniqueFormRegenerationTest`
before this plan's own Task 2 landed).

**A hypothesis for the future audit, recorded but not pursued here (user,
2026-08-16):** the "+4 magnitudes" vs. "+10" gap may be a simplification
specific to spells at level ≥5 — `SpellLevelCalculator`'s own additive-vs-
multiplicative split treats the 1-5 tier differently from everything above
it (see its comment at `spell_engine.dart` and the "Global Constraints"
note in the base-effect-analogy plan). Whether that tier boundary is what
produced the "+10" figure in *Unravelling the Fabric*'s prose — as opposed
to a plain data-entry error in `offsetMagnitudes` — is exactly what the
future audit needs to check first.

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

Three judgment calls, confirmed by the user 2026-08-16 — **the first is now
verified, not just asserted, for the 2 spells this round actually uses it
for** (see "Mid-implementation finding" above; item 2 is deferred along with
*Dispel the Phantom Image*, unused by this round's data):

1. **Formula fidelity: use each Vim donor's formula unmodified**, including
   its `offsetMagnitudes`/`stressDie`. Originally framed as "the schema has
   no override field, so accept the generalized rule even where it doesn't
   match the one canonical spell's numbers" — implementation-time
   verification found something stronger for `revi-G2`/`pevi-G3`: their
   offsets are not just an accepted approximation, they're independently
   confirmed correct against every existing spell built on them (see above).
   `pevi-G2` is the one where "accept it unmodified" would have been
   actually wrong, not just imprecise — which is why it's parked rather than
   shipped this round.
2. **Pre-fill `chosenSlots.specificType = "Creo Imaginem"`** for *Dispel the
   Phantom Image* (`pevi-G2` has an open `specificType` slot) — **deferred
   along with the spell itself.** Task 1's `chosen_slots` parameter on
   `emit.build_template` still exists and is tested standalone; this
   specific data usage of it waits for the `pevi-G2` audit.
3. **The 4th spell is fixed too, but via the exception-spell mechanism, not
   analogy** — see below.

### The 4th spell: exception, not analogy

*The Invisible Eye Revealed* is printed under **Intellego Vim → GENERAL** —
it is *already* a Vim spell. The analogy mechanism unblocks a Form-specific
spell by pointing it at a *more general* guideline one Technique/Form up the
chain (Form → Vim). There is nothing more general than Vim to point to. Its
own table's only General row, `invi-G` ("detect spell traces of negative
magnitude"), computes a genuinely different quantity — checked numerically,
not just by wording: at level 20, `invi-G`'s formula produces a magnitude
count of 2, while this spell needs a level threshold of 40 ("double the
level of this spell"). Different `GeneralEffectKind` families
(`spellTraceMagnitude` vs. `targetSpellLevel`), off by roughly an order of
magnitude at every level — not a close-enough match. Building a new InVi
catalog row for its actual mechanic is exactly what
`test_general_entries_match_the_rulebook_bullet_for_bullet` forbids, the same
constraint that already forced *Sight of the True Form* (a different spell,
same shape: General-kind, no matching row in its own Form's table) to become
an exception spell rather than getting a fabricated catalog row.

*The Invisible Eye Revealed* fits the exact same shape *Sight of the True
Form* already established: General-kind, no printed level, and its own
Form's guideline table genuinely has no row for its mechanic (the one row
that exists, `invi-G`, is confirmed the wrong guideline above, not merely
unchecked). It is recorded as free-text `ExceptionSpell` data — no
`baseEffectId` at all — with a citation-backed rationale, exactly like
*Sight of the True Form*, *Watching Ward*, and the other five entries in
`exceptions.EXCEPTION_SPELLS`.

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
#
# Dispel the Phantom Image (Perdo Imaginem, would point at pevi-G2) is
# deliberately NOT here. pevi-G2's own offsetMagnitudes (4) doesn't survive
# verification against its own worked example (Unravelling the Fabric of
# (Form) states "+10", i.e. 2 magnitudes, not 4) -- see the spec's
# "Mid-implementation finding" section. It stays blocked pending a
# pevi-G2/offsetMagnitudes audit, not shipped on an unverified number.
ANALOGY_BASE_EFFECTS: dict[str, dict] = {
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

### 2. Route the two spells through it

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
still unconditionally blocks *Lay to Rest the Haunting Spirit* — it's in
`ANALOGY_BASE_EFFECTS` now, so it's caught before ever reaching that block;
*Dispel the Phantom Image* is deliberately absent from
`ANALOGY_BASE_EFFECTS`, so it still falls through to and is still blocked by
that same empty-`general_candidates` check, unchanged) and
`DESIGN_LINE_INCOMPLETE` (which currently blocks *Restore the Moved Image*).
Remove `"lib-reim-restore-moved-image"` from `DESIGN_LINE_INCOMPLETE`
(`extract_spells.py:176-177`) — it's now handled here instead, and a stale
entry would be dead code. **Leave `"lib-invi-invisible-eye-revealed"` in
`DESIGN_LINE_INCOMPLETE` untouched** (Task 3 removes it).

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

### 4. Add *The Invisible Eye Revealed* to `exceptions.EXCEPTION_SPELLS`

In `scripts/spell_import/exceptions.py`, one new entry, same table shape as
the existing 7 — no new code, this dict is already checked first thing in
`extract_spells.py`'s main loop (`extract_spells.py:493-497`,
`if block.name in exceptions_module.EXCEPTION_SPELLS: ... continue`), before
any of the `ANALOGY_BASE_EFFECTS`/`general_candidates`/`DESIGN_LINE_INCOMPLETE`
handling above is ever reached:

```python
"The Invisible Eye Revealed": (
    "Design line prints \"(Base effect)\", General-kind, no printed level. "
    "Intellego Vim's own guideline table prints exactly one General row, "
    "invi-G (\"detect the traces of magic of negative magnitude up to the "
    "magnitude of the guideline used - 2\") -- a residual-trace-decay "
    "formula, confirmed the wrong guideline by checking the arithmetic, not "
    "just the wording: at level 20 invi-G computes a magnitude of 2, while "
    "this spell's own text (\"detects the use of Intellego spells of up to "
    "double the level of this spell\") needs a level threshold of 40 -- "
    "different GeneralEffectKind families "
    "(spellTraceMagnitude vs. targetSpellLevel), not a close-enough match. "
    "No other Form's guideline can substitute by analogy either: this spell "
    "is already Intellego Vim, the top of the analogy chain. Same shape as "
    "Sight of the True Form (see that entry) -- a matching InVi row was not "
    "attempted here for the identical reason: "
    "test_general_entries_match_the_rulebook_bullet_for_bullet forbids it."
),
```

**Remove `"lib-invi-invisible-eye-revealed"` from `DESIGN_LINE_INCOMPLETE`**
(`extract_spells.py:178-179`) — the `EXCEPTION_SPELLS` check above now
intercepts this spell before the loop ever reaches `DESIGN_LINE_INCOMPLETE`,
so the entry is dead. Leave a one-line pointer comment, matching the existing
"Wizard's Communion used to be here" precedent in the same dict's docstring.

**Fix the stale cross-reference in *Sight of the True Form*'s own entry**
(`exceptions.py`): its rationale currently reads "...the same policy that
keeps Dispel the Phantom Image, Lay to Rest the Haunting Spirit, Restore the
Moved Image and The Invisible Eye Revealed blocked rather than exceptions
(see todo item 25 for why those four stay blocked and this one does not)."
That sentence needs correcting, not just retiring — 2 of the 4 (*Restore the
Moved Image*, *Lay to Rest the Haunting Spirit*) resolve via analogy this
round, *The Invisible Eye Revealed* becomes an exception spell alongside it,
and *Dispel the Phantom Image* is the one still genuinely blocked (now for a
narrower, documented reason — a suspect catalog value, not "no guideline
exists"). Replace with a pointer to this spec instead of re-deriving the
(now differentiated) status of each spell inline.

### 5. Update the surrounding comment blocks

`extract_spells.py:106-183` (the `REALM_BY_SPELL_ID`/`DESIGN_LINE_INCOMPLETE`
preambles) currently describe all four spells as a single permanently-blocked
family. Rewrite to state plainly: 2 of the 4 now resolve via
`ANALOGY_BASE_EFFECTS`, a 3rd via `exceptions.EXCEPTION_SPELLS` — all with a
pointer to this spec — and *Dispel the Phantom Image* remains blocked, but
now for the specific, narrower `pevi-G2` reason recorded in this spec's
"Mid-implementation finding" section, not the original "no guideline
exists" framing. Do the same for the `general_candidates` empty-branch
comment (`extract_spells.py:552-577`), which currently names *Dispel the
Phantom Image* and *Lay to Rest the Haunting Spirit* together as
permanently blocked — only the latter's mention needs updating now.

### 6. `.superpowers/todo.md` item 25

Once verified, update item 25's body: **3 of the 4** move from "remain
blocked" into a new "✅ unblocked, 2026-08-16" note (mirroring how items
46/28/39 record their closures) — 2 via base-effect analogy, 1 as an
exception spell — citing this spec. *Dispel the Phantom Image* gets its own
updated note: still blocked, but reason narrowed from "no Perdo Imaginem
General row" to "pevi-G2's own offsetMagnitudes doesn't survive
verification against its worked example — see this spec's
Mid-implementation finding for the audit this needs." The "Where the import
stands" table at the top of the file also needs its blocked-count row
corrected (4 → 1) and the exception-spell count row incremented (7 → 8).

### 7. Regenerate and verify

`python -m scripts.spell_import.extract_spells --write`, then:

- `--show-blocked` count drops from 4 to **1** (*Dispel the Phantom Image*
  only).
- The two new templates appear in `assets/data/spell_templates.json`, each
  with `technique`/`form` matching the spell's own printed Form (not the
  donor's) and a non-null `analogyRationale`.
- *The Invisible Eye Revealed* appears in `assets/data/spell_exceptions.json`
  (8 entries, was 7), with `technique: "Intellego"`, `form: "Vim"`, and the
  rationale above.
- Both test suites green: `python -m unittest discover`, `flutter test`.
- `test_general_entries_match_the_rulebook_bullet_for_bullet` still passes
  unmodified — no new catalog row is added anywhere, only new pointers to
  existing rows plus one new exception entry.

## Testing

- Python: extend `scripts/spell_import/tests/test_extract.py` with one case
  per newly-unblocked spell (the 2 analogy templates plus *The Invisible Eye
  Revealed*'s exception entry), asserting the produced record's
  `baseEffectId`/`technique`/`form`/`analogyRationale` (analogy templates) or
  `technique`/`form`/`rationale` with no `baseEffectId` at all (the
  exception spell). Also assert *Dispel the Phantom Image* is still reported
  blocked (a staleness guard, same shape as `GeneralBlockedStalenessTest`) —
  it must fail loudly, not silently pass, if the `pevi-G2` audit later
  unblocks it without this test being updated.
- A Python unit test for `emit.build_template`'s new `chosen_slots`
  parameter, exercised standalone (not through `ANALOGY_BASE_EFFECTS`, which
  doesn't use it this round): the open-slot guard (unknown slot kind
  silently dropped), matching the existing `realm_by_spell_id` guard's test
  coverage.
- No new test is needed for `build_exception_spell` itself — it is unchanged
  code, already covered by the 7 existing exception spells' tests.
- No new Dart tests are needed — `validateSpellAgainstCatalog`'s check 8
  (rationale required exactly when technique/form diverges) and the existing
  `published_spell_import_test.dart` assertions already cover the resulting
  templates once the asset is regenerated, the same way they cover every
  other General template and exception spell.

## Out of scope

- *Dispel the Phantom Image* and the `pevi-G2`/`offsetMagnitudes` audit it
  needs — see "Mid-implementation finding" above. Deliberately parked, not
  forgotten: a follow-up item, not a silent drop.
- The 4 candidate spells this session's earlier base-effect-analogy plan
  scoped out (`.superpowers/todo.md` item 48's own "explicitly not done"
  note) are unaffected — this spec's spells are a *different* set from that
  plan's originally-motivating 4.
- Creation-screen UI for picking a cross-Form base effect — still deferred,
  unchanged from the merged plan's scope.
- No change to `ExceptionSpell`'s model or `build_exception_spell` — *The
  Invisible Eye Revealed* uses that mechanism exactly as it already exists.
