import 'dart:math';
import 'dart:typed_data';

import 'package:ramanujan/src/primitive/primitive.dart';

/// [ scaleX shearX translateX ]
/// [ shearY scaleY translateY ]
/// [    0     0        1      ]
class Affine2d {
  final double scaleX, shearY, shearX, scaleY, translateX, translateY;

  Affine2d(
      {this.scaleX = 1,
      this.shearX = 0,
      this.translateX = 0,
      this.scaleY = 1,
      this.shearY = 0,
      this.translateY = 0});

  factory Affine2d.scaler(double s) => Affine2d(scaleX: s, scaleY: s);

  factory Affine2d.rotator(double angle) => Affine2d(
        scaleX: cos(angle),
        shearX: -sin(angle),
        scaleY: cos(angle),
        shearY: sin(angle),
      );

  factory Affine2d.fromMatrix(Float64List m) {
    assert(m.length == 9);
    assert(m[6] == 0);
    assert(m[7] == 0);
    assert(m[8] == 1);
    return Affine2d(
        scaleX: m[0],
        shearX: m[1],
        translateX: m[2],
        scaleY: m[3],
        shearY: m[4],
        translateY: m[5]);
  }

  factory Affine2d.fromMatrix4Cols(Float64List m) {
    assert(m.length == 16);

    assert(m[2] == 0);
    assert(m[6] == 0);
    assert(m[10] == 1);

    assert(m[8] == 0);
    assert(m[9] == 0);
    assert(m[14] == 0);

    assert(m[3] == 0);
    assert(m[7] == 0);
    assert(m[11] == 0);
    assert(m[15] == 1);
    return Affine2d(
        scaleX: m[0],
        shearX: m[4],
        translateX: m[12],
        shearY: m[1],
        scaleY: m[5],
        translateY: m[13]);
  }

  Affine2d scale(double sx, double sy) => Affine2d(
      scaleX: scaleX * sx,
      shearX: shearX * sy,
      scaleY: scaleY * sy,
      shearY: shearY * sx,
      translateX: translateX,
      translateY: translateY);

  Affine2d translate(double tx, double ty) => Affine2d(
        scaleX: scaleX,
        scaleY: scaleY,
        shearX: shearX,
        shearY: shearY,
        translateX: scaleX * tx + shearX * ty + translateX,
        translateY: shearY * tx + scaleY * ty + translateY,
      );

  Affine2d rotate(double angle) => Affine2d(
      scaleX: scaleX * cos(angle) + shearX * sin(angle),
      shearX: scaleX * -sin(angle) + shearX * cos(angle),
      shearY: shearY * cos(angle) + scaleY * sin(angle),
      scaleY: shearY * -sin(angle) + scaleY * cos(angle),
      translateX: translateX,
      translateY: translateY);

  late final double det = scaleX * scaleY - shearX * shearY;

  /// True when the linear part is a (possibly reflected) similarity —
  /// rotation plus uniform scale, no skew — so circles map to circles.
  bool get isSimilarity {
    final n1 = scaleX * scaleX + shearY * shearY;
    final n2 = shearX * shearX + scaleY * scaleY;
    final dot = scaleX * shearX + shearY * scaleY;
    final magnitude = n1 + n2;
    return (n1 - n2).abs() <= 1e-9 * magnitude &&
        dot.abs() <= 1e-9 * magnitude;
  }

  /// The ellipse that this transform's linear part maps the unit circle to:
  /// semi-axis lengths (major axis first) and the major-axis angle.
  ///
  /// Computed from the eigen-decomposition of M·Mᵀ, whose eigenvalues are the
  /// squared singular values of M and whose leading eigenvector points along
  /// the major axis.
  ({P radii, double rotation}) get unitCircleImage {
    final m00 = scaleX * scaleX + shearX * shearX;
    final m01 = scaleX * shearY + shearX * scaleY;
    final m11 = shearY * shearY + scaleY * scaleY;
    final mean = (m00 + m11) / 2;
    final diff = (m00 - m11) / 2;
    final spread = sqrt(diff * diff + m01 * m01);
    final major = sqrt(max(mean + spread, 0));
    final minor = sqrt(max(mean - spread, 0));
    final rotation = atan2(2 * m01, m00 - m11) / 2;
    return (radii: P(major, minor), rotation: rotation);
  }

