# Requisites Map Reshape Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reshape `requisites` from `List<Requisite>` to `Map<String, RequisiteKind>` keyed by art, across every Dart model that carries it and the Python importer that emits it, so a duplicate requisite art becomes unrepresentable instead of validator-checked.

**Architecture:** This is todo item 40 Part B, from `docs/superpowers/specs/2026-08-09-spell-invariant-enforcement-design.md`'s "Scope" and "What part B drags with it" sections (Part A — the shared validator and its enforcement — is already merged, commits `a160855`..`d1acc12`). `Requisite` the class is deleted; `RequisiteKind` (already `{free, adding}`) survives and gains a `magnitude` extension getter to replace the deleted class's computed property. `validateSpellAgainstCatalog`'s duplicate-art check (check 4) is deleted — a map cannot hold two entries for the same key, so the invariant it enforced no longer needs enforcing. Everything else that read or wrote `List<Requisite>` moves to `Map<String, RequisiteKind>` in lockstep, because Dart's static typing means the whole call graph must agree in the same commit; there is no incremental migration path and, per project convention, none is wanted.

**Tech Stack:** Dart/Flutter (`lib/`, `test/`), Python 3 (`scripts/spell_import/`, `scripts/spell_import/tests/`).

## Global Constraints

- No migration story for already-serialized data: this is a prototype, the DB is droppable, and old-shape backups become unsupported rather than translated (project convention; see the design spec's decision 2 for the parallel case).
- Batching this work with todo items 35/37 was explicitly considered and rejected on 2026-08-09 (design spec decision 7). Do not fold in unrelated slots.
- Part A's validator checks 1, 2 and 5 (`spell.dart`'s `validateSpellAgainstCatalog`) are baseline and must not be re-touched beyond what the type change mechanically requires.
- The wire format for `requisites` goes from a JSON array `[{"art": "Rego", "kind": "adding"}]` to a JSON object `{"Rego": "adding"}`. `BackupService._supportedVersion` bumps `'2.0'` → `'3.0'` so an old-shape backup fails loudly (`FormatException: Unsupported backup version`) instead of parsing wrong.
- `scripts/spell_import/emit.py`'s duplicate-art guard must become `dict.setdefault`, never plain assignment — an earlier `adding` requisite must not be silently overwritten by a later `free` one naming the same art (design spec, "What part B drags with it").
- `source.lock`'s pinned rulebook revision does not change — this task changes code shape, not rulebook content. Asset regeneration uses `--write` alone; reach for `--accept-source` only if the run unexpectedly reports a source mismatch, and treat that as a signal to stop and investigate rather than a flag to add reflexively.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/requisite.dart` | `RequisiteKind` enum + its `magnitude` extension; shared `requisitesToMap`/`requisitesFromMap` (de)serialization used by both `Spell` and `SpellTemplate`. `Requisite` the class is deleted. |
| `lib/models/spell.dart` | `validateSpellAgainstCatalog`'s checks 3/4 collapse to a map-keyed self-match check; `Spell`/`SpellDraft` fields, `toMap`/`fromMap`, `copyWith`. |
| `lib/models/spell_template.dart` | `SpellTemplate.requisites` field, `toMap`/`fromMap`. |
| `lib/models/resolved_spell.dart`, `lib/models/resolved_template.dart` | Pass-through `requisites` getters; type follows the underlying record. |
| `lib/engine/spell_engine.dart` | `calculateBreakdown`/`calculateSpellLevel`'s `requisites` parameter and the per-requisite `LevelContribution` loop. |
| `lib/bloc/spell_creation/spell_creation_bloc.dart` | `RequisiteAdded`/`RequisiteRemoved`/`RequisiteKindChanged` handlers, rewritten as direct map operations. |
| `lib/presentation/screens/spell_creation_screen.dart` | `_buildRequisitesSection` renders `draft.requisites.entries` instead of a list. |
| `lib/data/services/backup_service.dart` | `_supportedVersion` bump. |
| `scripts/spell_import/emit.py` | `build_spell`/`build_template`'s requisites building, list-of-dicts → dict via `setdefault`. |
| `assets/data/spell_library.json`, `assets/data/spell_templates.json` | Regenerated with the new wire shape. |
| Every test file listed in Task 1 | Updated literals; a handful get real logic changes (see Task 1 step-by-step). |

---

### Task 1: The Dart reshape — models, engine, bloc, screen, backup version

