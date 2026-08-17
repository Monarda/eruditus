import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/modifier.dart';
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

/// Looks up an [OpenSlotKind] by [OpenSlotKind.name], or `null` if [name]
/// does not match one. Unlike `base_effect.dart`'s private
/// `_openSlotKindFromName` (not reusable here -- Dart privacy is per-file),
/// this never throws: check 7 needs to tolerate an arbitrary stray
/// `chosenSlots` key that may not parse as a known kind at all.
OpenSlotKind? _openSlotKindByName(String name) {
  for (final value in OpenSlotKind.values) {
    if (value.name == name) return value;
  }
  return null;
}

/// Human-readable phrasing for an [OpenSlotKind] in a check-6 message.
/// [OpenSlotKind.specificType] reads as "a specific type of enchantment" to
/// match the rulebook's own phrasing rather than the bare enum name.
String _openSlotDescription(OpenSlotKind kind) {
  switch (kind) {
    case OpenSlotKind.realm:
      return 'realm';
    case OpenSlotKind.form:
      return 'Form';
    case OpenSlotKind.specificType:
      return 'specific type of enchantment';
  }
}

/// The catalog-dependent invariants every spell must satisfy, stated once and
/// shared by every path that can produce or hold one — the same contract
/// [validateSpellProse] provides for prose.
///
/// Returns a list of human-readable problems; empty means valid. Problems
/// accumulate: a caller showing them to a user should see all of them at once.
///
/// **Why this is a free function taking pieces rather than a method on [Spell].**
/// [Spell] deliberately holds `baseEffectId` and not [BaseEffect], so it cannot
/// see `isGeneral`, the effect's technique/form, or a modifier's
/// `selectionMode`. All of these six checks are therefore uncheckable from
/// inside the record. Taking the pieces (rather than a `ResolvedSpell`) is what
/// lets [SpellDraft] — which holds a bare `BaseEffect?`, never a resolved
/// wrapper — call the identical function, and avoids a circular import, since
/// `resolved_spell.dart` imports this file.
///
/// [isTemplate] skips checks 1, 2 and 6. A `SpellTemplate` built on a
/// General guideline legitimately has no chosen level; supplying one is
/// precisely what instantiating the template means. An open slot may
/// legitimately stay unfilled until instantiation (Decision 9). Check 7 is
/// NOT skipped for templates — a `SpellTemplate` genuinely carries
/// `chosenSlots` now, so a stray key naming a kind the guideline never
/// declared open is just as much a bug there as on a `Spell`.
List<String> validateSpellAgainstCatalog({
  required BaseEffect effect,
  required String technique,
  required String form,
  required String? analogyRationale,
  required int? chosenBaseLevel,
  required Map<String, RequisiteKind> requisites,
  required Map<String, List<String>> selectedModifiers,
  required Map<String, String> chosenSlots,
  required List<Modifier> modifiers,
  bool isTemplate = false,
}) {
  final problems = <String>[];

  if (!isTemplate) {
    // 1. A General guideline's level comes from the caster, so it must be
    //    present and usable. Absent it, calculateBreakdown throws.
    if (effect.isGeneral) {
      if (chosenBaseLevel == null) {
        problems.add('Choose a level for this General guideline');
      } else if (chosenBaseLevel < 1) {
        problems.add('The chosen level must be at least 1');
      }
    } else if (chosenBaseLevel != null) {
      // 2. The converse. calculateBreakdown ignores a chosen level on a
      //    fixed-level guideline, so a stray one is silently meaningless
      //    stored data rather than a visible error.
      problems.add('A chosen base level applies only to a General guideline');
    }
  }

  // 3. A requisite naming the spell's own Art is meaningless. Duplicate arts
  //    cannot occur here — requisites is keyed by art, so a second requisite
  //    for the same art overwrites rather than duplicates. That was check 4;
  //    it is deleted, not merely unreachable, because the shape now makes it
  //    impossible rather than checked.
  for (final art in requisites.keys) {
    if (art == technique || art == form) {
      problems.add("Requisite art cannot be the spell's own technique or form");
    }
  }

  // 5. selectionMode lives on the catalog entry, not on the record, which is
  //    why this cannot be checked without the modifier list. An id that does
  //    not resolve is tolerated, matching calculateBreakdown's treatment of
  //    an unresolvable modifier as contributing 0.
  final modifiersById = {for (final modifier in modifiers) modifier.id: modifier};
  selectedModifiers.forEach((modifierId, optionIds) {
    final modifier = modifiersById[modifierId];
    if (modifier == null) return;
    if (modifier.selectionMode == ModifierSelectionMode.single &&
        optionIds.length > 1) {
      problems.add('Only one option may be selected for ${modifier.name}');
    }
  });

  if (!isTemplate) {
    // 6. An open slot (realm, Form, "a specific type") is the caster's to fill,
    //    the same completeness requirement chosenBaseLevel already enforces for
    //    a General guideline's level -- a ward with no realm chosen is not yet
    //    a spell. "At least one" (not "every") declared kind, because pevi-G10
    //    declares two alternatives (Form OR a specific type of enchantment) and
    //    either satisfies it; every other entry declares exactly one kind, so
    //    this collapses to "mandatory" for them. Skipped for a template
    //    (Decision 9): a template's chosenSlots may legitimately stay empty
    //    for a declared-open kind until a caster instantiates it.
    if (effect.openSlots.isNotEmpty) {
      final filled = effect.openSlots
          .any((kind) => (chosenSlots[kind.name] ?? '').isNotEmpty);
      if (!filled) {
        final kindNames = effect.openSlots.length == 1
            ? _openSlotDescription(effect.openSlots.single)
            : effect.openSlots.map(_openSlotDescription).join(' or a ');
        problems.add('Choose a $kindNames for this guideline');
      }
    }
  }

  // 7. The converse of check 6: stray chosen-slot data for a kind this
  //    guideline never declared open is silently meaningless, the same
  //    class of bug check 2 closes for a stray chosenBaseLevel. Unlike check
  //    6, this runs for a template too -- a SpellTemplate genuinely carries
  //    chosenSlots, so a stray key is just as much a bug there.
  final openKindNames = effect.openSlots.map((k) => k.name).toSet();
  for (final kind in chosenSlots.keys) {
    if (!openKindNames.contains(kind)) {
      final description = _openSlotKindByName(kind) != null
          ? _openSlotDescription(_openSlotKindByName(kind)!)
          : kind;
      problems.add('A chosen $description applies only to a guideline with an open $description slot');
    }
  }

  // 8. A spell's own Technique/Form is now stored, not derived, so it can
  //    legitimately differ from its base effect's -- but only when that
  //    difference is explained. Symmetric: an unexplained mismatch is a data
  //    bug (the record and its guideline silently disagree); an explanation
  //    attached to a spell that doesn't actually differ is meaningless
  //    decoration, the same class of bug check 2 catches for a stray
  //    chosenBaseLevel. Runs unconditionally -- unlike checks 1, 2 and 6, not
  //    wrapped in `if (!isTemplate)`: a template needs its own
  //    correctly-recorded Technique/Form exactly as much as a spell does.
  final isAnalogy = technique != effect.technique || form != effect.form;
  if (isAnalogy && (analogyRationale == null || analogyRationale.trim().isEmpty)) {
    problems.add(
      "Technique/Form differs from the base effect's own -- "
      'an analogyRationale is required to explain why',
    );
  } else if (!isAnalogy && analogyRationale != null) {
    problems.add(
      'analogyRationale is set but Technique/Form already matches the base '
      "effect's own -- remove it",
    );
  }

  return problems;
}

