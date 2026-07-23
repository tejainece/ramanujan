part of 'corner.dart';

/// Rounds the corner with a straight bevel (chamfer): cuts the incoming side
/// back by [CornerRadius.incoming] and the outgoing side back by
/// [CornerRadius.outgoing], independently, and connects the two cut points
/// with a single straight line. Unlike the arc-based styles, a straight line
/// has no tangency constraint linking the two sides, so the two radii are
/// always honoured exactly, however different they are -- and nothing about
/// the connecting line depends on whether either side is straight or curved.
final class ChamferCorner extends CornerStyle {
  const ChamferCorner();

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
    _chamferFilletFromCuts,
  );
}
