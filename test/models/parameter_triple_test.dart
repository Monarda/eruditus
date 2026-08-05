import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/parameter_triple.dart';

void main() {
  test('the standard triple is Personal/Momentary/Individual', () {
    const triple = ParameterTriple.standard();

    expect(triple.rangeId, 'range-personal');
    expect(triple.durationId, 'duration-momentary');
    expect(triple.targetId, 'target-individual');
  });

  test('round-trips through a map', () {
    const triple = ParameterTriple(
      rangeId: 'range-touch', durationId: 'duration-ring', targetId: 'target-circle');

    expect(ParameterTriple.fromMap(triple.toMap()), triple);
  });

  test('fromMap requires all three ids', () {
    expect(() => ParameterTriple.fromMap({'rangeId': 'range-touch'}),
        throwsFormatException);
  });
}
