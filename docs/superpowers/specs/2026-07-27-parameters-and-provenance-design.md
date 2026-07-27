# Core Parameter Completion and Provenance — Design

**Date:** 2026-07-27
**Status:** Approved for planning

## Goal

Close todo item 15 (the parameter catalog is missing 8 core-rulebook entries) and
extend the citation/provenance model that `Spell` already has to `BaseEffect`,
`Parameter`, and `Modifier`, so all four kinds of catalog data record where they
came from in the same way.

## Out of Scope

Stated explicitly, because research surfaced real content that could plausibly
be folded in, and wasn't:

- **Merinita's Faerie Magic parameters** (Road, Bargain, Fire, Until (Condition),
  Year+1, Bloodline) and **Symbolic Magic's Symbol Range/Duration/Target** — both
  real, both found during this session's research, both deferred. See "Deferred
  Work" below.
- **A ritual-only flag.** Year and Boundary are ritual-only per the rulebook;
  Vision is explicitly not, despite the same magnitude. This constraint is added
  to the data as prose only — nothing in the model enforces it.
- **Disambiguating Target "Touch" from Range "Touch"** in the creation screen's
  dropdowns. They don't collide in data (ids are category-scoped), only in the
  UI label. Left as-is.
- **Citations on `Spell`** — already done, in the prior Spell Provenance and
  Tags plan. This plan extends the same pattern to the other three models.

## New Parameters

`parameters.json` grows from 17 to 25 entries:

| Category | Name | Magnitude | Basis |
|---|---|---|---|
| Range | Eye | +1 | Core Rules: paired with Touch, "same level of range" |
| Duration | Ring | +2 | Core Rules: paired with Sun |
| Duration | Year | +4 | Core Rules; ritual-only (unenforced, see above) |
| Target | Circle | +0 | Core Rules: paired with Individual |
| Target | Taste | +0 | Core Rules "Magical Senses": equivalent to Individual |
| Target | Touch | +1 | Core Rules "Magical Senses": equivalent to Part |
| Target | Smell | +2 | Core Rules "Magical Senses": equivalent to Group |
| Target | Hearing | +3 | Core Rules "Magical Senses": equivalent to Structure |

**Rename:** `target-bound` ("Bound") → `target-boundary` ("Boundary"), correcting
a data error against the rulebook's actual name (Core Rules: "Boundary"). Backward
compatibility is not a goal; the id may change. No built-in spell currently
references it.

**Citation for all 25 parameters (existing 17 + new 8):** `arm5-core`, no page.

## Provenance Model

`Spell` already has `source: SpellSource` and `citations: List<Citation>`,
validated by a shared function called from every construction path. Extending
that same shape independently to `BaseEffect`, `Parameter`, and `Modifier` would
repeat the exact failure mode already found and fixed once on `Spell`: a
constructor that forgets to call the shared validator. With four models instead
of one, that's four chances to forget instead of one.

Instead, the source/citations pairing is extracted into its own self-validating
value object:

```dart
enum PublicationSource {
  userCreated('user-created'),
  published('published');

  const PublicationSource(this.wireValue);
  final String wireValue;

  static PublicationSource fromWire(String value) => switch (value) {
        'user-created' => PublicationSource.userCreated,
        'published' => PublicationSource.published,
        _ => throw FormatException('Unknown PublicationSource: "$value"'),
      };
}

/// Where a catalog entry or spell came from, and — if published — where.
///
/// Self-validating: the published/user-created ⟺ has-citations rule is
/// enforced in this constructor, once, rather than by every model that embeds
/// it remembering to call a shared validator.
class Provenance {
  final PublicationSource source;
  final List<Citation> citations;

  Provenance({required this.source, this.citations = const []}) {
    if (source == PublicationSource.published && citations.isEmpty) {
      throw FormatException('Provenance: a published entry needs at least one citation');
    }
    if (source == PublicationSource.userCreated && citations.isNotEmpty) {
      throw FormatException('Provenance: a user-created entry cannot have citations');
    }
  }

  Map<String, dynamic> toMap() => {
        'source': source.wireValue,
        'citations': citations.map((c) => c.toMap()).toList(),
      };

  factory Provenance.fromMap(Map<String, dynamic> map) => Provenance(
        source: PublicationSource.fromWire(requireField<String>(map, 'source', 'Provenance')),
        citations: (map['citations'] as List?)
                ?.map((c) => Citation.fromMap(c as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
```

`PublicationSource` is a rename of the existing `SpellSource` (same two values,
same wire strings `"published"`/`"user-created"`) — moved because it's no
longer spell-specific.

**`SpellSource` is renamed, not duplicated.** Every existing reference (the
enum's own file, `Spell`, `ResolvedSpell`, the blocs, the repositories, the
card widget, and every test fixture across the codebase) moves to
`PublicationSource`. There is exactly one enum for "published or
user-created," used by all four models.

### Applying `Provenance`

