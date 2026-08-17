# Required Prose for User-Created Spells — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the spell creation screen a summary input and make the
summary-or-description rule apply to user-created spells as well as published
ones, closing todo item 13.

**Architecture:** The summary lives on `SpellDraft` and is edited in a
screen-body section like every other draft field; the save dialog collects it
only when the draft still has none. The rule itself is enforced where it
already is — inside the `Spell` constructor and `SpellDraft.toSpell` — by
deleting a `source` branch, not by adding a new check. Records written before
the rule existed are backfilled at deserialization so nothing already saved
becomes unloadable.

**Tech Stack:** Flutter, `flutter_bloc`, `bloc_test`, `mocktail`.

**Design spec:** `docs/superpowers/specs/2026-08-17-user-created-spell-prose-design.md`

## Global Constraints

- **Task order is load-bearing.** Tasks 1–4 are additive and leave the suite
  green at every commit. Task 5 flips the rule and is the only task that
  breaks existing fixtures. Task 4 (the backfill) MUST land before Task 5, or
  flipping the rule makes already-saved spells unloadable.
- **The spec's Decision 6 needs no work.** `TemplateInstantiated` already
  copies `summary` and `description` from the template
  (`spell_creation_bloc.dart:273-274`), and that is already asserted
  (`test/bloc/spell_creation_bloc_test.dart:1488`). Verified 2026-08-17 while
  writing this plan. Do not add a duplicate test.
- **Do not add a prose check to `SpellEngine.validateSpellDraft`.** It gates
  breakdown recalculation (`spell_creation_bloc.dart:387-391`), so requiring
  prose there would stop the level displaying until a summary was typed. This
  is Decision 4 in the spec and is deliberate.
- **`flutter test` does not run `integration_test/`.** Run
  `flutter test integration_test/spell_creation_flow_test.dart -d windows`
  separately. Both must pass before Task 6.
- The backfill sentinel string is exactly `'No summary recorded.'`
- The validator's new message is exactly `'a spell needs a summary or a description'`.
- Follow the existing comment style: explain *why*, not *what*, and record
  what was rejected where a reader would otherwise wonder.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `lib/bloc/spell_creation/spell_creation_event.dart` | `SummaryChanged`; `SpellSaveRequested.summary` | 1, 4 |
| `lib/bloc/spell_creation/spell_creation_bloc.dart` | Handle `SummaryChanged`; apply an event-supplied summary on save | 1, 4 |
| `lib/presentation/screens/spell_creation_screen.dart` | `_SummaryField`; `_SaveSpellDialog.requiresSummary`; wiring | 2, 4 |
| `lib/models/spell.dart` | `Spell.fromMap` backfill; unconditional `validateSpellProse` | 4, 5 |
| `test/bloc/spell_creation_bloc_test.dart` | Event/handler coverage | 1, 3 |
| `test/presentation/screens/spell_creation_screen_test.dart` | Field and dialog coverage | 2, 3 |
| `test/models/spell_test.dart` | Backfill and rule coverage | 4, 5 |
| `integration_test/spell_creation_flow_test.dart` | End-to-end save now needs prose | 5 |
| `.superpowers/todo.md`, provenance design spec | Bookkeeping | 6 |

---

### Task 1: `SummaryChanged` event and handler

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_event.dart` (after `RequisiteKindChanged`, ~line 99)
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart` (event chain, before `else if (event is ModifierOptionSelected)` ~line 212)
- Test: `test/bloc/spell_creation_bloc_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `class SummaryChanged extends SpellCreationEvent` with
  `final String summary` and `const SummaryChanged(this.summary)`. Tasks 2
  and 4 dispatch it.

- [ ] **Step 1: Write the failing test**

Add to `test/bloc/spell_creation_bloc_test.dart`:

```dart
  blocTest<SpellCreationBloc, SpellCreationState>(
    'SummaryChanged writes the text to the draft',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) => bloc.add(const SummaryChanged('A jet of flame.')),
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.status, 'status', SpellCreationStatus.editing)
          .having((s) => s.draft.summary, 'draft.summary', 'A jet of flame.'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'SummaryChanged does not recompute the breakdown',
    // Prose cannot change a level, so recomputing on every keystroke of a
    // multi-line field is pure waste. Pinned because the surrounding
    // handlers all DO recompute, making this the odd one out on purpose.
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellCalculated());
      bloc.add(const SummaryChanged('A jet of flame.'));
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.draft.summary, 'draft.summary', 'A jet of flame.')
          .having((s) => s.calculatedLevel, 'calculatedLevel', isNotNull),
    ],
  );
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: FAIL — `SummaryChanged` is undefined.

