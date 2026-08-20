# App

### 7. Spell Export/Backup Validation
- [ ] **7.1** Validate imported spells conform to the one-Range/Duration/Target constraint
- [ ] **7.2** Add migration for legacy spell saves (if any)
- [ ] **7.3** **Custom modifiers are absent from backup entirely.** Verified 2026-08-17:
      `BackupService.exportToJson` carries `customEffects` and `customParameters`
      only, though `app_database.dart` has a `custom_modifiers` table. A restored
      spell that selected a custom modifier resolves to nothing on import, so
      check 5 (single-selection cardinality) is silently skipped and the spell
      imports unvalidated on that axis. Consistent with the existing "unknown
      modifier id is tolerated" constraint — **not a regression** — but the gap
      should be closed with the rest of this item.
- **Round-trip coverage is done** (item 40 Task 7): the backup test calls through
  the real `exportToJson`/`importFromJson`; import now loads custom effects and
  parameters *before* spells, and uses `SpellRepository.saveAll`, so one invalid
  spell no longer aborts a restore (`BackupImportResult.rejectedSpells`).


### 9. Spell Tags / Library Organisation — half done
- [x] **9.1** `tags` field on the Spell model (`c4242d6`) — `List<String>`, serialized and persisted
- [ ] **9.2** Assign tags when creating or editing a spell
- [ ] **9.3** Filter/browse the library by tag
- [ ] **9.4** Support multiple tags per spell, and combine tag filters with the existing
      search + source filters
- [ ] **9.5** Decide: free-text, a curated vocabulary, or free-text with suggestions from
      existing tags
- **Model and persistence are done — what remains is purely UI.** No schema change
  needed. Verified 2026-08-17: no screen references `tags`, and 0 of the 325
  published spells carry any.
- **Rationale:** thematic grouping the Technique/Form axes can't express. A spell
  that raises a castle is both "defensive" and "architecture"; neither is derivable
  from Creo/Terram. Value rises sharply now the library holds 325 spells.
- **Files:** `lib/presentation/screens/spell_library_screen.dart` (tag filter UI),
  `lib/presentation/screens/spell_creation_screen.dart` (tag entry),
  `lib/bloc/spell_library/` (filter events/state)


### 16. Short Forms for Parameter Names
- [ ] **16.1** Decide whether parameters need a short display form at all — **confirm a real
      layout is constrained before building anything**
- [ ] **16.2** If so, add an optional `shortName` to `Parameter`, falling back to `name`
- [ ] **16.3** Add a small widget picking the longest form that fits the available width
- **Check the need first.** These names appear mostly in dropdowns, where width is
  rarely tight and substituting text makes selection confusing. More likely
  candidates are the spell card or the level-breakdown chips — measure first. **The
  rulebook abbreviates in exactly one place: the spell stat line
  (`R: Touch, D: Sun, T: Ind`).** If the app ever renders that line, that is the
  constrained widget.
