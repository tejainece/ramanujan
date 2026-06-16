import 'dart:math';

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
    throw UnimplementedError();
  }
}
