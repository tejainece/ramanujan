import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

/// A corner's radius, expressed as one value per side rather than one shared
/// number: [incoming] is how far to cut back along the segment arriving at
/// the corner, [outgoing] how far along the segment leaving it. The same type
/// is used for a single corner and for a whole-path `roundAllCorners` call, so
/// an asymmetric corner can be requested in either.
class CornerRadius {
  const CornerRadius(this.incoming, this.outgoing);

  /// Both sides cut back by the same [radius].
  const CornerRadius.symmetric(double radius)
    : incoming = radius,
      outgoing = radius;

  final double incoming;
  final double outgoing;

  /// The single true radius a style that can't honor asymmetric radii
  /// actually cuts with (see `CornerStyle.honorsAsymmetricRadius`).
  double get averaged => (incoming + outgoing) / 2;

  /// Clamps [incoming] to at most [segment1]'s own arc length and [outgoing]
  /// to at most [segment2]'s, so a corner fillet can never be asked to cut
  /// back further along an adjacent edge than that edge actually is -- which
  /// would otherwise overshoot the edge's far end (into whatever lies beyond
  /// it, typically the *next* corner) and produce a degenerate, over-cut
  /// fillet. Every `CornerStyle` applies this to its raw radius input before
  /// doing anything else with it, including the styles that average the two
  /// sides into a single shared radius -- so that averaging happens between
  /// two values already sane for their own side.
  CornerRadius clampedToEdgeLength(Segment segment1, Segment segment2) {
    return CornerRadius(
      min(incoming, segment1.length),
      min(outgoing, segment2.length),
    );
  }
}