- **Do NOT encode alternatives as inline markup** (e.g. `"B/ound/ary"`):
  presentation inside domain data means search, comparison, backup export and tests
  must all strip markup first; it can only express prefix truncation ("Arcane
  Connection" → "Arc" works, → "AC" does not); and **`/` already means something
  else here** — the rulebook uses it for equal-difficulty pairings (`Touch/Eye`,
  `Sun/Ring`, `Group/Room`, `Individual/Circle`).
- **Precedent:** `Book` carries `title` *and* `abbreviation` as separate fields; the
  wider precedent is CLDR, which models wide/abbreviated/narrow as named forms.
- **Flutter has no built-in string-alternatives system.** `FittedBox` scales glyphs;
  `TextOverflow.ellipsis` truncates crudely; `auto_size_text` shrinks the font. The
  real mechanism is `LayoutBuilder` + `TextPainter` with your own selection logic.
- **Note:** `Bound` → `Boundary` was a *data error* fixed by item 15, not evidence
  that abbreviations are needed. No `shortName` exists today (verified 2026-08-17).
- **Files:** `lib/models/parameter.dart`, `assets/data/parameters.json`


### 18. Storyguide-Ruling UI for Rituals — remaining questions only

The UI half is **✅ DONE 2026-08-16**: `RitualSection` is a three-way
`RadioGroup<RitualDeclaration>` (Not declared / Creates something lasting /
Storyguide ruling), wired through the existing `RitualDeclarationChanged` event.
The "Creates something lasting" option stays gated to Creo + Momentary; the
storyguide-ruling option is always shown, since Core Rules line 12352 lets the
troupe declare *any* spell a Ritual. `_withRitualDeclaration` already handled
`storyguideRuling` correctly — 5 new bloc regression tests passed immediately,
confirming no bloc change was needed. `TemplateInstantiated` copies a template's
declaration verbatim (deliberately, for cases like *Disenchant*), so the option's
visibility was widened to cover an ineligible-but-carried declaration rather than
letting it become a one-way clear.
Spec: `docs/superpowers/specs/2026-08-16-storyguide-ruling-ui-design.md`.

- [ ] **18.1** **Decide whether the two Vim Generals want a guideline flag rather than a
      per-spell ruling.** *Disenchant* (PeVi Gen) and *Watching Ward* (ReVi Gen)
      carry no declaration at all and are Ritual for reasons that look
      guideline-level — that would be a `ritualRequirement` on the base effect, not
      a declaration. The other 5 of the 7 non-derivable Ritual spells are settled:
      3 became `storyguideRuling` via item 49, and *Rain of Oil* / *Incantation of
      Summoning the Dead* derive independently.
- **Of 39 Ritual-flagged published spells, 32 derive today** from Year duration,
  Boundary target, level > 50, or the Creo+Momentary declaration. Current
  declaration spread in the asset (verified 2026-08-17): 30 `lastingCreation`,
  3 `storyguideRuling`, 292 none.
- **Spec:** `docs/superpowers/specs/2026-07-27-ritual-spells-design.md`


### 23. Ritual Spells Review — Remaining Test-Hygiene Findings
None affect correctness.

- [ ] **23.1** **A widget test title promises more than it asserts** — one test from the
      Ritual Spells work (`test/presentation/widgets/*` or
      `test/presentation/screens/spell_creation_screen_test.dart`; not pinned down
      further). Find it, then narrow the title or extend the assertions.
- [ ] **23.2** **The "no accidental Ritual" regression guard only checks
      `ritualDeclaration`**, not a full breakdown recompute — it could miss a case
      where `ritualDeclaration == none` but `RitualStatus`-derived reasons (a
      guideline flag, the >50 threshold) still fire. Assert on a recomputed
      `LevelBreakdown.ritualStatus.isRitual` instead.
- **✅ The JSON formatting bullet is resolved** — regeneration normalized
  `spell_library.json`; all 325 entries share one format (verified 2026-08-17).


### 33. Write-Only Columns on the `spells` Table — MAYBE, revisit when relevant
Filed as a *maybe*: nothing is wrong today. Pick this up only when a task lands in
this area — most likely item 9 (tag filtering) or item 7 (backup validation). **Do
not do it on its own.**

- [ ] **33.1** Decide whether to drop `name`, `source`, `created_at` and `updated_at` from the
      `spells` table, or to start using them
- **What was found** (still true 2026-08-17). `spells` is
  `(id, name, source, data, created_at, updated_at)`, where `data` holds the whole
  serialized `Spell` as JSON. `_toRow` writes both the projected columns *and* the
  blob from the same object, but every read goes through `jsonDecode(row['data'])`
  and every query is either `where: 'id = ?'` or a bare `query('spells')`. Those four
  columns are **write-only duplication**: drift risk, no benefit.
- **The blob is the right design here and should stay.** The table holds **only
  user-created spells** (published ones load from the asset); `Spell` carries four
  nested collections whose normalization means four or five join tables serving
  queries nothing issues; and **the interesting joins are impossible in SQL anyway** —
  `baseEffectId`, `rangeId` and the rest point into JSON assets, not tables.
- **If per-spell predicates ever outgrow Dart-side filtering**, the fix is a generated
  column or an index on a JSON path — not a schema rewrite.
- **Files:** `lib/data/database/app_database.dart`,
  `lib/data/datasources/local_spell_datasource.dart`


### 10. Documentation
- [x] **10.1** Update README — DONE 2026-08-17 (`97d316c`, see item 29)
- [ ] **10.2** Add a Size feature guide to docs
- [ ] **10.3** Document the Aquam sub-type limitation (see *Notes*)


### 11. Performance
- [ ] **11.1** Optimize base effects JSON (611 effects, all loaded at startup)
- [ ] **11.2** Consider lazy loading or caching if the app grows
- **Re-measure now the library holds 325 spells**, each computing a level on load.
  This item's premise is only now testable. See also item 38's efficiency bullet.


### 56. Rules Hints — What a Choice Means, and Where It Comes From

**Opened 2026-08-17, from item 14's brainstorm.** A general gap, not a bug: the
creation screen offers choices whose rulebook meaning is invisible. The user
sees a name and a magnitude and has to already know the rules. Pure UI work, no
model change, no fidelity risk — deferred on purpose.

**⚠️ Asked for directly by the user, 2026-08-17**, in the same pass that opened
items 59-61: *"there needs to be a help mouseover or other way of bringing up a
more detailed explanation of what is being chosen and why"*. That is this item,
and it moves it from "found while doing something else" to requested work —
consider its position in section D accordingly.

- [ ] **56.1** **Decide the affordance, which the item did not previously cover.** A
      hover tooltip is desktop-only; the app also builds for Android and iOS,
      where there is no hover, so a mouseover alone cannot be the whole answer.
      Likely an info icon opening a sheet or popover, with the tooltip as the
      desktop convenience on top of it — one source of text, two ways in.
- [ ] **56.2** **Decide the coverage bar.** The user's ask is "what is being chosen and
      why", which reaches every control on the creation screen — Technique,
      Form, base effect, all three parameters, modifiers, requisites,
      adjustments, Ritual — not only the four instances listed below. Those are
      where the gap was *noticed*, not its extent.

**Concrete instances found so far.** These are examples of one need, not
separate items:

- **`target-bloodline` carries a built-in ongoing rule that nothing surfaces.**
  The spell "applies to all members of the bloodline born during its duration,
  as well as those already living when it is cast" (core 10046). A user picking
  it gets no hint. Found while writing item 14's spec, which deliberately does
  *not* give Bloodline a static/dynamic control — the behaviour is the Target's
  own rule, not a per-spell choice, so it is display work and belongs here.
- **Circle's "ends if the circle is broken"** — same class, and it interacts
  with Ring Duration in a way the two dropdowns never show.
- **`requiresVirtue` renders as bare label text** ("Bloodline (+3, requires
  Faerie Magic)") and `requiresRitual` renders as nothing at all in the
  dropdown. Both are informational only — there is no character/Virtue model
  (`parameter.dart:40-44`) — but the *reason* is unexplained.
- **Item 14's segmented control ships its own one-off helper line.** That is the
  first instance of this pattern; if a general mechanism lands, fold it in
  rather than leaving one bespoke explainer behind.

**⚠️ The one decision that stops this being "pure UI."** Where does the hint
text live?
- **UI copy** — hardcoded strings beside each control. Genuinely pure UI, and
  what makes this deferrable, but hand-maintained and unable to cite anything.
- **Catalog data** — a new `Parameter`/`BaseEffect` field, importable and
  citable, but then it needs importer work and an extraction source, and it
  stops being a UI item.

Decide this first when picking the item up; the estimate swings entirely on it.

**⚠️ Two 2026-08-20 findings push this decision toward catalog data.** (a) The
licence is CC BY-SA 4.0, so a hint may **quote the rulebook verbatim** rather
than paraphrase it (item 79) — and quoted text with a page reference is
extraction output, not hand-written UI copy. (b) Item 80.3 routes rules text
through the catalog per source edition, never through ARB. Both point the same
way, so the "hardcoded UI copy" option is weaker than it looked when this item
was written. **Items 78, 79 and 80 are all upstream of this decision** — that is
why they were opened.

**~~⚠️ Citations cannot supply page numbers.~~ RETRACTED 2026-08-20 — see item
78.** This item previously recorded that `Citation.page` "structurally cannot be
filled" because the markdown carries no page markers. That was measured against
the book's *body* and never tested against its *indexes*. The markdown holds
**1650 `[page](#anchor)` pairs across four index tables, 97.3% of which resolve
to real headings**, including a Spells Index and a Spell Guidelines Index — the
two things this catalog actually cites. **A hint may name a page.** Plan the
"see p. 112" affordance; item 78 supplies the data, and 78.6 settles which
edition the number belongs to (Definitive Edition — decided 2026-08-20).

- **Files:** `lib/presentation/screens/spell_creation_screen.dart`,
  `lib/models/parameter.dart` and `assets/data/parameters.json` (only if the
  catalog-data route wins)


### 58. Container Target Mode — UX Seam Between the Bloc/UI Work and the Derived Predicate

**Opened 2026-08-17, from item 14's whole-branch final review.** Six follow-ups,
none blocking, all polish on the container-mode feature closed as item 14.

- [x] **58.1** **`ContainerModeSelected` hides the level breakdown.** It emits
      `status: SpellCreationStatus.editing`
      (`lib/bloc/spell_creation/spell_creation_bloc.dart:170`), and the screen
      gates the results block on `status == calculated`
      (`lib/presentation/screens/spell_creation_screen.dart:81-83`). Picking a
      mode makes the level card vanish and forces a recalculate, for a field
      the design calls level-neutral. **`SummaryChanged` has the identical
      wart** — fix both events together rather than leaving them inconsistent.
      The most user-visible of the six. **⚠️ Superseded by item 59**, which
      makes the level card live and so unhideable by *any* edit — do that
      instead of patching these two events, and close this bullet with it.
      **✅ DONE 2026-08-17 via item 59.** The emit funnel recomputes the level
      on every event, so no edit can hide it — including these two. Both
      events' tests now assert the recomputed breakdown compares *equal*
      (they previously asserted `same`, which encoded the old contract).
- [ ] **58.2** **The control nudges a decision the model says is not owed.** It renders
      for any container Target (`spell_creation_screen.dart:255`), and on a
      Momentary container spell the helper line still reads "Not recorded… so
      it is worth deciding" (`:819`) even though `spellOwesContainerMode` says
      such a spell owes nothing and the importer deliberately leaves the 5
      Momentary rows unset. ⚠️ The obvious fix — the widget consulting
      `spellOwesContainerMode` — would give that predicate a **production
      caller**, which item 14's design deliberately withheld so it stays the
      hook a future character-library feature flips to a requirement. Needs a
      design decision first, not just a patch.
- [ ] **58.3** **A user-authored custom Target can never carry a mode.**
      `lib/presentation/screens/configuration_screen.dart:285-291` builds a
      custom `Parameter` with no `targetType`, so the control never appears
      and check 9 would reject a mode on it anyway. Item 14's design cited
      exactly this case as the reason to make the kind catalog data.
      `requiresRitual`, `requiresVirtue` and `scope` are equally unsettable
      there already — fix the family, not just this field.
- [x] **58.4** **A latent hole in `_withPrunedFormScopedParameters`**
      (`lib/bloc/spell_creation/spell_creation_bloc.dart:379-388`): it can null
      the target without clearing `containerMode`, so a mode stated under Room
      could survive a Form change and reattach to the next container chosen.
      **Unreachable today** — `duration-fire` is the only Form-scoped
      parameter and no Target is scoped — but the helper is generic and
      `TargetSelected` is currently the only place the mode/Target coupling is
      maintained.
      **✅ ALREADY CLOSED — verified 2026-08-18 during item 64.** Not latent:
      stale. `_seedParameters` ends with
      `containerMode: keepsMode ? null : ContainerMode.unstated`, computed from
      the *resulting* Target, and every caller of the pruning helper wraps it in
      `_withSeededParameters` — so a Target pruned to null always reaches a mode
      clear one call later. `git log -S` dates that line to `8143c8e`, the
      draft-reference-seed work, which landed after this bullet was written.
      Item 64 gave the helper a second axis and looked for the hole to confirm
      it; there was none to fix.
- [ ] **58.5** **An importer id mismatch aborts before the diagnostics exist.**
      `apply_container_modes` raises at
      `scripts/spell_import/extract_spells.py:919`, before the run's report is
      assembled. If a spell named in `container_modes.json` later falls into
      `blocked`/`unresolved`, the operator sees
      `UnknownContainerModeSpell: names spells no run produced` — wrong in
      that case, since the run did produce the spell, just into another
      bucket — instead of the report explaining why it disappeared. Failing
      loudly is right; failing before the report exists is not.
- [ ] **58.6** **The ward rationale does not engage the strongest counter-reading.** All
      8 entries in `container_modes.json` cite Core Rules 12166, but 12164
      says a ward's "target is the thing protected, rather than the things
      warded against" and 12168 says such wards "target the circle itself,
      which cannot leave the circle" — a reading under which the Target is
      fixed at casting, i.e. static. The branch's `dynamic` reading is right (a
      static ward would let a demon walk in after casting, contradicting
      12166), but whoever works item 57 will hit this tension on the first
      non-ward Circle spell. One sentence in the shared rationale addressing
      12164/12170 would pre-empt it. See item 57.
