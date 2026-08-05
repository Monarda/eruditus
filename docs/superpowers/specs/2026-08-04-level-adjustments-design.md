# Level Adjustments: one Modifier, and free text for what is genuinely unique

**Date:** 2026-08-04
**Status:** Design agreed section-by-section in discussion
**Todo items:** 24 (Ad-hoc Level Adjustments), and most of 26 (Non-standard
Ranges, Durations and Targets)
**Source:** `Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition
(Core Rules).md`, Chapter 9, at the revision `scripts/spell_import/source.lock`
records

## Problem

Item 24 describes "21 published spells [that] carry a one-off magnitude the
storyguide assigned with a prose justification", and states flatly: **"No catalog
entry can ever cover these — they are per-spell, not per-guideline."**

That framing does not survive contact with the data. Parsing all 360 design
lines yields 36 tokens the extractor does not recognise. Clustered by the
*reason* behind them rather than their wording:

| Cluster | Count | Really is |
|---|---|---|
| "the effect is fancier than the guideline covers" | 9 | **One reason, nine spellings** |
| `+N Special` parameters | 4 | Item 26 — folds in here |
| Genuinely unique per-spell prose | 6 | Item 24's real shape |
| Requisite-driven | 4 | The **existing** `Requisite(art, adding)` mechanism |
| Existing catalog Modifiers | 4 | `muto-terram-material`, `creo-auram-unnatural`, size |
| Ritual / ward declarations | 3 | Items 18 and 4 |
| Damage scaling | 1 | Item 4b |
| Casting-requirement waivers | 2 | A real reusable rule with no home yet |

