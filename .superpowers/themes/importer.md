# Importer

### 31. Real Per-Spell Summaries — Ledger-Authored
- [ ] **31.1** Author real per-spell summaries into a committed ledger keyed by spell id —
      the same pattern as `resolutions.json`, because the extractor is
      deterministic stdlib Python and cannot summarise prose
- **Why:** summaries are currently the description truncated to 400 characters,
  which duplicates the description rather than summarising it.
- **Deferred by the human partner** until all core-rulebook spells import, so the
  work is done once against the full set.
- **⚠️ Landing this changes text provenance, and one thing must NOT be deleted.**
  `test/models/summary_provenance_tripwire_test.dart` fails the moment these
  summaries stop being derived from descriptions, and names the three
  `Resolved*.sourcedSummary` sites to switch to `SourcedText.authored`. But
  `sourcedSpellText` then falls out of the *summary* path while remaining
  load-bearing on the *description* path — instantiating a published template
  copies the book's verbatim description into a spell saved as `userCreated`.
  Deleting it as "now dead" reintroduces the mislabel item 79.3 fixed. This also
  resolves item 87.1, which is one entry that reached this steady state early.
  See DECISIONS.md, "Text provenance".
- **Do the `" Level N."` suffix removal at the same time.** It is vestigial —
  nothing reads `RegExp(r'Level (\d+)\.$')` anymore; both former readers use the
  typed `printedLevel` field. Removing it from `emit._summary` rewrites every
  summary, which is why it waits for this item rather than a code dependency.
- **Files:** `scripts/spell_import/emit.py` (`_summary`), a new summary ledger
  alongside `scripts/spell_import/resolutions.json`, `assets/data/spell_library.json`


### 38. Open Follow-ups from item 25's Whole-Branch Review
None of this blocks anything. Found by an Opus-run multi-angle `code-review --max`
of `feature/general-base-effects`, each finding re-verified against source.

- [x] **38.1** **`SpellEngine.allParameters` starts empty and is populated only by a listener
      scoped to the Create screen.** Verified 2026-08-17: `spell_engine.dart:32`
      defaults it to `const []`, filled only via `AvailableParametersSynced` from
      `SpellCreationScreen`'s `BlocListener`. `main.dart`'s `IndexedStack` builds the
      Library tab eagerly at app start, so `SpellLibraryBloc` can call
      `calculateBreakdown` for a saved General ward-type spell before that sync
      lands. Then `_parameterById` returns null and the reference discount is
      silently skipped — the spell is momentarily overcharged, with no error
      surfaced. Not reachable from today's shipped library, but nothing prevents it
      for the first user-saved spell that does. **DONE 2026-08-17** (`54addae`, with
      item 60) — `main.dart` now hoists `getAllParameters()` and passes it to
      `SpellEngine` at construction.
- [ ] **38.2** **Duplicated join/filter logic between `Spell`'s path and `SpellTemplate`'s.**
      All real, none urgent; worth collapsing **before a third catalog-referencing
      record type shows up** (`ExceptionSpell` already made it three):
      - `SpellResolver.resolve`/`resolveAll` vs. `resolveTemplate`/`resolveAllTemplates`
        — identical four-field id lookup, differing only in wrapper type.
      - `SpellLibraryState.visibleSpells`/`visibleTemplates` — identical
        filter-by-source-then-substring pipeline. (Its "My Spells" branch on
        `visibleTemplates` always returning empty is **not** dead code — a template
        is published catalog data and can never be user-created.)
      - `ResolvedSpell`/`ResolvedTemplate` duplicate `isResolved`/
        `unresolvedReferences`/`technique`/`form` and the pass-through getters.
        **Do not merge `problems` into `isResolved` without preserving the compute
        gate** — `isResolved` means "the four catalog ids resolved, so a level can be
        computed at all"; `problems` means it computes but must not be trusted.
        `spell_library_bloc.dart:45` depends on the gate.
      - `emit.py`'s `build_template` mirrors `build_spell` near-verbatim; its own
        docstring says so without factoring the shared part out.
      - `extract_spells.py`'s General branch duplicates the ordinary
        ledger-resolution pipeline below it, and the two have **already drifted**:
        `DESIGN_LINE_INCOMPLETE` exists only on the General side though nothing about
        it is General-specific.
