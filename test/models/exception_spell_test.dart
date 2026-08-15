import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  ExceptionSpell buildException({
    String? summary = 'Test summary.',
    String? description,
    int? printedLevel,
    bool isRitual = false,
    PublicationSource source = PublicationSource.published,
  }) {
    return ExceptionSpell(
      id: 'exc-1',
      name: 'Test Exception',
      technique: 'Muto',
      form: 'Vim',
      range: 'Voice',
      duration: 'Sun & Year',
      target: 'Bound',
      isRitual: isRitual,
      printedLevel: printedLevel,
      summary: summary,
      description: description,
      rationale: 'Test rationale.',
      provenance: Provenance(
        source: source,
        citations: source == PublicationSource.published
            ? const [Citation(bookId: 'arm5-core')]
            : const [],
      ),
    );
  }

  test('a published exception needs a summary or description', () {
    expect(
      () => buildException(summary: null, description: null),
      throwsA(isA<FormatException>()),
    );
  });

  test('a published exception with only a description is valid', () {
    final exception = buildException(summary: null, description: 'Verbatim text.');
    expect(exception.description, 'Verbatim text.');
  });

  test('printedLevel is null for a General-kind exception', () {
    final exception = buildException(printedLevel: null);
    expect(exception.printedLevel, isNull);
  });

  test('printedLevel carries through for a fixed-level exception', () {
    final exception = buildException(printedLevel: 15);
    expect(exception.printedLevel, 15);
  });

  test('range/duration/target are the free-text strings as given', () {
    final exception = buildException();
    expect(exception.range, 'Voice');
    expect(exception.duration, 'Sun & Year');
    expect(exception.target, 'Bound');
  });

  test('toMap/fromMap round-trips every field', () {
    final original = buildException(printedLevel: 60, isRitual: true);
    final restored = ExceptionSpell.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.technique, original.technique);
    expect(restored.form, original.form);
    expect(restored.range, original.range);
    expect(restored.duration, original.duration);
    expect(restored.target, original.target);
    expect(restored.isRitual, original.isRitual);
    expect(restored.printedLevel, original.printedLevel);
    expect(restored.summary, original.summary);
    expect(restored.rationale, original.rationale);
    expect(restored.provenance.source, original.provenance.source);
    expect(restored.provenance.citations, original.provenance.citations);
  });

  test('a round trip with a null printedLevel stays null', () {
    final original = buildException(printedLevel: null);
    final restored = ExceptionSpell.fromMap(original.toMap());
    expect(restored.printedLevel, isNull);
  });

  test('fromMap throws a descriptive FormatException for a missing required field', () {
    final map = buildException().toMap()..remove('rationale');
    expect(
      () => ExceptionSpell.fromMap(map),
      throwsA(isA<FormatException>().having(
          (e) => e.message, 'message', contains('rationale'))),
    );
  });
}
