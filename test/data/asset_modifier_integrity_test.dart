import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = AssetDataLoader();

  // Vim: "Size modifiers don't apply to ... effects with Individual targets"
  // — core rules, Base Individuals table. Mentem is an exception: per the
  // Definitive Edition Mentem Guidelines, Size affects the number of targets.
  const sizeExemptForms = ['Vim'];

  test('every Form except Vim has exactly one Size ladder', () async {
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

  test('size-mentem excludes Individual targets, since minds have no size', () async {
    final modifiers = await loader.loadModifiers();
    final sizeMentem = modifiers.firstWhere((m) => m.id == 'size-mentem');

    expect(sizeMentem.scope.excludeTargets, contains('target-individual'));
    expect(
      sizeMentem.scope.appliesTo(
          technique: null, form: 'Mentem', baseEffectId: 'any', targetId: 'target-individual'),
      isFalse,
    );
    expect(
      sizeMentem.scope.appliesTo(
          technique: null, form: 'Mentem', baseEffectId: 'any', targetId: 'target-group'),
      isTrue,
    );
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

  test('the distance ladder is scoped to its transport effects', () async {
    final modifiers = await loader.loadModifiers();
    final distance = modifiers.firstWhere((m) => m.id == 'rego-transport-distance');

    expect(distance.scope.effectIds..sort(), ['rean-10b', 'reaq-4b', 'rehe-10b', 'reig-3c', 'rete-4']);
    expect(distance.scope.technique, isNull);
    expect(distance.scope.form, isNull);
  });

  test('every scoped effectId refers to a real base effect of the scoped Art', () async {
    final modifiers = await loader.loadModifiers();
    final byId = {for (final e in await loader.loadBaseEffects()) e.id: e};

    for (final modifier in modifiers) {
      for (final id in modifier.scope.effectIds) {
        final effect = byId[id];
        // `fail` returns Never, which promotes `effect` to non-null below.
        // `expect(effect, isNotNull)` would not, and every later line would
        // need a `!`.
        if (effect == null) {
          fail('${modifier.id} references unknown base effect $id');
        }
        // Existence alone would accept crhe-1b on a Creo Animal modifier.
        // A null side of a scope is a deliberate wildcard — the transport
        // ladder spans five Forms — so only a stated Technique or Form is
        // held to agree.
        if (modifier.scope.technique != null) {
          expect(effect.technique, modifier.scope.technique,
              reason: '${modifier.id} is scoped to ${modifier.scope.technique} '
                  'but $id is ${effect.technique}');
        }
        if (modifier.scope.form != null) {
          expect(effect.form, modifier.scope.form,
              reason: '${modifier.id} is scoped to ${modifier.scope.form} '
                  'but $id is ${effect.form}');
        }
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

  test('the fire-intensity modifiers mirror chill-damage\'s 4-rung progression', () async {
    final modifiers = await loader.loadModifiers();

    for (final id in ['muto-ignem-fire-intensity', 'rego-ignem-fire-intensity']) {
      final ladder = modifiers.firstWhere((m) => m.id == id);
      expect(ladder.options.map((o) => o.magnitude).toList(), [0, 1, 2, 3],
          reason: '$id should mirror chill-damage\'s +5/+10/+15/+20 rungs');
    }
  });

  test('the Rego Ignem fire-intensity modifier is scoped to controlling rows, not the ward table', () async {
    final modifiers = await loader.loadModifiers();
    final fireIntensity = modifiers.firstWhere((m) => m.id == 'rego-ignem-fire-intensity');

    expect(fireIntensity.scope.effectIds..sort(),
        ['reig-10', 'reig-3a', 'reig-3b', 'reig-4', 'reig-5b']);

    for (final wardRow in ['reig-15b', 'reig-20', 'reig-25', 'reig-30', 'reig-35', 'reig-40']) {
      expect(
        fireIntensity.scope.appliesTo(technique: 'Rego', form: 'Ignem', baseEffectId: wardRow),
        isFalse,
        reason: '$wardRow already bakes fire damage into its base level; offering '
            'the intensity modifier there would double-count',
      );
    }
  });

  test('the treated-product modifiers skip rows that already price treatment', () async {
    final modifiers = await loader.loadModifiers();
    final herbam = modifiers.firstWhere((m) => m.id == 'creo-herbam-treated-product');
    final animal = modifiers.firstWhere((m) => m.id == 'creo-animal-treated-product');

    expect(herbam.scope.effectIds..sort(), ['crhe-1b', 'crhe-1c', 'crhe-3a']);
    expect(animal.scope.effectIds..sort(), ['cran-10a', 'cran-5a']);

    expect(
      herbam.scope.appliesTo(technique: 'Creo', form: 'Herbam', baseEffectId: 'crhe-2a'),
      isFalse,
      reason: 'crhe-2a "Create a processed plant product" is crhe-1b with the '
          'treated rule already applied — levels 1-5 are the additive tier, so '
          'one magnitude is one level. Offering the modifier there double-counts',
    );
    for (final living in ['cran-5b', 'cran-10b', 'cran-15c', 'cran-50']) {
      expect(
        animal.scope.appliesTo(technique: 'Creo', form: 'Animal', baseEffectId: living),
        isFalse,
        reason: '$living creates a living animal, and the rule prices treatment '
            'against the level to create an equivalent amount of dead animal',
      );
    }
    expect(
      herbam.scope.appliesTo(technique: 'Creo', form: 'Herbam', baseEffectId: 'crhe-1b'),
      isTrue,
      reason: 'the rule has to still apply somewhere',
    );
  });

  test('every new additive modifier loads with its stated Technique and Form', () async {
    final modifiers = await loader.loadModifiers();
    final expectedScopes = {
      'muto-ignem-fire-intensity': ('Muto', 'Ignem'),
      'rego-ignem-fire-intensity': ('Rego', 'Ignem'),
      'creo-animal-treated-product': ('Creo', 'Animal'),
      'muto-herbam-treated-material': ('Muto', 'Herbam'),
      'perdo-herbam-live-wood': ('Perdo', 'Herbam'),
      'perdo-auram-precision': ('Perdo', 'Auram'),
      'rego-auram-precision': ('Rego', 'Auram'),
      'creo-aquam-unnatural': ('Creo', 'Aquam'),
      'creo-herbam-treated-product': ('Creo', 'Herbam'),
    };

    for (final entry in expectedScopes.entries) {
      final modifier = modifiers.firstWhere((m) => m.id == entry.key);
      expect(modifier.scope.technique, entry.value.$1, reason: '${entry.key} technique');
      expect(modifier.scope.form, entry.value.$2, reason: '${entry.key} form');
    }

    expect(modifiers.firstWhere((m) => m.id == 'creo-animal-treated-product').options.map((o) => o.magnitude).toList(), [1, 2]);
    expect(modifiers.firstWhere((m) => m.id == 'muto-herbam-treated-material').options.map((o) => o.magnitude).toList(), [1]);
    expect(modifiers.firstWhere((m) => m.id == 'perdo-herbam-live-wood').options.map((o) => o.magnitude).toList(), [1]);
    expect(modifiers.firstWhere((m) => m.id == 'perdo-auram-precision').options.map((o) => o.magnitude).toList(), [1]);
    expect(modifiers.firstWhere((m) => m.id == 'rego-auram-precision').options.map((o) => o.magnitude).toList(), [1]);
    expect(modifiers.firstWhere((m) => m.id == 'creo-aquam-unnatural').options.map((o) => o.magnitude).toList(), [0, 1, 2]);
    expect(modifiers.firstWhere((m) => m.id == 'creo-herbam-treated-product').options.map((o) => o.magnitude).toList(), [1, 2]);
  });
}
