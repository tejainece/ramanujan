import 'package:ramanujan/src/segment/region.dart';

abstract class LiveOperation {
  const LiveOperation();
  Region apply(Region input);
}

class LiveRegion {
  Region _source;
  List<LiveOperation> _operations = const [];
  Region? _cachedResult;

  LiveRegion(this._source);

  Region get source => _source;

  set source(Region value) {
    if (_source == value) return;
    _source = value;
    _invalidate();
  }

  Region get evaluated {
    if (_cachedResult != null) return _cachedResult!;

    Region current = _source;
    for (final op in _operations) {
      current = op.apply(current);
    }
    _cachedResult = current;
    return _cachedResult!;
  }

  List<LiveOperation> get operations => _operations;

  set operations(List<LiveOperation> ops) {
    _operations = List.unmodifiable(ops);
    _invalidate();
  }

  void addOperation(LiveOperation op) {
    _operations = List.unmodifiable([..._operations, op]);
    _invalidate();
  }

  void removeOperation(LiveOperation op) {
    final newList = _operations.toList();
    if (newList.remove(op)) {
      _operations = List.unmodifiable(newList);
      _invalidate();
    }
  }

  void updateOperation(int index, LiveOperation op) {
    final newList = _operations.toList();
    newList[index] = op;
    _operations = List.unmodifiable(newList);
    _invalidate();
  }

  void _invalidate() {
    _cachedResult = null;
  }
}
