# Text Provenance (item 79.3, plan B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app distinguish the rulebook's own words from ours wherever it renders prose, so it never silently attributes a paraphrase to the rulebook.

**Architecture:** `TextProvenance` and a `SourcedText` view type pair each user-facing string with whose words it is. Provenance is **derived, never stored** — one rule function reads the entry's existing `Provenance`, so no asset changes, no schema bump, and no duplication of data that already exists. A single widget implements the rendering rule, and a tripwire test fails when item 31 invalidates the rule for `Spell.summary`.

**Tech Stack:** Dart/Flutter, `flutter_test` unit and widget tests, gen-l10n ARB localisation.

**Spec:** `docs/superpowers/specs/2026-08-20-quoting-rules-text-design.md`, section 4. Sections 1-3 landed as plan A (merged, item 79.1/79.2 closed).

## Why this deviates from the spec, and what governs

**The spec says store a `SourcedText` on `BaseEffect.description`, `Spell.summary` and `Spell.description`, serialized with no bare-string fallback. This plan derives it instead.** The decision was taken with the human partner on 2026-08-21, after reconnaissance showed the spec's premise does not survive contact with the code:

- Provenance is computable from `Provenance.source` for every field the spec names. The spec argued item 31 breaks that; it does not — it changes the rule for `Spell.summary` from source-dependent to field-dependent, which is still a rule, not data.
- Storing it would persist, across 612 guidelines + 336 spells + 31 templates + 8 exceptions, a value computable from a field sitting beside it — what todo item 33 calls "write-only duplication: drift risk, no benefit", and what the 2026-07-27 provenance design rejected when it refused auto-derived summaries.
- **It would not pre-pay for the coming Spanish edition either.** `SourcedText` holds one string; guideline `cran-1` under two editions needs two, each cited to its own book. That is a per-edition collection, which item 86 must build regardless — so storing now costs two restructures instead of one.

**What is NOT deferred:** the vocabulary (`TextProvenance`), the rule, the rendering treatment, and the tests. Item 86 owns turning the field into a per-edition collection.

## Global Constraints

