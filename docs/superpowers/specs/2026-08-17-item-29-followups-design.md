# Item 29 Follow-ups: Ledger Override, Treated/Unnatural Modifiers, README — Design

**Date:** 2026-08-17
**Status:** Approved for planning

## Goal

Close the three open bullets of todo item 29, the last section-A item:

1. **Decide the ledger's "explicit override" promise.** The import spec promises a
   capability `ledger.py` has never had. Drop the promise.
2. **Add the 2 still-missing modifiers** — Creo Aquam unnatural liquids, Creo
   Herbam treated products — and make the treated-product family consistent while
   we are in it.
3. **Replace the stock Flutter README** with a real orientation document.

The three are independent; they share only their parent item. Nothing here changes
a computed spell level, and nothing here is blocked by anything else.

## Rulebook Basis

All line numbers are into `reviewed/Ars Magica - Definitive Edition (Core Rules).md`
in the sibling `Ars-Magica-Open-License` checkout, at the revision `source.lock`
pins (`9c6aee1`).

- **Creo Aquam**, line 12806: *"Slightly unnatural liquids are one magnitude harder
  than water, very unnatural liquids are two magnitudes harder, and require a Muto
  requisite."*
- **Creo Herbam**, line 13931: *"To create treated Herbam products (for example, cut
  timber, a vegetarian meal, or linen or cotton cloth) add one magnitude to the level
  necessary to create the equivalent amount of unworked living or dead plants. To
  create treated and processed Herbam products (for example, clothes or furniture),
  add two magnitudes."*
- **Creo Animal**, line 12470 — the same rule in the same words for animal products,
  already modelled as `creo-animal-treated-product`. It is quoted here because the
  retrofit in Part B turns on one word of it: *"the level necessary to create the
  equivalent amount of **dead** animal."*
- **Muto Herbam**, line 14044 — the Muto counterpart, already modelled as
  `muto-herbam-treated-material` (+1 only; Muto prints no "treated and processed"
  rung). Named here so a later reader does not mistake it for the Creo row.

## Out of Scope (deliberately)

- **Forcing a requisite from a modifier option.** The Creo Aquam rule says very
  unnatural liquids *"require a Muto requisite"*. `Modifier` has no mechanism to
  add a requisite, and this design does not build one — the requirement is recorded
  as option `description` text. Surfacing rule consequences attached to a choice is
  todo item 56's subject, and this is one more instance for its list, not a reason
  to grow the model here.
- **`ModifierScope` per-spell granularity.** Item 50's open question (an Intellego
  spell that legitimately takes a Size modifier) is untouched. Part B uses only the
  `effectIds` include-list that already exists.
- **Any importer change.** No published spell selects either new modifier, so
  `emit.py`'s design-line token mapping is not extended. See *Why no spell needs
  these*, below.
- **A `CLAUDE.md`.** The repo has none. Part C writes a README, not agent
  instructions.

## Part A — Drop the Ledger's "Explicit Override" Promise

### The contradiction

`docs/superpowers/specs/2026-07-28-published-spell-import-design.md:203-206` says an
entry for an unambiguous spell is rejected *"except as an explicit override, which
needs a rationale like any other decision."*

`Ledger.resolve()` (`scripts/spell_import/ledger.py:99-146`) has no path where that
succeeds. With one candidate and an entry naming a different id, the
`len(candidates) == 1` branch matches neither of its two conditions, execution falls
through, and `entry.base_effect_id not in candidates` raises `StaleEntry`. A `NOTE`
comment at lines 105-110 states this outright and points at todo item 27.

### The decision

**Drop the promise.** The ledger records a choice *among* the candidates a spell's
own design line admits, never one against them. Where a spell is unambiguous there
is no judgement to record, so an entry is either redundant (`UnnecessaryEntry`) or
wrong (`StaleEntry`) — and those two errors between them already cover every case.

The reasoning, for the record:

- **Nothing needs it.** No entry in the 206-row ledger is an override, and none
  could be — the build has always rejected them.
- **The cases an override would serve already have homes.** A spell whose printed
  arithmetic does not fit its guideline takes an `adjustments` entry; one with no
  computable arithmetic at all becomes an `ExceptionSpell` (item 46). A spell whose
  sole candidate is the wrong guideline is evidence the *catalog* is wrong at that
  level, and belongs in `base_effects.json`, where every spell at that level
  benefits — not hidden in one spell's ledger row.
- **It would weaken the invariant that makes the ledger checkable.** `candidates`
  is the ledger's link to reality: assertion 3 compares the recorded set against a
  freshly computed one, which is what catches a decision going stale when the
  catalog moves. An entry whose choice is not in its own candidate set cannot be
  checked that way at all.

