# Ramanujan

Ramanujan is a robust, pure-Dart 2D vector geometry library designed to construct, manipulate, and query complex vector paths consisting of lines, circular arcs, elliptical arcs, and quadratic or cubic Bézier curves. The library prefers exact analytical methods wherever possible (such as closed-form algebraic solvers) to ensure maximum precision and performance, resorting to numerical approximation only when closed-form solutions do not exist.

## Features

### 1. Vector Primitives & Geometry
* **`P` (Point)**: 2D coordinate class with utility operators, scaling, distance, rotation, normalization, and line creation helpers.
* **`R` (Rectangle)**: Axis-aligned rectangle with support for intersection, containment, perimeter, area, inflation/deflation, and offset shift.
* **`Angle` / `Radian` / `Degree`**: Strongly-typed angle system with bounds wrapping, normalization, and comparisons.
* **`Circle` & `Ellipse`**: Circular and elliptical shapes supporting point containment, parameter evaluation, bounding boxes, and least-squares fitting from points.
* **`Affine2D`**: 2D affine transformations (translate, scale, rotate, skew, invert) applicable to points and segment geometry.

### 2. Parametric Segments
* **Abstract `Segment` base class** with implementations for:
  * `LineSegment`
  * `CircularArcSegment`
  * `ArcSegment` (elliptical arcs)
  * `QuadraticSegment`
  * `CubicSegment`
* **Mathematical Operations**:
  * Analytical evaluation of parameter space: length, unit tangents, unit normals.
  * Intersection between any two segment types (e.g. cubic-to-circle, line-to-arc).
  * Parameter projection (`ilerp` to locate a point's parameter `t` on a segment).
  * Segment bifurcation/splitting (`bifurcateAtInterval` or splitting into N parts).
  * Coincidence overlap analysis (`coincidentOverlap`).

### 3. Vector Paths & Loops
* **`VectorPath`**: A contiguous chain of segments. Supports expanding segments via custom mappers and querying neighbor segments.
* **`Loop`**: A closed `VectorPath` contour enforcing closedness at construction. Includes an efficient point-in-polygon containment test (`contains`) using even-odd ray casting.
* **`PathTangiblePoint` & `TangiblePointAddress`**: Programmatic path editing interface to locate and update endpoints and control points.

### 4. Path Operations & Boolean Logic
* **Polygon-clipping pipeline** supporting boolean operations on regions:
  * **`PathUnion`**: Merge overlapping regions.
  * **`PathIntersection`**: Extract overlapping regions.
  * **`PathDifference`**: Subtract one region from another.
  * **`PathXor`**: Symmetric difference of two regions.
  * **`PathDivision`**: Splits a region into intersecting and non-intersecting sub-regions.
  * **`PathFracture`**: Splits overlapping regions into disjoint parts.
  * **`PathFlatten`**: Merges overlapping regions into non-overlapping flat shapes.
* **`Region`**: Represents a shape composed of multiple loops, handling hole nesting and disjoint separation.
* **`simplifyClosedPath`**: Snaps/force-closes open endpoints, and decomposes self-intersecting loops into simple non-overlapping faces.

### 5. Offset & Mappers
* **Path Smoothing**: Catmull-Rom (`catmullRomSmoother`) and Cardinal (`cardinalSmoother`) spline interpolation.
* **Inset/Outset (`insetOutset`)**: Inflate or deflate paths by a distance perpendicular to the curve, with configurable corner joins (`miter`, `round`, `bevel`) and automatic trim back of concave overlaps.
* **Stroke Expansion (`strokeExpand`)**: Expand a stroke into a closed, filled vector path loop. Supports uniform or tapered widths, custom cap styles, and profile mapping.
* **Notcher (`notcher`)**: Adds triangular notches along segments at precise intervals (useful for laser cutting/mechanical joints).
* **Corner Rounding**: Utilities to round joints between consecutive segments (`roundCornerUsingCircularArc`, `roundCornerUsingQuadraticBezier`, `roundCornerUsingCubicBezier`).

### 6. Curve Fitting
* **`fitPath`**: Recursively fits an ordered sequence of 2D points into a `VectorPath` composed of the simplest possible segment types (lines → circular arcs → quadratic Béziers → cubic Béziers) that keep all points within a specified error tolerance.

---

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  ramanujan: ^1.0.0
```

---

## Usage Examples

### 1. Boolean Operations
```dart
import 'package:ramanujan/ramanujan.dart';

void main() {
  // Define a rectangle region (0,0 to 100,100)
  final rectA = Region([
    Loop([
      LineSegment(P(0, 0), P(100, 0)),
      LineSegment(P(100, 0), P(100, 100)),
      LineSegment(P(100, 100), P(0, 100)),
      LineSegment(P(0, 100), P(0, 0)),
    ])
  ]);

  // Define a second overlapping rectangle region (50,50 to 150,150)
  final rectB = Region([
    Loop([
      LineSegment(P(50, 50), P(150, 50)),
      LineSegment(P(150, 50), P(150, 150)),
      LineSegment(P(150, 150), P(50, 150)),
      LineSegment(P(50, 150), P(50, 50)),
    ])
  ]);

  // Compute Union
  final unionRegion = const PathUnion().compute(rectA, rectB);
  print('Union contains ${unionRegion.loops.length} loop(s).');
}
```

### 2. Path Offsetting (Inset & Outset)
```dart
import 'package:ramanujan/ramanujan.dart';

void main() {
  final path = [
    LineSegment(P(0, 0), P(100, 0)),
    LineSegment(P(100, 0), P(100, 100)),
    LineSegment(P(100, 100), P(0, 0)), // Closed triangle
  ];

  // Outset (grow) the path by 10 units with rounded corners
  final outsetPath = outset(path, 10, join: OffsetJoin.round);
  print('Outset path contains ${outsetPath.length} segments.');
}
```

### 3. Curve Fitting
```dart
import 'package:ramanujan/ramanujan.dart';

void main() {
  final points = [
    P(0, 0),
    P(25, 5),
    P(50, 20),
    P(75, 45),
    P(100, 50),
  ];

  // Fit the points into an optimized bezier path with a 2.0 unit tolerance
  final fittedPath = fitPath(points, tolerance: 2.0);
  print('Fitted path segments: ${fittedPath.numSegments}');
}
```

---

## TODOs

The following features and improvements are planned:
- [ ] **Wave**: Path mapper to distort segments into wave patterns.
- [ ] **Pucker and bloat**: Envelope/distortion effects on paths.
- [ ] **Path Splitting**: Split a `VectorPath` into separate sub-paths at discontinuous breaks.
- [ ] **Segment Generic `isPointOn`**: Implement direct point-on-curve boundary checks for individual segment instances.