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
    id: map['id'] as String,
    name: map['name'] as String,
    category: map['category'] as String,
    magnitude: map['magnitude'] as int,
    source: map['source'] as String,
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
    parameterId: map['parameterId'] as String,
    parameter: Parameter.fromMap(map['parameter'] as Map<String, dynamic>),
  );
}
