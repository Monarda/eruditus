# Eruditus — Item Index

**Now:** 32

**Standing goal:** every published spell in the Definitive Edition core rules
is either (a) in the spell library with its computed level matching its
printed level, (b) a template whose caster-supplied choices are left open
(item 25/37), or (c) recorded as an exception spell with a citation-backed
reason the guidelines don't apply to it (item 46).

**How this works:** item numbers are stable global ids, never reused and never
renumbered. Themes are files; the table below is the only thing that maps a
number to its home. `open 3/7` means three of seven sub-ids remain open.
Standing constraints live in `DECISIONS.md`; closed bodies in `ARCHIVE.md`;
live counts and suite results live in `STATUS.md`.

**Kind legend:** `decide` = a question is open and nobody has answered it;
`do` = the decision is made, the work is not; `maybe` = deliberately filed as
not-yet-worth-doing.

| #  | Kind | Status | Home | Title |
|----|------|--------|------|-------|
| 1 | — | closed | ARCHIVE.md | Spell Constraint: One of Each Parameter (`2d897db`) |
| 2 | — | closed | ARCHIVE.md | Requisites UI & Integration |
| 3 | — | closed | ARCHIVE.md | Size Feature (MVP) |
| 4 | do | open 3/3 | rules-fidelity.md | Conditional Wards *(the last open piece of the original item 4)* |
| 4b | do | open 1/1 | rules-fidelity.md | Intensity/Damage Modifiers |
| 4c | do | open 1/1 | rules-fidelity.md | Level-Dependent Might Reduction |
| 5 | — | closed | ARCHIVE.md | Asset Data Loader Test Failures |
| 6 | — | closed | ARCHIVE.md | Widget-Test Coverage Hole — DONE 2026-08-17 |
| 7 | do | open 3/3 | app.md | Spell Export/Backup Validation |
| 8 | — | closed | ARCHIVE.md | UI: Disable Multi-Select for Range/Duration/Target — OBSOLETE |
| 9 | do | open 4/5 | app.md | Spell Tags / Library Organisation — half done |
| 10 | do | open 2/3 | app.md | Documentation |
| 11 | maybe | open 2/2 | app.md | Performance |
| 12 | do | open 2/2 | rules-fidelity.md | Out-of-Scope Effects Handling |
| 13 | — | closed | ARCHIVE.md | Summary/Description Entry for User-Created Spells — DONE 2026-08-17 |
| 14 | — | closed | ARCHIVE.md | Container Targets: Static vs. Dynamic — DONE 2026-08-17 |
| 15 | — | closed | ARCHIVE.md | Add All Core-Rulebook Parameters (`c835d0a`) |
| 16 | decide | open 3/3 | app.md | Short Forms for Parameter Names |
| 17 | — | closed | ARCHIVE.md | Virtue-Gated Parameters: Merinita Faerie Magic and Symbolic Magic — DONE 2026-08-16 |
| 18 | decide | open 1/1 | app.md | Storyguide-Ruling UI for Rituals — remaining questions only |
| 19 | — | closed | ARCHIVE.md | Size-Ladder Ceiling — COMPLETE 2026-08-16 |
| 20 | decide | open 1/1 | rules-fidelity.md | Creo Creation `suggested` Ritual Sweep |
| 21 | decide | open 1/1 | rules-fidelity.md | Creo Mentem Memory Restoration |
| 22 | decide | open 1/1 | rules-fidelity.md | Catalog Extraction Gaps — ✅ effectively closed; one question remains |
| 23 | do | open 2/2 | app.md | Ritual Spells Review — Remaining Test-Hygiene Findings |
| 24 | — | closed | ARCHIVE.md | Ad-hoc Level Adjustments |
| 25 | — | closed | ARCHIVE.md | General-Level Spells — base level is chosen, not fixed |
| 26 | — | closed | ARCHIVE.md | Non-standard Ranges, Durations and Targets |
| 27 | — | closed | ARCHIVE.md | Published Spell Import Harness |
| 28 | — | closed | ARCHIVE.md | Guideline Levels Absent from the Rulebook's Own Table — 5 of 5 |
| 29 | — | closed | ARCHIVE.md | Open Follow-ups from the Import-Harness Review — DONE 2026-08-17 |
| 30 | — | closed | ARCHIVE.md | Rulebook Source Provenance (`77c8b01`) |
| 31 | do | open 1/1 | importer.md | Real Per-Spell Summaries — Ledger-Authored |
| 32 | do | open 1/3 | importer.md | Audit `resolutions.json` — no Test Can Check It |
| 33 | maybe | open 1/1 | app.md | Write-Only Columns on the `spells` Table — MAYBE, revisit when relevant |
| 34 | — | closed | ARCHIVE.md | Guidelines Missing From the Catalog (`8a70889`, `87ac754`) |
| 35 | — | closed | ARCHIVE.md | Open Guideline Slots — Realm, Form, "Specific Type" — DONE 2026-08-14/15 |
| 36 | do | open | rules-fidelity.md | Audit the Catalog's `description` Fields Against the Rulebook |
| 37 | — | closed | ARCHIVE.md | A Template Has Open Slots Beyond Its Level |
| 38 | do | open 6/7 | importer.md | Open Follow-ups from item 25's Whole-Branch Review |
| 39 | — | closed | ARCHIVE.md | Ambiguous Ledger Resolutions Needing a Rules Decision — 4 of 4 |
| 40 | — | closed | ARCHIVE.md | Model Invariants Have Only One Enforcement Path — COMPLETE 2026-08-16 |
| 41 | maybe | open | rules-fidelity.md | Row-Duplication Ladders Across the Catalog (item 28's shape, elsewhere) |
| 42 | decide | open 1/1 | rules-fidelity.md | Derived Ease Factor Display for Poison/Disease Guidelines |
| 43 | — | closed | ARCHIVE.md | Transport-Distance Modifier Wiring — DONE 2026-08-15 |
| 44 | — | closed | ARCHIVE.md | Bare/Non-standard Requisite-Magnitude Phrasing — DONE 2026-08-15 |
| 45 | — | closed | ARCHIVE.md | Design-Line Tokenizer Doesn't Recognize Transport-Distance Labels |
| 46 | — | closed | ARCHIVE.md | Exception Spells — DONE 2026-08-16, 8 total |
| 47 | decide | open 3/3 | model.md | Multiple Base Effects in Spell Creation — Combined Guidelines |
| 48 | — | closed | ARCHIVE.md | Base Effect Analogy — DONE 2026-08-16 |
| 49 | — | closed | ARCHIVE.md | `emit.py` Mistagged Ritual Declarations — DONE 2026-08-16 |
| 50 | decide | open 1/1 | rules-fidelity.md | `size-terram` on an Intellego Spell — Rulebook-Printed Exception to the `excludeTechniques` Rule |
| 51 | — | closed | ARCHIVE.md | `flutter test --platform chrome` Hangs Forever on Windows — RESOLVED 2026-08-16 |
| 52 | — | closed | ARCHIVE.md | Bottom Navigation Bar Was Effectively Invisible — FIXED 2026-08-16 |
| 53 | decide | open 1/1 | model.md | Bargain Duration's Nested Level Computation |
| 54 | decide | open 1/1 | model.md | Open/Variable Requisites (Per-Casting, Not Per-Catalog-Entry) |
| 55 | — | closed | ARCHIVE.md | The Catalog Stopped Being Core-Rules-Only — RESOLVED 2026-08-17 |
| 56 | decide | open 2/2 | app.md | Rules Hints — What a Choice Means, and Where It Comes From |
| 57 | decide | open 3/3 | model.md | The Remaining 16 Container Rows Still Owe a Static/Dynamic Ruling |
| 58 | do | open 4/6 | app.md | Container Target Mode — UX Seam Between the Bloc/UI Work and the Derived Predicate |
| 59 | — | closed | ARCHIVE.md | The Spell Level Computes Live (`99aa462..e6a61b4`) |
| 60 | — | closed | ARCHIVE.md | Drafts Seed From Their Guideline's Reference Triple (`657c491`) |
| 61 | — | closed | ARCHIVE.md | Clearable Single-Select Modifiers (`337adb4`) |
| 62 | — | closed | ARCHIVE.md | Every State Field Has an Owner (`940c8bc..e7774cd`) |
| 63 | decide | open 3/3 | rules-fidelity.md | The Ritual Default Is Form-Blind, and Imaginem/Mentem Pay for It |
| 64 | — | closed | ARCHIVE.md | HoH:MC Catalog Rows and the Intellego Exclusion (`2983b57..497ea1f`) |
| 65 | — | closed | ARCHIVE.md | HoH:MC Spell Extraction — the Inline Block Parser (sub-project B) (`7ebd409..757e9a8`, merged `1a6783e`) |
| 66 | do | open 3/3 | multibook.md | HoH:MC's 36 Faerie "Animae" Guidelines (sub-project C) |
| 67 | decide | open 1/3 | model.md | The Sensory Magic Restrictions the Model Cannot Yet Express |
| 68 | — | closed | ARCHIVE.md | Do the Sensory Targets' `targetType` Values Misrepresent Their Container Mode? (`c60a03d..eb28b18`, merged `1a6783e`) |
| 69 | decide | open 3/3 | model.md | Constraint-Handling Pains Deferred From the Cross-Field Design Discussion |
| 70 | do | open 2/3 | importer.md | Three Defects Found by the 52-Book Constraint Survey |
| 71 | do | open 3/3 | multibook.md | The Anchored-but-Unparseable Rate, Measured Across Three More Inline Books |
| 72 | — | closed | ARCHIVE.md | Three Latent Defects the Second Book Exposed (`9b21925`, `757e9a8`) |
| 73 | — | closed | ARCHIVE.md | Deferred Minor Findings From Item 65's Reviews (`4a2030f`, `df15b84`) |
| 74 | — | closed | ARCHIVE.md | Guideline Adoption Can Still Seed a Range/Target Pair Check 10 Rejects (`5bfd5e8`, `f75c2c9`) |
| 75 | decide | open 1/1 | rules-fidelity.md | Should Group/Room/Structure/Boundary Cost Differently Under the Size Ladder? |
| 76 | decide | open 1/1 | app.md | Creation-Screen UI for Picking a Cross-Form Base Effect |
