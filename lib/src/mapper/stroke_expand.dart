import 'dart:math';

import 'package:ramanujan/ramanujan.dart' show P;

import '../segment/segment.dart';
import 'stroke_expand_with_profile.dart';

/// Which side(s) of the curve to offset in [strokeExpand].
enum StrokeExpandSide {
  /// Offset both sides symmetrically — produces a lens shape.
  both,

  /// Offset only the right side (positive normal); original curve is the left edge.
  a,

  /// Offset only the left side (negative normal); original curve is the right edge.
  b,
}

/// Expands [segments] into a filled outline using same-type offset curves.
///
/// [segments] is treated as a single connected path. The stroke width peaks at
/// [maxWidth] at the midpoint of each segment and is [maxWidth] at all interior
/// joints — only the very first point ([widthAtP1]) and the very last point
/// ([widthAtP2]) can taper to a different width (default 0). A zero-width end
/// closes to a point; an end with non-zero width is closed with a flat cap
/// joining the two offset edges, so the returned outline is always a closed loop.
///
/// [side] selects which side(s) are offset; the other edge uses the original path.
/// Returns a single list of segments forming the full outline.
///
/// Per-segment type dispatch:
/// - [CubicSegment]: two cubics fitted to the true perpendicular offset.
/// - [QuadraticSegment]: two quadratics fitted to the true perpendicular offset.
/// - [LineSegment]: two cubics fitted to the tapered offset.
/// - [CircularArcSegment]: two circular arcs via circumcircle fit (exact for
///   uniform width — always the case for closed paths).
/// - [ArcSegment]: cubic Béziers fitted to the perpendicular offset, one per
///   ~quarter turn of the arc (the ellipse offset is not itself an ellipse).
/// - Everything else: delegates to [strokeExpandWithProfile] (polyline fallback).
List<Segment> strokeExpand(
  List<Segment> segments, {
  required double maxWidth,
  double widthAtP1 = 0,
  double widthAtP2 = 0,
  StrokeExpandSide side = StrokeExpandSide.both,
}) {
  assert(segments.isNotEmpty);

  // Detect closed paths: if the last segment's p2 coincides with the first
  // segment's p1 the path loops back on itself. Treat the seam as an interior
  // joint so the stroke doesn't taper to zero there.
  final isClosed = (segments.last.p2 - segments.first.p1).lengthSquared < 1e-6;

  // Pre-compute the seam joint normal for closed paths (average of the
  // incoming and outgoing normals at the shared start/end point).
  final P seamNormal;
  if (isClosed) {
    final avg = _normalAtP2(segments.last) + _normalAtP1(segments.first);
    seamNormal =
        avg.length < 1e-10 ? _normalAtP1(segments.first) : avg.normalized;
  } else {
    seamNormal = _normalAtP1(segments.first); // unused
  }

  // At each interior joint, average the two meeting normals so both adjacent
  // segments share the same offset endpoint (no gap or overlap at joins).
  // Normals are taken in path orientation (see [_normalAtP1]/[_normalAtP2]) so a
  // segment whose lerp runs p2→p1 (a CW circular arc) still contributes the same
  // geometric side as its neighbours — otherwise the offset edge breaks at the
  // joint (e.g. at an S-curve inflection where a CCW arc meets a CW arc).
  final jointNormals = List<P>.generate(segments.length + 1, (i) {
    if (i == 0) return isClosed ? seamNormal : _normalAtP1(segments[0]);
    if (i == segments.length) {
      return isClosed ? seamNormal : _normalAtP2(segments[segments.length - 1]);
    }
    final avg = _normalAtP2(segments[i - 1]) + _normalAtP1(segments[i]);
    return avg.length < 1e-10 ? _normalAtP2(segments[i - 1]) : avg.normalized;
  });

  final sideAs = <Segment>[];
  final sideBs = <Segment>[];

  for (int i = 0; i < segments.length; i++) {
    final hw0 = (i == 0 && !isClosed) ? widthAtP1 / 2 : maxWidth / 2;
    final hw2 =
        (i == segments.length - 1 && !isClosed) ? widthAtP2 / 2 : maxWidth / 2;
    final (a, b) = _expandOne(
      segments[i],
      maxWidth: maxWidth,
      hw0: hw0,
      hw2: hw2,
      n0: jointNormals[i],
      n1: jointNormals[i + 1],
    );
    sideAs.addAll(a);
    sideBs.addAll(b);
  }

  // The two offset edges meet at each end of an open stroke. A cap segment
  // joining them is needed at the far (p2) end for closed paths (the seam —
  // otherwise a renderer bridges the gap with an unintended straight line,
  // nicking the donut fill) and at any open end with non-zero width: without the
  // cap the renderer runs a straight line between the diverging edges, collapsing
  // the mouth. The far cap also closes the seam of a closed path; the near (p1)
  // cap is only for open paths (a closed path's single seam is the far cap).
  // Emit each whenever its two endpoints don't already coincide (a zero-width
  // taper end leaves them equal, needing no cap).
  bool gap(P a, P b) => (a - b).lengthSquared > 1e-9;

  // Closes the outline loop back to its start: the traversal ends at the side-B
  // start point, so a cap returns it to the side-A start point.
  Iterable<Segment> startCap(P fromB, P toA) =>
      (!isClosed && gap(fromB, toA)) ? [LineSegment(fromB, toA)] : const [];

  return switch (side) {
    StrokeExpandSide.both => [
        ...sideAs,
        if (gap(sideAs.last.p2, sideBs.last.p2))
          LineSegment(sideAs.last.p2, sideBs.last.p2),
        ...sideBs.reversed.map((s) => s.reversed()),
        ...startCap(sideBs.first.p1, sideAs.first.p1),
      ],
    StrokeExpandSide.a => [
        ...sideAs,
        if (gap(sideAs.last.p2, segments.last.p2))
          LineSegment(sideAs.last.p2, segments.last.p2),
        ...segments.reversed.map((s) => s.reversed()),
        ...startCap(segments.first.p1, sideAs.first.p1),
      ],
    StrokeExpandSide.b => [
        ...segments,
        if (gap(segments.last.p2, sideBs.last.p2))
          LineSegment(segments.last.p2, sideBs.last.p2),
        ...sideBs.reversed.map((s) => s.reversed()),
        ...startCap(sideBs.first.p1, segments.first.p1),
      ],
  };
}

