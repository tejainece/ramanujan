import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

/// How the gap left at a *convex* corner is bridged when a path is offset
/// outward — the Inkscape "Join" style.
enum OffsetJoin {
  /// Extend the two offset edges along their tangents until they meet at a
  /// sharp point. Falls back to [bevel] when the point would stick out further
  /// than `miterLimit * |delta|` (a spike), exactly like SVG `stroke-linejoin`.
  miter,

  /// Connect the two offset edges with a circular arc of radius `|delta|`
  /// centred on the original corner — the rounded corners Inkscape's
  /// Path ▸ Outset produces by default.
  round,

  /// Connect the two offset edges with a single straight chord.
  bevel,
}

/// Offsets [segments] perpendicular to itself by [delta], Inkscape's
/// Path ▸ Outset / Path ▸ Inset.
///
/// A positive [delta] **outsets** (grows the area enclosed by a closed path); a
/// negative [delta] **insets** (shrinks it). The grow/shrink direction is taken
/// from the path's winding, so it is independent of whether the path is wound
/// clockwise or counter-clockwise. For an open path there is no inside, so the
/// path is simply shifted toward its clockwise normal by [delta].
///
/// Each segment is offset on its own (preserving its type where the offset of
/// that type is the same type — lines stay lines, circular arcs stay concentric
/// circular arcs; cubics, quadratics and elliptical arcs are fitted with
/// Béziers since their true offset is not the same type). Adjacent offset edges
/// are then reconciled at every corner:
/// - **convex** corners (where the edges pull apart) are bridged with [join];
/// - **concave** corners (where the edges overlap) are trimmed back to the
///   point where the two offset edges intersect.
///
/// This local, per-corner reconciliation can still leave *global*
/// self-intersections when [delta] is large enough to collapse a whole feature
/// (e.g. offsetting past a narrow neck, or outward past overlapping lobes of a
/// concave shape). When [cleanup] is true (the default) and [segments] is
/// closed, a second pass removes these: the raw offset is decomposed into its
/// correctly-filled atomic faces ([simplifyClosedPath]) and re-stitched into
/// the minimal enclosing loop ([mergeFaces]), matching what Illustrator's
/// Offset Path / Inkscape's Dynamic Offset do internally. This pass is a no-op
/// whenever the raw offset has no self-intersections, so it never changes
/// output for the moderate offsets inset/outset is normally used for. If the
/// cleanup splits the offset into disjoint islands (e.g. insetting a dumbbell
/// shape past its waist), only the largest by area is returned — this
/// function always returns a single loop. Pass `cleanup: false` to skip this
/// pass and get the raw, possibly self-intersecting offset (e.g. for
/// performance, or to inspect the artifact itself).
///
/// The result is returned as a fresh list of segments — closed if [segments]
/// was closed, open otherwise.
List<Segment> insetOutset(
  List<Segment> segments,
  double delta, {
  OffsetJoin join = OffsetJoin.round,
  double miterLimit = 4.0,
  bool cleanup = true,
}) {
  if (segments.isEmpty || delta == 0) return List.of(segments);

  final closed = (segments.last.p2 - segments.first.p1).lengthSquared < 1e-9;

  // Signed displacement along each segment's clockwise normal. For a closed
  // path the sign is chosen from the winding so that delta>0 always grows the
  // enclosed area: moving along the cw-normal grows the area exactly when the
  // shoelace signed area is positive (see [_signedArea2]).
  final outwardSign = closed ? (_signedArea2(segments) > 0 ? 1.0 : -1.0) : 1.0;
  final s = delta * outwardSign;

  final offsets = [for (final seg in segments) _offsetSegment(seg, s)];

  final out = <Segment>[];
  for (int i = 0; i < segments.length; i++) {
    final cur = offsets[i];
    if (out.isEmpty) {
      out.addAll(cur);
      continue;
    }
    final j = _resolveJoint(
        out.last, cur.first, segments[i].p1, s, join, miterLimit);
    out[out.length - 1] = j.incoming;
    out
      ..addAll(j.connectors)
      ..add(j.outgoing)
      ..addAll(cur.skip(1));
  }

  // Close the loop: reconcile the last offset edge with the first.
  if (closed && out.length >= 2) {
    final j = _resolveJoint(
        out.last, out.first, segments.first.p1, s, join, miterLimit);
    out[out.length - 1] = j.incoming;
    out[0] = j.outgoing;
    out.addAll(j.connectors); // bridge incoming.p2 → outgoing.p1, closing it
  }

  return (closed && cleanup) ? _resolveSelfIntersections(out) : out;
}

