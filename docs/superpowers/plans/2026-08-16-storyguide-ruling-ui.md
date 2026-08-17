# Storyguide-Ruling UI for Rituals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user declare a spell a Ritual by storyguide ruling (Core Rules line 12352), closing todo item 18.

**Architecture:** Replace `RitualSection`'s single lasting-creation checkbox with a three-way `RadioGroup<RitualDeclaration>` (Not declared / Creates something lasting / Storyguide ruling), wired through the existing `RitualDeclarationChanged` event with no new bloc logic. Regression-test that `SpellCreationBloc._withRitualDeclaration`'s existing storyguide-ruling guard — until now only exercised by template data, never live user input — holds under the same direct user actions the new control performs.

**Tech Stack:** Flutter/Dart, `flutter_bloc`, `bloc_test`, `flutter_test`, `integration_test`.

## Global Constraints

- No model or schema changes. `RitualDeclaration`, `SpellDraft.ritualDeclaration`, and `SpellEngine._deriveRitualStatus`'s unconditional honoring of any declaration already exist and are correct — do not modify `lib/models/ritual_declaration.dart`, `lib/models/spell.dart`, or `lib/engine/spell_engine.dart`.
- Out of scope: todo items 21 and 23, and reclassifying any of the 4 remaining non-derivable Ritual spells (*Rain of Oil*, *Incantation of Summoning the Dead*, *Disenchant*, *Watching Ward*).
- Widget test command: `flutter test`.
- Integration test command: `flutter test integration_test/spell_creation_flow_test.dart -d windows` (required separately — `flutter test` alone does not run `integration_test/`, and this project has a known real-Bloc hang under `flutter_tester`).
- **Superseded 2026-08-17: this is false.** A real Bloc hangs only if it awaits real I/O; the fake-async zone is the actual cause. See `test/support/bloc_factories.dart`.
- Follow the existing `RadioGroup<T>` pattern already used in `lib/presentation/screens/spell_library_screen.dart` (a `RadioGroup<T>(groupValue:, onChanged:, child: Column/Row of RadioListTile<T>(value:, title:, ...))` — individual tiles take no `groupValue`/`onChanged` of their own).

---

### Task 1: Three-way Ritual declaration control

**Files:**
- Modify: `lib/presentation/widgets/ritual_section.dart`
- Modify: `lib/presentation/screens/spell_creation_screen.dart:261-279`
- Test: `test/presentation/widgets/ritual_section_test.dart`
- Test: `integration_test/spell_creation_flow_test.dart:722-732`

**Interfaces:**
- Consumes: `RitualDeclaration` enum (`lib/models/ritual_declaration.dart`, values `none`/`lastingCreation`/`storyguideRuling`, unchanged), `RitualStatus`/`RitualReason` (`lib/engine/ritual_status.dart`, unchanged), `RitualRequirement` (`lib/models/base_effect.dart`, unchanged).
- Produces: `RitualSection` constructor parameter renamed from `showDeclarationCheckbox` to `showLastingCreationOption` (same `bool` meaning: true when `draft.isEligibleForLastingCreationDeclaration`). Widget keys renamed from `ritual-checkbox` to `ritual-radio-none` / `ritual-radio-lastingCreation` / `ritual-radio-storyguideRuling`. No other public interface changes — `ritualStatus`, `declaration`, `durationName`, `targetName`, `guidelineIsSuggested`, `onDeclarationChanged` keep their names and types.

- [ ] **Step 1: Replace the widget test file with the three-way-control version**

