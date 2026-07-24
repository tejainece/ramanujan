import 'dart:math';

import 'package:polynomial/polynomial.dart';
import 'package:ramanujan/ramanujan.dart';

import 'root_finding.dart';

///
class CubicSegment extends Segment {
  @override
  final P p1;
  @override
  final P p2;

  final P c1;
  final P c2;

  CubicSegment({
    required this.p1,
    required this.p2,
    required this.c1,
    required this.c2,
  });

  @override
  List<P> get controlPoints => [c1, c2];

  @override
  LineSegment get p1Tangent => LineSegment(p1, c1);

  @override
  LineSegment get p2Tangent => LineSegment(c2, p2);

  @override
  double get length {
    final (q4, q3, q2, q1, q0) = _cubicSpeedCoeffs(p1, c1, c2, p2);
    return _cubicArcLengthAt(q4, q3, q2, q1, q0, 1.0);
  }

  @override
  P lerp(double t) => P(
    cubicBezierLerp(p1.x, c1.x, c2.x, p2.x, t),
    cubicBezierLerp(p1.y, c1.y, c2.y, p2.y, t),
  );

  // B'(t) = 3(1-t)²(c1 - p1) + 6(1-t)t(c2 - c1) + 3t²(p2 - c2)
  @override
  P unitTangentAt(double t) {
    final u = 1 - t;
    return ((c1 - p1) * (3 * u * u) +
            (c2 - c1) * (6 * u * t) +
            (p2 - c2) * (3 * t * t))
        .normalized;
  }

  @override
  double ilerp(P point, {double epsilon = 1e-3}) {
    // Invert B(t) per coordinate analytically (Cardano) and return the root in
    // [0,1] whose point matches; NaN when [point] is not on the curve.
    const eps = 1e-9;
    for (final t in [
      ..._inverseCubicBezier(p1.x, c1.x, c2.x, p2.x, point.x),
      ..._inverseCubicBezier(p1.y, c1.y, c2.y, p2.y, point.y),
    ]) {
      if (t < -eps || t > 1 + eps) continue;
      if (lerp(t.clamp(0.0, 1.0)).distanceTo(point) < epsilon) return t;
    }
    return double.nan;
  }

  @override
  double closestT(P point) {
    // Stationary points of |B(t) - point|²: (B(t) - point)·B'(t) is degree 5 —
    // past the closed-form limit — so its roots in [0,1] are found numerically,
    // like the intersection code. The minimum is at a root or an endpoint.
    final dx = Polynomial(_cubicCoeffs(p1.x, c1.x, c2.x, p2.x)..[0] -= point.x);
    final dy = Polynomial(_cubicCoeffs(p1.y, c1.y, c2.y, p2.y)..[0] -= point.y);
    final f = dx * dx.derivative() + dy * dy.derivative();
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
    for (final t in _rootsInUnit(f)) {
      consider(t);
    }
    return bestT;
  }

  @override
  double paramAtLength(double distance) {
    final (q4, q3, q2, q1, q0) = _cubicSpeedCoeffs(p1, c1, c2, p2);
    final total = _cubicArcLengthAt(q4, q3, q2, q1, q0, 1.0);
    if (total <= 1e-12) return 0.0;
    final target = distance.clamp(0.0, total);
    double g(double t) => _cubicArcLengthAt(q4, q3, q2, q1, q0, t) - target;
    return brentRoot(g, 0.0, 1.0);
  }

  @override
  CubicSegment transform(Affine2d affine) => CubicSegment(
    p1: affine.apply(p1),
    p2: affine.apply(p2),
    c1: affine.apply(c1),
    c2: affine.apply(c2),
  );

  @override
  (CubicSegment, CubicSegment) bifurcateAtInterval(double t) {
    final path1c1 = LineSegment(p1, c1).lerp(t);
    final a = LineSegment(c1, c2).lerp(t);
    final path2c2 = LineSegment(c2, p2).lerp(t);
    final path1c2 = LineSegment(path1c1, a).lerp(t);
    final path2c1 = LineSegment(a, path2c2).lerp(t);
    final path1p2 = LineSegment(path1c2, path2c1).lerp(t);
    return (
      CubicSegment(p1: p1, p2: path1p2, c1: path1c1, c2: path1c2),
      CubicSegment(p1: path1p2, p2: p2, c1: path2c1, c2: path2c2),
    );
  }