- [ ] **38.3** **Efficiency, all in the Library-load path, none correctness-affecting.**
      (`AssetDataLoader`'s repeated `spell_templates.json` parse was the third
      sub-problem and is fixed — every asset load is now memoised.)
      - `SpellLibraryBloc._onEvent` (`:36-38`, verified 2026-08-17) awaits
        `getAllSpells()`, `getTemplates()` and `getExceptions()` sequentially, each
        independently calling `LibraryRepository._refreshResolver()` — **three**
        catalog reloads where one would do (item 46 added the third), on **every**
        Library tab visit. `Future.wait` plus one resolver refresh fixes it cheaply.
      - `SpellEngine._parameterById` (`:49-50`) linear-scans instead of using a map,
        unlike `SpellResolver`'s own id maps.
- [ ] **38.4** **`deriveGeneralEffect` silently returns null when a negative
      `offsetMagnitudes` drives the value below 1**, and `validateSpellDraft` does not
      check this independently of the overall spell level — so such a guideline,
      chosen low enough, saves with a blank effect sentence and no validation error.
      No current catalog entry has a negative `offsetMagnitudes`.
- [ ] **38.5** **`TemplateInstantiated` silently discards an in-progress, unsaved draft.**
      Deliberate (a stale breakdown must not follow the user into a new spell), but
      there is no confirmation prompt. Worth one if it becomes a reported annoyance.
- [ ] **38.6** **38 of the 51 General catalog entries omit an explicit `reference` triple**
      (recounted 2026-08-18; was "37 of 50" before item 65 added `revi-hohmc-G1`
      without a reference), falling back to `ParameterTriple.standard()` rather than stating it.
      The fallback cannot distinguish "explicitly Personal/Momentary/Individual" from
      "field just wasn't authored". A natural extension of item 32. **One specific
      candidate:** `crvi-G4`'s formula codes `offsetMagnitudes: -1` while its one
      template's verbatim prose (*Restore the Faded Threads*) reads "up to the
      magnitude of this spell –3". Low confidence either is wrong — they may describe
      different quantities — but it is exactly what item 32 exists to check. **Item
      32.1 has since cleared that entry's `unreviewedCandidates` field, but only
      against `crvi-hohmc-G1` — the `offsetMagnitudes` question below is untouched
      and still wants its own read.**
- [ ] **38.7** **Two latent gaps in the Python import pipeline**, neither hit by the current
      corpus:
      - `extract_spells.py`'s General routing (`design.base_level is None or
        block.printed_level is None`) treats *either* side being absent as "General",
        so a spell under a `#### GENERAL` heading whose design line parses a concrete
        numeric base has that number silently discarded.
      - `emit.py`'s `_selected_modifiers` "size" token branch has no
        duplicate-selection guard, unlike the structurally identical
        `elaborate-effect` branch above it, though every `size-<form>` modifier is
        `selectionMode: single`.


### 70. Three Defects Found by the 52-Book Constraint Survey

**Opened 2026-08-18.** A survey of the whole rulebook corpus (52 books, 9
parallel agents) for "if X then Y must (not) be Z" rules turned up three
defects incidental to its purpose. **All three were verified by hand against
`reviewed/`**, unlike the bulk of the survey's 90 raw findings, which are
unverified agent output. Survey writeup and classification:
`scratchpad/survey-merged.md` (session-local; re-derive if lost).

- [x] **70.1** **A core rule nothing enforces: Personal Range forbids a container
      Target.** Core Rules line 12086, read against the *current* `reviewed/`
      file: "Personal Range spells can never have a container Target (such as
      Circle, Room, or Structure)." When opened, nothing
      in `lib/` checked this; the 325-spell library had **0 violations**, so it
      was latent — but the creation screen permitted the combination, and
      Boundary and the two new Sensory containers were equally affected. This
      is the *same shape* as item 67's "Range must be Personal", pointing the
      other way, and it was the strongest single argument for building that
      capability: it is core, universal, and gated behind no Virtue.
      **✅ DONE 2026-08-19 via check 10**, on the cross-field constraints
      branch this bullet argued for. `Parameter.forbidsTargetTypes` carries it,
      keyed on `TargetType` rather than on target ids so that Boundary — and
      any future container row — is covered with no data edit. Enforced
      corpus-wide by `published_spell_import_test.dart`'s assertion 7 over 336
      library spells and 31 templates; the guard was verified to fail (naming
      16 spells) when the data was deliberately broken. **One seam remains,
      recorded as item 74**: the guideline-adoption path can still assemble the
      forbidden pair, which validation then reports.
