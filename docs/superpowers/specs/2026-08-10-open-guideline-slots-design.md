# Open Guideline Slots: realm, Form, and "a specific type"

**Todo items:** 35 ("A Guideline's Realm Is a Choice, Like Its Level") and 37
("A Template Has Open Slots Beyond Its Level — Realm, Form, 'Specific Type'"),
designed together per item 37's own framing — 37 generalises 35, and item 40's
spec (decision 7) already rejected batching a *different* piece of work with
these two on the grounds that their design question was still open. It no
longer is.

**Status:** designed 2026-08-10

**Rulebook:** Core Rules Chapter 9 guideline tables; specific citations inline
below.

---

## Problem

A General guideline's *level* is the one slot the model already treats as the
caster's to fill (`Spell.chosenBaseLevel`, item 25). Three more slots the
rulebook leaves open the same way have no representation at all:

- **Realm** — "Ward against beings... from one supernatural realm (Divine,
  Faerie, Infernal, or Magic)" (12 ward guidelines, plus `pevi-G6`, `pevi-G12`,
  `pevi-G5`, `revi-G1`; and two fixed-level Rego Vim rows, `revi-5`/`revi-15`).
  **17 catalog entries total** — verified against the rulebook text directly,
  superseding both prior counts (see Decision 1).
- **"A specific type"** — "Dispel effects of a specific type... a specific
  type could be Hermetic Terram magic, or Shamanic spirit control magic"
  (`pevi-G2`, `pevi-G7`, `pevi-G10`, `revi-G5` — 4 entries).
- **Form** — `pevi-G10`'s alternative branch ("a particular Hermetic Form **or**
  a specific type of enchantment") and the near-identical Form-Resistance
  bullet; plus three published Muto Vim spells (*Mirror of Opposition*,
  *Wizard's Boost*, *Wizard's Reach*) whose own prose says the guideline "comes
  in ten versions, each affecting spells of one of the Hermetic forms" without
  the catalog guideline itself mentioning Form at all.

`BaseEffect` has no concept of any of this. `SpellTemplate` is `Spell` minus
`chosenBaseLevel`/`printedLevel`/`templateId` and has nowhere to hold a slot
either. **Neither realm nor the case-2 Form spells are a blocked-import
problem** — 6 ward templates and one oddity (`Wind of Mundane Silence`)
already import successfully today without any realm data (Decision 10), and
the three Muto Vim "ten versions" spells (`Mirror of Opposition`, `Wizard's
Boost`, `Wizard's Reach`) already import successfully today as templates too,
without any Form data (Decision 11). Both parts are backfilling `chosenSlots`
onto already-working templates, not unblocking anything.

### Why realm is not simply "chosenBaseLevel again"

For a *published* spell, the realm is not actually the caster's choice — it's
already decided by which named spell you're looking at. "Circular Ward against
Demons" (Rego Vim, General, Core Rules ~line 15938) commits to Infernal in its
own prose — "creatures with **Infernal** Might" — while its level stays
genuinely open, because that's what "General" means. The realm also does not
feed `SpellEngine`'s level math anywhere; it is purely the fact that keeps two
otherwise-identical wards distinguishable.

So the slot is filled by two different parties depending on the path:

- **A published spell whose prose commits to a value** (nearly all 17 realm
  entries): the importer reads it and bakes it onto the emitted
  `SpellTemplate`, the same way it already bakes down technique/form/baseEffectId.
- **A guideline used directly to build a brand-new custom spell**, or a
  published entry that is genuinely a family with no single committed value
  (the three Form case-2 spells): nothing to inherit from — the caster fills it,
  exactly like `chosenBaseLevel` today.

Both paths write the same field. Nothing downstream needs to know which one
happened.

---

## Decisions taken

Recorded here because each was a fork with a defensible other side.

