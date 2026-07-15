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
  P lerp(double t) => P(
    quadraticBezierLerp(p1.x, c.x, p2.x, t),
    quadraticBezierLerp(p1.y, c.y, p2.y, t),
  );

  // B'(t) = 2(1-t)(c - p1) + 2t(p2 - c)
  @override
  P unitTangentAt(double t) =>
      ((c - p1) * (2 * (1 - t)) + (p2 - c) * (2 * t)).normalized;

  @override
  double ilerp(P point) {
    // Invert B(t) = (p1 - 2c + p2)·t² + 2(c - p1)·t + p1 per coordinate with
    // the quadratic formula and return the root in [0,1] whose point matches;
    // NaN when [point] does not lie on the curve.
    const eps = 1e-9;
    final ax = p1.x - 2 * c.x + p2.x, bx = 2 * (c.x - p1.x);
    final ay = p1.y - 2 * c.y + p2.y, by = 2 * (c.y - p1.y);
    for (final t in [
      if (ax.abs() + bx.abs() > 1e-10)
        ...quadraticRealRoots(ax, bx, p1.x - point.x),
      if (ay.abs() + by.abs() > 1e-10)
        ...quadraticRealRoots(ay, by, p1.y - point.y),
    ]) {
      if (t < -eps || t > 1 + eps) continue;
      if (lerp(t.clamp(0.0, 1.0)).distanceTo(point) < 1e-6) return t;
    }
    return double.nan;
  }

  @override
  double closestT(P point) {
    // Stationary points of |B(t) - point|²: with B(t) = a·t² + b·t + p1, the
    // derivative (B(t) - point)·B'(t) is a cubic in t. The minimum over [0,1]
    // is at one of its roots or at an endpoint.
    final a = p1 - c * 2 + p2;
    final b = (c - p1) * 2;
    final e = p1 - point;
    final roots = cubicRealRoots(
      2 * (a.x * a.x + a.y * a.y),
      3 * (a.x * b.x + a.y * b.y),
      (b.x * b.x + b.y * b.y) + 2 * (a.x * e.x + a.y * e.y),
      b.x * e.x + b.y * e.y,
    );
    var bestT = 0.0;
    var bestD = point.distanceTo(lerp(0));
    void consider(double t) {
      final d = point.distanceTo(lerp(t));
      if (d < bestD) {
        bestD = d;
        bestT = t;
      }
    }

    consider(1);
    for (final t in roots) {
      if (t > 0 && t < 1) consider(t);
    }
    return bestT;
  }

  // B'(t) = A + t·D, so speed² = a·t² + b·t + c0 (see [_quadraticSpeedCoeffs]).
  @override
  double paramAtLength(double distance) {
    final (a, b, c0) = quadraticSpeedCoeffs(p1, c, p2);
    final total = _quadraticArcLengthAt(a, b, c0, 1.0);
    if (total <= 1e-12) return 0.0;
    final target = distance.clamp(0.0, total);

    // Newton's method on the exact S(t) = target, using the exact speed as
    // S'(t) -- converges quadratically, unlike bisecting against an
    // approximate, tolerance-limited length.
    var t = (target / total).clamp(0.0, 1.0);
    for (int i = 0; i < 8; i++) {
      final speed = quadraticSpeed(a, b, c0, t);
      if (speed < 1e-12) break;
      t = (t - (_quadraticArcLengthAt(a, b, c0, t) - target) / speed).clamp(
        0.0,
        1.0,
      );
    }
    return t;
  }

  @override
  QuadraticSegment transform(Affine2d affine) => QuadraticSegment(
    p1: affine.apply(p1),
    p2: affine.apply(p2),
    c: affine.apply(c),
  );

  @override
  (QuadraticSegment, QuadraticSegment) bifurcateAtInterval(double t) {
    final curve1cp = LineSegment(p1, c).lerp(t);
    final curve2cp = LineSegment(c, p2).lerp(t);
    final bridge = LineSegment(curve1cp, curve2cp).lerp(t);
    return (
      QuadraticSegment(p1: p1, p2: bridge, c: curve1cp),
      QuadraticSegment(p1: bridge, p2: p2, c: curve2cp),
    );
  }

  @override
  double get length {
    final (a, b, c0) = quadraticSpeedCoeffs(p1, c, p2);
    return _quadraticArcLengthAt(a, b, c0, 1.0);
  }

  CubicSegment toCubic() => CubicSegment(
    p1: p1,
    p2: p2,
    c1: p1 * (1 / 3.0) + c * (2 / 3.0),
    c2: c * (2 / 3.0) + p2 * (1 / 3.0),
  );

  @override
  P getPointByAddress(PointId id) => switch (id) {
    PointId.p1 => p1,
    PointId.c1 => c,
    PointId.p2 => p2,
    _ => throw ArgumentError('QuadraticSegment has no point $id'),
  };

  @override
  List<TangiblePointAddress> getPointAddresses() => [
    TangiblePointAddress(segment: this, name: PointId.p1),
    TangiblePointAddress(segment: this, name: PointId.c1),
    TangiblePointAddress(segment: this, name: PointId.p2),
  ];

  @override
  Segment updateByPointAddresses(Map<TangiblePointAddress, P> updates) {
    var np1 = p1, nc = c, np2 = p2;
    for (final e in updates.entries) {
      switch (e.key.name) {
        case PointId.p1:
          np1 = e.value;
        case PointId.c1:
          nc = e.value;
        case PointId.p2:
          np2 = e.value;
        default:
          throw ArgumentError('QuadraticSegment has no point ${e.key.name}');
      }
    }
    return QuadraticSegment(p1: np1, c: nc, p2: np2);
  }

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
  CoincidentOverlap? coincidentOverlap(Segment other) {
    if (other is CircularArcSegment || other is ArcSegment) return null;
    if (other is QuadraticSegment) return bezierCoincidentOverlap(this, other);
    return overlapFromBoundaries(
      this,
      other,
      ilerp(other.p1),
      ilerp(other.p2),
      other.ilerp(p1),
      other.ilerp(p2),
    );
  }

  @override
  List<P> intersect(Segment other) {
    if (other is LineSegment) return intersectLine(other);
    if (other is QuadraticSegment) return intersectQuadratic(other);
    if (other is CircularArcSegment) return intersectCircularArc(other);
    if (other is ArcSegment) return intersectArc(other);
    if (other is CubicSegment) return other.intersect(this);
    throw ArgumentError(
      'QuadraticSegment.intersect with ${other.runtimeType} not implemented',
    );
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
    final res =
        fp * fp * (a * a) +
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
        .where(ca.containsPointAngle)
        .toList();
  }

  // Transform this quadratic into the ellipse's unit-circle space; find where
  // the transformed curve hits the unit circle → degree-4 poly.
  List<P> intersectArc(ArcSegment a) {
    final T = a.ellipse.inverseUnitCircleTransform;
    final tp1 = T.apply(p1), tcp = T.apply(c), tp2 = T.apply(p2);
    final ux = Polynomial([
      tp1.x,
      2 * (tcp.x - tp1.x),
      tp1.x - 2 * tcp.x + tp2.x,
    ]);
    final uy = Polynomial([
      tp1.y,
      2 * (tcp.y - tp1.y),
      tp1.y - 2 * tcp.y + tp2.y,
    ]);
    final poly = ux * ux + uy * uy + Polynomial([-1.0]);
    const eps = 1e-9;
    return ClosedFormMethod.instance
        .realRoots(poly)
        .where((t) => t >= -eps && t <= 1 + eps)
        .map((t) => lerp(t.clamp(0.0, 1.0)))
        .where(a.containsPointAngle)
        .toList();
  }

  // B(t) = (1-t)²p1 + 2t(1-t)c + t²p2, so B'(t) = A + t·D with A = 2(c - p1)
  // and D = 2(p1 - 2c + p2) -- affine in t, making speed² = |B'(t)|² a plain
  // quadratic in t: a·t² + b·t + c0 with a = D·D, b = 2·A·D, c0 = A·A.
  static (double, double, double) quadraticSpeedCoeffs(P p1, P c, P p2) {
    final a = (c - p1) * 2;
    final d = (p1 - c * 2 + p2) * 2;
    return (d.dot(d), 2 * a.dot(d), a.dot(a));
  }

  static double quadraticSpeed(double a, double b, double c0, double t) =>
      sqrt(max(a * t * t + b * t + c0, 0.0));
}

