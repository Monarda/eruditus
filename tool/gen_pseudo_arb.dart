import 'dart:convert';
import 'dart:io';

// Latin letters with diacritics only. Never a homoglyph: a Cyrillic small a is
// indistinguishable from ASCII 'a' on screen, which defeats the half of this
// harness that relies on a human seeing the difference.
const _accents = {
  'a': 'ā', 'b': 'ƀ', 'c': 'ć', 'd': 'đ', 'e': 'ē', 'f': 'ƒ', 'g': 'ģ',
  'h': 'ĥ', 'i': 'ĭ', 'j': 'ĵ', 'k': 'ķ', 'l': 'ĺ', 'm': 'ɱ', 'n': 'ň',
  'o': 'ō', 'p': 'ƥ', 'q': 'ɋ', 'r': 'ŕ', 's': 'ś', 't': 'ţ', 'u': 'ű',
  'v': 'ṽ', 'w': 'ŵ', 'x': 'ẋ', 'y': 'ý', 'z': 'ź',
  'A': 'Å', 'B': 'Ɓ', 'C': 'Ĉ', 'D': 'Đ', 'E': 'Ē', 'F': 'Ƒ', 'G': 'Ĝ',
  'H': 'Ĥ', 'I': 'Ĭ', 'J': 'Ĵ', 'K': 'Ķ', 'L': 'Ĺ', 'M': 'Ṁ', 'N': 'Ň',
  'O': 'Ō', 'P': 'Ƥ', 'Q': 'Ɋ', 'R': 'Ŕ', 'S': 'Ś', 'T': 'Ţ', 'U': 'Ű',
  'V': 'Ṽ', 'W': 'Ŵ', 'X': 'Ẋ', 'Y': 'Ý', 'Z': 'Ź',
};

/// Accents [value]'s letters and pads it ~30%, leaving `{placeholders}` alone.
///
/// A string that still renders as plain ASCII under locale `en_XA` never reached
/// the ARB. The padding surfaces truncation, which is the evidence items 16
/// and 58 have both been waiting on.
///
/// **Brace depth, not a boolean.** ICU plural and select messages nest. A
/// boolean "am I in a placeholder" flag clears on the first inner closing brace
/// and then accents the ICU keyword `other`, which gen-l10n needs verbatim -
/// corrupting codegen for *every* locale, not just this one.
///
/// **Known limitation, accepted deliberately:** with a depth counter, literal
/// text inside a plural's sub-messages is left un-accented, because telling ICU
/// syntax from display text needs a real ICU parser. Such a value is still
/// wrapped in brackets and padding, so the "was this migrated?" signal is
/// intact; only the visual accenting is weaker for pluralised strings. Never
/// corrupting ICU is worth more than accenting the few strings that use it.
String pseudoTransform(String value) {
  final buffer = StringBuffer('[');
  var depth = 0;

  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (char == '{') {
      depth++;
      buffer.write(char);
      continue;
    }
    if (char == '}') {
      if (depth > 0) depth--;
      buffer.write(char);
      continue;
    }
    buffer.write(depth > 0 ? char : (_accents[char] ?? char));
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
