/// Whether a requisite contributes to the spell's level.
///
/// A `free` requisite is demanded by the spell's nature but is incidental
/// enough that it costs nothing (the classic example being a Corpus requisite
/// on a spell that moves a person's clothing along with them). An `adding`
/// requisite is significant enough to make the effect harder, and costs one
/// magnitude.
enum RequisiteKind { free, adding }

/// The level-magnitude [RequisiteKind] costs: 1 for [RequisiteKind.adding],
/// 0 for [RequisiteKind.free].
extension RequisiteKindMagnitude on RequisiteKind {
  int get magnitude => this == RequisiteKind.adding ? 1 : 0;
}

/// Resolves a requisite kind's wire name back to the enum value, with the
/// same clear-error convention as [ritualDeclarationFromName].
RequisiteKind requisiteKindFromName(String name, String className) {
  for (final value in RequisiteKind.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown requisite kind '$name' (expected one of: "
    "${RequisiteKind.values.map((k) => k.name).join(', ')})",
  );
}

/// Serializes a requisites map to its wire shape, e.g. `{"Rego": "adding"}`.
///
/// Shared by [Spell] and [SpellTemplate] so the two paths cannot drift, the
/// same reason [validateSpellProse] is shared between them.
Map<String, String> requisitesToMap(Map<String, RequisiteKind> requisites) =>
    requisites.map((art, kind) => MapEntry(art, kind.name));

/// Parses the wire shape back, keyed by art. A missing `requisites` key
/// ([map] is `null`) yields an empty map, matching every other optional
/// collection field's default.
Map<String, RequisiteKind> requisitesFromMap(
  Map<String, dynamic>? map,
  String className,
) {
  if (map == null) return const {};
  return map.map((art, kindValue) {
    if (kindValue is! String) {
      throw FormatException("$className.fromMap: requisite '$art' has no kind");
    }
    return MapEntry(art, requisiteKindFromName(kindValue, className));
  });
}
