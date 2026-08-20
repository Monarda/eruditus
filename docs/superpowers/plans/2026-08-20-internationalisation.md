# Internationalisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up Flutter's l10n pipeline, migrate every user-facing string into ARB, and stop the engine composing display prose — so adding a language later is translation work, not a rewrite.

**Architecture:** `gen-l10n` generates `AppLocalizations` from `lib/l10n/app_en.arb`. The engine stops returning `String` labels and returns a sealed `ContributionSource` hierarchy plus a `LevelUnavailableReason` enum; a presentation-layer formatter turns those into localised text. A generated pseudo-locale (`xx`) proves, mechanically, that no string was missed.

**Tech Stack:** Flutter 3.44.8, Dart SDK `^3.12.2`, `flutter_localizations` (SDK), `intl`, `flutter_bloc` 9, `equatable`, `bloc_test`/`mocktail`.

## Global Constraints

- **Never run `dart format`.** It is not clean in this repo. Hand-indent to match surrounding code and verify with `git diff -w`.
- **`flutter analyze` must end at exit 0.** Not "only pre-existing warnings" — zero.
- **The Dart test count must never fall.** Baseline is **745 passing**. Assertions are rewritten, never deleted.
- Other suites must stay green: Python `python -m unittest discover -s scripts/spell_import/tests -t .` (**397**), and `flutter test integration_test -d windows` (**8**).
- **If `flutter test` reports a sqlite3.dll permissions error**, it is stale `flutter_tester` processes holding a lock, not a real permissions problem. Kill them and re-run.
- **If working in a git worktree, set `ARS_RULEBOOK_ROOT`** or ~35 phantom rulebook-path test errors appear.
- **Three text populations** (from the spec) govern every decision below: **app chrome** → ARB; **rulebook content** (parameter names, effect descriptions, modifier labels) → stays catalog data, never ARB; **user content** (adjustment notes, spell names the user typed) → verbatim, never ARB, never pseudo-transformed.
- Latin is **not** part of this work. It is item 81.
- **Translation provenance (item 82): mark non-template locales only.** `gen-l10n` accepts custom ARB metadata — verified against Flutter 3.44.8, exit 0 and no warnings, at file level (`@@x-translation-status`), per string (inside a `@key` block), and per string overriding a file-level default. The only non-template locale in this pass is the generated `app_xx.arb`, which Task 3 marks `generated`. **Do not add a `"x-translation-status": "original"` attribute to `app_en.arb` entries** — the template file is the original by definition (`l10n.yaml` declares `template-arb-file: app_en.arb`), so the value is derivable, and storing it anyway would force a `@key` block onto ~115 strings that need none.

---

### Task 1: Stand up the l10n toolchain

**Files:**
- Modify: `pubspec.yaml`
- Create: `l10n.yaml`
- Create: `lib/l10n/app_en.arb`
- Modify: `lib/main.dart:111` (the `MaterialApp`)
- Test: `test/l10n/localization_wiring_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AppLocalizations` (generated, importable as `package:eruditus/l10n/app_localizations.dart`), with getters `spellLevel`, `showBreakdown`, `hideBreakdown`. The `AppLocalizations.localizationsDelegates` and `AppLocalizations.supportedLocales` statics used by every later task.

- [ ] **Step 1: Verify which pseudo-locale code the toolchain accepts**

The spec names `xx` with `en_XA` as fallback. Settle it now — the filename, `supportedLocales`, and every later locale-switching test depend on it.

Create `lib/l10n/app_xx.arb` containing `{"@@locale": "xx", "spellLevel": "test"}`, run `flutter gen-l10n`, and check it is accepted without error. If it errors, delete it, use `app_en_XA.arb` with `"@@locale": "en_XA"` instead, and **substitute `en_XA` for `xx` everywhere in this plan**. Record which one won in the commit message.

- [ ] **Step 2: Add dependencies and enable generation**

In `pubspec.yaml`, under `dependencies:` (alongside the existing `flutter:` entry):

```yaml
  flutter_localizations:
    sdk: flutter
  intl: any
```

`intl: any` lets the Flutter SDK pin the version it wants; a hard pin here fights the SDK constraint.

Under the existing `flutter:` section, add:

```yaml
  generate: true
```

- [ ] **Step 3: Create `l10n.yaml` at the repo root**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

`nullable-getter: false` makes a missing `Localizations` ancestor fail loudly at the call site instead of silently short-circuiting through `?.`.

- [ ] **Step 4: Create `lib/l10n/app_en.arb` with the level-banner strings**

These three are the smallest real slice that proves wiring. They come from `level_banner.dart:78,90`.

```json
{
  "@@locale": "en",
  "spellLevel": "Spell level",
  "@spellLevel": {
    "description": "Heading above the calculated level number"
  },
  "showBreakdown": "Show the breakdown",
  "@showBreakdown": {
    "description": "Tooltip on the control that expands the level breakdown"
  },
  "hideBreakdown": "Hide the breakdown",
  "@hideBreakdown": {
    "description": "Tooltip on the control that collapses the level breakdown"
  }
}
```

- [ ] **Step 5: Write the failing test**

Create `test/l10n/localization_wiring_test.dart`:

```dart
import 'package:eruditus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppLocalizations resolves under the English locale', (tester) async {
    late AppLocalizations l10n;

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(l10n.spellLevel, 'Spell level');
  });
}
```

- [ ] **Step 6: Run it and confirm it fails**

Run: `flutter test test/l10n/localization_wiring_test.dart`
Expected: FAIL — `app_localizations.dart` does not exist yet (`Target of URI doesn't exist`).

- [ ] **Step 7: Generate and wire `MaterialApp`**

Run `flutter pub get` (which triggers generation), then in `lib/main.dart` add the import:

```dart
import 'package:eruditus/l10n/app_localizations.dart';
```

and extend the `MaterialApp` at `lib/main.dart:111`:

```dart
    return MaterialApp(
      title: 'Eruditus',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
```

`title: 'Eruditus'` deliberately stays a literal — it is the product name, not chrome.

- [ ] **Step 8: Run the test and the full suite**

