import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

/// Samples a circular arc the way the RENDERER does: Flutter's
/// `arcToPoint(p2, radius, largeArc, clockwise: !seg.clockwise)` implements the
/// SVG endpoint-to-center parameterization (W3C SVG impl notes F.6.5/F.6.6),
/// INCLUDING the F.6.6 radius correction that scales the radius up when the
/// chord exceeds the diameter. We reproduce it here so tests do not depend on
/// the library's own geometry. `sweep` == Flutter's clockwise flag == !cw.
P _svgArcMidpoint(P p1, P p2, double r,
    {required bool largeArc, required bool sweep}) {
  final x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y;
  final x1p = (x1 - x2) / 2, y1p = (y1 - y2) / 2;
  var rr = r;
  final lambda = (x1p * x1p + y1p * y1p) / (rr * rr);
  if (lambda > 1) rr *= math.sqrt(lambda); // F.6.6 radius correction
  final num = rr * rr * rr * rr - rr * rr * (y1p * y1p + x1p * x1p);
  final den = rr * rr * (y1p * y1p + x1p * x1p);
  var factor = den == 0 ? 0.0 : math.sqrt((num / den).clamp(0, double.infinity));
  if (largeArc == sweep) factor = -factor;
  final cxp = factor * (rr * y1p) / rr, cyp = factor * -(rr * x1p) / rr;
  final cx = cxp + (x1 + x2) / 2, cy = cyp + (y1 + y2) / 2;
  double ang(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final len = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
    var a = math.acos((dot / len).clamp(-1.0, 1.0));
    if (ux * vy - uy * vx < 0) a = -a;
    return a;
  }

  final theta1 = ang(1, 0, (x1p - cxp) / rr, (y1p - cyp) / rr);
  var dTheta = ang((x1p - cxp) / rr, (y1p - cyp) / rr, (-x1p - cxp) / rr,
      (-y1p - cyp) / rr);
  if (!sweep && dTheta > 0) dTheta -= 2 * math.pi;
  if (sweep && dTheta < 0) dTheta += 2 * math.pi;
  final t = theta1 + dTheta * 0.5;
  return P(cx + rr * math.cos(t), cy + rr * math.sin(t));
}

void main() {
  group('CircularArcSegment radius correction (chord > 2*radius)', () {
    // Dragging the closed-circle playground path apart leaves radius small
    // while the chord grows; the renderer scales the radius up to chord/2.
    // The library's geometry must agree, or stroke expansion fits its offset
    // to a curve that does not match what is drawn.
    final degenerate = CircularArcSegment(
        const P(-130, 0), const P(300, 0), 120,
        clockwise: false);

    test('effectiveRadius scales up to chord/2', () {
      expect(degenerate.effectiveRadius, closeTo(430 / 2, 1e-9));
    });

    test('lerp(0.5) matches the rendered midpoint', () {
      final rendered = _svgArcMidpoint(degenerate.p1, degenerate.p2,
          degenerate.radius,
          largeArc: degenerate.largeArc, sweep: !degenerate.clockwise);
      expect((degenerate.lerp(0.5) - rendered).length, closeTo(0, 1e-6));
    });

    test('endpoints lie on the (corrected) circle', () {
      expect((degenerate.center - degenerate.p1).length,
          closeTo(degenerate.effectiveRadius, 1e-6));
      expect((degenerate.center - degenerate.p2).length,
          closeTo(degenerate.effectiveRadius, 1e-6));
    });

    test('valid arcs (chord <= 2*radius) are unaffected', () {
      final valid = CircularArcSegment(const P(-130, 0), const P(300, 0), 250,
          clockwise: false);
      expect(valid.effectiveRadius, closeTo(250, 1e-9));
    });
  });

  group('strokeExpand: rendered arc bulges to the correct side', () {
    final arcs = <String, CircularArcSegment>{
      'small ccw': CircularArcSegment(const P(-120, 0), const P(120, 0), 200,
          clockwise: false),
      'small cw': CircularArcSegment(const P(-120, 0), const P(120, 0), 200,
          clockwise: true),
      'large ccw': CircularArcSegment(const P(-120, 0), const P(120, 0), 130,
          largeArc: true, clockwise: false),
      'large cw': CircularArcSegment(const P(-120, 0), const P(120, 0), 130,
          largeArc: true, clockwise: true),
      'semicircle ccw': CircularArcSegment(
          const P(-120, 0), const P(120, 0), 120,
          clockwise: false),
      'quarter ccw': CircularArcSegment(const P(0, 100), const P(100, 0), 100,
          clockwise: false),
      'quarter cw': CircularArcSegment(const P(0, 100), const P(100, 0), 100,
          clockwise: true),
      // the degenerate, dragged-lens case from the playground:
      'degenerate ccw': CircularArcSegment(
          const P(-130, 0), const P(300, 0), 120,
          clockwise: false),
    };

    final widthConfigs = <String, (double, double, double)>{
      'uniform': (40, 40, 40),
      'tapered': (40, 0, 0),
    };

    arcs.forEach((label, arc) {
      widthConfigs.forEach((wlabel, cfg) {
        final (maxWidth, w1, w2) = cfg;
        test('$label / $wlabel', () {
          final result = strokeExpand([arc],
              maxWidth: maxWidth, widthAtP1: w1, widthAtP2: w2);

          final origMid = arc.lerp(0.5);
          final n = arc.unitNormalAt(0.5);
          final hwMid = maxWidth / 2;
          final candPlus = origMid + n * hwMid;
          final candMinus = origMid - n * hwMid;

          for (final s in result) {
            if (s is! CircularArcSegment) continue;
            final rendMid = _svgArcMidpoint(s.p1, s.p2, s.radius,
                largeArc: s.largeArc, sweep: !s.clockwise);
            final dP = (rendMid - candPlus).length;
            final dM = (rendMid - candMinus).length;
            expect(dP < 2.0 || dM < 2.0, isTrue,
                reason: '$label/$wlabel: rendered midpoint $rendMid is on the '
                    'WRONG side — matches neither $candPlus nor $candMinus. '
                    'arc(p1=${s.p1} p2=${s.p2} r=${s.radius} '
                    'large=${s.largeArc} cw=${s.clockwise})');
          }
        });
      });
    });
  });
}
