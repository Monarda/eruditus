# Base Effect Analogy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a `Spell`/`SpellTemplate` reference a base effect from a different Technique/Form than its own, explicitly marked with a required rationale, so a spell built "by analogy" to a Vim guideline displays and validates under its own real Technique/Form instead of the borrowed one.

**Architecture:** `Spell` and `SpellTemplate` gain two required fields (`technique`, `form` — the record's own, no longer derived from the catalog) and one optional field (`analogyRationale` — required non-null exactly when those differ from the resolved base effect's own technique/form). `ResolvedSpell`/`ResolvedTemplate` read the stored fields instead of deriving them. `validateSpellAgainstCatalog` gains an 8th check enforcing the rationale invariant. The Python importer emits the two new fields on every entry and threads through an (unused for now) analogy-rationale parameter.

**Tech Stack:** Dart/Flutter (`lib/models`, `lib/engine`), Python 3 (`scripts/spell_import`), JSON assets.

## Global Constraints

- **Backwards compatibility is not a goal.** `technique`/`form` are required, non-nullable fields on `Spell` and `SpellTemplate`. No migration path — a local database missing them is dropped and rebuilt.
- **No catalog changes.** `assets/data/base_effects.json` is untouched by this plan.
- **`analogyRationale` stays unset (null) everywhere in this plan.** No published spell uses analogy yet (see the spec's "Explicitly not in scope") — every Python call site passes `analogy_rationale=None`, and no Dart construction site sets a non-null value except where a test specifically exercises the new check.
- **Full three-suite verification after every task**: `python -m unittest discover -p "test_*.py"` (from repo root, with `ARS_RULEBOOK_ROOT` set), `flutter test`, and (final task only) the Windows integration suite.
- **`ARS_RULEBOOK_ROOT` env var** must be set to the sibling rulebook checkout before any Python command: `C:/Development/personal/Ars-Magica-Open-License`.
- **Commit trailer:** `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- **Regenerate assets, never hand-edit them.** `assets/data/spell_library.json`/`spell_templates.json` are only ever touched via `python -m scripts.spell_import.extract_spells --write`.

---

### Task 1: `Spell`/`SpellTemplate` gain `technique`/`form`/`analogyRationale`

This is the one unavoidably large task in this plan: Dart's `required` named parameters make this an all-or-nothing change — every direct `Spell(...)`/`SpellTemplate(...)` construction across the repo must gain the two new arguments in the same commit, or nothing compiles. There are 70 such sites across 19 files (2 of them the classes' own `fromMap`/`toSpell` factories). All 70 are enumerated below with the exact value to use — no site is left to judgement.

**Files:**
- Modify: `lib/models/spell.dart` (`Spell` class, `SpellDraft.toSpell`)
- Modify: `lib/models/spell_template.dart` (`SpellTemplate` class)
- Modify (mechanical, exact sites listed below): `test/models/spell_test.dart`, `test/models/spell_template_test.dart`, `test/models/resolved_spell_test.dart`, `test/models/resolved_template_test.dart`, `test/bloc/spell_creation_bloc_test.dart`, `test/bloc/spell_library_bloc_test.dart`, `test/data/datasources/local_spell_datasource_test.dart`, `test/data/repositories/library_repository_test.dart`, `test/data/repositories/spell_repository_test.dart`, `test/data/services/backup_service_test.dart`, `test/data/spell_resolver_test.dart`, `test/engine/spell_engine_test.dart`, `test/presentation/screens/backup_screen_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`, `test/presentation/screens/spell_library_screen_test.dart`, `test/presentation/widgets/spell_card_test.dart`, `integration_test/spell_creation_flow_test.dart`

**Interfaces:**
- Produces: `Spell.technique` (`String`, required), `Spell.form` (`String`, required), `Spell.analogyRationale` (`String?`, optional, defaults to `null`). Identically on `SpellTemplate`. Both remain unread by `validateSpellAgainstCatalog` until Task 3 and by `ResolvedSpell`/`ResolvedTemplate` until Task 2 — this task only adds and threads the data.

- [ ] **Step 1: Add the fields to `Spell`**

In `lib/models/spell.dart`, add two fields to the class declaration (right after `baseEffectId`):

```dart
  final String baseEffectId;
  final String technique;
  final String form;
```

and one after `templateId`:

```dart
  final String? templateId;

  /// Non-null only when [technique]/[form] differ from the resolved base
  /// effect's own technique/form -- the citation-backed reason a human
  /// chose to apply that guideline outside its own Form. Null whenever they
  /// match; enforced by `validateSpellAgainstCatalog`'s check 8 (Task 3).
  final String? analogyRationale;
```

Also update the class doc comment — it currently says technique/form are deliberately never stored:

```dart
/// A saved spell, stored as references into the effect/parameter catalogs.
///
/// This record deliberately holds no copy of any catalog data -- no base
/// level, magnitude. [technique]/[form] are the one exception: they are the
/// spell's own, which may legitimately differ from [baseEffectId]'s own
/// technique/form (see [analogyRationale]) -- so unlike everything else
/// here, they cannot be safely derived and must be stored.
```

In the constructor, add the two required params and the one optional param:

```dart
  Spell({
    required this.id,
    this.name,
    required this.baseEffectId,
    required this.technique,
    required this.form,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    required this.requisites,
    this.adjustments = const [],
    this.summary,
    this.description,
    this.printedLevel,
    required this.provenance,
    this.tags = const [],
    this.ritualDeclaration = RitualDeclaration.none,
    required this.createdAt,
    required this.updatedAt,
    this.chosenBaseLevel,
    this.chosenSlots = const {},
    this.templateId,
    this.analogyRationale,
  }) {
```

In `toMap()`, add both after `'baseEffectId'`:

```dart
        'baseEffectId': baseEffectId,
        'technique': technique,
        'form': form,
```

and `analogyRationale` after `'templateId'`:

```dart
        'templateId': templateId,
        'analogyRationale': analogyRationale,
      };
```

In `Spell.fromMap`, add after `baseEffectId`:

```dart
        baseEffectId: requireField<String>(map, 'baseEffectId', 'Spell'),
        technique: requireField<String>(map, 'technique', 'Spell'),
        form: requireField<String>(map, 'form', 'Spell'),
```

and after `templateId`:

```dart
        templateId: map['templateId'] as String?,
        analogyRationale: map['analogyRationale'] as String?,
      );
```

- [ ] **Step 2: Add the fields to `SpellTemplate`**

In `lib/models/spell_template.dart`, mirror Step 1 exactly:

```dart
  final String baseEffectId;
  final String technique;
  final String form;