Run: `flutter test test/l10n/localization_wiring_test.dart` → PASS
Run: `flutter test` → 746 passing (745 + 1)
Run: `flutter analyze` → exit 0

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml lib/l10n/app_en.arb lib/main.dart test/l10n/localization_wiring_test.dart
git commit -m "feat(l10n): stand up gen-l10n pipeline with the level-banner strings"
```

---

### Task 2: `pumpApp` test harness

**Files:**
- Create: `test/support/pump_app.dart`
- Modify: the 10 test files holding 47 inline `MaterialApp(` constructions
- Test: `test/support/pump_app_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations.localizationsDelegates`, `AppLocalizations.supportedLocales` (Task 1).
- Produces: `Future<void> pumpApp(WidgetTester tester, Widget child, {Locale locale = const Locale('en'), List<SingleChildWidget> providers = const []})`. Every later widget test uses this instead of building its own `MaterialApp`.

Every widget that calls `AppLocalizations.of(context)` needs a `Localizations` ancestor. There are 47 inline `MaterialApp(` constructions across 10 test files and no shared helper — each file reinvents a private `pump` (see `level_banner_test.dart:24`). Without this helper the pseudo-locale switch in Task 3 has nowhere to be applied.

- [ ] **Step 1: Write the failing test**

Create `test/support/pump_app_test.dart`:

```dart
import 'package:eruditus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  testWidgets('pumpApp provides Localizations to its child', (tester) async {
    await pumpApp(
      tester,
      Builder(builder: (context) => Text(AppLocalizations.of(context).spellLevel)),
    );

    expect(find.text('Spell level'), findsOneWidget);
  });

  testWidgets('pumpApp honours an explicit locale', (tester) async {
    await pumpApp(
      tester,
      Builder(builder: (context) => Text(Localizations.localeOf(context).toString())),
      locale: const Locale('xx'),
    );

    expect(find.text('xx'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/support/pump_app_test.dart`
Expected: FAIL — `pump_app.dart` does not exist.

- [ ] **Step 3: Implement the helper**

Create `test/support/pump_app.dart`:

```dart
import 'package:eruditus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

/// Pumps [child] inside a MaterialApp carrying the localisation delegates.
///
/// Every widget test goes through this rather than building its own
/// MaterialApp: a widget that reads AppLocalizations needs a Localizations
/// ancestor, and [locale] is the seam the pseudo-locale coverage test uses to
/// re-run a screen under `xx`.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  List<SingleChildWidget> providers = const [],
}) {
  final body = providers.isEmpty
      ? child
      : MultiBlocProvider(providers: providers, child: child);

  return tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: body),
  ));
}
```

`SingleChildWidget` is `provider`'s type, re-exported through `flutter_bloc`; import it from `package:flutter_bloc/flutter_bloc.dart` instead if the direct `provider` import is not already a dependency.

Note `home: Scaffold(body: ...)` — most existing per-file helpers already wrap in a `Scaffold` (e.g. `level_banner_test.dart:24`). Tests that pump a full screen widget which supplies its *own* `Scaffold` will now nest two. That is harmless for layout but check the affected screen tests still pass; if one breaks, give `pumpApp` a `wrapInScaffold: true` default and pass `false` from that test.

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/support/pump_app_test.dart` → PASS

- [ ] **Step 5: Migrate the 47 call sites**

Find them: `grep -rn 'MaterialApp(' test integration_test`

Replace each inline construction with a `pumpApp` call. Example, `level_banner_test.dart:24`:

```dart
// before
await tester.pumpWidget(MaterialApp(home: Scaffold(body: banner)));

// after
await pumpApp(tester, banner);
```

Delete each file's now-unused private `pump` helper. Where a test supplies bloc providers, pass them through `providers:` rather than nesting a `MultiBlocProvider` by hand.

- [ ] **Step 6: Run the full suite**

Run: `flutter test` → 748 passing (746 + 2)
Run: `flutter analyze` → exit 0
Run: `git diff -w --stat` to confirm no whitespace-only churn crept in.

- [ ] **Step 7: Commit**

```bash
git add test/support/pump_app.dart test/support/pump_app_test.dart test integration_test
git commit -m "test: add pumpApp helper and route all widget tests through it"
```

---

### Task 3: Generated pseudo-locale and its sync test

**Files:**
- Create: `tool/gen_pseudo_arb.dart`
- Create: `lib/l10n/app_xx.arb` (generated output, committed)
- Test: `test/l10n/pseudo_arb_sync_test.dart`

**Interfaces:**
- Consumes: `lib/l10n/app_en.arb` (Task 1).
- Produces: `String pseudoTransform(String value)` exported from `tool/gen_pseudo_arb.dart`, and the committed `app_xx.arb`. Task 11's coverage test relies on the transform being total and on placeholders surviving it.

A hand-written pseudo ARB drifts from `app_en.arb` the first time someone adds a string, and a drifted proof harness is worse than none. This mirrors the repo's existing regeneration-test idiom for `spell_library.json` (item 30).

- [ ] **Step 1: Write the failing test**

Create `test/l10n/pseudo_arb_sync_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_pseudo_arb.dart';

void main() {
  test('pseudoTransform accents letters and pads length', () {
    final result = pseudoTransform('Calculate');

    expect(result.startsWith('['), isTrue);
    expect(result.endsWith(']'), isTrue);
    expect(result.contains('Calculate'), isFalse,
        reason: 'every ASCII letter should have been accented');
    expect(result.length, greaterThan('Calculate'.length * 1.3));
  });

  test('pseudoTransform leaves ICU placeholders untouched', () {
    final result = pseudoTransform('Imported {count} spells');

    expect(result.contains('{count}'), isTrue);
  });

  test('the generated locale is marked as machine-produced', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;

    final produced = jsonDecode(generatePseudoArb(en)) as Map<String, dynamic>;

    expect(produced['@@x-translation-status'], 'generated',
        reason: 'item 82 — an unmarked generated locale pollutes the '
            'translation burn-down with entries nobody will ever review');
  });

  test('app_xx.arb is exactly what the generator produces', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    final committed = File('lib/l10n/app_xx.arb').readAsStringSync();

    expect(committed, generatePseudoArb(en),
        reason: 'app_xx.arb is stale — run: dart run tool/gen_pseudo_arb.dart');
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/l10n/pseudo_arb_sync_test.dart`
Expected: FAIL — `gen_pseudo_arb.dart` does not exist.

- [ ] **Step 3: Implement the generator**

Create `tool/gen_pseudo_arb.dart`:

```dart
import 'dart:convert';
import 'dart:io';

const _accents = {
  'a': 'а', 'c': 'ć', 'e': 'ē', 'g': 'ģ', 'i': 'ĭ', 'l': 'ĺ', 'n': 'ň',
  'o': 'ō', 'r': 'ŕ', 's': 'ś', 't': 'ţ', 'u': 'ű', 'z': 'ź',
  'A': 'Å', 'C': 'Ĉ', 'E': 'Ē', 'G': 'Ĝ', 'I': 'Ĭ', 'L': 'Ĺ', 'N': 'Ň',
  'O': 'Ō', 'R': 'Ŕ', 'S': 'Ś', 'T': 'Ţ', 'U': 'Ű', 'Z': 'Ź',
};

/// Accents [value]'s letters and pads it ~30%, leaving `{placeholders}` alone.
///
/// A string that still renders as plain ASCII under locale `xx` never reached
/// the ARB. The padding surfaces truncation, which is the evidence items 16
/// and 58 have both been waiting on.
String pseudoTransform(String value) {
  final buffer = StringBuffer('[');
  var inPlaceholder = false;

  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (char == '{') inPlaceholder = true;
    if (char == '}') {
      inPlaceholder = false;
      buffer.write(char);
      continue;
    }
    buffer.write(inPlaceholder ? char : (_accents[char] ?? char));
  }

  final padding = '·' * (value.length * 0.3).ceil();
  return '$buffer$padding]';
}

/// Renders a complete `app_xx.arb` from a decoded `app_en.arb`.
///
/// Metadata keys (`@@locale`, and every `@key` description block) are dropped:
/// gen-l10n takes placeholder metadata from the template file only.
///
/// `@@x-translation-status: generated` marks the whole file as machine-produced
/// and never reviewable (item 82). Without it these entries would sit in any
/// future translation burn-down forever, since nobody will ever human-review a
/// pseudo-locale. gen-l10n tolerates the custom attribute — verified against
/// Flutter 3.44.8, exit 0, no warnings.
String generatePseudoArb(Map<String, dynamic> en) {
  final out = <String, dynamic>{
    '@@locale': 'xx',
    '@@x-translation-status': 'generated',
  };

  for (final entry in en.entries) {
    if (entry.key.startsWith('@')) continue;
    out[entry.key] = pseudoTransform(entry.value as String);
  }

  return '${const JsonEncoder.withIndent('  ').convert(out)}\n';
}

void main() {
  final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
      as Map<String, dynamic>;
  File('lib/l10n/app_xx.arb').writeAsStringSync(generatePseudoArb(en));
  stdout.writeln('wrote lib/l10n/app_xx.arb');
}
```

