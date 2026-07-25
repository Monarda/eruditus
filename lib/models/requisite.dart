import 'package:eruditus/utils/map_serialization.dart';

/// Whether a requisite contributes to the spell's level.
///
/// A `free` requisite is demanded by the spell's nature but is incidental
/// enough that it costs nothing (the classic example being a Corpus requisite
/// on a spell that moves a person's clothing along with them). An `adding`
/// requisite is significant enough to make the effect harder, and costs one
/// magnitude.
enum RequisiteKind { free, adding }

class Requisite {
  final String art;
  final RequisiteKind kind;

  Requisite({required this.art, required this.kind});

  int get magnitude => kind == RequisiteKind.adding ? 1 : 0;

  Map<String, dynamic> toMap() => {'art': art, 'kind': kind.name};

  factory Requisite.fromMap(Map<String, dynamic> map) {
    final kindName = requireField<String>(map, 'kind', 'Requisite');
    final kind = RequisiteKind.values.where((k) => k.name == kindName);
    if (kind.isEmpty) {
      throw FormatException(
        'Requisite has unknown kind "$kindName" '
        '(expected one of: ${RequisiteKind.values.map((k) => k.name).join(', ')})',
      );
    }

    return Requisite(
      art: requireField<String>(map, 'art', 'Requisite'),
      kind: kind.first,
    );
  }
}
