import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  group('CubicSegment.isPointOn', () {
    test('endpoints, midpoint, off-curve, on-curve-but-out-of-range', () {
      final cubic = CubicSegment(
        p1: P(0, 0),
        c1: P(0, 100),
        c2: P(100, 100),
        p2: P(100, 0),
      );
      expect(cubic.isPointOn(P(0, 0)), isTrue, reason: 'p1');
      expect(cubic.isPointOn(P(100, 0)), isTrue, reason: 'p2');
      expect(cubic.isPointOn(cubic.lerp(0.5)), isTrue, reason: 'lerp(0.5)');
      expect(cubic.isPointOn(P(50, 50)), isFalse, reason: 'off curve');
      expect(
        cubic.isPointOn(cubic.lerp(-0.5)),
        isFalse,
        reason: 'on curve, t out of range',
      );
    });
  });
}
