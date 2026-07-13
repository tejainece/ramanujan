import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

/// The transformed segment must trace the same points as transforming the
/// original's points directly: transformed.lerp(t) == affine(original.lerp(t)).
/// Arcs re-parameterize by eccentric angle, which an affine map does not
/// preserve (and clockwise arcs have known lerp-direction quirks), so with
/// [parameterizationPreserved] false each transformed sample is instead
/// checked to lie on the transformed arc's circle/ellipse and within its
/// angular span.
void expectTracesSameCurve(Segment original, Affine2d affine,
    {double tolerance = 1e-6, bool parameterizationPreserved = true}) {
  final transformed = original.transform(affine);
  expect(transformed.p1.isEqual(affine.apply(original.p1), tolerance), isTrue,
      reason: 'p1 mismatch: ${transformed.p1} vs ${affine.apply(original.p1)}');
  expect(transformed.p2.isEqual(affine.apply(original.p2), tolerance), isTrue,
      reason: 'p2 mismatch: ${transformed.p2} vs ${affine.apply(original.p2)}');
  for (var i = 0; i <= 20; i++) {
    final t = i / 20;
    final expected = affine.apply(original.lerp(t));
    if (parameterizationPreserved) {
      final actual = transformed.lerp(t);
      expect(actual.isEqual(expected, tolerance), isTrue,
          reason: 't=$t: $actual vs $expected');
      continue;
    }
    switch (transformed) {
      case CircularArcSegment arc:
        expect(arc.isOnCircle(expected, epsilon: tolerance), isTrue,
            reason: 't=$t: $expected not on circle '
                '(center ${arc.center}, r ${arc.effectiveRadius})');
        if (i > 0 && i < 20) {
          expect(arc.containsPointAngle(expected), isTrue,
              reason: 't=$t: $expected outside the arc span');
        }
      case ArcSegment arc:
        final q = arc.ellipse.inverseUnitCircleTransform.apply(expected);
        expect((q.x * q.x + q.y * q.y - 1).abs(), lessThan(tolerance),
            reason: 't=$t: $expected not on ellipse ${arc.ellipse}');
        if (i > 0 && i < 20) {
          expect(arc.containsPointAngle(expected), isTrue,
              reason: 't=$t: $expected outside the arc span');
        }
      default:
        fail('unexpected transformed type ${transformed.runtimeType}');
    }
  }
}

