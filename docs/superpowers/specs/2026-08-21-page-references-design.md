# Page References for Users: three sources, one nullable field

**Todo items:** 78 (78.1, 78.3, 78.4, 78.5, 78.6; 78.2 deferred). Unblocks the
citation half of item 56.

**Status:** designed 2026-08-21

**Rulebook:** `Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition
(Core Rules).md`, pinned at `ffc1c6b`. Line numbers in this document were read
fresh on 2026-08-21 and are to that file. **Every figure below was obtained by
running something** — the measurement is named beside each one so it can be
re-run.

---

## Problem

`Citation.page` is null for every built-in entry, and three places record that
it therefore *cannot* be filled: `citation.dart`'s own doc comment,
`DECISIONS.md`'s "Known limits — do not re-promise", and item 56. **That claim
was measured against the book's body and never against its indexes**, and it is
false. The markdown carries four index tables whose every row cites a page as
`[313](#anchor)`.

Item 56 — *"Rules Hints — What a Choice Means, and Where It Comes From"* — is
the work this unblocks, and it is the one piece here the user asked for
directly. Item 79 established that a hint may quote the rulebook verbatim and
must mark the quote; the marker and the page reference are the same affordance,
so a hint that says *"see p. 112"* needs this data.

## What the measurements establish

Re-run any of these before trusting them.

| Measured | Result |
|---|---|
| Index table locations | Spells Index line 23778, Spell Guidelines Index 24143, Bestiary Index 24198, Traditional Index 24265 — all four match item 78's recorded values |
| Anchor resolution, per index | Spell Guidelines **50/50**; Spells Index **359/360**; Bestiary 60/62; Traditional 1302/1357 |
| Where the failures live | **95% of unresolved anchors are in the Bestiary and Traditional indexes** — the two the catalog never cites |
| Calibration points | **1606** resolved anchor→line pairs, matching item 78's figure. Gaps between them: median 6 lines, p90 32, **max 789** |
| Guideline locatability | 32 of 40 sampled core guidelines locate in the markdown by exact description match; distance to nearest preceding anchor **median 13, p90 22, max 25 lines** against ~44 markdown lines per printed page |
| Can the PDF replace the index for core? | **No.** First PDF occurrence of a spell name equals the Spells Index page in only **68 of 120** cases (57%) — *Aegis of the Hearth* is indexed at p.370 but first appears on p.13 |
| HoH:MC markdown | **Zero anchor pairs.** 5077 lines, 317 headings, no index tables. The convenience links are a Definitive-Edition-only feature of that repo |
| HoH:MC PDF | 138 pages, **printed page = PDF index + 1**, confirmed on 125. The 12 exceptions are 1 textless cover and 10 chapter-opening pages whose first line is the chapter number |
| HoH:MC automated matching | Description match 9/15, name match a *different* 9/15, union 12/15. *Ball of Abysmal Music* matches by description but not by name — the failures are typography, not absence |
| Citation volume | **1034 `arm5-core`, 27 `arm5-hohmc`** |

## Explicitly not in scope

- **78.2, the unresolved anchors.** Deferred deliberately: they cost calibration
  density, never correctness, and 95% sit in indexes the catalog does not cite.
  The safety rule below turns a sparse patch into a null page rather than a
  wrong one.
- **Item 56's display work.** This document stops at the data. How a hint
  renders "p. 112", and where, is 56's.
- **Automated PDF parsing.** No PDF code enters the repo. The PDF is what item
  78 called it — the cross-check — plus, for HoH:MC, the reference a subagent
  reads once while authoring a committed ledger. Reading a PDF is not the same
  as depending on one at build time.
- **Other books.** Only two need this today. A third book's PDF has its own
  offset (do not assume `+1` or `−7`), and a third book without an index needs
  its own ledger.
- **Renaming `arm5-core`.** The id stays; only its metadata changes. See §5.

## Backwards compatibility is not a goal

