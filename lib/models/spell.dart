import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';

class Spell {
  final String id;
  final String? name;
  final String technique;
  final String form;
  final BaseEffect baseEffect;
  final List<SelectedParameter> parameters;
  final List<String> selectedSpecialFactorIds;
  final List<RequiredRequisite> requiredRequisites;
  final List<AdditionalRequisite> additionalRequisites;
  final String? description;
  final String source; // "built-in" or "user-created"
  final DateTime createdAt;
  final DateTime updatedAt;

  Spell({
    required this.id,
    this.name,
    required this.technique,
    required this.form,
    required this.baseEffect,
    required this.parameters,
    required this.selectedSpecialFactorIds,
    required this.requiredRequisites,
    required this.additionalRequisites,
    this.description,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'technique': technique,
    'form': form,
    'baseEffect': baseEffect.toMap(),
    'parameters': parameters.map((p) => p.toMap()).toList(),
    'selectedSpecialFactorIds': selectedSpecialFactorIds,
    'requiredRequisites': requiredRequisites.map((r) => r.toMap()).toList(),
    'additionalRequisites': additionalRequisites.map((r) => r.toMap()).toList(),
    'description': description,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Spell.fromMap(Map<String, dynamic> map) => Spell(
    id: map['id'] as String,
    name: map['name'] as String?,
    technique: map['technique'] as String,
    form: map['form'] as String,
    baseEffect: BaseEffect.fromMap(map['baseEffect'] as Map<String, dynamic>),
    parameters: (map['parameters'] as List?)
        ?.map((p) => SelectedParameter.fromMap(p as Map<String, dynamic>))
        .toList() ?? [],
    selectedSpecialFactorIds: List<String>.from(map['selectedSpecialFactorIds'] as List? ?? []),
    requiredRequisites: (map['requiredRequisites'] as List?)
        ?.map((r) => RequiredRequisite.fromMap(r as Map<String, dynamic>))
        .toList() ?? [],
    additionalRequisites: (map['additionalRequisites'] as List?)
        ?.map((r) => AdditionalRequisite.fromMap(r as Map<String, dynamic>))
        .toList() ?? [],
    description: map['description'] as String?,
    source: map['source'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}

class SpellDraft {
  String id;
  String? technique;
  String? form;
  BaseEffect? baseEffect;
  List<SelectedParameter> parameters;
  List<String> selectedSpecialFactorIds;
  List<RequiredRequisite> requiredRequisites;
  List<AdditionalRequisite> additionalRequisites;
  String? description;

  SpellDraft({
    String? id,
    this.technique,
    this.form,
    this.baseEffect,
    List<SelectedParameter>? parameters,
    List<String>? selectedSpecialFactorIds,
    List<RequiredRequisite>? requiredRequisites,
    List<AdditionalRequisite>? additionalRequisites,
    this.description,
  })  : id = id ?? _generateId(),
        parameters = parameters ?? [],
        selectedSpecialFactorIds = selectedSpecialFactorIds ?? [],
        requiredRequisites = requiredRequisites ?? [],
        additionalRequisites = additionalRequisites ?? [];

  static String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  Spell toSpell({required String name, required String source}) => Spell(
    id: id,
    name: name,
    technique: technique!,
    form: form!,
    baseEffect: baseEffect!,
    parameters: parameters,
    selectedSpecialFactorIds: selectedSpecialFactorIds,
    requiredRequisites: requiredRequisites,
    additionalRequisites: additionalRequisites,
    description: description,
    source: source,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
