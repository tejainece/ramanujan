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
/// ([_trimChainEndToChord] / [_trimChainStartToChord]), a
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
  /// ([_trimChainEndToChord] / [_trimChainStartToChord]), so on a
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

    final (kept1, cut1) = _trimChainEndToChord(incoming, vertex, radius);
    final outSrc = identical(outgoing, incoming) ? kept1 : outgoing;
    final (kept2, cut2) = _trimChainStartToChord(outSrc, vertex, radius);

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

  /// Chord-distance counterpart of [VectorPath.trimStart]: walking forward from
  /// the chain's start (which sits at [vertex]). See [_trimChainEndToChord].
  (VectorPath, Trim) _trimChainStartToChord(
    VectorPath chain,
    P vertex,
    double radius,
  ) {
    final segs = chain.segments;
    for (int i = 0; i < segs.length; i++) {
      if (i == segs.length - 1 || segs[i].p2.distanceTo(vertex) >= radius) {
        final t = _paramAtChordDistanceFrom(segs[i], vertex, radius);
        final kept = segs[i].bifurcateAtInterval(t).$2;
        final trim = Trim(
          kept: kept,
          atStart: true,
          tangentDir: segs[i].unitTangentAt(t),
          normalDir: segs[i].unitNormalAt(t),
        );
        return (VectorPath([trim.kept, ...segs.sublist(i + 1)]), trim);
      }
    }
    throw StateError('unreachable: chain is never empty');
  }

  /// Chord-distance counterpart of [VectorPath.trimEnd]: walking backward from
  /// the chain's end (which sits at [vertex]), lands on the first point whose
  /// Euclidean distance from [vertex] is [radius]. If even the chain's start is
  /// nearer than [radius] (possible on a strongly curved chain, whose chord
  /// from the vertex can be much shorter than its arc length), the trim
  /// saturates at the chain's start.
  (VectorPath, Trim) _trimChainEndToChord(
    VectorPath chain,
    P vertex,
    double radius,
  ) {
    final segs = chain.segments;
    for (int i = segs.length - 1; i >= 0; i--) {
      if (i == 0 || segs[i].p1.distanceTo(vertex) >= radius) {
        final t = _paramAtChordDistanceFrom(segs[i], vertex, radius);
        final kept = segs[i].bifurcateAtInterval(t).$1;
        final trim = Trim(
          kept: kept,
          atStart: false,
          tangentDir: segs[i].unitTangentAt(t),
          normalDir: segs[i].unitNormalAt(t),
        );
        return (VectorPath([...segs.sublist(0, i), trim.kept]), trim);
      }
    }
    throw StateError('unreachable: chain is never empty');
  }

  /// Parameter `t` on [segment] at which the point's Euclidean distance from
  /// [origin] equals [distance]. Unlike [Segment.paramAtLength] this is a
  /// straight-line (chord) distance, not an arc length -- used by the inverted
  /// -arc style, whose cut points must lie on a literal circle centered on the
  /// corner's vertex rather than at a given arc-length offset. Found by
  /// bisection bracketed from the segment's end nearer [origin] toward the
  /// farther one, assuming distance from [origin] is monotone along the segment
  /// -- true for a segment (or chain link) that bites away from the corner
  /// rather than curving back around it.
  double _paramAtChordDistanceFrom(Segment segment, P origin, double distance) {
    double lo, hi;
    if (segment.p1.distanceTo(origin) <= segment.p2.distanceTo(origin)) {
      lo = 0.0;
      hi = 1.0;
    } else {
      lo = 1.0;
      hi = 0.0;
    }
    for (int i = 0; i < 50; i++) {
      final mid = (lo + hi) / 2;
      if (segment.lerp(mid).distanceTo(origin) < distance) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }
}
