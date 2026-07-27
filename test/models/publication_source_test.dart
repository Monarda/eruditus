import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  test('wire values are exactly the two strings used in storage and assets', () {
    expect(PublicationSource.published.wireValue, 'published');
    expect(PublicationSource.userCreated.wireValue, 'user-created');
  });

  test('fromWire round-trips every value', () {
    for (final source in PublicationSource.values) {
      expect(PublicationSource.fromWire(source.wireValue), source);
    }
  });

  test('an unrecognised value throws rather than defaulting silently', () {
    expect(() => PublicationSource.fromWire('built-in'),
        throwsA(isA<FormatException>()));
  });
}
