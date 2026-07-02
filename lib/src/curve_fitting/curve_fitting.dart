import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

/// Fits an ordered sequence of 2D [points] to a [VectorPath] composed of the
/// simplest segment types (line → circular arc → quadratic Bézier → cubic
/// Bézier) that keep every input point within [tolerance] of the fitted curve.
///
/// - [tolerance]: max allowed distance (same units as the points) from any
///   input point to the fitted curve.
/// - [closed]: if true, a closing segment is appended and a [Loop] is returned.
/// - [cornerThreshold]: turning angle (radians) that forces a segment boundary
///   in the pre-pass. Smaller values split more aggressively at gentle bends.
VectorPath fitPath(
  List<P> points, {
  double tolerance = 1.0,
  bool closed = false,
  double cornerThreshold = pi / 4,
}) {
  if (points.length < 2) return VectorPath([]);

  // Append the start point to close the sequence if needed.
  final pts = (closed && !points.first.isEqual(points.last))
      ? [...points, points.first]
      : points;

  // Phase 0: detect corners and use them as forced segment boundaries.
  final corners = _findCorners(pts, cornerThreshold);

  // Phase 1: fit each run between consecutive corners.
  final segments = <Segment>[];
  for (int i = 0; i < corners.length - 1; i++) {
    segments.addAll(_fitSegments(pts, corners[i], corners[i + 1], tolerance));
  }

  if (segments.isEmpty) return VectorPath([]);
  return closed ? Loop(segments) : VectorPath(segments);
}

// ---------------------------------------------------------------------------
// Phase 0 — corner pre-pass
// ---------------------------------------------------------------------------

List<int> _findCorners(List<P> points, double threshold) {
  final result = [0];
  for (int i = 1; i < points.length - 1; i++) {
    final v1 = points[i] - points[i - 1];
    final v2 = points[i + 1] - points[i];
    final l1 = v1.length, l2 = v2.length;
    if (l1 < 1e-10 || l2 < 1e-10) continue;
    final cosA = ((v1.x * v2.x + v1.y * v2.y) / (l1 * l2)).clamp(-1.0, 1.0);
    if (acos(cosA) > threshold) result.add(i);
  }
  result.add(points.length - 1);
  return result;
}

// ---------------------------------------------------------------------------
// Phase 1 — recursive fitting
// ---------------------------------------------------------------------------

List<Segment> _fitSegments(List<P> points, int lo, int hi, double tolerance) {
  if (hi <= lo) return [];
  // Two points can only be a line.
  if (hi - lo == 1) return [LineSegment(points[lo], points[hi])];

  final segment = _tryLine(points, lo, hi, tolerance) ??
      _tryArc(points, lo, hi, tolerance) ??
      _tryQuadratic(points, lo, hi, tolerance) ??
      _tryCubic(points, lo, hi, tolerance);

  if (segment != null) return [segment];

  // Nothing fits the whole sub-sequence. Find the point of maximum error
  // under a cubic fit — that is the natural boundary between segments.
  final ts = _chordParams(points, lo, hi);
  final cubic = _fitCubicLS(points, lo, hi, ts);

  var maxErr = 0.0;
  var mid = (lo + hi) ~/ 2;
  for (int i = lo + 1; i < hi; i++) {
    final err = (points[i] - _evalCubic(cubic, ts[i - lo])).length;
    if (err > maxErr) {
      maxErr = err;
      mid = i;
    }
  }

  return [
    ..._fitSegments(points, lo, mid, tolerance),
    ..._fitSegments(points, mid, hi, tolerance),
  ];
}

// ---------------------------------------------------------------------------
// Segment type cascade
// ---------------------------------------------------------------------------

Segment? _tryLine(List<P> points, int lo, int hi, double tolerance) {
  final p0 = points[lo], p1 = points[hi];
  final d = p1 - p0;
  final len = d.length;
  if (len < 1e-10) return LineSegment(p0, p1);
  for (int i = lo + 1; i < hi; i++) {
    final v = points[i] - p0;
    // Perpendicular distance = |cross(v, d)| / |d|.
    if ((v.x * d.y - v.y * d.x).abs() / len > tolerance) return null;
  }
  return LineSegment(p0, p1);
}

Segment? _tryArc(List<P> points, int lo, int hi, double tolerance) {
  final circle = Circle.fit(points.getRange(lo, hi + 1));
  if (circle == null || circle.radius > 1e5) return null;
  for (int i = lo; i <= hi; i++) {
    if (((points[i] - circle.center).length - circle.radius).abs() > tolerance) {
      return null;
    }
  }
  final midPt = points[(lo + hi) ~/ 2];
  return circle.arcThrough(points[lo], midPt, points[hi]);
}

