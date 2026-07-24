part of 'corner.dart';

/// Rounds the corner with the unique ellipse tangent to the incoming segment
/// at distance [CornerRadius.incoming] from the shared vertex (measured
/// along its own arc length) and tangent to the outgoing segment at distance
/// [CornerRadius.outgoing] -- the asymmetric-radius counterpart to
/// [CircularArcCorner]. A true circle can't be tangent to both at two
/// independently-chosen cut distances (see [CircularArcCorner] for why), so
/// when the radii genuinely differ, this is what a single, exactly-tangent,
/// smooth fillet curve looks like instead.
///
/// The construction works in the oblique coordinate frame whose axes run
/// along the *tangent lines* of the two segments at their cut points -- not
/// along the segments themselves, since those may be curved. When both are
/// straight lines, a line's tangent is itself everywhere, so this
/// tangent-line intersection is exactly the original shared vertex and the
/// construction below reduces to the line-only version exactly. When either
/// side is curved, the two tangent lines generally meet somewhere else
/// entirely -- call that point the corner's "effective vertex" -- and the
/// oblique frame is anchored there instead, with its two "radii" being each
/// cut point's actual distance from *that* point (not
/// [CornerRadius.incoming]/[CornerRadius.outgoing], which only ever
/// controlled how far to cut back along the curve). In that frame the corner
/// becomes a right angle, and the ellipse centered at (effectiveRadius1,
/// effectiveRadius2) with semi-axes (effectiveRadius1, effectiveRadius2) is
/// tangent to both axes exactly at the two cut points by construction.
/// Mapping that back to world space gives a general affine image of a
/// circle -- an ellipse whose canonical (center, radii, rotation) is
/// recovered from the eigen-decomposition of the resulting shape matrix.
final class EllipticArcCorner extends CornerStyle {
  const EllipticArcCorner();

  @override
  bool get honorsAsymmetricRadius => true;

  @override
  (VectorPath, Segment, VectorPath) _constructChain(
    VectorPath incoming,
    VectorPath outgoing,
    CornerRadius radius,
    P vertex,
  ) => _roundChainWithCuts(
    incoming,
    outgoing,
    radius,
    _ellipticFilletFromCuts,
  );
}
