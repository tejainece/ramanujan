import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  test('boundingBox includes the peak of a symmetric hump (a.y == 0 case)', () {
    // Both control points sit at the same y (-40), so the derivative's
    // quadratic coefficient on y is exactly zero: a degenerate case the
    // general quadratic-formula solve must fall back to a linear solve for.
    final hump = CubicSegment(
      p1: P(0, 0),
      c1: P(30, -40),
      c2: P(70, -40),
      p2: P(100, 0),
    );

    final box = hump.boundingBox;

    expect(
      box.top,
      lessThan(-25),
      reason: 'peak of the hump must be included, not just the endpoints',
    );
  });

  test('boundingBox includes the peak of a symmetric dip (a.x == 0 case)', () {
    // Same degeneracy on the x-axis instead, for a vertically oriented curve.
    final hump = CubicSegment(
      p1: P(0, 0),
      c1: P(-40, 30),
      c2: P(-40, 70),
      p2: P(0, 100),
    );

    final box = hump.boundingBox;

    expect(
      box.left,
      lessThan(-25),
      reason: 'peak of the hump must be included, not just the endpoints',
    );
  });

  test('boundingBox still matches ordinary (a != 0) curves', () {
    final quarterCircle = CubicSegment(
      p1: P(0, -100),
      c1: P(55.2284749831, -100),
      c2: P(100, -55.2284749831),
      p2: P(100, 0),
    );

    final box = quarterCircle.boundingBox;

    expect(box.left, closeTo(0, 1e-6));
    expect(box.top, closeTo(-100, 1e-6));
    expect(box.right, closeTo(100, 1e-6));
    expect(box.bottom, closeTo(0, 1e-6));
  });
}
