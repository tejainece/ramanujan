part of 'corner.dart';

/// Rounds a corner with a true circular arc, tangent to both sides -- each
/// side may be a straight line or any curved segment type
/// ([QuadraticSegment], [CubicSegment], [CircularArcSegment], [ArcSegment]).
///
/// A single circle tangent to two curves at two independently-chosen cut
/// distances necessarily has equal tangent length on both sides (the
/// tangent-length theorem: from the shared vertex, any two tangent segments
/// to the same circle are equal), so a real circle only has one true radius
/// per corner -- [honorsAsymmetricRadius] is `false`, and
/// [CornerRadius.incoming]/[CornerRadius.outgoing] are averaged rather than
/// honoured independently. Use [EllipticArcCorner] when the two sides
/// genuinely need different radii.
///
/// Unlike every other style, the two cut points are *not* found
/// independently: the incoming side is cut back by the averaged radius, but
/// the outgoing side's cut point is *solved for*, not prescribed. Cutting
/// both sides back by the same distance and intersecting the two
/// perpendiculars at those points -- what a first pass at this
/// generalization does, and what the original line-only version actually
/// did -- only lands on a point equidistant from both cut points when the
/// two sides are mirror-symmetric about the corner's bisector. That symmetry
/// is real for two straight lines cut by *equal* amounts (so the line-only
/// version could get away with it), but breaks even for two straight lines
/// cut by *different* amounts, and there is no analogous symmetry once
/// either side is curved. So instead: the center is constrained to lie on
/// the incoming side's normal line at its cut point (a necessary condition
/// for tangency there, true for any segment type), parameterized by unknown
/// signed offset `s`; for each candidate `s` the true tangent point on the
/// outgoing side is found via [_paramOfTangencyTo]; and `s` itself is found
/// by bisecting on the residual between that tangent point's actual distance
/// to the candidate center and `s` -- the two match exactly once the circle
/// is tangent to both sides. This reduces to the original closed-form result
/// exactly when both sides are lines (verified by this library's test
/// suite), since a line's unique closest/tangent point to an external center
/// is always well-defined and the two solves agree.
final class CircularArcCorner extends CornerStyle {
  const CircularArcCorner();

  @override
  bool get honorsAsymmetricRadius => false;

  @override
  (List<Segment>, Segment, List<Segment>) _constructChain(
    List<Segment> incoming,
    List<Segment> outgoing,
    double radius1,
    double radius2,
    P vertex,
  ) => _roundChainCircular(incoming, outgoing, (radius1 + radius2) / 2);
}
