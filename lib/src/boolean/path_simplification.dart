import 'package:ramanujan/ramanujan.dart';

import 'planar_graph.dart';

/// Normalises [path] into a list of simple, closed, non-self-intersecting
/// faces.
///
/// 1. Force-closes the path: if the gap between the last and first point is
///    within [snapEpsilon] the endpoints are snapped together; otherwise a
///    straight closing [LineSegment] is added.
/// 2. Decomposes self-intersections via [divideSelfIntersecting].
///
/// Zero-area remnants (lollipop tails, hanging segments) are dropped by
/// [divideSelfIntersecting]'s area filter. Returns an empty list for an
/// empty path.
///
/// See also [divideSelfIntersecting] for the decomposition step in isolation.
///
/// Used by boolean operations as Step 1 of the operation pipeline.
List<VectorPath> simplifyClosedPath(VectorPath path,
    {double snapEpsilon = 1e-3}) {
  if (path.segments.isEmpty) return [];

  final first = path.segments.first.p1;
  final last = path.segments.last.p2;

  // TODO why doesnt it use path.isClosed?
  final VectorPath closed;
  if (first == last) {
    closed = path;
  } else if (first.isEqual(last, snapEpsilon)) {
    final segs = path.segments.toList();
    segs[segs.length - 1] = segmentWithP2(segs.last, first);
    closed = VectorPath(segs);
  } else {
    closed = VectorPath([...path.segments, LineSegment(last, first)]);
  }

  return divideSelfIntersecting(closed);
}
