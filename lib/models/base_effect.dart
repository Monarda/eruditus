import 'package:eruditus/models/general_effect_formula.dart';
import 'package:eruditus/models/parameter_triple.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/utils/map_serialization.dart';

/// Whether a guideline demands a Ritual spell.
///
/// [required] is a hard constraint from the rulebook — the spell cannot be
/// Formulaic. [suggested] is guidance only: it forces nothing, and exists so
/// the UI can explain what casting the effect non-ritually actually does. See
/// Core Rules line 13415 on healing spells, which suspend rather than cure
/// when cast as anything other than a Momentary Ritual.
enum RitualRequirement { none, suggested, required }

/// Reads the nullable `baseLevel` field, distinguishing three cases that
/// [requireField] cannot: the key is absent (an error — every stored effect
/// must state its base level, even if that statement is General), the key
/// is `null` (General), or the key holds a non-int value (an error).
int? _baseLevelFromMap(Map<String, dynamic> map) {
  if (!map.containsKey('baseLevel')) {
    throw FormatException("BaseEffect.fromMap: missing required field 'baseLevel'");
  }
  final value = map['baseLevel'];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException(
    "BaseEffect.fromMap: required field 'baseLevel' has the wrong type "
    "(expected int?, got ${value.runtimeType})",
  );
}

RitualRequirement _ritualRequirementFromName(String name) {
  for (final value in RitualRequirement.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "BaseEffect.fromMap: unknown ritualRequirement '$name' (expected one of: "
    "${RitualRequirement.values.map((r) => r.name).join(', ')})",
  );
}

class BaseEffect {
  final String id;
  final String technique;
  final String form;
  final String description;
  /// The guideline's base level, or null when the guideline is **General** —
  /// the rulebook prints `General` where every other row prints a number,
  /// because the caster chooses it (Core Rules line 12410). Null is the
  /// marker; there is deliberately no separate `isGeneral` field, so the two
  /// cannot disagree.
  ///
  /// A General guideline's level arrives on the spell as
  /// `Spell.chosenBaseLevel`, and what it is priced against arrives as
  /// [reference].
  final int? baseLevel;

  bool get isGeneral => baseLevel == null;

  final RitualRequirement ritualRequirement;
  final Provenance provenance;

  /// What this guideline is priced against. Absent in JSON means
  /// [ParameterTriple.standard].
  final ParameterTriple reference;

  /// How the guideline's effect strength derives from the chosen level.
  /// Present on every General entry, absent on every other.
  final GeneralEffectFormula? effectFormula;

  BaseEffect({
    required this.id,
    required this.technique,
    required this.form,
    required this.description,
    required this.baseLevel,
    this.ritualRequirement = RitualRequirement.none,
    required this.provenance,
    this.reference = const ParameterTriple.standard(),
    this.effectFormula,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'technique': technique,
    'form': form,
    'description': description,
    'baseLevel': baseLevel,
    'ritualRequirement': ritualRequirement.name,
    ...provenance.toMap(),
    'reference': reference.toMap(),
    if (effectFormula != null) 'effectFormula': effectFormula!.toMap(),
  };

  factory BaseEffect.fromMap(Map<String, dynamic> map) => BaseEffect(
    id: requireField<String>(map, 'id', 'BaseEffect'),
    technique: requireField<String>(map, 'technique', 'BaseEffect'),
    form: requireField<String>(map, 'form', 'BaseEffect'),
    description: requireField<String>(map, 'description', 'BaseEffect'),
    baseLevel: _baseLevelFromMap(map),
    ritualRequirement: map['ritualRequirement'] == null
        ? RitualRequirement.none
        : _ritualRequirementFromName(
            requireField<String>(map, 'ritualRequirement', 'BaseEffect')),
    provenance: Provenance.fromMap(map),
    reference: map['reference'] == null
        ? const ParameterTriple.standard()
        : ParameterTriple.fromMap(map['reference'] as Map<String, dynamic>),
    effectFormula: map['effectFormula'] == null
        ? null
        : GeneralEffectFormula.fromMap(map['effectFormula'] as Map<String, dynamic>),
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