- [ ] **Step 3: Add the event**

In `spell_creation_event.dart`, after `RequisiteKindChanged`:

```dart
/// The spell's own prose. Only [summary] is user-editable: `description` is
/// documented as verbatim rulebook text, which a user-created spell has none
/// of (design spec Decision 2).
class SummaryChanged extends SpellCreationEvent {
  final String summary;
  const SummaryChanged(this.summary);
  @override
  List<Object?> get props => [summary];
}
```

- [ ] **Step 4: Add the handler**

In `spell_creation_bloc.dart`'s event chain, before the
`else if (event is ModifierOptionSelected)` branch:

```dart
    } else if (event is SummaryChanged) {
      // Draft only, deliberately no recompute: prose cannot change a level,
      // unlike every neighbouring handler here. Nor is there any pruning to
      // do on the way out -- prose is scoped to no Technique, Form or
      // guideline, so nothing it touches can go stale.
      emit(state.copyWith(
        status: SpellCreationStatus.editing,
        draft: state.draft.copyWith(summary: event.summary),
      ));
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/bloc/spell_creation/spell_creation_event.dart lib/bloc/spell_creation/spell_creation_bloc.dart test/bloc/spell_creation_bloc_test.dart
git commit -m "feat: carry a user-written summary on the spell draft"
```

---

### Task 2: The summary field on the creation screen

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart` (body, after `RitualSection` ends at ~line 285; new widget beside `_SpecificTypeField` ~line 714)
- Test: `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: `SummaryChanged(String)` from Task 1.
- Produces: widget key `summary-field`.

- [ ] **Step 1: Write the failing test**

Add to `test/presentation/screens/spell_creation_screen_test.dart`:

```dart
  testWidgets('typing a summary dispatches SummaryChanged', (tester) async {
    await pumpScreen(tester, SpellCreationState.initial());
    await tester.scrollUntilVisible(find.byKey(const Key('summary-field')), 200);

    await tester.enterText(find.byKey(const Key('summary-field')), 'A jet of flame.');
    await tester.pump();

    verify(() => bloc.add(const SummaryChanged('A jet of flame.'))).called(1);
  });

  testWidgets('the summary field shows the draft summary', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.editing,
      draft: SpellDraft(summary: 'Seeded from a template.'),
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('summary-field')), 200);

    expect(find.text('Seeded from a template.'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: FAIL — no widget with key `summary-field`.

- [ ] **Step 3: Add the field widget**

In `spell_creation_screen.dart`, immediately after `_SpecificTypeFieldState`:

```dart
/// The spell's own summary.
///
/// A real [StatefulWidget] owning its controller, for the same reason as
/// [_SpecificTypeField]: an uncontrolled [TextFormField] seeds itself from
/// `initialValue` once and never resyncs. That resync is load-bearing here,
/// not decorative -- a successful save resets the draft to
/// `SpellCreationState.initial()`, and without it this field would keep
/// showing the saved spell's summary over an empty draft.
class _SummaryField extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _SummaryField({required this.value, required this.onChanged});

  @override
  State<_SummaryField> createState() => _SummaryFieldState();
}