- `Spell.provenance` replaces its separate `source: SpellSource` and
  `citations: List<Citation>` fields. `Spell`'s own summary-or-description
  invariant is unrelated to `Provenance` and stays on `Spell` — it's a rule
  about `Spell` specifically, not about publication.
- `BaseEffect`, `Parameter`, `Modifier` each replace their plain `String source`
  with `final Provenance provenance;`.
- `ResolvedSpell` keeps flat `source`/`citations` getters delegating to
  `record.provenance`, so its existing consumers (`SpellLibraryBloc`,
  `SpellCard`, etc.) change type (`String` → `PublicationSource`) but not
  shape.
- Every call site currently comparing `.source == 'published'`/`'user-created'`
  moves to `.provenance.source == PublicationSource.published` /
  `.userCreated`.

### JSON shape stays flat

`Provenance.toMap()`/`fromMap()` operate on flat top-level keys (`source`,
`citations`) — the same keys `Spell`'s JSON already uses from the prior plan.
Nothing on disk needs restructuring: adding citations to `base_effects.json`,
`parameters.json`, and `modifiers.json` is a purely additive script (append a
`citations` key next to the existing `source` key on every published entry),
not a rewrite of existing data. This was a deliberate simplification made
during design specifically so the migration could be scripted rather than
hand-edited.

## Migration Script Plan

Two scripted passes, run after the 8 new parameter entries are hand-authored
(without citations) into `parameters.json`:

1. **Add citations.** For every entry across `base_effects.json` (604),
   `parameters.json` (25), and `modifiers.json` (17) whose `source` is
   `"published"`, append `"citations": [{"bookId": "arm5-core"}]`. Purely
   additive — the existing `source` key is never touched. 646 entries total.
2. **Rename Boundary.** `target-bound` → `target-boundary`, `"Bound"` →
   `"Boundary"`, in `parameters.json` only.

Both are mechanical, following the same `re.subn`/JSON-script pattern already
used successfully for the built-in→published rename and the `Spell` migration
in the prior plan.

## Consumer Ripple

Measured directly against the current tree: 30 distinct files (across
`lib/`, `test/`, `integration_test/`) construct `BaseEffect(`, `Parameter(`, or
`Modifier(` and will need their `source: 'string'` argument replaced with
`provenance: Provenance(source: PublicationSource.xxx, citations: [...])`.
This is larger than the `Spell`-only ripple in the prior plan (14 files) because
`BaseEffect` and `Parameter` are constructed far more widely across the test
suite — nearly every engine, bloc, and widget test builds at least one fixture.

Every production call site comparing a catalog entry's `source` as a string
(`ConfigurationRepository`, `configuration_screen.dart`,
`spell_library_state.dart`, `backup_service.dart`, and others) moves to the
enum comparison.

## Testing

- `Provenance`/`PublicationSource` round-trip and invariant tests — including
  the constructor-level validation (learned directly from the gap found and
  fixed on `Spell`'s own constructor in the prior plan).
- `BaseEffect`/`Parameter`/`Modifier` `fromMap`/`toMap` tests updated for the
  new `provenance` field.
- The existing citation-resolution asset test (currently checks only
  `Spell.citations` against `books.json`) extends to check `BaseEffect`,
  `Parameter`, and `Modifier` citations resolve too.
- The parameter-count test moves from a literal `17` to `25` — kept as a
  literal, consistent with the existing precedent that this is a small,
  hand-curated list rather than bulk-extracted data prone to silent drift.
- **One built-in spell added or modified to exercise a real magical-sense
  target** (Taste, Touch, Smell, or Hearing), found and cited from the
  rulebook during plan-writing — not fabricated in this design doc. This
  mirrors how the Terram spells were researched and added for the modifiers
  plan's Size ladders.

## Deferred Work

Recorded here so the research done this session isn't lost, and filed as new
todo items rather than silently dropped:

**Merinita: Faerie Magic** (Core Rules, "Mysteries" chapter — not Houses of
Hermes: Mystery Cults, where the House's other content lives). Grants six
parameters to initiates of the Faerie Magic Outer Mystery only:

| Name | Type | Level | Note |
|---|---|---|---|
| Road | Range | = Voice | affects anyone/anything on the same road |
| Bargain | Duration | = Year + 3 magnitudes | ritual; max Year after triggering |
| Fire | Duration | = Moon | Ignem/Imaginem only |
| Until (Condition) | Duration | = Year | ritual |
| Year + 1 | Duration | = Year | ritual |
| Bloodline | Target | = Structure | affects all blood descendants of the immediate target |

**Symbolic Magic** (Houses of Hermes: Mystery Cults, House Merinita chapter).
Grants a Symbol Range/Duration/Target triad to initiates of the Symbolic Magic
Major Folk Mystery, always ritual, requiring physical charm objects
representing the target.

Both require: (a) a way to record that a parameter requires a specific Mystery
Virtue, and (b) a ritual-only flag — neither of which this app models today
(there is no character/Virtue model at all, only spell and catalog data). Real
content, real citations, genuinely deferred pending that groundwork.
