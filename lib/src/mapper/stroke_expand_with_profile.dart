import 'dart:math' as math;

import '../primitive/primitive.dart';
import '../segment/segment.dart';

/// Maps t ∈ [0, 1] to stroke width at that point along the path.
typedef WidthProfile = double Function(double t);

/// Expands [segments] into a closed filled path representing a variable-width stroke.
///
/// [segments] is treated as a single connected path. The [width] profile receives
/// a global t ∈ [0, 1] mapped proportionally across all segments by arc length,
/// so the profile is continuous regardless of how many segments are provided.
///
/// Returns a closed list of [LineSegment]s tracing the outline of the stroke.
/// [maxChordError] controls sampling density — smaller produces smoother curves.
/// [roundCaps] adds semicircular end caps; false gives flat (squared-off) caps.
List<Segment> strokeExpandWithProfile(
  List<Segment> segments, {
  required WidthProfile width,
  double maxChordError = 0.5,
  bool roundCaps = true,
}) {
  assert(segments.isNotEmpty);

  final lengths = [for (final s in segments) s.length];
  final totalLength = lengths.fold(0.0, (sum, l) => sum + l);

  final sideA = <P>[];
  final sideB = <P>[];

  var cumLength = 0.0;
  for (int i = 0; i < segments.length; i++) {
    final seg = segments[i];
    final tOffset = cumLength / totalLength;
    final tScale = lengths[i] / totalLength;

    final localTs = _adaptiveSampleTs(seg, maxChordError);
    for (final lt in localTs) {
      if (i > 0 && lt == 0.0) continue; // skip duplicate joint point
      final globalT = tOffset + lt * tScale;
      final p = seg.lerp(lt);
      final n = seg.unitNormalAt(lt);
      final hw = width(globalT) / 2;
      sideA.add(p + n * hw);
      sideB.add(p - n * hw);
    }
    cumLength += lengths[i];
  }

  final path = <Segment>[];

  // Start cap: sideA.first → sideB.first, arcing behind p1
  if (roundCaps) {
    _addArcSegments(path, sideA.first, sideB.first, segments.first.lerp(0),
        width(0) / 2, maxChordError);
  } else {
    path.add(LineSegment(sideA.first, sideB.first));
  }

  // Side B forward: left of travel, p1 → p2
  for (int i = 0; i < sideB.length - 1; i++) {
    path.add(LineSegment(sideB[i], sideB[i + 1]));
  }

  // End cap: sideB.last → sideA.last, arcing around p2
  if (roundCaps) {
    _addArcSegments(path, sideB.last, sideA.last, segments.last.lerp(1),
        width(1) / 2, maxChordError);
  } else {
    path.add(LineSegment(sideB.last, sideA.last));
  }

  // Side A backward: right of travel, p2 → p1
  for (int i = sideA.length - 1; i > 0; i--) {
    path.add(LineSegment(sideA[i], sideA[i - 1]));
  }

  return path;
}

/// Adaptively samples [segment] in t, subdividing wherever the chord error
/// exceeds [maxChordError]. Returns a sorted list of t values (includes 0 and 1).
List<double> _adaptiveSampleTs(Segment segment, double maxChordError) {
  final ts = <double>[0.0, 1.0];

  void refine(double t0, double t1, int depth) {
    if (depth >= 8) return;
    final p0 = segment.lerp(t0);
    final p1 = segment.lerp(t1);
    // Measure deviation from the chord at several interior samples, not just the
    // midpoint: an inflecting sub-curve (an S-shape) can place its midpoint
    // exactly on the chord while bulging far off it on either side, which a
    // single-point test reads as flat and never subdivides.
    var maxDev = 0.0;
    for (final f in const [0.25, 0.5, 0.75]) {
      final dev = _distanceToChord(segment.lerp(t0 + (t1 - t0) * f), p0, p1);
      if (dev > maxDev) maxDev = dev;
    }
    if (maxDev > maxChordError) {
      final tMid = (t0 + t1) / 2;
      ts.add(tMid);
      refine(t0, tMid, depth + 1);
      refine(tMid, t1, depth + 1);
    }
  }

  refine(0.0, 1.0, 0);
  ts.sort();
  return ts;
}

/// Perpendicular distance from [p] to the chord segment [a]→[b].
double _distanceToChord(P p, P a, P b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  if (len2 < 1e-12) return p.distanceTo(a);
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  final cx = a.x + t * dx, cy = a.y + t * dy;
  return math.sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy));
}

/// Appends line segments tracing a clockwise semicircle from [from] to [to],
/// both lying on a circle of [radius] centered at [center].
void _addArcSegments(
  List<Segment> out,
  P from,
  P to,
  P center,
  double radius,
  double maxChordError,
) {
  if (radius <= 0) {
    out.add(LineSegment(from, to));
    return;
  }
  final steps = _capSteps(radius, maxChordError);
  P prev = from;
  final a0 = math.atan2(from.y - center.y, from.x - center.x);
  for (int i = 1; i <= steps; i++) {
    final a = a0 - math.pi * i / steps;
    final next = i == steps
        ? to
        : P(center.x + math.cos(a) * radius, center.y + math.sin(a) * radius);
    out.add(LineSegment(prev, next));
    prev = next;
  }
}

/// Number of steps for a semicircular cap so chord error stays within [maxChordError].
int _capSteps(double radius, double maxChordError) {
  final ratio = (maxChordError / radius).clamp(0.0, 2.0);
  final halfAngle = math.acos(1 - ratio);
  return (math.pi / halfAngle).ceil().clamp(2, 64);
}
