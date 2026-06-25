import 'package:ramanujan/ramanujan.dart';

import 'cross_split.dart';

/// Step 4 of the boolean path pipeline.
///
/// Any edge shared between two adjacent kept faces is interior to the result
/// and is discarded. The surviving boundary edges are chained into closed
/// output rings.
///
/// [faces] is the output of step 3 ([BooleanOpFilter]).
List<Loop> mergeFaces(List<ClassifiedFace> faces) {
  if (faces.isEmpty) return [];

  final allSegs = faces.expand((f) => f.path.segments).toList();

  // An edge is interior iff its reverse (p1↔p2 swapped) also appears in the
  // kept set. buildFaces snaps all segment endpoints to canonical node
  // coordinates, so the comparison converges well within the default epsilon.
  final boundary = <Segment>[];
  for (final seg in allSegs) {
    final interior = allSegs.any(
        (s) => s.p1.isEqual(seg.p2) && s.p2.isEqual(seg.p1));
    if (!interior) boundary.add(seg);
  }

  return _chain(boundary);
}

// Chains a flat list of boundary segments into closed rings by following
// the p2 → p1 link between consecutive segments.
List<Loop> _chain(List<Segment> segs) {
  final remaining = segs.toList();
  final rings = <Loop>[];

  while (remaining.isNotEmpty) {
    final ring = <Segment>[remaining.removeAt(0)];

    while (true) {
      final tip = ring.last.p2;
      final i = remaining.indexWhere((s) => s.p1.isEqual(tip));
      if (i < 0) break;
      ring.add(remaining.removeAt(i));
    }

    if (ring.length >= 2 && ring.last.p2 == ring.first.p1) {
      rings.add(Loop(ring));
    }
  }

  return rings;
}
