import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

/// Signed area ×2 of the polygon through the offset segment endpoints.
double _area2(List<Segment> segs) {
  final pts = <P>[segs.first.p1, for (final s in segs) s.p2];
  if (pts.length > 1 && pts.last.isEqual(pts.first)) pts.removeLast();
  double a = 0;
  for (int i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.x * q.y - q.x * p.y;
  }
  return a;
}

bool _isClosed(List<Segment> segs) =>
    (segs.last.p2 - segs.first.p1).lengthSquared < 1e-6;

bool _continuous(List<Segment> segs) {
  for (var i = 1; i < segs.length; i++) {
    if (!segs[i].p1.isEqual(segs[i - 1].p2)) return false;
  }
  return true;
}

void main() {
  // A unit-ish square wound counter-clockwise in shoelace terms (area2 > 0).
  List<Segment> square(double n) => [
        LineSegment(P(0, 0), P(n, 0)),
        LineSegment(P(n, 0), P(n, n)),
        LineSegment(P(n, n), P(0, n)),
        LineSegment(P(0, n), P(0, 0)),
      ];

  group('square (lines only)', () {
    test('outset grows the bounding box by delta on every side', () {
      final out = outset(square(100), 10, join: OffsetJoin.miter);
      // Corners are sharp (miter), so the outline is the 110-side square offset
      // outward by 10: x in [-10, 110], y in [-10, 110].
      final xs = out.expand((s) => [s.p1.x, s.p2.x]);
      final ys = out.expand((s) => [s.p1.y, s.p2.y]);
      expect(xs.reduce(math.min), closeTo(-10, 1e-6));
      expect(xs.reduce(math.max), closeTo(110, 1e-6));
      expect(ys.reduce(math.min), closeTo(-10, 1e-6));
      expect(ys.reduce(math.max), closeTo(110, 1e-6));
    });

    test('inset shrinks the bounding box by delta on every side', () {
      final out = inset(square(100), 10, join: OffsetJoin.miter);
      final xs = out.expand((s) => [s.p1.x, s.p2.x]);
      final ys = out.expand((s) => [s.p1.y, s.p2.y]);
      expect(xs.reduce(math.min), closeTo(10, 1e-6));
      expect(xs.reduce(math.max), closeTo(90, 1e-6));
      expect(ys.reduce(math.min), closeTo(10, 1e-6));
      expect(ys.reduce(math.max), closeTo(90, 1e-6));
    });

    test('result stays closed and continuous', () {
      final out = outset(square(100), 10);
      expect(_isClosed(out), isTrue);
      expect(_continuous(out), isTrue);
    });

    test('outset increases enclosed area, inset decreases it', () {
      final base = _area2(square(100)).abs();
      expect(_area2(outset(square(100), 10)).abs(), greaterThan(base));
      expect(_area2(inset(square(100), 10)).abs(), lessThan(base));
    });

    test('winding-independent: a clockwise square grows on outset too', () {
      final cw = square(100).reversed.map((s) => s.reversed()).toList();
      expect(_area2(cw), lessThan(0)); // opposite winding
      final out = outset(cw, 10, join: OffsetJoin.miter);
      final xs = out.expand((s) => [s.p1.x, s.p2.x]);
      expect(xs.reduce(math.min), closeTo(-10, 1e-6));
      expect(xs.reduce(math.max), closeTo(110, 1e-6));
    });

    test('round join inserts an arc at each convex corner on outset', () {
      final out = outset(square(100), 10, join: OffsetJoin.round);
      expect(out.whereType<CircularArcSegment>().length, 4);
      expect(_isClosed(out), isTrue);
      expect(_continuous(out), isTrue);
      // Every rounded corner point stays within delta of the original corner.
      for (final arc in out.whereType<CircularArcSegment>()) {
        expect(arc.radius, closeTo(10, 1e-6));
      }
    });

    test('bevel join inserts a chord at each convex corner on outset', () {
      final out = outset(square(100), 10, join: OffsetJoin.bevel);
      // 4 offset edges + 4 bevel chords.
      expect(out.length, 8);
      expect(out.every((s) => s is LineSegment), isTrue);
      expect(_isClosed(out), isTrue);
    });

    test('inset corners are trimmed (no extra connector segments)', () {
      final out = inset(square(100), 10, join: OffsetJoin.round);
      // Concave on inset → trim to intersection, so just the 4 edges remain.
      expect(out.length, 4);
      expect(_continuous(out), isTrue);
      expect(_isClosed(out), isTrue);
    });
  });

  group('circle (circular arcs)', () {
    // Full circle as two semicircular arcs, radius 50 about origin.
    List<Segment> circle(double r) => [
          CircularArcSegment(P(-r, 0), P(r, 0), r, clockwise: false),
          CircularArcSegment(P(r, 0), P(-r, 0), r, clockwise: false),
        ];

    test('outset yields concentric arcs of radius r + delta', () {
      final out = outset(circle(50), 10);
      expect(out.every((s) => s is CircularArcSegment), isTrue);
      for (final arc in out.whereType<CircularArcSegment>()) {
        expect(arc.radius, closeTo(60, 1e-6));
        expect(arc.center.isEqual(P(0, 0)), isTrue);
      }
    });

    test('inset yields concentric arcs of radius r - delta', () {
      final out = inset(circle(50), 10);
      for (final arc in out.whereType<CircularArcSegment>()) {
        expect(arc.radius, closeTo(40, 1e-6));
        expect(arc.center.isEqual(P(0, 0)), isTrue);
      }
    });
  });

  group('open path', () {
    test('a single line is shifted by delta along its normal', () {
      final out = insetOutset([LineSegment(P(0, 0), P(100, 0))], 10);
      expect(out.length, 1);
      expect(out.first, isA<LineSegment>());
      expect(out.first.p1.y.abs(), closeTo(10, 1e-6));
      expect(out.first.p2.y.abs(), closeTo(10, 1e-6));
      expect((out.first.p1.y - out.first.p2.y).abs(), closeTo(0, 1e-6));
    });

    test('open polyline keeps its endpoints offset and stays continuous', () {
      final out = insetOutset([
        LineSegment(P(0, 0), P(100, 0)),
        LineSegment(P(100, 0), P(100, 100)),
      ], 10, join: OffsetJoin.miter);
      expect(_continuous(out), isTrue);
      expect(_isClosed(out), isFalse);
    });
  });

  group('degenerate input', () {
    test('empty stays empty', () {
      expect(insetOutset(<Segment>[], 10), isEmpty);
    });

    test('zero delta returns the path unchanged', () {
      final sq = square(100);
      expect(insetOutset(sq, 0), equals(sq));
    });
  });
}
