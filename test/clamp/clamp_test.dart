import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _ClampTest {
  final Clamp clamp;
  final double unclamped;
  final double clamped;

  _ClampTest(this.clamp, this.unclamped, this.clamped);

  static List<_ClampTest> cases = [
    _ClampTest(Clamp(1), 0, 0),
    _ClampTest(Clamp(1), 0.5, 0.5),
    _ClampTest(Clamp(1), 1, 0),
    _ClampTest(Clamp(1), 1.2, 0.2),
    _ClampTest(Clamp(1), 1.5, 0.5),
    _ClampTest(Clamp(1), 1.7, 0.7),
    _ClampTest(Clamp(1), 2, 0),
  ];

  static List<_ClampTest> minusCases = [
    _ClampTest(Clamp(1), -0.2, 0.8),
    _ClampTest(Clamp(1), -0.5, 0.5),
    _ClampTest(Clamp(1), -0.75, 0.25),
    _ClampTest(Clamp(1), -1, 0),
    _ClampTest(Clamp(1), -1.2, 0.8),
    _ClampTest(Clamp(1), -1.5, 0.5),
    _ClampTest(Clamp(1), -1.75, 0.25),
    _ClampTest(Clamp(1), -2, 0),
  ];
}

void main() {
  group('Clamp', () {
    test('plus', () {
      for (final tc in _ClampTest.cases) {
        expect(
          tc.clamp.clamp(tc.unclamped),
          closeTo(tc.clamped, 1e-6),
          reason: 'unclamped: ${tc.unclamped}',
        );
      }
    });
    test('minus', () {
      for (final tc in _ClampTest.minusCases) {
        expect(
          tc.clamp.clamp(tc.unclamped),
          closeTo(tc.clamped, 1e-6),
          reason: 'unclamped: ${tc.unclamped}',
        );
      }
    });
  });
}