Segment? _tryQuadratic(List<P> points, int lo, int hi, double tolerance) {
  final p0 = points[lo], p3 = points[hi];
  final ts = _chordParams(points, lo, hi);

  // Closed-form least-squares: C = Σ b_i·q_i / Σ b_i²
  // where b_i = 2·t·(1−t) and q_i = p_i − (1−t)²·P0 − t²·P3.
  var numX = 0.0, numY = 0.0, den = 0.0;
  for (int i = 1; i < ts.length - 1; i++) {
    final t = ts[i], s = 1 - t;
    final b = 2 * t * s;
    numX += b * (points[lo + i].x - s * s * p0.x - t * t * p3.x);
    numY += b * (points[lo + i].y - s * s * p0.y - t * t * p3.y);
    den += b * b;
  }
  if (den < 1e-10) return null;

  final c = P(numX / den, numY / den);
  for (int i = 1; i < ts.length - 1; i++) {
    final t = ts[i], s = 1 - t;
    final fitted = p0 * (s * s) + c * (2 * s * t) + p3 * (t * t);
    if ((points[lo + i] - fitted).length > tolerance) return null;
  }
  return QuadraticSegment(p1: p0, p2: p3, c: c);
}

Segment? _tryCubic(List<P> points, int lo, int hi, double tolerance) {
  var ts = _chordParams(points, lo, hi);
  var cubic = _fitCubicLS(points, lo, hi, ts);
  // One Newton-Raphson reparameterization pass improves accuracy on
  // non-uniformly spaced points.
  ts = _reparamTs(points, lo, ts, cubic);
  cubic = _fitCubicLS(points, lo, hi, ts);

  for (int i = 1; i < ts.length - 1; i++) {
    if ((points[lo + i] - _evalCubic(cubic, ts[i])).length > tolerance) {
      return null;
    }
  }
  return CubicSegment(p1: cubic.p0, p2: cubic.p3, c1: cubic.c1, c2: cubic.c2);
}

// ---------------------------------------------------------------------------
// Chord-length parameterization
// ---------------------------------------------------------------------------

List<double> _chordParams(List<P> points, int lo, int hi) {
  final n = hi - lo + 1;
  final ts = List<double>.filled(n, 0.0);
  for (int i = 1; i < n; i++) {
    ts[i] = ts[i - 1] + points[lo + i].distanceTo(points[lo + i - 1]);
  }
  final total = ts[n - 1];
  if (total < 1e-10) return ts;
  for (int i = 1; i < n; i++) {
    ts[i] /= total;
  }
  return ts;
}

// ---------------------------------------------------------------------------
// Cubic Bézier least-squares fit and helpers
// ---------------------------------------------------------------------------

typedef _Cubic = ({P p0, P c1, P c2, P p3});

/// Least-squares fit of a cubic Bézier to [points[lo..hi]] parameterized by [ts].
/// Solves a 2×2 normal-equations system per axis. Falls back to placing
/// control points at 1/3 and 2/3 of the chord when the system is degenerate.
_Cubic _fitCubicLS(List<P> points, int lo, int hi, List<double> ts) {
  final p0 = points[lo], p3 = points[hi];
  var a11 = 0.0, a12 = 0.0, a22 = 0.0;
  var bx1 = 0.0, bx2 = 0.0, by1 = 0.0, by2 = 0.0;

  for (int i = 1; i < ts.length - 1; i++) {
    final t = ts[i], s = 1 - t;
    final b1 = 3 * t * s * s; // basis for c1
    final b2 = 3 * t * t * s; // basis for c2
    final qx = points[lo + i].x - s * s * s * p0.x - t * t * t * p3.x;
    final qy = points[lo + i].y - s * s * s * p0.y - t * t * t * p3.y;
    a11 += b1 * b1;
    a12 += b1 * b2;
    a22 += b2 * b2;
    bx1 += b1 * qx;
    bx2 += b2 * qx;
    by1 += b1 * qy;
    by2 += b2 * qy;
  }

  final det = a11 * a22 - a12 * a12;
  if (det.abs() < 1e-10) {
    // Degenerate (e.g. only two interior points with symmetric ts): fall back
    // to evenly-spaced control points along the chord.
    return (
      p0: p0,
      c1: p0 + (p3 - p0) / 3,
      c2: p0 + (p3 - p0) * (2 / 3),
      p3: p3,
    );
  }

  return (
    p0: p0,
    c1: P((bx1 * a22 - bx2 * a12) / det, (by1 * a22 - by2 * a12) / det),
    c2: P((bx2 * a11 - bx1 * a12) / det, (by2 * a11 - by1 * a12) / det),
    p3: p3,
  );
}

/// One Newton-Raphson step: for each interior point project onto the current
/// cubic to get a better parameter, then re-solve.
List<double> _reparamTs(
    List<P> points, int lo, List<double> ts, _Cubic cubic) {
  final newTs = List<double>.from(ts);
  for (int i = 1; i < ts.length - 1; i++) {
    final t = ts[i];
    final diff = _evalCubic(cubic, t) - points[lo + i];
    final db = _evalCubicDeriv(cubic, t);
    final denom = db.x * db.x + db.y * db.y;
    if (denom < 1e-10) continue;
    newTs[i] = (t - (diff.x * db.x + diff.y * db.y) / denom).clamp(0.0, 1.0);
  }
  return newTs;
}

P _evalCubic(_Cubic c, double t) {
  final s = 1 - t;
  return c.p0 * (s * s * s) +
      c.c1 * (3 * s * s * t) +
      c.c2 * (3 * s * t * t) +
      c.p3 * (t * t * t);
}

P _evalCubicDeriv(_Cubic c, double t) {
  final s = 1 - t;
  return (c.c1 - c.p0) * (3 * s * s) +
      (c.c2 - c.c1) * (6 * s * t) +
      (c.p3 - c.c2) * (3 * t * t);
}

