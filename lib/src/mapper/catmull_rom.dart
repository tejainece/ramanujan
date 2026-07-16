import 'package:ramanujan/ramanujan.dart';

SegmentMapperWithControls catmullRomSmoother({
  int steps = 100,
  double tension = 0.5,
}) {
  return (P cp1, Segment segment, P cp2) =>
      segment.line.catmullRomInterpolate(steps, tension, cp1, cp2);
}

/// https://en.wikipedia.org/wiki/Cubic_Hermite_spline#Unit_interval_(0,_1)
P catmullRomLerp(P cp0, P p0, P p1, P cp1, double t) {
  final t2 = t * t;
  final t3 = t2 * t;

  final c = 2 * t3 - 3 * t2;
  final c0 = c + 1;
  final c1 = t3 - 2 * t2 + t;
  final c2 = -c;
  final c3 = t3 - t2;

  final ret = P(
    c0 * p0.x + c1 * cp0.x + c2 * p1.x + c3 * cp1.x,
    c0 * p0.y + c1 * cp0.y + c2 * p1.y + c3 * cp1.y,
  );
  return ret;
}

extension CatmullRomLineExt on LineSegment {
  List<LineSegment> catmullRomInterpolate(
    int steps,
    double tension,
    P cp1,
    P cp2,
  ) {
    double s = 2 * tension;
    final m1 = P((p2.x - cp1.x) / s, (p2.y - cp1.y) / s);
    final m2 = P((cp2.x - p1.x) / s, (cp2.y - p1.y) / s);

    final ret = <LineSegment>[];
    P pivot = catmullRomLerp(m1, p1, p2, m2, 0);
    ret.add(LineSegment(p1, pivot));
    final step = 1.0 / steps;
    for (double t = step; t < 1; t += step) {
      P nextPivot = catmullRomLerp(m1, p1, p2, m2, t);
      ret.add(LineSegment(pivot, nextPivot));
      pivot = nextPivot;
    }
    ret.add(LineSegment(pivot, p2));
    return ret;
  }
}
