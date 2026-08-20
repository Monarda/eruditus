# Internationalisation: ARB-backed chrome, and an engine that stops writing prose

Item 80. Opened 2026-08-20, asked for directly by the user.

**Goal: no translation today, but adding one later must not be a rewrite.**
Nothing is wired now — no `intl`, no `flutter_localizations`, no `l10n.yaml`, no
ARB files. This spec stands the mechanism up, migrates the existing strings, and
fixes the one structural obstacle that would otherwise make the app
untranslatable no matter how many ARB files it had.

## Problem

Two problems, and only the first is the obvious one.

**1. There is no localisation mechanism.** `lib/presentation/` is 8 files and
2345 lines carrying roughly 115 user-facing literals, plus the tab labels and
dialog titles in `lib/main.dart`. All hardcoded English.

**2. ⚠️ The engine composes user-facing prose.** `spell_engine.dart` builds
display strings at seven sites and hands them to the UI pre-formatted:

```dart
label: 'Base effect · ${baseEffect.description}',
label: 'Requisite · ${entry.key}, ${entry.value.name}',
label: 'Adjustment · ${adjustment.note}',
label: '${modifier.name} · ${option.label}',
label: '$slot · ${actual.name} (guideline assumes ${reference.name})',
```

`LevelContribution.label` is a plain `String` (`level_breakdown.dart:7`) rendered
straight by `LevelBanner`. This is domain code: there is no `BuildContext`, so no
locale can reach it. **The level breakdown — the app's most rules-dense surface,
made live by item 59 — is therefore untranslatable in principle, not merely
unlocalised in practice.** Adding ARB files does not touch it.

**⚠️ Amended 2026-08-20, while writing the implementation plan: there are twelve
such strings, not seven.** `LevelPreview.unavailableReason` is a second family —
five more composed in `previewLevel` (`spell_engine.dart:169-210`), reaching the
screen through `SpellCreationState.levelUnavailableReason` and carrying **19 test
references**:

```dart
return const LevelPreview.unavailable('Choose a base effect to see a level.');
return const LevelPreview.unavailable('Magnitudes reduce this spell below level 1.');
```

These are pure chrome with no operands, so they need an enum rather than a
sealed hierarchy — `LevelUnavailableReason`, resolved by the same formatter.
Without them the "choose a base effect" prompt stays hardcoded English while
everything around it localises. Covered by the plan's Task 5.

Fixing (1) without (2) produces an app that reports its own labels in French and
its actual reasoning in English.

## The organising idea: three text populations

Item 80.3 records two. Designing the contribution restructure surfaced a third,
and it is the one most easily got wrong.

| Population | Example | Where it lives | Who translates it |
|---|---|---|---|
| **App chrome** | "Calculate", "Range", "Save Backup" | ARB, keyed by locale | us |
| **Rulebook content** | "Voice", "Create flame", "Metal or gemstone" | `assets/data/*.json`, per source edition | the published translation (item 79) |
| **⚠️ User content** | an adjustment's `note` | the user's own saved spell | nobody — verbatim, always |

**The third population is why `Adjustment · ${adjustment.note}` needs care.** The
note is text the user typed. It must render unchanged under every locale, must
never enter an ARB file, and must be **exempt from the pseudo-locale transform**
or the proof harness below will raise false failures on it.

**The boundary rule, stated once so later items can apply it:** *ARB holds the
vocabulary that labels the interface; the catalog holds the content the rulebook
prints; user content passes through untouched.* So "Range" is chrome — it labels
a control — while "Voice" is content. When a translated edition eventually
lands, its official term for Range is what belongs in that locale's ARB value.

## Explicitly not in scope

- **Any actual translation.** English plus a mechanical pseudo-locale. No second
  language is added, and none is promised.
- **Localising rulebook content.** That is routed through the catalog per source
  edition and needs items 78 and 79 first. This spec only guarantees the route
  exists and that rules text never lands in ARB.
- **Date, number and currency formatting.** `intl` arrives as a dependency, but
  the app displays no dates or currency; spell levels are bare integers and stay
  that way.
- **RTL / bidirectional layout.** Deferred until a real RTL locale is on the
  table.
- **Item 56's hint strings.** 80 lands the mechanism so 56's strings arrive
  localised. See "Sequencing" below.

## Backwards compatibility is not a goal

Consistent with the project's standing position. `LevelBreakdown`,
`LevelContribution` and `RitualStatus` are **computed values, never persisted** —
verified: `level_breakdown.dart` has no `toMap`/`toJson`/`fromMap`, and the type
appears outside `lib/engine/` only in `SpellCreationState.breakdown` and
`LevelBanner`. **So this restructure has no database migration, no backup-format
change, and no asset change.** For a change this central to the level maths, that
is an unusually contained blast radius, and it is what makes doing it now cheap.

