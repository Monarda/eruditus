import 'dart:convert';
import 'dart:io';

const _accents = {
  'a': 'а', 'c': 'ć', 'e': 'ē', 'g': 'ģ', 'i': 'ĭ', 'l': 'ĺ', 'n': 'ň',
  'o': 'ō', 'r': 'ŕ', 's': 'ś', 't': 'ţ', 'u': 'ű', 'z': 'ź',
  'A': 'Å', 'C': 'Ĉ', 'E': 'Ē', 'G': 'Ĝ', 'I': 'Ĭ', 'L': 'Ĺ', 'N': 'Ň',
  'O': 'Ō', 'R': 'Ŕ', 'S': 'Ś', 'T': 'Ţ', 'U': 'Ű', 'Z': 'Ź',
};

/// Accents [value]'s letters and pads it ~30%, leaving `{placeholders}` alone.
///
/// A string that still renders as plain ASCII under locale `en_XA` never reached
/// the ARB. The padding surfaces truncation, which is the evidence items 16
/// and 58 have both been waiting on.
String pseudoTransform(String value) {
  final buffer = StringBuffer('[');
  var inPlaceholder = false;

  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (char == '{') inPlaceholder = true;
    if (char == '}') {
      inPlaceholder = false;
      buffer.write(char);
      continue;
    }
    buffer.write(inPlaceholder ? char : (_accents[char] ?? char));
  }

  final padding = '·' * (value.length * 0.3).ceil();
  return '$buffer$padding]';
}

/// Renders a complete `app_en_XA.arb` from a decoded `app_en.arb`.
///
/// Metadata keys (`@@locale`, and every `@key` description block) are dropped:
/// gen-l10n takes placeholder metadata from the template file only.
///
/// `@@x-translation-status: generated` marks the whole file as machine-produced
/// and never reviewable (item 82). Without it these entries would sit in any
/// future translation burn-down forever, since nobody will ever human-review a
/// pseudo-locale. gen-l10n tolerates the custom attribute — verified against
/// Flutter 3.44.8, exit 0, no warnings.
String generatePseudoArb(Map<String, dynamic> en) {
  final out = <String, dynamic>{
    '@@locale': 'en_XA',
    '@@x-translation-status': 'generated',
  };

  for (final entry in en.entries) {
    if (entry.key.startsWith('@')) continue;
    out[entry.key] = pseudoTransform(entry.value as String);
  }

  return '${const JsonEncoder.withIndent('  ').convert(out)}\n';
}

void main() {
  final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
      as Map<String, dynamic>;
  File('lib/l10n/app_en_XA.arb').writeAsStringSync(generatePseudoArb(en));
  stdout.writeln('wrote lib/l10n/app_en_XA.arb');
}
