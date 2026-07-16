import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

Loop _circleLoop(P c, double r) => Loop([
  CircularArcSegment(P(c.x + r, c.y), P(c.x, c.y + r), r, clockwise: false),
  CircularArcSegment(P(c.x, c.y + r), P(c.x - r, c.y), r, clockwise: false),
  CircularArcSegment(P(c.x - r, c.y), P(c.x, c.y - r), r, clockwise: false),
  CircularArcSegment(P(c.x, c.y - r), P(c.x + r, c.y), r, clockwise: false),
]);

Region _circle(P c, double r) => Region([_circleLoop(c, r)]);
Region _annulus(P c, double outerR, double innerR) =>
    Region([_circleLoop(c, outerR), _circleLoop(c, innerR)]);

Region _rect(double x, double y, double w, double h) => Region([
  Loop([
    LineSegment(P(x, y), P(x + w, y)),
    LineSegment(P(x + w, y), P(x + w, y + h)),
    LineSegment(P(x + w, y + h), P(x, y + h)),
    LineSegment(P(x, y + h), P(x, y)),
  ]),
]);

double _area(VectorPath path) {
  var a = 0.0;
  for (final s in path.segments) {
    a += s.p1.x * s.p2.y - s.p2.x * s.p1.y;
  }
  return a / 2;
}

double _totalArea(Region region) =>
    region.loops.map(_area).fold(0.0, (a, b) => a + b);

// A=[0,0,100,100]  B=[50,50,100,100] — diagonal overlap, no coincident edges.
final _a = _rect(0, 0, 100, 100);
final _b = _rect(50, 50, 100, 100);

