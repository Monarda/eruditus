import 'package:eruditus/models/publication_source.dart';

/// The surface a library row needs to render itself: everything
/// [SpellCard] reads, and nothing else.
///
/// Implemented by both ResolvedSpell and ResolvedTemplate so one card widget
/// renders both, rather than a near-identical second widget that drifts.
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
