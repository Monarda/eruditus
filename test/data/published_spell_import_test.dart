import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/publication_source.dart';

/// Assertions 1-4 of the published spell import harness.
/// See docs/superpowers/specs/2026-07-28-published-spell-import-design.md
///
/// Assertion 5 (regeneration is clean) lives in
/// scripts/spell_import/tests/test_extract.py, because it has to run the
/// extractor. Both suites must run in CI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = AssetDataLoader();

  /// The printed level, which every generated summary ends with.
  int printedLevel(String? summary) {
    final match = RegExp(r'Level (\d+)\.$').firstMatch((summary ?? '').trim());
    expect(match, isNotNull, reason: 'summary must end with "Level N.": "$summary"');
    return int.parse(match!.group(1)!);
  }

  test('assertion 1: every spell computes to its printed level', () async {
    final spells = await loader.loadSpellLibrary();
    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final engine = SpellEngine(allSpells: const [], allModifiers: await loader.loadModifiers());

    final mismatches = <String>[];
    for (final spell in spells) {
      final breakdown = engine.calculateBreakdown(
        baseEffect: effects[spell.baseEffectId]!,
        range: parameters[spell.rangeId]!,
        duration: parameters[spell.durationId]!,
        target: parameters[spell.targetId]!,
        selectedModifiers: spell.selectedModifiers,
        requisites: spell.requisites,
        ritualDeclaration: spell.ritualDeclaration,
      );
      final want = printedLevel(spell.summary);
      if (breakdown.level != want) {
        mismatches.add('${spell.name}: computed ${breakdown.level}, printed $want');
      }
    }

    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
  });

  test('assertion 2: derived Ritual status matches the printed Ritual flag', () async {
    // The oracle that does not depend on the base effect being right, and so
    // is sensitive to precisely what assertion 1 is blind to.
    //
    // Stated per-spell, not as a count. 39 of the 360 published spells print
    // Ritual but only 19 fall in the importable set; a count assertion would
    // be wrong on the day it lands and would need editing every time a
    // blocker clears.
    final spells = await loader.loadSpellLibrary();
    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final engine = SpellEngine(allSpells: const [], allModifiers: await loader.loadModifiers());

    final raw = jsonDecode(await rootBundle.loadString('assets/data/spell_library.json')) as List;
    final printedRitual = {
      for (final entry in raw.cast<Map<String, dynamic>>())
        entry['id'] as String: entry['ritualDeclaration'] != null,
    };

    final disagreements = <String>[];
    for (final spell in spells) {
      final derived = engine
          .calculateBreakdown(
            baseEffect: effects[spell.baseEffectId]!,
            range: parameters[spell.rangeId]!,
            duration: parameters[spell.durationId]!,
            target: parameters[spell.targetId]!,
            selectedModifiers: spell.selectedModifiers,
            requisites: spell.requisites,
            ritualDeclaration: spell.ritualDeclaration,
          )
          .ritualStatus
          .isRitual;

      if (derived != printedRitual[spell.id]) {
        disagreements.add(
          '${spell.name}: derived $derived, rulebook prints ${printedRitual[spell.id]}',
        );
      }
    }

    expect(disagreements, isEmpty, reason: disagreements.join('\n'));
  });

  test('assertion 3: every ambiguous base effect has a ledger entry', () async {
    // Enforced in full by the extractor, which refuses to write an
    // unresolved spell. This is the standing guard on the committed asset:
    // no spell may reference a base effect at a level where the catalog
    // offers alternatives without a recorded decision.
    final spells = await loader.loadSpellLibrary();
    final effects = await loader.loadBaseEffects();

    final ledgerJson = jsonDecode(
      await File('scripts/spell_import/resolutions.json').readAsString(),
    ) as Map<String, dynamic>;

    final undocumented = <String>[];
    for (final spell in spells) {
      final chosen = effects.firstWhere((e) => e.id == spell.baseEffectId);
      final candidates = effects
          .where((e) =>
              e.technique == chosen.technique &&
              e.form == chosen.form &&
              e.baseLevel == chosen.baseLevel)
          .map((e) => e.id)
          .toSet();
      if (candidates.length > 1 && !ledgerJson.containsKey(spell.id)) {
        undocumented.add('${spell.name}: ${candidates.length} candidates, no ledger entry');
      }
    }

    expect(undocumented, isEmpty, reason: undocumented.join('\n'));
  });

  test('assertion 4: every referenced id resolves', () async {
    final spells = await loader.loadSpellLibrary();
    final effectIds = (await loader.loadBaseEffects()).map((e) => e.id).toSet();
    final parameterIds = (await loader.loadParameters()).map((p) => p.id).toSet();
    final modifiers = await loader.loadModifiers();
    final bookIds = (await loader.loadBooks()).map((b) => b.id).toSet();

    for (final spell in spells) {
      expect(effectIds, contains(spell.baseEffectId), reason: spell.name);
      for (final id in [spell.rangeId, spell.durationId, spell.targetId]) {
        expect(parameterIds, contains(id), reason: '${spell.name}: $id');
      }
      spell.selectedModifiers.forEach((modifierId, optionIds) {
        final modifier = modifiers.where((m) => m.id == modifierId);
        expect(modifier, isNotEmpty, reason: '${spell.name}: modifier $modifierId');
        for (final optionId in optionIds) {
          expect(modifier.first.optionById(optionId), isNotNull,
              reason: '${spell.name}: option $optionId');
        }
      });
      expect(spell.provenance.source, PublicationSource.published, reason: spell.name);
      for (final citation in spell.provenance.citations) {
        expect(bookIds, contains(citation.bookId), reason: spell.name);
      }
    }
  });
}
