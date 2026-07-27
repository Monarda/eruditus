import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/utils/map_serialization.dart';

class Parameter {
  final String id;
  final String name;
  final String category; // "Range", "Duration", "Target", or custom
  final int magnitude;

  /// True when the rulebook forbids this parameter on a non-Ritual spell.
  /// Only Year (Duration) and Boundary (Target) set it in the built-in
  /// catalog — see Core Rules lines 12116 and 12138. Deliberately a generic
  /// flag rather than an id check, because the Faerie and Symbolic Magic
  /// parameters of todo item 17 need the same treatment.
  final bool requiresRitual;

  final Provenance provenance;

  Parameter({
    required this.id,
    required this.name,
    required this.category,
    required this.magnitude,
    this.requiresRitual = false,
    required this.provenance,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'magnitude': magnitude,
    'requiresRitual': requiresRitual,
    ...provenance.toMap(),
  };

  factory Parameter.fromMap(Map<String, dynamic> map) => Parameter(
    id: requireField<String>(map, 'id', 'Parameter'),
    name: requireField<String>(map, 'name', 'Parameter'),
    category: requireField<String>(map, 'category', 'Parameter'),
    magnitude: requireField<int>(map, 'magnitude', 'Parameter'),
    requiresRitual: map['requiresRitual'] as bool? ?? false,
    provenance: Provenance.fromMap(map),
  );

  // Value equality by id — see BaseEffect for why this matters (reloaded
  // ConfigurationBloc state produces fresh, non-identical instances).
  @override
  bool operator ==(Object other) => identical(this, other) || (other is Parameter && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