- [ ] **Step 4: Generate the file and run the test**

Run: `dart run tool/gen_pseudo_arb.dart`
Run: `flutter test test/l10n/pseudo_arb_sync_test.dart` → PASS
Run: `flutter pub get` to regenerate `AppLocalizations` with the new locale.

- [ ] **Step 5: Confirm the locale resolves end to end**

Add to `test/l10n/pseudo_arb_sync_test.dart`:

```dart
  testWidgets('the xx locale returns transformed strings', (tester) async {
    late AppLocalizations l10n;

    await pumpApp(
      tester,
      Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const SizedBox.shrink();
      }),
      locale: const Locale('xx'),
    );

    expect(l10n.spellLevel, isNot('Spell level'));
    expect(l10n.spellLevel.startsWith('['), isTrue);
  });
```

Add the imports it needs (`app_localizations.dart`, `../support/pump_app.dart`).

Run: `flutter test test/l10n/pseudo_arb_sync_test.dart` → PASS

- [ ] **Step 6: Commit**

```bash
git add tool/gen_pseudo_arb.dart lib/l10n/app_xx.arb test/l10n/pseudo_arb_sync_test.dart
git commit -m "test(l10n): add generated pseudo-locale and its regeneration guard"
```

---

### Task 4: `ContributionSource` — the engine stops composing prose

**Files:**
- Create: `lib/engine/contribution_source.dart`
- Modify: `lib/engine/level_breakdown.dart:6-20` (`LevelContribution`)
- Modify: `lib/engine/spell_engine.dart:235-270` and `:311-328` (7 composition sites)
- Test: `test/engine/spell_engine_test.dart`, `test/engine/level_breakdown_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks — this is pure structure, no l10n involved.
- Produces: `sealed class ContributionSource` with variants `BaseEffectContribution(String description)`, `SlotContribution({ParameterSlot slot, String actualName, String? referenceName})`, `RequisiteContribution({String art, String parameterName})`, `AdjustmentContribution(String note)`, `ModifierContribution({String modifierName, String optionLabel})`; `enum ParameterSlot { range, duration, target }`; and `LevelContribution({required ContributionSource source, required int magnitude, bool isBase})`. Task 6's formatter switches over exactly these.

- [ ] **Step 1: Write the failing test**

Add to `test/engine/level_breakdown_test.dart`:

```dart
  test('LevelContribution compares equal by its structured source', () {
    const a = LevelContribution(
      source: SlotContribution(
          slot: ParameterSlot.range, actualName: 'Voice', referenceName: 'Touch'),
      magnitude: 1,
    );
    const b = LevelContribution(
      source: SlotContribution(
          slot: ParameterSlot.range, actualName: 'Voice', referenceName: 'Touch'),
      magnitude: 1,
    );

    expect(a, equals(b));
  });

  test('a differing reference makes contributions unequal', () {
    const a = LevelContribution(
      source: SlotContribution(slot: ParameterSlot.range, actualName: 'Voice'),
      magnitude: 1,
    );
    const b = LevelContribution(
      source: SlotContribution(
          slot: ParameterSlot.range, actualName: 'Voice', referenceName: 'Touch'),
      magnitude: 1,
    );

    expect(a, isNot(equals(b)));
  });
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/engine/level_breakdown_test.dart`
Expected: FAIL — `SlotContribution` is undefined, `LevelContribution` has no `source` parameter.

- [ ] **Step 3: Create the sealed hierarchy**

Create `lib/engine/contribution_source.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Which of the three parameter slots a [SlotContribution] charges for.
enum ParameterSlot { range, duration, target }

/// What produced one line of a level calculation, as structure rather than
/// prose.
///
/// The engine has no BuildContext and so no locale: composing a display string
/// here made the level breakdown untranslatable in principle. Each variant
/// names its operands and leaves the wording to
/// `presentation/format/contribution_formatter.dart`.
///
/// Sealed on purpose. A sixth variant will not compile until the formatter's
/// switch handles it, so no contribution can reach the screen unlocalised.
sealed class ContributionSource extends Equatable {
  const ContributionSource();
}

/// The guideline's own base level. [description] is rulebook content.
final class BaseEffectContribution extends ContributionSource {
  final String description;

  const BaseEffectContribution(this.description);

  @override
  List<Object?> get props => [description];
}

/// One Range/Duration/Target line. [actualName] and [referenceName] are
/// rulebook content; a non-null [referenceName] means the guideline was priced
/// against a different parameter and the delta is being explained.
final class SlotContribution extends ContributionSource {
  final ParameterSlot slot;
  final String actualName;
  final String? referenceName;

  const SlotContribution({
    required this.slot,
    required this.actualName,
    this.referenceName,
  });

  @override
  List<Object?> get props => [slot, actualName, referenceName];
}

/// A requisite Art and the parameter driving it. [art] is Latin and is never
/// translated; [parameterName] is rulebook content.
final class RequisiteContribution extends ContributionSource {
  final String art;
  final String parameterName;

  const RequisiteContribution({required this.art, required this.parameterName});

  @override
  List<Object?> get props => [art, parameterName];
}

/// A one-off level adjustment.
///
/// [note] is USER CONTENT — prose the caster typed. It renders verbatim under
/// every locale, never enters an ARB file, and is exempt from the pseudo-locale
/// transform.
final class AdjustmentContribution extends ContributionSource {
  final String note;

  const AdjustmentContribution(this.note);

  @override
  List<Object?> get props => [note];
}

/// A selected modifier option. Both fields are rulebook content.
final class ModifierContribution extends ContributionSource {
  final String modifierName;
  final String optionLabel;

  const ModifierContribution({
    required this.modifierName,
    required this.optionLabel,
  });

  @override
  List<Object?> get props => [modifierName, optionLabel];
}
```

- [ ] **Step 4: Swap `LevelContribution.label` for `source`**

In `lib/engine/level_breakdown.dart`, add the import and replace lines 6-20:

```dart
import 'package:eruditus/engine/contribution_source.dart';

/// One line of a spell's level calculation. [magnitude] holds the base level
/// when [isBase] is true, and a magnitude contribution otherwise.
class LevelContribution extends Equatable {
  final ContributionSource source;
  final int magnitude;
  final bool isBase;

  const LevelContribution({
    required this.source,
    required this.magnitude,
    this.isBase = false,
  });

  // See RitualStatus.props for why these three types carry value equality.
  @override
  List<Object?> get props => [source, magnitude, isBase];
}
```

- [ ] **Step 5: Rewrite the 7 engine composition sites**

In `lib/engine/spell_engine.dart`, at `:235-270`:

```dart
    final contributions = <LevelContribution>[
      LevelContribution(
          source: BaseEffectContribution(baseEffect.description),
          magnitude: baseLevel,
          isBase: true),
      _parameterContribution(
          ParameterSlot.range, range, baseEffect.reference.rangeId),
      _parameterContribution(
          ParameterSlot.duration, duration, baseEffect.reference.durationId),
      _parameterContribution(
          ParameterSlot.target, target, baseEffect.reference.targetId),
    ];

    for (final entry in requisites.entries) {
      contributions.add(LevelContribution(
          source: RequisiteContribution(
              art: entry.key, parameterName: entry.value.name),
          magnitude: entry.value.magnitude));
    }
```

the adjustments loop:

```dart
      contributions.add(LevelContribution(
          source: AdjustmentContribution(adjustment.note),
          magnitude: adjustment.magnitude));
