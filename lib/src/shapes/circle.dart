import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

class Circle implements ClosedShape {
  final P center;
  final double radius;

  Circle({this.center = origin, this.radius = 1});

  /// Returns this path as a [Circle] if it exactly matches the cubic bezier
  /// approximation of a circle used by the generator, or null otherwise.
  static Circle? fromVectorPath(VectorPath path) {
    if (!path.isClosed()) return null;
    final segments = path.segments;
    if (segments.length != 4) return null;

    if (segments.any((s) => s is! CubicSegment)) return null;

    final s0 = segments[0] as CubicSegment;
    final s1 = segments[1] as CubicSegment;
    final s2 = segments[2] as CubicSegment;
    final s3 = segments[3] as CubicSegment;

    final top = s0.p1;
    final right = s1.p1;
    final bottom = s2.p1;
    final left = s3.p1;

    final cx = (left.x + right.x) / 2;
    final cy = (top.y + bottom.y) / 2;

    if ((top.x - cx).abs() > 1e-6 || (bottom.x - cx).abs() > 1e-6) return null;
    if ((left.y - cy).abs() > 1e-6 || (right.y - cy).abs() > 1e-6) return null;

    final r1 = (top.y - cy).abs();
    final r2 = (bottom.y - cy).abs();
    final r3 = (left.x - cx).abs();
    final r4 = (right.x - cx).abs();

    if ((r1 - r2).abs() > 1e-6 ||
        (r1 - r3).abs() > 1e-6 ||
        (r1 - r4).abs() > 1e-6) {
      return null;
    }

    final radius = r1;
    if (radius <= 0) return null;

    final kappa = 0.552284749831 * radius;
    const eps = 1e-4;

    if (!s0.c1.isEqual(P(cx + kappa, cy - radius), eps) ||
        !s0.c2.isEqual(P(cx + radius, cy - kappa), eps)) {
      return null;
    }
    if (!s1.c1.isEqual(P(cx + radius, cy + kappa), eps) ||
        !s1.c2.isEqual(P(cx + kappa, cy + radius), eps)) {
      return null;
    }
    if (!s2.c1.isEqual(P(cx - kappa, cy + radius), eps) ||
        !s2.c2.isEqual(P(cx - radius, cy + kappa), eps)) {
      return null;
    }
    if (!s3.c1.isEqual(P(cx - radius, cy - kappa), eps) ||
        !s3.c2.isEqual(P(cx - kappa, cy - radius), eps)) {
      return null;
    }

    return Circle(center: P(cx, cy), radius: radius);
  }

  /// Circumscribed circle through three non-collinear points.
  /// Returns null when [a], [b], [c] are collinear (determinant < 1e-10).
  static Circle? through(P a, P b, P c) {
    final d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
    if (d.abs() < 1e-10) return null;
    final a2 = a.x * a.x + a.y * a.y;
    final b2 = b.x * b.x + b.y * b.y;
    final c2 = c.x * c.x + c.y * c.y;
    final cx = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d;
    final cy = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d;
    final center = P(cx, cy);
    return Circle(center: center, radius: (a - center).length);
  }

  /// Algebraic least-squares circle fit (Kasa's method) over [points].
  /// Minimises Σ(x²+y²+Dx+Ey+F)², then recovers
  ///   centre = (−D/2, −E/2),  radius = √(cx²+cy²−F).
  /// Returns null for fewer than 3 points or a degenerate configuration.
  static Circle? fit(Iterable<P> points) {
    var sx2 = 0.0, sxy = 0.0, sx = 0.0, sy2 = 0.0, sy = 0.0;
    var r0 = 0.0, r1 = 0.0, r2 = 0.0;
    var n = 0;
    for (final p in points) {
      final x = p.x, y = p.y, z = x * x + y * y;
      sx2 += x * x;
      sxy += x * y;
      sx += x;
      sy2 += y * y;
      sy += y;
      r0 -= x * z;
      r1 -= y * z;
      r2 -= z;
      n++;
    }
    if (n < 3) return null;
    final nd = n.toDouble();
    final det =
        sx2 * (sy2 * nd - sy * sy) -
        sxy * (sxy * nd - sy * sx) +
        sx * (sxy * sy - sy2 * sx);
    if (det.abs() < 1e-10) return null;
    final bigD =
        (r0 * (sy2 * nd - sy * sy) -
            sxy * (r1 * nd - sy * r2) +
            sx * (r1 * sy - sy2 * r2)) /
        det;
    final bigE =
        (sx2 * (r1 * nd - sy * r2) -
            r0 * (sxy * nd - sy * sx) +
            sx * (sxy * r2 - r1 * sx)) /
        det;
    final bigF =
        (sx2 * (sy2 * r2 - r1 * sy) -
            sxy * (sxy * r2 - r1 * sx) +
            r0 * (sxy * sy - sy2 * sx)) /
        det;
    final cx = -bigD / 2, cy = -bigE / 2;
    final rSq = cx * cx + cy * cy - bigF;
    if (rSq <= 0) return null;
    return Circle(center: P(cx, cy), radius: sqrt(rSq));
  }

