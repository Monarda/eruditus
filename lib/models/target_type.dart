/// Which of the rulebook's three kinds of Target a parameter is.
///
/// Core Rules line 12120: "There are three types of target: objects,
/// containers, and senses." Each Target then states its own kind (Individual
/// 12122, Circle 12124, Part 12128, Group 12130, Room 12132, Structure 12136,
/// Boundary 12138, senses 12152-12160).
///
/// Only a [container] Target has the static/dynamic distinction — see
/// `ContainerMode`. An [object] Target is always static (12246), and a
/// [sense] Target grants information rather than affecting a volume, so
/// neither offers the choice.
enum TargetType { object, container, sense }

TargetType targetTypeFromName(String name, String className) {
  for (final value in TargetType.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown targetType '$name' (expected one of: "
    "${TargetType.values.map((t) => t.name).join(', ')})",
  );
}
