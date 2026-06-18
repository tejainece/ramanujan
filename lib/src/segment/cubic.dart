import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

///
class CubicSegment extends Segment {
  @override
  final P p1;
  @override
  final P p2;

  final P c1;
  final P c2;

  CubicSegment(
      {required this.p1, required this.p2, required this.c1, required this.c2});

  @override
  List<P> get controlPoints => [c1, c2];

  @override
  LineSegment get p1Tangent => LineSegment(p1, c1);

  @override
  LineSegment get p2Tangent => LineSegment(c2, p2);

  @override
  double get length => _cubicBezierLength(p1, c1, c2, p2, 0.01, 0);

  @override
  P lerp(double t) => P(cubicBezierLerp(p1.x, c1.x, c2.x, p2.x, t),
      cubicBezierLerp(p1.y, c1.y, c2.y, p2.y, t));

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
  double ilerp(P point) {
    // TODO
    throw UnimplementedError();
  }

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
      CubicSegment(p1: path1p2, p2: p2, c1: path2c1, c2: path2c2)
    );
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
  R get boundingBox {
    R ret = R.fromPoints(p1, p2);

    P c = -p1 + c1;
    P b = p1 - c1 * 2 + c2;
    P a = -p1 + c1 * 3 - c2 * 3 + p2;

    P h = b * b - a * c;

    if (h.x > 0) {
      h = P(sqrt(h.x), h.y);
      double t = (-b.x - h.x) / a.x;
      if (t > 0 && t < 1) {
        double s = 1 - t;
        double q = s * s * s * p1.x +
            3 * s * s * t * c1.x +
            3 * s * t * t * c2.x +
            t * t * t * p2.x;
        ret = ret.includeX(q);
      }
      t = (-b.x + h.x) / a.x;
      if (t > 0 && t < 1) {
        double s = 1 - t;
        double q = s * s * s * p1.x +
            3 * s * s * t * c1.x +
            3 * s * t * t * c2.x +
            t * t * t * p2.x;
        ret = ret.includeX(q);
      }
    }
    if (h.y > 0) {
      h = P(h.x, sqrt(h.y));
      double t = (-b.y - h.y) / a.y;
      if (t > 0 && t < 1) {
        double s = 1 - t;
        double q = s * s * s * p1.y +
            3 * s * s * t * c1.y +
            3 * s * t * t * c2.y +
            t * t * t * p2.y;
        ret = ret.includeY(q);
      }
      t = (-b.y + h.y) / a.y;
      if (t > 0 && t < 1) {
        double s = 1 - t;
        double q = s * s * s * p1.y +
            3 * s * s * t * c1.y +
            3 * s * t * t * c2.y +
            t * t * t * p2.y;
        ret = ret.includeY(q);
      }
    }
    return ret;
  }

  @override
  List<P> intersect(Segment other) {
    if (other is LineSegment) return intersectLine(other);
    if (other is QuadraticSegment) {
      throw UnimplementedError(
          'CubicSegment × QuadraticSegment: degree 6, no closed form');
    }
    if (other is CubicSegment) {
      throw UnimplementedError(
          'CubicSegment × CubicSegment: degree 9, no closed form');
    }
    if (other is CircularArcSegment) {
      throw UnimplementedError(
          'CubicSegment × CircularArcSegment: degree 6, no closed form');
    }
    if (other is ArcSegment) {
      throw UnimplementedError(
          'CubicSegment × ArcSegment: degree 6, no closed form');
    }
    throw ArgumentError(
        'CubicSegment.intersect with ${other.runtimeType} not implemented');
  }

  List<P> intersectLine(LineSegment l) => l.intersectCubic(this);
}

double _cubicBezierLength(P a0, P a1, P a2, P a3, double tolerance, int level) {
  double lower = a0.distanceTo(a2);
  double upper = a0.distanceTo(a1) + a1.distanceTo(a2) + a2.distanceTo(a3);

  if (upper - lower <= 2 * tolerance || level >= 8) {
    return (lower + upper) / 2;
  }
  P b1 = (a0 + a1) * 0.5;
  P t0 = (a1 + a2) * 0.5;
  P c1 = (a2 + a3) * 0.5;
  P b2 = (b1 + t0) * 0.5;
  P c2 = (t0 + c1) * 0.5;
  P b3 = (b2 + c2) * 0.5;

  return _cubicBezierLength(a0, b1, b2, b3, 0.5 * tolerance, level + 1) +
      _cubicBezierLength(b3, c2, c1, a3, 0.5 * tolerance, level + 1);
}

double cubicBezierLerp(double p0, double p1, double p2, double p3, double t) =>
    (1 - t) * (1 - t) * (1 - t) * p0 +
    3 * (1 - t) * (1 - t) * t * p1 +
    3 * (1 - t) * t * t * p2 +
    t * t * t * p3;