  @override
  P getPointByAddress(PointId id) => switch (id) {
    PointId.p1 => p1,
    PointId.c1 => c1,
    PointId.c2 => c2,
    PointId.p2 => p2,
    _ => throw ArgumentError('CubicSegment has no point $id'),
  };

  @override
  List<TangiblePointAddress> getPointAddresses() => [
    TangiblePointAddress(segment: this, name: PointId.p1),
    TangiblePointAddress(segment: this, name: PointId.c1),
    TangiblePointAddress(segment: this, name: PointId.c2),
    TangiblePointAddress(segment: this, name: PointId.p2),
  ];

  @override
  Segment updateByPointAddresses(Map<TangiblePointAddress, P> updates) {
    var np1 = p1, nc1 = c1, nc2 = c2, np2 = p2;
    for (final e in updates.entries) {
      switch (e.key.name) {
        case PointId.p1:
          np1 = e.value;
        case PointId.c1:
          nc1 = e.value;
        case PointId.c2:
          nc2 = e.value;
        case PointId.p2:
          np2 = e.value;
        default:
          throw ArgumentError('CubicSegment has no point ${e.key.name}');
      }
    }
    return CubicSegment(p1: np1, c1: nc1, c2: nc2, p2: np2);
  }

  @override
  CubicSegment reversed() => CubicSegment(p1: p2, p2: p1, c1: c2, c2: c1);

  @override
  bool operator ==(Object other) =>
      other is CubicSegment &&
      other.p1 == p1 &&
      other.p2 == p2 &&
      other.c1 == c1 &&
      other.c2 == c2;

  @override
  int get hashCode => Object.hash(p1, p2, c1, c2);

  @override
  /// https://iquilezles.org/articles/bezierbbox/
  ///
  /// Finds where the derivative (a quadratic in t) is zero, per axis. When
  /// the axis's control points are equally spaced from the endpoints on that
  /// axis (e.g. `c1.y == c2.y` for a symmetric hump), the quadratic's leading
  /// coefficient is zero and the derivative is linear instead, with a single
  /// root — handled separately so it isn't lost to a division by zero.
  R get boundingBox {
    R ret = R.fromPoints(p1, p2);

    P c = -p1 + c1;
    P b = p1 - c1 * 2 + c2;
    P a = -p1 + c1 * 3 - c2 * 3 + p2;

    const eps = 1e-9;

    void includeRootX(double t) {
      if (t <= 0 || t >= 1) return;
      double s = 1 - t;
      ret = ret.includeX(
        s * s * s * p1.x +
            3 * s * s * t * c1.x +
            3 * s * t * t * c2.x +
            t * t * t * p2.x,
      );
    }

    void includeRootY(double t) {
      if (t <= 0 || t >= 1) return;
      double s = 1 - t;
      ret = ret.includeY(
        s * s * s * p1.y +
            3 * s * s * t * c1.y +
            3 * s * t * t * c2.y +
            t * t * t * p2.y,
      );
    }

    if (a.x.abs() < eps) {
      if (b.x.abs() >= eps) includeRootX(-c.x / (2 * b.x));
    } else {
      final hx = b.x * b.x - a.x * c.x;
      if (hx > 0) {
        final sq = sqrt(hx);
        includeRootX((-b.x - sq) / a.x);
        includeRootX((-b.x + sq) / a.x);
      }
    }

    if (a.y.abs() < eps) {
      if (b.y.abs() >= eps) includeRootY(-c.y / (2 * b.y));
    } else {
      final hy = b.y * b.y - a.y * c.y;
      if (hy > 0) {
        final sq = sqrt(hy);
        includeRootY((-b.y - sq) / a.y);
        includeRootY((-b.y + sq) / a.y);
      }
    }

    return ret;
  }

