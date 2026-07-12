import 'dart:math';

import 'package:ramanujan/ramanujan.dart';

void main() {
  final radii = P(100, 50);
  final center = P(100, 100);
  final rotation = pi / 3;
  final ellipse = Ellipse(radii, center: center, rotation: rotation);
  final uct = ellipse.unitCircleTransform;
  print(uct);
  final iuct = ellipse.inverseUnitCircleTransform;
  final res = uct * iuct;
  print(res);

  final angle = pi / 3;
  final p = P.onCircle(angle);
  print(p);
  final p1 = uct.apply(p);
  print(p1);
  final p2 = iuct.apply(p1);
  print(p2);
  print(p2.angle);

  /*final uctm = Matrix3(uct.scaleX, uct.shearY, 0, uct.shearX, uct.scaleY, 0,
      uct.translateX, uct.translateY, 1);
  final iuctm = Matrix3.copy(uctm)..invert();
  print('------');
  print(iuctm.pretty);
  final iuct2 = iuctm.affine;
  print(iuct2);
  print(uct * iuct2);
  print(iuct2.apply(p1));
  print('------');*/
}
