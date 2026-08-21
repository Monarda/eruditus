# Standing Decisions and Constraints

Standing constraints, organised by topic, each citing the item it came from.
They are distilled from the closed bodies in `ARCHIVE.md`, which is **not**
loaded by default — so an entry here is the only reachable statement of its
rule. Anything below still binds: contradicting one is a decision to revisit
it, not something to do in passing. Live counts and suite results live in
`STATUS.md`; the item index is `todo.md`.

## Prototype, not production
Backwards compatibility is not a goal and the database is droppable, so a
serialized-shape change needs no migration story. Correctness beats
compatibility. Records already stored invalid likewise get no migration
story — they are rejected where they are validated, not converted.  *(item 40)*

## Source of truth and provenance

**Source of truth for the import:**
`Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md`,
Chapter 9 (lines 12020–16004). One supplement is also in the catalog as of item 17:
*Houses of Hermes: Mystery Cults* (`arm5-hohmc`).

**Source precedence:** the rulebook repo holds the same book in `reviewed/` and `wip/`,
in descending quality. **Always resolve `reviewed` → `wip` and stop at the first hit.**
Filenames differ between folders, so match on book title. (`raw-md/` was unreviewed OCR
and has been removed upstream.) The original base effects came from `raw-md` — item 22
reconciles the two.

`ARS_RULEBOOK_ROOT` overrides the rulebook location; CI relies on it. Source
identity lives in a committed sidecar (`scripts/spell_import/source.lock`),
**never in the asset itself**, and `provenance.py`/`report.py` are testable with
zero rulebook dependency — keep them that way.  *(item 30)*

**`RegenerationTest`'s failure message is drift-aware.** It checks `source.lock`
to tell "the source moved" from "the asset was hand-edited" — do not flatten the
two into one message while simplifying it.  *(item 30)*

**`--write` is gated on `--accept-source`**: adopting a moved rulebook is always
explicit. The one carve-out is that a `--write` under an *unchanged* source
refreshes the lock's advisory counts, which are otherwise only ever written when
the source moves, and had silently drifted to 294 against 325.  *(items 30, 55)*

**A defect in the source's transcription is fixed in a typo table**
(`DESIGN_LINE_TYPOS`, `SPELL_NAME_TYPOS`), not by loosening a parser. *The
Bountiful Feast*'s missing closing paren is the worked example.  *(item 26)*

**Per-book source identity is merged, not rewritten.** When `source.lock`'s drift
branch fires, write back only the entries that actually matched over the loaded
lock. Writing every book's identity there can launder a book whose markdown moved
but was never accepted: its new sha256 is recorded as attested, the next run sees
a match, and no change report is ever written.  *(item 72)*

## What may enter the catalog

**A catalog row must never be reconstructed from a spell's own prose in order to
receive that spell.** Tried twice (`peme-G`, `inco-gen`) and reverted both times;
`test_general_entries_match_the_rulebook_bullet_for_bullet` now holds the catalog
to the rulebook's own bullets, per art and in both directions, permanently. The
reverse direction is the one that catches this.  *(items 25, 34)*

**The catalog is flat, and stays flat** (decided by the user). It is one pool,
never partitioned per book. What follows from that: the oracles must say which
rows they mean — `catalog.cites(entry, book_id)` plus `CORE_BOOK_ID` — and the
core-only tests keep their **exact** counts rather than relaxing to a bound,
because an exact total is something every new supplement has to bump anyway.
`test_loads_the_committed_catalogs`'s parameter count is deliberately a
floor.  *(item 55)*

**A spell may only use rows from books it could have been printed against**
(decided by the user). Core spells use core base effects, modifiers and
parameters only; a supplement spell uses core rows, its own book's, and
*Mysteries Revised*'. `catalog.visible_books(book_id)` is the rule and both
`candidates()` and `general_candidates()` apply it, so the narrowing is scoped
at source. **This revises item 55's second half**, which made resolution
book-blind and called an out-of-scope row "a ledger decision, not a filter".
Book-blind resolution meant every new supplement widened the candidate sets of
spells printed years earlier and handed a human the backlog: all seven entries
item 32.1 cleared were HoH:MC rows offered to core spells that could never
legally use them. **Adding a book must not reopen a decided question about an
existing spell.**  *(items 55, 32)*

**There is deliberately no exception mechanism for that scoping rule** (decided
by the user). Real exceptions are expected to be rare; the first one fails
loudly — `StaleEntry`, or "no base effect at that Technique/Form/level" — and
the escape hatch gets designed against that concrete case rather than guessed
at in advance.  *(item 32)*

**A supplement row's id carries its book** (`crvi-hohmc-G1` cites `arm5-hohmc`),
and the id-suffix test derives that segment from the row's own citation, so the
convention is enforced rather than merely followed.  *(item 55)*

**Deleting a catalog row means re-checking every ledger *candidate* list, not
just the chosen ids.** Removing `peig-10b` would have silently dropped a real
corpus spell whose ledger entry still named the deleted row as a candidate; a
test now asserts the ledger and `NUMBERED_OVERRIDES` never silently disagree.
This is the same failure shape as item 55, one layer down.  *(items 28, 55)*

**A perceived modelling gap may be an extraction gap.** Characteristic Point
Scaling looked like a missing feature; each rung was already its own base effect
and the rows had simply been dropped in extraction. Check the rulebook's own
table before designing a mechanism.  *(items 4, 22)*

**If the base-effect asset is ever rebuilt, it must reproduce the full catalog,
and item 34's bullet-count comparison is the first test to run.** Nobody knows
why the original extraction dropped rows, and the producing script is not in the
tree, so a rebuild has no way to inherit the fix.  *(items 34, 22)*

**Bullet counts compared per art, in both directions, is the shape that works.**
A dropped bullet in one art and an invented row in another cancel out in a single
total — very nearly what had already happened.  *(item 34)*

## The resolution ledger

**The ledger records a choice *among* the candidates a spell's design line
admits, never one against them.** A sole candidate that is the wrong guideline is
a `base_effects.json` bug, or an `ExceptionSpell` — not an override. The
"explicit override" promise was dropped rather than implemented.  *(item 29)*

**Each entry records the candidate set it was made against**, so a later catalog
change flags affected decisions as stale instead of letting them stand
unexamined.  *(item 27)*

**A widening is not a staleness.** `ledger.WidenedEntry` (a `StaleEntry`
subclass, so an un-migrated ledger is still a build failure) marks the case where
rows were only *added* and the recorded choice is still on offer. Any removal, or
the loss of the chosen row, stays an ordinary `StaleEntry` and still demands a
human.  *(item 55)*

