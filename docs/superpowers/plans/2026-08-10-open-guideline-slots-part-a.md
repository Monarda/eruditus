# Open Guideline Slots — Part A (Mechanism + Realm) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `BaseEffect` a generic "this guideline leaves a slot open" concept (`OpenSlotKind`/`openSlots`), give `Spell`/`SpellDraft`/`SpellTemplate` a matching `chosenSlots` map, enforce it in `validateSpellAgainstCatalog`, wire it through the creation bloc/UI, and fully deliver one instance of it — realm — end to end: 17 catalog entries annotated, the 7 real corpus templates that use them carry a verified `chosenSlots`, and a user can fill a realm themselves when building a custom spell off a raw guideline.

**Architecture:** `OpenSlotKind` is a new enum (`realm`, `form`, `specificType`) living beside `RitualRequirement` in `base_effect.dart`. `chosenSlots: Map<String, String>` (keyed by `OpenSlotKind.name`) is a new field on `Spell`, `SpellDraft`, and `SpellTemplate`, filled either by the caster (a new `OpenSlotChosen` bloc event, mirroring `ChosenBaseLevelChanged`) or, for realm, by a small hand-verified table in the Python importer (mirroring `KNOWN_UNRESOLVABLE`) — never by a prose-scanning heuristic, which the real corpus already defeats (see the design spec's Decisions 7/9/10). Two new checks in `validateSpellAgainstCatalog` (checks 6 and 7) require at least one declared-open kind to be filled, and reject a value for a kind the effect doesn't declare open.

**Tech Stack:** Dart/Flutter (`lib/`, `test/`), Python 3 (`scripts/spell_import/`, `scripts/spell_import/tests/`).

## Global Constraints

- No migration story for already-serialized data: this is a prototype, the DB is droppable, and old-shape backups become unsupported rather than translated (project convention).
- Checks 6 and 7 are the next free numbers in `validateSpellAgainstCatalog`'s numbered-check comments — check 4 was deleted (not reused) by item 40 Part B; checks 1, 2, 3, 5 are baseline and must not be renumbered or otherwise touched beyond what's mechanically required.
- `chosenSlots` defaults to `{}` (never null) on every model that carries it, exactly like `selectedModifiers`.
- Checks 6/7 apply on both `Spell` write paths (`Spell.fromMap`, `SpellDraft.toSpell` via `validateSpellDraft`) and nowhere else — `SpellTemplate` is read-only catalog data with no write boundary (same reasoning item 40 already recorded for checks 1/2).
- The realm value for a published spell is resolved by a **hand-verified lookup table**, not a prose scan — a scan was tried during design and demonstrably misfires on the real corpus (two ward spells don't restate their realm word in their own text; `Wind of Mundane Silence` only contains "Magic" via "Magic Resistance"/"Magical things", not a realm commitment). See Task 6.
- Part A does not unblock any currently-blocked spell and does not change `import_report.md`'s blocked count. It backfills `chosenSlots` onto 7 already-imported templates.
- `source.lock`'s pinned rulebook revision does not change — Task 7's asset regeneration uses `--write` alone, not `--accept-source`.
- Out of scope for this plan: Form and "specific type" slot kinds, and the three case-2 Muto Vim spells (`Mirror of Opposition`, `Wizard's Boost`, `Wizard's Reach`) — all Part B, planned separately. The mechanism this plan builds must not need reshaping when Part B lands.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/base_effect.dart` | `OpenSlotKind` enum, `BaseEffect.openSlots`, `chosenSlotsFromMap` shared parse helper (mirrors `requisite.dart`'s `requisitesFromMap`). |
| `lib/models/spell.dart` | `Spell`/`SpellDraft.chosenSlots`; checks 6/7 in `validateSpellAgainstCatalog`. |
| `lib/models/spell_template.dart` | `SpellTemplate.chosenSlots`. |
| `lib/models/resolved_spell.dart`, `lib/models/resolved_template.dart` | Pass-through `chosenSlots` getters; `ResolvedSpell.problems` passes `chosenSlots` into `validateSpellAgainstCatalog`. |
| `lib/engine/spell_engine.dart` | `validateSpellDraft`'s existing `validateSpellAgainstCatalog` call gains `chosenSlots: draft.chosenSlots`. No other engine change — realm doesn't feed level math. |
| `lib/bloc/spell_creation/spell_creation_event.dart`, `spell_creation_bloc.dart` | New `OpenSlotChosen(kind, value)` event; handler; pruning on `TechniqueSelected`/`FormSelected`/`BaseEffectSelected`; `TemplateInstantiated` copies `template.chosenSlots` onto the new draft. |
| `lib/presentation/screens/spell_creation_screen.dart` | Realm dropdown, gated on `draft.baseEffect?.openSlots.isNotEmpty ?? false`. |
| `lib/data/services/backup_service.dart` | `_supportedVersion` bump `'3.0'` → `'4.0'`. |
| `scripts/spell_import/catalog.py` | `Catalog.open_slots(effect_id)` lookup, mirroring `reference_cost`'s style. |
| `scripts/spell_import/extract_spells.py` | `REALM_BY_SPELL_ID` hand-verified table, mirroring `KNOWN_UNRESOLVABLE`. |
| `scripts/spell_import/emit.py` | `build_spell`/`build_template` set `chosenSlots["realm"]` when the base effect declares it open and the spell's slug is in the table. |
| `assets/data/base_effects.json` | 17 entries gain `"openSlots": ["realm"]`. |
| `assets/data/spell_library.json`, `assets/data/spell_templates.json` | Regenerated; 7 existing entries gain `chosenSlots`. |
| Every test file listed per task | Updated/new tests. |

---

### Task 1: `OpenSlotKind`, `BaseEffect.openSlots`, `Spell`/`SpellDraft.chosenSlots`, checks 6/7

**Files:**
- Modify: `lib/models/base_effect.dart`
- Modify: `lib/models/spell.dart`
- Test: `test/models/base_effect_test.dart`
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Produces: `enum OpenSlotKind { realm, form, specificType }` (`base_effect.dart`); `BaseEffect.openSlots` (`List<OpenSlotKind>`, default `const []`); `Map<String, String> chosenSlotsFromMap(Map<String, dynamic>? map)` (`base_effect.dart`, parses a `chosenSlots` wire map, defaulting a missing key to `{}`); `Spell.chosenSlots`/`SpellDraft.chosenSlots` (`Map<String, String>`, default `{}`); `validateSpellAgainstCatalog(..., required Map<String, String> chosenSlots)` — new required parameter.
- Consumes: nothing from other tasks.

- [ ] **Step 1: Write failing tests for `OpenSlotKind` and `BaseEffect.openSlots`**

Add to `test/models/base_effect_test.dart`, in the same top-level group as the existing `ritualRequirement` tests:

```dart
    test('openSlots defaults to empty and round-trips every combination', () {
      final plain = BaseEffect(
        id: 'e-5', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 10,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      expect(plain.openSlots, isEmpty);

      final withSlots = BaseEffect(
        id: 'e-6', technique: 'Perdo', form: 'Vim',
        description: 'Dispel a specific type of enchantment', baseLevel: null,
        openSlots: const [OpenSlotKind.form, OpenSlotKind.specificType],
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      expect(BaseEffect.fromMap(withSlots.toMap()).openSlots,
          [OpenSlotKind.form, OpenSlotKind.specificType]);
    });

    test('fromMap treats an absent openSlots key as empty', () {
      final restored = BaseEffect.fromMap({
        'id': 'e-7',
        'technique': 'Creo',
        'form': 'Ignem',
        'description': 'Create flame',
        'baseLevel': 10,
        'source': 'user-created',
      });
      expect(restored.openSlots, isEmpty);
    });

    test('fromMap throws a clear FormatException on an unknown openSlots entry', () {
      expect(
        () => BaseEffect.fromMap({
          'id': 'e-8',
          'technique': 'Creo',
          'form': 'Ignem',
          'description': 'Create flame',
          'baseLevel': 10,
          'openSlots': ['alignment'],
          'source': 'user-created',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('alignment'), contains('BaseEffect'), contains('realm')),
          ),
        ),
      );
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/base_effect_test.dart`
Expected: FAIL — `openSlots` and `OpenSlotKind` are undefined.

- [ ] **Step 3: Implement `OpenSlotKind` and `BaseEffect.openSlots`**

In `lib/models/base_effect.dart`, add beside `RitualRequirement`:

```dart
/// A slot the rulebook leaves open on a guideline for the caster (or, for a
/// published spell, the spell's own prose) to fill — the same shape of thing
/// `chosenBaseLevel` is for a General guideline's level, generalized to
/// cover the guideline text's other open choices.
///
/// [realm] — "Ward against beings... from one supernatural realm (Divine,
/// Faerie, Infernal, or Magic)". [form] and [specificType] are Part B's; the
/// enum carries all three now so the wire shape never needs to change again
/// when they land (todo items 35/37's design spec, decision 8).
enum OpenSlotKind { realm, form, specificType }

OpenSlotKind _openSlotKindFromName(String name) {
  for (final value in OpenSlotKind.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "BaseEffect.fromMap: unknown open slot kind '$name' (expected one of: "
    "${OpenSlotKind.values.map((k) => k.name).join(', ')})",
  );
}

/// Parses a `chosenSlots` wire map (`{"realm": "Infernal"}`) back, shared by
/// [Spell]/[SpellDraft]/[SpellTemplate] so the three cannot drift, the same
/// reason [requisitesFromMap] is shared.
Map<String, String> chosenSlotsFromMap(Map<String, dynamic>? map) {
  if (map == null) return const {};
  return map.map((kind, value) => MapEntry(kind, value as String));
}
```

Add the field, constructor parameter, `toMap` entry, and `fromMap` parsing:

```dart
  /// Slots this guideline's own text leaves for the caster (or a published
  /// spell's prose) to fill — realm, Form, or "a specific type", per
  /// [OpenSlotKind]. Empty for every guideline that commits to everything
  /// itself.
  final List<OpenSlotKind> openSlots;
```

```dart
  BaseEffect({
    required this.id,
    required this.technique,
    required this.form,
    required this.description,
    required this.baseLevel,
    this.ritualRequirement = RitualRequirement.none,
    required this.provenance,
    this.reference = const ParameterTriple.standard(),
    this.effectFormula,
    this.openSlots = const [],
  });
```

```dart
  Map<String, dynamic> toMap() => {
    'id': id,
    'technique': technique,
    'form': form,
    'description': description,
    'baseLevel': baseLevel,
    'ritualRequirement': ritualRequirement.name,
    ...provenance.toMap(),
    'reference': reference.toMap(),
    if (effectFormula != null) 'effectFormula': effectFormula!.toMap(),
    'openSlots': openSlots.map((k) => k.name).toList(),
  };
```

```dart
  factory BaseEffect.fromMap(Map<String, dynamic> map) => BaseEffect(
    id: requireField<String>(map, 'id', 'BaseEffect'),
    technique: requireField<String>(map, 'technique', 'BaseEffect'),
    form: requireField<String>(map, 'form', 'BaseEffect'),
    description: requireField<String>(map, 'description', 'BaseEffect'),
    baseLevel: _baseLevelFromMap(map),
    ritualRequirement: map['ritualRequirement'] == null
        ? RitualRequirement.none
        : _ritualRequirementFromName(
            requireField<String>(map, 'ritualRequirement', 'BaseEffect')),
    provenance: Provenance.fromMap(map),
    reference: map['reference'] == null
        ? const ParameterTriple.standard()
        : ParameterTriple.fromMap(map['reference'] as Map<String, dynamic>),
    effectFormula: map['effectFormula'] == null
        ? null
        : GeneralEffectFormula.fromMap(map['effectFormula'] as Map<String, dynamic>),
    openSlots: (map['openSlots'] as List?)
            ?.map((k) => _openSlotKindFromName(k as String))
            .toList() ??
        const [],
  );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/base_effect_test.dart`
Expected: PASS

- [ ] **Step 5: Write failing tests for `chosenSlots` and checks 6/7**

Add to `test/models/spell_test.dart`. First, `chosenSlots` round-trips alongside the existing `chosenBaseLevel and templateId round-trip` test (same group):

```dart
    test('chosenSlots defaults to empty and round-trips', () {
      final spell = Spell(
        id: 's-1', baseEffectId: 'e1', rangeId: 'p1', durationId: 'p2', targetId: 'p3',
        requisites: const {},
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      expect(spell.chosenSlots, isEmpty);

      final withSlot = Spell(
        id: 's-2', baseEffectId: 'e1', rangeId: 'p1', durationId: 'p2', targetId: 'p3',
        requisites: const {},
        chosenSlots: const {'realm': 'Infernal'},
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      expect(Spell.fromMap(withSlot.toMap()).chosenSlots, {'realm': 'Infernal'});
    });
```

Then, in the `validateSpellAgainstCatalog` group, extend the local `validate()` helper and add a realm-slot fixture, right after `generalEffect()`:

```dart
    BaseEffect realmSlotEffect() => BaseEffect(
          id: 'revi-G1-open', technique: 'Rego', form: 'Vim',
          description: 'Ward against beings from one realm', baseLevel: null,
          openSlots: const [OpenSlotKind.realm],
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        );

    BaseEffect eitherSlotEffect() => BaseEffect(
          id: 'pevi-G10-open', technique: 'Perdo', form: 'Vim',
          description: 'Dispel a particular Hermetic Form or a specific type of enchantment',
          baseLevel: null,
          openSlots: const [OpenSlotKind.form, OpenSlotKind.specificType],
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        );
```

Update the `validate()` helper to accept and forward `chosenSlots`:

```dart
    List<String> validate({
      required BaseEffect effect,
      int? chosenBaseLevel,
      Map<String, RequisiteKind> requisites = const {},
      Map<String, List<String>> selectedModifiers = const {},
      Map<String, String> chosenSlots = const {},
      List<Modifier> modifiers = const [],
      bool isTemplate = false,
    }) =>
        validateSpellAgainstCatalog(
          effect: effect,
          chosenBaseLevel: chosenBaseLevel,
          requisites: requisites,
          selectedModifiers: selectedModifiers,
          chosenSlots: chosenSlots,
          modifiers: modifiers,
          isTemplate: isTemplate,
        );
```

Then the check 6/7 tests, added after the existing check 5 tests:

```dart
    test('check 6: a declared open realm slot with no chosen value is a problem', () {
      expect(validate(effect: realmSlotEffect(), chosenBaseLevel: 20),
          contains('Choose a realm for this guideline'));
    });

    test('check 6: a filled realm slot is fine', () {
      expect(
        validate(
          effect: realmSlotEffect(),
          chosenBaseLevel: 20,
          chosenSlots: const {'realm': 'Infernal'},
        ),
        isEmpty,
      );
    });

    test('check 6: an either/or slot is satisfied by just one of its declared kinds', () {
      expect(
        validate(
          effect: eitherSlotEffect(),
          chosenBaseLevel: 20,
          chosenSlots: const {'specificType': 'Hermetic Terram magic'},
        ),
        isEmpty,
      );
    });

    test('check 6: an either/or slot with neither kind filled is a problem', () {
      expect(
        validate(effect: eitherSlotEffect(), chosenBaseLevel: 20),
        contains('Choose a Form or a specific type of enchantment for this guideline'),
      );
    });

    test('check 7: a chosen realm on a guideline with no open realm slot is a problem', () {
      expect(
        validate(effect: fixedEffect(), chosenSlots: const {'realm': 'Infernal'}),
        contains('A chosen realm applies only to a guideline with an open realm slot'),
      );
    });

    test('isTemplate still runs checks 6 and 7', () {
      expect(
        validate(effect: realmSlotEffect(), isTemplate: true),
        contains('Choose a realm for this guideline'),
      );
    });
```

- [ ] **Step 6: Run the tests to verify they fail**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — `chosenSlots` parameter undefined, checks 6/7 don't exist.

- [ ] **Step 7: Implement `chosenSlots` and checks 6/7**

In `lib/models/spell.dart`, add the import and the new parameter/checks to `validateSpellAgainstCatalog`:

```dart
import 'package:eruditus/models/base_effect.dart';
```

(This import likely already exists — verify before adding a duplicate.)

Add the parameter to the function signature, right after `selectedModifiers`:

```dart
List<String> validateSpellAgainstCatalog({
  required BaseEffect effect,
  required int? chosenBaseLevel,
  required Map<String, RequisiteKind> requisites,
  required Map<String, List<String>> selectedModifiers,
  required Map<String, String> chosenSlots,
  required List<Modifier> modifiers,
  bool isTemplate = false,
}) {
```

Add checks 6 and 7 at the end of the function body, before the final `return problems;`:

```dart
  // 6. An open slot (realm, Form, "a specific type") is the caster's to fill,
  //    the same completeness requirement chosenBaseLevel already enforces for
  //    a General guideline's level -- a ward with no realm chosen is not yet
  //    a spell. "At least one" (not "every") declared kind, because pevi-G10
  //    declares two alternatives (Form OR a specific type of enchantment) and
  //    either satisfies it; every other entry declares exactly one kind, so
  //    this collapses to "mandatory" for them.
  if (effect.openSlots.isNotEmpty) {
    final filled = effect.openSlots
        .any((kind) => (chosenSlots[kind.name] ?? '').isNotEmpty);
    if (!filled) {
      final kindNames = effect.openSlots.length == 1
          ? _openSlotDescription(effect.openSlots.single)
          : effect.openSlots.map(_openSlotDescription).join(' or a ');
      problems.add('Choose a $kindNames for this guideline');
    }
  }

  // 7. The converse of check 6: stray chosen-slot data for a kind this
  //    guideline never declared open is silently meaningless, the same
  //    class of bug check 2 closes for a stray chosenBaseLevel.
  final openKindNames = effect.openSlots.map((k) => k.name).toSet();
  for (final kind in chosenSlots.keys) {
    if (!openKindNames.contains(kind)) {
      problems.add('A chosen $kind applies only to a guideline with an open $kind slot');
    }
  }
```

Add the small formatting helper near the top of the file, beside `validateSpellAgainstCatalog`:

```dart
/// Human-readable phrasing for an [OpenSlotKind] in a check-6 message.
/// [OpenSlotKind.specificType] reads as "a specific type of enchantment" to
/// match the rulebook's own phrasing rather than the bare enum name.
String _openSlotDescription(OpenSlotKind kind) {
  switch (kind) {
    case OpenSlotKind.realm:
      return 'realm';
    case OpenSlotKind.form:
      return 'Form';
    case OpenSlotKind.specificType:
      return 'specific type of enchantment';
  }
}
```

Now add the `chosenSlots` field to `Spell` and `SpellDraft`. In the `Spell` class, beside `chosenBaseLevel`:

```dart
  /// Slots this spell's guideline declared open, filled in — realm, Form, or
  /// "a specific type", keyed by [OpenSlotKind.name]. Filled by the importer
  /// for a published spell whose prose commits to a value, or by the caster
  /// via [SpellCreationBloc]'s `OpenSlotChosen` otherwise. Empty when the
  /// guideline declares nothing open.
  final Map<String, String> chosenSlots;
```

In `Spell`'s constructor, add `this.chosenSlots = const {},` beside `this.chosenBaseLevel,`. In `toMap()`, add `'chosenSlots': chosenSlots,` beside `'chosenBaseLevel': chosenBaseLevel,`. In `fromMap()`, add:

```dart
        chosenSlots: chosenSlotsFromMap(map['chosenSlots'] as Map<String, dynamic>?),
```

right after the `chosenBaseLevel:` line.

For `SpellDraft`: add `Map<String, String> chosenSlots;` beside `int? chosenBaseLevel;`, add `Map<String, String>? chosenSlots,` to the constructor parameter list and `chosenSlots = chosenSlots ?? {},` to the initializer list (beside `requisites = requisites ?? {},`). In `toSpell()`, pass `chosenSlots: chosenSlots,` beside `chosenBaseLevel: chosenBaseLevel,`. In `copyWith()`, add `Map<String, String>? chosenSlots,` to the parameter list and `chosenSlots: chosenSlots ?? this.chosenSlots,` to the returned `SpellDraft(...)` call — plain-nullable, not `_unset`-sentinel-gated, matching `selectedModifiers`'/`requisites`' own `copyWith` treatment (a map field is always replaced wholesale or kept, never explicitly nulled).

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/models/spell_test.dart`
Expected: PASS

- [ ] **Step 9: Run the full Dart test suite to confirm nothing else broke**

Run: `flutter test`
Expected: PASS, same count as before this task plus the new tests.

- [ ] **Step 10: Commit**

```bash
git add lib/models/base_effect.dart lib/models/spell.dart test/models/base_effect_test.dart test/models/spell_test.dart
git commit -m "feat: add OpenSlotKind/openSlots and chosenSlots, checks 6/7"
```

---

### Task 2: `SpellTemplate.chosenSlots`, `ResolvedSpell`/`ResolvedTemplate` wiring, `BackupService` version bump

**Files:**
- Modify: `lib/models/spell_template.dart`
- Modify: `lib/models/resolved_spell.dart`
- Modify: `lib/models/resolved_template.dart`
- Modify: `lib/engine/spell_engine.dart`
- Modify: `lib/data/services/backup_service.dart`
- Test: `test/models/spell_template_test.dart`
- Test: `test/models/resolved_spell_test.dart`
- Test: `test/models/resolved_template_test.dart`
- Test: `test/data/services/backup_service_test.dart`

**Interfaces:**
- Consumes: `OpenSlotKind`, `chosenSlotsFromMap` (Task 1, `base_effect.dart`); `Spell.chosenSlots`, `validateSpellAgainstCatalog`'s `chosenSlots` parameter (Task 1, `spell.dart`).
- Produces: `SpellTemplate.chosenSlots` (`Map<String, String>`, default `{}`); `ResolvedSpell.chosenSlots`, `ResolvedTemplate.chosenSlots` pass-through getters; `BackupService._supportedVersion == '4.0'`.

- [ ] **Step 1: Write a failing test for `SpellTemplate.chosenSlots`**

Add to `test/models/spell_template_test.dart`, alongside its existing `requisites` round-trip test:

```dart
    test('chosenSlots defaults to empty and round-trips', () {
      final template = SpellTemplate(
        id: 't-1', name: 'Test Template', baseEffectId: 'e1',
        rangeId: 'p1', durationId: 'p2', targetId: 'p3',
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      expect(template.chosenSlots, isEmpty);

      final withSlot = SpellTemplate(
        id: 't-2', name: 'Test Ward', baseEffectId: 'e1',
        rangeId: 'p1', durationId: 'p2', targetId: 'p3',
        chosenSlots: const {'realm': 'Faerie'},
        provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      );
      expect(SpellTemplate.fromMap(withSlot.toMap()).chosenSlots, {'realm': 'Faerie'});
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/spell_template_test.dart`
Expected: FAIL — `chosenSlots` undefined.

- [ ] **Step 3: Implement `SpellTemplate.chosenSlots`**

In `lib/models/spell_template.dart`, add the import:

```dart
import 'package:eruditus/models/base_effect.dart' show chosenSlotsFromMap;
```

Add the field beside `requisites`:

```dart
  /// Slots this template's guideline declared open, already filled in where
  /// the published spell's own prose commits to a value — see
  /// [Spell.chosenSlots]'s doc comment. May stay empty for a declared-open
  /// kind when the corpus text genuinely doesn't commit to one; a template
  /// carries no write-boundary validation, so this is tolerated (the caster
  /// fills it via `OpenSlotChosen` when instantiating).
  final Map<String, String> chosenSlots;
```

Add `this.chosenSlots = const {},` to the constructor (beside `this.requisites = const {},`). Add `'chosenSlots': chosenSlots,` to `toMap()` (beside `'requisites': requisitesToMap(requisites),`). Add to `fromMap()`:

```dart
        chosenSlots: chosenSlotsFromMap(map['chosenSlots'] as Map<String, dynamic>?),
```

right after the `requisites:` line.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/models/spell_template_test.dart`
Expected: PASS

- [ ] **Step 5: Write failing tests for `ResolvedSpell`/`ResolvedTemplate` pass-throughs and `problems` wiring**

Add to `test/models/resolved_spell_test.dart`:

```dart
  test('chosenSlots passes through from the record', () {
    final spell = Spell(
      id: 's-1', baseEffectId: 'e1', rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      requisites: const {},
      chosenSlots: const {'realm': 'Divine'},
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final resolved = ResolvedSpell(record: spell);
    expect(resolved.chosenSlots, {'realm': 'Divine'});
  });

  test('problems reports check 6 when the resolved base effect declares an unfilled open slot', () {
    final effect = BaseEffect(
      id: 'revi-G1', technique: 'Rego', form: 'Vim',
      description: 'Ward against beings from one realm', baseLevel: null,
      openSlots: const [OpenSlotKind.realm],
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final spell = Spell(
      id: 's-2', baseEffectId: effect.id, rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      requisites: const {},
      chosenBaseLevel: 20,
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );
    final resolved = ResolvedSpell(record: spell, baseEffect: effect);
    expect(resolved.problems, contains('Choose a realm for this guideline'));
  });
```

Add to `test/models/resolved_template_test.dart`:

```dart
  test('chosenSlots passes through from the record', () {
    final template = SpellTemplate(
      id: 't-1', name: 'Test Ward', baseEffectId: 'e1',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      chosenSlots: const {'realm': 'Magic'},
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final resolved = ResolvedTemplate(record: template);
    expect(resolved.chosenSlots, {'realm': 'Magic'});
  });
```

(Check both test files' existing imports already cover `Spell`/`SpellTemplate`/`BaseEffect`/`OpenSlotKind`/`Provenance`/`PublicationSource`/`Citation` — add any missing import rather than assuming.)

- [ ] **Step 6: Run the tests to verify they fail**

Run: `flutter test test/models/resolved_spell_test.dart test/models/resolved_template_test.dart`
Expected: FAIL — `chosenSlots` getter undefined on both, and `problems` doesn't yet see check 6 (the call site doesn't pass `chosenSlots` yet).

- [ ] **Step 7: Implement the pass-throughs and wire both `validateSpellAgainstCatalog` call sites**

In `lib/models/resolved_spell.dart`, add the getter beside `requisites`:

```dart
  Map<String, String> get chosenSlots => record.chosenSlots;
```

Update the `problems` getter's call to `validateSpellAgainstCatalog` to add `chosenSlots: record.chosenSlots,` beside `chosenBaseLevel: record.chosenBaseLevel,`.

In `lib/models/resolved_template.dart`, add the getter beside `requisites`:

```dart
  Map<String, String> get chosenSlots => record.chosenSlots;
```

In `lib/engine/spell_engine.dart`, find the `validateSpellAgainstCatalog(...)` call inside `validateSpellDraft` (around the existing `requisites: draft.requisites,` line) and add `chosenSlots: draft.chosenSlots,` beside it.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/models/resolved_spell_test.dart test/models/resolved_template_test.dart`
Expected: PASS

- [ ] **Step 9: Write a failing test for the `BackupService` version bump**

`test/data/services/backup_service_test.dart` already asserts the version string in 5 places, all currently `'3.0'`. Change all 5 occurrences to `'4.0'`:

```bash
```

(No new test needed — this is a value change in existing assertions, not a new behavior. Use `Edit` with `replace_all: true` on the literal `'3.0'` across the file.)

- [ ] **Step 10: Run the test to verify it fails**

Run: `flutter test test/data/services/backup_service_test.dart`
Expected: FAIL — the test file now expects `'4.0'`, but `BackupService._supportedVersion` still reads `'3.0'`.

- [ ] **Step 11: Bump `_supportedVersion`**

In `lib/data/services/backup_service.dart`:

```dart
  static const String _supportedVersion = '4.0';
```

- [ ] **Step 12: Run the test to verify it passes**

Run: `flutter test test/data/services/backup_service_test.dart`
Expected: PASS

- [ ] **Step 13: Run the full Dart test suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 14: Commit**

```bash
git add lib/models/spell_template.dart lib/models/resolved_spell.dart lib/models/resolved_template.dart lib/engine/spell_engine.dart lib/data/services/backup_service.dart test/models/spell_template_test.dart test/models/resolved_spell_test.dart test/models/resolved_template_test.dart test/data/services/backup_service_test.dart
git commit -m "feat: wire chosenSlots through SpellTemplate/Resolved*, bump backup version to 4.0"
```

---

### Task 3: `OpenSlotChosen` bloc event, pruning, template instantiation

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_event.dart`
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart`
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `SpellDraft.chosenSlots`, `BaseEffect.openSlots` (Task 1); `ResolvedTemplate.chosenSlots` (Task 2).
- Produces: `OpenSlotChosen(String kind, String value)` event; `SpellCreationBloc` handler that sets `state.draft.chosenSlots[kind] = value`.

- [ ] **Step 1: Write failing tests for `OpenSlotChosen` and pruning**

Add to `test/bloc/spell_creation_bloc_test.dart`, as a new `group` right after the existing `'General guideline level (ChosenBaseLevelChanged / generalEffectSentence)'` group, reusing that group's `wardGuideline` fixture (extend it, or add a sibling fixture with `openSlots` set — add a new one so the existing group's fixture and its tests stay untouched):

```dart
  group('Open slots (OpenSlotChosen)', () {
    final realmSlotGuideline = BaseEffect(
      id: 'revi-G1', technique: 'Rego', form: 'Vim',
      description: 'Ward against beings from one realm', baseLevel: null,
      openSlots: const [OpenSlotKind.realm],
      reference: const ParameterTriple(
          rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle'),
      provenance: Provenance(source: PublicationSource.published,
          citations: [Citation(bookId: 'arm5-core')]),
      effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'OpenSlotChosen sets the named key in draft.chosenSlots',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(realmSlotGuideline))
        ..add(const OpenSlotChosen('realm', 'Infernal')),
      verify: (bloc) => expect(bloc.state.draft.chosenSlots, {'realm': 'Infernal'}),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'selecting a different base effect prunes chosenSlots keys the new effect does not declare open',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(realmSlotGuideline))
        ..add(const OpenSlotChosen('realm', 'Infernal'))
        ..add(BaseEffectSelected(creoIgnemEffect)),
      verify: (bloc) => expect(bloc.state.draft.chosenSlots, isEmpty),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'TechniqueSelected clears chosenSlots, same as chosenBaseLevel',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(BaseEffectSelected(realmSlotGuideline))
        ..add(const OpenSlotChosen('realm', 'Infernal'))
        ..add(const TechniqueSelected('Perdo')),
      verify: (bloc) => expect(bloc.state.draft.chosenSlots, isEmpty),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'TemplateInstantiated copies the template chosenSlots onto the new draft',
      build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) {
        final template = SpellTemplate(
          id: 'tpl-1', name: 'Circular Ward against Demons',
          baseEffectId: realmSlotGuideline.id,
          rangeId: 'p1', durationId: 'p2', targetId: 'p3',
          chosenSlots: const {'realm': 'Infernal'},
          provenance: Provenance(source: PublicationSource.published,
              citations: const [Citation(bookId: 'arm5-core')]),
        );
        final resolved = ResolvedTemplate(
          record: template,
          baseEffect: realmSlotGuideline,
          range: rangeParam, duration: durationParam, target: targetParam,
        );
        bloc.add(TemplateInstantiated(resolved));
      },
      verify: (bloc) => expect(bloc.state.draft.chosenSlots, {'realm': 'Infernal'}),
    );
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL — `OpenSlotChosen` is undefined.

- [ ] **Step 3: Add the `OpenSlotChosen` event**

In `lib/bloc/spell_creation/spell_creation_event.dart`, add beside `ChosenBaseLevelChanged`:

```dart
/// The caster's value for one of `BaseEffect.openSlots` — realm, Form, or
/// "a specific type" (see `OpenSlotKind`). [kind] is `OpenSlotKind.name`
/// (`'realm'`, `'form'`, or `'specificType'`); [value] is the chosen string.
class OpenSlotChosen extends SpellCreationEvent {
  final String kind;
  final String value;
  const OpenSlotChosen(this.kind, this.value);
  @override
  List<Object?> get props => [kind, value];
}
```

- [ ] **Step 4: Implement the handler and pruning**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, add the handler beside the `ChosenBaseLevelChanged` branch:

```dart
    } else if (event is OpenSlotChosen) {
      final updated = {...state.draft.chosenSlots, event.kind: event.value};
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(chosenSlots: updated),
      ));
```

Add a small private helper near `_withRitualDeclaration`/`_withPrunedModifiers`:

```dart
  /// Drops any `chosenSlots` entry [effect] no longer declares open — the
  /// map-keyed sibling of `chosenBaseLevel: null`'s clearing above. `null`
  /// [effect] (Technique/Form changed, base effect cleared) drops everything.
  Map<String, String> _prunedSlots(Map<String, String> slots, BaseEffect? effect) {
    if (effect == null) return const {};
    final openKindNames = effect.openSlots.map((k) => k.name).toSet();
    return Map.fromEntries(
      slots.entries.where((entry) => openKindNames.contains(entry.key)),
    );
  }
```

Update the three existing handlers that already clear `chosenBaseLevel` to also prune `chosenSlots`:

In the `TechniqueSelected` branch, change:
```dart
          chosenBaseLevel: null,
          templateId: null,
        )),
```
to:
```dart
          chosenBaseLevel: null,
          templateId: null,
          chosenSlots: const {},
        )),
```

Do the identical change in the `FormSelected` branch.

In the `BaseEffectSelected` branch, add `chosenSlots: _prunedSlots(state.draft.chosenSlots, event.effect),` beside the existing `chosenBaseLevel: event.effect.isGeneral ? state.draft.chosenBaseLevel : null,` line.

In the `TemplateInstantiated` branch, add `chosenSlots: template.chosenSlots,` to the `SpellDraft(...)` construction, beside `templateId: template.id,`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS

- [ ] **Step 6: Run the full Dart test suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_event.dart lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: add OpenSlotChosen event and chosenSlots pruning to SpellCreationBloc"
```

---

### Task 4: Realm dropdown in the creation screen

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart`
- Test: `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: `SpellDraft.chosenSlots`, `BaseEffect.openSlots` (Task 1); `OpenSlotChosen` (Task 3).
- Produces: a `DropdownButtonFormField<String>` keyed `'chosen-realm-field'` (matching the file's existing `'chosen-base-level-field'` naming convention).

This test file mocks the bloc (`MockSpellCreationBloc` via mocktail) rather than running a real one — every test constructs a `SpellCreationState` directly, pumps the screen via the file's existing `pumpScreen(tester, state, {configState})` helper, and asserts either on rendered widgets or on `verify(() => bloc.add(...))`. Do not tap through Technique/Form/base-effect dropdowns to reach a state; construct it directly, mirroring the existing `'chosen base level field (General guidelines)'` group (`spell_creation_screen_test.dart:571-598`).

- [ ] **Step 1: Write failing widget tests for the realm dropdown's visibility and wiring**

Add a `generalRealmEffect` fixture near the file's existing `generalWardEffect` (a sibling, not a mutation — `generalWardEffect` has no `openSlots` and several existing tests depend on that):

```dart
  final generalRealmEffect = BaseEffect(
    id: 'revi-G1', technique: 'Rego', form: 'Vim',
    description: 'Ward against beings from one realm', baseLevel: null,
    openSlots: const [OpenSlotKind.realm],
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );
```

Add a new group, mirroring `'chosen base level field (General guidelines)'`'s shape exactly:

```dart
  group('chosen realm field (open realm slot)', () {
    testWidgets('is absent when the selected base effect declares no open slot', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect),
      );
      await pumpScreen(tester, state);

      expect(find.byKey(const Key('chosen-realm-field')), findsNothing);
    });

    testWidgets('is present when the selected base effect declares an open realm slot',
        (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Rego', form: 'Vim', baseEffect: generalRealmEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalRealmEffect],
          parameters: const [],
        ),
      );

      expect(find.byKey(const Key('chosen-realm-field')), findsOneWidget);
    });

    testWidgets('picking a realm dispatches OpenSlotChosen', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Rego', form: 'Vim', baseEffect: generalRealmEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalRealmEffect],
          parameters: const [],
        ),
      );

      await tester.tap(find.byKey(const Key('chosen-realm-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Infernal').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const OpenSlotChosen('realm', 'Infernal'))).called(1);
    });

    testWidgets('a pre-filled chosenSlots value shows as the initial selection', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(
          technique: 'Rego', form: 'Vim', baseEffect: generalRealmEffect,
          chosenSlots: const {'realm': 'Faerie'},
        ),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, generalRealmEffect],
          parameters: const [],
        ),
      );

      expect(find.text('Faerie'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: FAIL — no widget with key `'chosen-realm-field'` exists yet.

- [ ] **Step 3: Add the realm dropdown**

In `lib/presentation/screens/spell_creation_screen.dart`, immediately after the existing `_GuidelineLevelField`/`generalEffectSentence` block (the `if (draft.baseEffect?.isGeneral ?? false) ...[...]` block), add:

```dart
                if (draft.baseEffect?.openSlots.contains(OpenSlotKind.realm) ?? false) ...[
                  const SizedBox(height: 8),
                  // ValueKey forces a fresh Element (and a fresh initialValue
                  // read) whenever the chosen realm changes out from under
                  // this field -- e.g. TemplateInstantiated setting a new
                  // pre-filled value while this screen's widget state
                  // survives underneath main.dart's IndexedStack. A dropdown
                  // has no in-progress typing state to lose, unlike
                  // _GuidelineLevelField's text field, so a full StatefulWidget
                  // isn't needed here -- keying by value is sufficient.
                  DropdownButtonFormField<String>(
                    key: ValueKey('chosen-realm-field-${draft.chosenSlots['realm']}'),
                    decoration: const InputDecoration(labelText: 'Realm'),
                    initialValue: draft.chosenSlots['realm'],
                    items: const ['Divine', 'Faerie', 'Infernal', 'Magic']
                        .map((realm) => DropdownMenuItem(value: realm, child: Text(realm)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) bloc.add(OpenSlotChosen('realm', value));
                    },
                  ),
                ],
```

Add the import if not already present:

```dart
import 'package:eruditus/models/base_effect.dart';
```

(Likely already imported for `BaseEffect` itself — verify before adding a duplicate.)

Step 1's tests find the field via `find.byKey(const Key('chosen-realm-field'))` (a plain `Key`), but the widget above uses `ValueKey('chosen-realm-field-${draft.chosenSlots['realm']}')` (e.g. `'chosen-realm-field-null'` when unset). These are different key identities — `find.byKey` would find nothing. Change every `find.byKey(const Key('chosen-realm-field'))` in Step 1's tests to `find.byWidgetPredicate((w) => w is DropdownButtonFormField<String> && (w.key as ValueKey).value.toString().startsWith('chosen-realm-field'))` instead — the value-suffixed key is deliberate (see the widget's own comment) and the test needs to match it structurally, not by exact key equality.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Run the full Dart test suite, then integration tests**

Run: `flutter test`
Run: `flutter test integration_test/ -d windows`
Expected: both PASS — the new field is additive and gated, so no existing flow's widget tree changes shape.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/spell_creation_screen.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: add realm dropdown to the spell creation screen"
```

---

### Task 5: Python catalog — `openSlots` on the 17 realm entries, `Catalog.open_slots`

**Files:**
- Modify: `assets/data/base_effects.json`
- Modify: `scripts/spell_import/catalog.py`
- Test: `scripts/spell_import/tests/test_catalog.py`

**Interfaces:**
- Produces: `Catalog.open_slots(effect_id: str) -> list[str]` — returns the `openSlots` list for a base effect id (empty list if the key is absent or the id is unknown to the raw list itself — an unknown id is a caller bug elsewhere, not this method's job to catch, matching `reference_cost`'s existing "raise on unknown id" precedent... note: mirror `reference_cost`'s KeyError-on-unknown-id behavior exactly, do not silently return `[]` for an unknown id).

- [ ] **Step 1: Write a failing test for `Catalog.open_slots`**

Add to `scripts/spell_import/tests/test_catalog.py`, in whatever class already covers `reference_cost`-style lookups (or a new `class OpenSlotsTest(unittest.TestCase):` if none fits):

```python
    def test_open_slots_returns_the_annotated_list(self):
        catalog = catalog_module.Catalog(
            base_effects=[
                {"id": "revi-G1", "technique": "Rego", "form": "Vim",
                 "baseLevel": None, "openSlots": ["realm"]},
            ],
            parameters=[], modifiers=[],
        )
        self.assertEqual(catalog.open_slots("revi-G1"), ["realm"])

    def test_open_slots_defaults_to_empty_when_the_key_is_absent(self):
        catalog = catalog_module.Catalog(
            base_effects=[
                {"id": "crig-10a", "technique": "Creo", "form": "Ignem",
                 "baseLevel": 10},
            ],
            parameters=[], modifiers=[],
        )
        self.assertEqual(catalog.open_slots("crig-10a"), [])

    def test_open_slots_raises_on_an_unknown_id(self):
        catalog = catalog_module.Catalog(base_effects=[], parameters=[], modifiers=[])
        with self.assertRaises(KeyError):
            catalog.open_slots("does-not-exist")
```

(Match this test file's existing import alias for the `catalog` module — check its top-of-file `from .. import catalog as catalog_module` or equivalent before assuming the name.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `python -m unittest scripts.spell_import.tests.test_catalog -v`
Expected: FAIL — `open_slots` is undefined.

- [ ] **Step 3: Implement `Catalog.open_slots`**

In `scripts/spell_import/catalog.py`, add beside `reference_cost`:

```python
    def open_slots(self, effect_id: str) -> list[str]:
        """The `OpenSlotKind` names this guideline declares open, or `[]`.

        Mirrors `reference_cost`'s lookup shape: an unknown id is a caller
        bug, not a "no slots" answer, so it raises rather than defaulting.
        """
        effect = next((e for e in self.base_effects if e["id"] == effect_id), None)
        if effect is None:
            raise KeyError(f"no base effect with id {effect_id!r} in base_effects.json")
        return effect.get("openSlots") or []
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python -m unittest scripts.spell_import.tests.test_catalog -v`
Expected: PASS

- [ ] **Step 5: Annotate the 17 realm entries in `base_effects.json`**

Add `"openSlots": ["realm"]` to each of these 17 entries (verified present with this exact shape during planning): `rean-gen`, `rean-gen-2`, `reaq-gen`, `reau-gen`, `reco-gen`, `rehe-gen`, `reig-gen`, `reim-G`, `reme-G`, `reme-G2`, `rete-G`, `pevi-G6`, `pevi-G12`, `pevi-G5`, `revi-G1`, `revi-5`, `revi-15`. Preserve the file's existing one-line-per-entry format (see commit `021cd87`, "fix: restore base_effects.json to its committed one-line-per-entry format" — do not let an editor's auto-formatter reflow the file).

- [ ] **Step 6: Verify every id was found and the JSON is still valid**

Run:
```bash
python -c "
import json
data = json.load(open('assets/data/base_effects.json', encoding='utf-8'))
ids = ['rean-gen','rean-gen-2','reaq-gen','reau-gen','reco-gen','rehe-gen','reig-gen','reim-G','reme-G','reme-G2','rete-G','pevi-G6','pevi-G12','pevi-G5','revi-G1','revi-5','revi-15']
by_id = {e['id']: e for e in data}
missing = [i for i in ids if i not in by_id or by_id[i].get('openSlots') != ['realm']]
assert not missing, f'not annotated: {missing}'
print('all 17 annotated')
"
```
Expected: prints `all 17 annotated`, no assertion error.

- [ ] **Step 7: Run the Python suite**

Run: `python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add assets/data/base_effects.json scripts/spell_import/catalog.py scripts/spell_import/tests/test_catalog.py
git commit -m "feat: annotate the 17 realm-slot catalog entries, add Catalog.open_slots"
```

---

### Task 6: Realm resolution table and importer wiring

**Files:**
- Modify: `scripts/spell_import/extract_spells.py`
- Modify: `scripts/spell_import/emit.py`
- Test: `scripts/spell_import/tests/test_emit.py`

**Interfaces:**
- Consumes: `Catalog.open_slots` (Task 5).
- Produces: `REALM_BY_SPELL_ID: dict[str, str]` (`extract_spells.py`); `build_spell`/`build_template` set `chosenSlots["realm"]` when applicable.

- [ ] **Step 1: Write failing tests for the emit-side wiring**

This file's existing convention (see `GeneralTemplateEmissionTest`, `test_emit.py:291-351`) is a module-level `_block(name, technique, form, level, prose="Test prose.")` helper (fixed `Touch`/`Sun`/`Ind` stat line — irrelevant to `chosenSlots`), `designline.parse_design(design_text)` for the design, and the **real, disk-loaded** catalog via `catalog_module.Catalog.load()` in `setUpClass` — not a synthetic `Catalog(...)`. Task 5 already annotated `revi-G1` and `pevi-G5` with `openSlots: ["realm"]` in the real `base_effects.json`, so this test can use them directly. Add a new class, mirroring `GeneralTemplateEmissionTest`'s shape exactly:

```python
class OpenSlotEmissionTest(unittest.TestCase):
    """`chosenSlots["realm"]` is set from `REALM_BY_SPELL_ID`, never scanned
    from prose -- see extract_spells.py's `REALM_BY_SPELL_ID` comment for why.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def test_build_template_sets_chosenSlots_when_the_table_has_an_entry(self):
        design = designline.parse_design("(As ward guideline, +1 Touch, +1 Ring)")
        block = _block("Circular Ward against Demons", "Rego", "Vim", None)
        template = emit.build_template(
            block, "revi-G1", self.catalog, design,
            realm_by_spell_id={"lib-revi-circular-ward-against-demons": "Infernal"},
        )
        self.assertEqual(template["chosenSlots"], {"realm": "Infernal"})

    def test_build_template_omits_chosenSlots_when_the_table_has_no_entry(self):
        design = designline.parse_design("(Base effect, +2 Voice, +2 Room)")
        block = _block("Wind of Mundane Silence", "Perdo", "Vim", None)
        template = emit.build_template(
            block, "pevi-G5", self.catalog, design, realm_by_spell_id={},
        )
        self.assertNotIn("chosenSlots", template)

    def test_build_template_omits_chosenSlots_when_the_effect_declares_no_open_slot(self):
        # pevi-G3 has no openSlots at all -- a table entry, if one existed,
        # must not leak onto a guideline that never declared anything open.
        design = designline.parse_design("(Base spell, +1 Touch, +2 Sun)")
        block = _block("Demon's Eternal Oblivion", "Perdo", "Vim", None)
        template = emit.build_template(
            block, "pevi-G3", self.catalog, design,
            realm_by_spell_id={"lib-pede-demons-eternal-oblivion": "Infernal"},
        )
        self.assertNotIn("chosenSlots", template)

    def test_realm_by_spell_id_defaults_to_empty_when_omitted(self):
        design = designline.parse_design("(As ward guideline, +1 Touch, +1 Ring)")
        block = _block("Circular Ward against Demons", "Rego", "Vim", None)
        template = emit.build_template(block, "revi-G1", self.catalog, design)
        self.assertNotIn("chosenSlots", template)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_emit -v`
Expected: FAIL — `build_template` doesn't accept `realm_by_spell_id` yet (every test in this class fails, including the last one's no-argument call, once Step 5 gives the parameter a default rather than making it required).

- [ ] **Step 3: Give `build_spell`/`build_template` an optional `realm_by_spell_id` parameter, defaulted, before touching `extract_spells.py`**

This keeps every pre-existing `test_emit.py` call site (`AdjustmentEmissionTest`, `ElaborateEffectEmissionTest`, `ModifierOptionTableTest`, `DescriptionEmissionTest`, `GeneralTemplateEmissionTest`, `PrintedLevelEmissionTest`, `RequisiteEmissionTest` — none of which care about realm) working unchanged; only `extract_spells.py`'s two real call sites pass it explicitly. See Step 4 for the signature.

- [ ] **Step 4: Add `REALM_BY_SPELL_ID` to `extract_spells.py`**

Add beside `KNOWN_UNRESOLVABLE`:

```python
# Realm for every corpus spell built on a guideline whose `openSlots` includes
# "realm" -- verified once against the rulebook's own prose (Decision 7/9/10,
# docs/superpowers/specs/2026-08-10-open-guideline-slots-design.md), never
# inferred at build time. A prose scan was tried first and rejected: two of
# these spells ("Ward against Faeries of the Air"/"...of the Wood") restate
# their realm only by cross-referencing "Ward against Faeries of the Waters"
# by name, and Wind of Mundane Silence's only "Magic" occurrences are "Magic
# Resistance"/"Magical things" -- neither a realm commitment, which is exactly
# why it has no entry here (its template imports with chosenSlots: {} and the
# caster fills the realm in later, same as any case-2 spell).
REALM_BY_SPELL_ID = {
    "lib-revi-circular-ward-against-demons": "Infernal",
    "lib-rean-ward-against-beasts-legend": "Magic",
    "lib-reaq-ward-against-faeries-waters": "Faerie",
    "lib-reau-ward-against-faeries-air": "Faerie",
    "lib-rehe-ward-against-faeries-wood": "Faerie",
    "lib-reme-ring-warding-against-spirits": "Magic",
}
```

Thread it through the two `emit.build_template`/`emit.build_spell` call sites (the ones this file's own `blocked.append`/`templates.append`/`spells.append` orchestration already makes — Step 5 adds the `realm_by_spell_id` keyword to both). At the `emit.build_template(block, base_effect_id, catalog, design)` call (General-guideline branch), change to:

```python
                templates.append(emit.build_template(
                    block, base_effect_id, catalog, design,
                    realm_by_spell_id=REALM_BY_SPELL_ID,
                ))
```

At the `emit.build_spell(block, base_effect_id, catalog, design)` call (fixed-level branch), change to:

```python
            spells.append(emit.build_spell(
                block, base_effect_id, catalog, design,
                realm_by_spell_id=REALM_BY_SPELL_ID,
            ))
```

- [ ] **Step 5: Wire `build_spell`/`build_template` in `emit.py`**

Add the optional parameter and the `chosenSlots` assembly to both functions. In `build_template`'s signature:

```python
def build_template(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
    realm_by_spell_id: dict[str, str] | None = None,
) -> dict:
```

`build_template` already computes `slug = catalog_module.slug_id(block.technique, block.form, block.name)` at its line 171, before the `template = {...}` dict literal — the table lookup below reuses that same variable, nothing new to compute. Immediately after that existing `slug = ...` line:

```python
    realm_by_spell_id = realm_by_spell_id or {}
    chosen_slots: dict[str, str] = {}
    if "realm" in catalog.open_slots(base_effect_id):
        realm = realm_by_spell_id.get(slug)
        if realm is not None:
            chosen_slots["realm"] = realm
```

Add this statement after the `template = {...}` dict literal, grouped with the other conditional-key statements (`description`, `citations`, `adjustments`, `ritualDeclaration`) already there:

```python
    if chosen_slots:
        template["chosenSlots"] = chosen_slots
```

Do the analogous change to `build_spell`: add the same optional `realm_by_spell_id: dict[str, str] | None = None,` parameter. Unlike `build_template`, `build_spell` has no pre-existing `slug` local — its `"id"` key is computed inline in the `spell = {...}` literal — so add `slug = spell["id"]` as the first line after that literal, then the identical `realm_by_spell_id = realm_by_spell_id or {}` / `chosen_slots` block and the same conditional `if chosen_slots: spell["chosenSlots"] = chosen_slots` statement grouped with `build_spell`'s existing conditional statements (`description`, `citations`, `adjustments`, `ritualDeclaration`).

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_emit -v`
Expected: PASS

- [ ] **Step 7: Run the full Python suite**

Run: `python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`
Expected: PASS — every pre-existing `build_spell`/`build_template` call site in this suite omits `realm_by_spell_id` and keeps working unchanged, since Step 5 made it optional.

- [ ] **Step 8: Commit**

```bash
git add scripts/spell_import/extract_spells.py scripts/spell_import/emit.py scripts/spell_import/tests/test_emit.py
git commit -m "feat: resolve realm via a hand-verified table, wire into build_spell/build_template"
```

---

### Task 7: Regenerate assets and verify

**Files:**
- Modify: `assets/data/spell_library.json`
- Modify: `assets/data/spell_templates.json`
- Modify: `scripts/spell_import/import_report.md` (if the regeneration flow writes one)

**Interfaces:**
- Consumes: everything from Tasks 5 and 6.

- [ ] **Step 1: Run the importer's write flow**

Run whatever command this project's existing regeneration flow uses (check `scripts/spell_import/extract_spells.py --help` for the exact flag names — the design spec's Global Constraints call it `--write`, without `--accept-source` since `source.lock`'s pinned revision is unchanged):

```bash
python -m scripts.spell_import.extract_spells --write
```

- [ ] **Step 2: Verify the diff is exactly the expected shape**

Run: `git diff --stat assets/data/spell_library.json assets/data/spell_templates.json`

Expected: `spell_library.json` unchanged (0 insertions/deletions — none of the 6 table entries are `build_spell`-shaped, fixed-level spells); `spell_templates.json` shows exactly 6 changed entries, each gaining one `"chosenSlots": {"realm": "..."}` line, no entries added or removed (still 23 templates), no other field touched.

- [ ] **Step 3: Verify the counts and blocked list are unaffected**

Run: `python -m scripts.spell_import.extract_spells --show-blocked`

Expected: `imported : 294`, `templates: 23`, `blocked : 43`, `unresolved: 0` — identical to the counts recorded before this plan (Global Constraints: Part A changes no count). Confirm `Wind of Mundane Silence` does not appear in the blocked list (it was never blocked, and still isn't — Decision 9 means it simply imports with `chosenSlots: {}`).

- [ ] **Step 4: Verify the 7 real entries individually**

Run:
```bash
python -c "
import json, sys
sys.stdout.reconfigure(encoding='utf-8')
tpl = json.load(open('assets/data/spell_templates.json', encoding='utf-8'))
by_name = {t['name']: t for t in tpl}
expected = {
    'Circular Ward against Demons': {'realm': 'Infernal'},
    'Ward against the Beasts of Legend': {'realm': 'Magic'},
    'Ward against Faeries of the Waters': {'realm': 'Faerie'},
    'Ward against Faeries of the Air': {'realm': 'Faerie'},
    'Ward against Faeries of the Wood': {'realm': 'Faerie'},
    'Ring of Warding against Spirits': {'realm': 'Magic'},
}
for name, want in expected.items():
    got = by_name[name].get('chosenSlots')
    assert got == want, f'{name}: expected {want}, got {got}'
wind = by_name['Wind of Mundane Silence']
assert wind.get('chosenSlots', {}) == {}, wind.get('chosenSlots')
print('all 7 verified')
"
```
Expected: prints `all 7 verified`.

- [ ] **Step 5: Run the full Dart test suite against the regenerated assets**

Run: `flutter test`
Expected: PASS — including any test that loads `spell_templates.json`/`spell_library.json` and asserts on its entry count or structure (e.g. `asset_data_loader_test.dart`); if any such test hardcodes an unrelated assumption the new `chosenSlots` field's presence breaks, fix that test's fixture, not the asset.

- [ ] **Step 6: Run the integration suite**

Run: `flutter test integration_test/ -d windows`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add assets/data/spell_library.json assets/data/spell_templates.json scripts/spell_import/import_report.md
git commit -m "chore: regenerate spell assets with realm chosenSlots"
```

---

## Self-Review Notes

- **Spec coverage:** Data model (Task 1), checks 6/7 (Task 1), `SpellTemplate`/`ResolvedSpell`/`ResolvedTemplate` wiring (Task 2), backup version bump (Task 2), bloc event + pruning + template instantiation (Task 3), UI (Task 4), catalog annotation (Task 5), realm resolution + import wiring (Task 6), asset regeneration + verification (Task 7) — every subsection of the design spec's "Design" section maps to a task. Form/specificType and the case-2 spells are explicitly out of scope (Global Constraints), matching the spec's Part A/B split.
- **Type consistency:** `chosenSlots` is `Map<String, String>` everywhere it appears (Task 1's `Spell`/`SpellDraft`, Task 2's `SpellTemplate`/`ResolvedSpell`/`ResolvedTemplate`, Task 3's bloc, Task 4's UI) — no task introduces a conflicting shape. `OpenSlotKind.name` string keys (`'realm'`) are used consistently, never the enum value itself, in every map.
- **No placeholders:** every step carries real, complete code or an exact command, verified against the actual current contents of every file it touches during planning (not assumed) — including two corrections this caught before they reached an implementer: Task 4's UI tests were rewritten from a tap-through-dropdowns draft to match the file's real mocked-bloc/`pumpScreen`/`verify()` convention, and Task 6's emit tests were rewritten from a synthetic-`Catalog` draft to match the file's real `Catalog.load()`/`_block`/`designline.parse_design` convention, with `realm_by_spell_id` made optional so no pre-existing call site needs touching.
