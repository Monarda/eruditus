import 'dart:convert';
import 'dart:io';

import 'package:eruditus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_pseudo_arb.dart';
import '../support/pump_app.dart';

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
    expect(result.contains('Imported'), isFalse,
        reason: 'text around a placeholder must still be accented');
  });

  test('pseudoTransform preserves two placeholders and the text between', () {
    final result = pseudoTransform('{technique} {form} spell');

    expect(result.contains('{technique}'), isTrue);
    expect(result.contains('{form}'), isTrue);
    expect(result.contains('spell'), isFalse);
  });

  test('pseudoTransform does not corrupt nested ICU plural syntax', () {
    const plural =
        '{count, plural, =0{none} one{1 spell} other{{count} spells}}';

    final result = pseudoTransform(plural);

    // The ICU keywords gen-l10n parses must survive byte-identical. A boolean
    // in-placeholder flag clears on the first inner closing brace and accents
    // `other`, breaking codegen for every locale.
    expect(result.contains('plural,'), isTrue);
    expect(result.contains('other{'), isTrue);
    expect(result.contains('=0{'), isTrue);
    expect(result.contains('one{'), isTrue);
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

  test('app_en_XA.arb is exactly what the generator produces', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    final committed = File('lib/l10n/app_en_XA.arb').readAsStringSync();

    expect(committed, generatePseudoArb(en),
        reason: 'app_en_XA.arb is stale — run: dart run tool/gen_pseudo_arb.dart');
  });

  testWidgets('the en_XA locale returns transformed strings', (tester) async {
    late AppLocalizations l10n;

    await pumpApp(
      tester,
      Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const SizedBox.shrink();
      }),
      locale: const Locale('en', 'XA'),
    );

    expect(l10n.spellLevel, isNot('Spell level'));
    expect(l10n.spellLevel.startsWith('['), isTrue);
  });

  testWidgets('pumpApp honours an explicit locale', (tester) async {
    await pumpApp(
      tester,
      Builder(builder: (context) => Text(Localizations.localeOf(context).toString())),
      locale: const Locale('en', 'XA'),
    );

    expect(find.text('en_XA'), findsOneWidget);
  });
}
