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
- [x] **32.1** **The entries that named their own gap — DONE 2026-08-19, 7 of 7.**
      Item 55's migration carried three Creo Vim decisions past `crvi-hohmc-G1`
      and item 65's `revi-hohmc-G1` widened four Rego Vim entries, each
      recording the fact in `unreviewedCandidates`. Both supplement rows are
      excluded on the rules: `crvi-hohmc-G1` binds a supernatural creature as a
      temporary familiar and is gated behind the Faerie Magic Outer Mystery;
      `revi-hohmc-G1` unites an automaton's instilled effects and is gated
      behind Craft Automata. Both must be Rituals. All seven spells are
      `arm5-core`, carry no virtue, and five are not Rituals.
      **Then fixed at source instead.** The user's scoping rule — a core spell
      uses core rows only — makes all seven questions structurally impossible,
      so `Catalog.candidates()`/`general_candidates()` now narrow by the spell's
      book (`catalog.visible_books`), the seven candidate lists dropped the
      supplement row, and the rationales went back to their pre-32.1 text
      because the row they weighed is no longer offered. The by-hand clearing
      is what the fix was diagnosed from; the guard against a repeat is
      `test_a_core_spell_is_never_offered_a_supplement_row`. See DECISIONS.md,
      which records this as a revision of item 55.
- [ ] **32.2** Re-read every entry against its spell's published text and its candidate
      guidelines' wording. **2 of 217 done, 2026-08-19** — the two this item
      already named as suspect, and one of them was wrong:
      - `lib-crig-heat-searing-forge` **corrected, `crig-4a` → `crig-4d`.** The
        Creo Ignem table runs four parallel ladders, and *Heat of the Searing
        Forge* is on "Heat an object" (2 warm to the touch, 3 hot to the touch,
        4 boil water, 5 glow red-hot): its own first sentence is "Heats a piece
        of metal so that it is **too hot to touch**", above level 3 and below
        red-hot. It creates no fire, so "Create a fire doing +5 damage" is the
        wrong ladder — compare *Blade of the Virulent Flame*, which does form a
        fire on metal and pays base 5 for the unnatural shape. The old
        rationale argued from the numeric coincidence of "+5 damage" alone and
        dismissed `crig-4d` as having "no damage stated"; the +5 here decays to
        +3 then +1 and armour padding grants +3 Soak against it, which is
        heated metal, not a conjured fire's flat rating. Both rows are base
        level 4, so no computed level moved and no test could have caught it.
      - `lib-peig-conjuration-indubitable-cold` **pick confirmed, model
        widened from two combined effects to three.** The spell achieves all
        three Perdo Ignem level-4 guidelines and pays for one. The old
        rationale dismissed `peig-4a` by claiming the spell only *shrinks*
        fires; it does both, and "campfires and smaller fires go out" is a
        full extinguish, since the Ignem base Individual is "a large campfire"
        (line 14260) — exactly the size a base-4 extinguish reaches, with
        larger fires only reduced because destroying a more intense one costs
        a magnitude per five damage above +5 (line 14461). A first correction
        argued `peig-4a` away as a free consequence of the chill; that was
        also wrong, and the user caught it — **air at slightly below freezing
        does not put out a campfire**, so the extinguishing is a separate
        effect, not a byproduct. All three are level 4, so under the
        Requisites section's "the base Arts and level for the spell are those
        for the highest-level effect it has" (line 12372) the other two are
        free. `COMBINED_BASE_EFFECTS` took a single `(magnitude, note)` pair
        and now takes a sequence, since this is the first spell needing two.
        The same wrong reasoning had been copied into `KNOWN_UNRESOLVABLE`'s
        comment and is corrected there too.
        **Caveat worth carrying:** line 12372 is written for a *requisite* —
        an added Art — and extending it to two guidelines of the same
        Technique and Form is this repo's inference, not a printed rule. It is
        the closest the core rules come, and nothing contradicts it, but a
        troupe could read it more narrowly.
      - **This is the second demonstrated failure of exactly the kind this item
        was opened for**, after `lib-reim-image-from-wizard-torn` (`cf0b40b`).
        Both were fluent, plausible rationales arguing from one salient detail
        while the spell's own opening sentence said otherwise. Two for two on
        the entries anyone bothered to look at twice is not a reassuring base
        rate for the 215 not yet re-read.
- [x] **32.3** **Record which entries carry the risk — re-measured 2026-08-19, and
      the earlier figure was wrong.** The 2026-08-17 measurement said 186 of 206
      entries had candidates sharing one base level and 20 did not. Re-running it
      against that same commit (`186419d`) gives **0** entries with differing
      candidate levels — the 20 were the all-General entries (`baseLevel: null`),
      not level-discriminable ones. Today: **217 entries, 0 discriminable**, 195
      numbered and 22 General-only. This is true *by construction* —
      `Catalog.candidates()` selects rows by `baseLevel == base_level` and
      `general_candidates()` by `baseLevel is None`, so a candidate set is always
      level-uniform, and that function is unchanged since `7fdbb1c`. Assertion 1
      therefore discriminates among candidates on **no** entry, not on 20 of
      them. There is no per-entry split left to record: the risky subset is the
      whole ledger.
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
  more. Those entries rest entirely on their written rationale — and per 32.3
  that is every entry, not a subset.
- **The same holds for every General entry, for a related reason.** A General base
  effect has no fixed level to check against — `chosenBaseLevel` comes from the
  caster — so assertion 1 cannot discriminate a wrong General guideline at all.
  Assertion 6 (`test_general_catalog.py:163`) is the only automated check standing
  between an entry and a wrong General pick.
- **Item 39's *Conjuration of the Indubitable Cold* pick is the deliberate case of
  this kind** — both candidates share base level 4 and the choice between them was
  made arbitrarily on the grounds that it is cosmetic. Re-reading it should
  confirm that reasoning, not the pick.
- **32.2 cannot be handed to a cheap model — measured 2026-08-19.** A blind
  20-entry eval (spell text + candidate guideline wording, answers withheld,
  candidate order shuffled) scored Haiku 4.5 at 19/20 against the ledger. The one
  miss was `lib-reim-image-from-wizard-torn`, planted as the known-defect case:
  Haiku reproduced the original `reim-15b` error, at `medium` confidence, with the
  Arcane Connection clause present in its input, and flagged nothing as ambiguous
  in the whole run. Sonnet also scored 19/20 but caught that item and flagged 3 of
  20 as genuinely ambiguous — including its own sole disagreement
  (`lib-crig-heat-searing-forge`, `crig-4d` over the recorded `crig-4a`). The
  usable shape is therefore *model as flagger, human as adjudicator*: a Sonnet
  pass at a ~15% flag rate queues roughly 30 of 217 entries for a human read, and
  the unflagged remainder stays unverified rather than becoming verified. Caveat:
  n=20 with exactly one certified ground truth (`cf0b40b`), and "agreement with
  the ledger" scores agreement with the artifact under audit. Eval harness is not
  committed; regenerate from this description if it is worth repeating.
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
