import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/target_type.dart';
import 'package:eruditus/utils/map_serialization.dart';

/// Which Forms a parameter is offered for. Empty means unrestricted.
/// Only a Forms list -- no Technique axis, no exclude-lists, no effectIds --
/// because Fire is the only parameter across todo item 17's 9 new entries
/// that needs scoping at all. Extend when real evidence demands it, not
/// preemptively.
class ParameterScope {
  final List<String> forms;
  const ParameterScope({this.forms = const []});

  // form is nullable, not required, matching ModifierScope.appliesTo --
  // draft.form is String? (unset until the user picks one), and a
  // Form-restricted parameter must stay hidden until it does. An empty
  // forms list short-circuits before the null check, so an unrestricted
  // parameter is unaffected by an unset Form.
  bool appliesTo({String? form}) => forms.isEmpty || forms.contains(form);

  Map<String, dynamic> toMap() => {'forms': forms};

  factory ParameterScope.fromMap(Map<String, dynamic>? map) => ParameterScope(
        forms: map == null ? const [] : List<String>.from(map['forms'] as List? ?? const []),
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
