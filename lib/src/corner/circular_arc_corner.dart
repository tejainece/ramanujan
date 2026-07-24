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
  /// more than one, see [_cutChainIncoming]) and solves for the tangent
  /// circle exactly as described in the class doc above -- except the
  /// tangency search walks [outgoing] segment by segment from the corner
  /// outward, taking the first tangency found, so the fillet's far endpoint
  /// may land on any segment of the chain, not just the one touching the
  /// corner. When [incoming] and [outgoing] are the *same* list (a closed
  /// path with a single rounded corner, whose two sides are the two ends of
  /// one wrapped-around stretch), the outgoing solve runs on the incoming
  /// cut's remainder so both trims survive in the returned chain.
  (VectorPath, Segment, VectorPath) _roundChain(
    VectorPath incoming,
    VectorPath outgoing,
    double radius,
  ) {
    final (kept1, cut1) = _cutChainIncoming(incoming, radius);
    final outSrc = identical(outgoing, incoming) ? kept1 : outgoing;
    final outSegs = outSrc.segments;
    final p1 = cut1.point;
    final nDir = cut1.normalDir;

    // Which of the two directions along the normal actually points toward
    // the outgoing side -- i.e. which side of the incoming normal line the
    // fillet center must be on.
    final probeSegment = outSegs.firstWhere(
      (s) => s.length > 1e-12,
      orElse: () => outSegs.first,
    );
    final probe = probeSegment.lerp(0.5) - p1;
    final sign = probe.dot(nDir) >= 0 ? 1.0 : -1.0;

    // First tangency walking the outgoing chain from the corner outward.
    // When none exists anywhere on the chain, the chain's far endpoint
    // stands in: this is what makes a fillet whose tangent point lands
    // *exactly* on the chain's end findable at all -- just past that
    // boundary the perpendicularity residual has no root, so without the
    // stand-in the sampling below would see NaN on one side of the answer
    // and never bracket it. (It also means a tangency the chain is too short
    // for saturates at the chain's end instead of failing -- see the
    // caveats on [roundAllCorners].)
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
    // actually reaches the outgoing chain (see _paramOfTangencyTo). The
    // search range is scaled to the corner's own size, generous enough to
    // cover any reasonable fillet.
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
    // As in _cutIncoming, the fillet is anchored at the kept piece's own
    // endpoint rather than lerp(t2), so the join is bitwise exact.
    final kept2Landing = outSegs[landIndex].bifurcateAtInterval(t2).$2;
    final p2 = kept2Landing.p1;
    final circleRadius = center.distanceTo(p1);

    return (
      kept1,
      _circularArcTowardCenter(p1, p2, circleRadius, center),
      VectorPath([kept2Landing, ...outSegs.sublist(landIndex + 1)]),
    );
  }
}
