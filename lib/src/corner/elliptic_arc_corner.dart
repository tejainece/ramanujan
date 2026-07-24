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
  ) {
    final (kept1, cut1) = incoming.trimEnd(radius.incoming);
    final outSrc = identical(outgoing, incoming) ? kept1 : outgoing;
    final (kept2, cut2) = outSrc.trimStart(radius.outgoing);

    final a = cut1.point, b = cut2.point;

    final tangentLine1 = a.lineAlong(cut1.tangentDir);
    final tangentLine2 = b.lineAlong(cut2.tangentDir);
    final effectiveVertex = tangentLine1.intersectInfiniteLine(tangentLine2);

    final d1 = (a - effectiveVertex).normalized;
    final d2 = (b - effectiveVertex).normalized;
    final effectiveRadius1 = effectiveVertex.distanceTo(a);
    final effectiveRadius2 = effectiveVertex.distanceTo(b);

    final center =
        effectiveVertex + d1 * effectiveRadius1 + d2 * effectiveRadius2;
    final c1 = d1 * effectiveRadius1;
    final c2 = d2 * effectiveRadius2;

    final sxx = c1.x * c1.x + c2.x * c2.x;
    final syy = c1.y * c1.y + c2.y * c2.y;
    final sxy = c1.x * c1.y + c2.x * c2.y;

    final mid = (sxx + syy) / 2;
    final spread = sqrt(
      max(0.0, ((sxx - syy) / 2) * ((sxx - syy) / 2) + sxy * sxy),
    );
    final rx = sqrt(max(0.0, mid + spread));
    final ry = sqrt(max(0.0, mid - spread));

    double rotation;
    if (sxy.abs() < 1e-12 && (sxx - syy).abs() < 1e-12) {
      rotation = 0;
    } else if (sxy.abs() < 1e-12) {
      rotation = sxx >= syy ? 0 : pi / 2;
    } else {
      rotation = P(sxy, (mid + spread) - sxx).angle.value;
    }

    final fillet = _arcTowardCenter(a, b, P(rx, ry), rotation, center);
    return (kept1, fillet, kept2);
  }

  /// Builds the [ArcSegment] between [a] and [b] with the given
  /// [radii]/[rotation], picking whichever of the two possible short-arc
  /// sweep directions has its reconstructed (SVG-endpoint-form) center
  /// closest to [target] -- the center derived from the tangency
  /// construction.
  ArcSegment _arcTowardCenter(P a, P b, P radii, double rotation, P target) {
    final cw = ArcSegment(
      a,
      b,
      radii,
      rotation: rotation,
      largeArc: false,
      clockwise: true,
    );
    final ccw = ArcSegment(
      a,
      b,
      radii,
      rotation: rotation,
      largeArc: false,
      clockwise: false,
    );
    return cw.center.distanceTo(target) <= ccw.center.distanceTo(target)
        ? cw
        : ccw;
  }
}
