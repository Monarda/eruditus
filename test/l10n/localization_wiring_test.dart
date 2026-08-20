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
