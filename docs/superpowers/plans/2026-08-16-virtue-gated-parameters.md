# Virtue-Gated Parameters (Todo Item 17) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the 6 Merinita Faerie Magic and 3 Symbolic Magic parameters to
the catalog, informationally gated by a new `requiresVirtue` field (no real
character/Virtue model exists or is being added), and land one worked,
citable example spell (*Faerie Chains of the Familiar Slave*) proving the
mechanism against real content.

**Architecture:** Two small model additions (`Parameter.requiresVirtue`/
`.scope`, `BaseEffect.requiresVirtue`) that are informational only — nothing
is blocked from being selected. One real engine gap closed along the way
(`SpellEngine` never checked a ritual-only Range). Everything else is new
catalog data: a supplement book, 9 parameters, 1 base effect, 1 spell
template — all hand-authored JSON, no Python import pipeline involved.

**Tech Stack:** Flutter/Dart, `flutter_test`, hand-authored JSON catalog data
under `assets/data/`.

## Global Constraints

- **Informational only.** `requiresVirtue` never blocks selection of a
  parameter or base effect — the app has no character/Virtue model to check
  against, and building one is explicitly out of scope.
- **No Python import pipeline involvement.** All new catalog data in this
  plan is hand-authored directly in `assets/data/*.json`, not produced by
  `scripts/spell_import/extract_spells.py`. No regeneration step, no Python
  test run required.
