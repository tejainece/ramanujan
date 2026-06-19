import 'package:ramanujan/ramanujan.dart';

/// A single triangular notch to carve into a segment. Positions and sizes are
/// supplied by the caller — this carries no randomness, so geometry built from
/// it is fully determined by its inputs.
///
/// Note the two coordinate spaces: [t] locates the apex *parametrically* along
/// the segment (`[0, 1]`), while [depth] and the half-widths are *physical*
/// sizes in the segment's coordinate units. So the same `Notch` carves an
/// equally-sized bite regardless of how long the segment is; only where it
/// lands scales with length. `notcher` converts the half-widths to parameter
/// space internally (dividing by segment length).
class Notch {
  /// Position of the notch apex along the segment, as a parameter in `[0, 1]`.
  final double t;

  /// Cut depth toward the segment normal, in the segment's coordinate units
  /// (a physical size, not a fraction of the segment).
  final double depth;

  /// Base half-width toward the segment's start (p1), in coordinate units
  /// (a physical size, not a fraction of the segment).
  final double halfBefore;

  /// Base half-width toward the segment's end (p2), in coordinate units
  /// (a physical size, not a fraction of the segment).
  final double halfAfter;

  /// Apex tilt, in radians, rotating the cut off the pure normal.
  final double tilt;

  const Notch({
    required this.t,
    required this.depth,
    required this.halfBefore,
    required this.halfAfter,
    this.tilt = 0,
  });
}

/// A [SegmentMapper] that carves the given [notches] into a segment — each a
/// triangular bite cut toward the segment's [cw] normal — and returns the
/// notched result as a mix of original sub-curves (between notches) and
/// [LineSegment]s (the notch cuts themselves).
///
/// [notches] must be ordered by ascending [Notch.t]; a notch whose base would
/// overlap the previous one or run past the end of the segment is skipped. The
/// caller decides where the notches go and how they vary (depth, width, tilt),
/// so this is a pure geometric transform — see the demo's stone frame for one
/// way to generate an organic, noise-driven distribution.
///
/// Composes with [VectorPath.expand].
SegmentMapper notcher(List<Notch> notches, {bool cw = true}) {
  return (Segment segment) {
    final len = segment.length;
    if (len == 0 || notches.isEmpty) return [segment];

    final result = <Segment>[];
    var lastEnd = 0.0; // last consumed position in param space
    for (final n in notches) {
      final start = n.t - n.halfBefore / len;
      final end = n.t + n.halfAfter / len;
      if (start < lastEnd || end > 1.0) continue; // no room — skip

      // Preserve the original curve from lastEnd up to the notch base
      if (start > lastEnd) {
        result.add(_subSegment(segment, lastEnd, start));
      }

      // Notch cut: two line segments forming the triangular bite
      final outward = segment.unitNormalAt(n.t, cw: cw).rotate(n.tilt);
      final apexPt = segment.lerp(n.t) + outward * n.depth;
      result
        ..add(LineSegment(segment.lerp(start), apexPt))
        ..add(LineSegment(apexPt, segment.lerp(end)));

      lastEnd = end;
    }

    // Preserve the original curve from the last notch base to the segment end
    if (lastEnd < 1.0) {
      result.add(_subSegment(segment, lastEnd, 1.0));
    }

    return result;
  };
}

/// Extracts the sub-curve of [s] between parameters [t1] and [t2] using
/// de Casteljau splitting, preserving the original segment type.
Segment _subSegment(Segment s, double t1, double t2) {
  if (t1 <= 0 && t2 >= 1) return s;
  if (t1 <= 0) return s.bifurcateAtInterval(t2).$1;
  if (t2 >= 1) return s.bifurcateAtInterval(t1).$2;
  // Split off the left part, then trim the remaining right part
  final right = s.bifurcateAtInterval(t1).$2;
  final tRel = (t2 - t1) / (1.0 - t1);
  return right.bifurcateAtInterval(tRel).$1;
}
