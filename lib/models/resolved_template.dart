import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell_template.dart';
import 'package:eruditus/models/text_provenance.dart';

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

  // Stored on the record, not derived: a template's own Technique/Form may
  // legitimately differ from its base effect's (see
  // SpellTemplate.analogyRationale) -- deriving from the base effect would
  // silently display the wrong one.
  @override
  String? get technique => record.technique;
  @override
  String? get form => record.form;
  String? get analogyRationale => record.analogyRationale;

  String get id => record.id;
  @override
  String? get name => record.name;
  @override
  String? get summary => record.summary;
  @override
  String? get description => record.description;
  // A template is read-only catalog data (see SpellTemplate's doc comment):
  // there is no user-editing path that could ever diverge its text from its
  // own provenance, unlike ResolvedSpell.sourcedSummary/sourcedDescription
  // -- so the plain sourcedFrom rule applies unconditionally here.
  @override
  SourcedText? get sourcedSummary => summary == null ? null : sourcedFrom(summary!, record.provenance);
  @override
  SourcedText? get sourcedDescription =>
      description == null ? null : sourcedFrom(description!, record.provenance);
  @override
  PublicationSource get source => record.provenance.source;
  List<Citation> get citations => record.provenance.citations;
  List<String> get tags => record.tags;
  Map<String, List<String>> get selectedModifiers => record.selectedModifiers;
  Map<String, RequisiteKind> get requisites => record.requisites;
  Map<String, String> get chosenSlots => record.chosenSlots;
  List<LevelAdjustment> get adjustments => record.adjustments;
  RitualDeclaration get ritualDeclaration => record.ritualDeclaration;
  ContainerMode get containerMode => record.containerMode;
}
