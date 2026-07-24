import 'dart:collection';

import 'package:ramanujan/ramanujan.dart';

export 'segments.dart';

part 'loop.dart';

class VectorPath {
  final List<Segment> _segments;

  VectorPath._(this._segments) {
    for (int i = 0; i < _segments.length - 1; i++) {
      final cur = _segments[i];
      final next = _segments[i + 1];
      if (!cur.p2.isEqual(next.p1)) {
        throw ArgumentError(
          'the segments are not continuous at $i',
          '_segments',
        );
      }
    }
  }

  factory VectorPath(Iterable<Segment> segments) {
    return VectorPath._(List.from(segments));
  }

  late final UnmodifiableListView<Segment> segments = UnmodifiableListView(
    _segments,
  );

  int get numSegments => _segments.length;

  bool get isEmpty => _segments.isEmpty;

  bool get isNotEmpty => _segments.isNotEmpty;

  R get boundingBox {
    if (isEmpty) return R(0, 0, 0, 0); // Or handle as appropriate
    R result = _segments.first.boundingBox;
    for (int i = 1; i < _segments.length; i++) {
      result = result.include(_segments[i].boundingBox);
    }
    return result;
  }

  bool isClosed() => _segments.isClosed();

  /// Total arc length of all segments in this path.
  late final double length = _segments.fold(0.0, (sum, s) => sum + s.length);

  /// Whether [point] lies on any segment of this path, within [epsilon].
  bool isPointOn(P point, {double epsilon = 1e-3}) =>
      _segments.any((s) => s.isPointOn(point, epsilon: epsilon));

  /// The segment, parameter, and point on this path closest to [target].
  /// Returns `null` if this path has no segments.
  ({Segment segment, double t, P point})? closestPoint(P target) {
    if (isEmpty) return null;
    var bestSegment = _segments.first;
    var bestT = bestSegment.closestT(target);
    var best = bestSegment.lerp(bestT);
    var bestD = best.distanceTo(target);
    for (final s in _segments.skip(1)) {
      final t = s.closestT(target);
      final candidate = s.lerp(t);
      final d = candidate.distanceTo(target);
      if (d < bestD) {
        bestD = d;
        bestSegment = s;
        bestT = t;
        best = candidate;
      }
    }
    return (segment: bestSegment, t: bestT, point: best);
  }

  /// Trims [distance] of arc length off the end of this path, consuming
  /// whole trailing segments when [distance] runs past them so the trim
  /// point can traverse across intermediate segment junctions instead of
  /// clamping at the first one. Returns the surviving prefix path and the
  /// [Trim] at the landing point. If [distance] exceeds this path's length,
  /// the trim saturates at the path's start.
  (VectorPath, Trim) trimEnd(double distance) {
    final segs = segments;
    var remaining = distance;
    for (int i = segs.length - 1; i > 0; i--) {
      if (remaining <= segs[i].length) {
        final trimmed = segs[i].trimEnd(remaining);
        return (VectorPath([...segs.sublist(0, i), trimmed.kept]), trimmed);
      }
      remaining -= segs[i].length;
    }
    final trimmed = segs.first.trimEnd(remaining);
    return (VectorPath([trimmed.kept]), trimmed);
  }

  /// Trims [distance] of arc length off the start of this path. See
  /// [trimEnd].
  (VectorPath, Trim) trimStart(double distance) {
    final segs = segments;
    var remaining = distance;
    for (int i = 0; i < segs.length - 1; i++) {
      if (remaining <= segs[i].length) {
        final trimmed = segs[i].trimStart(remaining);
        return (VectorPath([trimmed.kept, ...segs.sublist(i + 1)]), trimmed);
      }
      remaining -= segs[i].length;
    }
    final trimmed = segs.last.trimStart(remaining);
    return (VectorPath([trimmed.kept]), trimmed);
  }

  /// Slices this path along its arc length.
  ///
  /// [startFraction] and [endFraction] are normalized in range [0.0, 1.0].
  /// [offsetFraction] shifts the starting position along the path.
  VectorPath trim(
    double startFraction,
    double endFraction, {
    double offsetFraction = 0.0,
  }) {
    if (isEmpty || length == 0) return VectorPath([]);

    final start = startFraction.clamp(0.0, 1.0);
    final end = endFraction.clamp(0.0, 1.0);
    if (start >= end) return VectorPath([]);

    if (start == 0.0 && end == 1.0 && (offsetFraction % 1.0 == 0.0)) {
      return this;
    }

    final totalLen = length;
    final isClosedPath = isClosed();

    if (isClosedPath) {
      final effStart = (start + offsetFraction) % 1.0;
      final normStart = effStart < 0 ? effStart + 1.0 : effStart;
      final span = end - start;
      if (span >= 1.0) return this;

      final d1 = normStart * totalLen;
      final d2 = d1 + span * totalLen;

      if (d2 <= totalLen) {
        return sliceByDistance(d1, d2);
      } else {
        final p1 = sliceByDistance(d1, totalLen);
        final p2 = sliceByDistance(0.0, d2 - totalLen);
        if (p1.isEmpty) return p2;
        if (p2.isEmpty) return p1;
        return VectorPath([...p1._segments, ...p2._segments]);
      }
    } else {
      final effStart = (start + offsetFraction).clamp(0.0, 1.0);
      final effEnd = (end + offsetFraction).clamp(0.0, 1.0);
      if (effStart >= effEnd) return VectorPath([]);
      return sliceByDistance(effStart * totalLen, effEnd * totalLen);
    }
  }