- **Never run `dart format`.** It is not clean in this repo. Hand-indent to match surrounding code and check with `git diff -w`.
- **`flutter analyze` must exit 0** at the end of every task.
- **Run `flutter pub get`** before analyze/test if `AppLocalizations` fails to resolve — `lib/l10n/app_localizations*.dart` is gitignored gen-l10n output.
- **If `flutter test` fails with a `sqlite3.dll` permissions error**, stale `flutter_tester` processes hold the file. Kill them and re-run.
- **No new pub dependencies.**
- **No asset changes and no database schema bump.** If you find yourself editing `assets/data/*.json`, `scripts/spell_import/`, or `app_database.dart`, stop and report — this plan derives provenance and touches none of them.
- **ARB key naming:** camelCase, prefixed by the concept. Every key this plan adds uses the `sourcedText` prefix. `@description` is mandatory on any key with a placeholder.
- **Licence and rulebook content never enters ARB** (DECISIONS.md, "Internationalisation"). The marker *label* is chrome and goes in ARB; the quoted text itself is content and does not.
- **The suite is at 818 tests, green.** Every task must leave it green, and the final total must be 818 plus exactly the tests the plan added — report both numbers rather than matching a prediction.

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/text_provenance.dart` | **New.** The `TextProvenance` enum, the `SourcedText` view type, and `sourcedFrom` — the one rule that maps an entry's `Provenance` to a string's provenance. No serialization: this type is built at read time, never persisted. |
| `lib/models/base_effect.dart` | Gains `sourcedDescription`, a one-line getter calling the rule. |
| `lib/models/spell.dart` | Gains `sourcedSummary` and `sourcedDescription`. |
| `lib/models/resolved_spell.dart` | Passes both through, as it already does for `summary`/`description`. |
| `lib/presentation/widgets/sourced_text_view.dart` | **New.** The rendering rule in one widget: quote styling plus a source marker for `verbatim`, plain body for `authored`, a translation marker for `translated`. |
| `lib/presentation/widgets/spell_card.dart` | Renders its blurb through the new widget. |
| `test/models/text_provenance_test.dart` | **New.** The rule table, and the verbatim-implies-citation invariant. |
| `test/models/summary_provenance_tripwire_test.dart` | **New.** Fails when item 31 lands, forcing the `Spell.sourcedSummary` rule to be revisited. |
| `test/presentation/widgets/sourced_text_view_test.dart` | **New.** The three treatments are visually distinct and the marker routes to About. |

---

### Task 1: `TextProvenance`, `SourcedText`, and the rule

Pure Dart with no Flutter and no consumers yet, so it can be tested in isolation.

**Files:**
- Create: `lib/models/text_provenance.dart`
- Test: `test/models/text_provenance_test.dart`

**Interfaces:**
- Consumes: `Provenance` and `PublicationSource` from `lib/models/provenance.dart` and `lib/models/publication_source.dart`; `Citation` from `lib/models/citation.dart`.
- Produces:
  - `enum TextProvenance { verbatim, authored, translated }`
  - `class SourcedText` with final fields `String text`, `TextProvenance provenance`, `List<Citation> citations`; const constructors `SourcedText.verbatim(String text, List<Citation> citations)`, `SourcedText.authored(String text)`, `SourcedText.translated(String text, List<Citation> citations)`; value equality on all three fields.
  - `SourcedText sourcedFrom(String text, Provenance provenance)`

- [ ] **Step 1: Write the failing test**

Create `test/models/text_provenance_test.dart`:

```dart
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/text_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const citation = Citation(bookId: 'arm5-core');

  group('sourcedFrom — the one rule', () {
    test('text on a published entry is the rulebook\'s own words', () {
      final result = sourcedFrom(
        'Give an animal a +1 bonus to Recovery rolls',
        Provenance(source: PublicationSource.published, citations: const [citation]),
      );

      expect(result.provenance, TextProvenance.verbatim);
      expect(result.text, 'Give an animal a +1 bonus to Recovery rolls');
      expect(result.citations, const [citation]);
    });

    test('text on a user-created entry is the user\'s own words', () {
      final result = sourcedFrom(
        'My homebrew guideline',
        Provenance(source: PublicationSource.userCreated),
      );

      expect(result.provenance, TextProvenance.authored);
      expect(result.citations, isEmpty);
    });

    test('it carries every citation through, not just the first', () {
      final result = sourcedFrom(
        'text',
        Provenance(source: PublicationSource.published, citations: const [
          Citation(bookId: 'arm5-core', page: 112),
          Citation(bookId: 'arm5-hohmc'),
        ]),
      );

      expect(result.citations, hasLength(2));
      expect(result.citations.last.bookId, 'arm5-hohmc');
    });
  });

  group('the verbatim-implies-citation invariant', () {
    test('a verbatim quote whose source cannot be named is rejected', () {
      expect(
        () => SourcedText.verbatim('text', const []),
        throwsA(isA<ArgumentError>()),
        reason: 'a quote we cannot attribute is a licence defect, not a '
            'display bug — see DECISIONS.md, "Licensing and attribution"',
      );
    });

    test('authored text carries no citations', () {
      expect(const SourcedText.authored('ours').citations, isEmpty);
    });

    test('a translation must still name what it was translated from', () {
      expect(
        () => SourcedText.translated('texto', const []),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        SourcedText.translated('texto', const [citation]).provenance,
        TextProvenance.translated,
      );
    });
  });

  group('value equality', () {
    test('two SourcedTexts with the same parts are equal', () {
      expect(
        SourcedText.verbatim('a', const [citation]),
        SourcedText.verbatim('a', const [citation]),
      );
    });

    test('same text, different provenance, is not equal', () {
      expect(
        SourcedText.verbatim('a', const [citation]),
        isNot(const SourcedText.authored('a')),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/text_provenance_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:eruditus/models/text_provenance.dart'".

- [ ] **Step 3: Write the implementation**

Create `lib/models/text_provenance.dart`:

```dart
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

/// Whose words a user-facing string is.
///
/// **Distinct from [Provenance], and deliberately so.** [Provenance] records
/// where an *entry* came from — a book, or the user. This records whose words
/// a particular *string on* that entry is. The two coincide today for every
/// field, which is why this is derived rather than stored (see
/// `sourcedFrom`), but they are not the same question and a future edition
/// will separate them.
enum TextProvenance {
  /// The published words of a cited edition — whichever edition, in whatever
  /// language. An officially published translation is Licensed Material in
  /// its own right, so quoting it is [verbatim] cited to *its* book, not
  /// [translated].
  verbatim,

  /// Our own prose, or the caster's. Not the rulebook's words, and must never
  /// be rendered as though it were.
  authored,

  /// A rendering *we* produced of someone else's words — the modification
  /// CC BY-SA 4.0 §3(a)(1)(B) obliges us to indicate.
  ///
  /// **Nothing in production yields this yet.** It is part of the vocabulary
  /// because items 82 (machine translation) and 86 (source editions) both
  /// need it, and because leaving it out would let the rendering rule ship
  /// without a branch for the case it exists to handle.
  translated,
}

/// A user-facing string together with whose words it is, and — when they are
/// not ours — where they came from.
///
/// A **view type**: built at read time by [sourcedFrom], never serialized.
/// See the plan's "Why this deviates from the spec" for why provenance is not
/// a stored field.
class SourcedText {
  final String text;
  final TextProvenance provenance;

  /// Where the words came from. Non-empty for [TextProvenance.verbatim] and
  /// [TextProvenance.translated]; empty for [TextProvenance.authored].
  final List<Citation> citations;

  const SourcedText._(this.text, this.provenance, this.citations);

  /// The published words of a cited edition.
  ///
  /// Throws if [citations] is empty: a quote whose source cannot be named
  /// cannot satisfy §3(a)(1)(A)(i), so it is a licence defect rather than a
  /// display bug and must fail loudly at construction.
  factory SourcedText.verbatim(String text, List<Citation> citations) {
    if (citations.isEmpty) {
      throw ArgumentError.value(
        citations,
        'citations',
        'SourcedText.verbatim: a quote must name the edition it came from',
      );
    }
    return SourcedText._(text, TextProvenance.verbatim, citations);
  }

  /// Our own prose, or the caster's.
  const SourcedText.authored(String text)
      : this._(text, TextProvenance.authored, const []);

  /// A rendering we produced of someone else's words.
  factory SourcedText.translated(String text, List<Citation> citations) {
    if (citations.isEmpty) {
      throw ArgumentError.value(
        citations,
        'citations',
        'SourcedText.translated: a translation must name its source',
      );
    }
    return SourcedText._(text, TextProvenance.translated, citations);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourcedText &&
          other.text == text &&
          other.provenance == provenance &&
          _sameCitations(other.citations, citations));

  static bool _sameCitations(List<Citation> a, List<Citation> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(text, provenance, Object.hashAll(citations));

  @override
  String toString() => 'SourcedText(${provenance.name}: "$text")';
}

/// The rule, in one place: a string on a published entry is that book's own
/// words; a string on a user-created entry is the user's.
///
/// **Derived, not stored.** Every field this is applied to today has a
/// provenance computable from the entry's own [Provenance], so storing it
/// would be the write-only duplication todo item 33 objects to. When a second
/// edition of one work exists (item 86), text becomes a per-edition
/// collection and each element names its own edition — that is the change
/// which makes a stored value earn its place, not this one.
///
/// **⚠️ `Spell.summary` is the field to watch.** It obeys this rule only
/// because `emit.py` currently derives summaries from descriptions, so a
/// published spell's summary really is a truncated quote. Item 31 replaces
/// them with ledger-*authored* prose, at which point `Spell.sourcedSummary`
/// must switch to [SourcedText.authored] unconditionally.
/// `test/models/summary_provenance_tripwire_test.dart` fails when that lands.
SourcedText sourcedFrom(String text, Provenance provenance) =>
    provenance.source == PublicationSource.published
        ? SourcedText.verbatim(text, provenance.citations)
        : SourcedText.authored(text);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/models/text_provenance_test.dart`
Expected: PASS. Report the number of tests.

- [ ] **Step 5: Check analyze and commit**

```bash
flutter analyze
git add lib/models/text_provenance.dart test/models/text_provenance_test.dart
git commit -m "feat: TextProvenance and SourcedText — whose words a string is

Derived from the entry's existing Provenance rather than stored: every
field it applies to today has a computable provenance, so a stored one
would be item 33's write-only duplication. Item 86's per-edition
collection is the change that makes storage earn its place.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Model getters, and the item 31 tripwire

**Files:**
- Modify: `lib/models/base_effect.dart`, `lib/models/spell.dart`, `lib/models/resolved_spell.dart`
- Test: `test/models/summary_provenance_tripwire_test.dart`, and additions to `test/models/text_provenance_test.dart`

**Interfaces:**
- Consumes: `sourcedFrom`, `SourcedText`, `TextProvenance` from Task 1.
- Produces:
  - `SourcedText BaseEffect.sourcedDescription`
  - `SourcedText? Spell.sourcedSummary` and `SourcedText? Spell.sourcedDescription` (null when the underlying string is null)
  - `SourcedText? ResolvedSpell.sourcedSummary` and `SourcedText? ResolvedSpell.sourcedDescription`, pass-throughs in the same shape as its existing `summary`/`description` getters at `lib/models/resolved_spell.dart:102-105`

- [ ] **Step 1: Write the failing tests**

Append to `test/models/text_provenance_test.dart`, inside `main()`:

```dart
  group('model getters apply the rule', () {
    test('a published guideline\'s description is verbatim, with its citation', () {
      final effect = BaseEffect(
        id: 'cran-1',
        technique: 'Creo',
        form: 'Animal',
        description: 'Give an animal a +1 bonus to Recovery rolls',
        baseLevel: 1,
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [citation],
        ),
      );

      expect(effect.sourcedDescription.provenance, TextProvenance.verbatim);
      expect(effect.sourcedDescription.citations, const [citation]);
    });

    test('a custom guideline\'s description is authored', () {
      final effect = BaseEffect(
        id: 'custom-1',
        technique: 'Creo',
        form: 'Animal',
        description: 'My homebrew guideline',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      expect(effect.sourcedDescription.provenance, TextProvenance.authored);
    });

    test('a null summary yields a null SourcedText, not an empty one', () {
      final spell = _spell(summary: null, description: 'text');

      expect(spell.sourcedSummary, isNull);
      expect(spell.sourcedDescription, isNotNull);
    });
  });
```

and add this helper above `main()`, plus the imports `package:eruditus/models/base_effect.dart` and `package:eruditus/models/spell.dart`:

```dart
/// A minimal published spell. Only the fields the provenance rule reads
/// matter here; the rest are the smallest values that satisfy Spell's own
/// invariants.
Spell _spell({required String? summary, required String? description}) => Spell(
      id: 'lib-test',
      name: 'Test Spell',
      baseEffectId: 'cran-1',
      technique: 'Creo',
      form: 'Animal',
      rangeId: 'range-touch',
      durationId: 'duration-moon',
      targetId: 'target-group',
      summary: summary,
      description: description,
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
```

If `Spell`'s constructor rejects this — for example because a required field is missing — read `lib/models/spell.dart`'s constructor and supply the smallest values that satisfy it. Do not weaken the model to fit the test.

Create `test/models/summary_provenance_tripwire_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A tripwire for todo item 31, not a test of behaviour anyone wrote.
///
/// `Spell.sourcedSummary` reports a published spell's summary as the
/// rulebook's own words. That is true only because `emit.py` currently builds
/// each summary by truncating the description — so the summary really is a
/// quote. Item 31 replaces them with **ledger-authored** prose, at which
/// point reporting them as verbatim would attribute our words to the
/// rulebook: exactly the failure item 79.3 exists to prevent.
///
/// When this test fails, the fix is NOT to change this file. It is to change
/// `Spell.sourcedSummary` in `lib/models/spell.dart` to return
/// `SourcedText.authored(summary)` unconditionally, and then delete this
/// test — its job is done.
void main() {
  test('every published summary is still derived from its description', () {
    final spells = (jsonDecode(
      File('assets/data/spell_library.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();

    expect(spells, isNotEmpty);

    final undermined = <String>[];
    for (final spell in spells) {
      final summary = spell['summary'] as String?;
      final description = spell['description'] as String?;
      if (summary == null || description == null) continue;

      // emit.py truncates the description and appends " Level N.", so the
      // summary's opening is a prefix of the description's.
      final opening = summary.length < 60 ? summary : summary.substring(0, 60);
      if (!description.startsWith(opening)) undermined.add(spell['id'] as String);
    }

    expect(undermined, isEmpty,
        reason: 'Item 31 has landed: these summaries are no longer quotes of '
            'their descriptions. Change Spell.sourcedSummary to return '
            'SourcedText.authored(summary) unconditionally, then delete this '
            'test. Spells: ${undermined.take(5).join(', ')}');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/text_provenance_test.dart test/models/summary_provenance_tripwire_test.dart`
Expected: the `text_provenance_test.dart` additions FAIL with "The getter 'sourcedDescription' isn't defined for the class 'BaseEffect'". The tripwire test should **PASS** on first run — it asserts a fact about today's assets that is currently true. That is its purpose; note it and continue.

- [ ] **Step 3: Add the getters**

In `lib/models/base_effect.dart`, add the import `import 'package:eruditus/models/text_provenance.dart';` and this getter to the `BaseEffect` class, after the `openSlots` field declaration:

```dart
  /// [description] together with whose words it is — the rulebook's, for a
  /// published guideline; the user's, for one they wrote. See `sourcedFrom`.
  SourcedText get sourcedDescription => sourcedFrom(description, provenance);
```

In `lib/models/spell.dart`, add the same import and these getters to the `Spell` class, after the `updatedAt` field declaration:

```dart
  /// [summary] together with whose words it is, or null when there is none.
  ///
  /// **⚠️ Reports a published spell's summary as verbatim, which is true only
  /// until item 31 lands** — see `sourcedFrom` and
  /// `test/models/summary_provenance_tripwire_test.dart`.
  SourcedText? get sourcedSummary =>
      summary == null ? null : sourcedFrom(summary!, provenance);

  /// [description] together with whose words it is, or null when there is
  /// none. Unlike [sourcedSummary] this one is stable: a published spell's
  /// description is the book's prose and item 31 does not touch it.
  SourcedText? get sourcedDescription =>
      description == null ? null : sourcedFrom(description!, provenance);
```

In `lib/models/resolved_spell.dart`, add the same import and these pass-throughs immediately after the existing `description` getter at line 105:

```dart
  SourcedText? get sourcedSummary => record.sourcedSummary;
  SourcedText? get sourcedDescription => record.sourcedDescription;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/text_provenance_test.dart test/models/summary_provenance_tripwire_test.dart`
Expected: PASS, both files.

- [ ] **Step 5: Check analyze and commit**

```bash
flutter analyze
git add lib/models/base_effect.dart lib/models/spell.dart lib/models/resolved_spell.dart test/models/text_provenance_test.dart test/models/summary_provenance_tripwire_test.dart
git commit -m "feat: sourced text getters on BaseEffect, Spell and ResolvedSpell

Plus a tripwire for item 31: a published spell's summary is a quote only
because emit.py truncates the description to build it. When item 31's
ledger-authored summaries land, the tripwire fails and names the fix.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: The rendering rule, in one widget

**Files:**
- Create: `lib/presentation/widgets/sourced_text_view.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_en_XA.arb`
- Test: `test/presentation/widgets/sourced_text_view_test.dart`

**Interfaces:**
- Consumes: `SourcedText`, `TextProvenance` from Task 1; `AboutScreen` from `lib/presentation/screens/about_screen.dart` (a `StatelessWidget` with `const AboutScreen({super.key})`); `pumpApp` from `test/support/pump_app.dart`.
- Produces: `class SourcedTextView extends StatelessWidget` with
  `const SourcedTextView(this.sourced, {super.key, this.style, this.maxLines, this.overflow, this.showMarker = true})`
  — `sourced` a `SourcedText`, `style` a `TextStyle?`, `maxLines` an `int?`, `overflow` a `TextOverflow?`, `showMarker` a `bool`.
  **`maxLines`/`overflow` exist because `spell_card.dart:170` truncates its blurb to two lines with an ellipsis, and Task 4 must not silently drop that.**
  **`showMarker: false` exists because the card is itself tappable** — an `InkWell` marker nested inside `ListTile.onTap` gives two competing tap targets in a list row. The quote styling still distinguishes the text; the notice stays reachable from Settings, which is what §3(a)(2) actually requires.

- [ ] **Step 1: Add the ARB chrome keys**

Add to `lib/l10n/app_en.arb`, at the end of the object. Neither key takes a placeholder, so neither needs an `@description`.

```json
  "sourcedTextRulebookMarker": "Rulebook",
  "sourcedTextMachineTranslated": "Machine translation",
```

**The marker names no book and no page deliberately.** The spec records that "the source marker on a quote *is* the page-reference affordance — one control, not two", and item 78 is what supplies book abbreviations and page numbers. Enriching the marker is that item's job, not this one's.

- [ ] **Step 2: Regenerate the pseudo-locale ARB and codegen**

```bash
dart run tool/gen_pseudo_arb.dart
flutter pub get
```

Run: `flutter test test/l10n/pseudo_arb_sync_test.dart`
Expected: PASS.

- [ ] **Step 3: Write the failing test**

Create `test/presentation/widgets/sourced_text_view_test.dart`:

```dart
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/text_provenance.dart';
import 'package:eruditus/presentation/screens/about_screen.dart';
import 'package:eruditus/presentation/widgets/sourced_text_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  const citation = Citation(bookId: 'arm5-core');
  final quoted = SourcedText.verbatim('The rulebook says this.', const [citation]);
  const ours = SourcedText.authored('We say this.');

  testWidgets('a quote renders its text and a source marker', (tester) async {
    await pumpApp(tester, SourcedTextView(quoted));

    expect(find.text('The rulebook says this.'), findsOneWidget);
    expect(find.byKey(const Key('sourced-text-marker')), findsOneWidget);
  });

  testWidgets('our own words render with no marker', (tester) async {
    await pumpApp(tester, const SourcedTextView(ours));

    expect(find.text('We say this.'), findsOneWidget);
    expect(find.byKey(const Key('sourced-text-marker')), findsNothing,
        reason: 'a marker on our own prose would attribute it to the rulebook '
            '— the exact failure item 79.3 exists to prevent');
  });

  testWidgets('a quote is visually distinct from our own words', (tester) async {
    await pumpApp(tester, SourcedTextView(quoted));
    final quotedDecoration = tester
        .widget<Container>(find.byKey(const Key('sourced-text-quote')))
        .decoration;

    expect(quotedDecoration, isNotNull,
        reason: 'verbatim text must carry a visible treatment our own prose '
            'does not, or the two are indistinguishable on screen');

    await pumpApp(tester, const SourcedTextView(ours));
    expect(find.byKey(const Key('sourced-text-quote')), findsNothing);
  });

  testWidgets('tapping the marker opens the About screen', (tester) async {
    await pumpApp(tester, SourcedTextView(quoted));

    await tester.tap(find.byKey(const Key('sourced-text-marker')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget,
        reason: '§3(a)(2) is satisfied by routing to one resource that '
            'carries the notice, so the marker must actually get there');
  });

  testWidgets('a translation is marked as ours, not as the rulebook\'s words',
      (tester) async {
    await pumpApp(
      tester,
      SourcedTextView(SourcedText.translated('El libro dice esto.', const [citation])),
    );

    expect(find.text('El libro dice esto.'), findsOneWidget);
    expect(find.byKey(const Key('sourced-text-translated-marker')), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/presentation/widgets/sourced_text_view_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:eruditus/presentation/widgets/sourced_text_view.dart'".

- [ ] **Step 5: Write the implementation**

Create `lib/presentation/widgets/sourced_text_view.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/models/text_provenance.dart';
import 'package:eruditus/presentation/screens/about_screen.dart';

/// Renders a [SourcedText] so the rulebook's words are never mistaken for
/// ours, nor ours for the rulebook's.
///
/// **This is the single place the rendering rule lives.** Item 79.3's whole
/// point is that a quote must be distinguishable from a paraphrase on screen;
/// scattering that treatment across call sites is how it stops being true.
///
/// The marker names no book and no page: §3(a)(2) is satisfied by routing to
/// one resource carrying the notice, and item 78 is what will enrich this
/// same control with a book abbreviation and page reference.
class SourcedTextView extends StatelessWidget {
  final SourcedText sourced;
  final TextStyle? style;

  /// Forwarded to the rendered [Text]. `spell_card.dart` truncates its blurb
  /// to two lines; dropping that on the way through here would silently
  /// change a list row's height.
  final int? maxLines;
  final TextOverflow? overflow;

  /// Whether to render the tappable source marker.
  ///
  /// False inside an already-tappable container — a `ListTile.onTap` row, for
  /// instance — where a nested [InkWell] would compete for the same gesture.
  /// The quote styling still marks the text as a quote; §3(a)(2) is satisfied
  /// by the About screen being reachable, not by every quote linking to it.
  final bool showMarker;

  const SourcedTextView(
    this.sourced, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.showMarker = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final body = style ?? theme.textTheme.bodyMedium;

    switch (sourced.provenance) {
      case TextProvenance.authored:
        return Text(
          sourced.text,
          style: body,
          maxLines: maxLines,
          overflow: overflow,
        );

      case TextProvenance.verbatim:
        return Container(
          key: const Key('sourced-text-quote'),
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sourced.text,
                style: body?.copyWith(fontStyle: FontStyle.italic),
                maxLines: maxLines,
                overflow: overflow,
              ),
              if (showMarker) ...[
                const SizedBox(height: 4),
                _Marker(
                  key: const Key('sourced-text-marker'),
                  label: l10n.sourcedTextRulebookMarker,
                ),
              ],
            ],
          ),
        );

      case TextProvenance.translated:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sourced.text,
              style: body,
              maxLines: maxLines,
              overflow: overflow,
            ),
            const SizedBox(height: 4),
            _Marker(
              key: const Key('sourced-text-translated-marker'),
              label: l10n.sourcedTextMachineTranslated,
            ),
          ],
        );
    }
  }
}

/// The tappable source marker: a route to the §3(a) notice, not a decoration.
class _Marker extends StatelessWidget {
  final String label;

  const _Marker({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/presentation/widgets/sourced_text_view_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 7: Check analyze and commit**

```bash
flutter analyze
git add lib/presentation/widgets/sourced_text_view.dart lib/l10n/app_en.arb lib/l10n/app_en_XA.arb test/presentation/widgets/sourced_text_view_test.dart
git commit -m "feat: SourcedTextView — the quote/paraphrase rendering rule

One widget, so the distinction cannot quietly stop being true at one
call site. The marker routes to the About screen, which §3(a)(2) permits;
naming the book and page is item 78's job on this same control.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Apply it where prose renders today

**Files:**
- Modify: `lib/presentation/widgets/spell_card.dart:97-105`
- Modify: `test/l10n/pseudo_locale_coverage_test.dart`
- Test: `test/presentation/widgets/spell_card_test.dart` (exists; reuse its `buildSpell` helper)

**Interfaces:**
- Consumes: `SourcedTextView` from Task 3; `ResolvedSpell.sourcedSummary`/`sourcedDescription` from Task 2.
- Produces: nothing further tasks depend on. This is the last task.

- [ ] **Step 1: Write the failing test**

`test/presentation/widgets/spell_card_test.dart` already exists and already has the helper you need: `buildSpell({String? name, PublicationSource source = PublicationSource.published, String? summary, String? description})`, which returns a `ResolvedSpell` and sets a `Citation(bookId: 'arm5-core')` for published spells and no citations for user-created ones. Use it; do not write a second builder.

Add these tests to that file, following the `pumpApp(tester, SpellCard(entry: ..., level: ...))` shape the existing tests use:

```dart
  testWidgets('a published spell's blurb renders as a quote', (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(name: 'Pillar of Fire', summary: 'The rulebook says this.'),
      level: 25,
    ));

    expect(find.byKey(const Key('sourced-text-quote')), findsOneWidget,
        reason: 'a published spell's prose is the book's own words');
  });

  testWidgets('a user-created spell's blurb renders as plain prose', (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(
          name: 'My Fireball',
          source: PublicationSource.userCreated,
          summary: 'My own spell idea.'),
    ));

    expect(find.text('My own spell idea.'), findsOneWidget);
    expect(find.byKey(const Key('sourced-text-quote')), findsNothing,
        reason: 'quote styling on the caster's own words would attribute '
            'them to the rulebook');
  });

  testWidgets('the card's blurb carries no competing tap target', (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(name: 'Pillar of Fire', summary: 'The rulebook says this.'),
      level: 25,
    ));

    expect(find.byKey(const Key('sourced-text-marker')), findsNothing,
        reason: 'the card is itself tappable; a nested InkWell would give a '
            'list row two competing gestures');
  });

  testWidgets('the blurb is still truncated to two lines', (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(name: 'Pillar of Fire', summary: 'The rulebook says this.'),
      level: 25,
    ));

    final text = tester.widget<Text>(find.text('The rulebook says this.'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });
