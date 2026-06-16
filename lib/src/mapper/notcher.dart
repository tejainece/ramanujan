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
/// notched polyline as [LineSegment]s.
///
/// [notches] must be ordered by ascending [Notch.t]; a notch whose base would
/// overlap the previous one or run past the end of the segment is skipped. The
/// caller decides where the notches go and how they vary (depth, width, tilt),
/// so this is a pure geometric transform — see the demo's stone frame for one
/// way to generate an organic, noise-driven distribution.
///
/// Composes with [VectorCurve.expand].
SegmentMapper notcher(List<Notch> notches, {bool cw = true}) {
  return (Segment segment) {
    final len = segment.length;
    if (len == 0 || notches.isEmpty) return [segment];

    final pts = <P>[segment.p1];
    var lastEnd = 0.0; // last consumed position in param space
    for (final n in notches) {
      final start = n.t - n.halfBefore / len;
      final end = n.t + n.halfAfter / len;
      if (start < lastEnd || end > 1.0) continue; // no room — skip

      final outward = segment.unitNormalAt(n.t, cw: cw).rotate(n.tilt);
      pts
        ..add(segment.lerp(start)) // base toward p1
        ..add(segment.lerp(n.t) + outward * n.depth) // apex along the normal
        ..add(segment.lerp(end)); // base toward p2
      lastEnd = end;
    }
    pts.add(segment.p2);
    return pts.toLines();
  };
}
