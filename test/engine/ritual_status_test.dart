import 'package:flutter_test/flutter_test.dart';

import 'package:eruditus/engine/ritual_status.dart';
import 'package:eruditus/engine/spell_engine.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/ritual_declaration.dart';

Provenance _prov() => Provenance(source: PublicationSource.userCreated);

Parameter _param(String id, String name, String category, int magnitude,
        {bool requiresRitual = false}) =>
    Parameter(
      id: id, name: name, category: category, magnitude: magnitude,
      requiresRitual: requiresRitual, provenance: _prov(),
    );

BaseEffect _effect(int baseLevel,
        {String technique = 'Creo',
        String form = 'Terram',
        RitualRequirement ritualRequirement = RitualRequirement.none}) =>
    BaseEffect(
      id: 'e-$baseLevel', technique: technique, form: form,
      description: 'test effect', baseLevel: baseLevel,
      ritualRequirement: ritualRequirement, provenance: _prov(),
    );

final _personal = _param('range-personal', 'Personal', 'Range', 0);
final _touch = _param('range-touch', 'Touch', 'Range', 1);
final _momentary = _param('duration-momentary', 'Momentary', 'Duration', 0);
final _year = _param('duration-year', 'Year', 'Duration', 4, requiresRitual: true);
final _individual = _param('target-individual', 'Individual', 'Target', 0);
final _boundary = _param('target-boundary', 'Boundary', 'Target', 4, requiresRitual: true);
final _symbolRange = _param('range-symbol', 'Symbol', 'Range', 4, requiresRitual: true);