```

You will need `import 'package:eruditus/models/text_provenance.dart';` only if you reference the type directly; the tests above go through keys, so the existing imports may suffice.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: FAIL — the quote key is not found, because the card still renders a plain `Text`.

- [ ] **Step 3: Render the blurb through the widget**

In `lib/presentation/widgets/spell_card.dart`, add the import:

```dart
import 'package:eruditus/presentation/widgets/sourced_text_view.dart';
```

**Edit 1 — the blurb selection, currently lines 103-105.** The existing comment about empty-string summaries is still correct and must be preserved verbatim; only the two `final` lines change type, from `String?` to `SourcedText?`:

```dart
    final summary = entry.summary;
    final blurb = (summary != null && summary.trim().isNotEmpty)
        ? entry.sourcedSummary
        : entry.sourcedDescription;
    final hasBlurb = blurb != null && blurb.text.isNotEmpty;
```

Also update the comment two lines above it, which currently reads "Prefer the paraphrase; fall back to the verbatim rulebook text." That is inaccurate today — both are the book's own words for a published spell — so replace that one line with:

```dart
    // Prefer the summary; fall back to the description. Both are the book's
    // own words for a published spell today; item 31 is what makes the
    // summary a real paraphrase. See sourcedFrom.
```

**Edit 2 — the render site, currently line 170**, which reads:

```dart
                  Text(blurb, maxLines: 2, overflow: TextOverflow.ellipsis),
