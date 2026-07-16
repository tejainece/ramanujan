import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

// A geometrically-straight cubic along y=[y], x running [x0]..[x1].
CubicSegment lineCubic(double x0, double x1, double y) => CubicSegment(
  p1: P(x0, y),
  c1: P(x0 + (x1 - x0) / 3, y),
  c2: P(x0 + 2 * (x1 - x0) / 3, y),
  p2: P(x1, y),
);

double minDistToSegment(P p, Segment s) {
  var best = double.infinity;
  const n = 40000;
  for (int i = 0; i <= n; i++) {
    final d = s.lerp(i / n).distanceTo(p);
    if (d < best) best = d;
  }
  return best;
}

/// Every reported point must independently lie on both segments.
void expectOnBoth(List<P> hits, Segment a, Segment b) {
  for (final p in hits) {
    expect(minDistToSegment(p, a), lessThan(1e-3), reason: 'off A: $p');
    expect(minDistToSegment(p, b), lessThan(1e-3), reason: 'off B: $p');
  }
}

void expectPoints(List<P> hits, List<P> want) {
  expect(hits.length, want.length, reason: 'got $hits');
  for (final w in want) {
    expect(
      hits.any((p) => p.distanceTo(w) < 1e-3),
      isTrue,
      reason: 'missing $w in $hits',
    );
  }
}

void main() {
  group('cubic × quadratic', () {
    test('symmetric parabola crossing a straight cubic', () {
      final cubic = lineCubic(-10, 10, 0);
      final quad = QuadraticSegment(p1: P(-5, -5), c: P(0, 15), p2: P(5, -5));
      final hits = cubic.intersect(quad);
      expectOnBoth(hits, cubic, quad);
      // Q(s) crosses y=0 at x = ±5/√2 ≈ ±3.5355.
      expectPoints(hits, [P(-5 / sqrt2, 0), P(5 / sqrt2, 0)]);
    });

    test('reverse direction agrees (quadratic × cubic)', () {
      final cubic = lineCubic(-10, 10, 0);
      final quad = QuadraticSegment(p1: P(-5, -5), c: P(0, 15), p2: P(5, -5));
      expect(quad.intersect(cubic).length, cubic.intersect(quad).length);
    });
  });

  group('cubic × cubic', () {
    test('two straight cubics crossing at the origin', () {
      final a = lineCubic(-10, 10, 0);
      final b = CubicSegment(
        p1: P(0, -10),
        c1: P(0, -10 / 3),
        c2: P(0, 10 / 3),
        p2: P(0, 10),
      );
      final hits = a.intersect(b);
      expectOnBoth(hits, a, b);
      expectPoints(hits, [P(0, 0)]);
    });

    test('genuine S-curves crossing (degree-9 path)', () {
      final a = CubicSegment(
        p1: P(-9, -3),
        c1: P(-3, 12),
        c2: P(3, -12),
        p2: P(9, 3),
      );
      final b = CubicSegment(
        p1: P(-3, -9),
        c1: P(12, -3),
        c2: P(-12, 3),
        p2: P(3, 9),
      );
      final hits = a.intersect(b);
      expect(hits, isNotEmpty);
      expectOnBoth(hits, a, b);
    });
  });

  group('cubic × circular arc', () {
    test('straight cubic across a top semicircle', () {
      final cubic = lineCubic(-10, 10, 3); // y = 3
      // Top half of circle r=5 at origin (CCW from (5,0) to (-5,0)).
      final arc = CircularArcSegment(P(5, 0), P(-5, 0), 5, clockwise: false);
      final hits = cubic.intersect(arc);
      expectOnBoth(hits, cubic, arc);
      expectPoints(hits, [P(-4, 3), P(4, 3)]); // x² + 9 = 25
    });

    test('reverse direction agrees (arc × cubic)', () {
      final cubic = lineCubic(-10, 10, 3);
      final arc = CircularArcSegment(P(5, 0), P(-5, 0), 5, clockwise: false);
      expect(arc.intersect(cubic).length, cubic.intersect(arc).length);
    });
  });

  group('cubic × elliptical arc', () {
    test('straight cubic across a top half-ellipse', () {
      final cubic = lineCubic(-10, 10, 1); // y = 1
      final arc = ArcSegment(P(8, 0), P(-8, 0), P(8, 4), clockwise: false);
      final hits = cubic.intersect(arc);
      expectOnBoth(hits, cubic, arc);
      // x²/64 + 1/16 = 1 → x = ±√60.
      expectPoints(hits, [P(-sqrt(60), 1), P(sqrt(60), 1)]);
    });

    test('reverse direction agrees (arc × cubic)', () {
      final cubic = lineCubic(-10, 10, 1);
      final arc = ArcSegment(P(8, 0), P(-8, 0), P(8, 4), clockwise: false);
      expect(arc.intersect(cubic).length, cubic.intersect(arc).length);
    });
  });
}
