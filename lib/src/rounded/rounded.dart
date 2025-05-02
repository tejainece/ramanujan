import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

List<Segment> roundCornerUsingCircularArc(
    LineSegment line1, LineSegment line2, double radius1, double radius2) {
  assert(line1.p2.isEqual(line2.p1));
  double radius = (radius1 + radius2) / 2;

  final p1 = line1.pointAtDistanceFromP2(radius);
  final p2 = line2.pointAtDistanceFromP1(radius);

  final tangent1 = line1.normalAt(p1);
  final tangent2 = line2.normalAt(p2);
  final center = tangent1.intersectInfiniteLine(tangent2);
  final circleRadius = center.distanceTo(p1);

  print('angles ${line1.angle.toDegree} ${line2.angle.toDegree} ${(line1.angle - line2.angle).toDegree}');
  final angle = line1.angle - line2.angle;

  final ret = <Segment>[
    LineSegment(line1.p1, p1),
    CircularArcSegment(
      p1,
      p2,
      circleRadius,
      clockwise: angle.value < pi,
      largeArc: false,
    ),
    LineSegment(p2, line2.p2),
  ];

  return ret;
}

// TODO implement controlling control point
List<Segment> roundCornerUsingQuadraticBezier(
    LineSegment line1, LineSegment line2, double radius1, double radius2) {
  assert(line1.p2.isEqual(line2.p1));

  final c1 = line1.pointAtDistanceFromP2(radius1);
  final c3 = line2.pointAtDistanceFromP1(radius2);
  final c2 = line1.p2;

  final ret = <Segment>[
    LineSegment(line1.p1, c1),
    QuadraticSegment(p1: c1, p2: c3, c: c2),
    LineSegment(c3, line2.p2),
  ];

  return ret;
}

// TODO implement controlling control point
List<Segment> roundCornerUsingCubicBezier(
    LineSegment line1, LineSegment line2, double radius1, double radius2) {
  assert(line1.p2.isEqual(line2.p1));

  final c1 = line1.pointAtDistanceFromP2(radius1);
  final c4 = line2.pointAtDistanceFromP1(radius2);
  final c2 = line1.p2;
  final c3 = line1.p2;

  final ret = <Segment>[
    LineSegment(line1.p1, c1),
    CubicSegment(p1: c1, p2: c4, c1: c2, c2: c3),
    LineSegment(c3, line2.p2),
  ];

  return ret;
}