class _SummaryFieldState extends State<_SummaryField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(covariant _SummaryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != (widget.value ?? '')) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('summary-field'),
      controller: _controller,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Summary',
        helperText: 'Required. Shown on this spell\'s card in your library.',
      ),
      onChanged: widget.onChanged,
    );
  }
}
```

- [ ] **Step 4: Place it in the body**

In the screen body, directly after the closing `),` of `RitualSection` and
before the `const SizedBox(height: 16)` that precedes the validation errors:

```dart
                const SizedBox(height: 16),
                _SummaryField(
                  value: draft.summary,
                  onChanged: (value) => bloc.add(SummaryChanged(value)),
                ),
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/spell_creation_screen.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: add a summary field to the spell creation screen"
```

---

### Task 3: Save-dialog backstop

**Files:**
- Modify: `lib/bloc/spell_creation/spell_creation_event.dart` (`SpellSaveRequested`, ~line 105)
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart` (`_handleSpellSaveRequested`, ~line 457)
- Modify: `lib/presentation/screens/spell_creation_screen.dart` (save button ~line 347; `_SaveSpellDialog` ~line 798)
- Test: `test/bloc/spell_creation_bloc_test.dart`, `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: `SummaryChanged` (Task 1), `_SummaryField` (Task 2). Produces the
  save path Task 5's integration test drives.
- Produces: `SpellSaveRequested(String name, {String? summary})`; dialog keys
  `save-dialog-summary-field` and the existing `spell-name-field` /
  `confirm-save-button`.

- [ ] **Step 1: Write the failing tests**

Bloc test:

```dart
  blocTest<SpellCreationBloc, SpellCreationState>(
    'a summary supplied at save time reaches the saved spell',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SpellSaveRequested('My Fireball', summary: 'A jet of flame.'));
    },
    skip: 7,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.savedSpell?.summary, 'savedSpell.summary', 'A jet of flame.'),
    ],
  );

  blocTest<SpellCreationBloc, SpellCreationState>(
    'a draft summary survives a save that supplies none',
    build: () => SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository),
    act: (bloc) {
      bloc.add(const TechniqueSelected('Creo'));
      bloc.add(const FormSelected('Ignem'));
      bloc.add(BaseEffectSelected(creoIgnemEffect));
      bloc.add(RangeSelected(rangeParam));
      bloc.add(DurationSelected(durationParam));
      bloc.add(TargetSelected(targetParam));
      bloc.add(const SummaryChanged('Typed while building.'));
      bloc.add(const SpellSaveRequested('My Fireball'));
    },
    skip: 8,
    expect: () => [
      isA<SpellCreationState>()
          .having((s) => s.savedSpell?.summary, 'savedSpell.summary', 'Typed while building.'),
    ],
  );
```

Widget tests:

```dart
  testWidgets('the save dialog asks for a summary when the draft has none', (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      calculatedLevel: 10,
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save-dialog-summary-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('spell-name-field')), 'My Fireball');
    await tester.enterText(find.byKey(const Key('save-dialog-summary-field')), 'A jet of flame.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-save-button')));
    await tester.pumpAndSettle();

    verify(() => bloc.add(
        const SpellSaveRequested('My Fireball', summary: 'A jet of flame.'))).called(1);
  });

  testWidgets('the save dialog asks only for a name when the draft has a summary',
      (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(
        technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect,
        range: range, duration: duration, target: target,
        summary: 'Already written.',
      ),
      calculatedLevel: 10,
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save-dialog-summary-field')), findsNothing);

    await tester.enterText(find.byKey(const Key('spell-name-field')), 'My Fireball');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-save-button')));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const SpellSaveRequested('My Fireball'))).called(1);
  });

  testWidgets('the save dialog blocks confirmation until both fields are filled',
      (tester) async {
    final state = SpellCreationState(
      status: SpellCreationStatus.calculated,
      draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect, range: range, duration: duration, target: target),
      calculatedLevel: 10,
    );
    await pumpScreen(tester, state);
    await tester.scrollUntilVisible(find.byKey(const Key('save-button')), 200);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('spell-name-field')), 'My Fireball');
    await tester.pumpAndSettle();

    final confirm = tester.widget<ElevatedButton>(find.byKey(const Key('confirm-save-button')));
    expect(confirm.onPressed, isNull);
  });
