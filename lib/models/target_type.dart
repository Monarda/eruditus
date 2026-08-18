/// Which kind of Target a parameter is.
///
/// Core Rules line 12120 enumerates three: "There are three types of target:
/// objects, containers, and senses." Each core Target states its own kind
/// (Individual 12122, Circle 12124, Part 12128, Group 12130, Room 12132,
/// Structure 12136, Boundary 12138, senses 12152-12160).
///
/// [sensorium] is a fourth, and deliberately not a rulebook word — it appears
/// nowhere in the corpus. HoH:MC's Sensory Magic Targets (Flavor, Texture,
/// Scent, Sound, Spectacle) need it because all three core kinds contradict
/// them, and HoH:MC line 1000 grants the exemption in its own words: these
/// Targets "were imperfectly melded to Hermetic Theory, remaining a Mystery
/// of House Bjornaer". A container is ruled out because HoH:MC 1006 requires
/// Sensory spells to be Personal Range while core 12086 forbids a container
/// Target on a Personal-Range spell; an object is ruled out because objects
/// are static (12246) while HoH:MC 1002 acquires targets continuously
/// throughout the duration.
///
/// The distinction from [sense] is the load-bearing one, and is why Intellego
/// is forbidden on these spells: **a [sense] Target grants the caster a
/// magical sense; a [sensorium] Target affects those who sense the caster.**
///
/// Only a [container] Target has the static/dynamic distinction — see
/// `ContainerMode`. An [object] Target is always static (12246); a [sense]
/// Target grants information rather than affecting a volume; and a
/// [sensorium] Target's membership is fixed by the rulebook rather than
/// chosen, so none of the three offers the choice.
enum TargetType { object, container, sense, sensorium }

TargetType targetTypeFromName(String name, String className) {
  for (final value in TargetType.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown targetType '$name' (expected one of: "
    "${TargetType.values.map((t) => t.name).join(', ')})",
  );
}