Overwrite `test/presentation/widgets/ritual_section_test.dart` in full:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/presentation/widgets/ritual_section.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets(
      'shows the declaration control even for an ordinary spell, hides the banner',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: false,
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    expect(find.byKey(const Key('ritual-banner')), findsNothing);
    expect(find.byKey(const Key('ritual-radio-none')), findsOneWidget);
    expect(find.byKey(const Key('ritual-radio-lastingCreation')), findsNothing);
    expect(find.byKey(const Key('ritual-radio-storyguideRuling')), findsOneWidget);
  });

  testWidgets(
      'shows the "creates something lasting" option only when the draft is Creo + Momentary',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    expect(find.byKey(const Key('ritual-radio-lastingCreation')), findsOneWidget);
  });

  testWidgets('names every reason in the banner', (tester) async {
    // Aegis of the Hearth: Year duration and Boundary target.
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([
        RitualReason.ritualOnlyDuration,
        RitualReason.ritualOnlyTarget,
      ]),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: false,
      durationName: 'Year',
      targetName: 'Boundary',
      guidelineIsSuggested: false,
      onDeclarationChanged: (_) {},
    )));

    final banner = tester.widget<Text>(find
        .descendant(
            of: find.byKey(const Key('ritual-banner')), matching: find.byType(Text))
        .first);
    expect(banner.data, contains('Year duration'));
    expect(banner.data, contains('Boundary target'));
  });

  testWidgets('explains the healing case when the guideline is suggested',
      (tester) async {
    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus([RitualReason.lastingCreation]),
      declaration: RitualDeclaration.lastingCreation,
      showLastingCreationOption: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: true,
      onDeclarationChanged: (_) {},
    )));

    expect(find.textContaining('suspends'), findsOneWidget);
  });

  testWidgets('selecting "creates something lasting" reports lastingCreation',
      (tester) async {
    final reported = <RitualDeclaration>[];

    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.none,
      showLastingCreationOption: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-radio-lastingCreation')));
    expect(reported, [RitualDeclaration.lastingCreation]);
  });

  testWidgets('selecting "storyguide ruling" reports storyguideRuling',
      (tester) async {
    final reported = <RitualDeclaration>[];

    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.lastingCreation,
      showLastingCreationOption: true,
      durationName: 'Momentary',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-radio-storyguideRuling')));
    expect(reported, [RitualDeclaration.storyguideRuling]);
  });

  testWidgets('selecting "not declared" reports none', (tester) async {
    final reported = <RitualDeclaration>[];

    await tester.pumpWidget(_host(RitualSection(
      ritualStatus: const RitualStatus.notRitual(),
      declaration: RitualDeclaration.storyguideRuling,
      showLastingCreationOption: false,
      durationName: 'Sun',
      targetName: 'Individual',
      guidelineIsSuggested: false,
      onDeclarationChanged: reported.add,
    )));

    await tester.tap(find.byKey(const Key('ritual-radio-none')));
    expect(reported, [RitualDeclaration.none]);
  });
}
```

- [ ] **Step 2: Run the test file to verify it fails**

Run: `flutter test test/presentation/widgets/ritual_section_test.dart`
Expected: FAIL. The current `RitualSection` constructor has no `showLastingCreationOption` parameter (only `showDeclarationCheckbox`), so this is a compile-time failure — every test in the file reports the same "no named parameter" error. That is the correct failing state for this step: the test file describes the widget's new public shape, which does not exist yet.

- [ ] **Step 3: Rewrite `RitualSection`**

Replace the full contents of `lib/presentation/widgets/ritual_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/ritual_declaration.dart';

/// The Ritual controls of the spell creation form: a non-interactive banner
/// listing every reason the spell is a Ritual, and a three-way declaration
/// control for the two cases the rulebook leaves to a person's judgement
/// (Core Rules line 12350 onward).
///
/// The banner and the declaration control are independent and both can be on
/// screen at once. A Creo/Momentary/Boundary spell is already forced by its
/// Target; the banner says so and the declaration control stays live and
/// harmless.
class RitualSection extends StatelessWidget {
  final RitualStatus ritualStatus;
  final RitualDeclaration declaration;