  /// True when the path [p1] → [mid] → [p2] turns clockwise (y-up convention).
  static bool clockwise(P p1, P mid, P p2) =>
      (mid.x - p1.x) * (p2.y - p1.y) - (mid.y - p1.y) * (p2.x - p1.x) < 0;

  /// Arc on this circle from [p0] to [p2] passing through [mid], with the
  /// correct [CircularArcSegment.largeArc] and [CircularArcSegment.clockwise]
  /// flags derived from the geometry.
  ///
  /// [p0], [mid], and [p2] should lie on (or very near) this circle.
  CircularArcSegment arcThrough(P p0, P mid, P p2) {
    final cw = Circle.clockwise(p0, mid, p2);
    // Large arc when mid and center are on the same side of chord p0→p2.
    final chordX = p2.x - p0.x, chordY = p2.y - p0.y;
    final midSide = chordX * (mid.y - p0.y) - chordY * (mid.x - p0.x);
    final centerSide = chordX * (center.y - p0.y) - chordY * (center.x - p0.x);
    return CircularArcSegment(
      p0,
      p2,
      radius,
      largeArc: midSide * centerSide > 0,
      clockwise: cw,
    );
  }

  P pointAtAngle(double angle) =>
      center + P(radius * cos(angle), radius * sin(angle));

  Radian angleOfPoint(P point) => LineSegment(center, point).angle;

  double arcLengthToT(double t) => perimeter * t;

  double arcLengthAtAngle(double radians) {
    radians = Radian(radians).value;
    return perimeter * radians / (2 * pi);
  }

  double arcLengthBetweenT(double t1, double t2, {bool clockwise = false}) {
    final t = Clamp.unit.difference(t1, t2, clockwise: clockwise);
    return perimeter * t;
  }

  CircularArcSegment arc(Radian start, Radian end) {
    return CircularArcSegment(
      pointAtAngle(start.value),
      pointAtAngle(end.value),
      radius,
      largeArc: (start.value - end.value).abs() > pi,
      clockwise: end < start,
    );
  }

  bool isEqual(Circle other, [double epsilon = 1e-3]) {
    if (!center.isEqual(other.center, epsilon)) return false;
    if (!radius.equals(other.radius, epsilon)) return false;
    return true;
  }

  @override
  late final double area = pi * radius * radius;

  @override
  late final double perimeter = 2 * pi * radius;

  P lerp(double t) => pointAtAngle(2 * pi * t);

  P lerpBetween(double t1, double t2, double t, {bool clockwise = false}) =>
      lerp(Clamp.unit.lerp(t1, t2, t, clockwise: clockwise));

  double ilerp(P point) {
    final angle = angleOfPoint(point);
    return angle.value / (2 * pi);
  }

  @override
  bool containsPoint(P point) => point.distanceTo(center) <= radius;

  @override
  bool isPointOn(P point) {
    final ys = evalY(point.x);
    if (ys.isEmpty) return false;
    return ys.any((y) => (y - point.y).abs() < 1e-6);
  }

  @override
  R get boundingBox =>
      R(center.x - radius, center.y - radius, radius * 2, radius * 2);

  List<double> evalX(double y) {
    final sq = sqrt(radius * radius - (y - center.y) * (y - center.y));
    final x1 = center.x - sq;
    final x2 = center.x + sq;
    List<double> ret = [if (!x1.isNaN) x1];
    if (!x2.isNaN && ret.every((x) => (x - x2).abs() > 1e-6)) ret.add(x2);
    return ret;
  }

  List<double> evalY(double x) {
    final sq = sqrt(radius * radius - (x - center.x) * (x - center.x));
    final y1 = center.y - sq;
    final y2 = center.y + sq;
    List<double> ret = [if (!y1.isNaN) y1];
    if (!y2.isNaN && ret.every((y) => (y - y2).abs() > 1e-6)) ret.add(y2);
    return ret;
  }