**The extractor must never write the ledger.** `run()` only reports what widened;
`migrate_ledger.py` carries decisions forward — keeping `baseEffectId` and
`rationale` **verbatim** — and it is a separate command rather than a flag for
exactly that reason.  *(item 55)*

**A migrated entry is not a reviewed entry.** Ids added by a migration land in
`unreviewedCandidates` and the extractor prints the outstanding count on every
run, so the backlog cannot go quiet. Clearing it is a re-read (item 32). Still
live, but it should now fire rarely: since the scoping rule above, a *new book*
no longer widens an existing spell's candidates, so the remaining triggers are
in-scope catalog changes such as item 22's rebuild.  *(items 55, 32)*

**Resolve an ambiguous pick against each candidate's *exact* wording, not the
most general-sounding one.** All four of item 39's supposedly undecidable cases
had a forced discriminator once read that way.  *(item 39)*

**A stale-entry guard must not block the tool that resolves the condition it
guards against.** `apply_container_modes` raised whenever `container_modes.json`
named a spell the run did not produce — which is exactly what a widened ledger
entry causes — and `migrate_ledger.py`, the only tool that resolves a widening,
calls `run()` and hit the identical crash. The guard now applies only to an
otherwise-clean run; the separate check that a recorded mode's Target really is a
container still runs unconditionally.  *(item 72)*

## Importer discipline

**Unrecognised prose blocks its spell; it is never guessed at.** Adjustments,
requisite labels and transport-distance labels are all matched against **closed
allow-lists** (`designline.ADJUSTMENT_LABELS`, `REQUISITE_LABEL_ARTS`, the six
concrete distance labels), so an unmodelled mechanism keeps failing loudly rather
than importing at a correct level with wrong modelling. Exception spells,
hand-derived spells and storyguide rulings use the same discipline: closed,
exact-name tables.  *(items 24, 43, 44, 46, 49)*

**Fail at the earliest layer that can tell.** Bare `"distance"` is deliberately
left out of the tokenizer vocabulary: it names no real option, so it should keep
failing at the tokenizer rather than one layer deeper with a near-identical
message.  *(item 43)*

**Raise rather than guess.** `emit._resolve_requisite_label` resolves a bare
`+1 requisite` against `block.stat.requisite_arts` and raises if that list does
not hold exactly one entry.  *(item 44)*

**A printed magnitude with unrecognised wording is a parser gap; an unprinted
magnitude is an adjustment.** That is the discriminator between widening the
vocabulary and reaching for item 24's mechanism.  *(item 44)*

**Match on a token's bracketed text, not a bare keyword, where the corpus reuses
the keyword.** `Special` hides two different mechanisms (a nonstandard Duration
and a nonstandard Target), so `ADJUSTMENT_LABELS` matches the bracketed text and
`emit._parameter_name` resolves `D: Spec` through the closed
`SPECIAL_PARAMETER_BASIS` table keyed on the spell's own "based on X" clause. A
spell whose clause names no basis cannot be resolved this way and becomes an
exception spell.  *(item 26)*

**Anything that belongs in a generated asset but cannot be generated must live in
an input file, never only in the output.** `--write` rebuilds
`spell_templates.json` from the run's own output and would have deleted item 17's
hand-authored template, which existed only in the asset; it is now a committed
input (`hand_authored_templates.json`) the extractor reads on every run — which
also makes the regeneration assertion non-circular.  *(item 55)*

**Published General spells emit to `spell_templates.json`, not
`spell_library.json`.**  *(item 25)*

**A new book's parser lands behind the per-book registry** (`sources.Book`,
`blocks.PARSERS`) so `parse_de` stays untouched and the core import is unchanged.
`--diagnose` cannot write, by design.  *(item 65)*

**Five importer tables are keyed by bare spell name across every book, and a
test — not `_reject_duplicate_ids` — is what guards them.** `HAND_DERIVED`,
`HAND_DERIVED_ADJUSTMENT`, `DESIGN_LINE_TYPOS`, `SPELL_NAME_TYPOS` and
`exceptions.EXCEPTION_SPELLS` are name-keyed; only `SKIPPED_BLOCKS` is keyed
per book id. `_reject_duplicate_ids` **structurally cannot** catch a cross-book
name collision here: these tables are consulted while a book is still being
parsed, and a misfire rewrites the name and therefore the id, so no duplicate
ever materialises for it to reject. `NameKeyedTableCollisionTest`
(`tests/test_extract.py`) covers the gap instead, asserting each key matches a
parsed name in exactly one registered book — two hits is a collision, zero is a
stale entry. **Do not delete it as redundant with the id guard.** Re-keying by
`(book_id, name)` was weighed and deliberately deferred, not forgotten: 18
entries, all core-book, against item 71's finding that the third book is
distant. When a collision does land, re-key — `registered.id` is already in
scope at all six lookup sites in `run()`.  *(items 73, 71)*

**Combining two base effects is importer-only.** `COMBINED_BASE_EFFECTS` plus
`emit.build_spell`'s `extra_adjustment` records a cosmetic tie as a magnitude-0
`LevelAdjustment` — real, UI-visible data rather than a silent drop — but a user
designing their own spell has no such mechanism (item 47). `KNOWN_UNRESOLVABLE`
is empty; the mechanism stays for a future genuine tie.  *(item 39)*

**Anchoring and parsing are different measurements.** The corpus survey behind
this item classified how spell blocks are *anchored* and never checked that an
anchored block *parses*, so a low tokenize rate from `--diagnose` is a first
measurement, not a regression. Product line does not predict format either —
HoH:*True Lineages* is 55/55 heading style.  *(item 65)*

## Naming

**The modifier is "Effect complexity", not "Complexity".** The three Imaginem
sensory-complexity modifiers are all already named "Complexity", and the UI heads
each modifier group by its name — two groups with the same heading, one a
checkbox list and one a dropdown, is unusable. Those three are a different,
printed mechanic (core 14596) and are deliberately left alone.  *(item 72)*

**`TargetType.sensorium` is deliberately not a rulebook word**, chosen so it
cannot be read as claiming membership in the Core Rules' stated "three types of
target".  *(item 68)*

**The Target `Touch` / Range `Touch` name collision is left as-is.** Ids are
category-scoped (`range-touch` vs `target-touch`) and the dropdowns filter by
category, so the two never share a picker.  *(item 15)*

**Content words stay in generated slugs** — `catalog._STOPWORDS` holds only true
stopwords, pinned by a slug test.  *(item 29)*

**Renaming a published id carries no migration weight**, because the `spells`
table holds only user-created spells (item 33) and nothing user-side can point at
a published id. Check `resolutions.json`, `container_modes.json` and the tests;
specs and plans are historical records and are left alone.  *(item 29)*

