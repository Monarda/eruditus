# Status

**Hand-maintained until the generator lands.** Every figure below was obtained by running something; re-verify before trusting.

## Where the import stands

**Live extractor run, 2026-08-18** (`python -m scripts.spell_import.extract_spells`):

> **336 imported · 31 templates · 8 exceptions · 0 blocked · 3 skipped · 0 unresolved**
> — plus `unreviewed: 7`, see below.

**Suite status: all three re-run 2026-08-19 at item 74's branch head — the
Dart count moved 742→745 for item 74's own three tests (bloc shapes B and C,
plus assertion 8):**

| Suite | Command | Result |
|---|---|---|
| Dart | `flutter test` | **745 tests, green** |
| Python | `python -m unittest discover -s scripts/spell_import/tests -t .` | **383 tests, green** |
| Integration | `flutter test integration_test -d windows` | **8 tests, green** — and now run by CI, see item 6 |

**7 ledger entries carry an unreviewed candidate** (was 3). Item 55's
migration carried three Creo Vim decisions past `crvi-hohmc-G1` without a
human weighing it; item 65's `revi-hohmc-G1` (a new general Rego Vim
guideline) widened four more — the four existing core-book entries it
touches kept their recorded choice unchanged, and the new id landed in
`unreviewedCandidates` rather than being folded into a rationale that never
weighed it. Each entry says so in its own `unreviewedCandidates` field. The
extractor prints the count on every run. Clearing it is a re-read, and
belongs to item 32.

**Catalog sizes, counted from the assets today:**

| Asset | Entries | Note |
|---|---|---|
| `base_effects.json` | 612 | 51 General — 49 core plus two supplement rows (item 17's one, plus item 65's `revi-hohmc-G1`); plus item 64's two Glamour guidelines |
| `parameters.json` | 39 | 25 core (item 15) + 9 virtue-gated (item 17) + 5 Sensory Targets (item 64) |
| `modifiers.json` | 35 | 34 plus item 65's `complexity` modifier |
| `spell_library.json` | 336 | 325 core + 11 HoH:MC (item 65) |
| `spell_templates.json` | 31 | 27 core-extracted + 4 hand-authored/HoH:MC-extracted (item 17's 1 plus item 65's 3) |
| `spell_exceptions.json` | 8 | item 46 |
| `resolutions.json` | 217 | item 32; 7 carry an unreviewed candidate |

**All 360 published Chapter 9 spells are still accounted for**, and item 65
adds *Houses of Hermes: Mystery Cults*' own 15 (11 library spells + 4
templates) alongside them: 336 + 31 + 8 = 375, 15 more than 360, all from
HoH:MC. No spell is blocked. HoH:MC's own 16 parsed blocks account as 11
library + 2 extracted templates + 3 deliberately skipped, with a 4th template
hand-authored rather than parsed. The 7 unreviewed entries are a ledger
problem, not a modelling gap.

**Standing finding: base-effect resolution rests on human judgement, and most
of it is unverifiable by test.** A design line names its guideline only by
level (`Base level 15`), and e.g. Creo Animal has four entries at level 15.
Measured 2026-08-17 across all 206 ledger entries: **186 have candidates that
all share one base level**, so the printed-vs-computed assertion confirms the
base level and nothing more — those rest entirely on their written rationale.
Only 20 have candidates whose levels differ, where assertion 1 discriminates.
See item 32.

**Two things confirmed as needing nothing further:**
- **The parameter catalog is complete.** Every Range, Duration and Target used
  by all 360 published spells resolves against item 15's 25 core entries.
- **The base-effect catalog matches the rulebook bullet-for-bullet**, per art
  in both directions, asserted by
  `test_general_entries_match_the_rulebook_bullet_for_bullet` — which since
  item 55 compares only the rows that cite the core rulebook, so a supplement
  guideline is neither a surplus nor a shortfall. Item 22's list of missing
  rows is now closed on the evidence; see that item.

**What the goal does and does not cover.** The goal is *computed level matches
printed level*, and the rulebook prints `#### GENERAL` instead of a number for
General-level spells — so a General template **can never satisfy the goal as
stated**. Item 25 solved the modelling (the caster picks a level) and routed
those spells to `spell_templates.json`; making templates genuinely
instantiable was items 35/37's job. Likewise Ritual correctness (item 18) and
ward mechanics (item 4) are fidelity work on spells the import already counts —
`extract_spells.py` gates on neither.

---
