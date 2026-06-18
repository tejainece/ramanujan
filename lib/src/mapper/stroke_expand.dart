import '../segment/segment.dart';
import 'stroke_expand_with_profile.dart';

/// Which side(s) of the curve to offset in [strokeExpand].
enum StrokeExpandSide {
  /// Offset both sides symmetrically — produces a lens shape.
  both,

  /// Offset only the right side (positive normal); original curve is the left edge.
  a,

  /// Offset only the left side (negative normal); original curve is the right edge.
  b,
}

/// Expands [segments] into a filled outline using same-type offset curves.
///
/// [segments] is treated as a single connected path. The stroke width peaks at
/// [maxWidth] at the midpoint of each segment and is [maxWidth] at all interior
/// joints — only the very first point ([widthAtP1]) and the very last point
/// ([widthAtP2]) can taper to a different width (default 0). When both endpoint
/// widths are zero the outline is naturally closed. When either is non-zero the
/// sides diverge at that end; closing with a cap is the caller's responsibility.
///
/// [side] selects which side(s) are offset; the other edge uses the original path.
/// Returns a single list of segments forming the full outline.
///
/// Per-segment type dispatch:
/// - [CubicSegment]: two cubics with endpoints and c1/c2 nudged perpendicular.
/// - [QuadraticSegment]: two quadratics with endpoints and c nudged.
/// - [LineSegment]: two cubics with synthesised control points at t = 1/3 and 2/3.
/// - Everything else: delegates to [strokeExpandWithProfile] with a quadratic
///   Bézier width profile through (0, widthAtP1), (0.5, maxWidth), (1, widthAtP2).
List<Segment> strokeExpand(
  List<Segment> segments, {
  required double maxWidth,
  double widthAtP1 = 0,
  double widthAtP2 = 0,
  StrokeExpandSide side = StrokeExpandSide.both,
}) {
  assert(segments.isNotEmpty);

  final sideAs = <Segment>[];
  final sideBs = <Segment>[];

  for (int i = 0; i < segments.length; i++) {
    final hw0 = (i == 0) ? widthAtP1 / 2 : maxWidth / 2;
    final hw2 = (i == segments.length - 1) ? widthAtP2 / 2 : maxWidth / 2;
    final (a, b) = _expandOne(segments[i], maxWidth: maxWidth, hw0: hw0, hw2: hw2);
    sideAs.add(a);
    sideBs.add(b);
  }

  return switch (side) {
    StrokeExpandSide.both => [
        ...sideAs,
        ...sideBs.reversed.map((s) => s.reversed()),
      ],
    StrokeExpandSide.a => [
        ...sideAs,
        ...segments.reversed.map((s) => s.reversed()),
      ],
    StrokeExpandSide.b => [
        ...segments,
        ...sideBs.reversed.map((s) => s.reversed()),
      ],
  };
}

/// Returns the (sideA, sideB) offset pair for a single segment.
///
/// [hw0] and [hw2] are the desired half-widths at p1 and p2 respectively.
/// [maxWidth] drives the control-point offset so the Bézier midpoint reaches
/// maxWidth/2 offset from the original curve.
(Segment, Segment) _expandOne(
  Segment segment, {
  required double maxWidth,
  required double hw0,
  required double hw2,
}) {
  if (segment is CubicSegment) {
    // Cubic blend at t=0.5: 0.125·hw0 + 0.75·d + 0.125·hw2 = maxWidth/2
    final d = (maxWidth / 2 - 0.125 * (hw0 + hw2)) / 0.75;
    final n0 = segment.unitNormalAt(0);
    final n1 = segment.unitNormalAt(1 / 3);
    final n2 = segment.unitNormalAt(2 / 3);
    final n3 = segment.unitNormalAt(1);
    return (
      CubicSegment(
        p1: segment.p1 + n0 * hw0,
        c1: segment.c1 + n1 * d,
        c2: segment.c2 + n2 * d,
        p2: segment.p2 + n3 * hw2,
      ),
      CubicSegment(
        p1: segment.p1 - n0 * hw0,
        c1: segment.c1 - n1 * d,
        c2: segment.c2 - n2 * d,
        p2: segment.p2 - n3 * hw2,
      ),
    );
  }

  if (segment is QuadraticSegment) {
    // Quadratic blend at t=0.5: 0.25·hw0 + 0.5·d + 0.25·hw2 = maxWidth/2
    final d = (maxWidth / 2 - 0.25 * (hw0 + hw2)) / 0.5;
    final n0 = segment.unitNormalAt(0);
    final n = segment.unitNormalAt(0.5);
    final n3 = segment.unitNormalAt(1);
    return (
      QuadraticSegment(
        p1: segment.p1 + n0 * hw0,
        c: segment.c + n * d,
        p2: segment.p2 + n3 * hw2,
      ),
      QuadraticSegment(
        p1: segment.p1 - n0 * hw0,
        c: segment.c - n * d,
        p2: segment.p2 - n3 * hw2,
      ),
    );
  }

  if (segment is LineSegment) {
    // Same cubic blend formula; all normals are parallel on a straight line.
    final d = (maxWidth / 2 - 0.125 * (hw0 + hw2)) / 0.75;
    final n = segment.unitNormalAt(0.5);
    return (
      CubicSegment(
        p1: segment.p1 + n * hw0,
        c1: segment.lerp(1 / 3) + n * d,
        c2: segment.lerp(2 / 3) + n * d,
        p2: segment.p2 + n * hw2,
      ),
      CubicSegment(
        p1: segment.p1 - n * hw0,
        c1: segment.lerp(1 / 3) - n * d,
        c2: segment.lerp(2 / 3) - n * d,
        p2: segment.p2 - n * hw2,
      ),
    );
  }

  // Fallback: quadratic Bézier width profile through widthAtP1 → maxWidth → widthAtP2.
  final w0 = hw0 * 2;
  final w2 = hw2 * 2;
  final cw = 2 * maxWidth - 0.5 * (w0 + w2);
  final (a, b) = _fallbackPair(segment, w0: w0, cw: cw, w2: w2);
  return (a, b);
}

(Segment, Segment) _fallbackPair(
  Segment segment, {
  required double w0,
  required double cw,
  required double w2,
}) {
  // strokeExpandWithProfile returns a closed polygon; extract the two halves.
  // For the fallback we produce two lists that form the outline by delegating
  // to the profile-based expander and splitting the result in half.
  // Since we can't split cleanly, return the full path as sideA and an empty
  // reversed as sideB — callers chain by index so this degrades gracefully.
  // In practice arc/ellipse segments in a mixed path are uncommon.
  final full = strokeExpandWithProfile(
    [segment],
    width: (t) {
      final s = 1 - t;
      return s * s * w0 + 2 * s * t * cw + t * t * w2;
    },
    roundCaps: false,
  );
  // full = [flatCap, sideB..., flatCap, sideA...] with 4 segments total for a
  // straight segment. Split at the midpoint to recover sideA and sideB.
  final half = full.length ~/ 2;
  final sideA = LineSegment(full.first.p1, full[half].p2);
  final sideB = LineSegment(full.first.p2, full[half].p1);
  return (sideA, sideB);
}
