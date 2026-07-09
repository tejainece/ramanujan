import 'package:ramanujan/src/segment/vector_path.dart';

abstract class LivePathOperation {
  const LivePathOperation();
  VectorPath apply(VectorPath input);
}

class LivePath {
  VectorPath _source;
  List<LivePathOperation> _operations = const [];
  VectorPath? _cachedResult;

  LivePath(this._source);

  VectorPath get source => _source;

  set source(VectorPath value) {
    if (_source == value) return;
    _source = value;
    _invalidate();
  }

  VectorPath get evaluated {
    if (_cachedResult != null) return _cachedResult!;

    VectorPath current = _source;
    for (final op in _operations) {
      current = op.apply(current);
    }
    _cachedResult = current;
    return _cachedResult!;
  }

  List<LivePathOperation> get operations => _operations;

  set operations(List<LivePathOperation> ops) {
    _operations = List.unmodifiable(ops);
    _invalidate();
  }

  void addOperation(LivePathOperation op) {
    _operations = List.unmodifiable([..._operations, op]);
    _invalidate();
  }

  void removeOperation(LivePathOperation op) {
    final newList = _operations.toList();
    if (newList.remove(op)) {
      _operations = List.unmodifiable(newList);
      _invalidate();
    }
  }

  void updateOperation(int index, LivePathOperation op) {
    final newList = _operations.toList();
    newList[index] = op;
    _operations = List.unmodifiable(newList);
    _invalidate();
  }

  void _invalidate() {
    _cachedResult = null;
  }
}
