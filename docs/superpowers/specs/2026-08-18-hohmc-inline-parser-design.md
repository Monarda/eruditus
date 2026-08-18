# HoH:MC Inline Block Parser and Multi-Book Plumbing — Design

**Date:** 2026-08-18
**Closes:** todo item 65 (sub-project B)
**Follows:** item 64 (HoH:MC catalog rows), which landed the Targets and
guidelines this pass consumes.

## Goal

Import the 14 spells *Houses of Hermes: Mystery Cults* prints, by teaching
`blocks.py` a second anchor style and making the importer's one hard-coded
book into a parameter. Prove the machinery generalises without spending the
curation budget that importing every anchored book would demand.

## Why this is the real test

Item 64 established that the *catalog* half generalises: item 55's book-aware
oracles absorbed a second book's Targets and guidelines with no structural
change. The *parser* half has never been tested, because `blocks.parse_de`
anchors on a heading structure only the Definitive Edition uses. Zero of
HoH:MC's 16 blocks are visible to it.

A corpus survey across 54 books (recorded in item 64's spec) found 3107 stat
lines in four anchor styles. The inline style is 664 of them across 16 books,
so this parser pays for far more than 14 spells — but importing those books is
explicitly **not** in this pass. See "Scope boundary".

## Scope boundary

**No spell from any book but HoH:MC enters `spell_library.json` in this pass.**

The multi-book plumbing mechanically unlocks 20 heading-style books (771
blocks) that `parse_de` can already read. Importing them is a separate, much
larger decision: at the core book's observed ratio of ~0.63 human ledger
decisions per imported spell, the anchored non-core corpus implies roughly
1000 rulings. That is an adjudication project, not an engineering one.

Other books are reachable in this pass only through `--diagnose`, which parses
and reports but writes nothing.

## Architecture

Four layers change. `designline`'s tokenizer core, `catalog`, `ledger`, the
level arithmetic and every assertion stay as they are — they never learn that
more than one book exists.

### 1. Book registry — `sources.py`

```python
@dataclasses.dataclass(frozen=True)
class Book:
    id: str      # books.json id, e.g. "arm5-hohmc"
    title: str   # markdown filename stem in the rulebook checkout
    parser: str  # key into blocks.PARSERS

BOOKS: tuple[Book, ...] = (
    Book("arm5-core",  DE_TITLE,                                           "de"),
    Book("arm5-hohmc", "Ars Magica 5e - Houses of Hermes - Mystery Cults", "inline"),
)
```

The registry title differs from the books.json display title
(`Houses of Hermes - Mystery Cults` against `Houses of Hermes: Mystery Cults`),
which is exactly why the mapping is explicit rather than derived. A test
asserts every `Book.id` appears in `assets/data/books.json`: that join is what
keeps emitted citations honest.

### 2. `blocks.parse_inline` — `parse_de` untouched

`parse_de` imports 325 working spells and is not to be generalised into a
mode-switching parser. The new function stands beside it, and
`PARSERS = {"de": parse_de, "inline": parse_inline}` selects between them.

One rule, applied to blockquote-stripped lines:

> A stat line is a spell when the line directly above it matches
> `(Cr|In|Mu|Pe|Re)(An|Aq|Au|Co|He|Ig|Im|Me|Te|Vi)\s+(\d+|Gen)`, and the name
> is the line above that, as either `##### Name` or `**Name**`.

The `TeFo Level` line supplies technique, form and printed level directly, so
no section-heading state machine is needed — the whole `_SECTION`/`_LEVEL`
apparatus `parse_de` carries has no analogue here.

`Gen` yields `printed_level = None`, the same signal `#### GENERAL` produces,
which is what routes a spell to `spell_templates.json`.

Accepting `**Name**` alongside `##### Name` is not scope creep: *Ball of
Abysmal Music* is the one HoH:MC spell that uses it, and rejecting it would
lose a real spell to a typesetting difference. It also happens to absorb most
of the corpus's separate "bold-name" anchor style for free.

**Blockquote handling is already solved.** `statline.strip_markup` strips
leading `>` via its `_LEADING` pattern, which is why 16/16 HoH:MC stat lines
already parse today despite most of them sitting inside blockquotes. The only
new need is a variant that strips the quote marker while *preserving* `**`, so
bold names remain recognisable:

```python
def strip_quote(line: str) -> str:
    """Blockquote markers and <br> removed; emphasis markup preserved."""
    return _BR.sub("", _LEADING.sub("", line)).rstrip()

def strip_markup(line: str) -> str:
    return _BOLD.sub("", strip_quote(line)).strip()
```

`strip_markup` is redefined in terms of `strip_quote` so one definition backs
both and its existing behaviour is unchanged.

Prose and design-line collection reuse `parse_de`'s approach: scan forward to
the next anchor or design line. The window must not be a fixed line count —
*Form of the (Temperament) Heartbeast* puts four variant paragraphs between
its stat line and its design line.

A stat line with no `TeFo Level` line above it is skipped silently and
counted, exactly as `parse_de` skips creature powers. Those blocks are
overwhelmingly not spells; see item 65's note on the unanchored blocks.

### 3. Design-line vocabulary — `designline.py`, `emit.py`

Only 4 of HoH:MC's 16 design lines tokenize today. Four narrow changes fix
every one that belongs to an importable spell:

| Change | Recovers |
|---|---|
| Five sensory Targets into `PARAMETER_LABELS` | 7 spells |
| `_BASE_GENERAL` accepts `Base Effect` beside `Base effect` | 1 spell |
| `"necessary requisites"` into `_BARE_REQUISITE_LABELS` | 1 spell |
| `_resolve_requisite_label` → `_resolve_requisite_arts` (plural) | same spell |

The first is a gap item 64 left open: it added `Flavor`, `Texture`, `Scent`,
`Sound` and `Spectacle` to `parameters.json` but never taught the tokenizer
their design-line labels, so every spell using one blocked.

`_BASE_GENERAL` gains `[Ee]ffect`/`[Ss]pell` explicitly rather than
`re.IGNORECASE`, which would also loosen the `Base` and `As ward guideline`
alternatives it shares the pattern with.

**The requisite change is the only one with judgement in it.** *Embrace of
Boethius* declares `Req: Vim, Corpus` and charges `+2 necessary requisites`.
`_resolve_requisite_label` today returns one art and raises when a spell
declares more than one — deliberately, so the importer never guesses a
distribution. The widening keeps that discipline:

```
labelled token          -> [token.label]
exactly one declared    -> [that art]
magnitude == art count  -> every declared art, each "adding"
anything else           -> raise, exactly as today
```

The guard is what makes it safe: `+2` across two declared requisites is the
book's own arithmetic, not an inference. Any other ratio still blocks. The
token's magnitude feeds the level sum unchanged either way — only attribution
moves. Two call sites, `emit.py:176` and `emit.py:314`.

`"necessary requisites"` joins a closed allow-list rather than becoming a
pattern, matching that table's stated discipline. It occurs exactly once in
all 54 books.

### 4. Multi-book `run()`

`run()` loops `BOOKS`, dispatching each to its registered parser and threading
`book.id` into `build_spell`, `build_template` and `build_exception_spell` in
place of the hard-coded `CORE_BOOK_ID`.

**`source.lock` becomes a dict keyed by book id.** `provenance.load`, `write`
and `matches` go per-book, and `SourceMoved` names which book moved. The
format change needs no migration path — prototype rules, and the lock is a
record that regenerates.

**Spell ids stay flat** (`lib-<tefo>-<slug>`, no book segment). They are also
the 206 `resolutions.json` keys; namespacing them would churn every one for no
correctness gain. Instead a **hard duplicate-id check** runs across the merged
output: a cross-book name collision fails the build loudly rather than
silently merging two spells into one row.

**Per-book skip list**, each entry carrying its reason:

- *Perceive the Change* — an enchanted-device effect, not a spell:
  `Pen 0, constant effect`, costing `+1 two uses/day, +3 environmental
  trigger`. The app models no enchantments. Its stat line mis-parses to
  `T: Ind Pen`, which is the tell.
- *Faerie Chains of the Familiar Slave* — already in
  `hand_authored_templates.json` from item 17. Without the skip the parser
  fights the committed asset.
- *Tie the Threads That Bind* — hand-authored for the same reason; see below.

**`--diagnose "<title>" --parser inline`** parses any book, prints
parsed/blocked/problems counts and detail, and writes nothing. Books outside
`BOOKS` are reachable this way and only this way.

## The automata guideline

*Tie the Threads That Bind* (ReVi Gen, `(Base Effect, +1 Touch, +2 Group)`)
has no Rego Vim guideline anywhere in HoH:MC. The book states the spell's own
level rule — "the final spell level must equal or exceed the automaton's Magic
Might + 15" — and prints no guideline row for it.

This is structurally identical to *Faerie Chains of the Familiar Slave*, and
gets item 17's treatment exactly:

- A new catalog row `revi-hohmc-G1`: *"Unite an automaton's instilled effects
  into a cohesive whole (level >= construct's Magic Might)"*, `baseLevel:
  null`, `ritualRequirement: "required"`, `requiresVirtue: "Craft Automata"`
  (HoH:MC line 4652: "Knowing this Mystery grants the Major Hermetic Virtue
  Craft Automata"), citing `arm5-hohmc`. No `effectFormula`, for the same
  reason `crvi-hohmc-G1` has none: the Might threshold ties to the total
  computed level rather than `chosenBaseLevel`, and the guideline offers no
  reference that would make those coincide.
- The template itself hand-authored beside *Faerie Chains*, because a general
  guideline without an `effectFormula` cannot be built by the extractor.
- `migrate_ledger --write` afterwards. The new row widens the 4 existing ReVi
  general entries, which gain `unreviewedCandidates: ["revi-hohmc-G1"]`. That
  is the honest record, and the precedent is exact: `crvi-hohmc-G1` widened 3
  CrVi entries the same way, and they carry the same marker today.

`target-group` is `targetType: object`, so this template owes no container
mode.

## Ledger decisions

Eleven spells face multiple candidates. Each ruling below was made by reading
the spell's own prose against the candidate guideline descriptions.

| Spell | Cand. | Chosen | Rationale |
|---|---|---|---|
| Revenge of the Bitten Toad | 4 | `pean-15b` | prose: victims "suffer a Heavy Wound" — verbatim the guideline |
| Scent of the Predator | 2 | `crme-4a` | "overwhelming sensation of menace and hostility" is an emotion placed in a mind, not a restored memory |
| Marking the Territory | 2 | `reco-3a` | the design line glosses itself: `[move in direction "away"]` |
| Clarion Call of the War Horse | 2 | `mume-3b` | "heartened by its tone", +3 to a Personality Trait — emotion, not memory |
| Brilliance of the Eagle's Plumage | 5 | `crig-5c` | "blinded by the brilliant light shining from his body"; creates no fire and heats nothing |
| Closed Mouth of the Nightwalker | 2 | `peme-10a` | "instantly forgets that he did so" — one brief memory, not a general reduction of mental capability |
| The Voice of the Bjornaer Magus | 3 | `muan-5b` | the caster stays the same animal and gains an unnatural vocal capacity; not a change into a different animal, and not animal products |
| Form of the (Temperament) Heartbeast | 3 | `muan-5b` | same reading: the animal is unchanged, its temperament correspondences unnaturally enhanced |
| Embrace of Boethius | 3 | `peme-15a` | "destroying a part of his understanding of formulaic spell casting" — a major, long memory; not emotions, not insanity |
| Facilitate the Stifled (Form) Spell | 3 | `muvi-G1` | removes a casting penalty, leaving the spell otherwise intact — superficial; the prose's "less than twice the level of this spell" matches G1's doubling tier against G2's and G3's tighter ones |
| The Rooster's Crow | 13 | `pevi-G3` | "lose Might equal to the spell's (level divided by 5)" is *Demon's Eternal Oblivion*'s own wording, and that spell resolves to `pevi-G3` in this ledger already |

Two spells need no entry: *Hibernation of the Slumbering Turb* resolves to the
sole candidate `reme-4`, and *Ball of Abysmal Music* to `muim-hohmc-10` — item
64's Glamour guideline, resolving its intended spell uniquely on first use.

## Container modes

HoH:MC line 1002 states that all five Sensory Targets are continuously
acquired throughout the spell's duration. That is `ContainerMode.dynamic`,
fixed at the Target level with no per-spell choice offered. `Sound` and
`Spectacle` are `targetType: container`, so `spellOwesContainerMode` demands an
answer for four spells:

- `lib-mume-clarion-call-war-horse` (Sound)
- `tpl-pevi-roosters-crow` (Sound)
- `lib-crig-brilliance-eagles-plumage` (Spectacle)
- `lib-peme-closed-mouth-nightwalker` (Spectacle)

All four record `dynamic`, citing line 1002. `Flavor`, `Texture` and `Scent`
are `object` and owe nothing.

That a Target-level fixed mode has to be recorded as four identical per-spell
choices is the model smell item 68 is open on. This pass records the answer
and does not attempt the redesign.

## Expected outcome

**14 spells.** 11 into `spell_library.json`, 2 extracted General templates
(*The Rooster's Crow*, *Facilitate the Stifled (Form) Spell*) and 1
hand-authored template (*Tie the Threads That Bind*) into
`spell_templates.json`. Plus 11 ledger entries, 4 container-mode entries and 1
base-effect row.

*Form of the (Temperament) Heartbeast* keeps its literal placeholder name. It
is a fixed-level spell, not a template, and the book prints one stat block for
its four variants — one row is the faithful reading.

## Diagnostics

`--diagnose` is run against the three inline-heavy books item 65 names:
Covenants (42/44 inline), HoH:Societates (50/59), Transforming Mythic Europe
(68/84). Their results are recorded in the todo, not acted on.

**A long failure list is the expected result, not a fault.** Only cheap
resolutions of the kind `_normalize_stat_line` already precedents may land;
anything needing a rules decision is logged and left. The survey classified
anchors, it never verified that an anchored block parses, so the
anchored-but-unparseable rate is genuinely unknown and worth measuring.

## Testing

- `parse_inline` unit tests on fixture lines covering: blockquoted and plain
  blocks, `##### Name` and `**Name**`, `Gen` and numeric levels, a stat line
  with no `TeFo` line above it (skipped), and a design line separated from its
  stat line by intervening paragraphs.
- `strip_quote` preserves `**`; `strip_markup` behaviour unchanged.
- `_resolve_requisite_arts`: one labelled art, one bare art, two arts with
  magnitude 2, and two arts with magnitude 3 (must still raise).
- The registry/books.json join.
- The duplicate-id check, on a synthetic collision.
- Regeneration idempotency, as today, now across both books.

Both suites must pass — `flutter test` and the Python suite — plus the
integration test. `flutter analyze` must exit 0. `dart format` is never run in
this repo.