```

the modifiers loop:

```dart
          contributions.add(LevelContribution(
              source: ModifierContribution(
                  modifierName: modifier.name, optionLabel: option.label),
              magnitude: option.magnitude));
```

and `_parameterContribution` at `:311-328`, whose signature changes from `String slot` to `ParameterSlot slot`. **Leave its existing doc comment in place** — its point about one code path rather than a branch on `isGeneral` is still true:

```dart
  LevelContribution _parameterContribution(
      ParameterSlot slot, Parameter actual, String referenceId) {
    if (actual.id == referenceId) {
      return LevelContribution(
          source: SlotContribution(slot: slot, actualName: actual.name),
          magnitude: 0);
    }

    final reference = _parameterById(referenceId);
    if (reference == null || reference.magnitude == 0) {
      return LevelContribution(
          source: SlotContribution(slot: slot, actualName: actual.name),
          magnitude: actual.magnitude);
    }

    return LevelContribution(
      source: SlotContribution(
          slot: slot, actualName: actual.name, referenceName: reference.name),
      magnitude: actual.magnitude - reference.magnitude,
    );
  }
```

- [ ] **Step 6: Rewrite the engine test assertions**

There are roughly 35, concentrated in `test/engine/spell_engine_test.dart` (45 `label` references) and `test/engine/level_breakdown_test.dart` (16). Find them: `grep -rn "·" test/`

Each becomes an assertion on structure. **Rewrite, never delete — each must still assert the same fact.**

```dart
// before
expect(breakdown.contributions[1].label, 'Range · Voice');

// after
expect(breakdown.contributions[1].source,
    const SlotContribution(slot: ParameterSlot.range, actualName: 'Voice'));
```

```dart
// before
expect(breakdown.contributions[1].label, 'Range · Personal (guideline assumes Touch)');

// after
expect(
    breakdown.contributions[1].source,
    const SlotContribution(
        slot: ParameterSlot.range,
        actualName: 'Personal',
        referenceName: 'Touch'));
```

```dart
// before
expect(contribution.label, 'Base effect · Create flame');

// after
expect(contribution.source, const BaseEffectContribution('Create flame'));
```

The `'Range · Voice|2'` style assertions (which packed label and magnitude into one string) become two expectations — one on `source`, one on `magnitude`.

- [ ] **Step 7: Run the suite**

Run: `flutter test` → 750 passing (748 + 2), zero failures
Run: `flutter analyze` → exit 0

Expect `level_banner.dart` to fail analysis here — it still reads `contribution.label`. Fix it minimally in this task by rendering a placeholder that Task 6 replaces:

```dart
Expanded(child: Text(contribution.source.toString())),
```

and note in the commit that Task 6 replaces it. Any widget test asserting on breakdown line text will fail; mark those tests `skip: 'Task 6 restores this via the formatter'` rather than deleting them, and remove the skips in Task 6.

- [ ] **Step 8: Commit**

```bash
git add lib/engine test/engine lib/presentation/widgets/level_banner.dart
git commit -m "refactor(engine): return structured ContributionSource instead of composed labels"
```

---

### Task 5: `LevelUnavailableReason` — the other engine-composed strings

**Files:**
- Modify: `lib/engine/level_breakdown.dart:70-78` (`LevelPreview`)
- Modify: `lib/engine/spell_engine.dart:166-211` (5 `LevelPreview.unavailable` sites)
- Modify: `lib/bloc/spell_creation/spell_creation_bloc.dart:60,140`
- Modify: `lib/bloc/spell_creation/spell_creation_state.dart` (`levelUnavailableReason`)
- Modify: `lib/presentation/screens/spell_creation_screen.dart:146`, `lib/presentation/widgets/level_banner.dart:30`
- Test: `test/engine/spell_engine_test.dart:1200-1298`, `test/presentation/widgets/level_banner_test.dart:159,170`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `enum LevelUnavailableReason { noBaseEffect, generalLevelNotTyped, generalLevelBelowOne, parametersIncomplete, magnitudesBelowOne }`, and `LevelPreview.unavailableReason` retyped from `String?` to `LevelUnavailableReason?`. Task 6's formatter renders it.

**This was not in the spec.** `LevelPreview.unavailableReason` is a second family of engine-composed user-facing strings, found while reading `level_breakdown.dart` for this plan. Five strings, 19 test references. Without this task the "choose a base effect" prompt stays hardcoded English while everything around it localises.

- [ ] **Step 1: Write the failing test**

Replace the assertion at `test/engine/spell_engine_test.dart:1200`:

```dart
      expect(preview.unavailableReason, LevelUnavailableReason.noBaseEffect);
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/engine/spell_engine_test.dart`
Expected: FAIL — `LevelUnavailableReason` is undefined.

- [ ] **Step 3: Add the enum and retype `LevelPreview`**

In `lib/engine/level_breakdown.dart`, above `LevelPreview`:

```dart
/// Why a draft cannot produce a level yet.
///
/// An enum rather than a message: these are chrome, and `previewLevel` runs in
/// domain code where no locale is reachable. See
/// `presentation/format/contribution_formatter.dart` for the wording.
enum LevelUnavailableReason {
  noBaseEffect,
  generalLevelNotTyped,
  generalLevelBelowOne,
  parametersIncomplete,
  magnitudesBelowOne,
}
```

and change the field and constructor:

```dart
  final LevelUnavailableReason? unavailableReason;

  const LevelPreview.available(LevelBreakdown this.breakdown)
      : unavailableReason = null;

  const LevelPreview.unavailable(LevelUnavailableReason this.unavailableReason)
      : breakdown = null;
