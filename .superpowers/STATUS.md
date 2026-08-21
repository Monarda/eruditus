# Status

**Hand-maintained until the generator lands.** Every figure below was obtained by running something; re-verify before trusting.

## Where the import stands

**Live extractor run, 2026-08-18** (`python -m scripts.spell_import.extract_spells`):

> **336 imported · 31 templates · 8 exceptions · 0 blocked · 3 skipped · 0 unresolved**
> — re-run 2026-08-19 after item 32.1: same counts, and the `unreviewed` line is
> gone (it prints only when the count is non-zero). Re-run again the same day
> after item 32.2's first two entries: same counts (a corrected guideline at
> the same base level moves no count).

**Suite status: Dart re-run 2026-08-21 at item 79's (licensing/attribution)
branch head; Python and Integration last run 2026-08-20 at item 80's. The Dart
count moved 745→782 across items 74 through 80, then 782→818 across item 79's
plan A — 36 tests covering the §3(a) notice as data, the repo licence files,
the About screen, and the pseudo-locale guard's fifth screen:**

| Suite | Command | Result |
|---|---|---|
| Dart | `flutter test` | **818 tests, green** |
| Python | `python -m unittest discover -s scripts/spell_import/tests -t .` | **397 tests, green** — re-run 2026-08-20 at item 80's branch head, same count as 2026-08-19's run; +6 there for the report/lock guard, the second combined-effect spell, and audit coverage |
| Integration | `flutter test integration_test -d windows` | **8 tests, green** — and now run by CI, see item 6 |

**0 ledger entries carry an unreviewed candidate** (was 7), and the count can no
longer be raised by adding a book. Item 55's migration had carried three Creo
Vim decisions past `crvi-hohmc-G1` and item 65's `revi-hohmc-G1` had widened
four more. Item 32.1 read all seven and every recorded choice stood — both
supplement rows are virtue-gated Rituals about binding a familiar and uniting
an automaton's effects, and all seven spells are `arm5-core` with no virtue.
That by-hand pass then showed the questions should never have been asked:
under the user's scoping rule a core spell may only use core rows, so
`catalog.visible_books` now narrows candidates by the spell's own book. The
seven candidate lists dropped the supplement row, the rationales reverted to
their pre-32.1 text, and `test_a_core_spell_is_never_offered_a_supplement_row`
guards the rule. Extractor counts are unchanged and it no longer prints the
`unreviewed` line. See DECISIONS.md — this revises item 55.

**Catalog sizes, counted from the assets today:**

| Asset | Entries | Note |
|---|---|---|
| `base_effects.json` | 612 | 51 General — 49 core plus two supplement rows (item 17's one, plus item 65's `revi-hohmc-G1`); plus item 64's two Glamour guidelines |
| `parameters.json` | 39 | 25 core (item 15) + 9 virtue-gated (item 17) + 5 Sensory Targets (item 64) |
| `modifiers.json` | 35 | 34 plus item 65's `complexity` modifier |
| `spell_library.json` | 336 | 325 core + 11 HoH:MC (item 65) |
| `spell_templates.json` | 31 | 27 core-extracted + 4 hand-authored/HoH:MC-extracted (item 17's 1 plus item 65's 3) |
| `spell_exceptions.json` | 8 | item 46 |
| `resolutions.json` | 217 | item 32, closed; 0 unreviewed candidates, 0 unaudited |

**All 360 published Chapter 9 spells are still accounted for**, and item 65
adds *Houses of Hermes: Mystery Cults*' own 15 (11 library spells + 4
templates) alongside them: 336 + 31 + 8 = 375, 15 more than 360, all from
HoH:MC. No spell is blocked. HoH:MC's own 16 parsed blocks account as 11
library + 2 extracted templates + 3 deliberately skipped, with a 4th template
hand-authored rather than parsed.

**The rulebook checkout is pinned at `ffc1c6b`** (2026-08-18, "tiny spelling
fix in spell"), adopted 2026-08-19. Its only edit corrects the "Sense the Feet
That *Thread* the Earth" heading to "Tread" — the correction
`SPELL_NAME_TYPOS` was already applying — so adopting it changed no asset.

**Standing finding: base-effect resolution rests on human judgement, and most
of it is unverifiable by test.** A design line names its guideline only by
level (`Base level 15`), and e.g. Creo Animal has four entries at level 15.
Re-measured 2026-08-19 across all 217 ledger entries: **every one has
candidates that all share a single base level**, so the printed-vs-computed
assertion confirms the base level and nothing more — all 217 rest entirely on
their written rationale. This holds by construction: `Catalog.candidates()`
selects rows by `baseLevel == base_level` and `general_candidates()` by
`baseLevel is None`, so a candidate set is never level-mixed.

The earlier figure here — "186 of 206 share one base level, 20 do not" —
**was wrong**, and is corrected above. Re-running the measurement against the
commit that recorded it (`186419d`) gives 0 entries with differing candidate
levels; the 20 were the all-General entries, which are *more* exposed, not
less. Assertion 1 discriminates among candidates on no entry at all. See item
32.3.

**Item 32 is closed.** All 217 entries were swept by a blind model pass and 4 corrected.
Eight Sonnet agents, candidates shuffled, answers withheld: **207 agreements,
10 disagreements, 4 self-flagged**. `lib-inte-tracks-faerie-glow` and
`lib-inte-sense-feet-that-tread-earth` moved to `inte-4b` (item 39 had
resolved three spells on one shared argument that holds for only one of them);
`lib-peco-twist-tongue` moved to `peco-15b` (speech is not a sense);
`lib-crig-heat-searing-forge` and `lib-peig-conjuration-indubitable-cold` both
turned out to be combined-effect spells rather than single-guideline ones.
Two model flags were the model being wrong where the ledger was right (*Wind of
Mundane Silence*, *Trackless Step*) — read the flags, don't obey them.

The item closed on a **redefined criterion**: not "a human has verified every
entry", which is unreachable at 217 and absurd at the 1,000+ the remaining
books will bring, but "every entry has been through an independent blind audit
and every disagreement has been adjudicated". Every entry now carries an
`audit` block — **204 `agreed`, 13 `adjudicated`, 0 unaudited** — and
`AuditCoverageTest` fails if a pick or candidate set moves without a fresh
audit. The ledger is audited, **not** verified; see DECISIONS.md. A new book
owes an audit of its own entries only.

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
