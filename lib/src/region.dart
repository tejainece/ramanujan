import 'dart:collection';

import 'package:ramanujan/ramanujan.dart';

/// Determines which regions enclosed by a [Region]'s loops are considered
/// inside the shape.
///
/// Corresponds to the SVG `fill-rule` presentation attribute.
/// See the winding spec (spec/boolean/winding.md) for a full explanation.
enum FillRule {
  /// A point is inside if a ray cast from it crosses the total boundary an
  /// odd number of times. Winding direction is ignored.
  ///
  /// SVG value: `evenodd`.
  evenOdd,

  /// A point is inside if the signed boundary-crossing count is non-zero:
  /// +1 when the boundary crosses the ray going one way, −1 the other.
  /// A sum of zero means outside.
  ///
  /// SVG default (`fill-rule="nonzero"`). Holes are encoded by drawing their
  /// loop in the opposite winding direction to the surrounding loop — the
  /// opposing signs cancel to zero inside the hole.
  nonZero,
}

/// A filled area in the plane: a flat collection of closed [Loop]s and a
/// [FillRule].
///
/// The fill rule determines which regions enclosed by the loops are
/// considered inside. There is no structural distinction between "outer" and
/// "hole" loops — that emerges from each loop's winding direction as
/// interpreted by the fill rule. See the winding spec for details.
///
/// Corresponds to an SVG `<path>` element whose sub-paths all close (`Z`)
/// and which carries a `fill-rule` attribute.
///
/// Boolean operations take two [Region]s and return a [Region].
class Region {
  final List<Loop> _loops;
  final FillRule fillRule;

  Region._(this._loops, this.fillRule);

  factory Region(
    Iterable<Loop> loops, {
    FillRule fillRule = FillRule.evenOdd,
  }) =>
      Region._(List.from(loops), fillRule);

  late final UnmodifiableListView<Loop> loops = UnmodifiableListView(_loops);

  bool get isEmpty => _loops.isEmpty;
  bool get isNotEmpty => _loops.isNotEmpty;

  /// Returns true if [point] is inside this region, according to [fillRule].
  ///
  /// Casts a horizontal ray rightward and aggregates crossings across all
  /// loops. For even-odd, counts crossings (odd = inside). For non-zero, sums
  /// signed contributions: upward boundary crossing = +1, downward = −1; a
  /// non-zero sum means inside. Near-equal x values (ray hitting a shared
  /// vertex) are grouped — their signs sum before contributing, so a
  /// tangential touch (opposite signs cancel) correctly counts as zero.
  bool contains(P point) {
    final ray =
        LineSegment(P(point.x - 1, point.y), P(point.x + 1e9, point.y));
    switch (fillRule) {
      case FillRule.evenOdd:
        final xs = <double>[];
        for (final loop in loops) {
          for (final seg in loop.segments) {
            for (final p in ray.intersect(seg)) {
              if (p.x > point.x) xs.add(p.x);
            }
          }
        }
        xs.sort();
        int count = 0;
        double? prev;
        for (final x in xs) {
          if (prev == null || (x - prev).abs() > 1e-9) count++;
          prev = x;
        }
        return count.isOdd;

      case FillRule.nonZero:
        final crossings = <(double, int)>[];
        for (final loop in loops) {
          for (final seg in loop.segments) {
            for (final p in ray.intersect(seg)) {
              if (p.x > point.x) {
                final sign = _crossingSign(seg, p);
                if (sign != 0) crossings.add((p.x, sign));
              }
            }
          }
        }
        crossings.sort((a, b) => a.$1.compareTo(b.$1));
        int winding = 0;
        int groupSign = 0;
        double? groupX;
        for (final (x, sign) in crossings) {
          if (groupX != null && (x - groupX!).abs() <= 1e-9) {
            groupSign += sign;
          } else {
            if (groupX != null) winding += groupSign.sign;
            groupX = x;
            groupSign = sign;
          }
        }
        if (groupX != null) winding += groupSign.sign;
        return winding != 0;
    }
  }

  /// Decomposes this compound region into separate, independent [Region]
  /// objects by classifying loop containment depths.
  ///
  /// Outermost boundaries (even containment depths) are grouped with their
  /// nested holes (odd containment depths). Nested outer islands (even depth >= 2)
  /// become separate independent regions.
  List<Region> separateDisconnected() {
    if (loops.isEmpty) return [];

    // 1. Compute interior points and absolute areas for all loops
    final interiorPoints = <Loop, P>{};
    final areas = <Loop, double>{};
    for (final loop in loops) {
      var area = 0.0;
      for (final s in loop.segments) {
        area += s.p1.x * s.p2.y - s.p2.x * s.p1.y;
      }
      areas[loop] = area.abs() / 2;
      final isCCW = area >= 0;
      final seg = loop.segments.first;
      final mid = seg.lerp(0.5);
      final normal = seg.unitNormalAt(0.5, cw: !isCCW);
      interiorPoints[loop] = mid + normal * 1e-4;
    }

    // 2. Classify nesting depths
    final depthMap = <Loop, int>{};

    for (final l1 in loops) {
      int depth = 0;
      for (final l2 in loops) {
        if (l1 == l2) continue;
        if (l2.contains(interiorPoints[l1]!) && areas[l1]! < areas[l2]!) {
          depth++;
        }
      }
      depthMap[l1] = depth;
    }

    // 3. Separate outer loops (even depth) and inner loops (odd depth)
    final outerLoops = loops.where((l) => depthMap[l]!.isEven).toList();
    final innerLoops = loops.where((l) => depthMap[l]!.isOdd).toList();

    // 4. For each outer loop, group it with its innermost containing outer loop
    final groups = <Loop, List<Loop>>{};
    for (final outer in outerLoops) {
      groups[outer] = [outer];
    }

    for (final inner in innerLoops) {
      Loop? parentOuter;
      int maxDepth = -1;

      for (final outer in outerLoops) {
        if (outer.contains(interiorPoints[inner]!) && areas[inner]! < areas[outer]!) {
          final depth = depthMap[outer]!;
          if (depth > maxDepth) {
            maxDepth = depth;
            parentOuter = outer;
          }
        }
      }

      if (parentOuter != null) {
        groups[parentOuter]!.add(inner);
      } else {
        groups[inner] = [inner];
      }
    }

    // 5. Build and return the regions
    return groups.values
        .map((g) => Region(g, fillRule: fillRule))
        .toList();
  }
}

/// Returns +1 if [seg] travels upward (decreasing Y) at [crossingPoint],
/// −1 if downward, 0 if horizontal. Used by [Region.contains] for non-zero
/// winding. Direction is determined by a short finite-difference sample.
int _crossingSign(Segment seg, P crossingPoint) {
  final t = seg.ilerp(crossingPoint);
  if (t.isNaN) return 0;
  const eps = 1e-4;
  final before = seg.lerp((t - eps).clamp(0.0, 1.0));
  final after = seg.lerp((t + eps).clamp(0.0, 1.0));
  final dy = after.y - before.y;
  if (dy < 0) return 1;
  if (dy > 0) return -1;
  return 0;
}