| # | Decision | Rationale |
|---|---|---|
| 1 | **The realm count is 17, not 14 or 16** | Item 35's original count (14) and item 37's rescan (15, adding `pevi-G5`) both undercounted General entries because item 35's count was a JSON keyword search over `base_effects.json`, whose stored description for `pevi-G5` drops the words "of one realm" during extraction (an item-22-shaped gap, not fixed here). Reading the rulebook prose directly gives 15 General + 2 fixed-level (`revi-5`, `revi-15`) = 17. This is the authoritative count going forward. |
| 2 | **One field shape (`openSlots`/`chosenSlots`) serves both "importer-filled" and "caster-filled" cases** | A second, parallel mechanism for "the value is already known" would double the plumbing for no behavioral gain — validation, storage, and display don't care who filled the map. |
| 3 | **`chosenSlots` is a `Map<String, String>`, not three bespoke fields** | Matches item 40 Part B's requisites-map precedent: a general shape absorbs `pevi-G10`'s two-alternative-kinds case for free (both are just entries the map may or may not have), where three bespoke nullable fields would need an extra "which one is live" flag. Paid once, not three times, per the plumbing-cost argument item 37 already made about `copyWith`/bloc/UI. |
| 4 | **"Specific type" is free text, not a closed set** | The rulebook gives illustrative examples ("could be X, or Y"), not an exhaustive list. A closed set risks rejecting a legitimate type the rulebook simply didn't happen to list. |
| 5 | **An open slot is mandatory, like `chosenBaseLevel`** | "A ward with no realm chosen is not yet a spell" is the identical argument that already governs the level check — completeness of the spell record, not a numeric dependency. |
| 6 | **Validation requires *at least one* of an effect's declared `openSlots` kinds to be filled, not all of them** | Collapses correctly to "this one is mandatory" for every entry except `pevi-G10`, and handles `pevi-G10`'s either/or without a special case. No entry found in this audit needs two slots filled simultaneously; if one surfaces later, this rule is revisited then. |
| 7 | **Realm is resolved by a small hand-maintained table, not a prose scan** | A prose scan was the first idea, and the real corpus breaks it: "Ward against Faeries of the Air/Wood" don't restate "Faerie" in their own body text at all (they cross-reference "Ward against Faeries of the Waters" by name instead), and `Wind of Mundane Silence` (`pevi-G5`) contains the bare word "Magic" only via "Magic Resistance"/"Magical things" — neither a realm commitment — which a naive scan would misread as "Magic realm" with false confidence. A hand-verified table (mirroring `KNOWN_UNRESOLVABLE` in `extract_spells.py` exactly) sidesteps both failure modes: each entry is a human judgment call recorded once, not a heuristic guessing at prose. See Decision 9. |
| 8 | **Design covers all three slot kinds now; implementation splits into two plans** | Designing only realm and revisiting Form/"specific type" later would risk re-picking the wire shape and re-serializing both assets a second time — the exact risk item 40's spec flagged when it rejected batching with these items. Splitting *implementation* (not design) still keeps each plan reviewably sized, mirroring item 40's own Part A/B split. |
| 9 | **A template's `chosenSlots` may stay empty even for a declared-open kind, with no error** | `SpellTemplate` carries no write-boundary validation (checks 6/7 apply to `Spell`/`SpellDraft` only — see Decision 5's "Design" section). `Wind of Mundane Silence` is deliberately left out of the realm table for exactly this reason: it doesn't commit to one realm, so its template imports with `chosenSlots: {}`, and a caster fills the realm in later, the same as any case-2 spell. No override table entry, no error, no blocked import — the mechanism already handles "genuinely undecided" for free. |
| 10 | **6 of the 17 realm entries are already-imported templates, not blocked spells** | Checked directly against `assets/data/spell_templates.json`: `Circular Ward against Demons`, `Ward against the Beasts of Legend`, `Ward against Faeries of the Waters/Air/Wood`, and `Ring of Warding against Spirits` import successfully today. `Wind of Mundane Silence` also already imports (Decision 9 covers why it gets no table entry). The remaining 10 catalog entries have no corpus spell referencing them yet. Part A's import work is backfilling `chosenSlots` onto the 7 existing templates via the hand-table, not unblocking anything. |
| 11 | **The 3 case-2 Muto Vim spells are also already-imported templates, not blocked** | Checked directly against `assets/data/spell_templates.json` (2026-08-14, re-verified before Part B planning): `tpl-muvi-mirror-opposition-form`, `tpl-muvi-wizards-boost-form`, and `tpl-muvi-wizards-reach-form` all exist and import successfully today — `muvi-G1/G2/G3`'s import path was never blocked by the missing Form concept, it simply produced a template with no Form data. This corrects both this spec's original Problem framing and the earlier "currently-blocked Muto Vim spells" phrasing in the Scope table below — Part B is annotating `muvi-G2`/`muvi-G3` (`muvi-G1` has no corpus spell referencing it yet) and backfilling 3 existing templates' `chosenSlots`, the same shape of work as Part A's realm backfill, not an unblocking operation. |
| 12 | **`openSlots` stays declared per-guideline even where one guideline serves both Form-restricted and Form-agnostic spells** | `muvi-G2` is used by `Wizard's Boost`/`Wizard's Reach` (Form-restricted, "ten versions, one per Form") **and** by `The Sorcerer's Fork` (already in the corpus, Form-agnostic prose — no Form mention at all). Declaring `openSlots: [form]` on `muvi-G2` is harmless for every corpus use today (all three are templates, and templates never need the slot filled — Decision 9) but would force a Form choice on a hypothetical brand-new custom spell a user builds directly on `muvi-G2` in the shape of `Sorcerer's Fork`, even though that shape doesn't conceptually need one. **Accepted as a narrow, non-blocking rough edge** (human decision, 2026-08-14) rather than redesigning `openSlots` to be scoped finer than the guideline — no corpus spell is affected, and a finer-grained scope would revisit Decision 3's "one map on the record" shape for a case that has not actually occurred yet. |

