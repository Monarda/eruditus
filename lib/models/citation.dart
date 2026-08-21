import 'package:eruditus/utils/map_serialization.dart';

/// One place a spell was published: a book, and optionally the page.
///
/// [page] is nullable. Earlier versions of this comment claimed page numbers
/// "cannot be recovered from the import source", measured against the
/// reviewed rulebook markdown's *body* — which indeed carries no page
/// markers, only prose cross-references like "see page 213" — but never
/// tested against its *indexes*. Four index tables (Spells, Spell Guidelines,
/// Bestiary, Traditional) carry `[page](#anchor)` pairs that resolve real
/// headings to printed pages, so `page` is now populated from those tables
/// for core content and from a committed ledger for HoH:MC (item 78). Pages
/// are Definitive Edition only.
///
/// [page] is still null for the 46 core records no index table covers and
/// for every comma-inverted spell name. A citation naming only its book is
/// complete and valid.
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