  // The cubic Bézier reduces every intersection to a single polynomial in this
  // segment's parameter t: degree 6 against a quadratic, circle or ellipse, and
  // degree 9 against another cubic. All exceed degree 4, so by Abel–Ruffini
  // there is no radical closed form; the coefficients are built exactly and the
  // real roots in [0,1] are found numerically (see [_rootsInUnit]).
  @override
  CoincidentOverlap? coincidentOverlap(Segment other) {
    if (other is CircularArcSegment || other is ArcSegment) return null;
    if (other is CubicSegment) return bezierCoincidentOverlap(this, other);
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
    if (other is CubicSegment) return intersectCubic(other);
    if (other is CircularArcSegment) return intersectCircularArc(other);
    if (other is ArcSegment) return intersectArc(other);
    throw ArgumentError(
      'CubicSegment.intersect with ${other.runtimeType} not implemented',
    );
  }

  List<P> intersectLine(LineSegment l) => l.intersectCubic(this);

  // Substitute the cubic into the circle equation (B(t)-center)²=r² → degree-6
  // polynomial in t.
  List<P> intersectCircularArc(CircularArcSegment ca) {
    final r = ca.effectiveRadius;
    final ax = _cubicCoeffs(p1.x, c1.x, c2.x, p2.x);
    final ay = _cubicCoeffs(p1.y, c1.y, c2.y, p2.y);
    final x = Polynomial([ax[0] - ca.center.x, ax[1], ax[2], ax[3]]);
    final y = Polynomial([ay[0] - ca.center.y, ay[1], ay[2], ay[3]]);
    final f = x * x + y * y - r * r;
    return _rootsInUnit(f).map(lerp).where(ca.containsPointAngle).toList();
  }

  // Transform the cubic into the ellipse's unit-circle space; intersect the
  // transformed cubic with the unit circle → degree-6 polynomial in t.
  List<P> intersectArc(ArcSegment arc) {
    final t = arc.ellipse.inverseUnitCircleTransform;
    final tp1 = t.apply(p1),
        tc1 = t.apply(c1),
        tc2 = t.apply(c2),
        tp2 = t.apply(p2);
    final x = Polynomial(_cubicCoeffs(tp1.x, tc1.x, tc2.x, tp2.x));
    final y = Polynomial(_cubicCoeffs(tp1.y, tc1.y, tc2.y, tp2.y));
    final f = x * x + y * y - 1.0;
    return _rootsInUnit(f).map(lerp).where(arc.containsPointAngle).toList();
  }

  // Eliminate the quadratic's parameter s from Q(s)=B(t) via a resultant in t;
  // the result is a degree-6 polynomial in t.
  List<P> intersectQuadratic(QuadraticSegment q) => _intersectParametric(
    [q.p1.x, 2 * (q.c.x - q.p1.x), q.p1.x - 2 * q.c.x + q.p2.x],
    [q.p1.y, 2 * (q.c.y - q.p1.y), q.p1.y - 2 * q.c.y + q.p2.y],
    (p) => !q.ilerp(p).isNaN,
  );

  // Eliminate the other cubic's parameter s from O(s)=B(t) via a resultant in t;
  // the result is a degree-9 polynomial in t.
  List<P> intersectCubic(CubicSegment o) => _intersectParametric(
    _cubicCoeffs(o.p1.x, o.c1.x, o.c2.x, o.p2.x),
    _cubicCoeffs(o.p1.y, o.c1.y, o.c2.y, o.p2.y),
    (p) => !o.ilerp(p).isNaN,
  );

