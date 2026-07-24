import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

/// ((x-h)*cosθ + (y-k)*sinθ)^2/r1^2 + ((x-h)*sinθ - (y-k)^cosθ)*2/r2^2 - 1 = 0
class Ellipse implements ClosedShape {
  final P center;

  final P radii;

  final double rotation;

  Ellipse(this.radii, {this.center = origin, this.rotation = 0});

  factory Ellipse.fromR(R rect) =>
      Ellipse(P(rect.width / 2, rect.height / 2), center: rect.center);

  factory Ellipse.fromSvgParameters(
    P p1,
    P p2,
    P radii, {
    double rotation = 0,
    bool clockwise = false,
    bool largeArc = false,
  }) {
    final d = P((p1.x - p2.x) / 2, (p1.y - p2.y) / 2);
    if (d.isEqual(origin)) {
      // Degenerate ellipse
      P center = P(-radii.x, 0).rotate(pi + rotation) + p1;
      return Ellipse(radii, center: center, rotation: rotation);
    }
    final costh = cos(rotation);
    final sinth = sin(rotation);
    final transformed = P(
      d.x * costh + d.y * sinth,
      d.x * -sinth + d.y * costh,
    );
    final rx = radii.x;
    final ry = radii.y;
    final rx2 = rx * rx;
    final ry2 = ry * ry;
    final tx2 = transformed.x * transformed.x;
    final ty2 = transformed.y * transformed.y;
    var factor = sqrt(
      (rx2 * ry2 - rx2 * ty2 - ry2 * tx2) / (rx2 * ty2 + ry2 * tx2),
    );
    if (largeArc == clockwise) {
      factor = -factor;
    }
    final centerTransformed = P(
      factor * (rx * transformed.y) / ry,
      -factor * (ry * transformed.x) / rx,
    );
    final chordMid = (p1 + p2) / 2;
    final center = P(
      costh * centerTransformed.x - sinth * centerTransformed.y + chordMid.x,
      sinth * centerTransformed.x + costh * centerTransformed.y + chordMid.y,
    );
    return Ellipse(radii, center: center, rotation: rotation);
  }

  /// Returns this path as an (possibly rotated) [Ellipse] if it exactly
  /// matches the cubic bezier approximation [toLoop] produces, or null
  /// otherwise. Mirrors [Circle.fromVectorPath], but allows unequal x/y
  /// radii and recovers the rotation. An axis-aligned path detects with
  /// rotation 0.
  static Ellipse? fromVectorPath(VectorPath path) {
    if (!path.isClosed()) return null;
    final segments = path.segments;
    if (segments.length != 4) return null;

    if (segments.any((s) => s is! CubicSegment)) return null;

    // In the loop [toLoop] produces, the four on-curve points are the axis
    // endpoints — top, right, bottom, left, rotated together for a rotated
    // ellipse. Opposite endpoints must agree on the center.
    final top = (segments[0] as CubicSegment).p1;
    final right = (segments[1] as CubicSegment).p1;
    final bottom = (segments[2] as CubicSegment).p1;
    final left = (segments[3] as CubicSegment).p1;

    final center = (top + bottom) / 2;
    if (!center.isEqual((left + right) / 2, 1e-6)) return null;

    final radiusX = (right - center).length;
    final radiusY = (top - center).length;
    if (radiusX <= 0 || radiusY <= 0) return null;

    // The x axis's direction carries the rotation. The candidate ellipse it
    // implies must reproduce the whole path, control points included — that
    // one comparison also rules out non-perpendicular axes and mismatched
    // opposite radii.
    final rotation = atan2(right.y - center.y, right.x - center.x);
    final candidate = Ellipse(
      P(radiusX, radiusY),
      center: center,
      rotation: rotation,
    );

    const eps = 1e-4;
    final expected = candidate.toLoop().segments;
    for (var i = 0; i < 4; i++) {
      final actual = segments[i] as CubicSegment;
      final want = expected[i] as CubicSegment;
      if (!actual.p1.isEqual(want.p1, eps) ||
          !actual.c1.isEqual(want.c1, eps) ||
          !actual.c2.isEqual(want.c2, eps)) {
        return null;
      }
    }
    return candidate;
  }