- Also worth a line: the segmented control is untested below 1200 logical px —
  `test/presentation/screens/spell_creation_screen_test.dart:143-148` sets a
  1200×5000 view, and the three labels ("Not stated", "Static", "Dynamic")
  will be tight on a 320dp phone.
- **See also:** item 14 (closed, `## Completed ✅`), item 57, item 59


### 76. Creation-Screen UI for Picking a Cross-Form Base Effect
**Opened 2026-08-19**, rescued from item 48's closed body where it was left open
deliberately and then became unreachable when that item was archived.

Item 48 landed the by-analogy model — a spell can borrow a base effect from
another Technique/Form and record why — but a user cannot reach it interactively.

- [ ] **76.1** Design and build the creation-screen affordance for choosing a
      cross-Form base effect, including how the analogy rationale is captured.
- **Spec:** `docs/superpowers/specs/2026-08-16-base-effect-analogy-design.md`
- **See also:** items 48 (closed, `ARCHIVE.md`), 47.


### 79. Quoting Rules Text Directly — What CC BY-SA 4.0 Permits and Demands

**Opened 2026-08-20.** Item 56 assumed hint text would have to be *paraphrased*
UI copy, because the licence position was never checked. It has been now:
`Ars-Magica-Open-License/LICENSE.md` is **Creative Commons
Attribution-ShareAlike 4.0 International**. §2(a)(1) grants the right to
"reproduce and Share the Licensed Material, in whole or in part". **So we may
quote rules text verbatim, and 56's hints can be the rulebook's own words rather
than our gloss of them.**