```

- [ ] **Step 4: Replace the 5 engine sites**

In `lib/engine/spell_engine.dart`, keeping every surrounding comment intact — particularly the long doc comment at `:150-165` explaining why the General case is answered before the `try`, which stays accurate:

| Line | Was | Becomes |
|---|---|---|
| 169 | `'Choose a base effect to see a level.'` | `LevelUnavailableReason.noBaseEffect` |
| 174 | `'Type a level for this General guideline.'` | `LevelUnavailableReason.generalLevelNotTyped` |
| 186 | `'A General guideline needs a level of 1 or more.'` | `LevelUnavailableReason.generalLevelBelowOne` |
| 194 | `'Choose a Range, Duration and Target.'` | `LevelUnavailableReason.parametersIncomplete` |
| 210 | `'Magnitudes reduce this spell below level 1.'` | `LevelUnavailableReason.magnitudesBelowOne` |

The inline comment at `:176-184` names the old string ("told the caster *Magnitudes reduce this spell below level 1.*"). Keep it, but reword the quotation to name the enum value so it does not decay into a reference to a string that no longer exists.

- [ ] **Step 5: Thread the type through bloc and UI**

`spell_creation_state.dart`: retype `levelUnavailableReason` to `LevelUnavailableReason?`. `spell_creation_bloc.dart:60,140` need no change beyond the type flowing. `level_banner.dart:30`: retype `unavailableReason`. Render it as `reason.toString()` for now — Task 6 replaces that.

- [ ] **Step 6: Update the remaining test references**

The other 18 references (`grep -rn "unavailableReason" test/`) become enum comparisons. `level_banner_test.dart:159,170` pass `LevelUnavailableReason.noBaseEffect`.

- [ ] **Step 7: Run the suite**

Run: `flutter test` → 750 passing
Run: `flutter analyze` → exit 0

- [ ] **Step 8: Commit**

```bash
git add lib/engine lib/bloc lib/presentation test
git commit -m "refactor(engine): make LevelPreview.unavailableReason an enum"
```

---

### Task 6: The contribution formatter

**Files:**
- Create: `lib/presentation/format/contribution_formatter.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/presentation/widgets/level_banner.dart:113,95-140`
- Test: `test/presentation/format/contribution_formatter_test.dart`

**Interfaces:**
- Consumes: `ContributionSource` and `ParameterSlot` (Task 4), `LevelUnavailableReason` (Task 5), `AppLocalizations` (Task 1).
- Produces: `String formatContribution(AppLocalizations l10n, ContributionSource source)` and `String formatUnavailableReason(AppLocalizations l10n, LevelUnavailableReason reason)`.

- [ ] **Step 1: Add the ARB entries**

Append to `lib/l10n/app_en.arb`. **The `·` separator lives here, not in Dart** — it is punctuation in a sentence and a translator may want a different one.

```json
  "contributionBaseEffect": "Base effect · {description}",
  "@contributionBaseEffect": {
    "placeholders": { "description": { "type": "String" } }
  },
  "contributionSlot": "{slot} · {actual}",
  "@contributionSlot": {
    "placeholders": {
      "slot": { "type": "String" },
      "actual": { "type": "String" }
    }
  },
  "contributionSlotAssumes": "{slot} · {actual} (guideline assumes {reference})",
  "@contributionSlotAssumes": {
    "placeholders": {
      "slot": { "type": "String" },
      "actual": { "type": "String" },
      "reference": { "type": "String" }
    }
  },
  "contributionRequisite": "Requisite · {art}, {parameter}",
  "@contributionRequisite": {
    "placeholders": {
      "art": { "type": "String" },
      "parameter": { "type": "String" }
    }
  },
  "contributionAdjustment": "Adjustment · {note}",
  "@contributionAdjustment": {
    "description": "{note} is USER CONTENT and renders verbatim in every locale",
    "placeholders": { "note": { "type": "String" } }
  },
  "contributionModifier": "{modifier} · {option}",
  "@contributionModifier": {
    "placeholders": {
      "modifier": { "type": "String" },
      "option": { "type": "String" }
    }
  },
  "slotRange": "Range",
  "slotDuration": "Duration",
  "slotTarget": "Target",
  "levelUnavailableNoBaseEffect": "Choose a base effect to see a level.",
  "levelUnavailableGeneralLevelNotTyped": "Type a level for this General guideline.",
  "levelUnavailableGeneralLevelBelowOne": "A General guideline needs a level of 1 or more.",
  "levelUnavailableParametersIncomplete": "Choose a Range, Duration and Target.",
  "levelUnavailableMagnitudesBelowOne": "Magnitudes reduce this spell below level 1.",
  "ritualMinimumRaised": "Ritual minimum: raised from {from} to {to}",
  "@ritualMinimumRaised": {
    "placeholders": {
      "from": { "type": "int" },
      "to": { "type": "int" }
    }
  }
```

- [ ] **Step 2: Write the failing test**

Create `test/presentation/format/contribution_formatter_test.dart`:

```dart
import 'package:eruditus/engine/contribution_source.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/presentation/format/contribution_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  late AppLocalizations l10n;

  Future<void> loadL10n(WidgetTester tester, {Locale? locale}) async {
    await pumpApp(
      tester,
      Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const SizedBox.shrink();
      }),
      locale: locale ?? const Locale('en'),
    );
  }

  testWidgets('formats a base effect', (tester) async {
    await loadL10n(tester);
    expect(formatContribution(l10n, const BaseEffectContribution('Create flame')),
        'Base effect · Create flame');
  });

  testWidgets('formats a slot at its reference', (tester) async {
    await loadL10n(tester);
    expect(
        formatContribution(l10n,
            const SlotContribution(slot: ParameterSlot.range, actualName: 'Voice')),
        'Range · Voice');
  });

  testWidgets('formats a slot against a differing reference', (tester) async {
    await loadL10n(tester);
    expect(
        formatContribution(
            l10n,
            const SlotContribution(
                slot: ParameterSlot.range,
                actualName: 'Personal',
                referenceName: 'Touch')),
        'Range · Personal (guideline assumes Touch)');
  });

  testWidgets('formats a requisite', (tester) async {
    await loadL10n(tester);
    expect(
        formatContribution(l10n,
            const RequisiteContribution(art: 'Vim', parameterName: 'adding')),
        'Requisite · Vim, adding');
  });

  testWidgets('formats a modifier', (tester) async {
    await loadL10n(tester);
    expect(
        formatContribution(
            l10n,
            const ModifierContribution(
                modifierName: 'Material difficulty',
                optionLabel: 'Metal or gemstone')),
        'Material difficulty · Metal or gemstone');
  });

  testWidgets('formats an adjustment', (tester) async {
    await loadL10n(tester);
    expect(formatContribution(l10n, const AdjustmentContribution('storyguide said so')),
        'Adjustment · storyguide said so');
  });

  testWidgets('a user note is NOT pseudo-transformed under xx', (tester) async {
    await loadL10n(tester, locale: const Locale('xx'));

    final result =
        formatContribution(l10n, const AdjustmentContribution('storyguide said so'));

    expect(result.contains('storyguide said so'), isTrue,
        reason: 'user content renders verbatim in every locale');
    expect(result.startsWith('['), isTrue,
        reason: 'but the frame around it is still localised');
  });

  testWidgets('formats every unavailable reason', (tester) async {
    await loadL10n(tester);
    expect(formatUnavailableReason(l10n, LevelUnavailableReason.noBaseEffect),
        'Choose a base effect to see a level.');
    expect(
        formatUnavailableReason(l10n, LevelUnavailableReason.magnitudesBelowOne),
        'Magnitudes reduce this spell below level 1.');
  });
}
```

The pseudo-locale test above is the explicit regression guard for the third text population.

- [ ] **Step 3: Run it and confirm it fails**

Run: `flutter test test/presentation/format/contribution_formatter_test.dart`
Expected: FAIL — `contribution_formatter.dart` does not exist.

- [ ] **Step 4: Implement the formatter**

Create `lib/presentation/format/contribution_formatter.dart`:

```dart
import 'package:eruditus/engine/contribution_source.dart';
import 'package:eruditus/engine/level_breakdown.dart';
import 'package:eruditus/l10n/app_localizations.dart';

/// Words a [ContributionSource] for display.
///
/// The switch is exhaustive over the sealed type, so a new variant will not
/// compile until it has wording here. That is the point: it makes "did we miss
/// a string?" a compile error rather than a review question.
String formatContribution(AppLocalizations l10n, ContributionSource source) =>
    switch (source) {
      BaseEffectContribution(:final description) =>
        l10n.contributionBaseEffect(description),
      SlotContribution(:final slot, :final actualName, referenceName: null) =>
        l10n.contributionSlot(_slotName(l10n, slot), actualName),
      SlotContribution(
        :final slot,
        :final actualName,
        :final referenceName?
      ) =>
        l10n.contributionSlotAssumes(
            _slotName(l10n, slot), actualName, referenceName),
      RequisiteContribution(:final art, :final parameterName) =>
        l10n.contributionRequisite(art, parameterName),
      AdjustmentContribution(:final note) => l10n.contributionAdjustment(note),
      ModifierContribution(:final modifierName, :final optionLabel) =>
        l10n.contributionModifier(modifierName, optionLabel),
    };

