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

    group('elliptical arc', () {
      // Half-ellipse arc from (-100,0) to (100,0), radii (100,60), sweeping
      // through the bottom (clockwise=false). Spans ~180° → 2 cubics per side.
      final arc = ArcSegment(
        const P(-100, 0),
        const P(100, 0),
        const P(100, 60),
        clockwise: false,
      );

      test('returns cubic segments, not a polyline fallback', () {
        final result = strokeExpand([arc], maxWidth: 10);
        expect(result.every((s) => s is CubicSegment || s is LineSegment), isTrue);
        // A ~180° arc subdivides into 2 cubics per side (4) plus the closing cap.
        expect(result.whereType<CubicSegment>().length, 4);
      });

      test('sideA starts and ends at the offset arc endpoints', () {
        const maxWidth = 10.0;
        final result = strokeExpand([arc], maxWidth: maxWidth);
        // Endpoints taper to zero width by default, so they sit on the arc ends.
        expect(result.first.p1.isEqual(arc.p1), isTrue);
      });

      test('mid of the outline is offset by maxWidth/2 from the arc midpoint', () {
        const maxWidth = 10.0;
        final result = strokeExpand([arc], maxWidth: maxWidth);
        final arcMid = arc.lerp(0.5);
        // The join between the two sideA cubics is the offset of the arc midpoint.
        final outlineMid = result[1].p1;
        final d = (outlineMid - arcMid).length;
        expect(d, closeTo(maxWidth / 2, 0.5));
      });

      test('consecutive sideA pieces are C0-continuous', () {
        final result = strokeExpand([arc], maxWidth: 10);
        expect(result[0].p2.isEqual(result[1].p1), isTrue);
      });
    });

    group('tapered circular arc stays bounded (no large-arc balloon)', () {
      // Regression: a circular arc whose width tapers has a non-circular offset.
      // The old circumcircle fit picked a bogus radius + largeArc=true, so the
      // stroke ballooned the long way around. Every outline point must stay
      // within [r - maxWidth/2, r + maxWidth/2] of the arc center.
      const maxWidth = 41.0;
      final arc = CircularArcSegment(const P(0, 0), const P(100, 0), 50,
          clockwise: true); // semicircle, center (50,0), radius 50

      test('every outline point is within maxWidth/2 of the radius', () {
        final result = strokeExpand([arc],
            maxWidth: maxWidth, widthAtP1: 0, widthAtP2: 0);
        const center = P(50, 0);
        const maxR = 50 + maxWidth / 2; // 70.5
        double worst = 0;
        for (final s in result) {
          for (var i = 0; i <= 8; i++) {
            final d = (s.lerp(i / 8) - center).length;
            if (d > worst) worst = d;
          }
        }
        // A balloon (old bug) reached ~110; allow a small fitting tolerance.
        expect(worst, lessThan(maxR + 2),
            reason: 'outline bulged to $worst from center (max allowed $maxR)');
      });
    });

    group('S-arc inflection joint stays connected', () {
      // Regression: a CCW arc meeting a CW arc (an S-curve) inflects at the
      // joint. CW arcs lerp p2→p1, so their normal must be taken in path
      // orientation or side-A of one arc joins the wrong side of the other,
      // leaving a dangling endpoint at the joint. The far endpoint is dragged
      // out (chord > diameter) to exaggerate the old break.
      final sArc = [
        CircularArcSegment(const P(-100, 0), const P(0, 0), 50,
            clockwise: false),
        CircularArcSegment(const P(0, 0), const P(250, 0), 50,
            clockwise: true),
      ];

      int interiorGaps(List<Segment> out) {
        var gaps = 0;
        for (var i = 1; i < out.length; i++) {
          if (!out[i].p1.isEqual(out[i - 1].p2)) gaps++;
        }
        return gaps;
      }

      test('tapered: no gap between consecutive outline segments', () {
        final out = strokeExpand(sArc, maxWidth: 40, widthAtP1: 0, widthAtP2: 0);
        expect(interiorGaps(out), 0);
      });

      test('uniform: no gap between consecutive outline segments', () {
        final out =
            strokeExpand(sArc, maxWidth: 40, widthAtP1: 40, widthAtP2: 40);
        expect(interiorGaps(out), 0);
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

    test('S-curve is sampled (midpoint on chord does not fool flatness)', () {
      // Antisymmetric cubic whose lerp(0.5) lands exactly on the chord midpoint.
      // A single-midpoint flatness test reads this as flat and emits a straight
      // ribbon along the chord; the outline must instead follow the curve.
      final sCubic = CubicSegment(
        p1: const P(-160, -40),
        c1: const P(-60, 140),
        c2: const P(60, -140),
        p2: const P(160, 40),
      );
      final result = strokeExpandWithProfile(
        [sCubic],
        width: (t) => 2 + 22 * (4 * t * (1 - t)),
        maxChordError: 0.5,
        roundCaps: true,
      );
      // A straight-chord collapse yields only a handful of segments; following
      // the curve at this chord error needs many more.
      expect(result.length, greaterThan(20));
      // The outline must visit the curve's upper hump (centerline ~y=23 near
      // t=0.25), well above the chord, which sits near y=-20 at that x.
      final hump = result
          .map((s) => s.p1)
          .where((p) => p.x > -110 && p.x < -50)
          .map((p) => p.y)
          .fold(-1e9, math.max);
      expect(hump, greaterThan(10));
    });
  });
}
