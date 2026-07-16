import 'dart:math';

import 'package:test/test.dart';
import 'package:ramanujan/ramanujan.dart';

class _FixRadianCase {
  final double inpAngle;
  final double outAngle;

  _FixRadianCase(this.inpAngle, this.outAngle);

  static List<_FixRadianCase> get center0_2pi => [
    _FixRadianCase(-14 * pi / 4, 2 * pi / 4), // -630
    _FixRadianCase(-13 * pi / 4, 3 * pi / 4), // -585
    _FixRadianCase(-12 * pi / 4, 4 * pi / 4), // -540
    _FixRadianCase(-11 * pi / 4, -3 * pi / 4), // -495
    _FixRadianCase(-10 * pi / 4, -2 * pi / 4), // -450
    _FixRadianCase(-9 * pi / 4, -1 * pi / 4), // -405
    _FixRadianCase(-8 * pi / 4, 0 * pi / 4), // -360
    _FixRadianCase(-7 * pi / 4, 1 * pi / 4), // -315
    _FixRadianCase(-6 * pi / 4, 2 * pi / 4), // -270
    _FixRadianCase(-5 * pi / 4, 3 * pi / 4), // -225
    _FixRadianCase(-4 * pi / 4, 4 * pi / 4), // -180
    _FixRadianCase(-3 * pi / 4, -3 * pi / 4), // -135
    _FixRadianCase(-2 * pi / 4, -2 * pi / 4), // -90
    _FixRadianCase(-1 * pi / 4, -1 * pi / 4), // -45
    _FixRadianCase(0 * pi / 4, 0 * pi / 4), // 0
    _FixRadianCase(1 * pi / 4, 1 * pi / 4), // 45
    _FixRadianCase(2 * pi / 4, 2 * pi / 4), // 90
    _FixRadianCase(3 * pi / 4, 3 * pi / 4), // 135
    _FixRadianCase(4 * pi / 4, 4 * pi / 4), // 180
    _FixRadianCase(5 * pi / 4, -3 * pi / 4), // 225
    _FixRadianCase(6 * pi / 4, -2 * pi / 4), // 270
    _FixRadianCase(7 * pi / 4, -1 * pi / 4), // 315
    _FixRadianCase(8 * pi / 4, 0 * pi / 4), // 360
    _FixRadianCase(9 * pi / 4, 1 * pi / 4), // 405
    _FixRadianCase(10 * pi / 4, 2 * pi / 4), // 450
    _FixRadianCase(11 * pi / 4, 3 * pi / 4), // 495
    _FixRadianCase(12 * pi / 4, 4 * pi / 4), // 540
    _FixRadianCase(13 * pi / 4, -3 * pi / 4), // 585
    _FixRadianCase(14 * pi / 4, -2 * pi / 4), // 630
  ];

  // ignore: non_constant_identifier_names
  static List<_FixRadianCase> get center0_pi => [
    _FixRadianCase(-14 * pi / 4, 2 * pi / 4), // -630
    _FixRadianCase(-13 * pi / 4, -1 * pi / 4), // -585
    _FixRadianCase(-12 * pi / 4, 0 * pi / 4), // -540
    _FixRadianCase(-11 * pi / 4, 1 * pi / 4), // -495
    _FixRadianCase(-10 * pi / 4, 2 * pi / 4), // -450
    _FixRadianCase(-9 * pi / 4, -1 * pi / 4), // -405
    _FixRadianCase(-8 * pi / 4, 0 * pi / 4), // -360
    _FixRadianCase(-7 * pi / 4, 1 * pi / 4), // -315
    _FixRadianCase(-6 * pi / 4, 2 * pi / 4), // -270
    _FixRadianCase(-5 * pi / 4, -1 * pi / 4), // -225
    _FixRadianCase(-4 * pi / 4, 0 * pi / 4), // -180
    _FixRadianCase(-3 * pi / 4, 1 * pi / 4), // -135
    _FixRadianCase(-2 * pi / 4, 2 * pi / 4), // -90
    _FixRadianCase(-1 * pi / 4, -1 * pi / 4), // -45
    _FixRadianCase(0 * pi / 4, 0 * pi / 4), // 0
    _FixRadianCase(1 * pi / 4, 1 * pi / 4), // 45
    _FixRadianCase(2 * pi / 4, 2 * pi / 4), // 90
    _FixRadianCase(3 * pi / 4, -1 * pi / 4), // 135
    _FixRadianCase(4 * pi / 4, 0 * pi / 4), // 180
    _FixRadianCase(5 * pi / 4, 1 * pi / 4), // 225
    _FixRadianCase(6 * pi / 4, 2 * pi / 4), // 270
    _FixRadianCase(7 * pi / 4, -1 * pi / 4), // 315
    _FixRadianCase(8 * pi / 4, 0 * pi / 4), // 360
    _FixRadianCase(9 * pi / 4, 1 * pi / 4), // 405
    _FixRadianCase(10 * pi / 4, 2 * pi / 4), // 450
    _FixRadianCase(11 * pi / 4, -1 * pi / 4), // 495
    _FixRadianCase(12 * pi / 4, 0 * pi / 4), // 540
    _FixRadianCase(13 * pi / 4, 1 * pi / 4), // 585
    _FixRadianCase(14 * pi / 4, 2 * pi / 4), // 630
  ];

