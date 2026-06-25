import 'package:ramanujan/ramanujan.dart';

import 'planar_graph.dart';

/// A face produced by [splitAndClassify], labelled with which input shapes
/// contain it. Input to step 3 (filter) of the boolean operation pipeline.
class ClassifiedFace {
  final VectorPath path;
  final bool insideA;
  final bool insideB;

  const ClassifiedFace(this.path, {required this.insideA, required this.insideB});
}

/// Step 2 of the boolean operation pipeline.
///
/// Takes the simple closed faces produced by step 1 for each shape and:
/// 1. Finds every intersection between A's edges and B's edges.
/// 2. Splits all segments at those parameters.
/// 3. Builds the planar half-edge graph and traces all enclosed faces.
/// 4. Classifies each face as inside A, inside B, both, or neither by
///    applying each region's fill rule to its original loops.
///
/// [aFaces]/[bFaces] are the step-1 decomposed simple faces used to build
/// the planar subdivision. [a]/[b] are the original regions whose loops and
/// fill rules are used for the classification in step 4. These differ when a
/// loop is self-intersecting — the faces are the decomposed pieces, but the
/// fill-rule test must be applied against the original self-intersecting
/// boundary to preserve correct crossing counts.
///
/// Intra-path self-intersections must already be absent in [aFaces]/[bFaces]
/// — step 1 ([simplifyClosedPath]) guarantees this.
List<ClassifiedFace> splitAndClassify(
  List<VectorPath> aFaces,
  List<VectorPath> bFaces,
  Region a,
  Region b,
) {
  if (aFaces.isEmpty && bFaces.isEmpty) return [];

  final aSegs = aFaces.expand((p) => p.segments).toList();
  final bSegs = bFaces.expand((p) => p.segments).toList();

  // ── Find cross-intersections ──────────────────────────────────────────────
  // Only A vs B pairs — intra-A and intra-B crossings were removed in step 1.
  const eps = 1e-6;
  final aSplitPts = <int, List<(double, P)>>{};
  final bSplitPts = <int, List<(double, P)>>{};

  for (int i = 0; i < aSegs.length; i++) {
    for (int j = 0; j < bSegs.length; j++) {
      // ── Crossing intersections ──────────────────────────────────────────
      for (final p in aSegs[i].intersect(bSegs[j])) {
        final tA = aSegs[i].ilerp(p);
        final tB = bSegs[j].ilerp(p);
        if (tA.isNaN || tB.isNaN) continue;
        if (tA > eps && tA < 1 - eps) (aSplitPts[i] ??= []).add((tA, p));
        if (tB > eps && tB < 1 - eps) (bSplitPts[j] ??= []).add((tB, p));
      }
      // ── Coincident overlap: add boundary points as split points ────────
      final ov = aSegs[i].coincidentOverlap(bSegs[j]);
      if (ov != null) {
        void addA(double t) {
          if (t > eps && t < 1 - eps) {
            (aSplitPts[i] ??= []).add((t, aSegs[i].lerp(t)));
          }
        }
        void addB(double s) {
          if (s > eps && s < 1 - eps) {
            (bSplitPts[j] ??= []).add((s, bSegs[j].lerp(s)));
          }
        }
        addA(ov.tStart);
        addA(ov.tEnd);
        addB(ov.reversed ? ov.sEnd : ov.sStart);
        addB(ov.reversed ? ov.sStart : ov.sEnd);
      }
    }
  }

  // ── Split segments and build planar graph ─────────────────────────────────
  final aSubSegs = _applysplits(aSegs, aSplitPts);
  final bSubSegs = _applysplits(bSegs, bSplitPts);

  // Remove B sub-segments that are geometric duplicates of an A sub-segment
  // (coincident regions split into matching endpoints by the step above).
  final bDeduped = _removeCoincidentCopies(aSubSegs, bSubSegs);

  final allSplit = [...aSubSegs, ...bDeduped];

  final faces = buildFaces(allSplit);

  // ── Classify each face ────────────────────────────────────────────────────
  return faces.map((face) {
    final pt = _interiorPoint(face);
    return ClassifiedFace(
      face,
      insideA: a.contains(pt),
      insideB: b.contains(pt),
    );
  }).toList();
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Removes B sub-segments whose endpoints are geometrically identical to those
/// of an A sub-segment (same direction or reversed). After the coincident-overlap
/// split-point pass, shared regions produce matching endpoint pairs, so each
/// coincident sub-segment appears once in A and once in B; we keep only the A copy.
List<Segment> _removeCoincidentCopies(
    List<Segment> aSegs, List<Segment> bSegs) {
  const eps = 1e-4;
  return [
    for (final b in bSegs)
      if (!aSegs.any((a) =>
          (a.p1.isEqual(b.p1, eps) && a.p2.isEqual(b.p2, eps)) ||
          (a.p1.isEqual(b.p2, eps) && a.p2.isEqual(b.p1, eps))))
        b,
  ];
}

List<Segment> _applysplits(
    List<Segment> segs, Map<int, List<(double, P)>> splitPts) {
  final result = <Segment>[];
  for (int i = 0; i < segs.length; i++) {
    final pts = splitPts[i];
    if (pts == null) {
      result.add(segs[i]);
      continue;
    }
    pts.sort((a, b) => a.$1.compareTo(b.$1));
    for (int k = pts.length - 1; k > 0; k--) {
      if ((pts[k].$1 - pts[k - 1].$1).abs() < 1e-6) pts.removeAt(k);
    }
    result.addAll(splitAtParams(segs[i], pts));
  }
  return result;
}

/// Returns a point guaranteed to be in the interior of [face] (which is CCW).
/// Takes the midpoint of the first segment and nudges it along the left-hand
/// (inward) normal.
P _interiorPoint(VectorPath face) {
  final seg = face.segments.first;
  final mid = seg.lerp(0.5);
  final normal = seg.unitNormalAt(0.5, cw: false); // left-hand = CCW interior
  return mid + normal * 1e-4;
}

