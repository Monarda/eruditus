import 'package:eruditus/models/base_effect.dart' show chosenSlotsFromMap;
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/utils/map_serialization.dart';

/// A published General spell: everything a [Spell] has except a level.
///
/// The rulebook is explicit that this is not a spell (Core Rules line 12414):
/// "General level spells are open-ended only in the sense that they may be
/// learned at any level … different levels of a General level spell are still
/// different spells." A template is the thing a spell is made *from*.
///
/// Read-only catalog data. Users instantiate templates; they do not author
/// them.
class SpellTemplate {
  final String id;
  final String name;
  final String baseEffectId;
  final String technique;
  final String form;
  final String rangeId;
  final String durationId;
  final String targetId;
  final Map<String, List<String>> selectedModifiers;
  final Map<String, RequisiteKind> requisites;
  /// Slots this template's guideline declared open, already filled in where
  /// the published spell's own prose commits to a value — see
  /// [Spell.chosenSlots]'s doc comment. May stay empty for a declared-open
  /// kind when the corpus text genuinely doesn't commit to one; a template
  /// carries no write-boundary validation, so this is tolerated (the caster
  /// fills it via `OpenSlotChosen` when instantiating).
  final Map<String, String> chosenSlots;
  final List<LevelAdjustment> adjustments;
  final String? summary;
  final String? description;
  final Provenance provenance;
  final List<String> tags;
  final RitualDeclaration ritualDeclaration;

  /// See [Spell.analogyRationale] -- identical contract.
  final String? analogyRationale;

  /// See [Spell.containerMode] — identical contract. Carried here because 8
  /// of the built-in Circle wards are templates.
  final ContainerMode containerMode;

  SpellTemplate({
    required this.id,
    required this.name,
    required this.baseEffectId,
    required this.technique,
    required this.form,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    this.requisites = const {},
    this.chosenSlots = const {},
    this.adjustments = const [],
    this.summary,
    this.description,
    required this.provenance,
    this.tags = const [],
    this.ritualDeclaration = RitualDeclaration.none,
    this.containerMode = ContainerMode.unstated,
    this.analogyRationale,
  }) {
    final problems = validateSpellProse(
      summary: summary,
      description: description,
    );
    if (problems.isNotEmpty) {
      throw FormatException('SpellTemplate: ${problems.join('; ')}');
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'baseEffectId': baseEffectId,
        'technique': technique,
        'form': form,
        'rangeId': rangeId,
        'durationId': durationId,
        'targetId': targetId,
        'selectedModifiers': selectedModifiers,
        'requisites': requisitesToMap(requisites),
        'chosenSlots': chosenSlots,
        'adjustments': adjustments.map((a) => a.toMap()).toList(),
        'summary': summary,
        'description': description,
        ...provenance.toMap(),
        'tags': tags,
        'ritualDeclaration': ritualDeclaration.name,
        'containerMode': containerMode.name,
        'analogyRationale': analogyRationale,
      };

  factory SpellTemplate.fromMap(Map<String, dynamic> map) => SpellTemplate(
        id: requireField<String>(map, 'id', 'SpellTemplate'),
        name: requireField<String>(map, 'name', 'SpellTemplate'),
        baseEffectId: requireField<String>(map, 'baseEffectId', 'SpellTemplate'),
        technique: requireField<String>(map, 'technique', 'SpellTemplate'),
        form: requireField<String>(map, 'form', 'SpellTemplate'),
        rangeId: requireField<String>(map, 'rangeId', 'SpellTemplate'),
        durationId: requireField<String>(map, 'durationId', 'SpellTemplate'),
        targetId: requireField<String>(map, 'targetId', 'SpellTemplate'),
        selectedModifiers: (map['selectedModifiers'] as Map?)?.map(
              (k, v) => MapEntry(k as String, List<String>.from(v as List)),
            ) ??
            const {},
        requisites: requisitesFromMap(map['requisites'] as Map<String, dynamic>?, 'SpellTemplate'),
        chosenSlots: chosenSlotsFromMap(map['chosenSlots'] as Map<String, dynamic>?),
        adjustments: (map['adjustments'] as List?)
                ?.map((a) => LevelAdjustment.fromMap(a as Map<String, dynamic>))
                .toList() ??
            [],
        summary: map['summary'] as String?,
        description: map['description'] as String?,
        provenance: Provenance.fromMap(map),
        tags: (map['tags'] as List?)?.map((t) => t as String).toList() ?? const [],
        ritualDeclaration: map['ritualDeclaration'] == null
            ? RitualDeclaration.none
            : ritualDeclarationFromName(
                requireField<String>(map, 'ritualDeclaration', 'SpellTemplate'), 'SpellTemplate'),
        containerMode: map['containerMode'] == null
            ? ContainerMode.unstated
            : containerModeFromName(
                requireField<String>(map, 'containerMode', 'SpellTemplate'),
                'SpellTemplate'),
        analogyRationale: map['analogyRationale'] as String?,
      );
}
