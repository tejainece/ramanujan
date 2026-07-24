part of 'corner.dart';

/// Rounds the corner with a single quadratic Bézier, cutting the incoming
/// side back by [CornerRadius.incoming] and the outgoing side back by
/// [CornerRadius.outgoing] independently. The control point is placed at the
/// intersection of the two cut points' tangent lines -- the same "effective
/// vertex" used by [EllipticArcCorner] -- so the curve's tangent at each end
/// (which points from that control point toward the cut point, or the
/// reverse) automatically points back along the adjacent segment's own
/// tangent line there. When both sides are straight lines that intersection
/// is exactly the shared vertex, matching the original corner-cut
/// construction exactly.
final class QuadraticBezierCorner extends CornerStyle {
  const QuadraticBezierCorner();

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
    _quadraticFilletFromCuts,
  );
}
