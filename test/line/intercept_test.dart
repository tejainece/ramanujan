import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _PerpendicularCase {
  final LineSegment line;
  final double yIntercept;

  const _PerpendicularCase(this.line, this.yIntercept);

  static List<_PerpendicularCase> cases = [
    _PerpendicularCase(LineSegment(P(0, 0), P(1, 0)), 0),
    _PerpendicularCase(LineSegment(P(1, 1), P(2, 3)), -1),
  ];
}

void main() {
  group('LineSegment', () {
    test('radial', () {
      for (final test in _PerpendicularCase.cases) {
        expect(
          test.line.yIntercept,
          test.yIntercept,
          reason: 'for line: ${test.line}',
        );
      }
    });
  });
}