void main() {
  final identity = Affine2d();
  final translation = Affine2d(translateX: 12, translateY: -7);
  final rotation = Affine2d.rotator(pi / 5).translate(3, 4);
  final uniformScale = Affine2d.scaler(2.5).translate(-1, 6);
  final mirror = Affine2d(scaleX: -1);
  final nonUniform = Affine2d(scaleX: 2, scaleY: 0.5, translateX: 5);
  final skewed = Affine2d(scaleX: 1.5, shearX: 0.6, shearY: -0.2, scaleY: 0.9);

  final line = LineSegment(P(1, 2), P(5, -3));
  final quadratic = QuadraticSegment(p1: P(0, 0), p2: P(6, 2), c: P(3, 5));
  final cubic =
      CubicSegment(p1: P(-2, 1), p2: P(4, 4), c1: P(0, 6), c2: P(3, -2));
  final circularCcw = CircularArcSegment(P(2, 0), P(0, 2), 2, clockwise: false);
  final circularCw =
      CircularArcSegment(P(2, 0), P(0, 2), 2, largeArc: true, clockwise: true);
  // Endpoints taken from the ellipse itself so the arc is well-defined.
  final sourceEllipse = Ellipse(P(3, 1.5), rotation: pi / 6);
  final elliptical = ArcSegment(
      sourceEllipse.unitCircleTransform.apply(P(1, 0)),
      sourceEllipse.unitCircleTransform.apply(P(cos(2 * pi / 3), sin(2 * pi / 3))),
      P(3, 1.5),
      rotation: pi / 6,
      clockwise: false);

  group('point-based segments transform exactly', () {
    for (final (name, affine) in [
      ('identity', identity),
      ('translation', translation),
      ('rotation', rotation),
      ('uniform scale', uniformScale),
      ('mirror', mirror),
      ('non-uniform scale', nonUniform),
      ('skew', skewed),
    ]) {
      test(name, () {
        expectTracesSameCurve(line, affine);
        expectTracesSameCurve(quadratic, affine);
        expectTracesSameCurve(cubic, affine);
      });
    }
  });

  group('circular arc', () {
    test('similarity keeps it circular', () {
      for (final affine in [identity, translation, rotation, uniformScale]) {
        for (final arc in [circularCcw, circularCw]) {
          final transformed = arc.transform(affine);
          expect(transformed, isA<CircularArcSegment>());
          expectTracesSameCurve(arc, affine);
        }
      }
    });

    test('similarity scales the radius', () {
      final transformed =
          circularCcw.transform(uniformScale) as CircularArcSegment;
      expect(transformed.radius, closeTo(2 * 2.5, 1e-9));
    });

    test('mirror keeps the circle and flips winding', () {
      for (final arc in [circularCcw, circularCw]) {
        final transformed = arc.transform(mirror) as CircularArcSegment;
        expect(transformed.clockwise, equals(!arc.clockwise));
        expect(transformed.largeArc, equals(arc.largeArc));
        expectTracesSameCurve(arc, mirror, parameterizationPreserved: false);
      }
    });

    test('non-uniform scale and skew produce an equivalent elliptical arc',
        () {
      for (final affine in [nonUniform, skewed]) {
        for (final arc in [circularCcw, circularCw]) {
          final transformed = arc.transform(affine);
          expect(transformed, isA<ArcSegment>());
          expectTracesSameCurve(arc, affine,
              parameterizationPreserved: false, tolerance: 1e-6);
        }
      }
    });
  });

  group('elliptical arc', () {
    for (final (name, affine) in [
      ('identity', identity),
      ('translation', translation),
      ('rotation', rotation),
      ('uniform scale', uniformScale),
      ('mirror', mirror),
      ('non-uniform scale', nonUniform),
      ('skew', skewed),
    ]) {
      test('traces the same curve under $name', () {
        expectTracesSameCurve(elliptical, affine,
            parameterizationPreserved: false, tolerance: 1e-6);
      });
    }

    test('mirror flips winding', () {
      final transformed = elliptical.transform(mirror);
      expect(transformed.clockwise, equals(!elliptical.clockwise));
    });
  });

  group('loop and region', () {
    Region unitSquare() => Region([
          Loop(Segment.rect(R(0, 0, 1, 1))),
        ]);

    test('loop stays closed and traces transformed corners', () {
      final loop = Loop(Segment.rect(R(0, 0, 2, 3)));
      final transformed = loop.transform(skewed);
      expect(transformed.isClosed(), isTrue);
      expect(transformed.segments.length, equals(4));
      expect(
          transformed.segments.first.p1
              .isEqual(skewed.apply(loop.segments.first.p1), 1e-9),
          isTrue);
    });

    test('region containment moves with the transform', () {
      final region = unitSquare();
      final affine = rotation;
      final transformed = region.transform(affine);
      expect(transformed.fillRule, equals(region.fillRule));
      expect(transformed.contains(affine.apply(P(0.5, 0.5))), isTrue);
      expect(transformed.contains(affine.apply(P(1.5, 0.5))), isFalse);
    });

    test('transformed regions feed the boolean pipeline', () {
      // Two unit squares, one shifted to overlap the other: union must be a
      // single merged outline whose midpoint of the overlap is inside.
      final a = unitSquare();
      final b = unitSquare().transform(Affine2d(translateX: 0.5));
      final union = const PathUnion().compute(a, b);
      expect(union.isNotEmpty, isTrue);
      expect(union.contains(P(0.75, 0.5)), isTrue);
      expect(union.contains(P(1.25, 0.5)), isTrue);
      expect(union.contains(P(1.75, 0.5)), isFalse);
    });
  });
}