- [ ] **70.2** **Vim has no size ladder.** Nine `size-<form>` modifiers exist
      (Animal, Aquam, Auram, Corpus, Herbam, Ignem, Imaginem, Terram, Mentem);
      Vim is absent entirely. Core Rules line 15670: "Spells and magical
      effects do not have sizes, so size modifications do not apply to the
      levels of Individual Target Vim spells. **However, Vim spells affecting
      areas, or number of spells, must be increased in level for large areas
      or large numbers, as normal.**" The second sentence is the one the
      catalog misses. Correct model is a `size-vim` ladder with
      `excludeTargets: ['target-individual']` — exactly the shape `size-mentem`
      already uses for the identical "minds have no size" rule. Check whether
      any imported Vim spell's design line references a size magnitude before
      assuming the gap is harmless.
- [ ] **70.3** **Every core-rules line citation in the codebase is exactly 8 lines
      low.** 23 citations across `lib/` and `scripts/`
      (`grep -rnoE "(line|lines) 1[0-9]{4}" lib/ scripts/`). Verified +8 at
      10566, 12030, 12116, 12120, 12242, 12340, 12346, 12351, 12354, 12410 and
      13415 — the offset is uniform (current file position = cited number + 8),
      so the `reviewed/` core file gained 8 lines somewhere before line 10566.
      Line numbers newly read from the current file — including the two bullets
      above — are correct as printed and need no adjustment. Mechanically
      fixable. **This drift
      class is already known and recurring**: commit `e2f25d8` fixed the
      HoH:MC citations as "all one low" days earlier. Worth fixing the numbers
      *and* deciding whether line citations should be anchored to quoted text
      rather than line numbers, since they have now silently rotted twice.
- **Files:** `lib/models/spell.dart` (the Personal/container check),
  `assets/data/modifiers.json` (`size-vim`), and the 23 citation sites
- **See also:** items 67 and 68 (the same cross-field capability), 69 (the
  deferred pains), 36 (catalog audit against the rulebook)

---

### 77. The Book-Scoping Rule Stops at Base Effects

**Opened 2026-08-19**, as the loose thread from the `visible_books` change
(commit `afe1f81`). That change scopes *base effect* candidates to the books a
spell could cite. Parameters and modifiers reach the spell by different paths,
neither of which is scoped, and one of them can be silently wrong.

- [ ] **77.1** **`Catalog.parameter_id(category, name)` is first-match-wins
      across the whole flat catalog.** It walks `parameters` and returns the
      first row whose `category` and `name` match, with no book filter. Two
      books printing a Range/Duration/Target of the same name at different
      magnitudes would resolve to whichever row sits earlier in
      `parameters.json` — file order, not a rule — and nothing would raise.
      Counted today: **39 parameters, 31 `arm5-core` + 8 `arm5-hohmc`, and zero
      duplicate `(category, name)` pairs**, so the defect is latent, not live.
      Fix shape is the same as `visible_books`: pass the spell's book id and
      narrow. Decide also whether a collision should *raise* rather than
      silently pick, since a duplicate name across books is more likely an
      import bug than a real rules distinction.
- [ ] **77.2** **Modifiers are exposed differently and may need nothing.**
      Selection does not search by name: `_selected_modifiers` resolves through
      hand-maintained mappings keyed by `(Technique, Form, label)` to explicit
      `modifiers.json` ids, so a new book's modifier cannot be picked by
      accident — only by someone adding a mapping to it. All **35 modifiers are
      `arm5-core`** today. The open question is whether an explicit mapping
      should still be checked against the spell's visible books, i.e. whether
      the scoping rule is about *what the catalog offers* or about *what a
      spell may end up holding*. 77.1's answer probably settles this one.
- **Why this is filed rather than done:** neither sub-item can bite until a book
  adds a colliding parameter name or a spell-reachable modifier. Filing it means
  the next book's import does not have to rediscover the reasoning.
- **Files:** `scripts/spell_import/catalog.py` (`parameter_id`, `visible_books`),
  `scripts/spell_import/emit.py` (the six `parameter_id` call sites)
- **See also:** DECISIONS.md, "A spell may only use rows from books it could
  have been printed against" — this item asks how far that rule reaches; items
  55 and 32.1 for the base-effect half; item 66/71 for the books that will
  trigger it


### 78. Page References for Users — the Markdown Indexes Can Supply Them