  static List<_FixRadianCase> get simple_2pi => [
    _FixRadianCase(-14 * pi / 4, 2 * pi / 4),
    _FixRadianCase(-13 * pi / 4, 3 * pi / 4),
    _FixRadianCase(-12 * pi / 4, 4 * pi / 4),
    _FixRadianCase(-11 * pi / 4, 5 * pi / 4),
    _FixRadianCase(-10 * pi / 4, 6 * pi / 4),
    _FixRadianCase(-9 * pi / 4, 7 * pi / 4),
    _FixRadianCase(-8 * pi / 4, 0 * pi / 4),
    _FixRadianCase(-7 * pi / 4, 1 * pi / 4),
    _FixRadianCase(-6 * pi / 4, 2 * pi / 4),
    _FixRadianCase(-5 * pi / 4, 3 * pi / 4),
    _FixRadianCase(-4 * pi / 4, 4 * pi / 4),
    _FixRadianCase(-3 * pi / 4, 5 * pi / 4),
    _FixRadianCase(-2 * pi / 4, 6 * pi / 4),
    _FixRadianCase(-1 * pi / 4, 7 * pi / 4),
    _FixRadianCase(0 * pi / 4, 0 * pi / 4),
    _FixRadianCase(1 * pi / 4, 1 * pi / 4),
    _FixRadianCase(2 * pi / 4, 2 * pi / 4),
    _FixRadianCase(3 * pi / 4, 3 * pi / 4),
    _FixRadianCase(4 * pi / 4, 4 * pi / 4),
    _FixRadianCase(5 * pi / 4, 5 * pi / 4),
    _FixRadianCase(6 * pi / 4, 6 * pi / 4),
    _FixRadianCase(7 * pi / 4, 7 * pi / 4),
    _FixRadianCase(8 * pi / 4, 0 * pi / 4),
    _FixRadianCase(9 * pi / 4, 1 * pi / 4),
    _FixRadianCase(10 * pi / 4, 2 * pi / 4),
    _FixRadianCase(11 * pi / 4, 3 * pi / 4),
    _FixRadianCase(12 * pi / 4, 4 * pi / 4),
    _FixRadianCase(13 * pi / 4, 5 * pi / 4),
    _FixRadianCase(14 * pi / 4, 6 * pi / 4),
  ];

  // ignore: non_constant_identifier_names
  static List<_FixRadianCase> get simple_pi => [
    _FixRadianCase(-14 * pi / 4, 2 * pi / 4),
    _FixRadianCase(-13 * pi / 4, 3 * pi / 4),
    _FixRadianCase(-12 * pi / 4, 0 * pi / 4),
    _FixRadianCase(-11 * pi / 4, 1 * pi / 4),
    _FixRadianCase(-10 * pi / 4, 2 * pi / 4),
    _FixRadianCase(-9 * pi / 4, 3 * pi / 4),
    _FixRadianCase(-8 * pi / 4, 0 * pi / 4),
    _FixRadianCase(-7 * pi / 4, 1 * pi / 4),
    _FixRadianCase(-6 * pi / 4, 2 * pi / 4),
    _FixRadianCase(-5 * pi / 4, 3 * pi / 4),
    _FixRadianCase(-4 * pi / 4, 0 * pi / 4), // -180
    _FixRadianCase(-3 * pi / 4, 1 * pi / 4), // -135
    _FixRadianCase(-2 * pi / 4, 2 * pi / 4), // -90
    _FixRadianCase(-1 * pi / 4, 3 * pi / 4), // -45
    _FixRadianCase(0 * pi / 4, 0 * pi / 4), // 0
    _FixRadianCase(1 * pi / 4, 1 * pi / 4), // 45
    _FixRadianCase(2 * pi / 4, 2 * pi / 4), // 90
    _FixRadianCase(3 * pi / 4, 3 * pi / 4), // 135
    _FixRadianCase(4 * pi / 4, 0 * pi / 4), // 180
    _FixRadianCase(5 * pi / 4, 1 * pi / 4), // 225
    _FixRadianCase(6 * pi / 4, 2 * pi / 4), // 270
    _FixRadianCase(7 * pi / 4, 3 * pi / 4), // 315
    _FixRadianCase(8 * pi / 4, 0 * pi / 4), // 360
    _FixRadianCase(9 * pi / 4, 1 * pi / 4), // 405
    _FixRadianCase(10 * pi / 4, 2 * pi / 4), // 450
    _FixRadianCase(11 * pi / 4, 3 * pi / 4), // 495
    _FixRadianCase(12 * pi / 4, 0 * pi / 4), // 540
    _FixRadianCase(13 * pi / 4, 1 * pi / 4), // 585
    _FixRadianCase(14 * pi / 4, 2 * pi / 4), // 630
  ];
}

void main() {
  group('angle', () {
    test('clampAngle.2pi', () {
      for (final test in _FixRadianCase.simple_2pi) {
        expect(
          test.inpAngle.clampAngle(),
          closeTo(test.outAngle, 1e-3),
          reason: 'wrong fixRadian for inpAngle: ${test.inpAngle.toDegree}',
        );
      }
    });
    test('clampAngle.pi', () {
      for (final test in _FixRadianCase.simple_pi) {
        expect(
          test.inpAngle.clampAngle(pi),
          closeTo(test.outAngle, 1e-3),
          reason: 'wrong fixRadian for inpAngle: ${test.inpAngle.toDegree}',
        );
      }
    });
    test('clampAngle0.2pi', () {
      for (final test in _FixRadianCase.center0_2pi) {
        expect(
          test.inpAngle.clampAngle0(2 * pi),
          closeTo(test.outAngle, 1e-3),
          reason: 'wrong fixRadian for inpAngle: ${test.inpAngle.toDegree}',
        );
      }
    });
    test('clampAngle0.pi', () {
      for (final test in _FixRadianCase.center0_pi) {
        expect(
          test.inpAngle.clampAngle0(pi),
          closeTo(test.outAngle, 1e-3),
          reason: 'wrong fixRadian for inpAngle: ${test.inpAngle.toDegree}',
        );
      }
    });
  });
}
