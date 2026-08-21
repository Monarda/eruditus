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

  testWidgets('showMarker: false keeps the quote styling but drops the tap target',
      (tester) async {
    await pumpApp(tester, SourcedTextView(quoted, showMarker: false));

    expect(find.byKey(const Key('sourced-text-quote')), findsOneWidget,
        reason: 'the text is still a quote and must still look like one');
    expect(find.byKey(const Key('sourced-text-marker')), findsNothing);
  });

  testWidgets('maxLines and overflow reach the rendered Text', (tester) async {
    await pumpApp(
      tester,
      SourcedTextView(quoted, maxLines: 2, overflow: TextOverflow.ellipsis),
    );

    final text = tester.widget<Text>(find.text('The rulebook says this.'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('showMarker: false also drops the translated marker, not just the verbatim one',
      (tester) async {
    await pumpApp(
      tester,
      SourcedTextView(
        SourcedText.translated('El libro dice esto.', const [citation]),
        showMarker: false,
      ),
    );

    expect(find.text('El libro dice esto.'), findsOneWidget);
    expect(find.byKey(const Key('sourced-text-translated-marker')), findsNothing,
        reason: 'showMarker gates every marker this widget can render, not '
            'only the verbatim one — a translated blurb in a tappable row '
            'would otherwise still nest a competing tap target');
  });
}