Counts are per token and total 33 of the 36. The remaining three are a cosmetic
"this is free" note (*Frosty Breath of the Spoken Lie*), a semicolon the splitter
does not handle (*Ball of Abysmal Flame*), and *Watching Ward*'s `Duration is
non-standard`, which has no magnitude. Each is addressed below or listed as a
non-goal.

Two conclusions follow.

**The largest cluster is one reason with nine different wordings.** `fancy
effect`, `complex effect`, `special effect`, `additional effect`, `elaborate
design`, `very elaborate effect` and `slightly nonstandard effect` all say the
same thing: the storyguide charged magnitudes because the effect exceeds what its
guideline describes. Item 24's objection — that a catalog entry "would pollute
the catalog with 21 single-use entries" — does not apply to **one** entry used
nine times.

**Most of the rest are not ad-hoc at all.** Roughly a third belong to mechanisms
the app already has, or to other tracked items. Treating them as ad-hoc
adjustments would record the wrong mechanism while still computing the right
level — invisible to the level test, and permanent in the asset.

## What already exists, and must not be duplicated

- **`Requisite(art, kind)`** already charges +1 for an `adding` requisite. The
  four requisite-worded tokens need parser work, not a new mechanism.
- **`Modifier`** already models a reusable, scoped, magnitude-bearing choice.
  `scope.technique` / `scope.form` of `null` means "offered on every spell";
  `selectionMode` is `single` or `multi`; each option carries a `magnitude`.
- **`SpellLevelCalculator`** already combines a base level with a list of
  magnitudes, including an additive tier below level 5 where a magnitude adds
  **1**, not 5.

## Design

### 1. An "Elaborate effect" Modifier

One new entry in `assets/data/modifiers.json`:

- `selectionMode: single`
- `scope`: `technique: null`, `form: null` — **globally scoped**, because the
  rule is general rather than tied to any Technique, Form or guideline
- four options at magnitudes 0, 1, 2 and 3

Every printed magnitude in the corpus for this reason is 1, 2 or 3, so the ladder
is closed rather than open-ended.

**Accepted loss of fidelity.** A Modifier records the option chosen, not the
rulebook's phrasing, so *Creeping Chasm* and *Weight of a Thousand Hells* will
both read "elaborate effect +1" rather than preserving "fancy" against "complex".
This is deliberate: the nine wordings are synonyms for one concept, which is the
observation that motivated this design. It is the assumption to revisit first if
the result reads wrong.

**This is the catalog's first globally-scoped Modifier.** Every existing entry is
scoped to a Technique, a Form, or specific `effectIds`, so this one appears in
every spell's creation UI. That is correct — the rule genuinely applies to any
spell — but it is a new shape in the catalog and worth knowing.

### 2. Free-text adjustments on the spell

A `List<LevelAdjustment>` on `Spell` and `SpellDraft`, each entry
`{magnitude: int, note: String}`, ordered and repeatable.

It carries what no vocabulary would ever capture:

| Spell | Adjustment |
|---|---|
| *Hunter's Sense* | `+1 for shape and primary motivation` |
| *The Miner's Keen Eye* | `+1 see through intervening material` |
| *Bridge of Frost* | `+1 to allow various shapes` |
| *Cloak of the Duck's Feathers* | `+1 for slightly unnatural control` |
| *Preternatural Growth and Shrinking* | `+1 because the spell allows growth or two kinds of shrinking` |
| *The Severed Limb Made Whole* | `-1 because the old limb is needed` |
| *Frosty Breath of the Spoken Lie* | `0` — "mist is a purely cosmetic effect and thus is free" |
| *Wind at the Back*, *Trackless Step* | `+2 Special (based on Concentration)` |
| *The Earth Split Asunder* | `+1 Special based on Mom` |
| *The Bountiful Feast* | `+4 Special (equivalent to Boundary)` |

The last four are item 26's, folded in on that item's own recommendation:
"Five of the six are one-offs with prose justification, which is exactly item
24's shape."

Three properties come from the corpus rather than from preference:

- **Negative magnitudes are permitted.** *The Severed Limb Made Whole* needs
  `-1`. Item 24 listed this as an open question; the data answers it.
- **Zero-magnitude entries are permitted**, because *Frosty Breath of the Spoken
  Lie* annotates that something is explicitly free. The note must survive while
  changing no level.
- **A spell may carry several.** *The Earth Split Asunder* takes both a `Special`
  adjustment and an elaborate-effect Modifier.

Serialization follows the existing `requisites` pattern — one key holding a list
of maps — so `app_database.dart` takes a schema bump and nothing else changes
shape.

**Not reused: `selectedModifiers`.** That map is keyed by catalog id, and these
entries have no catalog entry by definition. Forcing them through it would mean
inventing a fake modifier id per spell — precisely the catalog pollution item 24
warns against.

### 3. Relaxing the calculator's non-negative invariant

`lib/engine/spell_level_calculator.dart` currently throws `ArgumentError` on any
negative magnitude. This feature collides with that invariant head-on.

Adjustments become magnitudes like any other, passed into the same `calculate()`
list. The guard changes from "no magnitude may be negative" to **"magnitudes may
not push the level below where it started"** — `level < 1 && level < baseLevel`.

> **Amended after review.** This section originally specified the flat "the
> resulting level must be at least 1", and that is what shipped first. It is
> wrong: `base_effects.json` holds 47 base-level-0 guidelines (the General and
> ward lines), and one at Personal/Momentary/Individual is `calculate(0, [0, 0,
> 0])` — a level-0 spell the calculator had always returned, which the flat
> guard turned into a crash. The comparison against `baseLevel` restores it
> while still rejecting, say, base 5 with five `-1`s.

Negatives inside the additive tier take the
symmetric rule: subtract 1 while below level 5. No published spell exercises that
case — the only negative has base 25, where additive capacity is already
exhausted — but leaving it undefined would be a hole.

**Rejected: applying adjustments as a post-hoc `magnitude × 5` level delta.**
It disagrees with `calculate()` below level 5, where a magnitude is worth 1. Two
code paths that diverge at the bottom of the scale is a bug the level test would
catch late and confusingly.

The engine emits one `LevelContribution` per adjustment, labelled with its note,
so the breakdown line item 24 asks for falls out of the existing mechanism.

### 4. Extractor: an allow-list, never a catch-all

The tempting implementation — "any unrecognised `+N <prose>` token becomes a
free-text adjustment" — **must not be built.**

It would silently absorb `+2 metal/gems` (really `muto-terram-material`), `+2 for
up to +15 damage` (item 4b), and `+1 requisite` (the existing requisite
mechanism). Each would import with a *correct computed level* and *wrong
modelling*: invisible to assertion 1, and permanent in the asset. This is the
failure item 27's spec names as the design's central constraint — the extractor
must not pretend to resolve what it cannot resolve.

So:

- a closed table in `designline.py`, beside the existing `MODIFIER_LABELS`,
  mapping each elaborate-effect wording to the modifier option at the printed
  magnitude
- a literal allow-list of the adjustment tokens above, matched exactly
- **everything else keeps blocking.** A new unrecognised adjustment in a future
  rulebook revision blocks its spell rather than being quietly absorbed.

**Notes are taken from the raw design line, before parenthetical stripping.**
`designline.py:114` runs `_PARENTHETICAL.sub("", inner)` before tokenising, so
`+2 Special (based on Concentration)` reaches the tokeniser as `+2 Special` —
the explanatory clause, which is the entire value of the note, destroyed before
the token exists. Stripping remains correct for every other token kind; for
adjustments the aside *is* the content.

### 5. The one hand-derived magnitude

*The Shadow of Human Life* prints `for a very elaborate effect` with no
magnitude. A human derives it, and it is recorded as a literal with its
reasoning, following item 27's `HAND_DERIVED` pattern.

Two rules attach:

- **Never compute an adjustment from `printed − computed`.** That would make
  assertion 1 tautological for the spell — computed would equal printed *by
  construction* — and a test that cannot fail is worse than no test.
- The literal is checked *by* assertion 1: a wrong value makes computed ≠
  printed and the test fails. Hand-derivation under a test is a different thing
  from hand-derivation on trust.

*Mists of Change* also lacks a magnitude, but carries `D: Sun & Year` — two
durations, which no adjustment can express. It stays blocked, so hand-deriving it
would be wasted work.

### 6. UI

The Modifier needs **no new UI**; the creation screen already renders modifiers,
and global scope means it appears everywhere.

Adjustments need one repeatable row — magnitude stepper permitting negatives and
zero, plus a note field, with add and remove — and one breakdown line per
adjustment. Bloc events follow the `requisites` pattern: `AdjustmentAdded`,
`AdjustmentRemoved`, `AdjustmentUpdated`.

**One hazard specific to this list.** Requisites key on `art`, which is stable;
adjustments have no natural key, so removal is index-based, and each row owns a
`TextEditingController`. That is exactly the re-render failure item 6 documents:
the add-requisite crash was invisible to six passing widget tests because a
mocked bloc emits no new state, so the rebuild never happens. This list must be
covered either by driving states through a `StreamController` on the mock, or in
`integration_test/`. A mocked-bloc test asserting the row renders proves nothing
about the case that actually breaks.

## Testing

**Python.** The elaborate-wording table maps each phrasing to the right option;
the allow-list matches literally and an unlisted `+N` token still blocks; notes
retain parenthetical text; the hand-derived magnitude is a literal.

**Dart.** Model round-trip through serialization and the database; the
calculator's negative handling, including the symmetric additive-tier rule and
the "level ≥ 1" guard; one breakdown contribution per adjustment; the five
existing asset assertions still passing.

**No spell count is promised.** Several of these spells may carry a second
blocker, as *Mists of Change* and *Watching Ward* do. The harness reports the
real number, and that number is the deliverable's measure.

## Expected side effect

This is the first change to regenerate `assets/data/spell_library.json` since
item 30 landed. It will trip the `--accept-source` gate and produce the first
real `import_report.md`, showing which spells moved from blocked to imported.
That machinery has never run against an actual change; this exercises it.

## Non-goals

- **The four requisite-worded spells** — `+1 requisite`, `+1 for light from
  Ignem requisite`, `+1 Rego to fling the fragments away`, `+2 Techniques and
  Forms`. Pure parser work against an existing mechanism; deliberately scoped
  out.
- **The casting-requirement waivers** — `+2 for no words`, `+1 for not needing
  to gesture`. These are a published, reusable rule and deserve their own
  Modifier, not free text.
- ***Ball of Abysmal Flame*** — its `+2 Voice; the ball appearing to shoot from
  your hand is a cosmetic effect` fails because the splitter handles `,` and `.`
  but not `;`. A parsing fix, not an adjustment.
- ***Mists of Change*** (two durations) and ***Watching Ward*** (General level,
  item 25).
- **Catalog Modifiers other tokens need** — `+2 metal/gems`, `+2 for up to +15
  damage`.
- **`spell_library.json`'s schema** is unchanged in shape; only new optional
  fields appear on spells that use them.

## A caution for implementation

*The Bountiful Feast*'s design line has unbalanced parentheses in the source —
`(Base 1, ... +1 Size (for a total of +4 Size, ...)` never closes the outer
bracket. Verify it parses as expected rather than assuming it does.
