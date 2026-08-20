import 'package:eruditus/engine/contribution_source.dart';
import 'package:eruditus/l10n/app_localizations.dart';
import 'package:eruditus/presentation/format/contribution_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  late AppLocalizations l10n;

  Future<void> loadL10n(WidgetTester tester, {Locale? locale}) async {
    await pumpApp(
      tester,
      Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const SizedBox.shrink();
      }),
      locale: locale ?? const Locale('en'),
    );
  }

  testWidgets('formats a base effect', (tester) async {
    await loadL10n(tester);
    expect(formatContribution(l10n, const BaseEffectContribution('Create flame')),
        'Base effect · Create flame');
  });

  testWidgets('formats a slot at its reference', (tester) async {
    await loadL10n(tester);
    expect(
        formatContribution(l10n,
            const SlotContribution(slot: ParameterSlot.range, actualName: 'Voice')),
        'Range · Voice');
  });

  testWidgets('formats a slot against a differing reference', (tester) async {
    await loadL10n(tester);
    expect(
        formatContribution(
            l10n,
            const SlotContribution(
                slot: ParameterSlot.range,
                actualName: 'Personal',
                referenceName: 'Touch')),
        'Range · Personal (guideline assumes Touch)');
  });

  testWidgets('formats a requisite', (tester) async {
    await loadL10n(tester);
    expect(
        formatContribution(l10n,
            const RequisiteContribution(art: 'Vim', parameterName: 'adding')),
        'Requisite · Vim, adding');
  });

  testWidgets('formats a modifier', (tester) async {
    await loadL10n(tester);
    expect(
        formatContribution(
            l10n,
            const ModifierContribution(
                modifierName: 'Material difficulty',
                optionLabel: 'Metal or gemstone')),
        'Material difficulty · Metal or gemstone');
  });

  testWidgets('formats an adjustment', (tester) async {
    await loadL10n(tester);
    expect(formatContribution(l10n, const AdjustmentContribution('storyguide said so')),
        'Adjustment · storyguide said so');
  });

  testWidgets('a user note is NOT pseudo-transformed under en_XA', (tester) async {
    await loadL10n(tester, locale: const Locale('en', 'XA'));

    final result =
        formatContribution(l10n, const AdjustmentContribution('storyguide said so'));

    expect(result.contains('storyguide said so'), isTrue,
        reason: 'user content renders verbatim in every locale');
    expect(result.startsWith('['), isTrue,
        reason: 'but the frame around it is still localised');
  });
}
