part of 'corner.dart';

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
/// [CornerRadius.clampedToEdgeLength]).
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
    return a.cross(b).abs() < 1e-9 && a.dot(b) > 0;
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
  final stretches = <VectorPath>[];
  if (closed) {
    for (int k = 0; k < b; k++) {
      final run = <Segment>[];
      for (int j = (barriers[(k - 1 + b) % b] + 1) % n; ; j = (j + 1) % n) {
        run.add(segments[j]);
        if (j == barriers[k]) break;
      }
      stretches.add(VectorPath(run));
    }
  } else {
    for (int k = 0; k < b; k++) {
      final from = k == 0 ? 0 : barriers[k - 1] + 1;
      stretches.add(
        VectorPath([for (int j = from; j <= barriers[k]; j++) segments[j]]),
      );
    }
    stretches.add(
      VectorPath([for (int j = barriers[b - 1] + 1; j < n; j++) segments[j]]),
    );
  }
  final stretchLengths = [for (final s in stretches) s.length];

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
      CornerRadius(radiusIn[t] * factor, radiusOut[t] * factor),
      segments[corners[t]].p2,
    );
    stretches[stretchIntoCorner(t)] = kept1;
    stretches[stretchOutOfCorner(t)] = kept2;
    fillets[t] = fillet;
  }

  // Splice: each stretch followed by the fillet at the barrier it ends on.
  final result = <Segment>[];
  for (int k = 0; k < stretches.length; k++) {
    result.addAll(
      stretches[k].segments.where((s) => s.length > _degenerateLength),
    );
    if (k < b) {
      final t = cornerIndexAt[barriers[k]];
      if (t != null) result.add(fillets[t]!);
    }
  }

  if (!closed) return VectorPath(result);
  // Joins are bitwise exact by construction (see Trim), but dropping a
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
