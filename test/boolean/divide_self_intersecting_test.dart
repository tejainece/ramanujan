import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

// Shoelace area using segment endpoints. Positive = CCW in y-up.
double _area(VectorPath path) {
  var a = 0.0;
  for (final s in path.segments) {
    a += s.p1.x * s.p2.y - s.p2.x * s.p1.y;
  }
  return a / 2;
}

// A regular {n/2} star polygon at the given radius.
// Connects every other vertex of a regular n-gon.
VectorPath _star(int n, double r) {
  final verts = List.generate(n, (k) {
    final angle = pi / 2 + k * 2 * pi / n;
    return P(r * cos(angle), r * sin(angle));
  });
  final pts = List.generate(n, (k) => verts[(k * 2) % n]);
  return VectorPath(
    List.generate(n, (i) => LineSegment(pts[i], pts[(i + 1) % n])),
  );
}

// Bowtie: two triangles joined at a crossing in the middle.
// Path (0,0)→(200,200)→(0,200)→(200,0)→(0,0) crosses at (100,100).
VectorPath get _bowtie => VectorPath([
  LineSegment(P(0, 0), P(200, 200)),
  LineSegment(P(200, 200), P(0, 200)),
  LineSegment(P(0, 200), P(200, 0)),
  LineSegment(P(200, 0), P(0, 0)),
]);

void main() {
  group('divideSelfIntersecting', () {
    test('simple closed path with no crossings returns input unchanged', () {
      final path = VectorPath([
        LineSegment(P(0, 0), P(100, 0)),
        LineSegment(P(100, 0), P(50, 100)),
        LineSegment(P(50, 100), P(0, 0)),
      ]);
      final result = divideSelfIntersecting(path);
      expect(result, hasLength(1));
      expect(result.first.segments, equals(path.segments));
    });

    group('bowtie (two crossing diagonals)', () {
      late List<VectorPath> faces;
      setUp(() => faces = divideSelfIntersecting(_bowtie));

      test('produces exactly 2 faces', () => expect(faces, hasLength(2)));

      test('every face is a closed path', () {
        for (final f in faces) {
          expect(f.isClosed(), isTrue, reason: 'face is not closed');
        }
      });

      test('every face is CCW (positive area)', () {
        for (final f in faces) {
          expect(_area(f), greaterThan(0), reason: 'face is not CCW');
        }
      });

      test('every face is a triangle (3 segments)', () {
        for (final f in faces) {
          expect(f.numSegments, equals(3));
        }
      });

      test('face areas sum to the bowtie area', () {
        final total = faces.fold(0.0, (sum, f) => sum + _area(f));
        // Bowtie has two triangles each with area 10000 (base 200 * height 100 / 2)
        expect(total, closeTo(20000, 1));
      });
    });

    group('5-pointed star', () {
      late List<VectorPath> faces;
      setUp(() => faces = divideSelfIntersecting(_star(5, 100)));

      test('produces exactly 6 faces (5 tips + 1 pentagon)', () {
        expect(faces, hasLength(6));
      });

      test('every face is closed and CCW', () {
        for (final f in faces) {
          expect(f.isClosed(), isTrue);
          expect(_area(f), greaterThan(0));
        }
      });

      test(
        'exactly one pentagon (5 segments) and five triangles (3 segments)',
        () {
          final segCounts = faces.map((f) => f.numSegments).toList()..sort();
          expect(segCounts, equals([3, 3, 3, 3, 3, 5]));
        },
      );
    });

    group('vertex-on-edge figure-8', () {
      // seg3 passes through (0,0) at t=0.5, which is also the shared endpoint
      // of seg0 (t=0) and seg6 (t=1) — a vertex-on-edge crossing.
      final path = VectorPath([
        LineSegment(P(0, 0), P(-100, 120)),
        LineSegment(P(-100, 120), P(-200, 0)),
        LineSegment(P(-200, 0), P(-100, -120)),
        LineSegment(P(-100, -120), P(100, 120)), // crosses (0,0) at t=0.5
        LineSegment(P(100, 120), P(200, 0)),
        LineSegment(P(200, 0), P(100, -120)),
        LineSegment(P(100, -120), P(0, 0)),
      ]);
      late List<VectorPath> faces;
      setUp(() => faces = divideSelfIntersecting(path));

      test('produces exactly 2 faces', () => expect(faces, hasLength(2)));

      test('every face is closed and CCW', () {
        for (final f in faces) {
          expect(f.isClosed(), isTrue);
          expect(_area(f), greaterThan(0));
        }
      });
    });

    test('non-self-intersecting closed lens returns input unchanged', () {
      // Two cubics forming a symmetric lens — no interior crossing.
      final lens = VectorPath([
        CubicSegment(
          p1: P(-100, 0),
          c1: P(-50, 150),
          c2: P(50, 150),
          p2: P(100, 0),
        ),
        CubicSegment(
          p1: P(100, 0),
          c1: P(50, -150),
          c2: P(-50, -150),
          p2: P(-100, 0),
        ),
      ]);
      expect(divideSelfIntersecting(lens), hasLength(1));
    });

    group('X-crossing (4 line segments, two diagonals crossing at origin)', () {
      // Rectangular frame where opposite corners are connected diagonally.
      // seg0 and seg2 cross transversally at (0,0).
      final xPath = VectorPath([
        LineSegment(P(-150, -100), P(150, 100)),
        LineSegment(P(150, 100), P(150, -100)),
        LineSegment(P(150, -100), P(-150, 100)),
        LineSegment(P(-150, 100), P(-150, -100)),
      ]);
      late List<VectorPath> faces;
      setUp(() => faces = divideSelfIntersecting(xPath));

      test('produces exactly 2 faces', () => expect(faces, hasLength(2)));

      test('every face is closed and CCW', () {
        for (final f in faces) {
          expect(f.isClosed(), isTrue);
          expect(_area(f), greaterThan(0));
        }
      });
    });
  });
}
