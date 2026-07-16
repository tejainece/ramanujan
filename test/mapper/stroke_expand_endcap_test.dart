import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

/// An open path whose end has a non-zero width must emit a cap edge joining the
/// two offset sides at that end. Without it the renderer runs the return edge
/// straight back from the side-A endpoint and the end collapses to a single
/// point (zero width).
void main() {
  final cubic = CubicSegment(
    p1: const P(-160, -40),
    c1: const P(-60, 140),
    c2: const P(60, -140),
    p2: const P(160, 40),
  );

  group('open-end cap', () {
    test('non-zero widthAtP2 emits a cap that gives the end its width', () {
      const w2 = 80.0;
      final out = strokeExpand(
        [cubic],
        maxWidth: 80,
        widthAtP1: 0,
        widthAtP2: w2,
      );
      final caps = out.whereType<LineSegment>().toList();
      expect(
        caps,
        isNotEmpty,
        reason: 'expected a cap segment at the wide end',
      );
      // The cap spans the full end width.
      final cap = caps.first;
      expect((cap.p1 - cap.p2).length, closeTo(w2, 1e-6));
    });

    test(
      'the two end edges meet the cap (outline is connected at the end)',
      () {
        final out = strokeExpand(
          [cubic],
          maxWidth: 80,
          widthAtP1: 0,
          widthAtP2: 80,
        );
        // Walk the outline; every consecutive pair must be continuous.
        for (var i = 0; i < out.length - 1; i++) {
          expect(
            out[i].p2.isEqual(out[i + 1].p1),
            isTrue,
            reason: 'discontinuity between segment $i and ${i + 1}',
          );
        }
      },
    );

    test('zero-width taper end emits NO cap (stays a point)', () {
      final out = strokeExpand(
        [cubic],
        maxWidth: 80,
        widthAtP1: 0,
        widthAtP2: 0,
      );
      expect(out.whereType<LineSegment>(), isEmpty);
      expect(out.length, 2);
    });

    test('closed path still gets its seam', () {
      final circle = strokeExpand([
        CircularArcSegment(
          const P(-120, 0),
          const P(120, 0),
          120,
          clockwise: false,
        ),
        CircularArcSegment(
          const P(120, 0),
          const P(-120, 0),
          120,
          clockwise: false,
        ),
      ], maxWidth: 40);
      expect(circle.whereType<LineSegment>(), isNotEmpty);
    });

    test('non-zero widthAtP1 caps the START so the loop closes', () {
      final out = strokeExpand(
        [cubic],
        maxWidth: 80,
        widthAtP1: 80,
        widthAtP2: 0,
      );
      // The outline must close back on itself: last segment ends where the
      // first begins (a start cap bridges the diverging side-A/side-B starts).
      expect(
        out.first.p1.isEqual(out.last.p2),
        isTrue,
        reason: 'open start with width should be closed by a cap',
      );
    });

    test('both ends tapered to zero need no start/end cap', () {
      final out = strokeExpand(
        [cubic],
        maxWidth: 80,
        widthAtP1: 0,
        widthAtP2: 0,
      );
      expect(out.whereType<LineSegment>(), isEmpty);
      // Still a closed loop (both ends are points).
      expect(out.first.p1.isEqual(out.last.p2), isTrue);
    });
  });
}
