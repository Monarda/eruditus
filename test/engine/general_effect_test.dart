import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/general_effect_formula.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/parameter_triple.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  group('deriveGeneralEffect', () {
    Parameter param(String id, String name, String category, int magnitude) => Parameter(
        id: id, name: name, category: category, magnitude: magnitude,
        provenance: Provenance(source: PublicationSource.published,
            citations: const [Citation(bookId: 'arm5-core')]));

    final touch = param('range-touch', 'Touch', 'Range', 1);
    final ring = param('duration-ring', 'Ring', 'Duration', 2);
    final circle = param('target-circle', 'Circle', 'Target', 0);
    final personal = param('range-personal', 'Personal', 'Range', 0);
    final sun = param('duration-sun', 'Sun', 'Duration', 2);
    final individual = param('target-individual', 'Individual', 'Target', 0);

    final engine = SpellEngine(
      allSpells: const [],
      allParameters: [touch, ring, circle, personal, sun, individual],
    );

    final creoIgnem10 = BaseEffect(
      id: 'crig-10', technique: 'Creo', form: 'Ignem',
      description: 'Create flame', baseLevel: 10,
      provenance: Provenance(source: PublicationSource.userCreated),
    );

    BaseEffect wardGuideline() => BaseEffect(
        id: 'rean-gen', technique: 'Rego', form: 'Animal',
        description: 'Ward against beings associated with Animal',
        baseLevel: null,
        reference: const ParameterTriple(
            rangeId: 'range-touch',
            durationId: 'duration-ring',
            targetId: 'target-circle'),
        provenance: Provenance(source: PublicationSource.published,
            citations: [Citation(bookId: 'arm5-core')]),
        effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold));

    BaseEffect generalEffect(GeneralEffectFormula formula) => BaseEffect(
        id: 'general-${formula.kind.name}', technique: 'Perdo', form: 'Vim',
        description: 'General guideline for test',
        baseLevel: null,
        provenance: Provenance(source: PublicationSource.published,
            citations: [Citation(bookId: 'arm5-core')]),
        effectFormula: formula);

    GeneralEffectValue? derive(GeneralEffectFormula formula, {required int chosen}) =>
        engine.deriveGeneralEffect(
            baseEffect: generalEffect(formula), chosenBaseLevel: chosen);

    // pevi-G4-ish: a ward's threshold is simply the chosen base level.
    const mightThreshold = GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold);

    // pevi-G3: "Reduce a target's Might Score by the level of the spell
    // + 2 magnitudes".
    const mightReductionPlus2 = GeneralEffectFormula(
        kind: GeneralEffectKind.mightReduction, offsetMagnitudes: 2);

    // pevi-G1: "twice the (level + 2 magnitudes)".
    const twiceLevelPlus2 = GeneralEffectFormula(
        kind: GeneralEffectKind.damage,
        multiplier: GeneralEffectMultiplier.two,
        offsetMagnitudes: 2);

    // pevi-G5: "half the (level + 4 magnitudes) + a stress die (no botch)".
    const halfLevelPlus4 = GeneralEffectFormula(
        kind: GeneralEffectKind.damage,
        multiplier: GeneralEffectMultiplier.half,
        offsetMagnitudes: 4,
        stressDie: true);

    // invi-G: "negative magnitude up to the magnitude of the guideline - 2".
    const traceMagnitudeMinus2 = GeneralEffectFormula(
        kind: GeneralEffectKind.spellTraceMagnitude,
        offsetMagnitudes: -2,
        unit: GeneralEffectUnit.magnitudes);

    test('a ward threshold is the chosen base', () {
      expect(derive(mightThreshold, chosen: 20)!.value, 20);
    });

    test('Might reduction adds the guideline offset in levels', () {
      // pevi-G3: "Reduce a target's Might Score by the level of the spell
      // + 2 magnitudes" — base + 10.
      expect(derive(mightReductionPlus2, chosen: 15)!.value, 25);
    });

    test('a doubling multiplier applies after the offset', () {
      // pevi-G1: "twice the (level + 2 magnitudes)".
      expect(derive(twiceLevelPlus2, chosen: 10)!.value, 40);
    });

    test('a halving multiplier rounds the same way as the rulebook', () {
      // pevi-G5: "half the (level + 4 magnitudes)".
      expect(derive(halfLevelPlus4, chosen: 15)!.value, 17);
    });

    test('a magnitudes unit converts by dividing by 5 and rounding up', () {
      // invi-G: "negative magnitude up to the magnitude of the guideline - 2".
      final result = derive(traceMagnitudeMinus2, chosen: 20);

      expect(result!.unit, GeneralEffectUnit.magnitudes);
      expect(result.value, 2); // (20 - 10) / 5
    });

    test('an offset inside the additive tier is worth 1 level, not 5', () {
      // The discriminating case. Every other test here uses a chosen level of
      // 10 or more, where a magnitude is worth 5 and `+ offset * 5` happens to
      // agree with the calculator. At chosen 3 they diverge: the additive tier
      // makes "+2 magnitudes" worth 2, so a base-3 DEO drains 5 Might — exactly
      // the level of the spell it produces. Hardcoding `* 5` would claim 13.
      expect(derive(mightReductionPlus2, chosen: 3)!.value, 5);
    });

    test('the value does not change when Range, Duration or Target change', () {
      // This is the whole point of anchoring to the chosen base: a
      // Personal-range ward is five levels cheaper but keeps out the same Might.
      // Assert it against real breakdowns at two parameter sets, not against
      // deriveGeneralEffect twice — that method takes no R/D/T, so calling it
      // twice with the same arguments proves nothing.
      final ward = wardGuideline(); // reference Touch/Ring/Circle

      final printed = engine.calculateBreakdown(
          baseEffect: ward, chosenBaseLevel: 20,
          range: touch, duration: ring, target: circle,
          selectedModifiers: const {}, requisites: const []);
      final cheaper = engine.calculateBreakdown(
          baseEffect: ward, chosenBaseLevel: 20,
          range: personal, duration: sun, target: individual,
          selectedModifiers: const {}, requisites: const []);

      expect(cheaper.level, lessThan(printed.level),
          reason: 'the cheaper parameter set must actually be cheaper, or this '
              'test proves nothing');
      expect(
          engine.deriveGeneralEffect(baseEffect: ward, chosenBaseLevel: 20)!.value,
          20,
          reason: 'the Might threshold follows the chosen base, not the level');
    });

    test('returns null when the offset drives the value below 1', () {
      // A level-1 guideline carrying a -2 offset has no meaningful strength.
      // Degrade to null rather than throwing: this is called to render a
      // sentence, and the Library tab must not crash on one bad saved spell.
      // Task 8 is what stops such a spell being saved in the first place.
      expect(derive(traceMagnitudeMinus2, chosen: 1), isNull);
    });

    test('a stress-die formula says so in its sentence', () {
      expect(derive(halfLevelPlus4, chosen: 15)!.sentence,
          contains('+ a stress die (no botch)'));
    });

    test('returns null for a non-General base effect', () {
      expect(
          engine.deriveGeneralEffect(baseEffect: creoIgnem10, chosenBaseLevel: null),
          isNull);
    });

    test('returns null when no level has been chosen yet', () {
      expect(
          engine.deriveGeneralEffect(baseEffect: wardGuideline(), chosenBaseLevel: null),
          isNull);
    });
  });
}
