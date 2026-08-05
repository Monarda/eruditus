import 'package:eruditus/utils/map_serialization.dart';

/// What quantity a General guideline's effect is measured in.
enum GeneralEffectKind {
  /// "Might less than or equal to the level of the spell" — every ward.
  mightThreshold,

  /// "Reduce a target's Might Score by the level of the spell + 2 magnitudes".
  mightReduction,

  /// "Create a corrosive substance doing +(Level) damage".
  damage,

  /// "Dispel effects … with a level less than or equal to …" — the Vim rows
  /// that act on another spell.
  targetSpellLevel,

  /// "Destroy an amount of raw vis equal to the level of the spell".
  visDestroyed,

  /// "Detect the traces of magic of negative magnitude up to the magnitude of
  /// the guideline used − 2" — the one family measured in magnitudes.
  spellTraceMagnitude,
}

enum GeneralEffectMultiplier { half, one, two }

enum GeneralEffectUnit { levels, magnitudes }

T _enumByName<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "GeneralEffectFormula.fromMap: unknown $field '$name' (expected one of: "
    "${values.map((v) => v.name).join(', ')})",
  );
}

/// How a General guideline's effect strength is derived from the level the
/// caster chose.
///
/// The value is `multiplier × (chosenBase + offsetMagnitudes × 5)`, always
/// computed in levels. It reads the **chosen base**, never the computed spell
/// level — which is why a Personal-range ward built on the same guideline
/// still keeps out the same Might, despite being five levels cheaper than the
/// printed Touch/Ring/Circle version.
///
/// [unit] converts the result for display only. `magnitudes` divides by 5 and
/// rounds up, per Core Rules line 12030.
class GeneralEffectFormula {
  final GeneralEffectKind kind;
  final GeneralEffectMultiplier multiplier;
  final int offsetMagnitudes;
  final GeneralEffectUnit unit;

  /// True when the guideline's own wording adds "+ a stress die (no botch)".
  final bool stressDie;

  const GeneralEffectFormula({
    required this.kind,
    this.multiplier = GeneralEffectMultiplier.one,
    this.offsetMagnitudes = 0,
    this.unit = GeneralEffectUnit.levels,
    this.stressDie = false,
  });

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'multiplier': multiplier.name,
        'offsetMagnitudes': offsetMagnitudes,
        'unit': unit.name,
        'stressDie': stressDie,
      };

  factory GeneralEffectFormula.fromMap(Map<String, dynamic> map) =>
      GeneralEffectFormula(
        kind: _enumByName(GeneralEffectKind.values,
            requireField<String>(map, 'kind', 'GeneralEffectFormula'), 'kind'),
        multiplier: map['multiplier'] == null
            ? GeneralEffectMultiplier.one
            : _enumByName(GeneralEffectMultiplier.values,
                map['multiplier'] as String, 'multiplier'),
        offsetMagnitudes: map['offsetMagnitudes'] as int? ?? 0,
        unit: map['unit'] == null
            ? GeneralEffectUnit.levels
            : _enumByName(GeneralEffectUnit.values, map['unit'] as String, 'unit'),
        stressDie: map['stressDie'] as bool? ?? false,
      );
}
