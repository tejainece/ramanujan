import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

part 'circular_arc_corner.dart';
part 'elliptic_arc_corner.dart';
part 'inverted_arc_corner.dart';
part 'chamfer_corner.dart';
part 'quadratic_bezier_corner.dart';
part 'cubic_bezier_corner.dart';

/// Result of cutting one side of a corner back from the shared vertex: [kept]
/// is the shortened input segment, [point] is the new cut endpoint, and
/// [tangentDir]/[normalDir] are the unit tangent/normal of the *original*
/// segment at that point (not of [kept], which is the same curve so they
/// coincide anyway). For a [LineSegment] these are constant along its length;
/// for a curved segment they are evaluated at the cut point specifically,
/// since direction varies along the curve.
///
/// [point] is taken from [kept]'s own endpoint rather than re-evaluated via
/// `segment.lerp(t)`: for curved segments [Segment.bifurcateAtInterval]
/// derives the split point through different arithmetic (e.g. de Casteljau)
/// than `lerp`, so the two agree only up to floating-point noise. Anchoring
/// the fillet at [kept]'s literal endpoint makes every fillet-to-kept-piece
/// join *bitwise* exact -- which [Loop] construction (exact-equality closure
/// check) relies on when a whole rounded path is spliced back together.
typedef _Cut = ({Segment kept, P point, P tangentDir, P normalDir});

/// Cuts [segment] back by arc length [distance] from its `p2` end -- the side
/// that meets the corner when [segment] is the *incoming* edge. Found via
/// [Segment.paramAtLength] on the reversed segment (so "distance from p2" of
/// the original becomes "distance from p1" of the reversal), which relies on
/// `segment.reversed().lerp(t) == segment.lerp(1 - t)`, the defining contract
/// of [Segment.reversed].
_Cut _cutIncoming(Segment segment, double distance) {
  final t = 1 - segment.reversed().paramAtLength(distance);
  final kept = segment.bifurcateAtInterval(t).$1;
  return (
    kept: kept,
    point: kept.p2,
    tangentDir: segment.unitTangentAt(t),
    normalDir: segment.unitNormalAt(t),
  );
}

/// Cuts [segment] back by arc length [distance] from its `p1` end -- the side
/// leaving the corner when [segment] is the *outgoing* edge. See [_cutIncoming].
_Cut _cutOutgoing(Segment segment, double distance) {
  final t = segment.paramAtLength(distance);
  final kept = segment.bifurcateAtInterval(t).$2;
  return (
    kept: kept,
    point: kept.p1,
    tangentDir: segment.unitTangentAt(t),
    normalDir: segment.unitNormalAt(t),
  );
}

/// Total arc length of a contiguous run of segments.
double _chainLength(Iterable<Segment> chain) =>
    chain.fold(0.0, (sum, segment) => sum + segment.length);

/// Multi-segment counterpart of [_cutIncoming]: cuts [distance] of arc length
/// off the *end* of [chain] (the side that meets the corner), consuming whole
/// trailing segments when [distance] runs past them -- this is what lets a
/// fillet's endpoint traverse across intermediate, un-rounded junctions
/// instead of clamping at the first one. Returns the surviving prefix of the
/// chain (whole leading segments plus the trimmed landing segment) and the
/// [_Cut] at the landing point. If [distance] exceeds the whole chain's
/// length, the cut saturates at the chain's start.
(List<Segment>, _Cut) _cutChainIncoming(List<Segment> chain, double distance) {
  var remaining = distance;
  for (int i = chain.length - 1; i > 0; i--) {
    if (remaining <= chain[i].length) {
      final cut = _cutIncoming(chain[i], remaining);
      return ([...chain.sublist(0, i), cut.kept], cut);
    }
    remaining -= chain[i].length;
  }
  final cut = _cutIncoming(chain.first, remaining);
  return ([cut.kept], cut);
}

/// Multi-segment counterpart of [_cutOutgoing]: cuts [distance] of arc length
/// off the *start* of [chain]. See [_cutChainIncoming].
(List<Segment>, _Cut) _cutChainOutgoing(List<Segment> chain, double distance) {
  var remaining = distance;
  for (int i = 0; i < chain.length - 1; i++) {
    if (remaining <= chain[i].length) {
      final cut = _cutOutgoing(chain[i], remaining);
      return ([cut.kept, ...chain.sublist(i + 1)], cut);
    }
    remaining -= chain[i].length;
  }
  final cut = _cutOutgoing(chain.last, remaining);
  return ([cut.kept], cut);
}

