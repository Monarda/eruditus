# Licensing and Attribution (item 79, plan A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give eruditus the licence files and in-app attribution that CC BY-SA 4.0 §3(a) requires for the rulebook text it already ships, and record the MIT/CC BY-SA split over the repo.

**Architecture:** The attribution notice is defined once as const Dart data in `lib/licensing/attribution.dart`. `NOTICE.md` and the in-app About screen are both rendered from — and tested against — that single source, so the two cannot drift. The About screen is a plain `StatelessWidget` reached from an `IconButton` in the Configuration screen's `AppBar`; it needs no bloc, no repository and no database.

**Tech Stack:** Flutter (Material 3), `flutter_gen`/gen-l10n ARB localisation, `flutter_test` widget tests, `dart:io` for the file-content tests.

**Spec:** `docs/superpowers/specs/2026-08-20-quoting-rules-text-design.md`. This plan implements sections 1, 2 and 3 (todo items 79.1 and 79.2) only. Section 4's per-string provenance (79.3) is plan B and is deliberately out of scope here.

## Global Constraints

- **Never run `dart format`.** It is not clean in this repo. Hand-indent to match surrounding code and check your work with `git diff -w`.
- **`flutter analyze` must exit 0** at the end of every task.
- **Run `flutter pub get` before `flutter analyze` or `flutter test`** in a fresh checkout. `lib/l10n/app_localizations*.dart` are gen-l10n output and gitignored; without codegen, `AppLocalizations` will not resolve.
- **If `flutter test` fails with a `sqlite3.dll` permissions error**, the cause is stale `flutter_tester` processes holding the file. Kill them and re-run.
- **ARB key naming:** camelCase, prefixed by the screen or concept the key belongs to. Every key added by this plan uses the `about` prefix. `@description` is mandatory on any key carrying a placeholder; a key with no placeholder needs none.
- **The attribution notice body must NOT enter ARB.** DECISIONS.md's boundary rule: ARB holds the vocabulary that labels the interface; rulebook and licence content does not. Screen chrome (title, button labels, section headings) goes in ARB. Creator names, the copyright line, the licence name, the URIs, the modification note and the disclaimer text are content and stay as const Dart data.
- **Do not add the notice body to `_mustNotSurvive`** in `test/l10n/pseudo_locale_coverage_test.dart`. It is a deliberately-English population, like the four realm values.
- **No new pub dependencies.** In particular no `url_launcher` (§3(a)(1)(A)(v) requires the URI be *provided*, not clickable) and no `package_info_plus`.
- **Pinned rulebook commit:** `ffc1c6b`. It appears in the source URI and is asserted by tests.

## Deviations from the spec, decided while planning

Two, both recorded here so an implementer does not "fix" them back:

1. **The About screen shows no app version.** The spec listed one. Flutter cannot read `pubspec.yaml`'s version at runtime without `package_info_plus`, and hardcoding a second copy of the version string in Dart is the write-only duplication todo item 33 objects to. A version is not required by §3(a). Dropped.
2. **The entry point is an `AppBar` action, not a `ListTile` at the foot of the Configuration screen.** The spec assumed a scrollable settings list. `configuration_screen.dart` is actually a `DefaultTabController` with two tabs and a `TabBarView` body — it has no shared foot, and a `ListTile` would have to live inside either the Effects tab or the Parameters tab, which is wrong in both. An `IconButton` in the existing `AppBar` is the correct affordance for this layout.

---

### Task 1: Attribution as const data

The single source of truth for the §3(a) notice. Pure Dart with no Flutter, no I/O and no consumers yet, so it can be tested in isolation before anything renders it.

**Files:**
- Create: `lib/licensing/attribution.dart`
- Test: `test/licensing/attribution_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class SourceEditionAttribution` with `const` constructor and final fields `String creators`, `String copyrightNotice`, `String licenceName`, `String licenceUri`, `String sourceUri`, `String modificationNote`, `List<String> books`.
  - `const SourceEditionAttribution arsMagicaAttribution`
  - `const List<SourceEditionAttribution> sourceEditions`
  - `const String warrantyDisclaimerNotice`
  - `const String warrantyDisclaimerFullText`
  - `const String trademarkNotice`
  - `const String endorsementNotice`
  - `const String repoLicenceSummary`
  - `const String pinnedRulebookCommit`

- [ ] **Step 1: Write the failing test**

Create `test/licensing/attribution_test.dart`:

```dart
import 'package:eruditus/licensing/attribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the Ars Magica attribution carries every CC BY-SA 4.0 §3(a) part', () {
    const a = arsMagicaAttribution;

    test('(A)(i) identifies the creators, including the transcriber', () {
      expect(a.creators, contains('Atlas Games'));
      expect(a.creators, contains('OriginalMadman'),
          reason: '§3(a)(1)(A)(i) covers "any others designated to receive '
              'attribution" — the markdown transcription is credited in the '
              'source material and must be retained');
    });

    test('(A)(ii) carries a copyright notice with the years', () {
      expect(a.copyrightNotice, contains('1993'));
      expect(a.copyrightNotice, contains('2024'));
      expect(a.copyrightNotice, contains('Trident'));
    });

    test('(A)(iii) names the licence', () {
      expect(a.licenceName, 'Creative Commons Attribution-ShareAlike 4.0 International');
    });

    test('(A)(v) and (C) give a URI for the material and for the licence', () {
      expect(a.sourceUri, contains('github.com/OriginalMadman/Ars-Magica-Open-License'));
      expect(a.sourceUri, contains(pinnedRulebookCommit),
          reason: 'the URI must identify the material we actually adapted, '
              'not a moving branch — see todo item 30');
      expect(a.licenceUri, 'https://creativecommons.org/licenses/by-sa/4.0/');
    });

    test('(B) indicates that we modified the material', () {
      expect(a.modificationNote, isNotEmpty);
      expect(a.modificationNote.toLowerCase(), contains('modif'));
    });

    test('it names the books actually shipped in assets/data', () {
      expect(a.books, containsAll(<String>[
        'Ars Magica Fifth Edition',
        'Ars Magica 5e - Houses of Hermes: Mystery Cults',
      ]));
    });
  });

  test('(A)(iv) is a notice referring to the disclaimer of warranties', () {
    expect(warrantyDisclaimerNotice, isNotEmpty);
    expect(warrantyDisclaimerNotice.toLowerCase(), contains('warrant'));
  });

  test('the full §5 disclaimer text is available as well', () {
    expect(warrantyDisclaimerFullText, contains('AS-IS'));
    expect(warrantyDisclaimerFullText, contains('MERCHANTABILITY'));
  });

  test('trademarks are disclaimed, because §2(b)(2) does not license them', () {
    expect(trademarkNotice.toLowerCase(), contains('trademark'));
    expect(trademarkNotice, contains('Ars Magica'));
  });

  test('endorsement is disclaimed, per §2(a)(6) and §5', () {
    expect(endorsementNotice.toLowerCase(), contains('endorse'));
    expect(endorsementNotice, contains('Atlas Games'));
  });

  test('the repo licence summary states both halves of the split', () {
    expect(repoLicenceSummary, contains('MIT'));
    expect(repoLicenceSummary, contains('CC BY-SA 4.0'));
    expect(repoLicenceSummary, contains('assets/data'));
  });

  test('sourceEditions is a list, so a second edition is additive', () {
    expect(sourceEditions, contains(arsMagicaAttribution));
    expect(sourceEditions, isA<List<SourceEditionAttribution>>());
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/licensing/attribution_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'eruditus' ... attribution.dart` / "Target of URI doesn't exist".

- [ ] **Step 3: Write the implementation**

Create `lib/licensing/attribution.dart`:

```dart
/// The attribution CC BY-SA 4.0 §3(a) requires eruditus to carry for the
/// rulebook text it ships, defined once so `NOTICE.md` and the About screen
/// cannot drift apart.
///
/// **This is content, not chrome, and never enters ARB.** See DECISIONS.md,
/// "Internationalisation": ARB holds the vocabulary that labels the interface;
/// a licensor's own copyright line, creator credit and disclaimer are not ours
/// to translate. The About screen's headings and buttons *are* chrome and do
/// go through `AppLocalizations`.
library;

/// The rulebook checkout these assets were extracted from. Named rather than
/// a branch, so §3(a)(1)(A)(v)'s URI identifies the material actually adapted
/// — the same discipline as `source.lock` (todo item 30).
const String pinnedRulebookCommit = 'ffc1c6b';

/// One licensed work the catalog draws on, with the §3(a)(1) attribution that
/// must be retained *for that work*.
///
/// A list rather than a single notice because §3(a)(1)(A)(i) requires
/// retaining creator identification as supplied *with the material*: a
/// separately published edition — a translation, say — comes with its own
/// translators and its own copyright line, and needs its own entry rather
/// than an appendix to this one.
class SourceEditionAttribution {
  final String creators;
  final String copyrightNotice;
  final String licenceName;
  final String licenceUri;
  final String sourceUri;
  final String modificationNote;

  /// Titles as they appear in `assets/data/books.json`.
  final List<String> books;

  const SourceEditionAttribution({
    required this.creators,
    required this.copyrightNotice,
    required this.licenceName,
    required this.licenceUri,
    required this.sourceUri,
    required this.modificationNote,
    required this.books,
  });
}

const SourceEditionAttribution arsMagicaAttribution = SourceEditionAttribution(
  creators: 'Trident, Inc. d/b/a Atlas Games®. '
      'Open License Markdown version by OriginalMadman.',
  copyrightNotice: 'Based on the material for Ars Magica, © 1993–2024, '
      'licensed by Trident, Inc. d/b/a Atlas Games®.',
  licenceName: 'Creative Commons Attribution-ShareAlike 4.0 International',
  licenceUri: 'https://creativecommons.org/licenses/by-sa/4.0/',
  sourceUri: 'https://github.com/OriginalMadman/Ars-Magica-Open-License'
      '/tree/$pinnedRulebookCommit',
  modificationNote: 'This material has been modified: guideline and spell text '
      'was transcribed, restructured into JSON, assigned identifiers, and in '
      'places corrected. The source itself is a corrected transcription of the '
      'published books. See scripts/spell_import/ for what the extractor does.',
  books: <String>[
    'Ars Magica Fifth Edition',
    'Ars Magica 5e - Houses of Hermes: Mystery Cults',
  ],
);

/// Every source edition the shipped catalog draws on. Adding one is additive.
const List<SourceEditionAttribution> sourceEditions = <SourceEditionAttribution>[
  arsMagicaAttribution,
];

/// §3(a)(1)(A)(iv) asks only for "a notice that refers to the disclaimer of
/// warranties", which this is. [warrantyDisclaimerFullText] goes further than
/// required and reproduces §5 itself.
const String warrantyDisclaimerNotice =
    'The Licensed Material is offered as-is and as-available, and the licensor '
    'makes no representations or warranties of any kind concerning it. See '
    'Section 5 of the licence for the full disclaimer of warranties and '
    'limitation of liability.';

/// CC BY-SA 4.0 §5(a), reproduced verbatim.
const String warrantyDisclaimerFullText =
    'UNLESS OTHERWISE SEPARATELY UNDERTAKEN BY THE LICENSOR, TO THE EXTENT '
    'POSSIBLE, THE LICENSOR OFFERS THE LICENSED MATERIAL AS-IS AND '
    'AS-AVAILABLE, AND MAKES NO REPRESENTATIONS OR WARRANTIES OF ANY KIND '
    'CONCERNING THE LICENSED MATERIAL, WHETHER EXPRESS, IMPLIED, STATUTORY, OR '
    'OTHER. THIS INCLUDES, WITHOUT LIMITATION, WARRANTIES OF TITLE, '
    'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, '
    'ABSENCE OF LATENT OR OTHER DEFECTS, ACCURACY, OR THE PRESENCE OR ABSENCE '
    'OF ERRORS, WHETHER OR NOT KNOWN OR DISCOVERABLE. WHERE DISCLAIMERS OF '
    'WARRANTIES ARE NOT ALLOWED IN FULL OR IN PART, THIS DISCLAIMER MAY NOT '
    'APPLY TO YOU.';

/// §2(b)(2): the licence grants no trademark rights. The text is licensed;
/// the marks are not.
const String trademarkNotice =
    'No trademark rights are granted by the licence. "Ars Magica", "Atlas '
    'Games" and related marks belong to their owners. Order of Hermes, '
    'Tremere, Doissetep and Grimgroth are trademarks of Paradox Interactive '
    'AB. Eruditus is not affiliated with any of them.';

/// §2(a)(6) and §5: nothing here may imply the licensor endorses this app.
const String endorsementNotice =
    'Eruditus is an unofficial, fan-made tool. Nothing in it is endorsed or '
    'sponsored by Atlas Games or by any other rights holder.';

/// How the repository itself is licensed — the §3(b) answer.
const String repoLicenceSummary =
    'Eruditus is licensed in two halves. The software — lib/, test/, '
    'integration_test/, tool/ and the Python extractor — is MIT licensed. The '
    'rulebook-derived content in assets/data and in '
    'scripts/spell_import/resolutions.json is Adapted Material under CC BY-SA '
    '4.0 and carries that licence. See LICENSE and NOTICE.md.';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/licensing/attribution_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 5: Check analyze is clean and commit**

```bash
flutter analyze
git add lib/licensing/attribution.dart test/licensing/attribution_test.dart
git commit -m "feat: define the CC BY-SA 4.0 attribution as const data

One source of truth for the §3(a) notice so NOTICE.md and the About
screen cannot drift. A list of source editions rather than one notice,
because §3(a)(1)(A)(i) requires retaining creator identification as
supplied with each work.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Repo licence files

The files a visitor to the repository sees. Tested against Task 1's data so the two cannot diverge.

**Files:**
- Create: `LICENSE`, `LICENSES/CC-BY-SA-4.0.txt`, `NOTICE.md`, `assets/data/LICENSE`
- Modify: `README.md`, `pubspec.yaml`
- Test: `test/licensing/repo_licence_files_test.dart`

**Interfaces:**
- Consumes: `lib/licensing/attribution.dart` — `arsMagicaAttribution`, `warrantyDisclaimerNotice`, `trademarkNotice`, `endorsementNotice`, `repoLicenceSummary`, `pinnedRulebookCommit`.
- Produces: `NOTICE.md` at the repo root, whose content the About screen mirrors.

- [ ] **Step 1: Write the failing test**

Create `test/licensing/repo_licence_files_test.dart`:

```dart
import 'dart:io';

import 'package:eruditus/licensing/attribution.dart';
import 'package:flutter_test/flutter_test.dart';

/// These read repo files directly rather than assets: the obligation is on the
/// distributed repository, not on the built app bundle. The same shape as
/// test/l10n/pseudo_arb_sync_test.dart, which also reads source files.
void main() {
  test('the MIT licence covers the software half', () {
    final licence = File('LICENSE').readAsStringSync();

    expect(licence, contains('MIT License'));
    expect(licence, contains('Permission is hereby granted, free of charge'));
    expect(licence, contains('2026'));
  });

  test('the full CC BY-SA 4.0 text is included, per §3(a)(1)(C)', () {
    final cc = File('LICENSES/CC-BY-SA-4.0.txt').readAsStringSync();

    expect(cc, contains('Attribution-ShareAlike 4.0 International'));
    expect(cc, contains('Section 3 -- License Conditions.'),
        reason: '§3(a)(1)(C) requires the licence text or a URI; we include '
            'the text, so it must actually be the licence and not a stub');
    expect(cc.length, greaterThan(10000));
  });

  group('NOTICE.md', () {
    final notice = File('NOTICE.md').readAsStringSync();

    test('states both halves of the licence split', () {
      expect(notice, contains('MIT'));
      expect(notice, contains('CC BY-SA 4.0'));
      expect(notice, contains('assets/data'));
    });

    test('carries every §3(a) part from the attribution data', () {
      expect(notice, contains(arsMagicaAttribution.copyrightNotice));
      expect(notice, contains(arsMagicaAttribution.licenceName));
      expect(notice, contains(arsMagicaAttribution.licenceUri));
      expect(notice, contains(arsMagicaAttribution.sourceUri));
      expect(notice, contains('OriginalMadman'));
      expect(notice, contains(pinnedRulebookCommit));
    });

    test('indicates the material was modified, per §3(a)(1)(B)', () {
      expect(notice, contains(arsMagicaAttribution.modificationNote));
    });

    test('refers to the disclaimer of warranties, per §3(a)(1)(A)(iv)', () {
      expect(notice, contains(warrantyDisclaimerNotice));
    });

    test('disclaims trademarks and endorsement', () {
      expect(notice, contains(trademarkNotice));
      expect(notice, contains(endorsementNotice));
    });

    test('names every book in the shipped catalog', () {
      for (final title in arsMagicaAttribution.books) {
        expect(notice, contains(title));
      }
    });
  });

  test('assets/data carries a licence marker at the boundary it applies to', () {
    final stub = File('assets/data/LICENSE').readAsStringSync();

    expect(stub, contains('CC BY-SA 4.0'));
    expect(stub, contains('LICENSES/CC-BY-SA-4.0.txt'));
  });

  test('pubspec no longer describes itself as a new Flutter project', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, isNot(contains('A new Flutter project')));
    expect(pubspec, contains('Ars Magica'));
  });

  test('the README states the split', () {
    final readme = File('README.md').readAsStringSync();

    expect(readme, contains('CC BY-SA 4.0'));
    expect(readme, contains('MIT'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/licensing/repo_licence_files_test.dart`
Expected: FAIL — `FileSystemException: Cannot open file, path = 'LICENSE'`.

- [ ] **Step 3: Copy in the CC BY-SA 4.0 text**

```bash
mkdir -p LICENSES
cp "../Ars-Magica-Open-License/LICENSE.md" LICENSES/CC-BY-SA-4.0.txt
```

Verify it is the full licence and not a truncated copy:

```bash
wc -l LICENSES/CC-BY-SA-4.0.txt   # expect 427
grep -c "Section 3 -- License Conditions." LICENSES/CC-BY-SA-4.0.txt   # expect 1
```

- [ ] **Step 4: Write `LICENSE`**

Create `LICENSE` with exactly this content:

```
MIT License

Copyright (c) 2026 Ivan Finch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

NOTE: This MIT licence covers the software only. The rulebook-derived content
in assets/data/ and scripts/spell_import/resolutions.json is Adapted Material
under Creative Commons Attribution-ShareAlike 4.0 International. See NOTICE.md.
```

- [ ] **Step 5: Write `NOTICE.md`**

Create `NOTICE.md`. Every quoted string below must match `lib/licensing/attribution.dart` **character for character** — Task 2's test compares them with `contains`.