```

**Also update the existing test** `'saving with a name dispatches SpellSaveRequested'`
(~line 456): its draft has no summary, so the dialog now requires one. Add an
`enterText` on `save-dialog-summary-field` and assert the summary in the
expected event, or delete it as superseded by the first widget test above —
they now cover the same path.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart test/presentation/screens/spell_creation_screen_test.dart`
Expected: FAIL — `SpellSaveRequested` has no `summary` parameter.

- [ ] **Step 3: Widen the event**

```dart
class SpellSaveRequested extends SpellCreationEvent {
  final String name;

  /// Supplied by the save dialog when the draft had no prose of its own.
  /// Null means "the draft already has it" -- not "clear it".
  final String? summary;

  const SpellSaveRequested(this.name, {this.summary});
  @override
  List<Object?> get props => [name, summary];
}
```

- [ ] **Step 4: Apply it in the save handler**

In `_handleSpellSaveRequested`, replace the `toSpell` line:

```dart
      // One event, one atomic save. Dispatching SummaryChanged and then
      // SpellSaveRequested would leave the draft half-updated if the second
      // never arrived.
      final draft = event.summary == null
          ? state.draft
          : state.draft.copyWith(summary: event.summary);
      final spell = draft.toSpell(name: event.name, source: PublicationSource.userCreated);
```

- [ ] **Step 5: Add the dialog branch**

Replace `_SaveSpellDialog` with:

```dart
class _SaveSpellDialog extends StatefulWidget {
  /// Whether to collect a summary as well as a name. True when the draft
  /// carries no prose at all -- the summary-or-description rule has to be
  /// satisfied by the time this spell is constructed, and this dialog is the
  /// last point at which it can be.
  final bool requiresSummary;

  const _SaveSpellDialog({required this.requiresSummary});

  @override
  State<_SaveSpellDialog> createState() => _SaveSpellDialogState();
}

class _SaveSpellDialogState extends State<_SaveSpellDialog> {
  final _nameController = TextEditingController();
  final _summaryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (!widget.requiresSummary || _summaryController.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name Your Spell'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('spell-name-field'),
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'e.g., Pillar of Flames'),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.requiresSummary) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('save-dialog-summary-field'),
              controller: _summaryController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Summary',
                hintText: 'What does this spell do?',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('confirm-save-button'),
          onPressed: _canSave
              ? () => Navigator.of(context).pop((
                  name: _nameController.text,
                  summary: widget.requiresSummary ? _summaryController.text : null,
                ))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Wire the save button**

Replace the save button's `onPressed` body:

```dart
                              : () async {
                                  final hasProse =
                                      (draft.summary ?? '').trim().isNotEmpty ||
                                          (draft.description ?? '').trim().isNotEmpty;
                                  final result =
                                      await showDialog<({String name, String? summary})>(
                                    context: context,
                                    builder: (dialogContext) =>
                                        _SaveSpellDialog(requiresSummary: !hasProse),
                                  );
                                  if (result != null && result.name.isNotEmpty) {
                                    bloc.add(SpellSaveRequested(result.name,
                                        summary: result.summary));
                                  }
                                },
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart test/presentation/screens/spell_creation_screen_test.dart`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/bloc/spell_creation lib/presentation/screens/spell_creation_screen.dart test/bloc/spell_creation_bloc_test.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: collect a summary in the save dialog when the draft has none"
```

---

### Task 4: Backfill prose on deserialization

**Files:**
- Modify: `lib/models/spell.dart` (`Spell.fromMap`, ~line 325)
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Consumes: nothing. Produces: the constant `legacySummaryPlaceholder`, used
  by Task 5's tests if they need to assert on it.

- [ ] **Step 1: Write the failing test**

