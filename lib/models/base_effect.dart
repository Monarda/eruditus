class BaseEffect {
  final String id;
  final String technique;
  final String form;
  final String description;
  final int baseLevel;
  final String source; // "built-in" or "user-created"

  BaseEffect({
    required this.id,
    required this.technique,
    required this.form,
    required this.description,
    required this.baseLevel,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'technique': technique,
    'form': form,
    'description': description,
    'baseLevel': baseLevel,
    'source': source,
  };

  factory BaseEffect.fromMap(Map<String, dynamic> map) => BaseEffect(
    id: map['id'] as String,
    technique: map['technique'] as String,
    form: map['form'] as String,
    description: map['description'] as String,
    baseLevel: map['baseLevel'] as int,
    source: map['source'] as String,
  );
}
