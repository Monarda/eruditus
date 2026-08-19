# Importer

### 31. Real Per-Spell Summaries — Ledger-Authored
- [ ] **31.1** Author real per-spell summaries into a committed ledger keyed by spell id —
      the same pattern as `resolutions.json`, because the extractor is
      deterministic stdlib Python and cannot summarise prose
- **Why:** summaries are currently the description truncated to 400 characters,
  which duplicates the description rather than summarising it.
- **Deferred by the human partner** until all core-rulebook spells import, so the
  work is done once against the full set.
- **Do the `" Level N."` suffix removal at the same time.** It is vestigial —
  nothing reads `RegExp(r'Level (\d+)\.$')` anymore; both former readers use the
  typed `printedLevel` field. Removing it from `emit._summary` rewrites every
  summary, which is why it waits for this item rather than a code dependency.
- **Files:** `scripts/spell_import/emit.py` (`_summary`), a new summary ledger
  alongside `scripts/spell_import/resolutions.json`, `assets/data/spell_library.json`


### 32. Audit `resolutions.json` — no Test Can Check It
- [ ] **32.1** **Start with the 3 entries that name their own gap.** Item 55's migration
      carried `lib-crvi-restore-faded-threads`,
      `lib-crvi-shell-false-determinations` and `lib-crvi-shell-opaque-mysteries`
      past `crvi-hohmc-G1` without weighing it, and each records that in
      `unreviewedCandidates`. Reading the familiar-binding guideline against
      those three rationales and clearing the field is the smallest possible
      instance of this item's whole job — and the only part of it the extractor
      currently reports.
- [ ] **32.2** Re-read every entry against its spell's published text and its candidate
      guidelines' wording
- [x] **32.3** **Record which entries carry the risk — measured 2026-08-17 rather than
      estimated.** Of 206 entries, **186 have candidates that all share one base
      level** and 20 do not. The 186 are the ones no automated check can reach.
      Recording the split *per entry* in the ledger file itself is still worth
      doing, so the risky subset is visible while editing.
- **A demonstrated failure, not a theoretical one.**
  `lib-reim-image-from-wizard-torn` shipped for months pointing at `reim-15b`,
  *"Summon a disembodied spirit associated with Imaginem"*. The spell summons
  nothing — it relocates the caster's own image — and its rationale argued "no
  Arcane Connection involved" when the spell's own text says *"you must use an
  Arcane Connection to yourself"*. Corrected in `cf0b40b`.
- **Why nothing caught it:** both candidates are base level 15 — which is why the
  extractor could not disambiguate them — so assertion 1 computed the printed 35
  either way; assertion 3 saw an entry present; assertion 4 saw the id resolve.
  Every automated check passed.
- **The rule this establishes:** when an ambiguous spell's candidates share a base
  level, the printed-vs-computed assertion confirms the base level and nothing
  more. Those entries rest entirely on their written rationale.
- **The same holds for every General entry, for a related reason.** A General base
  effect has no fixed level to check against — `chosenBaseLevel` comes from the
  caster — so assertion 1 cannot discriminate a wrong General guideline at all.
  Assertion 6 (`test_general_catalog.py:163`) is the only automated check standing
  between an entry and a wrong General pick.
- **Item 39's *Conjuration of the Indubitable Cold* pick is a deliberate member of
  the 186** — both candidates share base level 4 and the choice between them was
  made arbitrarily on the grounds that it is cosmetic. Re-reading it should
  confirm that reasoning, not the pick.
- **Files:** `scripts/spell_import/resolutions.json`

---


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
      different quantities — but it is exactly what item 32 exists to check. **That
      template is also one of the three entries carrying an unreviewed candidate
      after item 55's migration, so it wants one re-read, not two.**
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


### 73. Deferred Minor Findings From Item 65's Reviews

**Opened 2026-08-18.** Item 65 ran nine task reviews plus a whole-branch
review. Their Critical and Important findings were fixed before merge; these
are the minors, judged non-blocking at the time and recorded here because
their only other home was a scratch ledger that has since been deleted. None
is a correctness bug.

- [ ] **73.1** **`parse_inline`'s damaged-stat-line branch is unexercised.** HoH:MC has
      zero damaged stat lines and no fixture covers it, so a polarity bug
      (reporting when it should skip, or the reverse) would go undetected.
- [ ] **73.2** **13 of HoH:MC's 16 blocks rest on an aggregate count.** Only three have
      their `prose` and `design_line` individually asserted; the rest are
      covered by `len(blocks) == 16` and `problems == []`, which would not
      catch a subtly wrong prose or design line on the other 13.
- [ ] **73.3** **`diagnose()` carries two lines of dead weight** — a
      `catalog_module.Catalog.load()` whose result is never used (and which
      reads the catalog off disk for nothing), and a reimplementation of
      `sources.read_lines` rather than a call to it. Both inherited verbatim
      from the plan text.
- [ ] **73.4** **`emit.CORE_BOOK_ID` is now referenced only by tests.** Production code
      threads the book id through instead. The comment justifying its survival
      names `catalog.CORE_BOOK_ID`, which is a different constant.
- [ ] **73.5** **A provenance test lost an assertion.** `test_names_the_absent_lock_...`
      dropped its `assertNotIn` guard against moved-source wording when it was
      adapted to the mapping API; its siblings still cover the wording.
- [ ] **73.6** **`provenance.load()` raises a bare `AttributeError` on a pre-mapping
      `source.lock`** rather than a message naming the cause. Only reachable by
      someone rebasing a branch that predates the format change.
- [ ] **73.7** **The per-book split stopped at `SKIPPED_BLOCKS`.** `SPELL_NAME_TYPOS`,
      `DESIGN_LINE_TYPOS`, `HAND_DERIVED`, `HAND_DERIVED_ADJUSTMENT` and
      `EXCEPTION_SPELLS` are still keyed by bare spell name across all books.
      Verified zero collisions today. `_reject_duplicate_ids` cannot catch a
      future one, because a name-keyed table misfires *before* ids are built —
      it changes the name, and so the id, so no collision ever materialises. A
      comment records this at the tables; a third book may force real keys.
- **See also:** item 65.
