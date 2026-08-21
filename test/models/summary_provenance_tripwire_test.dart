import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A tripwire for todo item 31, not a test of behaviour anyone wrote.
///
/// `Spell.sourcedSummary` reports a published spell's summary as the
/// rulebook's own words. That is true only because `emit.py` currently builds
/// each summary by truncating the description — so the summary really is a
/// quote. Item 31 replaces them with **ledger-authored** prose, at which
/// point reporting them as verbatim would attribute our words to the
/// rulebook: exactly the failure item 79.3 exists to prevent.
///
/// The same exposure applies to templates and exceptions: `emit.py` builds
/// `spell_templates.json` (`build_template`, line ~387) and
/// `spell_exceptions.json` (`build_exception_spell`, line ~852) summaries
/// with the same `_template_summary`/`_truncated_prose` helpers `_summary`
/// (spells) itself calls, so all three assets are truncated-quote summaries
/// today and all three need the same guard.
///
/// When this test fails, the fix is NOT to change this file. It is to:
///  1. Change `Spell.sourcedSummary` in `lib/models/spell.dart`,
///     `ResolvedTemplate`'s/`ResolvedException`'s summary provenance (via
///     `sourcedFrom` in `lib/presentation/widgets/spell_card.dart` or
///     wherever it has moved to by then), to return
///     `SourcedText.authored(summary)` unconditionally for whichever
///     asset(s) just failed below, and
///  2. Delete this test once every asset it checks passes unconditionally --
///     its job is done.
void main() {
  /// Prefix-of-description sniff test, shared by all three assets: `emit.py`
  /// truncates a description and (for spells only) appends " Level N.", so a
  /// summary's opening -- once that suffix is stripped -- is a prefix of its
  /// description. The suffix must be stripped before truncating to a
  /// fixed-length opening -- otherwise a short prose's summary (e.g. "Turns a
  /// person into a pig. Level 30.", under 60 chars whole) keeps its
  /// " Level N." tail in the comparison and never matches. Templates and
  /// exceptions never carry that suffix (`_template_summary` omits it), so
  /// the strip is a harmless no-op for them.
  List<String> undermined(List<Map<String, dynamic>> records) {
    final result = <String>[];
    for (final record in records) {
      final summary = record['summary'] as String?;
      final description = record['description'] as String?;
      if (summary == null || description == null) continue;

      final withoutLevelSuffix = summary.replaceFirst(RegExp(r' Level \d+\.$'), '');
      final opening = withoutLevelSuffix.length < 60
          ? withoutLevelSuffix
          : withoutLevelSuffix.substring(0, 60);
      if (!description.startsWith(opening)) result.add(record['id'] as String);
    }
    return result;
  }

  List<Map<String, dynamic>> loadAsset(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as List).cast<Map<String, dynamic>>();

  test('every published spell summary is still derived from its description', () {
    final spells = loadAsset('assets/data/spell_library.json');
    expect(spells, isNotEmpty);

    final result = undermined(spells);
    expect(result, isEmpty,
        reason: 'Item 31 has landed: spell_library.json summaries are no '
            'longer quotes of their descriptions. Change Spell.sourcedSummary '
            'to return SourcedText.authored(summary) unconditionally. Spells: '
            '${result.take(5).join(', ')}');
  });

  test('every published template summary is still derived from its description', () {
    final templates = loadAsset('assets/data/spell_templates.json');
    expect(templates, isNotEmpty);

    // scripts/spell_import/extract_spells.py's hand_authored_templates()
    // merges scripts/spell_import/hand_authored_templates.json in verbatim
    // (todo item 17) -- those two entries never go through
    // build_template/_template_summary at all, so this sniff test's premise
    // doesn't apply to them. (One of the two, tpl-revi-tie-threads-that-bind,
    // in fact fails the prefix check below: its summary is genuinely
    // hand-paraphrased, not a truncated quote, while its provenance is
    // "published" with a citation -- so ResolvedTemplate.summary is already
    // mislabeled verbatim today, independent of item 31. That is a real,
    // separate defect this tripwire cannot itself fix -- see the report for
    // 2026-08-21's text-provenance fixes -- so it is excluded here rather
    // than silently passed.)
    const handAuthored = {
      'tpl-crvi-faerie-chains-familiar-slave',
      'tpl-revi-tie-threads-that-bind',
    };
    final result = undermined(
      templates.where((t) => !handAuthored.contains(t['id'])).toList(),
    );
    expect(result, isEmpty,
        reason: 'spell_templates.json summaries are no longer quotes of '
            'their descriptions -- the same _template_summary/_truncated_prose '
            'exposure as spells, on the template side. Templates: '
            '${result.take(5).join(', ')}');
  });

  test('every published exception summary is still derived from its description', () {
    final exceptions = loadAsset('assets/data/spell_exceptions.json');
    expect(exceptions, isNotEmpty);

    final result = undermined(exceptions);
    expect(result, isEmpty,
        reason: 'spell_exceptions.json summaries are no longer quotes of '
            'their descriptions -- the same _template_summary/_truncated_prose '
            'exposure as spells, on the exception side. Exceptions: '
            '${result.take(5).join(', ')}');
  });
}
