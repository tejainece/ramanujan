import 'package:polynomial/polynomial.dart';
import 'package:ramanujan/ramanujan.dart';

/// The parameter-space overlap between two coincident segments.
///
/// [tStart] and [tEnd] are parameters on the receiver segment (the one
/// [Segment.coincidentOverlap] was called on). [sStart] and [sEnd] are the
/// corresponding parameters on the argument segment.
///
/// When [sStart] > [sEnd] the two segments traverse the overlap region in
/// opposite directions.
class CoincidentOverlap {
  /// Start of the overlap on the receiver segment (always ≤ [tEnd]).
  final double tStart;

  /// End of the overlap on the receiver segment.
  final double tEnd;

  /// Parameter on the argument segment corresponding to [tStart].
  /// May be greater than [sEnd] if the segments run in opposite directions.
  final double sStart;

  /// Parameter on the argument segment corresponding to [tEnd].
  final double sEnd;

  const CoincidentOverlap({
    required this.tStart,
    required this.tEnd,
    required this.sStart,
    required this.sEnd,
  });

  /// True when the two segments traverse the overlap in opposite directions.
  bool get reversed => sStart > sEnd;
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

/// Builds a [CoincidentOverlap] from the four endpoint ilerp values and
/// verifies coincidence at three evenly-spaced interior points.
///
/// [tA] — parameter on [self] where [other].p1 lands (NaN if not on curve).
/// [tB] — parameter on [self] where [other].p2 lands.
/// [sA] — parameter on [other] where [self].p1 lands.
/// [sB] — parameter on [other] where [self].p2 lands.
CoincidentOverlap? overlapFromBoundaries(
  Segment self,
  Segment other,
  double tA,
  double tB,
  double sA,
  double sB,
) {
  const eps = 1e-6;
  bool valid(double v) =>
      !v.isNaN && !v.isInfinite && v >= -eps && v <= 1 + eps;

  // Each boundary point contributes a (t-on-self, s-on-other) pair.
  final boundaries = <(double, double)>[];
  if (valid(tA)) boundaries.add((tA.clamp(0.0, 1.0), 0.0));
  if (valid(tB)) boundaries.add((tB.clamp(0.0, 1.0), 1.0));
  if (valid(sA)) boundaries.add((0.0, sA.clamp(0.0, 1.0)));
  if (valid(sB)) boundaries.add((1.0, sB.clamp(0.0, 1.0)));

  if (boundaries.length < 2) return null;

  boundaries.sort((a, b) => a.$1.compareTo(b.$1));
  final tStart = boundaries.first.$1;
  final tEnd = boundaries.last.$1;
  final sStart = boundaries.first.$2;
  final sEnd = boundaries.last.$2;

  if (tEnd - tStart < eps) return null;

  // Verify at three interior points that self and other trace the same curve.
  for (final alpha in const [0.25, 0.5, 0.75]) {
    final t = tStart + alpha * (tEnd - tStart);
    final s = sStart + alpha * (sEnd - sStart);
    if (self.lerp(t).distanceTo(other.lerp(s)) > 1e-3) return null;
  }

  return CoincidentOverlap(
    tStart: tStart,
    tEnd: tEnd,
    sStart: sStart,
    sEnd: sEnd,
  );
}

// ─── Bézier polynomial extraction ────────────────────────────────────────────

// Standard-form coefficients of the x-component of a quadratic Bézier.
Polynomial _quadXPoly(QuadraticSegment s) =>
    Polynomial([s.p1.x, -2 * s.p1.x + 2 * s.c.x, s.p1.x - 2 * s.c.x + s.p2.x]);

Polynomial _quadYPoly(QuadraticSegment s) =>
    Polynomial([s.p1.y, -2 * s.p1.y + 2 * s.c.y, s.p1.y - 2 * s.c.y + s.p2.y]);

// Standard-form coefficients of the x-component of a cubic Bézier.
Polynomial _cubicXPoly(CubicSegment s) => Polynomial([
  s.p1.x,
  -3 * s.p1.x + 3 * s.c1.x,
  3 * s.p1.x - 6 * s.c1.x + 3 * s.c2.x,
  -s.p1.x + 3 * s.c1.x - 3 * s.c2.x + s.p2.x,
]);

Polynomial _cubicYPoly(CubicSegment s) => Polynomial([
  s.p1.y,
  -3 * s.p1.y + 3 * s.c1.y,
  3 * s.p1.y - 6 * s.c1.y + 3 * s.c2.y,
  -s.p1.y + 3 * s.c1.y - 3 * s.c2.y + s.p2.y,
]);

// ─── Bézier coincidence ───────────────────────────────────────────────────────

/// Shared coincident-overlap logic for [QuadraticSegment] and [CubicSegment].
///
/// Uses [Segment.ilerp] to locate boundary candidates, [overlapFromBoundaries]
/// for geometric verification, and — when the full reparameterization is
/// available — polynomial composition for an exact algebraic confirmation.
CoincidentOverlap? bezierCoincidentOverlap(Segment self, Segment other) {
  final tA = self.ilerp(other.p1);
  final tB = self.ilerp(other.p2);
  final sA = other.ilerp(self.p1);
  final sB = other.ilerp(self.p2);

  final overlap = overlapFromBoundaries(self, other, tA, tB, sA, sB);
  if (overlap == null) return null;

  // When other is entirely contained in self (tA and tB are both valid), the
  // full reparameterization L(s) = tA + (tB − tA)·s is available. Verify via
  // polynomial composition: self(L(s)) − other(s) should be the zero polynomial.
  if (!tA.isNaN && !tB.isNaN) {
    final L = Polynomial([tA, tB - tA]);
    if (!_polyCoincident(self, other, L)) return null;
  }

  return overlap;
}

bool _polyCoincident(Segment self, Segment other, Polynomial L) {
  if (self is CubicSegment && other is CubicSegment) {
    return (_cubicXPoly(self).compose(L) - _cubicXPoly(other)).isNearlyZero(
          1e-4,
        ) &&
        (_cubicYPoly(self).compose(L) - _cubicYPoly(other)).isNearlyZero(1e-4);
  }
  if (self is QuadraticSegment && other is QuadraticSegment) {
    return (_quadXPoly(self).compose(L) - _quadXPoly(other)).isNearlyZero(
          1e-4,
        ) &&
        (_quadYPoly(self).compose(L) - _quadYPoly(other)).isNearlyZero(1e-4);
  }
  return true; // different types handled upstream
}
