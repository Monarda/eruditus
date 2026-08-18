import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/models/target_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = AssetDataLoader();

  test('loadBaseEffects loads every built-in base effect in the asset file', () async {
    final effects = await loader.loadBaseEffects();

    // base_effects.json is bulk-extracted from the rulebook and grows across
    // many extraction commits, so the expected count is derived from the raw
    // file itself (an oracle independent of loadBaseEffects) rather than a
    // literal number -- a hardcoded count here previously drifted from 38 to
    // 604 without being noticed. This still catches a real loader bug (a
    // dropped or duplicated entry), it just doesn't need updating by hand
    // every time the catalog grows.
    final rawList =
        jsonDecode(await rootBundle.loadString('assets/data/base_effects.json')) as List;
    expect(effects.length, rawList.length,
        reason: 'loadBaseEffects should return exactly the entries present in base_effects.json');
    expect(effects.every((e) => e.provenance.source == PublicationSource.published), isTrue);
    expect(effects.any((e) => e.technique == 'Creo' && e.form == 'Animal'), isTrue);
  });

  test('loadParameters loads all 39 built-in parameters', () async {
    final parameters = await loader.loadParameters();

    expect(parameters.length, 39);
    expect(parameters.every((p) => p.provenance.source == PublicationSource.published), isTrue);
    expect(
      parameters.any((p) => p.name == 'Eye' && p.category == 'Range' && p.magnitude == 1),
      isTrue,
    );
    expect(
      parameters.any((p) => p.name == 'Boundary' && p.category == 'Target' && p.magnitude == 4),
      isTrue,
    );
    expect(parameters.any((p) => p.name == 'Bound'), isFalse,
        reason: 'Bound was a data error; the rulebook name is Boundary');
  });

  test('the five Sensory Magic Targets load with their stated ladder', () async {
    // The magnitudes still follow the book's printed equivalences (Flavor to
    // Individual, Texture to Part, Scent to Group, Sound to Structure,
    // Spectacle to Boundary), because those sentences price the Target. They
    // do not classify it -- all five are `sensorium`. See the 2026-08-18
    // cross-field-parameter-constraints spec.
    final parameters = await loader.loadParameters();
    final byId = {for (final p in parameters) p.id: p};

    const expected = <String, (int, TargetType)>{
      'target-flavor': (0, TargetType.sensorium),
      'target-texture': (1, TargetType.sensorium),
      'target-scent': (2, TargetType.sensorium),
      'target-sound': (3, TargetType.sensorium),
      'target-spectacle': (4, TargetType.sensorium),
    };

    for (final entry in expected.entries) {
      final parameter = byId[entry.key];
      expect(parameter, isNotNull, reason: '${entry.key} missing from parameters.json');
      expect(parameter!.magnitude, entry.value.$1, reason: '${entry.key} magnitude');
      expect(parameter.targetType, entry.value.$2, reason: '${entry.key} targetType');
      expect(parameter.category, 'Target');
      expect(parameter.requiresVirtue, 'Sensory Magic');
      // The rule this carries: HoH:MC forbids these Targets on any spell
      // employing Intellego.
      expect(parameter.scope.excludeTechniques, ['Intellego'], reason: '${entry.key} scope');
    }
  });

  test('the two Glamour guidelines load, gated on the Glamour Mystery', () async {
    // muim-hohmc-10 is the only base level any HoH:MC spell needs that the core
    // catalog cannot supply -- Ball of Abysmal Music, (Base 10, +2 Voice).
    final effects = await loader.loadBaseEffects();
    final byId = {for (final e in effects) e.id: e};

    for (final id in ['crim-hohmc-10', 'muim-hohmc-10']) {
      final effect = byId[id];
      expect(effect, isNotNull, reason: '$id missing from base_effects.json');
      expect(effect!.baseLevel, 10, reason: '$id baseLevel');
      expect(effect.form, 'Imaginem', reason: '$id form');
      expect(effect.requiresVirtue, 'Glamour', reason: '$id requiresVirtue');
    }
    expect(byId['crim-hohmc-10']!.technique, 'Creo');
    expect(byId['muim-hohmc-10']!.technique, 'Muto');
  });

  test('every ritual-only parameter is flagged, including item 17\'s additions', () async {
    final parameters = await loader.loadParameters();

    final flagged = parameters.where((p) => p.requiresRitual).map((p) => p.id).toSet();

    // Hardcoded, unlike the base-effect counts: parameters.json is the small
    // hand-curated list todo item 5 deliberately left as literals. Grew from
    // {duration-year, target-boundary} to include item 17's 5 new
    // ritual-only entries (Until (Condition)/Year + 1, all three Symbol
    // parameters). Bargain and Fire are NOT ritual-only: neither one's own
    // rulebook paragraph (Core Rules, reviewed/ copy) states a Ritual
    // requirement -- unlike Until (Condition) and Year + 1, which explicitly
    // say so (post-final-review fix, item 17).
    expect(flagged, {
      'duration-year', 'target-boundary',
      'duration-until-condition',
      'duration-year-plus-one', 'range-symbol', 'duration-symbol', 'target-symbol',
    });

    // Vision shares Boundary's +4 magnitude but is explicitly not ritual-only
    // (Core Rules line 12345: Formulaic spells "may have Vision target, if
    // they are magical sense spells").
    expect(
      parameters.firstWhere((p) => p.id == 'target-vision').requiresRitual,
      isFalse,
    );
  });

  test(
      'exactly the Faerie Magic, Symbolic Magic and Sensory Magic parameters '
      'are flagged requiresVirtue', () async {
    final parameters = await loader.loadParameters();

    final byVirtue = <String, Set<String>>{};
    for (final parameter in parameters) {
      if (parameter.requiresVirtue == null) continue;
      byVirtue.putIfAbsent(parameter.requiresVirtue!, () => {}).add(parameter.id);
    }

    // Asserted over the key set too, not just each group's members: without
    // it, a sixth virtue group could be added tomorrow with nothing failing.
    expect(byVirtue.keys, {'Faerie Magic', 'Symbolic Magic', 'Sensory Magic'});
    expect(byVirtue['Faerie Magic'], {
      'range-road', 'duration-bargain', 'duration-fire',
      'duration-until-condition', 'duration-year-plus-one', 'target-bloodline',
    });
    expect(byVirtue['Symbolic Magic'], {
      'range-symbol', 'duration-symbol', 'target-symbol',
    });
    expect(byVirtue['Sensory Magic'], {
      'target-flavor', 'target-texture', 'target-scent',
      'target-sound', 'target-spectacle',
    });
  });

  test('every Target declares a targetType, and exactly four are containers',
      () async {
    final parameters = await loader.loadParameters();
    final targets = parameters.where((p) => p.category == 'Target').toList();

    // Hardcoded like the requiresRitual test above, and for the same reason:
    // parameters.json is small and hand-maintained, so a count that drifts
    // silently is the failure mode worth catching.
    expect(targets.length, 19);

    for (final target in targets) {
      expect(target.targetType, isNotNull,
          reason: '${target.id} has no targetType — every Target needs one, '
              'or check 9 silently stops applying to it');
    }

    final containers = targets
        .where((p) => p.targetType == TargetType.container)
        .map((p) => p.id)
        .toSet();
    expect(containers, {
      'target-circle',
      'target-room',
      'target-structure',
      'target-boundary',
    });

    // All five Sensory Magic Targets are TargetType.sensorium, not object or
    // container -- see TargetType's doc comment for why the rulebook's three
    // kinds all contradict HoH:MC's Sensory Magic Targets.
    final sensoria = targets
        .where((p) => p.targetType == TargetType.sensorium)
        .map((p) => p.id)
        .toSet();
    expect(sensoria, {
      'target-flavor',
      'target-texture',
      'target-scent',
      'target-sound',
      'target-spectacle',
    });

    // Bloodline is an object Target that carries its own ongoing rule (a
    // spell "applies to all members of the bloodline born during its
    // duration"), which is the Target's behaviour and not a per-spell design
    // choice. Pinned so nobody later "fixes" it into a container.
    expect(
      parameters.firstWhere((p) => p.id == 'target-bloodline').targetType,
      TargetType.object,
    );
    // Symbol is "essentially a large Group" (Houses of Hermes: Mystery Cults).
    expect(
      parameters.firstWhere((p) => p.id == 'target-symbol').targetType,
      TargetType.object,
    );
  });

  test('Fire is scoped to Ignem and Imaginem; every other parameter is unrestricted', () async {
    final parameters = await loader.loadParameters();

    for (final parameter in parameters) {
      if (parameter.id == 'duration-fire') {
        expect(parameter.scope.forms, ['Ignem', 'Imaginem']);
      } else {
        expect(parameter.scope.forms, isEmpty, reason: parameter.id);
      }
    }
  });

  test('loadBooks includes the Houses of Hermes: Mystery Cults supplement', () async {
    final books = await loader.loadBooks();
    final supplement =
        books.firstWhere((b) => b.id == 'arm5-hohmc');
    expect(supplement.title, 'Ars Magica 5e - Houses of Hermes: Mystery Cults');
    expect(supplement.abbreviation, 'HoH:MC');
    expect(supplement.edition, '5e');
  });

  test('the ritual-flagged base effects are exactly the reviewed sets', () async {
    final effects = await loader.loadBaseEffects();

    Set<String> idsWith(RitualRequirement requirement) => effects
        .where((e) => e.ritualRequirement == requirement)
        .map((e) => e.id)
        .toSet();

    // Asserted as exact SETS, not counts. Todo item 5's reasoning for deriving
    // counts from the file applies to properties that drift as the extraction
    // grows; this is a hand-reviewed membership decision, and a count would
    // pass while an entry silently moved between the two flags.
    expect(idsWith(RitualRequirement.required), {
      'craq-25b', 'crau-25', 'crig-25b', 'crte-25b',
      'pevi-G9', 'pevi-G10',
      'crvi-hohmc-G1', 'revi-hohmc-G1',
    });

    expect(idsWith(RitualRequirement.suggested), {
      // Creo Animal (11)
      'cran-15a', 'cran-20a', 'cran-25b', 'cran-25c', 'cran-25d', 'cran-25e',
      'cran-30a', 'cran-30b', 'cran-35', 'cran-40', 'cran-75',
      // Creo Corpus (21) -- crco-5b reclassified from required during
      // whole-branch review: the rulebook guideline table carries no Ritual
      // marker for it, unlike the other six required entries.
      'crco-5b',
      'crco-15a', 'crco-15c', 'crco-20a', 'crco-20b', 'crco-20c', 'crco-25a',
      'crco-25b', 'crco-25c', 'crco-25d', 'crco-30a', 'crco-30b', 'crco-30d',
      'crco-35a', 'crco-35b', 'crco-35c', 'crco-40', 'crco-45', 'crco-50',
      'crco-55', 'crco-70',
      // Creo Herbam (7)
      'crhe-1e', 'crhe-2c', 'crhe-3b', 'crhe-4', 'crhe-5', 'crhe-10',
      'crhe-15b',
    });

    // Recovery bonuses and suppression effects are sustained by the spell and
    // are deliberately excluded; "Stop the progress of a disease" is contrasted
    // directly with the ritual "Cure a disease" at Core Rules line 12478.
    for (final id in ['cran-1', 'crco-1a', 'cran-25a', 'crco-3b', 'crhe-1a']) {
      expect(
        effects.firstWhere((e) => e.id == id).ritualRequirement,
        RitualRequirement.none,
        reason: '$id is sustained by the spell, not lasting after it',
      );
    }
  });

  test('loadSpellLibrary loads every spell in the asset file', () async {
    final spells = await loader.loadSpellLibrary();

    // Derived from the raw file, not a literal. Item 5 left this as a
    // hardcoded 36 on the reasoning that the library was "small,
    // hand-curated, changed in deliberate reviewed batches, not
    // bulk-extracted". Every clause of that stopped being true when the
    // library became generator output.
    final rawList =
        jsonDecode(await rootBundle.loadString('assets/data/spell_library.json')) as List;
    expect(spells.length, rawList.length,
        reason: 'loadSpellLibrary should return exactly the entries in spell_library.json');
    expect(spells.every((s) => s.provenance.source == PublicationSource.published), isTrue);
    expect(spells.every((s) => s.name != null && s.name!.isNotEmpty), isTrue);
  });

  test('the built-in Ritual spells resolve and calculate to their printed levels',
      () async {
    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final modifiers = await loader.loadModifiers();
    final spells = {for (final s in await loader.loadSpellLibrary()) s.id: s};

    final engine = SpellEngine(allSpells: const [], allModifiers: modifiers);

    const expected = <String, ({int level, bool isRitual, int reasonCount})>{
      'lib-crco-incantation-body-made-whole': (level: 40, isRitual: true, reasonCount: 1),
      'lib-crte-touch-midas': (level: 20, isRitual: true, reasonCount: 1),
      'lib-crco-cheating-reaper': (level: 30, isRitual: true, reasonCount: 1),
      'lib-mume-past-another': (level: 35, isRitual: true, reasonCount: 2),
      'lib-reme-incantation-summoning-dead': (level: 40, isRitual: true, reasonCount: 1),
    };

    expected.forEach((id, want) {
      final spell = spells[id]!;
      final breakdown = engine.calculateBreakdown(
        baseEffect: effects[spell.baseEffectId]!,
        range: parameters[spell.rangeId]!,
        duration: parameters[spell.durationId]!,
        target: parameters[spell.targetId]!,
        selectedModifiers: spell.selectedModifiers,
        requisites: spell.requisites,
        adjustments: spell.adjustments,
        ritualDeclaration: spell.ritualDeclaration,
      );

      expect(breakdown.level, want.level, reason: '$id level');
      expect(breakdown.ritualStatus.isRitual, want.isRitual, reason: '$id isRitual');
      expect(breakdown.ritualStatus.reasons.length, want.reasonCount,
          reason: '$id reason count');
    });

    // Touch of Midas lands exactly on the floor, proving the minimum is a
    // no-op at 20 rather than something that silently adds.
    expect(
      engine
          .calculateBreakdown(
            baseEffect: effects['crte-15a']!,
            range: parameters['range-touch']!,
            duration: parameters['duration-momentary']!,
            target: parameters['target-individual']!,
            selectedModifiers: const {},
            requisites: const {},
            ritualDeclaration: RitualDeclaration.lastingCreation,
          )
          .ritualMinimumApplied,
      isFalse,
    );

    // This spot-checks a handful of named spells; it does not assert that no
    // OTHER spell is a Ritual. That was true when the library was a small,
    // hand-curated 36 entries — it stopped being true once the library
    // became bulk-extracted from the whole rulebook (Ritual is a real,
    // common property, not something added one spell at a time). Full-corpus
    // Ritual-status correctness is assertion 2 in
    // test/data/published_spell_import_test.dart, which checks every spell,
    // not just a named few.
  });

  test('the Faerie Chains familiar-binding base effect loads with its Virtue gate', () async {
    final effects = await loader.loadBaseEffects();
    final effect = effects.firstWhere((e) => e.id == 'crvi-hohmc-G1');

    expect(effect.technique, 'Creo');
    expect(effect.form, 'Vim');
    expect(effect.isGeneral, isTrue);
    expect(effect.ritualRequirement, RitualRequirement.required);
    expect(effect.requiresVirtue, 'Faerie Magic');
    // No effectFormula (post-final-review fix, item 17): this guideline has
    // no reference override, so its own template charges the FULL magnitude
    // for both Touch and Until (Condition) -- the actual total spell level
    // is 25 levels above chosenBaseLevel. deriveGeneralEffect computes a
    // General guideline's displayed strength from chosenBaseLevel alone
    // (correct and load-bearing for every OTHER mightThreshold guideline,
    // all of which have a reference), so it cannot express this guideline's
    // effect strength without either misrepresenting the design line or
    // baking in a fragile magic-number assumption about today's template.
    expect(effect.effectFormula, isNull);
    expect(effect.provenance.citations, [
      const Citation(bookId: 'arm5-hohmc'),
    ]);
  });

  test("every spell's referenced ids exist in the built-in catalogs", () async {
    final spells = await loader.loadSpellLibrary();
    final effects = await loader.loadBaseEffects();
    final parameters = await loader.loadParameters();

    // Sanity check: every parameter/effect id referenced by a spell actually
    // exists in its respective built-in list (catches typos in the
    // hand-authored JSON above). Note: this does NOT verify that the spell's
    // calculated level matches its stated level — see the test below for that.
    final effectIds = effects.map((e) => e.id).toSet();
    final parameterIds = parameters.map((p) => p.id).toSet();

    for (final spell in spells) {
      expect(effectIds.contains(spell.baseEffectId), isTrue,
          reason: '${spell.name}: baseEffect id ${spell.baseEffectId} not in base_effects.json');
      for (final id in [spell.rangeId, spell.durationId, spell.targetId]) {
        expect(parameterIds.contains(id), isTrue,
            reason: '${spell.name}: parameter id $id not in parameters.json');
      }
    }
  });

  test('every loaded spell calculates to the level stated in its description', () async {
    final spells = await loader.loadSpellLibrary();
    final modifiers = await loader.loadModifiers();

    // Reads the rulebook's printed level directly off the spell rather than
    // regex-scraping it out of the prose summary. Scraping made this
    // assertion depend on English prose formatting ("Level N.") and blocked
    // a planned rework of the summary text; printedLevel is its own field
    // precisely so this check does not have to parse prose. A spell with no
    // printed level fails loudly here rather than being silently skipped.
    int levelStatedInDescription(spell) {
      final printedLevel = spell.printedLevel;
      expect(printedLevel, isNotNull,
          reason: '${spell.name}: has no printedLevel');
      return printedLevel as int;
    }

    final effectsById = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parametersById = {for (final p in await loader.loadParameters()) p.id: p};

    // Ask the engine rather than re-summing the magnitudes here. This test
    // kept its own copy of that sum until todo item 29, and the copy drifted
    // exactly as predicted: when item 24 taught the engine about
    // `adjustments`, this list had to be patched separately, and until it was,
    // The Severed Limb Made Whole computed 30 against a printed 25. A General
    // base effect's missing baseLevel is likewise the engine's business —
    // `chosenBaseLevel` supplies it.
    //
    // `allParameters` is left empty, matching assertion 1 in
    // published_spell_import_test.dart, so neither oracle applies the
    // base-effect reference discount.
    final engine = SpellEngine(allSpells: const [], allModifiers: modifiers);

    for (final spell in spells) {
      final breakdown = engine.calculateBreakdown(
        baseEffect: effectsById[spell.baseEffectId]!,
        chosenBaseLevel: spell.chosenBaseLevel,
        range: parametersById[spell.rangeId]!,
        duration: parametersById[spell.durationId]!,
        target: parametersById[spell.targetId]!,
        selectedModifiers: spell.selectedModifiers,
        requisites: spell.requisites,
        adjustments: spell.adjustments,
        ritualDeclaration: spell.ritualDeclaration,
      );

      expect(breakdown.level, levelStatedInDescription(spell),
          reason: '${spell.name}: calculated level does not match the stated level');
    }
  });

  test('loadModifiers loads the built-in modifier definitions', () async {
    final modifiers = await loader.loadModifiers();

    expect(modifiers, isNotEmpty);
    expect(modifiers.every((m) => m.provenance.source == PublicationSource.published), isTrue);

    final creoImaginem = modifiers.firstWhere((m) => m.id == 'crim-complexity');
    expect(creoImaginem.selectionMode, ModifierSelectionMode.multi);
    expect(creoImaginem.scope.technique, 'Creo');
    expect(creoImaginem.scope.form, 'Imaginem');
    expect(creoImaginem.optionById('crim-directed-image')?.magnitude, 2);
  });

  test('every modifier option id is unique across all modifiers', () async {
    final modifiers = await loader.loadModifiers();
    final ids = [for (final m in modifiers) for (final o in m.options) o.id];

    expect(ids.length, ids.toSet().length,
        reason: 'duplicate option ids would make selections ambiguous');
  });

  test('the library covers more than one Form', () async {
    final spells = await loader.loadSpellLibrary();
    final effects = await loader.loadBaseEffects();
    final effectsById = {for (final e in effects) e.id: e};
    final forms = spells.map((s) => effectsById[s.baseEffectId]!.form).toSet();

    expect(forms.length, greaterThan(1),
        reason: 'a single-Form library cannot exercise Form-scoped modifiers');
    expect(forms, contains('Terram'));
  });

  test('at least one library spell selects a single-select modifier', () async {
    final spells = await loader.loadSpellLibrary();
    final modifiers = await loader.loadModifiers();
    final singleIds = modifiers
        .where((m) => m.selectionMode == ModifierSelectionMode.single)
        .map((m) => m.id)
        .toSet();

    expect(
      spells.any((s) => s.selectedModifiers.keys.any(singleIds.contains)),
      isTrue,
    );
  });

  test('loadBooks loads the seeded books catalog', () async {
    final books = await loader.loadBooks();

    expect(books, isNotEmpty);
    final core = books.firstWhere((b) => b.id == 'arm5-core');
    expect(core.title, 'Ars Magica Fifth Edition');
    expect(core.abbreviation, 'ArM5');
    expect(core.edition, '5e');
  });

  test('every book id is unique', () async {
    final books = await loader.loadBooks();
    final ids = books.map((b) => b.id).toList();

    expect(ids.length, ids.toSet().length,
        reason: 'duplicate book ids would make citations ambiguous');
  });

  test("every spell's cited book ids exist in the books catalog", () async {
    final spells = await loader.loadSpellLibrary();
    final books = await loader.loadBooks();
    final bookIds = books.map((b) => b.id).toSet();

    for (final spell in spells) {
      expect(spell.provenance.source, PublicationSource.published,
          reason: '${spell.name}: every library spell should be published');
      expect(spell.provenance.citations, isNotEmpty,
          reason: '${spell.name}: a published spell needs at least one citation');
      for (final citation in spell.provenance.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${spell.name}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });

  test("every base effect's cited book ids exist in the books catalog", () async {
    final effects = await loader.loadBaseEffects();
    final books = await loader.loadBooks();
    final bookIds = books.map((b) => b.id).toSet();

    for (final effect in effects) {
      for (final citation in effect.provenance.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${effect.id}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });

  test("every parameter's cited book ids exist in the books catalog", () async {
    final parameters = await loader.loadParameters();
    final books = await loader.loadBooks();
    final bookIds = books.map((b) => b.id).toSet();

    for (final parameter in parameters) {
      for (final citation in parameter.provenance.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${parameter.id}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });

  test("every modifier's cited book ids exist in the books catalog", () async {
    final modifiers = await loader.loadModifiers();
    final books = await loader.loadBooks();
    final bookIds = books.map((b) => b.id).toSet();

    for (final modifier in modifiers) {
      for (final citation in modifier.provenance.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${modifier.id}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });

  test('loads every template in the asset', () async {
    final raw = jsonDecode(
        await File('assets/data/spell_templates.json').readAsString()) as List;

    final templates = await AssetDataLoader().loadSpellTemplates();

    expect(templates, hasLength(raw.length));
  });

  test('every template references a General base effect', () async {
    final effects = {
      for (final e in await AssetDataLoader().loadBaseEffects()) e.id: e,
    };

    for (final template in await AssetDataLoader().loadSpellTemplates()) {
      expect(effects[template.baseEffectId]?.isGeneral, isTrue,
          reason: '${template.id} points at a non-General base effect');
    }
  });

  test('the Faerie Chains template computes its Ritual status from Until (Condition)', () async {
    final templates = await loader.loadSpellTemplates();
    final effects = await loader.loadBaseEffects();
    final parameters = await loader.loadParameters();

    final template =
        templates.firstWhere((t) => t.id == 'tpl-crvi-faerie-chains-familiar-slave');
    final baseEffect = effects.firstWhere((e) => e.id == template.baseEffectId);
    final range = parameters.firstWhere((p) => p.id == template.rangeId);
    final duration = parameters.firstWhere((p) => p.id == template.durationId);
    final target = parameters.firstWhere((p) => p.id == template.targetId);

    expect(range.id, 'range-touch');
    expect(duration.id, 'duration-until-condition');
    expect(duration.requiresRitual, isTrue);
    expect(duration.requiresVirtue, 'Faerie Magic');
    expect(baseEffect.requiresVirtue, 'Faerie Magic');
    expect(baseEffect.isGeneral, isTrue);

    final engine = SpellEngine(allSpells: const [], allParameters: parameters);
    // Binding a creature with Might 5: level must be >= 20 (Might + 15).
    final breakdown = engine.calculateBreakdown(
      baseEffect: baseEffect,
      chosenBaseLevel: 20,
      range: range,
      duration: duration,
      target: target,
      selectedModifiers: template.selectedModifiers,
      requisites: template.requisites,
    );

    expect(breakdown.ritualStatus.isRitual, isTrue);
    expect(breakdown.ritualStatus.reasons, containsAll([
      RitualReason.ritualOnlyDuration,
      RitualReason.guideline,
    ]));
    // 20 (chosen base, already above the level-5 additive tier) + Touch(1)*5
    // + Until (Condition)(4)*5 = 20 + 5 + 20 = 45. The base effect has no
    // reference override, so both parameters charge their full magnitude
    // (unlike a ward guideline, whose own text states it already assumes a
    // non-standard Range/Duration/Target for free).
    expect(breakdown.level, 45);
  });

  test('loads every exception in the asset', () async {
    final raw = jsonDecode(
        await File('assets/data/spell_exceptions.json').readAsString()) as List;

    final exceptions = await AssetDataLoader().loadSpellExceptions();

    expect(exceptions, hasLength(raw.length));
    expect(exceptions, hasLength(8));
  });

  test('every exception carries a rationale', () async {
    for (final exception in await AssetDataLoader().loadSpellExceptions()) {
      expect(exception.rationale, isNotEmpty, reason: exception.name);
    }
  });

  test('exactly six exceptions have no printed level', () async {
    final exceptions = await AssetDataLoader().loadSpellExceptions();
    final generalKind = exceptions.where((e) => e.printedLevel == null);
    expect(generalKind.length, 6);
  });

  test('the elaborate-effect modifier is globally scoped with a 0-3 ladder', () async {
    final modifiers = await loader.loadModifiers();
    final elaborate = modifiers.firstWhere((m) => m.id == 'elaborate-effect');

    expect(elaborate.scope.technique, isNull,
        reason: 'the rule applies to any Technique');
    expect(elaborate.scope.form, isNull, reason: 'the rule applies to any Form');
    expect(elaborate.selectionMode, ModifierSelectionMode.single);
    expect(elaborate.options.map((o) => o.magnitude).toList(), [0, 1, 2, 3]);
  });

  test('repeat loads return the identical parsed list, not a re-parse', () async {
    final loader = AssetDataLoader();

    final first = await loader.loadBaseEffects();
    final second = await loader.loadBaseEffects();

    // Identity, not equality: a re-parse would produce an equal-but-distinct
    // list. ConfigurationRepository.getAllEffects delegates straight here and
    // is called by both SpellRepository._refreshResolver (every save) and
    // LibraryRepository._refreshResolver (every Library tab visit).
    expect(identical(first, second), isTrue);
  });

  test('a cached list cannot be mutated by one caller and seen by another', () async {
    final loader = AssetDataLoader();
    final effects = await loader.loadBaseEffects();

    expect(() => effects.clear(), throwsUnsupportedError);
  });
}
