import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/utils/map_serialization.dart';

/// The prose rule every published [Spell] must satisfy, stated once and
/// shared by [Spell.fromMap] and [SpellDraft.toSpell] so the two paths
/// cannot drift.
///
/// Returns a list of human-readable problems; empty means valid.
///
/// This rule applies to published spells only. This is interim: user-created
/// spells should carry prose too, but the creation screen collects nothing
/// but a name, so an unconditional rule would reject every user-created
/// spell on save. Tighten this when that UI lands — todo item 13.
///
/// The citation invariant (published needs ≥1 citation, user-created needs
/// 0) is no longer checked here — it now lives on [Provenance] itself, and
/// is enforced when the [Provenance] passed to this [Spell] was constructed.
List<String> validateSpellProse({
  required PublicationSource source,
  required String? summary,
  required String? description,
}) {
  final hasProse = (summary != null && summary.isNotEmpty) ||
      (description != null && description.isNotEmpty);

  if (source == PublicationSource.published && !hasProse) {
    return ['a published spell needs a summary or a description'];
  }
  return const [];
}

/// A saved spell, stored as references into the effect/parameter catalogs.
///
/// This record deliberately holds no copy of any catalog data — no base level,
/// magnitude, technique or form. Those are looked up through [SpellResolver] on
/// read, so there is exactly one source of truth.
///
/// [summary] is a short paraphrase; [description] is verbatim text from the
/// rulebook. Both are optional individually, and a published spell needs at
/// least one of them.
class Spell {
  final String id;
  final String? name;
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
  final DateTime createdAt;
  final DateTime updatedAt;

  Spell({
    required this.id,
    this.name,
    required this.baseEffectId,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    required this.requisites,
    this.adjustments = const [],
    this.summary,
    this.description,
    required this.provenance,
    this.tags = const [],
    this.ritualDeclaration = RitualDeclaration.none,
    required this.createdAt,
    required this.updatedAt,
  }) {
    final problems = validateSpellProse(
      source: provenance.source,
      summary: summary,
      description: description,
    );
    if (problems.isNotEmpty) {
      throw FormatException('Spell: ${problems.join('; ')}');
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
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Spell.fromMap(Map<String, dynamic> map) => Spell(
        id: requireField<String>(map, 'id', 'Spell'),
        name: map['name'] as String?,
        baseEffectId: requireField<String>(map, 'baseEffectId', 'Spell'),
        rangeId: requireField<String>(map, 'rangeId', 'Spell'),
        durationId: requireField<String>(map, 'durationId', 'Spell'),
        targetId: requireField<String>(map, 'targetId', 'Spell'),
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
                requireField<String>(map, 'ritualDeclaration', 'Spell'), 'Spell'),
        createdAt: DateTime.parse(requireField<String>(map, 'createdAt', 'Spell')),
        updatedAt: DateTime.parse(requireField<String>(map, 'updatedAt', 'Spell')),
      );
}

class SpellDraft {
  String id;
  String? technique;
  String? form;
  BaseEffect? baseEffect;
  Parameter? range;
  Parameter? duration;
  Parameter? target;
  Map<String, List<String>> selectedModifiers;
  List<Requisite> requisites;
  List<LevelAdjustment> adjustments;
  String? summary;
  String? description;
  RitualDeclaration ritualDeclaration;

  SpellDraft({
    String? id,
    this.technique,
    this.form,
    this.baseEffect,
    this.range,
    this.duration,
    this.target,
    Map<String, List<String>>? selectedModifiers,
    List<Requisite>? requisites,
    List<LevelAdjustment>? adjustments,
    this.summary,
    this.description,
    this.ritualDeclaration = RitualDeclaration.none,
  })  : id = id ?? _generateId(),
        selectedModifiers = selectedModifiers ?? {},
        requisites = requisites ?? [],
        adjustments = adjustments ?? [];

  static String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  static const String _creo = 'Creo';
  static const String _momentaryDurationId = 'duration-momentary';

  /// A Momentary Creo spell is the one case the rulebook leaves to the caster
  /// (Core Rules line 12351) — the only case the `lastingCreation` checkbox
  /// is offered for and the only case it is set automatically.
  bool get isEligibleForLastingCreationDeclaration =>
      technique == _creo && duration?.id == _momentaryDurationId;

  Spell toSpell({required String name, required PublicationSource source}) {
    final missingFields = <String>[
      if (baseEffect == null) 'baseEffect',
      if (range == null) 'range',
      if (duration == null) 'duration',
      if (target == null) 'target',
    ];
    if (missingFields.isNotEmpty) {
      throw StateError(
        'Cannot convert SpellDraft to Spell: ${missingFields.join(', ')} '
        '${missingFields.length == 1 ? 'is' : 'are'} not set',
      );
    }

    final problems = validateSpellProse(source: source, summary: summary, description: description);
    if (problems.isNotEmpty) {
      throw StateError('Cannot convert SpellDraft to Spell: ${problems.join('; ')}');
    }

    return Spell(
      id: id,
      name: name,
      baseEffectId: baseEffect!.id,
      rangeId: range!.id,
      durationId: duration!.id,
      targetId: target!.id,
      selectedModifiers: selectedModifiers,
      requisites: requisites,
      adjustments: adjustments,
      summary: summary,
      description: description,
      ritualDeclaration: ritualDeclaration,
      provenance: Provenance(source: source),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  SpellDraft copyWith({
    String? technique,
    String? form,
    Object? baseEffect = _unset,
    Object? range = _unset,
    Object? duration = _unset,
    Object? target = _unset,
    Map<String, List<String>>? selectedModifiers,
    List<Requisite>? requisites,
    List<LevelAdjustment>? adjustments,
    String? summary,
    String? description,
    RitualDeclaration? ritualDeclaration,
  }) {
    return SpellDraft(
      id: id,
      technique: technique ?? this.technique,
      form: form ?? this.form,
      baseEffect: identical(baseEffect, _unset) ? this.baseEffect : baseEffect as BaseEffect?,
      range: identical(range, _unset) ? this.range : range as Parameter?,
      duration: identical(duration, _unset) ? this.duration : duration as Parameter?,
      target: identical(target, _unset) ? this.target : target as Parameter?,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      requisites: requisites ?? this.requisites,
      adjustments: adjustments ?? this.adjustments,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      ritualDeclaration: ritualDeclaration ?? this.ritualDeclaration,
    );
  }
}

/// Sentinel used by [SpellDraft.copyWith] to distinguish "argument omitted"
/// (keep current value) from "argument explicitly passed as null" (clear the
/// field). A plain `T? field` parameter with `field ?? this.field` cannot
/// tell these two cases apart, since both result in `null` being passed in.
class _Unset {
  const _Unset();
}

const _unset = _Unset();
