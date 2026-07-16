import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

void main() {
  final center = P(0, 0);
  final radius = 1.0;
  final startAngle = Radian(0);
  final endAngle = Radian(3 * pi / 2);
  final clockwise = startAngle < endAngle;
  final largeArc =
      Radian((endAngle.value - startAngle.value).abs()) > Radian(pi);
  final arc = CircularArcSegment(
    P.onCircle(startAngle.value, radius, center),
    P.onCircle(endAngle.value, radius, center),
    radius,
    clockwise: clockwise,
    largeArc: largeArc,
  );
  print('angle: ${arc.angle.toDegree}');
}
