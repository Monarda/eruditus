import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';

void main() {
  test('round-trips with a page', () {
    const citation = Citation(bookId: 'arm5-core', page: 142);
    expect(Citation.fromMap(citation.toMap()), citation);
  });

  test('round-trips without a page, and omits the key entirely', () {
    const citation = Citation(bookId: 'arm5-core');
    expect(citation.toMap().containsKey('page'), isFalse,
        reason: 'an absent page should be absent, not an explicit null');
    expect(Citation.fromMap(citation.toMap()), citation);
  });

  test('two citations of the same book and page are equal', () {
    expect(const Citation(bookId: 'arm5-core', page: 142),
        const Citation(bookId: 'arm5-core', page: 142));
  });

  test('the same book on different pages is not equal', () {
    expect(const Citation(bookId: 'arm5-core', page: 142),
        isNot(const Citation(bookId: 'arm5-core', page: 143)));
  });

  test('fromMap throws a descriptive FormatException when bookId is missing', () {
    expect(() => Citation.fromMap(const {'page': 12}),
        throwsA(isA<FormatException>()));
  });
}
