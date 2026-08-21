import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/text_provenance.dart';

/// The [LibraryEntry] view of an [ExceptionSpell].
///
/// Trivial today — [isResolved] is always true, because nothing in
/// [ExceptionSpell] references the catalog, so there is nothing to fail to
/// resolve. Kept as a distinct wrapper rather than having [ExceptionSpell]
/// implement [LibraryEntry] directly, mirroring how [Spell] and
/// [SpellTemplate] themselves never implement it either — only their
/// `Resolved*` views do — and leaving a seam if [technique]/[form] ever
/// become real catalog references later.
class ResolvedException implements LibraryEntry {
  final ExceptionSpell record;

  const ResolvedException({required this.record});

  @override
  bool get isResolved => true;

  @override
  List<String> get unresolvedReferences => const [];

  @override
  String? get name => record.name;

  @override
  String? get technique => record.technique;

  @override
  String? get form => record.form;

  @override
  String? get summary => record.summary;

  @override
  String? get description => record.description;

  // An ExceptionSpell is published catalog data the user cannot edit -- the
  // same reasoning as ResolvedTemplate.sourcedSummary/sourcedDescription.
  @override
  SourcedText? get sourcedSummary => summary == null ? null : sourcedFrom(summary!, record.provenance);
  @override
  SourcedText? get sourcedDescription =>
      description == null ? null : sourcedFrom(description!, record.provenance);

  @override
  PublicationSource get source => record.provenance.source;

  String get id => record.id;
  String get rationale => record.rationale;
  bool get isRitual => record.isRitual;
  int? get printedLevel => record.printedLevel;
}