- **Every published citation's `bookId` must resolve in `books.json`** — an
  existing test (`test/data/datasources/asset_data_loader_test.dart`,
  *"every parameter's/base effect's cited book ids exist in the books
  catalog"*) already enforces this; the new supplement book must land before
  anything cites it.
- **Spec:** `docs/superpowers/specs/2026-08-16-virtue-gated-parameters-design.md`
  — read it first; this plan implements it task-by-task and does not repeat
  its rulebook citations.

---

### Task 1: `Parameter.requiresVirtue` and `ParameterScope`

**Files:**
- Modify: `lib/models/parameter.dart`
- Test: `test/models/parameter_test.dart`

**Interfaces:**
- Produces: `class ParameterScope { final List<String> forms; const ParameterScope({this.forms = const []}); bool appliesTo({String? form}); Map<String, dynamic> toMap(); factory ParameterScope.fromMap(Map<String, dynamic>? map); }`
- Produces: `Parameter` gains `final String? requiresVirtue;` (default `null`) and `final ParameterScope scope;` (default `const ParameterScope()`), both as named constructor params.

- [ ] **Step 1: Write the failing tests**

Open `test/models/parameter_test.dart` and add these tests inside the
existing `group('Parameter', ...)` block, after the `'fromMap treats an
absent requiresRitual key as false'` test (just before the closing `});` of
the group):

```dart
    test('requiresVirtue defaults to null and round-trips when set', () {
      final plain = Parameter(
        id: 'p-4', name: 'Touch', category: 'Range', magnitude: 1,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(plain.requiresVirtue, isNull);

      final gated = Parameter(
        id: 'p-5', name: 'Road', category: 'Range', magnitude: 2,
        requiresVirtue: 'Faerie Magic',
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(Parameter.fromMap(gated.toMap()).requiresVirtue, 'Faerie Magic');
      expect(Parameter.fromMap(plain.toMap()).requiresVirtue, isNull);
    });

    test('fromMap treats an absent requiresVirtue key as null', () {
      final restored = Parameter.fromMap({
        'id': 'p-6',
        'name': 'Touch',
        'category': 'Range',
        'magnitude': 1,
        'source': 'published',
        'citations': [
          {'bookId': 'arm5-core'},
        ],
      });
      expect(restored.requiresVirtue, isNull);
    });

    test('scope defaults to unrestricted and round-trips a Form restriction', () {
      final plain = Parameter(
        id: 'p-7', name: 'Voice', category: 'Range', magnitude: 2,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(plain.scope.forms, isEmpty);

      final scoped = Parameter(
        id: 'p-8', name: 'Fire', category: 'Duration', magnitude: 3,
        scope: const ParameterScope(forms: ['Ignem', 'Imaginem']),
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(
        Parameter.fromMap(scoped.toMap()).scope.forms,
        ['Ignem', 'Imaginem'],
      );
    });

    test('fromMap treats an absent scope key as unrestricted', () {
      final restored = Parameter.fromMap({
        'id': 'p-9',
        'name': 'Touch',
        'category': 'Range',
        'magnitude': 1,
        'source': 'published',
        'citations': [
          {'bookId': 'arm5-core'},
        ],
      });
      expect(restored.scope.forms, isEmpty);
    });
```

Then add a **new, separate** top-level group in the same file, after the
closing `});` of `group('Parameter', ...)` but before the file's final
`}` (the `main()` closing brace):

```dart
  group('ParameterScope', () {
    test('an unrestricted scope (default) applies to every Form, including null', () {
      const scope = ParameterScope();
      expect(scope.appliesTo(form: 'Ignem'), isTrue);
      expect(scope.appliesTo(form: 'Terram'), isTrue);
      expect(scope.appliesTo(form: null), isTrue);
    });

    test('a restricted scope applies only to a listed Form', () {
      const scope = ParameterScope(forms: ['Ignem', 'Imaginem']);
      expect(scope.appliesTo(form: 'Ignem'), isTrue);
      expect(scope.appliesTo(form: 'Imaginem'), isTrue);
      expect(scope.appliesTo(form: 'Terram'), isFalse);
      expect(scope.appliesTo(form: null), isFalse);
    });

    test('toMap/fromMap round-trips forms', () {
      const scope = ParameterScope(forms: ['Ignem', 'Imaginem']);
      final restored = ParameterScope.fromMap(scope.toMap());
      expect(restored.forms, ['Ignem', 'Imaginem']);
    });

    test('fromMap treats a null map as unrestricted', () {
      expect(ParameterScope.fromMap(null).forms, isEmpty);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/parameter_test.dart`
Expected: analyzer/compile errors — `requiresVirtue`, `scope`, and
`ParameterScope` do not exist yet on `Parameter`.

- [ ] **Step 3: Implement `ParameterScope` and the two new `Parameter` fields**

Replace the full contents of `lib/models/parameter.dart` with:

```dart
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/utils/map_serialization.dart';

/// Which Forms a parameter is offered for. Empty means unrestricted.
/// Only a Forms list -- no Technique axis, no exclude-lists, no effectIds --
/// because Fire is the only parameter across todo item 17's 9 new entries
/// that needs scoping at all. Extend when real evidence demands it, not
/// preemptively.
class ParameterScope {
  final List<String> forms;
  const ParameterScope({this.forms = const []});

  // form is nullable, not required, matching ModifierScope.appliesTo --
  // draft.form is String? (unset until the user picks one), and a
  // Form-restricted parameter must stay hidden until it does. An empty
  // forms list short-circuits before the null check, so an unrestricted
  // parameter is unaffected by an unset Form.
  bool appliesTo({String? form}) => forms.isEmpty || forms.contains(form);

  Map<String, dynamic> toMap() => {'forms': forms};

  factory ParameterScope.fromMap(Map<String, dynamic>? map) => ParameterScope(
        forms: map == null ? const [] : List<String>.from(map['forms'] as List? ?? const []),
      );
}

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

  /// The Mystery Virtue the rulebook requires to use this parameter (e.g.
  /// "Faerie Magic"), or null for a parameter anyone can use. Informational
  /// only, like requiresRitual's relationship to spell-saving -- the app has
  /// no character/Virtue model, so nothing is actually gated. See todo item 17.
  final String? requiresVirtue;

  /// Which Forms this parameter is offered for. Unrestricted by default; only
  /// Fire (Ignem/Imaginem only, todo item 17) uses this today.
  final ParameterScope scope;

  final Provenance provenance;

  Parameter({
    required this.id,
    required this.name,
    required this.category,
    required this.magnitude,
    this.requiresRitual = false,
    this.requiresVirtue,
    this.scope = const ParameterScope(),
    required this.provenance,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'magnitude': magnitude,
    'requiresRitual': requiresRitual,
    if (requiresVirtue != null) 'requiresVirtue': requiresVirtue,
    'scope': scope.toMap(),
    ...provenance.toMap(),
  };

  factory Parameter.fromMap(Map<String, dynamic> map) => Parameter(
    id: requireField<String>(map, 'id', 'Parameter'),
    name: requireField<String>(map, 'name', 'Parameter'),
    category: requireField<String>(map, 'category', 'Parameter'),
    magnitude: requireField<int>(map, 'magnitude', 'Parameter'),
    requiresRitual: map['requiresRitual'] as bool? ?? false,
    requiresVirtue: map['requiresVirtue'] as String?,
    scope: map['scope'] == null
        ? const ParameterScope()
        : ParameterScope.fromMap(map['scope'] as Map<String, dynamic>),
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

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/parameter_test.dart`
Expected: PASS, all tests including the pre-existing ones.

- [ ] **Step 5: Commit**

```bash
git add lib/models/parameter.dart test/models/parameter_test.dart
git commit -m "feat: add Parameter.requiresVirtue and ParameterScope

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `BaseEffect.requiresVirtue`

**Files:**
- Modify: `lib/models/base_effect.dart`
- Test: `test/models/base_effect_test.dart`

**Interfaces:**
- Produces: `BaseEffect` gains `final String? requiresVirtue;` (default `null`).

- [ ] **Step 1: Write the failing tests**

Add to `test/models/base_effect_test.dart`, inside `group('BaseEffect', ...)`,
after the `'fromMap throws a clear FormatException on an unknown
ritualRequirement'` test:

```dart
    test('requiresVirtue defaults to null and round-trips when set', () {
      final plain = BaseEffect(
        id: 'e-9', technique: 'Creo', form: 'Ignem',
        description: 'Create flame', baseLevel: 10,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      expect(plain.requiresVirtue, isNull);

      final gated = BaseEffect(
        id: 'e-10', technique: 'Creo', form: 'Vim',
        description: 'Bind a supernatural creature as a temporary familiar',
        baseLevel: null,
        requiresVirtue: 'Faerie Magic',
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      expect(BaseEffect.fromMap(gated.toMap()).requiresVirtue, 'Faerie Magic');
      expect(BaseEffect.fromMap(plain.toMap()).requiresVirtue, isNull);
    });

    test('fromMap treats an absent requiresVirtue key as null', () {
      final restored = BaseEffect.fromMap({
        'id': 'e-11',
        'technique': 'Creo',
        'form': 'Ignem',
        'description': 'Create flame',
        'baseLevel': 10,
        'source': 'user-created',
      });
      expect(restored.requiresVirtue, isNull);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/base_effect_test.dart`
Expected: compile error — `requiresVirtue` does not exist on `BaseEffect` yet.

- [ ] **Step 3: Implement**

In `lib/models/base_effect.dart`, add the field just after
`final RitualRequirement ritualRequirement;`:

```dart
  /// The Mystery Virtue the rulebook requires to invent/use this guideline
  /// (e.g. "Faerie Magic"), or null for a guideline anyone can use.
  /// Informational only -- see Parameter.requiresVirtue's identical doc
  /// comment; this app has no character/Virtue model to enforce it against.
  final String? requiresVirtue;
```

Add `this.requiresVirtue,` to the constructor's named parameter list (right
after `this.ritualRequirement = RitualRequirement.none,`).

In `toMap()`, add after `'ritualRequirement': ritualRequirement.name,`:

```dart
    if (requiresVirtue != null) 'requiresVirtue': requiresVirtue,
```

In `BaseEffect.fromMap`, add after the `ritualRequirement:` line:

```dart
    requiresVirtue: map['requiresVirtue'] as String?,
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/base_effect_test.dart`
Expected: PASS, all tests including the pre-existing ones.

- [ ] **Step 5: Commit**

