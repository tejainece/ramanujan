import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

abstract mixin class ILine {
  Radian get angle;

  double get slope;

  double get normalSlope => -1 / slope;

  Radian get normalAngle => angle + pi / 2;

  bool isParallelTo(ILine other, [double epsilon = 1e-3]) {
    final diff = angle - other.angle;
    return diff.equals(Radian(0), epsilon) || diff.equals(Radian(pi), epsilon);
  }

  bool isPerpendicularTo(ILine other, [double epsilon = 1e-3]) {
    final diff = angle - other.angle;
    return diff.isParallelTo(Radian(pi / 2), epsilon);
  }
}

class LineSegment extends Segment with ILine {
  @override
  final P p1;
  @override
  final P p2;

  LineSegment(this.p1, this.p2);

  LineSegment.origin(this.p2) : p1 = origin;

  factory LineSegment.radial(double angle,
      [double radius = 1, P center = origin]) {
    return LineSegment(center, P.onCircle(angle, radius, center));
  }

  factory LineSegment.horizontal(double x1, double x2, [double y = 0]) =>
      LineSegment(P(x1, y), P(x2, y));

  factory LineSegment.vertical(double y1, double y2, [double x = 0]) =>
      LineSegment(P(x, y1), P(x, y2));

  @override
  LineSegment get p1Tangent => LineSegment(p1, p2);

  @override
  LineSegment get p2Tangent => LineSegment(p1, p2);

  @override
  double get slope => (p2.y - p1.y) / (p2.x - p1.x);

  @override
  Radian get angle => Radian(atan2(p2.y - p1.y, p2.x - p1.x));

  P get midpoint => (p1 + p2) / 2;

  LineSegment rotate(double radians) =>
      LineSegment(p1, p1 + (p2 - p1).rotate(radians));

  Radian angleTo(LineSegment other) => angle - other.angle;

  P pointAt(double x) => P(x, slope * x + yIntercept);

  double get yIntercept => p1.y - slope * p1.x;

  double lerpX(double t) => p1.x + (p2.x - p1.x) * t;

  @override
  P lerp(double t) => p1 * (1 - t) + p2 * t;

  @override
  P unitTangentAt(double t) => (p2 - p1).normalized;

  @override
  double ilerp(P point) => (point.x - p1.x) / (p2.x - p1.x);

  @override
  (LineSegment, LineSegment) bifurcateAtInterval(double t) {
    final point = lerp(t);
    return (LineSegment(p1, point), LineSegment(point, p2));
  }

  @override
  double get length => p1.distanceTo(p2);

  P pointAtDistanceFromP1(double distance) => lerp(distance / length);

  P pointAtDistanceFromP2(double distance) => lerp(1 - distance / length);

  bool isOnExtendedLine(P p, {double epsilon = 1e-3}) =>
      ((p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x)).abs() <
      epsilon;

  bool hasPoint(P p, {double epsilon = 1e-3}) {
    if (!isOnExtendedLine(p, epsilon: epsilon)) return false;
    if (p.x < min(p1.x, p2.x) || p.x > max(p1.x, p2.x)) return false;
    return true;
  }

  @override
  LineSegment reversed() => LineSegment(p2, p1);

  @override
  bool operator ==(other) =>
      other is LineSegment && other.p1.isEqual(p1) && other.p2.isEqual(p2);

  LineSegment normalAt(P point, {double? length, bool cw = true}) {
    final angle = this.angle + Radian(cw ? pi / 2 : 3 * pi / 2);
    return LineSegment.radial(angle.value, length ?? 1, point);
  }

  LineSegment normalAtP1({double? length, bool cw = true}) =>
      normalAt(p1, length: length, cw: cw);

  LineSegment normalAtP2({double? length, bool cw = true}) =>
      normalAt(p2, length: length, cw: cw);

  LineSegment bisector({double? length, bool cw = true}) =>
      normalAt(midpoint, length: length, cw: cw);

