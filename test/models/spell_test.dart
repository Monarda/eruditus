import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/container_mode.dart';
import 'package:eruditus/models/level_adjustment.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/requisite.dart';
import 'package:eruditus/models/ritual_declaration.dart';
import 'package:eruditus/models/target_type.dart';

void main() {
  group('Spell Model', () {
    test('Spell.toMap and fromMap round-trip preserves every field', () {
      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        baseEffectId: '1',
        technique: 'Perdo',
        form: 'Corpus',
        rangeId: 'param-voice',
        durationId: 'param-sun',
        targetId: 'param-individual',
        requisites: {
          'Vim': RequisiteKind.free,
          'Mentem': RequisiteKind.free,
          'Auram': RequisiteKind.adding,
          'Terram': RequisiteKind.adding,
        },
        description: 'A test spell',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 7, 24, 12, 30),
        updatedAt: DateTime(2026, 7, 25, 8, 15),
      );

      final map = spell.toMap();
      final restored = Spell.fromMap(map);

      expect(restored.id, spell.id);
      expect(restored.name, spell.name);
      expect(restored.baseEffectId, spell.baseEffectId);
      expect(restored.technique, 'Perdo');
      expect(restored.form, 'Corpus');
      expect(restored.analogyRationale, isNull);
      expect(restored.rangeId, spell.rangeId);
      expect(restored.durationId, spell.durationId);
      expect(restored.targetId, spell.targetId);
      expect(restored.description, spell.description);
      expect(restored.provenance.source, spell.provenance.source);
      expect(restored.createdAt, spell.createdAt);
      expect(restored.updatedAt, spell.updatedAt);

      expect(restored.requisites.length, 4);
      expect(restored.requisites['Vim'], RequisiteKind.free);
      expect(RequisiteKind.free.magnitude, 0);
      expect(restored.requisites['Mentem'], RequisiteKind.free);
      expect(restored.requisites['Auram'], RequisiteKind.adding);
      expect(RequisiteKind.adding.magnitude, 1);
      expect(restored.requisites['Terram'], RequisiteKind.adding);
    });

    test('fromMap throws a clear FormatException when a requisite kind is unknown', () {
      final map = Spell(
        id: 'spell-bad-kind', baseEffectId: '1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'param-voice',
        durationId: 'param-sun', targetId: 'param-individual',
        requisites: const {},
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
      ).toMap();
      map['requisites'] = {'Vim': 'mandatory'};

      expect(
        () => Spell.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('mandatory'), contains('free'), contains('adding')),
          ),
        ),
      );
    });

    test('fromMap throws a clear FormatException when a requisite kind is not a string', () {
      final map = Spell(
        id: 'spell-null-kind', baseEffectId: '1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'param-voice',
        durationId: 'param-sun', targetId: 'param-individual',
        requisites: const {},
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
      ).toMap();
      map['requisites'] = {'Vim': null};

      expect(
        () => Spell.fromMap(map),
        throwsA(isA<FormatException>().having(
          (e) => e.message, 'message', allOf(contains('Vim'), contains('no kind')),
        )),
      );
    });

    test('fromMap throws a clear FormatException when a required field is missing', () {
      final map = {
        'id': 'spell-1',
        // 'rangeId' missing
        'baseEffectId': '1',
        'technique': 'Creo',
        'form': 'Ignem',
        'durationId': 'p1',
        'targetId': 'p2',
        'source': 'user-created',
        'createdAt': DateTime(2026, 7, 24).toIso8601String(),
        'updatedAt': DateTime(2026, 7, 24).toIso8601String(),
      };

      expect(
        () => Spell.fromMap(map),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('rangeId'), contains('Spell')),
          ),
        ),
      );
    });

    test('SpellDraft.toSpell creates Spell with current timestamp', () {
      final effect = BaseEffect(
        id: '1',
        technique: 'Muto',
        form: 'Corpus',
        description: 'Transform body',
        baseLevel: 5,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final range = Parameter(
          id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0,
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
      final duration = Parameter(
          id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0,
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
      final target = Parameter(
          id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 10,
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

      final draft = SpellDraft(
        technique: 'Muto',
        form: 'Corpus',
        baseEffect: effect,
        range: range,
        duration: duration,
        target: target,
        summary: 'Transforms the target body.',
      );

      final spell = draft.toSpell(name: 'My Spell', source: PublicationSource.userCreated);

      expect(spell.name, 'My Spell');
      expect(spell.provenance.source, PublicationSource.userCreated);
      expect(spell.baseEffectId, effect.id);
      expect(spell.rangeId, range.id);
      expect(spell.durationId, duration.id);
      expect(spell.targetId, target.id);
    });

    test('SpellDraft.toSpell throws StateError when range is not set', () {
      final draft = SpellDraft(
        technique: 'Muto',
        form: 'Corpus',
        baseEffect: BaseEffect(
          id: '1',
          technique: 'Muto',
          form: 'Corpus',
          description: 'Transform body',
          baseLevel: 5,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        duration: Parameter(
            id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0,
            provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')])),
        target: Parameter(
            id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 10,
            provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')])),
      );

      expect(
        () => draft.toSpell(name: 'My Spell', source: PublicationSource.userCreated),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('range')),
        ),
      );
    });

    test('SpellDraft.toSpell throws StateError when baseEffect is not set', () {
      final draft = SpellDraft(
        technique: 'Muto',
        form: 'Corpus',
      );

      expect(
        () => draft.toSpell(name: 'My Spell', source: PublicationSource.userCreated),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('baseEffect')),
        ),
      );
    });

    test('SpellDraft.toSpell throws StateError naming all missing fields', () {
      final draft = SpellDraft();

      expect(
        () => draft.toSpell(name: 'My Spell', source: PublicationSource.userCreated),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('baseEffect'), contains('range'), contains('duration'), contains('target')),
          ),
        ),
      );
    });

    test('selectedModifiers survives a toMap/fromMap round-trip', () {
      final spell = Spell(
        id: 'spell-1',
        name: 'Test Spell',
        baseEffectId: 'rete-4',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'p1',
        durationId: 'p2',
        targetId: 'p3',
        selectedModifiers: const {
          'terram-material': ['mat-metal'],
          'rego-transport-distance': ['dist-500-paces'],
        },
        requisites: const {},
        summary: 'Shapes and hurls a metal object.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = Spell.fromMap(spell.toMap());

      expect(restored.selectedModifiers['terram-material'], ['mat-metal']);
      expect(restored.selectedModifiers['rego-transport-distance'], ['dist-500-paces']);
    });

    test('fromMap defaults selectedModifiers to an empty map when absent', () {
      final map = Spell(
        id: 'spell-2',
        baseEffectId: 'e1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'p1',
        durationId: 'p2',
        targetId: 'p3',
        requisites: const {},
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ).toMap();
      map.remove('selectedModifiers');

      expect(Spell.fromMap(map).selectedModifiers, isEmpty);
    });

    test('tags default to empty and round-trip through toMap/fromMap', () {
      final spell = Spell(
        id: 'x',
        baseEffectId: 'e1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'p1',
        durationId: 'p2',
        targetId: 'p3',
        requisites: const {},
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(spell.tags, isEmpty);

      final tagged = Spell(
        id: 'y',
        baseEffectId: 'e1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'p1',
        durationId: 'p2',
        targetId: 'p3',
        requisites: const {},
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        tags: const ['architecture', 'defensive'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final restored = Spell.fromMap(tagged.toMap());
      expect(restored.tags, ['architecture', 'defensive']);
    });

    test('SpellDraft.copyWith replaces selectedModifiers wholesale', () {
      final draft = SpellDraft(
        technique: 'Rego',
        form: 'Terram',
        selectedModifiers: const {'terram-material': ['mat-stone']},
      );

      final updated = draft.copyWith(selectedModifiers: const {'terram-material': ['mat-metal']});

      expect(updated.selectedModifiers['terram-material'], ['mat-metal']);
      expect(draft.selectedModifiers['terram-material'], ['mat-stone'], reason: 'original unchanged');
    });

    test('ritualDeclaration defaults to none and round-trips every value', () {
      for (final value in RitualDeclaration.values) {
        final spell = Spell(
          id: 's-1', name: 'Touch of Midas',
          baseEffectId: 'crte-15a',
          technique: 'Creo',
          form: 'Ignem',
          rangeId: 'range-touch',
          durationId: 'duration-momentary',
          targetId: 'target-individual',
          requisites: const {},
          ritualDeclaration: value,
          summary: 'Transmutes base metal into gold.',
          provenance: Provenance(source: PublicationSource.userCreated),
          createdAt: DateTime(2026), updatedAt: DateTime(2026),
        );
        expect(Spell.fromMap(spell.toMap()).ritualDeclaration, value);
      }
    });

    test('fromMap treats an absent ritualDeclaration key as none', () {
      final restored = Spell.fromMap({
        'id': 's-2',
        'baseEffectId': 'crte-15a',
        'technique': 'Creo',
        'form': 'Ignem',
        'rangeId': 'range-touch',
        'durationId': 'duration-momentary',
        'targetId': 'target-individual',
        'requisites': <String, dynamic>{},
        'source': 'user-created',
        'createdAt': DateTime(2026).toIso8601String(),
        'updatedAt': DateTime(2026).toIso8601String(),
      });
      expect(restored.ritualDeclaration, RitualDeclaration.none);
    });

    test('fromMap throws a clear FormatException on an unknown ritualDeclaration', () {
      expect(
        () => Spell.fromMap({
          'id': 's-3',
          'baseEffectId': 'crte-15a',
          'technique': 'Creo',
          'form': 'Ignem',
          'rangeId': 'range-touch',
          'durationId': 'duration-momentary',
          'targetId': 'target-individual',
          'requisites': <String, dynamic>{},
          'ritualDeclaration': 'because-i-said-so',
          'source': 'user-created',
          'createdAt': DateTime(2026).toIso8601String(),
          'updatedAt': DateTime(2026).toIso8601String(),
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('because-i-said-so'), contains('storyguideRuling')),
          ),
        ),
      );
    });

    test('toSpell carries the draft ritualDeclaration through', () {
      final draft = SpellDraft(
        technique: 'Creo', form: 'Terram',
        baseEffect: BaseEffect(
          id: 'crte-15a', technique: 'Creo', form: 'Terram',
          description: 'Create precious metal', baseLevel: 15,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        range: Parameter(
          id: 'range-touch', name: 'Touch', category: 'Range', magnitude: 1,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        duration: Parameter(
          id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        target: Parameter(
          id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0,
          provenance: Provenance(source: PublicationSource.userCreated),
        ),
        ritualDeclaration: RitualDeclaration.lastingCreation,
        summary: 'Transmutes base metal into gold.',
      );

      final spell = draft.toSpell(
          name: 'Touch of Midas', source: PublicationSource.userCreated);

      expect(spell.ritualDeclaration, RitualDeclaration.lastingCreation);
    });

    test('Spell round-trips its adjustments', () {
      final spell = Spell(
        id: 'spell-adj',
        name: 'Test Spell',
        baseEffectId: '1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'param-voice',
        durationId: 'param-sun',
        targetId: 'param-individual',
        requisites: const {},
        adjustments: [
          LevelAdjustment(magnitude: -1, note: 'because the old limb is needed'),
          LevelAdjustment(magnitude: 0, note: 'purely cosmetic and thus free'),
        ],
        description: 'A test spell',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(Spell.fromMap(spell.toMap()).adjustments, spell.adjustments);
    });

    test('a Spell whose map has no adjustments key parses as an empty list', () {
      final spell = Spell(
        id: 'spell-none',
        name: 'Test Spell',
        baseEffectId: '1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'param-voice',
        durationId: 'param-sun',
        targetId: 'param-individual',
        requisites: const {},
        description: 'A test spell',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final map = spell.toMap()..remove('adjustments');

      expect(Spell.fromMap(map).adjustments, isEmpty);
    });

    test('chosenBaseLevel and templateId round-trip', () {
      final spell = Spell(
        id: 's-1', name: 'Circular Ward against Demons 20',
        baseEffectId: 'revi-G1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'range-touch',
        durationId: 'duration-ring', targetId: 'target-circle',
        chosenBaseLevel: 20, templateId: 'tpl-revi-circular-ward-against-demons',
        requisites: const {},
        summary: 'Wards a circle against demons.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
      );

      final restored = Spell.fromMap(spell.toMap());

      expect(restored.chosenBaseLevel, 20);
      expect(restored.templateId, 'tpl-revi-circular-ward-against-demons');
    });

    test('both fields default to null', () {
      final spell = Spell(
        id: 's-2', baseEffectId: 'crig-10',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'range-voice',
        durationId: 'duration-momentary', targetId: 'target-individual',
        requisites: const {},
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
      );

      expect(spell.chosenBaseLevel, isNull);
      expect(spell.templateId, isNull);
    });

    test('chosenSlots defaults to empty and round-trips', () {
      final spell = Spell(
        id: 's-1', baseEffectId: 'e1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'p1', durationId: 'p2', targetId: 'p3',
        requisites: const {},
        summary: 'Conjures a bolt of flame.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      expect(spell.chosenSlots, isEmpty);

      final withSlot = Spell(
        id: 's-2', baseEffectId: 'e1',
        technique: 'Creo',
        form: 'Ignem',
        rangeId: 'p1', durationId: 'p2', targetId: 'p3',
        requisites: const {},
        chosenSlots: const {'realm': 'Infernal'},
        summary: 'Wards a circle against the Infernal realm.',
        provenance: Provenance(source: PublicationSource.userCreated),
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      expect(Spell.fromMap(withSlot.toMap()).chosenSlots, {'realm': 'Infernal'});
    });

    group('fromMap prose backfill', () {
      Map<String, dynamic> userCreatedMap({String? summary, String? description}) => {
            'id': 'u1',
            'name': 'My Spell',
            'baseEffectId': 'e1',
            'technique': 'Creo',
            'form': 'Ignem',
            'rangeId': 'range-voice',
            'durationId': 'duration-momentary',
            'targetId': 'target-individual',
            'requisites': <String, dynamic>{},
            'summary': summary,
            'description': description,
            'source': 'user-created',
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
            'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
          };

      test('a user-created record with no prose is backfilled, not rejected', () {
        final spell = Spell.fromMap(userCreatedMap());
        expect(spell.summary, legacySummaryPlaceholder);
      });

      test('an existing summary is left alone', () {
        final spell = Spell.fromMap(userCreatedMap(summary: 'Mine.'));
        expect(spell.summary, 'Mine.');
      });

      test('a description alone is enough, and no summary is invented', () {
        final spell = Spell.fromMap(userCreatedMap(description: 'Long form.'));
        expect(spell.summary, isNull);
      });

      test('an empty-string summary counts as absent', () {
        final spell = Spell.fromMap(userCreatedMap(summary: '   '));
        expect(spell.summary, legacySummaryPlaceholder);
      });

      test('a published record with no prose still throws', () {
        // The backfill must never reach published data: assertion 7 in
        // published_spell_import_test.dart is what stops a prose-less spell
        // shipping, and silently repairing one here would take its teeth out.
        final map = userCreatedMap()
          ..['source'] = 'published'
          ..['citations'] = [
            {'bookId': 'arm5-core'}
          ];
        expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
      });
    });
  });

  group('spell field invariants', () {
    // The citation invariant (published needs >=1 citation, user-created
    // needs 0) and the "unknown source value throws" invariant now live on
    // Provenance/PublicationSource themselves — see
    // test/models/provenance_test.dart and test/models/publication_source_test.dart.
    // This group covers only the summary-or-description rule that Spell
    // itself still owns via validateSpellProse.
    Map<String, dynamic> baseMap() => {
          'id': 'x',
          'name': 'X',
          'baseEffectId': 'e1',
          'technique': 'Creo',
          'form': 'Ignem',
          'rangeId': 'p1',
          'durationId': 'p2',
          'targetId': 'p3',
          'requisites': <String, dynamic>{},
          'source': 'published',
          'summary': 'A summary.',
          'citations': [
            {'bookId': 'arm5-core'}
          ],
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-01T00:00:00.000',
        };

    test('a published spell with only a summary is valid', () {
      expect(Spell.fromMap(baseMap()).summary, 'A summary.');
    });

    test('a published spell with only a description is valid', () {
      final map = baseMap()
        ..remove('summary')
        ..['description'] = 'Verbatim rulebook text.';
      expect(Spell.fromMap(map).description, 'Verbatim rulebook text.');
    });

    test('a published spell with neither summary nor description is rejected', () {
      final map = baseMap()..remove('summary');
      expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
    });

    test('a user-created record with neither summary nor description is backfilled, not rejected', () {
      // fromMap's backfill (todo item 13) stands in for a pre-rule record; the
      // rule itself no longer carves out an exception for user-created spells
      // -- see the two tests below.
      final map = baseMap()
        ..remove('summary')
        ..['source'] = 'user-created'
        ..['citations'] = <dynamic>[];
      expect(Spell.fromMap(map).provenance.source, PublicationSource.userCreated);
    });

    test('a user-created spell needs a summary or a description', () {
      expect(
        () => Spell(
          id: 'u1',
          name: 'My Spell',
          baseEffectId: 'e1',
          technique: 'Creo',
          form: 'Ignem',
          rangeId: 'range-voice',
          durationId: 'duration-momentary',
          targetId: 'target-individual',
          requisites: const {},
          provenance: Provenance(source: PublicationSource.userCreated),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('the rule names no source', () {
      expect(
        validateSpellProse(summary: null, description: null),
        ['a spell needs a summary or a description'],
      );
    });

    test('whitespace is not prose', () {
      // Pins the trim directly, because nothing else can: the fromMap route
      // never reaches an untrimmed validator -- `_backfilledSummary` trims
      // first and substitutes the placeholder, so a blank summary arrives at
      // the constructor already replaced. Without this test, dropping the
      // trim from validateSpellProse leaves the whole suite green while a
      // spell whose only prose is spaces saves and renders as a blank card.
      expect(
        validateSpellProse(summary: '   ', description: null),
        ['a spell needs a summary or a description'],
      );
      expect(
        validateSpellProse(summary: null, description: '\n\t '),
        ['a spell needs a summary or a description'],
      );
      expect(validateSpellProse(summary: '  x  ', description: null), isEmpty);
    });
  });

  group('validateSpellAgainstCatalog', () {
    BaseEffect fixedEffect() => BaseEffect(
          id: 'crig-10a', technique: 'Creo', form: 'Ignem',
          description: 'A fire doing +10 damage', baseLevel: 10,
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        );

    BaseEffect generalEffect() => BaseEffect(
          id: 'revi-G1', technique: 'Rego', form: 'Vim',
          description: 'Ward against beings of one realm', baseLevel: null,
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        );

    BaseEffect realmSlotEffect() => BaseEffect(
          id: 'revi-G1-open', technique: 'Rego', form: 'Vim',
          description: 'Ward against beings from one realm', baseLevel: null,
          openSlots: const [OpenSlotKind.realm],
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        );

    BaseEffect eitherSlotEffect() => BaseEffect(
          id: 'pevi-G10-open', technique: 'Perdo', form: 'Vim',
          description: 'Dispel a particular Hermetic Form or a specific type of enchantment',
          baseLevel: null,
          openSlots: const [OpenSlotKind.form, OpenSlotKind.specificType],
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        );

    Modifier singleChoice() => Modifier(
          id: 'size-ignem', name: 'Size (Ignem)',
          selectionMode: ModifierSelectionMode.single,
          scope: const ModifierScope(form: 'Ignem'),
          options: [
            ModifierOption(id: 'a', label: 'A', magnitude: 0),
            ModifierOption(id: 'b', label: 'B', magnitude: 1),
          ],
          provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
        );

    List<String> validate({
      required BaseEffect effect,
      String? technique,
      String? form,
      String? analogyRationale,
      int? chosenBaseLevel,
      Map<String, RequisiteKind> requisites = const {},
      Map<String, List<String>> selectedModifiers = const {},
      Map<String, String> chosenSlots = const {},
      List<Modifier> modifiers = const [],
      bool isTemplate = false,
      Parameter? range,
      Parameter? target,
      ContainerMode containerMode = ContainerMode.unstated,
    }) =>
        validateSpellAgainstCatalog(
          effect: effect,
          technique: technique ?? effect.technique,
          form: form ?? effect.form,
          analogyRationale: analogyRationale,
          chosenBaseLevel: chosenBaseLevel,
          requisites: requisites,
          selectedModifiers: selectedModifiers,
          chosenSlots: chosenSlots,
          modifiers: modifiers,
          isTemplate: isTemplate,
          range: range,
          target: target,
          containerMode: containerMode,
        );

    test('a valid fixed-level spell has no problems', () {
      expect(validate(effect: fixedEffect()), isEmpty);
    });

    test('check 1: a General guideline with no chosen level is a problem', () {
      expect(validate(effect: generalEffect()),
          contains('Choose a level for this General guideline'));
    });

    test('check 1: a General guideline with a level below 1 is a problem', () {
      expect(validate(effect: generalEffect(), chosenBaseLevel: 0),
          contains('The chosen level must be at least 1'));
    });

    test('check 1: a General guideline with a valid level is fine', () {
      expect(validate(effect: generalEffect(), chosenBaseLevel: 20), isEmpty);
    });

    test('check 2: a chosen level on a non-General guideline is a problem', () {
      expect(validate(effect: fixedEffect(), chosenBaseLevel: 20),
          contains('A chosen base level applies only to a General guideline'));
    });

    test('check 3: a requisite equal to the spell own Technique is a problem', () {
      expect(
        validate(effect: fixedEffect(), requisites: {'Creo': RequisiteKind.free}),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('check 3: a requisite equal to the spell own Form is a problem', () {
      expect(
        validate(effect: fixedEffect(), requisites: {'Ignem': RequisiteKind.free}),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('check 3: an unrelated requisite alongside a self-matching one still fires', () {
      expect(
        validate(
          effect: fixedEffect(),
          requisites: {
            'Creo': RequisiteKind.free, // matches fixedEffect's technique
            'Rego': RequisiteKind.adding, // unrelated
          },
        ),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('check 5: two options on a single-selection modifier is a problem', () {
      expect(
        validate(
          effect: fixedEffect(),
          selectedModifiers: {'size-ignem': ['a', 'b']},
          modifiers: [singleChoice()],
        ),
        contains('Only one option may be selected for Size (Ignem)'),
      );
    });

    test('check 5: one option on a single-selection modifier is fine', () {
      expect(
        validate(
          effect: fixedEffect(),
          selectedModifiers: {'size-ignem': ['a']},
          modifiers: [singleChoice()],
        ),
        isEmpty,
      );
    });

    test('an unknown modifier id is tolerated, matching calculateBreakdown', () {
      expect(
        validate(
          effect: fixedEffect(),
          selectedModifiers: {'no-such-modifier': ['a', 'b']},
          modifiers: [singleChoice()],
        ),
        isEmpty,
      );
    });

    test('isTemplate skips checks 1 and 2, which cannot apply to a template', () {
      // A General template legitimately has no chosen level -- supplying one is
      // what instantiating it means.
      expect(validate(effect: generalEffect(), isTemplate: true), isEmpty);
    });

    test('isTemplate still runs checks 3 and 5', () {
      expect(
        validate(
          effect: fixedEffect(),
          requisites: {'Creo': RequisiteKind.free},
          isTemplate: true,
        ),
        contains("Requisite art cannot be the spell's own technique or form"),
      );
    });

    test('problems accumulate rather than short-circuiting', () {
      final problems = validate(
        effect: generalEffect(), // technique Rego, form Vim, no chosenBaseLevel
        requisites: {'Rego': RequisiteKind.free}, // matches own technique
      );
      expect(problems.length, 2); // check 1 (no chosen level) + check 3 (self-match)
    });

    test('check 6: a declared open realm slot with no chosen value is a problem', () {
      expect(validate(effect: realmSlotEffect(), chosenBaseLevel: 20),
          contains('Choose a realm for this guideline'));
    });

    test('check 6: a filled realm slot is fine', () {
      expect(
        validate(
          effect: realmSlotEffect(),
          chosenBaseLevel: 20,
          chosenSlots: const {'realm': 'Infernal'},
        ),
        isEmpty,
      );
    });

    test('check 6: an either/or slot is satisfied by just one of its declared kinds', () {
      expect(
        validate(
          effect: eitherSlotEffect(),
          chosenBaseLevel: 20,
          chosenSlots: const {'specificType': 'Hermetic Terram magic'},
        ),
        isEmpty,
      );
    });

    test('check 6: an either/or slot with neither kind filled is a problem', () {
      expect(
        validate(effect: eitherSlotEffect(), chosenBaseLevel: 20),
        contains('Choose a Form or a specific type of enchantment for this guideline'),
      );
    });

    test('check 7: a chosen realm on a guideline with no open realm slot is a problem', () {
      expect(
        validate(effect: fixedEffect(), chosenSlots: const {'realm': 'Infernal'}),
        contains('A chosen realm applies only to a guideline with an open realm slot'),
      );
    });

    test('isTemplate still skips check 6 for an unfilled open slot', () {
      // A template may legitimately have an unfilled open slot -- Wind of
      // Mundane Silence (pevi-G5) is the real corpus case: its prose doesn't
      // commit to one realm, so its chosenSlots stays empty until a caster
      // instantiates it and fills one in.
      expect(validate(effect: realmSlotEffect(), isTemplate: true), isEmpty);
    });

    test('isTemplate still runs check 7 for a stray chosenSlots key', () {
      // Unlike check 6, check 7 is NOT skipped for a template -- a
      // SpellTemplate genuinely carries chosenSlots now, so a stray key
      // naming a kind the guideline never declared open is just as much a
      // bug there as on a Spell.
      expect(
        validate(
          effect: fixedEffect(),
          chosenSlots: const {'realm': 'Infernal'},
          isTemplate: true,
        ),
        contains('A chosen realm applies only to a guideline with an open realm slot'),
      );
    });

    test('check 8: matching technique/form with no analogyRationale is valid', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: null,
        target: null,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );
      expect(problems, isEmpty);
    });

    test('check 8: mismatched technique/form with a rationale is valid', () {
      final effect = BaseEffect(
        id: 'revi-G2', technique: 'Rego', form: 'Vim',
        description: 'test', baseLevel: null,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Rego',
        form: 'Imaginem',
        analogyRationale: 'By analogy to Rego Vim.',
        chosenBaseLevel: 20,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: null,
        target: null,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );
      expect(problems, isEmpty);
    });

    test('check 8: mismatched technique/form with no rationale is invalid', () {
      final effect = BaseEffect(
        id: 'revi-G2', technique: 'Rego', form: 'Vim',
        description: 'test', baseLevel: null,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Rego',
        form: 'Imaginem',
        analogyRationale: null,
        chosenBaseLevel: 20,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: null,
        target: null,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );
      expect(problems, ['Technique/Form differs from the base effect\'s own -- an analogyRationale is required to explain why']);
    });

    test('check 8: matching technique/form with a stray rationale is invalid', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: 'This should not be here.',
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: null,
        target: null,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );
      expect(problems, ["analogyRationale is set but Technique/Form already matches the base effect's own -- remove it"]);
    });

    group('check 9: container mode belongs only to a container Target', () {
      Parameter targetOfType(String id, TargetType type) => Parameter(
            id: id,
            name: id,
            category: 'Target',
            magnitude: 0,
            targetType: type,
            provenance: Provenance(
                source: PublicationSource.published,
                citations: const [Citation(bookId: 'arm5-core')]),
          );

      test('accepts either mode on a container Target', () {
        for (final mode in [ContainerMode.static, ContainerMode.dynamic]) {
          expect(
            validate(
              effect: fixedEffect(),
              target: targetOfType('target-room', TargetType.container),
              containerMode: mode,
            ),
            isEmpty,
          );
        }
      });

      test('rejects a stated mode on an object Target', () {
        expect(
          validate(
            effect: fixedEffect(),
            target: targetOfType('target-group', TargetType.object),
            containerMode: ContainerMode.dynamic,
          ),
          contains(contains('container mode applies only to a container Target')),
        );
      });

      test('rejects a stated mode on a sense Target', () {
        expect(
          validate(
            effect: fixedEffect(),
            target: targetOfType('target-vision', TargetType.sense),
            containerMode: ContainerMode.static,
          ),
          contains(contains('container mode applies only to a container Target')),
        );
      });

      test('unstated is accepted on every Target kind', () {
        for (final type in TargetType.values) {
          expect(
            validate(
              effect: fixedEffect(),
              target: targetOfType('target-x', type),
              containerMode: ContainerMode.unstated,
            ),
            isEmpty,
          );
        }
      });

      test('an unresolvable Target skips the check rather than reporting it', () {
        // Matches check 5's treatment of an unresolvable modifier: a null here
        // means the catalog could not resolve the id, which is a different
        // problem reported elsewhere (ResolvedSpell.isResolved).
        expect(
          validate(
              effect: fixedEffect(), target: null, containerMode: ContainerMode.dynamic),
          isEmpty,
        );
      });

      // Deliberately NO Momentary test in this group. Check 9 takes no Duration
      // — that is Decision 4 — so a "Momentary does not invalidate a stated
      // mode" test here could only duplicate the accept case above while its
      // comment claimed a guarantee it cannot provide. The Momentary rule is
      // pinned where it is actually executable, in spellOwesContainerMode's
      // group below. Do not add one here.
    });

    test('check 10: Personal Range with a container Target is rejected', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final personal = Parameter(
        id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0,
        forbidsTargetTypes: const [TargetType.container],
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final room = Parameter(
        id: 'target-room', name: 'Room', category: 'Target', magnitude: 2,
        targetType: TargetType.container,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: personal,
        target: room,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );

      expect(problems, hasLength(1));
      expect(problems.single, contains('Personal'));
      expect(problems.single, contains('Room'));
    });

    test('check 10: Personal Range with a sensorium Target is valid', () {
      final effect = BaseEffect(
        id: 'e1', technique: 'Creo', form: 'Ignem',
        description: 'test', baseLevel: 1,
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final personal = Parameter(
        id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0,
        forbidsTargetTypes: const [TargetType.container],
        provenance: Provenance(source: PublicationSource.userCreated),
      );
      final sound = Parameter(
        id: 'target-sound', name: 'Sound', category: 'Target', magnitude: 3,
        targetType: TargetType.sensorium,
        provenance: Provenance(source: PublicationSource.userCreated),
      );

      final problems = validateSpellAgainstCatalog(
        effect: effect,
        technique: 'Creo',
        form: 'Ignem',
        analogyRationale: null,
        chosenBaseLevel: null,
        requisites: const {},
        selectedModifiers: const {},
        chosenSlots: const {},
        range: personal,
        target: sound,
        containerMode: ContainerMode.unstated,
        modifiers: const [],
      );

      expect(problems, isEmpty);
    });
  });

  group('spellOwesContainerMode', () {
    Parameter param(String id, {String category = 'Target', TargetType? type}) =>
        Parameter(
          id: id,
          name: id,
          category: category,
          magnitude: 0,
          targetType: type,
          provenance: Provenance(
              source: PublicationSource.published,
              citations: const [Citation(bookId: 'arm5-core')]),
        );

    final room = param('target-room', type: TargetType.container);
    final group_ = param('target-group', type: TargetType.object);
    final sun = param('duration-sun', category: 'Duration');
    final momentary = param('duration-momentary', category: 'Duration');

    test('true for a container Target, a non-Momentary Duration and no mode', () {
      expect(
        spellOwesContainerMode(
            target: room, duration: sun, mode: ContainerMode.unstated),
        isTrue,
      );
    });

    test('false once a mode is stated', () {
      for (final mode in [ContainerMode.static, ContainerMode.dynamic]) {
        expect(
          spellOwesContainerMode(target: room, duration: sun, mode: mode),
          isFalse,
        );
      }
    });

    test('false for a non-container Target', () {
      expect(
        spellOwesContainerMode(
            target: group_, duration: sun, mode: ContainerMode.unstated),
        isFalse,
      );
    });

    test('false for a Momentary Duration', () {
      // Nothing can enter a container during a duration that does not elapse,
      // so the two designs are indistinguishable and no ruling is owed. This
      // is the case a later reader is most likely to get wrong.
      expect(
        spellOwesContainerMode(
            target: room, duration: momentary, mode: ContainerMode.unstated),
        isFalse,
      );
    });

    test('false when either parameter is unresolvable', () {
      expect(
        spellOwesContainerMode(
            target: null, duration: sun, mode: ContainerMode.unstated),
        isFalse,
      );
      expect(
        spellOwesContainerMode(
            target: room, duration: null, mode: ContainerMode.unstated),
        isFalse,
      );
    });
  });

  group('containerMode', () {
    Spell buildSpell({ContainerMode containerMode = ContainerMode.unstated}) => Spell(
          id: 's-1',
          baseEffectId: 'e1',
          technique: 'Creo',
          form: 'Ignem',
          rangeId: 'p1',
          durationId: 'p2',
          targetId: 'p3',
          requisites: const {},
          summary: 'Conjures a bolt of flame.',
          containerMode: containerMode,
          provenance: Provenance(source: PublicationSource.userCreated),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

    test('defaults to unstated', () {
      expect(buildSpell().containerMode, ContainerMode.unstated);
    });

    test('round-trips through toMap/fromMap', () {
      for (final mode in ContainerMode.values) {
        final restored =
            Spell.fromMap(buildSpell(containerMode: mode).toMap());
        expect(restored.containerMode, mode);
      }
    });

    test('serializes to the rulebook words', () {
      expect(buildSpell(containerMode: ContainerMode.static).toMap()['containerMode'],
          'static');
      expect(buildSpell(containerMode: ContainerMode.dynamic).toMap()['containerMode'],
          'dynamic');
    });

    test('a record with no containerMode key reads as unstated', () {
      final map = buildSpell().toMap()..remove('containerMode');
      expect(Spell.fromMap(map).containerMode, ContainerMode.unstated);
    });

    test('throws on an unknown stored value rather than defaulting', () {
      final map = buildSpell().toMap()..['containerMode'] = 'ongoing';
      expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
    });
  });
}
