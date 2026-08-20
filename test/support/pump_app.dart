import 'package:eruditus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

/// Pumps [child] inside a MaterialApp carrying the localisation delegates.
///
/// Every widget test goes through this rather than building its own
/// MaterialApp: a widget that reads AppLocalizations needs a Localizations
/// ancestor, and [locale] is the seam the pseudo-locale coverage test uses to
/// re-run a screen under `en_XA`.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  List<SingleChildWidget> providers = const [],
  bool wrapInScaffold = true,
}) {
  final body = providers.isEmpty
      ? child
      : MultiBlocProvider(providers: providers, child: child);

  return tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: wrapInScaffold ? Scaffold(body: body) : body,
  ));
}
