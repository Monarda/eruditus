# Exception Spells: recording what the rulebook says doesn't follow the guidelines

**Todo items:** 25, 26, 27 (each loses one or more spells to this collection,
with the item's own section updated to say so). Item 24 is explicitly
unaffected — see §Problem's exclusion list.

**Status:** designed 2026-08-15

**Rulebook:** `Ars-Magica-Open-License/reviewed/Ars Magica - Definitive
Edition (Core Rules).md`. Line references in this document are to that file.

---

## Problem

Six published spells are blocked for a different reason than every other
entry on the blocked list: the rulebook itself, in the spell's own printed
text, says the guideline-arithmetic system does not apply to it. No amount of
tokenizer widening or ledger work closes these — there is no arithmetic to
recover, because the spell was never designed that way.

Two shapes, confirmed against the pipeline's own `--show-blocked` output and
the rulebook text it's blocking on, not inferred from prose alone:

**Rulebook-disclaimed (General-kind — no printed level at all):**

- ***Wizard's Communion*** (line 15862). Design line is `(Base effect)`, but
  the prose (15864) says outright: *"Communion is a remnant of Mercurian
  rituals, so it does not perfectly fit into the guidelines of Hermetic
  theory."*
- ***Wizard's Vigil*** (line 15872). No design line at all — its prose (15874)
  defines it purely in relation to Communion: *"treat it as a Wizard's
  Communion of two magnitudes lower."* An exception defined relative to
  another exception.
- ***Aegis of the Hearth*** (line 15936). No design-line marker of any kind —
  not `(Base effect)`, nothing. Its prose explains why: a Major Breakthrough
  combining Mercurian ritual with Hermetic theory, *"more powerful than it
  ought to be, and has no Perdo requisite."* The general-base-effects design
  (2026-08-05) already flagged this spell as permanently unblockable for the
  identical reason, alongside *Whispering Winds*.

**Schema-mismatched (fixed printed level, but the shape doesn't fit R/D/T):**

- ***Whispering Winds*** (line 13251). Design line is literally `(Unique
  spell)` — a distinct marker, not a variant of `(Base effect)`. Prose:
  *"This spell is an adaptation of an effect known to Bjornaer the Founder,
  and fits poorly into the normal framework of Hermetic magic."*
- ***Watching Ward*** (line 15984). Prints `D: Spec` with no basis a reader
  could resolve to a real Duration — because the duration genuinely isn't one
  of the catalog's values. It lasts *"until the conditions you specify come
  to pass"* — event-triggered, not a missing catalog entry but a missing
  concept.
- ***Mists of Change*** (line 13694). Prints `D: Sun & Year` — two Durations
  for one spell — plus its own design-line clause, *"slightly nonstandard
  effect, mist and wind are cosmetic only."* The R/D/T model has exactly one
  Duration slot; this spell genuinely needs two.

`Spell` and `SpellTemplate` require `baseEffectId`/`rangeId`/`durationId`/
`targetId` as non-nullable references into the catalog. There is no way to
express "no base effect" or "two Durations" in that shape, and there
shouldn't be — widening it to tolerate these six would weaken the guarantee
every other spell relies on.

**Explicitly not in scope**, despite sharing the "blocked" list: *Sense of the
Lingering Magic* and *Conjuration of the Indubitable Cold* (genuinely
ambiguous resolutions of arithmetic that otherwise works — item 39/28's
territory, nothing to record here), the four catalog-gap spells (*Dispel the
Phantom Image*, *Lay to Rest the Haunting Spirit*, *Restore the Moved Image*,
*The Invisible Eye Revealed* — missing rows or a transcription defect, both
fixable the ordinary way), and the three unmodelled-mechanism spells (*Black
Whisper*, *Sight of the Active Magics*, *The Kiss of Death* — real, reusable
Ars Magica rules that belong in the Modifier catalog once built, not
exceptions to it). None of these nine spells enters `EXCEPTION_SPELLS`
(§4) — see the staleness test in §5.

## Backwards compatibility is not a goal

Eruditus is a prototype with no users. No migration path is designed and none
should be added.

---

## Design

### 1. `ExceptionSpell`, a new read-only entity

`lib/models/exception_spell.dart`. Everything a citation-worthy library entry
needs, and nothing that implies computability:

```dart
class ExceptionSpell {
  final String id;
  final String name;
  final String technique;
  final String form;
  final String range;       // free text: "Voice", "Touch" -- not a Parameter id
  final String duration;    // free text: "Sun & Year", "Until triggered"
  final String target;
  final bool isRitual;      // read straight off the stat line, no RitualDeclaration
                             // nuance needed -- nothing here is computed, so
                             // lastingCreation/storyguideRuling's "why did this
                             // become a Ritual" question never arises
  final int? printedLevel;  // null for the three General-kind entries
  final String? summary;
  final String? description;
  final String rationale;   // required (not optional, unlike Spell's citations)
                             // -- every entry must say *why* it's here instead
                             // of computed
  final Provenance provenance;
  final List<String> tags;
}
```

`technique`/`form` are plain strings, not looked up through a `BaseEffect` the
way `ResolvedSpell`/`ResolvedTemplate` derive them — there is no base effect
to look them up through. `range`/`duration`/`target` are plain strings for the
same reason `SpecialParameterBasis`-style resolution doesn't apply here: these
values were confirmed, spell by spell, not to resolve to a catalog id at all
(§Problem's "missing concept," not "missing catalog value").

The constructor reuses `validateSpellProse` unchanged — a published exception
still needs a summary or description, exactly like `Spell` and
`SpellTemplate`. `Provenance`'s own constructor already enforces the
published-needs-a-citation rule, so `rationale` is a second, additional
requirement on top of that, not a replacement for it.

**No common parent class with `Spell`/`SpellTemplate`.** `lib/models`
currently has zero `extends` relationships — the only inheritance-shaped
thing anywhere is `implements LibraryEntry`, and it is a pure interface
(`abstract interface class`, no shared state), used only at the
resolved/UI-consumption layer. Shared *behavior* between the record types is
already done via free functions (`validateSpellProse`,
`validateSpellAgainstCatalog`) specifically so `SpellDraft` — a different
shape — can reuse the identical logic without an inheritance relationship or
a circular import. A base class here would buy little even setting the
convention aside: the one field that would most want to be shared, R/D/T, is
exactly the field that cannot be identical — `Spell`/`SpellTemplate` need
typed catalog ids, `ExceptionSpell` needs free text, which is the entire
reason it exists as a separate type.

### 2. `ResolvedException` — the `LibraryEntry` wrapper

`lib/models/resolved_exception.dart`, alongside `ResolvedSpell` and
`ResolvedTemplate`:

```dart
class ResolvedException implements LibraryEntry {
  final ExceptionSpell record;
  const ResolvedException({required this.record});

  @override
  bool get isResolved => true; // nothing to resolve
  @override
  List<String> get unresolvedReferences => const [];
  @override
  String? get name => record.name;
  @override
  String? get technique => record.technique;
  @override
  String? get form => record.form;
  @override
  String? get summary => record.summary;
  @override
  String? get description => record.description;
  @override
  PublicationSource get source => record.provenance.source;

  String get rationale => record.rationale;
  bool get isRitual => record.isRitual;
  int? get printedLevel => record.printedLevel;
}
```

Trivial today — `isResolved` is always `true` because there is nothing to
look up. Kept as a distinct wrapper rather than having `ExceptionSpell`
`implements LibraryEntry` directly, because that mirrors how `Spell` and
`SpellTemplate` themselves never implement `LibraryEntry` — only their
`Resolved*` views do — and leaves a seam if `technique`/`form` ever become
real catalog references.

### 3. Asset, loader, repository

- `assets/data/spell_exceptions.json` — a flat list of `ExceptionSpell.toMap()`.
- `AssetDataLoader.loadSpellExceptions()`, mirroring `loadSpellTemplates()`.
- `LibraryRepository.getExceptions()` — simpler than `getTemplates()`: no
  catalog resolution step, since nothing in `ExceptionSpell` references the
  catalog. Just decode and wrap in `ResolvedException`.

### 4. Import pipeline

A new closed table in `scripts/spell_import/exceptions.py`:

```python
EXCEPTION_SPELLS: dict[str, str] = {
    "Wizard's Communion": (
        'Design line prints "(Base effect)" but the spell\'s own prose '
        'disclaims it: "Communion is a remnant of Mercurian rituals, so it '
        'does not perfectly fit into the guidelines of Hermetic theory."'
    ),
    "Wizard's Vigil": (
        "No design line at all -- defined purely relative to Wizard's "
        'Communion ("treat it as a Wizard\'s Communion of two magnitudes '
        'lower"), itself an exception.'
    ),
    "Aegis of the Hearth": (
        "No design-line marker of any kind. The rulebook's own text says "
        'why: a Major Breakthrough combining Mercurian ritual with Hermetic '
        'theory, "more powerful than it ought to be, and has no Perdo '
        'requisite."'
    ),
    "Whispering Winds": (
        'Design line is "(Unique spell)", not a variant of "(Base effect)". '
        'Prose: "fits poorly into the normal framework of Hermetic magic."'
    ),
    "Watching Ward": (
        'Duration is event-triggered ("until the conditions you specify '
        'come to pass") -- not a missing catalog value, a missing concept.'
    ),
    "Mists of Change": (
        'Prints two Durations in one stat line ("D: Sun & Year") plus its '
        'own "slightly nonstandard effect" clause -- the R/D/T model has '
        "exactly one Duration slot."
    ),
}
```

`extract_spells.py`'s main loop checks a block's name against
`EXCEPTION_SPELLS` **before** it would otherwise land in `blocked`. A match
routes to a new `emit.build_exception_spell(block, rationale)` instead of
`build_spell` — no design-line tokenization is attempted at all for these six,
sidestepping the arithmetic pipeline entirely rather than coaxing it through a
case it was never meant to handle. `build_exception_spell` reuses
`SpellBlock`'s already-parsed technique/form/prose/stat-line fields
(`range_name`/`duration_name`/`target_name` as-is, `is_ritual` as-is) — no new
parsing logic, just a different sink for data the extractor already has.

Output: a new `report.exceptions` list, written to `spell_exceptions.json` by
`--write`, reported in the summary line (`imported : 320 · exceptions : 6 ·
templates : 24 · blocked : 10`).

**Guards, both required — this table can drift in either direction:**

- A staleness test (shape of `KnownUnresolvableStalenessTest`): every
  `EXCEPTION_SPELLS` name must still exist in the corpus and still land in
  `report.exceptions`, not silently start resolving normally or vanish from a
  rulebook update.
- A disjointness test: no `EXCEPTION_SPELLS` key may also appear in
  `KNOWN_UNRESOLVABLE`, `HAND_DERIVED`, or any other closed table — each
  blocked/excepted spell has exactly one home.
- A regeneration test for `spell_exceptions.json`, byte-for-byte, matching
  the existing ones for `spell_library.json`/`spell_templates.json`.

### 5. UI

A third section in `SpellLibraryScreen`, below the leveled-spells list (after
Templates, after ordinary Spells) — these six are curiosities, not the
primary actionable content the screen exists for. Heading: *"Exceptions —
recorded from the rulebook directly, not derived from the guidelines."*
Omitted entirely when empty, matching the Templates section's own
convention.

`SpellCard` gains one new optional flag, `isException`, rendering a
`Chip(key: Key('exception-chip'), label: Text('Exception'))` alongside the
existing `ritual-chip`/`general-chip`. No `isGeneral` flag is passed for
these — that chip specifically signals "instantiate via Learn at level…,"
which does not apply here. `level` is passed straight from
`ResolvedException.printedLevel` (nullable): the existing `level != null`
branch in `SpellCard` already renders `"Technique Form"` with no level number
when it's null, so the three General-kind exceptions need no special-casing
there. No `actions` — there is nothing to instantiate, edit, or learn.

`rationale` renders as a second subtitle line, below the summary/description
blurb, so the "why is this here and not computed" answer is never a click
away.

### 6. `todo.md`'s standing goal

Current wording claims universal computability. Amend to:

> **Standing goal:** every published spell in the Definitive Edition core
> rules is either (a) in the spell library with its computed level matching
> its printed level, or (b) recorded as an exception spell with a
> citation-backed reason the guidelines don't apply to it.

Items 24, 25, 26 and 27's own sections each note which of their currently-listed
spells move to this collection instead of staying in their blocked count.

---

## Testing

**Python — `scripts/spell_import/tests/`**

- `build_exception_spell` produces the expected `ExceptionSpell` shape for
  all six spells, R/D/T strings matching the stat line verbatim.
- The staleness and disjointness guards from §4.
- The `spell_exceptions.json` regeneration test.

**Dart — `test/`**

- `ExceptionSpell`/`ResolvedException` serialization round-trips.
- `validateSpellProse` still rejects a published `ExceptionSpell` with
  neither summary nor description (proves the reuse actually wires through,
  not just compiles).
- `SpellCard` renders the `exception-chip` when `isException` is true, and
  renders a level-less subtitle for a null `printedLevel`.
- `LibraryRepository.getExceptions()` returns all six, each `isResolved`.

**Integration — `integration_test/`**

- The Exceptions section appears in the Library screen, below Templates and
  Spells, and is absent when the list is empty (a mocked-empty-repository
  variant, not one of the six real spells).

---

## Non-goals

- **Editing, instantiating, or "learning" an exception spell.** These are
  read-only canon records, not templates or drafts.
- **Typed `technique`/`form` catalog references.** Plain strings for now,
  same as `range`/`duration`/`target`.
- **Any of the nine explicitly-excluded spells from §Problem.** Sense of the
  Lingering Magic, Conjuration of the Indubitable Cold, the four catalog-gap
  spells, and the three unmodelled-mechanism spells stay under their existing
  items, not this one.
- **A common parent class for `Spell`/`SpellTemplate`/`ExceptionSpell`.**
  Decided against in §1.
- **Any migration path.** See "Backwards compatibility is not a goal."