/// Removes the self-intersection artifacts a large [insetOutset] offset can
/// leave (see the "Limitation" note on [insetOutset]): decomposes [raw] into
/// its correctly-filled atomic faces and re-stitches them into the minimal
/// enclosing loop(s).
///
/// No-op (returns [raw] unchanged) whenever [raw] has no self-intersections —
/// [simplifyClosedPath] returns it as the sole face in that case.
List<Segment> _resolveSelfIntersections(List<Segment> raw) {
  final faces = simplifyClosedPath(VectorPath(raw));
  if (faces.length <= 1) return raw;

  final merged = mergeFaces([
    for (final f in faces) ClassifiedFace(f, insideA: true, insideB: true),
  ]);
  if (merged.isEmpty) return raw;

  // A large enough offset can pinch the shape into disjoint islands (e.g.
  // insetting a dumbbell past its waist). This function returns one loop, so
  // keep the largest — the island the offset was chiefly forming.
  merged.sort((a, b) => _signedArea2(b.segments.toList())
      .abs()
      .compareTo(_signedArea2(a.segments.toList()).abs()));
  return merged.first.segments.toList();
}

/// Insets (shrinks) a closed [segments] by [distance] — Inkscape's Path ▸ Inset.
/// [distance] is treated as a magnitude; its sign is ignored.
List<Segment> inset(
  List<Segment> segments,
  double distance, {
  OffsetJoin join = OffsetJoin.round,
  double miterLimit = 4.0,
  bool cleanup = true,
}) =>
    insetOutset(segments, -distance.abs(),
        join: join, miterLimit: miterLimit, cleanup: cleanup);

/// Outsets (grows) a closed [segments] by [distance] — Inkscape's
/// Path ▸ Outset. [distance] is treated as a magnitude; its sign is ignored.
List<Segment> outset(
  List<Segment> segments,
  double distance, {
  OffsetJoin join = OffsetJoin.round,
  double miterLimit = 4.0,
  bool cleanup = true,
}) =>
    insetOutset(segments, distance.abs(),
        join: join, miterLimit: miterLimit, cleanup: cleanup);

/// Generates a ring-like shape representing the area between an inner and outer
/// offset of a closed loop.
/// 
/// Returns a [Region] containing the outset loop (outer boundary) and the inset 
/// loop (inner hole), using an even-odd fill rule.
Region ringFromLoop(
  List<Segment> segments, {
  double innerDistance = 0,
  double outerDistance = 0,
  OffsetJoin join = OffsetJoin.round,
  double miterLimit = 4.0,
  bool cleanup = true,
}) {
  final outer = outset(segments, outerDistance,
      join: join, miterLimit: miterLimit, cleanup: cleanup);
  final inner = inset(segments, innerDistance,
      join: join, miterLimit: miterLimit, cleanup: cleanup);
  return Region([Loop(outer), Loop(inner)], fillRule: FillRule.evenOdd);
}

/// Shoelace signed area × 2 of the closed polygon sampled along [segments].
/// Each segment is sampled at several interior points (in geometric p1→p2
/// order) so the winding direction is read correctly even when the chord
/// polygon is degenerate — e.g. a circle split into two semicircles whose four
/// endpoints are collinear on a diameter. Only the sign is used.
double _signedArea2(List<Segment> segments) {
  const k = 8;
  final pts = <P>[];
  for (final seg in segments) {
    final reversed = (seg.lerp(0) - seg.p2).lengthSquared <
        (seg.lerp(0) - seg.p1).lengthSquared;
    for (int i = 0; i < k; i++) {
      final u = i / k;
      pts.add(seg.lerp(reversed ? 1 - u : u));
    }
  }
  double a2 = 0;
  for (int i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    a2 += a.x * b.y - b.x * a.y;
  }
  return a2;
}

/// The result of reconciling two adjacent offset edges at a corner.
typedef _Joint = ({Segment incoming, List<Segment> connectors, Segment outgoing});