```

```dart
  final RitualDeclaration ritualDeclaration;

  /// See [Spell.analogyRationale] -- identical contract.
  final String? analogyRationale;
```

Constructor:

```dart
  SpellTemplate({
    required this.id,
    required this.name,
    required this.baseEffectId,
    required this.technique,
    required this.form,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    this.requisites = const {},
    this.chosenSlots = const {},
    this.adjustments = const [],
    this.summary,
    this.description,
    required this.provenance,
    this.tags = const [],
    this.ritualDeclaration = RitualDeclaration.none,
    this.analogyRationale,
  }) {
```

`toMap()`:

```dart
        'baseEffectId': baseEffectId,
        'technique': technique,
        'form': form,
```

```dart
        'ritualDeclaration': ritualDeclaration.name,
        'analogyRationale': analogyRationale,
      };
```

`fromMap`:

```dart
        baseEffectId: requireField<String>(map, 'baseEffectId', 'SpellTemplate'),
        technique: requireField<String>(map, 'technique', 'SpellTemplate'),
        form: requireField<String>(map, 'form', 'SpellTemplate'),
```

```dart
        ritualDeclaration: map['ritualDeclaration'] == null
            ? RitualDeclaration.none
            : ritualDeclarationFromName(
                requireField<String>(map, 'ritualDeclaration', 'SpellTemplate'), 'SpellTemplate'),
        analogyRationale: map['analogyRationale'] as String?,
      );
