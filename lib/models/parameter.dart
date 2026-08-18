import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/target_type.dart';
import 'package:eruditus/utils/map_serialization.dart';

/// Which Forms a parameter is offered for, and which Techniques it is never
/// offered for. An empty [forms] means unrestricted.
///
/// [excludeTechniques] carves out Techniques the parameter never applies to,
/// mirroring [ModifierScope.excludeTechniques] and added for the same shape of
/// rule: HoH:MC's five Sensory Magic Targets, which the book forbids on any
/// spell employing Intellego, "even as a requisite" -- the requisite half needs
/// a validation check rather than a scope field, and is todo item 67.
///
/// One list is positive and the other negative because that is how each rule is
/// written, not by accident: Fire is offered *for* Ignem and Imaginem, while a
/// Sensory Target is offered for everything *except* Intellego. A positive
/// Technique list could not express the second without naming all four others.
class ParameterScope {
  final List<String> forms;
  final List<String> excludeTechniques;
  const ParameterScope({this.forms = const [], this.excludeTechniques = const []});

  // technique and form are nullable, not required, matching
  // ModifierScope.appliesTo -- draft.technique and draft.form are String?
  // (unset until the user picks one), and a Form-restricted parameter must stay
  // hidden until it does. An empty forms list short-circuits before the null
  // check, so an unrestricted parameter is unaffected by an unset Form.
  //
  // An unset *Technique* is the opposite case and excludes nothing: hiding
  // every Sensory Target before the user has chosen a Technique would hide
  // them from the four Techniques that may use them.
  //
  // Exclusion is tested before the positive match, matching ModifierScope's
  // ordering, because a Forms match cannot overrule "never on this Technique".
  bool appliesTo({String? technique, String? form}) {
    if (technique != null && excludeTechniques.contains(technique)) return false;
    return forms.isEmpty || forms.contains(form);
  }

  Map<String, dynamic> toMap() => {'forms': forms, 'excludeTechniques': excludeTechniques};

  factory ParameterScope.fromMap(Map<String, dynamic>? map) => ParameterScope(
        forms: map == null ? const [] : List<String>.from(map['forms'] as List? ?? const []),
        excludeTechniques: map == null
            ? const []
            : List<String>.from(map['excludeTechniques'] as List? ?? const []),
      );
}

class Parameter {
  final String id;
  final String name;
  final String category; // "Range", "Duration", "Target", or custom
  final int magnitude;

  /// True when the rulebook forbids this parameter on a non-Ritual spell.
  /// Only Year (Duration) and Boundary (Target) set it in the built-in
  /// catalog — see Core Rules lines 12116 and 12138. Deliberately a generic
  /// flag rather than an id check, because the Faerie and Symbolic Magic
  /// parameters of todo item 17 need the same treatment.
  final bool requiresRitual;

  /// The Mystery Virtue the rulebook requires to use this parameter (e.g.
  /// "Faerie Magic"), or null for a parameter anyone can use. Informational
  /// only, like requiresRitual's relationship to spell-saving -- the app has
  /// no character/Virtue model, so nothing is actually gated. See todo item 17.
  final String? requiresVirtue;

  /// Which Forms this parameter is offered for. Unrestricted by default; only
  /// Fire (Ignem/Imaginem only, todo item 17) uses this today.
  final ParameterScope scope;

  /// Which of the rulebook's three kinds of Target this is, or null when this
  /// parameter is not a Target at all (every Range and Duration row).
  ///
  /// Nullable rather than defaulted: "this is not a Target" and "this is a
  /// Target of unknown kind" are different, and only the first should be
  /// silent. A Target with no annotation is a data bug, caught by
  /// `asset_data_loader_test.dart`, not papered over here.
  ///
  /// Read by `validateSpellAgainstCatalog`'s check 9 and by the creation
  /// screen, which offers the container-mode control only for a container.
  final TargetType? targetType;

  final Provenance provenance;

  Parameter({
    required this.id,
    required this.name,
    required this.category,
    required this.magnitude,
    this.requiresRitual = false,
    this.requiresVirtue,
    this.scope = const ParameterScope(),
    this.targetType,
    required this.provenance,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'magnitude': magnitude,
    'requiresRitual': requiresRitual,
    if (requiresVirtue != null) 'requiresVirtue': requiresVirtue,
    if (targetType != null) 'targetType': targetType!.name,
    'scope': scope.toMap(),
    ...provenance.toMap(),
  };

  factory Parameter.fromMap(Map<String, dynamic> map) => Parameter(
    id: requireField<String>(map, 'id', 'Parameter'),
    name: requireField<String>(map, 'name', 'Parameter'),
    category: requireField<String>(map, 'category', 'Parameter'),
    magnitude: requireField<int>(map, 'magnitude', 'Parameter'),
    requiresRitual: map['requiresRitual'] as bool? ?? false,
    requiresVirtue: map['requiresVirtue'] as String?,
    scope: map['scope'] == null
        ? const ParameterScope()
        : ParameterScope.fromMap(map['scope'] as Map<String, dynamic>),
    targetType: map['targetType'] == null
        ? null
        : targetTypeFromName(map['targetType'] as String, 'Parameter'),
    provenance: Provenance.fromMap(map),
  );

  // Value equality by id — see BaseEffect for why this matters (reloaded
  // ConfigurationBloc state produces fresh, non-identical instances).
  @override
  bool operator ==(Object other) => identical(this, other) || (other is Parameter && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