---

## Design

### Data model

`OpenSlotKind` — new enum in `lib/models/base_effect.dart`, alongside
`RitualRequirement`:

```dart
enum OpenSlotKind { realm, form, specificType }
```

`BaseEffect.openSlots: List<OpenSlotKind>` — new field, `const []` default.
Empty for all but the annotated entries. `pevi-G10` gets
`[OpenSlotKind.form, OpenSlotKind.specificType]` (either satisfies it); every
other affected entry gets a single-element list.

`chosenSlots: Map<String, String>` — new field on `Spell`, `SpellDraft`, and
`SpellTemplate`, keyed by `OpenSlotKind.name` (`'realm'`, `'form'`,
`'specificType'`), defaulting to `{}`. Wire shape:
`"chosenSlots": {"realm": "Infernal"}`.

### Validation

Two new checks in `validateSpellAgainstCatalog` (`spell.dart`), continuing the
existing numbered-check comment convention (checks 1, 2, 3, 5 exist today; 4
was deleted, not reused, by item 40 Part B — these become **checks 6 and 7**,
the next free numbers, not a renumbering of anything existing):

- **Check 6:** if `effect.openSlots` is non-empty, at least one of those kinds
  must have a non-empty entry in `chosenSlots` — otherwise: *"Choose a realm
  for this guideline"* (single-kind case) or *"Choose a Form or a specific
  type of enchantment for this guideline"* (`pevi-G10`'s alternative case).
- **Check 7:** the converse — any `chosenSlots` key naming a kind
  `effect.openSlots` does **not** declare is stray — *"A chosen realm applies
  only to a guideline with an open realm slot"* — mirroring check 2's
  treatment of a stray `chosenBaseLevel`.

Applies on both write paths (`Spell.fromMap`, `SpellDraft.toSpell`), same as
every other check in this function. Does not apply to `SpellTemplate` — it is
read-only catalog data with no write boundary, same reasoning item 40 already
recorded for checks 1/2 there.

