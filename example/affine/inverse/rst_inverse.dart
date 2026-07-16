import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

void main() {
  final rotation = pi / 3;
  final radii = P(100, 50);
  final center = P(100, 100);

  final affTr = Affine2d(
    translateX: center.x,
    translateY: center.y,
  ).rotate(rotation).scale(radii.x, radii.y);
  print(affTr);
  final invTr = Affine2d(
    scaleX: 1 / radii.x,
    scaleY: 1 / radii.y,
  ).rotate(-rotation).translate(-center.x, -center.y);
  print(invTr);

  print(affTr * invTr);

  final p = P(1, 0);
  print(p);
  final p1 = affTr.apply(p);
  print(p1);
  print(invTr.apply(p1));

  final invTr1 = affTr.inverse();
  print(invTr1);
  print(affTr * invTr1);
}