  /// This ellipse as a closed [Loop] of four [CubicSegment]s (the standard
  /// kappa approximation), in the form [fromVectorPath] recognizes. A nonzero
  /// [rotation] is baked in by transforming the axis-aligned loop about
  /// [center].
  Loop toLoop() {
    final kappaX = 0.552284749831 * radii.x;
    final kappaY = 0.552284749831 * radii.y;
    final cx = center.x, cy = center.y;
    final rx = radii.x, ry = radii.y;
    var loop = Loop([
      CubicSegment(
        p1: P(cx, cy - ry),
        c1: P(cx + kappaX, cy - ry),
        c2: P(cx + rx, cy - kappaY),
        p2: P(cx + rx, cy),
      ),
      CubicSegment(
        p1: P(cx + rx, cy),
        c1: P(cx + rx, cy + kappaY),
        c2: P(cx + kappaX, cy + ry),
        p2: P(cx, cy + ry),
      ),
      CubicSegment(
        p1: P(cx, cy + ry),
        c1: P(cx - kappaX, cy + ry),
        c2: P(cx - rx, cy + kappaY),
        p2: P(cx - rx, cy),
      ),
      CubicSegment(
        p1: P(cx - rx, cy),
        c1: P(cx - rx, cy - kappaY),
        c2: P(cx - kappaX, cy - ry),
        p2: P(cx, cy - ry),
      ),
    ]);
    if (rotation != 0) {
      final affine = Affine2d(
        translateX: cx,
        translateY: cy,
      ).rotate(rotation).translate(-cx, -cy);
      loop = loop.transform(affine);
    }
    return loop;
  }

  /// Returns the affine transformation that maps the unit circle to this ellipse
  late final Affine2d unitCircleTransform = Affine2d(
    translateX: center.x,
    translateY: center.y,
  ).rotate(rotation).scale(radii.x, radii.y);

  /// Returns the affine transformation that maps this ellipse to the unit circle
  late final Affine2d inverseUnitCircleTransform = Affine2d(
    scaleX: 1 / radii.x,
    scaleY: 1 / radii.y,
  ).rotate(-rotation).translate(-center.x, -center.y);

  Ellipse canonicalForm() {
    if (radii.x == radii.y) {
      return Ellipse(radii, center: center, rotation: 0);
    }
    double rotation = this.rotation;
    if (rotation < 0) {
      rotation += pi;
    }
    if (rotation >= pi / 2) {
      return Ellipse(
        P(radii.y, radii.x),
        center: center,
        rotation: rotation - pi / 2,
      );
    }
    return Ellipse(radii, center: center, rotation: rotation);
  }

  P pointAtAngle(double angle) {
    final unitCircleTransform = this.unitCircleTransform;
    return unitCircleTransform.apply(P.onCircle(angle));
  }

  Radian angleOfPoint(P point) {
    final inverseUnitCircleTransform = this.inverseUnitCircleTransform;
    final transformedPoint = inverseUnitCircleTransform.apply(point);
    return transformedPoint.angle;
  }

  double tAtPoint(P point) => ilerp(point);

  double tAtAngle(double radians) {
    radians = Radian(radians).value;
    int n = radians ~/ (pi / 2);
    double remainder = radians - n * (pi / 2);

    double ret = n / 4.0;
    if (n.isOdd) {
      remainder = pi / 2 - remainder;
    }
    ret += atan(radii.y * tan(remainder) / radii.x) / (2 * pi);
    return ret;
  }

  double angleAtT(double t) {
    t = Clamp.unit.clamp(t);
    int n = t ~/ 0.25;
    double remainder = t - n * 0.25;

    double ret = n * (pi / 2);
    if (n.isOdd) {
      remainder = 0.25 - remainder;
    }
    ret += atan(radii.y * tan(remainder * pi / 2) / radii.x);
    return ret;
  }

  P lerp(double t) {
    t = Clamp.unit.clamp(t);
    t = 4 * t * (pi / 2);
    var ret = P(radii.x * cos(t), radii.y * sin(t));
    return ret.transform(
      Affine2d(translateX: center.x, translateY: center.y).rotate(rotation),
    );
  }

  P lerpBetweenPoints(P p1, P p2, double t, {bool clockwise = false}) {
    final t1 = ilerp(p1);
    final t2 = ilerp(p2);
    return lerpBetween(t1, t2, t, clockwise: clockwise);
  }

  P lerpBetween(double t1, double t2, double t, {bool clockwise = false}) {
    final forT = Clamp.unit.lerp(t1, t2, t, clockwise: clockwise);
    return lerp(forT);
  }

  double ilerp(P point) {
    final angle = angleOfPoint(point);
    return angle.value / (2 * pi);
  }

