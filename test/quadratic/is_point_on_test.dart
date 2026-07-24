import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  group('QuadraticSegment.isPointOn', () {
    test('endpoints, midpoint, off-curve, on-curve-but-out-of-range', () {
      final quad = QuadraticSegment(p1: P(0, 0), c: P(50, 100), p2: P(100, 0));
      expect(quad.isPointOn(P(0, 0)), isTrue, reason: 'p1');
      expect(quad.isPointOn(P(100, 0)), isTrue, reason: 'p2');
      expect(quad.isPointOn(quad.lerp(0.5)), isTrue, reason: 'lerp(0.5)');
      expect(quad.isPointOn(P(50, 10)), isFalse, reason: 'off curve');
      expect(
        quad.isPointOn(quad.lerp(-0.5)),
        isFalse,
        reason: 'on curve, t out of range',
      );
    });
  });
}
