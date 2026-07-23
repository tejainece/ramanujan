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
}