/// True when the segment's [Segment.lerp] runs p2→p1 rather than p1→p2 — the
/// case for CW [CircularArcSegment]s, whose parameter starts at the end angle.
/// For such segments the parameter normal is read from the opposite end and
/// points the opposite way relative to the path's p1→p2 travel direction.
bool _lerpReversed(Segment s) =>
    (s.lerp(0) - s.p2).lengthSquared < (s.lerp(0) - s.p1).lengthSquared;

/// Unit normal at the segment's geometric p1 / p2, oriented consistently along
/// the p1→p2 path direction (so neighbouring segments offset to the same side
/// and their edges meet at the joint). Equal to [Segment.unitNormalAt] at 0/1
/// for ordinary segments; for a reversed-lerp segment we read the far parameter
/// end and negate to undo the reversed travel direction.
P _normalAtP1(Segment s) =>
    _lerpReversed(s) ? s.unitNormalAt(1) * -1 : s.unitNormalAt(0);
P _normalAtP2(Segment s) =>
    _lerpReversed(s) ? s.unitNormalAt(0) * -1 : s.unitNormalAt(1);

/// Returns the (sideA, sideB) offset segments for a single segment.
///
/// Returns lists because some types produce multiple segments: elliptical arcs
/// fit one cubic per sub-span, and unknown types produce polylines via the
/// fallback. Cubic/quadratic/line/circular-arc always return single-element lists.
(List<Segment>, List<Segment>) _expandOne(
  Segment segment, {
  required double maxWidth,
  required double hw0,
  required double hw2,
  required P n0,
  required P n1,
}) {
  final chw = maxWidth - 0.5 * (hw0 + hw2);

  if (segment is CubicSegment) {
    final nt1 = segment.unitNormalAt(1 / 3);
    final nt2 = segment.unitNormalAt(2 / 3);
    final hwt1 = _quadHW(1 / 3, hw0, chw, hw2);
    final hwt2 = _quadHW(2 / 3, hw0, chw, hw2);
    final p1a = segment.p1 + n0 * hw0;
    final p2a = segment.p2 + n1 * hw2;
    final (c1a, c2a) = _fitCubicHandles(
      p1a,
      segment.lerp(1 / 3) + nt1 * hwt1,
      segment.lerp(2 / 3) + nt2 * hwt2,
      p2a,
    );
    final p1b = segment.p1 - n0 * hw0;
    final p2b = segment.p2 - n1 * hw2;
    final (c1b, c2b) = _fitCubicHandles(
      p1b,
      segment.lerp(1 / 3) - nt1 * hwt1,
      segment.lerp(2 / 3) - nt2 * hwt2,
      p2b,
    );
    return (
      [CubicSegment(p1: p1a, c1: c1a, c2: c2a, p2: p2a)],
      [CubicSegment(p1: p1b, c1: c1b, c2: c2b, p2: p2b)],
    );
  }

  if (segment is QuadraticSegment) {
    final nmid = segment.unitNormalAt(0.5);
    final hwmid = maxWidth / 2;
    final p1a = segment.p1 + n0 * hw0;
    final p2a = segment.p2 + n1 * hw2;
    final qmida = segment.lerp(0.5) + nmid * hwmid;
    final p1b = segment.p1 - n0 * hw0;
    final p2b = segment.p2 - n1 * hw2;
    final qmidb = segment.lerp(0.5) - nmid * hwmid;
    return (
      [QuadraticSegment(p1: p1a, c: qmida * 2 - (p1a + p2a) * 0.5, p2: p2a)],
      [QuadraticSegment(p1: p1b, c: qmidb * 2 - (p1b + p2b) * 0.5, p2: p2b)],
    );
  }

  if (segment is LineSegment) {
    final n = segment.unitNormalAt(0.5);
    final hwt1 = _quadHW(1 / 3, hw0, chw, hw2);
    final hwt2 = _quadHW(2 / 3, hw0, chw, hw2);
    final p1a = segment.p1 + n0 * hw0;
    final p2a = segment.p2 + n1 * hw2;
    final (c1a, c2a) = _fitCubicHandles(
      p1a,
      segment.lerp(1 / 3) + n * hwt1,
      segment.lerp(2 / 3) + n * hwt2,
      p2a,
    );
    final p1b = segment.p1 - n0 * hw0;
    final p2b = segment.p2 - n1 * hw2;
    final (c1b, c2b) = _fitCubicHandles(
      p1b,
      segment.lerp(1 / 3) - n * hwt1,
      segment.lerp(2 / 3) - n * hwt2,
      p2b,
    );
    return (
      [CubicSegment(p1: p1a, c1: c1a, c2: c2a, p2: p2a)],
      [CubicSegment(p1: p1b, c1: c1b, c2: c2b, p2: p2b)],
    );
  }

  // Circular arc: fit a circumcircle through three offset points per side.
  // When hw0 == hw2 == maxWidth/2 (always for closed paths), the circumcircle
  // is exact: same center as original, radius r ± hw. n0/n1 are already in path
  // orientation (see [_normalAtP1]), so they pair directly with geometric p1/p2;
  // the midpoint normal is flipped to match for CW (reversed-lerp) arcs.
  if (segment is CircularArcSegment) {
    final flip = _lerpReversed(segment) ? -1.0 : 1.0;

    // The concentric circumcircle fit is only exact when the width is constant
    // along the arc. With a tapered end (hw0 != hw2 != maxWidth/2) the offset is
    // no longer a circular arc, and forcing one through three points yields a
    // wildly wrong radius/largeArc. Fall back to the cubic fit used for ellipses.
    final uniform = (hw0 - maxWidth / 2).abs() < 1e-9 &&
        (hw2 - maxWidth / 2).abs() < 1e-9;
    if (!uniform) {
      final n = max(1, (segment.angle.value / (pi / 2)).ceil());
      return _offsetByCubicFit(segment,
          hw0: hw0, chw: chw, hw2: hw2, nP1: n0, nP2: n1, pieces: n);
    }

    final hwmid = _quadHW(0.5, hw0, chw, hw2);
    final midPt = segment.lerp(0.5);
    final midN = segment.unitNormalAt(0.5) * flip;

    final p1a = segment.p1 + n0 * hw0;
    final p2a = segment.p2 + n1 * hw2;
    final midA = midPt + midN * hwmid;
    final p1b = segment.p1 - n0 * hw0;
    final p2b = segment.p2 - n1 * hw2;
    final midB = midPt - midN * hwmid;

    final caA = _circumcenter(p1a, midA, p2a);
    final caB = _circumcenter(p1b, midB, p2b);
    final rA = (p1a - caA).length;
    final rB = (p1b - caB).length;

    return (
      rA > 1e-6
          ? [
              CircularArcSegment(p1a, p2a, rA,
                  largeArc: _largeArcFor(p1a, midA, p2a, caA),
                  clockwise: _clockwiseFor(p1a, midA, p2a))
            ]
          : [LineSegment(p1a, p2a)],
      rB > 1e-6
          ? [
              CircularArcSegment(p1b, p2b, rB,
                  largeArc: _largeArcFor(p1b, midB, p2b, caB),
                  clockwise: _clockwiseFor(p1b, midB, p2b))
            ]
          : [LineSegment(p1b, p2b)],
    );
  }

  // Elliptical arc: the offset of an ellipse is not itself an ellipse, so we
  // approximate each side with cubic Béziers fitted to the true perpendicular
  // offset — the same strategy used for tapered circular arcs. Subdivide by
  // eccentric-angle span (one cubic per ~quarter turn) so wide arcs stay accurate.
  if (segment is ArcSegment) {
    final sweep = segment.clockwise
        ? (segment.startAngle - segment.endAngle).value
        : (segment.endAngle - segment.startAngle).value;
    final span = sweep == 0 ? 2 * pi : sweep;
    final n = max(1, (span / (pi / 2)).ceil());
    return _offsetByCubicFit(segment,
        hw0: hw0, chw: chw, hw2: hw2, nP1: n0, nP2: n1, pieces: n);
  }

  throw ArgumentError(
      'strokeExpand has no offset strategy for ${segment.runtimeType}');
}

