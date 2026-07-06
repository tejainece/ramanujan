# Curve Fitting

Converts an ordered sequence of 2D points into a `VectorPath` composed of the simplest SVG segment types that fit within a given tolerance.

## Goal

Produce compact, semantically clean SVG paths from traced point data (e.g. PNG→SVG contours). A straight edge should become a `LineSegment`, a circular arc should become a `CircularArcSegment`, and only genuinely curved regions should become `CubicSegment`s.

## Segment Type Cascade

For any sub-sequence of points, fitting is attempted in order from simplest to most expressive. The first type whose max error stays within tolerance is used:

1. **Line** — all points within `tolerance` of the chord from first to last point
2. **Circular arc** — all points within `tolerance` of a circle fitted through the two endpoints and the midpoint, with the rest verified against it
3. **Quadratic Bézier** — least-squares fit of a single control point; all points within `tolerance`
4. **Cubic Bézier** — least-squares fit of two control points; all points within `tolerance`

If even the cubic fails, the sequence is split and each half is processed recursively.

## Algorithm

### Phase 0 — Corner pre-pass (optional)

Scan the full point sequence for corners: points where the signed angle change between consecutive tangent vectors exceeds a threshold (default 45°). These become forced split points, partitioning the sequence into smooth sub-runs before any fitting is attempted. This improves segment boundary accuracy and reduces recursion depth.

### Phase 1 — Recursive fitting

For a sub-sequence of points, the algorithm attempts to fit the sequence using the segment cascade. If any segment type fits all points within the target tolerance, it returns that single segment. Otherwise, it identifies the point of maximum error under a cubic fit, splits the sequence at that index (clamping to ensure both splits have at least one segment), and recursively processes both halves, concatenating the resulting segments.

The parameter `t_i` is the chord-length parameter for point `i`, and `C(t)` is the cubic fitted to the full sub-sequence. The max-error point is where the geometry changes character most sharply — the natural split boundary.


### Phase 2 — Merge pass

After recursion, scan adjacent segments of the same type. If merging a pair keeps max error within tolerance, replace them with a single segment. Prevents over-segmentation from splits that landed slightly off the true boundary.

## Fitting Details

### Line

Compute the perpendicular distance from each point to the chord (first→last). O(n).

### Circular arc

1. Fit a circle to **all points** in the sub-sequence using Kasa's algebraic least-squares method (`Circle.fit`). The system `x²+y²+Dx+Ey+F=0` is solved via 3×3 Cramer's rule; center = (−D/2, −E/2), radius = √(cx²+cy²−F).
2. Verify all points are within `tolerance` of the fitted circle's radius.
3. Determine arc direction and `largeArc` flag via the chord-side algorithm (`Circle.arcThrough`).

### Quadratic Bézier

Chord-length parameterize the points. Solve for the single control point `C1` by least squares:

```
minimize Σ |B(t_i) - p_i|²   where B(t) = (1-t)²·P0 + 2t(1-t)·C1 + t²·P3
```

`C1` has a closed-form solution (one linear solve per axis).

### Cubic Bézier

Chord-length parameterize the points. Estimate endpoint tangents from the first/last few points. Solve for control points `C1`, `C2` by least squares (two linear equations per axis, closed form). If error is still too high, run one round of Newton-Raphson reparameterization and re-solve.

This is Schneider's algorithm (Graphics Gems, 1990), adapted to return max error rather than subdivide internally — subdivision is handled by the outer recursive fitter.

## Chord-Length Parameterization

Used by both quadratic and cubic fitting:

```
d_0 = 0
d_i = d_{i-1} + |p_i - p_{i-1}|
t_i = d_i / d_{n-1}
```

Assigns each point a parameter value proportional to cumulative arc length. Degenerate if all points are coincident (guard: return a single point path).

## Split Point Computation

```
splitAt = argmax_i  |p_i - C(t_i)|,   i in [lo+1, hi-1]
```

`C(t)` is the cubic fitted to the current sub-sequence. Evaluating at each point's chord-length parameter `t_i` is O(n). The cubic is used even when the eventual segment type will be simpler — it gives the most accurate picture of where the geometry diverges from a single smooth curve.

## Complexity

- Corner pre-pass: O(n)
- Fitting a sub-sequence of length k: O(k) for line/arc, O(k) for quadratic/cubic (closed-form least squares)
- Recursion depth: O(log n) expected; O(n) worst case (e.g. a noisy point cloud)
- Merge pass: O(s) where s = number of segments

Overall: O(n log n) expected.

## Parameters

| Parameter | Default | Effect |
|---|---|---|
| `tolerance` | 1.0 | Max point-to-curve distance. Smaller → more segments, more accurate. |
| `cornerThreshold` | 45° | Angle change that forces a split in the pre-pass. Smaller → more splits at gentle bends. |
| `closed` | false | Whether to emit a closing segment back to the first point. |

## Relation to Existing ramanujan Code

- `_fitCubicHandles` in `stroke_expand.dart` and `inset_outset.dart` solves a simpler variant: given two interior points at fixed `t=1/3` and `t=2/3`, recover control handles algebraically. The curve fitter here is the general case: arbitrary points at chord-length parameters, solved by least squares.
- `Circle.fit` and `Circle.arcThrough` on the `Circle` class provide the arc geometry — Kasa's least-squares circle fit and chord-side arc construction respectively.
- Output segments (`LineSegment`, `CircularArcSegment`, `QuadraticSegment`, `CubicSegment`) are existing `ramanujan` types.
