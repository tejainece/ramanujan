import 'package:ramanujan/ramanujan.dart';

import 'planar_graph.dart';

/// Splits a self-intersecting closed path into its minimal enclosed faces.
///
/// Returns all faces as simple closed [VectorPath]s oriented counter-clockwise.
/// If the input has no self-intersections, returns a single-element list
/// containing the input unchanged.
List<VectorPath> divideSelfIntersecting(VectorPath path) {
  final segs = path.segments.toList();
  if (segs.isEmpty) return [path];
  final splits = _findSplits(segs);
  if (splits.isEmpty) return [path];
  final split = _splitSegments(segs, splits);
  return buildFaces(split);
}

// ─── Split detection ───────────────────────────────────────────────────────
//
// For each non-adjacent segment pair we check for intersections.
// We only need to split a segment when the intersection falls at an interior
// parameter (t strictly in (0,1)). If the intersection coincides with a
// segment endpoint (t ≈ 0 or 1) that endpoint is already a graph node, so
// no split is needed there — but the OTHER segment may still need splitting.
//
// The same interior split-point can be discovered twice (once from pair (i,j)
// and again from pair (j,k) that shares the same path vertex). Duplicates are
// removed in _splitSegments.

List<(int segIdx, double t, P point)> _findSplits(List<Segment> segs) {
  const eps = 1e-6;
  final n = segs.length;
  final result = <(int, double, P)>[];
  for (int i = 0; i < n; i++) {
    for (int j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue; // adjacent via closure
      for (final p in segs[i].intersect(segs[j])) {
        final tI = segs[i].ilerp(p);
        final tJ = segs[j].ilerp(p);
        if (tI.isNaN || tJ.isNaN) continue;
        final iInterior = tI > eps && tI < 1 - eps;
        final jInterior = tJ > eps && tJ < 1 - eps;
        if (!iInterior && !jInterior) continue; // both at endpoints — skip
        if (iInterior) result.add((i, tI, p));
        if (jInterior) result.add((j, tJ, p));
      }
    }
  }
  return result;
}

// ─── Segment splitting ─────────────────────────────────────────────────────

List<Segment> _splitSegments(
  List<Segment> segs,
  List<(int, double, P)> splits,
) {
  final bySegment = <int, List<(double, P)>>{};
  for (final (idx, t, p) in splits) {
    (bySegment[idx] ??= []).add((t, p));
  }
  for (final ts in bySegment.values) {
    ts.sort((a, b) => a.$1.compareTo(b.$1));
    // Remove duplicate split-points (same interior t found via different pairs).
    for (int i = ts.length - 1; i > 0; i--) {
      if ((ts[i].$1 - ts[i - 1].$1).abs() < 1e-6) ts.removeAt(i);
    }
  }
  final result = <Segment>[];
  for (int i = 0; i < segs.length; i++) {
    final ts = bySegment[i];
    result.addAll(ts == null ? [segs[i]] : splitAtParams(segs[i], ts));
  }
  return result;
}
