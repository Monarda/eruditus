import 'package:eruditus/utils/map_serialization.dart';

/// A rulebook that spells can be published in.
///
/// The catalog is curated rather than scraped: the sibling
/// `Ars-Magica-Open-License` repo holds 56 files, but those include two OCR
/// passes of the same supplement, one book under two titles, and a file marked
/// "DO NOT USE". Files are not works.
class Book {
  final String id;
  final String title;
  final String abbreviation;
  final String edition;

  Book({
    required this.id,
    required this.title,
    required this.abbreviation,
    required this.edition,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'abbreviation': abbreviation,
        'edition': edition,
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: requireField<String>(map, 'id', 'Book'),
        title: requireField<String>(map, 'title', 'Book'),
        abbreviation: requireField<String>(map, 'abbreviation', 'Book'),
        edition: requireField<String>(map, 'edition', 'Book'),
      );

  // Value equality by id, matching BaseEffect and Parameter — reloaded catalogs
  // produce fresh, non-identical instances that must still compare equal.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Book && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
