import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _AcuteCase {
  final Radian angle;
  final Radian acute;

  const _AcuteCase(this.angle, this.acute);

  static List<_AcuteCase> cases = [
    // 0
    _AcuteCase(Radian(0.toRadian), Radian(0.toRadian)),
    _AcuteCase(Radian(360.toRadian), Radian(0.toRadian)),
    // 30
    _AcuteCase(Radian(30.toRadian), Radian(30.toRadian)),
    _AcuteCase(Radian(330.toRadian), Radian(30.toRadian)),
    // 45
    _AcuteCase(Radian(45.toRadian), Radian(45.toRadian)),
    _AcuteCase(Radian(315.toRadian), Radian(45.toRadian)),
    // 60
    _AcuteCase(Radian(60.toRadian), Radian(60.toRadian)),
    _AcuteCase(Radian(300.toRadian), Radian(60.toRadian)),
    // 90
    _AcuteCase(Radian(90.toRadian), Radian(90.toRadian)),
    _AcuteCase(Radian(270.toRadian), Radian(90.toRadian)),
    // 120
    _AcuteCase(Radian(120.toRadian), Radian(120.toRadian)),
    _AcuteCase(Radian(240.toRadian), Radian(120.toRadian)),
    // 135
    _AcuteCase(Radian(135.toRadian), Radian(135.toRadian)),
    _AcuteCase(Radian(225.toRadian), Radian(135.toRadian)),
    // 150
    _AcuteCase(Radian(150.toRadian), Radian(150.toRadian)),
    _AcuteCase(Radian(210.toRadian), Radian(150.toRadian)),
    // 180
    _AcuteCase(Radian(180.toRadian), Radian(180.toRadian)),
  ];
}

void main() {
  group('angle', () {
    test('leastCoterminal', () {
      for (final test in _AcuteCase.cases) {
        expect(
          test.angle.leastCoterminal.value,
          closeTo(test.acute.value, 1e-3),
          reason: 'for angle: ${test.angle.toDegree}',
        );
      }
    });
  });
}
