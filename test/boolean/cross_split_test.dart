import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

// A simple closed rectangle as a list of simple faces (step-1 output).
List<Loop> _rect(double x, double y, double w, double h) => [
      Loop([
        LineSegment(P(x, y), P(x + w, y)),
        LineSegment(P(x + w, y), P(x + w, y + h)),
        LineSegment(P(x + w, y + h), P(x, y + h)),
        LineSegment(P(x, y + h), P(x, y)),
      ])
    ];

// Convenience: runs splitAndClassify with Region wrappers for classification.
List<ClassifiedFace> _classify(List<Loop> a, List<Loop> b) =>
    splitAndClassify(a, b, Region(a), Region(b));

double _area(VectorPath path) {
  var a = 0.0;
  for (final s in path.segments) {
    a += s.p1.x * s.p2.y - s.p2.x * s.p1.y;
  }
  return a / 2;
}

void main() {
  group('splitAndClassify', () {
    test('empty inputs return empty list', () {
      expect(splitAndClassify([], [], Region([]), Region([])), isEmpty);
    });

    test('non-overlapping rectangles — no cross intersections', () {
      // A: [0,0]–[100,100]  B: [200,0]–[300,100]  (no overlap)
      final result = _classify(_rect(0, 0, 100, 100), _rect(200, 0, 100, 100));
      final aOnly = result.where((f) => f.insideA && !f.insideB).toList();
      final bOnly = result.where((f) => !f.insideA && f.insideB).toList();
      final both = result.where((f) => f.insideA && f.insideB).toList();
      expect(aOnly, hasLength(1));
      expect(bOnly, hasLength(1));
      expect(both, isEmpty);
    });

    test('partially overlapping rectangles produce three CCW faces', () {
      // A: [0,0]–[100,100]  B: [50,50]–[150,150]
      // Overlap region: [50,50]–[100,100] (area 50×50 = 2500).
      // Boundaries cross only at (100,50) and (50,100) — no coincident edges.
      final result = _classify(_rect(0, 0, 100, 100), _rect(50, 50, 100, 100));
      final aOnly = result.where((f) => f.insideA && !f.insideB).toList();
      final bOnly = result.where((f) => !f.insideA && f.insideB).toList();
      final both = result.where((f) => f.insideA && f.insideB).toList();

      expect(aOnly, hasLength(1));
      expect(bOnly, hasLength(1));
      expect(both, hasLength(1));

      // A-only: L-shape 100×100 − 50×50 = 7500
      expect(_area(aOnly.first.path), closeTo(7500, 1));
      // A∩B: 50×50 square
      expect(_area(both.first.path), closeTo(2500, 1));
      // B-only: L-shape 100×100 − 50×50 = 7500
      expect(_area(bOnly.first.path), closeTo(7500, 1));
    });

    test('fully contained rectangle — B inside A produces two faces', () {
      // A: [0,0]–[200,200]  B: [50,50]–[150,150]
      // B is fully inside A with no boundary crossings. The planar graph has
      // two disconnected components, so the result is A's full square and B's
      // square — not a donut. Step 3 uses these labels for boolean filtering.
      final result = _classify(_rect(0, 0, 200, 200), _rect(50, 50, 100, 100));
      final aOnly = result.where((f) => f.insideA && !f.insideB).toList();
      final both = result.where((f) => f.insideA && f.insideB).toList();
      final bOnly = result.where((f) => !f.insideA && f.insideB).toList();

      expect(bOnly, isEmpty);
      // A's full rectangle (interior point is outside B)
      expect(aOnly, hasLength(1));
      expect(_area(aOnly.first.path), closeTo(40000, 1));
      // B's rectangle (interior point is inside both A and B)
      expect(both, hasLength(1));
      expect(_area(both.first.path), closeTo(10000, 1));
    });

    test('all faces are closed and CCW', () {
      // Use the diagonal-offset case — avoids coincident edges.
      final result = _classify(_rect(0, 0, 100, 100), _rect(50, 50, 100, 100));
      for (final f in result) {
        expect(f.path.isClosed(), isTrue, reason: 'face not closed');
        expect(_area(f.path), greaterThan(0), reason: 'face not CCW');
      }
    });
  });
}
