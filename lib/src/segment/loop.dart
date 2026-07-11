part of 'vector_path.dart';

/// A closed [VectorPath]: the last segment's [Segment.p2] is the same point
/// as the first segment's [Segment.p1].
///
/// Closedness is enforced at construction. Use [Loop] wherever a closed
/// boundary is required — for example, as a contour of a [Region].
class Loop extends VectorPath {
  Loop._(super.segments) : super._() {
    if (!isClosed()) {
      throw ArgumentError(
          'loop segments must be closed: last p2 must equal first p1',
          'segments');
    }
  }

  factory Loop(Iterable<Segment> segments) => Loop._(List.from(segments));

  /// Returns true if [point] is inside this loop (even-odd ray casting).
  ///
  /// Casts a horizontal ray rightward and counts how many times the boundary
  /// crosses it. Odd count → inside. Near-equal x values (ray hitting a shared
  /// vertex) are deduplicated so a vertex counts as one crossing.
  bool contains(P point) {
    final ray =
        LineSegment(P(point.x - 1, point.y), P(point.x + 1e9, point.y));
    final xs = <double>[];
    for (final seg in segments) {
      for (final p in ray.intersect(seg)) {
        if (p.x > point.x) xs.add(p.x);
      }
    }
    xs.sort();
    int count = 0;
    double? prev;
    for (final x in xs) {
      if (prev == null || (x - prev).abs() > 1e-9) count++;
      prev = x;
    }
    return count.isOdd;
  }
}
