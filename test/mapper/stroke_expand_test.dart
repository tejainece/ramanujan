import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
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

  group('strokeExpand (curve-following)', () {
    group('cubic', () {
      test('returns two CubicSegments', () {
        final result = strokeExpand([cubic], maxWidth: 10);
        expect(result.length, 2);
        expect(result[0], isA<CubicSegment>());
        expect(result[1], isA<CubicSegment>());
      });

      test('sideA endpoints match original', () {
        final result = strokeExpand([cubic], maxWidth: 10);
        expect(result[0].p1.isEqual(cubic.p1), isTrue);
        expect(result[0].p2.isEqual(cubic.p2), isTrue);
      });

      test('sideB (reversed) endpoints match original swapped', () {
        final result = strokeExpand([cubic], maxWidth: 10);
        expect(result[1].p1.isEqual(cubic.p2), isTrue);
        expect(result[1].p2.isEqual(cubic.p1), isTrue);
      });

      test('sideA midpoint is offset by maxWidth/2 perpendicular', () {
        const maxWidth = 10.0;
        final result = strokeExpand([cubic], maxWidth: maxWidth);
        final mid = result[0].lerp(0.5);
        expect(mid.x, closeTo(50, 1));
        expect(mid.y.abs(), closeTo(maxWidth / 2, 0.5));
      });

      test('sideA and sideB midpoints are on opposite sides', () {
        final result = strokeExpand([cubic], maxWidth: 10);
        expect(result[0].lerp(0.5).y.sign, isNot(equals(result[1].lerp(0.5).y.sign)));
      });

      test('side:a — result[1] is the original curve reversed', () {
        final result = strokeExpand([cubic], maxWidth: 10, side: StrokeExpandSide.a);
        expect(result.length, 2);
        expect(result[0], isA<CubicSegment>());
        expect(result[1].p1.isEqual(cubic.p2), isTrue);
        expect(result[1].p2.isEqual(cubic.p1), isTrue);
      });

      test('side:b — result[0] is the original curve', () {
        final result = strokeExpand([cubic], maxWidth: 10, side: StrokeExpandSide.b);
        expect(result.length, 2);
        expect(result[0].p1.isEqual(cubic.p1), isTrue);
        expect(result[0].p2.isEqual(cubic.p2), isTrue);
        expect(result[1], isA<CubicSegment>());
      });
    });

    group('quadratic', () {
      test('returns two QuadraticSegments', () {
        final result = strokeExpand([quad], maxWidth: 10);
        expect(result.length, 2);
        expect(result[0], isA<QuadraticSegment>());
        expect(result[1], isA<QuadraticSegment>());
      });

      test('sideA endpoints match original', () {
        final result = strokeExpand([quad], maxWidth: 10);
        expect(result[0].p1.isEqual(quad.p1), isTrue);
        expect(result[0].p2.isEqual(quad.p2), isTrue);
      });

      test('sideB (reversed) endpoints match original swapped', () {
        final result = strokeExpand([quad], maxWidth: 10);
        expect(result[1].p1.isEqual(quad.p2), isTrue);
        expect(result[1].p2.isEqual(quad.p1), isTrue);
      });

      test('sideA midpoint is offset by maxWidth/2 perpendicular', () {
        const maxWidth = 10.0;
        final result = strokeExpand([quad], maxWidth: maxWidth);
        final mid = result[0].lerp(0.5);
        expect(mid.x, closeTo(50, 1));
        expect(mid.y.abs(), closeTo(maxWidth / 2, 0.5));
      });
    });

    group('line', () {
      test('returns two CubicSegments', () {
        final result = strokeExpand([line], maxWidth: 10);
        expect(result.length, 2);
        expect(result[0], isA<CubicSegment>());
        expect(result[1], isA<CubicSegment>());
      });

      test('sideA endpoints match original', () {
        final result = strokeExpand([line], maxWidth: 10);
        expect(result[0].p1.isEqual(line.p1), isTrue);
        expect(result[0].p2.isEqual(line.p2), isTrue);
      });

      test('sideA midpoint is offset by maxWidth/2 perpendicular', () {
        const maxWidth = 10.0;
        final result = strokeExpand([line], maxWidth: maxWidth);
        final mid = result[0].lerp(0.5);
        expect(mid.x, closeTo(50, 1));
        expect(mid.y.abs(), closeTo(maxWidth / 2, 0.5));
      });
    });

    group('multi-segment', () {
      // Two cubics end-to-end: (0,0)→(100,0) then (100,0)→(200,0).
      final seg1 = CubicSegment(
          p1: const P(0, 0),
          c1: const P(33, 0),
          c2: const P(67, 0),
          p2: const P(100, 0));
      final seg2 = CubicSegment(
          p1: const P(100, 0),
          c1: const P(133, 0),
          c2: const P(167, 0),
          p2: const P(200, 0));

      test('returns 4 segments for two cubics (2 sideA + 2 sideB reversed)', () {
        final result = strokeExpand([seg1, seg2], maxWidth: 10);
        expect(result.length, 4);
      });

      test('sideA[0] starts at path start (widthAtP1=0)', () {
        final result = strokeExpand([seg1, seg2], maxWidth: 10);
        expect(result[0].p1.isEqual(seg1.p1), isTrue);
      });

      test('sideA[1] ends at path end (widthAtP2=0)', () {
        final result = strokeExpand([seg1, seg2], maxWidth: 10);
        expect(result[1].p2.isEqual(seg2.p2), isTrue);
      });

      test('interior joint: sideA[0].p2 == sideA[1].p1 (continuous at joint)', () {
        final result = strokeExpand([seg1, seg2], maxWidth: 10);
        // At interior joint, both sides have width=maxWidth, so sideA is offset
        // by maxWidth/2 from the joint point.
        expect(result[0].p2.isEqual(result[1].p1), isTrue);
      });

      test('sideB chain is reversed: last segment reversed first', () {
        final result = strokeExpand([seg1, seg2], maxWidth: 10);
        // result[2] is sideB[1].reversed() → goes from seg2.p2 toward seg2.p1
        expect(result[2].p1.isEqual(seg2.p2), isTrue);
        // result[3] is sideB[0].reversed() → ends at seg1.p1
        expect(result[3].p2.isEqual(seg1.p1), isTrue);
      });
    });
  });

  group('strokeExpandWithProfile (variable width)', () {
    test('constant profile: returns LineSegments', () {
      final result = strokeExpandWithProfile([line], width: (_) => 10);
      expect(result.isNotEmpty, isTrue);
      expect(result.every((s) => s is LineSegment), isTrue);
    });

    test('constant profile on a line produces 4 segments with flat caps', () {
      final result =
          strokeExpandWithProfile([line], width: (_) => 10, roundCaps: false);
      expect(result.length, 4);
    });

    test('round caps add more segments than flat caps', () {
      final withCaps = strokeExpandWithProfile([line], width: (_) => 10);
      final withoutCaps =
          strokeExpandWithProfile([line], width: (_) => 10, roundCaps: false);
      expect(withCaps.length, greaterThan(withoutCaps.length));
    });

    test('constant profile: offset points are at ±halfWidth from the line', () {
      const w = 10.0;
      final result =
          strokeExpandWithProfile([line], width: (_) => w, roundCaps: false);
      final sideBFirst = result[1].p1;
      expect(sideBFirst.y.abs(), closeTo(w / 2, 1e-6));
    });

    test('multi-segment: width profile spans both segments by arc length', () {
      // Two equal-length horizontal lines end-to-end.
      // With a profile that is 0 at t=0, peaks at t=0.5, 0 at t=1, the joint
      // (global t=0.5) should be the widest point.
      final seg1 = LineSegment(const P(0, 0), const P(100, 0));
      final seg2 = LineSegment(const P(100, 0), const P(200, 0));
      final result = strokeExpandWithProfile(
        [seg1, seg2],
        width: (t) => 20 * math.sin(math.pi * t),
        roundCaps: false,
      );
      // The widest sideB point (most positive y) should be near the joint.
      final maxY = result.map((s) => s.p1.y.abs()).reduce(math.max);
      expect(maxY, closeTo(10, 2));
    });
  });
}