**Files:**
- Modify: `lib/models/requisite.dart`
- Modify: `lib/models/spell.dart`
- Modify: `lib/models/spell_template.dart`
- Modify: `lib/models/resolved_spell.dart`
- Modify: `lib/models/resolved_template.dart`
- Modify: `lib/engine/spell_engine.dart`
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart`
- Modify: `lib/presentation/screens/spell_creation_screen.dart`
- Modify: `lib/data/services/backup_service.dart`
- Modify (full rewrite): `test/models/requisite_test.dart`
- Modify: `test/models/spell_test.dart`
- Modify: `test/engine/spell_engine_test.dart`
- Modify: `test/bloc/spell_creation_bloc_test.dart`
- Modify: `test/presentation/screens/spell_creation_screen_test.dart`
- Modify: `test/data/services/backup_service_test.dart`
- Modify (mechanical, see step 10): `test/presentation/widgets/spell_card_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/data/spell_resolver_test.dart`, `test/engine/ritual_status_test.dart`, `test/presentation/screens/backup_screen_test.dart`, `test/models/resolved_spell_test.dart`, `test/engine/general_effect_test.dart`, `test/data/repositories/spell_repository_test.dart`, `test/data/datasources/local_spell_datasource_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/data/datasources/asset_data_loader_test.dart`, `test/data/published_spell_import_test.dart`

**Interfaces:**
- Consumes: nothing outside this task — this is the whole reshape, done together because Dart requires the type to agree everywhere it is used simultaneously.
- Produces: `RequisiteKind` (unchanged enum), `RequisiteKind.magnitude` (new extension getter), `requisitesToMap`/`requisitesFromMap` (new free functions in `requisite.dart`), `Spell.requisites` / `SpellDraft.requisites` / `SpellTemplate.requisites` / `ResolvedSpell.requisites` / `ResolvedTemplate.requisites` all typed `Map<String, RequisiteKind>`. Task 2 (the Python importer) does not consume any of this — it only has to agree on the wire format, which this task fixes.

This task has 11 steps. Steps 1–8 change `lib/`; steps 9 rewrites the tests whose *logic* changes (not just literal shape); step 10 sweeps the remaining test files mechanically; step 11 verifies and commits. Because the whole type flips at once, `flutter analyze`/`flutter test` will not be green until step 10 is done — that is expected for a reshape this wide, and mirrors how Part A's multi-file tasks worked. Commit once, at the end (step 11), not after each sub-step — an intermediate commit here would not compile.

- [ ] **Step 1: `lib/models/requisite.dart` — delete `Requisite`, add the magnitude extension and shared (de)serialization**

Replace the file's contents entirely:

```dart
/// Whether a requisite contributes to the spell's level.
///
/// A `free` requisite is demanded by the spell's nature but is incidental
/// enough that it costs nothing (the classic example being a Corpus requisite
/// on a spell that moves a person's clothing along with them). An `adding`
/// requisite is significant enough to make the effect harder, and costs one
/// magnitude.
enum RequisiteKind { free, adding }

/// The level-magnitude [RequisiteKind] costs: 1 for [RequisiteKind.adding],
/// 0 for [RequisiteKind.free].
extension RequisiteKindMagnitude on RequisiteKind {
  int get magnitude => this == RequisiteKind.adding ? 1 : 0;
}

