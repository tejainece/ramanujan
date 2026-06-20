import 'dart:math';

import 'package:polynomial/polynomial.dart';
import 'package:ramanujan/ramanujan.dart';

class CircularArcSegment extends Segment {
  @override
  final P p1;
  @override
  final P p2;
  final double radius;
  final bool largeArc;
  final bool clockwise;

  CircularArcSegment(this.p1, this.p2, this.radius,
      {this.largeArc = false, this.clockwise = true});

  /// The radius used for all derived geometry. When the chord exceeds the
  /// diameter (`2 * radius`) the arc cannot reach its own endpoints at [radius];
  /// per the SVG spec (and Flutter's `arcToPoint`) renderers then scale the
  /// radius up to `chord / 2`. We mirror that here so [center], [angle], [lerp]
  /// and friends describe the arc that is actually drawn — otherwise consumers
  /// like stroke expansion fit to a curve that doesn't match the rendering.
  late final double effectiveRadius = max(radius, line.length / 2);

  @override
  List<P> get controlPoints => const [];

  @override
  LineSegment get p1Tangent => radial1.normalAtP2(length: radius);

  @override
  LineSegment get p2Tangent => radial2.normalAtP2(length: radius);

  LineSegment tangentAt(P p) =>
      LineSegment(center, p).normalAtP2(length: radius);

  bool isOnCircle(P point, {double epsilon = 1e-3}) {
    final c = center;
    final diff = point - c;
    return (diff.x * diff.x + diff.y * diff.y - effectiveRadius * effectiveRadius)
        .equals(0, epsilon);
  }

  bool isOn(P point, {double epsilon = 1e-3}) {
    if (!isOnCircle(point, epsilon: epsilon)) return false;
    final ang = angleOfPoint(point);
    return startAngle <= ang && ang <= endAngle;
  }

  @override
  P lerp(double t) {
    Radian angle;
    if (clockwise) {
      angle = endAngle + this.angle.value * t;
    } else {
      angle = startAngle + this.angle.value * t;
    }
    return P.onCircle(angle.value, effectiveRadius, center);
  }

  // d/dt of lerp's P.onCircle(base + angle·t): direction (-sin a, cos a), since
  // radius and angle.value are positive, so this already points along travel.
  @override
  P unitTangentAt(double t) {
    final a = (clockwise ? endAngle.value : startAngle.value) + angle.value * t;
    return P(-sin(a), cos(a));
  }

  @override
  double ilerp(P point) {
    final ang = angleOfPoint(point);

    double ret;
    if (clockwise) {
      ret = (ang - startAngle).value / angle.value;
    } else {
      ret = (ang - endAngle).value / angle.value;
    }
    return ret;
  }

  @override
  (CircularArcSegment, CircularArcSegment) bifurcateAtInterval(double t) {
    final p = lerp(t);
    final arc1LargeArc = angle.value * t > pi;
    final arc2LargeArc = angle.value * (1 - t) > pi;
    return (
      CircularArcSegment(
        p1,
        p,
        radius,
        largeArc: clockwise ? arc2LargeArc : arc1LargeArc,
        clockwise: clockwise,
      ),
      CircularArcSegment(
        p,
        p2,
        radius,
        largeArc: clockwise ? arc1LargeArc : arc2LargeArc,
        clockwise: clockwise,
      )
    );
  }

  @override
  P getPointByAddress(PointId id) => switch (id) {
        PointId.p1 => p1,
        PointId.p2 => p2,
        _ => throw ArgumentError('CircularArcSegment has no point $id'),
      };

  @override
  List<TangiblePointAddress> getPointAddresses() => [
        TangiblePointAddress(segment: this, name: PointId.p1),
        TangiblePointAddress(segment: this, name: PointId.p2),
      ];

  @override
  Segment updateByPointAddresses(Map<TangiblePointAddress, P> updates) {
    var np1 = p1, np2 = p2;
    for (final e in updates.entries) {
      switch (e.key.name) {
        case PointId.p1:
          np1 = e.value;
        case PointId.p2:
          np2 = e.value;
        default:
          throw ArgumentError('CircularArcSegment has no point ${e.key.name}');
      }
    }
    return CircularArcSegment(np1, np2, radius,
        largeArc: largeArc, clockwise: clockwise);
  }

  @override
  CircularArcSegment reversed() => CircularArcSegment(p2, p1, radius,
      largeArc: largeArc, clockwise: !clockwise);

  @override
  double get length => effectiveRadius * angle.value;

  late final P center = () {
    final dist = effectiveRadius * cos(angle.value / 2);
    final bisector = line.bisector(length: dist, cw: !clockwise);
    final ret = bisector.p2;
    return ret;
  }();

  late final Radian angle = () {
    final opp = line.length / 2;
    final hypotenuse = effectiveRadius;
    double angle = asin((opp / hypotenuse).clamp(-1.0, 1.0)) * 2;
    if (!largeArc) return Radian(angle);
    return Radian(2 * pi - angle);
  }();

  Radian angleOfPoint(P point) => LineSegment(center, point).angle;

  late final Radian startAngle = radial1.angle;

  late final Radian endAngle = radial2.angle;

  late final LineSegment radial1 = LineSegment(center, p1);

  late final LineSegment radial2 = LineSegment(center, p2);