```bash
git add lib/models/base_effect.dart test/models/base_effect_test.dart
git commit -m "feat: add BaseEffect.requiresVirtue

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: `RitualReason.ritualOnlyRange` and engine derivation

**Files:**
- Modify: `lib/engine/ritual_status.dart`
- Modify: `lib/engine/spell_engine.dart`
- Test: `test/engine/ritual_status_test.dart`

**Interfaces:**
- Consumes: `Parameter.requiresRitual` (existing, Task 1 unchanged it).
- Produces: `RitualReason.ritualOnlyRange` (new enum value).
- Produces: `SpellEngine._deriveRitualStatus` now requires a `range` named
  parameter (private, but `calculateBreakdown`'s public signature is
  unchanged — `range` was already a required parameter there).

- [ ] **Step 1: Write the failing tests**

In `test/engine/ritual_status_test.dart`, add a new fixture near the other
`final _year = ...`/`final _boundary = ...` lines (after `_boundary`):

```dart
final _symbolRange = _param('range-symbol', 'Symbol', 'Range', 4, requiresRitual: true);
```

Add a new test inside `group('forced ritual reasons', ...)`, after the
`'a ritual-only Target forces a Ritual'` test:

```dart
    test('a ritual-only Range forces a Ritual', () {
      final result = run(range: _symbolRange);
      expect(result.isRitual, isTrue);
      expect(result.reasons, [RitualReason.ritualOnlyRange]);
    });