/// Approximates both offset sides of [segment] with cubic Béziers fitted to the
/// true perpendicular offset, for segment types (elliptical arcs, tapered
/// circular arcs) whose constant- or variable-width offset is not the same type.
///
/// The arc is split into [pieces] sub-spans of equal parameter length; each gets
/// one cubic fitted through its offset endpoints and the offset of its t=1/3 and
/// t=2/3 points, so consecutive pieces share endpoints (each side stays C0).
/// Half-width follows the quadratic [_quadHW] profile in path order (0→1). [nP1]
/// and [nP2] are the path-oriented normals at the geometric endpoints p1/p2
/// (side-A orientation, supplied by the caller for join continuity); interior
/// samples use the segment's own normal, flipped for reversed-lerp segments so
/// it agrees with [nP1]/[nP2]. Arcs whose [Segment.lerp] runs p2→p1 (CW circular
/// arcs) are detected so path order and geometric order stay aligned.
(List<Segment>, List<Segment>) _offsetByCubicFit(
  Segment segment, {
  required double hw0,
  required double chw,
  required double hw2,
  required P nP1,
  required P nP2,
  required int pieces,
}) {
  final reversed = _lerpReversed(segment);
  final flip = reversed ? -1.0 : 1.0;

  // [u] runs 0→1 in path/geometric order (p1→p2); map it to the lerp parameter.
  P offsetAt(double u, double sgn) {
    final t = reversed ? 1 - u : u;
    final P normal;
    if (u <= 1e-9) {
      normal = nP1;
    } else if (u >= 1 - 1e-9) {
      normal = nP2;
    } else {
      normal = segment.unitNormalAt(t) * flip;
    }
    return segment.lerp(t) + normal * (sgn * _quadHW(u, hw0, chw, hw2));
  }

  List<Segment> side(double sgn) {
    final out = <Segment>[];
    for (int k = 0; k < pieces; k++) {
      final uA = k / pieces, uB = (k + 1) / pieces, du = uB - uA;
      final p1s = offsetAt(uA, sgn);
      final p2s = offsetAt(uB, sgn);
      final (c1, c2) = _fitCubicHandles(
        p1s,
        offsetAt(uA + du / 3, sgn),
        offsetAt(uA + 2 * du / 3, sgn),
        p2s,
      );
      out.add(CubicSegment(p1: p1s, c1: c1, c2: c2, p2: p2s));
    }
    return out;
  }

  return (side(1), side(-1));
}

