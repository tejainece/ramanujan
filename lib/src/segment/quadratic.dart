import 'package:ramanujan/ramanujan.dart';

class QuadraticSegment extends Segment {
  @override
  final P p1;
  @override
  final P p2;

  final P c;

  QuadraticSegment({required this.p1, required this.p2, required this.c});

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
    throw UnimplementedError();
  }
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
