import 'dart:math';

import 'package:polynomial/polynomial.dart';
import 'package:ramanujan/ramanujan.dart';

class QuadraticSegment extends Segment {
  @override
  final P p1;
  @override
  final P p2;

  final P c;

  QuadraticSegment({required this.p1, required this.p2, required this.c});

  @override
  List<P> get controlPoints => [c];

  @override
  LineSegment get p1Tangent => LineSegment(p1, c);

  @override
  LineSegment get p2Tangent => LineSegment(c, p2);

  @override
  P lerp(double t) => P(quadraticBezierLerp(p1.x, c.x, p2.x, t),
      quadraticBezierLerp(p1.y, c.y, p2.y, t));

  // B'(t) = 2(1-t)(c - p1) + 2t(p2 - c)
  @override
  P unitTangentAt(double t) =>
      ((c - p1) * (2 * (1 - t)) + (p2 - c) * (2 * t)).normalized;

  @override
  double ilerp(P point) {
    // TODO
    throw UnimplementedError();
  }

  @override
  (QuadraticSegment, QuadraticSegment) bifurcateAtInterval(double t) {
    final curve1cp = LineSegment(p1, c).lerp(t);
    final curve2cp = LineSegment(c, p2).lerp(t);
    final bridge = LineSegment(curve1cp, curve2cp).lerp(t);
    return (
      QuadraticSegment(p1: p1, p2: bridge, c: curve1cp),
      QuadraticSegment(p1: bridge, p2: p2, c: curve2cp)
    );
  }

  @override
  double get length => _quadraticBezierLength(p1, c, p2, 0.01, 0);

  CubicSegment toCubic() => CubicSegment(
      p1: p1,
      p2: p2,
      c1: p1 * (1 / 3.0) + c * (2 / 3.0),
      c2: c * (2 / 3.0) + p2 * (1 / 3.0));

  @override
  QuadraticSegment reversed() => QuadraticSegment(p2: p1, p1: p2, c: c);

  @override
  bool operator ==(Object other) =>
      other is QuadraticSegment &&
      other.p1 == p1 &&
      other.p2 == p2 &&
      other.c == c;

  @override
  int get hashCode => Object.hash(p1, p2, c);

  @override

  /// https://iquilezles.org/articles/bezierbbox/
  R get boundingBox {
    R ret = R.fromPoints(p1, p2);
    if (ret.containsPoint(c)) return ret;
    P t = (p1 - c) / (p1 - c * 2 + p2);
    P s = P(1 - t.x, 1 - t.y);
    P p = s * s * p1 + s * t * c * 2 + t * t * p2;
    if (!p.x.isNaN) {
      ret = ret.includeX(p.x);
    }
    if (!p.y.isNaN) {
      ret = ret.includeY(p.y);
    }
    return ret;
  }

  @override
  List<P> intersect(Segment other) {
    if (other is LineSegment) return intersectLine(other);
    if (other is QuadraticSegment) return intersectQuadratic(other);
    if (other is CircularArcSegment) return intersectCircularArc(other);
    if (other is ArcSegment) return intersectArc(other);
    if (other is CubicSegment) return other.intersect(this);
    throw ArgumentError(
        'QuadraticSegment.intersect with ${other.runtimeType} not implemented');
  }

  List<P> intersectLine(LineSegment l) => l.intersectQuadratic(this);

  // Sylvester resultant eliminates the parameter of the other quadratic,
  // producing a degree-4 polynomial in our parameter t.
  List<P> intersectQuadratic(QuadraticSegment other) {
    final c10x = p1.x, c11x = 2 * (c.x - p1.x), c12x = p1.x - 2 * c.x + p2.x;
    final c10y = p1.y, c11y = 2 * (c.y - p1.y), c12y = p1.y - 2 * c.y + p2.y;
    final c20x = other.p1.x,
        c21x = 2 * (other.c.x - other.p1.x),
        c22x = other.p1.x - 2 * other.c.x + other.p2.x;
    final c20y = other.p1.y,
        c21y = 2 * (other.c.y - other.p1.y),
        c22y = other.p1.y - 2 * other.c.y + other.p2.y;

    if (c22x.abs() < 1e-10 && c22y.abs() < 1e-10) {
      return intersectLine(LineSegment(other.p1, other.p2));
    }

    final a = c22x, b = c21x, d = c22y, e = c21y;
    final cp = Polynomial([c20x - c10x, -c11x, -c12x]);
    final fp = Polynomial([c20y - c10y, -c11y, -c12y]);

    // Res(f,g) = A²F² − ABEF + AE²C − 2ADCF + B²DF − BDEC + D²C²
    final res = fp * fp * (a * a) +
        fp * (-a * b * e) +
        cp * (a * e * e) +
        cp * fp * (-2 * a * d) +
        fp * (b * b * d) +
        cp * (-b * d * e) +
        cp * cp * (d * d);

    const eps = 1e-9;
    final result = <P>[];
    for (final t in ClosedFormMethod.instance.realRoots(res)) {
      if (t < -eps || t > 1 + eps) continue;
      final pt = lerp(t.clamp(0.0, 1.0));
      if (_onQuadratic(other, pt, c22x, c21x, c20x, c22y, c21y, c20y)) {
        result.add(pt);
      }
    }
    return result;
  }

