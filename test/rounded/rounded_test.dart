import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  // Two lines sharing a vertex at `vertex`, making an interior turn of
  // `turnDegrees` there. line1 runs into the vertex, line2 runs out of it.
  (LineSegment, LineSegment) corner({
    P vertex = const P(0, 0),
    double incomingAngleDeg = 180,
    double turnDegrees = 90,
    double len1 = 50,
    double len2 = 50,
  }) {
    final inRad = incomingAngleDeg * pi / 180;
    final p1 = vertex - P(cos(inRad), sin(inRad)) * len1;
    final outRad = inRad + turnDegrees * pi / 180;
    final p2 = vertex + P(cos(outRad), sin(outRad)) * len2;
    return (LineSegment(p1, vertex), LineSegment(vertex, p2));
  }

  bool parallel(P a, P b, [double epsilon = 1e-3]) =>
      (a.x * b.y - a.y * b.x).abs() < epsilon;

  void expectConnected(List<Segment> segs) {
    for (var i = 0; i < segs.length - 1; i++) {
      expect(
        segs[i].p2.isEqual(segs[i + 1].p1, 1e-6),
        isTrue,
        reason: 'segment $i does not connect to segment ${i + 1}',
      );
    }
  }

  group('roundCornerUsingCircularArc', () {
    test('averages asymmetric radii into one true circle', () {
      final (line1, line2) = corner();
      final segs = roundCornerUsingCircularArc(line1, line2, 10, 20);
      expectConnected(segs);
      final arc = segs[1] as CircularArcSegment;
      expect(arc.p1.isEqual(line1.pointAtDistanceFromP2(15)), isTrue);
      expect(arc.p2.isEqual(line2.pointAtDistanceFromP1(15)), isTrue);
    });

    test('is tangent to both lines for a variety of corner angles', () {
      for (final turn in [30.0, 60.0, 90.0, 120.0, 150.0]) {
        for (final incoming in [0.0, 40.0, -70.0]) {
          final (line1, line2) = corner(
            turnDegrees: turn,
            incomingAngleDeg: incoming,
          );
          final segs = roundCornerUsingCircularArc(line1, line2, 8, 8);
          final arc = segs[1];
          expect(
            parallel(arc.unitTangentAt(0), line1.unitTangentAt(0)),
            isTrue,
            reason: 'turn=$turn incoming=$incoming start tangent',
          );
          expect(
            parallel(arc.unitTangentAt(1), line2.unitTangentAt(0)),
            isTrue,
            reason: 'turn=$turn incoming=$incoming end tangent',
          );
        }
      }
    });
  });

  group('roundCornerUsingEllipticArc', () {
    test('honours two different radii independently', () {
      final (line1, line2) = corner();
      final segs = roundCornerUsingEllipticArc(line1, line2, 10, 20);
      expectConnected(segs);
      expect(segs[1], isA<ArcSegment>());
      expect(segs[1].p1.isEqual(line1.pointAtDistanceFromP2(10)), isTrue);
      expect(segs[1].p2.isEqual(line2.pointAtDistanceFromP1(20)), isTrue);
    });

    test(
      'is exactly tangent to both lines across angles and radius ratios',
      () {
        for (final turn in [30.0, 60.0, 90.0, 120.0, 150.0]) {
          for (final incoming in [0.0, 40.0, -70.0]) {
            for (final radii in [(6.0, 14.0), (14.0, 6.0), (9.0, 9.0)]) {
              final (line1, line2) = corner(
                turnDegrees: turn,
                incomingAngleDeg: incoming,
              );
              final segs = roundCornerUsingEllipticArc(
                line1,
                line2,
                radii.$1,
                radii.$2,
              );
              final arc = segs[1];
              expect(
                parallel(arc.unitTangentAt(0), line1.unitTangentAt(0)),
                isTrue,
                reason: 'turn=$turn incoming=$incoming radii=$radii start',
              );
              expect(
                parallel(arc.unitTangentAt(1), line2.unitTangentAt(0)),
                isTrue,
                reason: 'turn=$turn incoming=$incoming radii=$radii end',
              );
            }
          }
        }
      },
    );

    test(
      'reduces to a circle for a right-angle corner with matching radii',
      () {
        // Only at a right angle are the two lines' normals orthogonal, so this
        // is the one case where the tangent ellipse degenerates to a true
        // circle -- away from 90 degrees, the ellipse tangent at two equally-
        // cut points is a genuinely different (still exactly tangent) curve
        // from the circle, since a conic tangent to two lines at two fixed
        // points has one remaining degree of freedom beyond "equal radii".
        final (line1, line2) = corner(turnDegrees: 90);
        final circular =
            roundCornerUsingCircularArc(line1, line2, 12, 12)[1]
                as CircularArcSegment;
        final elliptic =
            roundCornerUsingEllipticArc(line1, line2, 12, 12)[1] as ArcSegment;
        expect(elliptic.radii.x, closeTo(elliptic.radii.y, 1e-6));
        expect(elliptic.radii.x, closeTo(circular.effectiveRadius, 1e-6));
      },
    );
  });

  group('roundCornerUsingInvertedArc', () {
    test('cuts both lines back to the same points a normal round would', () {
      for (final turn in [40.0, 90.0, 130.0]) {
        final (line1, line2) = corner(turnDegrees: turn);
        final segs = roundCornerUsingInvertedArc(line1, line2, 10, 10);
        expectConnected(segs);

        expect(segs[0].p2.isEqual(line1.pointAtDistanceFromP2(10)), isTrue);
        expect(segs[2].p1.isEqual(line2.pointAtDistanceFromP1(10)), isTrue);
      }
    });

    test('bridges the cut points with an arc of a circle centered exactly '
        'on the original vertex, for a variety of corner angles', () {
      for (final turn in [
        -150.0,
        -120.0,
        -90.0,
        -60.0,
        -30.0,
        30.0,
        60.0,
        90.0,
        120.0,
        150.0,
      ]) {
        for (final incoming in [0.0, 40.0, -70.0]) {
          final (line1, line2) = corner(
            turnDegrees: turn,
            incomingAngleDeg: incoming,
          );
          final vertex = line1.p2;
          final segs = roundCornerUsingInvertedArc(line1, line2, 8, 8);
          final arc = segs[1] as CircularArcSegment;
          expect(
            arc.center.isEqual(vertex, 1e-6),
            isTrue,
            reason: 'turn=$turn incoming=$incoming',
          );
          // Every point on the arc stays exactly at the cut radius from the
          // vertex -- it bites into the corner, never past it.
          for (var t = 0.0; t <= 1; t += 0.1) {
            expect(arc.lerp(t).distanceTo(vertex), closeTo(8, 1e-6));
          }
        }
      }
    });

    test('meets each straight line at a right angle, not tangentially', () {
      final (line1, line2) = corner(turnDegrees: 90);
      final segs = roundCornerUsingInvertedArc(line1, line2, 10, 10);
      final arc = segs[1];
      expect(parallel(arc.unitTangentAt(0), line1.unitTangentAt(0)), isFalse);
      expect(parallel(arc.unitTangentAt(1), line2.unitTangentAt(0)), isFalse);
    });

    test(
      'regression: a clockwise turn (line1 pointing up into the vertex, '
      'line2 pointing right out of it) centers the arc on the vertex too',
      () {
        final vertex = P(0, 105);
        final line1 = LineSegment(P(0, -50), vertex);
        final line2 = LineSegment(vertex, P(140, 105));
        final segs = roundCornerUsingInvertedArc(line1, line2, 100, 100);
        final arc = segs[1] as CircularArcSegment;
        expect(arc.center.isEqual(vertex, 1e-6), isTrue);
      },
    );
  });

  group('roundCornerUsingChamfer', () {
    test('connects the two independently-cut points with a straight line', () {
      final (line1, line2) = corner();
      final segs = roundCornerUsingChamfer(line1, line2, 10, 20);
      expectConnected(segs);
      expect(segs[1], isA<LineSegment>());
      expect(segs[1].p1.isEqual(line1.pointAtDistanceFromP2(10)), isTrue);
      expect(segs[1].p2.isEqual(line2.pointAtDistanceFromP1(20)), isTrue);
    });
  });

  group('roundCornerUsingCubicBezier', () {
    test('is continuous end-to-end (regression: used to have a gap)', () {
      final (line1, line2) = corner();
      final segs = roundCornerUsingCubicBezier(line1, line2, 10, 20);
      expectConnected(segs);
    });

    test('has zero curvature at both ends, matching the straight lines', () {
      final (line1, line2) = corner(turnDegrees: 100);
      final segs = roundCornerUsingCubicBezier(line1, line2, 10, 15);
      final cubic = segs[1] as CubicSegment;
      // Curvature ∝ |tangent × secondDerivative|; both derivatives collapse
      // toward the same direction at t=0/t=1 iff c1/c2 sit exactly at the
      // vertex, so the cross product should vanish at both ends.
      P deriv2At(double t) {
        const h = 1e-4;
        final a = cubic.lerp((t - h).clamp(0.0, 1.0));
        final b = cubic.lerp(t);
        final c = cubic.lerp((t + h).clamp(0.0, 1.0));
        return a - b * 2 + c;
      }

      final cross0 =
          cubic.unitTangentAt(0).x * deriv2At(0).y -
          cubic.unitTangentAt(0).y * deriv2At(0).x;
      final cross1 =
          cubic.unitTangentAt(1).x * deriv2At(1).y -
          cubic.unitTangentAt(1).y * deriv2At(1).x;
      expect(cross0.abs(), lessThan(1e-2));
      expect(cross1.abs(), lessThan(1e-2));
    });

    test('honours the two radii independently', () {
      final (line1, line2) = corner();
      final segs = roundCornerUsingCubicBezier(line1, line2, 10, 20);
      expect(segs[1].p1.isEqual(line1.pointAtDistanceFromP2(10)), isTrue);
      expect(segs[1].p2.isEqual(line2.pointAtDistanceFromP1(20)), isTrue);
    });
  });

  group('roundCornerUsingSquircle', () {
    test('matches roundCornerUsingCubicBezier exactly', () {
      final (line1, line2) = corner(turnDegrees: 55);
      final squircle = roundCornerUsingSquircle(line1, line2, 9, 17);
      final cubic = roundCornerUsingCubicBezier(line1, line2, 9, 17);
      for (var i = 0; i < 3; i++) {
        expect(squircle[i].p1.isEqual(cubic[i].p1), isTrue);
        expect(squircle[i].p2.isEqual(cubic[i].p2), isTrue);
      }
    });
  });

  group('rounding a corner where an adjacent segment is a curve', () {
    // A quarter-circle arc arriving at the vertex from the left, followed by
    // a straight line leaving it horizontally -- one curved side, one
    // straight side, so tangent direction genuinely varies along segment1.
    (CircularArcSegment, LineSegment) arcThenLine() {
      final vertex = P(0, -50);
      final segment1 = CircularArcSegment(
        P(-50, 0),
        vertex,
        50,
        clockwise: false,
      );
      // Deliberately not the arc's own tangent direction at the vertex
      // (which happens to be horizontal here) -- otherwise there's no real
      // corner to round, just a smooth continuation.
      final segment2 = LineSegment(vertex, P(80, 0));
      return (segment1, segment2);
    }

    // Two curved sides: a cubic arriving at the vertex, and a quadratic
    // leaving it -- exercises the fully-general curve-to-curve path.
    (CubicSegment, QuadraticSegment) cubicThenQuadratic() {
      const vertex = P(0, 0);
      final segment1 = CubicSegment(
        p1: const P(-80, 40),
        c1: const P(-40, 40),
        c2: const P(-10, 10),
        p2: vertex,
      );
      final segment2 = QuadraticSegment(
        p1: vertex,
        c: const P(40, -10),
        p2: const P(80, -40),
      );
      return (segment1, segment2);
    }

    test('circular arc stays tangent to a curved incoming side', () {
      final (segment1, segment2) = arcThenLine();
      final segs = roundCornerUsingCircularArc(segment1, segment2, 10, 10);
      expectConnected(segs);
      final fillet = segs[1];
      expect(
        parallel(fillet.unitTangentAt(0), segs[0].unitTangentAt(1)),
        isTrue,
      );
      expect(
        parallel(fillet.unitTangentAt(1), segs[2].unitTangentAt(0)),
        isTrue,
      );
    });

    test('elliptic arc stays tangent to both a curved and a straight side', () {
      final (segment1, segment2) = arcThenLine();
      final segs = roundCornerUsingEllipticArc(segment1, segment2, 8, 16);
      expectConnected(segs);
      final fillet = segs[1];
      expect(
        parallel(fillet.unitTangentAt(0), segs[0].unitTangentAt(1)),
        isTrue,
      );
      expect(
        parallel(fillet.unitTangentAt(1), segs[2].unitTangentAt(0)),
        isTrue,
      );
    });

    test(
      'chamfer cuts a curved side back by arc length, not by a straight-line distance',
      () {
        final (segment1, segment2) = arcThenLine();
        const radius = 12.0;
        final segs = roundCornerUsingChamfer(
          segment1,
          segment2,
          radius,
          radius,
        );
        expectConnected(segs);
        // The kept piece of the arc is shorter than the original by exactly
        // the arc-length radius cut back.
        expect(segs[0].length, closeTo(segment1.length - radius, 1e-2));
        expect(segs[1], isA<LineSegment>());
      },
    );

    test('inverted arc cuts a curved side to where the vertex-centered circle '
        'crosses it, not to an arc-length offset', () {
      final (segment1, segment2) = arcThenLine();
      const radius = 15.0;
      final vertex = segment1.p2;
      final segs = roundCornerUsingInvertedArc(
        segment1,
        segment2,
        radius,
        radius,
      );
      expectConnected(segs);
      // Both cut points sit exactly on the vertex-centered circle -- if this
      // had cut by arc length instead (like every other style), the cut
      // point on the curved side would land at a different, larger chord
      // distance from the vertex.
      expect(segs[0].p2.distanceTo(vertex), closeTo(radius, 1e-6));
      expect(segs[2].p1.distanceTo(vertex), closeTo(radius, 1e-6));
      final arc = segs[1] as CircularArcSegment;
      expect(arc.center.isEqual(vertex, 1e-6), isTrue);
    });

    test(
      'quadratic/cubic/squircle fillets stay tangent at a curved cut point, not just a straight one',
      () {
        final (segment1, segment2) = arcThenLine();
        for (final builder in [
          roundCornerUsingQuadraticBezier,
          roundCornerUsingCubicBezier,
          roundCornerUsingSquircle,
        ]) {
          final segs = builder(segment1, segment2, 9, 14);
          expectConnected(segs);
          final fillet = segs[1];
          expect(
            parallel(fillet.unitTangentAt(0), segs[0].unitTangentAt(1)),
            isTrue,
          );
          expect(
            parallel(fillet.unitTangentAt(1), segs[2].unitTangentAt(0)),
            isTrue,
          );
        }
      },
    );

    test('all six styles also work between two curved sides', () {
      final (segment1, segment2) = cubicThenQuadratic();
      for (final builder in [
        roundCornerUsingCircularArc,
        roundCornerUsingEllipticArc,
        roundCornerUsingChamfer,
        roundCornerUsingQuadraticBezier,
        roundCornerUsingCubicBezier,
        roundCornerUsingSquircle,
      ]) {
        final segs = builder(segment1, segment2, 6, 9);
        expectConnected(segs);
      }
    });
  });

  group('automatic radius clamping vs. adjacent edge length', () {
    test('styles with independent radii clamp each radius to its own side, '
        'leaving the other side unaffected', () {
      final (line1, line2) = corner(len1: 20, len2: 80);
      for (final builder in [
        roundCornerUsingChamfer,
        roundCornerUsingEllipticArc,
        roundCornerUsingQuadraticBezier,
        roundCornerUsingCubicBezier,
        roundCornerUsingSquircle,
      ]) {
        // radius1 (1000) is clamped down to segment1's own length (20),
        // fully consuming it; radius2 (30) is well within segment2's
        // length (80) and is honoured exactly, unaffected by the other
        // side's oversized request.
        final segs = builder(line1, line2, 1000, 30);
        expectConnected(segs);
        expect(segs[0].length, closeTo(0, 1e-6));
        expect(segs[2].length, closeTo(80 - 30, 1e-6));
      }
    });

    test(
      'roundCornerUsingCircularArc clamps each radius to its own side before '
      'averaging, so one oversized radius cannot blow out the cut on the '
      'other side',
      () {
        final (line1, line2) = corner(len1: 100, len2: 10);
        // Without clamping, radius2 (1000) would average with radius1 (5)
        // into 502.5 and devour all of segment1 (length 100) too, even
        // though radius1 itself was perfectly reasonable. Clamped, radius2
        // is capped to segment2's own length (10) before averaging, giving
        // an averaged radius of (5 + 10) / 2 = 7.5.
        final segs = roundCornerUsingCircularArc(line1, line2, 5, 1000);
        expectConnected(segs);
        expect(segs[0].length, closeTo(100 - 7.5, 1e-6));
      },
    );

    test(
      'roundCornerUsingInvertedArc clamps each radius to its own side before '
      'averaging, so one oversized radius cannot blow out the cut on the '
      'other side',
      () {
        final (line1, line2) = corner(len1: 100, len2: 10);
        final vertex = line1.p2;
        final segs = roundCornerUsingInvertedArc(line1, line2, 5, 1000);
        expectConnected(segs);
        expect(segs[0].p2.distanceTo(vertex), closeTo(7.5, 1e-6));
      },
    );
  });
}
