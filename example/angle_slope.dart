import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

void main() {
  for (final angle in Iterable<double>.generate(9, (i) => (i * 45) - 180)) {
    final radian = angle.toRadian;
    final slope = radian.angleToSlope;
    final angleDup = atan2(sin(radian), cos(radian)).toDegree;
    final angleDup2 = slope.slopeToAngle().toDegree.round();
    final angleDup3 = atan2(-slope, -1).toDegree.round();
    print(
      'angle: $angle; slope: $slope, angleDup: $angleDup, angleDup2: $angleDup2, angleDup3: $angleDup3',
    );
  }
}