```

Add a new test inside `group('reasons accumulate', ...)`, after the existing
`'Aegis of the Hearth reports both its forced reasons'` test:

```dart
    test('a ritual-only Range accumulates alongside Duration and Target', () {
      final result = run(
        effect: _effect(1),
        range: _symbolRange,
        duration: _year,
        target: _boundary,
      );
      expect(result.reasons, containsAll([
        RitualReason.ritualOnlyRange,
        RitualReason.ritualOnlyDuration,
        RitualReason.ritualOnlyTarget,
      ]));
      expect(result.reasons.length, 3);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/engine/ritual_status_test.dart`
Expected: compile error — `RitualReason.ritualOnlyRange` does not exist yet.

- [ ] **Step 3: Add the enum value**

In `lib/engine/ritual_status.dart`, replace the doc comment and enum:

```dart
/// Why a spell is a Ritual. See Core Rules "Ritual Spells", line 12340.
///
/// [ritualOnlyRange], [ritualOnlyDuration] and [ritualOnlyTarget] are named
/// for the generic `Parameter.requiresRitual` flag rather than for specific
/// parameters, because todo item 17 adds three more ritual-only Durations
/// and the first-ever ritual-only Range (Symbol) -- a reason called
/// `yearDuration` would become a lie, and Range needed a reason at all.
/// Callers that want to name the parameter read its `name` directly.
enum RitualReason {
  ritualOnlyRange,
  ritualOnlyDuration,
  ritualOnlyTarget,
  exceedsMaxFormulaicLevel,
  guideline,
  lastingCreation,
  storyguideRuling,
}
```

- [ ] **Step 4: Wire the derivation in `SpellEngine`**

In `lib/engine/spell_engine.dart`, update the call to `_deriveRitualStatus`
(inside `calculateBreakdown`, currently reading `baseEffect:`, `duration:`,
`target:`, `ritualDeclaration:`, `rawLevel:`) to also pass `range:`:

```dart
    final ritualStatus = _deriveRitualStatus(
      baseEffect: baseEffect,
      range: range,
      duration: duration,
      target: target,
      ritualDeclaration: ritualDeclaration,
      rawLevel: rawLevel,
    );
```

Update the `_deriveRitualStatus` method itself:

```dart
  /// Every reason [rawLevel]'s spell is a Ritual, accumulated in a stable
  /// order. Declarations are honoured unconditionally — a storyguide ruling is
  /// legitimate on any spell by definition, and keeping a live draft's
  /// declaration meaningful is the bloc's job, not the engine's.
  RitualStatus _deriveRitualStatus({
    required BaseEffect baseEffect,
    required Parameter range,
    required Parameter duration,
    required Parameter target,
    required RitualDeclaration ritualDeclaration,
    required int rawLevel,
  }) {
    final reasons = <RitualReason>[];

    if (range.requiresRitual) reasons.add(RitualReason.ritualOnlyRange);
    if (duration.requiresRitual) reasons.add(RitualReason.ritualOnlyDuration);
    if (target.requiresRitual) reasons.add(RitualReason.ritualOnlyTarget);
    if (baseEffect.ritualRequirement == RitualRequirement.required) {
      reasons.add(RitualReason.guideline);
    }
```

(The rest of the method — the `rawLevel` and `ritualDeclaration` checks below
— is unchanged; only the fixed-Range-related lines above are new.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/engine/ritual_status_test.dart`
Expected: PASS, all tests including the pre-existing ones.

- [ ] **Step 6: Run the full engine test suite to catch any other breakage**

Run: `flutter test test/engine/`
Expected: PASS. (`spell_engine_test.dart` calls `calculateBreakdown` with
`range:` already required, so no other call site should need changes.)

- [ ] **Step 7: Commit**

```bash
git add lib/engine/ritual_status.dart lib/engine/spell_engine.dart test/engine/ritual_status_test.dart
git commit -m "feat: derive Ritual status from a ritual-only Range too

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: `RitualSection` gets a `rangeName` and the new reason

**Files:**
- Modify: `lib/presentation/widgets/ritual_section.dart`
- Modify: `lib/presentation/screens/spell_creation_screen.dart`
- Test: `test/presentation/widgets/ritual_section_test.dart`

**Interfaces:**
- Consumes: `RitualReason.ritualOnlyRange` (Task 3).
- Produces: `RitualSection` now requires a `rangeName` named parameter,
  alongside the existing `durationName`/`targetName`.

- [ ] **Step 1: Write the failing tests**

In `test/presentation/widgets/ritual_section_test.dart`, every existing
`RitualSection(...)` constructor call needs a `rangeName: 'Touch',` line
added immediately after its `showLastingCreationOption: ...,` line. There
are 11 such calls in the file. For example, the first one:

```dart
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: false,
      rangeName: 'Touch',
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));
```

Apply the identical insertion (`rangeName: 'Touch',` right after
`showLastingCreationOption: ...,`) to every other `RitualSection(` call in
this file. Verify the count before and after:

```bash
grep -c "showLastingCreationOption:" test/presentation/widgets/ritual_section_test.dart
grep -c "rangeName:" test/presentation/widgets/ritual_section_test.dart
```

Both commands must report the same number when you're done (11).

Then add one new test, after the existing `'names every reason in the
banner'` test:

```dart
  testWidgets('names the range reason in the banner', (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([RitualReason.ritualOnlyRange]),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: false,
      rangeName: 'Symbol',
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final banner = tester.widget<Text>(find
        .descendant(
            of: find.byKey(const Key('ritual-banner')), matching: find.byType(Text))
        .first);
    expect(banner.data, contains('Symbol range'));
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/widgets/ritual_section_test.dart`
Expected: compile error — `rangeName` is not a parameter of `RitualSection`
yet.

- [ ] **Step 3: Implement**

In `lib/presentation/widgets/ritual_section.dart`, update the field
declarations (add `rangeName` before `durationName`):

```dart
  final RitualStatus ritualStatus;
  final RitualDeclaration declaration;

  /// True when the draft is Creo with Momentary duration -- the only
  /// configuration the "Creates something lasting" option is offered for
  /// (Core Rules line 12351). The "Storyguide ruling" option has no such
  /// gate: line 12352 lets the troupe declare *any* spell a Ritual.
  final bool showLastingCreationOption;

  /// The selected parameters' own names, so the banner can say "Year duration"
  /// without RitualReason having to hardcode which parameters are ritual-only.
  final String rangeName;
  final String durationName;
  final String targetName;
```

Update the constructor:

```dart
  const RitualSection({
    super.key,
    required this.ritualStatus,
    required this.declaration,
    required this.showLastingCreationOption,
    required this.rangeName,
    required this.durationName,
    required this.targetName,
    required this.guidelineIsSuggested,
    required this.onDeclarationChanged,
  });
```

Update the `_describe` switch:

```dart
  String _describe(RitualReason reason) => switch (reason) {
        RitualReason.ritualOnlyRange => '$rangeName range',
        RitualReason.ritualOnlyDuration => '$durationName duration',
        RitualReason.ritualOnlyTarget => '$targetName target',
        RitualReason.exceedsMaxFormulaicLevel =>
          'level above ${RitualStatus.maxFormulaicLevel}',
        RitualReason.guideline => 'the guideline requires it',
        RitualReason.lastingCreation => 'it creates something lasting',
        RitualReason.storyguideRuling => 'storyguide ruling',
      };
```

Now wire the real call site. In `lib/presentation/screens/spell_creation_screen.dart`,
find the `RitualSection(` instantiation and add `rangeName:` right before
`durationName:`:

```dart
                RitualSection(
                  // Gated the same as LevelBreakdownCard below: state.breakdown
                  // is carried forward by copyWith across edits made after
                  // Calculate, so without this gate the banner would keep
                  // showing a reason computed for a draft the user has since
                  // changed (e.g. still reading "Year duration" after Duration
                  // was switched to Sun).
                  ritualStatus: showResultsBlock
                      ? (state.breakdown?.ritualStatus ?? const RitualStatus.notRitual())
                      : const RitualStatus.notRitual(),
                  declaration: draft.ritualDeclaration,
                  showLastingCreationOption: draft.isEligibleForLastingCreationDeclaration,
                  rangeName: draft.range?.name ?? '',
                  durationName: draft.duration?.name ?? '',
                  targetName: draft.target?.name ?? '',
                  guidelineIsSuggested: draft.baseEffect?.ritualRequirement ==
                      RitualRequirement.suggested,
                  onDeclarationChanged: (declaration) =>
                      bloc.add(RitualDeclarationChanged(declaration)),
                ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/widgets/ritual_section_test.dart`
Expected: PASS, all 12 tests (11 existing + 1 new).

- [ ] **Step 5: Run the full presentation test suite to catch any other breakage**

Run: `flutter test test/presentation/`
Expected: PASS. `spell_creation_screen_test.dart` reaches `RitualSection`
only through the whole-screen widget tree, not by constructing it directly,
so it should be unaffected by the new required parameter.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/ritual_section.dart lib/presentation/screens/spell_creation_screen.dart test/presentation/widgets/ritual_section_test.dart
git commit -m "feat: RitualSection names the range reason too

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Dropdown scope filtering and Virtue notes

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart`
- Test: `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: `Parameter.scope`/`.requiresVirtue` (Task 1),
  `BaseEffect.requiresVirtue` (Task 2).

- [ ] **Step 1: Write the failing tests**

In `test/presentation/screens/spell_creation_screen_test.dart`, add these
three tests near the end of the `main()` body (alongside the other
`testWidgets` calls; exact position doesn't matter, but keep them together):

```dart
  testWidgets('a Form-scoped parameter is hidden from the dropdown on a non-matching Form',
      (tester) async {
    final fireParam = Parameter(
      id: 'duration-fire', name: 'Fire', category: 'Duration', magnitude: 3,
      requiresRitual: true,
      requiresVirtue: 'Faerie Magic',
      scope: const ParameterScope(forms: ['Ignem', 'Imaginem']),
      provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
    );
    final draftState = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(technique: 'Creo', form: 'Terram'),
    );
    await pumpScreen(
      tester,
      draftState,
      configState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [durationParam, fireParam],
      ),
    );

    await tester.tap(find.byKey(const Key('duration-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Fire (+3, requires Faerie Magic)'), findsNothing);
  });

  testWidgets('a Form-scoped parameter appears in the dropdown on a matching Form',
      (tester) async {
    final fireParam = Parameter(
      id: 'duration-fire', name: 'Fire', category: 'Duration', magnitude: 3,
      requiresRitual: true,
      requiresVirtue: 'Faerie Magic',
      scope: const ParameterScope(forms: ['Ignem', 'Imaginem']),
      provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')]),
    );
    final draftState = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem'),
    );
    await pumpScreen(
      tester,
      draftState,
      configState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [creoIgnemEffect],
        parameters: [durationParam, fireParam],
      ),
    );

    await tester.tap(find.byKey(const Key('duration-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Fire (+3, requires Faerie Magic)'), findsOneWidget);
  });

  testWidgets('a Virtue-gated base effect shows a requirement note in the dropdown',
      (tester) async {
    final gatedEffect = BaseEffect(
      id: 'crvi-hohmc-G1', technique: 'Creo', form: 'Vim',
      description: 'Bind a supernatural creature as a temporary familiar',
      baseLevel: null,
      requiresVirtue: 'Faerie Magic',
      ritualRequirement: RitualRequirement.required,
      effectFormula: const GeneralEffectFormula(
          kind: GeneralEffectKind.mightThreshold, offsetMagnitudes: -3),
      provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-hohmc')]),
    );
    final draftState = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(technique: 'Creo', form: 'Vim'),
    );
    await pumpScreen(
      tester,
      draftState,
      configState: ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [gatedEffect],
        parameters: [voiceParam],
      ),
    );

    await tester.tap(find.byKey(const Key('base-effect-dropdown')));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Bind a supernatural creature as a temporary familiar (General, requires Faerie Magic)'),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: FAIL — `ParameterScope` filtering doesn't exist yet, so Fire shows
up regardless of Form, and neither dropdown appends a Virtue note.

- [ ] **Step 3: Implement**

In `lib/presentation/screens/spell_creation_screen.dart`, update
`_buildParameterDropdown`:

```dart
  Widget _buildParameterDropdown({
    required Key key,
    required String label,
    required String category,
    required List<Parameter> parameters,
    required Parameter? selectedParameter,
    required String? form,
    required Function(Parameter?) onChanged,
  }) {
    final categoryParameters = parameters
        .where((p) => p.category == category && p.scope.appliesTo(form: form))
        .toList();

    return DropdownButtonFormField<Parameter>(
      key: key,
      decoration: InputDecoration(labelText: label),
      initialValue: selectedParameter,
      items: categoryParameters
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.requiresVirtue == null
                    ? '${p.name} (+${p.magnitude})'
                    : '${p.name} (+${p.magnitude}, requires ${p.requiresVirtue})'),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
```

Update the three call sites (Range/Duration/Target dropdowns) to pass
`form: draft.form,`. For example, the Range dropdown:

```dart
                _buildParameterDropdown(
                  key: const Key('range-dropdown'),
                  label: 'Range',
                  category: 'Range',
                  parameters: configState.parameters,
                  selectedParameter: draft.range,
                  form: draft.form,
                  onChanged: (param) {
                    if (param != null) bloc.add(RangeSelected(param));
                  },
                ),
```

Apply the same `form: draft.form,` addition to the Duration and Target
dropdown calls immediately below it.

Update the base effect dropdown's item text (the `DropdownMenuItem` inside
the `base-effect-dropdown` builder):

```dart
                    items: effectsForSelection
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                '${e.description} (${e.isGeneral ? 'General' : 'Base ${e.baseLevel}'}'
                                '${e.requiresVirtue == null ? '' : ', requires ${e.requiresVirtue}'})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: PASS, all tests including the pre-existing ones (the pre-existing
`'Create flame (Base 10)'` assertion is unaffected, since `creoIgnemEffect`
has no `requiresVirtue`).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/spell_creation_screen.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: filter parameters by Form scope, show Virtue requirement notes

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: New book and the 9 new parameters

**Files:**
- Modify: `assets/data/books.json`
- Modify: `assets/data/parameters.json`
- Modify: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: `Parameter.requiresVirtue`/`.scope` (Task 1).
- Produces: book id `arm5-hohmc`; parameter ids
  `range-road`, `duration-bargain`, `duration-fire`, `duration-until-condition`,
  `duration-year-plus-one`, `target-bloodline`, `range-symbol`,
  `duration-symbol`, `target-symbol` — all later tasks that cite these ids
  depend on this task landing first.

- [ ] **Step 1: Write the failing tests**

In `test/data/datasources/asset_data_loader_test.dart`:

Replace the existing `'loadParameters loads all 25 built-in parameters'`
test in full with:

```dart
  test('loadParameters loads all 34 built-in parameters', () async {
    final parameters = await loader.loadParameters();

    expect(parameters.length, 34);
    expect(parameters.every((p) => p.provenance.source == PublicationSource.published), isTrue);
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

Change the ritual-flagged set test:

```dart
  test('every ritual-only parameter is flagged, including item 17\'s additions', () async {
    final parameters = await loader.loadParameters();

    final flagged = parameters.where((p) => p.requiresRitual).map((p) => p.id).toSet();

    // Hardcoded, unlike the base-effect counts: parameters.json is the small
    // hand-curated list todo item 5 deliberately left as literals. Grew from
    // {duration-year, target-boundary} to include item 17's 7 new
    // ritual-only entries (Bargain/Fire/Until (Condition)/Year + 1, all
    // three Symbol parameters).
    expect(flagged, {
      'duration-year', 'target-boundary',
      'duration-bargain', 'duration-fire', 'duration-until-condition',
      'duration-year-plus-one', 'range-symbol', 'duration-symbol', 'target-symbol',
    });

    // Vision shares Boundary's +4 magnitude but is explicitly not ritual-only
    // (Core Rules line 12345: Formulaic spells "may have Vision target, if
    // they are magical sense spells").
    expect(
      parameters.firstWhere((p) => p.id == 'target-vision').requiresRitual,
      isFalse,
    );
  });
```

(This replaces the existing `'exactly Year and Boundary are flagged
ritual-only'` test in place — same test, new name and body.)

Add two new tests, after the block above:

```dart
  test('exactly the Faerie Magic and Symbolic Magic parameters are flagged requiresVirtue', () async {
    final parameters = await loader.loadParameters();

    final byVirtue = <String, Set<String>>{};
    for (final parameter in parameters) {
      if (parameter.requiresVirtue == null) continue;
      byVirtue.putIfAbsent(parameter.requiresVirtue!, () => {}).add(parameter.id);
    }

    expect(byVirtue['Faerie Magic'], {
      'range-road', 'duration-bargain', 'duration-fire',
      'duration-until-condition', 'duration-year-plus-one', 'target-bloodline',
    });
    expect(byVirtue['Symbolic Magic'], {
      'range-symbol', 'duration-symbol', 'target-symbol',
    });
  });

  test('Fire is scoped to Ignem and Imaginem; every other parameter is unrestricted', () async {
    final parameters = await loader.loadParameters();

    for (final parameter in parameters) {
      if (parameter.id == 'duration-fire') {
        expect(parameter.scope.forms, ['Ignem', 'Imaginem']);
      } else {
        expect(parameter.scope.forms, isEmpty, reason: parameter.id);
      }
    }
  });

  test('loadBooks includes the Houses of Hermes: Mystery Cults supplement', () async {
    final books = await loader.loadBooks();
    final supplement =
        books.firstWhere((b) => b.id == 'arm5-hohmc');
    expect(supplement.title, 'Ars Magica 5e - Houses of Hermes: Mystery Cults');
    expect(supplement.abbreviation, 'HoH:MC');
    expect(supplement.edition, '5e');
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — the count is still 25, the ritual-flagged set doesn't
include the new ids, no parameter has `requiresVirtue` set, and the
supplement book isn't in `books.json` yet.

- [ ] **Step 3: Add the book**

In `assets/data/books.json`, change:

```json
[
  {
    "id": "arm5-core",
    "title": "Ars Magica Fifth Edition",
    "abbreviation": "ArM5",
    "edition": "5e"
  }
]
```

to:

```json
[
  {
    "id": "arm5-core",
    "title": "Ars Magica Fifth Edition",
    "abbreviation": "ArM5",
    "edition": "5e"
  },
  {
    "id": "arm5-hohmc",
    "title": "Ars Magica 5e - Houses of Hermes: Mystery Cults",
    "abbreviation": "HoH:MC",
    "edition": "5e"
  }
]
```

- [ ] **Step 4: Add the 9 parameters**

In `assets/data/parameters.json`, the file currently ends with the
`target-boundary` entry followed by `]`. Change the end of that entry from:

```json
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  }
]
```

to:

```json
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "range-road",
    "name": "Road",
    "category": "Range",
    "magnitude": 2,
    "requiresVirtue": "Faerie Magic",
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "duration-bargain",
    "name": "Bargain",
    "category": "Duration",
    "magnitude": 4,
    "requiresRitual": true,
    "requiresVirtue": "Faerie Magic",
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "duration-fire",
    "name": "Fire",
    "category": "Duration",
    "magnitude": 3,
    "requiresRitual": true,
    "requiresVirtue": "Faerie Magic",
    "scope": {
      "forms": ["Ignem", "Imaginem"]
    },
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "duration-until-condition",
    "name": "Until (Condition)",
    "category": "Duration",
    "magnitude": 4,
    "requiresRitual": true,
    "requiresVirtue": "Faerie Magic",
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "duration-year-plus-one",
    "name": "Year + 1",
    "category": "Duration",
    "magnitude": 4,
    "requiresRitual": true,
    "requiresVirtue": "Faerie Magic",
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "target-bloodline",
    "name": "Bloodline",
    "category": "Target",
    "magnitude": 3,
    "requiresVirtue": "Faerie Magic",
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-core"
      }
    ]
  },
  {
    "id": "range-symbol",
    "name": "Symbol",
    "category": "Range",
    "magnitude": 4,
    "requiresRitual": true,
    "requiresVirtue": "Symbolic Magic",
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  },
  {
    "id": "duration-symbol",
    "name": "Symbol",
    "category": "Duration",
    "magnitude": 4,
    "requiresRitual": true,
    "requiresVirtue": "Symbolic Magic",
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  },
  {
    "id": "target-symbol",
    "name": "Symbol",
    "category": "Target",
    "magnitude": 4,
    "requiresRitual": true,
    "requiresVirtue": "Symbolic Magic",
    "source": "published",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  }
]
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: PASS, all tests including the pre-existing ones (in particular the
citation-consistency tests, which now find `arm5-hohmc`
in `books.json`).

