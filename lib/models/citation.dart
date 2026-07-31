import 'package:eruditus/utils/map_serialization.dart';

/// One place a spell was published: a book, and optionally the page.
///
/// [page] is nullable and is null for every built-in entry. The reviewed
/// rulebook markdown carries no page markers — only prose cross-references of
/// the form "see page 213" — so page numbers cannot be recovered from the
/// import source. An earlier version of this comment promised they would
/// "arrive with the spell-parsing work"; that work is done and the promise
/// could not be kept. Supplying them needs the PDFs or a different edition.
/// A citation naming only its book is complete and valid.
class Citation {
  final String bookId;
  final int? page;

  const Citation({required this.bookId, this.page});

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        if (page != null) 'page': page,
      };

  factory Citation.fromMap(Map<String, dynamic> map) => Citation(
        bookId: requireField<String>(map, 'bookId', 'Citation'),
        page: map['page'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Citation && other.bookId == bookId && other.page == page);

  @override
  int get hashCode => Object.hash(bookId, page);

  @override
  String toString() => 'Citation($bookId${page == null ? '' : ' p.$page'})';
}
