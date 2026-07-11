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
  double ilerp(P point) {
    // Map to unit-circle space: the point is on the ellipse iff its image
    // has distance 1 from the origin.
    final ucp = ellipse.inverseUnitCircleTransform.apply(point);
    if ((ucp.x * ucp.x + ucp.y * ucp.y - 1.0).abs() > 1e-3) return double.nan;
    return ellipse.ilerpBetween(p1, p2, point, clockwise: clockwise);
  }

  @override
  double closestT(P point) {
    // In the ellipse's local (rotated, unscaled) frame with semi-axes a/b and
    // query point q, the distance to E(θ) = (a·cosθ, b·sinθ) is stationary
    // where (b²−a²)·sinθ·cosθ + a·qx·sinθ − b·qy·cosθ = 0. The Weierstrass
    // substitution u = tan(θ/2) turns this into a quartic in u — the same
    // technique the intersection code uses. The minimum over the arc is at a
    // stationary point inside its angular span or at an endpoint.
    final el = ellipse;
    final dp = point - el.center;
    final qx = dp.x * el.costh + dp.y * el.sinth;
    final qy = -dp.x * el.sinth + dp.y * el.costh;
    final a = el.radii.x, b = el.radii.y;
    final k = b * b - a * a;
    final poly = Polynomial([
      -b * qy,
      2 * (a * qx + k),
      0,
      2 * (a * qx - k),
      b * qy,
    ]);
    final thetas = [
      for (final u in ClosedFormMethod.instance.realRoots(poly)) 2 * atan(u),
      pi, // u=∞ is missed by the substitution; harmless as an extra candidate.
    ];
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
    for (final theta in thetas) {
      final cand = el.unitCircleTransform.apply(P(cos(theta), sin(theta)));
      if (!containsPointAngle(cand)) continue;
      final t = ilerp(cand);
      if (t.isNaN) continue;
      consider(t.clamp(0.0, 1.0));
    }
    return bestT;
  }

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
  P getPointByAddress(PointId id) => switch (id) {
        PointId.p1 => p1,
        PointId.p2 => p2,
        _ => throw ArgumentError('ArcSegment has no point $id'),
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
          throw ArgumentError('ArcSegment has no point ${e.key.name}');
      }
    }
    return ArcSegment(np1, np2, radii,
        largeArc: largeArc, clockwise: clockwise, rotation: rotation);
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

  /// Whether [point] — assumed already on this arc's ellipse — lies within the
  /// arc's angular span, honouring winding direction. The eccentric angle is
  /// read in the ellipse's unit-circle space; this is the winding-aware check
  /// that handles clockwise arcs and arcs crossing 0.
  bool containsPointAngle(P point) {
    final q = ellipse.inverseUnitCircleTransform.apply(point);
    final ang = Radian(Radian(atan2(q.y, q.x)).value);
    return clockwise
        ? ang.isBetweenCW(startAngle, endAngle)
        : ang.isBetweenCCW(startAngle, endAngle);
  }

  @override
  CoincidentOverlap? coincidentOverlap(Segment other) {
    if (other is LineSegment) return null;
    if (other is ArcSegment) {
      if (!ellipse.isEqual(other.ellipse)) return null;
    } else if (other is CircularArcSegment) {
      if (!center.isEqual(other.center, 1e-3)) return null;
    }
    // Use lerp(0)/lerp(1) rather than p1/p2 for the same reason as
    // CircularArcSegment: clockwise arcs have lerp(0)≠p1.
    return overlapFromBoundaries(this, other,
        ilerp(other.lerp(0)), ilerp(other.lerp(1)),
        other.ilerp(lerp(0)), other.ilerp(lerp(1)));
  }

  @override
  List<P> intersect(Segment other) {
    if (other is LineSegment) return intersectLine(other);
    if (other is QuadraticSegment) return intersectQuadratic(other);
    if (other is CubicSegment) return other.intersectArc(this);
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
      if (ca.containsPointAngle(p)) result.add(p);
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
      if (!other.containsPointAngle(p)) continue;
      result.add(p);
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
