import 'package:ramanujan/ramanujan.dart';

export 'arc.dart';
export 'circular.dart';
export 'coincident_overlap.dart';
export 'cubic.dart';
export 'line.dart';
export 'quadratic.dart';
export 'live_region.dart';

enum PointId {
  p1, p2, c1, c2, c3
}

abstract class Segment {
  static List<Segment> rect(R rect) => [
        LineSegment(rect.topLeft, rect.topRight),
        LineSegment(rect.topRight, rect.bottomRight),
        LineSegment(rect.bottomRight, rect.bottomLeft),
        LineSegment(rect.bottomLeft, rect.topLeft)
      ];

  P get p1;

  P get p2;

  List<P> get endPoints => [p1, p2];

  List<P> get controlPoints;

  P getPointByAddress(PointId id);

  List<TangiblePointAddress> getPointAddresses();

  Segment updateByPointAddresses(Map<TangiblePointAddress, P> updates);

  LineSegment get p1Tangent;

  LineSegment get p2Tangent;

  LineSegment get line => LineSegment(p1, p2);

  double get length;

  P lerp(double t);

  double ilerp(P point);

  /// Parameter t in [0,1] of the point on this segment closest to [point].
  ///
  /// Unlike [ilerp], [point] need not lie on the curve.
  double closestT(P point);

  /// The point on this segment closest to [point]. See [closestT].
  P closestPoint(P point) => lerp(closestT(point));

  // TODO is point on curve?

  Segment reversed();

  R get boundingBox;

  (Segment, Segment) bifurcateAtInterval(double t);

  List<Segment> split([int count = 2]) {
    final ret = <Segment>[];
    final step = 1.0 / count;
    Segment prev = this;
    for (int i = 0; i < count - 1; i++) {
      final t = step * (1 - step * i);

      final parts = prev.bifurcateAtInterval(t);
      prev = parts.$2;
      ret.add(parts.$1);
    }
    ret.add(prev);
    return ret;
  }

  List<P> intersect(Segment other);

  /// Returns the parameter-space overlap if this segment and [other] are
  /// coincident (trace the same geometric curve over some interval), or `null`
  /// if they are not coincident or do not overlap.
  CoincidentOverlap? coincidentOverlap(Segment other);

  /// Unit tangent (direction of travel as [t] increases) at parameter [t].
  /// Implemented analytically per segment type.
  P unitTangentAt(double t);

  /// Unit normal at parameter [t], on the [cw] side — the tangent rotated 90°
  /// (clockwise, in a y-down space, when [cw] is true).
  P unitNormalAt(double t, {bool cw = true}) {
    final tan = unitTangentAt(t);
    return cw ? P(tan.y, -tan.x) : P(-tan.y, tan.x);
  }
}