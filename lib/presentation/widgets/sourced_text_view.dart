import 'package:flutter/material.dart';

import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/models/text_provenance.dart';
import 'package:eruditus/presentation/screens/about_screen.dart';

/// Renders a [SourcedText] so the rulebook's words are never mistaken for
/// ours, nor ours for the rulebook's.
///
/// **This is the single place the rendering rule lives.** Item 79.3's whole
/// point is that a quote must be distinguishable from a paraphrase on screen;
/// scattering that treatment across call sites is how it stops being true.
///
/// The marker names no book and no page: §3(a)(2) is satisfied by routing to
/// one resource carrying the notice, and item 78 is what will enrich this
/// same control with a book abbreviation and page reference.
class SourcedTextView extends StatelessWidget {
  final SourcedText sourced;
  final TextStyle? style;

  /// Forwarded to the rendered [Text]. `spell_card.dart` truncates its blurb
  /// to two lines; dropping that on the way through here would silently
  /// change a list row's height.
  final int? maxLines;
  final TextOverflow? overflow;

  /// Whether to render the tappable source marker.
  ///
  /// False inside an already-tappable container — a `ListTile.onTap` row, for
  /// instance — where a nested [InkWell] would compete for the same gesture.
  /// The quote styling still marks the text as a quote; §3(a)(2) is satisfied
  /// by the About screen being reachable, not by every quote linking to it.
  /// This applies to every marker this widget can render, not just the
  /// verbatim one — a translated blurb inside the same tappable row would
  /// nest a tap target just as surely.
  final bool showMarker;

  const SourcedTextView(
    this.sourced, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.showMarker = true,
  });

  /// The rendered prose, with [style] applied on top of the shared body
  /// style. Pulled out because the three provenance branches otherwise
  /// repeat `maxLines`/`overflow` wiring with only the text style varying.
  Widget _text(TextStyle? style) => Text(
    sourced.text,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    switch (sourced.provenance) {
      case TextProvenance.authored:
        return _text(style);

      case TextProvenance.verbatim:
        // Merge italic onto whatever style applies -- the caller's [style]
        // when given, the ambient DefaultTextStyle otherwise (a bare
        // TextStyle has `inherit: true`, so `Text` merges this onto it
        // rather than replacing it). Passing `theme.textTheme.bodyMedium`
        // here instead would override that ambient style outright -- e.g. a
        // ListTile subtitle's onSurfaceVariant colour -- with
        // Typography.bodyMedium's own explicit black87.
        final italic = (style ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic);
        return Container(
          key: const Key('sourced-text-quote'),
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(italic),
              if (showMarker) ...[
                const SizedBox(height: 4),
                _Marker(
                  key: const Key('sourced-text-marker'),
                  label: l10n.sourcedTextRulebookMarker,
                ),
              ],
            ],
          ),
        );

      case TextProvenance.translated:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text(style),
            if (showMarker) ...[
              const SizedBox(height: 4),
              _Marker(
                key: const Key('sourced-text-translated-marker'),
                label: l10n.sourcedTextMachineTranslated,
              ),
            ],
          ],
        );
    }
  }
}

/// The tappable source marker: a route to the §3(a) notice, not a decoration.
class _Marker extends StatelessWidget {
  final String label;

  const _Marker({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