Two conditions ride along, and both are product decisions, not legal trivia:

- [ ] **79.1** **Attribution (§3(a)) needs somewhere to live in the app.** The licence
      requires retaining creator identification, a copyright notice, a notice
      referring to the licence, a disclaimer notice, and a URI to the licensed
      material — plus **an indication that we modified it** (§3(a)(1)(B)), which
      we have: the `reviewed/` markdown is itself a corrected transcription.
      §3(a)(2) allows satisfying this "in any reasonable manner based on the
      medium", including by linking to one resource that carries it all. Decide
      the affordance: an About/Licences screen, a footer on quoted text, or
      both.
- [ ] **79.2** **⚠️ ShareAlike (§3(b)) may reach eruditus itself.** If embedding quoted
      rules text makes the app "Adapted Material", the adapter's licence must be
      CC BY-SA 4.0 or a compatible one. **This is the decision with real
      consequences and it should be made deliberately, before quoted text is
      designed into a feature** — retrofitting a licence choice after the fact
      is far worse than making it now. Note the catalog JSON is arguably already
      a database derived from the Licensed Material (§4), so this question may
      predate item 56 entirely.
- [ ] **79.3** **Decide how much to quote, and mark it as a quote.** A hint that
      reproduces a guideline verbatim must be visually distinguishable from our
      own words, or the app silently attributes its own paraphrases to the
      rulebook. This is the coupling to 56.1's affordance decision.

