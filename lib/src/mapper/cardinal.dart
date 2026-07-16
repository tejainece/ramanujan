import 'package:ramanujan/ramanujan.dart';

SegmentMapperWithControls cardinalSmoother({double tension = 2}) {
  return (P c1, Segment segment, P c2) {
    final p1Prime = (segment.p2 - c1) / tension;
    final p2Prime = (c2 - segment.p1) / tension;

    return [
      CubicSegment(
        p1: segment.p1,
        p2: segment.p2,
        c1: segment.p1 + p1Prime / 3,
        c2: segment.p2 - p2Prime / 3,
      ),
    ];
  };
}