/// Resolves a requisite kind's wire name back to the enum value, with the
/// same clear-error convention as [ritualDeclarationFromName].
RequisiteKind requisiteKindFromName(String name, String className) {
  for (final value in RequisiteKind.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown requisite kind '$name' (expected one of: "
    "${RequisiteKind.values.map((k) => k.name).join(', ')})",
  );
}

/// Serializes a requisites map to its wire shape, e.g. `{"Rego": "adding"}`.
///
/// Shared by [Spell] and [SpellTemplate] so the two paths cannot drift, the
/// same reason [validateSpellProse] is shared between them.
Map<String, String> requisitesToMap(Map<String, RequisiteKind> requisites) =>
    requisites.map((art, kind) => MapEntry(art, kind.name));

/// Parses the wire shape back, keyed by art. A missing `requisites` key
/// ([map] is `null`) yields an empty map, matching every other optional
/// collection field's default.
Map<String, RequisiteKind> requisitesFromMap(
  Map<String, dynamic>? map,
  String className,
) {
  if (map == null) return const {};
  return map.map((art, kindValue) {
    if (kindValue is! String) {
      throw FormatException("$className.fromMap: requisite '$art' has no kind");
    }
    return MapEntry(art, requisiteKindFromName(kindValue, className));
  });
}
```

`ritualDeclarationFromName` (in `lib/models/ritual_declaration.dart`) already establishes this exact pattern — a free function named `<enum>FromName`, taking the raw name and the calling class's name for the error message. `requisiteKindFromName` mirrors it. The old `Requisite` class's `toMap`/`fromMap` were instance methods; since the class is gone, module-level functions are their natural replacement, the same way `ritualDeclarationFromName` sits beside `RitualDeclaration` rather than on a deleted wrapper class.

The `import 'package:eruditus/utils/map_serialization.dart';` line is gone — `requireField` was only used by the deleted `Requisite.fromMap`, and nothing here needs it.

- [ ] **Step 2: `lib/models/spell.dart` — the validator, `Spell`, `SpellDraft`**

Update the doc comment above `validateSpellAgainstCatalog` (currently reads, in part, "Check 3 (self-matching requisite arts) is suppressed for any art already flagged as a duplicate by check 4; see the checks-3/4 implementation for detail.") — delete that sentence. There is no duplicate suppression left to describe; a map cannot hold a duplicate key.

Change the signature's `requisites` parameter:

```dart
List<String> validateSpellAgainstCatalog({
  required BaseEffect effect,
  required int? chosenBaseLevel,
  required Map<String, RequisiteKind> requisites,
  required Map<String, List<String>> selectedModifiers,
  required List<Modifier> modifiers,
  bool isTemplate = false,
}) {
```

Replace the checks-3/4 block (the `seenArts`/`duplicateArts` two-pass loop) with:

```dart
  // 3. A requisite naming the spell's own Art is meaningless. Duplicate arts
  //    cannot occur here — requisites is keyed by art, so a second requisite
  //    for the same art overwrites rather than duplicates. That was check 4;
  //    it is deleted, not merely unreachable, because the shape now makes it
  //    impossible rather than checked.
  for (final art in requisites.keys) {
    if (art == effect.technique || art == effect.form) {
      problems.add("Requisite art cannot be the spell's own technique or form");
    }
  }
```

Leave check 5 (the `selectedModifiers.forEach` block) untouched — it does not reference `requisites`.

Also update the class-level doc comment fragment: "Reconciling against the problem table: of the four invariants named there, three become checks 1, 3 and 4" and similar historical references to "check 4" elsewhere in this file's comments (search for `check 4` and `checks 3, 4`) — the design-spec table (in the spec, not this file) is the historical record; this file's comments should describe the code as it now stands, so drop or reword any live comment claiming a "check 4" still runs. Checks keep their original numbers 1, 2, 3, 5 (4 is retired, not renumbered) so nothing outside this file that names a check number by that convention goes stale.

`Spell`:

```dart
  final Map<String, RequisiteKind> requisites;
```

(constructor parameter unchanged in shape — `required this.requisites,`)

```dart
  Map<String, dynamic> toMap() => {
        ...
        'requisites': requisitesToMap(requisites),
        ...
      };

  factory Spell.fromMap(Map<String, dynamic> map) => Spell(
        ...
        requisites: requisitesFromMap(map['requisites'] as Map<String, dynamic>?, 'Spell'),
        ...
      );
```

`SpellDraft`:

```dart
  Map<String, RequisiteKind> requisites;

  SpellDraft({
    ...
    Map<String, RequisiteKind>? requisites,
    ...
  })  : id = id ?? _generateId(),
        selectedModifiers = selectedModifiers ?? {},
        requisites = requisites ?? {},
        adjustments = adjustments ?? [];
```

`copyWith`:

```dart
  SpellDraft copyWith({
    ...
    Map<String, RequisiteKind>? requisites,
    ...
  }) {
    return SpellDraft(
      ...
      requisites: requisites ?? this.requisites,
      ...
    );
  }
```

`toSpell()`'s `requisites: requisites,` line is unchanged text — the type now flows through automatically.

- [ ] **Step 3: `lib/models/spell_template.dart`**

```dart
  final Map<String, RequisiteKind> requisites;

  SpellTemplate({
    ...
    this.requisites = const {},
    ...
  }) {

  Map<String, dynamic> toMap() => {
        ...
        'requisites': requisitesToMap(requisites),
        ...
      };

  factory SpellTemplate.fromMap(Map<String, dynamic> map) => SpellTemplate(
        ...
        requisites: requisitesFromMap(map['requisites'] as Map<String, dynamic>?, 'SpellTemplate'),
        ...
      );
```

- [ ] **Step 4: `lib/models/resolved_spell.dart`, `lib/models/resolved_template.dart`**

In both files, the pass-through getter's declared type changes; nothing else does:

```dart
  Map<String, RequisiteKind> get requisites => record.requisites;
```

`ResolvedSpell.problems`'s call to `validateSpellAgainstCatalog(... requisites: record.requisites ...)` is unchanged text — the type flows through.

- [ ] **Step 5: `lib/engine/spell_engine.dart`**

`calculateBreakdown`'s parameter:

```dart
  LevelBreakdown calculateBreakdown({
    required BaseEffect baseEffect,
    int? chosenBaseLevel,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    required Map<String, List<String>> selectedModifiers,
    required Map<String, RequisiteKind> requisites,
    List<LevelAdjustment> adjustments = const [],
    RitualDeclaration ritualDeclaration = RitualDeclaration.none,
  }) {
```

Its contribution loop:

```dart
    for (final entry in requisites.entries) {
      contributions.add(LevelContribution(
          label: 'Requisite · ${entry.key}, ${entry.value.name}',
          magnitude: entry.value.magnitude));
    }
```

`calculateSpellLevel`'s parameter, same change:

```dart
  int calculateSpellLevel({
    required BaseEffect baseEffect,
    int? chosenBaseLevel,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    Map<String, List<String>> selectedModifiers = const {},
    required Map<String, RequisiteKind> requisites,
    List<LevelAdjustment> adjustments = const [],
    RitualDeclaration ritualDeclaration = RitualDeclaration.none,
  }) =>
```

Every call site in this file (`validateSpellDraft`'s `validateSpellAgainstCatalog(...)` call, its `calculateBreakdown(...)` call, and `findSimilarSpells`'s `calculateSpellLevel(...)` call) already reads `draft.requisites` / `s.requisites` — those lines do not need editing, only recompiling against the new type.

- [ ] **Step 6: `lib/bloc/spell_creation/spell_creation_bloc.dart`**

Replace the three requisite event handlers:

```dart
    } else if (event is RequisiteAdded) {
      final kind = event.kind == 'adding' ? RequisiteKind.adding : RequisiteKind.free;
      final updated = {...state.draft.requisites, event.art: kind};
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is RequisiteRemoved) {
      final updated = Map<String, RequisiteKind>.from(state.draft.requisites)
        ..remove(event.art);
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    } else if (event is RequisiteKindChanged) {
      final kind = event.newKind == 'adding' ? RequisiteKind.adding : RequisiteKind.free;
      final updated = {...state.draft.requisites, event.art: kind};
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(requisites: updated),
      ));
    }
```

`RequisiteAdded` and `RequisiteKindChanged` now build the update identically (`{...map, art: kind}` inserts or overwrites either way); they stay as separate `else if` branches because they are distinct events with distinct callers, not because the bodies differ. Do not merge them into one branch — that would make the bloc's event handling depend on incidental code shape rather than event identity.

If this file imports `Requisite` directly (check the import line for `lib/models/requisite.dart`), drop `Requisite` from a `show` clause if present — `RequisiteKind` is still needed.

- [ ] **Step 7: `lib/presentation/screens/spell_creation_screen.dart`**

Replace `_buildRequisitesSection`:

```dart
  Widget _buildRequisitesSection(
    BuildContext context,
    SpellCreationBloc bloc,
    SpellDraft draft,
  ) {
    final taken = draft.requisites.keys.toSet();
    final available =
        _selectableRequisiteArts(draft).where((art) => !taken.contains(art)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Requisites', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Free requisites cost nothing; adding requisites cost +1 magnitude each.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (draft.requisites.isEmpty)
          const Text('No requisites.')
        else
          ...draft.requisites.entries.map(
            (entry) => Padding(
              key: Key('requisite-row-${entry.key}'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  DropdownButton<RequisiteKind>(
                    key: Key('requisite-kind-${entry.key}'),
                    value: entry.value,
                    items: RequisiteKind.values
                        .map((kind) => DropdownMenuItem(
                              value: kind,
                              child: Text(
                                kind == RequisiteKind.adding ? 'Adding (+1)' : 'Free (+0)',
                              ),
                            ))
                        .toList(),
                    onChanged: (kind) {
                      if (kind != null) {
                        bloc.add(RequisiteKindChanged(entry.key, kind.name));
                      }
                    },
                  ),
                  IconButton(
                    key: Key('requisite-remove-${entry.key}'),
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove ${entry.key} requisite',
                    onPressed: () => bloc.add(RequisiteRemoved(entry.key)),
                  ),
                ],
              ),
            ),
          ),
        if (available.isNotEmpty)
          // A plain DropdownButton, not a DropdownButtonFormField: this is an
          // action picker, not a field holding a value. Selecting an art moves
          // it into the requisites map and therefore out of `available`, so a
          // FormField's retained selection would match no remaining item and
          // trip Flutter's "exactly one item with value" assertion on the next
          // rebuild. Pinning value to null keeps the hint showing and leaves
          // nothing to go stale.
          DropdownButton<String>(
            key: const Key('requisite-add-dropdown'),
            value: null,
            hint: const Text('Add requisite'),
            isExpanded: true,
            items: available
                .map((art) => DropdownMenuItem(value: art, child: Text(art)))
                .toList(),
            // New requisites default to free, the cheaper and more common
            // case; the user can promote one to adding via its kind dropdown.
            onChanged: (art) {
              if (art != null) {
                bloc.add(RequisiteAdded(art, RequisiteKind.free.name));
              }
            },
          ),
      ],
    );
  }