- **Trademark is explicitly *not* licensed** (§2(b)(2)). The grant covers the
  text, not "Ars Magica" as a mark — so this item does not settle naming,
  branding or store-listing questions.
- **No warranty, and no endorsement** (§5, §2(a)(6)): the app must not imply
  Atlas Games endorses it.
- **Files:** `assets/data/` (if quoted text becomes catalog data — see 56's
  "UI copy vs. catalog data" decision), a new About/Licences screen
- **See also:** items 56 (the consumer of this permission), 78 (a quote and its
  page reference are the same affordance), 30 (provenance)


### 80. Flutter Internationalisation for All User-Facing Text

**Opened 2026-08-20, asked for directly by the user.** No translation is wanted
yet; the goal is that adding one later is not a rewrite. Nothing is wired today:
**no `intl`, no `flutter_localizations`, no `l10n.yaml`, no ARB files.**

**Smaller than it looks.** `lib/presentation/` is **8 files** carrying roughly
**115** candidate literals (of 55 Dart files in `lib/` total). This is a day of
mechanical work, not a fortnight — the estimate should not be used as a reason
to defer it.

- [ ] **80.1** **Stand up the mechanism**: `flutter_localizations` + `intl`,
      `l10n.yaml`, `generate: true`, one `app_en.arb`, and `MaterialApp`'s
      `localizationsDelegates`/`supportedLocales`.
