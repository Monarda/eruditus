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

/// A slot the rulebook leaves open on a guideline for the caster (or, for a
/// published spell, the spell's own prose) to fill — the same shape of thing
/// `chosenBaseLevel` is for a General guideline's level, generalized to
/// cover the guideline text's other open choices.
///
/// [realm] — "Ward against beings... from one supernatural realm (Divine,
/// Faerie, Infernal, or Magic)". [form] and [specificType] are Part B's; the
/// enum carries all three now so the wire shape never needs to change again
/// when they land (todo items 35/37's design spec, decision 8).
enum OpenSlotKind { realm, form, specificType }

OpenSlotKind _openSlotKindFromName(String name) {
  for (final value in OpenSlotKind.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "BaseEffect.fromMap: unknown open slot kind '$name' (expected one of: "
    "${OpenSlotKind.values.map((k) => k.name).join(', ')})",
  );
}

/// Parses a `chosenSlots` wire map (`{"realm": "Infernal"}`) back, shared by
/// [Spell]/[SpellDraft]/[SpellTemplate] so the three cannot drift, the same
/// reason [requisitesFromMap] is shared.
Map<String, String> chosenSlotsFromMap(Map<String, dynamic>? map) {
  if (map == null) return const {};
  return map.map((kind, value) => MapEntry(kind, value as String));
}

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

  /// Slots this guideline's own text leaves for the caster (or a published
  /// spell's prose) to fill — realm, Form, or "a specific type", per
  /// [OpenSlotKind]. Empty for every guideline that commits to everything
  /// itself.
  final List<OpenSlotKind> openSlots;

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
    this.openSlots = const [],
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
    'openSlots': openSlots.map((k) => k.name).toList(),
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
    openSlots: (map['openSlots'] as List?)
            ?.map((k) => _openSlotKindFromName(k as String))
            .toList() ??
        const [],
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