### Import behavior

**Case 1 — prose commits to a value, resolved by a hand-verified table**
(Decisions 7/9/10): a new `REALM_BY_SPELL_ID` table in `extract_spells.py`,
keyed by the same `lib-*` slug `KNOWN_UNRESOLVABLE` already uses, giving each
known spell's verified realm — checked once against the rulebook text, not
inferred at build time:

```python
REALM_BY_SPELL_ID = {
    "lib-revi-circular-ward-against-demons": "Infernal",
    "lib-rean-ward-against-beasts-legend": "Magic",
    "lib-reaq-ward-against-faeries-waters": "Faerie",
    "lib-reau-ward-against-faeries-air": "Faerie",
    "lib-rehe-ward-against-faeries-wood": "Faerie",
    "lib-reme-ring-warding-against-spirits": "Magic",
    # Wind of Mundane Silence (pevi-G5) is deliberately absent: its prose
    # dispels "any spell" without committing to one realm, and its only
    # "Magic" appearances are "Magic Resistance"/"Magical things" — neither
    # a realm reference. Its template imports with chosenSlots: {} instead;
    # see Decision 9.
}
```

`build_template`/`build_spell` look up the block's slug in this table when
`catalog.open_slots(base_effect_id)` includes `"realm"`; a hit sets
`chosenSlots["realm"]`, a miss leaves `chosenSlots` without that key —
**not** an error, since a template tolerates it (Decision 9) and no corpus
`Spell` (non-template) currently references a realm-open guideline at all.
The table starts with exactly the 6 known cases; a future rulebook addition
that needs one gets a new entry the same way `KNOWN_UNRESOLVABLE` grows today.

**Case 2 — nothing to extract** (the three Muto Vim "ten versions" spells, and
any custom spell a user builds directly off a raw open-slot guideline): the
emitted `SpellTemplate`/`Spell` has empty `chosenSlots` for the declared kind,
and the caster fills it — via a new `OpenSlotChosen(kind, value)` bloc event
(Part B ships the Form/specificType instances of this; the event and its
handler are generic and ship in Part A).

**Actual consequence, checked against the corpus, not assumed:** Part A does
not unblock any currently-blocked spell. 6 templates already import
successfully today without any realm data (Decision 10); Part A backfills
their `chosenSlots` via the table above. `import_report.md`'s blocked count is
unaffected by Part A.

### UI

Mirrors the existing `chosenBaseLevel` field placement and pattern in
`spell_creation_screen.dart`: gated on
`draft.baseEffect?.openSlots.isNotEmpty ?? false`, rendered where the
guideline-level field sits today. Part A renders one dropdown (the four
canonical realms) wired to `OpenSlotChosen`. A template instantiated with
`chosenSlots` already filled shows the dropdown pre-selected but editable —
same "controlled field, externally settable" pattern the level field already
uses across the template-swap case, so a wrongly-extracted realm can still be
hand-corrected.

Part B adds the Form dropdown and the specificType text field under the same
gate; `pevi-G10` shows both, satisfied by either being non-empty.

### Wire format bump

`chosenSlots` is a new field on every `Spell`/`SpellTemplate` record.
`BackupService._supportedVersion` bumps again (Part A ships the bump; the
exact prior value is whatever item 40 Part B leaves it at) so an old-shape
backup fails loudly rather than silently parsing without the field — the same
prototype-stage, no-migration convention as item 40 Part B.

---

## Testing

- Unit tests for the new `validateSpellAgainstCatalog` check: single-kind
  mandatory, `pevi-G10`-shaped either/or satisfied by either kind, stray-kind
  rejection, and the existing checks 1/2/3/5 unaffected.
- `SpellEngine`/model round-trip tests for `chosenSlots` serialization
  (`toMap`/`fromMap`) on `Spell` and `SpellTemplate`.
