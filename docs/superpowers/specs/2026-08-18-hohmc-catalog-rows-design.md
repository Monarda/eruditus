# HoH:MC Catalog Rows — the Five Sensory Targets and the Two Glamour Guidelines

**Sub-project A of three.** Designed 2026-08-18.

Adds exactly the catalog rows the *Houses of Hermes: Mystery Cults* spells
depend on, and nothing else. No parser changes and no spells: this is the
foundation sub-project B consumes.

## Why this is one of three

The ask was "extract the rest of the HoH:MC spells, after finding the new base
effects, parameters and modifiers". Measuring the book against the importer's
own regexes turned that into three separable pieces:

| | Work | Depends on |
|---|---|---|
| **A** (this spec) | 5 Sensory Magic Targets + 2 Glamour guidelines | — |
| **B** | Generalise the parser to HoH:MC's block format; extract its 14 spells | A |
| **C** | The 36 Faerie Magic "Animae" guideline rows | — |

A and B are the job as described. C is a different kind of work — bulk table
extraction, like the original base-effect sweep — and only 1 of the book's 38
new guidelines is used by any of its spells, so C must not block B.

**What the book actually holds** (measured, not estimated): 16 spell stat
blocks. One is already hand-authored (*Faerie Chains of the Familiar Slave*,
todo item 17). One is an enchanted-device effect rather than a spell —
*Perceive the Change*, whose stat line reads `Pen 0, constant effect` and whose
design line costs `+1 two uses/day, +3 environmental trigger`. That leaves 14
extractable spells, 8 of which need the Targets this spec adds.

**Corpus survey (informs B, recorded here so it is not lost).** All 54 books the
importer can resolve were parsed for spell-block shape: 3107 stat lines, 2252
design lines, of which the core book is 385/353 — roughly 87% of the corpus's
spell blocks sit outside the core rules. Four anchor styles appear: heading-name
(1131 stat lines, what `blocks.parse_de` handles), inline `TeFo Level` (664,
HoH:MC's), bold-name (120), and unanchored (1192, largely creature powers and
magic items rather than spells). HoH:MC is 16/16 inline with zero orphans — the
cleanest non-core book measured. The inline style is not a HoH:MC quirk:
Covenants is 42/44, Transforming Mythic Europe 68/84, HoH:Societates 50/59.
Product line does not predict format — HoH:True Lineages is 55/55 *heading*
style.

## The five Sensory Magic Targets

House Bjornaer's Sensory Magic (Minor House Mystery, HoH:MC line 997) adds five
Targets. Each is an area of effect around the caster: "anyone sensing the
Bjornaer magus through the specified sense becomes a target" (line 1001).

New rows in `assets/data/parameters.json`:

| id | name | magnitude | targetType | book's stated equivalent |
|---|---|---|---|---|
| `target-flavor` | Flavor | 0 | `object` | Individual (line 1019) |
| `target-texture` | Texture | 1 | `object` | Part (line 1023) |
| `target-scent` | Scent | 2 | `object` | Group (line 1027) |
| `target-sound` | Sound | 3 | `container` | Structure (line 1031) |
| `target-spectacle` | Spectacle | 4 | `container` | Boundary (line 1035) |

Every row also carries `"category": "Target"`,
`"requiresVirtue": "Sensory Magic"`, `"source": "published"` and
`"citations": [{"bookId": "arm5-hohmc"}]`, matching the shape of the existing
`target-bloodline` row.

`requiresVirtue` is informational, exactly as item 17 established: the app has
no character or Virtue model to enforce against, so the field names the
requirement and nothing gates on it.

### The magnitudes are verified against printed design lines

The book gives magnitudes only by equivalence, so each was reconciled against a
spell whose printed level must come out right:

| Target | Design line | Printed | Reconciles |
|---|---|---|---|
| Flavor +0 | `(Base 15, +1 Diam)` | PeAn 20 | 15 → 20 ✓ |
| Texture +1 | `(Base 4, +4 Year, +1 Texture, +1 Creo requisite, +1 complexity)` | ReMe 35 | ✓ |
| Scent +2 | `(Base 4, +2 Sun, +2 Scent)` | CrMe 20 | ✓ |
| Sound +3 | `(Base 3, +1 Diam, +3 Sound)` | MuMe 15 | ✓ |
| Spectacle +4 | `(Base 5, +1 Conc, +4 Spectacle)` | CrIg 30 | ✓ |

### Why `targetType` follows the printed equivalences

This was the one genuine modelling decision, and it is closer than it looks.
The core catalog already holds a `sense` Target ladder at the *same five
magnitudes* — Taste 0, Touch 1, Smell 2, Hearing 3, Vision 4 — matching the new
ladder sense for sense. Grouping the Sensory Targets there would be wrong
anyway, and the book says so itself: a core `sense` Target grants the caster a
magical sense, while HoH:MC line 1008 rules that a Sensory Magic spell "cannot
employ the Technique of Intellego, even as a requisite. Spells which grant
magical senses … fill that role." One enum value would mean two different
things.

