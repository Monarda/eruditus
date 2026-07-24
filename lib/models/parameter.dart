import 'package:eruditus/utils/map_serialization.dart';

class Parameter {
  final String id;
  final String name;
  final String category; // "Range", "Duration", "Target", or custom
  final int magnitude;
  final String source; // "built-in" or "user-created"

  Parameter({
    required this.id,
    required this.name,
    required this.category,
    required this.magnitude,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'magnitude': magnitude,
    'source': source,
  };

  factory Parameter.fromMap(Map<String, dynamic> map) => Parameter(
    id: requireField<String>(map, 'id', 'Parameter'),
    name: requireField<String>(map, 'name', 'Parameter'),
    category: requireField<String>(map, 'category', 'Parameter'),
    magnitude: requireField<int>(map, 'magnitude', 'Parameter'),
    source: requireField<String>(map, 'source', 'Parameter'),
  );
}

class SelectedParameter {
  final String parameterId;
  final Parameter parameter;

  SelectedParameter({
    required this.parameterId,
    required this.parameter,
  });

  Map<String, dynamic> toMap() => {
    'parameterId': parameterId,
    'parameter': parameter.toMap(),
  };

  factory SelectedParameter.fromMap(Map<String, dynamic> map) => SelectedParameter(
    parameterId: requireField<String>(map, 'parameterId', 'SelectedParameter'),
    parameter: Parameter.fromMap(
      requireField<Map<String, dynamic>>(map, 'parameter', 'SelectedParameter'),
    ),
  );
}
