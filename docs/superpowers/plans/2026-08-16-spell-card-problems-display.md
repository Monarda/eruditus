# Surfacing ResolvedSpell.problems on the Library Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `ResolvedSpell.problems` (already shipped, already computed correctly) its first UI consumer — a Library card whose underlying spell violates a catalog invariant is visibly flagged instead of rendering as an ordinary, silently-untrustworthy card.

**Architecture:** `SpellCard` gains one new caller-supplied parameter, `problems`, mirroring how `isRitual`/`isGeneral`/`isException`/`rationale` are already precomputed by the caller rather than read from `entry` — `problems` isn't on the shared `LibraryEntry` interface, only `ResolvedSpell` exposes it. `SpellLibraryScreen`'s one spell-mapping call site threads `s.problems` through. No bloc, model, or catalog change.

**Tech Stack:** Dart / Flutter, `flutter_test` widget tests.

## Global Constraints

- Follow the existing `SpellCard` convention: values a caller can precompute are passed in, never derived from `entry` inside the widget (see `isRitual`/`isGeneral`/`isException`/`rationale`).
- No migration story, no backwards-compatibility shim — this is additive, default-empty, and the project is prototype-stage (dropping/rewriting stored data is free; see project convention).
- Every new/changed behavior gets a widget test before the implementation (TDD).
- Spec: `docs/superpowers/specs/2026-08-16-spell-card-problems-display-design.md` — read it if anything below is ambiguous.

---

## Task 1: `SpellCard` renders `problems`

**Files:**
- Modify: `lib/presentation/widgets/spell_card.dart`
- Test: `test/presentation/widgets/spell_card_test.dart`

**Interfaces:**
- Consumes: `LibraryEntry.isResolved` (existing), `ResolvedSpell.problems` (existing, `lib/models/resolved_spell.dart`) — but only via the new parameter below, not read from `entry` directly.
- Produces: `SpellCard({..., List<String> problems = const []})` — a new named constructor parameter every later task (Task 2) relies on by this exact name and type.

- [ ] **Step 1: Write the failing tests**

Add to `test/presentation/widgets/spell_card_test.dart`, right after the existing `'shows a Ritual chip only when the spell is a Ritual'` test:

```dart
  testWidgets('shows a "Needs review" chip, unverified level suffix, and joined problem text',
      (tester) async {
    final spell = buildSpell(name: 'Miscast Aegis', summary: 'Test summary.');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(
          entry: spell,
          level: 20,
          problems: const [
            'Choose a level for this General guideline',
            'Only one option may be selected for Size',
          ],
        ),
      ),
    ));

    expect(find.byKey(const Key('needs-review-chip')), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.textContaining('Level 20 (unverified)'), findsOneWidget);
    expect(
      find.text('Choose a level for this General guideline; Only one option may be selected for Size'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('spell-card-invalid')), findsOneWidget);
  });

  testWidgets('an empty problems list renders no chip, no suffix, and no invalid key',
      (tester) async {
    final spell = buildSpell(name: 'Ordinary Bolt', summary: 'Test summary.');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(entry: spell, level: 20)),
    ));

    expect(find.byKey(const Key('needs-review-chip')), findsNothing);
    expect(find.textContaining('(unverified)'), findsNothing);
    expect(find.byKey(const Key('spell-card-invalid')), findsNothing);
  });

  testWidgets(
      'an unresolved spell with a non-empty problems value still renders only the unavailable branch',
      (tester) async {
    final record = Spell(
      id: 'orphan-2',
      name: 'Half-Broken Spell',
      baseEffectId: 'deleted-custom-effect',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const {},
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    // Base effect missing, parameters present -- the same "deleted custom
    // effect" shape as the existing unresolved fixture above. The explicit
    // non-empty `problems` here exercises the widget's own gating (isResolved
    // && problems.isNotEmpty), independent of whether ResolvedSpell.problems
    // could ever actually produce this combination for a real record.
    final unresolved = ResolvedSpell(
      record: record,
      baseEffect: null,
      range: personalParam,
      duration: momentaryParam,
      target: individualParam,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpellCard(
          entry: unresolved,
          problems: const ['Choose a level for this General guideline'],
        ),
      ),
    ));

    expect(find.byKey(const Key('spell-card-unresolved')), findsOneWidget);
    expect(find.byKey(const Key('spell-card-invalid')), findsNothing);
    expect(find.byKey(const Key('needs-review-chip')), findsNothing);
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(find.text('Choose a level for this General guideline'), findsNothing);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: the three new tests FAIL (no `problems` parameter exists on `SpellCard` yet, so this fails to compile) — every test in the file reports as failing/erroring, not just the three new ones. That total failure is the expected signal at this step.

- [ ] **Step 3: Implement**

Replace the full contents of `lib/presentation/widgets/spell_card.dart` with:

```dart
import 'package:flutter/material.dart';

