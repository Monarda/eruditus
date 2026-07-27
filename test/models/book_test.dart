import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/book.dart';

void main() {
  test('round-trips through toMap/fromMap', () {
    final book = Book(
      id: 'arm5-core',
      title: 'Ars Magica Fifth Edition',
      abbreviation: 'ArM5',
      edition: '5e',
    );
    final restored = Book.fromMap(book.toMap());

    expect(restored.id, book.id);
    expect(restored.title, book.title);
    expect(restored.abbreviation, book.abbreviation);
    expect(restored.edition, book.edition);
  });

  test('fromMap throws a descriptive FormatException when title is missing', () {
    expect(
      () => Book.fromMap(const {'id': 'x', 'abbreviation': 'X', 'edition': '5e'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('books are equal by id', () {
    final a = Book(id: 'arm5-core', title: 'A', abbreviation: 'A', edition: '5e');
    final b = Book(id: 'arm5-core', title: 'B', abbreviation: 'B', edition: '4e');
    expect(a, b);
  });
}