void main() {
  group('PathUnion', () {
    const op = PathUnion();

    test('union of overlapping rects is one ring', () {
      final result = op.compute(_a, _b);
      expect(result.loops, hasLength(1));
    });

    test('union area = sum minus overlap (17500)', () {
      final result = op.compute(_a, _b);
      expect(_totalArea(result), closeTo(17500, 1));
    });

    test('union of non-overlapping rects is two rings', () {
      final result = op.compute(_rect(0, 0, 100, 100), _rect(200, 0, 100, 100));
      expect(result.loops, hasLength(2));
      expect(_totalArea(result), closeTo(20000, 1));
    });

    test('union result rings are closed', () {
      for (final ring in op.compute(_a, _b).loops) {
        expect(ring.isClosed(), isTrue);
      }
    });
  });

  group('PathIntersection', () {
    const op = PathIntersection();

    test('intersection of overlapping rects is one ring', () {
      final result = op.compute(_a, _b);
      expect(result.loops, hasLength(1));
    });

    test('intersection area = overlap (2500)', () {
      final result = op.compute(_a, _b);
      expect(_totalArea(result), closeTo(2500, 1));
    });

    test('intersection of non-overlapping rects is empty', () {
      final result = op.compute(_rect(0, 0, 100, 100), _rect(200, 0, 100, 100));
      expect(result.loops, isEmpty);
    });

    test('intersection result rings are closed', () {
      for (final ring in op.compute(_a, _b).loops) {
        expect(ring.isClosed(), isTrue);
      }
    });
  });

  group('PathDifference', () {
    const op = PathDifference();

    test('A minus B is one ring', () {
      final result = op.compute(_a, _b);
      expect(result.loops, hasLength(1));
    });

    test('A minus B area = A area minus overlap (7500)', () {
      final result = op.compute(_a, _b);
      expect(_totalArea(result), closeTo(7500, 1));
    });

    test('non-overlapping A minus B returns A unchanged', () {
      final result = op.compute(_rect(0, 0, 100, 100), _rect(200, 0, 100, 100));
      expect(result.loops, hasLength(1));
      expect(_totalArea(result), closeTo(10000, 1));
    });

    test('difference result rings are closed', () {
      for (final ring in op.compute(_a, _b).loops) {
        expect(ring.isClosed(), isTrue);
      }
    });
  });

  group('PathXor', () {
    const op = PathXor();

    test('xor of overlapping rects is two rings', () {
      final result = op.compute(_a, _b);
      expect(result.loops, hasLength(2));
    });

    test('xor total area = both areas minus twice overlap (15000)', () {
      final result = op.compute(_a, _b);
      expect(_totalArea(result), closeTo(15000, 1));
    });

    test('xor of non-overlapping rects is two rings', () {
      final result = op.compute(_rect(0, 0, 100, 100), _rect(200, 0, 100, 100));
      expect(result.loops, hasLength(2));
      expect(_totalArea(result), closeTo(20000, 1));
    });

    test('xor result rings are closed', () {
      for (final ring in op.compute(_a, _b).loops) {
        expect(ring.isClosed(), isTrue);
      }
    });
  });

  group('PathDivision', () {
    const op = PathDivision();

    test(
      'division of overlapping rects splits A into 2 pieces (intersection and difference)',
      () {
        final result = op.compute(_a, _b);
        expect(result.loops, hasLength(2));
      },
    );

    test('division area equals total A area (10000)', () {
      final result = op.compute(_a, _b);
      expect(_totalArea(result), closeTo(10000, 1));
    });

    test('division of non-overlapping rects returns A unchanged', () {
      final result = op.compute(_rect(0, 0, 100, 100), _rect(200, 0, 100, 100));
      expect(result.loops, hasLength(1));
      expect(_totalArea(result), closeTo(10000, 1));
    });

    test('division result rings are closed', () {
      for (final ring in op.compute(_a, _b).loops) {
        expect(ring.isClosed(), isTrue);
      }
    });
  });

  group('PathFracture', () {
    const op = PathFracture();

    test(
      'fracture of overlapping rects splits into 3 pieces (A-B, B-A, and intersection)',
      () {
        final result = op.compute(_a, _b);
        // A-B is 1, B-A is 1, intersection is 1, total = 3 rings
        expect(result.loops, hasLength(3));
      },
    );

    test('fracture area equals union area (17500)', () {
      final result = op.compute(_a, _b);
      expect(_totalArea(result), closeTo(17500, 1));
    });

    test('fracture of non-overlapping rects returns both A and B', () {
      final result = op.compute(_rect(0, 0, 100, 100), _rect(200, 0, 100, 100));
      expect(result.loops, hasLength(2));
      expect(_totalArea(result), closeTo(20000, 1));
    });

    test('fracture result rings are closed', () {
      for (final ring in op.compute(_a, _b).loops) {
        expect(ring.isClosed(), isTrue);
      }
    });
  });

  group('PathFlatten', () {
    const op = PathFlatten();

    test('flatten of overlapping rects splits into 2 pieces (B and A-B)', () {
      final result = op.compute(_a, _b);
      expect(result.loops, hasLength(2));
    });

    test('flatten area equals union area (17500)', () {
      final result = op.compute(_a, _b);
      expect(_totalArea(result), closeTo(17500, 1));
    });

    test('flatten of non-overlapping rects returns both A and B', () {
      final result = op.compute(_rect(0, 0, 100, 100), _rect(200, 0, 100, 100));
      expect(result.loops, hasLength(2));
      expect(_totalArea(result), closeTo(20000, 1));
    });

    test('flatten result rings are closed', () {
      for (final ring in op.compute(_a, _b).loops) {
        expect(ring.isClosed(), isTrue);
      }
    });
  });

  group('arc-based operations', () {
    test('union of two overlapping circles is non-empty', () {
      final result = const PathUnion().compute(
        _circle(P(0, 0), 60),
        _circle(P(50, 0), 60),
      );
      expect(result.loops, isNotEmpty);
    });

    test('intersection of two overlapping circles is non-empty', () {
      final result = const PathIntersection().compute(
        _circle(P(0, 0), 60),
        _circle(P(50, 0), 60),
      );
      expect(result.loops, isNotEmpty);
    });

    test('intersection of two annuli is non-empty', () {
      final result = const PathIntersection().compute(
        _annulus(P(-50, 0), 120, 55),
        _annulus(P(50, 0), 120, 55),
      );
      expect(result.loops, isNotEmpty);
    });

    test('union of two annuli is non-empty', () {
      final result = const PathUnion().compute(
        _annulus(P(-50, 0), 120, 55),
        _annulus(P(50, 0), 120, 55),
      );
      expect(result.loops, isNotEmpty);
    });

    test('arc result rings are all closed', () {
      for (final op in <PathBoolean>[
        const PathUnion(),
        const PathIntersection(),
        const PathDifference(),
        const PathXor(),
        const PathDivision(),
        const PathFracture(),
        const PathFlatten(),
      ]) {
        final result = op.compute(_circle(P(0, 0), 80), _circle(P(60, 0), 80));
        for (final ring in result.loops) {
          expect(
            ring.isClosed(),
            isTrue,
            reason: '${op.runtimeType} ring is not closed',
          );
        }
      }
    });
  });

  group('Region.separateDisconnected', () {
    test(
      'separateDisconnected of disconnected rects splits into separate regions',
      () {
        final region = Region([
          ..._rect(0, 0, 100, 100).loops,
          ..._rect(200, 0, 100, 100).loops,
        ]);
        final pieces = region.separateDisconnected();
        expect(pieces, hasLength(2));
        expect(
          _totalArea(pieces[0]) + _totalArea(pieces[1]),
          closeTo(20000, 1),
        );
      },
    );

    test('separateDisconnected of donut preserves the donut as one region', () {
      final donut = _annulus(P(0, 0), 100, 50);
      final pieces = donut.separateDisconnected();
      expect(pieces, hasLength(1));
      expect(pieces[0].loops, hasLength(2));
    });

    test(
      'separateDisconnected of donut with island splits into two regions',
      () {
        final donut = _annulus(P(0, 0), 100, 50);
        final island = _circle(P(0, 0), 20);
        final combined = Region([...donut.loops, ...island.loops]);
        final pieces = combined.separateDisconnected();
        expect(pieces, hasLength(2));
        final loopCounts = pieces.map((p) => p.loops.length).toList()..sort();
        expect(loopCounts, equals([1, 2]));
      },
    );

    test(
      'separateDisconnected of overlapping annuli flatten result decomposes correctly',
      () {
        final a = _annulus(P(-50, 0), 120, 55);
        final b = _annulus(P(50, 0), 120, 55);
        final result = const PathFlatten().compute(a, b);
        final pieces = result.separateDisconnected();
        expect(pieces, hasLength(3));
      },
    );
  });
}
