import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell_template.dart';

/// A [SpellTemplate] record joined to the catalog entries its ids refer to.
///
/// The record is the persisted truth; the catalog objects are looked up fresh
/// on every load. Any of them may be null when the id no longer resolves —
/// which happens when a user deletes a custom base effect or parameter a
/// template was built on. Such a template is not repaired and not discarded:
/// it stays listed, reports [isResolved] false, and cannot be instantiated
/// into a draft.
class ResolvedTemplate implements LibraryEntry {
  final SpellTemplate record;
  final BaseEffect? baseEffect;
  final Parameter? range;
  final Parameter? duration;
  final Parameter? target;

  const ResolvedTemplate({
    required this.record,
    this.baseEffect,
    this.range,
    this.duration,
    this.target,
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

  // Derived from the resolved base effect rather than stored on the record, so
  // a template can never claim a technique its own base effect disagrees with.
  @override
  String? get technique => baseEffect?.technique;
  @override
  String? get form => baseEffect?.form;

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
  Map<String, List<String>> get selectedModifiers => record.selectedModifiers;
  Map<String, RequisiteKind> get requisites => record.requisites;
  List<LevelAdjustment> get adjustments => record.adjustments;
  RitualDeclaration get ritualDeclaration => record.ritualDeclaration;
}