  LineSegment transform(Affine2d affine) =>
      LineSegment(affine.apply(p1), affine.apply(p2));

  @override
  int get hashCode => Object.hash(p1, p2);

  @override
  String toString() => 'Line($p1, $p2)';

  @override
  R get boundingBox => R.fromPoints(p1, p2);

  late final LineStandardForm standardForm =
      LineStandardForm.fromPoints(p1, p2);

  @override
  List<P> intersect(Segment other) {
    if (other is LineSegment) {
      final ret = intersectLineSegment(other);
      return ret != null ? [ret] : [];
    }
    throw ArgumentError(
        'Finding intersect LineSegment with ${other.runtimeType} is not implemented');
  }

  P intersectInfiniteLine(LineSegment other) {
    return standardForm.intersect(other.standardForm);
  }

  P? intersectLineSegment(LineSegment other) {
    final ret = standardForm.intersect(other.standardForm);
    if (!hasPoint(ret) || !other.hasPoint(ret)) return null;
    return ret;
  }

  /// https://mathworld.wolfram.com/Circle-LineIntersection.html
  List<P> intersectCircle(Circle circle) {
    final ret = <P>[];
    final det = p1.x * p2.y - p2.x * p1.y;
    final r2 = circle.radius * circle.radius;
    final det2 = det * det;
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    final dr2 = dx * dx + dy * dy;
    final discriminant = r2 * dr2 - det2;
    if (discriminant < 0) {
      return ret;
    } else if (discriminant == 0) {
      ret.add(P(det * dy / dr2, -det * dx / dr2));
      return ret;
    }
    final discriminantSqrt = sqrt(discriminant);
    double dySign = dy.isNegative ? -1 : 1;
    final y1 = (-det * dx - dy.abs() * discriminantSqrt) / dr2;
    final y2 = (-det * dx + dy.abs() * discriminantSqrt) / dr2;
    final x1 = (det * dy - dySign * dx * discriminantSqrt) / dr2;
    final x2 = (det * dy + dySign * dx * discriminantSqrt) / dr2;
    ret.add(P(x1, y1));
    ret.add(P(x2, y2));
    return ret;
  }
}

class LineVectorForm with ILine {
  final P p;
  @override
  final Radian angle;

  const LineVectorForm(this.p, this.angle);

  @override
  double get slope => angle.slope;
}

class LineSlopeForm with ILine {
  final double m;

  final double c;

  const LineSlopeForm(this.m, this.c);

  @override
  Radian get angle => Radian(atan(m));

  @override
  double get slope => m;

  @override
  String toString() => 'y = $m * x + $c';
}

class LineStandardForm with ILine {
  final double a;
  final double b;
  final double c;

  const LineStandardForm(this.a, this.b, this.c);

  factory LineStandardForm.fromPoints(P p1, P p2) {
    final a = p2.y - p1.y;
    final b = p1.x - p2.x;
    final c = p1.y * (p2.x - p1.x) - (p2.y - p1.y) * p1.x;
    return LineStandardForm(a, b, c);
  }

  @override
  double get slope => -a / b;

  @override
  Radian get angle => Radian(atan2(a, b));

  LineSegment lineWithX(double x1, double x2) =>
      LineSegment(P(x1, evalY(x1)), P(x2, evalY(x2)));

  List<double> get coefficients => [a, b, c];

  @override
  String toString() => '$a * x + $b * y + $c = 0';

  P intersect(LineStandardForm other) {
    final div = other.a * b - other.b * a;
    final x = (other.b * c - other.c * b) / div;
    final y = (-other.a * c + other.c * a) / div;
    return P(x, y);
  }

