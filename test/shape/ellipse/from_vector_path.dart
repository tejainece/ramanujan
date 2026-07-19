import 'dart:math';

import 'package:ramanujan/ramanujan.dart';
import 'package:test/test.dart';

void main() {
  group('Shape.Ellipse.FromVectorPath', () {
    test('round-trips an axis-aligned ellipse with rotation 0', () {
      final ellipse = Ellipse(P(40, 20), center: P(50, 50));

      final detected = Ellipse.fromVectorPath(ellipse.toLoop())!;

      expect(detected.center.isEqual(P(50, 50)), isTrue);
      expect(detected.radii.x, closeTo(40, 1e-9));
      expect(detected.radii.y, closeTo(20, 1e-9));
      expect(detected.rotation, closeTo(0, 1e-9));
    });

    test('round-trips a rotated ellipse, recovering the rotation', () {
      final ellipse = Ellipse(P(40, 20), center: P(50, 50), rotation: pi / 6);

      final detected = Ellipse.fromVectorPath(ellipse.toLoop())!;

      expect(detected.center.isEqual(P(50, 50)), isTrue);
      expect(detected.radii.x, closeTo(40, 1e-9));
      expect(detected.radii.y, closeTo(20, 1e-9));
      expect(detected.rotation, closeTo(pi / 6, 1e-9));
    });

    test('detects an externally rotated loop', () {
      final loop = Ellipse(P(40, 20), center: P(50, 50)).toLoop();
      final affine = Affine2d(
        translateX: 50,
        translateY: 50,
      ).rotate(pi / 3).translate(-50, -50);

      final detected = Ellipse.fromVectorPath(loop.transform(affine))!;

      expect(detected.center.isEqual(P(50, 50)), isTrue);
      expect(detected.radii.x, closeTo(40, 1e-6));
      expect(detected.radii.y, closeTo(20, 1e-6));
      expect(detected.rotation, closeTo(pi / 3, 1e-6));
    });

    test('rejects a loop whose points are not an ellipse', () {
      final loop = Ellipse(P(40, 20), center: P(50, 50)).toLoop();
      final skewed = loop.transform(Affine2d(shearX: 0.4));

      expect(Ellipse.fromVectorPath(skewed), isNull);
    });
  });
}
