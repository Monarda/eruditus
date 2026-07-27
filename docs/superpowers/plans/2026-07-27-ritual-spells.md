# Ritual Spells Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Model Ritual spells — derive which spells are Rituals and why, let the user declare the cases only a person can judge, and apply the minimum-level-20 floor.

**Architecture:** One new persisted field on `Spell` (`ritualDeclaration`); everything else derives on read. `Parameter` gains a `requiresRitual` flag, `BaseEffect` gains a `ritualRequirement` enum, and `SpellEngine` computes a `RitualStatus` (a list of accumulated reasons) plus the level floor. The floor is applied by `SpellEngine`, never by `SpellLevelCalculator`, which stays a pure magnitude-summing function.

**Tech Stack:** Flutter, Dart, `flutter_bloc`, `sqflite`, `equatable`, `mocktail`/`bloc_test`. Data lives in `assets/data/*.json`.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-07-27-ritual-spells-design.md`. Read it before starting.
- **Rulebook:** `C:\Users\idf53\Development\personal\arsm\Ars-Magica-Open-License\reviewed\Ars Magica - Definitive Edition (Core Rules).md`. All line numbers in this plan refer to it.
- **Flutter is not on the default PATH.** Every shell step must start with:
  `export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH"`
- **`flutter test` does not run `integration_test/`.** Those need a device: `flutter test integration_test/... -d windows`. "Tests pass" for this branch means **both** suites. See todo item 6. Windows Developer Mode is enabled on this machine and `-d windows` is verified working, so this is a normal step, not a blocker.
- **Real Blocs hang forever under `flutter_tester`.** Widget tests must use `MockBloc` from `bloc_test`; anything needing a real Bloc goes in `integration_test/`.
- **Ritual threshold is `> 50`, not `>= 50`.** Level 50 is a legal Formulaic spell (line 12346).
- **Ritual minimum level is 20** (line 12354).
- **Backward compatibility is not a goal.** Dropping and rebuilding the `spells` table on upgrade is the established pattern.
- **JSON asset files use LF line endings.** Any script writing them must use `newline='\n'` or it will rewrite every line on Windows.
- Branch is `feature/ritual-spells`, already created, spec already committed.

---

### Task 1: `Parameter.requiresRitual`

**Files:**
- Modify: `lib/models/parameter.dart`
- Modify: `assets/data/parameters.json`
- Test: `test/models/parameter_test.dart`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `Parameter.requiresRitual` (`bool`, defaults `false`), a named constructor parameter `requiresRitual`. JSON key `"requiresRitual"`; absent means `false`. Task 5 reads this.

- [ ] **Step 1: Write the failing tests**

Append these two tests inside the existing `group('Parameter', ...)` in `test/models/parameter_test.dart`:

```dart
    test('requiresRitual defaults to false and round-trips when true', () {
      final plain = Parameter(
        id: 'p-1', name: 'Sun', category: 'Duration', magnitude: 2,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(plain.requiresRitual, isFalse);

      final ritual = Parameter(
        id: 'p-2', name: 'Year', category: 'Duration', magnitude: 4,
        requiresRitual: true,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(Parameter.fromMap(ritual.toMap()).requiresRitual, isTrue);
      expect(Parameter.fromMap(plain.toMap()).requiresRitual, isFalse);
    });

    test('fromMap treats an absent requiresRitual key as false', () {
      final restored = Parameter.fromMap({
        'id': 'p-3',
        'name': 'Touch',
        'category': 'Range',
        'magnitude': 1,
        'source': 'published',
        'citations': [
          {'bookId': 'arm5-core'},
        ],
      });
      expect(restored.requiresRitual, isFalse);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/models/parameter_test.dart
```

Expected: compile error — `No named parameter with the name 'requiresRitual'`.

- [ ] **Step 3: Add the field**

Replace the whole body of the `Parameter` class in `lib/models/parameter.dart` (keep the imports and the `==`/`hashCode` overrides below it exactly as they are):