void main() {
  final engine = SpellEngine(allSpells: []);

  LevelBreakdownResult run({
    BaseEffect? effect,
    Parameter? range,
    Parameter? duration,
    Parameter? target,
    RitualDeclaration declaration = RitualDeclaration.none,
  }) {
    final breakdown = engine.calculateBreakdown(
      baseEffect: effect ?? _effect(10),
      range: range ?? _personal,
      duration: duration ?? _momentary,
      target: target ?? _individual,
      selectedModifiers: const {},
      requisites: const {},
      ritualDeclaration: declaration,
    );
    return (
      level: breakdown.level,
      rawLevel: breakdown.rawLevel,
      reasons: breakdown.ritualStatus.reasons,
      isRitual: breakdown.ritualStatus.isRitual,
    );
  }

  group('forced ritual reasons', () {
    test('a ritual-only Duration forces a Ritual', () {
      final result = run(duration: _year);
      expect(result.isRitual, isTrue);
      expect(result.reasons, [RitualReason.ritualOnlyDuration]);
    });

    test('a ritual-only Target forces a Ritual', () {
      final result = run(target: _boundary);
      expect(result.isRitual, isTrue);
      expect(result.reasons, [RitualReason.ritualOnlyTarget]);
    });

    test('a ritual-only Range forces a Ritual', () {
      final result = run(range: _symbolRange);
      expect(result.isRitual, isTrue);
      expect(result.reasons, [RitualReason.ritualOnlyRange]);
    });

    test('a required guideline forces a Ritual', () {
      final result = run(
          effect: _effect(25, ritualRequirement: RitualRequirement.required));
      expect(result.reasons, [RitualReason.guideline]);
    });

    test('a suggested guideline forces nothing', () {
      final result = run(
          effect: _effect(25, ritualRequirement: RitualRequirement.suggested));
      expect(result.isRitual, isFalse);
      expect(result.reasons, isEmpty);
    });
  });

  group('the level threshold', () {
    test('exactly level 50 is a legal Formulaic spell', () {
      // Core Rules line 12346: "they may have a level of 50, but not 51 or
      // higher."
      final result = run(effect: _effect(50));
      expect(result.level, 50);
      expect(result.isRitual, isFalse);
    });

    test('level 51 forces a Ritual', () {
      final result = run(effect: _effect(51));
      expect(result.reasons, [RitualReason.exceedsMaxFormulaicLevel]);
    });
  });

  group('declarations', () {
    test('lastingCreation makes a spell a Ritual', () {
      final result = run(declaration: RitualDeclaration.lastingCreation);
      expect(result.reasons, [RitualReason.lastingCreation]);
    });

    test('storyguideRuling is honoured on a non-Creo, non-Momentary spell', () {
      // Incantation of Summoning the Dead is Rego Mentem, Duration
      // Concentration, and a Ritual by storyguide judgement alone.
      final result = run(
        effect: _effect(15, technique: 'Rego', form: 'Mentem'),
        duration: _param('duration-concentration', 'Concentration', 'Duration', 1),
        declaration: RitualDeclaration.storyguideRuling,
      );
      expect(result.reasons, [RitualReason.storyguideRuling]);
    });
  });

  group('reasons accumulate', () {
    test('Aegis of the Hearth reports both its forced reasons', () {
      // R: Touch, D: Year, T: Boundary, Ritual (Core Rules line 15934).
      //
      // Uses a low-level base effect rather than the shared run() default
      // (base 10): base 10 has zero additive capacity (it is already >= 5),
      // so Touch(1) + Year(4) + Boundary(4) would multiply out to a raw
      // level of 55 — over the Formulaic cap — and add an unrelated third
      // reason (exceedsMaxFormulaicLevel) that this test isn't about.
      final result = run(
        effect: _effect(1),
        range: _touch,
        duration: _year,
        target: _boundary,
      );
      expect(result.reasons, containsAll([
        RitualReason.ritualOnlyDuration,
        RitualReason.ritualOnlyTarget,
      ]));
      expect(result.reasons.length, 2);
    });

    test('a ritual-only Range accumulates alongside Duration and Target', () {
      final result = run(
        effect: _effect(1),
        range: _symbolRange,
        duration: _year,
        target: _boundary,
      );
      expect(result.reasons, containsAll([
        RitualReason.ritualOnlyRange,
        RitualReason.ritualOnlyDuration,
        RitualReason.ritualOnlyTarget,
      ]));
      expect(result.reasons.length, 3);
    });
  });

  group('the minimum level 20 floor', () {
    test('raises a low-level Ritual to 20', () {
      // crhe-1e "Heal a Light Wound to a plant" at Touch: raw level 2.
      final result = run(
        effect: _effect(1, form: 'Herbam'),
        range: _touch,
        declaration: RitualDeclaration.lastingCreation,
      );
      expect(result.rawLevel, 2);
      expect(result.level, 20);
    });

    test('is a no-op at exactly 20', () {
      // Touch of Midas: base 15 + Touch = 20.
      final result = run(
        effect: _effect(15),
        range: _touch,
        declaration: RitualDeclaration.lastingCreation,
      );
      expect(result.rawLevel, 20);
      expect(result.level, 20);
    });

    test('never lowers a Ritual above 20', () {
      // Incantation of the Body Made Whole: base 35 + Touch = 40.
      final result = run(
        effect: _effect(35, form: 'Corpus'),
        range: _touch,
        declaration: RitualDeclaration.lastingCreation,
      );
      expect(result.level, 40);
    });

    test('does not apply to a non-Ritual spell', () {
      final result = run(effect: _effect(1));
      expect(result.level, 1);
      expect(result.rawLevel, 1);
    });

    test('can never produce a level above the Formulaic cap', () {
      // Guards the single-pass ordering: the floor decides nothing that could
      // re-trigger the >50 check, so calculateBreakdown needs no fixed point.
      expect(
        RitualStatus.minimumRitualLevel <= RitualStatus.maxFormulaicLevel,
        isTrue,
        reason: 'if the floor could exceed the cap, ritual status would have '
            'to be recomputed after applying it',
      );
    });
  });
}

typedef LevelBreakdownResult = ({
  int level,
  int rawLevel,
  List<RitualReason> reasons,
  bool isRitual,
});
