import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _SlopeRotateCase {
  final double slope;
  final double angle;
  final double rotatedSlope;

  const _SlopeRotateCase(this.slope, this.angle, this.rotatedSlope);

  static List<_SlopeRotateCase> cases = [
    for (final angle in Iterable.generate(
      9,
      (i) => (i * 45) - 180,
    ).map((v) => v.toRadian))
      _SlopeRotateCase(tan(angle), 30.toRadian, tan(angle + 30.toRadian)),
  ];
}

void main() {
  group('angle', () {
    test('slopeRotate', () {
      for (final test in _SlopeRotateCase.cases) {
        expect(
          test.slope.slopeRotate(test.angle),
          closeTo(test.rotatedSlope, 1e-3),
          reason: 'for slope: ${test.slope}, angle: ${test.angle.toDegree}',
        );
      }
    });
  });
}
