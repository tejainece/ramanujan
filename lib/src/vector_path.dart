import 'dart:collection';

import 'package:ramanujan/ramanujan.dart';

export 'segments.dart';

class VectorPath {
  final List<Segment> _segments;

  VectorPath._(this._segments) {
    // TODO verify that, each segment's p2 is next segment's p1
  }

  factory VectorPath(Iterable<Segment> segments) {
    return VectorPath._(List.from(segments));
  }

  late final UnmodifiableListView<Segment> segments =
      UnmodifiableListView(_segments);

  int get numSegments => _segments.length;

  bool get isEmpty => _segments.isEmpty;

  bool get isNotEmpty => _segments.isNotEmpty;

  bool isClosed() => _segments.isClosed();

  VectorPath expand(SegmentMapper mapper) =>
      VectorPath(_segments.expand(mapper));

  VectorPath expandWithControls(SegmentMapperWithControls mapper,
      {P? controlStart, P? controlEnd}) {
    final newSegments = _segments.expandWithControls(mapper,
        controlStart: controlStart, controlEnd: controlEnd);
    return VectorPath(newSegments);
  }

// TODO split into sub paths

  /// Returns the segment that preceeds [index]. Handles [isClosed] correctly.
  Segment? getPreviousOf(int index) {
    if (index.isNegative || index >= _segments.length) {
      throw ArgumentError.value(
          index, 'index', 'Out of range 0..${_segments.length - 1}');
    }
    if (index > 0) return _segments[index - 1];
    return isClosed() ? _segments.last : null;
  }

  /// Returns the segment that follows [index]. Handles [isClosed] correctly.
  Segment? getNextOf(int index) {
    if (index.isNegative || index >= _segments.length) {
      throw ArgumentError.value(
          index, 'index', 'Out of range 0..${_segments.length - 1}');
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
          result.add(PathTangiblePoint(
              isEndPoint: addr.isEndPoint, addresses: [addr]));
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
    return VectorPath._(_segments.map((s) {
      final segUpdates = bySegment[s];
      return segUpdates != null ? s.updateByPointAddresses(segUpdates) : s;
    }).toList());
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
