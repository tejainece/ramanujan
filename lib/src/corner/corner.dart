import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

/// Result of cutting one side of a corner back from the shared vertex: [kept]
/// is the shortened input segment, [point] is the new cut endpoint, and
/// [tangentDir]/[normalDir] are the unit tangent/normal of the *original*
/// segment at that point (not of [kept], which is the same curve so they
/// coincide anyway). For a [LineSegment] these are constant along its length;
/// for a curved segment they are evaluated at the cut point specifically,
/// since direction varies along the curve.
typedef _Cut = ({Segment kept, P point, P tangentDir, P normalDir});

/// Parameter `t` at which the leading piece of [segment] -- the part from its
/// `p1` up to `t` -- has arc length [distance]. Exact for a [LineSegment]
/// (`distance / length`, closed form); for every curved segment type arc
/// length has no closed-form inverse, so `t` is found by bisection using the
/// segment's own [Segment.length] (itself exact for lines/circular arcs and
/// adaptively-subdivided for quadratics/cubics/elliptic arcs) on the piece
/// [Segment.bifurcateAtInterval] returns. This assumes arc length grows
/// monotonically with `t`, true for any regular (non-cusped, non-looping)
/// segment -- the only kind a single corner-rounding fillet is built against.
double _paramAtLengthFromP1(Segment segment, double distance) {
  if (segment is LineSegment) {
    return segment.length <= 1e-12
        ? 0.0
        : (distance / segment.length).clamp(0.0, 1.0);
  }
  double lo = 0.0, hi = 1.0;
  for (int i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (segment.bifurcateAtInterval(mid).$1.length < distance) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Cuts [segment] back by arc length [distance] from its `p2` end -- the side
/// that meets the corner when [segment] is the *incoming* edge. Found via
/// [_paramAtLengthFromP1] on the reversed segment (so "distance from p2" of
/// the original becomes "distance from p1" of the reversal), which relies on
/// `segment.reversed().lerp(t) == segment.lerp(1 - t)`, the defining contract
/// of [Segment.reversed].
_Cut _cutIncoming(Segment segment, double distance) {
  final t = 1 - _paramAtLengthFromP1(segment.reversed(), distance);
  return (
    kept: segment.bifurcateAtInterval(t).$1,
    point: segment.lerp(t),
    tangentDir: segment.unitTangentAt(t),
    normalDir: segment.unitNormalAt(t),
  );
}

/// Cuts [segment] back by arc length [distance] from its `p1` end -- the side
/// leaving the corner when [segment] is the *outgoing* edge. See [_cutIncoming].
_Cut _cutOutgoing(Segment segment, double distance) {
  final t = _paramAtLengthFromP1(segment, distance);
  return (
    kept: segment.bifurcateAtInterval(t).$2,
    point: segment.lerp(t),
    tangentDir: segment.unitTangentAt(t),
    normalDir: segment.unitNormalAt(t),
  );
}

/// Parameter `t` on [segment] (measured from its own `p1`) at which the
/// point's Euclidean distance from [segment]'s `p1` first equals [distance].
/// Unlike [_paramAtLengthFromP1] this is a straight-line (chord) distance, not
/// an arc length -- used by [roundCornerUsingInvertedArc], whose cut points
/// must lie on a literal circle centered on the vertex rather than at a given
/// arc-length offset. For a [LineSegment] the two notions coincide exactly
/// (the line passes straight through its own `p1`), so this reduces to the
/// same closed form as [_paramAtLengthFromP1]. For a curved segment it is
/// found by bisection, assuming distance-from-`p1` grows monotonically with
/// `t` -- true for a segment that bites away from its own endpoint rather
/// than curving back toward it, which is the only shape a corner's adjacent
/// edge has.
double _paramAtChordDistanceFromP1(Segment segment, double distance) {
  if (segment is LineSegment) {
    return segment.length <= 1e-12
        ? 0.0
        : (distance / segment.length).clamp(0.0, 1.0);
  }
  double lo = 0.0, hi = 1.0;
  for (int i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (segment.lerp(mid).distanceTo(segment.p1) < distance) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Like [_cutIncoming], but the cut point is chosen so its Euclidean distance
/// from the vertex (this segment's `p2`) is exactly [distance], not its arc
/// length. See [_paramAtChordDistanceFromP1].
_Cut _cutIncomingToChord(Segment segment, double distance) {
  final t = 1 - _paramAtChordDistanceFromP1(segment.reversed(), distance);
  return (
    kept: segment.bifurcateAtInterval(t).$1,
    point: segment.lerp(t),
    tangentDir: segment.unitTangentAt(t),
    normalDir: segment.unitNormalAt(t),
  );
}

/// Like [_cutOutgoing], but the cut point is chosen so its Euclidean distance
/// from the vertex (this segment's `p1`) is exactly [distance]. See
/// [_paramAtChordDistanceFromP1].
_Cut _cutOutgoingToChord(Segment segment, double distance) {
  final t = _paramAtChordDistanceFromP1(segment, distance);
  return (
    kept: segment.bifurcateAtInterval(t).$2,
    point: segment.lerp(t),
    tangentDir: segment.unitTangentAt(t),
    normalDir: segment.unitNormalAt(t),
  );
}

/// The infinite line through [point] running along unit direction [dir].
LineSegment _lineThrough(P point, P dir) => LineSegment(point, point + dir);

double _dot(P a, P b) => a.x * b.x + a.y * b.y;

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
  double residual(double t) => _dot(segment.lerp(t) - center, segment.unitTangentAt(t));

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

/// Picks whichever of the two [CircularArcSegment]s through [a] and [b] with
/// radius [radius] has its own reconstructed center closest to [target] -- the
/// center actually derived from the tangency construction. Two circles of a
/// given radius pass through any two points (one on each side of their
/// chord), and [CircularArcSegment] only recovers *which* one from its
/// `clockwise` flag, so this sidesteps hand-deriving that sign convention the
/// same way [_arcTowardCenter] does for [ArcSegment].
CircularArcSegment _circularArcTowardCenter(P a, P b, double radius, P target) {
  final cw = CircularArcSegment(a, b, radius, clockwise: true, largeArc: false);
  final ccw = CircularArcSegment(a, b, radius, clockwise: false, largeArc: false);
  return cw.center.distanceTo(target) <= ccw.center.distanceTo(target) ? cw : ccw;
}

/// Rounds the corner shared by [segment1] and [segment2] with a true circular
/// arc, tangent to both -- [segment1] and [segment2] may each be a straight
/// line or any curved segment type ([QuadraticSegment], [CubicSegment],
/// [CircularArcSegment], [ArcSegment]).
///
/// A single circle tangent to two curves at two independently-chosen cut
/// distances necessarily has equal tangent length on both sides (the
/// tangent-length theorem: from the shared vertex, any two tangent segments to
/// the same circle are equal), so a real circle only has one true radius per
/// corner -- [radius1] and [radius2] are averaged rather than honoured
/// independently. Use [roundCornerUsingEllipticArc] when the two sides
/// genuinely need different radii.
///
/// Unlike every other function in this file, the two cut points are *not*
/// found independently: [segment1] is cut back by the averaged [radius], but
/// [segment2]'s cut point is *solved for*, not prescribed. Cutting both sides
/// back by the same distance and intersecting the two perpendiculars at those
/// points -- what a first pass at this generalization does, and what the
/// original line-only version actually did -- only lands on a point
/// equidistant from both cut points when the two sides are mirror-symmetric
/// about the corner's bisector. That symmetry is real for two straight lines
/// cut by *equal* amounts (so the line-only version could get away with it),
/// but breaks even for two straight lines cut by *different* amounts, and
/// there is no analogous symmetry once either side is curved. So instead:
/// the center is constrained to lie on [segment1]'s normal line at its cut
/// point (a necessary condition for tangency there, true for any segment
/// type), parameterized by unknown signed offset `s`; for each candidate `s`
/// the true tangent point on [segment2] is found via [_paramOfTangencyTo]; and
/// `s` itself is found by bisecting on the residual between that tangent
/// point's actual distance to the candidate center and `s` -- the two match
/// exactly once the circle is tangent to both sides. This reduces to the
/// original closed-form result exactly when both sides are lines (verified by
/// this library's test suite), since a line's unique closest/tangent point to
/// an external center is always well-defined and the two solves agree.
List<Segment> roundCornerUsingCircularArc(
  Segment segment1,
  Segment segment2,
  double radius1,
  double radius2,
) {
  assert(segment1.p2.isEqual(segment2.p1));
  final radius = (radius1 + radius2) / 2;

  final cut1 = _cutIncoming(segment1, radius);
  final p1 = cut1.point;
  final nDir = cut1.normalDir;

  // Which of the two directions along the normal actually points toward
  // segment2 -- i.e. which side of segment1's normal line the fillet center
  // must be on.
  final probe = segment2.lerp(0.5) - p1;
  final sign = _dot(probe, nDir) >= 0 ? 1.0 : -1.0;

  double residualForS(double s) {
    final center = p1 + nDir * (sign * s);
    final t2 = _paramOfTangencyTo(segment2, center);
    if (t2 == null) return double.nan;
    return segment2.lerp(t2).distanceTo(center) - s;
  }

  // Dense-sample-then-bisect for the s at which the candidate circle actually
  // reaches segment2 (see _paramOfTangencyTo). The search range is scaled to
  // the corner's own size, generous enough to cover any reasonable fillet.
  final searchScale = (radius + segment1.length + segment2.length) * 4;
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
  assert(sRoot != null, 'no circle tangent to both segments was found');

  final center = p1 + nDir * (sign * sRoot!);
  final t2 = _paramOfTangencyTo(segment2, center)!;
  final p2 = segment2.lerp(t2);
  final circleRadius = center.distanceTo(p1);

  return [
    cut1.kept,
    _circularArcTowardCenter(p1, p2, circleRadius, center),
    segment2.bifurcateAtInterval(t2).$2,
  ];
}

/// Builds the [ArcSegment] between [a] and [b] with the given [radii]/[rotation],
/// picking whichever of the two possible short-arc sweep directions has its
/// reconstructed (SVG-endpoint-form) center closest to [target] -- the center
/// we derived directly from the tangency construction. This sidesteps hand
/// -verifying [ArcSegment]'s sweep-flag sign convention (it also avoids
/// [Ellipse.arc]'s own large-arc detection, which goes through
/// [Ellipse.arcLengthBetweenAngles] and throws for angles that land exactly on
/// a quadrant boundary -- a common case here since cut points often sit on an
/// axis).
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

/// Rounds the corner with the unique ellipse tangent to [segment1] at distance
/// [radius1] from the shared vertex (measured along its own arc length) and
/// tangent to [segment2] at distance [radius2] -- the asymmetric-radius
/// counterpart to [roundCornerUsingCircularArc]. A true circle can't be
/// tangent to both at two independently-chosen cut distances (see
/// [roundCornerUsingCircularArc] for why), so when the radii genuinely differ,
/// this is what a single, exactly-tangent, smooth fillet curve looks like
/// instead.
///
/// The construction works in the oblique coordinate frame whose axes run along
/// the *tangent lines* of [segment1] and [segment2] at their cut points --
/// not along [segment1]/[segment2] themselves, since those may be curved. When
/// both are straight lines, a line's tangent is itself everywhere, so this
/// tangent-line intersection is exactly the original shared vertex and the
/// construction below reduces to the line-only version exactly. When either
/// side is curved, the two tangent lines generally meet somewhere else
/// entirely -- call that point the corner's "effective vertex" -- and the
/// oblique frame is anchored there instead, with its two "radii" being each
/// cut point's actual distance from *that* point (not [radius1]/[radius2],
/// which only ever controlled how far to cut back along the curve). In that
/// frame the corner becomes a right angle, and the ellipse centered at
/// (effectiveRadius1, effectiveRadius2) with semi-axes
/// (effectiveRadius1, effectiveRadius2) is tangent to both axes exactly at the
/// two cut points by construction. Mapping that back to world space gives a
/// general affine image of a circle -- an ellipse whose canonical (center,
/// radii, rotation) is recovered from the eigen-decomposition of the
/// resulting shape matrix.
List<Segment> roundCornerUsingEllipticArc(
  Segment segment1,
  Segment segment2,
  double radius1,
  double radius2,
) {
  assert(segment1.p2.isEqual(segment2.p1));

  final cut1 = _cutIncoming(segment1, radius1);
  final cut2 = _cutOutgoing(segment2, radius2);
  final a = cut1.point, b = cut2.point;

  final tangentLine1 = _lineThrough(a, cut1.tangentDir);
  final tangentLine2 = _lineThrough(b, cut2.tangentDir);
  final effectiveVertex = tangentLine1.intersectInfiniteLine(tangentLine2);

  final d1 = (a - effectiveVertex).normalized;
  final d2 = (b - effectiveVertex).normalized;
  final effectiveRadius1 = effectiveVertex.distanceTo(a);
  final effectiveRadius2 = effectiveVertex.distanceTo(b);

  final center = effectiveVertex + d1 * effectiveRadius1 + d2 * effectiveRadius2;
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

  final radii = P(rx, ry);
  final arc = _arcTowardCenter(a, b, radii, rotation, center);

  return [cut1.kept, arc, cut2.kept];
}

/// Concave "inverted round" corner (Illustrator's Inverted Round, Inkscape's
/// Inverse Fillet) -- the picture-frame-mat / movie-ticket-notch look: cuts
/// [segment1] and [segment2] back to the same points a normal round would
/// (their [radius1]/[radius2], averaged into one [radius] for the same
/// tangent-length reason as [roundCornerUsingCircularArc]), then bridges those
/// two points with the arc of that literal circle **centered at the original
/// vertex** rather than tangent to the lines.
///
/// Unlike every other function here, the cut points are *not* found by
/// cutting back a given arc length: they are wherever the circle of [radius]
/// centered on the vertex crosses [segment1]/[segment2] ([_cutIncomingToChord]
/// / [_cutOutgoingToChord]), a Euclidean-distance condition rather than an
/// arc-length one. For a straight line the two coincide exactly, since the
/// line passes straight through its own endpoint -- which is why the original
/// line-only version of this function could get away with an ordinary
/// distance-along-the-line cut. For a curved segment they generally differ,
/// so using an arc-length cut there (as every other style in this file does)
/// would place the point off the circle, breaking the "arc of the vertex
/// -centered circle" construction this style is built on.
///
/// Because each side meets that circle rather than being tangent to it, the
/// corner meets the arc at whatever angle the segment's tangent happens to
/// make with the circle there -- for a line this is a right angle (the line
/// passes through the circle's center); for a curve it generally is not, but
/// it is still a real corner, not a blended fillet, matching the reference
/// construction (draw a circle centered on the corner, then
/// Pathfinder/Boolean-subtract it). The arc never extends past the original
/// vertex; it only ever bites material away from inside the original angle.
List<Segment> roundCornerUsingInvertedArc(
  Segment segment1,
  Segment segment2,
  double radius1,
  double radius2,
) {
  assert(segment1.p2.isEqual(segment2.p1));
  final radius = (radius1 + radius2) / 2;

  final cut1 = _cutIncomingToChord(segment1, radius);
  final cut2 = _cutOutgoingToChord(segment2, radius);

  final turn = segment1.unitTangentAt(1).angle - segment2.unitTangentAt(0).angle;

  return [
    cut1.kept,
    CircularArcSegment(
      cut1.point,
      cut2.point,
      radius,
      clockwise: turn.value >= pi,
      largeArc: false,
    ),
    cut2.kept,
  ];
}

/// Rounds the corner with a straight bevel (chamfer): cuts [segment1] back by
/// [radius1] and [segment2] back by [radius2], independently, and connects the
/// two cut points with a single straight line. Unlike the arc-based styles, a
/// straight line has no tangency constraint linking the two sides, so the two
/// radii are always honoured exactly, however different they are -- and
/// nothing about the connecting line depends on whether either side is
/// straight or curved.
List<Segment> roundCornerUsingChamfer(
  Segment segment1,
  Segment segment2,
  double radius1,
  double radius2,
) {
  assert(segment1.p2.isEqual(segment2.p1));
  final cut1 = _cutIncoming(segment1, radius1);
  final cut2 = _cutOutgoing(segment2, radius2);
  return [cut1.kept, LineSegment(cut1.point, cut2.point), cut2.kept];
}

/// Rounds the corner with a single quadratic Bézier, cutting [segment1] back
/// by [radius1] and [segment2] back by [radius2] independently. The control
/// point is placed at the intersection of the two cut points' tangent lines --
/// the same "effective vertex" used by [roundCornerUsingEllipticArc] -- so the
/// curve's tangent at each end (which points from that control point toward
/// the cut point, or the reverse) automatically points back along the
/// adjacent segment's own tangent line there. When both sides are straight
/// lines that intersection is exactly the shared vertex, matching the
/// original corner-cut construction exactly.
List<Segment> roundCornerUsingQuadraticBezier(
  Segment segment1,
  Segment segment2,
  double radius1,
  double radius2,
) {
  assert(segment1.p2.isEqual(segment2.p1));

  final cut1 = _cutIncoming(segment1, radius1);
  final cut2 = _cutOutgoing(segment2, radius2);

  final tangentLine1 = _lineThrough(cut1.point, cut1.tangentDir);
  final tangentLine2 = _lineThrough(cut2.point, cut2.tangentDir);
  final controlPoint = tangentLine1.intersectInfiniteLine(tangentLine2);

  final ret = <Segment>[
    cut1.kept,
    QuadraticSegment(p1: cut1.point, p2: cut2.point, c: controlPoint),
    cut2.kept,
  ];

  return ret;
}

/// Rounds the corner with a single cubic Bézier, cutting [segment1] back by
/// [radius1] and [segment2] back by [radius2] independently. Both interior
/// control points are anchored at the same point: the intersection of the two
/// cut points' tangent lines (see [roundCornerUsingQuadraticBezier]). Since
/// `{p1, anchor, anchor}` and `{anchor, anchor, p2}` are each trivially
/// collinear, curvature is exactly zero at both ends of the curve.
///
/// When both adjacent segments are straight lines that anchor is the shared
/// vertex, and zero curvature there matches the (also zero) curvature of the
/// lines it meets -- the guarantee the original line-only version of this
/// function made. When either adjacent segment is curved, this construction
/// still gives an exact tangent match (the curve leaves each cut point along
/// that segment's own tangent direction) but *not* a curvature match: the
/// fillet's curvature is forced to zero at that end regardless of what
/// curvature the adjacent curve actually has there, so a curved neighbor
/// still produces a curvature jump at the join, just no longer a tangent
/// jump. Matching curvature as well would mean solving for the control point
/// from the neighbor's actual curvature at the cut point, not merely its
/// tangent -- a materially different (and heavier) construction this function
/// does not attempt.
List<Segment> roundCornerUsingCubicBezier(
  Segment segment1,
  Segment segment2,
  double radius1,
  double radius2,
) {
  assert(segment1.p2.isEqual(segment2.p1));

  final cut1 = _cutIncoming(segment1, radius1);
  final cut2 = _cutOutgoing(segment2, radius2);

  final tangentLine1 = _lineThrough(cut1.point, cut1.tangentDir);
  final tangentLine2 = _lineThrough(cut2.point, cut2.tangentDir);
  final anchor = tangentLine1.intersectInfiniteLine(tangentLine2);

  final ret = <Segment>[
    cut1.kept,
    CubicSegment(p1: cut1.point, p2: cut2.point, c1: anchor, c2: anchor),
    cut2.kept,
  ];

  return ret;
}

/// Continuous-curvature ("squircle"/superellipse-style) corner, in the spirit
/// of Figma's corner smoothing: curvature eases from 0 into the fillet and back
/// to 0, instead of jumping instantly the way it does at the tangent points of
/// a circular arc. This is exactly [roundCornerUsingCubicBezier]'s construction
/// -- a single cubic with both interior control points anchored at the same
/// point is the only way to get that zero-curvature match at both ends --
/// exposed under its own name since that curvature-continuity property, not
/// the cubic machinery, is what callers reaching for "squircle" actually want.
/// See [roundCornerUsingCubicBezier] for the caveat when either adjacent
/// segment is itself curved: the tangent match still holds exactly, but the
/// curvature match only holds when the adjacent segment also has zero
/// curvature at the join (i.e. is a straight line).
List<Segment> roundCornerUsingSquircle(
  Segment segment1,
  Segment segment2,
  double radius1,
  double radius2,
) {
  assert(segment1.p2.isEqual(segment2.p1));
  return roundCornerUsingCubicBezier(segment1, segment2, radius1, radius2);
}
