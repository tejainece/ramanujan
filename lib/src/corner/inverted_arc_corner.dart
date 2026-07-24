part of 'corner.dart';

/// Concave "inverted round" corner (Illustrator's Inverted Round, Inkscape's
/// Inverse Fillet) -- the picture-frame-mat / movie-ticket-notch look: cuts
/// both sides back to the same points a normal round would (their
/// [CornerRadius.incoming]/[CornerRadius.outgoing], averaged into one radius
/// for the same tangent-length reason as [CircularArcCorner]), then bridges
/// those two points with the arc of that literal circle **centered at the
/// original vertex** rather than tangent to the lines.
///
/// Unlike every other style, the cut points are *not* found by cutting back
/// a given arc length: they are wherever the circle of that radius centered
/// on the vertex crosses the incoming/outgoing segments
/// ([_cutChainIncomingToChord] / [_cutChainOutgoingToChord]), a
/// Euclidean-distance condition rather than an arc-length one. For a
/// straight line the two coincide exactly, since the line passes straight
/// through its own endpoint -- which is why the original line-only version
/// of this style could get away with an ordinary distance-along-the-line
/// cut. For a curved segment they generally differ, so using an arc-length
/// cut there (as every other style does) would place the point off the
/// circle, breaking the "arc of the vertex-centered circle" construction
/// this style is built on.
///
/// Because each side meets that circle rather than being tangent to it, the
/// corner meets the arc at whatever angle the segment's tangent happens to
/// make with the circle there -- for a line this is a right angle (the line
/// passes through the circle's center); for a curve it generally is not, but
/// it is still a real corner, not a blended fillet, matching the reference
/// construction (draw a circle centered on the corner, then
/// Pathfinder/Boolean-subtract it). The arc never extends past the original
/// vertex; it only ever bites material away from inside the original angle.
final class InvertedArcCorner extends CornerStyle {
  const InvertedArcCorner();

  @override
  bool get honorsAsymmetricRadius => false;

  @override
  (VectorPath, Segment, VectorPath) _constructChain(
    VectorPath incoming,
    VectorPath outgoing,
    CornerRadius radius,
    P vertex,
  ) => _roundChain(incoming, outgoing, radius.averaged, vertex);

  /// Chain-generalized core, shared with [roundAllCorners]: [incoming] and
  /// [outgoing] are contiguous runs of segments meeting at [vertex]. The two
  /// cut points are wherever the circle of [radius] centered on [vertex]
  /// first crosses each chain walking away from the corner
  /// ([_cutChainIncomingToChord] / [_cutChainOutgoingToChord]), so on a
  /// multi-segment chain the notch's endpoint may land past any number of
  /// intermediate junctions -- the crossing is a property of the circle, not
  /// of segment boundaries, so the construction generalizes unchanged. The
  /// sweep direction comes from the turn between the two chains' tangents
  /// *at the vertex*, same as the single-corner version. When [incoming] and
  /// [outgoing] are the same list (a closed path with a single rounded
  /// corner), the outgoing cut is applied to the incoming cut's remainder so
  /// both trims survive in the returned chain.
  (VectorPath, Segment, VectorPath) _roundChain(
    VectorPath incoming,
    VectorPath outgoing,
    double radius,
    P vertex,
  ) {
    final turn =
        incoming.segments.last.unitTangentAt(1).angle -
        outgoing.segments.first.unitTangentAt(0).angle;

    final (kept1, cut1) = _cutChainIncomingToChord(incoming, vertex, radius);
    final outSrc = identical(outgoing, incoming) ? kept1 : outgoing;
    final (kept2, cut2) = _cutChainOutgoingToChord(outSrc, vertex, radius);

    return (
      kept1,
      CircularArcSegment(
        cut1.point,
        cut2.point,
        radius,
        clockwise: turn.value >= pi,
        largeArc: false,
      ),
      kept2,
    );
  }
}
