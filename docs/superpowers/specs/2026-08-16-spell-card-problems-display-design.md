# Surfacing ResolvedSpell.problems on the Library Card — Design

**Date:** 2026-08-16
**Status:** Approved for planning

## Goal

Close todo item 40's last open checkbox: give `ResolvedSpell.problems`
(shipped 2026-08-09, `lib/models/resolved_spell.dart`) a UI consumer. The
design doc that introduced it named "Library renders an invalid card" as the
consumer, but no task in that plan built it, so a spell that becomes invalid
*after* being written — the read-side half of the blocking-vs-degrading
split, unreachable by write-time blocking — is currently invisible: the value
is computed correctly and has zero effect anywhere in the app.

## Context (confirmed by reading the code, not assumed)

- `problems` is a deliberate **sibling** of `isResolved`, not a replacement:
  `isResolved` is a can-I-compute gate (`baseEffect`/`range`/`duration`/
  `target` all resolve); `problems` means the level computes but the
  combination breaks a rule (duplicate requisite art, wrong modifier
  cardinality, a missing chosen level/slot, etc.). Its entries are already
  plain-English, display-ready strings (`spell.dart`'s
  `validateSpellAgainstCatalog`), e.g. *"Choose a level for this General
  guideline"*.
- Today, `SpellLibraryBloc` gates only on `isResolved` (`spell_library_bloc.dart:45`)
  before calling `calculateBreakdown`; `problems` doesn't affect anything
  currently. A `problems`-nonempty spell renders as an entirely ordinary
  card, level and all.
- `SpellCard` already has the precedent this mirrors: when `!entry.isResolved`,
  it swaps the subtitle for an error-colored "Unavailable — missing X, Y" line
  and tags the `Card` with `Key('spell-card-unresolved')`.
- `SpellCard.entry` is typed as the `LibraryEntry` interface, whose doc
  comment states it is "everything SpellCard reads, and nothing else" —
  implemented by `ResolvedSpell`, `ResolvedTemplate`, and `ResolvedException`
  so one widget renders all three without drifting into near-identical
  copies. `problems` is **not** on `LibraryEntry` — only `ResolvedSpell`
  exposes it (`ResolvedTemplate`/`ResolvedException` have no such getter;
  `SpellTemplate` has no `chosenBaseLevel` field at all).
- `SpellCard` already takes several values **precomputed by the caller**
  rather than derived from `entry` internally (`isRitual`, `isGeneral`,
  `isException`, `rationale`) — the established pattern for exactly this
  situation.
- Only `SpellLibraryScreen`'s bare spell-mapping call constructs `SpellCard`
  from a `ResolvedSpell` (`state.visibleSpells.map((s) => SpellCard(entry: s, …))`).
  `_TemplateCard` and `_ExceptionCard` construct it from `ResolvedTemplate`/
  `ResolvedException` and are unaffected.
- Realistically this only fires for **user-created spells** — published
  spells are asset-validated at build time (assertion 7,
  `published_spell_import_test.dart`), so `problems` is provably empty for
  all 360 of them today. The live case is a restored backup, or a custom
  effect/modifier edited in Settings after a spell built on it was saved.

## Out of Scope

- **`ResolvedTemplate`/`ResolvedException` gaining a `problems` getter.**
  Neither has one today; adding one is a separate, later item, not bundled
  into giving the existing spell-only getter its display.
- **Any edit/fix action from the card.** The Library screen doesn't wire
  `onTap` for spell cards at all today; adding an edit flow is a distinct,
  larger feature.
- **Bloc-level filtering or sorting change.** An invalid spell still appears
  in search/filter results exactly like any other spell — flagged, not
  hidden or demoted.
- **Any change to `SpellLibraryBloc`.** It already computes a level for a
  `problems`-nonempty spell today (nothing gates on `problems`, only
  `isResolved`); only the screen's card-construction call site changes.

## Approach

### `SpellCard` (`lib/presentation/widgets/spell_card.dart`)

New parameter, defaulting to empty so every existing call site (and test) is
unaffected:

```dart
/// Catalog-validity problems on the underlying record — a sibling of
/// [LibraryEntry.isResolved], not a substitute for it. Only [ResolvedSpell]
/// exposes this today (see ResolvedSpell.problems' doc comment), so it is
/// precomputed by the caller rather than read from `entry`, the same way
/// [isRitual]/[isGeneral]/[rationale] already are.
final List<String> problems;
```

Rendering, gated on `entry.isResolved && problems.isNotEmpty` — deliberately
**not** triggered when `!isResolved`, so the existing "Unavailable — missing
X" branch is untouched regardless of what `problems` happens to return in
that state:

- **Chip**, appended to the existing title-row chip group (after
  Ritual/Gen/Exception): `Key('needs-review-chip')`, label "Needs review",
  styled with `colorScheme.errorContainer`/`onErrorContainer` so it reads as
  a warning rather than blending in with the neutral category chips.
- **Level suffix**: when a level is shown, append `' (unverified)'` to the
  existing `'$technique $form • Level $level'` string. Ritual/General chips
  are unaffected — the breakdown did compute successfully; only the number's
  trustworthiness is in question.
- **Text line**, in the same subtitle-column slot as `rationale`, below the
  blurb: `problems.join('; ')`, styled in `Theme.of(context).colorScheme.error`
  — the same color the unresolved case already uses for its own line.
- `Card`'s `key` becomes `Key('spell-card-invalid')` in this state (parallel
  to the existing `Key('spell-card-unresolved')`; the two states are mutually
  exclusive since the new branch requires `isResolved`).

### `SpellLibraryScreen` (`lib/presentation/screens/spell_library_screen.dart`)

One call site changes:

```dart
...state.visibleSpells.map((s) => SpellCard(
      entry: s,
      level: state.spellLevels[s.id],
      isRitual: state.ritualSpellIds.contains(s.id),
      problems: s.problems,
    )),
```

### Tests

- **`test/presentation/widgets/spell_card_test.dart`**: a resolved
  `ResolvedSpell` with non-empty `problems` renders the chip, the joined
  text line, and the `(unverified)` level suffix; the same spell with empty
  `problems` is pixel-for-pixel unchanged from today's rendering (a
  regression guard, since this is the common case for all 360 published
  spells); an *unresolved* spell with a non-empty `problems` value (the
  `baseEffect`-present-but-`range`-null edge case) still renders the
  existing "Unavailable" branch only, confirming the two states don't layer.
- **`test/presentation/screens/spell_library_screen_test.dart`**: a
  `ResolvedSpell` with `problems` set reaches its rendered `SpellCard` with
  `Key('spell-card-invalid')`.

## Testing Strategy

Standard `flutter test` coverage for the widget and screen changes above,
written test-first. No Python import-pipeline code, catalog asset, or
`problems` computation itself is touched — this is a pure display consumer
of an already-shipped, already-tested value.