```

- [ ] **Step 3: Thread `SpellDraft.technique`/`.form` through to `Spell`**

`SpellDraft` already has nullable `technique`/`form` fields (used today only to filter the creation screen's base-effect picker) but never passes them to the `Spell` it builds. In `lib/models/spell.dart`'s `SpellDraft.toSpell()`:

```dart
  Spell toSpell({required String name, required PublicationSource source}) {
    final missingFields = <String>[
      if (baseEffect == null) 'baseEffect',
      if (technique == null) 'technique',
      if (form == null) 'form',
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
      technique: technique!,
      form: form!,
      rangeId: range!.id,
      durationId: duration!.id,
      targetId: target!.id,
      selectedModifiers: selectedModifiers,
      requisites: requisites,
      adjustments: adjustments,
      summary: summary,
      description: description,
      printedLevel: printedLevel,
      ritualDeclaration: ritualDeclaration,
      chosenBaseLevel: chosenBaseLevel,
      chosenSlots: chosenSlots,
      templateId: templateId,
      analogyRationale: null, // the creation screen cannot produce one yet
      provenance: Provenance(source: source),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
```

- [ ] **Step 4: Run `flutter analyze` to see the full breakage**

Run: `flutter analyze`
Expected: dozens of "missing required argument 'technique'"/"'form'" errors, one per remaining call site below. This is the checklist for the rest of this task.

- [ ] **Step 5: Fix the 9 files needing only the uniform default**

For every `Spell(...)`/`SpellTemplate(...)` construction in these files, add `technique: 'Creo',\n        form: 'Ignem',` (matching the surrounding indentation) immediately after the `baseEffectId:` line. None of these tests read `.technique`/`.form` (directly, via `ResolvedSpell`/`ResolvedTemplate`, or via rendered UI text), so the exact value is not load-bearing — it only needs to be *a* valid, non-empty string pair.

| File | Sites |
|---|---|
| `test/bloc/spell_library_bloc_test.dart` | 7 |
| `test/data/datasources/local_spell_datasource_test.dart` | 1 |
| `test/data/repositories/library_repository_test.dart` | 3 |
| `test/data/repositories/spell_repository_test.dart` | 1 (one helper, reused with varying `baseEffectId`) |
| `test/data/services/backup_service_test.dart` | 6 |
| `test/presentation/screens/backup_screen_test.dart` | 1 |
| `test/presentation/screens/spell_creation_screen_test.dart` | 3 |
| `test/presentation/screens/spell_library_screen_test.dart` | 2 (1 `Spell(`, 1 `SpellTemplate(`) |
| `integration_test/spell_creation_flow_test.dart` | 1 |

Worked example (`test/data/datasources/local_spell_datasource_test.dart`, the helper at line 27):

```dart
Spell buildSpell(String id, {String? name}) => Spell(
      id: id, name: name,
      baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'range-personal', durationId: 'duration-momentary', targetId: 'target-individual',
      requisites: const {},
```

Apply the identical two-line insertion at every other site in the 9 files above (25 sites total).

Run: `flutter analyze test/bloc/spell_library_bloc_test.dart test/data/datasources/local_spell_datasource_test.dart test/data/repositories/library_repository_test.dart test/data/repositories/spell_repository_test.dart test/data/services/backup_service_test.dart test/presentation/screens/backup_screen_test.dart test/presentation/screens/spell_creation_screen_test.dart test/presentation/screens/spell_library_screen_test.dart integration_test/spell_creation_flow_test.dart`
Expected: no "missing required argument" errors remain in these 9 files.

- [ ] **Step 6: Fix `test/presentation/widgets/spell_card_test.dart` (3 sites) — must match `'Creo Ignem'`**

This file asserts on rendered text (`find.textContaining('Creo Ignem')` at lines 77, 215, 270, and `find.text('Untitled Creo Ignem')` at line 96), driven by the file's top-level `effect` fixture (`technique: 'Creo', form: 'Imaginem'`... check the actual fixture: it's `id: 'e1'`, and the file's own `BaseEffect` for it is Creo/Ignem — same values as the uniform default, so this happens to need the same insertion as Step 5, just called out separately because it *is* load-bearing (not incidental) and must not silently drift if the default ever changes:

```dart
final record = Spell(
  id: '1', name: name,
  baseEffectId: effect.id,
  technique: 'Creo',
  form: 'Ignem',
  rangeId: rangeParam.id, durationId: durationParam.id, targetId: targetParam.id,
  requisites: const {}, summary: summary, description: description,
```

Apply at the `buildSpell` helper (line 45) and `buildTemplate` helper (line 193). The third site (line 143, the "orphan"/unresolved-spell fixture with `baseEffectId: 'deleted-custom-effect'`) renders no technique/form text at all — use the same `technique: 'Creo', form: 'Ignem',` there too, for consistency, though it is not load-bearing.

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: all pass (the three `'Creo Ignem'` assertions still find their text, now sourced correctly once Task 2 lands — for this task alone, they still pass because `ResolvedSpell.technique` still derives from `baseEffect`, unchanged until Task 2).

- [ ] **Step 7: Fix `test/models/resolved_spell_test.dart` and `test/models/resolved_template_test.dart` — must match `Creo`/`Imaginem`**

Both files have a `record()` helper whose `baseEffectId` is `'crim-2'` (a real catalog id, Creo/Imaginem), feeding an existing assertion (`expect(resolved.technique, 'Creo')`, `expect(resolved.form, 'Imaginem')`) that Task 2 will make load-bearing on these new fields. Use `technique: 'Creo', form: 'Imaginem',` there. The file's other sites (the `buildSpell`/`chosenSlots`/`problems`-check fixtures) are not load-bearing — use the uniform default (`'Creo'`/`'Ignem'`) for those.

`test/models/resolved_spell_test.dart`, `record()` (line 65):

```dart
  Spell record() => Spell(
        id: 'spell-1',
        name: 'Phantasm',
        baseEffectId: 'crim-2',
        technique: 'Creo',
        form: 'Imaginem',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
```

`test/models/resolved_spell_test.dart` has 4 more sites, none load-bearing — uniform default (`technique: 'Creo', form: 'Ignem',`) at each:

`buildSpell` (line 48):

```dart
  Spell buildSpell({String? baseEffectId}) => Spell(
        id: 'spell-1', name: 'Phantasm',
        baseEffectId: baseEffectId ?? 'crig-10a',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'range-voice', durationId: 'duration-momentary', targetId: 'target-individual',
```

`'chosenSlots passes through from the record'` (line 152):

```dart
    final spell = Spell(
      id: 's-1', baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      requisites: const {},
      chosenSlots: const {'realm': 'Divine'},
```

`'problems reports check 6...'` (line 170):

```dart
    final spell = Spell(
      id: 's-2', baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      requisites: const {},
      chosenBaseLevel: 20,
```

`'problems does not report check 6...'` (line 188):

```dart
    final spell = Spell(
      id: 's-3', baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      requisites: const {},
      chosenBaseLevel: 20,
      chosenSlots: const {'realm': 'Divine'},
```

`test/models/resolved_template_test.dart`, `record()` (line 25) — same treatment as the spell version:

```dart
  SpellTemplate record() => SpellTemplate(
        id: 'tpl-1', name: 'Phantasm',
        baseEffectId: 'crim-2',
        technique: 'Creo',
        form: 'Imaginem',
        rangeId: 'range-voice', durationId: 'duration-momentary', targetId: 'target-individual',
```

`test/models/resolved_template_test.dart`'s other site — `'chosenSlots passes through from the record'` (line 103), uniform default:

```dart
    final template = SpellTemplate(
      id: 't-1', name: 'Test Ward', baseEffectId: 'e1',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
      summary: 'Test ward summary',
      chosenSlots: const {'realm': 'Magic'},
```

Run: `flutter test test/models/resolved_spell_test.dart test/models/resolved_template_test.dart`
Expected: all pass unchanged (Task 2 hasn't landed yet, so these fields aren't read by the getters yet — this step is purely "make it compile with the values Task 2 will need").

- [ ] **Step 8: Fix `test/data/spell_resolver_test.dart` (3 sites) — must match `Creo`/`Imaginem`**

All three helpers (`record()` line 30, `buildSpell()` line 43, `template()` line 102) default to or use `'crim-2'`/`effect.id` where `effect` is Creo/Imaginem (top of file), feeding `expect(resolved.technique, 'Creo')` at lines 62 and 122. Use `technique: 'Creo', form: 'Imaginem',` at all three sites:

```dart
  Spell record({String baseEffectId = 'crim-2', String rangeId = 'range-voice'}) => Spell(
        id: 'spell-1', name: 'Phantasm', baseEffectId: baseEffectId,
        technique: 'Creo',
        form: 'Imaginem',
        rangeId: rangeId,
        durationId: 'duration-momentary', targetId: 'target-individual',
```

```dart
  Spell buildSpell({Map<String, List<String>> selectedModifiers = const {}}) => Spell(
        id: 'test-spell', baseEffectId: effect.id,
        technique: 'Creo',
        form: 'Imaginem',
        rangeId: voice.id,
        durationId: momentary.id, targetId: individual.id,
```

```dart
  SpellTemplate template({String baseEffectId = 'crim-2', String rangeId = 'range-voice'}) =>
      SpellTemplate(
        id: 'tpl-1', name: 'Phantasm', baseEffectId: baseEffectId,
        technique: 'Creo',
        form: 'Imaginem',
        rangeId: rangeId,
        durationId: 'duration-momentary', targetId: 'target-individual',
```

Run: `flutter test test/data/spell_resolver_test.dart`
Expected: all pass.

- [ ] **Step 9: Fix `test/engine/spell_engine_test.dart` (4 sites) — thread the local fixture's own Technique/Form**

This file's whole purpose is technique/form matching (`engine.findSimilarSpells('Creo', 'Ignem', ...)` etc.), so every site must match its sibling `BaseEffect` fixture exactly.

Site 1, line 821 (`buildSpell` helper — already receives `technique`/`form` as its own parameters, thread them straight through):

```dart
  ResolvedSpell buildSpell(String id, String technique, String form, String name, int baseLevel) {
    final effect = BaseEffect(
      id: 'e$id', technique: technique, form: form,
      description: name, baseLevel: baseLevel,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    final record = Spell(
      id: id, name: name, baseEffectId: effect.id,
      technique: technique,
      form: form,
      rangeId: _range.id, durationId: _duration.id, targetId: _target.id,
```

Site 2, line 880 (`orphan`, in `'excludes unresolved spells...'` — `orphanEffect` a few lines above is Creo/Ignem):

```dart
    final orphan = ResolvedSpell(
      record: Spell(
        id: 'orphan', name: 'Orphan',
        baseEffectId: orphanEffect.id,
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'gone',
        durationId: _duration.id, targetId: _target.id,
```

Site 3, line 922 (`uncomputable`, in `'drops an uncomputable spell...'` — `uncomputableEffect` a few lines above is Creo/Ignem):

```dart
    final uncomputable = ResolvedSpell(
      record: Spell(
        id: 'uncomputable', name: 'Over-Discounted Spell',
        baseEffectId: uncomputableEffect.id,
        technique: 'Creo',
        form: 'Ignem',
        rangeId: _range.id, durationId: _duration.id, targetId: _target.id,
```

Site 4, line 1036 (`spellWith` helper, in the `adjustments` group — its own local `effect` is hardcoded `Muto`/`Imaginem`, matching `engine.findSimilarSpells('Muto', 'Imaginem', ...)` in this test):

```dart
  ResolvedSpell spellWith(String id, int baseLevel, List<LevelAdjustment> adj) {
    final effect = BaseEffect(
      id: 'e$id', technique: 'Muto', form: 'Imaginem',
      description: 'test', baseLevel: baseLevel,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    return ResolvedSpell(
      record: Spell(
        id: id, name: id, baseEffectId: effect.id,
        technique: 'Muto',
        form: 'Imaginem',
        rangeId: _range.id, durationId: _duration.id, targetId: _target.id,
```

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: all pass.

- [ ] **Step 10: Fix `test/bloc/spell_creation_bloc_test.dart` (8 sites: 5 `Spell(`, 3 `SpellTemplate(`)**

5 of the 8 use the uniform default (`'Creo'`/`'Ignem'`) — the mocktail fallback (line 39) and the four `SpellCalculated` suggestion fixtures (lines 141, 198, 208, 264 — all reference `creoIgnemEffect`/`lowEffect`, both Creo/Ignem).

The other 3 need a specific, non-default value each. The `TemplateInstantiated`-chosenSlots fixture (line 1221) references `realmSlotGuideline`, which is Rego/Vim — **use `'Rego'`/`'Vim'` here specifically**, not the uniform default, since it is not load-bearing either way but should stay internally consistent with its own `realmSlotGuideline` fixture. The remaining 2 (`wardTemplateRecord`, `disenchantTemplateRecord`) are the real published-template fixtures below, and *are* load-bearing.

The remaining 2 sites are real published-template fixtures and must match their sibling `BaseEffect` fixture:

Line 1266, `wardTemplateRecord` (`wardBaseEffect`, defined just above, is `technique: 'Rego', form: 'Aquam'`):

```dart
    final wardTemplateRecord = SpellTemplate(
      id: 'tpl-reaq-ward-against-faeries-waters',
      name: 'Ward against Faeries of the Waters',
      baseEffectId: 'reaq-gen',
      technique: 'Rego',
      form: 'Aquam',
      rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle',
```

Line 1306, `disenchantTemplateRecord` (`disenchantBaseEffect`, defined just above, is `technique: 'Perdo', form: 'Vim'`):

```dart
    final disenchantTemplateRecord = SpellTemplate(
      id: 'tpl-pevi-disenchant', name: 'Disenchant',
      baseEffectId: 'pevi-G9',
      technique: 'Perdo',
      form: 'Vim',
      rangeId: 'range-touch', durationId: 'duration-momentary', targetId: 'target-individual',
```

Line 1221 (`TemplateInstantiated` chosenSlots fixture):

```dart
    final template = SpellTemplate(
      id: 'tpl-1', name: 'Circular Ward against Demons',
      baseEffectId: realmSlotGuideline.id,
      technique: 'Rego',
      form: 'Vim',
      rangeId: 'p1', durationId: 'p2', targetId: 'p3',
```

The other 5 sites (uniform default `'Creo'`/`'Ignem'`, added the same way as Step 5's worked example): mocktail fallback (line 39), suggestion fixtures at lines 141, 198, 208, 264.

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: all pass.

- [ ] **Step 11: Fix `test/models/spell_test.dart` — 13 uniform + 1 exhaustiveness fixture**

13 of the file's 14 sites (every one except line 16) get the uniform default (`'Creo'`/`'Ignem'`) — none of them assert on technique/form and none feed a `ResolvedSpell`.

Line 16 is different: the test is named `'Spell.toMap and fromMap round-trip preserves every field'` and asserts on essentially every other field — it needs its own `technique`/`form`/`analogyRationale` assertions too, or it silently stops being exhaustive the moment these fields exist. Update it:

```dart
    test('Spell.toMap and fromMap round-trip preserves every field', () {
      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        baseEffectId: '1',
        technique: 'Perdo',
        form: 'Corpus',
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
      expect(restored.technique, 'Perdo');
      expect(restored.form, 'Corpus');
      expect(restored.analogyRationale, isNull);
      expect(restored.rangeId, spell.rangeId);
```

(the rest of the test body is unchanged).

Run: `flutter test test/models/spell_test.dart`
Expected: all pass, including the two new assertions.

- [ ] **Step 12: Fix `test/models/spell_template_test.dart` — 2 uniform + 1 exhaustiveness fixture**

The `chosenSlots` test's two fixtures (lines 35, 43) get the uniform default. The `build()` helper (line 8) feeds `'round-trips through a map'`, which should be exhaustive the same way — its `baseEffectId` is `'pevi-G3'` (Perdo/Vim), so use those real values and add assertions:

```dart
  SpellTemplate build() => SpellTemplate(
        id: 'tpl-pevi-demons-eternal-oblivion',
        name: "Demon's Eternal Oblivion",
        baseEffectId: 'pevi-G3',
        technique: 'Perdo',
        form: 'Vim',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        summary: 'Weakens and possibly destroys a creature with Infernal Might.',
        provenance: Provenance(
            source: PublicationSource.published,
            citations: [Citation(bookId: 'arm5-core')]),
      );

  test('round-trips through a map', () {
    final restored = SpellTemplate.fromMap(build().toMap());

    expect(restored.id, 'tpl-pevi-demons-eternal-oblivion');
    expect(restored.baseEffectId, 'pevi-G3');
    expect(restored.technique, 'Perdo');
    expect(restored.form, 'Vim');
    expect(restored.analogyRationale, isNull);
    expect(restored.rangeId, 'range-voice');
  });
```

Run: `flutter test test/models/spell_template_test.dart`
Expected: all pass, including the three new assertions.

- [ ] **Step 13: Full repo compile + test check**

Run: `flutter analyze`
Expected: zero errors.

Run: `flutter test`
Expected: all pass. (This exercises every one of the 70 sites at once — the true integration check for this task.)

- [ ] **Step 14: Commit**

```bash
git add lib/models/spell.dart lib/models/spell_template.dart \
  test/models/spell_test.dart test/models/spell_template_test.dart \
  test/models/resolved_spell_test.dart test/models/resolved_template_test.dart \
  test/bloc/spell_creation_bloc_test.dart test/bloc/spell_library_bloc_test.dart \
  test/data/datasources/local_spell_datasource_test.dart \
  test/data/repositories/library_repository_test.dart test/data/repositories/spell_repository_test.dart \
  test/data/services/backup_service_test.dart test/data/spell_resolver_test.dart \
  test/engine/spell_engine_test.dart test/presentation/screens/backup_screen_test.dart \
  test/presentation/screens/spell_creation_screen_test.dart test/presentation/screens/spell_library_screen_test.dart \
  test/presentation/widgets/spell_card_test.dart integration_test/spell_creation_flow_test.dart
git commit -m "feat: add technique/form/analogyRationale fields to Spell and SpellTemplate"
```

---

### Task 2: `ResolvedSpell`/`ResolvedTemplate` read the stored fields

**Files:**
- Modify: `lib/models/resolved_spell.dart`
- Modify: `lib/models/resolved_template.dart`
- Modify: `test/models/resolved_spell_test.dart`
- Modify: `test/models/resolved_template_test.dart`

**Interfaces:**
- Consumes: `Spell.technique`/`.form`, `SpellTemplate.technique`/`.form` (Task 1)
- Produces: `ResolvedSpell.technique`/`.form` and `ResolvedTemplate.technique`/`.form` now read the record, not the base effect — later tasks and the app's existing `SpellCard`/`LibraryEntry` consumers need no further change to display correctly.

- [ ] **Step 1: Switch `ResolvedSpell`'s getters**

In `lib/models/resolved_spell.dart`, replace:

```dart
  // Derived from the resolved base effect rather than stored on the record, so
  // a spell can never claim a technique its own base effect disagrees with.
  @override
  String? get technique => baseEffect?.technique;
  @override
  String? get form => baseEffect?.form;
```

with:

```dart
  // Stored on the record, not derived: a spell's own Technique/Form may
  // legitimately differ from its base effect's (see Spell.analogyRationale)
  // -- deriving from the base effect would silently display the wrong one.
  @override
  String? get technique => record.technique;
  @override
  String? get form => record.form;
```

- [ ] **Step 2: Switch `ResolvedTemplate`'s getters**

In `lib/models/resolved_template.dart`, identically:

```dart
  // Stored on the record, not derived: a template's own Technique/Form may
  // legitimately differ from its base effect's (see
  // SpellTemplate.analogyRationale) -- deriving from the base effect would
  // silently display the wrong one.
  @override
  String? get technique => record.technique;
  @override
  String? get form => record.form;
```

- [ ] **Step 3: Update the two tests whose "missing base effect" expectations just changed**

Both files have a test asserting `technique`/`form` go `null` when `baseEffect` is `null` — that was only ever true because the old getters derived from `baseEffect`. Now that `technique`/`form` are stored on the record directly, they survive an unresolved base effect (which is the point: a spell with a deleted custom base effect still knows its own Technique/Form).

In `test/models/resolved_spell_test.dart`:

```dart
  test('a missing base effect makes the spell unresolved and names the reference', () {
    final resolved = ResolvedSpell(
        record: record(), baseEffect: null, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['crim-2']);
    // technique/form are stored on the record, not derived from the base
    // effect, so they survive even when the base effect itself is missing.
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
    // The record survives intact so the spell can still be listed and re-saved.
    expect(resolved.id, 'spell-1');
    expect(resolved.name, 'Phantasm');
  });
```

In `test/models/resolved_template_test.dart`:

```dart
  test('a missing base effect makes the template unresolved and names the reference', () {
    final resolved = ResolvedTemplate(
        record: record(), baseEffect: null, range: voice, duration: momentary, target: individual);

    expect(resolved.isResolved, isFalse);
    expect(resolved.unresolvedReferences, ['crim-2']);
    // technique/form are stored on the record, not derived from the base
    // effect, so they survive even when the base effect itself is missing.
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
    // The record survives intact so the template can still be listed.
    expect(resolved.id, 'tpl-1');
    expect(resolved.name, 'Phantasm');
  });
```

Also update the doc comment on the *first* test in each file (the fully-resolved case), which still says "Derived from the base effect... cannot disagree with it" — now false:

In `test/models/resolved_spell_test.dart`, the `'a fully resolved spell exposes...'` test:

```dart
    // Stored on the record -- happens to match the base effect here because
    // this fixture isn't an analogy (see Spell.analogyRationale).
    expect(resolved.technique, 'Creo');
    expect(resolved.form, 'Imaginem');
```

In `test/models/resolved_template_test.dart`, the equivalent test: identical comment/assertion pair.

- [ ] **Step 4: Add a test proving the analogy case actually displays correctly**

This is the direct regression test for the Problem this whole plan exists to solve — prove that when a record's own `technique`/`form` disagree with its base effect's, the resolved view shows the record's, not the base effect's.

In `test/models/resolved_spell_test.dart`, add:

```dart
  test('technique/form come from the record even when the base effect disagrees', () {
    // The Vim-analogy shape this plan exists for: a Rego Imaginem spell
    // built on a Rego Vim base effect "by analogy".
    final vimEffect = BaseEffect(
      id: 'revi-G2', technique: 'Rego', form: 'Vim',
      description: 'Sustain or suppress a spell', baseLevel: null,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    final analogySpell = Spell(
      id: 'spell-analogy', name: 'Restore the Moved Image',
      baseEffectId: 'revi-G2',
      technique: 'Rego',
      form: 'Imaginem',
      analogyRationale: 'By analogy to Rego Vim\'s sustain-or-suppress guideline.',
      rangeId: 'range-voice', durationId: 'duration-momentary', targetId: 'target-individual',
      requisites: const {},
      description: 'Cancels a ReIm spell that moves an image.',
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final resolved = ResolvedSpell(
        record: analogySpell, baseEffect: vimEffect, range: voice, duration: momentary, target: individual);

    // The spell is Rego Imaginem, not Rego Vim -- even though its base
    // effect is a Vim guideline.
    expect(resolved.technique, 'Rego');
    expect(resolved.form, 'Imaginem');
    expect(resolved.baseEffect?.form, 'Vim'); // the borrowed guideline, for contrast
  });
```

Run: `flutter test test/models/resolved_spell_test.dart::technique/form come from the record even when the base effect disagrees`
Expected: FAIL if Step 1 isn't applied yet, PASS after.

- [ ] **Step 5: Run the full Dart suite**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/models/resolved_spell.dart lib/models/resolved_template.dart \
  test/models/resolved_spell_test.dart test/models/resolved_template_test.dart
git commit -m "fix: ResolvedSpell/ResolvedTemplate read technique/form from the record"
```

---

### Task 3: `validateSpellAgainstCatalog` gains check 8

**Files:**
- Modify: `lib/models/spell.dart` (`validateSpellAgainstCatalog`)
- Modify: `lib/models/resolved_spell.dart` (`ResolvedSpell.problems` call site)
- Modify: `lib/engine/spell_engine.dart` (`validateSpellDraft` call site)
- Modify: `test/data/published_spell_import_test.dart` (assertion 7's two call sites)
- Modify: `test/models/spell_test.dart` (`validateSpellAgainstCatalog` test group)

**Interfaces:**
- Consumes: `Spell.technique`/`.form`/`.analogyRationale` (Task 1)
- Produces: `validateSpellAgainstCatalog` now requires three more named parameters: `required String technique, required String form, required String? analogyRationale`. Every existing caller must be updated in this same task (the function signature change is itself all-or-nothing, the same way Task 1's constructor changes were).

- [ ] **Step 1: Add check 8 and the new parameters**

In `lib/models/spell.dart`, add the two params to the function signature:

```dart
List<String> validateSpellAgainstCatalog({
  required BaseEffect effect,
  required String technique,
  required String form,
  required String? analogyRationale,
  required int? chosenBaseLevel,
  required Map<String, RequisiteKind> requisites,
  required Map<String, List<String>> selectedModifiers,
  required Map<String, String> chosenSlots,
  required List<Modifier> modifiers,
  bool isTemplate = false,
}) {
```

Add the check at the end of the function, after check 7 and before `return problems;`:

```dart
  // 8. A spell's own Technique/Form is now stored, not derived, so it can
  //    legitimately differ from its base effect's -- but only when that
  //    difference is explained. Symmetric: an unexplained mismatch is a data
  //    bug (the record and its guideline silently disagree); an explanation
  //    attached to a spell that doesn't actually differ is meaningless
  //    decoration, the same class of bug check 2 catches for a stray
  //    chosenBaseLevel. Runs unconditionally -- unlike checks 1, 2 and 6, not
  //    wrapped in `if (!isTemplate)`: a template needs its own
  //    correctly-recorded Technique/Form exactly as much as a spell does.
  final isAnalogy = technique != effect.technique || form != effect.form;
  if (isAnalogy && (analogyRationale == null || analogyRationale.trim().isEmpty)) {
    problems.add(
      "Technique/Form differs from the base effect's own -- "
      'an analogyRationale is required to explain why',
    );
  } else if (!isAnalogy && analogyRationale != null) {
    problems.add(
      'analogyRationale is set but Technique/Form already matches the base '
      "effect's own -- remove it",
    );
  }

  return problems;
}
```

- [ ] **Step 2: Update `ResolvedSpell.problems`**

In `lib/models/resolved_spell.dart`:

```dart
  List<String> get problems {
    final effect = baseEffect;
    if (effect == null) return const [];
    return validateSpellAgainstCatalog(
      effect: effect,
      technique: record.technique,
      form: record.form,
      analogyRationale: record.analogyRationale,
      chosenBaseLevel: record.chosenBaseLevel,
      requisites: record.requisites,
      selectedModifiers: record.selectedModifiers,
      modifiers: modifiers,
      chosenSlots: record.chosenSlots,
    );
  }
```

- [ ] **Step 3: Update `SpellEngine.validateSpellDraft`**

In `lib/engine/spell_engine.dart`, the existing call is guarded by `if (draft.baseEffect != null)` but not by `draft.technique`/`.form` being non-null (those are checked separately, a few lines above, and added to `errors` without an early return) — use `?? ''` so a still-null draft technique/form does not throw, and simply adds one more (harmless, accurate) error message on top of "Technique must be selected":

```dart
    if (draft.baseEffect != null) {
      errors.addAll(validateSpellAgainstCatalog(
        effect: draft.baseEffect!,
        technique: draft.technique ?? '',
        form: draft.form ?? '',
        analogyRationale: null, // the creation screen cannot produce one yet
        chosenBaseLevel: draft.chosenBaseLevel,
        requisites: draft.requisites,
        selectedModifiers: draft.selectedModifiers,
        modifiers: allModifiers,
        chosenSlots: draft.chosenSlots,
      ));
    }
```

- [ ] **Step 4: Update `published_spell_import_test.dart`'s assertion 7**

In `test/data/published_spell_import_test.dart`, both loops:

```dart
    for (final spell in await loader.loadSpellLibrary()) {
      final effect = effects[spell.baseEffectId];
      // Assertion 4 already covers an id that does not resolve.
      if (effect == null) continue;
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: spell.technique,
        form: spell.form,
        analogyRationale: spell.analogyRationale,
        chosenBaseLevel: spell.chosenBaseLevel,
        requisites: spell.requisites,
        selectedModifiers: spell.selectedModifiers,
        chosenSlots: spell.chosenSlots,
        modifiers: modifiers,
      );
      if (problems.isNotEmpty) {
        failures.add('${spell.name} (${spell.id}): ${problems.join('; ')}');
      }
    }

    for (final template in await loader.loadSpellTemplates()) {
      final effect = effects[template.baseEffectId];
      if (effect == null) continue;
      // isTemplate: a General template legitimately has no chosen level --
      // supplying one is what instantiating it means. Checks 3, 4, 5 and 8
      // still apply.
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: template.technique,
        form: template.form,
        analogyRationale: template.analogyRationale,
        chosenBaseLevel: null,
        requisites: template.requisites,
        selectedModifiers: template.selectedModifiers,
        chosenSlots: template.chosenSlots,
        modifiers: modifiers,
        isTemplate: true,
      );
      if (problems.isNotEmpty) {
        failures.add('${template.name} (${template.id}): ${problems.join('; ')}');
      }
    }
```

This is the whole-corpus regression guard: once Task 5 regenerates the committed assets with every real spell's `technique`/`form` matching its base effect's own (and `analogyRationale` null everywhere), this assertion proves check 8 introduces zero false positives across all 325 spells and 24 templates.

- [ ] **Step 5: Write the four direct pins for check 8**

In `test/models/spell_test.dart`, inside the existing `group('validateSpellAgainstCatalog', ...)`, add:

```dart
    test('check 8: matching technique/form with no analogyRationale is valid', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        modifiers: const [],
      );
      expect(problems, isEmpty);
    });

    test('check 8: mismatched technique/form with a rationale is valid', () {
      final effect = BaseEffect(
        id: 'revi-G2', technique: 'Rego', form: 'Vim',
        description: 'test', baseLevel: null,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Rego',
        form: 'Imaginem',
        analogyRationale: 'By analogy to Rego Vim.',
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        modifiers: const [],
      );
      expect(problems, isEmpty);
    });

    test('check 8: mismatched technique/form with no rationale is invalid', () {
      final effect = BaseEffect(
        id: 'revi-G2', technique: 'Rego', form: 'Vim',
        description: 'test', baseLevel: null,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Rego',
        form: 'Imaginem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        modifiers: const [],
      );
      expect(problems, ['Technique/Form differs from the base effect\'s own -- an analogyRationale is required to explain why']);
    });

    test('check 8: matching technique/form with a stray rationale is invalid', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: 'This should not be here.',
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        modifiers: const [],
      );
      expect(problems, ["analogyRationale is set but Technique/Form already matches the base effect's own -- remove it"]);
    });
```

- [ ] **Step 6: Run the full Dart suite**

Run: `flutter test`
Expected: all pass, including the four new checks and assertion 7's updated call sites against the real (not-yet-regenerated) committed assets — this must stay green even before Task 5's regeneration, since every real spell's `technique`/`form` will already match its base effect exactly (Task 1/2 only added/wired the fields, nothing sets a mismatch anywhere in production data yet).

- [ ] **Step 7: Commit**

```bash
git add lib/models/spell.dart lib/models/resolved_spell.dart lib/engine/spell_engine.dart \
  test/data/published_spell_import_test.dart test/models/spell_test.dart
git commit -m "feat: validateSpellAgainstCatalog enforces the analogyRationale invariant"
```

---

### Task 4: Python importer emits `technique`/`form`/`analogyRationale`

**Files:**
- Modify: `scripts/spell_import/emit.py` (`build_spell`, `build_template`)
- Modify: `scripts/spell_import/tests/test_emit.py`

**Interfaces:**
- Consumes: `block.technique`, `block.form` (already on every `SpellBlock`)
- Produces: `build_spell(..., technique: str, form: str, analogy_rationale: str | None = None)` and identically on `build_template` — every returned dict now always carries `"technique"`/`"form"` keys, and `"analogyRationale"` only when `analogy_rationale` is not `None`.

- [ ] **Step 1: Add the parameters and emitted keys to `build_spell`**

In `scripts/spell_import/emit.py`, update the signature:

```python
def build_spell(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
    realm_by_spell_id: dict[str, str] | None = None,
    chosen_base_level: int | None = None,
    override_modifiers: dict[str, list[str]] | None = None,
    extra_adjustment: tuple[int, str] | None = None,
    analogy_rationale: str | None = None,
) -> dict:
```

Add `"technique"`/`"form"` to the `spell` dict literal, right after `"name"`:

```python
    spell = {
        "id": catalog_module.slug_id(block.technique, block.form, block.name),
        "name": block.name,
        "technique": block.technique,
        "form": block.form,
        "requisites": requisites,
```

Add the conditional `analogyRationale` key right before the function's final `return spell`:

```python
    if analogy_rationale is not None:
        spell["analogyRationale"] = analogy_rationale

    return spell
```

- [ ] **Step 2: Add the parameter and emitted keys to `build_template`**

Mirror Step 1 in `build_template`: same signature addition (`analogy_rationale: str | None = None`), same `"technique"`/`"form"` keys after `"name"` in the `template` dict literal, same conditional `analogyRationale` append before `return template`.

- [ ] **Step 3: Write the emission pins**

In `scripts/spell_import/tests/test_emit.py`, add a new test class:

```python
class TechniqueFormEmissionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def test_build_spell_emits_technique_and_form(self):
        design = designline.parse_design("(Base 2, +1 Touch, +2 Sun)")
        spell = emit.build_spell(
            _block("Test Spell", "Rego", "Aquam", 10), "reaq-3", self.catalog, design
        )
        self.assertEqual(spell["technique"], "Rego")
        self.assertEqual(spell["form"], "Aquam")
        self.assertNotIn("analogyRationale", spell)

    def test_build_spell_emits_analogy_rationale_when_given(self):
        design = designline.parse_design("(Base 2, +1 Touch, +2 Sun)")
        spell = emit.build_spell(
            _block("Test Spell", "Rego", "Aquam", 10), "reaq-3", self.catalog, design,
            analogy_rationale="By analogy to a Vim guideline.",
        )
        self.assertEqual(spell["analogyRationale"], "By analogy to a Vim guideline.")

    def test_build_template_emits_technique_and_form(self):
        design = designline.parse_design("(Base effect)")
        template = emit.build_template(
            _block("Test Template", "Rego", "Vim", None), "revi-G1", self.catalog, design
        )
        self.assertEqual(template["technique"], "Rego")
        self.assertEqual(template["form"], "Vim")
        self.assertNotIn("analogyRationale", template)

    def test_build_template_emits_analogy_rationale_when_given(self):
        design = designline.parse_design("(Base effect)")
        template = emit.build_template(
            _block("Test Template", "Rego", "Vim", None), "revi-G1", self.catalog, design,
            analogy_rationale="By analogy to a Vim guideline.",
        )
        self.assertEqual(template["analogyRationale"], "By analogy to a Vim guideline.")
```

Run: `python -m unittest scripts.spell_import.tests.test_emit -v` (from repo root, with `ARS_RULEBOOK_ROOT` set)
Expected: the four new tests pass; every pre-existing test in the file still passes (they don't assert on the dict's exact key set, only specific keys, so the two new always-present keys don't break them — verified by running the whole file, not just the new tests).

- [ ] **Step 4: Commit**

```bash
git add scripts/spell_import/emit.py scripts/spell_import/tests/test_emit.py
git commit -m "feat: emit.py emits technique/form/analogyRationale on every spell and template"
```

---

### Task 5: Wire `extract_spells.py` and regenerate the committed assets

**Files:**
- Modify: `scripts/spell_import/extract_spells.py`
- Modify: `assets/data/spell_library.json`, `assets/data/spell_templates.json` (regenerated, not hand-edited)
- Modify: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: `emit.build_spell`/`build_template`'s new `analogy_rationale` parameter (Task 4)
- Produces: every one of the 3 real call sites to `build_spell`/`build_template` in `extract_spells.py` now passes `technique=block.technique, form=block.form` (mandatory positional data already available) and `analogy_rationale=None` (no published spell uses analogy yet).

- [ ] **Step 1: Find and update every `build_spell`/`build_template` call site**

Run: `grep -n "emit.build_spell(\|emit.build_template(" scripts/spell_import/extract_spells.py`
Expected: 3 sites, at lines 610 (`build_template`, the General/template branch), 625 (`build_spell`, the `NUMBERED_OVERRIDES`-no-candidates branch) and 669 (`build_spell`, the normal numbered-resolve branch).

Site 1, line 610 — before:

```python
            try:
                templates.append(emit.build_template(
                    block, base_effect_id, catalog, design,
                    realm_by_spell_id=REALM_BY_SPELL_ID,
                ))
```

after:

```python
            try:
                templates.append(emit.build_template(
                    block, base_effect_id, catalog, design,
                    realm_by_spell_id=REALM_BY_SPELL_ID,
                    technique=block.technique,
                    form=block.form,
                    analogy_rationale=None,
                ))
```

Site 2, line 625 — before:

```python
            try:
                spells.append(emit.build_spell(
                    block, override["base_effect_id"], catalog, design,
                    realm_by_spell_id=REALM_BY_SPELL_ID,
                    chosen_base_level=override["chosen_base_level"],
                    override_modifiers=override["modifiers"],
                ))
```

after:

```python
            try:
                spells.append(emit.build_spell(
                    block, override["base_effect_id"], catalog, design,
                    realm_by_spell_id=REALM_BY_SPELL_ID,
                    chosen_base_level=override["chosen_base_level"],
                    override_modifiers=override["modifiers"],
                    technique=block.technique,
                    form=block.form,
                    analogy_rationale=None,
                ))
```

Site 3, line 669 — before:

```python
        try:
            spells.append(emit.build_spell(
                block, base_effect_id, catalog, design,
                realm_by_spell_id=REALM_BY_SPELL_ID,
                extra_adjustment=COMBINED_BASE_EFFECTS.get(spell_id),
            ))
```

after:

```python
        try:
            spells.append(emit.build_spell(
                block, base_effect_id, catalog, design,
                realm_by_spell_id=REALM_BY_SPELL_ID,
                extra_adjustment=COMBINED_BASE_EFFECTS.get(spell_id),
                technique=block.technique,
                form=block.form,
                analogy_rationale=None,
            ))
```

- [ ] **Step 2: Regenerate the committed assets**

```bash
export ARS_RULEBOOK_ROOT="C:/Development/personal/Ars-Magica-Open-License"
python -m scripts.spell_import.extract_spells --write
```

Expected output: `imported : 325`, `templates: 24`, `exceptions: 7`, `blocked : 4`, `unresolved: 0` (unchanged from the current committed counts — this task adds two keys to every entry, it does not change which spells import, block, or except).

Run: `git diff --stat assets/data/spell_library.json assets/data/spell_templates.json`
Expected: both files show additions only (two new keys per entry), no deletions, no spell's `baseEffectId`/`printedLevel`/`chosenBaseLevel`/other field changed.

- [ ] **Step 3: Add a regression test pinning that every real entry carries `technique`/`form`**

In `scripts/spell_import/tests/test_extract.py`, add:

```python
class TechniqueFormRegenerationTest(unittest.TestCase):
    """Every emitted spell and template must carry its own technique/form --
    the whole reason this plan exists. No spell should ever emit without
    them (a missing key here would mean a code path in extract_spells.py
    forgot to thread block.technique/block.form through).
    """

    def test_every_spell_and_template_has_technique_and_form(self):
        report = extract_spells.run(write=False)
        for spell in report.spells:
            self.assertIn("technique", spell, msg=spell["name"])
            self.assertIn("form", spell, msg=spell["name"])
        for template in report.templates:
            self.assertIn("technique", template, msg=template["name"])
            self.assertIn("form", template, msg=template["name"])

    def test_no_spell_carries_an_analogy_rationale_yet(self):
        # Global Constraint: this plan wires the capability through but does
        # not use it -- no published spell is analogous yet.
        report = extract_spells.run(write=False)
        for spell in report.spells:
            self.assertNotIn("analogyRationale", spell, msg=spell["name"])
        for template in report.templates:
            self.assertNotIn("analogyRationale", template, msg=template["name"])
```

Run: `python -m unittest discover -p "test_*.py"` (from repo root)
Expected: all pass, including the two new tests and the pre-existing byte-for-byte regeneration test (`RegenerationTest`), which now also covers the two new keys.

- [ ] **Step 4: Commit**

```bash
git add scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_extract.py \
  assets/data/spell_library.json assets/data/spell_templates.json
git commit -m "feat: extract_spells.py emits technique/form on every real spell and template"
```

---

### Task 6: Final verification and `todo.md`

**Files:**
- Modify: `.superpowers/todo.md`

- [ ] **Step 1: Run the full Python suite**

```bash
export ARS_RULEBOOK_ROOT="C:/Development/personal/Ars-Magica-Open-License"
python -m unittest discover -p "test_*.py"
```
Expected: all pass (278 + the new tests from Tasks 4 and 5).

- [ ] **Step 2: Run the full Flutter suite**

```bash
flutter test
```
Expected: all pass (550 + the new tests from Tasks 1-3).

- [ ] **Step 3: Run the Windows integration suite**

Follow the project's existing integration-test invocation (see `integration_test/spell_creation_flow_test.dart` and any project README/CI instructions for the Windows target).
Expected: all pass, including the new site 16 (`spell_creation_flow_test.dart`, fixed in Task 1) and no new failures.

- [ ] **Step 4: Add item 48 to `todo.md`**

Add a new section (the next unused item number — items run through 47) documenting what landed, in the style of every other completed item this session:

```markdown
### 48. Base Effect Analogy — model + pipeline capability — ✅ DONE 2026-08-16

**Spec:** `docs/superpowers/specs/2026-08-16-base-effect-analogy-design.md`

`Spell` and `SpellTemplate` gained their own `technique`/`form` (stored, no
longer derived from the base effect) and an optional `analogyRationale`
(required non-null exactly when they differ from the resolved base effect's
own technique/form). `ResolvedSpell`/`ResolvedTemplate` now read the stored
fields, so a by-analogy spell displays under its own real Technique/Form
instead of the borrowed one. `validateSpellAgainstCatalog` gained an 8th
check enforcing the invariant. The Python importer emits both new fields on
every spell and template; every one of the 325 spells and 24 templates in
the committed assets was regenerated to carry them.

**Explicitly not done in this item — separate follow-ups:**
- Actually unblocking *Restore the Moved Image*, *Dispel the Phantom Image*,
  *The Invisible Eye Revealed*, *Lay to Rest the Haunting Spirit* with a real
  analogy reference — each needs its own per-spell reference-R/D/T
  derivation, independent of this capability (see item 25's body for the
  complication found while designing this).
- Creation-screen UI for picking a cross-Form base effect interactively.

- **Files:** `lib/models/spell.dart`, `lib/models/spell_template.dart`,
  `lib/models/resolved_spell.dart`, `lib/models/resolved_template.dart`,
  `lib/engine/spell_engine.dart`, `scripts/spell_import/emit.py`,
  `scripts/spell_import/extract_spells.py`
```

- [ ] **Step 5: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close out item 48, base effect analogy capability"
```