- Bloc tests for `OpenSlotChosen` and for `chosenSlots` pruning when
  `TechniqueSelected`/`FormSelected`/`BaseEffectSelected` fire (mirrors the
  existing `chosenBaseLevel: null` clearing tests).
- Widget tests for the new dropdown's conditional visibility and the
  pre-filled-but-editable template-instantiation case.
- Python importer tests: the realm keyword scan (positive match, zero-match
  fallback, ambiguous multi-match fallback) and the two now-generic
  `build_spell`/`build_template` paths emitting `chosenSlots`.
- `BackupService` version-bump test, mirroring item 40 Part B's.

---

## Scope: two plans, planned separately

Only Part A touches import behavior; Part B is additive catalog coverage on
top of a mechanism that already exists. Neither part unblocks a spell that's
blocked today for an unrelated reason (e.g. `Ward against Faeries of the
Mountain`, blocked on "no design line printed" — untouched by this work).

| | Touches | Delivers |
|---|---|---|
| **A. Mechanism + realm** | `base_effect.dart`, `spell.dart`, `spell_template.dart`, `resolved_spell.dart`, `resolved_template.dart`, `spell_engine.dart`, `spell_creation_bloc.dart`, `spell_creation_screen.dart`, `backup_service.dart`, `catalog.py` (`open_slots` lookup), `emit.py`/`extract_spells.py` (`REALM_BY_SPELL_ID` table), both assets, every affected test | `OpenSlotKind`/`chosenSlots` generic mechanism; realm fully modeled, validated, and editable; the 17 realm-slot catalog entries annotated; the 7 existing realm-guideline templates carry verified `chosenSlots` |
| **B. Form + "specific type" + case-2 spells** | Catalog annotation for `pevi-G2/7/10`, `pevi-G11` (the Form-Resistance bullet), `revi-G5`, `muvi-G2/G3` (the two guidelines the 3 case-2 templates actually reference); case-2 needs no importer table at all — unlike most realm entries, none of the 3 templates' own prose commits to one Form (each explicitly says "ten versions, one per Form"), so their `chosenSlots` correctly stays empty by the same rule that already covers `Wind of Mundane Silence` (Decision 9), extended to a second real corpus case; Form dropdown + specificType text field UI; `base_effects.json` re-annotated, `spell_templates.json` regenerated (its 3 entries are unaffected — they already have no `chosenSlots` key and correctly keep none) | The remaining two slot kinds; `muvi-G2/G3`'s Form slot is declared and immediately exercisable by a caster instantiating any of the 3 existing templates |

**Part A is planned and implemented first.** It delivers the full generic
mechanism plus one complete, working instance of it (realm) — nothing in Part
B changes the shape Part A ships, only adds more annotated catalog rows and
two more UI controls that reuse it as-is.

---

## What this deliberately does not do

- **It does not build a closed vocabulary for "specific type."** Decision 4
  keeps it free text; a curated enum can be revisited if the corpus later
  demonstrates the examples given are exhaustive in practice.
- **It does not fix `pevi-G5`'s dropped-phrase description in `base_effects.json`.**
  That is an extraction-quality gap belonging to item 22, noted here only
  because it's what caused the 14-vs-15 discrepancy this spec resolves.
- **It does not handle a hypothetical guideline needing two slot kinds filled
  simultaneously.** No such entry was found; Decision 6's "at least one" rule
  is scoped to the cases the rulebook audit actually turned up.
- **It does not touch `chosenBaseLevel` or items 40's existing checks 1–5.**
  Those are baseline and unmodified beyond whatever the new check's numbering
  mechanically shifts.
- **It does not scope `openSlots` finer than the guideline for a guideline
  that serves both a Form-restricted and a Form-agnostic spell** (`muvi-G2`,
  Decision 12). Accepted as a narrow rough edge on hypothetical future custom
  spells; no corpus spell is affected.
