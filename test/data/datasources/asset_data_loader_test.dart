import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/engine/spell_level_calculator.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/ritual_declaration.dart';

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

  test('loadParameters loads all 25 built-in parameters', () async {
    final parameters = await loader.loadParameters();

    expect(parameters.length, 25);
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

  test('exactly Year and Boundary are flagged ritual-only', () async {
    final parameters = await loader.loadParameters();

    final flagged = parameters.where((p) => p.requiresRitual).map((p) => p.id).toSet();

    // Hardcoded, unlike the base-effect counts: parameters.json is the small
    // hand-curated list todo item 5 deliberately left as literals.
    expect(flagged, {'duration-year', 'target-boundary'});

    // Vision shares Boundary's +4 magnitude but is explicitly not ritual-only
    // (Core Rules line 12345: Formulaic spells "may have Vision target, if
    // they are magical sense spells").
    expect(
      parameters.firstWhere((p) => p.id == 'target-vision').requiresRitual,
      isFalse,
    );
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
            requisites: const [],
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

    int levelStatedInDescription(spell) {
      final match = RegExp(r'Level (\d+)\.').firstMatch(spell.summary ?? '');
      expect(match, isNotNull,
          reason: '${spell.name}: summary does not contain a "Level N." phrase '
              '(summary was: "${spell.summary}")');
      return int.parse(match!.group(1)!);
    }

    final effects = await loader.loadBaseEffects();
    final parameters = await loader.loadParameters();
    final effectsById = {for (final e in effects) e.id: e};
    final parametersById = {for (final p in parameters) p.id: p};

    for (final spell in spells) {
      final statedLevel = levelStatedInDescription(spell);
      final baseEffect = effectsById[spell.baseEffectId]!;

      final magnitudes = [
        parametersById[spell.rangeId]!.magnitude,
        parametersById[spell.durationId]!.magnitude,
        parametersById[spell.targetId]!.magnitude,
        for (final entry in spell.selectedModifiers.entries)
          for (final optionId in entry.value)
            modifiers.firstWhere((m) => m.id == entry.key).optionById(optionId)!.magnitude,
        ...spell.requisites.map((r) => r.magnitude),
      ];

      expect(SpellLevelCalculator.calculate(baseEffect.baseLevel, magnitudes), statedLevel,
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
}
