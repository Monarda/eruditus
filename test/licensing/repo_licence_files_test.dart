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
