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

  test('material difficulty covers Muto, Perdo and Rego Terram but not Creo', () async {
    final modifiers = await loader.loadModifiers();
    final material = modifiers.where((m) => m.id.endsWith('-terram-material')).toList();

    expect(material.length, 3);
    expect(material.map((m) => m.scope.technique).toSet(), {'Muto', 'Perdo', 'Rego'});
    expect(material.every((m) => m.scope.form == 'Terram'), isTrue);
    expect(
      material.any((m) => m.scope.appliesTo(technique: 'Creo', form: 'Terram', baseEffectId: 'crte-5')),
      isFalse,
      reason: 'Creo Terram models material as the base effect',
    );
  });

  test('the distance ladder is scoped to its three transport effects', () async {
    final modifiers = await loader.loadModifiers();
    final distance = modifiers.firstWhere((m) => m.id == 'rego-transport-distance');

    expect(distance.scope.effectIds..sort(), ['rehe-10b', 'reig-3c', 'rete-4']);
    expect(distance.scope.technique, isNull);
    expect(distance.scope.form, isNull);
  });

  test('every scoped effectId refers to a real base effect', () async {
    final modifiers = await loader.loadModifiers();
    final effectIds = (await loader.loadBaseEffects()).map((e) => e.id).toSet();

    for (final modifier in modifiers) {
      for (final id in modifier.scope.effectIds) {
        expect(effectIds.contains(id), isTrue,
            reason: '${modifier.id} references unknown base effect $id');
      }
    }
  });

  test('rete-4 draws all three of Size, material and distance', () async {
    final modifiers = await loader.loadModifiers();
    final applicable = modifiers
        .where((m) => m.scope.appliesTo(
            technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4'))
        .map((m) => m.id)
        .toList();

    expect(applicable, containsAll(['size-terram', 'rego-terram-material', 'rego-transport-distance']));
  });
}
