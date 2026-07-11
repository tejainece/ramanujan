import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  group('Polygon.fromVectorPath', () {
    test('round-trips a regular pentagon', () {
      final polygon = Polygon(center: P(10, 20), radii: P(30, 30), sides: 5);
      final recovered = Polygon.fromVectorPath(polygon.toLoop());

      expect(recovered, isNotNull);
      expect(recovered!.center.isEqual(polygon.center), isTrue);
      expect(recovered.radii.isEqual(polygon.radii), isTrue);
      expect(recovered.sides, equals(5));
    });

    test('round-trips a polygon stretched to fit a non-square rect', () {
      final polygon = Polygon(center: P(-5, 8), radii: P(40, 15), sides: 7);
      final recovered = Polygon.fromVectorPath(polygon.toLoop());

      expect(recovered, isNotNull);
      expect(recovered!.center.isEqual(polygon.center), isTrue);
      expect(recovered.radii.isEqual(polygon.radii), isTrue);
      expect(recovered.sides, equals(7));
    });

    test('returns null for an axis-aligned rectangle', () {
      final rect = R(0, 0, 100, 50);
      final loop = Loop(Segment.rect(rect));

      expect(Polygon.fromVectorPath(loop), isNull);
    });

    test('returns null for a non-closed path', () {
      final path = VectorPath([
        LineSegment(P(0, 0), P(10, 0)),
        LineSegment(P(10, 0), P(10, 10)),
      ]);

      expect(Polygon.fromVectorPath(path), isNull);
    });
  });

  group('Polygon.toLoop', () {
    test('produces `sides` vertices at the expected radii', () {
      final polygon = Polygon(center: P(0, 0), radii: P(10, 5), sides: 4);
      final loop = polygon.toLoop();

      expect(loop.segments.length, equals(4));
      // First vertex points straight up.
      expect(polygon.vertex(0).isEqual(P(0, -5)), isTrue);
    });
  });

  group('Polygon.containsPoint', () {
    test('center is inside, far outside point is not', () {
      final polygon = Polygon(center: P(0, 0), radii: P(20, 20), sides: 6);
      expect(polygon.containsPoint(P(0, 0)), isTrue);
      expect(polygon.containsPoint(P(1000, 1000)), isFalse);
    });
  });
}