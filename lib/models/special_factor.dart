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
    id: map['id'] as String,
    technique: map['technique'] as String,
    form: map['form'] as String,
    name: map['name'] as String,
    description: map['description'] as String,
    magnitude: map['magnitude'] as int,
    source: map['source'] as String,
  );
}
