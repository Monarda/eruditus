import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/engine/spell_level_calculator.dart';
import 'package:eruditus/models/modifier.dart';

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
    expect(effects.every((e) => e.source == 'built-in'), isTrue);
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
    expect(spells.every((s) => s.source == 'built-in'), isTrue);
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
      expect(effectIds.contains(spell.baseEffect.id), isTrue,
          reason: '${spell.name}: baseEffect id ${spell.baseEffect.id} not in base_effects.json');
      for (final p in [spell.range, spell.duration, spell.target]) {
        expect(parameterIds.contains(p.id), isTrue,
            reason: '${spell.name}: parameter id ${p.id} not in parameters.json');
      }
    }
  });

  test('every loaded spell calculates to the level stated in its description', () async {
    final spells = await loader.loadSpellLibrary();
    final modifiers = await loader.loadModifiers();

    int levelStatedInDescription(spell) {
      final match = RegExp(r'Level (\d+)\.').firstMatch(spell.description ?? '');
      expect(match, isNotNull,
          reason: '${spell.name}: description does not contain a "Level N." phrase '
              '(description was: "${spell.description}")');
      return int.parse(match!.group(1)!);
    }

    for (final spell in spells) {
      final statedLevel = levelStatedInDescription(spell);

      final magnitudes = [
        spell.range.magnitude,
        spell.duration.magnitude,
        spell.target.magnitude,
        for (final entry in spell.selectedModifiers.entries)
          for (final optionId in entry.value)
            modifiers.firstWhere((m) => m.id == entry.key).optionById(optionId)!.magnitude,
        ...spell.requisites.map((r) => r.magnitude),
      ];

      final calculatedLevel =
          SpellLevelCalculator.calculate(spell.baseEffect.baseLevel, magnitudes);

      expect(calculatedLevel, statedLevel,
          reason: '${spell.name}: calculated level $calculatedLevel does not match '
              'level $statedLevel stated in description');
    }
  });

  test('loadModifiers loads the built-in modifier definitions', () async {
    final modifiers = await loader.loadModifiers();

    expect(modifiers, isNotEmpty);
    expect(modifiers.every((m) => m.source == 'built-in'), isTrue);

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
    final forms = spells.map((s) => s.form).toSet();

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
}