// Checks whether [pt] lies on quadratic [q] within [0,1] by solving the
// 1-D inverse: x2(s)=pt.x or y2(s)=pt.y and verifying by distance.
bool _onQuadratic(
  QuadraticSegment q,
  P pt,
  double c22x,
  double c21x,
  double c20x,
  double c22y,
  double c21y,
  double c20y,
) {
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

/// `∫₀ᵗ sqrt(a·s² + b·s + c0) ds` -- the exact arc length from `p1` to `t`,
/// via the standard closed-form antiderivative of a square root of a
/// quadratic (an algebraic term plus an [_asinh] term). Exact and
/// scale-independent, unlike a fixed-tolerance recursive subdivision.
double _quadraticArcLengthAt(double a, double b, double c0, double t) {
  if (a <= 1e-12) return sqrt(max(c0, 0.0)) * t; // D ≈ 0: constant speed.

  double antiderivative(double s) {
    final f = max(a * s * s + b * s + c0, 0.0);
    final term1 = (2 * a * s + b) / (4 * a) * sqrt(f);
    final disc = 4 * a * c0 - b * b;
    if (disc <= 1e-12) return term1; // degenerate: speed touches zero.
    final sqrtDisc = sqrt(disc);
    return term1 +
        disc / (8 * pow(a, 1.5)) * _asinh((2 * a * s + b) / sqrtDisc);
  }

  return antiderivative(t) - antiderivative(0);
}

double _asinh(double x) =>
    x >= 0 ? log(x + sqrt(x * x + 1)) : -log(sqrt(x * x + 1) - x);

double quadraticBezierLerp(double p0, double p1, double p2, double t) =>
    (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2;

extension TupleExt<T> on (T, T) {
  List<T> toList() => [$1, $2];
}
