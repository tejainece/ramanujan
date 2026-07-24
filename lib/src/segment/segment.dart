import 'package:ramanujan/ramanujan.dart';

export 'arc.dart';
export 'circular.dart';
export 'coincident_overlap.dart';
export 'cubic.dart';
export 'line.dart';
export 'quadratic.dart';

enum PointId { p1, p2, c1, c2, c3 }

/// Result of trimming a segment back by some distance from one of its ends.
class Trim {
  const Trim({
    required this.kept,
    required this.atStart,
    required this.tangentDir,
    required this.normalDir,
  });

  /// The shortened segment.
  final Segment kept;

  /// Whether the trim point is [kept]'s `p1` end (vs. its `p2` end).
  final bool atStart;

  /// The new trim endpoint.
  P get point => atStart ? kept.p1 : kept.p2;

  /// Unit tangent at [point], from the original (pre-trim) segment: [kept]
  /// itself may be a zero-length leftover when the trim distance saturates
  /// at [kept]'s far end, which has no well-defined tangent of its own.
  final P tangentDir;

  /// Unit normal at [point]. See [tangentDir].
  final P normalDir;
}

abstract class Segment {
  static List<Segment> rect(R rect) => [
    LineSegment(rect.topLeft, rect.topRight),
    LineSegment(rect.topRight, rect.bottomRight),
    LineSegment(rect.bottomRight, rect.bottomLeft),
    LineSegment(rect.bottomLeft, rect.topLeft),
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

  double ilerp(P point, {double epsilon = 1e-3});

  /// Parameter t in [0,1] of the point on this segment closest to [point].
  ///
  /// Unlike [ilerp], [point] need not lie on the curve.
  double closestT(P point);

  /// The point on this segment closest to [point]. See [closestT].
  P closestPoint(P point) => lerp(closestT(point));

  /// Parameter `t` in `[0,1]` at which the leading piece of this segment --
  /// the part from `p1` up to `t` -- has arc length [distance].
  double paramAtLength(double distance);

  /// Whether [point] lies on this segment (not just its underlying curve),
  /// within [epsilon].
  bool isPointOn(P point, {double epsilon = 1e-3}) =>
      !ilerp(point, epsilon: epsilon).isNaN;

  Segment reversed();

  /// This segment mapped through [affine]. Lines and béziers transform their
  /// points exactly; a circular arc stays circular under a similarity and
  /// becomes an elliptical [ArcSegment] otherwise; a reflection (negative
  /// determinant) flips the winding direction of arcs.
  Segment transform(Affine2d affine);

  R get boundingBox;

  (Segment, Segment) bifurcateAtInterval(double t);

  /// Slices this segment between parameters [t1] and [t2] in [0, 1],
  /// or returns null if [t1] >= [t2].
  Segment? slice(double t1, double t2) {
    final startT = t1.clamp(0.0, 1.0);
    final endT = t2.clamp(0.0, 1.0);
    if (startT >= endT) return null;
    if (startT == 0.0 && endT == 1.0) return this;

    var current = this;
    if (endT < 1.0) {
      current = current.bifurcateAtInterval(endT).$1;
    }
    if (startT > 0.0) {
      final u = startT / endT;
      current = current.bifurcateAtInterval(u.clamp(0.0, 1.0)).$2;
    }
    return current;
  }

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

  /// Trims this segment back by arc length [distance] from its `p2` end.
  /// Found via [paramAtLength] on the reversed segment (so "distance from
  /// p2" becomes "distance from p1" of the reversal), relying on
  /// `reversed().lerp(t) == lerp(1 - t)`.
  Trim trimEnd(double distance) {
    final t = 1 - reversed().paramAtLength(distance);
    final kept = bifurcateAtInterval(t).$1;
    return Trim(
      kept: kept,
      atStart: false,
      tangentDir: unitTangentAt(t),
      normalDir: unitNormalAt(t),
    );
  }

  /// Trims this segment back by arc length [distance] from its `p1` end.
  /// See [trimEnd].
  Trim trimStart(double distance) {
    final t = paramAtLength(distance);
    final kept = bifurcateAtInterval(t).$2;
    return Trim(
      kept: kept,
      atStart: true,
      tangentDir: unitTangentAt(t),
      normalDir: unitNormalAt(t),
    );
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
