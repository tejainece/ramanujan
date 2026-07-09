import 'package:ramanujan/src/segment/live_region.dart';
import 'package:ramanujan/src/segment/region.dart';
import 'package:ramanujan/src/corner/corner.dart';

class CornerOperation extends LiveOperation {
  /// Maps vertex index to corner radius. If an index is not in the map,
  /// the [defaultRadius] is used (if greater than 0).
  final Map<int, double> radii;
  final double defaultRadius;

  const CornerOperation({
    this.radii = const {},
    this.defaultRadius = 0.0,
  });

  CornerOperation copyWith({
    Map<int, double>? radii,
    double? defaultRadius,
  }) {
    return CornerOperation(
      radii: radii ?? this.radii,
      defaultRadius: defaultRadius ?? this.defaultRadius,
    );
  }

  @override
  Region apply(Region input) {
    if (radii.isEmpty && defaultRadius <= 0) return input;

    final resultLoops = <Loop>[];
    for (final loop in input.loops) {
      // Loop is a VectorPath. We can apply roundAllCorners.
      // Currently, roundAllCorners supports either `radius` or `radii` array (one per junction).
      // Since our map gives per-vertex indices, we can construct the radii list for the loop.
      final junctionCount = loop.segments.length;
      final loopRadii = <double>[];
      for (int i = 0; i < junctionCount; i++) {
        // Here we assume the vertex index maps directly to the junction index.
        // If the region has multiple loops, the indexing might be more complex,
        // but for simplicity, we'll assume it's per-loop or we just use defaultRadius for now.
        // Let's implement it with defaultRadius first, and if radii is provided, use it.
        loopRadii.add(radii[i] ?? defaultRadius);
      }

      final rounded = roundAllCorners(
        loop,
        CornerStyle.circularArc,
        radii: loopRadii,
      );
      
      if (rounded is Loop) {
        resultLoops.add(rounded);
      } else {
        // Should be a loop since we passed a loop
        resultLoops.add(Loop(rounded.segments));
      }
    }
    
    return Region(resultLoops, fillRule: input.fillRule);
  }
}
