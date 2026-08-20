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
      // SingleChildScrollView + Column, not ListView: this content is a
      // small, bounded set of legal notices, and ListView's Sliver-based
      // lazy building left the tail of the notice (including the package
      // licences button) unbuilt and unfindable in widget tests.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        // One title per line, undecorated: the test looks up each book by
        // an exact `find.text` match against `edition.books`.
        for (final title in edition.books) _Body(title),
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
