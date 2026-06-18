import 'dart:math' as math;

import '../primitive/primitive.dart';
import '../segment/segment.dart';

/// Maps t ∈ [0, 1] to stroke width at that point along the segment.
typedef WidthProfile = double Function(double t);

/// Expands [segment] into a closed filled path representing a variable-width stroke.
///
/// Returns a closed list of [LineSegment]s tracing the outline of the stroke.
/// The path is suitable for use with a filled [PathComponent].
///
/// [width] maps t → stroke width in the same units as the segment geometry.
/// [maxChordError] controls sampling density — smaller produces smoother curves.
/// [roundCaps] adds semicircular end caps; false gives flat (squared-off) caps.
List<Segment> strokeExpandWithProfile(
  Segment segment, {
  required WidthProfile width,
  double maxChordError = 0.5,
  bool roundCaps = true,
}) {
  final ts = _adaptiveSampleTs(segment, maxChordError);

  final sideA = <P>[]; // +unitNormalAt(cw=true): right of travel in y-down space
  final sideB = <P>[]; // -unitNormalAt(cw=true): left of travel in y-down space

  for (final t in ts) {
    final p = segment.lerp(t);
    final n = segment.unitNormalAt(t);
    final hw = width(t) / 2;
    sideA.add(p + n * hw);
    sideB.add(p - n * hw);
  }

  final path = <Segment>[];

  // Start cap: sideA.first → sideB.first, arcing behind p1
  if (roundCaps) {
    _addArcSegments(path, sideA.first, sideB.first, segment.lerp(0),
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
    _addArcSegments(path, sideB.last, sideA.last, segment.lerp(1),
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
    final tMid = (t0 + t1) / 2;
    final p0 = segment.lerp(t0);
    final p1 = segment.lerp(t1);
    final pMid = segment.lerp(tMid);
    final chordMid = P((p0.x + p1.x) / 2, (p0.y + p1.y) / 2);
    if (pMid.distanceTo(chordMid) > maxChordError) {
      ts.add(tMid);
      refine(t0, tMid, depth + 1);
      refine(tMid, t1, depth + 1);
    }
  }

  refine(0.0, 1.0, 0);
  ts.sort();
  return ts;
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