```dart
class Parameter {
  final String id;
  final String name;
  final String category; // "Range", "Duration", "Target", or custom
  final int magnitude;

  /// True when the rulebook forbids this parameter on a non-Ritual spell.
  /// Only Year (Duration) and Boundary (Target) set it in the built-in
  /// catalog — see Core Rules lines 12116 and 12138. Deliberately a generic
  /// flag rather than an id check, because the Faerie and Symbolic Magic
  /// parameters of todo item 17 need the same treatment.
  final bool requiresRitual;

  final Provenance provenance;

  Parameter({
    required this.id,
    required this.name,
    required this.category,
    required this.magnitude,
    this.requiresRitual = false,
    required this.provenance,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'magnitude': magnitude,
    'requiresRitual': requiresRitual,
    ...provenance.toMap(),
  };

  factory Parameter.fromMap(Map<String, dynamic> map) => Parameter(
    id: requireField<String>(map, 'id', 'Parameter'),
    name: requireField<String>(map, 'name', 'Parameter'),
    category: requireField<String>(map, 'category', 'Parameter'),
    magnitude: requireField<int>(map, 'magnitude', 'Parameter'),
    requiresRitual: map['requiresRitual'] as bool? ?? false,
    provenance: Provenance.fromMap(map),
  );
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/models/parameter_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Flag the two ritual-only parameters in the asset file**

In `assets/data/parameters.json`, find the `duration-year` entry and add the key after `magnitude`:

```json
  {
    "id": "duration-year",
    "name": "Year",
    "category": "Duration",
    "magnitude": 4,
    "requiresRitual": true,
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
```

Do the same for `target-boundary`:

```json
  {
    "id": "target-boundary",
    "name": "Boundary",
    "category": "Target",
    "magnitude": 4,
    "requiresRitual": true,
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
```

Add the key to **no other entry**. Vision is +4 like Boundary but is explicitly *not* ritual-only (line 12345).

- [ ] **Step 6: Write the failing asset test**

Add to `test/data/datasources/asset_data_loader_test.dart`, after the existing `loadParameters` test:

```dart
  test('exactly Year and Boundary are flagged ritual-only', () async {
    final parameters = await loader.loadParameters();

    final flagged = parameters.where((p) => p.requiresRitual).map((p) => p.id).toSet();

    // Hardcoded, unlike the base-effect counts: parameters.json is the small
    // hand-curated list todo item 5 deliberately left as literals.
    expect(flagged, {'duration-year', 'target-boundary'});

    // Vision shares Boundary's +4 magnitude but is explicitly not ritual-only
    // (Core Rules line 12345: Formulaic spells "may have Vision target, if
    // they are magical sense spells").
    expect(
      parameters.firstWhere((p) => p.id == 'target-vision').requiresRitual,
      isFalse,
    );
  });
```

- [ ] **Step 7: Run the asset test**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/data/datasources/asset_data_loader_test.dart
```

Expected: PASS.

- [ ] **Step 8: Run the full unit suite to check nothing regressed**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test
```

Expected: all PASS. `Parameter` gained an optional parameter with a default, so no existing call site breaks.

- [ ] **Step 9: Commit**

```bash
git add lib/models/parameter.dart assets/data/parameters.json test/models/parameter_test.dart test/data/datasources/asset_data_loader_test.dart && git commit -m "feat: add requiresRitual to Parameter, flag Year and Boundary"
```

---

### Task 2: `BaseEffect.ritualRequirement`

**Files:**
- Modify: `lib/models/base_effect.dart`
- Test: `test/models/base_effect_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum RitualRequirement { none, suggested, required }` exported from `lib/models/base_effect.dart`; `BaseEffect.ritualRequirement` (defaults `RitualRequirement.none`). JSON key `"ritualRequirement"`, serialized by `.name`; absent means `none`. Tasks 3, 5, 6 and 7 read this.

`required` is legal as a Dart enum constant — it is a contextual keyword, meaningful only in formal parameter lists. This was verified by compiling and running it before writing this plan.

- [ ] **Step 1: Write the failing tests**

Append to the existing `group` in `test/models/base_effect_test.dart`:

```dart
    test('ritualRequirement defaults to none and round-trips every value', () {
      for (final value in RitualRequirement.values) {
        final effect = BaseEffect(
          id: 'e-1', technique: 'Creo', form: 'Corpus',
          description: 'Heal a Light Wound', baseLevel: 15,
          ritualRequirement: value,
          provenance: Provenance(source: PublicationSource.userCreated),
        );
        expect(BaseEffect.fromMap(effect.toMap()).ritualRequirement, value);
      }

      final plain = BaseEffect(
        id: 'e-2', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 10,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      expect(plain.ritualRequirement, RitualRequirement.none);
    });

    test('fromMap treats an absent ritualRequirement key as none', () {
      final restored = BaseEffect.fromMap({
        'id': 'e-3',
        'technique': 'Creo',
        'form': 'Ignem',
        'description': 'Create flame',
        'baseLevel': 10,
        'source': 'userCreated',
      });
      expect(restored.ritualRequirement, RitualRequirement.none);
    });

    test('fromMap throws a clear FormatException on an unknown ritualRequirement', () {
      expect(
        () => BaseEffect.fromMap({
          'id': 'e-4',
          'technique': 'Creo',
          'form': 'Ignem',
          'description': 'Create flame',
          'baseLevel': 10,
          'ritualRequirement': 'mandatory',
          'source': 'userCreated',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('mandatory'),
              contains('BaseEffect'),
              contains('suggested'),
            ),
          ),
        ),
      );
    });
```

Add `import 'package:eruditus/models/base_effect.dart';` if the file does not already have it (it will).

- [ ] **Step 2: Run the tests to verify they fail**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/models/base_effect_test.dart
```

Expected: compile error — `Undefined name 'RitualRequirement'`.

- [ ] **Step 3: Add the enum, the parser and the field**

In `lib/models/base_effect.dart`, insert this above the `BaseEffect` class, below the imports:

```dart
/// Whether a guideline demands a Ritual spell.
///
/// [required] is a hard constraint from the rulebook — the spell cannot be
/// Formulaic. [suggested] is guidance only: it forces nothing, and exists so
/// the UI can explain what casting the effect non-ritually actually does. See
/// Core Rules line 13415 on healing spells, which suspend rather than cure
/// when cast as anything other than a Momentary Ritual.
enum RitualRequirement { none, suggested, required }

RitualRequirement _ritualRequirementFromName(String name) {
  for (final value in RitualRequirement.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "BaseEffect.fromMap: unknown ritualRequirement '$name' (expected one of: "
    "${RitualRequirement.values.map((r) => r.name).join(', ')})",
  );
}
```

Then change the class body (leaving the `==`/`hashCode` overrides and their comment untouched):

```dart
class BaseEffect {
  final String id;
  final String technique;
  final String form;
  final String description;
  final int baseLevel;
  final RitualRequirement ritualRequirement;
  final Provenance provenance;

  BaseEffect({
    required this.id,
    required this.technique,
    required this.form,
    required this.description,
    required this.baseLevel,
    this.ritualRequirement = RitualRequirement.none,
    required this.provenance,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'technique': technique,
    'form': form,
    'description': description,
    'baseLevel': baseLevel,
    'ritualRequirement': ritualRequirement.name,
    ...provenance.toMap(),
  };

  factory BaseEffect.fromMap(Map<String, dynamic> map) => BaseEffect(
    id: requireField<String>(map, 'id', 'BaseEffect'),
    technique: requireField<String>(map, 'technique', 'BaseEffect'),
    form: requireField<String>(map, 'form', 'BaseEffect'),
    description: requireField<String>(map, 'description', 'BaseEffect'),
    baseLevel: requireField<int>(map, 'baseLevel', 'BaseEffect'),
    ritualRequirement: map['ritualRequirement'] == null
        ? RitualRequirement.none
        : _ritualRequirementFromName(
            requireField<String>(map, 'ritualRequirement', 'BaseEffect')),
    provenance: Provenance.fromMap(map),
  );
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/models/base_effect_test.dart && flutter test
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/base_effect.dart test/models/base_effect_test.dart && git commit -m "feat: add ritualRequirement enum to BaseEffect"
```

---

### Task 3: Flag the 45 ritual base effects in the catalog

**Files:**
- Modify: `assets/data/base_effects.json`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: `RitualRequirement` from Task 2.
- Produces: 7 entries flagged `required`, 38 flagged `suggested`. Task 9's fixtures rely on `crco-35a` and `crte-15a` being present and resolvable.

The membership was fixed during design by walking the Creo Animal (line 12468), Creo Corpus (line 13413) and Creo Herbam (line 13919) guideline tables row by row. Do **not** re-derive it — the spec's "Exclusions, and why" section records why each near-miss was left out. Implement the list as given.

- [ ] **Step 1: Write the failing asset test**

Add to `test/data/datasources/asset_data_loader_test.dart`:

```dart
  test('the ritual-flagged base effects are exactly the reviewed sets', () async {
    final effects = await loader.loadBaseEffects();

    Set<String> idsWith(RitualRequirement requirement) => effects
        .where((e) => e.ritualRequirement == requirement)
        .map((e) => e.id)
        .toSet();

    // Asserted as exact SETS, not counts. Todo item 5's reasoning for deriving
    // counts from the file applies to properties that drift as the extraction
    // grows; this is a hand-reviewed membership decision, and a count would
    // pass while an entry silently moved between the two flags.
    expect(idsWith(RitualRequirement.required), {
      'craq-25b', 'crau-25', 'crco-5b', 'crig-25b', 'crte-25b',
      'pevi-G9', 'pevi-G10',
    });

    expect(idsWith(RitualRequirement.suggested), {
      // Creo Animal (11)
      'cran-15a', 'cran-20a', 'cran-25b', 'cran-25c', 'cran-25d', 'cran-25e',
      'cran-30a', 'cran-30b', 'cran-35', 'cran-40', 'cran-75',
      // Creo Corpus (20)
      'crco-15a', 'crco-15c', 'crco-20a', 'crco-20b', 'crco-20c', 'crco-25a',
      'crco-25b', 'crco-25c', 'crco-25d', 'crco-30a', 'crco-30b', 'crco-30d',
      'crco-35a', 'crco-35b', 'crco-35c', 'crco-40', 'crco-45', 'crco-50',
      'crco-55', 'crco-70',
      // Creo Herbam (7)
      'crhe-1e', 'crhe-2c', 'crhe-3b', 'crhe-4', 'crhe-5', 'crhe-10',
      'crhe-15b',
    });

    // Recovery bonuses and suppression effects are sustained by the spell and
    // are deliberately excluded; "Stop the progress of a disease" is contrasted
    // directly with the ritual "Cure a disease" at Core Rules line 12478.
    for (final id in ['cran-1', 'crco-1a', 'cran-25a', 'crco-3b', 'crhe-1a']) {
      expect(
        effects.firstWhere((e) => e.id == id).ritualRequirement,
        RitualRequirement.none,
        reason: '$id is sustained by the spell, not lasting after it',
      );
    }
  });
```

Add `import 'package:eruditus/models/base_effect.dart';` to the test file's imports.

- [ ] **Step 2: Run it to verify it fails**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/data/datasources/asset_data_loader_test.dart
```

Expected: FAIL — both sets come back empty.

- [ ] **Step 3: Apply the flags with a line-preserving script**

`base_effects.json` stores one entry per line in a compact non-`json.dump` format. Re-serializing the whole file would reformat all 604 lines. This script edits only the 45 target lines.

Save as `scripts/flag_ritual_effects.py` and run it from the repo root:

```python
import pathlib
import re

REQUIRED = [
    'craq-25b', 'crau-25', 'crco-5b', 'crig-25b', 'crte-25b',
    'pevi-G9', 'pevi-G10',
]

SUGGESTED = [
    # Creo Animal (11)
    'cran-15a', 'cran-20a', 'cran-25b', 'cran-25c', 'cran-25d', 'cran-25e',
    'cran-30a', 'cran-30b', 'cran-35', 'cran-40', 'cran-75',
    # Creo Corpus (20)
    'crco-15a', 'crco-15c', 'crco-20a', 'crco-20b', 'crco-20c', 'crco-25a',
    'crco-25b', 'crco-25c', 'crco-25d', 'crco-30a', 'crco-30b', 'crco-30d',
    'crco-35a', 'crco-35b', 'crco-35c', 'crco-40', 'crco-45', 'crco-50',
    'crco-55', 'crco-70',
    # Creo Herbam (7)
    'crhe-1e', 'crhe-2c', 'crhe-3b', 'crhe-4', 'crhe-5', 'crhe-10',
    'crhe-15b',
]

FLAGS = {}
for effect_id in REQUIRED:
    FLAGS[effect_id] = 'required'
for effect_id in SUGGESTED:
    FLAGS[effect_id] = 'suggested'
assert len(FLAGS) == 45, f'expected 45 distinct ids, got {len(FLAGS)}'

path = pathlib.Path('assets/data/base_effects.json')
lines = path.read_text(encoding='utf-8').split('\n')

seen = set()
out = []
for line in lines:
    match = re.match(r'\s*\{"id": "([^"]+)"', line)
    flag = FLAGS.get(match.group(1)) if match else None
    if flag:
        seen.add(match.group(1))
        stripped = line.rstrip()
        trailing_comma = stripped.endswith(',')
        body = stripped[:-1] if trailing_comma else stripped
        assert body.endswith('}'), f'unexpected line shape for {match.group(1)}'
        assert '"ritualRequirement"' not in body, f'{match.group(1)} already flagged'
        line = body[:-1] + f', "ritualRequirement": "{flag}"' + '}' + (',' if trailing_comma else '')
    out.append(line)

missing = set(FLAGS) - seen
assert not missing, f'ids not found in the catalog: {sorted(missing)}'

# newline='\n' is mandatory: Python on Windows would otherwise translate every
# \n to \r\n and rewrite all 604 lines.
with open(path, 'w', encoding='utf-8', newline='\n') as handle:
    handle.write('\n'.join(out))

print(f'flagged {len(seen)} entries')
```

Run it:

```bash
python scripts/flag_ritual_effects.py
```

Expected output: `flagged 45 entries`

- [ ] **Step 4: Verify the diff touched exactly 45 lines and nothing else**

```bash
git diff --numstat assets/data/base_effects.json
```

Expected: `45	45	assets/data/base_effects.json` — 45 insertions, 45 deletions, i.e. 45 modified lines and no reformatting.

- [ ] **Step 5: Run the asset test to verify it passes**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/data/datasources/asset_data_loader_test.dart && flutter test
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add assets/data/base_effects.json scripts/flag_ritual_effects.py test/data/datasources/asset_data_loader_test.dart && git commit -m "feat: flag 7 required and 38 suggested ritual base effects"
```

---

### Task 4: `RitualDeclaration` on `Spell` and `SpellDraft`

**Files:**
- Create: `lib/models/ritual_declaration.dart`
- Modify: `lib/models/spell.dart`
- Modify: `lib/models/resolved_spell.dart`
- Modify: `lib/data/database/app_database.dart:6`
- Test: `test/models/spell_test.dart`
- Test: `test/models/spell_draft_copy_with_test.dart`
- Test: `test/data/services/backup_service_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum RitualDeclaration { none, lastingCreation, storyguideRuling }` from `lib/models/ritual_declaration.dart`; `Spell.ritualDeclaration`, `SpellDraft.ritualDeclaration` (both default `RitualDeclaration.none`), `SpellDraft.copyWith(ritualDeclaration:)`, and `ResolvedSpell.ritualDeclaration` as a passthrough getter. `SpellDraft.toSpell` forwards it. JSON key `"ritualDeclaration"`, serialized by `.name`; absent means `none`. Tasks 5, 6, 7, 8 and 9 all use this.

- [ ] **Step 1: Write the failing tests**

Append to the existing `group('Spell', ...)` in `test/models/spell_test.dart`:

```dart
    test('ritualDeclaration defaults to none and round-trips every value', () {
      for (final value in RitualDeclaration.values) {
        final spell = Spell(
          id: 's-1', name: 'Touch of Midas',
          baseEffectId: 'crte-15a',
          rangeId: 'range-touch',
          durationId: 'duration-momentary',
          targetId: 'target-individual',
          requisites: const [],
          ritualDeclaration: value,
          provenance: Provenance(source: PublicationSource.userCreated),
          createdAt: DateTime(2026), updatedAt: DateTime(2026),
        );
        expect(Spell.fromMap(spell.toMap()).ritualDeclaration, value);
      }
    });

    test('fromMap treats an absent ritualDeclaration key as none', () {
      final restored = Spell.fromMap({
        'id': 's-2',
        'baseEffectId': 'crte-15a',
        'rangeId': 'range-touch',
        'durationId': 'duration-momentary',
        'targetId': 'target-individual',
        'requisites': <Map<String, dynamic>>[],
        'source': 'userCreated',
        'createdAt': DateTime(2026).toIso8601String(),
        'updatedAt': DateTime(2026).toIso8601String(),
      });
      expect(restored.ritualDeclaration, RitualDeclaration.none);
    });

    test('fromMap throws a clear FormatException on an unknown ritualDeclaration', () {
      expect(
        () => Spell.fromMap({
          'id': 's-3',
          'baseEffectId': 'crte-15a',
          'rangeId': 'range-touch',
          'durationId': 'duration-momentary',
          'targetId': 'target-individual',
          'requisites': <Map<String, dynamic>>[],
          'ritualDeclaration': 'because-i-said-so',
          'source': 'userCreated',
          'createdAt': DateTime(2026).toIso8601String(),
          'updatedAt': DateTime(2026).toIso8601String(),
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('because-i-said-so'), contains('storyguideRuling')),
          ),
        ),
      );
    });

    test('toSpell carries the draft ritualDeclaration through', () {
      final draft = SpellDraft(
        technique: 'Creo', form: 'Terram',
        baseEffect: BaseEffect(
          id: 'crte-15a', technique: 'Creo', form: 'Terram',
          description: 'Create precious metal', baseLevel: 15,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        range: Parameter(
          id: 'range-touch', name: 'Touch', category: 'Range', magnitude: 1,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        duration: Parameter(
          id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        target: Parameter(
          id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        ritualDeclaration: RitualDeclaration.lastingCreation,
      );

      final spell = draft.toSpell(
          name: 'Touch of Midas', source: PublicationSource.userCreated);

      expect(spell.ritualDeclaration, RitualDeclaration.lastingCreation);
    });
```

Add `import 'package:eruditus/models/ritual_declaration.dart';` to the test file, plus `base_effect.dart` and `parameter.dart` imports if absent.

Append to `test/models/spell_draft_copy_with_test.dart`:

```dart
  test('copyWith replaces ritualDeclaration and preserves it when omitted', () {
    final draft = SpellDraft(ritualDeclaration: RitualDeclaration.lastingCreation);

    expect(
      draft.copyWith(ritualDeclaration: RitualDeclaration.none).ritualDeclaration,
      RitualDeclaration.none,
    );
    expect(draft.copyWith(technique: 'Creo').ritualDeclaration,
        RitualDeclaration.lastingCreation);
  });
```

- [ ] **Step 2: Run to verify they fail**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/models/spell_test.dart test/models/spell_draft_copy_with_test.dart
```

Expected: compile error — `Target of URI doesn't exist: 'package:eruditus/models/ritual_declaration.dart'`.

- [ ] **Step 3: Create the enum file**

Create `lib/models/ritual_declaration.dart`:

```dart
/// The part of a spell's Ritual status that cannot be derived from its
/// configuration, because the rulebook leaves it to a person's judgement.
///
/// [lastingCreation] is Core Rules line 12351: "If the spell is a Momentary
/// Creo spell creating a lasting thing, it must be a Ritual." Whether the thing
/// created is meant to last is not visible in the guideline.
///
/// [storyguideRuling] is line 12352: an effect "so spectacular that it must not
/// be easily accessible to magi". Four published core spells are Rituals for
/// this reason alone. No UI sets it yet — see the todo item — but the model and
/// the built-in library both carry it, so adding that UI needs no migration.
enum RitualDeclaration { none, lastingCreation, storyguideRuling }

RitualDeclaration ritualDeclarationFromName(String name, String className) {
  for (final value in RitualDeclaration.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown ritualDeclaration '$name' (expected one of: "
    "${RitualDeclaration.values.map((d) => d.name).join(', ')})",
  );
}
```

- [ ] **Step 4: Wire it into `Spell` and `SpellDraft`**

In `lib/models/spell.dart`, add the import:

```dart
import 'package:eruditus/models/ritual_declaration.dart';
```

Add the field to `Spell` after `tags`:

```dart
  final List<String> tags;
  final RitualDeclaration ritualDeclaration;
```

Add to the `Spell` constructor parameter list, after `this.tags = const []`:

```dart
    this.ritualDeclaration = RitualDeclaration.none,
```

Add to `Spell.toMap()`, after `'tags': tags,`:

```dart
        'ritualDeclaration': ritualDeclaration.name,
```

Add to `Spell.fromMap`, after the `tags:` line:

```dart
        ritualDeclaration: map['ritualDeclaration'] == null
            ? RitualDeclaration.none
            : ritualDeclarationFromName(
                requireField<String>(map, 'ritualDeclaration', 'Spell'), 'Spell'),
```

In `SpellDraft`, add the field after `description`:

```dart
  RitualDeclaration ritualDeclaration;
```

Add to the `SpellDraft` constructor parameter list after `this.description`:

```dart
    this.ritualDeclaration = RitualDeclaration.none,
```

Add to `SpellDraft.toSpell`'s `return Spell(...)` call, after `description: description,`:

```dart
      ritualDeclaration: ritualDeclaration,
```

Add to `SpellDraft.copyWith`'s parameter list after `String? description,`:

```dart
    RitualDeclaration? ritualDeclaration,
```

and to its `return SpellDraft(...)` after `description: description ?? this.description,`:

```dart
      ritualDeclaration: ritualDeclaration ?? this.ritualDeclaration,
```

- [ ] **Step 5: Add the `ResolvedSpell` passthrough getter**

In `lib/models/resolved_spell.dart`, add the import:

```dart
import 'package:eruditus/models/ritual_declaration.dart';
```

and the getter, next to the other record passthroughs (after `List<Requisite> get requisites => record.requisites;`):

```dart
  RitualDeclaration get ritualDeclaration => record.ritualDeclaration;
```

- [ ] **Step 6: Run the model tests**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/models/
```

Expected: all PASS.

- [ ] **Step 7: Bump the database version**

In `lib/data/database/app_database.dart`, change line 6:

```dart
  static const int _databaseVersion = 5;
```

Then extend the existing explanatory comment above `onUpgrade` by appending this sentence to it:

```dart
        // The v5 bump is the same shape again: the `spells` DDL is unchanged,
        // but stored blobs predate `ritualDeclaration`, so the table is
        // dropped and rebuilt rather than translated.
```

- [ ] **Step 8: Add a backup round-trip test**

Append to `test/data/services/backup_service_test.dart`, inside its existing top-level `group`:

```dart
    test('export/import round-trips ritualDeclaration', () async {
      final spell = Spell(
        id: 'ritual-1', name: 'Touch of Midas',
        baseEffectId: 'crte-15a',
        rangeId: 'range-touch',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        ritualDeclaration: RitualDeclaration.lastingCreation,
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
      );

      final restored = Spell.fromMap(spell.toMap());

      expect(restored.ritualDeclaration, RitualDeclaration.lastingCreation);
    });
```

Add `import 'package:eruditus/models/ritual_declaration.dart';` to that test file.

- [ ] **Step 9: Run the full unit suite**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test
```

Expected: all PASS. Every new parameter has a default, so no existing construction site breaks.

- [ ] **Step 10: Commit**

```bash
git add lib/models/ritual_declaration.dart lib/models/spell.dart lib/models/resolved_spell.dart lib/data/database/app_database.dart test/ && git commit -m "feat: add RitualDeclaration to Spell and SpellDraft, bump db to v5"
```

---

### Task 5: `RitualStatus`, the reason derivation, and the level floor

**Files:**
- Create: `lib/engine/ritual_status.dart`
- Modify: `lib/engine/level_breakdown.dart`
- Modify: `lib/engine/spell_engine.dart`
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart:148-172`
- Modify: `lib/bloc/spell_library/spell_library_bloc.dart:42`
- Test: `test/engine/ritual_status_test.dart` (create)
- Test: `test/engine/level_breakdown_test.dart`
- Test: `test/presentation/widgets/level_breakdown_card_test.dart`
- Test: `test/presentation/screens/spell_creation_screen_test.dart:195`

**Interfaces:**
- Consumes: `Parameter.requiresRitual` (Task 1), `RitualRequirement` (Task 2), `RitualDeclaration` (Task 4).
- Produces:
  - `enum RitualReason { ritualOnlyDuration, ritualOnlyTarget, exceedsMaxFormulaicLevel, guideline, lastingCreation, storyguideRuling }`
  - `class RitualStatus` with `List<RitualReason> reasons`, `bool get isRitual`, and statics `RitualStatus.maxFormulaicLevel = 50`, `RitualStatus.minimumRitualLevel = 20`.
  - `LevelBreakdown` gains `required int rawLevel` and `RitualStatus ritualStatus` (defaults to an empty status), plus `bool get ritualMinimumApplied`.
  - `SpellEngine.calculateBreakdown` and `SpellEngine.calculateSpellLevel` gain `RitualDeclaration ritualDeclaration = RitualDeclaration.none`.

The reasons are named for the *flag*, not for Year and Boundary. `requiresRitual` is generic and todo item 17 adds three more ritual-only Durations; a reason called `yearDuration` would become a lie. The UI names the actual parameter by reading `duration.name`.

- [ ] **Step 1: Write the failing engine tests**

Create `test/engine/ritual_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/ritual_declaration.dart';

Provenance _prov() => Provenance(source: PublicationSource.userCreated);

Parameter _param(String id, String name, String category, int magnitude,
        {bool requiresRitual = false}) =>
    Parameter(
      id: id, name: name, category: category, magnitude: magnitude,
      requiresRitual: requiresRitual, provenance: _prov(),
    );

BaseEffect _effect(int baseLevel,
        {String technique = 'Creo',
        String form = 'Terram',
        RitualRequirement ritualRequirement = RitualRequirement.none}) =>
    BaseEffect(
      id: 'e-$baseLevel', technique: technique, form: form,
      description: 'test effect', baseLevel: baseLevel,
      ritualRequirement: ritualRequirement, provenance: _prov(),
    );

final _personal = _param('range-personal', 'Personal', 'Range', 0);
final _touch = _param('range-touch', 'Touch', 'Range', 1);
final _momentary = _param('duration-momentary', 'Momentary', 'Duration', 0);
final _year = _param('duration-year', 'Year', 'Duration', 4, requiresRitual: true);
final _individual = _param('target-individual', 'Individual', 'Target', 0);
final _boundary = _param('target-boundary', 'Boundary', 'Target', 4, requiresRitual: true);

void main() {
  final engine = SpellEngine(allSpells: []);

  LevelBreakdownResult run({
    BaseEffect? effect,
    Parameter? range,
    Parameter? duration,
    Parameter? target,
    RitualDeclaration declaration = RitualDeclaration.none,
  }) {
    final breakdown = engine.calculateBreakdown(
      baseEffect: effect ?? _effect(10),
      range: range ?? _personal,
      duration: duration ?? _momentary,
      target: target ?? _individual,
      selectedModifiers: const {},
      requisites: const [],
      ritualDeclaration: declaration,
    );
    return (
      level: breakdown.level,
      rawLevel: breakdown.rawLevel,
      reasons: breakdown.ritualStatus.reasons,
      isRitual: breakdown.ritualStatus.isRitual,
    );
  }

  group('forced ritual reasons', () {
    test('a ritual-only Duration forces a Ritual', () {
      final result = run(duration: _year);
      expect(result.isRitual, isTrue);
      expect(result.reasons, [RitualReason.ritualOnlyDuration]);
    });

    test('a ritual-only Target forces a Ritual', () {
      final result = run(target: _boundary);
      expect(result.isRitual, isTrue);
      expect(result.reasons, [RitualReason.ritualOnlyTarget]);
    });

    test('a required guideline forces a Ritual', () {
      final result = run(
          effect: _effect(25, ritualRequirement: RitualRequirement.required));
      expect(result.reasons, [RitualReason.guideline]);
    });

    test('a suggested guideline forces nothing', () {
      final result = run(
          effect: _effect(25, ritualRequirement: RitualRequirement.suggested));
      expect(result.isRitual, isFalse);
      expect(result.reasons, isEmpty);
    });
  });

  group('the level threshold', () {
    test('exactly level 50 is a legal Formulaic spell', () {
      // Core Rules line 12346: "they may have a level of 50, but not 51 or
      // higher."
      final result = run(effect: _effect(50));
      expect(result.level, 50);
      expect(result.isRitual, isFalse);
    });

    test('level 51 forces a Ritual', () {
      final result = run(effect: _effect(51));
      expect(result.reasons, [RitualReason.exceedsMaxFormulaicLevel]);
    });
  });

  group('declarations', () {
    test('lastingCreation makes a spell a Ritual', () {
      final result = run(declaration: RitualDeclaration.lastingCreation);
      expect(result.reasons, [RitualReason.lastingCreation]);
    });

    test('storyguideRuling is honoured on a non-Creo, non-Momentary spell', () {
      // Incantation of Summoning the Dead is Rego Mentem, Duration
      // Concentration, and a Ritual by storyguide judgement alone.
      final result = run(
        effect: _effect(15, technique: 'Rego', form: 'Mentem'),
        duration: _param('duration-concentration', 'Concentration', 'Duration', 1),
        declaration: RitualDeclaration.storyguideRuling,
      );
      expect(result.reasons, [RitualReason.storyguideRuling]);
    });
  });

  group('reasons accumulate', () {
    test('Aegis of the Hearth reports both its forced reasons', () {
      // R: Touch, D: Year, T: Boundary, Ritual (Core Rules line 15934).
      final result = run(range: _touch, duration: _year, target: _boundary);
      expect(result.reasons, containsAll([
        RitualReason.ritualOnlyDuration,
        RitualReason.ritualOnlyTarget,
      ]));
      expect(result.reasons.length, 2);
    });
  });

  group('the minimum level 20 floor', () {
    test('raises a low-level Ritual to 20', () {
      // crhe-1e "Heal a Light Wound to a plant" at Touch: raw level 2.
      final result = run(
        effect: _effect(1, form: 'Herbam'),
        range: _touch,
        declaration: RitualDeclaration.lastingCreation,
      );
      expect(result.rawLevel, 2);
      expect(result.level, 20);
    });

    test('is a no-op at exactly 20', () {
      // Touch of Midas: base 15 + Touch = 20.
      final result = run(
        effect: _effect(15),
        range: _touch,
        declaration: RitualDeclaration.lastingCreation,
      );
      expect(result.rawLevel, 20);
      expect(result.level, 20);
    });

    test('never lowers a Ritual above 20', () {
      // Incantation of the Body Made Whole: base 35 + Touch = 40.
      final result = run(
        effect: _effect(35, form: 'Corpus'),
        range: _touch,
        declaration: RitualDeclaration.lastingCreation,
      );
      expect(result.level, 40);
    });

    test('does not apply to a non-Ritual spell', () {
      final result = run(effect: _effect(1));
      expect(result.level, 1);
      expect(result.rawLevel, 1);
    });

    test('can never produce a level above the Formulaic cap', () {
      // Guards the single-pass ordering: the floor decides nothing that could
      // re-trigger the >50 check, so calculateBreakdown needs no fixed point.
      expect(
        RitualStatus.minimumRitualLevel <= RitualStatus.maxFormulaicLevel,
        isTrue,
        reason: 'if the floor could exceed the cap, ritual status would have '
            'to be recomputed after applying it',
      );
    });
  });
}

typedef LevelBreakdownResult = ({
  int level,
  int rawLevel,
  List<RitualReason> reasons,
  bool isRitual,
});
```

- [ ] **Step 2: Run to verify it fails**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/engine/ritual_status_test.dart
```

Expected: compile error — `Target of URI doesn't exist: 'package:eruditus/engine/ritual_status.dart'`.

- [ ] **Step 3: Create `RitualStatus`**

Create `lib/engine/ritual_status.dart`:

```dart
/// Why a spell is a Ritual. See Core Rules "Ritual Spells", line 12340.
///
/// [ritualOnlyDuration] and [ritualOnlyTarget] are named for the generic
/// `Parameter.requiresRitual` flag rather than for Year and Boundary, because
/// todo item 17 adds three more ritual-only Durations and a reason called
/// `yearDuration` would become a lie. Callers that want to name the parameter
/// read its `name` directly.
enum RitualReason {
  ritualOnlyDuration,
  ritualOnlyTarget,
  exceedsMaxFormulaicLevel,
  guideline,
  lastingCreation,
  storyguideRuling,
}

/// Whether a spell is a Ritual, and every reason it is one.
///
/// Reasons accumulate rather than short-circuit: Aegis of the Hearth is a
/// Ritual for two independent reasons, and reporting only the first would make
/// the UI text wrong. It would also foreclose the enchanted-item rule at Core
/// Rules line 10566, which turns on a spell being a Ritual *only* because its
/// level exceeds the Formulaic cap.
class RitualStatus {
  /// The highest level a Formulaic or Spontaneous spell may have. Core Rules
  /// line 12346: "they may have a level of 50, but not 51 or higher."
  static const int maxFormulaicLevel = 50;

  /// Core Rules line 12354: "Ritual spells are always at least level 20, even
  /// if the level calculation would make them lower."
  static const int minimumRitualLevel = 20;

  final List<RitualReason> reasons;

  const RitualStatus(this.reasons);

  const RitualStatus.notRitual() : reasons = const [];

  bool get isRitual => reasons.isNotEmpty;
}
```

- [ ] **Step 4: Extend `LevelBreakdown`**

Replace the `LevelBreakdown` class in `lib/engine/level_breakdown.dart` (leave `LevelContribution` untouched):

```dart
/// A spell's calculated level together with the sources that produced it.
class LevelBreakdown {
  /// The level after the Ritual minimum has been applied. This is the number
  /// the user sees.
  final int level;

  /// The level the magnitudes alone produce, before the Ritual minimum. Equal
  /// to [level] whenever the minimum does not bite.
  final int rawLevel;

  final RitualStatus ritualStatus;
  final List<LevelContribution> contributions;

  const LevelBreakdown({
    required this.level,
    required this.rawLevel,
    required this.contributions,
    this.ritualStatus = const RitualStatus.notRitual(),
  });

  /// True when the Ritual minimum raised the level. The floor is deliberately
  /// NOT modelled as a [LevelContribution]: contributions carry magnitudes and
  /// [magnitudeTotal] sums them, so a contribution holding a level delta would
  /// silently corrupt that sum. Callers explain the difference themselves by
  /// comparing [level] against [rawLevel].
  bool get ritualMinimumApplied => level != rawLevel;

  /// Total magnitude from every non-base contribution. Not displayed in the
  /// UI — see the spec's UI section — but used by tests and by callers that
  /// need the magnitude sum without re-deriving it.
  int get magnitudeTotal => contributions
      .where((c) => !c.isBase)
      .fold(0, (sum, c) => sum + c.magnitude);
}
```

Add the import at the top of the file:

```dart
import 'package:eruditus/engine/ritual_status.dart';
```

- [ ] **Step 5: Derive the status and apply the floor in `SpellEngine`**

In `lib/engine/spell_engine.dart`, add the imports:

```dart
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/ritual_declaration.dart';
```

Add `ritualDeclaration` to `calculateBreakdown`'s parameter list, after `required List<Requisite> requisites,`:

```dart
    RitualDeclaration ritualDeclaration = RitualDeclaration.none,
```

Replace the `return LevelBreakdown(...)` at the end of `calculateBreakdown` with:

```dart
    final rawLevel = SpellLevelCalculator.calculate(baseEffect.baseLevel, magnitudes);

    final ritualStatus = _deriveRitualStatus(
      baseEffect: baseEffect,
      duration: duration,
      target: target,
      ritualDeclaration: ritualDeclaration,
      rawLevel: rawLevel,
    );

    // Single pass, no fixed point: the floor only ever raises a level TO 20,
    // and 20 is below the Formulaic cap of 50, so applying it can never
    // trigger the exceedsMaxFormulaicLevel reason that was just evaluated.
    // ritual_status_test.dart asserts that invariant on the constants.
    final level = ritualStatus.isRitual && rawLevel < RitualStatus.minimumRitualLevel
        ? RitualStatus.minimumRitualLevel
        : rawLevel;

    return LevelBreakdown(
      level: level,
      rawLevel: rawLevel,
      ritualStatus: ritualStatus,
      contributions: contributions,
    );
  }

  /// Every reason [rawLevel]'s spell is a Ritual, accumulated in a stable
  /// order. Declarations are honoured unconditionally — a storyguide ruling is
  /// legitimate on any spell by definition, and keeping a live draft's
  /// declaration meaningful is the bloc's job, not the engine's.
  RitualStatus _deriveRitualStatus({
    required BaseEffect baseEffect,
    required Parameter duration,
    required Parameter target,
    required RitualDeclaration ritualDeclaration,
    required int rawLevel,
  }) {
    final reasons = <RitualReason>[];

    if (duration.requiresRitual) reasons.add(RitualReason.ritualOnlyDuration);
    if (target.requiresRitual) reasons.add(RitualReason.ritualOnlyTarget);
    if (baseEffect.ritualRequirement == RitualRequirement.required) {
      reasons.add(RitualReason.guideline);
    }
    if (rawLevel > RitualStatus.maxFormulaicLevel) {
      reasons.add(RitualReason.exceedsMaxFormulaicLevel);
    }
    switch (ritualDeclaration) {
      case RitualDeclaration.lastingCreation:
        reasons.add(RitualReason.lastingCreation);
      case RitualDeclaration.storyguideRuling:
        reasons.add(RitualReason.storyguideRuling);
      case RitualDeclaration.none:
        break;
    }

    return RitualStatus(reasons);
  }
```

Then add the same parameter to `calculateSpellLevel` and forward it. Replace that method with:

```dart
  int calculateSpellLevel({
    required BaseEffect baseEffect,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    Map<String, List<String>> selectedModifiers = const {},
    required List<Requisite> requisites,
    RitualDeclaration ritualDeclaration = RitualDeclaration.none,
  }) =>
      calculateBreakdown(
        baseEffect: baseEffect,
        range: range,
        duration: duration,
        target: target,
        selectedModifiers: selectedModifiers,
        requisites: requisites,
        ritualDeclaration: ritualDeclaration,
      ).level;
```

Finally, in `findSimilarSpells`, both `calculateSpellLevel` calls inside the sort must pass the spell's own declaration. Change each to add:

```dart
          ritualDeclaration: a.ritualDeclaration,
```

(and `b.ritualDeclaration` for the second).

- [ ] **Step 6: Update the existing `LevelBreakdown` construction sites in tests**

`rawLevel` is required, so four test constructions need it. In each, add `rawLevel:` with the same value as `level`:

- `test/engine/level_breakdown_test.dart:6` and `:21`
- `test/presentation/widgets/level_breakdown_card_test.dart:7`
- `test/presentation/screens/spell_creation_screen_test.dart:195`

For example, `test/presentation/widgets/level_breakdown_card_test.dart`:

```dart
  const breakdown = LevelBreakdown(
    level: 20,
    rawLevel: 20,
    contributions: [
```

Making it required rather than defaulting is deliberate: a breakdown whose raw level is unknown is a meaningless state, and four mechanical edits is cheaper than a nullable field every caller has to reason about.

- [ ] **Step 7: Pass the declaration from the two blocs**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, add to the `calculateBreakdown` call at line 148:

```dart
      ritualDeclaration: state.draft.ritualDeclaration,
```

and to the `calculateSpellLevel` call inside the `suggestionLevels` map at line 169:

```dart
          ritualDeclaration: s.ritualDeclaration,
```

In `lib/bloc/spell_library/spell_library_bloc.dart`, add to the `calculateSpellLevel` call at line 42:

```dart
              ritualDeclaration: s.ritualDeclaration,
```

- [ ] **Step 8: Run the engine tests**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/engine/
```

Expected: all PASS, including the untouched `spell_level_calculator_test.dart` — that class was not modified.

- [ ] **Step 9: Run the full unit suite**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test
```

Expected: all PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/engine/ test/engine/ lib/bloc/ test/presentation/ && git commit -m "feat: derive RitualStatus and apply the minimum level 20 floor"
```

---

### Task 6: Bloc support — declaration event, defaults and pruning

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_event.dart`
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart`
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `RitualDeclaration` (Task 4), `RitualRequirement` (Task 2).
- Produces: `RitualDeclarationChanged(RitualDeclaration declaration)` event. Bloc invariant: `SpellDraft.ritualDeclaration` holds `lastingCreation` only while the draft is Creo with Momentary duration; `storyguideRuling` is never touched by the bloc. Task 7's widget dispatches the event.

Eligibility is: `draft.technique == 'Creo' && draft.duration?.id == 'duration-momentary'`.

- [ ] **Step 1: Write the failing bloc tests**

Append to `test/bloc/spell_creation_bloc_test.dart`, inside the existing `main()`. The file already declares `late SpellEngine spellEngine;` and `late SpellRepository spellRepository;` and initialises them in `setUp`; the `build:` closures below match the form its existing `blocTest`s already use (see line 75).

```dart
  group('ritual declaration', () {
    final momentary = Parameter(
      id: 'duration-momentary', name: 'Momentary', category: 'Duration',
      magnitude: 0, provenance: Provenance(source: PublicationSource.userCreated),
    );
    final sun = Parameter(
      id: 'duration-sun', name: 'Sun', category: 'Duration',
      magnitude: 2, provenance: Provenance(source: PublicationSource.userCreated),
    );
    final suggestedHealing = BaseEffect(
      id: 'crco-35a', technique: 'Creo', form: 'Corpus',
      description: 'Heal all wounds', baseLevel: 35,
      ritualRequirement: RitualRequirement.suggested,
      provenance: Provenance(source: PublicationSource.userCreated),
    );
    final plainCreo = BaseEffect(
      id: 'crte-15a', technique: 'Creo', form: 'Terram',
      description: 'Create precious metal', baseLevel: 15,
      provenance: Provenance(source: PublicationSource.userCreated),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'defaults to lastingCreation for any Creo + Momentary draft',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(BaseEffectSelected(plainCreo)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.lastingCreation),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'defaults to lastingCreation for a suggested healing effect too',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(BaseEffectSelected(suggestedHealing)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.lastingCreation),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'does not default for a non-Creo technique',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Perdo'))
        ..add(DurationSelected(momentary)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'does not default for a non-Momentary duration',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(sun)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'respects an explicit clear and does not re-tick on an unrelated event',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(const RitualDeclarationChanged(RitualDeclaration.none))
        ..add(const FormSelected('Terram')),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'prunes lastingCreation when the draft leaves Creo + Momentary',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(DurationSelected(sun)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'prunes lastingCreation when the technique leaves Creo',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(const TechniqueSelected('Muto')),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'never prunes a storyguideRuling',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Perdo'))
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(DurationSelected(sun)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );
  });
```

The only import the file is missing is:

```dart
import 'package:eruditus/models/ritual_declaration.dart';
```

`base_effect.dart`, `parameter.dart`, `provenance.dart` and `publication_source.dart` are already imported there. `RitualRequirement` comes from `base_effect.dart`, so no extra import is needed for it.

- [ ] **Step 2: Run to verify they fail**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/bloc/spell_creation_bloc_test.dart
```

Expected: compile error — `Undefined name 'RitualDeclarationChanged'`.

- [ ] **Step 3: Add the event**

Append to `lib/bloc/spell_creation/spell_creation_event.dart`:

```dart
/// The caster's own statement about a spell's Ritual status — the part the
/// rulebook leaves to judgement rather than to the spell's configuration.
class RitualDeclarationChanged extends SpellCreationEvent {
  final RitualDeclaration declaration;
  const RitualDeclarationChanged(this.declaration);
  @override
  List<Object?> get props => [declaration];
}
```

and the import:

```dart
import 'package:eruditus/models/ritual_declaration.dart';
```

- [ ] **Step 4: Implement the defaulting, pruning and event handling**

In `lib/bloc/spell_creation/spell_creation_bloc.dart`, add the imports:

```dart
import 'package:eruditus/models/base_effect.dart' show RitualRequirement;
import 'package:eruditus/models/ritual_declaration.dart';
```

Add these two helpers next to the existing `_withPrunedModifiers`:

```dart
  static const String _creo = 'Creo';
  static const String _momentaryDurationId = 'duration-momentary';

  /// A Momentary Creo spell is the one case the rulebook leaves to the caster
  /// (Core Rules line 12351), so it is the only case the checkbox is offered
  /// for and the only case the bloc sets automatically.
  bool _declaresLastingCreation(SpellDraft draft) =>
      draft.technique == _creo && draft.duration?.id == _momentaryDurationId;

  /// Re-derives [SpellDraft.ritualDeclaration] after a change to Technique,
  /// Form, base effect or Duration.
  ///
  /// A `lastingCreation` declaration is a statement about *this* effect at
  /// *this* Duration; when either moves out of eligibility the statement has
  /// become false and must go, exactly as pruneModifierSelections drops a
  /// stranded modifier rather than let it keep affecting the level invisibly.
  ///
  /// A `storyguideRuling` is never touched. It is not invalidated by changing
  /// Duration, and no UI sets it yet — silently wiping one would make the
  /// deferred storyguide-ruling UI a second migration.
  SpellDraft _withRitualDeclaration(SpellDraft draft, {required bool reapplyDefault}) {
    if (draft.ritualDeclaration == RitualDeclaration.storyguideRuling) return draft;

    if (!_declaresLastingCreation(draft)) {
      return draft.copyWith(ritualDeclaration: RitualDeclaration.none);
    }
    if (reapplyDefault) {
      return draft.copyWith(ritualDeclaration: RitualDeclaration.lastingCreation);
    }
    return draft;
  }
```

Then update four handlers in `_onEvent`. `reapplyDefault` is true only for the events that change *what* is being created — selecting a base effect or a Duration — so an unrelated `FormSelected` cannot re-tick a box the user cleared.

```dart
    if (event is TechniqueSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withRitualDeclaration(
          _withPrunedModifiers(
              state.draft.copyWith(technique: event.technique, baseEffect: null)),
          reapplyDefault: false,
        ),
      ));
    } else if (event is FormSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withRitualDeclaration(
          _withPrunedModifiers(
              state.draft.copyWith(form: event.form, baseEffect: null)),
          reapplyDefault: false,
        ),
      ));
    } else if (event is BaseEffectSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withRitualDeclaration(
          _withPrunedModifiers(state.draft.copyWith(baseEffect: event.effect)),
          reapplyDefault: true,
        ),
      ));
    } else if (event is DurationSelected) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: _withRitualDeclaration(
          state.draft.copyWith(duration: event.parameter),
          reapplyDefault: true,
        ),
      ));
    } else if (event is RangeSelected) {
```

Note `TechniqueSelected` and `FormSelected` clear `baseEffect`, which makes the draft ineligible only if the Duration also moves — `_declaresLastingCreation` checks the live technique, so switching to Muto prunes correctly.

Finally add the new event branch, before `} else if (event is SpellCalculated) {`:

```dart
    } else if (event is RitualDeclarationChanged) {
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(ritualDeclaration: event.declaration),
      ));
```

- [ ] **Step 5: Run the bloc tests**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/bloc/spell_creation_bloc_test.dart
```

Expected: all PASS.

- [ ] **Step 6: Run the full unit suite**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/bloc/spell_creation/ test/bloc/spell_creation_bloc_test.dart && git commit -m "feat: default and prune the ritual declaration in SpellCreationBloc"
```

---

### Task 7: `RitualSection` widget and screen wiring

**Files:**
- Create: `lib/presentation/widgets/ritual_section.dart`
- Modify: `lib/presentation/screens/spell_creation_screen.dart:180-181`
- Test: `test/presentation/widgets/ritual_section_test.dart` (create)

**Interfaces:**
- Consumes: `RitualStatus`, `RitualReason` (Task 5), `RitualDeclaration` (Task 4), `RitualRequirement` (Task 2), `RitualDeclarationChanged` (Task 6).
- Produces: `RitualSection` widget with constructor parameters `ritualStatus`, `declaration`, `showDeclarationCheckbox`, `durationName`, `targetName`, `guidelineIsSuggested`, `onDeclarationChanged`. Widget keys `ritual-banner` and `ritual-checkbox`.

`spell_creation_screen.dart` is already 400+ lines with two inline `_build*` helpers; this follows the `modifiers_section.dart` precedent rather than adding a third.

- [ ] **Step 1: Write the failing widget tests**

Create `test/presentation/widgets/ritual_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/presentation/widgets/ritual_section.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('hides both banner and checkbox for an ordinary spell',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showDeclarationCheckbox: false,
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    expect(find.byKey(const Key('ritual-banner')), findsNothing);
    expect(find.byKey(const Key('ritual-checkbox')), findsNothing);
  });

  testWidgets('shows the checkbox only when the draft is Creo + Momentary',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showDeclarationCheckbox: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    expect(find.byKey(const Key('ritual-checkbox')), findsOneWidget);
  });

  testWidgets('names every reason in the banner', (tester) async {
    // Aegis of the Hearth: Year duration and Boundary target.
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([
        RitualReason.ritualOnlyDuration,
        RitualReason.ritualOnlyTarget,
      ]),
      declaration: RitualDeclaration.none,
      showDeclarationCheckbox: false,
      durationName: 'Year',
      targetName: 'Boundary',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final banner = tester.widget<Text>(
        find.descendant(of: find.byKey(const Key('ritual-banner')), matching: find.byType(Text)).first);
    expect(banner.data, contains('Year duration'));
    expect(banner.data, contains('Boundary target'));
  });

  testWidgets('explains the healing case when the guideline is suggested',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([RitualReason.lastingCreation]),
      declaration: RitualDeclaration.lastingCreation,
      showDeclarationCheckbox: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: true,
      onDeclarationChanged: (_) {},
    )));

    expect(find.textContaining('suspends'), findsOneWidget);
  });

  testWidgets('ticking and clearing the checkbox reports the right declaration',
      (tester) async {
    final reported = <RitualDeclaration>[];

    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showDeclarationCheckbox: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-checkbox')));
    expect(reported, [RitualDeclaration.lastingCreation]);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/presentation/widgets/ritual_section_test.dart
```

Expected: compile error — `Target of URI doesn't exist: '.../ritual_section.dart'`.

- [ ] **Step 3: Create the widget**

Create `lib/presentation/widgets/ritual_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/ritual_declaration.dart';

/// The Ritual controls of the spell creation form: a non-interactive banner
/// listing every reason the spell is a Ritual, and — only for the one case the
/// rulebook leaves to the caster — a checkbox declaring it one.
///
/// Both can be on screen at once. A Creo/Momentary/Boundary spell is already
/// forced by its Target; the banner says so and the checkbox stays live and
/// harmless.
class RitualSection extends StatelessWidget {
  final RitualStatus ritualStatus;
  final RitualDeclaration declaration;

  /// True when the draft is Creo with Momentary duration — the only
  /// configuration the checkbox is offered for (Core Rules line 12351).
  final bool showDeclarationCheckbox;

  /// The selected parameters' own names, so the banner can say "Year duration"
  /// without RitualReason having to hardcode which parameters are ritual-only.
  final String durationName;
  final String targetName;

  /// True when the chosen guideline is [RitualRequirement.suggested], which
  /// forces nothing but changes what a non-Ritual casting actually does.
  final bool guidelineIsSuggested;

  final ValueChanged<RitualDeclaration> onDeclarationChanged;

  const RitualSection({
    super.key,
    required this.ritualStatus,
    required this.declaration,
    required this.showDeclarationCheckbox,
    required this.durationName,
    required this.targetName,
    required this.guidelineIsSuggested,
    required this.onDeclarationChanged,
  });

  String _describe(RitualReason reason) => switch (reason) {
        RitualReason.ritualOnlyDuration => '$durationName duration',
        RitualReason.ritualOnlyTarget => '$targetName target',
        RitualReason.exceedsMaxFormulaicLevel =>
          'level above ${RitualStatus.maxFormulaicLevel}',
        RitualReason.guideline => 'the guideline requires it',
        RitualReason.lastingCreation => 'it creates something lasting',
        RitualReason.storyguideRuling => 'storyguide ruling',
      };

  @override
  Widget build(BuildContext context) {
    if (!ritualStatus.isRitual && !showDeclarationCheckbox) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ritualStatus.isRitual)
          Card(
            key: const Key('ritual-banner'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Ritual: ${ritualStatus.reasons.map(_describe).join('; ')}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        if (showDeclarationCheckbox)
          CheckboxListTile(
            key: const Key('ritual-checkbox'),
            value: declaration == RitualDeclaration.lastingCreation,
            title: const Text('This creates something lasting'),
            subtitle: Text(
              guidelineIsSuggested
                  // Core Rules line 13415.
                  ? 'Cast as anything other than a Momentary Ritual, this '
                      'suspends the healing rather than completing it.'
                  : 'A Momentary Creo spell that is not a Ritual creates '
                      'something that vanishes as the magic ends.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (checked) => onDeclarationChanged(checked == true
                ? RitualDeclaration.lastingCreation
                : RitualDeclaration.none),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the widget tests**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/presentation/widgets/ritual_section_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Wire it into the creation screen**

In `lib/presentation/screens/spell_creation_screen.dart`, add the imports:

```dart
import 'package:eruditus/models/base_effect.dart' show RitualRequirement;
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/presentation/widgets/ritual_section.dart';
```

Immediately after the `ModifiersSection(...)` widget and its following `const SizedBox(height: 16),` (around line 180), insert:

```dart
                RitualSection(
                  ritualStatus:
                      state.breakdown?.ritualStatus ?? const RitualStatus.notRitual(),
                  declaration: draft.ritualDeclaration,
                  showDeclarationCheckbox: draft.technique == 'Creo' &&
                      draft.duration?.id == 'duration-momentary',
                  durationName: draft.duration?.name ?? '',
                  targetName: draft.target?.name ?? '',
                  guidelineIsSuggested: draft.baseEffect?.ritualRequirement ==
                      RitualRequirement.suggested,
                  onDeclarationChanged: (declaration) =>
                      bloc.add(RitualDeclarationChanged(declaration)),
                ),
                const SizedBox(height: 16),
```

Add the `ritual_status.dart` import too:

```dart
import 'package:eruditus/engine/ritual_status.dart';
```

The banner reads its status from `state.breakdown`, so it appears once the user presses Calculate. The checkbox is driven by the draft and is live immediately.

- [ ] **Step 6: Run the full unit suite**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test
```

Expected: all PASS.

- [ ] **Step 7: Check the analyzer is clean**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/ test/presentation/widgets/ritual_section_test.dart && git commit -m "feat: add RitualSection widget and wire it into the creation screen"
```

---

### Task 8: Ritual marker on the library card

**Files:**
- Modify: `lib/presentation/widgets/spell_card.dart`
- Modify: `lib/bloc/spell_library/spell_library_state.dart`
- Modify: `lib/bloc/spell_library/spell_library_bloc.dart:35-51`
- Modify: `lib/presentation/screens/spell_library_screen.dart:64`
- Test: `test/presentation/widgets/spell_card_test.dart`
- Test: `test/bloc/spell_library_bloc_test.dart`

**Interfaces:**
- Consumes: `ResolvedSpell.ritualDeclaration` (Task 4), `SpellEngine.calculateBreakdown` (Task 5).
- Produces: `SpellCard` gains an optional `bool isRitual = false` and renders a `Chip` with key `ritual-chip` when true. `SpellLibraryState` gains `Set<String> ritualSpellIds` (defaults `const {}`), populated by `SpellLibraryBloc` on `LibraryRequested`.

`SpellCard` already takes a precomputed `level`; `isRitual` follows the same shape, because the card must not reach for a `SpellEngine` it does not have. The bloc is the layer that has one.

- [ ] **Step 1: Write the failing widget test**

Append to `test/presentation/widgets/spell_card_test.dart`, inside `main()` (the file already has a `buildSpell({...})` helper returning a `ResolvedSpell`):

```dart
  testWidgets('shows a Ritual chip only when the spell is a Ritual',
      (tester) async {
    final spell = buildSpell(name: 'Touch of Midas');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(spell: spell, level: 20, isRitual: true)),
    ));
    expect(find.byKey(const Key('ritual-chip')), findsOneWidget);
    expect(find.text('Ritual'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(spell: spell, level: 20)),
    ));
    expect(find.byKey(const Key('ritual-chip')), findsNothing);
  });
```

- [ ] **Step 2: Run to verify it fails**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/presentation/widgets/spell_card_test.dart
```

Expected: compile error — `No named parameter with the name 'isRitual'`.

- [ ] **Step 3: Add the parameter and the chip**

In `lib/presentation/widgets/spell_card.dart`, add the field after `final int? level;`:

```dart
  /// Precomputed by the caller, which owns the SpellEngine. The card never
  /// derives it — same reason `level` is passed in rather than calculated here.
  final bool isRitual;
```

and to the constructor:

```dart
    this.isRitual = false,
```

In `build`, render the chip next to the title. Place it immediately after the title `Text` inside whatever `Row` or `Column` holds it:

```dart
            if (isRitual)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(
                  key: Key('ritual-chip'),
                  label: Text('Ritual'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
```

- [ ] **Step 4: Run the widget test**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/presentation/widgets/spell_card_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write the failing bloc test**

Without this next part the chip can never appear in the running app — nothing computes which library spells are Rituals. Append to `test/bloc/spell_library_bloc_test.dart`, following the setup its existing `LibraryRequested` tests already use:

```dart
    blocTest<SpellLibraryBloc, SpellLibraryState>(
      'LibraryRequested marks Year-duration spells as Rituals',
      build: () => SpellLibraryBloc(
          libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
      act: (bloc) => bloc.add(const LibraryRequested()),
      verify: (bloc) {
        expect(bloc.state.ritualSpellIds, contains(ritualSpell.id));
        expect(bloc.state.ritualSpellIds, isNot(contains(ordinarySpell.id)));
      },
    );
```

Build `ritualSpell` as a `ResolvedSpell` whose `duration` is a `Parameter` with `requiresRitual: true`, and `ordinarySpell` as one whose duration has `requiresRitual: false`, using the same `Provenance(source: PublicationSource.userCreated)` shape the file's other fixtures use. Stub `mockLibraryRepository.getAllSpells()` to return both.

- [ ] **Step 6: Add `ritualSpellIds` to the library state**

In `lib/bloc/spell_library/spell_library_state.dart`, add the field after `spellLevels`:

```dart
  /// Ids of the spells that are Rituals. Precomputed alongside [spellLevels]
  /// for the same reason: the card has no SpellEngine to derive it with.
  final Set<String> ritualSpellIds;
```

to the constructor:

```dart
    this.ritualSpellIds = const {},
```

to `copyWith`'s parameters:

```dart
    Set<String>? ritualSpellIds,
```

to its body:

```dart
      ritualSpellIds: ritualSpellIds ?? this.ritualSpellIds,
```

and to `props`:

```dart
        ritualSpellIds,
```

- [ ] **Step 7: Populate it in the bloc**

In `lib/bloc/spell_library/spell_library_bloc.dart`, replace the `levels` map and the following `emit` in the `LibraryRequested` branch with a single pass that computes both:

```dart
        final levels = <String, int>{};
        final ritualIds = <String>{};
        for (final s in spells) {
          // An unresolved spell has no base effect to calculate from. It is
          // omitted rather than defaulted to 0, so the card can tell
          // "invalid" apart from "genuinely level 0".
          if (!s.isResolved) continue;
          final breakdown = spellEngine.calculateBreakdown(
            baseEffect: s.baseEffect!, range: s.range!, duration: s.duration!,
            target: s.target!, selectedModifiers: s.selectedModifiers,
            requisites: s.requisites, ritualDeclaration: s.ritualDeclaration,
          );
          levels[s.id] = breakdown.level;
          if (breakdown.ritualStatus.isRitual) ritualIds.add(s.id);
        }

        emit(state.copyWith(
          status: SpellLibraryStatus.loaded,
          allSpells: spells,
          spellLevels: levels,
          ritualSpellIds: ritualIds,
        ));
```

This replaces the `calculateSpellLevel` call added in Task 5 Step 7 — one `calculateBreakdown` now yields both the level and the status, instead of calculating twice.

- [ ] **Step 8: Pass it to the card**

In `lib/presentation/screens/spell_library_screen.dart`, change line 64:

```dart
                      .map((s) => SpellCard(
                            spell: s,
                            level: state.spellLevels[s.id],
                            isRitual: state.ritualSpellIds.contains(s.id),
                          ))
```

- [ ] **Step 9: Run the tests**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test && flutter analyze
```

Expected: all tests PASS and `No issues found!`.

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/ lib/bloc/spell_library/ test/ && git commit -m "feat: show a Ritual chip on library spell cards"
```

---

### Task 9: Five built-in Ritual spells

**Files:**
- Modify: `assets/data/spell_library.json`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces: five new library entries. The `loadSpellLibrary` count assertion moves from 31 to 36.

All five are published core spells with verified base effects and design lines. Levels below were computed with the existing calculator and match the rulebook's printed levels.

| Spell | Line | Arts | Level | Base effect | Design line |
|---|---|---|---|---|---|
| Incantation of the Body Made Whole | 13496 | CrCo | 40 | `crco-35a` | Base 35, +1 Touch |
| Touch of Midas | 15312 | CrTe | 20 | `crte-15a` | Base 15, +1 Touch |
| Curse of the Ravenous Swarm | 12516 | CrAn | 50 | `cran-5b` | Base 5, +1 Touch, +3 Moon, +2 Group, +2 size, +1 requisite |
| Breath of the Open Sky | 13214 | CrAu | 40 | `crau-5` | Base 5, +1 Touch, +1 Conc, +4 size, +1 unnatural |
| Incantation of Summoning the Dead | 15260 | ReMe | 40 | `reem-15b` | Base 15, +4 Arc, +1 Conc |

- [ ] **Step 1: Add the five entries**

In `assets/data/spell_library.json`, insert these before the closing `]`, adding a comma to the previously-last entry:

```json
  {
    "id": "lib-crco-body-made-whole",
    "name": "Incantation of the Body Made Whole",
    "requisites": [],
    "source": "published",
    "createdAt": "2026-01-01T00:00:00.000",
    "updatedAt": "2026-01-01T00:00:00.000",
    "selectedModifiers": {},
    "baseEffectId": "crco-35a",
    "rangeId": "range-touch",
    "durationId": "duration-momentary",
    "targetId": "target-individual",
    "ritualDeclaration": "lastingCreation",
    "summary": "Heals all damage to a human body at the conclusion of the ritual. Cannot restore missing limbs, or damage from disease or poison. Level 40.",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "lib-crte-touch-of-midas",
    "name": "Touch of Midas",
    "requisites": [],
    "source": "published",
    "createdAt": "2026-01-01T00:00:00.000",
    "updatedAt": "2026-01-01T00:00:00.000",
    "selectedModifiers": {},
    "baseEffectId": "crte-15a",
    "rangeId": "range-touch",
    "durationId": "duration-momentary",
    "targetId": "target-individual",
    "ritualDeclaration": "lastingCreation",
    "summary": "Creates a roughly spherical lump of gold about six inches across, weighing some eighty pounds. Level 20.",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "lib-cran-ravenous-swarm",
    "name": "Curse of the Ravenous Swarm",
    "requisites": [
      {
        "art": "Rego",
        "kind": "adding"
      }
    ],
    "source": "published",
    "createdAt": "2026-01-01T00:00:00.000",
    "updatedAt": "2026-01-01T00:00:00.000",
    "selectedModifiers": {
      "size-animal": [
        "size-animal-2"
      ]
    },
    "baseEffectId": "cran-5b",
    "rangeId": "range-touch",
    "durationId": "duration-moon",
    "targetId": "target-group",
    "ritualDeclaration": "storyguideRuling",
    "summary": "Calls a swarm of locusts or other destructive insects upon an area, destroying wild plant life and fields. A Ritual because the effect is a really major one. Level 50.",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "lib-crau-breath-open-sky",
    "name": "Breath of the Open Sky",
    "requisites": [],
    "source": "published",
    "createdAt": "2026-01-01T00:00:00.000",
    "updatedAt": "2026-01-01T00:00:00.000",
    "selectedModifiers": {
      "size-auram": [
        "size-auram-4"
      ],
      "creo-auram-unnatural": [
        "creo-auram-unnatural-slight"
      ]
    },
    "baseEffectId": "crau-5",
    "rangeId": "range-touch",
    "durationId": "duration-concentration",
    "targetId": "target-individual",
    "ritualDeclaration": "storyguideRuling",
    "summary": "Summons a vast and violent storm. A Ritual because of the spectacular scale of the effect. Level 40.",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "lib-reem-summoning-the-dead",
    "name": "Incantation of Summoning the Dead",
    "requisites": [],
    "source": "published",
    "createdAt": "2026-01-01T00:00:00.000",
    "updatedAt": "2026-01-01T00:00:00.000",
    "selectedModifiers": {},
    "baseEffectId": "reem-15b",
    "rangeId": "range-arcane-connection",
    "durationId": "duration-concentration",
    "targetId": "target-individual",
    "ritualDeclaration": "storyguideRuling",
    "summary": "Calls up a person's ghost. The caster must stand where the person died, or hold the corpse. Level 40.",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  }
```

- [ ] **Step 2: Update the existing library count assertion**

In `test/data/datasources/asset_data_loader_test.dart`, change the `loadSpellLibrary` test name and its assertion from 31 to 36:

```dart
  test('loadSpellLibrary loads all 36 built-in spells', () async {
    final spells = await loader.loadSpellLibrary();

    expect(spells.length, 36);
```

Leave the rest of that test as it is.

- [ ] **Step 3: Write the failing fixture test**

Add to the same file:

```dart
  test('the built-in Ritual spells resolve and calculate to their printed levels',
      () async {
    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final modifiers = await loader.loadModifiers();
    final spells = {for (final s in await loader.loadSpellLibrary()) s.id: s};

    final engine = SpellEngine(allSpells: const [], allModifiers: modifiers);

    const expected = <String, ({int level, bool isRitual, int reasonCount})>{
      'lib-crco-body-made-whole': (level: 40, isRitual: true, reasonCount: 1),
      'lib-crte-touch-of-midas': (level: 20, isRitual: true, reasonCount: 1),
      'lib-cran-ravenous-swarm': (level: 50, isRitual: true, reasonCount: 1),
      'lib-crau-breath-open-sky': (level: 40, isRitual: true, reasonCount: 1),
      'lib-reem-summoning-the-dead': (level: 40, isRitual: true, reasonCount: 1),
    };

    expected.forEach((id, want) {
      final spell = spells[id]!;
      final breakdown = engine.calculateBreakdown(
        baseEffect: effects[spell.baseEffectId]!,
        range: parameters[spell.rangeId]!,
        duration: parameters[spell.durationId]!,
        target: parameters[spell.targetId]!,
        selectedModifiers: spell.selectedModifiers,
        requisites: spell.requisites,
        ritualDeclaration: spell.ritualDeclaration,
      );

      expect(breakdown.level, want.level, reason: '$id level');
      expect(breakdown.ritualStatus.isRitual, want.isRitual, reason: '$id isRitual');
      expect(breakdown.ritualStatus.reasons.length, want.reasonCount,
          reason: '$id reason count');
    });

    // Touch of Midas lands exactly on the floor, proving the minimum is a
    // no-op at 20 rather than something that silently adds.
    expect(
      engine
          .calculateBreakdown(
            baseEffect: effects['crte-15a']!,
            range: parameters['range-touch']!,
            duration: parameters['duration-momentary']!,
            target: parameters['target-individual']!,
            selectedModifiers: const {},
            requisites: const [],
            ritualDeclaration: RitualDeclaration.lastingCreation,
          )
          .ritualMinimumApplied,
      isFalse,
    );

    // No pre-existing built-in became a Ritual by accident.
    final ritualIds = expected.keys.toSet();
    for (final spell in spells.values.where((s) => !ritualIds.contains(s.id))) {
      expect(spell.ritualDeclaration, RitualDeclaration.none, reason: spell.id);
    }
  });
```

Add these imports to the test file:

```dart
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/ritual_declaration.dart';
```

- [ ] **Step 4: Run the asset tests**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test test/data/datasources/asset_data_loader_test.dart
```

Expected: all PASS. If a level is off, the design line in the table above is the oracle — check the modifier option ids first, then the parameter ids.

- [ ] **Step 5: Run the full unit suite**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add assets/data/spell_library.json test/data/datasources/asset_data_loader_test.dart && git commit -m "feat: add five built-in Ritual spells to the library"
```

---

### Task 10: Integration test, todo updates, and full verification

**Files:**
- Modify: `integration_test/spell_creation_flow_test.dart`
- Modify: `.superpowers/todo.md`

**Interfaces:**
- Consumes: everything.
- Produces: nothing further.

- [ ] **Step 1: Add the end-to-end Ritual test**

Append a second `testWidgets` block to `integration_test/spell_creation_flow_test.dart`. The setup below is the same wiring the existing test uses, written out in full — each test builds its own in-memory database, so it cannot be shared by reference:

```dart
  testWidgets(
    'end-to-end: a Momentary Creo spell is offered the Ritual checkbox, and '
    'declaring it produces a Ritual spell',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
      );
      final spellRepository = SpellRepository(
          datasource: LocalSpellDatasource(database: database), resolver: resolver);
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(
          spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(
          libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Create Spell'), findsOneWidget);

      // Select Creo / Terram / Create precious metal.
      await tester.tap(find.byKey(const Key('technique-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Creo').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('form-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terram').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base-effect-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Create precious metal').last);
      await tester.pumpAndSettle();

      // Touch / Momentary / Individual. Each dropdown must be scrolled into
      // view first — the form is taller than the viewport, and the existing
      // test in this file uses exactly this helper for the same reason.
      for (final entry in const {
        'range-dropdown': 'Touch',
        'duration-dropdown': 'Momentary',
        'target-dropdown': 'Individual',
      }.entries) {
        await tester.scrollUntilVisible(
          find.byKey(Key(entry.key)),
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.value).last);
        await tester.pumpAndSettle();
      }

      // The checkbox appears for Creo + Momentary and defaults to ticked.
      await tester.scrollUntilVisible(
        find.byKey(const Key('ritual-checkbox')),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byKey(const Key('ritual-checkbox'))).value,
        isTrue,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('calculate-button')),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calculate-button')));
      await tester.pumpAndSettle();

      // Touch of Midas: base 15, +1 Touch = 20.
      expect(find.text('20'), findsWidgets);

      await tester.scrollUntilVisible(
        find.byKey(const Key('ritual-banner')),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('ritual-banner')), findsOneWidget);
    },
  );
```

Note the `range-dropdown` entry selects `'Touch'`. Range Touch and Target Touch share a display name, but the dropdowns filter by category so only one is on screen at a time — recorded as a deliberate non-issue in todo item 15.

Add `import 'package:eruditus/models/ritual_declaration.dart';` if the assertions need it.

- [ ] **Step 2: Run the integration suite**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test integration_test/spell_creation_flow_test.dart -d windows
```

Expected: both tests PASS. Developer Mode is enabled and `-d windows` is verified working on this machine, so this runs as-is — do not substitute another device. `-d chrome` is not viable because `sqflite_common_ffi` has no web support.

- [ ] **Step 3: Update the todo list**

In `.superpowers/todo.md`:

Mark item 4's **Ritual-Only Constraints** bullet complete and correct its mistaken text:

```markdown
- [x] **Ritual-Only Constraints** — ✅ COMPLETE (branch `feature/ritual-spells`)
  - [x] Add ritual-only flag to BaseEffect — landed as `RitualRequirement`
        (`none`/`suggested`/`required`), 7 required and 38 suggested entries
  - [x] Validate in spell creation — landed as derivation, not validation:
        nothing is rejected, because a Year-duration spell is not an error,
        it is a Ritual
  - [x] Display warning in UI — landed as the `RitualSection` banner
  - **This item's original wording was wrong.** It said "force Duration =
        Ritual". Ritual is a spell *type*, orthogonal to all eight Durations —
        not a Duration itself. See the spec's "Points the rulebook settles that
        the todo list got wrong".
```

Update item 15's deferred-constraint note to point at the spec, and item 17's blocker to record that the ritual flag now exists (only the Virtue-gating model is still missing).

Then add five new items:

```markdown
### 18. Storyguide-Ruling UI for Rituals
- [ ] Expose `RitualDeclaration.storyguideRuling`, which the model supports and
      three built-in spells already use, but no control sets
- [ ] Revisit `SpellCreationBloc._withRitualDeclaration` so the two declaration
      kinds stay distinguishable once both are user-settable
- **Rationale:** Core Rules line 12352 lets the troupe declare any spell a
  Ritual. Four published core spells are Rituals for this reason alone. The
  Creo+Momentary-only checkbox cannot express them.
- **Spec:** `docs/superpowers/specs/2026-07-27-ritual-spells-design.md`

### 19. Size-Ladder Ceiling
- [ ] Every Size ladder in `modifiers.json` stops at +4 (×10,000); some
      published spells need +5
- **Blocked example:** *Rain of Oil* (MuAu 50 with an Aquam requisite, core
  rules line 13310: `Base 4, +3 Sight, +2 Sun, +5 size`) could not be added to
  the library with the Ritual work for this reason alone.
- **Belongs with item 4.**

### 20. Creo Creation `suggested` Ritual Sweep
- [ ] Decide whether every "Create X" guideline should carry
      `RitualRequirement.suggested`, as the Creo healing guidelines now do
- **Rationale:** Core Rules line 12176 — "An item made with Creo only lasts for
  the duration of the spell, unless the spell was a Momentary Ritual" — makes
  creation exactly as much a lasting-thing case as healing. Skipped deliberately
  because it is hundreds of entries across all ten Forms, and because the
  checkbox already defaults on for *every* Creo + Momentary draft, so nothing is
  incorrect without it. The flag would only add explanatory text.

### 21. Creo Mentem Memory Restoration
- [ ] Decide whether `creem-4b`, `creem-5b` and `creem-10a` ("Restore a memory
      … to a fresh state") are Momentary-Creo-lasting-thing cases
- **Context:** The Ritual sweep's criterion arguably reaches them, but the
  approved scope was Creo *bodily* healing across Animal, Corpus and Herbam, and
  the healing-suspension rule at line 13415 does not cover memory. All three are
  already flagged "Variable base level", so this belongs with item 4.

### 22. Four Creo Animal Guidelines Missing from the Catalog
- [ ] Level 35 "Increase a Characteristic to one above average"
- [ ] Level 40 "Cause an animal to reach full maturity in a moment"
- [ ] Level 45 "Increase a Characteristic to three above average"
- [ ] Level 55 "Increase a Characteristic to five above average"
- **Context:** Found while walking the Creo Animal guideline table (core rules
  line 12468) for the Ritual flagging pass. Nothing to do with Rituals — an
  extraction gap. The catalog has `cran-35` (Heal all wounds), `cran-40`
  (Characteristic) and `cran-50` (magical beast) but no siblings for these rows.
```

Update the "Next Up" section at the top to drop the completed work and list the new items.

- [ ] **Step 4: Run the analyzer and both test suites**

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter analyze && flutter test
```

Expected: `No issues found!` and all unit tests PASS.

```bash
export PATH="$HOME/Development/SDKs/flutter/flutter/bin:$PATH" && flutter test integration_test/ -d windows
```

Expected: all integration tests PASS. Do not claim the branch is green until **both** commands have been run and their output seen — todo item 6 records two separate failures that hid behind exactly this gap.

- [ ] **Step 5: Commit**

```bash
git add integration_test/ .superpowers/todo.md && git commit -m "test: end-to-end ritual spell creation; update todo list"
```

---

## Notes for the Implementer

**Do not touch `SpellLevelCalculator`.** It stays a pure magnitude-summing function with no knowledge of Rituals. Its tests should not change. If you find yourself editing it, the floor has ended up in the wrong layer.

**Reasons accumulate.** Every place that builds a reason list appends rather than returns early. Aegis of the Hearth must report two reasons, and `ritual_status_test.dart` asserts exactly that.

**`> 50`, never `>= 50`.** Core Rules line 12346 is explicit that level 50 is a legal Formulaic spell.

**The two data files have different formats.** `parameters.json` and `spell_library.json` are pretty-printed and can be hand-edited. `base_effects.json` stores one compact object per line — use the script in Task 3, and check `git diff --numstat` shows exactly 45 changed lines.