  /// Intersects this cubic with another polynomial parametric curve whose
  /// coordinate coefficients (constant-first, in the other curve's parameter s)
  /// are [oxS]/[oyS]. The other parameter s is eliminated by the Sylvester
  /// resultant of `Oₓ(s)-Bₓ(t)` and `Oᵧ(s)-Bᵧ(t)`, yielding one polynomial in
  /// t; each real root in [0,1] is kept when its point also lies on the other
  /// curve ([onOther]). The resultant adapts to the other curve's true degree,
  /// so a degenerate (e.g. straight or axis-aligned) input is handled too.
  List<P> _intersectParametric(
    List<double> oxS,
    List<double> oyS,
    bool Function(P) onOther,
  ) {
    final cx = _cubicCoeffs(p1.x, c1.x, c2.x, p2.x);
    final cy = _cubicCoeffs(p1.y, c1.y, c2.y, p2.y);
    // f(s) = O_x(s) - B_x(t): only the s⁰ term carries t (a degree-3 poly).
    final f = <Polynomial>[
      Polynomial([oxS[0] - cx[0], -cx[1], -cx[2], -cx[3]]),
      for (int i = 1; i < oxS.length; i++) Polynomial([oxS[i]]),
    ];
    final g = <Polynomial>[
      Polynomial([oyS[0] - cy[0], -cy[1], -cy[2], -cy[3]]),
      for (int i = 1; i < oyS.length; i++) Polynomial([oyS[i]]),
    ];
    return _rootsInUnit(_resultant(f, g)).map(lerp).where(onOther).toList();
  }
}

/// Sylvester resultant in t of two polynomials in s, [f] and [g], whose
/// coefficients (constant-first in s) are themselves polynomials in t. Trailing
/// (high-degree) zero coefficients are dropped first, so the matrix is sized to
/// each input's true degree in s — the resultant degenerates correctly when a
/// curve is lower degree than its container allows.
Polynomial _resultant(List<Polynomial> f, List<Polynomial> g) {
  List<Polynomial> trim(List<Polynomial> c) {
    var hi = c.length - 1;
    while (hi > 0 && c[hi].isZero) {
      hi--;
    }
    return c.sublist(0, hi + 1);
  }

  final fc = trim(f), gc = trim(g);
  final m = fc.length - 1, n = gc.length - 1; // degrees in s
  if (m == 0 && n == 0) return Polynomial([1]); // no parameter to share
  final zero = Polynomial([0]);
  final fHi = fc.reversed.toList(); // [fₘ … f₀]
  final gHi = gc.reversed.toList();
  final size = m + n;
  final mat = [
    for (int i = 0; i < size; i++) List<Polynomial>.filled(size, zero),
  ];
  for (int r = 0; r < n; r++) {
    for (int k = 0; k < fHi.length; k++) {
      mat[r][r + k] = fHi[k];
    }
  }
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < gHi.length; k++) {
      mat[n + r][r + k] = gHi[k];
    }
  }
  return _polyDet(mat);
}

/// Determinant of a square matrix of polynomials by cofactor expansion (sizes
/// here are ≤ 6, so the factorial cost is negligible and only +,−,× are used).
Polynomial _polyDet(List<List<Polynomial>> m) {
  final n = m.length;
  if (n == 1) return m[0][0];
  if (n == 2) return m[0][0] * m[1][1] - m[0][1] * m[1][0];
  var sum = Polynomial([0]);
  for (int c = 0; c < n; c++) {
    final minor = [
      for (int i = 1; i < n; i++)
        [
          for (int j = 0; j < n; j++)
            if (j != c) m[i][j],
        ],
    ];
    final term = m[0][c] * _polyDet(minor);
    sum = c.isEven ? sum + term : sum - term;
  }
  return sum;
}

/// Cubic Bézier coordinate coefficients `[a0, a1, a2, a3]` (constant-first, as
/// [Polynomial] expects) so that `B(t) = a0 + a1·t + a2·t² + a3·t³` for the
/// control values [p0]..[p3].
List<double> _cubicCoeffs(double p0, double p1, double p2, double p3) => [
  p0,
  3 * (p1 - p0),
  3 * (p0 - 2 * p1 + p2),
  -p0 + 3 * p1 - 3 * p2 + p3,
];