  List<P> intersectCircle(Circle circle) {
    double a2 = a * a;
    double b2 = b * b;
    double c2 = c * c;
    double h = circle.center.x;
    double k = circle.center.y;
    double h2 = h * h;
    double k2 = k * k;
    double r2 = circle.radius * circle.radius;
    double discriminant = -a2 * h2 +
        a2 * r2 -
        2 * a * b * h * k -
        2 * a * c * h -
        b2 * k2 +
        b2 * r2 -
        2 * b * c * k -
        c2;
    if (discriminant.isNegative) {
      return [];
    }
    double partn = sqrt(discriminant);
    double part1 = a * partn / (a2 + b2);
    double part2 = (a2 * k - a * b * h - b * c) / (a2 + b2);
    P p1;
    P p2;
    if (a == 0) {
      double x = circle.evalX(-part2).first;
      p1 = P(-x, -part2);
      p2 = P(x, -part2);
    } else {
      p1 = P((b * (part1 - part2) - c) / a, -part1 + part2);
      p2 = P(-(b * (part1 + part2) + c) / a, part1 + part2);
    }
    if (p1.isEqual(p2)) {
      return [p1];
    }
    return [p1, p2];
  }

  List<P> intersectEllipse(Ellipse ellipse) {
    final costh = ellipse.costh;
    final sinth = ellipse.sinth;
    final costh2 = costh * costh;
    final sinth2 = sinth * sinth;
    final r1 = ellipse.radii.x;
    final r2 = ellipse.radii.y;
    final r12 = r1 * r1;
    final r22 = r2 * r2;
    final a2 = a * a;
    final b2 = b * b;
    final c2 = c * c;
    final h = ellipse.center.x;
    final k = ellipse.center.y;
    final h2 = h * h;
    final k2 = k * k;
    final A = costh2 / r12 -
        2 * costh * a * sinth / (b * r12) +
        a2 * sinth2 / (b2 * r12) +
        sinth2 / r22 +
        2 * sinth * a * costh / (b * r22) +
        a2 * costh2 / (b2 * r22);
    double B = -2 * costh2 * h / r12 -
        2 * costh * c * sinth / (b * r12) -
        2 * costh * k * sinth / r12 +
        2 * h * costh * a * sinth / (b * r12) +
        2 * a * c * sinth2 / (b2 * r12) +
        2 * a * sinth2 * k / (b * r12) -
        2 * sinth2 * h / r22 +
        2 * sinth * c * costh / (b * r22) +
        2 * sinth * k * costh / r22 -
        2 * h * sinth * a * costh / (b * r22) +
        2 * a * c * costh2 / (b2 * r22) +
        2 * a * costh2 * k / (b * r22);
    double C = -1 +
        h2 * costh2 / r12 +
        2 * h * costh * c * sinth / (b * r12) +
        2 * h * costh * k * sinth / r12 +
        c2 * sinth2 / (b2 * r12) +
        2 * c * sinth2 * k / (b * r12) +
        k2 * sinth2 / r12 +
        h2 * sinth2 / r22 -
        2 * h * sinth * c * costh / (b * r22) -
        2 * h * sinth * k * costh / r22 +
        c2 * costh2 / (b2 * r22) +
        2 * c * costh2 * k / (b * r22) +
        k2 * costh2 / r22;
    // print('a: $a, b: $b, c: $c, h: $h, k: $k, r1: $r1, r2: $r2');
    final discriminant = B * B - 4 * A * C;
    if (discriminant.isNegative) {
      return [];
    }
    // print('A: $A, B: $B, C: $C; discriminant: $discriminant');
    final x1 = (-B - sqrt(discriminant)) / (2 * A);
    final x2 = (-B + sqrt(discriminant)) / (2 * A);
    final y1 = -(a * x1 + c) / b;
    final y2 = -(a * x2 + c) / b;
    return [P(x1, y1), P(x2, y2)];
  }

  double evalY(double x) => -(a * x + c) / b;

  double evalX(double y) => -(b * y + c) / a;
}

extension PointsLineSegmentExt on Iterable<P> {
  List<LineSegment> toLines() {
    final lines = <LineSegment>[];
    if (length < 2) return lines;
    P pivot = first;
    for (final cur in skip(1)) {
      lines.add(LineSegment(pivot, cur));
      pivot = cur;
    }
    return lines;
  }
}