```

Every `Key(...)` string is unchanged (still keyed by art), so `find.byKey(const Key('requisite-row-Auram'))` and friends in the widget tests keep working untouched. `_selectableRequisiteArts` is untouched — it never read `requisites`.

- [ ] **Step 8: `lib/data/services/backup_service.dart`**

```dart
  static const String _supportedVersion = '3.0';
```

That is the entire change to this file. The export/import logic already reads/writes `_supportedVersion` by reference; nothing else here names `Requisite` or the shape directly — the requisites shape flows through `Spell.toMap`/`fromMap`, already handled by Step 2.

- [ ] **Step 9: Rewrite the tests whose logic changes**

**`test/models/requisite_test.dart`** — full replacement. The old file tested the now-deleted `Requisite` class's `toMap`/`fromMap`/`magnitude`/error messages; the (de)serialization tests move to `test/models/spell_test.dart` below, since that is where `requisitesFromMap` is now exercised through `Spell.fromMap`. This file shrinks to just the extension:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/requisite.dart';

void main() {
  group('RequisiteKind.magnitude', () {
    test('adding has magnitude 1', () {
      expect(RequisiteKind.adding.magnitude, 1);
    });

    test('free has magnitude 0', () {
      expect(RequisiteKind.free.magnitude, 0);
    });
  });
}
```

**`test/models/spell_test.dart`:**

Replace the `import 'package:eruditus/models/requisite.dart';` line's usage is unchanged (still needs `RequisiteKind`), but drop `Requisite` if the import uses a `show` clause naming it.

The round-trip test (lines 15–60, `'Spell.toMap and fromMap round-trip preserves every field'`):

```dart
    test('Spell.toMap and fromMap round-trip preserves every field', () {
      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        baseEffectId: '1',
        rangeId: 'param-voice',
        durationId: 'param-sun',
        targetId: 'param-individual',
        requisites: {
          'Vim': RequisiteKind.free,
          'Mentem': RequisiteKind.free,
          'Auram': RequisiteKind.adding,
          'Terram': RequisiteKind.adding,
        },
        description: 'A test spell',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 7, 24, 12, 30),
        updatedAt: DateTime(2026, 7, 25, 8, 15),
      );

      final map = spell.toMap();
      final restored = Spell.fromMap(map);

      expect(restored.id, spell.id);
      expect(restored.name, spell.name);
      expect(restored.baseEffectId, spell.baseEffectId);
      expect(restored.rangeId, spell.rangeId);
      expect(restored.durationId, spell.durationId);
      expect(restored.targetId, spell.targetId);
      expect(restored.description, spell.description);
      expect(restored.provenance.source, spell.provenance.source);
      expect(restored.createdAt, spell.createdAt);
      expect(restored.updatedAt, spell.updatedAt);

      expect(restored.requisites.length, 4);
      expect(restored.requisites['Vim'], RequisiteKind.free);
      expect(RequisiteKind.free.magnitude, 0);
      expect(restored.requisites['Mentem'], RequisiteKind.free);
      expect(restored.requisites['Auram'], RequisiteKind.adding);
      expect(RequisiteKind.adding.magnitude, 1);
      expect(restored.requisites['Terram'], RequisiteKind.adding);
    });
```

Add two new tests directly after it, carrying over the deleted `requisite_test.dart`'s (de)serialization-error coverage, now exercised through `Spell.fromMap`:

```dart
    test('fromMap throws a clear FormatException when a requisite kind is unknown', () {
      final map = Spell(
        id: 'spell-bad-kind', baseEffectId: '1', rangeId: 'param-voice',
        durationId: 'param-sun', targetId: 'param-individual',
        requisites: const {},
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
      ).toMap();
      map['requisites'] = {'Vim': 'mandatory'};

      expect(
        () => Spell.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('mandatory'), contains('free'), contains('adding')),
          ),
        ),
      );
    });

    test('fromMap throws a clear FormatException when a requisite kind is not a string', () {
      final map = Spell(
        id: 'spell-null-kind', baseEffectId: '1', rangeId: 'param-voice',
        durationId: 'param-sun', targetId: 'param-individual',
        requisites: const {},
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
      ).toMap();
      map['requisites'] = {'Vim': null};

      expect(
        () => Spell.fromMap(map),
        throwsA(isA<FormatException>().having(
          (e) => e.message, 'message', allOf(contains('Vim'), contains('no kind')),
        )),
      );
    });
```

Every remaining `requisites: const [],` in this file (lines ~273, 358, 380, 397, 412 — five occurrences) becomes `requisites: const {},`. Every raw wire-format literal `'requisites': <Map<String, dynamic>>[],` (two occurrences, ~289 and ~305) becomes `'requisites': <String, dynamic>{},`. `baseMap()`'s `'requisites': <dynamic>[],` (~436) becomes `'requisites': <String, dynamic>{},`.

In the `validateSpellAgainstCatalog` test group (the `validate()` helper and its tests, originally around lines 496–641):

```dart
    List<String> validate({
      required BaseEffect effect,
      int? chosenBaseLevel,
      Map<String, RequisiteKind> requisites = const {},
      Map<String, List<String>> selectedModifiers = const {},
      List<Modifier> modifiers = const [],
      bool isTemplate = false,
    }) =>
        validateSpellAgainstCatalog(
          effect: effect,
          chosenBaseLevel: chosenBaseLevel,
          requisites: requisites,
          selectedModifiers: selectedModifiers,
          modifiers: modifiers,
          isTemplate: isTemplate,
        );
```

```dart
    test('check 3: a requisite equal to the spell own Technique is a problem', () {
      expect(
        validate(effect: fixedEffect(), requisites: {'Creo': RequisiteKind.free}),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('check 3: a requisite equal to the spell own Form is a problem', () {
      expect(
        validate(effect: fixedEffect(), requisites: {'Ignem': RequisiteKind.free}),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('check 3: an unrelated requisite alongside a self-matching one still fires', () {
      expect(
        validate(
          effect: fixedEffect(),
          requisites: {
            'Creo': RequisiteKind.free, // matches fixedEffect's technique
            'Rego': RequisiteKind.adding, // unrelated
          },
        ),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });
```

**Delete** the `'check 4: a duplicate requisite art is a problem'` test entirely — `requisites` is now a map, so `{'Rego': RequisiteKind.free, 'Rego': RequisiteKind.adding}` is not two entries, it is one entry whose value is whichever the Dart map literal evaluates last. There is no duplicate to detect, which is exactly the point of this reshape; keeping a test that constructs one would either fail to compile as written or silently test nothing.

```dart
    test('isTemplate still runs checks 3 and 5', () {
      expect(
        validate(
          effect: fixedEffect(),
          requisites: {'Creo': RequisiteKind.free},
          isTemplate: true,
        ),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('problems accumulate rather than short-circuiting', () {
      final problems = validate(
        effect: generalEffect(), // technique Rego, form Vim, no chosenBaseLevel
        requisites: {'Rego': RequisiteKind.free}, // matches own technique
      );
      expect(problems.length, 2); // check 1 (no chosen level) + check 3 (self-match)
    });
```

The old "problems accumulate" test used two duplicate `Rego` requisites to land on checks 1+4; that combination no longer exists. The replacement above reaches 2 problems a different way — a General guideline's missing chosen level (check 1) plus a requisite matching that guideline's own Rego technique (check 3) — while still proving accumulation rather than short-circuiting, which is the property under test.

**`test/engine/spell_engine_test.dart`:**

```dart
    test('fails if a requisite art is the spell\'s own technique or form', () {
      final draft = SpellDraft(
        technique: 'Creo',
        baseEffect: creoIgnemEffect, // (whatever the surrounding test already uses — unchanged)
        range: _range,
        duration: _duration,
        target: _target,
        requisites: {'Ignem': RequisiteKind.adding},
      );
      // ...unchanged assertion body
```

