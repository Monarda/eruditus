import 'package:eruditus/utils/map_serialization.dart';

/// The Range, Duration and Target a guideline is priced against.
///
/// Most guidelines assume nothing, which is [ParameterTriple.standard] —
/// Personal, Momentary, Individual, all magnitude 0 — so their whole stat
/// line is charged. A General guideline may assume more: every ward row in
/// the rulebook ends "(Touch, Ring, Circle)" and the Intellego Imaginem row
/// ends "(Vision target)", meaning those parameters are already paid for.
///
/// Varying a parameter away from the reference costs, or refunds, the
/// difference. See `SpellEngine.calculateBreakdown`.
class ParameterTriple {
  final String rangeId;
  final String durationId;
  final String targetId;

  const ParameterTriple({
    required this.rangeId,
    required this.durationId,
    required this.targetId,
  });

  const ParameterTriple.standard()
      : rangeId = 'range-personal',
        durationId = 'duration-momentary',
        targetId = 'target-individual';

  Map<String, dynamic> toMap() => {
        'rangeId': rangeId,
        'durationId': durationId,
        'targetId': targetId,
      };

  factory ParameterTriple.fromMap(Map<String, dynamic> map) => ParameterTriple(
        rangeId: requireField<String>(map, 'rangeId', 'ParameterTriple'),
        durationId: requireField<String>(map, 'durationId', 'ParameterTriple'),
        targetId: requireField<String>(map, 'targetId', 'ParameterTriple'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParameterTriple &&
          other.rangeId == rangeId &&
          other.durationId == durationId &&
          other.targetId == targetId);

  @override
  int get hashCode => Object.hash(rangeId, durationId, targetId);
}