/// gen-l10n cannot generate a getter keyed by a Dart enum, so the mapping lives
/// here. Exhaustive for the same reason as above.
String _slotName(AppLocalizations l10n, ParameterSlot slot) => switch (slot) {
      ParameterSlot.range => l10n.slotRange,
      ParameterSlot.duration => l10n.slotDuration,
      ParameterSlot.target => l10n.slotTarget,
    };

String formatUnavailableReason(
        AppLocalizations l10n, LevelUnavailableReason reason) =>
    switch (reason) {
      LevelUnavailableReason.noBaseEffect => l10n.levelUnavailableNoBaseEffect,
      LevelUnavailableReason.generalLevelNotTyped =>
        l10n.levelUnavailableGeneralLevelNotTyped,
      LevelUnavailableReason.generalLevelBelowOne =>
        l10n.levelUnavailableGeneralLevelBelowOne,
      LevelUnavailableReason.parametersIncomplete =>
        l10n.levelUnavailableParametersIncomplete,
      LevelUnavailableReason.magnitudesBelowOne =>
        l10n.levelUnavailableMagnitudesBelowOne,
    };
```

- [ ] **Step 5: Wire `LevelBanner` to the formatter**

Regenerate first: `flutter pub get`. Then in `level_banner.dart`, replace the Task 4 placeholder at the contribution row:

```dart
Expanded(child: Text(formatContribution(l10n, contribution.source))),
```

the unavailable-reason `Text(reason)` with `Text(formatUnavailableReason(l10n, reason))`, and the hardcoded ritual-minimum line at `:134`:

```dart
child: Text(
  l10n.ritualMinimumRaised(breakdown.rawLevel, breakdown.level),
  style: Theme.of(context).textTheme.bodySmall,
),
```

Also migrate `'Spell level'` (`:78`) and the `'Show the breakdown'`/`'Hide the breakdown'` pair (`:90`) to `l10n.spellLevel`, `l10n.showBreakdown`, `l10n.hideBreakdown` — Task 1 already put them in the ARB.

Obtain `l10n` once at the top of `build`: `final l10n = AppLocalizations.of(context);`.

- [ ] **Step 6: Remove the Task 4 skips**

Delete the `skip: 'Task 6 restores this via the formatter'` markers added in Task 4 Step 7. Those tests should now pass unchanged, because the rendered text is identical to what the engine used to compose.

- [ ] **Step 7: Run the suite**

Run: `flutter test` → 758 passing (750 + 8 formatter tests), zero skips
Run: `flutter analyze` → exit 0
Run: `dart run tool/gen_pseudo_arb.dart` then `flutter test test/l10n/pseudo_arb_sync_test.dart` — the ARB grew, so `app_xx.arb` must be regenerated.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation lib/l10n test/presentation
git commit -m "feat(l10n): localise the level breakdown through a contribution formatter"
```

---

### Task 7: Migrate the small widgets

**Files:**
- Modify: `lib/presentation/widgets/modifiers_section.dart:63,68,105,136`
- Modify: `lib/presentation/widgets/spell_card.dart:73,79,84,86,146,185`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/presentation/widgets/modifiers_section_test.dart`, `test/presentation/widgets/spell_card_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations` (Task 1), `pumpApp` (Task 2).
- Produces: no new Dart API — ARB keys only.

**Watch the population boundary here.** `option.label`, `entry.technique`, `entry.form` and `p.name` are rulebook content; the user's spell name is user content. Only the *frames* move to ARB.

- [ ] **Step 1: Add the ARB entries**

```json
  "modifiersSelectedCount": "{count} selected",
  "@modifiersSelectedCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "modifierOptionWithMagnitude": "{option} (+{magnitude})",
  "@modifierOptionWithMagnitude": {
    "placeholders": {
      "option": { "type": "String" },
      "magnitude": { "type": "int" }
    }
  },
  "untitledSpell": "Untitled spell",
  "untitledSpellOfArts": "Untitled {technique} {form}",
  "@untitledSpellOfArts": {
    "placeholders": {
      "technique": { "type": "String" },
      "form": { "type": "String" }
    }
  },
  "spellCardUnavailable": "Unavailable — missing {references}",
  "@spellCardUnavailable": {
    "placeholders": { "references": { "type": "String" } }
  },
  "spellCardUnverifiedSuffix": " (unverified)",
  "spellCardArtsAndLevel": "{technique} {form} • Level {level}{suffix}",
  "@spellCardArtsAndLevel": {
    "placeholders": {
      "technique": { "type": "String" },
      "form": { "type": "String" },
      "level": { "type": "int" },
      "suffix": { "type": "String" }
    }
  },
  "spellCardArtsOnly": "{technique} {form}",
  "@spellCardArtsOnly": {
    "placeholders": {
      "technique": { "type": "String" },
      "form": { "type": "String" }
    }
  },
  "needsReview": "Needs review",
  "mySpell": "My Spell"
```

- [ ] **Step 2: Write the failing test**

Add to `test/presentation/widgets/spell_card_test.dart`:

```dart
  testWidgets('the card chrome is localised but the spell name is not',
      (tester) async {
    await pumpApp(tester, const SpellCard(/* existing fixture args */),
        locale: const Locale('xx'));

    expect(find.text('Needs review'), findsNothing,
        reason: 'chrome should be pseudo-transformed under xx');
  });
```

Use whichever fixture the neighbouring tests in that file already build; do not invent a new one.

- [ ] **Step 3: Run it and confirm it fails**

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: FAIL — `'Needs review'` is still a hardcoded literal, so it renders untransformed under `xx`.

- [ ] **Step 4: Replace the literals**

In each widget, take `final l10n = AppLocalizations.of(context);` at the top of `build` and replace each literal with its ARB getter. `'+$_totalMagnitude'` at `modifiers_section.dart:68` stays a literal — it is a signed number, not prose.

- [ ] **Step 5: Run, regenerate, commit**

Run: `flutter test` → PASS, `flutter analyze` → exit 0
Run: `dart run tool/gen_pseudo_arb.dart`

```bash
git add lib/presentation/widgets lib/l10n test/presentation/widgets
git commit -m "feat(l10n): migrate modifiers section and spell card strings"
```

---

### Task 8: Migrate `ritual_section.dart`

**Files:**
- Modify: `lib/presentation/widgets/ritual_section.dart:50-57,71,87,95,99-102,110,113`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/presentation/widgets/ritual_section_test.dart` (create if absent)

**Interfaces:**
- Consumes: `AppLocalizations` (Task 1), `pumpApp` (Task 2).
- Produces: no new Dart API.

This file is separated from Task 7 because `_describe` composes a *sentence* from a list of ritual reasons — the same class of problem as the engine's labels, but already in the presentation layer, so it needs ICU care rather than restructuring.

- [ ] **Step 1: Add the ARB entries**

```json
  "ritualReasonRange": "{range} range",
  "@ritualReasonRange": {
    "placeholders": { "range": { "type": "String" } }
  },
  "ritualReasonDuration": "{duration} duration",
  "@ritualReasonDuration": {
    "placeholders": { "duration": { "type": "String" } }
  },
  "ritualReasonTarget": "{target} target",
  "@ritualReasonTarget": {
    "placeholders": { "target": { "type": "String" } }
  },
  "ritualReasonLevelAbove": "level above {max}",
  "@ritualReasonLevelAbove": {
    "placeholders": { "max": { "type": "int" } }
  },
  "ritualReasonGuidelineRequires": "the guideline requires it",
  "ritualReasonLastingCreation": "it creates something lasting",
  "ritualReasonStoryguideRuling": "storyguide ruling",
  "ritualSummary": "Ritual: {reasons}",
  "@ritualSummary": {
    "description": "{reasons} is a pre-joined list built by _describe",
    "placeholders": { "reasons": { "type": "String" } }
  },
  "ritualNotDeclared": "Not declared",
  "ritualCreatesLasting": "This creates something lasting",
  "ritualCreatesLastingHelp": "Cast as anything other than a Momentary Ritual, this suspends the healing rather than completing it. A Momentary Creo spell that is not a Ritual creates something that vanishes as the magic ends.",
  "ritualStoryguideRuling": "Storyguide ruling: too spectacular to be freely available",
  "ritualStoryguideRulingHelp": "The troupe may declare any spell a Ritual, as the storyguide determines (Core Rules line 12352)."
```