- [ ] **80.2** **Migrate the existing literals**, and add a guard that stops new bare
      literals reaching `lib/presentation/` — otherwise the migration decays
      immediately. Flutter ships the `flutter_lints` rules for this; decide
      whether to enable them repo-wide or scope them to `presentation/`.
- [ ] **80.3** **⚠️ Decide how the text populations localise differently — the one
      genuinely hard question here. ✅ Answered by the 2026-08-20 spec; kept open
      until the code matches it.** There are **three**, not two — designing the
      contribution restructure surfaced the third — and they do not travel the
      same road:
      - **App chrome** — our own labels, buttons, helper lines. Translated by us,
        lives in ARB files, keyed by locale. Ordinary l10n.
      - **Rules text** — quoted from the rulebook (item 79). **This is
        translatable, but not by us and not through ARB.** Ars Magica has been
        published in translation, and more may follow; the right source for
        French rules text is the French edition, not our rendering of the
        English one. So a locale selects a *source edition*, and the catalog
        carries per-edition text — the ARB pipeline never sees it.
      - **⚠️ User content** — an adjustment's `note`, and any prose the caster
        typed. **Nobody translates it; it renders verbatim under every locale.**
        Never in ARB, and explicitly **exempt from the pseudo-locale
        transform**, or the proof harness raises false failures on the user's
        own words. This is the one the item originally missed.
      **The failure mode to design against is a translator being handed rules
      strings in an ARB file**, where they would produce an unofficial
      translation that the app then presents as the rulebook's own words.
      Keeping rules text out of ARB is what prevents that, not a claim that it
      cannot be translated at all.
      **The boundary rule the spec settles on:** *ARB holds the vocabulary that
      labels the interface; the catalog holds the content the rulebook prints;
      user content passes through untouched.* So "Range" is chrome — it labels a
      control — while "Voice" is content.

