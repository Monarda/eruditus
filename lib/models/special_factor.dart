import 'package:eruditus/utils/map_serialization.dart';

class SpecialFactor {
  final String id;
  final String technique;
  final String form;
  final String name;
  final String description;
  final int magnitude;
  final String source; // "built-in" or "user-created"

  SpecialFactor({
    required this.id,
    required this.technique,
    required this.form,
    required this.name,
    required this.description,
    required this.magnitude,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'technique': technique,
    'form': form,
    'name': name,
    'description': description,
    'magnitude': magnitude,
    'source': source,
  };

  factory SpecialFactor.fromMap(Map<String, dynamic> map) => SpecialFactor(
    id: requireField<String>(map, 'id', 'SpecialFactor'),
    technique: requireField<String>(map, 'technique', 'SpecialFactor'),
    form: requireField<String>(map, 'form', 'SpecialFactor'),
    name: requireField<String>(map, 'name', 'SpecialFactor'),
    description: requireField<String>(map, 'description', 'SpecialFactor'),
    magnitude: requireField<int>(map, 'magnitude', 'SpecialFactor'),
    source: requireField<String>(map, 'source', 'SpecialFactor'),
  );
}