The book explains their magnitudes against the object/container ladder rather
than the sense one, so the rows follow what it prints. A fourth `TargetType`
value was considered and rejected as disproportionate: it would touch the
model, the UI's target-kind handling and item 14's derived predicate, for five
rows — and `TargetType`'s own doc comment rests on the Core Rules' "there are
three types of target" (line 12120).

**Consequence, stated rather than discovered later:** Sound and Spectacle become
`container` Targets, so `spellOwesContainerMode` will say they owe a
static/dynamic ruling. That affects the four HoH:MC spells using them (*Clarion
Call of the War Horse*, *The Rooster's Crow*, *Brilliance of the Eagle's
Plumage*, *Closed Mouth of the Nightwalker*), and belongs to sub-project B —
`containerMode` is per-spell, not per-parameter. Item 57's backlog is 16 *core*
spells; these four are B's to rule on and do not change that count.

## The two Glamour guidelines

Glamour (Major Illusion Mystery, line 3826) is restricted: glamours "are Muto or
Creo Imaginem spells that only magi with this Virtue may invent or cast" (line
3828). Both printed guidelines are level 10 (lines 3840 and 3842-3843).

New rows in `assets/data/base_effects.json`:

- `crim-hohmc-10` — Creo Imaginem, `baseLevel: 10`, "Create a glamour."
- `muim-hohmc-10` — Muto Imaginem, `baseLevel: 10`, "Change a target into
  glamour. (Requisite of the Form of the target required.)"

Both carry `"source": "published"`,
`"citations": [{"bookId": "arm5-hohmc"}]` and
`"requiresVirtue": "Glamour"`. The id convention follows item 17's
`crvi-hohmc-G1`: technique+form prefix, book segment, then level.

Only `muim-hohmc-10` is used by a spell — *Ball of Abysmal Music* (MuIm 20,
`(Base 10, +2 Voice)`), which is the sole HoH:MC spell whose base level has no
candidate anywhere in the current catalog. The Creo row is added because the two
are one printed table; splitting them would leave a table half-imported for no
reason.

**Format note:** `base_effects.json` stores one compact object per line and
committed JSON assets must not be reformatted. Append the two rows in that
style and check `git diff --numstat` shows exactly two added lines.

## Tests

Three Dart tests hardcode catalog counts as deliberate drift detectors. They
must be updated, and updating them is part of this work rather than a surprise:

- `test/data/datasources/asset_data_loader_test.dart:42` — parameters 34 → 39
- `test/bloc/configuration_bloc_test.dart:57` — parameters 34 → 39
- `test/data/repositories/configuration_repository_test.dart:45,59` — effects
  610 → 612 and 609 → 611

The Python oracles need no change. Item 55 already made them book-aware:
counts that must stay exact are scoped with
`catalog.cites(entry, catalog.CORE_BOOK_ID)`, and the parameter check is a floor
(`assertGreaterEqual(len(self.catalog.parameters), 25)`).

New coverage, one test each:

1. **The five Sensory Targets load with their stated magnitudes and kinds** —
   asserting the 0/1/2/3/4 ladder and the object/object/object/container/
   container split, since those numbers are the whole content of the rows and a
   silent typo in one would produce spells that compute a plausible wrong level.
2. **The two Glamour guidelines resolve as candidates at base 10** — via
   `Catalog.candidates("Muto", "Imaginem", 10)`, which returns empty today.
   This is the assertion sub-project B depends on.

## Out of scope, with reasons

- **The glamour complexity modifiers** (+1 for intricate glamours, +2 for
  animate → inanimate, lines 3834-3836). No HoH:MC spell uses them, and
  `designline.py` already tokenises `complexity` generically.
- **The 36 Faerie Magic "Animae" guidelines** — sub-project C.
- **Per-spell static/dynamic container rulings** — sub-project B.
- **Any parser change** — sub-project B.
- **Enforcing the Sensory Magic restrictions** (Range must be Personal, no
  Intellego, not investable into items, Form must suit the medium; lines
  1005-1011). The app has no Virtue model, and these constrain spell *design*
  rather than the catalog row. Recorded here so a later reader knows they were
  seen and set aside, not missed.

## Files

- `assets/data/parameters.json`
- `assets/data/base_effects.json`
- `test/data/datasources/asset_data_loader_test.dart`
- `test/bloc/configuration_bloc_test.dart`
- `test/data/repositories/configuration_repository_test.dart`
- `.superpowers/todo.md` (open the item; file B and C)

## See also

- Item 17 — virtue-gated parameters; the precedent this follows, and the source
  of the only existing HoH:MC catalog rows.
- Item 55 — what broke when the catalog stopped being core-only, and the
  book-aware oracles that resolved it.
- Item 57 — the container rows owing static/dynamic rulings.
