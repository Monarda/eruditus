import 'package:eruditus/utils/map_serialization.dart';

class BaseEffect {
  final String id;
  final String technique;
  final String form;
  final String description;
  final int baseLevel;
  final String source; // "published" or "user-created"

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

  // Value equality by id. Effects are re-parsed from JSON/DB on every
  // ConfigurationRepository fetch (see AssetDataLoader), so a freshly loaded
  // instance is never `identical()` to one already held e.g. in a
  // SpellDraft.baseEffect. Without this, a DropdownButtonFormField whose
  // `items` are rebuilt from a reloaded list (as happens whenever
  // ConfigurationBloc reloads after a Settings-tab edit) would no longer
  // recognize a previously selected value as present in the new list.
  @override
  bool operator ==(Object other) => identical(this, other) || (other is BaseEffect && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
