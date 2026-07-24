import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _IsOnCircularArcCase {
  final CircularArcSegment arc;
  final P point;
  final bool isOnArc;
  final bool isOnCircle;

  const _IsOnCircularArcCase(
    this.arc,
    this.point,
    this.isOnArc,
    this.isOnCircle,
  );

  static List<_IsOnCircularArcCase> cases = [
    _IsOnCircularArcCase(
      CircularArcSegment(P.onCircle(0.2), P.onCircle(0.5), 1, clockwise: false),
      P.onCircle(0.3),
      true,
      true,
    ),
    _IsOnCircularArcCase(
      CircularArcSegment(P.onCircle(0.2), P.onCircle(0.5), 1, clockwise: false),
      P.onCircle(0.6),
      false,
      true,
    ),
    _IsOnCircularArcCase(
      CircularArcSegment(P.onCircle(0.2), P.onCircle(0.5), 1, clockwise: false),
      P.onCircle(0.1),
      false,
      true,
    ),
  ];
}

void main() {
  group('CircularArc', () {
    test('isPointOn', () {
      for (int i = 0; i < _IsOnCircularArcCase.cases.length; i++) {
        final test = _IsOnCircularArcCase.cases[i];
        expect(
          test.arc.isPointOn(test.point),
          test.isOnArc,
          reason: 'test $i; isPointOn?',
        );
        expect(
          test.arc.isOnCircle(test.point),
          test.isOnCircle,
          reason: 'test $i; isOnCircle?',
        );
      }
    });
  });
}