### Changes

1. **The spec sentence.** Replace the "except as an explicit override" clause with
   the rule as it actually is, and append a dated amendment note recording that this
   supersedes an earlier promise and why. The spec is a historical record; it should
   read as amended, not as though it never said otherwise.
2. **The `NOTE` comment**, `ledger.py:105-110`. Rewrite from a known-gap note
   pointing at item 27 into a positive statement of the design. `resolve()` itself
   is unchanged — its behaviour was never wrong, only undocumented as intentional.
3. **A test in `test_ledger.py`** pinning that an entry disagreeing with a sole
   candidate raises `StaleEntry`, with the decision recorded in its docstring. This
   is what stops a future reader "fixing" the gap the old comment described.

## Part B — The Two Missing Modifiers, and a Family Retrofit

### Why no spell needs these

Verified 2026-08-17 across all 325 imported spells: 22 distinct modifiers are
selected by at least one spell, and 10 catalogued modifiers are selected by none —
including `creo-animal-treated-product`, `muto-herbam-treated-material` and
`perdo-herbam-live-wood`, the three nearest neighbours of this work. A modifier is
catalogue data for a user designing their own spell, not an import artifact. Both
Creo Aquam oil spells (*Creeping Oil*, *Footsteps of Slippery Oil*) sit on `craq-3a`
with no magnitude for the oil, which is correct: oil is a naturally-occurring
liquid, so the new modifier's zero rung applies.

### `creo-aquam-unnatural`

Mirrors `creo-auram-unnatural` in shape and scope.

| Field | Value |
|---|---|
| `id` | `creo-aquam-unnatural` |
| `name` | Unnatural liquid |
| `selectionMode` | `single` |
| `scope` | `technique: Creo`, `form: Aquam`, `effectIds: []` |
| `source` | `published` |
| `citations` | `[{ "bookId": "arm5-core" }]` |

| Option id | Label | Magnitude |
|---|---|---|
| `creo-aquam-unnatural-none` | A liquid found in nature | 0 |
| `creo-aquam-unnatural-slight` | Slightly unnatural liquid | 1 |
| `creo-aquam-unnatural-very` | Very unnatural liquid | 2 |

The `-very` option carries `description: "Requires a Muto requisite"`, per line 12806.

The modifier's own `description` must say what this axis is **not**, because Creo
Aquam has two neighbours it is easily confused with:

- **`craq-4a`, "Create water in an unnatural shape"** — unnatural *shape*, an
  existing base effect. A sphere of ordinary water hovering overhead is `craq-4a`
  with this modifier at zero.
- **`aquam-base-individual`** — the water / naturally-occurring / processed /
  dangerous / poison ladder, which sets what one Individual *is* and costs zero
  magnitudes. That is a size axis. This is a difficulty axis. Wine is a processed
  liquid and still a natural one.

Scope stays broad (`effectIds: []`), matching `creo-auram-unnatural`: how unnatural
the created liquid is applies to every Creo Aquam creation row, and no row prices it
already.

### `creo-herbam-treated-product`

| Field | Value |
|---|---|
| `id` | `creo-herbam-treated-product` |
| `name` | Treated Plant Product |
| `selectionMode` | `single` |
| `scope` | `technique: Creo`, `form: Herbam`, `effectIds: ["crhe-1b", "crhe-1c", "crhe-3a"]` |
| `source` | `published` |
| `citations` | `[{ "bookId": "arm5-core" }]` |

| Option id | Label | Magnitude |
|---|---|---|
| `creo-herbam-treated-product-treated` | Treated (e.g. cut timber, linen cloth, a vegetarian meal) | 1 |
| `creo-herbam-treated-product-processed` | Treated and processed (e.g. clothes, furniture) | 2 |

**The narrowed scope exists to prevent a real double-count, not for tidiness.** The
Creo Herbam table prints `crhe-2a` *"Create a processed plant product, like a
finished plank of wood"* — which is `crhe-1b` *"Create a plant product"* with the
line-13931 rule's +1 already applied, since levels 1-5 sit in the additive tier where
one magnitude is one level. Its example, a finished plank, is the same *cut timber*
the prose gives as a treated product. A user selecting `crhe-2a` and then the
"treated" option would pay for the same treatment twice. Creo Animal's table prints
no equivalent row, which is why `creo-animal-treated-product` never met this problem.

Listing the three creation rows also keeps the control off the eight healing and
maturity rows, where "treated" is meaningless.

### `creo-animal-treated-product` retrofit

Change its scope from `effectIds: []` to `effectIds: ["cran-5a", "cran-10a"]`.

