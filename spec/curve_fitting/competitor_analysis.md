# Curve Fitting — Competitor Analysis

Comparison of ramanujan's `fitPath` against the major open-source curve-fitting / vectorisation libraries.

## Competitors

**potrace** (C, 2001–present) — the canonical bitmap tracer. Used internally by Inkscape's "Trace Bitmap" and by most SVG export pipelines. Outputs cubic Béziers only; its distinguishing feature is tangent-continuous junctions and a tunable `alpha` corner-smoothing parameter.

**vtracer** (Rust, 2020–present) — a modern alternative to potrace. Includes a full pipeline: pixel clustering → contour tracing → path simplification → Bézier fitting. Outputs cubic Béziers only.

## Feature Comparison

| Feature | ramanujan | vtracer | potrace |
|---|---|---|---|
| Line segments | ✅ | ✅ | ✅ |
| Circular arc segments | ✅ | ✗ | ✗ |
| Quadratic Bézier segments | ✅ | ✗ | ✗ |
| Cubic Bézier segments | ✅ | ✅ | ✅ |
| Simplest-first segment cascade | ✅ | ✗ | ✗ |
| All-points least-squares arc fit (Kasa) | ✅ | n/a | n/a |
| Closed-form quadratic least-squares | ✅ | n/a | n/a |
| Schneider cubic fit + Newton-Raphson | ✅ | ✅ | ✅ |
| Corner pre-pass | ✅ | ✅ | ✅ |
| Post-split merge pass | ✗ | ✅ | ✅ |
| C1 tangent continuity at junctions | ✗ | partial | ✅ |
| Corner smoothing parameter | ✗ | ✗ | ✅ (`alpha`) |
| Built-in contour tracer (pixel→points) | ✗ | ✅ | ✅ |
| Multi-shape / disconnected paths | ✗ | ✅ | ✅ |

## Advantages

### Simplest-first cascade
ramanujan tries line → circular arc → quadratic Bézier → cubic Bézier and uses the simplest type that fits. potrace and vtracer both go straight to cubic Béziers for all curved regions.

For images with geometric structure (logos, icons, technical drawings, fonts), this produces semantically cleaner output: a circular arc is represented as `<arc>`, not as four cubics. Fewer segments, smaller SVG, round-trip editable in Inkscape as an actual arc.

### All-points arc fitting (Kasa's method)
The circle that defines a `CircularArcSegment` is found by Kasa's algebraic least-squares fit over **all** points in the sub-sequence, not just three representative points. This is more robust to noise and non-uniform sampling than a circumcircle through three points.

### Closed-form quadratic fit
The quadratic control point is solved in a single closed-form pass (`C = Σ b_i·q_i / Σ b_i²`). No iteration required.

## Gaps

### 1. No merge pass
After recursive splitting, adjacent segments of the same type are not merged back. If a long arc just exceeds tolerance at one point, the recursion splits it into two shorter arcs rather than reporting a single near-miss arc. potrace and vtracer both run a post-processing pass that merges neighbours when their union still fits within tolerance.

**Impact:** over-segmentation on smooth input; more segments than necessary.

**Fix:** after `_fitSegments` returns, scan adjacent same-type segments and merge pairs (or longer runs) that fit within tolerance.

### 2. No C1 tangent continuity
At every split boundary, the two adjacent segments meet at whatever angle their endpoints happen to share. There is no enforcement that the outgoing tangent of one segment matches the incoming tangent of the next.

potrace enforces C1 continuity at Bézier junctions by adjusting control handles after fitting. This matters most for smooth organic shapes; it is less important for technical/geometric paths where corners are intentional.

**Impact:** visible kinks at some segment boundaries on smooth curves.

### 3. No corner smoothing
potrace's `alpha` parameter controls how aggressively detected corners are softened into smooth curves. ramanujan has `cornerThreshold` (detection sensitivity) but no equivalent smoothing step after detection.

**Impact:** sharp corners cannot be blended into smooth transitions without external post-processing.

### 4. No contour tracer
ramanujan accepts an ordered `List<P>` as input — it is a fitting library, not a vectoriser. Callers must supply the point sequence (e.g. from a marching-squares contour trace or manual input). vtracer and potrace own the full pixel→SVG pipeline.

**Impact:** ramanujan cannot replace vtracer/potrace as a standalone PNG→SVG tool without an upstream contour tracer.

## Priority

The **merge pass** (Gap 1) is the highest-leverage improvement: it is purely post-processing over existing output, already documented in the algorithm spec, and directly reduces segment count on smooth input. Gaps 2–4 matter more for organic image tracing than for the geometric use cases ramanujan's cascade is optimised for.
