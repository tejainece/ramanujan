import 'dart:math';

import 'package:ramanujan/ramanujan.dart';
import 'package:test/test.dart';

/// Every consecutive pair of segments connects, and for a closed result the
/// last connects back to the first.
void expectConnected(List<Segment> segments, {bool closed = false}) {
  for (int i = 0; i + 1 < segments.length; i++) {
    expect(
      segments[i].p2.distanceTo(segments[i + 1].p1),
      closeTo(0, 1e-6),
      reason: 'segments $i and ${i + 1} do not connect',
    );
  }
  if (closed) {
    expect(
      segments.last.p2.distanceTo(segments.first.p1),
      closeTo(0, 1e-6),
      reason: 'last segment does not connect back to the first',
    );
  }
}

Loop rectangle(double width, double height) => Loop([
  LineSegment(P(0, 0), P(width, 0)),
  LineSegment(P(width, 0), P(width, height)),
  LineSegment(P(width, height), P(0, height)),
  LineSegment(P(0, height), P(0, 0)),
]);

Loop square(double side) => rectangle(side, side);

void main() {
  group('roundAllCorners on a closed path', () {
    test('rounds every corner of a square, alternating trimmed sides and '
        'fillets', () {
      final result = roundAllCorners(
        square(100),
        CornerStyle.chamfer,
        radius: 10,
      );
      expect(result, isA<Loop>());
      expect(result.numSegments, 8);
      expectConnected(result.segments, closed: true);
      for (int i = 0; i < 8; i++) {
        // Even slots are the trimmed sides (100 - 10 - 10), odd slots the
        // 45-degree chamfers bridging cuts 10 back on each side.
        expect(
          result.segments[i].length,
          closeTo(i.isEven ? 80 : sqrt(200), 1e-6),
        );
      }
    });

    test('circular-arc fillets on a square have the requested radius', () {
      final result = roundAllCorners(
        square(100),
        CornerStyle.circularArc,
        radius: 10,
      );
      expect(result.numSegments, 8);
      expectConnected(result.segments, closed: true);
      for (int i = 1; i < 8; i += 2) {
        final arc = result.segments[i];
        expect(arc, isA<CircularArcSegment>());
        expect((arc as CircularArcSegment).radius, closeTo(10, 1e-6));
      }
    });

    test('every style produces a connected closed result on a square', () {
      for (final style in CornerStyle.values) {
        final result = roundAllCorners(square(100), style, radius: 10);
        expect(result, isA<Loop>(), reason: '$style');
        expect(result.numSegments, 8, reason: '$style');
        expectConnected(result.segments, closed: true);
      }
    });
  });

  group('cross-corner radius clamping', () {
    test('two corners sharing a short edge split it proportionally, scaling '
        'each corner as a whole', () {
      // 100x10 rectangle, chamfer radius 20: each short edge is demanded
      // 10 + 10 = 20 > 10, so both corners scale by 0.5 -- cutting 10 along
      // the long sides and 5 along the short ones. The short edges are
      // consumed exactly and drop out of the output.
      final result = roundAllCorners(
        rectangle(100, 10),
        CornerStyle.chamfer,
        radius: 20,
      );
      expect(result, isA<Loop>());
      expect(result.numSegments, 6);
      expectConnected(result.segments, closed: true);
      final lengths = result.segments.map((s) => s.length).toList();
      expect(
        lengths.where((l) => (l - 80).abs() < 1e-6).length,
        2,
        reason: 'two long sides trimmed to 100 - 10 - 10',
      );
      expect(
        lengths.where((l) => (l - sqrt(125)).abs() < 1e-6).length,
        4,
        reason: 'four chamfers spanning cuts of 10 and 5',
      );
    });

    test('averaging styles budget their averaged radius, landing on the '
        'half-edge cap', () {
      // Square of side 10, circular arc radius 100: per-side caps bring each
      // corner to an averaged demand of 10, each edge is oversubscribed
      // 20 > 10, and everything scales to the classic half-edge radius of 5.
      // All four edges are consumed whole: only the four arcs remain.
      final result = roundAllCorners(
        square(10),
        CornerStyle.circularArc,
        radius: 100,
      );
      expect(result, isA<Loop>());
      expect(result.numSegments, 4);
      expectConnected(result.segments, closed: true);
      for (final segment in result.segments) {
        expect(segment, isA<CircularArcSegment>());
        expect((segment as CircularArcSegment).radius, closeTo(5, 1e-6));
      }
    });

    test('without traversal an oversized radius clamps at the adjacent '
        'segment', () {
      // L-shaped open path; the corner's radius exceeds the 30-long incoming
      // segment, so the cut saturates at that segment's start instead of
      // continuing into the segment before it.
      final path = VectorPath([
        LineSegment(P(0, 0), P(70, 0)),
        LineSegment(P(70, 0), P(100, 0)),
        LineSegment(P(100, 0), P(100, 100)),
      ]);
      // Junction 0 is smooth (collinear) and skipped; junction 1 is the
      // corner.
      final result = roundAllCorners(path, CornerStyle.chamfer, radius: 50);
      expectConnected(result.segments);
      expect(result.segments.first.p1, P(0, 0));
      // The cut along the incoming side stops at (70, 0) -- the full second
      // segment -- rather than reaching arc length 50 back at (50, 0).
      final fillet = result.segments.firstWhere(
        (s) => s is LineSegment && (s.p2 - s.p1).x != 0 && (s.p2 - s.p1).y != 0,
      );
      expect(fillet.p1.distanceTo(P(70, 0)), closeTo(0, 1e-6));
      expect(fillet.p2.distanceTo(P(100, 50)), closeTo(0, 1e-6));
    });
  });

  group('traversal across segments (traverseSegments: true)', () {
    test(
      'a cut continues across a smooth junction into the segment beyond',
      () {
        final path = VectorPath([
          LineSegment(P(0, 0), P(50, 0)),
          LineSegment(P(50, 0), P(60, 0)),
          LineSegment(P(60, 0), P(60, 100)),
        ]);
        final result = roundAllCorners(
          path,
          CornerStyle.chamfer,
          radius: 30,
          traverseSegments: true,
        );
        // The 10-long middle segment is consumed whole; the fillet runs from
        // (30, 0) -- 30 of arc length back through the smooth junction -- up to
        // (60, 30).
        expect(result.numSegments, 3);
        expectConnected(result.segments);
        expect(result.segments[0].p1, P(0, 0));
        expect(result.segments[0].p2.distanceTo(P(30, 0)), closeTo(0, 1e-6));
        expect(result.segments[1].p2.distanceTo(P(60, 30)), closeTo(0, 1e-6));
        expect(result.segments[2].p2, P(60, 100));
      },
    );

    test('a cut swallows an un-rounded sharp corner whole', () {
      final path = VectorPath([
        LineSegment(P(0, 0), P(100, 0)),
        LineSegment(P(100, 0), P(100, 20)),
        LineSegment(P(100, 20), P(0, 20)),
      ]);
      // Only junction 1 is rounded; its incoming cut of 50 walks back through
      // the sharp corner at (100, 0), erasing it.
      final result = roundAllCorners(
        path,
        CornerStyle.chamfer,
        radii: [0, 50],
        traverseSegments: true,
      );
      expect(result.numSegments, 3);
      expectConnected(result.segments);
      expect(result.segments[0].p2.distanceTo(P(70, 0)), closeTo(0, 1e-6));
      expect(result.segments[1].p2.distanceTo(P(50, 20)), closeTo(0, 1e-6));
      expect(result.segments[2].p2, P(0, 20));
    });

    test('adjacent rounded corners still cap each other: a cut never crosses '
        'a rounded corner', () {
      // Both corners rounded with a radius that would traverse: each cut is
      // capped by the shared 20-long vertical edge instead (10 each), and
      // the long sides are only cut by their own corner's share.
      final path = VectorPath([
        LineSegment(P(0, 0), P(100, 0)),
        LineSegment(P(100, 0), P(100, 20)),
        LineSegment(P(100, 20), P(0, 20)),
      ]);
      final result = roundAllCorners(
        path,
        CornerStyle.chamfer,
        radius: 200,
        traverseSegments: true,
      );
      expectConnected(result.segments);
      // Corner radii: capped per side at min(200, 100) = 100 on the long
      // sides and min(200, 20) = 20 on the shared edge; the shared edge's
      // 20 + 20 = 40 > 20 scales both corners by 0.5 -> cuts of 50 and 10.
      expect(result.numSegments, 4);
      expect(result.segments[0].p2.distanceTo(P(50, 0)), closeTo(0, 1e-6));
      expect(result.segments[1].p2.distanceTo(P(100, 10)), closeTo(0, 1e-6));
      expect(result.segments[2].p2.distanceTo(P(50, 20)), closeTo(0, 1e-6));
    });

    test('a closed path with a single rounded corner wraps the whole loop as '
        'one stretch', () {
      final result = roundAllCorners(
        square(100),
        CornerStyle.chamfer,
        radii: [30, 0, 0, 0],
        traverseSegments: true,
      );
      expect(result, isA<Loop>());
      expect(result.numSegments, 5);
      expectConnected(result.segments, closed: true);
      // The rounded junction is at (100, 0): cut 30 back along segment 0 and
      // 30 up segment 1; the other three vertices survive untouched.
      final fillet = result.segments.firstWhere(
        (s) => s is LineSegment && (s.p2 - s.p1).x != 0 && (s.p2 - s.p1).y != 0,
      );
      expect(fillet.p1.distanceTo(P(70, 0)), closeTo(0, 1e-6));
      expect(fillet.p2.distanceTo(P(100, 30)), closeTo(0, 1e-6));
      final points = result.segments.expand((s) => [s.p1, s.p2]);
      for (final vertex in [P(100, 100), P(0, 100), P(0, 0)]) {
        expect(
          points.where((p) => p.isEqual(vertex, 1e-6)).length,
          2,
          reason: 'un-rounded vertex $vertex must survive',
        );
      }
    });
  });

  group('per-vertex radii', () {
    test('zero entries leave their corners sharp', () {
      final result = roundAllCorners(
        square(100),
        CornerStyle.chamfer,
        radii: [10, 0, 10, 0],
      );
      expect(result, isA<Loop>());
      expect(result.numSegments, 6);
      expectConnected(result.segments, closed: true);
      final points = result.segments.expand((s) => [s.p1, s.p2]);
      // Junctions 1 (at (100, 100)) and 3 (the wrap, at (0, 0)) stay sharp.
      for (final vertex in [P(100, 100), P(0, 0)]) {
        expect(
          points.where((p) => p.isEqual(vertex, 1e-6)).length,
          2,
          reason: 'un-rounded vertex $vertex must survive',
        );
      }
    });

    test('different radii per corner are honoured', () {
      final result = roundAllCorners(
        square(100),
        CornerStyle.chamfer,
        radii: [10, 20, 30, 40],
      );
      expect(result.numSegments, 8);
      expectConnected(result.segments, closed: true);
      // Side k of the square is cut by radii[k-1] at its start and radii[k]
      // at its end; sides are the even slots starting with side 0.
      expect(result.segments[0].length, closeTo(100 - 40 - 10, 1e-6));
      expect(result.segments[2].length, closeTo(100 - 10 - 20, 1e-6));
      expect(result.segments[4].length, closeTo(100 - 20 - 30, 1e-6));
      expect(result.segments[6].length, closeTo(100 - 30 - 40, 1e-6));
    });
  });

  group('argument validation and degenerate inputs', () {
    test('requires exactly one of radius or radii', () {
      expect(
        () => roundAllCorners(square(10), CornerStyle.chamfer),
        throwsArgumentError,
      );
      expect(
        () => roundAllCorners(
          square(10),
          CornerStyle.chamfer,
          radius: 1,
          radii: [1, 1, 1, 1],
        ),
        throwsArgumentError,
      );
    });

    test('requires one radius per junction', () {
      expect(
        () =>
            roundAllCorners(square(10), CornerStyle.chamfer, radii: [1, 1, 1]),
        throwsArgumentError,
      );
      // An open path has one junction fewer than it has segments.
      final open = VectorPath([
        LineSegment(P(0, 0), P(10, 0)),
        LineSegment(P(10, 0), P(10, 10)),
      ]);
      expect(
        () => roundAllCorners(open, CornerStyle.chamfer, radii: [1, 1]),
        throwsArgumentError,
      );
    });

    test('a path with only smooth junctions is returned unchanged', () {
      final path = VectorPath([
        LineSegment(P(0, 0), P(10, 0)),
        LineSegment(P(10, 0), P(20, 0)),
      ]);
      final result = roundAllCorners(path, CornerStyle.chamfer, radius: 5);
      expect(result.numSegments, 2);
      expect(result.segments[0].p2, P(10, 0));
    });

    test('an all-zero radii list is a no-op', () {
      final result = roundAllCorners(
        square(10),
        CornerStyle.circularArc,
        radii: [0, 0, 0, 0],
      );
      expect(result.numSegments, 4);
    });

    test('open path endpoints are never moved', () {
      final path = VectorPath([
        LineSegment(P(0, 0), P(10, 0)),
        LineSegment(P(10, 0), P(10, 10)),
      ]);
      final result = roundAllCorners(path, CornerStyle.circularArc, radius: 4);
      expect(result, isNot(isA<Loop>()));
      expect(result.segments.first.p1, P(0, 0));
      expect(result.segments.last.p2, P(10, 10));
      expect(result.numSegments, 3);
      expectConnected(result.segments);
    });
  });
}
