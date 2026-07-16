import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _PerpendicularCase {
  final LineSegment line1;
  final LineSegment line2;
  final bool isPerpendicular;

  const _PerpendicularCase(this.line1, this.line2, this.isPerpendicular);

  static List<_PerpendicularCase> cases = [
    _PerpendicularCase(
      LineSegment(P(0, 0), P(1, 0)),
      LineSegment(P(0, 0), P(0, 1)),
      true,
    ),
    _PerpendicularCase(
      LineSegment(P(0, 0), P(1, 0)),
      LineSegment(P(0, 0), P(0, -1)),
      true,
    ),
  ];

  static List<_PerpendicularCase> radial = [
    for (final angle in Iterable<double>.generate(9, (i) => (i * 45).toRadian))
      _PerpendicularCase(
        LineSegment.radial(angle),
        LineSegment.radial(angle + pi / 2),
        true,
      ),
    for (final angle in Iterable<double>.generate(9, (i) => (i * 45)))
      _PerpendicularCase(
        LineSegment.radial(angle),
        LineSegment.radial(angle - pi / 2),
        true,
      ),
    for (final angle in Iterable<double>.generate(9, (i) => (i * 45).toRadian))
      _PerpendicularCase(
        LineSegment.radial(angle),
        LineSegment.radial(angle + pi / 6),
        false,
      ),
    for (final angle in Iterable<double>.generate(9, (i) => (i * 45)))
      _PerpendicularCase(
        LineSegment.radial(angle),
        LineSegment.radial(angle - pi / 6),
        false,
      ),
  ];
}

void main() {
  group('LineSegment', () {
    test('radial', () {
      for (final test in _PerpendicularCase.cases) {
        expect(
          test.line1.isPerpendicularTo(test.line2),
          test.isPerpendicular,
          reason: 'for line1: ${test.line1}, line2: ${test.line2}',
        );
      }

      for (final test in _PerpendicularCase.radial) {
        expect(
          test.line1.isPerpendicularTo(test.line2),
          test.isPerpendicular,
          reason: 'for line1: ${test.line1}, line2: ${test.line2}',
        );
      }
    });
    /*
    test('radial.dummy', () {
      expect(
          LineSegment(
                  P(0.0, 0.0), Point(-0.4480736161291702, 0.8939966636005579))
              .isPerpendicularTo(LineSegment(Point(0.0, 0.0),
                  Point(0.8939966636005555, 0.44807361612917496))),
          true,
          reason: 'isPerpendicularTo failed');
    });
     */
  });
}
