import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _SlopeCase {
  final LineSegment line;
  final double slope;
  final double angle;

  const _SlopeCase(this.line, this.slope, this.angle);

  static List<_SlopeCase> cases = [
    _SlopeCase(LineSegment(P(0, 0), P(10, 0)), 0, 0),
    _SlopeCase(LineSegment(P(0, 0), P(0, 10)), double.infinity, pi / 2),
    _SlopeCase(LineSegment(P(0, 0), P(-10, 0)), 0, pi),
    _SlopeCase(
        LineSegment(P(0, 0), P(0, -10)), double.negativeInfinity, -pi / 2),
  ];

  static List<_SlopeCase> radial = [
    for (final angle in [0.0, pi / 2, pi, -pi / 2])
      _SlopeCase(LineSegment.radial(angle), angle.angleToSlope, angle),
  ];
}

class _RadialCase {
  final double radius;
  final double angle;
  final LineSegment line;

  const _RadialCase(this.radius, this.angle, this.line);

  static List<_RadialCase> cases = [
    _RadialCase(1, 0, LineSegment.origin(P(1, 0))),
    _RadialCase(1, pi / 4, LineSegment.origin(P(0.707, 0.707))),
    _RadialCase(1, pi / 2, LineSegment.origin(P(0, 1))),
    _RadialCase(1, 3 * pi / 4, LineSegment.origin(P(-0.707, 0.707))),
    _RadialCase(1, pi, LineSegment.origin(P(-1, 0))),
    _RadialCase(1, 5 * pi / 4, LineSegment.origin(P(-0.707, -0.707))),
    _RadialCase(1, 6 * pi / 4, LineSegment.origin(P(0, -1))),
    _RadialCase(1, 7 * pi / 4, LineSegment.origin(P(0.707, -0.707))),
    _RadialCase(1, 8 * pi / 4, LineSegment.origin(P(1, 0))),
  ];
}

void main() {
  group('LineSegment', () {
    test('radial', () {
      for (final test in _RadialCase.cases) {
        expect(LineSegment.radial(test.angle, test.radius), test.line,
            reason:
                'wrong line for radius: ${test.radius}, angle: ${test.angle.toDegree}');
      }
    });

    test('slope and angle', () {
      for (final test in _SlopeCase.cases) {
        expect(test.line.slope, test.slope,
            reason: 'wrong slope for ${test.line}');
        expect(test.line.angle.equals(Radian(test.angle)), isTrue,
            reason: 'wrong angle for ${test.line}: expected ${test.angle}, got ${test.line.angle}');
      }

      for (final test in _SlopeCase.radial) {
        expect(test.line.slope, test.slope,
            reason: 'wrong slope for ${test.line}');
        expect(test.line.angle.equals(Radian(test.angle)), isTrue,
            reason: 'wrong angle for ${test.line}: expected ${test.angle}, got ${test.line.angle}');
      }
    });
  });
}