/// Reconciles offset edge [inc] (ending at the corner) with offset edge [out]
/// (leaving it), around the original corner [v]. [s] is the signed cw-normal
/// displacement used for the offset.
_Joint _resolveJoint(Segment inc, Segment out, P v, double s, OffsetJoin join,
    double miterLimit) {
  final a = inc.p2, b = out.p1;
  final tanIn = inc.unitTangentAt(1);
  final tanOut = out.unitTangentAt(0);
  final cross = tanIn.x * tanOut.y - tanIn.y * tanOut.x;

  // Nearly collinear: edges already line up (or leave a hairline gap to bridge).
  if (cross.abs() < 1e-9) {
    return (incoming: inc, connectors: _bevel(a, b), outgoing: out);
  }

  // The corner opens a gap (convex w.r.t. the offset side) exactly when the
  // offset direction agrees with the turn direction: s*cross > 0.
  if (s * cross > 0) {
    return (
      incoming: inc,
      connectors: _joinConnector(a, b, v, s, tanIn, tanOut, join, miterLimit),
      outgoing: out,
    );
  }

  // Concave: the offset edges overlap — trim both back to where they cross.
  final trimmed = _trimToIntersection(inc, out);
  if (trimmed != null) {
    return (incoming: trimmed.$1, connectors: const [], outgoing: trimmed.$2);
  }
  return (incoming: inc, connectors: _bevel(a, b), outgoing: out);
}

List<Segment> _bevel(P a, P b) =>
    (a - b).lengthSquared > 1e-9 ? [LineSegment(a, b)] : const [];

/// Bridges the convex gap from [a] (end of the incoming edge) to [b] (start of
/// the outgoing edge), around corner [v], per the chosen [join] style.
List<Segment> _joinConnector(P a, P b, P v, double s, P tanIn, P tanOut,
    OffsetJoin join, double miterLimit) {
  if ((a - b).lengthSquared < 1e-12) return const [];
  switch (join) {
    case OffsetJoin.bevel:
      return [LineSegment(a, b)];
    case OffsetJoin.round:
      final r = s.abs();
      // a and b both sit on the circle of radius r about v (they are v offset
      // along the two edge normals), so an arc of radius r centred on v joins
      // them exactly. The outward bisector picks the correct (outer) arc.
      final bisector = (a - v).normalized + (b - v).normalized;
      if (bisector.length < 1e-9) return [LineSegment(a, b)]; // 180° spike
      final mid = v + bisector.normalized * r;
      return [Circle(center: v, radius: r).arcThrough(a, mid, b)];
    case OffsetJoin.miter:
      final m = _rayIntersect(a, tanIn, b, tanOut);
      if (m == null || (m - v).length > miterLimit * s.abs()) {
        return [LineSegment(a, b)];
      }
      return [LineSegment(a, m), LineSegment(m, b)];
  }
}

/// Trims [inc] and [out] back to their intersection nearest the shared corner,
/// returning the shortened (incoming, outgoing) pair, or null when no usable
/// interior intersection exists (e.g. the segment pair has no closed-form
/// intersection in this library, or they only meet on an extension).
(Segment, Segment)? _trimToIntersection(Segment inc, Segment out) {
  try {
    final hits = inc.intersect(out);
    if (hits.isEmpty) return null;
    hits.sort((p, q) =>
        (p - inc.p2).lengthSquared.compareTo((q - inc.p2).lengthSquared));
    for (final hit in hits) {
      final ni = _trimEnd(inc, hit);
      final no = _trimStart(out, hit);
      if (ni != null && no != null) return (ni, no);
    }
    return null;
  } catch (_) {
    // ilerp/intersect is unimplemented for some Bézier pairs — caller bevels.
    return null;
  }
}

/// Shortens [s] so it ends at interior point [pt], or null when [pt] is at an
/// endpoint or off the curve. Lines are trimmed directly (their [Segment.ilerp]
/// is undefined for vertical lines); other types split by parameter.
Segment? _trimEnd(Segment s, P pt) {
  if (s is LineSegment) {
    return (pt.isEqual(s.p1) || pt.isEqual(s.p2)) ? null : LineSegment(s.p1, pt);
  }
  final t = s.ilerp(pt);
  if (t.isNaN || t <= 1e-6 || t >= 1 - 1e-6) return null;
  return s.bifurcateAtInterval(t).$1;
}

/// Shortens [s] so it starts at interior point [pt]; counterpart of [_trimEnd].
Segment? _trimStart(Segment s, P pt) {
  if (s is LineSegment) {
    return (pt.isEqual(s.p1) || pt.isEqual(s.p2)) ? null : LineSegment(pt, s.p2);
  }
  final t = s.ilerp(pt);
  if (t.isNaN || t <= 1e-6 || t >= 1 - 1e-6) return null;
  return s.bifurcateAtInterval(t).$2;
}

