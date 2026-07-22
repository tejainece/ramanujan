import 'package:ramanujan/ramanujan.dart';
import 'package:test/test.dart';

void main() {
  group('VectorPath length and trim', () {
    final line1 = LineSegment(const P(0, 0), const P(100, 0));
    final line2 = LineSegment(const P(100, 0), const P(100, 100));
    final openPath = VectorPath([line1, line2]);

    test('length computes total length correctly', () {
      expect(openPath.length, closeTo(200.0, 1e-6));
    });

    test('trim full open path returns original path', () {
      final trimmed = openPath.trim(0.0, 1.0);
      expect(trimmed.segments.length, equals(2));
      expect(trimmed.length, closeTo(200.0, 1e-6));
    });

    test('trim partial open path (0.0 to 0.5) slices first segment', () {
      final trimmed = openPath.trim(0.0, 0.5);
      expect(trimmed.length, closeTo(100.0, 1e-6));
      expect(trimmed.segments.first.p1, equals(const P(0, 0)));
      expect(trimmed.segments.first.p2, equals(const P(100, 0)));
    });

    test('trim middle of open path (0.25 to 0.75)', () {
      final trimmed = openPath.trim(0.25, 0.75);
      expect(trimmed.length, closeTo(100.0, 1e-6));
      expect(trimmed.segments.first.p1, equals(const P(50, 0)));
      expect(trimmed.segments.last.p2, equals(const P(100, 50)));
    });

    test('sliceByDistance slices path by absolute units', () {
      final sliced = openPath.sliceByDistance(50.0, 150.0);
      expect(sliced.length, closeTo(100.0, 1e-6));
      expect(sliced.segments.first.p1, equals(const P(50, 0)));
      expect(sliced.segments.last.p2, equals(const P(100, 50)));
    });

    test('trim closed loop rectangle', () {
      final rectPath = VectorPath(Segment.rect(const R(0, 0, 100, 100)));
      expect(rectPath.isClosed(), isTrue);
      expect(rectPath.length, closeTo(400.0, 1e-6));

      // Trim half of rectangle
      final trimmed = rectPath.trim(0.0, 0.5);
      expect(trimmed.length, closeTo(200.0, 1e-6));
      expect(trimmed.isClosed(), isFalse);
    });

    test('trim closed loop with offset wrap-around', () {
      final rectPath = VectorPath(Segment.rect(const R(0, 0, 100, 100)));

      // Trim 50% starting at offset 0.75 (300px to 500px -> 300..400 and 0..100)
      final trimmed = rectPath.trim(0.0, 0.5, offsetFraction: 0.75);
      expect(trimmed.length, closeTo(200.0, 1e-6));
    });

    test('trim with start >= end returns empty path', () {
      final trimmed = openPath.trim(0.5, 0.5);
      expect(trimmed.isEmpty, isTrue);
    });
  });
}