/// Real roots of [f] in [0,1]. The cubic intersection polynomials are degree
/// 6–9 — past the degree-4 limit of any closed-form (radical) solver — so the
/// roots are found numerically: bracket sign changes on a dense sample and
/// refine each by bisection. Tangential (even-multiplicity) roots leave no sign
/// change, so they are recovered as extrema of [f] where `f ≈ 0` relative to
/// its own scale.
List<double> _rootsInUnit(Polynomial f) {
  if (f.degree < 1) return const [];
  const n = 1000;
  final df = f.derivative();

  final roots = <double>[];
  void add(double r) {
    final rc = r.clamp(0.0, 1.0);
    for (final q in roots) {
      if ((q - rc).abs() < 1e-7) return;
    }
    roots.add(rc);
  }

  // Refine a sign-change bracket [a,b] of [p] to a root by bisection.
  double bisect(Polynomial p, double a, double b, double fa) {
    for (int k = 0; k < 60; k++) {
      final m = 0.5 * (a + b);
      final fm = p(m);
      if (fm == 0) return m;
      if ((fa < 0) != (fm < 0)) {
        b = m;
      } else {
        a = m;
        fa = fm;
      }
    }
    return 0.5 * (a + b);
  }

  // Transversal crossings: sign changes of f.
  double xa = 0, fa = f(0), maxAbs = fa.abs();
  if (fa == 0) add(0);
  for (int i = 1; i <= n; i++) {
    final xb = i / n;
    final fb = f(xb);
    if (fb.abs() > maxAbs) maxAbs = fb.abs();
    if (fb == 0) {
      add(xb);
    } else if ((fa < 0) != (fb < 0)) {
      add(bisect(f, xa, xb, fa));
    }
    xa = xb;
    fa = fb;
  }

  // Tangencies: extrema of f (sign changes of f') at which f vanishes.
  if (df.degree >= 1) {
    final tol = 1e-7 * (maxAbs == 0 ? 1 : maxAbs);
    double ea = 0, da = df(0);
    for (int i = 1; i <= n; i++) {
      final eb = i / n;
      final db = df(eb);
      if (db != 0 && (da < 0) != (db < 0)) {
        final e = bisect(df, ea, eb, da);
        if (f(e).abs() < tol) add(e);
      }
      ea = eb;
      da = db;
    }
  }
  return roots;
}

// B'(t) = A + B·t + C·t² (vector quadratic); |B'(t)|² is then an exact
// quartic in t, q4·t⁴+q3·t³+q2·t²+q1·t+q0.
(double, double, double, double, double) _cubicSpeedCoeffs(
  P p1,
  P c1,
  P c2,
  P p2,
) {
  final a = (c1 - p1) * 3;
  final b = (p1 - c1 * 2 + c2) * 6;
  final c = (p2 - p1 + (c1 - c2) * 3) * 3;
  return (
    c.dot(c),
    2 * b.dot(c),
    b.dot(b) + 2 * a.dot(c),
    2 * a.dot(b),
    a.dot(a),
  );
}

// Arc length from 0 to t of a cubic Bézier via fixed 24-point Gauss-Legendre
// quadrature on the exact quartic speed² above. |B'| is real-analytic
// wherever it's nonzero, so the quadrature error shrinks geometrically in the
// point count (a classical, computable bound -- not "converged in practice"):
// 24 points puts the error at the machine-epsilon floor for any non-cusped
// cubic. Root-finding on top of this (see [CubicSegment.paramAtLength]) uses
// Brent's method, which has its own independent convergence guarantee.
//
// Exception: a control polygon so extreme that B'(t) nearly vanishes inside
// (0,1) (e.g. a near-self-intersecting "bowtie") pushes a singularity of the
// integrand close to the real line, degrading convergence from geometric to
// algebraic -- length stays in the right ballpark but may be off by ~1e-3
// relative. Ordinary (non-degenerate) cubics are unaffected.
double _cubicArcLengthAt(
  double q4,
  double q3,
  double q2,
  double q1,
  double q0,
  double t,
) {
  if (t <= 0) return 0.0;
  final (nodes, weights) = _gaussLegendre24;
  final half = t / 2;
  var sum = 0.0;
  for (var i = 0; i < nodes.length; i++) {
    final s = half * (nodes[i] + 1);
    final speed2 = (((q4 * s + q3) * s + q2) * s + q1) * s + q0;
    sum += weights[i] * sqrt(max(speed2, 0.0));
  }
  return half * sum;
}

