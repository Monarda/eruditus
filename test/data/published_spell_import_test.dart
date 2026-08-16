import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/spell.dart';

/// Assertions 1-4 of the published spell import harness.
/// See docs/superpowers/specs/2026-07-28-published-spell-import-design.md
///
/// Assertion 5 (regeneration is clean) lives in
/// scripts/spell_import/tests/test_extract.py, because it has to run the
/// extractor. Both suites must run in CI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = AssetDataLoader();

  /// The rulebook's printed level, read off the spell's own typed field.
  ///
  /// This used to regex-scrape `Level (\d+)\.` out of the summary prose, which
  /// made the harness's primary assertion depend on English prose formatting
  /// and pinned the `" Level N."` suffix in place (see .superpowers/todo.md
  /// item 31). `printedLevel` is emitted as its own field precisely so this
  /// oracle does not have to parse prose. A spell carrying no printed level
  /// fails loudly here rather than being silently skipped.
  int printedLevelOf(Spell spell) {
    final printed = spell.printedLevel;
    expect(printed, isNotNull, reason: '${spell.name}: has no printedLevel');
    return printed as int;
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
        adjustments: spell.adjustments,
        ritualDeclaration: spell.ritualDeclaration,
        chosenBaseLevel: spell.chosenBaseLevel,
      );
      final want = printedLevelOf(spell);
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
            adjustments: spell.adjustments,
            ritualDeclaration: spell.ritualDeclaration,
            chosenBaseLevel: spell.chosenBaseLevel,
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

  test('assertion 7: every published spell and template satisfies the catalog invariants', () async {
    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final modifiers = await loader.loadModifiers();

    final failures = <String>[];

    for (final spell in await loader.loadSpellLibrary()) {
      final effect = effects[spell.baseEffectId];
      // Assertion 4 already covers an id that does not resolve.
      if (effect == null) continue;
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: spell.technique,
        form: spell.form,
        analogyRationale: spell.analogyRationale,
        chosenBaseLevel: spell.chosenBaseLevel,
        requisites: spell.requisites,
        selectedModifiers: spell.selectedModifiers,
        chosenSlots: spell.chosenSlots,
        modifiers: modifiers,
      );
      if (problems.isNotEmpty) {
        failures.add('${spell.name} (${spell.id}): ${problems.join('; ')}');
      }
    }

    for (final template in await loader.loadSpellTemplates()) {
      final effect = effects[template.baseEffectId];
      if (effect == null) continue;
      // isTemplate: a General template legitimately has no chosen level --
      // supplying one is what instantiating it means. Checks 3, 4, 5 and 8
      // still apply.
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: template.technique,
        form: template.form,
        analogyRationale: template.analogyRationale,
        chosenBaseLevel: null,
        requisites: template.requisites,
        selectedModifiers: template.selectedModifiers,
        chosenSlots: template.chosenSlots,
        modifiers: modifiers,
        isTemplate: true,
      );
      if (problems.isNotEmpty) {
        failures.add('${template.name} (${template.id}): ${problems.join('; ')}');
      }
    }

    expect(failures, isEmpty,
        reason: 'published assets break catalog invariants:\n${failures.join('\n')}');
  });

  test(
      "Circular Ward against Demons' chosenSlots survives the asset-load path "
      'and instantiates cleanly', () async {
    // Not covered by assertions 1-7 above: every other assertion here reads
    // spell.chosenSlots/template.chosenSlots straight off the parsed model,
    // so a future importer key-rename or serialization drift (e.g. emit.py
    // starts writing "chosenSlot" singular, or the wire key stops matching
    // OpenSlotKind.name) would silently produce an empty map everywhere and
    // still pass every other test. This test pins the real corpus value.
    final templates = await loader.loadSpellTemplates();
    final template = templates.firstWhere((t) => t.name == 'Circular Ward against Demons');

    expect(template.chosenSlots, {'realm': 'Infernal'});

    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final modifiers = await loader.loadModifiers();
    final baseEffect = effects[template.baseEffectId]!;

    // Instantiate the template into a SpellDraft the same way
    // SpellCreationBloc's TemplateInstantiated handler does: technique/form/
    // analogyRationale seeded from the *template's own* fields (not derived
    // from the base effect -- they may legitimately diverge, see
    // Spell.analogyRationale), chosenSlots carried across verbatim. The
    // guideline is General (revi-G1), so a caster also fills in the level --
    // the same as the real handler leaves for the level field.
    final draft = SpellDraft(
      technique: template.technique,
      form: template.form,
      baseEffect: baseEffect,
      range: parameters[template.rangeId],
      duration: parameters[template.durationId],
      target: parameters[template.targetId],
      selectedModifiers: template.selectedModifiers,
      requisites: template.requisites,
      adjustments: template.adjustments,
      summary: template.summary,
      description: template.description,
      chosenSlots: template.chosenSlots,
      chosenBaseLevel: 20,
      analogyRationale: template.analogyRationale,
    );

    final spell = draft.toSpell(name: template.name, source: PublicationSource.userCreated);
    expect(spell.chosenSlots, {'realm': 'Infernal'});

    final problems = validateSpellAgainstCatalog(
      effect: baseEffect,
      technique: spell.technique,
      form: spell.form,
      analogyRationale: spell.analogyRationale,
      chosenBaseLevel: spell.chosenBaseLevel,
      requisites: spell.requisites,
      selectedModifiers: spell.selectedModifiers,
      chosenSlots: spell.chosenSlots,
      modifiers: modifiers,
    );

    expect(problems, isEmpty, reason: problems.join('; '));
  });

  test(
      "Wizard's Boost (Form) has no committed Form (case 2), but a caster's "
      'choice at instantiation validates cleanly', () async {
    final templates = await loader.loadSpellTemplates();
    final template = templates.firstWhere((t) => t.name == "Wizard's Boost (Form)");

    // Case 2: the template itself never commits to one Form -- its own
    // prose says "one for each Hermetic Form" -- so chosenSlots stays empty,
    // same rule as Wind of Mundane Silence's realm case in Part A.
    expect(template.chosenSlots, isEmpty);

    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final modifiers = await loader.loadModifiers();
    final baseEffect = effects[template.baseEffectId]!;

    Spell instantiate({required Map<String, String> chosenSlots}) {
      final draft = SpellDraft(
        technique: baseEffect.technique,
        form: baseEffect.form,
        baseEffect: baseEffect,
        range: parameters[template.rangeId],
        duration: parameters[template.durationId],
        target: parameters[template.targetId],
        selectedModifiers: template.selectedModifiers,
        requisites: template.requisites,
        adjustments: template.adjustments,
        summary: template.summary,
        description: template.description,
        chosenSlots: chosenSlots,
        chosenBaseLevel: 20,
      );
      return draft.toSpell(name: template.name, source: PublicationSource.userCreated);
    }

    // A caster who instantiates without picking a Form gets a real,
    // catchable problem -- the template's completeness rule (Decision 9)
    // does not extend to the concrete Spell it becomes.
    final unfilled = instantiate(chosenSlots: const {});
    final unfilledProblems = validateSpellAgainstCatalog(
      effect: baseEffect,
      technique: unfilled.technique,
      form: unfilled.form,
      analogyRationale: unfilled.analogyRationale,
      chosenBaseLevel: unfilled.chosenBaseLevel,
      requisites: unfilled.requisites,
      selectedModifiers: unfilled.selectedModifiers,
      chosenSlots: unfilled.chosenSlots,
      modifiers: modifiers,
    );
    expect(unfilledProblems, contains('Choose a Form for this guideline'));

    // Filling it in satisfies check 6, same real catalog entry.
    final filled = instantiate(chosenSlots: const {'form': 'Ignem'});
    final filledProblems = validateSpellAgainstCatalog(
      effect: baseEffect,
      technique: filled.technique,
      form: filled.form,
      analogyRationale: filled.analogyRationale,
      chosenBaseLevel: filled.chosenBaseLevel,
      requisites: filled.requisites,
      selectedModifiers: filled.selectedModifiers,
      chosenSlots: filled.chosenSlots,
      modifiers: modifiers,
    );
    expect(filledProblems, isEmpty, reason: filledProblems.join('; '));
  });
}