  double ilerpBetween(P p1, P p2, P p, {bool clockwise = false}) {
    final t1 = ilerp(p1);
    final t2 = ilerp(p2);
    final t = ilerp(p);
    return Clamp.unit.ilerp(t1, t2, t, clockwise: clockwise);
  }

  bool isEqual(Ellipse other, [double epsilon = 1e-3]) {
    if (!center.isEqual(other.center, epsilon)) return false;
    final a = canonicalForm();
    final b = other.canonicalForm();
    if (!a.radii.isEqual(b.radii, epsilon)) return false;
    if (!a.rotation.equals(b.rotation, epsilon)) return false;
    return true;
  }

  late final double h = () {
    final diff = radii.x - radii.y;
    final sum = radii.x + radii.y;
    return (diff * diff) / (sum * sum);
  }();

  late final double perimeterApprox = () {
    return pi * (radii.x + radii.y) * (1 + 3 * h / (10 + sqrt(4 - 3 * h)));
  }();

  // Complete elliptic integral of the second kind. Same for every quadrant
  // by the ellipse's 4-fold symmetry. To avoid numerical issues when
  // radii.y > radii.x (which makes m < 0 and potentially -Infinity), we
  // use the alternate parameterization which swaps the axes.
  late final double quart = () {
    if (radii.x >= radii.y) {
      return radii.x * _ellipticE(pi / 2, m);
    } else {
      return radii.y * _ellipticE(pi / 2, mAlt);
    }
  }();

  @override
  late final double perimeter = 4 * quart;

  // Evaluates ∫₀^radians √(radii.x² sin²θ + radii.y² cos²θ) dθ.
  // If radii.x >= radii.y, this equals radii.x · (E(m) − E(π/2−radians, m)).
  // If radii.y > radii.x, this equals radii.y · E(radians, mAlt).
  // [_ellipticE] handles any real argument via its quasi-periodic extension.
  double arcLengthAtAngle(double radians) {
    radians = Radian(radians).value;
    if (radii.x >= radii.y) {
      return quart - radii.x * _ellipticE(pi / 2 - radians, m);
    } else {
      return radii.y * _ellipticE(radians, mAlt);
    }
  }

  double arcLengthAtT(double t) =>
      arcLengthAtAngle(2 * pi * Clamp.unit.clamp(t));

  double arcLengthBetweenAngles(
    Radian start,
    Radian end, {
    bool clockwise = false,
  }) {
    final s = arcLengthAtAngle(start.value);
    final e = arcLengthAtAngle(end.value);
    if (clockwise) {
      return s >= e ? s - e : perimeter - (e - s);
    }
    return e >= s ? e - s : perimeter - (s - e);
  }

  double arcLengthBetweenT(double t1, double t2, {bool clockwise = false}) =>
      arcLengthBetweenAngles(
        Radian(2 * pi * t1),
        Radian(2 * pi * t2),
        clockwise: clockwise,
      );

  double arcLengthAtPoint(P point) =>
      arcLengthAtAngle(angleOfPoint(point).value);

  double arcLengthBetweenPoints(P p1, P p2, {bool clockwise = false}) =>
      arcLengthBetweenAngles(
        angleOfPoint(p1),
        angleOfPoint(p2),
        clockwise: clockwise,
      );

  double get m => 1 - (radii.y * radii.y) / (radii.x * radii.x);

  double get mAlt => 1 - (radii.x * radii.x) / (radii.y * radii.y);

  @override
  double get area => pi * radii.x * radii.y;

  /// Unit tangent direction at the eccentric angle [theta], pointing in the
  /// direction of increasing angle.
  ///
  /// The point is `unitCircleTransform.apply((cosθ, sinθ))`, so its derivative
  /// is the same transform's linear part applied to `(-sinθ, cosθ)` — which we
  /// recover as `apply(...) - center`. Reusing the transform keeps this exactly
  /// consistent with [pointAtAngle].
  P tangentDirAtAngle(double theta) =>
      (unitCircleTransform.apply(P(-sin(theta), cos(theta))) - center)
          .normalized;

  LineSegment tangentAtAngle(double radians) {
    final p = pointAtAngle(radians);
    return p.lineAlong(tangentDirAtAngle(radians));
  }

  LineSegment tangentAtT(double t) =>
      tangentAtAngle(2 * pi * Clamp.unit.clamp(t));

  LineSegment tangentAtPoint(P point) =>
      tangentAtAngle(angleOfPoint(point).value);

