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

  CircularArcSegment(
    this.p1,
    this.p2,
    this.radius, {
    this.largeArc = false,
    this.clockwise = true,
  });

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
    return (diff.x * diff.x +
            diff.y * diff.y -
            effectiveRadius * effectiveRadius)
        .equals(0, epsilon);
  }

  /// Whether [point] — assumed already on this arc's circle — lies within the
  /// arc's angular span, honouring winding direction. Normalizes via `.value`
  /// so atan2-derived negative angles match `startAngle`/`endAngle`.
  bool containsPointAngle(P point) {
    final ang = Radian(angleOfPoint(point).value);
    return clockwise
        ? ang.isBetweenCW(startAngle, endAngle)
        : ang.isBetweenCCW(startAngle, endAngle);
  }

  @override
  P lerp(double t) {
    Radian angle;
    if (clockwise) {
      angle = startAngle - this.angle.value * t;
    } else {
      angle = startAngle + this.angle.value * t;
    }
    return P.onCircle(angle.value, effectiveRadius, center);
  }

  @override
  P unitTangentAt(double t) {
    final a = startAngle.value + (clockwise ? -angle.value : angle.value) * t;
    final d = P(-sin(a), cos(a));
    return clockwise ? -d : d;
  }

  @override
  double ilerp(P point, {double epsilon = 1e-3}) {
    if (!isOnCircle(point, epsilon: epsilon)) return double.nan;
    if (!containsPointAngle(point)) return double.nan;
    final ang = angleOfPoint(point);
    if (clockwise) {
      return (startAngle - ang).value / angle.value;
    } else {
      return (ang - startAngle).value / angle.value;
    }
  }

  @override
  double closestT(P point) {
    // Radially projecting [point] onto the circle gives the nearest circle
    // point; it is the answer whenever it falls inside the arc's angular span.
    // Otherwise the minimum is at the closer endpoint.
    final ang = Radian(angleOfPoint(point).value);
    final inSpan = clockwise
        ? ang.isBetweenCW(startAngle, endAngle)
        : ang.isBetweenCCW(startAngle, endAngle);
    if (inSpan) {
      final t = clockwise
          ? (startAngle - ang).value / angle.value
          : (ang - startAngle).value / angle.value;
      if (t >= 0 && t <= 1) return t;
    }
    return point.distanceTo(lerp(0)) <= point.distanceTo(lerp(1)) ? 0.0 : 1.0;
  }

  // [lerp] sweeps the angle linearly in `t`, so arc length from `p1` to `t`
  // is exactly `length * t` -- same closed form as a line.
  @override
  double paramAtLength(double distance) =>
      length <= 1e-12 ? 0.0 : (distance / length).clamp(0.0, 1.0);

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
        largeArc: arc1LargeArc,
        clockwise: clockwise,
      ),
      CircularArcSegment(
        p,
        p2,
        radius,
        largeArc: arc2LargeArc,
        clockwise: clockwise,
      ),
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
    return CircularArcSegment(
      np1,
      np2,
      radius,
      largeArc: largeArc,
      clockwise: clockwise,
    );
  }

  @override
  CircularArcSegment reversed() => CircularArcSegment(
    p2,
    p1,
    radius,
    largeArc: largeArc,
    clockwise: !clockwise,
  );

  @override
  Segment transform(Affine2d affine) {
    final flipped = affine.det < 0;
    if (affine.isSimilarity) {
      final scale = sqrt(affine.det.abs());
      return CircularArcSegment(
        affine.apply(p1),
        affine.apply(p2),
        radius * scale,
        largeArc: largeArc,
        clockwise: flipped ? !clockwise : clockwise,
      );
    }
    // A non-uniform scale or skew turns the circle into an ellipse.
    final image = affine.unitCircleImage;
    return ArcSegment(
      affine.apply(p1),
      affine.apply(p2),
      image.radii * effectiveRadius,
      rotation: image.rotation,
      largeArc: largeArc,
      clockwise: flipped ? !clockwise : clockwise,
    );
  }

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
      ret = ret.includePoint(
        center.x + effectiveRadius * cos(angle.value),
        center.y + effectiveRadius * sin(angle.value),
      );
    }
    return ret;
  }

  @override
  CoincidentOverlap? coincidentOverlap(Segment other) {
    if (other is LineSegment) return null;
    if (other is CircularArcSegment) {
      if (!center.isEqual(other.center, 1e-3)) return null;
      if ((effectiveRadius - other.effectiveRadius).abs() > 1e-3) return null;
    } else if (other is ArcSegment) {
      // An elliptic arc with equal semi-axes is circular and may coincide.
      // Fast-reject on center before computing ilerp values.
      if (!center.isEqual(other.center, 1e-3)) return null;
    }
    // Use lerp(0)/lerp(1) rather than p1/p2: for clockwise arcs lerp(0)≠p1,
    // so the parameterized endpoints diverge from the declared endpoints.
    final otherStart = other.lerp(0);
    final otherEnd = other.lerp(1);
    return overlapFromBoundaries(
      this,
      other,
      ilerp(otherStart),
      ilerp(otherEnd),
      other.ilerp(lerp(0)),
      other.ilerp(lerp(1)),
    );
  }

  @override
  List<P> intersect(Segment other) {
    if (other is LineSegment) return intersectLine(other);
    if (other is QuadraticSegment) return intersectQuadratic(other);
    if (other is CubicSegment) return other.intersectCircularArc(this);
    if (other is CircularArcSegment) return intersectCircularArc(other);
    if (other is ArcSegment) return intersectArc(other);
    throw ArgumentError(
      'CircularArcSegment.intersect with ${other.runtimeType} not implemented',
    );
  }

  List<P> intersectLine(LineSegment l) => l.intersectCircularArc(this);

  List<P> intersectQuadratic(QuadraticSegment q) =>
      q.intersectCircularArc(this);

  List<P> intersectCircularArc(CircularArcSegment other) {
    final circle1 = Circle(center: center, radius: effectiveRadius);
    final circle2 = Circle(center: other.center, radius: other.effectiveRadius);
    return circle1
        .intersectCircle(circle2)
        .where((p) => containsPointAngle(p) && other.containsPointAngle(p))
        .toList();
  }

  // Parameterize this circular arc by eccentric angle φ; find φ where the
  // circle point also lies on a's ellipse via Weierstrass substitution.
  List<P> intersectArc(ArcSegment a) {
    final caUCT = Affine2d(
      scaleX: effectiveRadius,
      scaleY: effectiveRadius,
      translateX: center.x,
      translateY: center.y,
    );
    final composed = a.ellipse.inverseUnitCircleTransform * caUCT;
    final result = <P>[];
    for (final phi in _weierstrassAngles(composed)) {
      final p = P(
        center.x + effectiveRadius * cos(phi),
        center.y + effectiveRadius * sin(phi),
      );
      if (!containsPointAngle(p)) continue;
      if (a.containsPointAngle(p)) result.add(p);
    }
    return result;
  }
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
    bigC * bigC + bigF * bigF - 1,
  ]);
  final angles = ClosedFormMethod.instance
      .realRoots(poly)
      .map((u) => 2 * atan(u))
      .toList();
  // φ=π (u=∞) is missed by the substitution; check if it satisfies the equation.
  if ((bigC * bigC + bigF * bigF - 1).abs() < 1e-9) angles.add(pi);
  return angles;
}
