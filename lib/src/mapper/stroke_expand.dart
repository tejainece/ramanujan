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
/// ([widthAtP2]) can taper to a different width (default 0). When both endpoint
/// widths are zero the outline is naturally closed. When either is non-zero the
/// sides diverge at that end; closing with a cap is the caller's responsibility.
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
  final isClosed =
      (segments.last.p2 - segments.first.p1).lengthSquared < 1e-6;

  // Pre-compute the seam joint normal for closed paths (average of the
  // incoming and outgoing normals at the shared start/end point).
  final P seamNormal;
  if (isClosed) {
    final avg =
        segments.last.unitNormalAt(1) + segments.first.unitNormalAt(0);
    seamNormal = avg.length < 1e-10
        ? segments.first.unitNormalAt(0)
        : avg.normalized;
  } else {
    seamNormal = segments.first.unitNormalAt(0); // unused
  }

  // At each interior joint, average the two meeting normals so both adjacent
  // segments share the same offset endpoint (no gap or overlap at joins).
  final jointNormals = List<P>.generate(segments.length + 1, (i) {
    if (i == 0) return isClosed ? seamNormal : segments[0].unitNormalAt(0);
    if (i == segments.length) {
      return isClosed ? seamNormal : segments[segments.length - 1].unitNormalAt(1);
    }
    final avg = segments[i - 1].unitNormalAt(1) + segments[i].unitNormalAt(0);
    return avg.length < 1e-10 ? segments[i - 1].unitNormalAt(1) : avg.normalized;
  });

  final sideAs = <Segment>[];
  final sideBs = <Segment>[];

  for (int i = 0; i < segments.length; i++) {
    final hw0 = (i == 0 && !isClosed) ? widthAtP1 / 2 : maxWidth / 2;
    final hw2 = (i == segments.length - 1 && !isClosed) ? widthAtP2 / 2 : maxWidth / 2;
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

  // For closed paths the outer and inner offset loops are disconnected at the
  // seam. A renderer that uses lineTo blindly bridges the gap with an unintended
  // straight line, causing a visible nick. Explicit seam segments make the result
  // one connected path: the seam line and the renderer's implicit close are the
  // same edge traversed in opposite directions and cancel in winding, so the
  // donut fill remains correct.
  return switch (side) {
    StrokeExpandSide.both => [
        ...sideAs,
        if (isClosed) LineSegment(sideAs.last.p2, sideBs.last.p2),
        ...sideBs.reversed.map((s) => s.reversed()),
      ],
    StrokeExpandSide.a => [
        ...sideAs,
        if (isClosed) LineSegment(sideAs.last.p2, segments.last.p2),
        ...segments.reversed.map((s) => s.reversed()),
      ],
    StrokeExpandSide.b => [
        ...segments,
        if (isClosed) LineSegment(segments.last.p2, sideBs.last.p2),
        ...sideBs.reversed.map((s) => s.reversed()),
      ],
  };
}

/// Returns the (sideA, sideB) offset segments for a single segment.
///
/// Returns lists because unknown segment types produce polylines via the fallback.
/// Cubic/quadratic/line/circular-arc always return single-element lists.
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
  // is exact: same center as original, radius r ± hw.
  // CW arcs traverse p2→p1 in parameter space, so n0/n1 (derived from
  // unitNormalAt(0/1)) are swapped relative to geometric p1/p2 — detect and fix.
  if (segment is CircularArcSegment) {
    final lerpStart = segment.lerp(0);
    final isReversed = (lerpStart - segment.p2).lengthSquared <
        (lerpStart - segment.p1).lengthSquared;
    final n0eff = isReversed ? n1 : n0;
    final n1eff = isReversed ? n0 : n1;
    final hwmid = _quadHW(0.5, hw0, chw, hw2);
    final midPt = segment.lerp(0.5);
    final midN = segment.unitNormalAt(0.5);

    final p1a = segment.p1 + n0eff * hw0;
    final p2a = segment.p2 + n1eff * hw2;
    final midA = midPt + midN * hwmid;
    final p1b = segment.p1 - n0eff * hw0;
    final p2b = segment.p2 - n1eff * hw2;
    final midB = midPt - midN * hwmid;

    final caA = _circumcenter(p1a, midA, p2a);
    final caB = _circumcenter(p1b, midB, p2b);
    final rA = (p1a - caA).length;
    final rB = (p1b - caB).length;

    return (
      rA > 1e-6
          ? [CircularArcSegment(p1a, p2a, rA,
              largeArc: _largeArcFor(p1a, midA, p2a, caA),
              clockwise: _clockwiseFor(p1a, midA, p2a))]
          : [LineSegment(p1a, p2a)],
      rB > 1e-6
          ? [CircularArcSegment(p1b, p2b, rB,
              largeArc: _largeArcFor(p1b, midB, p2b, caB),
              clockwise: _clockwiseFor(p1b, midB, p2b))]
          : [LineSegment(p1b, p2b)],
    );
  }

  // Fallback for other segment types (e.g. ArcSegment): polyline approximation.
  final full = strokeExpandWithProfile(
    [segment],
    width: (t) {
      final s = 1 - t;
      return s * s * hw0 * 2 + 2 * s * t * (maxWidth * 2 - (hw0 + hw2)) + t * t * hw2 * 2;
    },
    roundCaps: false,
  );
  final half = full.length ~/ 2;
  final sideA = full.skip(half + 1).map((s) => s.reversed()).toList().reversed.toList();
  final sideB = full.skip(1).take(half - 1).toList();
  return (sideA, sideB);
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
/// through [p1], [mid], [p2] in order. In screen coords (y-down), cross > 0
/// means CW traversal → clockwise=false; cross < 0 → clockwise=true.
bool _clockwiseFor(P p1, P mid, P p2) {
  final cross = (p2.x - p1.x) * (mid.y - p1.y) - (p2.y - p1.y) * (mid.x - p1.x);
  return cross < 0;
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
