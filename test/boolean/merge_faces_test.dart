import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

List<Loop> _rect(double x, double y, double w, double h) => [
  Loop([
    LineSegment(P(x, y), P(x + w, y)),
    LineSegment(P(x + w, y), P(x + w, y + h)),
    LineSegment(P(x + w, y + h), P(x, y + h)),
    LineSegment(P(x, y + h), P(x, y)),
  ]),
];

double _area(VectorPath path) {
  var a = 0.0;
  for (final s in path.segments) {
    a += s.p1.x * s.p2.y - s.p2.x * s.p1.y;
  }
  return a / 2;
}

// All overlap tests use the diagonal-offset pair that avoids coincident edges.
// A=[0,0,100,100]  B=[50,50,100,100]
// Crossings at (100,50) and (50,100) only.
List<ClassifiedFace> get _overlapping {
  final a = _rect(0, 0, 100, 100);
  final b = _rect(50, 50, 100, 100);
  return splitAndClassify(a, b, Region(a), Region(b));
}

void main() {
  group('mergeFaces', () {
    test('empty input returns empty list', () {
      expect(mergeFaces([]), isEmpty);
    });

    test('single kept face is returned unchanged', () {
      // Intersection of the overlapping pair: one face (the 50×50 overlap).
      final filtered = const Intersection().filter(_overlapping);
      expect(filtered, hasLength(1));
      final result = mergeFaces(filtered);
      expect(result, hasLength(1));
      expect(_area(result.first), closeTo(2500, 1));
    });

    test('union merges adjacent faces into one ring', () {
      // A∪B = 100×100 + 100×100 − 50×50 = 17500.
      final result = mergeFaces(const Union().filter(_overlapping));
      expect(result, hasLength(1));
      expect(_area(result.first), closeTo(17500, 1));
    });

    test('intersection keeps only the overlap face', () {
      final result = mergeFaces(const Intersection().filter(_overlapping));
      expect(result, hasLength(1));
      expect(_area(result.first), closeTo(2500, 1));
    });

    test('difference A−B keeps the A-only L-shape', () {
      final result = mergeFaces(const Difference().filter(_overlapping));
      expect(result, hasLength(1));
      expect(_area(result.first), closeTo(7500, 1));
    });

    test('xor keeps the two non-adjacent L-shapes as separate rings', () {
      // aOnly and bOnly share no edges (both-face is discarded), so two rings.
      final result = mergeFaces(const Xor().filter(_overlapping));
      expect(result, hasLength(2));
      final total = result.map(_area).reduce((a, b) => a + b);
      expect(total, closeTo(15000, 1));
    });

    test('union of non-overlapping shapes returns both unchanged', () {
      // No shared edges → nothing to remove → both original paths returned.
      final a = _rect(0, 0, 100, 100);
      final b = _rect(200, 0, 100, 100);
      final classified = splitAndClassify(a, b, Region(a), Region(b));
      final result = mergeFaces(const Union().filter(classified));
      expect(result, hasLength(2));
      final total = result.map(_area).reduce((a, b) => a + b);
      expect(total, closeTo(20000, 1));
    });

    test('all result rings are closed', () {
      for (final op in <BooleanOpFilter>[
        const Union(),
        const Intersection(),
        const Difference(),
        const Xor(),
      ]) {
        final result = mergeFaces(op.filter(_overlapping));
        for (final ring in result) {
          expect(
            ring.isClosed(),
            isTrue,
            reason: 'ring is not closed for ${op.runtimeType}',
          );
        }
      }
    });

    test('cross (plus-sign) union merges 5 faces into one ring', () {
      // A: wide horizontal bar  B: tall vertical bar — 4 crossings.
      final a = [
        Loop([
          LineSegment(P(-150, -40), P(150, -40)),
          LineSegment(P(150, -40), P(150, 40)),
          LineSegment(P(150, 40), P(-150, 40)),
          LineSegment(P(-150, 40), P(-150, -40)),
        ]),
      ];
      final b = [
        Loop([
          LineSegment(P(-40, -150), P(40, -150)),
          LineSegment(P(40, -150), P(40, 150)),
          LineSegment(P(40, 150), P(-40, 150)),
          LineSegment(P(-40, 150), P(-40, -150)),
        ]),
      ];
      final classified = splitAndClassify(a, b, Region(a), Region(b));
      final result = mergeFaces(const Union().filter(classified));
      expect(result, hasLength(1));
      // Area = 300×80 + 80×300 − 80×80 = 24000 + 24000 − 6400 = 41600
      expect(_area(result.first), closeTo(41600, 1));
    });
  });
}