  ArcSegment arc(Radian start, Radian end, {bool? clockwise}) {
    clockwise ??= end < start;
    final largeArc =
        arcLengthBetweenAngles(start, end, clockwise: clockwise) >
        perimeter / 2;
    return ArcSegment(
      pointAtAngle(start.value),
      pointAtAngle(end.value),
      radii,
      rotation: rotation,
      largeArc: largeArc,
      clockwise: clockwise,
    );
  }

  @override
  R get boundingBox {
    final xs = xBounds();
    final ys = yBounds();
    return R.fromPoints(P(xs.$1, ys.$1), P(xs.$2, ys.$2));
  }

  (double, double) xBounds() {
    final axis = P(
      unitCircleTransform.elementAt(0),
      unitCircleTransform.elementAt(1),
    );
    var r = axis.length;
    var mid = unitCircleTransform.elementAt(2);
    return (mid - r, mid + r);
  }

  (({Radian angle, double value}), ({Radian angle, double value}))
  xBoundsWithAngle() {
    final axis = P(
      unitCircleTransform.elementAt(0),
      unitCircleTransform.elementAt(1),
    );
    var r = axis.length;
    var mid = unitCircleTransform.elementAt(2);
    final angle = axis.angle;
    return (
      (angle: angle, value: mid + r),
      (angle: angle + pi, value: mid - r),
    );
  }

  (double, double) yBounds() {
    final axis = P(
      unitCircleTransform.elementAt(3),
      unitCircleTransform.elementAt(4),
    );
    var r = axis.length;
    var mid = unitCircleTransform.elementAt(5);
    return (mid - r, mid + r);
  }

  (({Radian angle, double value}), ({Radian angle, double value}))
  yBoundsWithAngle() {
    final axis = P(
      unitCircleTransform.elementAt(3),
      unitCircleTransform.elementAt(4),
    );
    var r = axis.length;
    var mid = unitCircleTransform.elementAt(5);
    final angle = axis.angle;
    return (
      (angle: angle, value: mid + r),
      (angle: angle + pi, value: mid - r),
    );
  }

  static double ellepticE(double t, double m) {
    return integralRiemannSums(0, t, _ellipticIntegrand(m), 100);
  }

  static double Function(num t) _ellipticIntegrand(double m) {
    return (t) => sqrt(1 - pow(cos(t), 2) * m);
  }

  late final costh = cos(rotation);

  late final sinth = sin(rotation);

  @override
  bool containsPoint(P point) {
    final dp = point - center;
    double x2 = dp.x * costh + dp.y * sinth;
    x2 *= x2;
    double y2 = dp.x * sinth - dp.y * costh;
    y2 *= y2;
    double rx2 = radii.x;
    rx2 *= rx2;
    double ry2 = radii.y;
    ry2 *= ry2;
    return x2 / rx2 + y2 / ry2 <= 1;
  }

  @override
  bool isPointOn(P point) {
    final ys = evalY(point.x);
    if (ys.isEmpty) return false;
    return ys.any((y) => (y - point.y).abs() < 1e-6);
  }

  List<double> evalX(double y) {
    final y2 = y * y;
    final r1 = radii.x;
    final r12 = r1 * r1;
    final r2 = radii.y;
    final r22 = r2 * r2;
    final h = center.x;
    final k = center.y;
    final k2 = k * k;
    final sinth2 = sinth * sinth;
    final sinth4 = sinth2 * sinth2;
    final costh2 = costh * costh;
    final costh4 = costh2 * costh2;
    final x1 =
        costh2 * h * r22 / ((costh2 * r22 + sinth2 * r12)) -
        costh * y * sinth * r22 / ((costh2 * r22 + sinth2 * r12)) +
        costh * k * sinth * r22 / ((costh2 * r22 + sinth2 * r12)) +
        sinth2 * h * r12 / ((costh2 * r22 + sinth2 * r12)) +
        sinth * y * costh * r12 / ((costh2 * r22 + sinth2 * r12)) -
        sinth * k * costh * r12 / ((costh2 * r22 + sinth2 * r12)) +
        r2 *
            r1 *
            pow(
              -2 * costh2 * y2 * sinth2 +
                  4 * costh2 * y * sinth2 * k -
                  2 * costh2 * k2 * sinth2 +
                  costh2 * r22 -
                  costh4 * y2 +
                  2 * costh4 * y * k -
                  costh4 * k2 +
                  sinth2 * r12 -
                  sinth4 * y2 +
                  2 * sinth4 * y * k -
                  sinth4 * k2,
              0.5,
            ) /
            ((costh2 * r22 + sinth2 * r12));
    final ret = <double>[if (!x1.isNaN) x1];
    final x2 =
        costh2 * h * r22 / ((costh2 * r22 + sinth2 * r12)) -
        costh * y * sinth * r22 / ((costh2 * r22 + sinth2 * r12)) +
        costh * k * sinth * r22 / ((costh2 * r22 + sinth2 * r12)) +
        sinth2 * h * r12 / ((costh2 * r22 + sinth2 * r12)) +
        sinth * y * costh * r12 / ((costh2 * r22 + sinth2 * r12)) -
        sinth * k * costh * r12 / ((costh2 * r22 + sinth2 * r12)) -
        r2 *
            r1 *
            pow(
              -2 * costh2 * y2 * sinth2 +
                  4 * costh2 * y * sinth2 * k -
                  2 * costh2 * k2 * sinth2 +
                  costh2 * r22 -
                  costh4 * y2 +
                  2 * costh4 * y * k -
                  costh4 * k2 +
                  sinth2 * r12 -
                  sinth4 * y2 +
                  2 * sinth4 * y * k -
                  sinth4 * k2,
              0.5,
            ) /
            ((costh2 * r22 + sinth2 * r12));
    if (!x2.isNaN) {
      if (ret.every((v) => (v - x2).abs() > 1e-6)) ret.add(x2);
    }
    return ret;
  }