/// Returns true when the arc from [p1] through [mid] to [p2] is the large arc
/// (spans > π). Derived by checking whether [mid] and [center] are on the same
/// side of chord [p1]→[p2]: same side → large arc, opposite sides → small arc.
bool _largeArcFor(P p1, P mid, P p2, P center) {
  final chordX = p2.x - p1.x, chordY = p2.y - p1.y;
  final midSide = chordX * (mid.y - p1.y) - chordY * (mid.x - p1.x);
  final centerSide = chordX * (center.y - p1.y) - chordY * (center.x - p1.x);
  return midSide * centerSide > 0;
}

/// Returns the `clockwise` flag for a [CircularArcSegment] whose arc passes
/// through [p1], [mid], [p2] in order.
/// (mid-p1)×(p2-p1) > 0 in screen coords (y-down) means CW traversal,
/// which maps to clockwise=false in this library's SVG-derived convention.
bool _clockwiseFor(P p1, P mid, P p2) {
  final cross = (mid.x - p1.x) * (p2.y - p1.y) - (mid.y - p1.y) * (p2.x - p1.x);
  return cross < 0;
}

/// Returns the circumcenter of triangle [a][b][c], or the midpoint of [a][c]
/// if the three points are collinear.
P _circumcenter(P a, P b, P c) {
  final d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
  if (d.abs() < 1e-10) return P((a.x + c.x) / 2, (a.y + c.y) / 2);
  final a2 = a.x * a.x + a.y * a.y;
  final b2 = b.x * b.x + b.y * b.y;
  final c2 = c.x * c.x + c.y * c.y;
  return P(
    (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
    (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d,
  );
}

/// Half-width at parameter [t] using a quadratic Bézier profile with
/// control half-width [chw] = maxWidth - 0.5*(hw0+hw2), ensuring the
/// peak at t=0.5 equals maxWidth/2.
double _quadHW(double t, double hw0, double chw, double hw2) {
  final s = 1 - t;
  return s * s * hw0 + 2 * s * t * chw + t * t * hw2;
}

/// Returns (c1, c2) handles for a cubic Bézier that passes exactly through
/// [q1] at t=1/3 and [q2] at t=2/3, given fixed endpoints [p1] and [p2].
///
/// Derived by solving the two cubic Bézier equations at t=1/3 and t=2/3:
///   A = 27·q1 − 8·p1 − p2  →  12·c1 + 6·c2 = A
///   B = 27·q2 − p1 − 8·p2  →   6·c1 + 12·c2 = B
(P, P) _fitCubicHandles(P p1, P q1, P q2, P p2) {
  final bigA = q1 * 27 - p1 * 8 - p2;
  final bigB = q2 * 27 - p1 - p2 * 8;
  return ((bigA * 2 - bigB) / 18, (bigB * 2 - bigA) / 18);
}