  @override
  bool operator ==(other) =>
      other is CircularArcSegment &&
      other.p1 == p1 &&
      other.p2 == p2 &&
      other.radius == radius &&
      other.largeArc == largeArc &&
      other.clockwise == clockwise;

  @override
  int get hashCode => Object.hash(p1, p2, radius, largeArc, clockwise);

  String get svgSolo =>
      'M ${p1.x} ${p1.y} A $radius $radius 0 ${largeArc ? 1 : 0} ${clockwise ? 0 : 1} ${p2.x} ${p2.y}';

  @override
  R get boundingBox {
    R ret = R.fromPoints(p1, p2);
    if (startAngle.equals(endAngle)) {
      return ret;
    }
    const double step = pi / 2;
    Radian angle = Radian((startAngle.value ~/ step) * step);
    if (clockwise) {
      angle = angle + step;
    }
    for (int i = 0; i < 4; i++) {
      if (clockwise) {
        angle = angle - step;
        if (!angle.isBetweenCW(startAngle, endAngle)) {
          return ret;
        }
      } else {
        angle = angle + step;
        if (!angle.isBetweenCCW(startAngle, endAngle)) {
          return ret;
        }
      }
      ret = ret.includePoint(center.x + effectiveRadius * cos(angle.value),
          center.y + effectiveRadius * sin(angle.value));
    }
    return ret;
  }

  @override
  List<P> intersect(Segment other) {
    if (other is LineSegment) return intersectLine(other);
    if (other is QuadraticSegment) return intersectQuadratic(other);
    if (other is CubicSegment) {
      throw UnimplementedError(
          'CircularArcSegment × CubicSegment: degree 6, no closed form');
    }
    if (other is CircularArcSegment) return intersectCircularArc(other);
    if (other is ArcSegment) return intersectArc(other);
    throw ArgumentError(
        'CircularArcSegment.intersect with ${other.runtimeType} not implemented');
  }

  List<P> intersectLine(LineSegment l) => l.intersectCircularArc(this);

  List<P> intersectQuadratic(QuadraticSegment q) =>
      q.intersectCircularArc(this);

  List<P> intersectCircularArc(CircularArcSegment other) {
    final circle1 = Circle(center: center, radius: effectiveRadius);
    final circle2 = Circle(center: other.center, radius: other.effectiveRadius);
    return circle1
        .intersectCircle(circle2)
        .where((p) => _onCircularArc(this, p) && _onCircularArc(other, p))
        .toList();
  }

  // Parameterize this circular arc by eccentric angle φ; find φ where the
  // circle point also lies on a's ellipse via Weierstrass substitution.
  List<P> intersectArc(ArcSegment a) {
    final caUCT = Affine2d(
        scaleX: effectiveRadius,
        scaleY: effectiveRadius,
        translateX: center.x,
        translateY: center.y);
    final composed = a.ellipse.inverseUnitCircleTransform * caUCT;
    final result = <P>[];
    for (final phi in _weierstrassAngles(composed)) {
      final p = P(center.x + effectiveRadius * cos(phi),
          center.y + effectiveRadius * sin(phi));
      if (!_onCircularArc(this, p)) continue;
      if (_onArc(a, p)) result.add(p);
    }
    return result;
  }
}

bool _onCircularArc(CircularArcSegment ca, P p) {
  final ang = Radian(ca.angleOfPoint(p).value);
  return ca.clockwise
      ? ang.isBetweenCW(ca.startAngle, ca.endAngle)
      : ang.isBetweenCCW(ca.startAngle, ca.endAngle);
}

bool _onArc(ArcSegment a, P p) {
  final q = a.ellipse.inverseUnitCircleTransform.apply(p);
  final ang = Radian(Radian(atan2(q.y, q.x)).value);
  return a.clockwise
      ? ang.isBetweenCW(a.startAngle, a.endAngle)
      : ang.isBetweenCCW(a.startAngle, a.endAngle);
}

// Weierstrass substitution u=tan(φ/2) converts the unit-circle constraint on
// a composed affine transform to a degree-4 polynomial in u. Returns eccentric
// angles φ for all real roots, plus π if the leading coefficient vanishes.
List<double> _weierstrassAngles(Affine2d composed) {
  final px = composed.scaleX, qx = composed.shearX, rx = composed.translateX;
  final py = composed.shearY, qy = composed.scaleY, ry = composed.translateY;
  final bigA = px + rx, bigB = 2 * qx, bigC = rx - px;
  final bigD = py + ry, bigE = 2 * qy, bigF = ry - py;
  // (C²+F²−1)u⁴ + 2(BC+EF)u³ + (B²+2AC+E²+2DF−2)u² + 2(AB+DE)u + (A²+D²−1) = 0
  final poly = Polynomial([
    bigA * bigA + bigD * bigD - 1,
    2 * (bigA * bigB + bigD * bigE),
    bigB * bigB + 2 * bigA * bigC + bigE * bigE + 2 * bigD * bigF - 2,
    2 * (bigB * bigC + bigE * bigF),
    bigC * bigC + bigF * bigF - 1
  ]);
  final angles = ClosedFormMethod.instance
      .realRoots(poly)
      .map((u) => 2 * atan(u))
      .toList();
  // φ=π (u=∞) is missed by the substitution; check if it satisfies the equation.
  if ((bigC * bigC + bigF * bigF - 1).abs() < 1e-9) angles.add(pi);
  return angles;
}