  List<double> evalY(double x) {
    final x2 = x * x;
    final r1 = radii.x;
    final r12 = r1 * r1;
    final r2 = radii.y;
    final r22 = r2 * r2;
    final h = center.x;
    final h2 = h * h;
    final k = center.y;
    final sinth2 = sinth * sinth;
    final sinth4 = sinth2 * sinth2;
    final costh2 = costh * costh;
    final costh4 = costh2 * costh2;
    final y1 =
        -x * costh * sinth * r22 / ((sinth2 * r22 + costh2 * r12)) +
        h * costh * sinth * r22 / ((sinth2 * r22 + costh2 * r12)) +
        sinth2 * k * r22 / ((sinth2 * r22 + costh2 * r12)) +
        x * sinth * costh * r12 / ((sinth2 * r22 + costh2 * r12)) -
        h * sinth * costh * r12 / ((sinth2 * r22 + costh2 * r12)) +
        costh2 * k * r12 / ((sinth2 * r22 + costh2 * r12)) +
        r2 *
            r1 *
            pow(
              -2 * x2 * costh2 * sinth2 +
                  4 * x * costh2 * sinth2 * h -
                  2 * h2 * costh2 * sinth2 +
                  sinth2 * r22 -
                  sinth4 * x2 +
                  2 * sinth4 * x * h -
                  sinth4 * h2 +
                  costh2 * r12 -
                  costh4 * x2 +
                  2 * costh4 * x * h -
                  costh4 * h2,
              0.5,
            ) /
            ((sinth2 * r22 + costh2 * r12));
    final ret = [if (!y1.isNaN) y1];
    final y2 =
        -x * costh * sinth * r22 / ((sinth2 * r22 + costh2 * r12)) +
        h * costh * sinth * r22 / ((sinth2 * r22 + costh2 * r12)) +
        sinth2 * k * r22 / ((sinth2 * r22 + costh2 * r12)) +
        x * sinth * costh * r12 / ((sinth2 * r22 + costh2 * r12)) -
        h * sinth * costh * r12 / ((sinth2 * r22 + costh2 * r12)) +
        costh2 * k * r12 / ((sinth2 * r22 + costh2 * r12)) -
        r2 *
            r1 *
            pow(
              -2 * x2 * costh2 * sinth2 +
                  4 * x * costh2 * sinth2 * h -
                  2 * h2 * costh2 * sinth2 +
                  sinth2 * r22 -
                  sinth4 * x2 +
                  2 * sinth4 * x * h -
                  sinth4 * h2 +
                  costh2 * r12 -
                  costh4 * x2 +
                  2 * costh4 * x * h -
                  costh4 * h2,
              0.5,
            ) /
            ((sinth2 * r22 + costh2 * r12));
    if (!y2.isNaN) {
      if (ret.every((v) => (v - y2).abs() > 1e-6)) ret.add(y2);
    }
    return ret;
  }
}

typedef UnivariateIntegrand = double Function(num t);

