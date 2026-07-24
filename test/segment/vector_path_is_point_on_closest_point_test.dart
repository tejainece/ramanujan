import 'package:ramanujan/ramanujan.dart';
import 'package:test/test.dart';

void main() {
  group('VectorPath.isPointOn', () {
    final line1 = LineSegment(const P(0, 0), const P(100, 0));
    final line2 = LineSegment(const P(100, 0), const P(100, 100));
    final path = VectorPath([line1, line2]);

    test('point on the first segment', () {
      expect(path.isPointOn(const P(50, 0)), isTrue);
    });

    test('point on the second segment', () {
      expect(path.isPointOn(const P(100, 50)), isTrue);
    });

    test('point on neither segment', () {
      expect(path.isPointOn(const P(50, 50)), isFalse);
    });

    test('empty path has no points on it', () {
      expect(VectorPath(const []).isPointOn(const P(0, 0)), isFalse);
    });
  });

  group('VectorPath.closestPoint', () {
    final line1 = LineSegment(const P(0, 0), const P(100, 0));
    final line2 = LineSegment(const P(100, 0), const P(100, 100));
    final path = VectorPath([line1, line2]);

    test('closest point on the first segment', () {
      final result = path.closestPoint(const P(50, 10));
      expect(result, isNotNull);
      expect(result!.segment, same(line1));
      expect(result.point, equals(const P(50, 0)));
      expect(result.t, closeTo(0.5, 1e-9));
    });

    test('closest point on the second segment', () {
      final result = path.closestPoint(const P(110, 50));
      expect(result, isNotNull);
      expect(result!.segment, same(line2));
      expect(result.point, equals(const P(100, 50)));
      expect(result.t, closeTo(0.5, 1e-9));
    });

    test('shared endpoint is equally close from either side', () {
      final result = path.closestPoint(const P(100, 0));
      expect(result, isNotNull);
      expect(result!.point, equals(const P(100, 0)));
    });

    test('empty path returns null', () {
      expect(VectorPath(const []).closestPoint(const P(0, 0)), isNull);
    });
  });
}