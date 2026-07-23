part of 'corner.dart';

/// Rounds the corner with a single cubic Bézier, cutting the incoming side
/// back by [CornerRadius.incoming] and the outgoing side back by
/// [CornerRadius.outgoing] independently. Both interior control points are
/// anchored at the same point: the intersection of the two cut points'
/// tangent lines (see [QuadraticBezierCorner]). Since `{p1, anchor, anchor}`
/// and `{anchor, anchor, p2}` are each trivially collinear, curvature is
/// exactly zero at both ends of the curve.
///
/// When both adjacent segments are straight lines that anchor is the shared
/// vertex, and zero curvature there matches the (also zero) curvature of the
/// lines it meets -- the guarantee the original line-only version of this
/// style made. When either adjacent segment is curved, this construction
/// still gives an exact tangent match (the curve leaves each cut point along
/// that segment's own tangent direction) but *not* a curvature match: the
/// fillet's curvature is forced to zero at that end regardless of what
/// curvature the adjacent curve actually has there, so a curved neighbor
/// still produces a curvature jump at the join, just no longer a tangent
/// jump. Matching curvature as well would mean solving for the control point
/// from the neighbor's actual curvature at the cut point, not merely its
/// tangent -- a materially different (and heavier) construction this style
/// does not attempt.
///
/// This continuous-curvature property -- curvature easing from 0 into the
/// fillet and back to 0, rather than jumping instantly the way it does at
/// the tangent points of a circular arc -- is also why this construction is
/// aliased as [CornerStyle.squircle] (Figma's corner-smoothing look): that
/// curvature-continuity property, not the cubic machinery, is what callers
/// reaching for "squircle" actually want.
final class CubicBezierCorner extends CornerStyle {
  const CubicBezierCorner();

  @override
  bool get honorsAsymmetricRadius => true;

  @override
  (List<Segment>, Segment, List<Segment>) _constructChain(
    List<Segment> incoming,
    List<Segment> outgoing,
    double radius1,
    double radius2,
    P vertex,
  ) => _roundChainWithCuts(
    incoming,
    outgoing,
    radius1,
    radius2,
    _cubicFilletFromCuts,
  );
}