/// Intersection of ray ([p1] along [d1]) with ray ([p2] along [d2]), or null
/// when parallel.
P? _rayIntersect(P p1, P d1, P p2, P d2) {
  final denom = d1.x * d2.y - d1.y * d2.x;
  if (denom.abs() < 1e-12) return null;
  final t = ((p2.x - p1.x) * d2.y - (p2.y - p1.y) * d2.x) / denom;
  return p1 + d1 * t;
}

/// Offsets a single [segment] by signed distance [s] along its clockwise
/// normal, returning same-type segment(s) where possible. Multiple segments are
/// returned only for elliptical arcs (one cubic per ~quarter turn).
List<Segment> _offsetSegment(Segment segment, double s) {
  // Some segments (clockwise circular arcs) parameterise p2→p1; map a geometric
  // position u∈[0,1] (p1→p2) to the lerp parameter and orient the normal to the
  // p1→p2 travel direction so the offset side is consistent across the path.
  final reversed =
      (segment.lerp(0) - segment.p2).lengthSquared < (segment.lerp(0) - segment.p1).lengthSquared;
  final flip = reversed ? -1.0 : 1.0;
  P pointAt(double u) => segment.lerp(reversed ? 1 - u : u);
  P normalAt(double u) => segment.unitNormalAt(reversed ? 1 - u : u) * flip;
  P offAt(double u) => pointAt(u) + normalAt(u) * s;

  final p1o = segment.p1 + normalAt(0) * s;
  final p2o = segment.p2 + normalAt(1) * s;

  if (segment is LineSegment) {
    return [LineSegment(p1o, p2o)];
  }

  if (segment is CircularArcSegment) {
    // The offset of a circle is a concentric circle: same centre, same angular
    // span, radius shifted by the (radial) normal displacement.
    final rNew = (p1o - segment.center).length;
    if (rNew < 1e-9) return [LineSegment(p1o, p2o)];
    return [
      CircularArcSegment(p1o, p2o, rNew,
          largeArc: segment.largeArc, clockwise: segment.clockwise)
    ];
  }

  if (segment is QuadraticSegment) {
    // Approximate the (non-quadratic) offset with a quadratic through the offset
    // endpoints and offset midpoint.
    final mid = offAt(0.5);
    return [QuadraticSegment(p1: p1o, c: mid * 2 - (p1o + p2o) * 0.5, p2: p2o)];
  }

  if (segment is CubicSegment) {
    final (c1, c2) =
        _fitCubicHandles(p1o, offAt(1 / 3), offAt(2 / 3), p2o);
    return [CubicSegment(p1: p1o, c1: c1, c2: c2, p2: p2o)];
  }

  if (segment is ArcSegment) {
    // The offset of an ellipse is not an ellipse — fit one cubic per ~quarter
    // turn through the true perpendicular offset.
    final sweep = segment.clockwise
        ? (segment.startAngle - segment.endAngle).value
        : (segment.endAngle - segment.startAngle).value;
    final span = sweep == 0 ? 2 * pi : sweep;
    final pieces = max(1, (span / (pi / 2)).ceil());
    final out = <Segment>[];
    for (int k = 0; k < pieces; k++) {
      final uA = k / pieces, uB = (k + 1) / pieces, du = uB - uA;
      final ps = offAt(uA), pe = offAt(uB);
      final (c1, c2) =
          _fitCubicHandles(ps, offAt(uA + du / 3), offAt(uA + 2 * du / 3), pe);
      out.add(CubicSegment(p1: ps, c1: c1, c2: c2, p2: pe));
    }
    return out;
  }

  throw ArgumentError(
      'insetOutset has no offset strategy for ${segment.runtimeType}');
}

/// Returns (c1, c2) handles for a cubic Bézier passing through [q1] at t=1/3 and
/// [q2] at t=2/3 with fixed endpoints [p1], [p2].
(P, P) _fitCubicHandles(P p1, P q1, P q2, P p2) {
  final bigA = q1 * 27 - p1 * 8 - p2;
  final bigB = q2 * 27 - p1 - p2 * 8;
  return ((bigA * 2 - bigB) / 18, (bigB * 2 - bigA) / 18);
}