/// Stands in for the prose of a user-created spell saved before a summary was
/// required (todo item 13).
///
/// Not a derivation: name and stat line both already appear on the card, so
/// deriving from them would add nothing, and the provenance design
/// (2026-07-27) rejected auto-derived summaries as storing derivable data.
/// This states the one true thing instead -- that none was recorded.
const String legacySummaryPlaceholder = 'No summary recorded.';

/// The summary a deserialized record should carry.
///
/// Applied in `fromMap` rather than in the datasource because a backup
/// written before the rule existed hits the identical wall one layer over --
/// `BackupService.importFromJson` builds its spells in a list literal, so one
/// throwing record aborts the whole restore. Read-only: nothing is written
/// back, so there is still no migration story.
String? _backfilledSummary(Map<String, dynamic> map) {
  final summary = map['summary'] as String?;
  final description = map['description'] as String?;
  final hasProse = (summary != null && summary.trim().isNotEmpty) ||
      (description != null && description.trim().isNotEmpty);
  if (hasProse) return summary;
  // Published records are deliberately excluded: one with no prose is an
  // importer bug, and must keep failing loudly.
  return Provenance.fromMap(map).source == PublicationSource.userCreated
      ? legacySummaryPlaceholder
      : summary;
}

/// A saved spell, stored as references into the effect/parameter catalogs.
///
/// This record deliberately holds no copy of any catalog data -- no base
/// level, magnitude. [technique]/[form] are the one exception: they are the
/// spell's own, which may legitimately differ from [baseEffectId]'s own
/// technique/form (see [analogyRationale]) -- so unlike everything else
/// here, they cannot be safely derived and must be stored.
///
/// [summary] is a short paraphrase; [description] is verbatim text from the
/// rulebook. Both are optional individually, and a published spell needs at
/// least one of them.
class Spell {
  final String id;
  final String? name;
  final String baseEffectId;
  final String technique;
  final String form;
  final String rangeId;
  final String durationId;
  final String targetId;
  final Map<String, List<String>> selectedModifiers;
  final Map<String, RequisiteKind> requisites;
  final List<LevelAdjustment> adjustments;
  final String? summary;
  final String? description;
  final int? printedLevel;
  final Provenance provenance;
  final List<String> tags;
  final RitualDeclaration ritualDeclaration;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The level the caster chose for a General guideline. Required when the
  /// referenced [BaseEffect] is General, absent otherwise. The engine reads
  /// it in place of `BaseEffect.baseLevel`.
  final int? chosenBaseLevel;

