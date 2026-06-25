// Shared planar half-edge graph utilities for boolean path operations.
// Not part of the public ramanujan API — not re-exported from ramanujan.dart.

import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

// ─── Endpoint snapping ────────────────────────────────────────────────────────

Segment segmentWithP2(Segment s, P p) => switch (s) {
      LineSegment l => LineSegment(l.p1, p),
      CubicSegment c => CubicSegment(p1: c.p1, c1: c.c1, c2: c.c2, p2: p),
      QuadraticSegment q => QuadraticSegment(p1: q.p1, c: q.c, p2: p),
      CircularArcSegment a => CircularArcSegment(a.p1, p, a.radius,
          largeArc: a.largeArc, clockwise: a.clockwise),
      ArcSegment a => ArcSegment(a.p1, p, a.radii,
          largeArc: a.largeArc, clockwise: a.clockwise, rotation: a.rotation),
      _ => s,
    };

Segment segmentWithP1(Segment s, P p) => switch (s) {
      LineSegment l => LineSegment(p, l.p2),
      CubicSegment c => CubicSegment(p1: p, c1: c.c1, c2: c.c2, p2: c.p2),
      QuadraticSegment q => QuadraticSegment(p1: p, c: q.c, p2: q.p2),
      CircularArcSegment a => CircularArcSegment(p, a.p2, a.radius,
          largeArc: a.largeArc, clockwise: a.clockwise),
      ArcSegment a => ArcSegment(p, a.p2, a.radii,
          largeArc: a.largeArc, clockwise: a.clockwise, rotation: a.rotation),
      _ => s,
    };

// ─── Segment splitting ────────────────────────────────────────────────────────

/// Splits [seg] at the given (t, snapPoint) pairs (must be sorted by t,
/// de-duplicated before calling). Returns the sub-segments in order.
List<Segment> splitAtParams(Segment seg, List<(double, P)> ts) {
  final out = <Segment>[];
  Segment rem = seg;
  double tOffset = 0;
  for (final (t, snap) in ts) {
    final localT = ((t - tOffset) / (1 - tOffset)).clamp(0.0, 1.0);
    final (left, right) = rem.bifurcateAtInterval(localT);
    out.add(segmentWithP2(left, snap));
    rem = segmentWithP1(right, snap);
    tOffset = t;
  }
  out.add(rem);
  return out;
}

// ─── Shoelace area ────────────────────────────────────────────────────────────

double shoelaceArea(List<Segment> segs) {
  var area = 0.0;
  for (final s in segs) {
    area += s.p1.x * s.p2.y - s.p2.x * s.p1.y;
  }
  return area / 2;
}

// ─── Half-edge graph ──────────────────────────────────────────────────────────

class PlanarNode {
  final P pos;
  final List<HalfEdge> outgoing = [];
  PlanarNode(this.pos);
}

class HalfEdge {
  final Segment seg;
  final PlanarNode from, to;
  bool visited = false;
  HalfEdge? next;
  HalfEdge(this.seg, this.from, this.to);
}

/// Builds a planar half-edge graph from [splitSegs] and traces all CCW
/// (positive-area) face cycles. Returns each face as a simple closed
/// [VectorPath].
List<VectorPath> buildFaces(List<Segment> splitSegs) {
  final nodes = <PlanarNode>[];
  final halfEdges = <HalfEdge>[];

  PlanarNode nodeFor(P p) {
    for (final n in nodes) {
      if (n.pos.isEqual(p, 1e-4)) return n;
    }
    final n = PlanarNode(p);
    nodes.add(n);
    return n;
  }

  for (final s in splitSegs) {
    final a = nodeFor(s.p1), b = nodeFor(s.p2);
    if (a == b) continue; // degenerate zero-length segment
    final fwd = HalfEdge(s, a, b);
    final rev = HalfEdge(s.reversed(), b, a);
    a.outgoing.add(fwd);
    b.outgoing.add(rev);
    halfEdges.add(fwd);
    halfEdges.add(rev);
  }

  // Sort outgoing half-edges at each node by tangent angle (CCW order).
  // For CCW arcs lerp(0)==p1 (near the from-node); for CW reversed arcs
  // lerp(0)==p2 and lerp(1)==p1.  Pick the lerp endpoint closer to from.pos
  // and sample eps inward from there so we always get the near-start tangent.
  for (final node in nodes) {
    node.outgoing.sort((a, b) {
      P nearStart(HalfEdge he) {
        const eps = 1e-4;
        final p0 = he.seg.lerp(0);
        final p1 = he.seg.lerp(1);
        final fx = he.from.pos.x, fy = he.from.pos.y;
        final d0 = (p0.x - fx) * (p0.x - fx) + (p0.y - fy) * (p0.y - fy);
        final d1 = (p1.x - fx) * (p1.x - fx) + (p1.y - fy) * (p1.y - fy);
        return d1 < d0 ? he.seg.lerp(1 - eps) : he.seg.lerp(eps);
      }

      final pa = nearStart(a);
      final pb = nearStart(b);
      final aa = atan2(pa.y - node.pos.y, pa.x - node.pos.x);
      final ab = atan2(pb.y - node.pos.y, pb.x - node.pos.x);
      return aa.compareTo(ab);
    });
  }

  // Wire next pointers.
  // next(h = u→v) = the outgoing edge at v at index (mateIdx − 1) in the
  // CCW-sorted list, where mateIdx is the position of the mate (v→u).
  // Walking next traces the face to the LEFT of each directed edge,
  // which is CCW (positive area) in a y-up coordinate space.
  for (final he in halfEdges) {
    final out = he.to.outgoing;
    final mateIdx = out.indexWhere((e) => e.to == he.from);
    if (mateIdx < 0) continue;
    he.next = out[(mateIdx - 1 + out.length) % out.length];
  }

  // Trace all face cycles.
  final result = <VectorPath>[];
  for (final start in halfEdges) {
    if (start.visited) continue;
    final faceSegs = <Segment>[];
    var cur = start;
    while (!cur.visited) {
      cur.visited = true;
      // Snap to canonical node positions so consecutive segments share the
      // exact same P object, satisfying VectorPath's continuity invariant.
      faceSegs.add(segmentWithP1(segmentWithP2(cur.seg, cur.to.pos), cur.from.pos));
      if (cur.next == null) break;
      cur = cur.next!;
    }
    // Positive shoelace area = CCW = enclosed interior face.
    // The exterior face traces CW (negative area) and is discarded.
    if (shoelaceArea(faceSegs) > 1e-6) {
      result.add(VectorPath(faceSegs));
    }
  }
  return result;
}