**Rung labels on judgement ladders are this project's wording, not the
rulebook's.** `elaborate-effect` and `complexity` both invent theirs; the rulebook
prints no ladder for either. Do not go looking for a printed source.  *(item 72)*

## Spell model — structure

**Exactly one Range, one Duration and one Target per spell.** The Ars Magica rule
is that modifiers scale the level instead. *Mists of Change* is the one published
spell that contradicts this and is recorded as an exception spell rather than
weakening the model.  *(items 1, 46)*

**`ParameterScope` carries a positive Forms list and a negative Techniques list**,
because that is how each rule is written: Fire is offered *for* Ignem and
Imaginem; a Sensory Target is offered for everything *except* Intellego.
*(item 64)*

**Duplicate requisite Arts are unrepresentable by construction** — `requisites`
is a map keyed by art. That is the one invariant fixed by modelling rather than
validation. The `free`/`adding` split is sufficient: every requisite-driven
magnitude in the 360 published spells is +0 or +1.  *(items 2, 40)*

**There is no bespoke `size` field on `Spell`.** Size is ordinary scoped
Modifiers through `selectedModifiers`, so magnitude reaches the level by the
normal path with **no special case in the calculator**.  *(item 3)*

**No common parent class for `Spell` / `SpellTemplate` / `ExceptionSpell`.**
`lib/models` has zero `extends` relationships, and the field most worth sharing
(Range/Duration/Target) is exactly the one that cannot be identical between the
typed and free-text shapes.  *(item 46)*

**`chosenBaseLevel` enters `SpellLevelCalculator`'s additive/multiplicative split
exactly as the guideline's own base would have.** That was the design-heavy
question and this is the answer. Validation rejects both a missing chosen level
and one below 1 — **neither computes a silent zero.**  *(item 25)*

**Open guideline slots use one generic `chosenSlots: Map<String, String>` keyed
by slot kind, not three bespoke `chosen*` fields.** Each bespoke nullable slot
costs a `copyWith` sentinel, a clear-on-switch branch and a UI conditional;
`chosenBaseLevel` pays that once. Realm could not have reused `chosenBaseLevel`'s
plumbing anyway, since every existing guard keys on `isGeneral`. Slot values are
**free text, not a closed set** — the rulebook gives illustrative examples, not an
exhaustive list.  *(items 35, 37)*

**The import reads a chosen slot value from a hand-verified table
(`REALM_BY_SPELL_ID`), not a prose scan.** A scan was tried and demonstrably
misfires on the real corpus.  *(item 35)*

**`Spell` and `SpellTemplate` store their own `technique`/`form`**, no longer
derived from the base effect, with `analogyRationale` required non-null exactly
when they differ from the resolved base effect's — so a by-analogy spell displays
under its own real Technique/Form.  *(item 48)*

**`requiresVirtue` is informational only.** The app has no character or Virtue
model to enforce against; the field names the requirement and nothing checks it.
*(item 17)*

## Ritual status and General levels

**`RitualRequirement` is derivation, not validation** — nothing is rejected,
because a Year-duration spell is not an error, it *is* a Ritual. **Ritual is a
spell *type*, orthogonal to all eight Durations.**  *(item 4)*

**`ritualDeclaration` must never be stamped unconditionally onto a Ritual-flagged
spell.** `emit` once wrote `lastingCreation` for every one of them with no regard
for why it was a Ritual; a `_ritual_declaration(block)` helper plus the closed
`STORYGUIDE_RULING_SPELLS` table decides it now. Note the blast radius: `isRitual`
derives independently, so a wrong stored declaration only ever changed the in-app
banner text, never a computed level.  *(item 49)*

**A General guideline whose payoff is a Might threshold, and which has no
reference triple, carries no `effectFormula`.** A Might threshold ties to the
total computed level, not `chosenBaseLevel`, and `crvi-hohmc-G1` has no
reference triple to make the two coincide — so the field is deliberately absent,
not missing. Its own `notes` field says so.  *(item 17)*

## Container and Sensory Targets

**Container mode is fixed at design time (Core Rules 12250) and is not
derivable** — two spells with identical Technique/Form/Range/Duration/Target can
differ in mode (12252). It is a stored per-spell field, and it is
**level-neutral**: no magnitude reads it.  *(item 14)*

**`unstated` means "no decision recorded," never "none owed."**
`spellOwesContainerMode` derives the latter.  *(item 14)*

**Check 9 in `validateSpellAgainstCatalog` tests Target kind only.** The Momentary
exclusion — where static-vs-dynamic is vacuous — lives in the
`spellOwesContainerMode` predicate, not in the check.  *(item 14)*

