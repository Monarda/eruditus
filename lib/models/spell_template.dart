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
  final String rangeId;
  final String durationId;
  final String targetId;
  final Map<String, List<String>> selectedModifiers;
  final List<Requisite> requisites;
  final List<LevelAdjustment> adjustments;
  final String? summary;
  final String? description;
  final Provenance provenance;
  final List<String> tags;
  final RitualDeclaration ritualDeclaration;

  SpellTemplate({
    required this.id,
    required this.name,
    required this.baseEffectId,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    this.requisites = const [],
    this.adjustments = const [],
    this.summary,
    this.description,
    required this.provenance,
    this.tags = const [],
    this.ritualDeclaration = RitualDeclaration.none,
  }) {
    final problems = validateSpellProse(
      source: provenance.source,
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
        'rangeId': rangeId,
        'durationId': durationId,
        'targetId': targetId,
        'selectedModifiers': selectedModifiers,
        'requisites': requisites.map((r) => r.toMap()).toList(),
        'adjustments': adjustments.map((a) => a.toMap()).toList(),
        'summary': summary,
        'description': description,
        ...provenance.toMap(),
        'tags': tags,
        'ritualDeclaration': ritualDeclaration.name,
      };

  factory SpellTemplate.fromMap(Map<String, dynamic> map) => SpellTemplate(
        id: requireField<String>(map, 'id', 'SpellTemplate'),
        name: requireField<String>(map, 'name', 'SpellTemplate'),
        baseEffectId: requireField<String>(map, 'baseEffectId', 'SpellTemplate'),
        rangeId: requireField<String>(map, 'rangeId', 'SpellTemplate'),
        durationId: requireField<String>(map, 'durationId', 'SpellTemplate'),
        targetId: requireField<String>(map, 'targetId', 'SpellTemplate'),
        selectedModifiers: (map['selectedModifiers'] as Map?)?.map(
              (k, v) => MapEntry(k as String, List<String>.from(v as List)),
            ) ??
            const {},
        requisites: (map['requisites'] as List?)
                ?.map((r) => Requisite.fromMap(r as Map<String, dynamic>))
                .toList() ??
            [],
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
      );
}
