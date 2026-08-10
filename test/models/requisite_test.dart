import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/requisite.dart';

void main() {
  group('RequisiteKind.magnitude', () {
    test('adding has magnitude 1', () {
      expect(RequisiteKind.adding.magnitude, 1);
    });

    test('free has magnitude 0', () {
      expect(RequisiteKind.free.magnitude, 0);
    });
  });
}
