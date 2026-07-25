import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/engine/spell_level_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = AssetDataLoader();

  test('loadBaseEffects loads all 38 built-in base effects', () async {
    final effects = await loader.loadBaseEffects();

    expect(effects.length, 38);
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

  test('loadSpecialFactors loads all 7 built-in special factors', () async {
    final factors = await loader.loadSpecialFactors();

    expect(factors.length, 7);
    expect(factors.every((f) => f.source == 'built-in'), isTrue);
  });

  test('loadSpellLibrary loads all 27 built-in spells', () async {
    final spells = await loader.loadSpellLibrary();

    expect(spells.length, 27);
    expect(spells.every((s) => s.source == 'built-in'), isTrue);
    expect(spells.every((s) => s.name != null && s.name!.isNotEmpty), isTrue);
  });

  test("every spell's referenced ids exist in the built-in catalogs", () async {
    final spells = await loader.loadSpellLibrary();
    final effects = await loader.loadBaseEffects();
    final parameters = await loader.loadParameters();
    final factors = await loader.loadSpecialFactors();

    // Sanity check: every parameter/effect/factor id referenced by a spell
    // actually exists in its respective built-in list (catches typos in the
    // hand-authored JSON above). Note: this does NOT verify that the spell's
    // calculated level matches its stated level — see the test below for that.
    final effectIds = effects.map((e) => e.id).toSet();
    final parameterIds = parameters.map((p) => p.id).toSet();
    final factorIds = factors.map((f) => f.id).toSet();

    for (final spell in spells) {
      expect(effectIds.contains(spell.baseEffect.id), isTrue,
          reason: '${spell.name}: baseEffect id ${spell.baseEffect.id} not in base_effects.json');
      for (final p in [spell.range, spell.duration, spell.target]) {
        expect(parameterIds.contains(p.parameterId), isTrue,
            reason: '${spell.name}: parameter id ${p.parameterId} not in parameters.json');
      }
      for (final factorId in spell.selectedSpecialFactorIds) {
        expect(factorIds.contains(factorId), isTrue,
            reason: '${spell.name}: special factor id $factorId not in special_factors.json');
      }
    }
  });

  test('every loaded spell calculates to the level stated in its description', () async {
    final spells = await loader.loadSpellLibrary();
    final factors = await loader.loadSpecialFactors();

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
        spell.range.parameter.magnitude,
        spell.duration.parameter.magnitude,
        spell.target.parameter.magnitude,
        ...spell.selectedSpecialFactorIds
            .map((id) => factors.firstWhere((f) => f.id == id).magnitude),
        ...spell.additionalRequisites.map((r) => r.magnitude),
      ];

      final calculatedLevel =
          SpellLevelCalculator.calculate(spell.baseEffect.baseLevel, magnitudes);

      expect(calculatedLevel, statedLevel,
          reason: '${spell.name}: calculated level $calculatedLevel does not match '
              'level $statedLevel stated in description');
    }
  });
}
