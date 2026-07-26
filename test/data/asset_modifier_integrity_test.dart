import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = AssetDataLoader();

  // Mentem and Vim: "Size modifiers don't apply to ... effects with
  // Individual targets" — core rules, Base Individuals table.
  const sizeExemptForms = ['Mentem', 'Vim'];

  test('every Form except Mentem and Vim has exactly one Size ladder', () async {
    final modifiers = await loader.loadModifiers();
    final sizeLadders = modifiers.where((m) => m.id.startsWith('size-')).toList();

    expect(sizeLadders.length, ArsForms.all.length - sizeExemptForms.length);
    for (final form in ArsForms.all) {
      final ladder = sizeLadders.where((m) => m.scope.form == form);
      if (sizeExemptForms.contains(form)) {
        expect(ladder, isEmpty, reason: '$form is exempt from Size');
        continue;
      }
      expect(ladder.length, 1, reason: '$form should have exactly one Size ladder');
      expect(ladder.first.scope.technique, isNull,
          reason: 'Size applies regardless of Technique, bar the exclusion below');
      expect(ladder.first.selectionMode, ModifierSelectionMode.single);
    }
  });

  test('no Size ladder is offered for Intellego', () async {
    final modifiers = await loader.loadModifiers();

    for (final ladder in modifiers.where((m) => m.id.startsWith('size-'))) {
      expect(ladder.scope.excludeTechniques, contains('Intellego'),
          reason: '${ladder.id}: Intellego spells are not affected by Target size');
      expect(
        ladder.scope.appliesTo(
            technique: 'Intellego', form: ladder.scope.form, baseEffectId: 'any'),
        isFalse,
      );
    }
  });

  test('every Size ladder uses the universal x10 magnitude progression', () async {
    final modifiers = await loader.loadModifiers();

    for (final ladder in modifiers.where((m) => m.id.startsWith('size-'))) {
      final magnitudes = ladder.options.map((o) => o.magnitude).toList();
      expect(magnitudes, List.generate(magnitudes.length, (i) => i),
          reason: '${ladder.id}: adding one magnitude multiplies size by ten, so '
              'rungs must run 0, 1, 2, ... — magnitudes are not per-Form');
    }
  });

  test('every Size ladder names its base Individual on the first rung', () async {
    final modifiers = await loader.loadModifiers();

    for (final ladder in modifiers.where((m) => m.id.startsWith('size-'))) {
      expect(ladder.options.first.baseIndividual, isNotNull,
          reason: '${ladder.id} must say what one Individual is');
    }
  });

  test('Aquam base Individual sub-types carry no magnitude', () async {
    final modifiers = await loader.loadModifiers();
    final aquam = modifiers.firstWhere((m) => m.id == 'aquam-base-individual');

    expect(aquam.options.length, 5);
    expect(aquam.options.every((o) => o.magnitude == 0), isTrue,
        reason: 'a sub-type fixes what one Individual is; it does not change the level');
    expect(aquam.options.every((o) => o.baseIndividual != null), isTrue);
  });

  test('every modifier option id is unique across all modifiers', () async {
    final modifiers = await loader.loadModifiers();
    final ids = [for (final m in modifiers) for (final o in m.options) o.id];

    expect(ids.length, ids.toSet().length);
  });
}
