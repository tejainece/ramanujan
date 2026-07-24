import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  group('ArcSegment.isPointOn', () {
    test('ccw — endpoints, midpoint, on-ellipse-but-outside-span, off-ellipse', () {
      final arc = ArcSegment(P(10, 0), P(0, 10), P(10, 10), clockwise: false);
      expect(arc.isPointOn(P(10, 0)), isTrue, reason: 'p1');
      expect(arc.isPointOn(P(0, 10)), isTrue, reason: 'p2');
      expect(arc.isPointOn(arc.lerp(0.5)), isTrue, reason: 'lerp(0.5)');
      expect(
        arc.isPointOn(P(-10, 0)),
        isFalse,
        reason: 'on ellipse, outside span',
      );
      expect(arc.isPointOn(P(5, 5)), isFalse, reason: 'off ellipse entirely');
    });

    test('cw, crossing angle 0 — the winding case a naive angle-compare gets wrong', () {
      final cwArc = ArcSegment(P(10, 0), P(0, -10), P(10, 10), clockwise: true);
      expect(cwArc.isPointOn(P(10, 0)), isTrue, reason: 'p1');
      expect(cwArc.isPointOn(P(0, -10)), isTrue, reason: 'p2');
      expect(cwArc.isPointOn(cwArc.lerp(0.5)), isTrue, reason: 'lerp(0.5)');
      expect(
        cwArc.isPointOn(P(-10, 0)),
        isFalse,
        reason: 'on ellipse, outside span',
      );
    });
  });
}
