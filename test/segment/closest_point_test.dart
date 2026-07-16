import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  // Reference minimum distance by dense sampling of the curve — used only to
  // validate the analytic closestT.
  double bruteMinDistance(Segment s, P q) {
    const n = 4000;
    var best = double.infinity;
    for (int i = 0; i <= n; i++) {
      final d = s.lerp(i / n).distanceTo(q);
      if (d < best) best = d;
    }
    return best;
  }

  void expectClosest(Segment s, String name, List<P> queries) {
    for (final q in queries) {
      final t = s.closestT(q);
      expect(t, inInclusiveRange(0.0, 1.0), reason: '$name @ $q: t=$t');
      final d = s.closestPoint(q).distanceTo(q);
      final brute = bruteMinDistance(s, q);
      expect(
        d,
        lessThanOrEqualTo(brute + 1e-3),
        reason: '$name @ $q: closestPoint distance $d vs sampled $brute',
      );
    }
  }

  // Points on the curve must project onto themselves.
  void expectOnCurveRoundTrip(Segment s, String name) {
    for (final t in [0.0, 0.2, 0.5, 0.8, 1.0]) {
      final p = s.lerp(t);
      final cp = s.closestPoint(p);
      expect(
        cp.isEqual(p, 1e-4),
        isTrue,
        reason: '$name @ t=$t: on-curve point $p projected to $cp',
      );
    }
  }

  group('LineSegment', () {
    final line = LineSegment(const P(10, 10), const P(110, 60));

    test('interior projection is perpendicular', () {
      const q = P(60, 0);
      final t = line.closestT(q);
      final cp = line.lerp(t);
      final dir = line.p2 - line.p1;
      final toQ = q - cp;
      expect((dir.x * toQ.x + dir.y * toQ.y).abs(), lessThan(1e-6));
    });

    test('clamps beyond the endpoints', () {
      expect(line.closestT(const P(-100, 0)), 0);
      expect(line.closestT(const P(300, 100)), 1);
    });

    test('degenerate zero-length segment', () {
      final dot = LineSegment(const P(5, 5), const P(5, 5));
      expect(dot.closestT(const P(50, 50)), 0);
    });

    test('matches sampled minimum', () {
      expectOnCurveRoundTrip(line, 'line');
      expectClosest(line, 'line', const [
        P(60, 0),
        P(0, 100),
        P(-50, -50),
        P(200, 200),
        P(55, 35),
      ]);
    });
  });

  group('QuadraticSegment', () {
    final quad = QuadraticSegment(
      p1: const P(0, 0),
      c: const P(50, 80),
      p2: const P(100, 0),
    );

    test('apex query resolves to the top of the arch', () {
      // Directly above the symmetric apex: closest point is at t=0.5.
      final t = quad.closestT(const P(50, 100));
      expect(t, closeTo(0.5, 1e-6));
    });

    test('matches sampled minimum', () {
      expectOnCurveRoundTrip(quad, 'quadratic');
      expectClosest(quad, 'quadratic', const [
        P(50, 100),
        P(50, 0),
        P(-20, -20),
        P(120, 30),
        P(25, 35),
        P(50, 39.999),
      ]);
    });
  });

  group('CubicSegment', () {
    final cubic = CubicSegment(
      p1: const P(0, 0),
      c1: const P(30, 90),
      c2: const P(70, -60),
      p2: const P(100, 20),
    );

    test('matches sampled minimum', () {
      expectOnCurveRoundTrip(cubic, 'cubic');
      expectClosest(cubic, 'cubic', const [
        P(50, 50),
        P(50, -50),
        P(-30, 10),
        P(140, 30),
        P(50, 10),
        P(0, 100),
      ]);
    });

    test('loop-adjacent query picks the globally nearest branch', () {
      // A self-intersecting cubic has two locally-closest branches; the
      // returned point must be the global minimum, not just any stationary t.
      final loop = CubicSegment(
        p1: const P(0, 0),
        c1: const P(150, 100),
        c2: const P(-50, 100),
        p2: const P(100, 0),
      );
      expectOnCurveRoundTrip(loop, 'loop cubic');
      expectClosest(loop, 'loop cubic', const [
        P(50, 80),
        P(50, 20),
        P(10, 50),
        P(90, 50),
      ]);
    });
  });

  group('CircularArcSegment', () {
    final ccw = CircularArcSegment(
      const P(50, 0),
      const P(0, 50),
      50,
      clockwise: false,
    );

    test('radial projection inside the span', () {
      // Query along the 45° radial of a quarter circle centered at origin.
      final t = ccw.closestT(const P(100, 100));
      final cp = ccw.lerp(t);
      expect(cp.isEqual(P(50 / sqrt2, 50 / sqrt2), 1e-6), isTrue);
    });

    test('outside the span clamps to the closer endpoint', () {
      // The nearest circle point is outside the quarter-circle span.
      final t = ccw.closestT(const P(60, -30));
      expect(t, 0);
      final t2 = ccw.closestT(const P(-30, 60));
      expect(t2, 1);
    });

    test('matches sampled minimum (ccw)', () {
      expectOnCurveRoundTrip(ccw, 'ccw arc');
      expectClosest(ccw, 'ccw arc', const [
        P(100, 100),
        P(10, 10),
        P(60, -30),
        P(-30, 60),
        P(0, 0),
      ]);
    });

    test('matches sampled minimum (cw, large arc)', () {
      final cw = CircularArcSegment(
        const P(50, 0),
        const P(0, 50),
        50,
        clockwise: true,
        largeArc: true,
      );
      expectOnCurveRoundTrip(cw, 'cw large arc');
      expectClosest(cw, 'cw large arc', const [
        P(100, 100),
        P(-80, -80),
        P(10, 10),
        P(60, -30),
      ]);
    });
  });

  group('ArcSegment', () {
    final arc = ArcSegment(
      const P(80, 0),
      const P(-80, 0),
      const P(80, 40),
      clockwise: false,
    );

    test('matches sampled minimum', () {
      expectOnCurveRoundTrip(arc, 'elliptic arc');
      expectClosest(arc, 'elliptic arc', const [
        P(0, 100),
        P(0, 10),
        P(70, 30),
        P(-70, 30),
        P(120, -20),
        P(0, 41),
      ]);
    });

    test('matches sampled minimum (rotated, clockwise)', () {
      final rotated = ArcSegment(
        const P(30, 10),
        const P(-40, -20),
        const P(60, 25),
        rotation: pi / 6,
        clockwise: true,
      );
      expectOnCurveRoundTrip(rotated, 'rotated cw arc');
      expectClosest(rotated, 'rotated cw arc', const [
        P(0, 60),
        P(0, -60),
        P(50, 0),
        P(-60, 10),
        P(5, 5),
      ]);
    });

    test('interior stationary point is perpendicular to the curve', () {
      const q = P(0, 10); // inside the ellipse, above center
      final t = arc.closestT(q);
      if (t > 0 && t < 1) {
        final tan = arc.unitTangentAt(t);
        final toQ = (q - arc.lerp(t)).normalized;
        expect((tan.x * toQ.x + tan.y * toQ.y).abs(), lessThan(1e-3));
      }
    });
  });
}
