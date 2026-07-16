import 'package:vector_math/vector_math.dart';
import 'package:ramanujan/ramanujan.dart';

extension Affine2dVMExt on Affine2d {
  Matrix3 get matrix3 {
    return Matrix3(
      scaleX,
      shearY,
      0,
      shearX,
      scaleY,
      0,
      translateX,
      translateY,
      1,
    );
  }
}

extension Matrix3VMExt on Matrix3 {
  String get pretty {
    return '''[${this[0]}, ${this[3]}, ${this[6]}
[${this[1]}, ${this[4]}, ${this[7]}
[${this[2]}, ${this[5]}, ${this[8]}]''';
  }

  Affine2d get affine {
    // TODO check that this is affine
    if (!this[2].equals(0)) throw Exception('(2,0) != 0');
    if (!this[5].equals(0)) throw Exception('(2,1) != 0');
    if (!this[8].equals(1)) throw Exception('(2,2) != 1');
    return Affine2d(
      scaleX: this[0],
      shearX: this[3],
      scaleY: this[4],
      shearY: this[1],
      translateX: this[6],
      translateY: this[7],
    );
  }
}
