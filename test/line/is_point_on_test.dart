import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  group('LineSegment.isPointOn', () {
    test('diagonal — endpoints and midpoint are on segment', () {
      final s = LineSegment(P(0, 0), P(100, 100));
      expect(s.isPointOn(P(0, 0)), isTrue);
      expect(s.isPointOn(P(100, 100)), isTrue);
      expect(s.isPointOn(P(50, 50)), isTrue);
    });

    test('diagonal — point past end is not on segment', () {
      final s = LineSegment(P(0, 0), P(100, 100));
      expect(s.isPointOn(P(150, 150)), isFalse);
      expect(s.isPointOn(P(-50, -50)), isFalse);
    });

    test('horizontal — in-range and out-of-range', () {
      final s = LineSegment(P(0, 5), P(100, 5));
      expect(s.isPointOn(P(50, 5)), isTrue);
      expect(s.isPointOn(P(-1, 5)), isFalse);
      expect(s.isPointOn(P(101, 5)), isFalse);
      expect(s.isPointOn(P(50, 6)), isFalse); // wrong y
    });

    test('vertical — in-range and out-of-range', () {
      final s = LineSegment(P(7, 0), P(7, 100));
      expect(s.isPointOn(P(7, 0)), isTrue);
      expect(s.isPointOn(P(7, 50)), isTrue);
      expect(s.isPointOn(P(7, 100)), isTrue);
      // Beyond the ends — used to return true before the fix
      expect(s.isPointOn(P(7, -1)), isFalse);
      expect(s.isPointOn(P(7, 101)), isFalse);
      // Off the line
      expect(s.isPointOn(P(8, 50)), isFalse);
    });

    test('vertical reversed — same bounds regardless of direction', () {
      final s = LineSegment(P(7, 100), P(7, 0));
      expect(s.isPointOn(P(7, 50)), isTrue);
      expect(s.isPointOn(P(7, -1)), isFalse);
      expect(s.isPointOn(P(7, 101)), isFalse);
    });

    test('near-vertical — dominant axis is y', () {
      final s = LineSegment(P(0, 0), P(1, 100));
      expect(s.isPointOn(P(0.5, 50)), isTrue);
      expect(s.isPointOn(P(0.5, 150)), isFalse); // past p2 end
    });

    test('isPointOn is true for all lerp(t) values', () {
      for (final seg in [
        LineSegment(P(0, 0), P(100, 0)), // horizontal
        LineSegment(P(0, 0), P(0, 100)), // vertical
        LineSegment(P(0, 0), P(60, 80)), // diagonal
        LineSegment(P(50, 200), P(50, 0)), // vertical reversed
      ]) {
        for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          expect(
            seg.isPointOn(seg.lerp(t)),
            isTrue,
            reason: 'isPointOn(lerp($t)) is false for $seg',
          );
        }
      }
    });
  });
}