import 'package:eruditus/utils/map_serialization.dart';

enum ModifierSelectionMode { single, multi }

ModifierSelectionMode _selectionModeFromName(String name) {
  for (final mode in ModifierSelectionMode.values) {
    if (mode.name == name) return mode;
  }
  throw FormatException(
    "Modifier.fromMap: unknown selectionMode '$name' (expected one of: "
    "${ModifierSelectionMode.values.map((m) => m.name).join(', ')})",
  );
}

/// One rung of a modifier: a choice the caster can make, costing [magnitude].
///
/// [baseIndividual] records what one Individual is when this option is chosen
/// — "one cubic inch" for gemstones, "a single dose" for poisons. It is the
/// quantity a Size ladder multiplies, and carries no magnitude of its own.
class ModifierOption {
  final String id;
  final String label;
  final String? description;
  final int magnitude;
  final String? baseIndividual;

  ModifierOption({
    required this.id,
    required this.label,
    this.description,
    required this.magnitude,
    this.baseIndividual,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'description': description,
        'magnitude': magnitude,
        'baseIndividual': baseIndividual,
      };

  factory ModifierOption.fromMap(Map<String, dynamic> map) => ModifierOption(
        id: requireField<String>(map, 'id', 'ModifierOption'),
        label: requireField<String>(map, 'label', 'ModifierOption'),
        description: map['description'] as String?,
        magnitude: requireField<int>(map, 'magnitude', 'ModifierOption'),
        baseIndividual: map['baseIndividual'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ModifierOption && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Which spells a modifier is offered for. A null [technique] or [form] is a
/// wildcard; an empty [effectIds] means any effect within that technique/form.
///
/// [excludeTechniques] carves out Techniques the modifier never applies to,
/// which a positive [technique] match cannot express. The Size ladders use it
/// for Intellego, which the rules exempt from Target size across every Form.
class ModifierScope {
  final String? technique;
  final String? form;
  final List<String> effectIds;
  final List<String> excludeTechniques;

  const ModifierScope({
    this.technique,
    this.form,
    this.effectIds = const [],
    this.excludeTechniques = const [],
  });

  bool appliesTo({String? technique, String? form, String? baseEffectId}) {
    if (technique != null && excludeTechniques.contains(technique)) return false;
    if (this.technique != null && this.technique != technique) return false;
    if (this.form != null && this.form != form) return false;
    if (effectIds.isNotEmpty &&
        (baseEffectId == null || !effectIds.contains(baseEffectId))) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() => {
        'technique': technique,
        'form': form,
        'effectIds': effectIds,
        'excludeTechniques': excludeTechniques,
      };

  factory ModifierScope.fromMap(Map<String, dynamic> map) => ModifierScope(
        technique: map['technique'] as String?,
        form: map['form'] as String?,
        effectIds: List<String>.from(map['effectIds'] as List? ?? const []),
        excludeTechniques:
            List<String>.from(map['excludeTechniques'] as List? ?? const []),
      );
}

/// A named set of magnitude-costing options offered for a scoped set of spells.
/// [selectionMode] decides whether the options are exclusive or cumulative.
class Modifier {
  final String id;
  final String name;
  final String? description;
  final ModifierSelectionMode selectionMode;
  final ModifierScope scope;
  final List<ModifierOption> options;
  final String source; // 'published' or 'user-created'

  Modifier({
    required this.id,
    required this.name,
    this.description,
    required this.selectionMode,
    required this.scope,
    required this.options,
    required this.source,
  });

  ModifierOption? optionById(String optionId) {
    for (final option in options) {
      if (option.id == optionId) return option;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'selectionMode': selectionMode.name,
        'scope': scope.toMap(),
        'options': options.map((o) => o.toMap()).toList(),
        'source': source,
      };

  factory Modifier.fromMap(Map<String, dynamic> map) => Modifier(
        id: requireField<String>(map, 'id', 'Modifier'),
        name: requireField<String>(map, 'name', 'Modifier'),
        description: map['description'] as String?,
        selectionMode:
            _selectionModeFromName(requireField<String>(map, 'selectionMode', 'Modifier')),
        scope: ModifierScope.fromMap(
            requireField<Map<String, dynamic>>(map, 'scope', 'Modifier')),
        options: requireField<List>(map, 'options', 'Modifier')
            .map((o) => ModifierOption.fromMap(o as Map<String, dynamic>))
            .toList(),
        source: requireField<String>(map, 'source', 'Modifier'),
      );

  // Value equality by id — see BaseEffect for why this matters (reloaded
  // ConfigurationBloc state produces fresh, non-identical instances).
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Modifier && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