import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/publication_source.dart';

class SpellCard extends StatelessWidget {
  final LibraryEntry entry;
  final int? level;
  final VoidCallback? onTap;

  /// A short "why this card exists outside the normal computed path" note
  /// — currently only set by an exception-spell card. Rendered as an extra
  /// line below the summary/description blurb, when present.
  final String? rationale;

  /// Precomputed by the caller, which owns the SpellEngine. The card never
  /// derives it — same reason `level` is passed in rather than calculated here.
  final bool isRitual;

  /// True for a General guideline, which has no fixed level of its own —
  /// distinct from [isRitual], which is a property of an already-leveled
  /// spell. Mirrors [isRitual]'s "precomputed by the caller" treatment: a
  /// LibraryEntry has no field a General template and a Ritual spell could
  /// share, so both are supplied rather than derived here.
  final bool isGeneral;

  /// True for an [ExceptionSpell] — a spell the rulebook itself says
  /// guideline arithmetic doesn't apply to. Distinct from [isGeneral]:
  /// an exception spell is never instantiable, whether or not it happens to
  /// print a level.
  final bool isException;

  /// Catalog-validity problems on the underlying record -- a sibling of
  /// [LibraryEntry.isResolved], not a substitute for it: [isResolved] means
  /// "can a level even be computed", this means "the level computes but the
  /// combination breaks a rule". Only `ResolvedSpell` exposes this today
  /// (`ResolvedSpell.problems`), so it is precomputed by the caller rather
  /// than read from [entry] directly -- the same way [isRitual]/[isGeneral]/
  /// [rationale] already are. Rendered only when [LibraryEntry.isResolved]
  /// is true; ignored otherwise, leaving the unresolved branch below
  /// untouched.
  final List<String> problems;

  /// Rendered inside the card below the ListTile, e.g. the Library screen's
  /// *Learn at level…* button for a template. Empty by default so ordinary
  /// spell cards (which have no actions) are unchanged.
  final List<Widget> actions;