## Design

### 1. The l10n mechanism

`pubspec.yaml` gains `flutter_localizations` (from the SDK) and `intl`, plus
`generate: true` under `flutter:`. Flutter 3.44.8's built-in `gen-l10n` does the
generation; no third-party package is involved.

`l10n.yaml` at the repo root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

`nullable-getter: false` makes `AppLocalizations.of(context)` non-nullable, so a
missing `Localizations` ancestor fails loudly at the call site rather than
silently short-circuiting on a `?.`.

`MaterialApp` in `lib/main.dart` gains `localizationsDelegates` and
`supportedLocales`. Its `title: 'Eruditus'` stays a literal — it is the product
name, not chrome.

### 2. `ContributionSource`: the engine states facts, the UI words them

New file `lib/engine/contribution_source.dart`. A sealed hierarchy with exactly
five variants, one per composition site found in the engine:

```dart
enum ParameterSlot { range, duration, target }

sealed class ContributionSource extends Equatable {
  const ContributionSource();
}

final class BaseEffectContribution extends ContributionSource {
  final String description;              // rulebook content
}

final class SlotContribution extends ContributionSource {
  final ParameterSlot slot;
  final String actualName;               // rulebook content
  final String? referenceName;           // non-null => "guideline assumes X"
}

final class RequisiteContribution extends ContributionSource {
  final String art;                      // Latin; never translated
  final String parameterName;            // rulebook content
}

final class AdjustmentContribution extends ContributionSource {
  final String note;                     // USER CONTENT — verbatim, always
}

final class ModifierContribution extends ContributionSource {
  final String modifierName;             // rulebook content
  final String optionLabel;              // rulebook content
}
```

`LevelContribution` swaps its `String label` for a `ContributionSource source`,
keeping `magnitude` and `isBase` unchanged. `props` becomes
`[source, magnitude, isBase]`; each variant carries its own `props`, so value
equality is preserved exactly as before — which matters, because item 58.1's
tests assert recomputed breakdowns compare *equal*.

**Why sealed rather than an enum plus nullable fields.** Dart 3 makes `switch`
over a sealed type exhaustive. **Adding a sixth contribution kind will fail to
compile until the formatter handles it** — so no contribution can ever reach the
screen unlocalised by omission. An enum-plus-nullables shape needs a `default:`
branch, which is precisely the silent-fallthrough this design exists to remove.

`_parameterContribution`'s three returns collapse to `SlotContribution`s
differing only in `referenceName` and magnitude. Its existing doc comment — that
the reference-equals-actual case is one code path and not a branch on
`isGeneral` — stays true and stays put.

### 3. Formatting lives in the presentation layer

New file `lib/presentation/format/contribution_formatter.dart`:

```dart
String formatContribution(AppLocalizations l10n, ContributionSource source) =>
    switch (source) {
      BaseEffectContribution(:final description) =>
          l10n.contributionBaseEffect(description),
      SlotContribution(:final slot, :final actualName, referenceName: null) =>
          l10n.contributionSlot(_slotName(l10n, slot), actualName),
      SlotContribution(:final slot, :final actualName, :final referenceName?) =>
          l10n.contributionSlotAssumes(
              _slotName(l10n, slot), actualName, referenceName),
      RequisiteContribution(:final art, :final parameterName) =>
          l10n.contributionRequisite(art, parameterName),
      AdjustmentContribution(:final note) => l10n.contributionAdjustment(note),
      ModifierContribution(:final modifierName, :final optionLabel) =>
          l10n.contributionModifier(modifierName, optionLabel),
    };
```

**The `·` separator moves into the ARB templates**, e.g.
`"contributionSlot": "{slot} · {actual}"`. It is punctuation in a sentence, and a
translator may legitimately want a different one. `LevelBanner` calls the
formatter instead of reading `.label`.

**`gen-l10n` cannot generate a getter keyed by a Dart enum**, so the slot name is
mapped in the formatter, not in the ARB:

```dart
String _slotName(AppLocalizations l10n, ParameterSlot slot) => switch (slot) {
      ParameterSlot.range => l10n.slotRange,
      ParameterSlot.duration => l10n.slotDuration,
      ParameterSlot.target => l10n.slotTarget,
    };
```

