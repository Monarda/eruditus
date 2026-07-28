import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

Modifier _mod({
  ModifierSelectionMode mode = ModifierSelectionMode.single,
  ModifierScope scope = const ModifierScope(),
}) =>
    Modifier(
      id: 'terram-material',
      name: 'Material difficulty',
      description: 'Harder materials cost magnitudes',
      selectionMode: mode,
      scope: scope,
      options: [
        ModifierOption(id: 'mat-dirt', label: 'Dirt', magnitude: 0),
        ModifierOption(id: 'mat-stone', label: 'Stone or glass', magnitude: 1),
        ModifierOption(id: 'mat-metal', label: 'Metal or gemstone', magnitude: 2),
      ],
      provenance: Provenance(
        source: PublicationSource.published,
        citations: const [Citation(bookId: 'arm5-core')],
      ),
    );

void main() {
  group('ModifierOption', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final option = ModifierOption(
          id: 'mat-stone', label: 'Stone or glass', description: 'Harder than dirt', magnitude: 1);

      final restored = ModifierOption.fromMap(option.toMap());

      expect(restored.id, 'mat-stone');
      expect(restored.label, 'Stone or glass');
      expect(restored.description, 'Harder than dirt');
      expect(restored.magnitude, 1);
    });

    test('fromMap throws a clear FormatException when magnitude is missing', () {
      expect(
        () => ModifierOption.fromMap({'id': 'x', 'label': 'X'}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            allOf(contains('magnitude'), contains('ModifierOption')))),
      );
    });
  });

  group('ModifierScope.appliesTo', () {
    test('an empty scope applies to anything', () {
      const scope = ModifierScope();
      expect(scope.appliesTo(technique: 'Creo', form: 'Ignem', baseEffectId: 'e1'), isTrue);
    });

    test('form-only scope matches any technique with that form', () {
      const scope = ModifierScope(form: 'Terram');
      expect(scope.appliesTo(technique: 'Muto', form: 'Terram', baseEffectId: 'mute-1'), isTrue);
      expect(scope.appliesTo(technique: 'Creo', form: 'Terram', baseEffectId: 'crte-1'), isTrue);
      expect(scope.appliesTo(technique: 'Muto', form: 'Ignem', baseEffectId: 'x'), isFalse);
    });

    test('technique-only scope matches any form with that technique', () {
      const scope = ModifierScope(technique: 'Rego');
      expect(scope.appliesTo(technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4'), isTrue);
      expect(scope.appliesTo(technique: 'Creo', form: 'Terram', baseEffectId: 'crte-1'), isFalse);
    });

    test('technique and form together require both to match', () {
      const scope = ModifierScope(technique: 'Creo', form: 'Auram');
      expect(scope.appliesTo(technique: 'Creo', form: 'Auram', baseEffectId: 'crau-3a'), isTrue);
      expect(scope.appliesTo(technique: 'Creo', form: 'Ignem', baseEffectId: 'x'), isFalse);
      expect(scope.appliesTo(technique: 'Perdo', form: 'Auram', baseEffectId: 'x'), isFalse);
    });

    test('effectIds narrows to listed effects only', () {
      const scope = ModifierScope(effectIds: ['rehe-10b', 'reig-3c', 'rete-4']);
      expect(scope.appliesTo(technique: 'Rego', form: 'Terram', baseEffectId: 'rete-4'), isTrue);
      expect(scope.appliesTo(technique: 'Rego', form: 'Terram', baseEffectId: 'rete-1'), isFalse);
    });

    test('effectIds does not match when no base effect is selected yet', () {
      const scope = ModifierScope(effectIds: ['rete-4']);
      expect(scope.appliesTo(technique: 'Rego', form: 'Terram', baseEffectId: null), isFalse);
    });

    test('excludeTechniques rejects a listed technique even when form matches', () {
      // "Intellego spells are not affected by Target size" — core rules.
      const scope = ModifierScope(form: 'Corpus', excludeTechniques: ['Intellego']);

      expect(scope.appliesTo(technique: 'Creo', form: 'Corpus', baseEffectId: 'e1'), isTrue);
      expect(scope.appliesTo(technique: 'Intellego', form: 'Corpus', baseEffectId: 'e1'), isFalse);
    });
  });

  group('Modifier', () {
    test('optionById returns the option, or null when absent', () {
      final modifier = _mod();
      expect(modifier.optionById('mat-stone')?.magnitude, 1);
      expect(modifier.optionById('no-such-option'), isNull);
    });

    test('toMap/fromMap round-trip preserves both selection modes', () {
      for (final mode in ModifierSelectionMode.values) {
        final restored = Modifier.fromMap(_mod(mode: mode).toMap());
        expect(restored.selectionMode, mode, reason: 'mode $mode did not survive the round-trip');
        expect(restored.options.length, 3);
        expect(restored.options[2].magnitude, 2);
      }
    });

    test('toMap/fromMap round-trip preserves scope', () {
      const scope = ModifierScope(
          technique: 'Rego',
          form: 'Terram',
          effectIds: ['rete-4'],
          excludeTechniques: ['Intellego']);
      final restored = Modifier.fromMap(_mod(scope: scope).toMap());

      expect(restored.scope.technique, 'Rego');
      expect(restored.scope.form, 'Terram');
      expect(restored.scope.effectIds, ['rete-4']);
      expect(restored.scope.excludeTechniques, ['Intellego']);
    });

    test('toMap/fromMap round-trip preserves an option baseIndividual', () {
      final modifier = Modifier(
        id: 'terram-material',
        name: 'Material difficulty',
        selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(technique: 'Rego', form: 'Terram'),
        options: [
          ModifierOption(
              id: 'mat-gemstone', label: 'Gemstone', magnitude: 2, baseIndividual: 'one cubic inch'),
        ],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );

      final restored = Modifier.fromMap(modifier.toMap());

      expect(restored.optionById('mat-gemstone')?.baseIndividual, 'one cubic inch');
    });

    test('baseIndividual is null when an option does not define one', () {
      expect(_mod().optionById('mat-dirt')?.baseIndividual, isNull);
    });

    test('fromMap throws a FormatException naming the valid modes when selectionMode is unknown', () {
      final map = _mod().toMap();
      map['selectionMode'] = 'exclusive';

      expect(
        () => Modifier.fromMap(map),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            allOf(contains('exclusive'), contains('single'), contains('multi')))),
      );
    });

    test('a published modifier needs at least one citation', () {
      expect(
        () => Modifier(
          id: 'x', name: 'X', selectionMode: ModifierSelectionMode.single,
          scope: const ModifierScope(), options: const [],
          provenance: Provenance(source: PublicationSource.published),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trips a published modifier with a citation', () {
      final modifier = Modifier(
        id: 'x', name: 'X', selectionMode: ModifierSelectionMode.single,
        scope: const ModifierScope(), options: const [],
        provenance: Provenance(
          source: PublicationSource.published,
          citations: const [Citation(bookId: 'arm5-core')],
        ),
      );
      final restored = Modifier.fromMap(modifier.toMap());
      expect(restored.provenance.source, PublicationSource.published);
      expect(restored.provenance.citations, [const Citation(bookId: 'arm5-core')]);
    });
  });
}
