import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/text_provenance.dart';

/// The surface a library row needs to render itself: everything
/// [SpellCard] reads, and nothing else.
///
/// Implemented by ResolvedSpell, ResolvedTemplate, and ResolvedException so
/// one card widget renders all three, rather than near-identical second and
/// third widgets that drift.
abstract interface class LibraryEntry {
  bool get isResolved;
  List<String> get unresolvedReferences;
  String? get name;
  String? get technique;
  String? get form;
  String? get summary;
  String? get description;
  PublicationSource get source;

  /// [summary] together with whose words it is, or null when there is none.
  ///
  /// Declared here, not just on the three implementers individually, so the
  /// compiler forces every current and future [LibraryEntry] to answer —
  /// rather than a presentation-layer fallback silently mislabeling a fourth
  /// implementer's published prose as ours. See todo item 79.3 finding F2.
  SourcedText? get sourcedSummary;

  /// [description] together with whose words it is, or null when there is
  /// none. See [sourcedSummary].
  SourcedText? get sourcedDescription;
}
