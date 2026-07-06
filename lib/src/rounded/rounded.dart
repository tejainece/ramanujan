import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

/// Rounds the corner shared by [line1] and [line2] with a true circular arc,
/// tangent to both lines.
///
/// A single circle tangent to two lines necessarily has equal tangent length
/// on both sides (the tangent-length theorem: from the shared vertex, any two
/// tangent segments to the same circle are equal), so a real circle only has
/// one true radius per corner -- [radius1] and [radius2] are averaged rather
/// than honoured independently. Use [roundCornerUsingEllipticArc] when the two
/// sides genuinely need different radii.
List<Segment> roundCornerUsingCircularArc(
  LineSegment line1,
  LineSegment line2,
  double radius1,
  double radius2,
) {
  assert(line1.p2.isEqual(line2.p1));
  double radius = (radius1 + radius2) / 2;

  final p1 = line1.pointAtDistanceFromP2(radius);
  final p2 = line2.pointAtDistanceFromP1(radius);

  final tangent1 = line1.normalAt(p1);
  final tangent2 = line2.normalAt(p2);
  final center = tangent1.intersectInfiniteLine(tangent2);
  final circleRadius = center.distanceTo(p1);

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

/// Builds the [ArcSegment] between [a] and [b] with the given [radii]/[rotation],
/// picking whichever of the two possible short-arc sweep directions has its
/// reconstructed (SVG-endpoint-form) center closest to [target] -- the center
/// we derived directly from the tangency construction. This sidesteps hand
/// -verifying [ArcSegment]'s sweep-flag sign convention (it also avoids
/// [Ellipse.arc]'s own large-arc detection, which goes through
/// [Ellipse.arcLengthBetweenAngles] and throws for angles that land exactly on
/// a quadrant boundary -- a common case here since cut points often sit on an
/// axis).
ArcSegment _arcTowardCenter(P a, P b, P radii, double rotation, P target) {
  final cw = ArcSegment(
    a,
    b,
    radii,
    rotation: rotation,
    largeArc: false,
    clockwise: true,
  );
  final ccw = ArcSegment(
    a,
    b,
    radii,
    rotation: rotation,
    largeArc: false,
    clockwise: false,
  );
  return cw.center.distanceTo(target) <= ccw.center.distanceTo(target)
      ? cw
      : ccw;
}

/// Rounds the corner with the unique ellipse tangent to [line1] at distance
/// [radius1] from the shared vertex and tangent to [line2] at distance
/// [radius2] -- the asymmetric-radius counterpart to
/// [roundCornerUsingCircularArc]. A true circle can't be tangent to both lines
/// at two independently-chosen cut distances (see [roundCornerUsingCircularArc]
/// for why), so when the radii genuinely differ, this is what a single,
/// exactly-tangent, smooth fillet curve looks like instead.
///
/// The construction works in the oblique coordinate frame whose axes run along
/// [line1] and [line2]: in that frame the corner becomes a right angle, and the
/// ellipse centered at (radius1, radius2) with semi-axes (radius1, radius2) is
/// tangent to both axes exactly at the two cut points by construction. Mapping
/// that back to world space gives a general affine image of a circle -- an
/// ellipse whose canonical (center, radii, rotation) is recovered from the
/// eigen-decomposition of the resulting shape matrix.
List<Segment> roundCornerUsingEllipticArc(
  LineSegment line1,
  LineSegment line2,
  double radius1,
  double radius2,
) {
  assert(line1.p2.isEqual(line2.p1));

  final vertex = line1.p2;
  final a = line1.pointAtDistanceFromP2(radius1);
  final b = line2.pointAtDistanceFromP1(radius2);

  final d1 = (a - vertex).normalized;
  final d2 = (b - vertex).normalized;

  final center = vertex + d1 * radius1 + d2 * radius2;
  final c1 = d1 * radius1;
  final c2 = d2 * radius2;

  final sxx = c1.x * c1.x + c2.x * c2.x;
  final syy = c1.y * c1.y + c2.y * c2.y;
  final sxy = c1.x * c1.y + c2.x * c2.y;

  final mid = (sxx + syy) / 2;
  final spread = sqrt(
    max(0.0, ((sxx - syy) / 2) * ((sxx - syy) / 2) + sxy * sxy),
  );
  final rx = sqrt(max(0.0, mid + spread));
  final ry = sqrt(max(0.0, mid - spread));

  double rotation;
  if (sxy.abs() < 1e-12 && (sxx - syy).abs() < 1e-12) {
    rotation = 0;
  } else if (sxy.abs() < 1e-12) {
    rotation = sxx >= syy ? 0 : pi / 2;
  } else {
    rotation = P(sxy, (mid + spread) - sxx).angle.value;
  }

  final radii = P(rx, ry);
  final arc = _arcTowardCenter(a, b, radii, rotation, center);

  return [LineSegment(line1.p1, a), arc, LineSegment(b, line2.p2)];
}

/// Concave "inverted round" corner (Illustrator's Inverted Round, Inkscape's
/// Inverse Fillet) -- the picture-frame-mat / movie-ticket-notch look: cuts
/// [line1] and [line2] back to the same points a normal round would (their
/// [radius1]/[radius2], averaged into one [radius] for the same
/// tangent-length reason as [roundCornerUsingCircularArc] -- a literal circle
/// centered at the vertex necessarily crosses both lines at the same distance
/// from it, since they pass straight through its center), then bridges those
/// two points with the arc of that literal circle **centered at the original
/// vertex** rather than tangent to the lines.
///
/// Because the lines pass through the circle's center, they meet the arc at a
/// right angle instead of blending into it smoothly -- this is a real corner,
/// not a tangent fillet, which is exactly how the reference construction
/// (draw a circle centered on the corner, then Pathfinder/Boolean-subtract
/// it) behaves. The corner never extends past its original vertex; the arc
/// only ever bites material away from inside the original angle.
List<Segment> roundCornerUsingInvertedArc(
  LineSegment line1,
  LineSegment line2,
  double radius1,
  double radius2,
) {
  assert(line1.p2.isEqual(line2.p1));
  final radius = (radius1 + radius2) / 2;

  final a = line1.pointAtDistanceFromP2(radius);
  final b = line2.pointAtDistanceFromP1(radius);

  final angle = line1.angle - line2.angle;

  return [
    LineSegment(line1.p1, a),
    CircularArcSegment(
      a,
      b,
      radius,
      clockwise: angle.value >= pi,
      largeArc: false,
    ),
    LineSegment(b, line2.p2),
  ];
}

/// Rounds the corner with a straight bevel (chamfer): cuts [line1] back by
/// [radius1] and [line2] back by [radius2], independently, and connects the two
/// cut points with a single straight line. Unlike the arc-based styles, a
/// straight line has no tangency constraint linking the two sides, so the two
/// radii are always honoured exactly, however different they are.
List<Segment> roundCornerUsingChamfer(
  LineSegment line1,
  LineSegment line2,
  double radius1,
  double radius2,
) {
  assert(line1.p2.isEqual(line2.p1));
  final p1 = line1.pointAtDistanceFromP2(radius1);
  final p2 = line2.pointAtDistanceFromP1(radius2);
  return [
    LineSegment(line1.p1, p1),
    LineSegment(p1, p2),
    LineSegment(p2, line2.p2),
  ];
}

List<Segment> roundCornerUsingQuadraticBezier(
  LineSegment line1,
  LineSegment line2,
  double radius1,
  double radius2,
) {
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

/// Rounds the corner with a single cubic Bezier, cutting [line1] back by
/// [radius1] and [line2] back by [radius2] independently. Both interior
/// control points are anchored at the shared vertex: since {p1, vertex, vertex}
/// and {vertex, vertex, p2} are each trivially collinear, curvature is exactly
/// zero at both ends of the curve, matching the zero curvature of the straight
/// lines it meets. This is in fact the *only* placement of a single cubic's two
/// interior control points that achieves that on both ends at once: the only
/// point common to both lines is the vertex itself.
List<Segment> roundCornerUsingCubicBezier(
  LineSegment line1,
  LineSegment line2,
  double radius1,
  double radius2,
) {
  assert(line1.p2.isEqual(line2.p1));

  final vertex = line1.p2;
  final c1 = line1.pointAtDistanceFromP2(radius1);
  final c4 = line2.pointAtDistanceFromP1(radius2);

  final ret = <Segment>[
    LineSegment(line1.p1, c1),
    CubicSegment(p1: c1, p2: c4, c1: vertex, c2: vertex),
    LineSegment(c4, line2.p2),
  ];

  return ret;
}

/// Continuous-curvature ("squircle"/superellipse-style) corner, in the spirit
/// of Figma's corner smoothing: curvature eases from 0 into the fillet and back
/// to 0, instead of jumping instantly the way it does at the tangent points of
/// a circular arc. This is exactly [roundCornerUsingCubicBezier]'s construction
/// -- a single cubic with both interior control points at the shared vertex is
/// the only way to get that zero-curvature match at both ends -- exposed under
/// its own name since that curvature-continuity property, not the cubic
/// machinery, is what callers reaching for "squircle" actually want.
List<Segment> roundCornerUsingSquircle(
  LineSegment line1,
  LineSegment line2,
  double radius1,
  double radius2,
) {
  assert(line1.p2.isEqual(line2.p1));
  return roundCornerUsingCubicBezier(line1, line2, radius1, radius2);
}