  const SpellCard({
    super.key,
    required this.entry,
    this.level,
    this.onTap,
    this.rationale,
    this.isRitual = false,
    this.isGeneral = false,
    this.isException = false,
    this.problems = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isInvalid = !entry.isResolved;
    final hasProblems = entry.isResolved && problems.isNotEmpty;
    // An unresolved spell (see below) has a null technique/form too, since
    // both are derived from the (possibly null) resolved baseEffect. Reachable
    // via BackupService.importFromJson, which calls Spell.fromMap directly on
    // user-supplied JSON where `name` is optional: without this branch a
    // nameless, unresolved spell would render the literal string
    // "Untitled null null".
    final title = entry.name ??
        (isInvalid ? 'Untitled spell' : 'Untitled ${entry.technique} ${entry.form}');
    final String subtitle;
    if (isInvalid) {
      // The catalog entry this spell was built on no longer exists (a custom
      // effect or parameter the user deleted). Say so plainly rather than
      // showing a half-empty card or hiding the spell.
      subtitle = 'Unavailable — missing ${entry.unresolvedReferences.join(', ')}';
    } else {
      // hasProblems doesn't change *whether* a level renders, only whether
      // it's flagged: the breakdown genuinely computed, so unlike the
      // isInvalid branch above there is a real number to show.
      final levelSuffix = hasProblems ? ' (unverified)' : '';
      subtitle = level != null
          ? '${entry.technique} ${entry.form} • Level $level$levelSuffix'
          : '${entry.technique} ${entry.form}';
    }
    // Prefer the paraphrase; fall back to the verbatim rulebook text. A
    // published spell always has at least one of them; a user-created spell may
    // have neither, in which case the blurb is simply omitted.
    final blurb = entry.summary ?? entry.description;
    final hasBlurb = blurb != null && blurb.isNotEmpty;

    return Card(
      key: isInvalid
          ? const Key('spell-card-unresolved')
          : (hasProblems ? const Key('spell-card-invalid') : null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: onTap,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(title)),
                if (isRitual)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      key: Key('ritual-chip'),
                      label: Text('Ritual'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (isGeneral)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      key: Key('general-chip'),
                      label: Text('Gen'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (isException)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      key: Key('exception-chip'),
                      label: Text('Exception'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (hasProblems)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      key: const Key('needs-review-chip'),
                      label: const Text('Needs review'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      labelStyle:
                          TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(subtitle,
                    style: isInvalid
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null),
                if (hasBlurb)
                  Text(blurb, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (hasProblems)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      problems.join('; '),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (rationale != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      rationale!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            trailing: Chip(
                label: Text(
                    entry.source == PublicationSource.published ? 'Published' : 'My Spell')),
          ),
          if (actions.isNotEmpty) ...actions,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: PASS — all tests in the file, the three new ones and every pre-existing one (confirming the additive parameter didn't change any existing card's rendering).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/spell_card.dart test/presentation/widgets/spell_card_test.dart
git commit -m "feat: SpellCard flags a spell whose ResolvedSpell.problems is non-empty

New caller-supplied 'problems' parameter, precomputed the same way
isRitual/isGeneral/rationale already are. A resolved spell with problems
gets a 'Needs review' chip, an '(unverified)' level suffix, and the joined
problem text below the blurb -- rendered only when isResolved is true, so
the existing unresolved branch is untouched. Part of todo item 40's last
checkbox; see docs/superpowers/specs/2026-08-16-spell-card-problems-display-design.md.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: `SpellLibraryScreen` threads `ResolvedSpell.problems` through

**Files:**
- Modify: `lib/presentation/screens/spell_library_screen.dart`
- Test: `test/presentation/screens/spell_library_screen_test.dart`

**Interfaces:**
- Consumes: `SpellCard({..., List<String> problems = const []})` from Task 1; `ResolvedSpell.problems` (existing, `lib/models/resolved_spell.dart`).
- Produces: nothing further downstream — this is the last task that touches production code.

- [ ] **Step 1: Write the failing test**

Add the import to `test/presentation/screens/spell_library_screen_test.dart`, alongside the existing `package:eruditus/models/...` imports:

```dart
import 'package:eruditus/models/requisite.dart';
```

Add this test, after the `'shows each card\'s precomputed level from state.spellLevels'` test:

```dart
  testWidgets('threads ResolvedSpell.problems onto the rendered card', (tester) async {
    final record = Spell(
      id: 'flawed-1',
      name: 'Flawed Ward',
      baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      // A requisite naming the spell's own Technique is exactly what
      // validateSpellAgainstCatalog's check 3 rejects -- the simplest way to
      // get a genuinely non-empty ResolvedSpell.problems for this fixture.
      requisites: const {'Creo': RequisiteKind.adding},
      description: 'A test spell.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final flawed = ResolvedSpell(
        record: record, baseEffect: effect, range: rangeParam, duration: durationParam, target: targetParam);
    // Sanity check on the fixture itself, not the screen -- if this ever
    // fails, the fixture stopped producing a real problem and the test below
    // would pass for the wrong reason.
    expect(flawed.problems, isNotEmpty);

    await pumpScreen(
      tester,
      SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [flawed]),
    );

    expect(find.byKey(const Key('spell-card-invalid')), findsOneWidget);
    expect(find.byKey(const Key('needs-review-chip')), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/screens/spell_library_screen_test.dart`
Expected: FAIL — the new test's two `findsOneWidget` expectations fail (`findsNothing` instead), because `SpellLibraryScreen` doesn't pass `problems` to `SpellCard` yet.

- [ ] **Step 3: Implement**

In `lib/presentation/screens/spell_library_screen.dart`, change:

```dart
                    ...state.visibleSpells.map((s) => SpellCard(
                          entry: s,
                          level: state.spellLevels[s.id],
                          isRitual: state.ritualSpellIds.contains(s.id),
                        )),
```

to:

```dart
                    ...state.visibleSpells.map((s) => SpellCard(
                          entry: s,
                          level: state.spellLevels[s.id],
                          isRitual: state.ritualSpellIds.contains(s.id),
                          problems: s.problems,
                        )),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_library_screen_test.dart`
Expected: PASS — the new test and every pre-existing test in the file.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS — no other suite reads `SpellCard`'s spell-mapping call site, but this confirms nothing else broke.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/spell_library_screen.dart test/presentation/screens/spell_library_screen_test.dart
git commit -m "feat: wire ResolvedSpell.problems into the Library screen's spell cards

Completes todo item 40's last checkbox -- problems now reaches the UI
along the one call site that constructs a SpellCard from a ResolvedSpell.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Close out item 40 and section 0's bookkeeping in `todo.md`

**Files:**
- Modify: `.superpowers/todo.md`

**Interfaces:**
- Consumes: nothing from Tasks 1/2 except the fact that they're done.
- Produces: nothing — this is the terminal, documentation-only task.

**Note:** `.superpowers/todo.md` already has an uncommitted edit from an earlier review pass (section 0's status callout/table, added before this plan existed). This task's commit will include that pending edit too — do not `git stash`/discard it.

- [ ] **Step 1: Mark item 40's last checkbox done**

In `.superpowers/todo.md`, change:

```markdown
- [ ] **Surface `ResolvedSpell.problems` in the Library card — the "degrading"
      half of the blocking-vs-degrading decision has no UI yet.** Flagged by
      Part A's final whole-branch review (2026-08-09,
      `.superpowers/sdd/2026-08-09-spell-invariant-enforcement/final-review-report.md`,
      finding M4). The design doc named "Library renders an invalid card" as
      `problems`' consumer, but no task in the plan added that UI, so a spell
      that becomes invalid *after* being written (write-time blocking cannot
      cover this — only a later catalog change can) is currently invisible:
      `problems` is computed and correct but has no visible effect anywhere in
      the app. Not a defect in what shipped — a plan-scope gap worth tracking
      so it isn't silently dropped when Part B closes this item.
```

to:

```markdown
- [x] **Surface `ResolvedSpell.problems` in the Library card — the "degrading"
      half of the blocking-vs-degrading decision has no UI yet.** Flagged by
      Part A's final whole-branch review (2026-08-09,
      `.superpowers/sdd/2026-08-09-spell-invariant-enforcement/final-review-report.md`,
      finding M4). The design doc named "Library renders an invalid card" as
      `problems`' consumer, but no task in the plan added that UI, so a spell
      that becomes invalid *after* being written (write-time blocking cannot
      cover this — only a later catalog change can) was invisible: `problems`
      was computed and correct but had no visible effect anywhere in the app.
      **✅ DONE 2026-08-16** — `SpellCard` now takes a caller-supplied
      `problems` parameter (mirroring how `isRitual`/`isGeneral`/`rationale`
      are already precomputed by the caller) and renders a "Needs review"
      chip, an `(unverified)` level suffix, and the joined problem text when
      a resolved spell's `problems` is non-empty; `SpellLibraryScreen`'s
      spell-mapping call site is the one place that threads it through, from
      `ResolvedSpell.problems`. `ResolvedTemplate`/`ResolvedException` gaining
      the same getter is explicitly out of scope, unchanged by this fix. See
      `docs/superpowers/specs/2026-08-16-spell-card-problems-display-design.md`
      and `docs/superpowers/plans/2026-08-16-spell-card-problems-display.md`.
```

- [ ] **Step 2: Mark item 40's heading complete**

Change:

```markdown
### 40. Model Invariants Have Only One Enforcement Path
```

to:

```markdown
### 40. Model Invariants Have Only One Enforcement Path — ✅ COMPLETE (2026-08-16)
```

- [ ] **Step 3: Update section 0's status callout and table**

Change:

```markdown
**Status as of 2026-08-16: 2 of 5 rows fully done, 1 confirmed with no model
change needed, 2 still open.** Rows 2 and 4 (items 37/35 and 19) shipped; row 5's
**26** half is confirmed (no model change needed); still open: row 1's last
checkbox (item 40 — a UI consumer, not a model change), row 3 (item 13 — waits
on creation-screen input) and row 5's **14** half (still needs a rulebook
reading before its "no model change" question can even be answered).

Ordered. Each row says what it changes in the model.

| # | Item | Model change | Status |
|---|---|---|---|
| 1 | **40** | Give the non-prose invariants an enforcement home both construction paths share | Model/validation work done 2026-08-09; **one checkbox still open** — surfacing `problems` in the Library card has no UI consumer yet (confirmed: nothing under `lib/presentation` references `ResolvedSpell`) |
| 2 | **37** + **35** | One `choices` map vs. three more bespoke `chosen*` fields — the decision, then the implementation | ✅ DONE — 35 decided 2026-08-14, both of 37's parts shipped 2026-08-14/15 |
| 3 | **13** | Tighten `validateSpellProse` to user-created spells too (waits on the creation-screen input) | Not started — no summary/description input exists on the creation screen yet |
| 4 | **19** | `ModifierScope` gains a Target restriction — `modifier.dart`, same foundation | ✅ COMPLETE 2026-08-16 |
| 5 | **14**, **26** | Confirm *no* model change is needed, before anyone adds a field on assumption | **26**: confirmed, no model change needed (covered by item 24's adjustments instead). **14**: still open — the rulebook reading that would settle it hasn't been done |
```

to:

```markdown
**Status as of 2026-08-16: 3 of 5 rows fully done, 1 confirmed with no model
change needed, 1 still open.** Rows 1, 2 and 4 (items 40, 37/35 and 19)
shipped; row 5's **26** half is confirmed (no model change needed); still
open: row 3 (item 13 — waits on creation-screen input) and row 5's **14**
half (still needs a rulebook reading before its "no model change" question
can even be answered).

Ordered. Each row says what it changes in the model.

| # | Item | Model change | Status |
|---|---|---|---|
| 1 | **40** | Give the non-prose invariants an enforcement home both construction paths share | ✅ COMPLETE 2026-08-16 |
| 2 | **37** + **35** | One `choices` map vs. three more bespoke `chosen*` fields — the decision, then the implementation | ✅ DONE — 35 decided 2026-08-14, both of 37's parts shipped 2026-08-14/15 |
| 3 | **13** | Tighten `validateSpellProse` to user-created spells too (waits on the creation-screen input) | Not started — no summary/description input exists on the creation screen yet |
| 4 | **19** | `ModifierScope` gains a Target restriction — `modifier.dart`, same foundation | ✅ COMPLETE 2026-08-16 |
| 5 | **14**, **26** | Confirm *no* model change is needed, before anyone adds a field on assumption | **26**: confirmed, no model change needed (covered by item 24's adjustments instead). **14**: still open — the rulebook reading that would settle it hasn't been done |
```

- [ ] **Step 4: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close out todo item 40's Library-card checkbox

Item 40 is now fully complete -- see docs/superpowers/plans/2026-08-16-spell-card-problems-display.md.
Also folds in section 0's earlier pending status-table update.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
