import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

part 'circular_arc_corner.dart';
part 'elliptic_arc_corner.dart';
part 'inverted_arc_corner.dart';
part 'chamfer_corner.dart';
part 'quadratic_bezier_corner.dart';
part 'cubic_bezier_corner.dart';

part 'round_all.dart';

/// A style of corner rounding: bridges two segments meeting at a corner.
sealed class CornerStyle {
  const CornerStyle();

  static const circularArc = CircularArcCorner();
  static const ellipticArc = EllipticArcCorner();
  static const invertedArc = InvertedArcCorner();
  static const chamfer = ChamferCorner();
  static const quadraticBezier = QuadraticBezierCorner();
  static const cubicBezier = CubicBezierCorner();

  static const squircle = CubicBezierCorner();

  static const values = [
    circularArc,
    ellipticArc,
    invertedArc,
    chamfer,
    quadraticBezier,
    cubicBezier,
    squircle,
  ];

  /// Whether this style honors [CornerRadius.incoming] and
  /// [CornerRadius.outgoing] independently. `false` for the two styles built
  /// from a true circle ([circularArc] and [invertedArc]): a single circle
  /// tangent to (or centered relative to) two independently-cut points
  /// necessarily has one radius, not two, so both sides are averaged via
  /// [CornerRadius.averaged] before construction rather than honoured as
  /// given.
  bool get honorsAsymmetricRadius;

  /// Chain-generalized construction shared with [roundAllCorners]: [incoming]
  /// and [outgoing] are contiguous runs of segments meeting at [vertex] --
  /// single segments for a two-segment [construct] call, whole stretches
  /// under [roundAllCorners]'s traversal, so a fillet's endpoint can land on
  /// any segment of a multi-segment run, not just the one touching the
  /// corner. Returns the trimmed incoming chain, the fillet, and the trimmed
  /// outgoing chain. When [incoming] and [outgoing] are the *same* instance
  /// (a closed path with a single rounded corner), the outgoing cut runs on
  /// the incoming cut's remainder so both trims survive in the returned
  /// chain.
  (VectorPath, Segment, VectorPath) _constructChain(
    VectorPath incoming,
    VectorPath outgoing,
    CornerRadius radius,
    P vertex,
  );

  /// Rounds the corner shared by [segment1] and [segment2] with this style --
  /// [segment1] and [segment2] may each be a straight line or any curved
  /// segment type ([QuadraticSegment], [CubicSegment], [CircularArcSegment],
  /// [ArcSegment]). [radius] is clamped per side to its own segment's arc
  /// length (see [CornerRadius.clampedToEdgeLength]) before this style cuts
  /// back and bridges the two cut points.
  List<Segment> construct(
    Segment segment1,
    Segment segment2,
    CornerRadius radius,
  ) {
    assert(segment1.p2.isEqual(segment2.p1));
    final clamped = radius.clampedToEdgeLength(segment1, segment2);
    final (kept1, fillet, kept2) = _constructChain(
      VectorPath([segment1]),
      VectorPath([segment2]),
      clamped,
      segment1.p2,
    );
    return [...kept1.segments, fillet, ...kept2.segments];
  }
}
