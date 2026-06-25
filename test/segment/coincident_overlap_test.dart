import 'package:ramanujan/ramanujan.dart';
import 'package:test/test.dart';

void main() {
  // ─── Helpers ──────────────────────────────────────────────────────────────

  void expectOverlap(CoincidentOverlap? ov,
      {required double tStart,
      required double tEnd,
      required double sStart,
      required double sEnd}) {
    expect(ov, isNotNull, reason: 'expected a non-null CoincidentOverlap');
    expect(ov!.tStart, closeTo(tStart, 1e-5));
    expect(ov.tEnd, closeTo(tEnd, 1e-5));
    expect(ov.sStart, closeTo(sStart, 1e-5));
    expect(ov.sEnd, closeTo(sEnd, 1e-5));
  }

  // ─── Line – Line ──────────────────────────────────────────────────────────

  group('LineSegment.coincidentOverlap(LineSegment)', () {
    test('identical segments — full overlap [0,1]×[0,1]', () {
      final a = LineSegment(P(0, 0), P(10, 0));
      final ov = a.coincidentOverlap(a);
      expectOverlap(ov, tStart: 0, tEnd: 1, sStart: 0, sEnd: 1);
    });

    test('partial overlap — B starts inside A and extends past end', () {
      final a = LineSegment(P(0, 0), P(10, 0));
      final b = LineSegment(P(5, 0), P(15, 0));
      final ov = a.coincidentOverlap(b);
      expectOverlap(ov, tStart: 0.5, tEnd: 1.0, sStart: 0.0, sEnd: 0.5);
    });

    test('B entirely inside A — full B visible on A subrange', () {
      final a = LineSegment(P(0, 0), P(10, 0));
      final b = LineSegment(P(2, 0), P(8, 0));
      final ov = a.coincidentOverlap(b);
      expectOverlap(ov, tStart: 0.2, tEnd: 0.8, sStart: 0, sEnd: 1);
    });

    test('reversed direction — sStart > sEnd', () {
      final a = LineSegment(P(0, 0), P(10, 0));
      final b = LineSegment(P(8, 0), P(2, 0)); // reversed
      final ov = a.coincidentOverlap(b);
      expectOverlap(ov, tStart: 0.2, tEnd: 0.8, sStart: 1.0, sEnd: 0.0);
      expect(ov!.reversed, isTrue);
    });

    test('non-overlapping collinear segments return null', () {
      final a = LineSegment(P(0, 0), P(5, 0));
      final b = LineSegment(P(6, 0), P(10, 0));
      expect(a.coincidentOverlap(b), isNull);
    });

    test('parallel but offset segments return null', () {
      final a = LineSegment(P(0, 0), P(10, 0));
      final b = LineSegment(P(0, 1), P(10, 1)); // 1 unit above
      expect(a.coincidentOverlap(b), isNull);
    });

    test('crossing (non-parallel) segments return null', () {
      final a = LineSegment(P(0, 0), P(10, 0));
      final b = LineSegment(P(5, -5), P(5, 5)); // vertical crossing
      expect(a.coincidentOverlap(b), isNull);
    });

    test('diagonal lines — full overlap', () {
      final a = LineSegment(P(0, 0), P(10, 10));
      final b = LineSegment(P(0, 0), P(10, 10));
      final ov = a.coincidentOverlap(b);
      expectOverlap(ov, tStart: 0, tEnd: 1, sStart: 0, sEnd: 1);
    });
  });

  // ─── Line – Quadratic/Cubic (degenerate Bézier) ───────────────────────────

  group('LineSegment.coincidentOverlap(degenerate Bézier)', () {
    test('collinear quadratic is coincident with its chord', () {
      // Control point on the line: p1=(0,0), c=(5,0), p2=(10,0)
      final line = LineSegment(P(0, 0), P(10, 0));
      final quad = QuadraticSegment(p1: P(0, 0), p2: P(10, 0), c: P(5, 0));
      final ov = line.coincidentOverlap(quad);
      expect(ov, isNotNull,
          reason: 'degenerate quadratic on line should be coincident');
      expect(ov!.tStart, closeTo(0.0, 1e-4));
      expect(ov.tEnd, closeTo(1.0, 1e-4));
    });

    test('curved quadratic off the line returns null', () {
      final line = LineSegment(P(0, 0), P(10, 0));
      final quad = QuadraticSegment(p1: P(0, 0), p2: P(10, 0), c: P(5, 5));
      expect(line.coincidentOverlap(quad), isNull);
    });
  });

  // ─── Quadratic – Quadratic ─────────────────────────────────────────────────

  group('QuadraticSegment.coincidentOverlap(QuadraticSegment)', () {
    test('identical quadratics — full overlap', () {
      final a = QuadraticSegment(p1: P(0, 0), p2: P(10, 0), c: P(5, 5));
      final ov = a.coincidentOverlap(a);
      expectOverlap(ov, tStart: 0, tEnd: 1, sStart: 0, sEnd: 1);
    });

    test('B is the right half of A (sub-curve)', () {
      // A: standard upward quadratic from (0,0) to (10,0) with apex at (5,5).
      // Sub-curve from t=0.5 to t=1.
      final a = QuadraticSegment(p1: P(0, 0), p2: P(10, 0), c: P(5, 5));
      // Compute sub-curve endpoints by de Casteljau at t=0.5
      final mid = a.lerp(0.5); // (5, 2.5)
      final cSub = LineSegment(P(5, 5), P(10, 0)).lerp(0.5); // (7.5, 2.5)
      final b = QuadraticSegment(p1: mid, p2: P(10, 0), c: cSub);
      final ov = a.coincidentOverlap(b);
      expect(ov, isNotNull, reason: 'sub-curve should be coincident');
      expect(ov!.tStart, closeTo(0.5, 1e-4));
      expect(ov.tEnd, closeTo(1.0, 1e-4));
    });

    test('distinct non-coincident quadratics return null', () {
      final a = QuadraticSegment(p1: P(0, 0), p2: P(10, 0), c: P(5, 5));
      final b = QuadraticSegment(p1: P(0, 1), p2: P(10, 1), c: P(5, 6));
      expect(a.coincidentOverlap(b), isNull);
    });

    test('quadratic × circular arc returns null', () {
      final q = QuadraticSegment(p1: P(0, 0), p2: P(10, 0), c: P(5, 5));
      final ca = CircularArcSegment(P(10, 0), P(0, 0), 7.07);
      expect(q.coincidentOverlap(ca), isNull);
    });
  });

  // ─── Cubic – Cubic ─────────────────────────────────────────────────────────

  group('CubicSegment.coincidentOverlap(CubicSegment)', () {
    test('identical cubics — full overlap', () {
      final a = CubicSegment(
          p1: P(0, 0), p2: P(10, 0), c1: P(2, 5), c2: P(8, 5));
      final ov = a.coincidentOverlap(a);
      expectOverlap(ov, tStart: 0, tEnd: 1, sStart: 0, sEnd: 1);
    });

    test('B is left half of A (sub-curve via de Casteljau)', () {
      // S-curve cubic
      final a = CubicSegment(
          p1: P(0, 0), p2: P(10, 0), c1: P(2, 6), c2: P(8, -6));
      // Sub-curve t ∈ [0, 0.5] via de Casteljau
      final (left, _) = a.bifurcateAtInterval(0.5);
      final ov = a.coincidentOverlap(left);
      expect(ov, isNotNull, reason: 'left half sub-curve should be coincident');
      expect(ov!.tStart, closeTo(0.0, 1e-4));
      expect(ov.tEnd, closeTo(0.5, 1e-4));
    });

    test('reversed cubic — overlap detected with reversed flag', () {
      final a = CubicSegment(
          p1: P(0, 0), p2: P(10, 0), c1: P(2, 5), c2: P(8, 5));
      final b = a.reversed();
      final ov = a.coincidentOverlap(b);
      expect(ov, isNotNull);
      expect(ov!.reversed, isTrue);
    });

    test('non-coincident cubics return null', () {
      final a =
          CubicSegment(p1: P(0, 0), p2: P(10, 0), c1: P(2, 5), c2: P(8, 5));
      final b =
          CubicSegment(p1: P(0, 1), p2: P(10, 1), c1: P(2, 6), c2: P(8, 6));
      expect(a.coincidentOverlap(b), isNull);
    });
  });

  // ─── CircularArcSegment – CircularArcSegment ──────────────────────────────

  group('CircularArcSegment.coincidentOverlap(CircularArcSegment)', () {
    // Unit circle arcs for reference
    // CCW quarter from (1,0) to (0,1)
    final topRight = CircularArcSegment(P(1, 0), P(0, 1), 1, clockwise: false);

    test('identical arc — full overlap', () {
      final ov = topRight.coincidentOverlap(topRight);
      expectOverlap(ov, tStart: 0, tEnd: 1, sStart: 0, sEnd: 1);
    });

    test('sub-arc: right half of top-right quarter', () {
      // B runs from (1,0) to (√2/2, √2/2), which is t=0..0.5 on topRight
      final mid = topRight.lerp(0.5);
      final b = CircularArcSegment(P(1, 0), mid, 1, clockwise: false);
      final ov = topRight.coincidentOverlap(b);
      expect(ov, isNotNull);
      expect(ov!.tStart, closeTo(0.0, 1e-4));
      expect(ov.tEnd, closeTo(0.5, 1e-4));
    });

    test('arcs on different circles return null', () {
      final a = CircularArcSegment(P(1, 0), P(0, 1), 1, clockwise: false);
      final b = CircularArcSegment(P(2, 0), P(0, 2), 2, clockwise: false);
      expect(a.coincidentOverlap(b), isNull);
    });

    test('non-overlapping arcs on same circle return null', () {
      // Top-right (0 to π/2) and bottom-left (π to 3π/2) do not overlap
      final a = CircularArcSegment(P(1, 0), P(0, 1), 1, clockwise: false);
      final b = CircularArcSegment(P(-1, 0), P(0, -1), 1, clockwise: false);
      expect(a.coincidentOverlap(b), isNull);
    });

    test('reversed() arc — overlap is detected (same parameterized direction)', () {
      // Due to the CW arc lerp convention, a.reversed() has lerp(t) ≈ a.lerp(t),
      // so the overlap is detected with reversed=false.
      final a = CircularArcSegment(P(1, 0), P(0, 1), 1, clockwise: false);
      final b = a.reversed();
      final ov = a.coincidentOverlap(b);
      expect(ov, isNotNull);
      expect(ov!.tStart, closeTo(0, 1e-4));
      expect(ov.tEnd, closeTo(1, 1e-4));
    });
  });

  // ─── ArcSegment – ArcSegment ──────────────────────────────────────────────

  group('ArcSegment.coincidentOverlap(ArcSegment)', () {
    // Ellipse with rx=2, ry=1 (horizontal)
    final ellipseRadii = P(2, 1);

    test('identical elliptic arcs — full overlap', () {
      final a = ArcSegment(P(2, 0), P(-2, 0), ellipseRadii, clockwise: false);
      final ov = a.coincidentOverlap(a);
      expect(ov, isNotNull);
      expect(ov!.tStart, closeTo(0, 1e-4));
      expect(ov.tEnd, closeTo(1, 1e-4));
    });

    test('arcs on different ellipses return null', () {
      final a = ArcSegment(P(2, 0), P(-2, 0), P(2, 1), clockwise: false);
      final b = ArcSegment(P(3, 0), P(-3, 0), P(3, 1), clockwise: false);
      expect(a.coincidentOverlap(b), isNull);
    });
  });

  // ─── Cross-type nulls ─────────────────────────────────────────────────────

  group('cross-type coincidentOverlap always returns null', () {
    test('line × arc returns null', () {
      final line = LineSegment(P(0, 0), P(10, 0));
      final arc = CircularArcSegment(P(-10, 0), P(10, 0), 10, clockwise: false);
      expect(line.coincidentOverlap(arc), isNull);
    });

    test('line × elliptic arc returns null', () {
      final line = LineSegment(P(0, 0), P(10, 0));
      final arc = ArcSegment(P(-10, 0), P(10, 0), P(10, 5), clockwise: false);
      expect(line.coincidentOverlap(arc), isNull);
    });

    test('quadratic × circular arc returns null', () {
      final q = QuadraticSegment(p1: P(-1, 0), p2: P(1, 0), c: P(0, 1));
      final ca = CircularArcSegment(P(-1, 0), P(1, 0), 1, clockwise: false);
      expect(q.coincidentOverlap(ca), isNull);
    });

    test('quadratic × elliptic arc returns null', () {
      final q = QuadraticSegment(p1: P(-1, 0), p2: P(1, 0), c: P(0, 1));
      final a = ArcSegment(P(-2, 0), P(2, 0), P(2, 1), clockwise: false);
      expect(q.coincidentOverlap(a), isNull);
    });

    test('cubic × circular arc returns null', () {
      final cu = CubicSegment(
          p1: P(-1, 0), p2: P(1, 0), c1: P(-0.5, 0.5), c2: P(0.5, 0.5));
      final ca = CircularArcSegment(P(-1, 0), P(1, 0), 1, clockwise: false);
      expect(cu.coincidentOverlap(ca), isNull);
    });
  });

  // ─── CoincidentOverlap.reversed ───────────────────────────────────────────

  group('CoincidentOverlap.reversed', () {
    test('sStart < sEnd → reversed is false', () {
      const ov = CoincidentOverlap(tStart: 0, tEnd: 1, sStart: 0, sEnd: 1);
      expect(ov.reversed, isFalse);
    });

    test('sStart > sEnd → reversed is true', () {
      const ov = CoincidentOverlap(tStart: 0, tEnd: 1, sStart: 1, sEnd: 0);
      expect(ov.reversed, isTrue);
    });
  });
}