**Opened 2026-08-20.** Reverses a standing "impossible" claim. `Citation.page` is
null for every built-in entry because the body markdown carries no page markers,
and `citation.dart:4-11`, `DECISIONS.md` ("Known limits — do not re-promise") and
item 56 all record that pages therefore *cannot* be supplied. **That is now
false.** The claim was made about the book's *body*; it was never tested against
the book's *indexes*.

**What the indexes actually hold** (measured 2026-08-20 against `reviewed/`):

| Index | Line | Shape |
|---|---|---|
| Spells Index | 23778 | `\| Spell Name \| Arts \| Level \| Page \|` |
| Spell Guidelines Index | 24143 | `\| Form \| Technique \| Page \|` |
| Bestiary Index | 24198 | `\| Name \| Realm \| Form \| Might \| Page \|` |
| Traditional Index | 24265 | `\| Entry \| Page \|` |

Every row cites its page as `[313](#anchor)`. Across the file there are **1650
unique `[page](#anchor)` pairs, of which 1606 (97.3%) resolve to a real heading**
— about one anchor per 14 body lines. So a line maps to a page via its nearest
preceding anchored heading. **The first two indexes alone cover exactly what the
catalog cites**: spells by name, and guidelines by Technique/Form.

- [x] **78.1 ✅ DONE 2026-08-21 — but not as written.** The anchor→page map was
      built, then **deleted**: the rulebook's own tables answer by lookup what it
      inferred. `scripts/spell_import/pages.py` now parses three tables — Spells
      Index (name→page), Spell Guidelines Index (`(technique, form)`→page, 608 of
      608), Traditional Index (`"{name} ({category})"`→page, 20 of 31 parameters).
      **See `DECISIONS.md`, "Choosing a mechanism", and the cautionary banner on
      `docs/superpowers/plans/2026-08-21-page-references.md`.**
- [ ] **78.2** **RE-SCOPED 2026-08-21 — the unresolved *anchors* no longer matter,
      because nothing resolves anchors any more.** What survives of this sub-item
      is the coverage gap: **46 core records no table indexes** (11 parameters —
      `Sight`, `Arcane Connection`, `Boundary`, the five sensory Targets, and
      `Road`/`Bargain`/`Fire` — plus all 35 modifiers), which ship page-less by
      design. Reopen only if item 56 finds those gaps actually hurt a hint.

- [x] **78.3 ✅ CLOSED AS OBSOLETE 2026-08-21.** It validated the anchor map, and
      the anchor map no longer exists. Nothing infers a page from a neighbouring
      line, so the defect it guarded against cannot occur. The 22 violations were
      diagnosed and resolved at a cost of ~508k tokens before the map was
      deleted — the single clearest illustration of the lesson in `DECISIONS.md`.
- [x] **78.4 ✅ DONE 2026-08-21.** `Citation.page` is populated and the three
      recorded "cannot" claims together — `citation.dart`, `DECISIONS.md`, and
      item 56's own warning. Retract them in the same change that makes them
      false, not before.
- [x] **78.5 ✅ DONE 2026-08-21.** `arm5-core` is now
      `"Ars Magica - Definitive Edition"` / `"ArM:DE"` / `"de"`. Its **id is
      unchanged** — it appears in 1034 citations. The title is load-bearing in
      five places: `books.json`, `lib/licensing/attribution.dart`, `NOTICE.md`
      and two tests, because item 79's attribution test asserts set equality
      between `arsMagicaAttribution.books` and `books.json`'s titles. That guard
      caught the drift, which is what it was added for.
- [x] **78.6 ✅ DONE 2026-08-21.** `page` stays a scalar `int?`; the edition is
      **implied by the `bookId`**, so a separately published edition is simply a
      different book id. This composes with item 86, which adds `workId` to group
      editions of one work — scoping keys on work, language selection on edition.

- [x] **78.7 ✅ DONE 2026-08-21.** The four defects the whole-branch review found
      are fixed. Three were parser rules, and the fixes are in `pages.py` so
      they cannot recur: a multi-link index row now prefers the link whose
      anchor matches the entry's own qualifier (`Concentration (Duration)` →
      `#durations`, not the concentration *roll* on 215) and emits nothing when
      none matches; the range pattern accepts an en dash; and the Spells Index's
      36 comma-inverted rows are registered under the real name too. The fourth
      was wiring — `enrich_catalog_pages.py` now consults the HoH:MC ledger for
      non-core entries, and the two hand-authored templates that bypass
      `emit.py` carry their pages directly.
