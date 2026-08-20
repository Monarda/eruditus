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
}