- [ ] **Step 6: Commit**

```bash
git add assets/data/books.json assets/data/parameters.json test/data/datasources/asset_data_loader_test.dart
git commit -m "feat: add Houses of Hermes: Mystery Cults book and item 17's 9 parameters

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: New base effect — binding a temporary faerie familiar

**Files:**
- Modify: `assets/data/base_effects.json`
- Modify: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: `BaseEffect.requiresVirtue` (Task 2), book
  `arm5-hohmc` (Task 6).
- Produces: base effect id `crvi-hohmc-G1` — Task 8's `SpellTemplate` depends
  on this landing first.

- [ ] **Step 1: Write the failing test**

Add these two imports to the top of
`test/data/datasources/asset_data_loader_test.dart`, alongside the existing
`package:eruditus/models/...` imports:

```dart
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/general_effect_formula.dart';
```

Add this test, near the other `loadBaseEffects` tests:

```dart
  test('the Faerie Chains familiar-binding base effect loads with its Virtue gate', () async {
    final effects = await loader.loadBaseEffects();
    final effect = effects.firstWhere((e) => e.id == 'crvi-hohmc-G1');

    expect(effect.technique, 'Creo');
    expect(effect.form, 'Vim');
    expect(effect.isGeneral, isTrue);
    expect(effect.ritualRequirement, RitualRequirement.required);
    expect(effect.requiresVirtue, 'Faerie Magic');
    expect(effect.effectFormula?.kind, GeneralEffectKind.mightThreshold);
    expect(effect.effectFormula?.offsetMagnitudes, -3);
    expect(effect.provenance.citations, [
      const Citation(bookId: 'arm5-hohmc'),
    ]);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — `firstWhere` throws `StateError` (`crvi-hohmc-G1` not found).

- [ ] **Step 3: Add the base effect**

`assets/data/base_effects.json` uses one compact single-line entry per
object. Add a new line as the new last array element, right before the
file's closing `]` (change the final entry's trailing `}` to `},` and add
the new line after it):

```json
{"id": "crvi-hohmc-G1", "technique": "Creo", "form": "Vim", "description": "Bind a supernatural creature as a temporary familiar (level >= creature's Might + 15)", "baseLevel": null, "source": "published", "citations": [{"bookId": "arm5-hohmc"}], "notes": "General entry; must be Ritual; requires Faerie Magic (Outer Mystery); hand-authored, not part of the core-rules extraction -- see todo item 17", "ritualRequirement": "required", "requiresVirtue": "Faerie Magic", "effectFormula": {"kind": "mightThreshold", "offsetMagnitudes": -3}}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: PASS, all tests including the pre-existing ones (in particular
`'loadBaseEffects loads every built-in base effect in the asset file'`,
whose expected count is derived from the raw file, not hardcoded).

- [ ] **Step 5: Commit**

```bash
git add assets/data/base_effects.json test/data/datasources/asset_data_loader_test.dart
git commit -m "feat: add the familiar-binding base effect for Faerie Chains

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: `SpellTemplate` for *Faerie Chains of the Familiar Slave*

**Files:**
- Modify: `assets/data/spell_templates.json`
- Modify: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: base effect `crvi-hohmc-G1` (Task 7), parameters `range-touch`
  (pre-existing), `duration-until-condition` (Task 6), `target-individual`
  (pre-existing), book `arm5-hohmc` (Task 6).

- [ ] **Step 1: Write the failing test**

Add this import to `test/data/datasources/asset_data_loader_test.dart`:

```dart
import 'package:eruditus/engine/ritual_status.dart';
```

Add this test, near the other `loadSpellTemplates` tests:

```dart
  test('the Faerie Chains template computes its Ritual status from Until (Condition)', () async {
    final templates = await loader.loadSpellTemplates();
    final effects = await loader.loadBaseEffects();
    final parameters = await loader.loadParameters();

    final template =
        templates.firstWhere((t) => t.id == 'tpl-crvi-faerie-chains-familiar-slave');
    final baseEffect = effects.firstWhere((e) => e.id == template.baseEffectId);
    final range = parameters.firstWhere((p) => p.id == template.rangeId);
    final duration = parameters.firstWhere((p) => p.id == template.durationId);
    final target = parameters.firstWhere((p) => p.id == template.targetId);

    expect(range.id, 'range-touch');
    expect(duration.id, 'duration-until-condition');
    expect(duration.requiresRitual, isTrue);
    expect(duration.requiresVirtue, 'Faerie Magic');
    expect(baseEffect.requiresVirtue, 'Faerie Magic');
    expect(baseEffect.isGeneral, isTrue);

    final engine = SpellEngine(allSpells: const [], allParameters: parameters);
    // Binding a creature with Might 5: level must be >= 20 (Might + 15).
    final breakdown = engine.calculateBreakdown(
      baseEffect: baseEffect,
      chosenBaseLevel: 20,
      range: range,
      duration: duration,
      target: target,
      selectedModifiers: template.selectedModifiers,
      requisites: template.requisites,
    );

    expect(breakdown.ritualStatus.isRitual, isTrue);
    expect(breakdown.ritualStatus.reasons, containsAll([
      RitualReason.ritualOnlyDuration,
      RitualReason.guideline,
    ]));
    // 20 (chosen base, already above the level-5 additive tier) + Touch's
    // magnitude 1, above the additive tier so worth *5 = 25.
    expect(breakdown.level, 25);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — `firstWhere` throws `StateError`
(`tpl-crvi-faerie-chains-familiar-slave` not found).

- [ ] **Step 3: Add the template**

`assets/data/spell_templates.json` uses pretty multi-line entries. Add a new
entry as the new last array element (change the previous last entry's
closing `}` to `},`, then add):

```json
  {
    "id": "tpl-crvi-faerie-chains-familiar-slave",
    "name": "Faerie Chains of the Familiar Slave",
    "technique": "Creo",
    "form": "Vim",
    "requisites": {},
    "source": "published",
    "selectedModifiers": {},
    "baseEffectId": "crvi-hohmc-G1",
    "rangeId": "range-touch",
    "durationId": "duration-until-condition",
    "targetId": "target-individual",
    "summary": "This ritual binds a supernatural creature to the caster as her familiar, until a condition incorporated into the spell comes to pass. The level of the ritual must be no less than (the creature's Might + 15).",
    "description": "This ritual binds a supernatural creature to the caster as her familiar, until a condition incorporated into the spell comes to pass. The level of the ritual must be no less than (the creature's Might + 15), though she may also need to penetrate its Magic Resistance if casting on an unwilling target. It has no effect if the target is already bound as a familiar to another. Casting requisites of a Technique and Form appropriate to the creature's nature and physical form may be included; this app has no way to model a per-casting, creature-dependent requisite, so none is recorded here (see todo item 52). It may be invented by anyone who has been Initiated into the Outer Mystery of Faerie Magic.",
    "citations": [
      {
        "bookId": "arm5-hohmc"
      }
    ]
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: PASS, all tests including the pre-existing ones (in particular
`'every template references a General base effect'`, since `crvi-hohmc-G1`
has `baseLevel: null`).

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS, every test in the project.

- [ ] **Step 6: Commit**

```bash
git add assets/data/spell_templates.json test/data/datasources/asset_data_loader_test.dart
git commit -m "feat: add Faerie Chains of the Familiar Slave as a spell template

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: Close out todo item 17, file items 51 and 52

**Files:**
- Modify: `.superpowers/todo.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Mark item 17 done**

In `.superpowers/todo.md`, replace the entire item 17 section — from its
`### 17. Virtue-Gated Parameters: Merinita Faerie Magic and Symbolic Magic`
heading through the line `  ("Deferred Work")` just before item 18's
heading — with:

```markdown
### 17. Virtue-Gated Parameters: Merinita Faerie Magic and Symbolic Magic — ✅ DONE 2026-08-16
**Merinita: Faerie Magic** — Core Rules, "Mysteries" chapter. **Symbolic
Magic** — *Houses of Hermes: Mystery Cults*, the first supplement book in the
catalog (`arm5-hohmc`). All 9 parameters added to
`assets/data/parameters.json`, gated by a new informational `requiresVirtue:
String?` field on both `Parameter` and `BaseEffect`
(`lib/models/parameter.dart`, `lib/models/base_effect.dart`) — selectable
like any other entry, since the app has no character/Virtue model to enforce
against; the field only names the requirement for the UI to display.

- **Fire** (Duration) needed real Form-scoping (Ignem/Imaginem only), closing
  a gap `Parameter` never had before: a new `ParameterScope` class
  (`forms: List<String>`, mirroring `ModifierScope` but far smaller),
  filtered in `spell_creation_screen.dart`'s parameter dropdowns.
- **Symbol (Range)** needed a ritual-only *Range* — the first the catalog has
  ever had. `SpellEngine._deriveRitualStatus` only checked Duration/Target;
  closed by adding `RitualReason.ritualOnlyRange` and a `range` parameter to
  the derivation, plus a matching case and `rangeName` field in
  `RitualSection`.
- **Worked example**: *Faerie Chains of the Familiar Slave*
  (`tpl-crvi-faerie-chains-familiar-slave`, *Houses of Hermes: Mystery
  Cults* lines 3371–3387) landed as a `SpellTemplate` on a new General base
  effect (`crvi-hohmc-G1`) using the existing `mightThreshold`
  `GeneralEffectFormula` kind with `offsetMagnitudes: -3` — no new kind
  needed. Both the base effect and its Until (Condition) duration carry
  independent `requiresVirtue: "Faerie Magic"` gates, per the rulebook's own
  two separate statements (base effect: line 3373; parameter: line 10030).
- **Two gaps found and deliberately deferred, not solved here**: Bargain's
  nested duration computation (item 51) and open/variable requisites
  (item 52).
- **Files:** `lib/models/parameter.dart`, `lib/models/base_effect.dart`,
  `lib/engine/ritual_status.dart`, `lib/engine/spell_engine.dart`,
  `lib/presentation/widgets/ritual_section.dart`,
  `lib/presentation/screens/spell_creation_screen.dart`,
  `assets/data/books.json`, `assets/data/parameters.json`,
  `assets/data/base_effects.json`, `assets/data/spell_templates.json`.
- **Spec:** `docs/superpowers/specs/2026-08-16-virtue-gated-parameters-design.md`.
  Plan: `docs/superpowers/plans/2026-08-16-virtue-gated-parameters.md`.
```

- [ ] **Step 2: File items 51 and 52**

Immediately after the item 17 block you just replaced (still before item
18's heading), insert:

```markdown
### 51. Bargain Duration's Nested Level Computation
Found 2026-08-16 while landing item 17. **Bargain** (Duration, Faerie Magic)
does not fit `Parameter`'s flat `magnitude` model: its true level is
*"calculate the level of the spell that takes effect when the bargain is
broken, and add three magnitudes"* (Core Rules line 10038) — a second,
nested spell-level computation `SpellEngine` has no mechanism for. The same
shape of problem as *Mists of Change*'s two-Durations-at-once
`ExceptionSpell` (item 46).

- [ ] Decide whether `SpellEngine` needs a nested-computation capability, or
      every real Bargain spell must be modeled as an `ExceptionSpell` instead
- **Not urgent:** no published spell using Bargain has been found or
  imported; `duration-bargain` is cataloged with `magnitude: 4` (Year's
  value) as a documented simplification, informational only until a real
  spell needs it.
- **Files:** `lib/engine/spell_engine.dart`, `lib/models/exception_spell.dart`
- **Spec:** `docs/superpowers/specs/2026-08-16-virtue-gated-parameters-design.md`
  ("Out of Scope")

### 52. Open/Variable Requisites (Per-Casting, Not Per-Catalog-Entry)
Found 2026-08-16 while landing item 17's worked example, *Faerie Chains of
the Familiar Slave*. Its own requisite — *"a Technique and Form appropriate
to the creature's nature and physical form"* — is chosen at the time of
casting, not fixed by the catalog entry, but
`SpellTemplate.requisites`/`Spell.requisites` (`lib/models/requisite.dart`)
only support fixed `{Art: kind}` pairs. Same shape of gap as item 50's
`ModifierScope` granularity problem, but for requisites instead of modifier
scope.

- [ ] Decide how to model a requisite whose Art is chosen per-casting rather
      than fixed by the spell/template
- **Not urgent:** `tpl-crvi-faerie-chains-familiar-slave` ships today with
  `requisites: {}` and the gap noted in its own `description` text; no
  arithmetic is wrong, the requisite is simply absent from the computed
  breakdown.
- **Files:** `lib/models/requisite.dart`, `lib/models/spell_template.dart`,
  `lib/models/spell.dart`
- **Spec:** `docs/superpowers/specs/2026-08-16-virtue-gated-parameters-design.md`
  ("Out of Scope")
```

- [ ] **Step 3: Update the file's "Last updated" line**

Near the top of the file, `**Status:** Active development · **Last
updated:** 2026-08-16` is already today's date — leave it as is unless the
implementation actually finishes on a later date, in which case update it to
match.

- [ ] **Step 4: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close todo item 17, file items 51 and 52

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
