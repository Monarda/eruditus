import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/utils/map_serialization.dart';

class Spell {
  final String id;
  final String? name;
  final String technique;
  final String form;
  final BaseEffect baseEffect;
  final Parameter range;
  final Parameter duration;
  final Parameter target;
  final Map<String, List<String>> selectedModifiers;
  final List<Requisite> requisites;
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
    required this.range,
    required this.duration,
    required this.target,
    this.selectedModifiers = const {},
    required this.requisites,
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
    'range': range.toMap(),
    'duration': duration.toMap(),
    'target': target.toMap(),
    'selectedModifiers': selectedModifiers.map((k, v) => MapEntry(k, v)),
    'requisites': requisites.map((r) => r.toMap()).toList(),
    'description': description,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Spell.fromMap(Map<String, dynamic> map) => Spell(
    id: requireField<String>(map, 'id', 'Spell'),
    name: map['name'] as String?,
    technique: requireField<String>(map, 'technique', 'Spell'),
    form: requireField<String>(map, 'form', 'Spell'),
    baseEffect: BaseEffect.fromMap(
      requireField<Map<String, dynamic>>(map, 'baseEffect', 'Spell'),
    ),
    range: Parameter.fromMap(requireField<Map<String, dynamic>>(map, 'range', 'Spell')),
    duration: Parameter.fromMap(requireField<Map<String, dynamic>>(map, 'duration', 'Spell')),
    target: Parameter.fromMap(requireField<Map<String, dynamic>>(map, 'target', 'Spell')),
    selectedModifiers: (map['selectedModifiers'] as Map?)?.map(
          (k, v) => MapEntry(k as String, List<String>.from(v as List)),
        ) ??
        const {},
    requisites: (map['requisites'] as List?)
        ?.map((r) => Requisite.fromMap(r as Map<String, dynamic>))
        .toList() ?? [],
    description: map['description'] as String?,
    source: requireField<String>(map, 'source', 'Spell'),
    createdAt: DateTime.parse(requireField<String>(map, 'createdAt', 'Spell')),
    updatedAt: DateTime.parse(requireField<String>(map, 'updatedAt', 'Spell')),
  );
}

class SpellDraft {
  String id;
  String? technique;
  String? form;
  BaseEffect? baseEffect;
  Parameter? range;
  Parameter? duration;
  Parameter? target;
  Map<String, List<String>> selectedModifiers;
  List<Requisite> requisites;
  String? description;

  SpellDraft({
    String? id,
    this.technique,
    this.form,
    this.baseEffect,
    this.range,
    this.duration,
    this.target,
    Map<String, List<String>>? selectedModifiers,
    List<Requisite>? requisites,
    this.description,
  })  : id = id ?? _generateId(),
        selectedModifiers = selectedModifiers ?? {},
        requisites = requisites ?? [];

  static String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  Spell toSpell({required String name, required String source}) {
    final missingFields = <String>[
      if (technique == null) 'technique',
      if (form == null) 'form',
      if (baseEffect == null) 'baseEffect',
      if (range == null) 'range',
      if (duration == null) 'duration',
      if (target == null) 'target',
    ];
    if (missingFields.isNotEmpty) {
      throw StateError(
        'Cannot convert SpellDraft to Spell: ${missingFields.join(', ')} '
        '${missingFields.length == 1 ? 'is' : 'are'} not set',
      );
    }

    final resolvedTechnique = technique!;
    final resolvedForm = form!;
    final resolvedBaseEffect = baseEffect!;
    final resolvedRange = range!;
    final resolvedDuration = duration!;
    final resolvedTarget = target!;

    return Spell(
      id: id,
      name: name,
      technique: resolvedTechnique,
      form: resolvedForm,
      baseEffect: resolvedBaseEffect,
      range: resolvedRange,
      duration: resolvedDuration,
      target: resolvedTarget,
      selectedModifiers: selectedModifiers,
      requisites: requisites,
      description: description,
      source: source,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  SpellDraft copyWith({
    String? technique,
    String? form,
    Object? baseEffect = _unset,
    Object? range = _unset,
    Object? duration = _unset,
    Object? target = _unset,
    Map<String, List<String>>? selectedModifiers,
    List<Requisite>? requisites,
    String? description,
  }) {
    return SpellDraft(
      id: id,
      technique: technique ?? this.technique,
      form: form ?? this.form,
      baseEffect: identical(baseEffect, _unset) ? this.baseEffect : baseEffect as BaseEffect?,
      range: identical(range, _unset) ? this.range : range as Parameter?,
      duration: identical(duration, _unset) ? this.duration : duration as Parameter?,
      target: identical(target, _unset) ? this.target : target as Parameter?,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      requisites: requisites ?? this.requisites,
      description: description ?? this.description,
    );
  }
}

/// Sentinel used by [SpellDraft.copyWith] to distinguish "argument omitted"
/// (keep current value) from "argument explicitly passed as null" (clear the
/// field). A plain `T? field` parameter with `field ?? this.field` cannot
/// tell these two cases apart, since both result in `null` being passed in.
class _Unset {
  const _Unset();
}

const _unset = _Unset();