/// Parameter `t` on [segment] at which the point's Euclidean distance from
/// [origin] equals [distance]. Unlike [Segment.paramAtLength] this is a
/// straight-line (chord) distance, not an arc length -- used by the inverted
/// -arc style, whose cut points must lie on a literal circle centered on the
/// corner's vertex rather than at a given arc-length offset. Found by
/// bisection bracketed from the segment's end nearer [origin] toward the
/// farther one, assuming distance from [origin] is monotone along the segment
/// -- true for a segment (or chain link) that bites away from the corner
/// rather than curving back around it.
double _paramAtChordDistanceFrom(Segment segment, P origin, double distance) {
  double lo, hi;
  if (segment.p1.distanceTo(origin) <= segment.p2.distanceTo(origin)) {
    lo = 0.0;
    hi = 1.0;
  } else {
    lo = 1.0;
    hi = 0.0;
  }
  for (int i = 0; i < 50; i++) {
    final mid = (lo + hi) / 2;
    if (segment.lerp(mid).distanceTo(origin) < distance) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Chord-distance counterpart of [_cutChainIncoming]: walking backward from
/// the chain's end (which sits at [vertex]), lands on the first point whose
/// Euclidean distance from [vertex] is [radius]. If even the chain's start is
/// nearer than [radius] (possible on a strongly curved chain, whose chord
/// from the vertex can be much shorter than its arc length), the cut
/// saturates at the chain's start.
(List<Segment>, _Cut) _cutChainIncomingToChord(
  List<Segment> chain,
  P vertex,
  double radius,
) {
  for (int i = chain.length - 1; i >= 0; i--) {
    if (i == 0 || chain[i].p1.distanceTo(vertex) >= radius) {
      final t = _paramAtChordDistanceFrom(chain[i], vertex, radius);
      final kept = chain[i].bifurcateAtInterval(t).$1;
      final cut = (
        kept: kept,
        point: kept.p2,
        tangentDir: chain[i].unitTangentAt(t),
        normalDir: chain[i].unitNormalAt(t),
      );
      return ([...chain.sublist(0, i), cut.kept], cut);
    }
  }
  throw StateError('unreachable: chain is never empty');
}

/// Chord-distance counterpart of [_cutChainOutgoing]: walking forward from
/// the chain's start (which sits at [vertex]). See [_cutChainIncomingToChord].
(List<Segment>, _Cut) _cutChainOutgoingToChord(
  List<Segment> chain,
  P vertex,
  double radius,
) {
  for (int i = 0; i < chain.length; i++) {
    if (i == chain.length - 1 || chain[i].p2.distanceTo(vertex) >= radius) {
      final t = _paramAtChordDistanceFrom(chain[i], vertex, radius);
      final kept = chain[i].bifurcateAtInterval(t).$2;
      final cut = (
        kept: kept,
        point: kept.p1,
        tangentDir: chain[i].unitTangentAt(t),
        normalDir: chain[i].unitNormalAt(t),
      );
      return ([cut.kept, ...chain.sublist(i + 1)], cut);
    }
  }
  throw StateError('unreachable: chain is never empty');
}

/// Clamps [radius1] to at most [segment1]'s own arc length and [radius2] to
/// at most [segment2]'s, so a corner fillet can never be asked to cut back
/// further along an adjacent edge than that edge actually is -- which would
/// otherwise overshoot the edge's far end (into whatever lies beyond it,
/// typically the *next* corner) and produce a degenerate, over-cut fillet.
/// Every [CornerStyle] applies this to its raw [radius1]/[radius2] inputs
/// before doing anything else with them, including the styles that average
/// the two into a single shared radius -- so that averaging happens between
/// two values already sane for their own side.
(double, double) _clampRadiiToEdgeLength(
  Segment segment1,
  Segment segment2,
  double radius1,
  double radius2,
) {
  return (min(radius1, segment1.length), min(radius2, segment2.length));
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
  double residual(double t) =>
      _dot(segment.lerp(t) - center, segment.unitTangentAt(t));

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

/// Chain-generalized core of [CircularArcCorner], shared with
/// [roundAllCorners]: [incoming] and [outgoing] are contiguous runs of
/// segments meeting at the corner ([incoming]'s end is [outgoing]'s start).
/// Cuts [radius] of arc length back along [incoming] (traversing across
/// whole segments if the chain has more than one, see [_cutChainIncoming])
/// and solves for the tangent circle exactly as described on
/// [CircularArcCorner] -- except the tangency search walks [outgoing] segment
/// by segment from the corner outward, taking the first tangency found, so
/// the fillet's far endpoint may land on any segment of the chain, not just
/// the one touching the corner. When [incoming] and [outgoing] are the *same*
/// list (a closed path with a single rounded corner, whose two sides are the
/// two ends of one wrapped-around stretch), the outgoing solve runs on the
/// incoming cut's remainder so both trims survive in the returned chain.
(List<Segment>, Segment, List<Segment>) _roundChainCircular(
  List<Segment> incoming,
  List<Segment> outgoing,
  double radius,
) {
  final (kept1, cut1) = _cutChainIncoming(incoming, radius);
  final outSrc = identical(outgoing, incoming) ? kept1 : outgoing;
  final p1 = cut1.point;
  final nDir = cut1.normalDir;

  // Which of the two directions along the normal actually points toward the
  // outgoing side -- i.e. which side of the incoming normal line the fillet
  // center must be on.
  final probeSegment = outSrc.firstWhere(
    (s) => s.length > 1e-12,
    orElse: () => outSrc.first,
  );
  final probe = probeSegment.lerp(0.5) - p1;
  final sign = _dot(probe, nDir) >= 0 ? 1.0 : -1.0;

  // First tangency walking the outgoing chain from the corner outward. When
  // none exists anywhere on the chain, the chain's far endpoint stands in:
  // this is what makes a fillet whose tangent point lands *exactly* on the
  // chain's end findable at all -- just past that boundary the
  // perpendicularity residual has no root, so without the stand-in the
  // sampling below would see NaN on one side of the answer and never bracket
  // it. (It also means a tangency the chain is too short for saturates at
  // the chain's end instead of failing -- see the caveats on
  // [roundAllCorners].)
  (int, double) tangency(P center) {
    for (int i = 0; i < outSrc.length; i++) {
      final t = _paramOfTangencyTo(outSrc[i], center);
      if (t != null) return (i, t);
    }
    return (outSrc.length - 1, 1.0);
  }

  double residualForS(double s) {
    final center = p1 + nDir * (sign * s);
    final (i, t) = tangency(center);
    return outSrc[i].lerp(t).distanceTo(center) - s;
  }

  // Dense-sample-then-bisect for the s at which the candidate circle actually
  // reaches the outgoing chain (see _paramOfTangencyTo). The search range is
  // scaled to the corner's own size, generous enough to cover any reasonable
  // fillet.
  final searchScale =
      (radius + _chainLength(incoming) + _chainLength(outSrc)) * 4;
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
  final kept2Landing = outSrc[landIndex].bifurcateAtInterval(t2).$2;
  final p2 = kept2Landing.p1;
  final circleRadius = center.distanceTo(p1);

  return (
    kept1,
    _circularArcTowardCenter(p1, p2, circleRadius, center),
    [kept2Landing, ...outSrc.sublist(landIndex + 1)],
  );
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

/// The tangent-ellipse construction of [EllipticArcCorner] (see that class's
/// doc for the geometry), factored to build the fillet from the two cut
/// endpoints and tangent directions alone -- which is all it ever needed, and
/// what lets [roundAllCorners] reuse it with cut points that may live on any
/// segment of a multi-segment chain.
Segment _ellipticFilletFromCuts(_Cut cut1, _Cut cut2) {
  final a = cut1.point, b = cut2.point;

  final tangentLine1 = _lineThrough(a, cut1.tangentDir);
  final tangentLine2 = _lineThrough(b, cut2.tangentDir);
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

  return _arcTowardCenter(a, b, P(rx, ry), rotation, center);
}

/// Chain-generalized core of [InvertedArcCorner], shared with
/// [roundAllCorners]: [incoming] and [outgoing] are contiguous runs of
/// segments meeting at [vertex]. The two cut points are wherever the circle
/// of [radius] centered on [vertex] first crosses each chain walking away
/// from the corner ([_cutChainIncomingToChord] / [_cutChainOutgoingToChord]),
/// so on a multi-segment chain the notch's endpoint may land past any number
/// of intermediate junctions -- the crossing is a property of the circle, not
/// of segment boundaries, so the construction generalizes unchanged. The
/// sweep direction comes from the turn between the two chains' tangents *at
/// the vertex*, same as the single-corner version. When [incoming] and
/// [outgoing] are the same list (a closed path with a single rounded corner),
/// the outgoing cut is applied to the incoming cut's remainder so both trims
/// survive in the returned chain.
(List<Segment>, Segment, List<Segment>) _roundChainInverted(
  List<Segment> incoming,
  List<Segment> outgoing,
  double radius,
  P vertex,
) {
  final turn =
      incoming.last.unitTangentAt(1).angle -
      outgoing.first.unitTangentAt(0).angle;

  final (kept1, cut1) = _cutChainIncomingToChord(incoming, vertex, radius);
  final outSrc = identical(outgoing, incoming) ? kept1 : outgoing;
  final (kept2, cut2) = _cutChainOutgoingToChord(outSrc, vertex, radius);

  return (
    kept1,
    CircularArcSegment(
      cut1.point,
      cut2.point,
      radius,
      clockwise: turn.value >= pi,
      largeArc: false,
    ),
    kept2,
  );
}

Segment _chamferFilletFromCuts(_Cut cut1, _Cut cut2) =>
    LineSegment(cut1.point, cut2.point);

/// Cuts [radius1]/[radius2] of arc length back along the [incoming]/
/// [outgoing] chains (traversing whole segments if a chain has more than one,
/// see [_cutChainIncoming]) and bridges the two cut points with
/// [filletFromCuts] -- the shared chain-generalized shape of every style
/// whose fillet is fully determined by its two cut points and the tangent
/// directions there (chamfer, quadratic/cubic Bézier, squircle, elliptic
/// arc). When [incoming] and [outgoing] are the *same* list (a closed path
/// with a single rounded corner, whose two sides are the two ends of one
/// wrapped-around stretch), the outgoing cut is applied to the incoming cut's
/// remainder so both trims survive in the returned chain.
(List<Segment>, Segment, List<Segment>) _roundChainWithCuts(
  List<Segment> incoming,
  List<Segment> outgoing,
  double radius1,
  double radius2,
  Segment Function(_Cut cut1, _Cut cut2) filletFromCuts,
) {
  final (kept1, cut1) = _cutChainIncoming(incoming, radius1);
  final outSrc = identical(outgoing, incoming) ? kept1 : outgoing;
  final (kept2, cut2) = _cutChainOutgoing(outSrc, radius2);
  return (kept1, filletFromCuts(cut1, cut2), kept2);
}

Segment _quadraticFilletFromCuts(_Cut cut1, _Cut cut2) {
  final tangentLine1 = _lineThrough(cut1.point, cut1.tangentDir);
  final tangentLine2 = _lineThrough(cut2.point, cut2.tangentDir);
  final controlPoint = tangentLine1.intersectInfiniteLine(tangentLine2);
  return QuadraticSegment(p1: cut1.point, p2: cut2.point, c: controlPoint);
}

Segment _cubicFilletFromCuts(_Cut cut1, _Cut cut2) {
  final tangentLine1 = _lineThrough(cut1.point, cut1.tangentDir);
  final tangentLine2 = _lineThrough(cut2.point, cut2.tangentDir);
  final anchor = tangentLine1.intersectInfiniteLine(tangentLine2);
  return CubicSegment(p1: cut1.point, p2: cut2.point, c1: anchor, c2: anchor);
}

/// A style of corner rounding: the seven ways this library can bridge two
/// segments meeting at a corner, plus the [squircle] alias, unified under one
/// sealed hierarchy. Each style is a `final class` that owns its own
/// construction -- [construct] and the chain-generalized [_constructChain] it
/// delegates to -- so adding an eighth style means adding a class, never
/// editing this one, [roundAllCorners], or any other style's code.
///
/// The seven concrete constructions -- [circularArc], [ellipticArc],
/// [invertedArc], [chamfer], [quadraticBezier], [cubicBezier], and the
/// [squircle] alias of [cubicBezier] -- are reached as `static const`
/// instances on this class, so call sites read the same as they would
/// against an enum (`CornerStyle.circularArc`, `CornerStyle.squircle`, ...)
/// and remain usable as compile-time constants. [values] stands in for the
/// `.values` list an `enum` would give for free.
///
/// Marked `sealed` rather than `abstract`: the set of styles is closed to
/// this library, the same guarantee an `enum` gives, and an exhaustive
/// `switch` over [CornerStyle] anywhere calling code needs to branch on style
/// is still compiler-checked.
sealed class CornerStyle {
  const CornerStyle();

  static const circularArc = CircularArcCorner();
  static const ellipticArc = EllipticArcCorner();
  static const invertedArc = InvertedArcCorner();
  static const chamfer = ChamferCorner();
  static const quadraticBezier = QuadraticBezierCorner();
  static const cubicBezier = CubicBezierCorner();

  /// Alias of [cubicBezier]: the identical construction, under the name
  /// design tools use for this look (Figma's corner smoothing, the
  /// "squircle"/superellipse aesthetic). `identical(CornerStyle.squircle,
  /// CornerStyle.cubicBezier)` is true -- there is exactly one
  /// [CubicBezierCorner] class, and this is another name for its one
  /// instance, not a second construction.
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
  /// outgoing chain. When [incoming] and [outgoing] are the *same* list (a
  /// closed path with a single rounded corner), the outgoing cut runs on the
  /// incoming cut's remainder so both trims survive in the returned chain.
  (List<Segment>, Segment, List<Segment>) _constructChain(
    List<Segment> incoming,
    List<Segment> outgoing,
    double radius1,
    double radius2,
    P vertex,
  );

  /// Rounds the corner shared by [segment1] and [segment2] with this style --
  /// [segment1] and [segment2] may each be a straight line or any curved
  /// segment type ([QuadraticSegment], [CubicSegment], [CircularArcSegment],
  /// [ArcSegment]). [radius] is clamped per side to its own segment's arc
  /// length (see [_clampRadiiToEdgeLength]) before this style cuts back and
  /// bridges the two cut points.
  List<Segment> construct(
    Segment segment1,
    Segment segment2,
    CornerRadius radius,
  ) {
    assert(segment1.p2.isEqual(segment2.p1));
    final (radius1, radius2) = _clampRadiiToEdgeLength(
      segment1,
      segment2,
      radius.incoming,
      radius.outgoing,
    );
    final (kept1, fillet, kept2) = _constructChain(
      [segment1],
      [segment2],
      radius1,
      radius2,
      segment1.p2,
    );
    return [...kept1, fillet, ...kept2];
  }
}

/// Segments shorter than this are dropped from [roundAllCorners]' output --
/// the leftovers of an edge consumed whole by its corners' cuts.
const double _degenerateLength = 1e-9;

/// Rounds every corner of [path] in one operation -- the whole-shape
/// counterpart to a single corner's `style.construct(...)` call, and the
/// operation design tools actually ship: walk the path, fillet each vertex
/// with [style], splice the results back together.
///
/// ## Corners and radii
///
/// A "corner" is a junction between consecutive segments: junction `j` is
/// where `path.segments[j]` ends. An open path has `numSegments - 1`
/// junctions; a closed path also has the wrap-around junction where the last
/// segment meets the first, giving `numSegments` (junction `numSegments - 1`
/// being the wrap). Exactly one of [radius] (one [CornerRadius] for every
/// corner) or [radii] (one [CornerRadius] per junction, indexed as above --
/// this is Figma-style per-vertex radii across the whole shape) must be
/// provided. A junction whose radius is zero (or negative) on both sides is
/// left sharp, and a *smooth* junction -- one whose incoming and outgoing
/// tangents already agree -- is always left alone, since there is no corner
/// there to round; with [traverseSegments] such junctions are exactly what a
/// large fillet cuts across.
///
/// ## Cross-corner radius clamping
///
/// Radii are clamped against what actually fits, in two steps. First each
/// corner's radius is capped per side at the length of the run of path it is
/// allowed to cut into (its adjacent segment, or with [traverseSegments] the
/// whole stretch to the next rounded corner). Then every such run is checked
/// against the *combined* demand of the two corners cutting into it from
/// either end -- the classic short-edge-between-two-rounded-corners case
/// every design tool caps automatically -- and when they oversubscribe it,
/// both corners' radii are scaled down proportionally (`run length /
/// combined demand`; for two equal radii this is the familiar
/// "half the shorter edge" cap). A corner squeezed on one side is scaled as
/// a whole -- both its radii shrink by its worst edge's factor -- so the
/// fillet keeps its proportions rather than going lopsided. For styles whose
/// [CornerStyle.honorsAsymmetricRadius] is `false` the demand each corner
/// places on a run is its *averaged* radius, since that is what will actually
/// be cut; the per-side cap happens before averaging (see
/// [_clampRadiiToEdgeLength]).
///
/// ## Traversal ([traverseSegments])
///
/// With [traverseSegments] false (the default, and how Illustrator, Inkscape,
/// and Figma all behave) a fillet's endpoints stay on the two segments
/// touching the vertex: a radius larger than an adjacent segment clamps.
/// With it true, a cut that runs off the end of its adjacent segment
/// continues into the segments beyond, consuming intermediate junctions whole
/// -- useful when a path's "sides" are really chains of several segments
/// (e.g. a polyline approximating a curve). Cuts still never cross a
/// *rounded* corner: the stretch of path between two consecutive rounded
/// corners is exactly the run the two share under the clamping rules above.
///
/// ## Result
///
/// Returns a [Loop] when [path] is closed (rounding preserves closedness) and
/// a plain [VectorPath] otherwise; an open path's two endpoints are never
/// moved. Segments consumed whole by a cut are dropped from the output, as
/// are the zero-length leftovers of an edge exactly used up.
///
/// Two caveats inherited from the single-corner constructions, both only
/// reachable through curved geometry: [CornerStyle.circularArc]'s far cut
/// point is solved for tangency rather than prescribed, and
/// [CornerStyle.invertedArc]'s cut points are at a straight-line distance
/// from the vertex rather than an arc-length one -- so on curved sides
/// either can consume slightly more arc length than the budget above
/// reserved. Corners are processed in path order on the surviving geometry,
/// so an overrun shrinks a neighbor's fillet rather than producing
/// overlapping or discontinuous output.
VectorPath roundAllCorners(
  VectorPath path,
  CornerStyle style, {
  CornerRadius? radius,
  List<CornerRadius>? radii,
  bool traverseSegments = false,
}) {
  if ((radius == null) == (radii == null)) {
    throw ArgumentError('exactly one of radius or radii must be provided');
  }
  final segments = path.segments;
  final n = segments.length;
  final closed = path.isClosed();
  final junctionCount = n == 0 ? 0 : (closed ? n : n - 1);
  if (radii != null && radii.length != junctionCount) {
    throw ArgumentError.value(
      radii,
      'radii',
      'expected one radius per junction ($junctionCount), '
          'got ${radii.length}',
    );
  }
  if (junctionCount == 0) return path;

  CornerRadius requestedAt(int j) => radii != null ? radii[j] : radius!;

  // A smooth junction has no corner to round: the incoming and outgoing
  // tangents already agree.
  bool isSmooth(int j) {
    final a = segments[j].unitTangentAt(1);
    final b = segments[(j + 1) % n].unitTangentAt(0);
    return (a.x * b.y - a.y * b.x).abs() < 1e-9 && _dot(a, b) > 0;
  }

  bool needsRounding(int j) {
    final r = requestedAt(j);
    return (r.incoming > 0 || r.outgoing > 0) && !isSmooth(j);
  }

  // Junction indices that actually get a fillet, in path order.
  final corners = [
    for (int j = 0; j < junctionCount; j++)
      if (needsRounding(j)) j,
  ];
  if (corners.isEmpty) return path;
  final m = corners.length;
  final cornerIndexAt = {for (int t = 0; t < m; t++) corners[t]: t};

  // Barriers are the junctions a cut may not pass: every junction when
  // traversal is off, only the rounded corners themselves when it's on. The
  // path splits at the barriers into "stretches" -- the maximal runs a cut is
  // allowed to roam -- with each rounded corner sitting at the end of one
  // stretch and the start of the next.
  final barriers = traverseSegments
      ? corners
      : [for (int j = 0; j < junctionCount; j++) j];
  final b = barriers.length;

  // stretches[k] holds the (current, progressively trimmed) segments of
  // stretch k; stretch k ends at junction barriers[k]. For an open path a
  // final extra stretch runs from the last barrier to the path's end.
  final stretches = <List<Segment>>[];
  if (closed) {
    for (int k = 0; k < b; k++) {
      final run = <Segment>[];
      for (int j = (barriers[(k - 1 + b) % b] + 1) % n; ; j = (j + 1) % n) {
        run.add(segments[j]);
        if (j == barriers[k]) break;
      }
      stretches.add(run);
    }
  } else {
    for (int k = 0; k < b; k++) {
      final from = k == 0 ? 0 : barriers[k - 1] + 1;
      stretches.add([for (int j = from; j <= barriers[k]; j++) segments[j]]);
    }
    stretches.add([for (int j = barriers[b - 1] + 1; j < n; j++) segments[j]]);
  }
  final stretchLengths = [for (final s in stretches) _chainLength(s)];

  // Corner t's incoming stretch ends at its junction; its outgoing stretch
  // starts there. Corners are a subset of barriers, so both always exist.
  final barrierIndexAt = {for (int k = 0; k < b; k++) barriers[k]: k};
  int stretchIntoCorner(int t) => barrierIndexAt[corners[t]]!;
  int stretchOutOfCorner(int t) => closed
      ? (barrierIndexAt[corners[t]]! + 1) % b
      : barrierIndexAt[corners[t]]! + 1;

  // Per-side cap against the stretch a cut may roam, then the demand each
  // corner actually places on its two stretches (the averaged radius for
  // styles that don't honor asymmetric radii -- that is what they cut on
  // both sides).
  final radiusIn = List<double>.filled(m, 0);
  final radiusOut = List<double>.filled(m, 0);
  final demandIn = List<double>.filled(m, 0);
  final demandOut = List<double>.filled(m, 0);
  for (int t = 0; t < m; t++) {
    final r = requestedAt(corners[t]);
    radiusIn[t] = min(r.incoming, stretchLengths[stretchIntoCorner(t)]);
    radiusOut[t] = min(r.outgoing, stretchLengths[stretchOutOfCorner(t)]);
    if (!style.honorsAsymmetricRadius) {
      demandIn[t] = demandOut[t] = (radiusIn[t] + radiusOut[t]) / 2;
    } else {
      demandIn[t] = radiusIn[t];
      demandOut[t] = radiusOut[t];
    }
  }

  // Each stretch is cut from its end by the corner there (if rounded) and
  // from its start by the corner at the barrier before it (if rounded); when
  // the two together demand more than the stretch has, both scale down
  // proportionally.
  final stretchFactor = List<double>.filled(stretches.length, 1.0);
  for (int k = 0; k < stretches.length; k++) {
    final endCorner = k < b ? cornerIndexAt[barriers[k]] : null;
    final startBarrier = closed
        ? barriers[(k - 1 + b) % b]
        : (k > 0 ? barriers[k - 1] : null);
    final startCorner = startBarrier == null
        ? null
        : cornerIndexAt[startBarrier];
    final demand =
        (endCorner == null ? 0 : demandIn[endCorner]) +
        (startCorner == null ? 0 : demandOut[startCorner]);
    if (demand > stretchLengths[k] && demand > 0) {
      stretchFactor[k] = stretchLengths[k] / demand;
    }
  }

  // Round each corner in path order, always cutting the *surviving* geometry.
  // Every stretch is shared by at most two corner sides cutting opposite ends
  // of it, and the budget above guarantees they fit, so order only matters
  // for the two overrun caveats in the doc comment.
  final fillets = List<Segment?>.filled(m, null);
  for (int t = 0; t < m; t++) {
    final factor = min(
      stretchFactor[stretchIntoCorner(t)],
      stretchFactor[stretchOutOfCorner(t)],
    );
    final incoming = stretches[stretchIntoCorner(t)];
    final outgoing = stretches[stretchOutOfCorner(t)];
    final (kept1, fillet, kept2) = style._constructChain(
      incoming,
      outgoing,
      radiusIn[t] * factor,
      radiusOut[t] * factor,
      segments[corners[t]].p2,
    );
    stretches[stretchIntoCorner(t)] = kept1;
    stretches[stretchOutOfCorner(t)] = kept2;
    fillets[t] = fillet;
  }

  // Splice: each stretch followed by the fillet at the barrier it ends on.
  final result = <Segment>[];
  for (int k = 0; k < stretches.length; k++) {
    result.addAll(stretches[k].where((s) => s.length > _degenerateLength));
    if (k < b) {
      final t = cornerIndexAt[barriers[k]];
      if (t != null) result.add(fillets[t]!);
    }
  }

  if (!closed) return VectorPath(result);
  // Joins are bitwise exact by construction (see _Cut), but dropping a
  // fully-consumed edge's zero-length leftover can leave the seam a few ulps
  // open -- and Loop's closure check is exact, so snap it shut.
  final last = result.last;
  if (last.p2 != result.first.p1) {
    result[result.length - 1] = last.updateByPointAddresses({
      TangiblePointAddress(segment: last, name: PointId.p2): result.first.p1,
    });
  }
  return Loop(result);
}
