/// Whether a container-target spell is static or dynamic.
///
/// Core Rules, the "Container Targets" sidebar, section "Static and Dynamic
/// Targets" (lines 12242-12252). Both words are the rulebook's own.
///
/// [static] — affects valid targets inside the container at the moment of
/// casting, and keeps affecting them even if they leave, and even if the
/// container ceases to exist (12246). A static Circle spell still ends if the
/// circle is broken.
///
/// [dynamic] — affects valid targets while they are in the container. One
/// that leaves stops being affected, one that enters or re-enters starts
/// being affected, and the spell ends early if the container ceases to exist
/// (12248).
///
/// [unstated] means **no decision was recorded**, never "no decision is
/// owed" — whether a spell owes one is derived by `spellOwesContainerMode`.
/// That distinction is exactly what keeps the outstanding set findable when
/// spells gain characters and the mode becomes required. Do not add a
/// `notApplicable` member.
///
/// The mode is fixed when the spell is designed and cannot be changed by the
/// casting magus (12250), which is why it lives on the record. Two spells with
/// identical Technique, Form, Range, Duration and Target can differ in it
/// (12252), which is why it cannot be derived. It is level-neutral.
///
/// `static` and `dynamic` are built-in identifiers in Dart, but both are legal
/// as enum constants and `.name` yields exactly the rulebook's words.
enum ContainerMode { unstated, static, dynamic }

ContainerMode containerModeFromName(String name, String className) {
  for (final value in ContainerMode.values) {
    if (value.name == name) return value;
  }
  throw FormatException(
    "$className.fromMap: unknown containerMode '$name' (expected one of: "
    "${ContainerMode.values.map((m) => m.name).join(', ')})",
  );
}
