import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _ClampLerpTest {
  final Clamp clamp;
  final double t1, t2, t, lerped;
  final bool clockwise;

  _ClampLerpTest(
    this.clamp,
    this.t1,
    this.t2,
    this.t,
    this.clockwise,
    this.lerped,
  );

  static List<_ClampLerpTest> cases = [
    _ClampLerpTest(
      Clamp.unit,
      0,
      0.51301166,
      0.2098646566,
      false,
      0.10766301585769596,
    ),
    _ClampLerpTest(
      Clamp.unit,
      0.99999,
      0.51301166,
      0.2098646566,
      false,
      0.10766301585769596,
    ),
  ];
}

void main() {
  group('ClampLerp', () {
    test('lerp', () {
      for (final test in _ClampLerpTest.cases) {
        expect(
          test.clamp.lerp(test.t1, test.t2, test.t, clockwise: test.clockwise),
          closeTo(test.lerped, 1e-3),
          reason:
              't1: ${test.t1}, t2: ${test.t2}, t: ${test.t}, clockwise: ${test.clockwise}',
        );
      }
    });
  });
}