  /// Slices this path between absolute arc-length distances [startDistance]
  /// and [endDistance] in [0, length].
  VectorPath sliceByDistance(double startDistance, double endDistance) {
    if (startDistance >= endDistance || isEmpty || length == 0) {
      return VectorPath([]);
    }
    final resultSegments = <Segment>[];
    double accumulated = 0.0;

    for (final seg in _segments) {
      final segLen = seg.length;
      final segStart = accumulated;
      final segEnd = accumulated + segLen;
      accumulated = segEnd;

      if (segEnd <= startDistance || segStart >= endDistance) {
        continue;
      }

      final localD1 = (startDistance - segStart).clamp(0.0, segLen);
      final localD2 = (endDistance - segStart).clamp(0.0, segLen);
      if (localD1 >= localD2) continue;

      if (localD1 == 0.0 && localD2 == segLen) {
        resultSegments.add(seg);
      } else {
        final t1 = segLen > 0 ? seg.paramAtLength(localD1) : 0.0;
        final t2 = segLen > 0 ? seg.paramAtLength(localD2) : 1.0;
        final sliced = seg.slice(t1, t2);
        if (sliced != null) {
          resultSegments.add(sliced);
        }
      }
    }
    return VectorPath(resultSegments);
  }

  VectorPath expand(SegmentMapper mapper) =>
      VectorPath(_segments.expand(mapper));

  /// This path with every segment mapped through [affine].
  VectorPath transform(Affine2d affine) =>
      VectorPath(_segments.map((s) => s.transform(affine)));

  VectorPath expandWithControls(
    SegmentMapperWithControls mapper, {
    P? controlStart,
    P? controlEnd,
  }) {
    final newSegments = _segments.expandWithControls(
      mapper,
      controlStart: controlStart,
      controlEnd: controlEnd,
    );
    return VectorPath(newSegments);
  }

  // TODO split into sub paths

  /// Returns the segment that preceeds [index]. Handles [isClosed] correctly.
  Segment? getPreviousOf(int index) {
    if (index.isNegative || index >= _segments.length) {
      throw ArgumentError.value(
        index,
        'index',
        'Out of range 0..${_segments.length - 1}',
      );
    }
    if (index > 0) return _segments[index - 1];
    return isClosed() ? _segments.last : null;
  }

  /// Returns the segment that follows [index]. Handles [isClosed] correctly.
  Segment? getNextOf(int index) {
    if (index.isNegative || index >= _segments.length) {
      throw ArgumentError.value(
        index,
        'index',
        'Out of range 0..${_segments.length - 1}',
      );
    }
    if (index < _segments.length - 1) return _segments[index + 1];
    return isClosed() ? _segments.first : null;
  }

  List<PathTangiblePoint> getTangiblePoints() {
    final result = <PathTangiblePoint>[];
    for (int i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      final prev = getPreviousOf(i);
      for (final addr in seg.getPointAddresses()) {
        // Merge p1 with the previous segment's p2 when they share the same position.
        // result.isNotEmpty guards against i==0 on a closed path where prev!=null
        // but the last segment hasn't been added yet.
        if (addr.name == PointId.p1 &&
            result.isNotEmpty &&
            prev != null &&
            prev.p2.isEqual(seg.p1)) {
          result.last.addresses.add(addr);
        } else {
          result.add(
            PathTangiblePoint(isEndPoint: addr.isEndPoint, addresses: [addr]),
          );
        }
      }
    }
    // For a closed path, merge the last segment's p2 into the first p1 entry
    // if they occupy the same position.
    if (isClosed() &&
        result.length >= 2 &&
        _segments.last.p2.isEqual(_segments.first.p1)) {
      result.first.addresses.addAll(result.last.addresses);
      result.removeLast();
    }
    return result;
  }

  VectorPath updateByTangiblePoints(Map<TangiblePointAddress, P> updates) {
    final bySegment = <Segment, Map<TangiblePointAddress, P>>{};
    for (final e in updates.entries) {
      bySegment.putIfAbsent(e.key.segment, () => {})[e.key] = e.value;
    }
    return VectorPath._(
      _segments.map((s) {
        final segUpdates = bySegment[s];
        return segUpdates != null ? s.updateByPointAddresses(segUpdates) : s;
      }).toList(),
    );
  }
}

class TangiblePointAddress {
  final Segment segment;
  final PointId name;

  TangiblePointAddress({required this.segment, required this.name});

  P get point => segment.getPointByAddress(name);

  bool get isEndPoint => name == PointId.p1 || name == PointId.p2;

  @override
  bool operator ==(Object other) =>
      other is TangiblePointAddress &&
      identical(other.segment, segment) &&
      other.name == name;

  @override
  int get hashCode => Object.hash(identityHashCode(segment), name);
}

class PathTangiblePoint {
  /// If false, the tangible point is a control point of the segment.
  final bool isEndPoint;

  final List<TangiblePointAddress> addresses;

  PathTangiblePoint({required this.isEndPoint, required this.addresses});

  P get point => addresses.first.point;
}
