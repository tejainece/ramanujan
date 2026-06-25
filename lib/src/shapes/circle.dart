import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

class Circle implements ClosedShape {
  final P center;
  final double radius;

  Circle({this.center = origin, this.radius = 1});

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
        pointAtAngle(start.value), pointAtAngle(end.value), radius,
        largeArc: (start.value - end.value).abs() > pi, clockwise: end < start);
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
    List<double> ret = [if(!x1.isNaN) x1];
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
    final a = 1 +
        h12 / ((k12 - 2 * k1 * k2 + k22)) -
        2 * h1 * h2 / ((k12 - 2 * k1 * k2 + k22)) +
        h22 / ((k12 - 2 * k1 * k2 + k22));
    final b = -2 * h1 -
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
    final c = h12 +
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
      ...xs.fold(
          <P>[],
          (List<P> list, x) =>
              list..addAll(evalY(x).map((y) => P(x, y)))).toList(),
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
    final a = k12 / ((h12 - 2 * h1 * h2 + h22)) -
        2 * k1 * k2 / ((h12 - 2 * h1 * h2 + h22)) +
        k22 / ((h12 - 2 * h1 * h2 + h22)) +
        1;
    final b = -h12 * k1 / ((h12 - 2 * h1 * h2 + h22)) +
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
    final c = 0.25 * h14 / ((h12 - 2 * h1 * h2 + h22)) +
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
      ...ys.fold(
          <P>[],
          (List<P> list, y) =>
              list..addAll(evalX(y).map((x) => P(x, y)))).toList(),
    }.toList();
    ret.removeWhere((p) => !other.isPointOn(p));
    // print(ret);
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
