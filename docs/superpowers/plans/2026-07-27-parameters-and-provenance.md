# Core Parameter Completion and Provenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close todo item 15 (8 missing core-rulebook parameters + a data-error rename) and extend `Spell`'s citation/provenance model to `BaseEffect`, `Parameter`, and `Modifier`.

**Architecture:** A self-validating `Provenance` value object (`PublicationSource` + `List<Citation>`) replaces the separate `source`/`citations` fields `Spell` already had, and replaces the plain `String source` field on the other three catalog models. Each model change is its own task, self-contained with its own citation-migration script, because flipping a model's `fromMap` to require citations before the JSON has them would make every existing entry fail to load.

**Tech Stack:** Flutter, Dart 3 (enhanced enums), sqflite / sqflite_common_ffi, flutter_bloc, equatable, mocktail, bloc_test.

**Spec:** `docs/superpowers/specs/2026-07-27-parameters-and-provenance-design.md`

## Global Constraints

- **Backward compatibility is not a goal**, neither for the API nor for stored data. No compatibility shims.
- **`PublicationSource` serializes to exactly `"published"` and `"user-created"`** — the same two wire values `SpellSource` already used. An unrecognised string is a `FormatException`, never a silent default.
- **`Provenance` is self-validating**: published ⟹ ≥1 citation, user-created ⟹ 0 citations, enforced in its own constructor. No model that embeds a `Provenance` needs its own copy of this check — that was the whole point of extracting it (a prior plan found and fixed a bug where `Spell`'s own constructor forgot to call a shared validator; with four models embedding this rule, that failure mode gets four chances instead of one).
- **The JSON shape stays flat.** `Provenance.toMap()`/`fromMap()` read and write plain top-level `source`/`citations` keys — the same keys `Spell`'s JSON already has. Adding citations to existing catalog data is a purely additive script; it must never restructure or nest existing entries.
- **No ritual-only flag, no Virtue-gating field.** Both are real constraints on Year/Boundary and on the Merinita/Symbolic-Magic content, and both are explicitly deferred — see todo items 14 and the newly-filed Merinita item. Do not add either field in this plan.
- **The Target "Touch" vs. Range "Touch" name collision is left as-is.** They don't collide in data (`target-touch` vs `range-touch`), only in the creation screen's dropdown labels. Not addressed here.
- **The books catalog stays seeded with `arm5-core` only.** Do not add other books.
- **No database schema change.** Confirmed by reading `app_database.dart`: only the `spells` table has a `source` column; `custom_effects`/`custom_parameters`/`custom_modifiers` store everything inside their `data` JSON blob, so a citations addition there needs no column and no version bump.
- **The suite is 239 unit tests / 0 failures, 4/4 integration tests before this plan starts, and must be green at every task boundary.** No pre-existing-failure allowance.
- **`flutter test` does not run `integration_test/`.** That needs `flutter test integration_test/<file> -d windows`.
- **Do not run `flutter analyze` and `flutter test` concurrently** — they contend over `build/`.
- **`python3` is a broken Windows Store alias in this environment; use `python`.**
- **Flutter is not on the default PATH.** Prepend `export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"`.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/models/publication_source.dart` | The `PublicationSource` enum (renamed from `SpellSource`). |
| `lib/models/provenance.dart` | The self-validating `Provenance` value object. |
| `test/models/publication_source_test.dart` | Renamed from `spell_source_test.dart`. |
| `test/models/provenance_test.dart` | `Provenance` round-trip and invariant tests. |

**Deleted:** `lib/models/spell_source.dart`, `test/models/spell_source_test.dart` (superseded by the two files above).

**Modified:** `lib/models/spell.dart`, `lib/models/resolved_spell.dart`, `lib/models/base_effect.dart`, `lib/models/parameter.dart`, `lib/models/modifier.dart`, `lib/data/datasources/local_spell_datasource.dart`, `lib/bloc/spell_library/spell_library_state.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart`, `lib/data/repositories/library_repository.dart`, `lib/presentation/widgets/spell_card.dart`, `lib/presentation/screens/configuration_screen.dart`, `lib/data/services/backup_service.dart`, `assets/data/base_effects.json`, `assets/data/parameters.json`, `assets/data/modifiers.json`, `assets/data/spell_library.json`, plus every test file listed per task below.

## A note on task sizing

Each of Tasks 2, 3, and 4 flips one model's `source` field to `Provenance` **and** migrates that model's asset JSON to carry citations, in the same task. They cannot be split further: the moment `BaseEffect.fromMap` requires a `Provenance` (which throws if a published entry has zero citations), every one of the 604 existing base effects would fail to load unless the JSON migration has already run. The model flip and its data migration are one atomic unit of "still loads correctly."

Task 1 has no such data dependency — `Spell`'s JSON wire format doesn't change at all, only its Dart-side field grouping — so it needs no migration step and is the smallest task.

---

### Task 1: `PublicationSource` and `Provenance`; flip `Spell`/`ResolvedSpell`

**Files:**
- Create: `lib/models/publication_source.dart`, `lib/models/provenance.dart`, `test/models/publication_source_test.dart`, `test/models/provenance_test.dart`
- Delete: `lib/models/spell_source.dart`, `test/models/spell_source_test.dart`
- Modify: `lib/models/spell.dart`, `lib/models/resolved_spell.dart`, `lib/data/datasources/local_spell_datasource.dart`, `lib/bloc/spell_library/spell_library_state.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart`, `lib/data/repositories/library_repository.dart`, `lib/presentation/widgets/spell_card.dart`
- Test: `test/models/spell_test.dart`, `test/models/resolved_spell_test.dart`, `test/data/datasources/asset_data_loader_test.dart`, `test/data/datasources/local_spell_datasource_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/data/repositories/spell_repository_test.dart`, `test/data/services/backup_service_test.dart`, `test/data/spell_resolver_test.dart`, `test/engine/spell_engine_test.dart`, `test/bloc/spell_creation_bloc_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/presentation/widgets/spell_card_test.dart`, `integration_test/spell_creation_flow_test.dart`

**Interfaces:**
- Consumes: nothing new — `Citation` already exists (`lib/models/citation.dart`), unchanged.
- Produces:
  - `enum PublicationSource { userCreated, published }` with `wireValue` and `fromWire`, identical shape to the old `SpellSource`.
  - `class Provenance { final PublicationSource source; final List<Citation> citations; Provenance({required source, citations = const []}) /* throws FormatException if invalid */; toMap(); factory fromMap(); }`.
  - `Spell.provenance` (type `Provenance`) replaces `Spell.source`/`Spell.citations`.
  - `ResolvedSpell.source` / `ResolvedSpell.citations` keep their existing flat getter shape and types (`PublicationSource`, `List<Citation>`), now delegating to `record.provenance.source`/`record.provenance.citations` instead of `record.source`/`record.citations`. **This is a deliberate asymmetry**: `ResolvedSpell` is a join/wrapper layer that already flattens several of `Spell`'s fields for its consumers (blocs, `SpellCard`) — it keeps doing that. `Spell` itself is a base record, like `BaseEffect`/`Parameter`/`Modifier` will be after Tasks 2-4, and exposes only `.provenance` — no flat delegating getter of its own.
  - `SpellDraft.toSpell({required String name, required PublicationSource source})` — same signature shape, `SpellSource` → `PublicationSource`.

- [ ] **Step 1: Write the failing `PublicationSource` test**

Create `test/models/publication_source_test.dart` (this is `spell_source_test.dart` renamed and retyped):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  test('wire values are exactly the two strings used in storage and assets', () {
    expect(PublicationSource.published.wireValue, 'published');
    expect(PublicationSource.userCreated.wireValue, 'user-created');
  });

  test('fromWire round-trips every value', () {
    for (final source in PublicationSource.values) {
      expect(PublicationSource.fromWire(source.wireValue), source);
    }
  });

  test('an unrecognised value throws rather than defaulting silently', () {
    expect(() => PublicationSource.fromWire('built-in'),
        throwsA(isA<FormatException>()));
  });
}
```

- [ ] **Step 2: Delete the old test and source file, add the new source file**

```bash
git rm lib/models/spell_source.dart test/models/spell_source_test.dart
```

Create `lib/models/publication_source.dart`:

```dart
/// Where a catalog entry or spell came from: an entry the user authored, or
/// one taken from a published book.
///
/// Used by [Spell] and, from here on, by [BaseEffect], [Parameter], and
/// [Modifier] too — one enum for "published or user-created" across every
/// kind of catalog data, rather than a plain string repeated per model.
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
```

- [ ] **Step 3: Run the new test to verify it passes**

Run: `flutter test test/models/publication_source_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 4: Write the failing `Provenance` test**

Create `test/models/provenance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  test('a published provenance with a citation round-trips', () {
    final provenance = Provenance(
      source: PublicationSource.published,
      citations: const [Citation(bookId: 'arm5-core')],
    );
    final restored = Provenance.fromMap(provenance.toMap());

    expect(restored.source, PublicationSource.published);
    expect(restored.citations, [const Citation(bookId: 'arm5-core')]);
  });

  test('a user-created provenance with no citations round-trips', () {
    final provenance = Provenance(source: PublicationSource.userCreated);
    final restored = Provenance.fromMap(provenance.toMap());

    expect(restored.source, PublicationSource.userCreated);
    expect(restored.citations, isEmpty);
  });

  test('published with no citations throws at construction', () {
    expect(() => Provenance(source: PublicationSource.published),
        throwsA(isA<FormatException>()));
  });

  test('user-created with a citation throws at construction', () {
    expect(
      () => Provenance(
        source: PublicationSource.userCreated,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromMap defaults citations to empty when the key is absent', () {
    final provenance = Provenance.fromMap({'source': 'user-created'});
    expect(provenance.citations, isEmpty);
  });

  test('two citations to the same book on different pages both survive', () {
    final provenance = Provenance(
      source: PublicationSource.published,
      citations: const [
        Citation(bookId: 'arm5-core', page: 10),
        Citation(bookId: 'arm5-core', page: 42),
      ],
    );
    final restored = Provenance.fromMap(provenance.toMap());
    expect(restored.citations, hasLength(2));
  });
}
```

- [ ] **Step 5: Run it to verify it fails**

Run: `flutter test test/models/provenance_test.dart`
Expected: FAIL — package `eruditus/models/provenance.dart` cannot be resolved.

- [ ] **Step 6: Write `Provenance`**

Create `lib/models/provenance.dart`:

```dart
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/utils/map_serialization.dart';

/// Where a catalog entry or spell came from, and — if published — where.
///
/// Self-validating: the published/user-created ⟺ has-citations rule is
/// enforced in this constructor, once, rather than by every model that
/// embeds a [Provenance] remembering to call a shared validator function.
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

- [ ] **Step 7: Run it to verify it passes**

Run: `flutter test test/models/provenance_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 8: Rewrite `Spell` to use `Provenance`**

In `lib/models/spell.dart`, replace the import of `spell_source.dart` with `provenance.dart` and `publication_source.dart`:

```dart
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/utils/map_serialization.dart';
```

Replace `validateSpellFields` — it now only checks the summary-or-description rule, since `Provenance`'s own constructor already enforces the citation invariant:

```dart
/// The prose rule every published [Spell] must satisfy, stated once and
/// shared by [Spell.fromMap] and [SpellDraft.toSpell] so the two paths
/// cannot drift.
///
/// Returns a list of human-readable problems; empty means valid.
///
/// This rule applies to published spells only. This is interim: user-created
/// spells should carry prose too, but the creation screen collects nothing
/// but a name, so an unconditional rule would reject every user-created
/// spell on save. Tighten this when that UI lands — todo item 13.
///
/// The citation invariant (published needs ≥1 citation, user-created needs
/// 0) is no longer checked here — it now lives on [Provenance] itself, and
/// is enforced when the [Provenance] passed to this [Spell] was constructed.
List<String> validateSpellProse({
  required PublicationSource source,
  required String? summary,
  required String? description,
}) {
  final hasProse = (summary != null && summary.isNotEmpty) ||
      (description != null && description.isNotEmpty);

  if (source == PublicationSource.published && !hasProse) {
    return ['a published spell needs a summary or a description'];
  }
  return const [];
}
```

Replace the `Spell` class:

```dart
/// A saved spell, stored as references into the effect/parameter catalogs.
///
/// This record deliberately holds no copy of any catalog data — no base level,
/// magnitude, technique or form. Those are looked up through [SpellResolver] on
/// read, so there is exactly one source of truth.
///
/// [summary] is a short paraphrase; [description] is verbatim text from the
/// rulebook. Both are optional individually, and a published spell needs at
/// least one of them.
class Spell {
  final String id;
  final String? name;
  final String baseEffectId;
  final String rangeId;
  final String durationId;
  final String targetId;
  final Map<String, List<String>> selectedModifiers;
  final List<Requisite> requisites;
  final String? summary;
  final String? description;
  final Provenance provenance;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Spell({
    required this.id,
    this.name,
    required this.baseEffectId,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    required this.requisites,
    this.summary,
    this.description,
    required this.provenance,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  }) {
    final problems = validateSpellProse(
      source: provenance.source,
      summary: summary,
      description: description,
    );
    if (problems.isNotEmpty) {
      throw FormatException('Spell: ${problems.join('; ')}');
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'baseEffectId': baseEffectId,
        'rangeId': rangeId,
        'durationId': durationId,
        'targetId': targetId,
        'selectedModifiers': selectedModifiers,
        'requisites': requisites.map((r) => r.toMap()).toList(),
        'summary': summary,
        'description': description,
        ...provenance.toMap(),
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Spell.fromMap(Map<String, dynamic> map) => Spell(
        id: requireField<String>(map, 'id', 'Spell'),
        name: map['name'] as String?,
        baseEffectId: requireField<String>(map, 'baseEffectId', 'Spell'),
        rangeId: requireField<String>(map, 'rangeId', 'Spell'),
        durationId: requireField<String>(map, 'durationId', 'Spell'),
        targetId: requireField<String>(map, 'targetId', 'Spell'),
        selectedModifiers: (map['selectedModifiers'] as Map?)?.map(
              (k, v) => MapEntry(k as String, List<String>.from(v as List)),
            ) ??
            const {},
        requisites: (map['requisites'] as List?)
                ?.map((r) => Requisite.fromMap(r as Map<String, dynamic>))
                .toList() ??
            [],
        summary: map['summary'] as String?,
        description: map['description'] as String?,
        provenance: Provenance.fromMap(map),
        tags: (map['tags'] as List?)?.map((t) => t as String).toList() ?? const [],
        createdAt: DateTime.parse(requireField<String>(map, 'createdAt', 'Spell')),
        updatedAt: DateTime.parse(requireField<String>(map, 'updatedAt', 'Spell')),
      );
}
```

`...provenance.toMap()` spreads `Provenance`'s flat `source`/`citations` keys directly into `Spell`'s own map — the on-disk JSON shape for `spell_library.json` is byte-for-byte unchanged from before this task. `Provenance.fromMap(map)` reads those same keys back out of `Spell`'s own map — `Provenance` doesn't need its own nested sub-map; it operates on whatever flat map it's handed.

Now update `SpellDraft.toSpell` (leave the rest of `SpellDraft` — `technique`/`form`/`baseEffect`/`range`/`duration`/`target`/`selectedModifiers`/`requisites`/`summary`/`description`/`copyWith` — untouched):

```dart
  Spell toSpell({required String name, required PublicationSource source}) {
    final missingFields = <String>[
      if (baseEffect == null) 'baseEffect',
      if (range == null) 'range',
      if (duration == null) 'duration',
      if (target == null) 'target',
    ];
    if (missingFields.isNotEmpty) {
      throw StateError(
        'Cannot convert SpellDraft to Spell: ${missingFields.join(', ')} '
        '${missingFields.length == 1 ? 'is' : 'are'} not set',
      );
    }

    final problems = validateSpellProse(source: source, summary: summary, description: description);
    if (problems.isNotEmpty) {
      throw StateError('Cannot convert SpellDraft to Spell: ${problems.join('; ')}');
    }

    return Spell(
      id: id,
      name: name,
      baseEffectId: baseEffect!.id,
      rangeId: range!.id,
      durationId: duration!.id,
      targetId: target!.id,
      selectedModifiers: selectedModifiers,
      requisites: requisites,
      summary: summary,
      description: description,
      provenance: Provenance(source: source),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
```

- [ ] **Step 9: Update `ResolvedSpell`**

In `lib/models/resolved_spell.dart`, replace the import and the delegating getters:

```dart
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/spell.dart';
```

```dart
  String get id => record.id;
  String? get name => record.name;
  String? get summary => record.summary;
  String? get description => record.description;
  PublicationSource get source => record.provenance.source;
  List<Citation> get citations => record.provenance.citations;
  List<String> get tags => record.tags;
  DateTime get createdAt => record.createdAt;
  DateTime get updatedAt => record.updatedAt;
  Map<String, List<String>> get selectedModifiers => record.selectedModifiers;
  List<Requisite> get requisites => record.requisites;
```

Only the getter bodies change (`record.source`/`record.citations` → `record.provenance.source`/`record.provenance.citations`); `isResolved` and `unresolvedReferences` are untouched.

- [ ] **Step 10: Update `local_spell_datasource.dart`**

In `lib/data/datasources/local_spell_datasource.dart` line 42:

```dart
        'source': spell.provenance.source.wireValue,
```

- [ ] **Step 11: Update `spell_library_state.dart`**

In `lib/bloc/spell_library/spell_library_state.dart`, replace the import and the two comparisons:

```dart
import 'package:eruditus/models/publication_source.dart';
```

```dart
    if (filter == 'Published') {
      result = result.where((s) => s.source == PublicationSource.published).toList();
    } else if (filter == 'My Spells') {
      result = result.where((s) => s.source == PublicationSource.userCreated).toList();
    }
```

- [ ] **Step 12: Update `spell_card.dart`**

In `lib/presentation/widgets/spell_card.dart`, replace the import and the badge line:

```dart
import 'package:eruditus/models/publication_source.dart';
```

```dart
        trailing: Chip(
            label: Text(
                spell.source == PublicationSource.published ? 'Published' : 'My Spell')),
```

- [ ] **Step 13: Update `spell_creation_bloc.dart`**

In `lib/bloc/spell_creation/spell_creation_bloc.dart` line 11, replace the import:

```dart
import 'package:eruditus/models/publication_source.dart';
```

And line 192:

```dart
      final spell = state.draft.toSpell(name: event.name, source: PublicationSource.userCreated);
```

- [ ] **Step 14: Update `library_repository.dart`**

`filterBySource`'s parameter type changes from `SpellSource` to `PublicationSource`:

```dart
  Future<List<ResolvedSpell>> filterBySource(PublicationSource source) async {
    final all = await getAllSpells();
    return all.where((s) => s.source == source).toList();
  }
```

Update the file's import accordingly.

- [ ] **Step 15: Fix every fixture file**

Run `flutter analyze` and work through the errors. Every file that constructs `Spell(source: SpellSource.x, ...)` needs two changes:

1. `import 'package:eruditus/models/spell_source.dart';` → `import 'package:eruditus/models/publication_source.dart';` (add `import 'package:eruditus/models/provenance.dart';` too).
2. `source: SpellSource.published, citations: [...]` → `provenance: Provenance(source: PublicationSource.published, citations: [...])`, or `source: SpellSource.userCreated` → `provenance: Provenance(source: PublicationSource.userCreated)`.

The files needing this: `integration_test/spell_creation_flow_test.dart`, `test/bloc/spell_creation_bloc_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/data/datasources/local_spell_datasource_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/data/repositories/spell_repository_test.dart`, `test/data/services/backup_service_test.dart`, `test/data/spell_resolver_test.dart`, `test/engine/spell_engine_test.dart`, `test/models/resolved_spell_test.dart`, `test/models/spell_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/presentation/widgets/spell_card_test.dart`.

In `test/models/spell_test.dart` specifically: find the `group('spell field invariants', ...)` block (added in a prior plan). Its citation-invariant tests (`'a published spell with no citations is rejected'`, `'a user-created spell carrying citations is rejected'`, `'an unknown source value is rejected rather than defaulted'`) now describe `Provenance`'s behavior, not `Spell`'s — move them (or equivalent versions) into `test/models/provenance_test.dart` if they're not already covered by Step 4's tests, and simplify this group in `spell_test.dart` to cover only the summary-or-description rule via `validateSpellProse`, since that's the only invariant `Spell` itself still owns directly.

- [ ] **Step 16: Update `asset_data_loader_test.dart`'s existing `SpellSource` references**

Change the import from `spell_source.dart` to `publication_source.dart`. Update every `s.source == SpellSource.published` → `s.source == PublicationSource.published` (these are calls on `Spell` instances returned by `loader.loadSpellLibrary()` — recall `Spell` no longer has a flat `.source` getter, so these become `s.provenance.source == PublicationSource.published`). Similarly `spell.source`/`spell.citations` in the citation-guard test become `spell.provenance.source`/`spell.provenance.citations`.

- [ ] **Step 17: Run the unit suite**

Run: `flutter test`
Expected: `All tests passed!` — 239 tests (same count; this task is a pure refactor, no new asset data, and the invariant tests just moved files, not multiplied).

- [ ] **Step 18: Run the integration suite**

This task touches `spell_creation_bloc.dart`, `spell_library_state.dart`, and `spell_card.dart` — all part of the widget tree.

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: `All tests passed!` — 4 tests.

- [ ] **Step 19: Commit**

```bash
git add lib test integration_test
git commit -m "refactor: extract Provenance and flip Spell to use it"
```

---

### Task 2: Apply `Provenance` to `BaseEffect`; migrate citations for all 604 entries

**Files:**
- Modify: `lib/models/base_effect.dart`, `lib/presentation/screens/configuration_screen.dart`, `lib/data/services/backup_service.dart`, `assets/data/base_effects.json`
- Test: `test/bloc/configuration_bloc_test.dart`, `test/bloc/spell_creation_bloc_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/data/datasources/local_configuration_datasource_test.dart`, `test/data/repositories/configuration_repository_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/data/services/backup_service_test.dart`, `test/data/spell_resolver_test.dart`, `test/engine/spell_engine_test.dart`, `test/models/base_effect_test.dart`, `test/models/resolved_spell_test.dart`, `test/models/spell_draft_copy_with_test.dart`, `test/models/spell_test.dart`, `test/presentation/screens/configuration_screen_test.dart`, `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/presentation/widgets/spell_card_test.dart`, `integration_test/spell_creation_flow_test.dart`

**Interfaces:**
- Consumes: `Provenance`/`PublicationSource` from Task 1.
- Produces: `BaseEffect.provenance` (type `Provenance`) replaces `BaseEffect.source` (was `String`).

- [ ] **Step 1: Migrate `base_effects.json` — add citations to all 604 entries**

This must run before the model change, so the file below still loads under the *old* `BaseEffect.fromMap` (which only requires `source`) — this script only adds a key, it doesn't require `Provenance` to exist yet.

```bash
python - <<'PY'
import json, pathlib
p = pathlib.Path('assets/data/base_effects.json')
effects = json.loads(p.read_text(encoding='utf-8'))
n = 0
for e in effects:
    if e.get('source') == 'published' and 'citations' not in e:
        e['citations'] = [{'bookId': 'arm5-core'}]
        n += 1
p.write_text(json.dumps(effects, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print('added citations to', n, 'entries')
PY
```

Expected output: `added citations to 604 entries`.

- [ ] **Step 2: Run the suite to confirm the additive migration alone doesn't break anything**

Run: `flutter test`
Expected: `All tests passed!` — 239 tests. `BaseEffect.fromMap` doesn't read `citations` yet, so this step is purely a safety check that the JSON is still well-formed.

- [ ] **Step 3: Write the failing `BaseEffect` provenance test**

Append to `test/models/base_effect_test.dart` (read the file first to match its existing fixture-construction style and add the necessary imports: `package:eruditus/models/provenance.dart`, `package:eruditus/models/publication_source.dart`):

```dart
  test('a published effect needs at least one citation', () {
    expect(
      () => BaseEffect(
        id: 'x', technique: 'Creo', form: 'Ignem', description: 'x', baseLevel: 5,
        provenance: Provenance(source: PublicationSource.published),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('round-trips a published effect with a citation', () {
    final effect = BaseEffect(
      id: 'x', technique: 'Creo', form: 'Ignem', description: 'x', baseLevel: 5,
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
    );
    final restored = BaseEffect.fromMap(effect.toMap());
    expect(restored.provenance.source, PublicationSource.published);
    expect(restored.provenance.citations, [const Citation(bookId: 'arm5-core')]);
  });

  test('a user-created effect needs no citation', () {
    final effect = BaseEffect(
      id: 'x', technique: 'Creo', form: 'Ignem', description: 'x', baseLevel: 5,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    expect(effect.provenance.citations, isEmpty);
  });
```

Add `import 'package:eruditus/models/citation.dart';` if not already present.

- [ ] **Step 4: Run it to verify it fails**

Run: `flutter test test/models/base_effect_test.dart`
Expected: FAIL — `BaseEffect` has no `provenance` parameter yet.

- [ ] **Step 5: Rewrite `BaseEffect`**

Replace `lib/models/base_effect.dart` in full:

```dart
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/utils/map_serialization.dart';

class BaseEffect {
  final String id;
  final String technique;
  final String form;
  final String description;
  final int baseLevel;
  final Provenance provenance;

  BaseEffect({
    required this.id,
    required this.technique,
    required this.form,
    required this.description,
    required this.baseLevel,
    required this.provenance,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'technique': technique,
    'form': form,
    'description': description,
    'baseLevel': baseLevel,
    ...provenance.toMap(),
  };

  factory BaseEffect.fromMap(Map<String, dynamic> map) => BaseEffect(
    id: requireField<String>(map, 'id', 'BaseEffect'),
    technique: requireField<String>(map, 'technique', 'BaseEffect'),
    form: requireField<String>(map, 'form', 'BaseEffect'),
    description: requireField<String>(map, 'description', 'BaseEffect'),
    baseLevel: requireField<int>(map, 'baseLevel', 'BaseEffect'),
    provenance: Provenance.fromMap(map),
  );

  // Value equality by id. Effects are re-parsed from JSON/DB on every
  // ConfigurationRepository fetch (see AssetDataLoader), so a freshly loaded
  // instance is never `identical()` to one already held e.g. in a
  // SpellDraft.baseEffect. Without this, a DropdownButtonFormField whose
  // `items` are rebuilt from a reloaded list (as happens whenever
  // ConfigurationBloc reloads after a Settings-tab edit) would no longer
  // recognize a previously selected value as present in the new list.
  @override
  bool operator ==(Object other) => identical(this, other) || (other is BaseEffect && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 6: Run it to verify it passes**

Run: `flutter test test/models/base_effect_test.dart`
Expected: PASS.

- [ ] **Step 7: Update `configuration_screen.dart`'s effect tab**

In `lib/presentation/screens/configuration_screen.dart`, add the imports:

```dart
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
```

Change the effects-tab comparison (line 76):

```dart
          final isCustom = e.provenance.source == PublicationSource.userCreated;
```

Change the "Add Custom Effect" construction (around line 161):

```dart
            Navigator.of(context).pop(BaseEffect(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              technique: _technique!,
              form: _form!,
              description: _descriptionController.text,
              baseLevel: level,
              provenance: Provenance(source: PublicationSource.userCreated),
            ));
```

- [ ] **Step 8: Update `backup_service.dart`'s effect filter**

In `lib/data/services/backup_service.dart`, add the import `package:eruditus/models/publication_source.dart` and change line 32:

```dart
        (await configRepository.getAllEffects())
            .where((e) => e.provenance.source == PublicationSource.userCreated)
            .toList();
```

- [ ] **Step 9: Fix every fixture file**

Run `flutter analyze`. Every file constructing `BaseEffect(source: 'published', ...)` or `BaseEffect(source: 'user-created', ...)` needs `source: 'x'` replaced with `provenance: Provenance(source: PublicationSource.x, citations: [...])` (citations only for published), plus the corresponding imports. Files: `test/bloc/configuration_bloc_test.dart`, `test/bloc/spell_creation_bloc_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/data/datasources/local_configuration_datasource_test.dart`, `test/data/repositories/configuration_repository_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/data/services/backup_service_test.dart`, `test/data/spell_resolver_test.dart`, `test/engine/spell_engine_test.dart`, `test/models/resolved_spell_test.dart`, `test/models/spell_draft_copy_with_test.dart`, `test/models/spell_test.dart`, `test/presentation/screens/configuration_screen_test.dart`, `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/presentation/widgets/spell_card_test.dart`, `integration_test/spell_creation_flow_test.dart`.

Most `BaseEffect` test fixtures represent user-created or ad-hoc test data — use `PublicationSource.userCreated` with no citations for those, exactly as the prior plan's guidance put it: "only use `published` where the test is actually about published entries." Where a fixture specifically stands in for a real catalog entry (rare outside asset-loading tests), use `published` with a citation.

- [ ] **Step 10: Extend the citation-resolution asset test**

In `test/data/datasources/asset_data_loader_test.dart`, extend the existing `"every spell's cited book ids exist in the books catalog"` test (or add a sibling test right after it) to also check `BaseEffect`:

```dart
  test("every base effect's cited book ids exist in the books catalog", () async {
    final effects = await loader.loadBaseEffects();
    final books = await loader.loadBooks();
    final bookIds = books.map((b) => b.id).toSet();

    for (final effect in effects) {
      for (final citation in effect.provenance.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${effect.id}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });
```

Also update the existing `'loadBaseEffects loads every built-in base effect in the asset file'` test's `e.source == 'published'` check (it currently compares a raw string, which no longer exists on `BaseEffect`) — change to:

```dart
    expect(effects.every((e) => e.provenance.source == PublicationSource.published), isTrue);
```

Add the `import 'package:eruditus/models/publication_source.dart';` if not already present in this file from Task 1.

- [ ] **Step 11: Run the unit suite**

Run: `flutter test`
Expected: `All tests passed!` — 243 tests (239 from Task 1, + 3 new `BaseEffect` tests from Step 3, + 1 new citation-resolution test from Step 10; Step 9's fixture fixes modify existing tests and add none).

- [ ] **Step 12: Run the integration suite**

This task touches `configuration_screen.dart`, part of the widget tree, and `backup_service.dart`.

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: `All tests passed!` — 4 tests.

- [ ] **Step 13: Commit**

```bash
git add lib test integration_test assets/data/base_effects.json
git commit -m "feat: apply Provenance to BaseEffect and cite all 604 built-in entries"
```

---

### Task 3: Apply `Provenance` to `Parameter`; add 8 new parameters; rename Boundary; add demonstration spell

**Files:**
- Modify: `lib/models/parameter.dart`, `lib/presentation/screens/configuration_screen.dart`, `assets/data/parameters.json`, `assets/data/spell_library.json`
- Test: `test/bloc/spell_creation_bloc_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/data/datasources/local_configuration_datasource_test.dart`, `test/data/repositories/configuration_repository_test.dart`, `test/data/spell_resolver_test.dart`, `test/engine/spell_engine_test.dart`, `test/models/parameter_test.dart`, `test/models/resolved_spell_test.dart`, `test/models/spell_test.dart`, `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/presentation/widgets/spell_card_test.dart`, `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: `Provenance`/`PublicationSource` from Task 1.
- Produces: `Parameter.provenance` (type `Provenance`) replaces `Parameter.source` (was `String`).

- [ ] **Step 1: Add the 8 new parameters and rename Boundary**

Replace `assets/data/parameters.json` in full:

```json
[
  {"id": "range-personal", "name": "Personal", "category": "Range", "magnitude": 0, "source": "published"},
  {"id": "range-touch", "name": "Touch", "category": "Range", "magnitude": 1, "source": "published"},
  {"id": "range-eye", "name": "Eye", "category": "Range", "magnitude": 1, "source": "published"},
  {"id": "range-voice", "name": "Voice", "category": "Range", "magnitude": 2, "source": "published"},
  {"id": "range-sight", "name": "Sight", "category": "Range", "magnitude": 3, "source": "published"},
  {"id": "range-arcane-connection", "name": "Arcane Connection", "category": "Range", "magnitude": 4, "source": "published"},
  {"id": "duration-momentary", "name": "Momentary", "category": "Duration", "magnitude": 0, "source": "published"},
  {"id": "duration-diameter", "name": "Diameter", "category": "Duration", "magnitude": 1, "source": "published"},
  {"id": "duration-concentration", "name": "Concentration", "category": "Duration", "magnitude": 1, "source": "published"},
  {"id": "duration-sun", "name": "Sun", "category": "Duration", "magnitude": 2, "source": "published"},
  {"id": "duration-ring", "name": "Ring", "category": "Duration", "magnitude": 2, "source": "published"},
  {"id": "duration-moon", "name": "Moon", "category": "Duration", "magnitude": 3, "source": "published"},
  {"id": "duration-year", "name": "Year", "category": "Duration", "magnitude": 4, "source": "published"},
  {"id": "target-individual", "name": "Individual", "category": "Target", "magnitude": 0, "source": "published"},
  {"id": "target-circle", "name": "Circle", "category": "Target", "magnitude": 0, "source": "published"},
  {"id": "target-taste", "name": "Taste", "category": "Target", "magnitude": 0, "source": "published"},
  {"id": "target-part", "name": "Part", "category": "Target", "magnitude": 1, "source": "published"},
  {"id": "target-touch", "name": "Touch", "category": "Target", "magnitude": 1, "source": "published"},
  {"id": "target-group", "name": "Group", "category": "Target", "magnitude": 2, "source": "published"},
  {"id": "target-room", "name": "Room", "category": "Target", "magnitude": 2, "source": "published"},
  {"id": "target-smell", "name": "Smell", "category": "Target", "magnitude": 2, "source": "published"},
  {"id": "target-structure", "name": "Structure", "category": "Target", "magnitude": 3, "source": "published"},
  {"id": "target-hearing", "name": "Hearing", "category": "Target", "magnitude": 3, "source": "published"},
  {"id": "target-vision", "name": "Vision", "category": "Target", "magnitude": 4, "source": "published"},
  {"id": "target-boundary", "name": "Boundary", "category": "Target", "magnitude": 4, "source": "published"}
]
```

This is the Boundary rename (`target-bound`/`"Bound"` → `target-boundary`/`"Boundary"`) combined with the 8 new entries, inserted in magnitude order within each category to match the file's existing convention. 25 entries total.

- [ ] **Step 2: Add citations to all 25 parameters**

```bash
python - <<'PY'
import json, pathlib
p = pathlib.Path('assets/data/parameters.json')
params = json.loads(p.read_text(encoding='utf-8'))
n = 0
for x in params:
    if x.get('source') == 'published' and 'citations' not in x:
        x['citations'] = [{'bookId': 'arm5-core'}]
        n += 1
p.write_text(json.dumps(params, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print('added citations to', n, 'entries')
PY
```

Expected output: `added citations to 25 entries`.

- [ ] **Step 3: Run the suite to confirm the JSON is still well-formed**

Run: `flutter test`
Expected: FAIL — the existing `'loadParameters loads all 17 built-in parameters'` test now sees 25. This is expected; Step 9 fixes it.

- [ ] **Step 4: Write the failing `Parameter` provenance test**

Append to `test/models/parameter_test.dart` (add imports for `Provenance`, `PublicationSource`, `Citation`):

```dart
  test('a published parameter needs at least one citation', () {
    expect(
      () => Parameter(
        id: 'x', name: 'X', category: 'Range', magnitude: 1,
        provenance: Provenance(source: PublicationSource.published),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('round-trips a published parameter with a citation', () {
    final parameter = Parameter(
      id: 'x', name: 'X', category: 'Range', magnitude: 1,
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
    );
    final restored = Parameter.fromMap(parameter.toMap());
    expect(restored.provenance.source, PublicationSource.published);
    expect(restored.provenance.citations, [const Citation(bookId: 'arm5-core')]);
  });
```

- [ ] **Step 5: Run it to verify it fails**

Run: `flutter test test/models/parameter_test.dart`
Expected: FAIL — `Parameter` has no `provenance` parameter yet.

- [ ] **Step 6: Rewrite `Parameter`**

Replace `lib/models/parameter.dart` in full:

```dart
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/utils/map_serialization.dart';

class Parameter {
  final String id;
  final String name;
  final String category; // "Range", "Duration", "Target", or custom
  final int magnitude;
  final Provenance provenance;

  Parameter({
    required this.id,
    required this.name,
    required this.category,
    required this.magnitude,
    required this.provenance,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'magnitude': magnitude,
    ...provenance.toMap(),
  };

  factory Parameter.fromMap(Map<String, dynamic> map) => Parameter(
    id: requireField<String>(map, 'id', 'Parameter'),
    name: requireField<String>(map, 'name', 'Parameter'),
    category: requireField<String>(map, 'category', 'Parameter'),
    magnitude: requireField<int>(map, 'magnitude', 'Parameter'),
    provenance: Provenance.fromMap(map),
  );

  // Value equality by id — see BaseEffect for why this matters (reloaded
  // ConfigurationBloc state produces fresh, non-identical instances).
  @override
  bool operator ==(Object other) => identical(this, other) || (other is Parameter && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 7: Run it to verify it passes**

Run: `flutter test test/models/parameter_test.dart`
Expected: PASS.

- [ ] **Step 8: Update `configuration_screen.dart`'s parameter tab**

In `lib/presentation/screens/configuration_screen.dart` (imports already added in Task 2), change the parameters-tab comparison (line 189):

```dart
          final isCustom = p.provenance.source == PublicationSource.userCreated;
```

Change the "Add Custom Parameter" construction (around line 265):

```dart
            Navigator.of(context).pop(Parameter(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text,
              category: _category!,
              magnitude: magnitude,
              provenance: Provenance(source: PublicationSource.userCreated),
            ));
```

- [ ] **Step 9: Update `backup_service.dart`'s parameter filter**

In `lib/data/services/backup_service.dart` line 34:

```dart
        (await configRepository.getAllParameters())
            .where((p) => p.provenance.source == PublicationSource.userCreated)
            .toList();
```

- [ ] **Step 10: Fix every fixture file, and the parameter count**

Run `flutter analyze`. Every file constructing `Parameter(source: 'x', ...)` needs the same `provenance: Provenance(...)` change as `BaseEffect` did in Task 2. Files: `test/bloc/spell_creation_bloc_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/data/datasources/local_configuration_datasource_test.dart`, `test/data/repositories/configuration_repository_test.dart`, `test/data/spell_resolver_test.dart`, `test/engine/spell_engine_test.dart`, `test/models/resolved_spell_test.dart`, `test/models/spell_test.dart`, `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/presentation/widgets/spell_card_test.dart`.

In `test/data/datasources/asset_data_loader_test.dart`, update the `'loadParameters loads all 17 built-in parameters'` test:

```dart
  test('loadParameters loads all 25 built-in parameters', () async {
    final parameters = await loader.loadParameters();

    expect(parameters.length, 25);
    expect(
      parameters.any((p) => p.name == 'Eye' && p.category == 'Range' && p.magnitude == 1),
      isTrue,
    );
    expect(
      parameters.any((p) => p.name == 'Boundary' && p.category == 'Target' && p.magnitude == 4),
      isTrue,
    );
    expect(parameters.any((p) => p.name == 'Bound'), isFalse,
        reason: 'Bound was a data error; the rulebook name is Boundary');
  });
```

This is kept as a literal count (`25`), matching the existing precedent for this small, hand-curated list.

- [ ] **Step 11: Add the demonstration spell**

`ireem-5b` (`"Understand the meaning behind spoken sounds"`, Intellego Mentem, base level 5) already exists in `base_effects.json`. This is the real ArM5 core rulebook spell **"Thoughts Within Babble"** (Level 25, Intellego Mentem, R: Personal, D: Concentration, T: Hearing; Base 5, +1 Concentration, +3 Hearing = 5 + 5 + 15 = 25 — verified against the guideline math).

Append to the array in `assets/data/spell_library.json` (comma after the previous last entry):

```json
  {
    "id": "lib-inme-thoughts-within-babble",
    "name": "Thoughts Within Babble",
    "requisites": [],
    "source": "published",
    "createdAt": "2026-01-01T00:00:00.000",
    "updatedAt": "2026-01-01T00:00:00.000",
    "selectedModifiers": {},
    "baseEffectId": "ireem-5b",
    "rangeId": "range-personal",
    "durationId": "duration-concentration",
    "targetId": "target-hearing",
    "summary": "You can understand the speech of those within range, even those who misuse a language you know — you hear both what they meant and what they actually said. Level 25.",
    "citations": [{"bookId": "arm5-core"}]
  }
```

- [ ] **Step 12: Run the citation-resolution and level-calculation asset tests directly**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: PASS, including `'every loaded spell calculates to the level stated in its description'` for the new spell (level 25) and `"every spell's referenced ids exist in the built-in catalogs"` (confirms `target-hearing` resolves).

If the level check fails, recompute by hand: `SpellLevelCalculator.calculate(baseLevel: 5, magnitudes: [1 /* Concentration */, 3 /* Hearing */])` should equal 25 — fix the `summary`'s stated level or the parameter ids, whichever is wrong, rather than the calculator.

- [ ] **Step 13: Extend the citation-resolution asset test for `Parameter`**

In `test/data/datasources/asset_data_loader_test.dart`, add a sibling to Task 2's `BaseEffect` citation test:

```dart
  test("every parameter's cited book ids exist in the books catalog", () async {
    final parameters = await loader.loadParameters();
    final books = await loader.loadBooks();
    final bookIds = books.map((b) => b.id).toSet();

    for (final parameter in parameters) {
      for (final citation in parameter.provenance.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${parameter.id}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });
```

- [ ] **Step 14: Run the full unit suite**

Run: `flutter test`
Expected: `All tests passed!` — 246 tests (243 from Task 2, + 2 new `Parameter` tests from Step 4, + 1 new citation-resolution test from Step 13; the rewritten parameter-count test replaces the old one at net 0, and the new spell is exercised by the existing loop-based asset tests rather than adding one).

- [ ] **Step 15: Run the integration suite**

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: `All tests passed!` — 4 tests.

- [ ] **Step 16: Commit**

```bash
git add lib test assets/data/parameters.json assets/data/spell_library.json
git commit -m "feat: add 8 core parameters, rename Boundary, apply Provenance to Parameter"
```

---

### Task 4: Apply `Provenance` to `Modifier`; migrate citations for all 17 entries

**Files:**
- Modify: `lib/models/modifier.dart`, `assets/data/modifiers.json`
- Test: `test/bloc/spell_creation_bloc_test.dart`, `test/data/datasources/local_configuration_datasource_test.dart`, `test/data/repositories/configuration_repository_test.dart`, `test/engine/spell_engine_test.dart`, `test/models/modifier_test.dart`, `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`, `test/presentation/widgets/modifiers_section_test.dart`, `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: `Provenance`/`PublicationSource` from Task 1.
- Produces: `Modifier.provenance` (type `Provenance`) replaces `Modifier.source` (was `String`).

`Modifier` has no direct construction site in `configuration_screen.dart` (custom modifiers are added elsewhere in the UI, not through that screen) — confirm this by grepping `Modifier(` in `lib/` before starting; if a construction site exists it needs the same `provenance:` treatment as `BaseEffect`/`Parameter` did.

- [ ] **Step 1: Add citations to all 17 modifiers**

```bash
python - <<'PY'
import json, pathlib
p = pathlib.Path('assets/data/modifiers.json')
mods = json.loads(p.read_text(encoding='utf-8'))
n = 0
for m in mods:
    if m.get('source') == 'published' and 'citations' not in m:
        m['citations'] = [{'bookId': 'arm5-core'}]
        n += 1
p.write_text(json.dumps(mods, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print('added citations to', n, 'entries')
PY
```

Expected output: `added citations to 17 entries`.

- [ ] **Step 2: Run the suite to confirm the JSON is still well-formed**

Run: `flutter test`
Expected: `All tests passed!` — unchanged count. `Modifier.fromMap` doesn't read `citations` yet.

- [ ] **Step 3: Write the failing `Modifier` provenance test**

Append to `test/models/modifier_test.dart` (add imports for `Provenance`, `PublicationSource`, `Citation`; read the file first for its exact `ModifierScope`/`ModifierOption` fixture construction style):

```dart
  test('a published modifier needs at least one citation', () {
    expect(
      () => Modifier(
        id: 'x', name: 'X', selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(), options: const [],
        provenance: Provenance(source: PublicationSource.published),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('round-trips a published modifier with a citation', () {
    final modifier = Modifier(
      id: 'x', name: 'X', selectionMode: ModifierSelectionMode.single,
      scope: const ModifierScope(), options: const [],
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
    );
    final restored = Modifier.fromMap(modifier.toMap());
    expect(restored.provenance.source, PublicationSource.published);
    expect(restored.provenance.citations, [const Citation(bookId: 'arm5-core')]);
  });
```

- [ ] **Step 4: Run it to verify it fails**

Run: `flutter test test/models/modifier_test.dart`
Expected: FAIL — `Modifier` has no `provenance` parameter yet.

- [ ] **Step 5: Rewrite `Modifier`**

In `lib/models/modifier.dart`, add the import `package:eruditus/models/provenance.dart` and replace the `Modifier` class (leave `ModifierSelectionMode`, `_selectionModeFromName`, `ModifierOption`, and `ModifierScope` untouched):

```dart
/// A named set of magnitude-costing options offered for a scoped set of spells.
/// [selectionMode] decides whether the options are exclusive or cumulative.
class Modifier {
  final String id;
  final String name;
  final String? description;
  final ModifierSelectionMode selectionMode;
  final ModifierScope scope;
  final List<ModifierOption> options;
  final Provenance provenance;

  Modifier({
    required this.id,
    required this.name,
    this.description,
    required this.selectionMode,
    required this.scope,
    required this.options,
    required this.provenance,
  });

  ModifierOption? optionById(String optionId) {
    for (final option in options) {
      if (option.id == optionId) return option;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'selectionMode': selectionMode.name,
        'scope': scope.toMap(),
        'options': options.map((o) => o.toMap()).toList(),
        ...provenance.toMap(),
      };

  factory Modifier.fromMap(Map<String, dynamic> map) => Modifier(
        id: requireField<String>(map, 'id', 'Modifier'),
        name: requireField<String>(map, 'name', 'Modifier'),
        description: map['description'] as String?,
        selectionMode:
            _selectionModeFromName(requireField<String>(map, 'selectionMode', 'Modifier')),
        scope: ModifierScope.fromMap(
            requireField<Map<String, dynamic>>(map, 'scope', 'Modifier')),
        options: requireField<List>(map, 'options', 'Modifier')
            .map((o) => ModifierOption.fromMap(o as Map<String, dynamic>))
            .toList(),
        provenance: Provenance.fromMap(map),
      );

  // Value equality by id — see BaseEffect for why this matters (reloaded
  // ConfigurationBloc state produces fresh, non-identical instances).
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Modifier && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 6: Run it to verify it passes**

Run: `flutter test test/models/modifier_test.dart`
Expected: PASS.

- [ ] **Step 7: Fix every fixture file**

Run `flutter analyze`. Every file constructing `Modifier(source: 'x', ...)` needs `provenance: Provenance(...)`. Files: `test/bloc/spell_creation_bloc_test.dart`, `test/data/datasources/local_configuration_datasource_test.dart`, `test/data/repositories/configuration_repository_test.dart`, `test/engine/spell_engine_test.dart`, `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`, `test/presentation/widgets/modifiers_section_test.dart`.

In `test/data/datasources/asset_data_loader_test.dart`, update `'loadModifiers loads the built-in modifier definitions'`'s `m.source == 'published'` check:

```dart
    expect(modifiers.every((m) => m.provenance.source == PublicationSource.published), isTrue);
```

- [ ] **Step 8: Extend the citation-resolution asset test for `Modifier`**

Add a third sibling test in `test/data/datasources/asset_data_loader_test.dart`:

```dart
  test("every modifier's cited book ids exist in the books catalog", () async {
    final modifiers = await loader.loadModifiers();
    final books = await loader.loadBooks();
    final bookIds = books.map((b) => b.id).toSet();

    for (final modifier in modifiers) {
      for (final citation in modifier.provenance.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${modifier.id}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });
```

- [ ] **Step 9: Run the full unit suite**

Run: `flutter test`
Expected: `All tests passed!` — 249 tests (246 from Task 3, + 2 new `Modifier` tests from Step 3, + 1 new citation-resolution test from Step 8).

- [ ] **Step 10: Run the integration suite**

This task doesn't touch the widget tree directly, but re-run it as a final confirmation before the branch's whole-branch review.

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: `All tests passed!` — 4 tests.

- [ ] **Step 11: Commit**

```bash
git add lib test assets/data/modifiers.json
git commit -m "feat: apply Provenance to Modifier and cite all 17 built-in entries"
```

---

## Notes for the executor

- **Every commit must leave `flutter test` green.** No task in this plan is monolithic in the way a prior plan's model flip was — each of Tasks 2-4 stays compilable throughout because the JSON migration (adding a key) always runs before the model change (requiring that key), never after.
- **`flutter test` never runs `integration_test/`.** Re-run it after any task touching the widget tree (Tasks 1, 2, 3) or a repository/service (all four).
- **Do not run `flutter analyze` and `flutter test` concurrently** — they contend over `build/`.
- **`python3` is a broken Windows Store alias in this environment; use `python`.**
- **Do not add a ritual-only flag or a Virtue-gating field.** Both are real, both are deferred — see the Global Constraints.
- **Do not relax a citation asset test to tolerate a missing book.** If one ever fires, the data is wrong, not the check.
- **`BaseEffect`/`Parameter`/`Modifier`/`Spell` expose only `.provenance` — no flat delegating `source`/`citations` getter.** Only `ResolvedSpell` (a join/wrapper layer) keeps flat getters, delegating into `record.provenance`. Don't add flat getters to the four base models — that would recreate the two-parallel-representations problem `Provenance` was extracted to remove.