  List<P> _intersectCircleUsingXFormula(Circle other) {
    final h1 = center.x;
    final h12 = h1 * h1;
    final h13 = h12 * h1;
    final h14 = h13 * h1;
    final k1 = center.y;
    final k12 = k1 * k1;
    final k13 = k12 * k1;
    final k14 = k12 * k12;
    final h2 = other.center.x;
    final h22 = h2 * h2;
    final h23 = h22 * h2;
    final h24 = h23 * h2;
    final k2 = other.center.y;
    final k22 = k2 * k2;
    final k24 = k22 * k22;
    final r1 = radius;
    final r12 = r1 * r1;
    final r14 = r12 * r12;
    final r2 = other.radius;
    final r22 = r2 * r2;
    final r24 = r22 * r22;
    final a =
        1 +
        h12 / ((k12 - 2 * k1 * k2 + k22)) -
        2 * h1 * h2 / ((k12 - 2 * k1 * k2 + k22)) +
        h22 / ((k12 - 2 * k1 * k2 + k22));
    final b =
        -2 * h1 -
        h13 / ((k12 - 2 * k1 * k2 + k22)) -
        h1 * k12 / ((k12 - 2 * k1 * k2 + k22)) +
        h1 * r12 / ((k12 - 2 * k1 * k2 + k22)) +
        h1 * h22 / ((k12 - 2 * k1 * k2 + k22)) +
        h1 * k22 / ((k12 - 2 * k1 * k2 + k22)) -
        h1 * r22 / ((k12 - 2 * k1 * k2 + k22)) +
        h12 * h2 / ((k12 - 2 * k1 * k2 + k22)) +
        k12 * h2 / ((k12 - 2 * k1 * k2 + k22)) -
        r12 * h2 / ((k12 - 2 * k1 * k2 + k22)) -
        h23 / ((k12 - 2 * k1 * k2 + k22)) -
        h2 * k22 / ((k12 - 2 * k1 * k2 + k22)) +
        h2 * r22 / ((k12 - 2 * k1 * k2 + k22)) -
        2 * h1 * k1 / ((-k1 + k2)) +
        2 * h2 * k1 / ((-k1 + k2));
    final c =
        h12 +
        0.25 * h14 / ((k12 - 2 * k1 * k2 + k22)) +
        0.5 * h12 * k12 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * h12 * r12 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * h12 * h22 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * h12 * k22 / ((k12 - 2 * k1 * k2 + k22)) +
        0.5 * h12 * r22 / ((k12 - 2 * k1 * k2 + k22)) +
        0.25 * k14 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * k12 * r12 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * k12 * h22 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * k12 * k22 / ((k12 - 2 * k1 * k2 + k22)) +
        0.5 * k12 * r22 / ((k12 - 2 * k1 * k2 + k22)) +
        0.25 * r14 / ((k12 - 2 * k1 * k2 + k22)) +
        0.5 * r12 * h22 / ((k12 - 2 * k1 * k2 + k22)) +
        0.5 * r12 * k22 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * r12 * r22 / ((k12 - 2 * k1 * k2 + k22)) +
        0.25 * h24 / ((k12 - 2 * k1 * k2 + k22)) +
        0.5 * h22 * k22 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * h22 * r22 / ((k12 - 2 * k1 * k2 + k22)) +
        0.25 * k24 / ((k12 - 2 * k1 * k2 + k22)) -
        0.5 * k22 * r22 / ((k12 - 2 * k1 * k2 + k22)) +
        0.25 * r24 / ((k12 - 2 * k1 * k2 + k22)) +
        h12 * k1 / ((-k1 + k2)) +
        k13 / ((-k1 + k2)) -
        r12 * k1 / ((-k1 + k2)) -
        h22 * k1 / ((-k1 + k2)) -
        k22 * k1 / ((-k1 + k2)) +
        r22 * k1 / ((-k1 + k2)) +
        k12 -
        r12;
    final discriminant = b * b - 4 * a * c;
    // print('$a $b $c $discriminant');
    if (discriminant.isNegative) {
      return [];
    }
    final x1 = (-b - sqrt(discriminant)) / (2 * a);
    final x2 = (-b + sqrt(discriminant)) / (2 * a);
    final xs = {x1, x2}.toList();
    final ret = <P>{
      ...xs.fold<List<P>>(
        <P>[],
        (list, x) => list..addAll(evalY(x).map((y) => P(x, y))),
      ),
    }.toList();
    ret.removeWhere((p) => !other.isPointOn(p));
    // print(ret);
    return ret;
  }