```

Replace it with:

```dart
                  SourcedTextView(
                    blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // The card is already tappable; a marker here would be a
                    // second gesture target inside one list row.
                    showMarker: false,
                  ),
```

Both `maxLines: 2` and `overflow` must be carried across — dropping them changes every list row's height.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Extend the pseudo-locale guard**

In `test/l10n/pseudo_locale_coverage_test.dart`, append the two new chrome strings to the existing `const _mustNotSurvive` list:

```dart
  // Item 79.3's source markers. Chrome — the quoted text they mark is not.
  'Rulebook',
  'Machine translation',
```

**Do not add any quoted rulebook text to that list.** Rulebook content is a deliberately-English population, the same status as the four realm values the file's own comment warns about; listing it would fail the test on correct code.

- [ ] **Step 6: Run the full suite**

```bash
flutter pub get
flutter analyze
flutter test
```

Expected: analyze exits 0; all tests pass. The total must be **818 plus exactly the tests this plan added**. Report both numbers and the arithmetic. A total that does not reconcile means a test was lost — investigate rather than accepting it.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/widgets/spell_card.dart test/presentation/widgets/spell_card_test.dart test/l10n/pseudo_locale_coverage_test.dart
git commit -m "feat: render spell-card blurbs through SourcedTextView

A published spell's blurb is the rulebook's prose and now reads as a
quote with a route to the notice; a caster's own words render plain.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## After the plan

Not part of any task, and not for a task implementer to do:

- **Close todo item 79.3** in `.superpowers/themes/app.md`, which closes item 79 entirely — so this time the body moves to `ARCHIVE.md` and the index row flips to `closed`. Use the `closing-an-item` skill; the constraints to extract include the derive-don't-store decision and its reasoning, the `SourcedTextView`-is-the-only-renderer rule, and the item 31 tripwire's existence.
- **Update `.superpowers/STATUS.md`** with the new Dart test count.
- **Note the coupling in item 31's body**: landing it requires flipping `Spell.sourcedSummary` to `authored` and deleting the tripwire test.
- **Note in item 56's body** that `SourcedTextView` is the affordance its hints should render through.