  // Substitute into circle equation (Q(t)-center)²=r² → degree-4 poly.
  List<P> intersectCircularArc(CircularArcSegment ca) {
    final cx = ca.center.x, cy = ca.center.y, r2 = ca.radius * ca.radius;
    final vx = Polynomial([p1.x - cx, 2 * (c.x - p1.x), p1.x - 2 * c.x + p2.x]);
    final vy = Polynomial([p1.y - cy, 2 * (c.y - p1.y), p1.y - 2 * c.y + p2.y]);
    final poly = vx * vx + vy * vy + Polynomial([-r2]);
    const eps = 1e-9;
    return ClosedFormMethod.instance
        .realRoots(poly)
        .where((t) => t >= -eps && t <= 1 + eps)
        .map((t) => lerp(t.clamp(0.0, 1.0)))
        .where((p) => _onCircularArc(ca, p))
        .toList();
  }

  // Transform this quadratic into the ellipse's unit-circle space; find where
  // the transformed curve hits the unit circle → degree-4 poly.
  List<P> intersectArc(ArcSegment a) {
    final T = a.ellipse.inverseUnitCircleTransform;
    final tp1 = T.apply(p1), tcp = T.apply(c), tp2 = T.apply(p2);
    final ux =
        Polynomial([tp1.x, 2 * (tcp.x - tp1.x), tp1.x - 2 * tcp.x + tp2.x]);
    final uy =
        Polynomial([tp1.y, 2 * (tcp.y - tp1.y), tp1.y - 2 * tcp.y + tp2.y]);
    final poly = ux * ux + uy * uy + Polynomial([-1.0]);
    const eps = 1e-9;
    return ClosedFormMethod.instance
        .realRoots(poly)
        .where((t) => t >= -eps && t <= 1 + eps)
        .map((t) => lerp(t.clamp(0.0, 1.0)))
        .where((p) => _onArc(a, p))
        .toList();
  }
}

bool _onCircularArc(CircularArcSegment ca, P p) {
  final ang = Radian(ca.angleOfPoint(p).value);
  return ca.clockwise
      ? ang.isBetweenCW(ca.startAngle, ca.endAngle)
      : ang.isBetweenCCW(ca.startAngle, ca.endAngle);
}

// Checks if [p]'s eccentric angle on [a]'s ellipse lies within the arc's
// angular range, bypassing ilerp which has the same Radian normalization issue.
bool _onArc(ArcSegment a, P p) {
  final q = a.ellipse.inverseUnitCircleTransform.apply(p);
  final ang = Radian(Radian(atan2(q.y, q.x)).value);
  return a.clockwise
      ? ang.isBetweenCW(a.startAngle, a.endAngle)
      : ang.isBetweenCCW(a.startAngle, a.endAngle);
}

// Checks whether [pt] lies on quadratic [q] within [0,1] by solving the
// 1-D inverse: x2(s)=pt.x or y2(s)=pt.y and verifying by distance.
bool _onQuadratic(QuadraticSegment q, P pt, double c22x, double c21x,
    double c20x, double c22y, double c21y, double c20y) {
  const eps = 1e-9;
  if (c22x.abs() + c21x.abs() > 1e-10) {
    for (final s in quadraticRealRoots(c22x, c21x, c20x - pt.x)) {
      if (s < -eps || s > 1 + eps) continue;
      if (q.lerp(s.clamp(0.0, 1.0)).distanceTo(pt) < 1e-5) return true;
    }
  }
  if (c22y.abs() + c21y.abs() > 1e-10) {
    for (final s in quadraticRealRoots(c22y, c21y, c20y - pt.y)) {
      if (s < -eps || s > 1 + eps) continue;
      if (q.lerp(s.clamp(0.0, 1.0)).distanceTo(pt) < 1e-5) return true;
    }
  }
  return false;
}

double _quadraticBezierLength(P a0, P a1, P a2, double tolerance, int level) {
  double lower = a0.distanceTo(a2);
  double upper = a0.distanceTo(a1) + a1.distanceTo(a2);

  if (upper - lower <= 2 * tolerance || level >= 8) {
    return (lower + upper) / 2;
  }

  P b1 = (a0 + a1) * 0.5;
  P c1 = (a1 + a2) * 0.5;
  P b2 = (b1 + c1) * 0.5;
  return _quadraticBezierLength(a0, b1, b2, 0.5 * tolerance, level + 1) +
      _quadraticBezierLength(b2, c1, a2, 0.5 * tolerance, level + 1);
}

double quadraticBezierLerp(double p0, double p1, double p2, double t) =>
    (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2;

extension TupleExt<T> on (T, T) {
  List<T> toList() => [$1, $2];
}