  List<P> _intersectCircleUsingYFormula(Circle other) {
    final h1 = center.x;
    final h12 = h1 * h1;
    final h13 = h12 * h1;
    final h14 = h13 * h1;
    final k1 = center.y;
    final k12 = k1 * k1;
    final k13 = k12 * k1;
    final k14 = k12 * k12;
    final h2 = other.center.x;
    final h22 = h2 * h2;
    final h23 = h22 * h2;
    final h24 = h23 * h2;
    final k2 = other.center.y;
    final k22 = k2 * k2;
    final k23 = k22 * k2;
    final k24 = k22 * k22;
    final r1 = radius;
    final r12 = r1 * r1;
    final r14 = r12 * r12;
    final r2 = other.radius;
    final r22 = r2 * r2;
    final r24 = r22 * r22;
    final a =
        k12 / ((h12 - 2 * h1 * h2 + h22)) -
        2 * k1 * k2 / ((h12 - 2 * h1 * h2 + h22)) +
        k22 / ((h12 - 2 * h1 * h2 + h22)) +
        1;
    final b =
        -h12 * k1 / ((h12 - 2 * h1 * h2 + h22)) +
        h12 * k2 / ((h12 - 2 * h1 * h2 + h22)) -
        k13 / ((h12 - 2 * h1 * h2 + h22)) +
        k1 * r12 / ((h12 - 2 * h1 * h2 + h22)) +
        k1 * h22 / ((h12 - 2 * h1 * h2 + h22)) +
        k1 * k22 / ((h12 - 2 * h1 * h2 + h22)) -
        k1 * r22 / ((h12 - 2 * h1 * h2 + h22)) +
        k12 * k2 / ((h12 - 2 * h1 * h2 + h22)) -
        r12 * k2 / ((h12 - 2 * h1 * h2 + h22)) -
        h22 * k2 / ((h12 - 2 * h1 * h2 + h22)) -
        k23 / ((h12 - 2 * h1 * h2 + h22)) +
        k2 * r22 / ((h12 - 2 * h1 * h2 + h22)) -
        2 * k1 * h1 / ((-h1 + h2)) +
        2 * k2 * h1 / ((-h1 + h2)) -
        2 * k1;
    final c =
        0.25 * h14 / ((h12 - 2 * h1 * h2 + h22)) +
        0.5 * h12 * k12 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * h12 * r12 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * h12 * h22 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * h12 * k22 / ((h12 - 2 * h1 * h2 + h22)) +
        0.5 * h12 * r22 / ((h12 - 2 * h1 * h2 + h22)) +
        0.25 * k14 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * k12 * r12 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * k12 * h22 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * k12 * k22 / ((h12 - 2 * h1 * h2 + h22)) +
        0.5 * k12 * r22 / ((h12 - 2 * h1 * h2 + h22)) +
        0.25 * r14 / ((h12 - 2 * h1 * h2 + h22)) +
        0.5 * r12 * h22 / ((h12 - 2 * h1 * h2 + h22)) +
        0.5 * r12 * k22 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * r12 * r22 / ((h12 - 2 * h1 * h2 + h22)) +
        0.25 * h24 / ((h12 - 2 * h1 * h2 + h22)) +
        0.5 * h22 * k22 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * h22 * r22 / ((h12 - 2 * h1 * h2 + h22)) +
        0.25 * k24 / ((h12 - 2 * h1 * h2 + h22)) -
        0.5 * k22 * r22 / ((h12 - 2 * h1 * h2 + h22)) +
        0.25 * r24 / ((h12 - 2 * h1 * h2 + h22)) +
        h13 / ((-h1 + h2)) +
        k12 * h1 / ((-h1 + h2)) -
        r12 * h1 / ((-h1 + h2)) -
        h22 * h1 / ((-h1 + h2)) -
        k22 * h1 / ((-h1 + h2)) +
        r22 * h1 / ((-h1 + h2)) +
        h12 +
        k12 -
        r12;
    final discriminant = b * b - 4 * a * c;
    // print('$a $b $c $discriminant');
    if (discriminant.isNegative) {
      return [];
    }
    final y1 = (-b - sqrt(discriminant)) / (2 * a);
    final y2 = (-b + sqrt(discriminant)) / (2 * a);
    final ys = {y1, y2}.toList();
    final ret = <P>{
      ...ys.fold<List<P>>(
        <P>[],
        (list, y) => list..addAll(evalX(y).map((x) => P(x, y))),
      ),
    }.toList();
    ret.removeWhere((p) => !other.isPointOn(p));
    return ret;
  }

  List<P> intersectCircle(Circle other) {
    if ((center.y - other.center.y).abs() < 1e-10) {
      if ((center.x - other.center.x).abs() < 1e-10) {
        return []; // concentric or identical circles — no finite intersection points
      }
      return _intersectCircleUsingYFormula(other);
    }
    return _intersectCircleUsingXFormula(other);
  }

  List<P> intersectEllipse(Ellipse other) {
    // TODO
    throw UnimplementedError();
  }
}
