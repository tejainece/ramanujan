part of 'corner.dart';

/// Rounds a corner with a true circular arc, tangent to both sides -- each
/// side may be a straight line or any curved segment type
/// ([QuadraticSegment], [CubicSegment], [CircularArcSegment], [ArcSegment]).
///
/// A single circle tangent to two curves has equal tangent length on both
/// sides, so it has only one true radius per corner: [honorsAsymmetricRadius]
/// is `false`, and [CornerRadius.incoming]/[CornerRadius.outgoing] are
/// averaged rather than honoured independently. Use [EllipticArcCorner] when
/// the two sides need different radii.
///
/// The two cut points are found differently: the incoming side is cut back
/// by the averaged radius, then the outgoing side's cut point is solved for.
/// The center is constrained to lie on the incoming side's normal line at
/// its cut point, parameterized by unknown signed offset `s`. For each
/// candidate `s`, the tangent point on the outgoing side is found via
/// [_paramOfTangencyTo], and `s` is solved by bisecting on the residual
/// between that tangent point's distance to the candidate center and `s`.
final class CircularArcCorner extends CornerStyle {
  const CircularArcCorner();

  @override
  bool get honorsAsymmetricRadius => false;

  @override
  (VectorPath, Segment, VectorPath) _constructChain(
    VectorPath incoming,
    VectorPath outgoing,
    CornerRadius radius,
    P vertex,
  ) => _roundChain(incoming, outgoing, radius.averaged);

  /// Chain-generalized core, shared with [roundAllCorners]: [incoming] and
  /// [outgoing] are contiguous runs of segments meeting at the corner
  /// ([incoming]'s end is [outgoing]'s start). Cuts [radius] of arc length
  /// back along [incoming] (traversing across whole segments if the chain has
  /// more than one, see [VectorPath.trimEnd]) and solves for the tangent
  /// circle as described in the class doc, walking [outgoing] segment by
  /// segment from the corner outward and taking the first tangency found, so
  /// the fillet's far endpoint may land on any segment of the chain. When
  /// [incoming] and [outgoing] are the same list (a closed path with a
  /// single rounded corner), the outgoing solve runs on the incoming cut's
  /// remainder so both trims survive in the returned chain.
  (VectorPath, Segment, VectorPath) _roundChain(
    VectorPath incoming,
    VectorPath outgoing,
    double radius,
  ) {
    final (kept1, cut1) = incoming.trimEnd(radius);
    final outSrc = identical(outgoing, incoming) ? kept1 : outgoing;
    final outSegs = outSrc.segments;
    final p1 = cut1.point;
    final nDir = cut1.normalDir;

    // Direction along the normal that points toward the outgoing side.
    final probeSegment = outSegs.firstWhere(
      (s) => s.length > 1e-12,
      orElse: () => outSegs.first,
    );
    final probe = probeSegment.lerp(0.5) - p1;
    final sign = probe.dot(nDir) >= 0 ? 1.0 : -1.0;

    // First tangency walking the outgoing chain from the corner outward.
    // Falls back to the chain's far endpoint if none is found.
    (int, double) tangency(P center) {
      for (int i = 0; i < outSegs.length; i++) {
        final t = _paramOfTangencyTo(outSegs[i], center);
        if (t != null) return (i, t);
      }
      return (outSegs.length - 1, 1.0);
    }

    double residualForS(double s) {
      final center = p1 + nDir * (sign * s);
      final (i, t) = tangency(center);
      return outSegs[i].lerp(t).distanceTo(center) - s;
    }

    // Dense-sample-then-bisect for the s at which the candidate circle
    // reaches the outgoing chain. Search range scales with the corner size.
    final searchScale = (radius + incoming.length + outSrc.length) * 4;
    const sampleCount = 256;
    double sLo = 1e-6, residualLo = residualForS(sLo);
    double? sRoot;
    for (int i = 1; i <= sampleCount; i++) {
      final sHi = searchScale * i / sampleCount;
      final residualHi = residualForS(sHi);
      if (!residualLo.isNaN &&
          !residualHi.isNaN &&
          (residualLo < 0) != (residualHi < 0)) {
        double lo = sLo, hi = sHi;
        var flo = residualLo;
        for (int k = 0; k < 50; k++) {
          final mid = (lo + hi) / 2;
          final fm = residualForS(mid);
          if ((flo < 0) != (fm < 0)) {
            hi = mid;
          } else {
            lo = mid;
            flo = fm;
          }
        }
        sRoot = (lo + hi) / 2;
        break;
      }
      sLo = sHi;
      residualLo = residualHi;
    }
    assert(sRoot != null, 'no circle tangent to both sides was found');

    final center = p1 + nDir * (sign * sRoot!);
    final (landIndex, t2) = tangency(center);
    // Anchored at the kept piece's own endpoint, not lerp(t2), for a bitwise-exact join.
    final kept2Landing = outSegs[landIndex].bifurcateAtInterval(t2).$2;
    final p2 = kept2Landing.p1;
    final circleRadius = center.distanceTo(p1);

    return (
      kept1,
      _circularArcTowardCenter(p1, p2, circleRadius, center),
      VectorPath([kept2Landing, ...outSegs.sublist(landIndex + 1)]),
    );
  }

  /// Picks whichever of the two [CircularArcSegment]s through [a] and [b]
  /// with radius [radius] has its own reconstructed center closest to
  /// [target] -- the center actually derived from the tangency construction.
  CircularArcSegment _circularArcTowardCenter(
    P a,
    P b,
    double radius,
    P target,
  ) {
    final cw = CircularArcSegment(
      a,
      b,
      radius,
      clockwise: true,
      largeArc: false,
    );
    final ccw = CircularArcSegment(
      a,
      b,
      radius,
      clockwise: false,
      largeArc: false,
    );
    return cw.center.distanceTo(target) <= ccw.center.distanceTo(target)
        ? cw
        : ccw;
  }

  /// Parameter `t` in `[0,1]` on [segment] at which the line from
  /// `segment.lerp(t)` to [center] is perpendicular to the segment's tangent
  /// there. That perpendicularity is exactly the condition for `segment.lerp(t)`
  /// to be [segment]'s point of tangency with a circle centered at [center] --
  /// equivalently, the closest point on [segment] to [center] -- so this is how
  /// a circle's tangent point against a *curved* side is found, in place of the
  /// closed-form projection a straight line would use.
  ///
  /// Found by dense sampling for a sign change in the perpendicularity residual
  /// followed by bisection within it, the same dense-sample-then-bisect shape
  /// used elsewhere in this library for roots with no closed form (see
  /// `cubic.dart`'s `_rootsInUnit`). Returns `null` if no such point exists in
  /// `[0,1]` (no sign change found).
  double? _paramOfTangencyTo(Segment segment, P center) {
    double residual(double t) =>
        (segment.lerp(t) - center).dot(segment.unitTangentAt(t));

    const n = 64;
    double ta = 0, fa = residual(0);
    if (fa.abs() < 1e-9) return 0.0;
    for (int i = 1; i <= n; i++) {
      final tb = i / n;
      final fb = residual(tb);
      if (fb.abs() < 1e-9) return tb;
      if ((fa < 0) != (fb < 0)) {
        double lo = ta, hi = tb;
        var flo = fa;
        for (int k = 0; k < 50; k++) {
          final mid = (lo + hi) / 2;
          final fm = residual(mid);
          if ((flo < 0) != (fm < 0)) {
            hi = mid;
          } else {
            lo = mid;
            flo = fm;
          }
        }
        return (lo + hi) / 2;
      }
      ta = tb;
      fa = fb;
    }
    return null;
  }
}