- **Sequencing matters against item 56.** 56 introduces a large volume of new
  user-facing strings. Doing 80.1 first means they land localised; doing it
  after means a second pass over the same text. **Neither ordering is wrong, but
  doing 80 *during* 56 is** — decide before 56 starts.
- **Names in the catalog are not UI strings.** Spell, Technique, Form and
  parameter names come from `assets/data/*.json`. Some are Latin and stay put
  under any locale (*Creo*, *Ignem*); the rest are rulebook English that a
  published translation would render differently. Either way they are data
  reached through 80.3's edition route, never ARB.
- **⚠️ The engine composes user-facing prose, and that is the real work.**
  `spell_engine.dart` builds display strings at 7 sites and hands them to
  `LevelBanner` pre-formatted, in domain code where no `BuildContext` and so no
  locale can reach. **The level breakdown is untranslatable in principle until
  `LevelContribution` carries structure instead of a `String label`** — adding
  ARB files does not touch it. Decided 2026-08-20 to fix it in this item rather
  than defer. De-risker: `LevelBreakdown` is **never persisted** (no
  `toMap`/`toJson`; outside `lib/engine/` it appears only in
  `SpellCreationState.breakdown` and `LevelBanner`), so there is no migration,
  no backup-format change and no asset change.
- **Spec:** `docs/superpowers/specs/2026-08-20-internationalisation-design.md`
- **Files:** `pubspec.yaml`, new `l10n.yaml` + `lib/l10n/app_en.arb`,
  new `lib/engine/contribution_source.dart`,
  `lib/presentation/format/contribution_formatter.dart`,
  `test/support/pump_app.dart`, `tool/gen_pseudo_arb.dart`,
  `lib/engine/spell_engine.dart` + `level_breakdown.dart`,
  `lib/presentation/**` (8 files), `lib/main.dart`, and the 10 test files
  holding 47 inline `MaterialApp` constructions
- **See also:** items 56 (the string-volume driver), 79 (why the boundary
  exists), 16 (short forms — a translated label breaks any width assumption
  that item makes)


### 81. Latin as the First Real Locale

**Opened 2026-08-20**, split out of item 80 so the proof harness and a shipped
translation stay separate concerns. Latin is the obvious first language for this
app — the game's whole vocabulary is Latin already — but it is **not** the right
*test* language, and item 80 keeps the generated pseudo-locale for that.

**Why it is not the test language.** The pseudo-locale's job is to make the
three-population boundary visible: `[Ŕaňģe····] · Voice` shows accented chrome
beside plain rulebook content, so a boundary mistake is obvious on sight. In
Latin, chrome and content look alike — the app's content vocabulary is *already*
Latin (*Creo*, *Ignem*, *Vim*) — so the very thing the harness exists to reveal
is camouflaged. Latin is also inflected and often **shorter** than English, so it
exercises layout in the opposite direction to the pseudo-locale's ~30% padding.

- [ ] **81.1** **Translate the chrome, and have a human review it.** Machine-translated
      Latin is weak — thin parallel corpora next to major languages — and this
      game's audience is unusually Latin-literate. MT is an acceptable *first
      draft* and an unacceptable *ship*.
- [ ] **81.2** **⚠️ Decide the fallback for rules content, which Latin forces first.**
      There is **no published Latin edition of Ars Magica**, so under item 80.3's
      rule a Latin locale has no Latin source for rulebook content and must fall
      back to English. **This is the first real exercise of the mixed-locale
      path** — Latin chrome around English rules text — and whatever it settles
      applies to every later locale whose edition does not exist. A locale
      whose book *has* been published (French, Spanish) never hits this, so
      Latin is the useful case to design against, not the awkward one.
- [ ] **81.3** **Do not translate the Art and Form names.** `ArsArts`/`ArsForms` are
      already Latin (`constants.dart`) and are correct as printed. A Latin
      locale must leave them exactly as they are — the risk is an MT pass
      "translating" already-correct Latin into different Latin.

- **Blocked on item 80** — there is no ARB pipeline to translate into until it
  lands.