Line 12470 prices treatment against *"the level necessary to create the equivalent
amount of **dead** animal"*. That reaches two rows: `cran-5a` (create an animal
product — spidersilk, wool: the raw materials leather and cloth are made from) and
`cran-10a` (create the corpse of an animal — the hide and jointed meat the rule
names). Creating a live insect (`cran-5b`), bird (`cran-10b`), mammal (`cran-15c`)
or magical beast (`cran-50`) is not an amount of dead animal, and neither are the
recovery-bonus, healing, characteristic or maturity rows the empty scope currently
sweeps in.

No published spell selects this modifier, so the change is inert to the corpus. It
is in scope because leaving the two halves of one rulebook rule encoded two
different ways, with nothing in the data saying why, is exactly the kind of drift
item 36 exists to hunt.

### The guard test

Narrowing by id is only safe if a typo fails the build. Add one assertion over
`modifiers.json`: **every id in a modifier's `effectIds` names a real base effect
whose own `technique` and `form` match that modifier's scope.**

Without it, a mistyped id silently disables the modifier for every spell — the
failure is invisible, because a modifier nothing offers looks exactly like a
modifier nobody selected. Three entries now depend on this
(`creo-herbam-treated-product`, `creo-animal-treated-product`, and any future
narrowing), where before the retrofit none did.

Home: the Python catalog tests (`scripts/spell_import/tests/test_catalog.py`). That
side already reads both `modifiers.json` and `base_effects.json` as data and asserts
their integrity, which is what this check is; the Dart suite's concern is what
`ModifierScope.appliesTo` *does* with a scope, not whether the scope's ids exist.
One home, not both.

## Part C — README

Replace all 18 stock Flutter lines. Target roughly one page — enough that a cold
reader can run everything and knows where to look next, and no more, since every
sentence is a sentence that can go stale.

Sections:

1. **What Eruditus is** — a Flutter spell-design calculator for Ars Magica, and in
   one sentence the domain: a spell's level is computed from a base-effect
   guideline plus its Range, Duration, Target and any modifiers.
2. **Repo layout** — `lib/` (models, engine, bloc, presentation), `assets/data/`
   (the seven JSON catalogs: base effects, parameters, modifiers, books, and the
   spell library, templates and exceptions), `scripts/spell_import/` (the Python
   extractor and its hand-edited ledger), `test/`, `integration_test/`.
3. **Running the app** — `flutter run`.
4. **The three suites**, with exact commands: `flutter test`, `python -m unittest
   discover -s scripts/spell_import/tests -t .`, and `flutter test integration_test
   -d windows`. State what each one is *for*, since the split is not obvious: the
   Python suite guards extraction, the Dart suite guards the model and the computed
   levels, the integration suite guards the app end to end.
5. **The rulebook dependency** — not vendored. A sibling `Ars-Magica-Open-License`
   checkout; `reviewed/` is authoritative over `wip/`; `source.lock` pins the
   revision CI clones so upstream churn cannot redden a PR, and
   `rulebook-freshness.yml` is the deliberately unpinned weekly counterpart.
6. **Provenance and licence** — the catalog data is derived from Ars Magica
   Open License material.
7. **Where to look next** — `.superpowers/todo.md` for open work,
   `docs/superpowers/specs/` for the design record.

**Two things the README must not do:** restate counts that live in the todo's
*Where the import stands* table (one home for counts; the README may say what a file
is, not how many rows it has today), and duplicate catalog schemas or the ledger
workflow — those are the specs' job, and the full-contributor-guide option was
declined for exactly that reason.

## Testing

| Change | How it is verified |
|---|---|
| Part A spec + comment | Prose; no test. |
| Part A behaviour | New `test_ledger.py` case: an entry disagreeing with a sole candidate raises `StaleEntry`. |
| Both new modifiers | Existing asset-loading tests parse them; the new guard test checks `creo-herbam-treated-product`'s `effectIds`. |
| `creo-animal-treated-product` retrofit | The new guard test, plus the full Dart suite proving no computed level moved. |
| Part C README | Every command in it is run once, by hand, and the output matches what the README claims. A README nobody executed is the failure mode being fixed. |

Full-suite expectation after the work: Dart 661 unchanged, Python 316 + 2 (the
ledger case and the guard test), integration 8 unchanged. The extractor must still
report
**325 imported · 28 templates · 8 exceptions · 0 blocked · 0 unresolved**, with
`unreviewed: 3` — item 32's business, untouched here.

## Todo Item Bookkeeping

On completion, item 29's three open bullets close. Its remaining content — the CI
notes that bind — stays; those are standing constraints, not tasks, and should move
to the *Completed* section with the item rather than being dropped. Item 10's
"Update README" bullet closes at the same time, since it names the same document.
