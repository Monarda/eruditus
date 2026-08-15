import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_exception.dart';

void main() {
  final record = ExceptionSpell(
    id: 'exc-1',
    name: 'Test Exception',
    technique: 'Muto',
    form: 'Vim',
    range: 'Voice',
    duration: 'Sun & Year',
    target: 'Bound',
    isRitual: true,
    printedLevel: 60,
    summary: 'Test summary.',
    rationale: 'Test rationale.',
    provenance: Provenance(
      source: PublicationSource.published,
      citations: const [Citation(bookId: 'arm5-core')],
    ),
  );

  test('is always resolved, with no unresolved references', () {
    final resolved = ResolvedException(record: record);
    expect(resolved.isResolved, isTrue);
    expect(resolved.unresolvedReferences, isEmpty);
  });

  test('implements LibraryEntry', () {
    final ResolvedException resolved = ResolvedException(record: record);
    expect(resolved, isA<LibraryEntry>());
  });

  test('delegates name/technique/form/summary/description/source to the record', () {
    final resolved = ResolvedException(record: record);
    expect(resolved.name, 'Test Exception');
    expect(resolved.technique, 'Muto');
    expect(resolved.form, 'Vim');
    expect(resolved.summary, 'Test summary.');
    expect(resolved.description, isNull);
    expect(resolved.source, PublicationSource.published);
  });

  test('exposes rationale, isRitual and printedLevel', () {
    final resolved = ResolvedException(record: record);
    expect(resolved.rationale, 'Test rationale.');
    expect(resolved.isRitual, isTrue);
    expect(resolved.printedLevel, 60);
  });
}