**`target-bloodline` must never become a container Target.** It is an `object`
Target with its own baked-in ongoing rule ("applies to all members … born during
its duration, as well as those already living when it is cast") — the rule is the
Target's, not a per-spell choice.  *(item 14)*

**All five Sensory Targets are `sensorium`, and no container mode is owed for any
of them.** `container` was actually unavailable: Core Rules 12086 forbids a
container Target at Personal Range, and HoH:MC 1006 requires Personal Range for
every Sensory Magic spell, so the pair is contradictory. `object` was equally
wrong — it is documented as "always static" (12246/12254), and HoH:MC 1002 states
continuous acquisition for all five. A stated mode on one of these would now fail
check 9.  *(items 68, 65)*

**The book's equivalence sentences price the Sensory Targets; they do not
classify them.** Magnitudes were untouched by the reclassification, and no
`targetType` is ever read off an equivalence. The core `sense` ladder in
particular is **not** what `targetType` follows: it matches sense-for-sense and
magnitude-for-magnitude but means the opposite thing. HoH:MC forbids Intellego
precisely because granting senses is the other feature.  *(items 64, 68)*

**A magnitude given only by equivalence is reconciled against a printed design
line before it is written down.** That is how the five Sensory Targets were
costed, and it binds the next supplement too — an equivalence sentence on its
own is not a magnitude.  *(item 64)*

## Modifiers, Size and adjustments

**Do not confuse `LevelAdjustment` with a Modifier.** A Modifier is a reusable
catalog choice scoped to a technique/form/effect; an adjustment is unique to one
spell, and promoting per-spell prose into the catalog pollutes it with single-use
entries. Recurring wordings do go the other way: `elaborate-effect`, `no-words`,
`no-gestures` and `invi-techniques-and-forms` all started as adjustment
candidates and became real catalog Modifiers because they are genuinely reusable.
*(item 24)*

**Negative adjustment magnitudes are allowed.** `SpellLevelCalculator` mirrors
the positive rule (worth 1 inside the additive tier, 5 above it) and restores the
additive capacity it gives back, so `[1, -1]` is a no-op at any base level.
*(item 24)*

**Prose rules that only change a level get modelled as modifiers, not as derived
catalog rows or ad-hoc adjustments.** The CrVi Warping Point and PeIg chill-damage
ladders became `selectionMode: single` modifiers scoped to their base effect;
MuAu's single-property discount became a broadly-scoped one.  *(item 28)*

**A storyguide judgement ladder is modelled as a *wildcard-scoped* modifier,
resolved by the design line's own printed magnitude.** `Effect complexity` is
scoped to no Technique/Form pair because core 12204 makes it general — "this
normally adds magnitudes to the spell level to account for the complexity" — and
the corpus prints it across many books and pairs; `elaborate-effect` is the
precedent it follows. This is the scoping decision the next supplement's parser
has to copy.  *(item 72)*

**`ModifierScope.excludeTargets` is a carve-out mirroring `excludeTechniques`,
not an allow-list.** `size-mentem` excludes `target-individual` because minds have
no size — but can still be counted for Groups.  *(item 19)*

**Creo Terram deliberately has no material-scaling modifier**: the material *is*
the base effect there. Do not "fill the gap".  *(item 4)*

**`effectIds` scoping on a modifier can be load-bearing.** `creo-herbam-treated-product`
and `creo-animal-treated-product` are scoped to specific rows because `crhe-2a`
already prices the Herbam treatment rule into its printed base level, and the Creo
Animal rule prices treatment against creating an equivalent amount of *dead*
animal — so live-animal rows are excluded from either scope. A test pins both
exclusions.  *(item 29)*

## Validation and enforcement

**`validateSpellAgainstCatalog` (`lib/models/spell.dart`) is the one enforcement
path**, called from `ResolvedSpell.problems`, `SpellEngine.validateSpellDraft` and
`SpellRepository` before every write.  *(item 40)*

**This cannot live in the `Spell` constructor.** `Spell` deliberately holds
`baseEffectId`, not `BaseEffect`, so it cannot see `isGeneral`; the enforcement
home must hold both the record and the catalog.  *(item 40)*

**An invalid spell blocks; an *unresolved* one degrades.** Invalid is rejected at
save/restore/import; unresolved renders a "Needs review" chip and an
`(unverified)` level suffix in **both** places that build a card from a
`ResolvedSpell`. The blocking half was decided by the user and flagged
**revisitable** — the two behaviours may want to converge.  *(item 40)*

**Do not collapse `problems` into `isResolved`.** `isResolved` is a can-I-compute
gate; `problems` means it computes but must not be trusted.  *(item 40)*

**`SpellRepository.saveAll` reports rejects instead of throwing**, so one bad
spell in a restore does not abort the rest.  *(item 40)*

**Prose validation deliberately stays out of `validateSpellDraft`.** That method
gates breakdown recalculation, so a summary check there would hide the level until
a summary was typed. Every spell, published or user-created, needs a summary or a
description; `SpellDraft` is home and the save dialog is the backstop.  *(item 13)*

**`Spell.fromMap`'s `legacySummaryPlaceholder` backfill is narrow on purpose.** It
lives in `fromMap` rather than the datasource because a pre-change backup would
otherwise abort a whole restore inside `BackupService`'s list literal, and it fires
only for user-created records with no prose — a *published* record with no prose
still throws, so the import assertion keeps its teeth. Read-only: nothing is
written back, so there is no migration.  *(item 13)*

## Exception spells, and when they are not the answer

**Three shapes qualify** (documented in `exceptions.py`'s module docstring): the
rulebook disclaims the arithmetic; the stat line cannot be expressed by the model;
or the guideline is genuinely absent from its art's table *and* reconstructing one
from the spell's prose was already tried and reverted. The table is closed and
exact-name, intercepted as the very first check in the import loop, before any
tokenization.  *(item 46)*

**A spell whose design line is complete and sums exactly is not an exception
spell**, even when it violates a rule the catalog models — routing it through
`ExceptionSpell` would discard a correct breakdown in favour of free text. Item 50
is the live instance.  *(items 46, 50)*

## Bloc and state

**Every emit in `SpellCreationBloc` goes through the one `_emit` funnel**, which
attaches `SpellEngine.previewLevel(draft)`. No handler can emit a state whose
breakdown disagrees with its own draft.  *(item 59)*

**Three rules cover every *derived* state field; a new field picks one.**
Computed from the draft in the funnel (`breakdown`, `levelUnavailableReason`,
`generalEffectSentence`); invalidated in the funnel by predicate
(`validationErrors`, the three suggestion fields); or a one-shot payload that
`copyWith` drops and the funnel re-passes (`errorMessage`, `savedSpell`). `status`
and `draft` sit outside all three, as the funnel's inputs. A new *handler* does
nothing for any of them.  *(item 62)*

**The test for the *computed* rule is `f(draft)`.**
`SpellEngine.deriveGeneralEffect` reads `baseEffect.effectFormula` and
`chosenBaseLevel` and consults **no catalog**, so no sync event can move it
without the draft moving — which is what puts a field in the funnel's computed
rule rather than under one of the other two.  *(item 62)*

**Keep the two invalidation predicates distinct.** `validationErrors` clear when
the **draft** moves, because they are statements about the draft's contents; the
suggestion fields clear when the **level** moves, because a suggestion asserts
"similar to level N" and only N can falsify it. Keying the suggestions to the
draft was tried and was wrong in both directions — a catalog sync moves the level
with the draft untouched.  *(item 59)*

**`savedSpell` follows `errorMessage`'s rule, deliberately**: the next edit after
a save nulls it. Its only reader is gated on `status == saved`. Restoring the old
`savedSpell ?? this.savedSpell` carry-through would reintroduce the hazard it was
removed for.  *(item 62)*

**`previewLevel` is not validation.** It answers "is there a number", returning a
breakdown or one of five reasons; both of `calculateBreakdown`'s reachable throws
become reasons rather than escaping. `validateSpellDraft` still owns the catalog
invariants and still fires only on button presses, because its messages render as
red text and firing them per keystroke would flag a half-built draft as broken.
*(item 59)*

**`LevelBreakdown`, `LevelContribution` and `RitualStatus` need value equality.**
The funnel mints a new breakdown per emit and `breakdown` is in
`SpellCreationState.props`, so identity comparison makes every state look changed.
*(item 59)*

**A parameter slot is re-seeded only when it is null or still holds the
*outgoing* guideline's reference value**, evaluated per slot — so a deliberately
chosen parameter survives a guideline switch while an untouched one follows. There
is no "touched" flag; it is a value comparison against data already in hand.
*(items 60, 74)*

**One exception to the per-slot evaluation: a seed that would contradict its
peer is not written.** Range and Target are not independent, so if the seeded
pair violates check 10 or check 11, *both* slots keep their pre-adoption values.
Reverting both is identical to reverting whichever slot moved, and the
pre-adoption pair is always legal — the constructor seeds the standard triple,
and `RangeSelected`/`TargetSelected` prune. `TemplateInstantiated` is the one
path that neither seeds nor prunes; it writes published catalog data, which
assertion 7 holds to the same two checks. This narrows "an untouched
slot follows the new guideline"; it carves no exception into "a deliberate
choice survives a guideline switch". A self-contradictory reference triple is
the one case reverting cannot fix, and is guarded by assertion 8 rather than
repaired in the bloc.  *(item 74)*

**No is-this-explicit predicate on `BaseEffect.reference`, deliberately.** It
already defaults to `ParameterTriple.standard()` in both the constructor and the
JSON factory, so "explicit reference, else standard" and "always `reference`" are
the same rule. Item 38's worry that the model cannot tell an authored
Personal/Momentary/Individual from an unauthored one is real, and irrelevant here.
*(item 60)*

**Every handler that can move Technique, Form, base effect or Target must prune
stale modifier selections.** `TargetSelected` was the one that did not, so
switching Target to Individual left a `size-mentem` selection silently
contributing magnitude.  *(item 19)*

**`containerMode` is pruned inside `_seedParameters`, not at each call site**,
computed from the *resulting* Target, because every handler that can re-seed a
Target can strand a mode. Every caller of the pruning helper seeds after it, so a
Target pruned to null always reaches a mode clear one call later — preserve that
ordering.  *(items 60, 64)*

**`TemplateInstantiated` is never seeded.** A template's parameters are published
catalog data about that specific effect.  *(item 60)*

## Creation-screen UI

**A single-select modifier's clear branch must deselect *every* selected id, not
just the first.** `_buildSingle`'s `value` already tolerates a stored selection
carrying more than one option by showing nothing, so clearing has to tolerate it
identically or the surplus survives with the field reading "None" and no way left
to reach it. Do not "simplify" that loop to `selectedIds.first`.  *(item 61)*

**An unselected single-select modifier reads "None", not blank** — a deliberate
choice across all of them, so the empty state looks chosen rather than
unset-because-unloaded.  *(item 61)*

**Save and Discard render unconditionally; the affordance is not the gate.**
Discard was once unreachable before the first Calculate, which left no way to
abandon a draft at all — including one carrying the globally-scoped `no-words` /
`no-gestures` modifiers, which are scoped to no Technique or Form and so appear on
every draft.  *(items 59, 61)*

**Suggestions stay behind a button, even though the level no longer does.**
`findSimilarSpells` plus a `calculateBreakdown` per candidate is the half
expensive enough to deserve one; making suggestions live because the level went
live is the obvious accidental next step.  *(item 59)*

**A `Column` gives its non-flex children an unbounded main axis**, so a banner
pinned above a `ListView` cannot measure the body itself. `LevelBanner`'s 40% cap
is measured by a `LayoutBuilder` on the screen and handed down; 40% of
`MediaQuery.size` overflows a short or keyboard-inset viewport.  *(item 59)*

**Set `BottomNavigationBar.type` explicitly.** With no `type` it defaults to
`fixed` for 2–3 items and `shifting` for 4+ — this bar has exactly 4, and
`shifting` ignores `backgroundColor` entirely and hides unselected labels, which
made Library/Settings/Backup effectively unreachable on every platform.
*(item 52)*

## Testing

**The rule is "don't await real I/O in a test body," not "don't use real
Blocs."** A `testWidgets` body runs in a fake-async zone, so real async I/O
awaited directly inside it hangs; a Bloc is only an event handler and hangs only
if it awaits real I/O, which mocking the *repository* removes. `setUp`/`tearDown`
run outside the fake-async zone, and `tester.runAsync` is the documented escape
hatch from inside it. The older "a real Bloc hangs forever under flutter_tester"
premise was probed and does not reproduce — and while it stood it foreclosed the
cheap fix for the whole re-render coverage gap.  *(item 6)*

**Mocked blocs cannot catch re-render bugs**: a mock emits no new state, so the
rebuild after an interaction never happens. When the failure mode *is* "what
happens on re-render", use a real bloc with a faked repository — or drive states
through a `StreamController` on the mock, or cover it in `integration_test/`.
*(item 6)*

**A widget-tree presence check is neither a visibility nor a reachability
check.** `find.text('Library')` passed throughout the invisible-nav-bar bug,
because `shifting` fades labels rather than removing them from the tree. Note also
that no test taps through the real nav shell — every screen is tested by pumping
it directly as `MaterialApp.home`.  *(items 52, 6)*

**Two widget-test files deliberately still hand-roll a mocktail repository**:
both use it for *error injection* (`thenThrow`), which an in-memory fake models
worse, and `test/support/bloc_factories.dart`'s fakes carry no error hook. Do not
"finish the migration".  *(item 6)*

**Counts in tests are derived, never hardcoded.** The asset loader test derives
its expected count from the raw JSON — an oracle independent of the loader. A
hardcoded count is exactly what silently drifted by 566 entries.  *(items 5, 55)*

**`allParameters` is left empty in the collapsed loader oracle, deliberately.**
`asset_data_loader_test.dart`'s level-sum assertion matches assertion 1 that
way, so that neither oracle applies the base-effect reference discount. Passing
`allParameters` to "improve" the test silently changes what the oracle proves.
*(item 29)*

**A regeneration assertion needs a second, independent test beside it.**
`spell_templates.json` had no regeneration test at all, so a committed-vs-fresh
divergence went unnoticed; assertion 5 now covers all three assets, and a
*separate* test pins that hand-authored templates survive a run — otherwise
deleting an entry from both sides goes green.  *(item 55)*

**Verification rule of thumb:** a change to a screen's widget tree is **not**
verified by `flutter test` alone — `flutter test` does not run `integration_test/`,
which needs a device (`flutter test integration_test/... -d windows`). The Python
and Dart suites are likewise not interchangeable: the import assertions are split
across both and neither alone covers all of them — a regression reintroducing the
`selectedModifiers: {}` bug passes every Python test and is caught only by
Dart-side assertion 1. Run all three; `dart run tool/run_all_tests.dart` does,
plus `flutter analyze`, which CI gates the Dart suite on. Current commands and
results are in `STATUS.md`.  *(items 6, 27, 29)*

**Use `flutter test -d chrome`, never `flutter test --platform chrome`.** The
latter is a deprecated `package:test` browser path whose local dev server fails to
serve CanvasKit's WASM/JS on Windows (`canvaskit/chromium/canvaskit.wasm` 404s
though the file exists in the SDK cache), so every widget test waits forever on a
renderer that never initializes. Upstream closed it by deprecating the flag rather
than fixing the server.  *(item 51)*

**Three other explanations for that hang were chased and falsified first** — a
real Bloc, `sqfliteFfiInit()` on web, and Chrome's Local Network Access policy.
None of them is the cause; do not reopen them.  *(item 51)*

**Python test files import like their siblings, not via `from .. import`** —
`unittest discover` cannot load that form, and one file using it silently kept
itself out of the suite.  *(item 49)*

**A book-corpus assertion is transcribed from the book, never pasted from
parser output.** The 13 HoH:MC blocks in
`test_the_remaining_blocks_prose_and_design_line_match_the_book` had their
`prose` and `design_line` read out of `reviewed/`, because the cheap route —
printing what `parse_inline` emits today and pasting it in — yields a test that
passes, looks like coverage, and pins whatever the parser currently does
*including its bugs*. That is the precise failure this test exists to prevent,
so it is worth the transcription cost each time a book is added. The tell that
it was done honestly is that the book's own inconsistencies survive in the
expected values: `(Base Effect, ...)` for *Tie the Threads That Bind* beside
`(Base effect, ...)` for *The Rooster's Crow*, and the stray space in
`(Base 15, + 1 Touch, ...)` for *Embrace of Boethius*. Do not "tidy" these.
*(item 73)*

## Internationalisation

**Three text populations, not two, and they do not travel the same road.**
*App chrome* — our own labels, buttons, helper lines — is translated by us and
lives in ARB, keyed by locale. *Rules text* quoted from the rulebook is
translatable but never by us and never through ARB: a locale selects a source
*edition* and the catalog carries per-edition text, because handing a
translator rules strings in an ARB file would produce an unofficial
translation the app then presents as the rulebook's own words. *User
content* — an adjustment's `note`, any prose the caster typed — is never
translated and renders verbatim under every locale, explicitly exempt from
the pseudo-locale transform too, or the proof harness raises false failures on
the user's own words. **The boundary rule: ARB holds the vocabulary that
labels the interface; the catalog holds the content the rulebook prints; user
content passes through untouched.** So "Range" is chrome — it labels a
control — while "Voice" is content.  *(item 80, 80.3)*

**Catalog names are data, not UI strings, and never enter ARB.** Spell,
Technique, Form and parameter names come from `assets/data/*.json`; some stay
Latin under any locale (*Creo*, *Ignem*), the rest are rulebook English a
published translation would render differently. Either way they are reached
through the per-edition catalog route above, never through `AppLocalizations`.
The four realm values (`Divine`/`Faerie`/`Infernal`/`Magic`) and the
filter/category comparison keys (`'All'`/`'Published'`/`'My Spells'`,
`'Range'`/`'Duration'`/`'Target'` as *state values*, not as displayed labels)
are the concrete instances of this: they stay hardcoded English literals in
`lib/presentation/screens/*.dart` on purpose. Localising any of them would
either hand a translator rulebook vocabulary to rewrite, or silently break a
`filter == 'My Spells'`-style comparison under every non-English locale — the
label *displayed* for each is localised via ARB, but the value dispatched and
compared against is not, and the two are deliberately decoupled. Do not
"finish" migrating these into ARB.  *(items 80.3, 9, 10)*

**The engine never composes display prose.** `spell_engine.dart` and
`level_breakdown.dart` hand `LevelBanner` a `LevelContribution` carrying
structured data (a `ContributionSource` value, a magnitude), not a
pre-formatted `String label` — formatting into locale-aware text happens only
in `lib/presentation/format/contribution_formatter.dart`, which has a
`BuildContext` and can reach `AppLocalizations`. Domain code (`lib/engine/`,
`lib/bloc/`) has no `BuildContext` and so no locale; any future engine change
that starts building a user-facing sentence there is unlocalisable by
construction and has to be undone. The same discipline applies to
`formatValidationError`/`formatUnavailableReason` and their sealed-class
sources (`SpellValidationError`, `LevelUnavailableReason`): the domain layer
produces a typed reason, the presentation layer's formatter turns it into
words.  *(items 80, 4, 5, 6)*

**The pseudo-locale (`en_XA`) is the standing guard against decay**, run in
`test/l10n/pseudo_locale_coverage_test.dart`. It pumps each of the four
top-level screens (there is no way to pump `main.dart`'s `_MainTabView`
directly — it is private) under `Locale('en', 'XA')` and asserts a fixed list
of chrome strings is unfindable, plus asserts the four realm values *are*
findable, to keep the chrome/content boundary itself under test. **A failure
of this test means a string was missed and must be moved to ARB — never
delete the failing entry to make the test pass**, and never add the three
deliberately-English populations above to its `_mustNotSurvive` list.
*(item 80, 80.2)*

**ARB conventions.** Written down here because five implementers on item 80
independently produced five conventions, none of them recorded — caught only
at the final whole-branch review.

- **Key naming.** camelCase, prefixed by the screen or concept it belongs to
  (`contribution*` for `ContributionSource` wording, `validation*` for
  `SpellValidationError` wording, `ritual*`, `backup*`, `spellCard*`, …) —
  match the sealed type or screen a key renders for, so a reader can find every
  key belonging to one formatter by prefix alone.
- **`@description` is mandatory on any key with a placeholder.** State which
  text population each operand belongs to — chrome (already localised before
  it reaches this key), rulebook content (not translated, routed through the
  catalog per Task 6/9's boundary rule), user content (verbatim, exempt from
  the pseudo-locale transform), or numeric — and, for rulebook content, name
  *what* it is (a Parameter's name, an Art's Latin name, a modifier's label).
  A key with no placeholder needs no `@description`.
- **One full frame per rendered variant, never one translatable string
  injected into another.** A book title or rulebook line citation is an
  operand on the message that cites it (`targetRequiresThisRange`,
  `ritualStoryguideRulingHelp`), not text baked into another ARB value's
  literal — the same boundary rule applied one level deeper: composing prose
  by string-gluing two ARB lookups together defeats a translator's ability to
  reorder or reword either one independently.
- **Pure sign/numeral strings stay in Dart, not ARB.** `'+2'`, `'—'`, and
  similar — punctuation and arithmetic notation are not language-specific
  vocabulary, and routing them through ARB just adds a lookup with nothing to
  translate.  *(item 80, final review)*

**The generated localisations are gitignored, so a fresh checkout does not
build until `flutter pub get` runs.** `lib/l10n/app_localizations*.dart` are
gen-l10n output and deliberately untracked (`.gitignore`); only the two `.arb`
files are committed. `flutter pub get` regenerates them, and
`.github/workflows/tests.yml` already runs it before `analyze` and `test` in
both jobs — but **this was not true of the repo before item 80**, and it bites
locally: merging item 80 to `main` produced 65 analyze errors and a failing
suite purely because codegen had not run in that checkout. Run `flutter pub
get` first when a tree suddenly cannot resolve `AppLocalizations`, before
suspecting the merge.  *(item 80, final review)*

**A domain exception that reaches the user gets caught specifically and routed
to the structured channel — never left to a `catch (e)` that stringifies it.**
`SpellCreationBloc._handleSpellSaveRequested` catches `InvalidSpellException`
ahead of its catch-all and emits `e.problems` into `validationErrors`, which
the screen renders through `formatValidationError`. The generic catch is for
genuinely unexpected failures only. Left to the catch-all, `e.toString()` put
a Dart *type name* in front of the user (`RequisiteIsOwnArt()`) where English
prose used to be — a regression the pseudo-locale guard structurally cannot
see, because those strings render only after a throw.

⚠️ **That fix depends on the bloc's sequential event transformer**
(`spell_creation_bloc.dart:41`, `events.asyncExpand(mapper)`): the draft merge
was moved ahead of the `saving` emit so `state.draft` and the handler's local
`draft` share identity, which is what stops `_emit`'s funnel clearing
`validationErrors` on the way out. Under flutter_bloc's *default* concurrent
transformer that identity is not guaranteed and the fix would be racy. Do not
change that transformer without revisiting this.  *(item 80, final review)*

## CI and workflows

**Two workflows answer deliberately different questions.**
`.github/workflows/tests.yml` runs on push to `main` and every PR and is
**pinned** — it reads the rulebook revision from `source.lock` and clones the
rulebook at exactly that commit, so upstream churn can never redden a PR.
`.github/workflows/rulebook-freshness.yml` is weekly and **unpinned**: a failure
there means "upstream improved, go adopt it".  *(items 29, 30)*

**Do not "simplify" the pinned job to a shallow fetch-by-SHA — it cannot work.**
`source.lock` records an **abbreviated** 7-char SHA and the git wire protocol
cannot fetch one (verified: `git fetch --depth 1 origin <short>` fails with
`couldn't find remote ref`). The job does a blobless clone (`--filter=blob:none`)
and resolves the short SHA locally; a cache keyed on the recorded SHA skips the
clone until the lock is bumped, and a post-restore `rev-parse` guards against a
cache entry holding the wrong tree. The alternative is widening the lock to a full
SHA.  *(item 29)*

**`integration` is a separate job on `windows-latest`** because the suite needs a
device and that is the only configuration it has ever run in; neither it nor the
Flutter suite pins the rulebook, since both read the committed assets only. It
names the *directory*, so a second integration file is picked up without editing
the workflow.  *(items 6, 29)*

**Supply chain, stated so the trade stays deliberate:** `tests.yml` uses
third-party `subosito/flutter-action@v2`, pinned by major-version tag rather than
commit SHA. It is the only non-first-party action in the repo. Pin it to a SHA if
that trade becomes unacceptable.  *(item 29)*

## Known limits — do not re-promise

**~~`Citation.page` cannot carry page numbers.~~ RETRACTED 2026-08-20 (item 78).**
The claim was that the markdown has no page markers. True of the book's *body*;
false of the book as a whole. Four index tables — Spells (line 23778), Spell
Guidelines (24143), Bestiary (24198) and Traditional (24265) — carry **1650
unique `[page](#anchor)` pairs, 1606 of them (97.3%) resolving to real
headings**, so a line maps to a printed page via its nearest preceding anchor.
The PDF corroborates independently: **printed page = PDF index − 7, zero
exceptions across 418 numbered pages**. `Citation.page` is still null everywhere
*today* — the retraction is of the impossibility, not of the current state.
**Page numbers are Definitive Edition only** (decided 2026-08-20: the open
licence makes the earlier edition largely obsolete); note `books.json` still
misdeclares `arm5-core` as 5e, which item 78.5 fixes.  *(items 27, 56, 78)*

**Core-rules line citations carried over from archived bodies are known to run
about 8 lines low**, so verify one against `reviewed/` before relying on it —
item 70.3 measured a uniform +8 offset, though the 12086 cited above was newly
read and is correct.  *(item 70)*

**Aquam MVP limitation:** the Aquam Form has 5 distinct base-Individual sub-types
(water/liquids/poisons/blood/wine), each with slightly different guideline
progressions. The Size MVP supports one sub-type per spell via `aquam-base-individual`,
recorded in its base option's `baseIndividual` field. Mixed sub-types within Size
calculations are deferred.

**The original "~200 flagged effects" figure was wrong and should not be
quoted.**  *(items 4, 12)*

### An audited ledger entry is not a verified one

Every `resolutions.json` entry carries an `audit` block: when it was last
independently re-derived, whether that pass `agreed` or the entry was
`adjudicated` by a human, and a digest of the decision audited. There is
deliberately no `verified` outcome. An audit that agrees with the ledger has
scored agreement with the artifact under audit — the 2026-08-19 sweep
produced two flags where the model was wrong and the ledger right, which is
the same coin the other way up.

What this buys is a closure criterion that survives scale. "A human has read
every entry" cannot be met at 217 and is absurd at the 1,000+ the remaining
books will bring; **audited, with every disagreement adjudicated** can be met
for each book as it lands, because only disagreements reach a person — 217
entries cost three rulings.

The digest covers the chosen id and the candidate set, not the rationale: a
rewritten argument does not invalidate an audit of the pick, but changing the
pick or the field of candidates does. `AuditCoverageTest` fails on any entry
no current audit covers, so an unaudited decision cannot sit quietly in a
ledger that claims to be audited. **A new book owes an audit of its own
entries, not of the whole ledger.**  *(items 32, 55)*

## Licensing and attribution

**The repo is licensed by content, not by path: rulebook-derived content is
CC BY-SA 4.0 wherever it appears; everything else is MIT.** The path tables in
`LICENSE`, `NOTICE.md`, `README.md` and `repoLicenceSummary` are *illustrative
of that rule*, never an exhaustive enumeration — a whole-branch review caught
exactly that failure once, when the rule sentence was dropped and the table
started reading as a closed list, leaving verbatim published-spell prose in
`scripts/spell_import/hand_authored_templates.json` and quoted rulebook
constructions in `container_modes.json` claimed by nothing. **When a new file
starts carrying rulebook text, it is CC BY-SA the moment it exists**, whether
or not anyone updates a table. Do not "tidy" the rule sentence away as
redundant with the table it governs.  *(item 79.2)*

**The split rests on §1(b)'s Collection/Adapted Material distinction, and that
argument is what makes the MIT half defensible.** `assets/data/*.json` is
Adapted Material — transcribed, restructured into a schema, given identifiers,
in places corrected. `lib/**` is an independent contribution aggregated *with*
licensed data, and the arithmetic it implements is a game system, not
expression. **The edge that would collapse the argument is a `.dart` file
embedding quoted rules text as a string literal.** Never do that; it is also
what items 56 and 80.3 independently require.  *(item 79.2)*

**§3(a) has seven parts, not five or six.** (A)(i) creator identification,
(A)(ii) a copyright notice, (A)(iii) a notice referring to the licence,
(A)(iv) a notice *referring to* the disclaimer of warranties — not the
disclaimer reproduced — (A)(v) a URI to the licensed material, (B) an
indication that we modified it, and **(C), the one that is easy to miss:
include the licence text or a URI to it**, which is why
`LICENSES/CC-BY-SA-4.0.txt` exists rather than only a link. §3(a)(2) then
allows satisfying all of it "in any reasonable manner based on the medium",
including by linking to one resource — which is why quoted text in the UI
needs only a route to the About screen, not a notice of its own.  *(item 79.1)*

**The notice is a *list* of source editions, and the list shape is
load-bearing.** §3(a)(1)(A)(i) requires retaining creator identification *as
supplied with the material*, so a separately published edition — an official
translation, say — arrives with its own translators and its own copyright line
and needs its own block, never an appendix to Atlas's. Adding one must be
additive. `arsMagicaAttribution.books` is asserted set-equal to
`assets/data/books.json`'s titles, so importing a book without crediting it
fails the suite.  *(item 79.1)*

**`NOTICE.md` and the About screen render from `lib/licensing/attribution.dart`,
and tests assert `contains` against those consts character-for-character.** When
an assertion fails, fix the Markdown to match the Dart — never loosen the
matcher, and never edit the Dart to match prose. The en dash in `© 1993–2024`
and the `®` after `Atlas Games` are part of that fidelity. Both notice routes —
the About screen and `LicenseRegistry`/`showLicensePage` — must carry the same
fields; they silently disagreed about the book list once, which is why
`arsMagicaLicenseEntries()` is a named function with its own test rather than a
closure inside `main()`.  *(item 79.1)*

**Licence and attribution text is a deliberately-English population and never
enters ARB** — the same status as the four realm values. A licensor's copyright
line and creator credit are not ours to hand a translator. Only the About
screen's *chrome* (title, headings, button label) is localised, and
`pseudo_locale_coverage_test.dart` guards both directions: the chrome must not
survive `en_XA`, and `Atlas Games` must. **Never add notice-body text to
`_mustNotSurvive`** — it would fail the test on correct code.  *(items 79.1,
80.3)*

**Two things the licence does not grant, and the app must not imply.**
Trademarks are excluded by §2(b)(2) — the grant covers the text, not "Ars
Magica" as a mark, so this settles nothing about naming, branding or store
listings. And §2(a)(6)/§5 mean nothing may imply Atlas Games endorses eruditus;
both disclaimers ship in `NOTICE.md` and on the About screen.  *(item 79)*

**The §3(a)(1)(A)(v) URI names the pinned rulebook commit (`ffc1c6b`), not a
branch**, so it identifies the material actually adapted — the same discipline
as `source.lock`. A URI must be *provided*, not clickable, which is why the
About screen uses `SelectableText` and the app takes no `url_launcher`
dependency.  *(items 79.1, 30)*

## Text provenance — whose words a string is

**`Provenance` and `TextProvenance` answer different questions, and conflating
them is the defect.** `Provenance` records where an *entry* came from — a book,
or the user. `TextProvenance {verbatim, authored, translated}` records whose
words a particular *string on* that entry is. `verbatim` means **the published
words of a cited edition** — whichever edition, in whatever language — so an
officially published translation is Licensed Material in its own right and
quoting it is `verbatim` cited to *its* book, never `translated`. `translated`
means only "we produced this rendering", which is the modification
§3(a)(1)(B) obliges us to indicate. Nothing in production yields `translated`
yet; items 82 and 86 will.  *(item 79.3)*

**Provenance is derived, not stored — and the reason matters more than the
rule.** Every field it applies to has a provenance computable from the entry's
own `Provenance`, so a stored copy would be item 33's write-only duplication.
It also would **not** pre-pay for a second edition: `SourcedText` holds one
string, where one guideline under two editions needs a per-edition collection.
Item 86 owns that restructure, and **that** is the change which makes storage
earn its place — not this one. Do not "finish the job" by persisting
`TextProvenance` onto the assets.  *(item 79.3)*

**⚠️ The one place entry-provenance and string-provenance genuinely diverge:
template instantiation.** Learning a published template seeds the new draft
with the template's own prose, and saving stamps that spell `userCreated` — so
the naive rule would report the rulebook's words as the caster's. `Spell`
carries `templateId`, and `sourcedSpellText` uses it: seeded prose stays
`verbatim` **while it still matches the source template's text**, cited to the
**template's** citations, and becomes `authored` the moment the user edits it.
Cite the spell's own citations there and it throws — a `userCreated` spell has
none, and `SourcedText.verbatim` rejects an empty list, so the failure is a
crashed list row rather than a quiet mislabel. A `templateId` that no longer
resolves degrades to `authored`, deliberately, rather than throwing.
*(item 79.3, final review)*

**`sourcedSummary`/`sourcedDescription` live on `LibraryEntry`, so the compiler
is the enforcement.** An earlier shape type-switched on the three concrete
`Resolved*` classes in `spell_card.dart` and fell through to
`SourcedText.authored` — which silently mislabelled all 31 published templates
and 8 exceptions as our own words, and would have done the same to any fourth
implementer. Putting the getters on the interface makes a missing answer a
build error. **Never reintroduce a default-to-authored fallback**: authored is
a positive claim about authorship, not a safe default.  *(item 79.3)*

**`SourcedTextView` is the only renderer of sourced prose, and it must not
impose a colour.** The distinction is carried by a left border plus italics;
`style` stays null by default so the ambient `DefaultTextStyle` wins, because
`ListTile` sets its subtitle colour and an explicit `bodyMedium` silently
overrode it. Merge only the italic — `TextStyle(fontStyle:)` has
`inherit: true`. Scattering the treatment across call sites is how the
distinction stops being true.  *(item 79.3, final review)*

**`test/models/summary_provenance_tripwire_test.dart` is a dated guard, not a
behaviour test.** Published summaries read as the rulebook's words only because
`emit.py` builds each one by truncating the description. **Item 31 replaces them
with ledger-authored prose**, at which point the summary getters must switch to
`authored` and this test must be deleted — its failure message says so. It
covers all three asset populations (library, templates, exceptions), since
`emit.py` builds all three the same way. Its two exclusions are the contents of
`hand_authored_templates.json`, a category exclusion — **never add an id to
that list to make the test pass.**  *(item 79.3)*
