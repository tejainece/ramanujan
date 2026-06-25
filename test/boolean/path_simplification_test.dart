import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

double _area(VectorPath path) {
  var a = 0.0;
  for (final s in path.segments) {
    a += s.p1.x * s.p2.y - s.p2.x * s.p1.y;
  }
  return a / 2;
}

void main() {
  group('simplifyClosedPath', () {
    test('empty path returns empty list', () {
      expect(simplifyClosedPath(VectorPath([])), isEmpty);
    });

    test('already-closed simple triangle passes through unchanged', () {
      final triangle = VectorPath([
        LineSegment(P(0, 0), P(100, 0)),
        LineSegment(P(100, 0), P(50, 100)),
        LineSegment(P(50, 100), P(0, 0)),
      ]);
      final result = simplifyClosedPath(triangle);
      expect(result, hasLength(1));
      expect(result.first.segments, equals(triangle.segments));
    });

    test('open path is force-closed with a straight segment', () {
      final open = VectorPath([
        LineSegment(P(0, 0), P(100, 0)),
        LineSegment(P(100, 0), P(50, 100)),
      ]);
      final result = simplifyClosedPath(open);
      expect(result, hasLength(1));
      final face = result.first;
      expect(face.isClosed(), isTrue);
      expect(face.numSegments, equals(3));
      expect(_area(face), greaterThan(0));
    });

    test('nearly-closed path snaps endpoints without adding a new segment', () {
      const gap = 5e-4; // within default snapEpsilon of 1e-3
      final nearlyClose = VectorPath([
        LineSegment(P(0, 0), P(100, 0)),
        LineSegment(P(100, 0), P(50, 100)),
        LineSegment(P(50, 100), P(gap, gap)),
      ]);
      final result = simplifyClosedPath(nearlyClose);
      expect(result, hasLength(1));
      expect(result.first.numSegments, equals(3)); // no extra segment added
      expect(result.first.isClosed(), isTrue);
    });

    test('self-intersecting bowtie is decomposed into two triangles', () {
      final bowtie = VectorPath([
        LineSegment(P(0, 0), P(200, 200)),
        LineSegment(P(200, 200), P(0, 200)),
        LineSegment(P(0, 200), P(200, 0)),
        LineSegment(P(200, 0), P(0, 0)),
      ]);
      final result = simplifyClosedPath(bowtie);
      expect(result, hasLength(2));
      for (final face in result) {
        expect(face.isClosed(), isTrue);
        expect(_area(face), greaterThan(0));
      }
    });

    test('open lollipop: triangle loop + dangling tail — tail is dropped', () {
      // A→B→C→A closes the triangle; A→D is the dangling tail.
      // simplifyClosedPath force-closes by adding D→A, then the spike is
      // dropped by the zero-area filter inside divideSelfIntersecting.
      final lollipop = VectorPath([
        LineSegment(P(0, 0), P(100, 0)),   // A→B
        LineSegment(P(100, 0), P(50, 100)), // B→C
        LineSegment(P(50, 100), P(0, 0)),   // C→A
        LineSegment(P(0, 0), P(-50, 50)),   // A→D (dangling tail)
      ]);
      final result = simplifyClosedPath(lollipop);
      expect(result, hasLength(1));
      expect(result.first.isClosed(), isTrue);
      expect(_area(result.first), closeTo(5000, 1));
    });
  });
}
