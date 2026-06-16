import 'package:ramanujan/ramanujan.dart';

extension SegementIterableExt on Iterable<Segment> {
  String? validate() {
    if (isEmpty) return null;

    Segment prev = first;
    int index = 1;
    for (var segment in skip(1)) {
      if (prev.p2 != segment.p1) {
        return 'At index $index: ${prev.p2} != ${segment.p1}';
      }
      prev = segment;
      index++;
    }
    return null;
  }

  bool isClosed() {
    if (isEmpty) return false;
    return first.p1 == last.p2;
  }

  /// The polyline vertices of these (assumed contiguous) segments: the first
  /// segment's start followed by every segment's end. Inverse of
  /// [PointsLineSegmentExt.toLines].
  List<P> get polylinePoints {
    final it = iterator;
    if (!it.moveNext()) return [];
    final pts = [it.current.p1, it.current.p2];
    while (it.moveNext()) {
      pts.add(it.current.p2);
    }
    return pts;
  }

  VectorCurve toCurve() => VectorCurve(this);

  Iterable<Radian> angles() => pairs().map((v) => v.$1.line.angleTo(v.$2.line));

  bool isSame(Iterable<Segment> other) {
    final it1 = iterator;
    final it2 = other.iterator;

    while (true) {
      if (!it1.moveNext()) return !it2.moveNext();
      if (!it2.moveNext()) return false;

      if (it1.current != it2.current) return false;
    }
  }
}

extension SegementListExt on List<Segment> {
  List<Segment> expandWithControls(SegmentMapperWithControls mapper,
      {P? controlStart, P? controlEnd}) {
    // if (length < 2) return toList();

    final ret = <Segment>[];
    P cp1 = first.p1;
    if (controlStart != null) {
      cp1 = controlStart;
    }

    for (int i = 0; i < length - 1; i++) {
      final cur = this[i];
      final next = this[i + 1];
      ret.addAll(mapper(cp1, cur, next.p2));
      cp1 = cur.p1;
    }
    ret.addAll(mapper(cp1, last, controlEnd ?? last.p2));
    return ret;
  }
}

extension PolyLinesExt on Iterable<LineSegment> {}

extension PairsIterable<T> on Iterable<T> {
  Iterable<(T, T)> pairs() sync* {
    final it = iterator;
    if (!it.moveNext()) return;

    T prev = it.current;
    while (it.moveNext()) {
      final cur = it.current;
      yield (prev, cur);
      prev = cur;
    }
  }
}
