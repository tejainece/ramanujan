import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

void main() {
  // Direction of the segment's own lerp by central difference — used only to
  // validate the analytic unitTangentAt (orientation + convention).
  P numericTangent(Segment s, double t) {
    const e = 1e-4;
    return (s.lerp(t + e) - s.lerp(t - e)).normalized;
  }

  void expectMatchesNumeric(Segment s, String name) {
    for (final t in [0.15, 0.4, 0.6, 0.85]) {
      final analytic = s.unitTangentAt(t);
      final numeric = numericTangent(s, t);
      expect(
        analytic.isEqual(numeric, 1e-2),
        isTrue,
        reason: '$name @ t=$t: analytic $analytic vs numeric $numeric',
      );
    }
  }

  group('unitTangentAt matches the lerp derivative', () {
    test('LineSegment', () {
      expectMatchesNumeric(
        LineSegment(const P(10, 20), const P(90, 60)),
        'line',
      );
    });

    test('QuadraticSegment', () {
      expectMatchesNumeric(
        QuadraticSegment(
          p1: const P(0, 0),
          c: const P(50, 80),
          p2: const P(100, 0),
        ),
        'quad',
      );
    });

    test('CubicSegment', () {
      expectMatchesNumeric(
        CubicSegment(
          p1: const P(0, 0),
          c1: const P(20, 80),
          c2: const P(80, 80),
          p2: const P(100, 0),
        ),
        'cubic',
      );
    });

    test('CircularArcSegment', () {
      expectMatchesNumeric(
        CircularArcSegment(const P(0, -50), const P(50, 0), 50),
        'circular',
      );
    });

    test('ArcSegment (axis-aligned)', () {
      expectMatchesNumeric(
        ArcSegment(const P(0, -40), const P(60, 0), const P(60, 40)),
        'arc',
      );
    });

    test('ArcSegment (rotated)', () {
      expectMatchesNumeric(
        ArcSegment(
          const P(0, -40),
          const P(60, 0),
          const P(60, 40),
          rotation: 0.5,
        ),
        'arc-rotated',
      );
    });

    test('ArcSegment (ccw)', () {
      expectMatchesNumeric(
        ArcSegment(
          const P(0, -40),
          const P(60, 0),
          const P(60, 40),
          clockwise: false,
        ),
        'arc-ccw',
      );
    });
  });

  group('unitNormalAt', () {
    final seg = LineSegment(const P(0, 0), const P(100, 0));

    test('is perpendicular to the tangent', () {
      final tan = seg.unitTangentAt(0.5);
      final n = seg.unitNormalAt(0.5);
      expect((tan.x * n.x + tan.y * n.y).abs(), lessThan(1e-9));
    });

    test('cw points to -y for a +x segment; cw:false flips it', () {
      final cw = seg.unitNormalAt(0.5);
      final ccw = seg.unitNormalAt(0.5, cw: false);
      expect(cw.isEqual(const P(0, -1), 1e-9), isTrue);
      expect(cw.isEqual(-ccw, 1e-9), isTrue);
    });
  });
}
