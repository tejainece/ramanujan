import 'dart:math';

import 'package:polynomial/polynomial.dart';
import 'package:ramanujan/ramanujan.dart';

class ArcSegment extends Segment {
  @override
  final P p1;
  @override
  final P p2;

  final P radii;
  final double rotation;
  final bool largeArc;
  final bool clockwise;

  ArcSegment(this.p1, this.p2, this.radii,
      {this.largeArc = false, this.clockwise = true, this.rotation = 0});

  late final Ellipse ellipse = Ellipse.fromSvgParameters(p1, p2, radii,
      rotation: rotation, clockwise: !clockwise, largeArc: largeArc);
      
  @override
  List<P> get controlPoints => const [];

  Affine2d get unitCircleTransform => ellipse.unitCircleTransform;

  @override
  LineSegment get p1Tangent => ellipse.tangentAtPoint(p1);

  @override
  LineSegment get p2Tangent => ellipse.tangentAtPoint(p2);

  @override
  P lerp(double t) =>
      ellipse.lerpBetweenPoints(p1, p2, t, clockwise: clockwise);

  // The arc parameter maps through Clamp.lerp into the ellipse's eccentric
  // angle θ = 2π·forT. The ellipse tangent points toward increasing θ, so we
  // flip it only when forT decreases with t — the single Clamp.lerp branch
  // where that happens is clockwise && t1 > t2.
  @override
  P unitTangentAt(double t) {
    final t1 = ellipse.ilerp(p1);
    final t2 = ellipse.ilerp(p2);
    final forT = Clamp.unit.lerp(t1, t2, t, clockwise: clockwise);
    final dir = ellipse.tangentDirAtAngle(2 * pi * forT);
    return (clockwise && t1 > t2) ? -dir : dir;
  }

  @override
  double ilerp(P point) =>
      ellipse.ilerpBetween(p1, p2, point, clockwise: clockwise);

  @override
  (ArcSegment, ArcSegment) bifurcateAtInterval(double t) {
    P mid = lerp(t);
    bool arc1LargeArc =
        ellipse.arcLengthBetweenPoints(p1, mid, clockwise: clockwise) >
            ellipse.perimeter / 2;
    bool arc2LargeArc =
        ellipse.arcLengthBetweenPoints(mid, p2, clockwise: clockwise) >
            ellipse.perimeter / 2;
    return (
      ArcSegment(p1, mid, radii,
          rotation: rotation, clockwise: clockwise, largeArc: arc1LargeArc),
      ArcSegment(mid, p2, radii,
          rotation: rotation, clockwise: clockwise, largeArc: arc2LargeArc)
    );
  }

  @override
  ArcSegment reversed() {
    return ArcSegment(p2, p1, radii,
        largeArc: largeArc, clockwise: !clockwise, rotation: rotation);
  }

  @override
  double get length => ellipse.arcLengthBetweenAngles(
      ellipse.angleOfPoint(p1), ellipse.angleOfPoint(p2),
      clockwise: clockwise);

  late final LineSegment chord = LineSegment(p1, p2);

  P get center => ellipse.center;

  @override
  bool operator ==(other) =>
      other is ArcSegment &&
      other.p1 == p1 &&
      other.p2 == p2 &&
      other.radii == radii &&
      other.largeArc == largeArc &&
      other.clockwise == clockwise &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(p1, p2, radii, rotation, largeArc, clockwise);

  String get soloSvg =>
      'M${p1.x},${p1.y}A${radii.x},${radii.y},$rotation,${largeArc ? 1 : 0},${clockwise ? 0 : 1},${p2.x},${p2.y}';

