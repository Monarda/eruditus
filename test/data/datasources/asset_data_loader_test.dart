import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';

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

  test('every loaded spell calculates to the level stated in its description', () async {
    final spells = await loader.loadSpellLibrary();
    final effects = await loader.loadBaseEffects();
    final parameters = await loader.loadParameters();
    final factors = await loader.loadSpecialFactors();

    // Sanity check: every parameter/effect/factor id referenced by a spell
    // actually exists in its respective built-in list (catches typos in the
    // hand-authored JSON above).
    final effectIds = effects.map((e) => e.id).toSet();
    final parameterIds = parameters.map((p) => p.id).toSet();
    final factorIds = factors.map((f) => f.id).toSet();

    for (final spell in spells) {
      expect(effectIds.contains(spell.baseEffect.id), isTrue,
          reason: '${spell.name}: baseEffect id ${spell.baseEffect.id} not in base_effects.json');
      for (final p in spell.parameters) {
        expect(parameterIds.contains(p.parameterId), isTrue,
            reason: '${spell.name}: parameter id ${p.parameterId} not in parameters.json');
      }
      for (final factorId in spell.selectedSpecialFactorIds) {
        expect(factorIds.contains(factorId), isTrue,
            reason: '${spell.name}: special factor id $factorId not in special_factors.json');
      }
    }
  });
}
