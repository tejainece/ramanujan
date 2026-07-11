import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

class Polygon implements ClosedShape {
  final P center;

  /// Independent x/y radii, like [Ellipse] — lets the polygon stretch
  /// non-uniformly to fit a bounding rectangle instead of staying regular.
  final P radii;

  final int sides;

  Polygon({this.center = origin, required this.radii, required this.sides})
      : assert(sides >= 3);

  /// Creates a polygon whose vertices are inscribed in [rect].
  factory Polygon.fromR(R rect, int sides) => Polygon(
        center: rect.center,
        radii: P(rect.width / 2, rect.height / 2),
        sides: sides,
      );

  double _thetaAt(int i) => -pi / 2 + i * (2 * pi / sides);

  /// The [i]-th vertex (0-indexed), with vertex 0 pointing straight up from
  /// [center] — the same top-first convention used by [Circle]/[Ellipse].
  P vertex(int i) {
    final theta = _thetaAt(i);
    return center + P(radii.x * cos(theta), radii.y * sin(theta));
  }

  List<P> get vertices => List.generate(sides, vertex);

  Loop toLoop() {
    final points = vertices;
    return Loop([
      for (int i = 0; i < sides; i++)
        LineSegment(points[i], points[(i + 1) % sides]),
    ]);
  }

  /// Returns this path as a [Polygon] if it exactly matches the straight-edge
  /// construction used by [toLoop] (evenly-spaced vertices around a center,
  /// independently scaled on x/y), or null otherwise.
  static Polygon? fromVectorPath(VectorPath path) {
    if (!path.isClosed()) return null;
    final segments = path.segments;
    final n = segments.length;
    if (n < 3) return null;

    if (segments.any((s) => s is! LineSegment)) return null;

    final points = segments.map((s) => s.p1).toList();

    final cx = points.map((p) => p.x).reduce((a, b) => a + b) / n;
    final cy = points.map((p) => p.y).reduce((a, b) => a + b) / n;

    final cosT = List.generate(n, (i) => cos(-pi / 2 + i * (2 * pi / n)));
    final sinT = List.generate(n, (i) => sin(-pi / 2 + i * (2 * pi / n)));

    final sumCos2 = cosT.fold(0.0, (acc, c) => acc + c * c);
    final sumSin2 = sinT.fold(0.0, (acc, s) => acc + s * s);
    if (sumCos2 <= 0 || sumSin2 <= 0) return null;

    var rxNumerator = 0.0;
    var ryNumerator = 0.0;
    for (int i = 0; i < n; i++) {
      rxNumerator += (points[i].x - cx) * cosT[i];
      ryNumerator += (points[i].y - cy) * sinT[i];
    }
    final rx = rxNumerator / sumCos2;
    final ry = ryNumerator / sumSin2;
    if (rx <= 1e-9 || ry <= 1e-9) return null;

    for (int i = 0; i < n; i++) {
      if ((points[i].x - cx - rx * cosT[i]).abs() > 1e-6) return null;
      if ((points[i].y - cy - ry * sinT[i]).abs() > 1e-6) return null;
    }

    return Polygon(center: P(cx, cy), radii: P(rx, ry), sides: n);
  }

  @override
  double get perimeter {
    final points = vertices;
    var total = 0.0;
    for (int i = 0; i < sides; i++) {
      total += points[i].distanceTo(points[(i + 1) % sides]);
    }
    return total;
  }

  @override
  late final double area = () {
    final points = vertices;
    var sum = 0.0;
    for (int i = 0; i < sides; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % sides];
      sum += p1.x * p2.y - p2.x * p1.y;
    }
    return sum.abs() / 2;
  }();

  @override
  R get boundingBox => R(
        center.x - radii.x,
        center.y - radii.y,
        radii.x * 2,
        radii.y * 2,
      );

  @override
  bool containsPoint(P point) {
    final points = vertices;
    var inside = false;
    for (int i = 0, j = sides - 1; i < sides; j = i++) {
      final pi = points[i];
      final pj = points[j];
      final intersects = (pi.y > point.y) != (pj.y > point.y) &&
          point.x <
              (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x;
      if (intersects) inside = !inside;
    }
    return inside;
  }

  @override
  bool isPointOn(P point) {
    final points = vertices;
    for (int i = 0; i < sides; i++) {
      if (_distanceToSegment(point, points[i], points[(i + 1) % sides]) <
          1e-6) {
        return true;
      }
    }
    return false;
  }

  static double _distanceToSegment(P point, P a, P b) {
    final ab = b - a;
    final lengthSquared = ab.lengthSquared;
    if (lengthSquared == 0) return point.distanceTo(a);
    var t = ((point - a).x * ab.x + (point - a).y * ab.y) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    final projection = a + ab * t;
    return point.distanceTo(projection);
  }
}
