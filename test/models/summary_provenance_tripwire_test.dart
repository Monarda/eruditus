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
/// When this test fails, the fix is NOT to change this file. It is to change
/// `Spell.sourcedSummary` in `lib/models/spell.dart` to return
/// `SourcedText.authored(summary)` unconditionally, and then delete this
/// test — its job is done.
void main() {
  test('every published summary is still derived from its description', () {
    final spells = (jsonDecode(
      File('assets/data/spell_library.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();

    expect(spells, isNotEmpty);

    final undermined = <String>[];
    for (final spell in spells) {
      final summary = spell['summary'] as String?;
      final description = spell['description'] as String?;
      if (summary == null || description == null) continue;

      // emit.py truncates the description and appends " Level N.", so the
      // summary's opening (once that suffix is stripped) is a prefix of the
      // description's. The suffix must be stripped before truncating to a
      // fixed-length opening -- otherwise a short prose's summary (e.g.
      // "Turns a person into a pig. Level 30.", under 60 chars whole) keeps
      // its " Level N." tail in the comparison and never matches.
      final withoutLevelSuffix = summary.replaceFirst(RegExp(r' Level \d+\.$'), '');
      final opening = withoutLevelSuffix.length < 60
          ? withoutLevelSuffix
          : withoutLevelSuffix.substring(0, 60);
      if (!description.startsWith(opening)) undermined.add(spell['id'] as String);
    }

    expect(undermined, isEmpty,
        reason: 'Item 31 has landed: these summaries are no longer quotes of '
            'their descriptions. Change Spell.sourcedSummary to return '
            'SourcedText.authored(summary) unconditionally, then delete this '
            'test. Spells: ${undermined.take(5).join(', ')}');
  });
}
