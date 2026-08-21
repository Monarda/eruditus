import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_exception.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_template.dart';
import 'package:eruditus/models/spell_validation_error.dart';
import 'package:eruditus/presentation/widgets/spell_card.dart';

import '../../support/pump_app.dart';

void main() {
  final rangeParam = Parameter(
      id: 'p1', name: 'Voice', category: 'Range', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final durationParam = Parameter(
      id: 'p2', name: 'Momentary', category: 'Duration', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final targetParam = Parameter(
      id: 'p3', name: 'Individual', category: 'Target', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final effect = BaseEffect(
    id: 'e1', technique: 'Creo', form: 'Ignem',
    description: 'test', baseLevel: 10,
    provenance: Provenance(source: PublicationSource.userCreated),
  );
  final personalParam = Parameter(
      id: 'range-personal', name: 'Personal', category: 'Range', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final momentaryParam = Parameter(
      id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));
  final individualParam = Parameter(
      id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0,
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]));

  ResolvedSpell buildSpell({
    String? name,
    PublicationSource source = PublicationSource.published,
    String? summary,
    String? description,
  }) {
    final record = Spell(
      id: '1',
      name: name,
      baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      requisites: const {},
      summary: summary,
      description: description,
      provenance: Provenance(
        source: source,
        citations: source == PublicationSource.published ? const [Citation(bookId: 'arm5-core')] : const [],
      ),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    return ResolvedSpell(
        record: record, baseEffect: effect, range: rangeParam, duration: durationParam, target: targetParam);
  }

  testWidgets('shows spell name, technique+form, level, and Published badge', (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(name: 'Pillar of Fire', summary: 'Test summary.'),
      level: 25,
    ));

    expect(find.text('Pillar of Fire'), findsOneWidget);
    expect(find.textContaining('Creo Ignem'), findsOneWidget);
    expect(find.textContaining('Level 25'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
  });

  testWidgets('shows "My Spell" badge for user-created spells', (tester) async {
    await pumpApp(tester, SpellCard(
        entry: buildSpell(
            name: 'My Fireball',
            source: PublicationSource.userCreated,
            summary: 'Test summary.')));

    expect(find.text('My Spell'), findsOneWidget);
  });

  testWidgets('falls back to "Untitled Technique Form" when name is null', (tester) async {
    await pumpApp(tester, SpellCard(entry: buildSpell(name: null, summary: 'Test summary.')));

    expect(find.text('Untitled Creo Ignem'), findsOneWidget);
  });

  testWidgets('shows the spell description when present', (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(name: 'Pillar of Fire', description: 'A wall of roaring flame.'),
      level: 25,
    ));

    expect(find.text('A wall of roaring flame.'), findsOneWidget);
  });

  testWidgets('falls back to the description when summary is the empty string, not just null',
      (tester) async {
    // Reachable in ordinary use: instantiate a template (seeds both), clear
    // the Summary field (SummaryChanged('') -> draft.summary == ''), save.
    // `entry.summary ?? entry.description` does not fall through on '' since
    // `??` only checks for null, so this pins the blank-is-absent treatment.
    await pumpApp(tester, SpellCard(
      entry: buildSpell(
          name: 'Pillar of Fire', summary: '', description: 'A wall of roaring flame.'),
      level: 25,
    ));

    expect(find.text('A wall of roaring flame.'), findsOneWidget);
  });

  testWidgets('tapping the card invokes onTap', (tester) async {
    var tapped = false;
    await pumpApp(tester, SpellCard(
      entry: buildSpell(
          name: 'Test', source: PublicationSource.userCreated, summary: 'Test summary.'),
      onTap: () => tapped = true,
    ));

    await tester.tap(find.byType(SpellCard));
    expect(tapped, isTrue);
  });

  testWidgets('an unresolved spell is shown as unavailable with no level', (tester) async {
    final record = Spell(
      id: 'orphan',
      name: 'Orphaned Spell',
      baseEffectId: 'deleted-custom-effect',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const {},
      summary: 'Conjures a bolt of flame.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    // Base effect missing, parameters present — exactly what a deleted custom
    // effect leaves behind.
    final unresolved = ResolvedSpell(
      record: record,
      baseEffect: null,
      range: personalParam,
      duration: momentaryParam,
      target: individualParam,
    );

    await pumpApp(tester, SpellCard(entry: unresolved));

    expect(find.byKey(const Key('spell-card-unresolved')), findsOneWidget);
    expect(find.text('Orphaned Spell'), findsOneWidget);
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(find.textContaining('deleted-custom-effect'), findsOneWidget);
    expect(find.textContaining('Level'), findsNothing);
    // This branch changed ResolvedSpell.technique/.form to read from the
    // record even when baseEffect is null (previously they went null). The
    // unresolved card's subtitle replaces technique/form with the
    // "Unavailable -- missing ..." message, so that survival isn't visible
    // in rendered text here; pin it directly on the entry instead.
    expect(unresolved.technique, 'Creo');
    expect(unresolved.form, 'Ignem');
  });

  testWidgets('shows a Ritual chip only when the spell is a Ritual',
      (tester) async {
    final spell = buildSpell(name: 'Touch of Midas', summary: 'Test summary.');

    await pumpApp(tester, SpellCard(entry: spell, level: 20, isRitual: true));
    expect(find.byKey(const Key('ritual-chip')), findsOneWidget);
    expect(find.text('Ritual'), findsOneWidget);

    await pumpApp(tester, SpellCard(entry: spell, level: 20));
    expect(find.byKey(const Key('ritual-chip')), findsNothing);
  });

  testWidgets('shows a "Needs review" chip, unverified level suffix, and joined problem text',
      (tester) async {
    final spell = buildSpell(name: 'Miscast Aegis', summary: 'Test summary.');

    await pumpApp(tester, SpellCard(
      entry: spell,
      level: 20,
      problems: const [
        GeneralLevelNotChosen(),
        ModifierNotMultiSelect('Size'),
      ],
    ));

    expect(find.byKey(const Key('needs-review-chip')), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.textContaining('Level 20 (unverified)'), findsOneWidget);
    expect(
      find.text('Choose a level for this General guideline; Only one option may be selected for Size'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('spell-card-invalid')), findsOneWidget);
  });

  testWidgets('an empty problems list renders no chip, no suffix, and no invalid key',
      (tester) async {
    final spell = buildSpell(name: 'Ordinary Bolt', summary: 'Test summary.');

    await pumpApp(tester, SpellCard(entry: spell, level: 20));

    expect(find.byKey(const Key('needs-review-chip')), findsNothing);
    expect(find.textContaining('(unverified)'), findsNothing);
    expect(find.byKey(const Key('spell-card-invalid')), findsNothing);
  });

  testWidgets(
      'an unresolved spell with a non-empty problems value still renders only the unavailable branch',
      (tester) async {
    final record = Spell(
      id: 'orphan-2',
      name: 'Half-Broken Spell',
      baseEffectId: 'deleted-custom-effect',
      technique: 'Creo',
      form: 'Ignem',
      rangeId: 'range-personal',
      durationId: 'duration-momentary',
      targetId: 'target-individual',
      requisites: const {},
      summary: 'Conjures a bolt of flame, partially.',
      provenance: Provenance(source: PublicationSource.userCreated),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    // Base effect missing, parameters present -- the same "deleted custom
    // effect" shape as the existing unresolved fixture above. The explicit
    // non-empty `problems` here exercises the widget's own gating (isResolved
    // && problems.isNotEmpty), independent of whether ResolvedSpell.problems
    // could ever actually produce this combination for a real record.
    final unresolved = ResolvedSpell(
      record: record,
      baseEffect: null,
      range: personalParam,
      duration: momentaryParam,
      target: individualParam,
    );

    await pumpApp(tester, SpellCard(
      entry: unresolved,
      problems: const [GeneralLevelNotChosen()],
    ));

    expect(find.byKey(const Key('spell-card-unresolved')), findsOneWidget);
    expect(find.byKey(const Key('spell-card-invalid')), findsNothing);
    expect(find.byKey(const Key('needs-review-chip')), findsNothing);
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(find.text('Choose a level for this General guideline'), findsNothing);
  });

  ResolvedTemplate buildTemplate({
    String? summary,
    String? description,
    PublicationSource source = PublicationSource.published,
  }) {
    final record = SpellTemplate(
      id: 'tpl-1',
      name: 'Ward against Faeries of the Waters',
      baseEffectId: effect.id,
      technique: 'Creo',
      form: 'Ignem',
      rangeId: rangeParam.id,
      durationId: durationParam.id,
      targetId: targetParam.id,
      summary: summary,
      description: description,
      provenance: Provenance(
          source: source,
          citations: source == PublicationSource.published ? const [Citation(bookId: 'arm5-core')] : const []),
    );
    return ResolvedTemplate(
        record: record, baseEffect: effect, range: rangeParam, duration: durationParam, target: targetParam);
  }

  ResolvedException buildException({
    String? summary,
    String? description,
    PublicationSource source = PublicationSource.published,
  }) {
    final record = ExceptionSpell(
      id: 'exc-1',
      name: 'Wizard\'s Communion',
      technique: 'Creo',
      form: 'Vim',
      range: 'Special',
      duration: 'Special',
      target: 'Special',
      rationale: 'Does not follow the guideline system.',
      summary: summary,
      description: description,
      provenance: Provenance(
          source: source,
          citations: source == PublicationSource.published ? const [Citation(bookId: 'arm5-core')] : const []),
    );
    return ResolvedException(record: record);
  }

  testWidgets('a card built from a template renders its name, Technique/Form, blurb, and Published chip',
      (tester) async {
    await pumpApp(tester, SpellCard(entry: buildTemplate(summary: 'Wards against faeries of water.')));

    expect(find.text('Ward against Faeries of the Waters'), findsOneWidget);
    expect(find.textContaining('Creo Ignem'), findsOneWidget);
    expect(find.text('Wards against faeries of water.'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
  });

  testWidgets('shows a Gen chip only when isGeneral is true', (tester) async {
    final template = buildTemplate(summary: 'Test summary.');

    await pumpApp(tester, SpellCard(entry: template, isGeneral: true));
    expect(find.byKey(const Key('general-chip')), findsOneWidget);
    expect(find.text('Gen'), findsOneWidget);

    await pumpApp(tester, SpellCard(entry: template));
    expect(find.byKey(const Key('general-chip')), findsNothing);
  });

  testWidgets('shows an Exception chip only when isException is true', (tester) async {
    final template = buildTemplate(summary: 'Test summary.');

    await pumpApp(tester, SpellCard(entry: template, isException: true));
    expect(find.byKey(const Key('exception-chip')), findsOneWidget);
    expect(find.text('Exception'), findsOneWidget);

    await pumpApp(tester, SpellCard(entry: template));
    expect(find.byKey(const Key('exception-chip')), findsNothing);
  });

  testWidgets('shows the rationale text only when provided', (tester) async {
    final template = buildTemplate(summary: 'Test summary.');

    await pumpApp(tester, SpellCard(entry: template, rationale: 'Rulebook says guideline arithmetic doesn\'t apply.'));
    expect(find.text('Rulebook says guideline arithmetic doesn\'t apply.'), findsOneWidget);

    await pumpApp(tester, SpellCard(entry: template));
    expect(find.text('Rulebook says guideline arithmetic doesn\'t apply.'), findsNothing);
  });

  testWidgets('a null level renders the subtitle with no level suffix', (tester) async {
    await pumpApp(tester, SpellCard(entry: buildTemplate(summary: 'Test summary.')));
    expect(find.textContaining('Creo Ignem'), findsOneWidget);
    expect(find.textContaining('Level'), findsNothing);
  });

  testWidgets('the card chrome is localised but the spell name is not',
      (tester) async {
    final spell = buildSpell(name: 'Miscast Aegis', summary: 'Test summary.');

    await pumpApp(tester, SpellCard(
      entry: spell,
      level: 20,
      problems: const [
        GeneralLevelNotChosen(),
        ModifierNotMultiSelect('Size'),
      ],
    ), locale: const Locale('en', 'XA'));

    expect(find.text('Needs review'), findsNothing,
        reason: 'chrome should be pseudo-transformed under en_XA');
  });

  testWidgets("a published spell's blurb renders as a quote", (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(name: 'Pillar of Fire', summary: 'The rulebook says this.'),
      level: 25,
    ));

    expect(find.byKey(const Key('sourced-text-quote')), findsOneWidget,
        reason: "a published spell's prose is the book's own words");
  });

  testWidgets("a user-created spell's blurb renders as plain prose", (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(
          name: 'My Fireball',
          source: PublicationSource.userCreated,
          summary: 'My own spell idea.'),
    ));

    expect(find.text('My own spell idea.'), findsOneWidget);
    expect(find.byKey(const Key('sourced-text-quote')), findsNothing,
        reason: 'quote styling on the caster\'s own words would attribute '
            'them to the rulebook');
  });

  testWidgets("the card's blurb carries no competing tap target", (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(name: 'Pillar of Fire', summary: 'The rulebook says this.'),
      level: 25,
    ));

    expect(find.byKey(const Key('sourced-text-marker')), findsNothing,
        reason: 'showMarker is false so that a caller who does pass onTap '
            'gets one gesture target, not two, inside the list row');
  });

  testWidgets('the blurb is still truncated to two lines', (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildSpell(name: 'Pillar of Fire', summary: 'The rulebook says this.'),
      level: 25,
    ));

    final text = tester.widget<Text>(find.text('The rulebook says this.'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets("a published template's blurb renders as a quote", (tester) async {
    await pumpApp(tester, SpellCard(entry: buildTemplate(summary: 'Wards against faeries of water.')));

    expect(find.byKey(const Key('sourced-text-quote')), findsOneWidget,
        reason: 'a General template is published rulebook prose, same as a spell');
  });

  testWidgets("a user-created template's blurb renders as plain prose", (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildTemplate(summary: 'My homebrew ward.', source: PublicationSource.userCreated),
    ));

    expect(find.text('My homebrew ward.'), findsOneWidget);
    expect(find.byKey(const Key('sourced-text-quote')), findsNothing);
  });

  testWidgets("a published exception's blurb renders as a quote", (tester) async {
    await pumpApp(tester, SpellCard(entry: buildException(summary: 'A famous ritual among Bonisagi.')));

    expect(find.byKey(const Key('sourced-text-quote')), findsOneWidget,
        reason: 'an exception spell is published rulebook prose, same as an ordinary spell');
  });

  testWidgets("a user-created exception's blurb renders as plain prose", (tester) async {
    await pumpApp(tester, SpellCard(
      entry: buildException(summary: 'My own oddity.', source: PublicationSource.userCreated),
    ));

    expect(find.text('My own oddity.'), findsOneWidget);
    expect(find.byKey(const Key('sourced-text-quote')), findsNothing);
  });
}
