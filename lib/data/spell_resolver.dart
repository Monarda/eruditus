import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_template.dart';

/// Joins [Spell] records to the catalogs their ids refer to.
///
/// Lookups are index-backed because [resolveAll] runs over the whole library on
/// every Library tab load, against a 604-entry effect catalog.
///
/// An id with no matching entry yields null rather than throwing: a spell built
/// on a since-deleted custom effect must still list (marked unresolved) instead
/// of taking down the whole Library tab.
class SpellResolver {
  // Mutable (not final): the catalog snapshot taken at construction goes
  // stale the moment a custom effect or parameter is added or deleted
  // elsewhere (e.g. the Settings tab). See [updateCatalogs].
  Map<String, BaseEffect> _effectsById;
  Map<String, Parameter> _parametersById;
  Map<String, Modifier> _modifiersById;

  SpellResolver({
    required List<BaseEffect> effects,
    required List<Parameter> parameters,
    required List<Modifier> modifiers,
  })  : _effectsById = {for (final e in effects) e.id: e},
        _parametersById = {for (final p in parameters) p.id: p},
        _modifiersById = {for (final m in modifiers) m.id: m};

  /// Replaces the known effect/parameter catalog used for id lookups.
  ///
  /// Without this, a resolver built once at app startup would keep resolving
  /// spells against that original snapshot forever: a spell built on a custom
  /// effect added after startup would never resolve, and a spell whose custom
  /// effect was later deleted would keep appearing to resolve. Callers that
  /// hold a long-lived resolver (see `LibraryRepository`) call this whenever
  /// they have a fresher view of the catalog, mirroring how `SpellEngine`
  /// keeps its `allModifiers` current via `updateModifiers`.
  void updateCatalogs({
    required List<BaseEffect> effects,
    required List<Parameter> parameters,
    required List<Modifier> modifiers,
  }) {
    _effectsById = {for (final e in effects) e.id: e};
    _parametersById = {for (final p in parameters) p.id: p};
    _modifiersById = {for (final m in modifiers) m.id: m};
  }

  ResolvedSpell resolve(Spell record) => ResolvedSpell(
        record: record,
        baseEffect: _effectsById[record.baseEffectId],
        range: _parametersById[record.rangeId],
        duration: _parametersById[record.durationId],
        target: _parametersById[record.targetId],
        modifiers: _selectedModifiers(record.selectedModifiers),
      );

  /// The catalog entries [selected]'s keys refer to, skipping ids that no
  /// longer resolve — `calculateBreakdown` already treats an unresolvable
  /// modifier id as contributing 0, and this preserves that.
  List<Modifier> _selectedModifiers(Map<String, List<String>> selected) => [
        for (final id in selected.keys)
          if (_modifiersById[id] case final modifier?) modifier,
      ];

  List<ResolvedSpell> resolveAll(Iterable<Spell> records) =>
      records.map(resolve).toList();

  ResolvedTemplate resolveTemplate(SpellTemplate record) => ResolvedTemplate(
        record: record,
        baseEffect: _effectsById[record.baseEffectId],
        range: _parametersById[record.rangeId],
        duration: _parametersById[record.durationId],
        target: _parametersById[record.targetId],
      );

  List<ResolvedTemplate> resolveAllTemplates(Iterable<SpellTemplate> records) =>
      records.map(resolveTemplate).toList();
}
