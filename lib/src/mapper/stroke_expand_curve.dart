import 'dart:math' as math;

import '../segment/segment.dart';
import 'stroke_expand.dart';

/// Which side(s) of the curve to offset in [strokeExpand].
enum StrokeExpandSide {
  /// Offset both sides symmetrically — produces a lens shape.
  both,

  /// Offset only the right side (positive normal); original curve is the left edge.
  a,

  /// Offset only the left side (negative normal); original curve is the right edge.
  b,
}

/// Expands [segment] into a closed filled path using same-type offset curves.
///
/// The stroke tapers naturally from zero at both endpoints to [maxWidth] at the
/// midpoint — driven by the Bézier blending of the offset control points rather
/// than an explicit profile function. Because width is zero at both endpoints the
/// two sides share p1 and p2, so no caps are required.
///
/// [side] selects which side(s) are offset; the other edge is the original curve.
/// Returns two segments forming a closed outline.
///
/// Type dispatch:
/// - [CubicSegment]: two cubics with c1/c2 nudged perpendicular to the curve.
///   Control-point offset = 2·maxWidth/3 so that the Bézier midpoint (blend 0.75)
///   lands at exactly maxWidth/2.
/// - [QuadraticSegment]: two quadratics with c nudged by maxWidth so the midpoint
///   (blend 0.5) is at maxWidth/2.
/// - [LineSegment]: two cubics with synthesised control points at t = 1/3 and 2/3,
///   using the same cubic correction factor.
/// - Everything else: delegates to [strokeExpandWithProfile] with a sin profile.
List<Segment> strokeExpand(
  Segment segment, {
  required double maxWidth,
  StrokeExpandSide side = StrokeExpandSide.both,
}) {
  if (segment is CubicSegment) {
    // Cubic blend at t=0.5 with two equal offsets = 0.75·d.
    // Set d = 2·maxWidth/3 so midpoint offset = 0.75 · (2·maxWidth/3) = maxWidth/2.
    final d = maxWidth * 2 / 3;
    final n1 = segment.unitNormalAt(1 / 3);
    final n2 = segment.unitNormalAt(2 / 3);
    final sideA = CubicSegment(
      p1: segment.p1,
      c1: segment.c1 + n1 * d,
      c2: segment.c2 + n2 * d,
      p2: segment.p2,
    );
    final sideB = CubicSegment(
      p1: segment.p1,
      c1: segment.c1 - n1 * d,
      c2: segment.c2 - n2 * d,
      p2: segment.p2,
    );
    return _assemble(segment, sideA, sideB, side);
  }

  if (segment is QuadraticSegment) {
    // Quadratic blend at t=0.5 = 0.5·d. Set d = maxWidth so midpoint = maxWidth/2.
    final d = maxWidth;
    final n = segment.unitNormalAt(0.5);
    final sideA = QuadraticSegment(
      p1: segment.p1,
      c: segment.c + n * d,
      p2: segment.p2,
    );
    final sideB = QuadraticSegment(
      p1: segment.p1,
      c: segment.c - n * d,
      p2: segment.p2,
    );
    return _assemble(segment, sideA, sideB, side);
  }

  if (segment is LineSegment) {
    final d = maxWidth * 2 / 3;
    final n = segment.unitNormalAt(0.5);
    final sideA = CubicSegment(
      p1: segment.p1,
      c1: segment.lerp(1 / 3) + n * d,
      c2: segment.lerp(2 / 3) + n * d,
      p2: segment.p2,
    );
    final sideB = CubicSegment(
      p1: segment.p1,
      c1: segment.lerp(1 / 3) - n * d,
      c2: segment.lerp(2 / 3) - n * d,
      p2: segment.p2,
    );
    return _assemble(segment, sideA, sideB, side);
  }

  return strokeExpandWithProfile(
    segment,
    width: (t) => maxWidth * math.sin(math.pi * t),
  );
}

List<Segment> _assemble(
  Segment original,
  Segment sideA,
  Segment sideB,
  StrokeExpandSide side,
) =>
    switch (side) {
      StrokeExpandSide.both => [sideA, sideB.reversed()],
      StrokeExpandSide.a => [sideA, original.reversed()],
      StrokeExpandSide.b => [original, sideB.reversed()],
    };