(Fetch the exact surrounding fixture names — `creoIgnemEffect` or equivalent — from the file as it stands; only the `requisites:` line's literal shape changes, not the rest of the test.)

**Delete** the `'fails if the same requisite art is listed twice'` test — same reasoning as `spell_test.dart`'s deleted check-4 test: the scenario it constructs (`Requisite(art: 'Auram', kind: RequisiteKind.free)` and `Requisite(art: 'Auram', kind: RequisiteKind.adding)` in one list) has no map equivalent.

```dart
    test('passes with several distinct requisites of mixed kinds', () {
      final draft = SpellDraft(
        technique: 'Creo',
        // ...unchanged
        requisites: {
          'Auram': RequisiteKind.free,
          'Terram': RequisiteKind.adding,
          'Rego': RequisiteKind.adding,
        },
      );
      // ...unchanged assertion body
```

```dart
    test('an adding requisite contributes +1 magnitude', () {
      // ...
      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        requisites: {'Auram': RequisiteKind.adding},
      );

      expect(level, 4); // Base 3 + adding requisite(+1) = 4
    });

    test('a free requisite contributes no magnitude', () {
      // ...
      final level = engine.calculateSpellLevel(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        requisites: {'Auram': RequisiteKind.free},
      );

      expect(level, 3); // Base 3 + free requisite(+0) = 3
    });
```

```dart
    test('the breakdown lists base, parameters, requisites and modifiers', () {
      // ...
      final breakdown = engine.calculateBreakdown(
        baseEffect: baseEffect,
        range: _range, duration: _duration, target: _target,
        selectedModifiers: const {},
        requisites: {'Auram': RequisiteKind.adding},
      );
      // ...unchanged assertion body
```

Every other `requisites: const [],` / `requisites: [],` in this file (the `calculateSpellLevel`/`calculateBreakdown`/`Spell(...)` fixtures that pass an empty collection — roughly a dozen occurrences) becomes `requisites: const {},` / `requisites: {},` with no other change.

**`test/bloc/spell_creation_bloc_test.dart`:**

```dart
  blocTest<SpellCreationBloc, SpellCreationState>(
    'RequisiteAdded appends a requisite of the given kind',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const RequisiteAdded('Auram', 'free'));
      bloc.add(const RequisiteAdded('Terram', 'adding'));
    },
    skip: 1,
    expect: () => [
      isA<SpellCreationState>().having(
        (s) => s.draft.requisites.entries.map((e) => '${e.key}:${e.value.name}'),
        'requisites',
        ['Auram:free', 'Terram:adding'],
      ),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'RequisiteKindChanged flips only the named art, leaving the others alone',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const RequisiteAdded('Auram', 'free'));
      bloc.add(const RequisiteAdded('Terram', 'free'));
      bloc.add(const RequisiteKindChanged('Terram', 'adding'));
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>().having(
        (s) => s.draft.requisites.entries.map((e) => '${e.key}:${e.value.name}'),
        'requisites',
        ['Auram:free', 'Terram:adding'],
      ),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'RequisiteRemoved drops only the named art',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const RequisiteAdded('Auram', 'free'));
      bloc.add(const RequisiteAdded('Terram', 'adding'));
      bloc.add(const RequisiteRemoved('Auram'));
    },
    skip: 2,
    expect: () => [
      isA<SpellCreationState>().having(
        (s) => s.draft.requisites.keys,
        'requisites',
        ['Terram'],
      ),
    ],
  );
```

The remaining two `blocTest`s in this group (`'an adding requisite raises the calculated level by one magnitude'`, `'a free requisite leaves the calculated level unchanged'`, `'SpellCalculated reports a requisite that duplicates the spell's own form'`) dispatch `RequisiteAdded` events and read no `requisites` literal directly — unchanged. The four `requisites: const [],` occurrences elsewhere in this file's `Spell`/`ResolvedSpell` fixtures become `requisites: const {},`.

**`test/presentation/screens/spell_creation_screen_test.dart`:**

```dart
  group('requisites section', () {
    SpellCreationState draftWith(Map<String, RequisiteKind> requisites) => SpellCreationState(
          status: SpellCreationStatus.editing,
          draft: SpellDraft(
            technique: 'Creo',
            form: 'Ignem',
            baseEffect: creoIgnemEffect,
            requisites: requisites,
          ),
        );

    testWidgets('shows an empty-state message when the draft has no requisites',
        (tester) async {
      await pumpScreen(tester, draftWith(const {}));
      // ...unchanged body
    });

    // 'selecting an art from the add dropdown dispatches RequisiteAdded as free'
    // and "the add dropdown offers neither the spell's own technique nor its
    // form" both call draftWith(const []) — change to draftWith(const {}), no
    // other change.

    testWidgets('an already-selected art is not offered again in the add dropdown',
        (tester) async {
      await pumpScreen(
        tester,
        draftWith({'Auram': RequisiteKind.free}),
      );
      // ...unchanged body
    });

    testWidgets('changing a requisite kind dispatches RequisiteKindChanged', (tester) async {
      await pumpScreen(
        tester,
        draftWith({'Auram': RequisiteKind.free}),
      );
      // ...unchanged body
    });

    testWidgets('tapping remove dispatches RequisiteRemoved', (tester) async {
      await pumpScreen(
        tester,
        draftWith({'Auram': RequisiteKind.adding}),
      );
      // ...unchanged body
    });

    testWidgets('adding a requisite survives the rebuild that removes it from the add dropdown',
        (tester) async {
      // ...
      SpellCreationState stateWith(Map<String, RequisiteKind> requisites) => SpellCreationState(
            status: SpellCreationStatus.editing,
            draft: SpellDraft(
              technique: 'Creo',
              form: 'Ignem',
              baseEffect: creoIgnemEffect,
              requisites: requisites,
            ),
          );
      // ...
      whenListen(bloc, stateController.stream, initialState: stateWith(const {}));
      // ...
      stateController.add(stateWith({'Auram': RequisiteKind.free}));
      // ...unchanged body
    });

    testWidgets('renders a row per requisite when several are present', (tester) async {
      await pumpScreen(
        tester,
        draftWith({
          'Auram': RequisiteKind.free,
          'Terram': RequisiteKind.adding,
          'Rego': RequisiteKind.adding,
        }),
      );
      // ...unchanged body
    });
  });
```

The two other `requisites: const [],` occurrences in this file (the `suggestion`/`ordinaryRecord`/etc. `Spell(...)` fixtures earlier in the file, lines ~316, ~346, ~411) become `requisites: const {},`.

**`test/data/services/backup_service_test.dart`:**

Every `'version': '2.0'` literal (5 occurrences: the `expect(data['version'], '2.0')` assertion plus four backup-JSON fixtures) becomes `'2.0'` → `'3.0'`. The `'version': '99.0'` fixture in `'importFromJson throws FormatException for an unsupported version'` is untouched — it is testing rejection of an unrelated version, which still applies. The six `requisites: const [],` occurrences in this file's `Spell(...)` fixtures become `requisites: const {},`.

- [ ] **Step 10: Mechanical sweep — every remaining `requisites: const []` / `requisites: []`**

The following files reference `requisites` only as an empty-collection default in a `Spell`/`SpellTemplate`/`SpellDraft` fixture — no `Requisite(...)` construction, no logic depending on the shape. In each, replace every `requisites: const [],` with `requisites: const {},` and every `requisites: [],` with `requisites: {},`. Nothing else in these files changes:

- `test/presentation/widgets/spell_card_test.dart`
- `test/presentation/screens/spell_library_screen_test.dart`
- `test/bloc/spell_library_bloc_test.dart`
- `test/data/spell_resolver_test.dart`
- `test/engine/ritual_status_test.dart`
- `test/presentation/screens/backup_screen_test.dart`
- `test/models/resolved_spell_test.dart`
- `test/engine/general_effect_test.dart`
- `test/data/repositories/spell_repository_test.dart`
- `test/data/datasources/local_spell_datasource_test.dart`
- `test/data/repositories/library_repository_test.dart`
- `test/data/datasources/asset_data_loader_test.dart`
- `test/data/published_spell_import_test.dart`

If any occurrence in these files turns out not to match this exact pattern (for instance, a raw wire-format map literal like `'requisites': []` rather than a constructor argument), apply the same list-to-empty-map substitution (`'requisites': {}` / `'requisites': <String, dynamic>{}`, matching the surrounding literal's style) rather than skipping it. If any file in this list contains a `Requisite(` construction this plan did not anticipate, stop and report `NEEDS_CONTEXT` rather than guessing at its replacement — do not delete a test to make it compile.

- [ ] **Step 11: Verify and commit**

Run:

```bash
flutter analyze
```

Expected: no errors. (Warnings pre-existing and unrelated to this change are fine; do not fix unrelated warnings in this task.)

```bash
flutter test
```

Expected: all tests pass. If anything still references `Requisite(` or a list-shaped `requisites:` literal, `flutter analyze` will report it as a compile error before you get this far — resolve those first.

As a final check, confirm nothing outside `lib/models/requisite.dart` itself still names the deleted class:

```bash
grep -rn "Requisite(" lib test
```

Expected: no output (the class no longer exists to construct).

```bash
git add -A
git commit -m "feat: reshape requisites from List<Requisite> to Map<String, RequisiteKind>"
```

---

### Task 2: The Python importer — emit.py and asset regeneration

**Files:**
- Modify: `scripts/spell_import/emit.py`
- Modify: `scripts/spell_import/tests/test_emit.py`
- Regenerate: `assets/data/spell_library.json`, `assets/data/spell_templates.json`
- Regenerate: `scripts/spell_import/import_report.md` (produced as a side effect of the regeneration run)

**Interfaces:**
- Consumes: nothing from Task 1 — Python and Dart do not share a compiler, only a JSON wire format. This task only has to agree with Task 1 on what `assets/data/spell_library.json`'s `"requisites"` key looks like: a JSON object (`{"Rego": "adding"}`), not an array.
- Produces: the two regenerated asset files, consumed by the Flutter app at runtime (already covered by Task 1's `Spell.fromMap`/`SpellTemplate.fromMap`, which now expect exactly this shape).

- [ ] **Step 1: Write the failing test**

Add to `scripts/spell_import/tests/test_emit.py` (a new test class, alongside the existing `AdjustmentEmissionTest`):

```python
class RequisiteEmissionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def test_requisites_serialize_as_a_dict_keyed_by_art(self):
        design = designline.parse_design("(Base 5, +1 Touch, +1 Rego requisite)")
        block = blocks.SpellBlock(
            name="Test Spell", technique="Creo", form="Ignem", printed_level=10,
            stat=statline.StatLine(
                range_name="Touch", duration_name="Sun", target_name="Ind",
                is_ritual=False, requisite_arts=[], trailing="",
            ),
            prose="Test prose.", design_line=None, line_no=1,
        )
        spell = emit.build_spell(block, "test-effect", self.catalog, design)
        self.assertEqual(spell["requisites"], {"Rego": "adding"})

    def test_a_design_line_requisite_is_not_overwritten_by_the_stat_lines_free_default(self):
        """setdefault, not assignment: the design line is more specific than
        the bare Req: stat line, so it must win when both name the same art.
        A spell whose design line prints "+1 Rego requisite" alongside a
        "Req: Rego" stat line must keep the adding cost, not silently drop to
        free."""
        design = designline.parse_design("(Base 5, +1 Touch, +1 Rego requisite)")
        block = blocks.SpellBlock(
            name="Test Spell", technique="Creo", form="Ignem", printed_level=10,
            stat=statline.StatLine(
                range_name="Touch", duration_name="Sun", target_name="Ind",
                is_ritual=False, requisite_arts=["Rego"], trailing="",
            ),
            prose="Test prose.", design_line=None, line_no=1,
        )
        spell = emit.build_spell(block, "test-effect", self.catalog, design)
        self.assertEqual(spell["requisites"], {"Rego": "adding"})
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run (from the repository root; this project's Python tests use stdlib `unittest`, not `pytest` — `pytest` is not installed): `python -m unittest -v scripts.spell_import.tests.test_emit.RequisiteEmissionTest`

Expected: both FAIL — `build_spell` still returns a list of dicts, so `spell["requisites"] == {"Rego": "adding"}` does not hold (it holds a `[{"art": "Rego", "kind": "adding"}]` list instead).

- [ ] **Step 3: Rewrite `build_spell` and `build_template`'s requisites building**

In `build_spell` (`scripts/spell_import/emit.py`), replace:

```python
    requisites = [
        {"art": token.label, "kind": "adding" if token.magnitude else "free"}
        for token in design.tokens
        if token.kind == "requisite" and token.label != "free"
    ]
    for art in block.stat.requisite_arts:
        if not any(r["art"] == art for r in requisites):
            requisites.append({"art": art, "kind": "free"})
```

with:

```python
    requisites: dict[str, str] = {}
    for token in design.tokens:
        if token.kind == "requisite" and token.label != "free":
            requisites.setdefault(token.label, "adding" if token.magnitude else "free")
    for art in block.stat.requisite_arts:
        requisites.setdefault(art, "free")
```

`setdefault` is load-bearing, not a style choice: the design-line loop runs first and may record `"adding"` for an art; the stat-line loop must not overwrite that with `"free"` for the same art. Plain assignment (`requisites[art] = "free"`) would silently downgrade an adding requisite whenever both a design-line token and a bare `Req:` stat entry name the same art.

Make the identical change in `build_template` — its requisites-building block is textually identical to `build_spell`'s (the design spec's "What part B drags with it" section flags this as the pre-existing near-duplication item 38 already tracks; do not deduplicate the two functions in this task, that refactor is out of scope here).

Both functions' `"requisites": requisites` line is unchanged text — it now assigns a `dict[str, str]` instead of a `list[dict]`, which `json.dump` serializes as a JSON object.

- [ ] **Step 4: Run the new tests to verify they pass**

Run: `python -m unittest -v scripts.spell_import.tests.test_emit.RequisiteEmissionTest`

Expected: PASS.

- [ ] **Step 5: Run the full Python test suite**

Run (from the repository root): `python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`

Expected: all tests pass. `test_emit.py`'s existing tests construct spells with `stat.requisite_arts=[]` and no requisite design tokens throughout, so they produce `{}` where they previously produced `[]` — check any test in this suite that asserts on the `"requisites"` key's exact value (not just its presence) and update the expected literal from `[]` to `{}` if one exists; the earlier grep of this file found only a key-presence assertion (`"requisites"` in a set of expected keys), not a shape assertion, so this is expected to need no further change, but verify by running the suite rather than assuming.

- [ ] **Step 6: Regenerate the assets**

Run, from the repository root:

```bash
python -m scripts.spell_import.extract_spells --write
```

Expected: succeeds without needing `--accept-source` (the rulebook pin in `source.lock` is unchanged — this run only changes what shape the already-parsed data is emitted in). If it reports a source mismatch, stop and investigate before adding `--accept-source` — that would mean something about the source changed unexpectedly, which this task does not intend.

Confirm the diff is shape-only, not content-only:

```bash
git diff --stat assets/data/spell_library.json assets/data/spell_templates.json
```

Expected: both files show changes (every spell/template carrying a non-empty `requisites` gets a reshaped value); `imported`/`templates`/`blocked` counts in the regenerated `scripts/spell_import/import_report.md` are unchanged from before this task (294/23/43, per the design spec's "zero violations" scan) — the change is purely how `requisites` is spelled, not which spells import or what they mean.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: emit requisites as a dict keyed by art, not a list"
```

---

### Task 3: Close out — combined verification and todo update

**Files:**
- Modify: `.superpowers/todo.md`

**Interfaces:**
- Consumes: Task 1's Dart reshape and Task 2's regenerated assets, run together for the first time.
- Produces: nothing further downstream — this is the plan's final task.

- [ ] **Step 1: Run both test suites together**

```bash
flutter test
```

Expected: all tests pass, now against the Task 2-regenerated `assets/data/spell_library.json`/`spell_templates.json` — this is the first point in the plan where the Dart side reads the Python side's actual output rather than a fixture, so it is the real integration check for the wire-format agreement Task 1 and Task 2 each assumed independently.

```bash
python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"
```

Expected: all tests pass (unchanged from Task 2's Step 5 — included here as a single combined confirmation before closing out).

- [ ] **Step 2: Update the todo**

In `.superpowers/todo.md`, find item 40's Part B checkbox (currently `- [ ] Reshape \`requisites\` from \`List<Requisite>\` to a map keyed by art — ...`) and mark it complete (`- [x]`). If item 40's surrounding text tracks completion status elsewhere in the same entry (compare to how Part A's completion was recorded — check for a line resembling "Part A: complete" or similar near the top of the item), add a parallel note for Part B rather than inventing a new format.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs: record item 40 part B as complete"
```

---

## Verification

- `flutter analyze` and `flutter test` are green after Task 1, and remain green after Task 2 regenerates the assets Task 1's tests do not directly exercise.
- `python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"` is green after Task 2.
- `grep -rn "Requisite(" lib test` returns nothing (Task 1, Step 11) — the deleted class has no surviving construction site.
- `assets/data/spell_library.json`'s `"requisites"` values are JSON objects, not arrays, for every spell that has one (spot-check a handful, e.g. `grep -A1 '"requisites"' assets/data/spell_library.json | head -20`).
- `scripts/spell_import/import_report.md`'s `imported`/`templates`/`blocked` counts are unchanged from the pre-task run (294/23/43) — Task 2 changes shape, not content.
- Todo item 40 (both parts) reads as complete in `.superpowers/todo.md`.
