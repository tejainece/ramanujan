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
  (List<Segment>, Segment, List<Segment>) _constructChain(
    List<Segment> incoming,
    List<Segment> outgoing,
    double radius1,
    double radius2,
    P vertex,
  ) => _roundChainInverted(incoming, outgoing, (radius1 + radius2) / 2, vertex);
}