double integralRiemannSums(num min, num max, UnivariateIntegrand func, num n) {
  double sum = 0;
  var dx = (max - min) / n;
  var currentX = min + dx / 2;
  for (var i = 0; i < n; i++) {
    var currentY = func(currentX);
    sum += dx * currentY;
    currentX += dx;
  }
  return sum;
}

// Carlson symmetric elliptic integral RF(x,y,z) = (1/2)∫₀^∞ dt/√((t+x)(t+y)(t+z)),
// x,y,z ≥ 0 (at most one zero). Duplication-theorem iteration (Carlson 1994;
// Press et al., Numerical Recipes §6.12): each step shrinks the spread
// between x,y,z by a fixed factor, so convergence to machine precision is
// geometric and provable for every valid input -- not a heuristic tolerance
// check whose required depth depends on the integrand's shape.
double _carlsonRF(double x, double y, double z) {
  const errtol = 0.0025;
  var xt = x, yt = y, zt = z;
  while (true) {
    final sqrtx = sqrt(xt), sqrty = sqrt(yt), sqrtz = sqrt(zt);
    final alamb = sqrtx * (sqrty + sqrtz) + sqrty * sqrtz;
    xt = 0.25 * (xt + alamb);
    yt = 0.25 * (yt + alamb);
    zt = 0.25 * (zt + alamb);
    final avg = (xt + yt + zt) / 3;
    final delx = (avg - xt) / avg,
        dely = (avg - yt) / avg,
        delz = (avg - zt) / avg;
    if (max(delx.abs(), max(dely.abs(), delz.abs())) <= errtol) {
      final e2 = delx * dely - delz * delz;
      final e3 = delx * dely * delz;
      return (1.0 + (e2 / 24 - 0.1 - 3 * e3 / 44) * e2 + e3 / 14) / sqrt(avg);
    }
  }
}

// Carlson symmetric elliptic integral RD(x,y,z) = (3/2)∫₀^∞ dt/[(t+z)√((t+x)(t+y)(t+z))].
double _carlsonRD(double x, double y, double z) {
  const errtol = 0.0015;
  const c1 = 3.0 / 14.0, c2 = 1.0 / 6.0, c3 = 9.0 / 22.0, c4 = 3.0 / 26.0;
  const c5 = 0.25 * c3, c6 = 1.5 * c4;
  var xt = x, yt = y, zt = z, sum = 0.0, fac = 1.0;
  while (true) {
    final sqrtx = sqrt(xt), sqrty = sqrt(yt), sqrtz = sqrt(zt);
    final alamb = sqrtx * (sqrty + sqrtz) + sqrty * sqrtz;
    sum += fac / (sqrtz * (zt + alamb));
    fac *= 0.25;
    xt = 0.25 * (xt + alamb);
    yt = 0.25 * (yt + alamb);
    zt = 0.25 * (zt + alamb);
    final avg = 0.2 * (xt + yt + 3 * zt);
    final delx = (avg - xt) / avg,
        dely = (avg - yt) / avg,
        delz = (avg - zt) / avg;
    if (max(delx.abs(), max(dely.abs(), delz.abs())) <= errtol) {
      final ea = delx * dely, eb = delz * delz;
      final ec = ea - eb, ed = ea - 6 * eb, ee = ed + ec + ec;
      return 3 * sum +
          fac *
              (1.0 +
                  ed * (-c1 + c5 * ed - c6 * delz * ee) +
                  delz * (c2 * ee + delz * (-c3 * ec + delz * c4 * ea))) /
              (avg * sqrt(avg));
    }
  }
}

// E(φ,m) restricted to φ ∈ [-π/2, π/2], where the Carlson-form evaluation
// applies directly (odd in φ, so negative φ falls out for free via s³).
double _ellipticEPrincipal(double phi, double m) {
  final s = sin(phi), c = cos(phi);
  final x = c * c, y = 1 - m * s * s;
  return s * _carlsonRF(x, y, 1.0) -
      (m / 3) * s * s * s * _carlsonRD(x, y, 1.0);
}

// Legendre incomplete elliptic integral of the second kind, E(φ,m) =
// ∫₀^φ √(1 − m·sin²θ) dθ, for any real φ. Reduces to the principal range via
// the quasi-periodicity E(φ+nπ,m) = E(φ,m) + 2n·E(m) (DLMF 19.2.11) so that
// callers never need their own per-quadrant case-work.
double _ellipticE(double phi, double m) {
  final n = (phi / pi + 0.5).floor();
  final r = phi - n * pi;
  return 2 * n * _ellipticEPrincipal(pi / 2, m) + _ellipticEPrincipal(r, m);
}