  /// Slots this spell's guideline declared open, filled in — realm, Form, or
  /// "a specific type", keyed by [OpenSlotKind.name]. Filled by the importer
  /// for a published spell whose prose commits to a value, or by the caster
  /// via [SpellCreationBloc]'s `OpenSlotChosen` otherwise. Empty when the
  /// guideline declares nothing open.
  final Map<String, String> chosenSlots;

  /// The [SpellTemplate] this spell was instantiated from, when it was.
  ///
  /// **Provenance only — nothing dereferences it.** A spell shared between
  /// users without its template validates and computes exactly as if the
  /// field were absent, in the same spirit as `calculateBreakdown` treating
  /// an unresolvable modifier id as contributing 0.
  final String? templateId;

  /// Non-null only when [technique]/[form] differ from the resolved base
  /// effect's own technique/form -- the citation-backed reason a human
  /// chose to apply that guideline outside its own Form. Null whenever they
  /// match; enforced by `validateSpellAgainstCatalog`'s check 8.
  final String? analogyRationale;

  Spell({
    required this.id,
    this.name,
    required this.baseEffectId,
    required this.technique,
    required this.form,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    required this.requisites,
    this.adjustments = const [],
    this.summary,
    this.description,
    this.printedLevel,
    required this.provenance,
    this.tags = const [],
    this.ritualDeclaration = RitualDeclaration.none,
    required this.createdAt,
    required this.updatedAt,
    this.chosenBaseLevel,
    this.chosenSlots = const {},
    this.templateId,
    this.analogyRationale,
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
        'technique': technique,
        'form': form,
        'rangeId': rangeId,
        'durationId': durationId,
        'targetId': targetId,
        'selectedModifiers': selectedModifiers,
        'requisites': requisitesToMap(requisites),
        'adjustments': adjustments.map((a) => a.toMap()).toList(),
        'summary': summary,
        'description': description,
        'printedLevel': printedLevel,
        ...provenance.toMap(),
        'tags': tags,
        'ritualDeclaration': ritualDeclaration.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'chosenBaseLevel': chosenBaseLevel,
        'chosenSlots': chosenSlots,
        'templateId': templateId,
        'analogyRationale': analogyRationale,
      };

  factory Spell.fromMap(Map<String, dynamic> map) => Spell(
        id: requireField<String>(map, 'id', 'Spell'),
        name: map['name'] as String?,
        baseEffectId: requireField<String>(map, 'baseEffectId', 'Spell'),
        technique: requireField<String>(map, 'technique', 'Spell'),
        form: requireField<String>(map, 'form', 'Spell'),
        rangeId: requireField<String>(map, 'rangeId', 'Spell'),
        durationId: requireField<String>(map, 'durationId', 'Spell'),
        targetId: requireField<String>(map, 'targetId', 'Spell'),
        selectedModifiers: (map['selectedModifiers'] as Map?)?.map(
              (k, v) => MapEntry(k as String, List<String>.from(v as List)),
            ) ??
            const {},
        requisites: requisitesFromMap(map['requisites'] as Map<String, dynamic>?, 'Spell'),
        adjustments: (map['adjustments'] as List?)
                ?.map((a) => LevelAdjustment.fromMap(a as Map<String, dynamic>))
                .toList() ??
            [],
        summary: _backfilledSummary(map),
        description: map['description'] as String?,
        printedLevel: map['printedLevel'] as int?,
        provenance: Provenance.fromMap(map),
        tags: (map['tags'] as List?)?.map((t) => t as String).toList() ?? const [],
        ritualDeclaration: map['ritualDeclaration'] == null
            ? RitualDeclaration.none
            : ritualDeclarationFromName(
                requireField<String>(map, 'ritualDeclaration', 'Spell'), 'Spell'),
        createdAt: DateTime.parse(requireField<String>(map, 'createdAt', 'Spell')),
        updatedAt: DateTime.parse(requireField<String>(map, 'updatedAt', 'Spell')),
        chosenBaseLevel: map['chosenBaseLevel'] as int?,
        chosenSlots: chosenSlotsFromMap(map['chosenSlots'] as Map<String, dynamic>?),
        templateId: map['templateId'] as String?,
        analogyRationale: map['analogyRationale'] as String?,
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
  Map<String, RequisiteKind> requisites;
  List<LevelAdjustment> adjustments;
  String? summary;
  String? description;
  int? printedLevel;
  RitualDeclaration ritualDeclaration;
  int? chosenBaseLevel;
  Map<String, String> chosenSlots;
  String? templateId;
  String? analogyRationale;

  SpellDraft({
    String? id,
    this.technique,
    this.form,
    this.baseEffect,
    this.range,
    this.duration,
    this.target,
    Map<String, List<String>>? selectedModifiers,
    Map<String, RequisiteKind>? requisites,
    List<LevelAdjustment>? adjustments,
    this.summary,
    this.description,
    this.printedLevel,
    this.ritualDeclaration = RitualDeclaration.none,
    this.chosenBaseLevel,
    Map<String, String>? chosenSlots,
    this.templateId,
    this.analogyRationale,
  })  : id = id ?? _generateId(),
        selectedModifiers = selectedModifiers ?? {},
        requisites = requisites ?? {},
        adjustments = adjustments ?? [],
        chosenSlots = chosenSlots ?? {};

  static String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  static const String _creo = 'Creo';
  static const String _momentaryDurationId = 'duration-momentary';

  /// A Momentary Creo spell is the one case the rulebook leaves to the caster
  /// (Core Rules line 12351) — the only case `lastingCreation` is offered as
  /// a RitualSection radio option by default, and the only case it is set
  /// automatically.
  bool get isEligibleForLastingCreationDeclaration =>
      technique == _creo && duration?.id == _momentaryDurationId;

  Spell toSpell({required String name, required PublicationSource source}) {
    final missingFields = <String>[
      if (baseEffect == null) 'baseEffect',
      if (technique == null) 'technique',
      if (form == null) 'form',
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
      technique: technique!,
      form: form!,
      rangeId: range!.id,
      durationId: duration!.id,
      targetId: target!.id,
      selectedModifiers: selectedModifiers,
      requisites: requisites,
      adjustments: adjustments,
      summary: summary,
      description: description,
      printedLevel: printedLevel,
      ritualDeclaration: ritualDeclaration,
      chosenBaseLevel: chosenBaseLevel,
      chosenSlots: chosenSlots,
      templateId: templateId,
      analogyRationale: analogyRationale,
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
    Map<String, RequisiteKind>? requisites,
    List<LevelAdjustment>? adjustments,
    String? summary,
    String? description,
    int? printedLevel,
    RitualDeclaration? ritualDeclaration,
    Object? chosenBaseLevel = _unset,
    Map<String, String>? chosenSlots,
    Object? templateId = _unset,
    Object? analogyRationale = _unset,
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
      printedLevel: printedLevel ?? this.printedLevel,
      ritualDeclaration: ritualDeclaration ?? this.ritualDeclaration,
      chosenBaseLevel: identical(chosenBaseLevel, _unset)
          ? this.chosenBaseLevel
          : chosenBaseLevel as int?,
      chosenSlots: chosenSlots ?? this.chosenSlots,
      templateId: identical(templateId, _unset) ? this.templateId : templateId as String?,
      analogyRationale: identical(analogyRationale, _unset)
          ? this.analogyRationale
          : analogyRationale as String?,
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
