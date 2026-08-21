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
