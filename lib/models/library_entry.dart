import 'package:eruditus/models/publication_source.dart';

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
}