```markdown
# Notices and Attribution

## How eruditus is licensed

Eruditus is licensed in two halves.

| Path | Licence |
|---|---|
| `lib/`, `test/`, `integration_test/`, `tool/`, `scripts/spell_import/*.py` | MIT — see `LICENSE` |
| `assets/data/*.json` | CC BY-SA 4.0 — see `LICENSES/CC-BY-SA-4.0.txt` |
| `scripts/spell_import/resolutions.json` | CC BY-SA 4.0 — it quotes design lines |
| `docs/` | follows the text it quotes |

The software is an independent work that reads a data file. The data files are
Adapted Material derived from the Ars Magica Open License material and carry
CC BY-SA 4.0 accordingly.

## Attribution for the licensed material

### Ars Magica

**Books used:**

- Ars Magica Fifth Edition
- Ars Magica 5e - Houses of Hermes: Mystery Cults

**Creators:** Trident, Inc. d/b/a Atlas Games®. Open License Markdown version by OriginalMadman.

**Copyright:** Based on the material for Ars Magica, © 1993–2024, licensed by Trident, Inc. d/b/a Atlas Games®.

**Licence:** Creative Commons Attribution-ShareAlike 4.0 International — https://creativecommons.org/licenses/by-sa/4.0/

**Source:** https://github.com/OriginalMadman/Ars-Magica-Open-License/tree/ffc1c6b

**Modifications:** This material has been modified: guideline and spell text was transcribed, restructured into JSON, assigned identifiers, and in places corrected. The source itself is a corrected transcription of the published books. See scripts/spell_import/ for what the extractor does.

## Disclaimer of warranties

The Licensed Material is offered as-is and as-available, and the licensor makes no representations or warranties of any kind concerning it. See Section 5 of the licence for the full disclaimer of warranties and limitation of liability.

## Trademarks

No trademark rights are granted by the licence. "Ars Magica", "Atlas Games" and related marks belong to their owners. Order of Hermes, Tremere, Doissetep and Grimgroth are trademarks of Paradox Interactive AB. Eruditus is not affiliated with any of them.

## No endorsement

Eruditus is an unofficial, fan-made tool. Nothing in it is endorsed or sponsored by Atlas Games or by any other rights holder.
```

- [ ] **Step 6: Write `assets/data/LICENSE`**

```
The JSON catalogs in this directory are Adapted Material under Creative
Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0), not under
the repository's MIT licence.

Full licence text: LICENSES/CC-BY-SA-4.0.txt
Attribution and modification notice: NOTICE.md
```

- [ ] **Step 7: Update `pubspec.yaml` and `README.md`**

In `pubspec.yaml`, replace the `description:` line:

```yaml
description: "A spell-design calculator for Ars Magica (Definitive Edition)."
```

Leave `publish_to: 'none'` alone — this is an application, not a pub package.

In `README.md`, add this section immediately after the `## Layout` table and before `## Running`:

```markdown
## Licence

Eruditus is licensed in two halves.

| Path | Licence |
|---|---|
| `lib/`, `test/`, `integration_test/`, `tool/`, `scripts/spell_import/*.py` | MIT — see `LICENSE` |
| `assets/data/*.json` | CC BY-SA 4.0 — see `LICENSES/CC-BY-SA-4.0.txt` |
| `scripts/spell_import/resolutions.json` | CC BY-SA 4.0 — it quotes design lines |
| `docs/` | follows the text it quotes |

The catalogs are Adapted Material derived from the Ars Magica Open License
material, © 1993–2024 Trident, Inc. d/b/a Atlas Games®, and carry CC BY-SA 4.0
accordingly. Full attribution, modification notice and disclaimers are in
[NOTICE.md](NOTICE.md). Eruditus is an unofficial, fan-made tool and is not
endorsed by Atlas Games.
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/licensing/repo_licence_files_test.dart`
Expected: PASS, 10 tests.

If a `contains` assertion fails, the cause is almost always a typographic difference between `NOTICE.md` and `attribution.dart` — an ASCII hyphen against an en dash, or `(c)` against `©`. Fix `NOTICE.md` to match the Dart, not the other way round.

- [ ] **Step 9: Check analyze is clean and commit**

```bash
flutter analyze
git add LICENSE LICENSES NOTICE.md assets/data/LICENSE README.md pubspec.yaml test/licensing/repo_licence_files_test.dart
git commit -m "feat: license the repo — MIT for code, CC BY-SA 4.0 for catalog data

The app has shipped verbatim rulebook text since the import landed and
the repo carried no LICENSE at all. Records the split on §1(b)'s
Collection / Adapted Material distinction and carries the full §3(a)
notice, tested against lib/licensing/attribution.dart so the two
cannot drift.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: The About & Licences screen

**Files:**
- Create: `lib/presentation/screens/about_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_en_XA.arb`
- Test: `test/presentation/screens/about_screen_test.dart`

**Interfaces:**
- Consumes: `lib/licensing/attribution.dart` (all consts from Task 1); `pumpApp` from `test/support/pump_app.dart`.
- Produces: `class AboutScreen extends StatelessWidget` with a `const AboutScreen({super.key})` constructor. Task 4 pushes it.

- [ ] **Step 1: Add the ARB chrome keys**

Add to `lib/l10n/app_en.arb`. These are chrome, so they belong in ARB; none takes a placeholder, so none needs an `@description`.

```json
  "aboutTitle": "About & Licences",
  "aboutHowLicensedHeading": "How eruditus is licensed",
  "aboutAttributionHeading": "Attribution",
  "aboutBooksUsedHeading": "Books used",
  "aboutCreatorsHeading": "Creators",
  "aboutCopyrightHeading": "Copyright",
  "aboutLicenceHeading": "Licence",
  "aboutSourceHeading": "Source",
  "aboutModificationsHeading": "Modifications",
  "aboutDisclaimerHeading": "Disclaimer of warranties",
  "aboutTrademarksHeading": "Trademarks",
  "aboutEndorsementHeading": "No endorsement",
  "aboutPackageLicencesButton": "Open-source package licences",
```

- [ ] **Step 2: Regenerate the pseudo-locale ARB and codegen**

```bash
dart run tool/gen_pseudo_arb.dart
flutter pub get
```

Then confirm the sync test still passes:

Run: `flutter test test/l10n/pseudo_arb_sync_test.dart`
Expected: PASS.

- [ ] **Step 3: Write the failing test**

Create `test/presentation/screens/about_screen_test.dart`:

```dart
import 'package:eruditus/licensing/attribution.dart';
import 'package:eruditus/presentation/screens/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

/// Finds [text] even when it is one of several strings in a scrolling column,
/// by scrolling until it is laid out. `find.text` alone fails on off-screen
/// children of a ListView.
Future<void> expectTextEventually(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.text(text), findsOneWidget);
}

void main() {
  testWidgets('renders every §3(a) part of the notice', (tester) async {
    await pumpApp(tester, const AboutScreen(), wrapInScaffold: false);
    await tester.pumpAndSettle();

    // (A)(i) creators, (A)(ii) copyright, (A)(iii) licence name,
    // (A)(v) source URI, (B) modification note.
    await expectTextEventually(tester, arsMagicaAttribution.creators);
    await expectTextEventually(tester, arsMagicaAttribution.copyrightNotice);
    await expectTextEventually(tester, arsMagicaAttribution.licenceName);
    await expectTextEventually(tester, arsMagicaAttribution.sourceUri);
    await expectTextEventually(tester, arsMagicaAttribution.modificationNote);

    // (A)(iv) a notice referring to the disclaimer of warranties.
    await expectTextEventually(tester, warrantyDisclaimerNotice);

    // (C) the licence URI. The full text ships at LICENSES/CC-BY-SA-4.0.txt.
    await expectTextEventually(tester, arsMagicaAttribution.licenceUri);
  });

  testWidgets('names every book the catalog draws on', (tester) async {
    await pumpApp(tester, const AboutScreen(), wrapInScaffold: false);
    await tester.pumpAndSettle();

    for (final title in arsMagicaAttribution.books) {
      await expectTextEventually(tester, title);
    }
  });

  testWidgets('disclaims trademarks and endorsement', (tester) async {
    await pumpApp(tester, const AboutScreen(), wrapInScaffold: false);
    await tester.pumpAndSettle();

    await expectTextEventually(tester, trademarkNotice);
    await expectTextEventually(tester, endorsementNotice);
  });

  testWidgets('states how eruditus itself is licensed', (tester) async {
    await pumpApp(tester, const AboutScreen(), wrapInScaffold: false);
    await tester.pumpAndSettle();

    await expectTextEventually(tester, repoLicenceSummary);
  });

  testWidgets('URIs are selectable, since §3(a)(1)(A)(v) needs them copyable',
      (tester) async {
    await pumpApp(tester, const AboutScreen(), wrapInScaffold: false);
    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('offers the package licence page', (tester) async {
    await pumpApp(tester, const AboutScreen(), wrapInScaffold: false);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-package-licences')), findsOneWidget);
  });

  testWidgets('the notice survives the pseudo-locale untranslated',
      (tester) async {
    await pumpApp(
      tester,
      const AboutScreen(),
      locale: const Locale('en', 'XA'),
      wrapInScaffold: false,
    );
    await tester.pumpAndSettle();

    // Licence content is a deliberately-English population, like the four
    // realm values: it must NOT be routed through ARB. See DECISIONS.md,
    // "Internationalisation".
    await expectTextEventually(tester, arsMagicaAttribution.copyrightNotice);
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/presentation/screens/about_screen_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:eruditus/presentation/screens/about_screen.dart'".

- [ ] **Step 5: Write the implementation**

Create `lib/presentation/screens/about_screen.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/licensing/attribution.dart';

/// Where CC BY-SA 4.0 §3(a) attribution lives in the app.
///
/// §3(a)(2) allows satisfying the attribution conditions "in any reasonable
/// manner based on the medium", explicitly including by linking to one
/// resource that carries the required information — so quoted rules text
/// elsewhere in the app needs only a route here, not a notice of its own.
///
/// **Headings are chrome and come from ARB; the notice body is content and
/// does not.** A licensor's copyright line and creator credit are not ours to
/// translate. See DECISIONS.md, "Internationalisation".
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Heading(l10n.aboutHowLicensedHeading),
          const _Body(repoLicenceSummary),
          const SizedBox(height: 24),
          _Heading(l10n.aboutAttributionHeading),
          for (final edition in sourceEditions) _Edition(edition, l10n: l10n),
          const SizedBox(height: 24),
          _Heading(l10n.aboutDisclaimerHeading),
          const _Body(warrantyDisclaimerNotice),
          const SizedBox(height: 24),
          _Heading(l10n.aboutTrademarksHeading),
          const _Body(trademarkNotice),
          const SizedBox(height: 24),
          _Heading(l10n.aboutEndorsementHeading),
          const _Body(endorsementNotice),
          const SizedBox(height: 24),
          OutlinedButton(
            key: const Key('about-package-licences'),
            onPressed: () => showLicensePage(context: context),
            child: Text(l10n.aboutPackageLicencesButton),
          ),
        ],
      ),
    );
  }
}

class _Edition extends StatelessWidget {
  final SourceEditionAttribution edition;
  final AppLocalizations l10n;

  const _Edition(this.edition, {required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubHeading(l10n.aboutBooksUsedHeading),
        for (final title in edition.books) _Body('• $title'),
        _SubHeading(l10n.aboutCreatorsHeading),
        _Body(edition.creators),
        _SubHeading(l10n.aboutCopyrightHeading),
        _Body(edition.copyrightNotice),
        _SubHeading(l10n.aboutLicenceHeading),
        _Body(edition.licenceName),
        // Selectable rather than tappable: §3(a)(1)(A)(v) requires the URI be
        // provided, not clickable, and url_launcher would add a dependency
        // plus Android `queries` and iOS plist configuration for nothing.
        SelectableText(edition.licenceUri),
        _SubHeading(l10n.aboutSourceHeading),
        SelectableText(edition.sourceUri),
        _SubHeading(l10n.aboutModificationsHeading),
        _Body(edition.modificationNote),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _SubHeading extends StatelessWidget {
  final String text;

  const _SubHeading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _Body extends StatelessWidget {
  final String text;

  const _Body(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/presentation/screens/about_screen_test.dart`
Expected: PASS, 7 tests.

If `scrollUntilVisible` throws `StateError: No element`, the string in the test does not match the string in `attribution.dart`. Compare them, do not loosen the matcher.

- [ ] **Step 7: Check analyze is clean and commit**

```bash
flutter analyze
git add lib/presentation/screens/about_screen.dart lib/l10n/app_en.arb lib/l10n/app_en_XA.arb test/presentation/screens/about_screen_test.dart
git commit -m "feat: add the About & Licences screen

Carries the full §3(a) notice, per source edition, so quoted rules text
elsewhere needs only a route here — §3(a)(2) permits satisfying the
conditions by linking to one resource that carries them.

Headings come from ARB; the notice body deliberately does not, and a
pseudo-locale test asserts it stays English.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Wire it up

Makes the screen reachable, registers the notice with Flutter's own licence machinery, and extends the standing pseudo-locale guard to cover the new screen.

**Files:**
- Modify: `lib/presentation/screens/configuration_screen.dart` (the `AppBar` at lines 34-41)
- Modify: `lib/main.dart` (inside `main()`, before `runApp`)
- Modify: `test/l10n/pseudo_locale_coverage_test.dart`
- Test: `test/presentation/screens/configuration_screen_about_test.dart`

**Interfaces:**
- Consumes: `AboutScreen` from Task 3; `arsMagicaAttribution`, `warrantyDisclaimerFullText` from Task 1.
- Produces: nothing further tasks depend on. This is the last task in plan A.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/screens/configuration_screen_about_test.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/presentation/screens/about_screen.dart';
import 'package:eruditus/presentation/screens/configuration_screen.dart';
import 'package:flutter/material.dart';

import '../../support/bloc_factories.dart';
import '../../support/pump_app.dart';

/// Drives the real ConfigurationScreen through a mocked bloc, the same shape
/// `configuration_screen_test.dart` already uses.
void main() {
  setUpAll(registerBlocFallbackValues);

  Future<void> pumpScreen(WidgetTester tester) async {
    final bloc = mockConfigurationBloc(
      initialState: const ConfigurationState(
        status: ConfigurationStatus.loaded,
        effects: [],
        parameters: [],
      ),
    );
    await pumpApp(
      tester,
      const ConfigurationScreen(),
      providers: [BlocProvider<ConfigurationBloc>.value(value: bloc)],
      wrapInScaffold: false,
    );
  }

  testWidgets('the settings screen offers a route to the licences', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('open-about')), findsOneWidget);
  });

  testWidgets('tapping it opens the About screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('open-about')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/screens/configuration_screen_about_test.dart`
Expected: FAIL, both tests — "Expected: exactly one matching candidate / Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'open-about'>]>". The `AppBar` has no `actions:` yet.

- [ ] **Step 3: Add the action to the Configuration screen's AppBar**

In `lib/presentation/screens/configuration_screen.dart`, add the import:

```dart
import 'package:eruditus/presentation/screens/about_screen.dart';
```

and give the existing `AppBar` an `actions:` list. The `AppBar` currently reads:

```dart
        appBar: AppBar(
          title: Text(l10n.configurationTitle),
          bottom: TabBar(tabs: [
```

Insert `actions:` between `title:` and `bottom:`:

```dart
        appBar: AppBar(
          title: Text(l10n.configurationTitle),
          // An AppBar action rather than a row in a settings list: this screen
          // is a two-tab TabBarView with no shared foot, so a ListTile would
          // have to sit inside either the Effects or the Parameters tab.
          actions: [
            IconButton(
              key: const Key('open-about'),
              icon: const Icon(Icons.info_outline),
              tooltip: l10n.aboutTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
          bottom: TabBar(tabs: [
```

- [ ] **Step 4: Register the notice with Flutter's LicenseRegistry**

In `lib/main.dart`, add the imports:

```dart
import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:eruditus/licensing/attribution.dart';
```

Note `kIsWeb` is already imported from `package:flutter/foundation.dart` at line 5 — extend that existing `show` clause rather than adding a second import of the same library.

Then, inside `main()` immediately after `WidgetsFlutterBinding.ensureInitialized();`:

```dart
  // Also surface the Ars Magica attribution through Flutter's own licence
  // machinery, so it is found by anyone reaching licences the standard way
  // (showLicensePage) and not only through the About screen. Two independent
  // routes to the same §3(a) notice.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const <String>['Ars Magica (rulebook content in assets/data)'],
      '${arsMagicaAttribution.creators}\n\n'
      '${arsMagicaAttribution.copyrightNotice}\n\n'
      'Licensed under ${arsMagicaAttribution.licenceName}\n'
      '${arsMagicaAttribution.licenceUri}\n\n'
      'Source: ${arsMagicaAttribution.sourceUri}\n\n'
      '${arsMagicaAttribution.modificationNote}\n\n'
      '$warrantyDisclaimerFullText\n\n'
      '$trademarkNotice\n\n'
      '$endorsementNotice',
    );
  });
```

- [ ] **Step 5: Extend the pseudo-locale coverage guard**

In `test/l10n/pseudo_locale_coverage_test.dart`:

**(a)** Append the new chrome to the existing `const _mustNotSurvive` list (it currently ends with `'Target',` at around line 93):

```dart
  // Item 79's About & Licences screen. Chrome only — see the assertion in
  // that screen's own testWidgets below for the content half.
  'About & Licences',
  'How eruditus is licensed',
  'Disclaimer of warranties',
  'No endorsement',
  'Open-source package licences',
```

`_expectNoneSurvive` runs the whole list against every screen, so these entries are checked on all five and trivially pass on the four that never render them.

**(b)** Add a fifth `testWidgets` block alongside the existing four. `AboutScreen` needs no bloc, so it is the simplest of the five:

```dart
  testWidgets(
    'about screen: no chrome string survives, and the licence notice still '
    'renders in English',
    (tester) async {
      await pumpApp(
        tester,
        const AboutScreen(),
        locale: _pseudoLocale,
        wrapInScaffold: false,
      );
      await tester.pumpAndSettle();

      _expectNoneSurvive('about');

      // The §3(a) notice is a deliberately-English population, the same
      // status as the four realm values in _mustSurvive: a licensor's
      // copyright line and creator credit are not ours to translate, and
      // routing them through ARB would hand a translator a legal notice to
      // reword. See DECISIONS.md, "Internationalisation", and item 79.
      expect(find.textContaining('Atlas Games'), findsWidgets,
          reason: 'licence content is deliberately not routed through ARB');
    },
  );
```

Add the import `import 'package:eruditus/presentation/screens/about_screen.dart';` alongside the four existing screen imports.

**Do not add any part of the notice body to `_mustNotSurvive`.** The copyright line, creator credit, URIs, modification note and disclaimers must stay English; listing them there would make this test fail on correct code, exactly as the file's own comment warns about the realm values.

- [ ] **Step 6: Run the full Dart suite**

```bash
flutter pub get
flutter analyze
flutter test
```

Expected: analyze exits 0; all tests pass. The count should be 782 plus the tests added by Tasks 1-4 — 11 (attribution) + 10 (repo files) + 7 (About screen) + 2 (navigation) + 1 (the fifth pseudo-locale block) = 31, so **813**. Treat a different total as something to explain, not to paper over. If the run fails with a `sqlite3.dll` permissions error, kill stale `flutter_tester` processes and re-run.

- [ ] **Step 7: Verify by hand in the running app**

```bash
flutter run -d windows
```

Go to the Settings tab, tap the ⓘ action, and confirm: the notice renders, the URIs can be selected and copied, and the package-licences button opens Flutter's licence page with an "Ars Magica (rulebook content in assets/data)" entry in the list.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/configuration_screen.dart lib/main.dart test/l10n/pseudo_locale_coverage_test.dart test/presentation/screens/configuration_screen_about_test.dart
git commit -m "feat: reach the About screen, and register the notice with LicenseRegistry

An AppBar action on Settings rather than a settings-list row: that
screen is a two-tab TabBarView with no shared foot. LicenseRegistry
gives the §3(a) notice a second, standard route via showLicensePage.

Extends the pseudo-locale guard to the new screen, asserting its chrome
is localised and its notice body deliberately is not.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## After the plan

Not part of any task above, and not to be done by a task implementer:

- **Close todo items 79.1 and 79.2** in `.superpowers/themes/app.md`, leaving 79.3 open and pointing at plan B. Use the `closing-an-item` skill so the still-binding constraints reach `DECISIONS.md` — at minimum: the MIT/CC BY-SA split rule, the "licence content never enters ARB" boundary, and the per-edition list shape.
- **File the new item** — *Source editions: the work/edition distinction* — against `.superpowers/themes/importer.md`, as described in the spec's "Consequences for other items".
- **Update `.superpowers/STATUS.md`** with the new Dart test count.
- **Write plan B** for section 4 of the spec (todo item 79.3, per-string provenance).