- **Files:** new `lib/l10n/app_la.arb`, `lib/main.dart` (`supportedLocales`)
- **⚠️ Item 82 must be settled before this item runs.** 81.1 permits MT as a
  first draft; item 82 is the flag that tracks which strings are still in that
  state. Producing MT text without it means the burn-down starts unrecorded.
- **See also:** items 80 (the mechanism and the pseudo-locale), 80.3 (the
  boundary rule this item is the first real test of), 79 (whether a translated
  quotation is still the licensed material), 82 (the MT flag)


### 82. Machine-Translation Provenance for User-Facing Text

**Opened 2026-08-20**, from the item 81 discussion. Nothing to build yet —
English is the original, not a translation — but the convention should be fixed
**before** item 81 produces the first machine-translated string, not retrofitted
afterwards.

**⚠️ This is partly a licence obligation, not only a quality signal.** CC BY-SA
§3(a)(1)(B) requires indicating **if you modified the Licensed Material**. A
machine translation of quoted rules text is a modification. So the moment MT
touches rulebook content, a marker stops being optional. See item 79.

- [ ] **82.1** **Decide the granularity — recommended: per string, not per locale.**
      Translation review is incremental; a locale is rarely wholly machine or
      wholly reviewed. Item 81.1 already draws the line at "MT is an acceptable
      first draft and an unacceptable ship", and a per-string flag is what turns
      that into a burn-down a release can be gated on. A file-level
      `@@x-translation-status` is the cheaper alternative and cannot express a
      half-reviewed locale — though 82.2 proved the two **compose**: set the
      file-level default, override per string as review lands.
      **⚠️ Do not stamp `original` onto every `app_en.arb` entry.** The template
      file is the original *by definition* — `l10n.yaml` declares
      `template-arb-file: app_en.arb` — so the value is derivable, and storing it
      anyway would force a `@key` metadata block onto ~115 strings that need
      none. That is item 33's write-only-duplication antipattern in a new place.
      **The flag belongs on non-template locales only.**
- [x] **82.2** **✅ VERIFIED 2026-08-20: `gen-l10n` tolerates custom ARB metadata.**
      Probed against Flutter 3.44.8 with an isolated package. Accepted at both
      levels, **exit 0 and no warnings**, with correct getters generated
      including a typed `counted(int count)` placeholder method:
      - **file level** — `@@x-generated`, `@@x-translation-status`
      - **per string** — `x-translation-status` inside a `@key` block
      - **on a non-template locale**, and a per-string value **overriding** a
        file-level default (`@@x-translation-status: machine` with one entry
        marked `reviewed`) — which is the exact shape 82.1 needs.
      **So the flag lives inside the ARB files. No sidecar is required**, and the
      shape-change risk this sub-item was guarding against does not exist.
- [ ] **82.3** **Decide what the flag actually drives.** At least one of: a release
      gate that refuses to ship an MT-flagged string in a shipped locale; an
      in-app disclosure that a translation is machine-generated (which is also
      the §3(a)(1)(B) indication); a reviewer filter listing what still needs
      human eyes. **A flag nothing consumes is worse than no flag** — it implies
      a guarantee nobody is enforcing.

- **It spans two stores, not one.** Chrome translations live in ARB; rules
  content lives in the catalog per source edition (item 80.3). Both can carry MT
  text, so the convention has to work in both places or it will be applied to
  whichever is convenient and forgotten in the other.
- **The pseudo-locale is generated but is not a translation.** `app_xx.arb` is a
  test artefact that never reaches a user as a language. Mark it
  `@@x-generated`, not machine-translated, or the burn-down is permanently
  polluted by ~115 entries that will never be reviewed.
- **Precedent:** this repo already takes provenance seriously — item 30's
  `source.lock` and `provenance.py` do exactly this for the import. Follow that
  shape rather than inventing a second vocabulary.
- **See also:** items 81 (produces the first MT text and is where this must be
  in place), 79 (the licence obligation), 80.3 (the two stores)