// Nodes/weights for 24-point Gauss-Legendre quadrature on [-1,1], computed
// once via Newton's method on the Legendre polynomial (Numerical Recipes
// §4.5 `gauleg`). Each root is isolated and approached from an asymptotic
// initial guess, so convergence to machine precision in a handful of
// iterations is guaranteed by the polynomial's structure, not hoped for.
final (List<double>, List<double>) _gaussLegendre24 =
    _gaussLegendreNodesWeights(24);

(List<double>, List<double>) _gaussLegendreNodesWeights(int n) {
  final x = List<double>.filled(n, 0.0);
  final w = List<double>.filled(n, 0.0);
  final m = (n + 1) ~/ 2;
  for (var i = 0; i < m; i++) {
    var z = cos(pi * (i + 0.75) / (n + 0.5));
    late double pp;
    while (true) {
      var p1 = 1.0, p2 = 0.0;
      for (var j = 1; j <= n; j++) {
        final p3 = p2;
        p2 = p1;
        p1 = ((2 * j - 1) * z * p2 - (j - 1) * p3) / j;
      }
      pp = n * (z * p1 - p2) / (z * z - 1);
      final z1 = z;
      z = z1 - p1 / pp;
      if ((z - z1).abs() < 1e-15) break;
    }
    x[i] = -z;
    x[n - 1 - i] = z;
    w[i] = 2 / ((1 - z * z) * pp * pp);
    w[n - 1 - i] = w[i];
  }
  return (x, w);
}

/// Real roots t of the cubic Bézier coordinate B(t) = [v] for control values
/// [p0]..[p3] — the analytic inverse of [cubicBezierLerp] for one axis.
List<double> _inverseCubicBezier(
  double p0,
  double p1,
  double p2,
  double p3,
  double v,
) {
  final a = -p0 + 3 * p1 - 3 * p2 + p3;
  final b = 3 * (p0 - 2 * p1 + p2);
  final c = 3 * (p1 - p0);
  final d = p0 - v;
  return _cubicRealRoots(a, b, c, d);
}

/// Real roots of a·t³ + b·t² + c·t + d = 0 by Cardano's method, degenerating
/// to the quadratic/linear formula when leading coefficients vanish.
List<double> _cubicRealRoots(double a, double b, double c, double d) {
  const eps = 1e-12;
  if (a.abs() < eps) {
    // Quadratic b·t² + c·t + d.
    if (b.abs() < eps) return c.abs() < eps ? const [] : [-d / c];
    final disc = c * c - 4 * b * d;
    if (disc < 0) return const [];
    final sq = sqrt(disc);
    return [(-c + sq) / (2 * b), (-c - sq) / (2 * b)];
  }
  // Depressed cubic x³ + p·x + q via t = x - b/(3a).
  final p = (3 * a * c - b * b) / (3 * a * a);
  final q = (2 * b * b * b - 9 * a * b * c + 27 * a * a * d) / (27 * a * a * a);
  final shift = b / (3 * a);
  final disc = q * q / 4 + p * p * p / 27;
  if (disc > eps) {
    // One real root.
    final sq = sqrt(disc);
    return [_cbrt(-q / 2 + sq) + _cbrt(-q / 2 - sq) - shift];
  }
  if (disc < -eps) {
    // Three distinct real roots (trigonometric form; here p < 0).
    final m = 2 * sqrt(-p / 3);
    final theta = acos(((3 * q) / (p * m)).clamp(-1.0, 1.0)) / 3;
    return [
      for (int k = 0; k < 3; k++) m * cos(theta - 2 * pi * k / 3) - shift,
    ];
  }
  // disc ≈ 0: a repeated root.
  final u = _cbrt(-q / 2);
  return [2 * u - shift, -u - shift];
}

/// Real cube root, handling negative arguments (`pow` does not).
double _cbrt(double x) =>
    x < 0 ? -pow(-x, 1 / 3).toDouble() : pow(x, 1 / 3).toDouble();

double cubicBezierLerp(double p0, double p1, double p2, double p3, double t) =>
    (1 - t) * (1 - t) * (1 - t) * p0 +
    3 * (1 - t) * (1 - t) * t * p1 +
    3 * (1 - t) * t * t * p2 +
    t * t * t * p3;
