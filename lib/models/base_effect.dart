import 'package:eruditus/utils/map_serialization.dart';

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
    id: requireField<String>(map, 'id', 'BaseEffect'),
    technique: requireField<String>(map, 'technique', 'BaseEffect'),
    form: requireField<String>(map, 'form', 'BaseEffect'),
    description: requireField<String>(map, 'description', 'BaseEffect'),
    baseLevel: requireField<int>(map, 'baseLevel', 'BaseEffect'),
    source: requireField<String>(map, 'source', 'BaseEffect'),
  );
}
