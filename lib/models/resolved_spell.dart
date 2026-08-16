import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart';

/// A [Spell] record joined to the catalog entries its ids refer to.
///
/// The record is the persisted truth; the catalog objects are looked up fresh
/// on every load. Any of them may be null when the id no longer resolves —
/// which happens when a user deletes a custom base effect or parameter a saved
/// spell was built on. Such a spell is not repaired and not discarded: it stays
/// listed, reports [isResolved] false, and yields no calculated level.
class ResolvedSpell implements LibraryEntry {
  final Spell record;
  final BaseEffect? baseEffect;
  final Parameter? range;
  final Parameter? duration;
  final Parameter? target;

  /// The catalog entries [Spell.selectedModifiers]' keys resolve to.
  ///
  /// Defaults to empty because the only direct constructions of this class
  /// outside [SpellResolver] are test fixtures, where "no modifiers" is
  /// accurate rather than a bypass. The production path is
  /// [SpellResolver.resolve], which always populates it.
  final List<Modifier> modifiers;

  const ResolvedSpell({
    required this.record,
    this.baseEffect,
    this.range,
    this.duration,
    this.target,
    this.modifiers = const [],
  });

  @override
  bool get isResolved =>
      baseEffect != null && range != null && duration != null && target != null;

  /// The ids that failed to resolve, in record order. Empty when [isResolved].
  @override
  List<String> get unresolvedReferences => [
        if (baseEffect == null) record.baseEffectId,
        if (range == null) record.rangeId,
        if (duration == null) record.durationId,
        if (target == null) record.targetId,
      ];

  /// The catalog-dependent invariants this spell breaks. Empty means none.
  ///
  /// **A sibling of [isResolved], not a replacement for it — the two answer
  /// different questions.** [isResolved] is a *can I compute* gate: the four
  /// catalog ids are null, so `calculateBreakdown` cannot run at all
  /// (`spell_library_bloc.dart` relies on exactly this). [problems] means the
  /// level computes fine but must not be trusted, because the record and its
  /// guideline disagree.
  ///
  /// Empty when [baseEffect] is null: there is nothing to validate against, and
  /// [isResolved] already reports that case.
  ///
  /// Whether these two notions should collapse into one is todo item 38's
  /// question, alongside the `ResolvedSpell`/`ResolvedTemplate` duplication.
  /// Do not merge them without preserving the compute gate.
  List<String> get problems {
    final effect = baseEffect;
    if (effect == null) return const [];
    return validateSpellAgainstCatalog(
      effect: effect,
      technique: record.technique,
      form: record.form,
      analogyRationale: record.analogyRationale,
      chosenBaseLevel: record.chosenBaseLevel,
      requisites: record.requisites,
      selectedModifiers: record.selectedModifiers,
      modifiers: modifiers,
      chosenSlots: record.chosenSlots,
    );
  }

  // Stored on the record, not derived: a spell's own Technique/Form may
  // legitimately differ from its base effect's (see Spell.analogyRationale)
  // -- deriving from the base effect would silently display the wrong one.
  @override
  String? get technique => record.technique;
  @override
  String? get form => record.form;

  String get id => record.id;
  @override
  String? get name => record.name;
  @override
  String? get summary => record.summary;
  @override
  String? get description => record.description;
  @override
  PublicationSource get source => record.provenance.source;
  List<Citation> get citations => record.provenance.citations;
  List<String> get tags => record.tags;
  DateTime get createdAt => record.createdAt;
  DateTime get updatedAt => record.updatedAt;
  Map<String, List<String>> get selectedModifiers => record.selectedModifiers;
  Map<String, RequisiteKind> get requisites => record.requisites;
  Map<String, String> get chosenSlots => record.chosenSlots;
  List<LevelAdjustment> get adjustments => record.adjustments;
  RitualDeclaration get ritualDeclaration => record.ritualDeclaration;
}
