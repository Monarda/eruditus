# Spell Provenance and Tags — Design

**Date:** 2026-07-27
**Status:** Approved for planning

## Goal

Prepare the data models for two pieces of future work — parsing the published
spell corpus into the library, and browsing that library independently of spell
creation — without implementing either.

Three changes, all model-level:

1. Spells carry optional **tags**, stored but not surfaced in any UI.
2. The overloaded `description` field splits into **`summary`** (short
   paraphrase) and **`description`** (verbatim rulebook text).
3. `source` becomes a two-value enum — **`userCreated`** or **`published`** —
   and a published spell carries one or more **citations** naming the book and
   page it appeared in. A spell can be published in more than one place.

## Out of Scope

Stated explicitly, because each is a plausible misreading of the above:

- **Parsing published spells.** No spell data is imported. The 30 existing
  built-in spells are migrated in place; nothing new is added.
- **Library browsing UI.** No new screens, no changes to how the library is
  navigated.
- **Tag UI.** Tags exist in the model and in persistence. Nothing reads them.
- **Page numbers.** Not available yet; they arrive with the parsing work. Every
  citation created by this change has a book and a null page.
- **Citations on `BaseEffect` / `Parameter` / `Modifier`.** Those keep a plain
  string `source`. Only its *value* changes (see "Vocabulary alignment").

## Model

```dart
enum SpellSource { userCreated, published }

class Citation {
  final String bookId;  // resolves against books.json
  final int? page;      // null until the page-number work lands
}

class Spell {
  // unchanged: id, name, baseEffectId, rangeId, durationId, targetId,
  //            selectedModifiers, requisites, createdAt, updatedAt
  final String? summary;           // NEW — short paraphrase
  final String? description;       // KEPT — meaning narrowed to verbatim text
  final SpellSource source;        // was: String 'built-in' | 'user-created'
  final List<Citation> citations;  // NEW
  final List<String> tags;         // NEW, defaults to const []
}
```

### Invariants

1. A **published** spell has at least one of `summary` / `description`, present
   and non-empty. A **user-created** spell may have neither.
2. `source == userCreated` ⟺ `citations.isEmpty`.
3. `source == published` ⟹ at least one citation.

**Invariant 1 is conditional only as an interim measure.** User-created spells
should eventually carry a summary or description too. They cannot yet: the
creation screen collects only a name — `SpellSaveRequested(name)` carries
nothing else — so an unconditional rule would reject every user-created spell on
save. Collecting the text needs an input field and a new event, which is UI work
and out of scope here.

So this plan prepares the model and defers the UI. `SpellDraft` gains a `summary`
field (see below) so the later work is purely presentational, with no further
model change. When that UI lands, invariant 1 should be tightened to apply to
both sources. Tracked as todo item 13.

The two alternatives were both worse: forcing a prose field into the creation
screen now is scope creep, and auto-deriving a summary would store derivable
data, which is precisely what the id-reference normalization removed.

### Serialization

`SpellSource` serializes to exactly the strings `"published"` and
`"user-created"` — the same two values the catalog models use, and the same
values stored in the `spells.source` column. An unrecognised string is a
`FormatException`, not a silent default.

### Enforcement

Following patterns already in the codebase rather than inventing one:

- `Spell.fromMap` validates all three invariants and throws `FormatException`,
  consistent with the existing `requireField<T>` helper.
- `SpellDraft.toSpell` throws `StateError`, consistent with its current
  missing-field behaviour.

Both delegate to one shared validator so the rules are stated once.

### `SpellDraft`

Gains a `String? summary` field alongside the `String? description` it already
has, and `toSpell` passes both through. Nothing sets either today — no code in
`lib/bloc/spell_creation/` writes `description`, so it is always null in
practice — but carrying them means the deferred UI work adds only an input
widget and an event, never another model change.

Otherwise unchanged. It holds catalog objects for the creation screen's
dropdowns, and the remaining new fields are not surfaced there: tags are
deliberately not exposed, and a user-created spell has no citations by
definition. `toSpell` emits `source: SpellSource.userCreated`, an empty citation
list, and empty tags.

## Books Catalog

New asset `assets/data/books.json`, a `Book` model, and
`AssetDataLoader.loadBooks()`:

```json
[
  { "id": "arm5-core", "title": "Ars Magica Fifth Edition",
    "abbreviation": "ArM5", "edition": "5e" }
]
```

**Seeded with the core rulebook only.** All 30 existing spells are ArM5 core
spells, verified by name — including the three Terram entries added for modifier
coverage. Nothing else is cited yet, and the asset test below makes a missing
book fail loudly, so the parsing work will be told exactly which rows to add as
it needs them. Curating 43 further books that nothing references would be
speculative.