Adding a nullable `page` to existing citations is additive at the wire level —
`Citation.fromMap` already reads `map['page'] as int?`. No schema bump is
needed: citations live in assets, not in the `spells` table. User-created
spells carry no citations at all (`Provenance`'s invariant), so nothing
persisted changes shape.

## The organising idea: three curated tables, no searching

**Revised 2026-08-21, after the human partner challenged the amount of search
effort. They were right, and the measurements below say so.**

The original design inferred a guideline's page from the nearest anchored
heading above its line, which required locating that line by matching its
description text. That is a search, and it is what made an anchor map, a
monotonicity gate and four exclusion mechanisms necessary. **None of it is
needed.** The rulebook carries three curated tables that answer by lookup:

| Population | Count | Table | Key | Coverage |
|---|---|---|---|---|
| Core spells | 360 | Spells Index | spell name | exact, curated |
| Core guidelines | 608 | Spell Guidelines Index | `(technique, form)` | **608/608 — 100%** |
| Core parameters | 31 | Traditional Index | `"{name} ({category})"` | **20/31 — 65%** |
| Core modifiers | 35 | — | — | not indexed |
| HoH:MC, everything | 27 | committed ledger | record id | exact, authored |

Measured 2026-08-21: every core `base_effect` carries `technique` and `form`,
and all 50 Technique/Form pairs appear in the Spell Guidelines Index, so the
join is total. `parameters.json` carries `name` and `category`, and the
Traditional Index indexes parameters in exactly that form — `Voice (Range)` →
303, `Momentary (Duration)` → 304, `Individual (Target)` → 305.

**Why lookup beats inference here, beyond simplicity.** The tables are the
book's own statement of where its content is. Inference reached ~80% of
guidelines where the table reaches 100%, and its correctness rested on 74
hand-justified anchor exclusions — every one of which was a place the mapping
could be wrong in a way no test would catch.

**The residue takes no page.** The 11 parameters absent from the Traditional
Index (`Sight`, `Arcane Connection`, `Boundary`, the sensory Targets) and the
35 modifiers get `page` omitted. That is not a gap to close: a null page is
valid and permanent (§2), and inventing a mechanism for 46 records is what
this revision exists to stop. If those gaps prove to matter in item 56's
hands, item 78.2 is where to reopen them.

## Design

### 1. The three table parsers (78.1)

`scripts/spell_import/pages.py` parses three tables into three dicts, and does
nothing else:

- `spell_index_pages: dict[str, int]` — spell name → page.
- `guideline_index_pages: dict[tuple[str, str], int]` — `(technique, form)` → page.
- `topic_index_pages: dict[str, int]` — Traditional Index entry → page, keyed
  on the entry's text lowercased with `&nbsp;` stripped.

A caller asks for a key; it gets a page or nothing. There is no line-to-page
inference, no anchor map, and nothing walks backwards through the document.

**Page ranges must be modelled, not truncated.** Rows like
`[158-159](#ability-types)` occur; the range's first page is what a citation
carries, but the parser must recognise the form rather than failing to match it.

### 2. The safety rule

**A page is emitted only when a table names one.** With lookup rather than
inference there is one rule and no thresholds: a key is present or it is not.
A missing key yields no page.

A null page is not a temporary state to be eliminated. HoH:MC records outside
the ledger, the 11 unindexed parameters and all 35 modifiers will have them,
and `Citation`'s own doc comment already says *"A citation naming only its book
is complete and valid."* That sentence stays true and stays in place.

**Never widen a key to raise coverage.** Matching `Voice` where the table says
`Voice (Range)`, or falling back to a neighbouring entry, reintroduces exactly
the guessing this revision removed.

### 3. What replaces the monotonicity gate (78.3)

78.3 existed to validate the anchor map. With no anchor map there is nothing
for it to validate, and the sub-item is **closed as obsolete rather than done**
— the defect it guarded against cannot occur, because no page is ever inferred
from a neighbouring line.

What replaces it is a coverage assertion per table, pinning the measured
figures so a source change is caught: the Spells Index yields 360 entries, the
Spell Guidelines Index 50, and every core `base_effect`'s `(technique, form)`
resolves.

### 4. The HoH:MC ledger

A committed JSON ledger keyed by record id — the same pattern as
`resolutions.json` and `hand_authored_templates.json` — mapping each
`arm5-hohmc` record to its printed page, from
`F:\OneDrive\RPGs\Ars Magica\Ars Magica 5e - Houses Of Hermes - Mystery Cults.pdf`
(printed page = PDF index + 1).

**Authored by a subagent, not by hand, and not by a matcher in the repo.**
Searching a PDF and checking whether a passage matches is mechanical work: a
cheap-tier agent extracts the pages, locates each of the 15 records, and records
the page plus the evidence it used (the matched phrase and the folio it read).
Its output is reviewed and committed as data. This keeps the repo free of PDF
code — the PDF stays the cross-check item 78 called it — without spending human
time on 27 lookups.

Each entry carries the evidence, not just the number, so a reviewer can check
the claim without re-opening the PDF:

```json
{ "lib-crme-scent-predator": { "page": 29, "matched": "…phrase read on that page…" } }
```

Two tests: **every `arm5-hohmc` citation in the assets has a ledger entry**, so a
future record cannot silently ship page-less while its siblings carry pages; and
every entry's page is within the book's page count. The 12 of 15 that regex
matching finds are a starting point for the agent, never the committed answer —
the three it misses (typography, not absence) are exactly where a reader is
needed.

### 5. `books.json` and the edition (78.5, 78.6)

**`Citation.page` stays a scalar `int?`, and the edition is implied by
`bookId`.** This is item 78.6's own suggested cheapest answer, and it composes
with item 86: a separately published edition becomes a *different* `bookId`,
and 86 adds `workId` so `visible_books()` can still group editions of one work.
No new field, no migration, and 78.6's warning — "deciding the shape costs
nothing today; changing it after 1061 citations carry a number costs a
migration" — is discharged by deciding it here.

That makes 78.5 load-bearing rather than cosmetic. `books.json` currently
declares `arm5-core` as `"Ars Magica Fifth Edition"` / `"ArM5"` / `"5e"`, but
the pages are **Definitive Edition**, which paginates differently — the
Reference Guide prints both (*"Fifth Edition p7, Definitive Edition p8"*), so a
DE page under a 5e label sends the reader to the wrong page. Per the 2026-08-20
decision, **Definitive Edition only**: never carry 5e numbers, never show a
paired form.

**The id stays `arm5-core`.** Renaming it would churn 1034 citations across
every asset for no benefit; what changes is its title, abbreviation and edition,
so the id unambiguously denotes the edition its pages belong to.

### 6. Populating the field (78.4) — two delivery mechanisms, not one

**⚠️ The extractor writes only three of the six assets**, verified 2026-08-21:
`extract_spells.py` emits `spell_library.json`, `spell_templates.json` and
`spell_exceptions.json`. It *reads* `base_effects.json`, `parameters.json` and
`modifiers.json` — those three are **hand-maintained catalogs with no
generator**, as their git history shows. So "the importer populates the field"
is only half true, and the halves are delivered differently:

| Assets | Records | How `page` arrives |
|---|---|---|
| `spell_library`, `spell_templates`, `spell_exceptions` | 375 | `emit.py` writes it on every extractor run, from the Spells Index or the HoH:MC ledger |
| `base_effects`, `parameters`, `modifiers` | 686 | A **one-shot enrichment script**, run once, its output reviewed and committed |

The one-shot follows `scripts/flag_ritual_effects.py`, which is precedent in
this repo for exactly this: a script that annotated `base_effects.json` once,
was applied, and carries a header saying it is *"kept for reference only, not
part of any build or test step — do not re-run without checking."* Ours gets the
same header. **Note its warning about line endings**: it rewrites all lines, so
the enrichment must preserve the file's existing newline convention or the diff
becomes unreadable.

**Consequence to accept rather than engineer around:** a guideline added by hand
*after* the one-shot runs will have no page, and nothing will notice. That is
correct behaviour under §2 — a null page is valid — and the coverage test below
is written as a floor, not a ceiling, so it does not force a re-run of a script
whose header says not to re-run it.

Then **retract the three "cannot" claims in the same change that makes them
false, not before**:

1. `lib/models/citation.dart`'s doc comment, which says page numbers "cannot be
   recovered from the import source" and that an earlier promise "could not be
   kept".
2. `DECISIONS.md`, "Known limits — do not re-promise".
3. Item 56's own warning — already struck through and marked RETRACTED
   2026-08-20; the strike-through can now cite this landing.

Each retraction must say what was actually wrong: the claim was measured against
the book's *body* and never tested against its *indexes*.

## Testing

- **Page ranges:** `[158-159](#x)` parses to page 158, not to a failure and not
  to 158159.
- **Table coverage, pinned to measurement:** the Spells Index yields 360
  entries; the Spell Guidelines Index yields 50; every core `base_effect`'s
  `(technique, form)` resolves against it. A change in any of these means the
  source moved — check `source.lock` before changing the number.
- **Parameter lookup uses name *and* category:** `Voice (Range)` resolves;
  bare `Voice` does not. This pins the key format against a future "helpful"
  widening.
- **A missing key yields no page**, and the emitted citation omits the `page`
  field entirely rather than carrying null — `Citation.toMap` writes the key
  only when it has a value.
- **HoH:MC ledger coverage:** every `arm5-hohmc` citation in the assets has a
  ledger entry, every entry names a record that exists, every page is inside
  the book, and every entry records the phrase it was matched on.
- **Page coverage is a floor, not a ceiling.** A test asserts that at least the
  number of `arm5-core` citations carrying a page today still carry one — so a
  regression is caught while a hand-added guideline with no page is not a
  failure.
- The three suites stay green: `flutter test`, the Python extractor suite, and
  `flutter test integration_test -d windows`.

## Files

| File | Change |
|---|---|
| `scripts/spell_import/pages.py` | three table parsers — and, in this revision, the removal of the anchor map, `page_for_line`, the monotonicity gate and all four exclusion mechanisms |
| `scripts/spell_import/hohmc_pages.json` | the committed HoH:MC ledger |
| `scripts/spell_import/emit.py` | populate `page` on the three emitted assets |
| `scripts/enrich_catalog_pages.py` | one-shot — pages into the three hand-maintained catalogs by lookup, then kept for reference |
| `assets/data/*.json` | regenerated / enriched, citations gaining `page` |
| `assets/data/books.json` | `arm5-core` metadata → Definitive Edition |
| `lib/models/citation.dart` | retract the "cannot" doc comment |
| `.superpowers/DECISIONS.md` | retract the "Known limits" entry |

## Consequences for other items

| Item | What this settles |
|---|---|
| **56** | The citation half of its hints. A hint can name a page for core content; HoH:MC content names a book only, permanently |
| **87.3** | The source marker can now say something useful — book plus page — which is the decision that item deferred |
| **86** | Confirms the edition model: `bookId` denotes an edition, `workId` groups them. 78.6 is discharged in a way 86 must preserve |
| **30** | Same provenance ethos; the ledger and the pinned commit are both part of the source record |
| **79** | The marker and the page reference are one control, as its spec said |