That switch is exhaustive over the enum for the same reason the outer one is
exhaustive over the sealed type: a fourth slot will not compile until it has a
name. (An ICU `select` message is the alternative and is worse here — it puts
the enum's value names into translator-visible ARB syntax.)

Note that `contributionAdjustment` interpolates user content into a chrome
frame — two populations meeting in one string, which is exactly why the frame is
translatable and the operand is not.

### 4. `pumpApp`: one localisation-aware test harness

Every widget under `Localizations` needs that ancestor in tests. There are
**47 inline `MaterialApp(` constructions across 10 test files** and no shared
helper — each file reinvents a private `pump`, e.g.
`level_banner_test.dart:24`.

New `test/support/pump_app.dart`, alongside the existing `bloc_factories.dart`:

```dart
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  List<SingleChildWidget> providers = const [],  // flutter_bloc's provider type
}) { /* wraps in MaterialApp with delegates + supportedLocales */ }
```

The 47 sites migrate to it. This is a prerequisite, not a bonus refactor: without
it the pseudo-locale switch in §5 has nowhere to be applied.

### 5. The pseudo-locale, generated rather than hand-written

With one language, a hardcoded literal and a correct ARB lookup are
indistinguishable on screen. A pseudo-locale makes the difference visible.

`app_xx.arb` transforms each English value by accenting its letters and padding
its length (`Calculate` → `[Ĉaĺćuĺaţe····]`), **leaving ICU placeholders
untouched**. Two properties fall out:

- a string that renders un-accented under locale `xx` is still hardcoded;
- the ~30% padding surfaces truncation and overflow, which is free evidence for
  **item 16** (short forms) and for **item 58's** untested-below-1200px
  segmented control.

**It is generated, not hand-maintained.** A hand-written pseudo ARB drifts from
`app_en.arb` the first time someone adds a string, and a drifted proof harness is
worse than none. `tool/gen_pseudo_arb.dart` derives `app_xx.arb` from
`app_en.arb`, and a test asserts the committed file is what the generator
produces — **the same regeneration-test idiom the repo already uses for
`spell_library.json`** (item 30).

`xx` is listed in `supportedLocales` and ships. No OS offers `xx`, so it is
unreachable in normal use; the alternative — a test-only delegate wrapping ~115
generated getters — is far more machinery for the same guarantee.

**If `gen-l10n` rejects `xx`** as a locale identifier, fall back to `en_XA` — the
pseudo-locale tag Android and Chrome already use — rather than inventing another.
Verify which one the toolchain accepts as the first implementation step, since
the filename, the `supportedLocales` entry and every test that switches locale
all depend on the answer.

## Testing

| Area | What it must show |
|---|---|
| Formatter | One test per `ContributionSource` variant; exhaustiveness is the compiler's job, not a test's. |
| Engine | The ~35 assertions on composed labels (`'Range · Voice'` ×14, `'Range · Personal (guideline assumes Touch)'`, …) become assertions on structured sources. **Rewritten, not deleted** — each must still assert the same fact. |
| Value equality | `LevelContribution` and `LevelBreakdown` still compare equal on recompute (guards item 58.1's contract). |
| Pseudo-locale | Pump each of the 4 screens under `Locale('xx')`; assert no known English chrome string is findable. |
| User content | An adjustment note renders **verbatim under `xx`** — the explicit regression guard for population three. |
| ARB sync | `app_xx.arb` matches the generator's output. |
| Suites | `flutter test`, the Python suite, and `flutter test integration_test -d windows` all green; `flutter analyze` at **exit 0**. |

Two working constraints carry over: **do not run `dart format`** (it is not clean
in this repo — hand-indent and check with `git diff -w`), and the Dart test count
should rise, never fall, since no assertion is being dropped.

## Files

**New:** `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_xx.arb` (generated),
`lib/engine/contribution_source.dart`,
`lib/presentation/format/contribution_formatter.dart`,
`test/support/pump_app.dart`, `tool/gen_pseudo_arb.dart`.

**Changed:** `pubspec.yaml`, `lib/main.dart`, `lib/engine/spell_engine.dart`
(7 sites), `lib/engine/level_breakdown.dart`, all 8 files under
`lib/presentation/`, and the 10 test files holding the 47 `MaterialApp`
constructions.

## Consequences for other items

- **Item 56** (rules hints) — the reason for sequencing 80 first. Its strings
  land localised, and its "UI copy vs. catalog data" decision is now partly
  settled: the boundary rule above says hint *frames* are ARB and quoted rules
  text is catalog.
- **Item 80.3** should be amended to name the **third** population (user
  content); it currently records only two.
- **Items 78 / 79** are unaffected in scope, but the boundary rule is the thing
  that makes "locale selects a source edition" implementable rather than
  aspirational.
- **Item 16** (short forms) gains real evidence from the padded pseudo-locale
  instead of the "measure first" it has been blocked on since it was written.
- **Item 58's** 1200px-untested segmented control gets the same evidence.