The catalog is curated, not scraped: the 56 files in the sibling
`Ars-Magica-Open-License` repo include two OCR passes of Hedge Magic, the same
Iceland book under two titles, and a 3e file marked `DO NOT USE`. Files are not
works.

## Citations Are Not Part of Resolution

`ResolvedSpell.isResolved` means "every input needed to calculate this spell's
level is present" — base effect plus three parameters. A book citation has no
bearing on that. A spell with a broken bibliography reference is still perfectly
calculable, and making it render as "Unavailable" would be wrong.

Therefore:

- `SpellResolver` and `ResolvedSpell` are **unchanged**. Books are not threaded
  through them.
- There is **no `BookResolver`**. Nothing displays citations until the browsing
  UI exists; building resolution now would be speculative.
- Correctness is guarded instead by an **asset test**: every `bookId` cited by
  any built-in spell must exist in `books.json`. This extends the existing test
  that checks every spell's `baseEffectId` and parameter ids resolve — same
  file, same pattern.

## Vocabulary Alignment

`BaseEffect`, `Parameter` and `Modifier` keep a plain string `source`, but its
`'built-in'` value is renamed to `'published'` so that one word means one thing
across the codebase. They gain no citations and no structural change.

This front-loads the rename while there is little data. If base effects later
gain citations — they do come from specific rulebook pages — only structure gets
added, with no second rename.

Scale: **668 values** across four asset files (`base_effects.json` 604,
`parameters.json` 17, `modifiers.json` 17, `spell_library.json` 30). Mechanical,
one script.

**No database migration is required for this rename.** Every custom row in the
database is `user-created`, which is unchanged; built-in catalog data lives only
in assets.

This supersedes the constraint from the id-reference normalization plan that
`source` values are exactly `'built-in'` and `'user-created'`.

## Persistence

Schema **version 4**. The `spells` table is the only one whose shape changes.

The `onUpgrade` narrowing committed in `a4ea6e5` already does exactly the right
thing without modification: it drops `spells` and recreates it, while preserving
the user's custom effects, parameters and modifiers.

The `source` column survives with new values (`published` / `user-created`), so
the library's source filter keeps working. `summary`, `description`, `citations`
and `tags` ride in the existing `data` JSON blob — no new columns.

Backward compatibility is not a goal. Stored spells from before this change are
destroyed by the migration, not translated.

## Migration of Existing Data

For each of the 30 spells in `spell_library.json`:

- Current `description` → **`summary`**. Every one is a hand-written paraphrase
  ending in "Level N.", not verbatim rulebook text.
- `description` → absent, pending the parsing work.
- `"source": "built-in"` → `"source": "published"`.
- `citations` → `[{ "bookId": "arm5-core" }]`, page omitted.
- `tags` → omitted (defaults to empty).

## Consumer Changes

- `spell_library_state.dart:31` — filter compares `SpellSource.published`.
- `library_repository.dart:70` — `filterBySource` takes the enum.
- `spell_creation_bloc.dart:191` — saves `SpellSource.userCreated`.
- `SpellCard` — "Built-in" badge becomes "Published".
- `asset_data_loader_test.dart` — the regex that verifies all 30 built-in spells
  calculate to the level stated in their prose must read `summary`, since that
  is where the "Level N." text now lives.
- `backup_service.dart` — no change. Citations and tags serialize through
  `record.toMap()` automatically.

## Testing

- `Citation` and `Book` map round-trips, including a citation with a null page.
- Each of the three invariants, in both the `fromMap` and `toSpell` paths.
- A user-created spell with neither summary nor description is valid; a
  published one without either is rejected.
- A spell with two citations round-trips with both intact.
- Asset test: every cited `bookId` exists in `books.json`.
- Asset test: all 30 built-in spells still calculate to their stated level, now
  read from `summary`.
- Migration test: upgrading to v4 drops spells while custom effects, parameters
  and modifiers survive. No such test exists today; it is the natural guard for
  the migration-scope finding fixed in `a4ea6e5`.

## Deliberately Deferred

Both cost nothing to defer, because no tag data will exist until the UI or the
parsing work writes some:

- **Tag normalisation** — whether tags are lowercased and trimmed on the way in,
  or stored with display casing and matched case-insensitively.
- **Tag vocabulary** — free text, a curated list, or free text with suggestions
  drawn from existing tags. `List<String>` serves all three, so todo item 9 can
  decide when it builds the UI.