  @override
  R get boundingBox {
    R ret = R.fromPoints(p1, p2);
    if (startAngle.equals(endAngle)) {
      return ret;
    }
    final xBounds = ellipse.xBoundsWithAngle();
    final yBounds = ellipse.yBoundsWithAngle();
    if (clockwise) {
      if (xBounds.$1.angle.isBetweenCW(startAngle, endAngle)) {
        ret = ret.includeX(xBounds.$1.value);
      }
      if (xBounds.$2.angle.isBetweenCW(startAngle, endAngle)) {
        ret = ret.includeX(xBounds.$2.value);
      }
      if (yBounds.$1.angle.isBetweenCW(startAngle, endAngle)) {
        ret = ret.includeY(yBounds.$1.value);
      }
      if (yBounds.$2.angle.isBetweenCW(startAngle, endAngle)) {
        ret = ret.includeY(yBounds.$2.value);
      }
    } else {
      if (xBounds.$1.angle.isBetweenCCW(startAngle, endAngle)) {
        ret = ret.includeX(xBounds.$1.value);
      }
      if (xBounds.$2.angle.isBetweenCCW(startAngle, endAngle)) {
        ret = ret.includeX(xBounds.$2.value);
      }
      if (yBounds.$1.angle.isBetweenCCW(startAngle, endAngle)) {
        ret = ret.includeY(yBounds.$1.value);
      }
      if (yBounds.$2.angle.isBetweenCCW(startAngle, endAngle)) {
        ret = ret.includeY(yBounds.$2.value);
      }
    }
    return ret;
  }

  late final Radian startAngle = ellipse.angleOfPoint(p1);

  late final Radian endAngle = ellipse.angleOfPoint(p2);

  @override
  List<P> intersect(Segment other) {
    if (other is LineSegment) return intersectLine(other);
    if (other is QuadraticSegment) return intersectQuadratic(other);
    if (other is CubicSegment) {
      throw UnimplementedError(
          'ArcSegment × CubicSegment: degree 6, no closed form');
    }
    if (other is CircularArcSegment) return intersectCircularArc(other);
    if (other is ArcSegment) return intersectArc(other);
    throw ArgumentError(
        'ArcSegment.intersect with ${other.runtimeType} not implemented');
  }

  List<P> intersectLine(LineSegment l) => l.intersectArc(this);

  List<P> intersectQuadratic(QuadraticSegment q) => q.intersectArc(this);

  // Parameterize this arc by eccentric angle φ; find φ where the ellipse point
  // also lies on ca's circle via Weierstrass substitution.
  List<P> intersectCircularArc(CircularArcSegment ca) {
    final caInvUCT = Affine2d(
        scaleX: 1 / ca.radius,
        scaleY: 1 / ca.radius,
        translateX: -ca.center.x / ca.radius,
        translateY: -ca.center.y / ca.radius);
    final composed = caInvUCT * ellipse.unitCircleTransform;
    final result = <P>[];
    for (final phi in _weierstrassAngles(composed)) {
      final normPhi = Radian(Radian(phi).value);
      final inRange = clockwise
          ? normPhi.isBetweenCW(startAngle, endAngle)
          : normPhi.isBetweenCCW(startAngle, endAngle);
      if (!inRange) continue;
      final p = ellipse.unitCircleTransform.apply(P(cos(phi), sin(phi)));
      if (_onCircularArc(ca, p)) result.add(p);
    }
    return result;
  }

  // Parameterize this arc by eccentric angle φ; find φ where the ellipse point
  // also lies on other's ellipse via Weierstrass substitution.
  List<P> intersectArc(ArcSegment other) {
    final composed =
        other.ellipse.inverseUnitCircleTransform * ellipse.unitCircleTransform;
    final result = <P>[];
    for (final phi in _weierstrassAngles(composed)) {
      final normPhi = Radian(Radian(phi).value);
      final inRange = clockwise
          ? normPhi.isBetweenCW(startAngle, endAngle)
          : normPhi.isBetweenCCW(startAngle, endAngle);
      if (!inRange) continue;
      final p = ellipse.unitCircleTransform.apply(P(cos(phi), sin(phi)));
      if (!_onArc(other, p)) continue;
      result.add(p);
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
