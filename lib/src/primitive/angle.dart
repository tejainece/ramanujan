import 'dart:math';

import 'package:ramanujan/src/primitive/clamp.dart';

extension NumAngleExt on num {
  double get toRadian => (this * pi) / 180;

  double get toDegree => (this * 180) / pi;

  double slopeToAngle([bool quadrant23 = false]) =>
      quadrant23 ? atan2(-this, -1) : atan2(this, 1);

  double get angleToSlope => tan(this);

  double clampAngle([double width = 2 * pi]) => toDouble() % width;

  double clampAngle0([double width = 2 * pi]) {
    double ret = toDouble() % width;
    double half = width / 2;
    if (ret <= half) return ret;
    return ret - width;
  }

  double slopeRotate(double radians) =>
      (sin(radians) + this * cos(radians)) /
          (cos(radians) - this * sin(radians));
}

extension DoubleAngleExt on double {
  bool equals(double other, [double epsilon = 1e-3]) {
    final diff = (this - other).abs();
    return diff < epsilon;
  }
}

sealed class Angle {
  const Angle();

  Clamp get clamp;

  double get value;

  Radian get toRadian;

  Degree get toDegree;

  Angle withClamp(Clamp clamp);

  Angle operator +(/* Angle | num */ other);

  Angle operator -(/* Angle | num */ other);

  bool operator <(Angle other);

  bool operator >(Angle other);

  double get slope;

  Angle get leastCoterminal;

  bool isEqualLeastCoterminals(Angle other, [double epsilon = 1e-3]);

  bool equals(Angle other, [double epsilon = 1e-3]);

  bool isParallelTo(Angle other, [double epsilon = 1e-3]);
}

class Radian extends Angle {
  @override
  final Clamp clamp;
  final double _value;

  const Radian(this._value, {this.clamp = Clamp.radian});

  @override
  double get value => clamp.clamp(_value);

  double get unclamped => _value;

  @override
  Radian withClamp(Clamp clamp) => Radian(value, clamp: clamp);

  @override
  Radian operator +(/* Angle | num */ other) {
    if (other is Angle) {
      other = other.toRadian;
      if (clamp != other.clamp) {
        other = other.withClamp(clamp);
      }
      return Radian(value + other.value, clamp: clamp);
    } else if (other is num) {
      return Radian(value + other, clamp: clamp);
    }
    throw UnsupportedError('unsupported type ${other.runtimeType}');
  }

  @override
  Radian operator -(/* Angle | num */ other) {
    if (other is Angle) {
      other = other.toRadian;
      if (clamp != other.clamp) {
        other = other.withClamp(clamp);
      }
      return Radian(value - other.value, clamp: clamp);
    } else if (other is num) {
      return Radian(value - other, clamp: clamp);
    }
    throw UnsupportedError('unsupported type ${other.runtimeType}');
  }

  @override
  bool operator <(Angle other) {
    other = other.toRadian;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return value < other.value;
  }

  bool operator <=(Angle other) {
    other = other.toRadian;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return value <= other.value;
  }

  @override
  bool operator >(Angle other) {
    other = other.toRadian;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return value > other.value;
  }

  bool operator >=(Angle other) {
    other = other.toRadian;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return value >= other.value;
  }

  @override
  Radian get leastCoterminal =>
      Radian(min(value, clamp.max - value), clamp: clamp);

  @override
  bool isEqualLeastCoterminals(Angle other, [double epsilon = 1e-3]) {
    other = other.toRadian;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return leastCoterminal.equals(other.leastCoterminal, epsilon);
  }

  @override
  bool equals(Angle other, [double epsilon = 1e-3]) {
    other = other.toRadian;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return clamp.areValuesEqual(_value, other.value, epsilon);
  }

  @override
  bool isParallelTo(Angle other, [double epsilon = 1e-3]) {
    other = other.toRadian;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    final diff = this - other;
    return diff.equals(Radian(0), epsilon) || diff.equals(Radian(pi), epsilon);
  }

  @override
  Radian get toRadian => this;

  @override
  Degree get toDegree =>
      Degree(value.toDegree, clamp: Clamp(clamp.width.toDegree, clamp.center0));

  @override
  double get slope => tan(_value);

  bool isBetweenCW(Radian start, Radian end) =>
      clamp.isBetweenCW(start.value, end.value, _value);

  bool isBetweenCCW(Radian start, Radian end) =>
      clamp.isBetweenCCW(start.value, end.value, _value);

  @override
  String toString({int? denom}) {
    double v = value / pi;
    if (denom != null) {
      final numerator = v * denom;
      if (!(numerator - numerator.round()).equals(0)) return _value.toString();
      if ((numerator - numerator.round()).equals(0)) {
        return '${numerator.round()}π/$denom';
      }
      return '$numeratorπ/$denom';
    } else {
      for (final factor in _factors) {
        final numerator = v * factor;
        if (!(numerator - numerator.round()).equals(0)) continue;
        return '${numerator.round()}π/$factor';
      }
    }
    // TODO
    return value.toString();
  }

  static final _factors = List
      .generate(9, (i) => 9 - i + 1)
      .reversed;
}

class Degree extends Angle {
  @override
  final Clamp clamp;
  final double _value;

  const Degree(this._value, {this.clamp = Clamp.degree});

  @override
  double get value => clamp.clamp(_value);

  double get unclamped => _value;

  @override
  Radian withClamp(Clamp clamp) => Radian(value, clamp: clamp);

  @override
  Degree operator +(/* Angle | num */ other) {
    if (other is Angle) {
      other = other.toDegree;
      if (clamp != other.clamp) {
        other = other.withClamp(clamp);
      }
      return Degree(value + other.value, clamp: clamp);
    } else if (other is num) {
      return Degree(value + other, clamp: clamp);
    }
    throw UnsupportedError('unsupported type ${other.runtimeType}');
  }

  @override
  Degree operator -(/* Angle | num */ other) {
    if (other is Angle) {
      other = other.toDegree;
      if (clamp != other.clamp) {
        other = other.withClamp(clamp);
      }
      return Degree(value - other.value, clamp: clamp);
    } else if (other is num) {
      return Degree(value - other, clamp: clamp);
    }
    throw UnsupportedError('unsupported type ${other.runtimeType}');
  }

  @override
  bool operator <(Angle other) {
    other = other.toDegree;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return value < other.value;
  }

  @override
  bool operator >(Angle other) {
    other = other.toDegree;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return value > other.value;
  }

  @override
  Degree get leastCoterminal =>
      Degree(min(value, clamp.max - value), clamp: clamp);

  @override
  bool isEqualLeastCoterminals(Angle other, [double epsilon = 1e-3]) {
    other = other.toDegree;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return leastCoterminal.equals(other.leastCoterminal, epsilon);
  }

  @override
  bool equals(Angle other, [double epsilon = 1e-3]) {
    other = other.toDegree;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    return value.equals(other.value, epsilon);
  }

  @override
  bool isParallelTo(Angle other, [double epsilon = 1e-3]) {
    other = other.toDegree;
    if (clamp != other.clamp) {
      other = other.withClamp(clamp);
    }
    final diff = this - other;
    return diff.equals(Degree(0), epsilon) || diff.equals(Degree(180), epsilon);
  }

  @override
  Radian get toRadian =>
      Radian(value.toRadian, clamp: Clamp(clamp.width.toRadian, clamp.center0));

  @override
  Degree get toDegree => this;

  @override
  double get slope => tan(_value.toRadian);

  @override
  String toString() => '$value°';
}
