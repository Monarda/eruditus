import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/spell.dart';

/// Joins [Spell] records to the catalogs their ids refer to.
///
/// Lookups are index-backed because [resolveAll] runs over the whole library on
/// every Library tab load, against a 604-entry effect catalog.
///
/// An id with no matching entry yields null rather than throwing: a spell built
/// on a since-deleted custom effect must still list (marked unresolved) instead
/// of taking down the whole Library tab.
class SpellResolver {
  final Map<String, BaseEffect> _effectsById;
  final Map<String, Parameter> _parametersById;

  SpellResolver({
    required List<BaseEffect> effects,
    required List<Parameter> parameters,
  })  : _effectsById = {for (final e in effects) e.id: e},
        _parametersById = {for (final p in parameters) p.id: p};

  ResolvedSpell resolve(Spell record) => ResolvedSpell(
        record: record,
        baseEffect: _effectsById[record.baseEffectId],
        range: _parametersById[record.rangeId],
        duration: _parametersById[record.durationId],
        target: _parametersById[record.targetId],
      );

  List<ResolvedSpell> resolveAll(Iterable<Spell> records) =>
      records.map(resolve).toList();
}
