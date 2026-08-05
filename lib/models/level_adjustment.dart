import 'package:eruditus/utils/map_serialization.dart';

/// A one-off magnitude assigned to a single spell, with the prose justifying it.
///
/// Deliberately not a [Modifier]. A Modifier is a reusable catalog choice,
/// scoped to a Technique, Form or set of effects, picked from a fixed ladder.
/// An adjustment is unique to one spell and carries free text that no
/// vocabulary would capture — "because the spell allows growth or two kinds of
/// shrinking".
///
/// [magnitude] may be negative: *The Severed Limb Made Whole* charges -1
/// because the old limb is needed. It may also be zero, because some design
/// lines record that something is explicitly *free* — *Frosty Breath of the
/// Spoken Lie* notes that its mist is purely cosmetic. Such an entry changes no
/// level but must survive, because the note is the point.
class LevelAdjustment {
  final int magnitude;
  final String note;

  LevelAdjustment({required this.magnitude, required this.note}) {
    if (note.trim().isEmpty) {
      throw const FormatException(
          'LevelAdjustment: note must not be empty — the note is the justification');
    }
  }

  Map<String, dynamic> toMap() => {'magnitude': magnitude, 'note': note};

  factory LevelAdjustment.fromMap(Map<String, dynamic> map) => LevelAdjustment(
        magnitude: requireField<int>(map, 'magnitude', 'LevelAdjustment'),
        note: requireField<String>(map, 'note', 'LevelAdjustment'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LevelAdjustment &&
          other.magnitude == magnitude &&
          other.note == note);

  @override
  int get hashCode => Object.hash(magnitude, note);

  @override
  String toString() => 'LevelAdjustment($magnitude, $note)';
}