  /// True when the draft is Creo with Momentary duration -- the only
  /// configuration the "Creates something lasting" option is offered for
  /// (Core Rules line 12351). The "Storyguide ruling" option has no such
  /// gate: line 12352 lets the troupe declare *any* spell a Ritual.
  final bool showLastingCreationOption;

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
    required this.showLastingCreationOption,
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
        RadioGroup<RitualDeclaration>(
          groupValue: declaration,
          onChanged: (value) {
            if (value != null) onDeclarationChanged(value);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RadioListTile<RitualDeclaration>(
                key: Key('ritual-radio-none'),
                value: RitualDeclaration.none,
                title: Text('Not declared'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (showLastingCreationOption)
                RadioListTile<RitualDeclaration>(
                  key: const Key('ritual-radio-lastingCreation'),
                  value: RitualDeclaration.lastingCreation,
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
                ),
              const RadioListTile<RitualDeclaration>(
                key: Key('ritual-radio-storyguideRuling'),
                value: RitualDeclaration.storyguideRuling,
                title:
                    Text('Storyguide ruling: too spectacular to be freely available'),
                subtitle: Text(
                  "At the troupe's discretion -- not something the guideline "
                  'determines (Core Rules line 12352).',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Rename the argument at the call site**

In `lib/presentation/screens/spell_creation_screen.dart`, find the `RitualSection(...)` construction (around line 261-279):

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
                  showDeclarationCheckbox: draft.isEligibleForLastingCreationDeclaration,
                  durationName: draft.duration?.name ?? '',
                  targetName: draft.target?.name ?? '',
                  guidelineIsSuggested: draft.baseEffect?.ritualRequirement ==
                      RitualRequirement.suggested,
                  onDeclarationChanged: (declaration) =>
                      bloc.add(RitualDeclarationChanged(declaration)),
                ),
```

Change only the `showDeclarationCheckbox:` line to:

```dart
                  showLastingCreationOption: draft.isEligibleForLastingCreationDeclaration,
```

Every other line in that block stays exactly as it is.

- [ ] **Step 5: Run the widget test to verify it passes**

Run: `flutter test test/presentation/widgets/ritual_section_test.dart`
Expected: PASS (7/7).

- [ ] **Step 6: Update the integration test for the renamed key and control**

In `integration_test/spell_creation_flow_test.dart`, add the model import alongside the other `eruditus/models/` imports near the top of the file:

```dart
import 'package:eruditus/models/ritual_declaration.dart';
```

Then replace this block (around line 722-732):

```dart
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
```

with:

```dart
      // The "creates something lasting" radio option appears for Creo +
      // Momentary and is selected by default.
      final lastingCreationRadio =
          find.byKey(const Key('ritual-radio-lastingCreation'));
      await tester.scrollUntilVisible(
        lastingCreationRadio,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        RadioGroup.maybeOf<RitualDeclaration>(tester.element(lastingCreationRadio))
            ?.groupValue,
        RitualDeclaration.lastingCreation,
      );
```

Nothing else in the file changes — the subsequent `calculate-button` tap and `ritual-banner` assertions stay as they are.

- [ ] **Step 7: Run the integration test to verify it passes**

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: PASS. This suite is not covered by plain `flutter test` — it must be run with this exact command.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/widgets/ritual_section.dart lib/presentation/screens/spell_creation_screen.dart test/presentation/widgets/ritual_section_test.dart integration_test/spell_creation_flow_test.dart
git commit -m "feat: three-way Ritual declaration control (item 18)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Bloc regression tests for storyguideRuling under live user input

**Files:**
- Modify: `test/bloc/spell_creation_bloc_test.dart:838-953` (the existing `group('ritual declaration', ...)` block)

**Interfaces:**
- Consumes: `SpellCreationBloc`, `RitualDeclarationChanged`, `TechniqueSelected`, `FormSelected`, `BaseEffectSelected` events (all pre-existing, unchanged), and the `momentary`/`sun`/`plainCreo` fixtures already declared inside the `group('ritual declaration', ...)` block in this file (do not redeclare them).
- Produces: nothing consumed by later tasks — this is the plan's final task.

This task is test-only. Task 1's exploration (recorded in the design spec's "Existing State" section) found that `SpellCreationBloc._withRitualDeclaration` already special-cases `storyguideRuling` — it returns the draft untouched, before checking lasting-creation eligibility at all, whenever `draft.ritualDeclaration == RitualDeclaration.storyguideRuling`. One existing test (`'never prunes a storyguideRuling'`, line 942-952) already proves this for `DurationSelected`. The five tests below extend that same proof to the other three `reapplyDefault` call sites (`TechniqueSelected`, `FormSelected`, `BaseEffectSelected`) and to two direct-replacement cases the new radio control makes newly reachable. **All five are expected to pass immediately, with no bloc code changes** — this locks in already-correct behavior under the paths a live user can now actually trigger. If any of them fails, that is a real bug in `SpellCreationBloc._withRitualDeclaration` or the `RitualDeclarationChanged` handler (`lib/bloc/spell_creation/spell_creation_bloc.dart`) and must be fixed as part of this task, not deferred.

- [ ] **Step 1: Add the five tests**

Inside the existing `group('ritual declaration', ...)` block in `test/bloc/spell_creation_bloc_test.dart`, immediately after the `'never prunes a storyguideRuling'` test (after line 952, still before the block's closing `});` on line 953), insert:

```dart
    blocTest<SpellCreationBloc, SpellCreationState>(
      'never prunes a storyguideRuling on TechniqueSelected',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(const TechniqueSelected('Creo')),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'never prunes a storyguideRuling on FormSelected',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(const FormSelected('Terram')),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'never prunes a storyguideRuling on BaseEffectSelected',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(BaseEffectSelected(plainCreo)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'switching from lastingCreation to storyguideRuling replaces the declaration',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling)),
      verify: (bloc) => expect(
        bloc.state.draft.ritualDeclaration, RitualDeclaration.storyguideRuling),
    );

    blocTest<SpellCreationBloc, SpellCreationState>(
      'an explicit clear from storyguideRuling reports none, not the lastingCreation default',
      build: () => SpellCreationBloc(
          spellEngine: spellEngine, spellRepository: spellRepository),
      act: (bloc) => bloc
        ..add(const TechniqueSelected('Creo'))
        ..add(DurationSelected(momentary))
        ..add(const RitualDeclarationChanged(RitualDeclaration.storyguideRuling))
        ..add(const RitualDeclarationChanged(RitualDeclaration.none)),
      verify: (bloc) =>
          expect(bloc.state.draft.ritualDeclaration, RitualDeclaration.none),
    );
```

- [ ] **Step 2: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_creation_bloc_test.dart`
Expected: PASS, all tests in the file including the 5 new ones (per the reasoning above — no production code change is anticipated).

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS, no regressions elsewhere.

- [ ] **Step 4: Commit**

```bash
git add test/bloc/spell_creation_bloc_test.dart
git commit -m "test: lock in storyguideRuling survival under live user events (item 18)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Final Verification

- [ ] `flutter test` passes in full.
- [ ] `flutter test integration_test/spell_creation_flow_test.dart -d windows` passes.
- [ ] Update `.superpowers/todo.md` item 18: check off both remaining bullets, and add a short "✅ DONE 2026-08-16" note describing the three-way radio control, matching the style of other closed items in that file (e.g. item 37's "**Both parts shipped**" note).
