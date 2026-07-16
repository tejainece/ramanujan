import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  group('notcher', () {
    // A +x horizontal segment: its clockwise normal is (0, -1), so cw notches
    // are carved toward negative y.
    final segment = LineSegment(const P(0, 0), const P(100, 0));

    Notch nick(
      double t, {
      double depth = 6,
      double half = 4,
      double tilt = 0,
    }) => Notch(
      t: t,
      depth: depth,
      halfBefore: half,
      halfAfter: half,
      tilt: tilt,
    );

    test('an empty list leaves the segment unchanged', () {
      expect(notcher([])(segment), [segment]);
    });

    test('keeps the original endpoints', () {
      final pts = notcher([nick(0.25), nick(0.5), nick(0.75)])(
        segment,
      ).polylinePoints;
      expect(pts.first, const P(0, 0));
      expect(pts.last, const P(100, 0));
    });

    test('carves an apex toward the cw normal at the given depth', () {
      final pts = notcher([nick(0.25), nick(0.5), nick(0.75)])(
        segment,
      ).polylinePoints;
      final apexes = pts.where((p) => p.y.abs() > 1e-6).toList();
      expect(apexes.length, 3);
      // straight +x segment, no tilt → apex sits at exactly (t*100, -depth).
      expect(apexes.every((p) => (p.y + 6).abs() < 1e-6), isTrue);
      expect(apexes[1].x, closeTo(50, 1e-6));
    });

    test('cw:false flips the carve direction', () {
      final pts = notcher([nick(0.5)], cw: false)(segment).polylinePoints;
      final apex = pts.firstWhere((p) => p.y.abs() > 1e-6);
      expect(apex.y, closeTo(6, 1e-6));
    });

    test('skips a notch that overlaps the previous one', () {
      // both have wide bases (half=30px) and sit close together → 2nd is dropped
      final pts = notcher([nick(0.5, half: 30), nick(0.55, half: 30)])(
        segment,
      ).polylinePoints;
      final apexes = pts.where((p) => p.y.abs() > 1e-6).toList();
      expect(apexes.length, 1);
    });

    test('skips a notch whose base runs past the segment end', () {
      final pts = notcher([nick(0.99, half: 20)])(segment).polylinePoints;
      expect(pts.where((p) => p.y.abs() > 1e-6), isEmpty);
    });
  });
}