- [x] **78.8 ✅ DONE 2026-08-21.** All 27 ledger phrases now verify against their
      claimed PDF page, checked by script rather than by the agent that wrote
      them. `printed = index + 1` is confirmed by 27 independent hits — the one
      check that catches a uniform offset error, which internal-consistency
      checks pass happily.

**Coverage: 1015 of 1061 citations carry a page.** The remaining 46 are by
design — 35 modifiers and 10 parameters that no index table lists, plus one
template whose name is a `(Form)` placeholder the index cannot match. A null
page is valid and permanent; see `citation.dart`.

**The PDF is the cross-check, not the source.** `F:\OneDrive\RPGs\Ars Magica\ArM
Definitive\Ars Magica Definitive Digital.pdf` extracts cleanly with `pypdf`
(~11s for all 582 pages). Two properties, both measured:
- **printed page = PDF index − 7, with zero exceptions** across all 418 pages
  that expose a numeric folio.
- each page's own folio is the first line of its extracted text, **doubled**
  (`293293` → 293), giving 418 independent confirmations.
- 5 pages extract no text at all (full-page art: idx 0, 207, 500, 501, 581);
  159 more lead with roman numerals (front matter) or an unextractable glyph.

Prefer the markdown indexes as the source — they are in-repo, versioned, and
already the provenance-locked artefact. Use the PDF to *verify* a sample, so the
mapping has a witness outside the file that produced it.

- **⚠️ Line citations in older item bodies run ~8 lines low** (DECISIONS.md, item
  70.3). Re-read any line number quoted here before trusting it; the four index
  line numbers above were read fresh on 2026-08-20.
- **Only two books need this today:** 1034 `arm5-core` citations and 27
  `arm5-hohmc` across the assets. Other books' PDFs are in
  `F:\OneDrive\RPGs\Ars Magica\`, each with its own offset — do not assume 7.
- **Files:** `scripts/spell_import/` (new index-parsing module),
  `lib/models/citation.dart`, `assets/data/books.json`
- **See also:** items 56 (the display half — this item stops at the data), 30
  (provenance), 79 (what may be quoted alongside a page), 80.3 (locale selects a
  source edition, which is what makes 78.6 necessary)


### 86. Source Editions — the Work/Edition Distinction

**Opened 2026-08-21**, from item 79's design discussion. The user noted that an
**official Spanish translation of the Definitive Edition is in progress and will
carry the same CC BY-SA licence**. That is not a hypothetical: it is a second
edition of the *same work*, and two things cannot express it today.

- [ ] **86.1** **`Book` cannot describe an edition.** `lib/models/book.dart` holds
      `id`/`title`/`abbreviation`/`edition`, where `edition` means "5e", not a
      language edition. It needs `language` and `workId`, plus the per-book
      §3(a) fields — `creators`, `copyrightNotice`, `licenceId`, `uri`,
      `modificationNote` — that would let `NOTICE.md` and the About screen
      generate their attribution list from `books.json` instead of carrying it
      hand-maintained in `lib/licensing/attribution.dart`.
- [ ] **86.2** **⚠️ Book-scoping would misfire, and this half is load-bearing.**
      `scripts/spell_import/catalog.py`'s `visible_books()` enforces the rule
      that *a spell may only use rows from books it could have been printed
      against*. A translated edition of the same work is **not** a different
      book under that rule — but as a fresh `books.json` row it reads as one, so
      a core spell would either lose access to its own guidelines or wrongly
      widen its candidate set. **Scoping must key on work id; language selection
      keys on edition.** This must exist *before* a second edition's rows are
      imported.
- [ ] **86.3** **Guideline ids stay language-independent.** A translated edition
      populates per-locale text against the **existing** ids — `cran-1` stays
      `cran-1`. A parallel per-language catalog would fork the level
      computation, which is the one thing this project cannot tolerate.

- **Why it matters beyond tidiness:** item 79.3 defines `verbatim` as "the
  published words of a **cited edition**", so quoting the Spanish edition is
  `verbatim` and cited to *its* book and page — not `translated`. Collapsing the
  two would under-credit its translators and claim a modification we did not
  make. That definition assumes an edition model that does not exist yet.
- **Same seam as item 77.** 77.1's latent parameter-collision defect goes live
  on the same trigger — a second book with a colliding name — so the two are
  best done together.
- **See also:** items 79 (which defined `verbatim` this way), 77 (the same
  seam), 55 and 32.1 (the book-scoping rule's history), 80.3/82 (locale selects
  an edition, never a translation of English)
