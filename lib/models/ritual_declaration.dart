/// The part of a spell's Ritual status that cannot be derived from its
/// configuration, because the rulebook leaves it to a person's judgement.
///
/// [lastingCreation] is Core Rules line 12351: "If the spell is a Momentary
/// Creo spell creating a lasting thing, it must be a Ritual." Whether the thing
/// created is meant to last is not visible in the guideline.
///
/// [storyguideRuling] is line 12352: an effect "so spectacular that it must not
/// be easily accessible to magi". Four published core spells are Rituals for
/// this reason alone. No UI sets it yet — see the todo item — but the model and
/// the built-in library both carry it, so adding that UI needs no migration.
enum RitualDeclaration { none, lastingCreation, storyguideRuling }

RitualDeclaration ritualDeclarationFromName(String name, String className) {
  for (final value in RitualDeclaration.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown ritualDeclaration '$name' (expected one of: "
    "${RitualDeclaration.values.map((d) => d.name).join(', ')})",
  );
}
