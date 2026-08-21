import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

/// Whose words a user-facing string is.
///
/// **Distinct from [Provenance], and deliberately so.** [Provenance] records
/// where an *entry* came from — a book, or the user. This records whose words
/// a particular *string on* that entry is. The two coincide today for every
/// field, which is why this is derived rather than stored (see
/// `sourcedFrom`), but they are not the same question and a future edition
/// will separate them.
enum TextProvenance {
  /// The published words of a cited edition — whichever edition, in whatever
  /// language. An officially published translation is Licensed Material in
  /// its own right, so quoting it is [verbatim] cited to *its* book, not
  /// [translated].
  verbatim,

  /// Our own prose, or the caster's. Not the rulebook's words, and must never
  /// be rendered as though it were.
  authored,

  /// A rendering *we* produced of someone else's words — the modification
  /// CC BY-SA 4.0 §3(a)(1)(B) obliges us to indicate.
  ///
  /// **Nothing in production yields this yet.** It is part of the vocabulary
  /// because items 82 (machine translation) and 86 (source editions) both
  /// need it, and because leaving it out would let the rendering rule ship
  /// without a branch for the case it exists to handle.
  translated,
}

/// A user-facing string together with whose words it is, and — when they are
/// not ours — where they came from.
///
/// A **view type**: built at read time by [sourcedFrom], never serialized.
/// See the plan's "Why this deviates from the spec" for why provenance is not
/// a stored field.
class SourcedText {
  final String text;
  final TextProvenance provenance;

  /// Where the words came from. Non-empty for [TextProvenance.verbatim] and
  /// [TextProvenance.translated]; empty for [TextProvenance.authored].
  final List<Citation> citations;

  const SourcedText._(this.text, this.provenance, this.citations);

  /// The published words of a cited edition.
  ///
  /// Throws if [citations] is empty: a quote whose source cannot be named
  /// cannot satisfy §3(a)(1)(A)(i), so it is a licence defect rather than a
  /// display bug and must fail loudly at construction.
  factory SourcedText.verbatim(String text, List<Citation> citations) {
    if (citations.isEmpty) {
      throw ArgumentError.value(
        citations,
        'citations',
        'SourcedText.verbatim: a quote must name the edition it came from',
      );
    }
    return SourcedText._(text, TextProvenance.verbatim, citations);
  }

  /// Our own prose, or the caster's.
  const SourcedText.authored(String text)
      : this._(text, TextProvenance.authored, const []);

  /// A rendering we produced of someone else's words.
  factory SourcedText.translated(String text, List<Citation> citations) {
    if (citations.isEmpty) {
      throw ArgumentError.value(
        citations,
        'citations',
        'SourcedText.translated: a translation must name its source',
      );
    }
    return SourcedText._(text, TextProvenance.translated, citations);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourcedText &&
          other.text == text &&
          other.provenance == provenance &&
          _sameCitations(other.citations, citations));

  static bool _sameCitations(List<Citation> a, List<Citation> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(text, provenance, Object.hashAll(citations));

  @override
  String toString() => 'SourcedText(${provenance.name}: "$text")';
}

/// The rule, in one place: a string on a published entry is that book's own
/// words; a string on a user-created entry is the user's.
///
/// **Derived, not stored.** Every field this is applied to today has a
/// provenance computable from the entry's own [Provenance], so storing it
/// would be the write-only duplication todo item 33 objects to. When a second
/// edition of one work exists (item 86), text becomes a per-edition
/// collection and each element names its own edition — that is the change
/// which makes a stored value earn its place, not this one.
///
/// **⚠️ `Spell.summary` is the field to watch.** It obeys this rule only
/// because `emit.py` currently derives summaries from descriptions, so a
/// published spell's summary really is a truncated quote. Item 31 replaces
/// them with ledger-*authored* prose, at which point `Spell.sourcedSummary`
/// must switch to [SourcedText.authored] unconditionally.
/// `test/models/summary_provenance_tripwire_test.dart` fails when that lands.
SourcedText sourcedFrom(String text, Provenance provenance) =>
    provenance.source == PublicationSource.published
        ? SourcedText.verbatim(text, provenance.citations)
        : SourcedText.authored(text);

/// [sourcedFrom]'s rule, widened for a spell that may still be carrying its
/// source template's own prose verbatim.
///
/// **The one rule for this decision — do not reimplement it at a second call
/// site.** [sourcedFrom] alone gets this wrong for a template-instantiated
/// spell: [TemplateInstantiated] seeds a fresh, user-created draft's
/// summary/description directly from the published [SpellTemplate]'s own
/// text (`lib/bloc/spell_creation/spell_creation_bloc.dart`), so until the
/// caster edits it, that text is still the rulebook's own words even though
/// [Provenance.source] on the saved [Spell] reads `userCreated`. This
/// function is the seam that corrects for that: seeded prose stays
/// [TextProvenance.verbatim], cited to the *template's* citations (a
/// user-created spell has none of its own), for exactly as long as [text]
/// still matches [seedText] character-for-character; the moment it diverges
/// — the user has edited it — [sourcedFrom] takes over unconditionally, and
/// the field is [TextProvenance.authored].
///
/// [ResolvedSpell] is the only caller: it is the layer that has both the
/// [Spell] record and (via `SpellResolver`, from [Spell.templateId]) its
/// source [SpellTemplate], which a bare [Spell] does not.
SourcedText? sourcedSpellText({
  required String? text,
  required Provenance recordProvenance,
  required String? seedText,
  required List<Citation> seedCitations,
}) {
  if (text == null) return null;
  final stillMatchesSeed = recordProvenance.source != PublicationSource.published &&
      seedText != null &&
      text == seedText;
  return stillMatchesSeed
      ? SourcedText.verbatim(text, seedCitations)
      : sourcedFrom(text, recordProvenance);
}