```dart
  group('fromMap prose backfill', () {
    Map<String, dynamic> userCreatedMap({String? summary, String? description}) => {
          'id': 'u1',
          'name': 'My Spell',
          'baseEffectId': 'e1',
          'technique': 'Creo',
          'form': 'Ignem',
          'rangeId': 'range-voice',
          'durationId': 'duration-momentary',
          'targetId': 'target-individual',
          'requisites': <String, dynamic>{},
          'summary': summary,
          'description': description,
          'source': 'user-created',
          'createdAt': DateTime(2026, 1, 1).toIso8601String(),
          'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
        };

    test('a user-created record with no prose is backfilled, not rejected', () {
      final spell = Spell.fromMap(userCreatedMap());
      expect(spell.summary, legacySummaryPlaceholder);
    });

    test('an existing summary is left alone', () {
      final spell = Spell.fromMap(userCreatedMap(summary: 'Mine.'));
      expect(spell.summary, 'Mine.');
    });

    test('a description alone is enough, and no summary is invented', () {
      final spell = Spell.fromMap(userCreatedMap(description: 'Long form.'));
      expect(spell.summary, isNull);
    });

    test('an empty-string summary counts as absent', () {
      final spell = Spell.fromMap(userCreatedMap(summary: '   '));
      expect(spell.summary, legacySummaryPlaceholder);
    });

    test('a published record with no prose still throws', () {
      // The backfill must never reach published data: assertion 7 in
      // published_spell_import_test.dart is what stops a prose-less spell
      // shipping, and silently repairing one here would take its teeth out.
      final map = userCreatedMap()
        ..['source'] = 'published'
        ..['citations'] = [
          {'bookId': 'arm5-core'}
        ];
      expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — `legacySummaryPlaceholder` is undefined. (The
"published still throws" case already passes; the others do not.)

- [ ] **Step 3: Implement the backfill**

In `lib/models/spell.dart`, above `class Spell`:

```dart
/// Stands in for the prose of a user-created spell saved before a summary was
/// required (todo item 13).
///
/// Not a derivation: name and stat line both already appear on the card, so
/// deriving from them would add nothing, and the provenance design
/// (2026-07-27) rejected auto-derived summaries as storing derivable data.
/// This states the one true thing instead -- that none was recorded.
const String legacySummaryPlaceholder = 'No summary recorded.';
```

Then in `Spell.fromMap`, replace the `summary:` line with a call to a helper
defined beside the constant:

```dart
/// The summary a deserialized record should carry.
///
/// Applied in `fromMap` rather than in the datasource because a backup
/// written before the rule existed hits the identical wall one layer over --
/// `BackupService.importFromJson` builds its spells in a list literal, so one
/// throwing record aborts the whole restore. Read-only: nothing is written
/// back, so there is still no migration story.
String? _backfilledSummary(Map<String, dynamic> map) {
  final summary = map['summary'] as String?;
  final description = map['description'] as String?;
  final hasProse = (summary != null && summary.trim().isNotEmpty) ||
      (description != null && description.trim().isNotEmpty);
  if (hasProse) return summary;
  // Published records are deliberately excluded: one with no prose is an
  // importer bug, and must keep failing loudly.
  return Provenance.fromMap(map).source == PublicationSource.userCreated
      ? legacySummaryPlaceholder
      : summary;
}
```

and use it:

```dart
        summary: _backfilledSummary(map),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/spell_test.dart`
Expected: PASS

- [ ] **Step 5: Run the whole suite — this touches every stored spell**

Run: `flutter test`
Expected: PASS, unchanged count.

- [ ] **Step 6: Commit**

```bash
git add lib/models/spell.dart test/models/spell_test.dart
git commit -m "feat: backfill prose for user-created records saved before it was required"
```

---

### Task 5: Make the rule unconditional

This is the only task that breaks existing fixtures. **Let the suite tell you
the list** rather than hunting call sites by hand.

**Files:**
- Modify: `lib/models/spell.dart` (`validateSpellProse` ~line 25, constructor call ~line 289, `toSpell` call ~line 434)
- Modify: test fixtures across `test/` as the suite reports them
- Modify: `integration_test/spell_creation_flow_test.dart`
- Test: `test/models/spell_test.dart`

**Interfaces:**
- Consumes: `legacySummaryPlaceholder` (Task 4), the dialog from Task 3.
- Produces: `validateSpellProse({required String? summary, required String? description})`
  — the `source` parameter is **removed**.

- [ ] **Step 1: Write the failing test**

```dart
  test('a user-created spell needs a summary or a description', () {
    expect(
      () => Spell(
        id: 'u1',
        name: 'My Spell',
        baseEffectId: 'e1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'range-voice',
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const {},
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('the rule names no source', () {
    expect(
      validateSpellProse(summary: null, description: null),
      ['a spell needs a summary or a description'],
    );
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/models/spell_test.dart`
Expected: FAIL — the spell constructs fine, and `validateSpellProse` still
requires a `source:` argument.

- [ ] **Step 3: Drop the branch**

```dart
/// Every spell needs a summary or a description.
///
/// Unconditional since todo item 13 landed the creation screen's summary
/// input. It was conditional on `source == published` only because the screen
/// collected nothing but a name, which the 2026-07-27 provenance design
/// recorded as an interim measure.
List<String> validateSpellProse({
  required String? summary,
  required String? description,
}) {
  final hasProse = (summary != null && summary.isNotEmpty) ||
      (description != null && description.isNotEmpty);

  if (!hasProse) {
    return ['a spell needs a summary or a description'];
  }
  return const [];
}
```

Drop the `source:` argument at both call sites (`Spell`'s constructor body,
`SpellDraft.toSpell`).

- [ ] **Step 4: Run the failing test to verify it passes**

Run: `flutter test test/models/spell_test.dart`
Expected: the two new tests PASS; **other tests in this file now fail.** That
is the fixture sweep, and it is expected.

- [ ] **Step 5: Sweep the fixtures**

Run: `flutter test`

For every failure, add prose to the fixture that constructs the spell — a
short summary describing what that fixture's spell does. Do **not** weaken the
validator, and do **not** reach for `legacySummaryPlaceholder` in a test
fixture: that constant means "written before the rule existed", which is not
true of a test written today.

Expect the bulk in `test/models/spell_test.dart` and
`test/engine/spell_engine_test.dart`; `spell_library_bloc_test.dart`,
`resolved_spell_test.dart`, `spell_resolver_test.dart` and
`spell_draft_copy_with_test.dart` also construct spells. Re-run until green.

- [ ] **Step 6: Update the integration test**

`integration_test/spell_creation_flow_test.dart` saves spells end-to-end, so
every save now meets the dialog's summary field. After each
`enterText` on `spell-name-field`, add:

```dart
    await tester.enterText(
        find.byKey(const Key('save-dialog-summary-field')), 'Created by an integration test.');
    await tester.pumpAndSettle();
```

- [ ] **Step 7: Run both suites**

Run: `flutter test`
Expected: PASS

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: PASS, 8 tests.

- [ ] **Step 8: Commit**

```bash
git add lib test integration_test
git commit -m "feat: require a summary or description on every spell"
```

---

### Task 6: Bookkeeping

**Files:**
- Modify: `docs/superpowers/specs/2026-07-27-spell-provenance-and-tags-design.md` (lines 63-77)
- Modify: `.superpowers/todo.md` (item 13 in section C; section 0's table; *Where the import stands* if any count moved)

**Interfaces:** none.

- [ ] **Step 1: Settle the provenance spec's interim note**

Rewrite lines 63-77 so invariant 1 reads as unconditional and the "interim
measure" paragraph becomes a record of what was deferred and how it was
settled, citing this plan's spec. Keep the two rejected alternatives — they
still explain why the summary is typed rather than derived.

- [ ] **Step 2: Close todo item 13**

Move item 13 out of section C into **Completed**, reduced to what still binds:
the unconditional rule, the draft-plus-dialog split, why `validateSpellDraft`
was deliberately left alone, and the backfill's two boundaries (user-created
only, read-only). Update section 0's row 3 to ✅ and note that row 5's item 14
is now the only thing left open in that table.

- [ ] **Step 3: Run everything one last time**

```bash
flutter test
flutter test integration_test/spell_creation_flow_test.dart -d windows
python -m unittest discover -s scripts/spell_import/tests -p "test_*.py"
```

Expected: all three green. Record the resulting test counts in the todo's
suite-status table.

- [ ] **Step 4: Commit**

```bash
git add .superpowers/todo.md docs/superpowers/specs/2026-07-27-spell-provenance-and-tags-design.md
git commit -m "docs: close todo item 13 and settle the provenance spec's interim invariant"
```
