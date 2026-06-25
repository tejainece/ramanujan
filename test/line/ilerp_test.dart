import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  group('LineSegment.ilerp', () {
    test('diagonal — p1 gives 0, p2 gives 1, midpoint gives 0.5', () {
      final s = LineSegment(P(0, 0), P(100, 100));
      expect(s.ilerp(P(0, 0)), closeTo(0.0, 1e-9));
      expect(s.ilerp(P(100, 100)), closeTo(1.0, 1e-9));
      expect(s.ilerp(P(50, 50)), closeTo(0.5, 1e-9));
    });

    test('horizontal — uses x axis', () {
      final s = LineSegment(P(10, 5), P(110, 5));
      expect(s.ilerp(P(10, 5)), closeTo(0.0, 1e-9));
      expect(s.ilerp(P(110, 5)), closeTo(1.0, 1e-9));
      expect(s.ilerp(P(60, 5)), closeTo(0.5, 1e-9));
      expect(s.ilerp(P(35, 5)), closeTo(0.25, 1e-9));
    });

    test('vertical — uses y axis (not x, which would divide by zero)', () {
      final s = LineSegment(P(7, 0), P(7, 200));
      expect(s.ilerp(P(7, 0)), closeTo(0.0, 1e-9));
      expect(s.ilerp(P(7, 200)), closeTo(1.0, 1e-9));
      expect(s.ilerp(P(7, 100)), closeTo(0.5, 1e-9));
      expect(s.ilerp(P(7, 50)), closeTo(0.25, 1e-9));
    });

    test('near-vertical — dominant axis is y', () {
      final s = LineSegment(P(0, 0), P(1, 100));
      expect(s.ilerp(P(0.5, 50)), closeTo(0.5, 1e-9));
    });

    test('reversed segment — t=0 at p1, t=1 at p2', () {
      final s = LineSegment(P(100, 50), P(0, 50));
      expect(s.ilerp(P(100, 50)), closeTo(0.0, 1e-9));
      expect(s.ilerp(P(0, 50)), closeTo(1.0, 1e-9));
      expect(s.ilerp(P(50, 50)), closeTo(0.5, 1e-9));
    });

    test('vertical reversed — p1 at top, p2 at bottom', () {
      final s = LineSegment(P(3, 100), P(3, 0));
      expect(s.ilerp(P(3, 100)), closeTo(0.0, 1e-9));
      expect(s.ilerp(P(3, 0)), closeTo(1.0, 1e-9));
      expect(s.ilerp(P(3, 50)), closeTo(0.5, 1e-9));
    });

    test('ilerp is inverse of lerp for several t values', () {
      for (final seg in [
        LineSegment(P(0, 0), P(100, 0)),   // horizontal
        LineSegment(P(0, 0), P(0, 100)),   // vertical
        LineSegment(P(0, 0), P(60, 80)),   // diagonal
        LineSegment(P(50, 200), P(50, 0)), // vertical reversed
      ]) {
        for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          expect(seg.ilerp(seg.lerp(t)), closeTo(t, 1e-9),
              reason: 'ilerp(lerp($t)) != $t for $seg');
        }
      }
    });
  });
}
