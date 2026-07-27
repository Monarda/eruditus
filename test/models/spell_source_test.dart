import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/spell_source.dart';

void main() {
  test('wire values are exactly the two strings used in storage and assets', () {
    expect(SpellSource.published.wireValue, 'published');
    expect(SpellSource.userCreated.wireValue, 'user-created');
  });

  test('fromWire round-trips every value', () {
    for (final source in SpellSource.values) {
      expect(SpellSource.fromWire(source.wireValue), source);
    }
  });

  test('an unrecognised value throws rather than defaulting silently', () {
    expect(() => SpellSource.fromWire('built-in'),
        throwsA(isA<FormatException>()));
  });
}
