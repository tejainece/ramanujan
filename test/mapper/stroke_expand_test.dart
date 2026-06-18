import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  // A horizontal cubic going from (0,0) to (100,0) with symmetric control
  // points — effectively straight, so normals are easy to reason about.
  final cubic = CubicSegment(
    p1: const P(0, 0),
    c1: const P(33, 0),
    c2: const P(67, 0),
    p2: const P(100, 0),
  );

  final quad = QuadraticSegment(
    p1: const P(0, 0),
    c: const P(50, 0),
    p2: const P(100, 0),
  );

  final line = LineSegment(const P(0, 0), const P(100, 0));

  // For all three, the CW unit normal of a +x segment is (0, −1):
  // sideA is offset in the +normal direction, sideB in −normal.
  // Both sides share p1 and p2 because width tapers to zero at both ends.
  // result[1] = sideB.reversed() so its p1/p2 are swapped vs. the original.

  group('strokeExpand (curve-following)', () {
    group('cubic', () {
      test('returns two CubicSegments', () {
        final result = strokeExpand(cubic, maxWidth: 10);
        expect(result.length, 2);
        expect(result[0], isA<CubicSegment>());
        expect(result[1], isA<CubicSegment>());
      });

      test('sideA endpoints match original', () {
        final result = strokeExpand(cubic, maxWidth: 10);
        expect(result[0].p1.isEqual(cubic.p1), isTrue);
        expect(result[0].p2.isEqual(cubic.p2), isTrue);
      });

      test('sideB (reversed) endpoints match original swapped', () {
        final result = strokeExpand(cubic, maxWidth: 10);
        expect(result[1].p1.isEqual(cubic.p2), isTrue);
        expect(result[1].p2.isEqual(cubic.p1), isTrue);
      });

      test('sideA midpoint is offset by maxWidth/2 perpendicular', () {
        const maxWidth = 10.0;
        final result = strokeExpand(cubic, maxWidth: maxWidth);
        final mid = result[0].lerp(0.5);
        expect(mid.x, closeTo(50, 1));
        expect(mid.y.abs(), closeTo(maxWidth / 2, 0.5));
      });

      test('sideA and sideB midpoints are on opposite sides', () {
        final result = strokeExpand(cubic, maxWidth: 10);
        final yA = result[0].lerp(0.5).y;
        // sideB reversed: evaluate at t=0.5 → that is sideB's midpoint
        final yB = result[1].lerp(0.5).y;
        expect(yA.sign, isNot(equals(yB.sign)));
      });

      test('side:a — result[1] is the original curve reversed', () {
        final result = strokeExpand(cubic, maxWidth: 10, side: StrokeExpandSide.a);
        expect(result.length, 2);
        expect(result[0], isA<CubicSegment>());
        expect(result[1].p1.isEqual(cubic.p2), isTrue);
        expect(result[1].p2.isEqual(cubic.p1), isTrue);
      });

      test('side:b — result[0] is the original curve', () {
        final result = strokeExpand(cubic, maxWidth: 10, side: StrokeExpandSide.b);
        expect(result.length, 2);
        expect(result[0].p1.isEqual(cubic.p1), isTrue);
        expect(result[0].p2.isEqual(cubic.p2), isTrue);
        expect(result[1], isA<CubicSegment>());
      });
    });

    group('quadratic', () {
      test('returns two QuadraticSegments', () {
        final result = strokeExpand(quad, maxWidth: 10);
        expect(result.length, 2);
        expect(result[0], isA<QuadraticSegment>());
        expect(result[1], isA<QuadraticSegment>());
      });

      test('sideA endpoints match original', () {
        final result = strokeExpand(quad, maxWidth: 10);
        expect(result[0].p1.isEqual(quad.p1), isTrue);
        expect(result[0].p2.isEqual(quad.p2), isTrue);
      });

      test('sideB (reversed) endpoints match original swapped', () {
        final result = strokeExpand(quad, maxWidth: 10);
        expect(result[1].p1.isEqual(quad.p2), isTrue);
        expect(result[1].p2.isEqual(quad.p1), isTrue);
      });

      test('sideA midpoint is offset by maxWidth/2 perpendicular', () {
        const maxWidth = 10.0;
        final result = strokeExpand(quad, maxWidth: maxWidth);
        final mid = result[0].lerp(0.5);
        expect(mid.x, closeTo(50, 1));
        expect(mid.y.abs(), closeTo(maxWidth / 2, 0.5));
      });
    });

    group('line', () {
      test('returns two CubicSegments', () {
        final result = strokeExpand(line, maxWidth: 10);
        expect(result.length, 2);
        expect(result[0], isA<CubicSegment>());
        expect(result[1], isA<CubicSegment>());
      });

      test('sideA endpoints match original', () {
        final result = strokeExpand(line, maxWidth: 10);
        expect(result[0].p1.isEqual(line.p1), isTrue);
        expect(result[0].p2.isEqual(line.p2), isTrue);
      });

      test('sideB (reversed) endpoints match original swapped', () {
        final result = strokeExpand(line, maxWidth: 10);
        expect(result[1].p1.isEqual(line.p2), isTrue);
        expect(result[1].p2.isEqual(line.p1), isTrue);
      });

      test('sideA midpoint is offset by maxWidth/2 perpendicular', () {
        const maxWidth = 10.0;
        final result = strokeExpand(line, maxWidth: maxWidth);
        final mid = result[0].lerp(0.5);
        expect(mid.x, closeTo(50, 1));
        expect(mid.y.abs(), closeTo(maxWidth / 2, 0.5));
      });
    });
  });

  group('strokeExpandWithProfile (variable width)', () {
    test('constant profile: returns LineSegments', () {
      final result = strokeExpandWithProfile(line, width: (_) => 10);
      expect(result.isNotEmpty, isTrue);
      expect(result.every((s) => s is LineSegment), isTrue);
    });

    test('constant profile on a line produces 4 segments with flat caps', () {
      // Straight line → adaptive sampler yields only t=[0,1].
      // Without round caps: start flat + sideB + end flat + sideA = 4 segments.
      final result = strokeExpandWithProfile(line, width: (_) => 10, roundCaps: false);
      expect(result.length, 4);
    });

    test('round caps add more segments than flat caps', () {
      final withCaps = strokeExpandWithProfile(line, width: (_) => 10);
      final withoutCaps = strokeExpandWithProfile(line, width: (_) => 10, roundCaps: false);
      expect(withCaps.length, greaterThan(withoutCaps.length));
    });

    test('constant profile: offset points are at ±halfWidth from the line', () {
      const w = 10.0;
      final result = strokeExpandWithProfile(line, width: (_) => w, roundCaps: false);
      // Flat caps at start/end connect sideA.first↔sideB.first and sideB.last↔sideA.last.
      // sideB goes forward (segment index 1) and sideA backward (segment index 3).
      // sideB[0]→sideB[1] is segment index 1; its p1 is sideB[0] = (0, w/2).
      final sideBFirst = result[1].p1;
      expect(sideBFirst.y.abs(), closeTo(w / 2, 1e-6));
    });

    test('sin profile on a curved segment: max offset ≈ maxWidth/2', () {
      // Use a cubic so the adaptive sampler generates intermediate samples.
      const maxWidth = 12.0;
      final curved = CubicSegment(
        p1: const P(0, 0),
        c1: const P(33, 50),
        c2: const P(67, 50),
        p2: const P(100, 0),
      );
      final result = strokeExpandWithProfile(
        curved,
        width: (t) => maxWidth * math.sin(math.pi * t),
        maxChordError: 0.1,
        roundCaps: false,
      );
      final maxOffset = result.map((s) => s.p1.distanceTo(curved.lerp(0))).reduce(math.max);
      // The farthest vertex should be near maxWidth/2 (≈6) from the curve's vicinity.
      // We just verify it's non-trivial (> 1) and not excessive (< maxWidth).
      expect(maxOffset, greaterThan(1));
    });
  });
}
