import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/spell.dart' show validateSpellProse;
import 'package:eruditus/utils/map_serialization.dart';

/// A published spell the rulebook itself says guideline arithmetic doesn't
/// apply to — its own prose disclaims normal Hermetic design, or its real
/// shape (an event-triggered Duration, two Durations at once) doesn't fit
/// the Range/Duration/Target model regardless of what the prose says.
///
/// A read-only canon record, not a designable spell: [range]/[duration]/
/// [target] are plain strings taken straight from the rulebook's stat line,
/// never catalog ids, and there is no `SpellLevelCalculator` involvement —
/// [rationale] is required precisely because nothing here is computed.
/// See docs/superpowers/specs/2026-08-15-exception-spells-design.md for the
/// full design rationale, including why this is not a subclass of [Spell]
/// or [SpellTemplate].
class ExceptionSpell {
  final String id;
  final String name;
  final String technique;
  final String form;
  final String range;
  final String duration;
  final String target;
  final bool isRitual;

  /// The spell's printed level, or null for the four General-kind entries
  /// (Wizard's Communion, Wizard's Vigil, Aegis of the Hearth, Watching
  /// Ward) which print no level at all.
  final int? printedLevel;

  final String? summary;
  final String? description;

  /// Why this spell doesn't compute — required, unlike [Spell]'s optional
  /// citations, because every entry here must say why it exists outside the
  /// normal guideline system.
  final String rationale;

  final Provenance provenance;
  final List<String> tags;

  ExceptionSpell({
    required this.id,
    required this.name,
    required this.technique,
    required this.form,
    required this.range,
    required this.duration,
    required this.target,
    this.isRitual = false,
    this.printedLevel,
    this.summary,
    this.description,
    required this.rationale,
    required this.provenance,
    this.tags = const [],
  }) {
    final problems = validateSpellProse(
      source: provenance.source,
      summary: summary,
      description: description,
    );
    if (problems.isNotEmpty) {
      throw FormatException('ExceptionSpell: ${problems.join('; ')}');
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'technique': technique,
        'form': form,
        'range': range,
        'duration': duration,
        'target': target,
        'isRitual': isRitual,
        'printedLevel': printedLevel,
        'summary': summary,
        'description': description,
        'rationale': rationale,
        ...provenance.toMap(),
        'tags': tags,
      };

  factory ExceptionSpell.fromMap(Map<String, dynamic> map) => ExceptionSpell(
        id: requireField<String>(map, 'id', 'ExceptionSpell'),
        name: requireField<String>(map, 'name', 'ExceptionSpell'),
        technique: requireField<String>(map, 'technique', 'ExceptionSpell'),
        form: requireField<String>(map, 'form', 'ExceptionSpell'),
        range: requireField<String>(map, 'range', 'ExceptionSpell'),
        duration: requireField<String>(map, 'duration', 'ExceptionSpell'),
        target: requireField<String>(map, 'target', 'ExceptionSpell'),
        isRitual: (map['isRitual'] as bool?) ?? false,
        printedLevel: map['printedLevel'] as int?,
        summary: map['summary'] as String?,
        description: map['description'] as String?,
        rationale: requireField<String>(map, 'rationale', 'ExceptionSpell'),
        provenance: Provenance.fromMap(map),
        tags: (map['tags'] as List?)?.map((t) => t as String).toList() ?? const [],
      );
}
