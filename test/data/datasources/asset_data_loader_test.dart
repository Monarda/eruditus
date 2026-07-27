import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/engine/spell_level_calculator.dart';
import 'package:eruditus/models/book.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/spell_source.dart';

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
    expect(effects.every((e) => e.source == 'published'), isTrue);
    expect(effects.any((e) => e.technique == 'Creo' && e.form == 'Animal'), isTrue);
  });

  test('loadParameters loads all 17 built-in parameters', () async {
    final parameters = await loader.loadParameters();

    expect(parameters.length, 17);
    expect(
      parameters.any((p) => p.name == 'Touch' && p.category == 'Range' && p.magnitude == 1),
      isTrue,
    );
  });

  test('loadSpellLibrary loads all 30 built-in spells', () async {
    final spells = await loader.loadSpellLibrary();

    expect(spells.length, 30);
    expect(spells.every((s) => s.source == SpellSource.published), isTrue);
    expect(spells.every((s) => s.name != null && s.name!.isNotEmpty), isTrue);
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
    expect(modifiers.every((m) => m.source == 'published'), isTrue);

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
      expect(spell.source, SpellSource.published,
          reason: '${spell.name}: every library spell should be published');
      expect(spell.citations, isNotEmpty,
          reason: '${spell.name}: a published spell needs at least one citation');
      for (final citation in spell.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${spell.name}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });
}