  Float64List get cofactor => Float64List.fromList([
        scaleY, -shearY, 0, // row1
        -shearX, scaleX, 0, // row2
        shearX * translateY - scaleY * translateX,
        -scaleX * translateY + shearY * translateX,
        scaleX * scaleY - shearX * shearY,
      ]);

  Float64List get adjoint => Float64List.fromList([
        scaleY, -shearX, shearX * translateY - scaleY * translateX, // row1
        -shearY, scaleX, -scaleX * translateY + shearY * translateX, // row2
        0, 0, scaleX * scaleY - shearX * shearY, // row3
      ]);

  Affine2d inverse() => Affine2d(
      scaleX: scaleY / det,
      shearX: -shearX / det,
      translateX: (shearX * translateY - scaleY * translateX) / det,
      shearY: -shearY / det,
      scaleY: scaleX / det,
      translateY: (-scaleX * translateY + shearY * translateX) / det);

  Affine2d withTranslate(double tx, double ty) {
    return Affine2d(
        scaleX: scaleX,
        scaleY: scaleY,
        shearX: shearX,
        shearY: shearY,
        translateX: tx,
        translateY: ty);
  }

  /// Applies the affine transformation to the [point].
  P apply(P point) => point.transform(this);

  Float64List get matrix => Float64List.fromList(_list);

  Float64List get matrixColMajor => Float64List.fromList([
        scaleX, shearY, 0, // row1
        shearX, scaleY, 0, // row2
        translateX, translateY, 1, // row3
      ]);

  Float64List get matrix4d => Float64List.fromList([
        scaleX, shearX, 0, translateX, // row1
        shearY, scaleY, 0, translateY, // row2
        0, 0, 1, 0, // row3
        0, 0, 0, 1, // row4
      ]);

  Float64List get matrix4dColMajor => Float64List.fromList([
        scaleX, shearY, 0, 0, // col1
        shearX, scaleY, 0, 0, // col2
        0, 0, 1, 0, // col3
        translateX, translateY, 0, 1, // col4
      ]);

  Affine2d operator *(value) {
    if (value is num) {
      return Affine2d(
        scaleX: scaleX * value,
        shearX: shearX * value,
        scaleY: scaleY * value,
        shearY: shearY * value,
        translateX: translateX * value,
        translateY: translateY * value,
      );
    } else if (value is Affine2d) {
      return Affine2d(
        scaleX: scaleX * value.scaleX + shearX * value.shearY,
        shearX: scaleX * value.shearX + shearX * value.scaleY,
        translateX:
            scaleX * value.translateX + shearX * value.translateY + translateX,
        shearY: shearY * value.scaleX + scaleY * value.shearY,
        scaleY: shearY * value.shearX + scaleY * value.scaleY,
        translateY:
            shearY * value.translateX + scaleY * value.translateY + translateY,
      );
    }
    throw UnsupportedError(
        'Type ${value.runtimeType} not supported for matrix multiplication');
  }

  late final _list = <double>[
    scaleX, shearX, translateX, // row1
    shearY, scaleY, translateY, // row2
    0, 0, 1, // row3
  ];

  double elementAt(int n) => _list[n];

  @override
  String toString() {
    final sb = StringBuffer();
    sb.write('[ $scaleX $shearX $translateX ]\n');
    sb.write('[ $shearY $scaleY $translateY ]\n');
    sb.write('[ 0 0 1 ]');
    return sb.toString();
  }
}

extension PointAffineExt on P {
  P transform(Affine2d affine) => P(
      affine.scaleX * x + affine.shearX * y + affine.translateX,
      affine.shearY * x + affine.scaleY * y + affine.translateY);
}