The two help strings were split across source lines by wrapping only; they are single sentences and belong in one ARB value each. **Do not preserve the line breaks** — a translator should not inherit our column width.

- [ ] **Step 2: Write the failing test**

```dart
  testWidgets('ritual reasons are localised', (tester) async {
    await pumpApp(tester, const RitualSection(/* existing fixture args */),
        locale: const Locale('xx'));

    expect(find.textContaining('the guideline requires it'), findsNothing);
  });
```

- [ ] **Step 3: Run it and confirm it fails**

Run: `flutter test test/presentation/widgets/ritual_section_test.dart`
Expected: FAIL — the reason strings are still hardcoded.

- [ ] **Step 4: Replace the literals**

`_describe` gains an `AppLocalizations` parameter. The join at `:71` keeps using `', '` for now — a locale-aware list join is `intl`'s job and is out of scope for this pass; note it in the commit body.

- [ ] **Step 5: Run, regenerate, commit**

Run: `flutter test` → PASS, `flutter analyze` → exit 0
Run: `dart run tool/gen_pseudo_arb.dart`

```bash
git add lib/presentation/widgets/ritual_section.dart lib/l10n test/presentation/widgets
git commit -m "feat(l10n): migrate ritual section strings"
```

---

### Task 9: Migrate the library, backup and configuration screens

**Files:**
- Modify: `lib/presentation/screens/spell_library_screen.dart:36,53,63,85,109,157`
- Modify: `lib/presentation/screens/backup_screen.dart:27,33,39-46,62,68`
- Modify: `lib/presentation/screens/configuration_screen.dart:86,129,154,212,255`
- Modify: `lib/main.dart:151,196-203` (dialog title, filename, 4 tab labels)
- Modify: `lib/l10n/app_en.arb`
- Test: the matching screen tests

**Interfaces:**
- Consumes: `AppLocalizations` (Task 1), `pumpApp` (Task 2).
- Produces: no new Dart API.

- [ ] **Step 1: Add the ARB entries**

`backup_screen.dart:39-43` is the one real plural in the codebase and needs ICU `plural`, not string concatenation:

```json
  "spellLibraryTitle": "Spell Library",
  "searchSpellsHint": "Search spells...",
  "mySpells": "My Spells",
  "generalSpellsHeader": "General spells — learn at any level",
  "exceptionsHeader": "Exceptions — recorded from the rulebook directly, not derived from the guidelines",
  "learnAtLevel": "Learn at level…",
  "backupExported": "Backup exported successfully.",
  "backupImportCancelled": "Import cancelled.",
  "backupImported": "Imported {spells} spells, {effects} effects, {parameters} parameters.",
  "@backupImported": {
    "placeholders": {
      "spells": { "type": "int" },
      "effects": { "type": "int" },
      "parameters": { "type": "int" }
    }
  },
  "backupRejectedSpells": "{count, plural, =0{} one{1 invalid spell: {ids}} other{{count} invalid spells: {ids}}}",
  "@backupRejectedSpells": {
    "placeholders": {
      "count": { "type": "int" },
      "ids": { "type": "String" }
    }
  },
  "backupImportFailed": "Import failed: {error}",
  "@backupImportFailed": {
    "placeholders": { "error": { "type": "String" } }
  },
  "exportBackupToFile": "Export Backup to File",
  "importBackupFromFile": "Import Backup from File",
  "saveBackupDialogTitle": "Save Backup",
  "addCustomEffect": "Add Custom Effect",
  "baseLevel": "Base Level",
  "addCustomParameter": "Add Custom Parameter",
  "parameterCategoryAndMagnitude": "{category} • Magnitude +{magnitude}",
  "@parameterCategoryAndMagnitude": {
    "placeholders": {
      "category": { "type": "String" },
      "magnitude": { "type": "int" }
    }
  },
  "tabCreate": "Create",
  "tabLibrary": "Library",
  "tabSettings": "Settings",
  "tabBackup": "Backup"
```

`'eruditus_backup.json'` (`main.dart:151`) stays a literal — it is a filename, not chrome.

- [ ] **Step 2: Write the failing test**

Add to `test/presentation/screens/spell_library_screen_test.dart`:

```dart
  testWidgets('library chrome is localised', (tester) async {
    await pumpApp(tester, /* existing fixture */, locale: const Locale('xx'));

    expect(find.text('Spell Library'), findsNothing);
  });
```

- [ ] **Step 3: Run it and confirm it fails**

Expected: FAIL — `'Spell Library'` is still hardcoded.

- [ ] **Step 4: Replace the literals**

For the tab labels in `main.dart`, note `BottomNavigationBarItem` is inside a `const []` list — the list can no longer be `const` once labels come from `l10n`. Drop the `const` on the list, keep it on each `Icon`.

- [ ] **Step 5: Run, regenerate, commit**

Run: `flutter test` → PASS, `flutter analyze` → exit 0
Run: `dart run tool/gen_pseudo_arb.dart`

```bash
git add lib/presentation/screens lib/main.dart lib/l10n test/presentation/screens
git commit -m "feat(l10n): migrate library, backup and configuration screens"
```

---

### Task 10: Migrate `spell_creation_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart` (51 literals)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/presentation/screens/spell_creation_screen_test.dart` (65 `find.text` calls), `test/presentation/screens/spell_creation_screen_configuration_sync_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations` (Task 1), `pumpApp` (Task 2).
- Produces: no new Dart API.

The largest file (1170 lines, 51 literals) and the most test-covered, so it gets its own task.

- [ ] **Step 1: Add the ARB entries**

Chrome, from the line numbers listed:

| Line | String |
|---|---|
| 55 | `"{name}" saved to your library.` → `spellSavedToLibrary` |
| 59 | `Could not save spell: {error}` → `couldNotSaveSpell` |
| 130 | `Create Spell` → `createSpell` |
| 181 | `Base Effect` → `baseEffect` |
| 276 | `Spell Parameters` → `spellParameters` |
| 278 | `Every spell requires exactly one of each:` → `everySpellRequiresOneOfEach` |
| 298-299 | `{target} requires this Range (Houses of Hermes: Mystery Cults, Sensory Magic).` → `targetRequiresThisRange` |
| 385 | `Find Similar Spells` → `findSimilarSpells` |
| 389 | `Similar Spells` → `similarSpellsTitle` |
| 391 | `No similar spells found.` → `noSimilarSpellsFound` |
| 424 | `Failed to save spell.` → `failedToSaveSpell` |
| 478 | `Save to Library` → `saveToLibrary` |
| 520 | `Free requisites cost nothing; adding requisites cost +1 magnitude each.` → `requisitesHelp` |
| 525 | `No requisites.` → `noRequisites` |
| 541 | `Adding (+1)` / `Free (+0)` → `requisiteAdding` / `requisiteFree` |
| 554 | `Remove {art} requisite` → `removeRequisite` |
| 572 | `Add requisite` → `addRequisite` |
| 611 | `A one-off magnitude with the prose that justifies it, positive or negative.` → `adjustmentsHelp` |
| 616 | `No adjustments.` → `noAdjustments` |
| 628 | `Decrease magnitude` → `decreaseMagnitude` |
| 649 | `Increase magnitude` → `increaseMagnitude` |
| 674 | `Remove adjustment` → `removeAdjustment` |
| 684 | `Add adjustment` → `addAdjustment` |
| 835 | `Guideline level` → `guidelineLevel` |
| 836 | `General guidelines have no fixed level — you choose it.` → `generalGuidelineLevelHelp` |
| 885 | `Specific type` → `specificType` |
| 934 | `Required. Shown on this spell...` → `nameRequiredHelp` |
| 964 | `Not stated` → `containerModeNotStated` |
| 972-973 | `Not recorded. The rulebook fixes this when the spell is designed, so it is worth deciding.` → `containerModeUnstatedHelp` |
| 975-976 | `Affects whatever is in the {target} when cast, and keeps affecting it even after it leaves.` → `containerModeStaticHelp` |
| 978-979 | `Affects whatever is in the {target} at the time. Leaving ends the effect; entering starts it.` → `containerModeDynamicHelp` |
| 988 | `Container behaviour` → `containerBehaviour` |
| 1121 | `Name Your Spell` → `nameYourSpell` |
| 1131 | `e.g., Pillar of Flames` → `spellNameHint` |
| 1142 | `What does this spell do?` → `spellSummaryHint` |

**The spell name at `:55` is user content** — it goes in as a placeholder, and the ARB value keeps the surrounding quotes:

```json
  "spellSavedToLibrary": "\"{name}\" saved to your library.",
  "@spellSavedToLibrary": {
    "description": "{name} is USER CONTENT and renders verbatim",
    "placeholders": { "name": { "type": "String" } }
  }
```

**Lines 199-200, 732-733 are composed from rulebook content** (`e.description`, `p.name`, `p.requiresVirtue`). Their *frames* become ARB entries:

```json
  "effectWithGeneralMarker": "{description} ({marker})",
  "parameterWithMagnitude": "{name} (+{magnitude})",
  "parameterWithMagnitudeAndVirtue": "{name} (+{magnitude}, requires {virtue})"
```

with `String` and `int` placeholders as in the earlier tasks.

Lines 215, 781, 852 are **comment text**, not UI strings — leave them alone. Line 239/256 are widget `Key`s — leave them alone.

- [ ] **Step 2: Write the failing test**

```dart
  testWidgets('creation screen chrome is localised', (tester) async {
    await pumpApp(tester, /* existing fixture */, locale: const Locale('xx'));

    expect(find.text('Create Spell'), findsNothing);
    expect(find.text('Save to Library'), findsNothing);
  });
```

- [ ] **Step 3: Run it and confirm it fails**

Expected: FAIL — both are still hardcoded.

- [ ] **Step 4: Replace the literals**

Work top-down through the table. This file has several nested builder closures; take `final l10n = AppLocalizations.of(context);` inside each closure that needs it rather than capturing one from an outer scope with a different `BuildContext`.

- [ ] **Step 5: Run, regenerate, commit**

Run: `flutter test` → PASS (the 65 `find.text` assertions in this file's tests are English-locale and should be unaffected)
Run: `flutter analyze` → exit 0
Run: `dart run tool/gen_pseudo_arb.dart`

```bash
git add lib/presentation/screens/spell_creation_screen.dart lib/l10n test/presentation/screens
git commit -m "feat(l10n): migrate spell creation screen strings"
```

---

### Task 11: Pseudo-locale coverage test

**Files:**
- Create: `test/l10n/pseudo_locale_coverage_test.dart`
- Modify: `.superpowers/todo.md`, `.superpowers/themes/app.md` (close item 80's sub-items)

**Interfaces:**
- Consumes: everything above.
- Produces: the standing guard that stops the migration decaying.

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// Chrome strings that must never survive a switch to the pseudo-locale.
///
/// If one of these is findable under `xx`, it is still a hardcoded literal.
const _mustNotSurvive = <String>[
  'Create Spell',
  'Save to Library',
  'Spell Library',
  'My Spells',
  'Export Backup to File',
  'Import Backup from File',
  'Add Custom Effect',
  'Add Custom Parameter',
  'Spell level',
  'Needs review',
  'Not declared',
  'Guideline level',
  'Container behaviour',
];

void main() {
  testWidgets('no chrome string survives the pseudo-locale', (tester) async {
    await pumpApp(tester, /* the app's root tab view */,
        locale: const Locale('xx'));
    await tester.pumpAndSettle();

    for (final literal in _mustNotSurvive) {
      expect(find.text(literal), findsNothing,
          reason: '"$literal" is still a hardcoded literal — move it to ARB');
    }
  });
}
```

Pump each of the four screens in turn if pumping the whole tab view needs more bloc scaffolding than the existing screen tests already build; reuse `bloc_factories.dart`'s mocks rather than constructing real repositories.

- [ ] **Step 2: Run it**

Run: `flutter test test/l10n/pseudo_locale_coverage_test.dart`
Expected: PASS if Tasks 7-10 were complete. **Any failure names a literal that was missed** — fix it by moving that string to ARB, not by removing it from the list.

- [ ] **Step 3: Run everything**

Run: `flutter test` → all green, count ≥ 760 and **never below the 745 baseline**
Run: `python -m unittest discover -s scripts/spell_import/tests -t .` → 397 green
Run: `flutter test integration_test -d windows` → 8 green
Run: `flutter analyze` → exit 0
Run: `git diff -w --stat` → no whitespace-only churn

- [ ] **Step 4: Close out the item**

Tick `80.1`, `80.2` and `80.3` in `.superpowers/themes/app.md`, and update the `todo.md` row for item 80 from `open 3/3` to `closed`. Record the actual final test count in `.superpowers/STATUS.md`, replacing the 745/397/8 line.

Then invoke the `closing-an-item` skill to extract any still-binding constraints into `DECISIONS.md` — at minimum the three-population boundary rule and the "engine never composes display prose" invariant, which is the one most likely to be violated by future work.

- [ ] **Step 5: Commit**

```bash
git add test/l10n .superpowers
git commit -m "test(l10n): add pseudo-locale coverage guard and close item 80"
```

---

## Self-review notes

**Spec coverage.** All five spec design sections map to tasks: §1 → Task 1, §2 → Task 4, §3 → Task 6, §4 → Task 2, §5 → Tasks 3 and 11. The spec's testing table maps to Tasks 4, 6 and 11.

**One addition beyond the spec.** Task 5 (`LevelUnavailableReason`) covers five engine-composed strings the spec missed — found while reading `level_breakdown.dart` to write Task 4. The spec named seven `label:` sites; there are twelve engine-composed user-facing strings in total. **The spec should be amended** to say so, or Task 5 will look like scope creep to a reviewer who reads the spec first.

**Item 82 folded in, narrowly.** The translation-provenance flag is applied to the one non-template locale this pass creates (`app_xx.arb`, Task 3) and deliberately *not* stamped across `app_en.arb`. Rationale in Global Constraints. This closes 82.2 and partly answers 82.1; **82.3 (what the flag drives) remains open** and is not blocked by this work.

**Deliberate deferrals**, each noted where it arises rather than left silent: the locale-aware list join in Task 8, and the double-`Scaffold` nesting risk in Task 2 Step 3.
