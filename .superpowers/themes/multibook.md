# Multibook

### 66. HoH:MC's 36 Faerie "Animae" Guidelines (sub-project C)

**Opened 2026-08-18.** A bulk catalog sweep, deliberately separated from item 65
so it cannot block the spells: only 1 of HoH:MC's 38 new guidelines is used by
any of its example spells, and item 64 already added that one.

The table is regular — `### <Form>` → `#### <Technique> <Form>` →
`**Level N:** <description>`, at `Ars Magica 5e - Houses of Hermes - Mystery
Cults.md:3465-3621` — 36 Creo/Muto "create or change a faerie" rows across the
ten Forms, all gated on Faerie Magic.

- [ ] **66.1** Decide whether to extract by script or hand-author. The core base-effect
      extraction is the precedent for the former; item 17's single row for the
      latter.
- [ ] **66.2** Set `requiresVirtue: "Faerie Magic"` on every row, matching
      `crvi-hohmc-G1`.
- [ ] **66.3** Check the ids against the `<te><fo>-hohmc-<level>` convention item 64 used,
      and against item 41's row-duplication concerns.
- **See also:** items 64, 65, 17


### 71. The Anchored-but-Unparseable Rate, Measured Across Three More Inline Books

**Opened 2026-08-18, from item 65's diagnostics.** The 52-book corpus survey
behind item 65 classified how spell blocks are *anchored*; it never checked
whether an anchored block *parses*. `extract_spells --diagnose` (item 65,
Task 5) makes that check possible, and running it against the three other
inline-heavy books for the first time is this item's finding. Full numbers,
raw `--diagnose` output and per-failure breakdown are **no longer on disk** —
they lived in the plan's scratch workspace, which is deleted when a plan
completes. Re-derive with `extract_spells --diagnose "<title>" --parser inline`
against each book; the table below is the durable record.

| Book | Blocks | With design line | Tokenized | Notes |
|---|---|---|---|---|
| Covenants | 0 | 0 | 0 | 42 of 44 candidate stat lines have their `TeFo Level` anchor one blank line above, not directly above; `parse_inline`'s anchor check requires direct adjacency. |
| Houses of Hermes: Societates | 0 | 0 | 0 | Same failure mode: 50 of 59 stat lines have a blank-line-separated anchor. |
| Transforming Mythic Europe | 38 | 37 | 23 | Anchoring itself is mostly fine (41 of 84 stat lines anchor directly); tokenization fails on free-prose modifiers (11 of 14 failures), prose embedded in the parenthetical (2), and 3 malformed stat lines (missing comma before `D:`). |

- [ ] **71.1** **Anchor-matching gaps, cheap and mechanical if ever done.** Tolerate a
      blank line between the `TeFo Level` anchor and the stat line (closes
      Covenants and Societates almost entirely — 92 of 103 stat lines between
      them); tolerate a trailing `, Ritual` on the anchor line and a
      parenthetical requisite form (`Mu(Re)Im 10`); accept spelled-out
      `General` alongside `Gen`. None of this was attempted here — it is scope,
      not a bug, in `blocks.parse_inline`.
- [ ] **71.2** **Design-line vocabulary gaps, not cheap.** TME's 14 tokenization
      failures are free-hand modifier prose (`+4 transport seven leagues`,
      `+1 unsupported surface`, `+3 Special Target`…) that would each need
      either a new vocabulary entry or a deliberate decision that the phrase
      is intentionally free text. This is per-phrase judgement, not a
      pattern fix.
- [ ] **71.3** **The 3 malformed TME stat lines** (`R: Touch D: Momentary, T: Group,
      Ritual`, missing the comma before `D:`) are a plausible candidate for a
      `_normalize_stat_line`-style fix — noted, not acted on, per this item's
      own diagnostic mandate.
- **The dominant remaining cost is per-book ledger curation, not parser
  code.** Even a fully anchor- and vocabulary-complete parser only produces
  *candidate* blocks — every tokenized block still needs a human to choose
  its base-effect ledger entry. The core book needed **206** human ledger
  decisions for **325** spells; HoH:MC needed **11** for **14**. Scaled by
  that ratio, importing even TME's 23 currently-tokenizing spells would cost
  on the order of 15-20 ledger rulings before parser work on the other 15
  blocks even starts — and Covenants and Societates currently tokenize zero.
  **No import of any of these three books should be scoped as a parser task;
  it is a ledger-curation task with a parser prerequisite.**
- **Files (if ever acted on):** `scripts/spell_import/blocks.py`
  (`_INLINE_ANCHOR`, `_inline_anchor`), `scripts/spell_import/designline.py`
  (the modifier vocabulary), `scripts/spell_import/statline.py`
  (`_normalize_stat_line`)
- **See also:** item 65 (closed, `## Completed ✅` — the parser and the
  diagnostic mode this measures with), item 32 (ledger curation as its own
  cost centre)
