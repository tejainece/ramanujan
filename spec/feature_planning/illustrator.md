# Path Manipulation Features — Adobe Illustrator

Adobe Illustrator is the industry-standard vector graphic editor. Its path manipulation suite includes destructive operations (Pathfinder, Outline Stroke, Simplify) and non-destructive Live Effects (Offset Path, Roughen, Zig Zag, Pucker & Bloat, Live Corners). This document details these operations, their geometric parameters, mathematical underpinnings, and how they relate to `ramanujan`'s architecture.

---

## 1. Pathfinder & Shape Builder (Boolean Operations)

### UI Context
* **Pathfinder Panel:** Destructive operations on multiple selected shapes. Divided into "Shape Modes" (Union, Subtract, Intersect, Exclude) which can also be non-destructive compound shapes, and "Pathfinders" (Divide, Trim, Merge, Crop, Outline, Minus Back).
* **Shape Builder Tool:** Interactive on-canvas tool that allows designers to merge, subtract, or extract regions by dragging a cursor across overlapping areas.

### Parameters & Input Types
* **Inputs:** Overlapping closed or open paths.
* **Fill Rules:** Supports both even-odd and non-zero winding (default is non-zero).

### Geometric Logic & Mathematics
Illustrator uses a **Vatti-style or Bentley-Ottmann sweep-line clipper** variant, adapted for bezier curves.
1. **Intersection Search:** Locates all points where segments cross. Curves are subdivided or solved parametrically to find precise crossing coordinates.
2. **Path Splitting:** Splices paths at all crossing points, turning intersecting curves into distinct edge segments.
3. **Planar Subdivision:** Builds a planar map of vertices, edges, and faces.
4. **Winding Classification:** Computes winding numbers for each face to determine which input paths contain it.
5. **Filtering & Reassembly:**
   * **Divide:** Keeps all faces, splitting all overlapping paths at their intersections.
   * **Trim / Merge:** Removes hidden overlapping fills (based on visual stacking order). Merge additionally coalesces adjacent regions sharing the same fill color.
   * **Union/Subtract/etc.:** Filters faces according to set operations.
6. **Curve Approximation:** Illustrator occasionally approximates curves at intersection vertices with small straight-line segments to ensure topological robustness.

### Ramanujan Integration
* **Status:** `ramanujan` already implements a face-based planar graph subdivision for booleans in `src/boolean/`.
* **Gaps:** `ramanujan` currently focuses on even-odd classification; adding non-zero winding is detailed in [face_stitching.md](../boolean/face_stitching.md).
* **Enhancements:** Implementing a "Divide" operation is highly feasible since `divideSelfIntersecting` and `crossSplit` already partition the plane into distinct edges.

---

## 2. Offset Path

### UI Context
* Available as a live effect (**Effect > Path > Offset Path**) or a destructive command (**Object > Path > Offset Path**).

### Parameters
* **Offset ($d$):** Positive (outward/expansion) or negative (inward/contraction) distance.
* **Joins:** `Miter` (sharp extension), `Round` (circular arc fillet), or `Bevel` (flat cut).
* **Miter Limit:** The threshold ratio of miter length to offset distance before a miter join is clamped to a bevel.

### Geometric Logic & Mathematics
For a path $P(t)$, the offset path $P_d(t)$ is defined as:
$$P_d(t) = P(t) + d \cdot \hat{n}(t)$$
where $\hat{n}(t)$ is the unit normal vector to the curve at $t$.
* **Lines & Arcs:** The offset of a line segment is a parallel line. The offset of a circular arc is a concentric circular arc with radius $R \pm d$. These are geometrically exact.
* **Bézier Curves:** The offset of a quadratic or cubic Bézier curve is *not* a Bézier curve (it is a higher-order algebraic curve). Illustrator approximates this offset by recursively subdividing the curve into sub-arcs where the normal variation is small, computing the offset points, and fitting new Bézier segments to these points (e.g., Tiller-Hanson algorithm or least-squares Bézier fitting).
* **Joins at Corners:** When two segments meet at a sharp corner with an angle $\theta$:
  * **Round Join:** Bridges the gap with a circular arc of radius $|d|$.
  * **Bevel Join:** Bridges the gap with a straight line between the two offset endpoints.
  * **Miter Join:** Extends the offset edges until they intersect. If the intersection length exceeds $d \times \text{Miter Limit}$, it falls back to a bevel.

### Ramanujan Integration
* **Status:** `ramanujan` contains offset logic in `insetOutset` (often used for stroking or offset curves).
* **Implementation Path:**
  1. Leverage `Segment.normal(t)` to evaluate offsets.
  2. Implement a curve-fitting offset approximation for `CubicBezierSegment` and `QuadraticBezierSegment` by splitting them when curvature or normal deviation exceeds a threshold, then fitting cubics to the offset samples.
  3. Support the three join styles at segment transitions.

---

## 3. Outline Stroke

### UI Context
* Destructive command (**Object > Path > Outline Stroke**).

### Parameters
* **Stroke Width ($w$):** Thickness of the stroke.
* **Cap Style:** `Butt` (flat end at anchor), `Round` (semi-circular cap), `Square` (flat end extended by $w/2$).
* **Join Style:** `Miter`, `Round`, `Bevel`.
* **Miter Limit:** Threshold for miters.

### Geometric Logic & Mathematics
Outline Stroke converts a stroke into a filled outline shape.
1. Computes the left offset path $P_{+w/2}(t)$ and the right offset path $P_{-w/2}(t)$ (which is the left offset of the reversed path).
2. For open paths, joins the left and right offsets at the start and end anchors using the selected Cap style:
   * **Butt:** A straight line connecting $P_{+w/2}(0)$ to $P_{-w/2}(0)$.
   * **Round:** A 180-degree circular arc centered at the anchor point.
   * **Square:** Extends the path by $w/2$ and draws a straight line.
3. For closed paths, no caps are needed; the left and right offsets form two independent nested loops (representing the inner and outer boundaries).
4. Emits the resulting loops as a compound path, resolving any self-intersections (using a Boolean Union or self-intersection decomposition).

### Ramanujan Integration
* **Implementation Path:**
  * Can be implemented directly on top of the Offset Path and Join/Cap geometry.
  * The result should return a `Region` (for closed paths) or a `VectorPath` compound shape.
  * Reuses `divideSelfIntersecting` to clean up any loops or overlapping regions that occur when stroking highly folded paths.

---

## 4. Simplify Path

### UI Context
* Destructive command (**Object > Path > Simplify**) with a simplified modal slider.

### Parameters
* **Simplify Slider (Threshold):** Controls how closely the output must match the original path.
* **Corner Angle Threshold:** Angles sharper than this value are kept as sharp corners; smoother transitions are smoothed out.
* **Show Original / Retain Curve Type:** Toggles to output clean curves or convert all segments to straight lines.

### Geometric Logic & Mathematics
Simplify reduces the coordinate data size by removing redundant anchor points while keeping the deviation within a user-defined tolerance $\epsilon$.
1. **Corner Detection:** Analyzes the turn angle at each vertex. Vertices with angles exceeding the threshold are marked as "fixed corner points".
2. **Sub-path Fitting:** Between each pair of fixed corner points, the sequence of original segments is sampled to obtain a dense sequence of points.
3. **Decimation / Fitting:**
   * Uses algorithms like **Ramer-Douglas-Peucker (RDP)** to decimate straight segments.
   * For curved segments, it fits cubic Béziers to the point cloud using least-squares fitting (e.g., Schneider's algorithm, similar to `fitPath` in `ramanujan/lib/src/curve_fitting/`).
   * Iteratively adds split points where the fitted curve deviates from the original sample by more than $\epsilon$.

### Ramanujan Integration
* **Status:** `ramanujan` has a powerful curve fitting module (`src/curve_fitting/`).
* **Implementation Path:**
  1. We can implement a path-level `simplify` by extracting tangible points, locating sharp corners (high turn angles), and running `fitPath` on the dense samples of the smooth intervals between those corners.
  2. This aligns with Todo item 5 (`Path simplification`).

---

## 5. Roughen

### UI Context
* Live Effect (**Effect > Distort & Transform > Roughen**).

### Parameters
* **Size:** Amplitude of the distortion (either relative percentage of path size or absolute points).
* **Detail:** Frequency of the ripples (number of ridges per inch/unit).
* **Points:** `Smooth` (creates curved waves) or `Corner` (creates jagged teeth).

### Geometric Logic & Mathematics
Roughen acts as a procedural noise operator on a path.
1. **Subdivision:** Divides each path segment into smaller sub-segments based on the **Detail** parameter.
2. **Noise Displacement:** At each generated vertex $V_i$, computes a displacement vector $\vec{d}_i$ in a pseudo-random direction (or along the local normal vector $\hat{n}_i$).
   * The magnitude of $\vec{d}_i$ is randomized up to the **Size** parameter.
3. **Segment Fitting:**
   * **Corner:** Connects the displaced vertices with straight `LineSegment`s.
   * **Smooth:** Interpolates Bezier tangents through the displaced vertices to create a smooth, undulating wave (similar to a Cardinal spline or Catmull-Rom spline, converted to Cubics).

### Ramanujan Integration
* **Implementation Path:**
  1. Implement a method `VectorPath.roughen(double size, double detail, {bool smooth = false, int? seed})`.
  2. For each segment, calculate its length and determine the number of divisions $N = \text{length} \times \text{detail}$.
  3. Sample the path at $N$ equal parametric or arc-length intervals.
  4. Displace each sample point perpendicular to the path direction by a random factor scaled by `size`.
  5. Assemble a new `VectorPath` from these points, using cubic Beziers (with tangent-aligned control points) if `smooth` is true, or lines if false.

---

## 6. Zig Zag

### UI Context
* Live Effect (**Effect > Distort & Transform > Zig Zag**).

### Parameters
* **Size:** Amplitude of the waves or spikes.
* **Ridges per Segment:** Explicit number of peaks/valleys to create along each individual segment.
* **Points:** `Smooth` (sine-wave look) or `Corner` (triangle-wave look).

### Geometric Logic & Mathematics
Unlike Roughen, Zig Zag is completely deterministic and symmetric per segment.
1. For each segment $S_i(t)$, divides the parameter space $[0, 1]$ into $2k$ equal intervals, where $k$ is the **Ridges per Segment** count.
2. Generates $2k - 1$ interior vertices.
3. Alternates the displacement direction for each vertex:
   * Odd vertices are shifted in the positive normal direction $+d \cdot \hat{n}(t_j)$.
   * Even vertices are shifted in the negative normal direction $-d \cdot \hat{n}(t_j)$.
4. **Segment Reconstruction:**
   * **Corner:** Connects anchors and displaced vertices with straight lines.
   * **Smooth:** Bridges the peaks and valleys with tangent-continuous curves. For a sine-wave appearance, control points are placed parallel to the segment direction at the peak/valley vertices.

### Ramanujan Integration
* **Implementation Path:**
  1. Implement `VectorPath.zigzag(double size, int ridges, {bool smooth = false})`.
  2. Map each segment $S_j$ by evaluating points at $t_m = m / (2 \cdot \text{ridges})$ for $m \in [0, 2 \cdot \text{ridges}]$.
  3. Compute normal vectors at $t_m$ and offset the points alternatingly.
  4. Generate lines or cubic/quadratic Beziers between the offset points.
  5. This maps directly to Todo item 7 (`Wave`).

---

## 7. Pucker & Bloat

### UI Context
* Live Effect (**Effect > Distort & Transform > Pucker & Bloat**).

### Parameters
* **Amount:** Percentage from -100% (Pucker) to +100% (Bloat).

### Geometric Logic & Mathematics
Pucker & Bloat distorts paths relative to their anchor points by manipulating their tangent control points.
1. **Centroid Anchor (Optional but common for closed paths):** Finds the center of the shape or path bounding box $C$.
2. **Control Point Manipulation:** For each anchor point $A_i$ with incoming control point $C_{i, \text{in}}$ and outgoing control point $C_{i, \text{out}}$:
   * **Pucker (Negative Amount):** Moves the control points *inward* toward the anchor point $A_i$ (collapsing the curvature towards the corners) and pulls the anchor points themselves toward the centroid $C$.
     $$A'_i = A_i + \text{Amount} \cdot (A_i - C)$$
     This sharpens the corners and curves, creating a star-like, pinched shape.
   * **Bloat (Positive Amount):** Pushes the control points *outward* (away from the anchor point $A_i$) and pushes the anchor points away from the centroid $C$.
     This increases the curvature of the segments, causing them to balloon outward into rounded, bulbous shapes.

### Ramanujan Integration
* **Implementation Path:**
  1. Identify path control points using `PathTangiblePoint` and `TangiblePointAddress`.
  2. Implement `VectorPath.puckerBloat(double amount)`.
  3. Calculate the centroid of the path.
  4. Update each anchor point and its neighboring Bezier control points by moving them toward or away from the centroid/anchors according to the scaling factor.
  5. This fulfills Todo item 8 (`Pucker and bloat`).

---

## 8. Blend Tool (Path Morphing / Interpolation)

### UI Context
* **Interactive Tool / Command:** (**Object > Blend > Make**). Creates an interactive transition between two or more distinct paths.

### Parameters
* **Spacing:** `Specified Steps` (fixed integer count of intermediate shapes), `Specified Distance` (steps placed at constant distance intervals), or `Smooth Color` (automatically calculates steps to prevent visible banding).
* **Orientation:** `Align to Page` (keeps horizontal axis fixed) or `Align to Path` (rotates shapes relative to the spline backbone).

### Geometric Logic & Mathematics
Let $A(u)$ and $B(v)$ be two parameterized vector paths. Interpolating between them to produce a step path $M_k(t)$ (for $k \in [0, N]$ steps) requires resolving point-correspondence:
1. **Normalization:** Both paths are re-parameterized by arc length or matched anchor by anchor. If they have a different number of anchors, Illustrator inserts virtual anchors on the path with fewer points to establish a 1-to-1 matching.
2. **Linear/Tangential Interpolation:** For each matched pair of anchor points $P_A$ and $P_B$ and their associated control tangents $T_{A1}, T_{A2}$ and $T_{B1}, T_{B2}$:
   $$P_k = (1 - \tau) \cdot P_A + \tau \cdot P_B$$
   $$T_{k1} = (1 - \tau) \cdot T_{A1} + \tau \cdot T_{B1}$$
   where $\tau = k / (N + 1)$ is the interpolation fraction.
3. If the blend has a curved backbone path $C(w)$, the centroid of $M_k$ is placed at $C(\tau)$ and rotated to align with the tangent of $C(\tau)$.

### Ramanujan Integration
* **Implementation Path:**
  * Create a utility to establish 1-to-1 correspondence between two paths (e.g. by subdividing segments at identical relative arc lengths).
  * Implement `VectorPath.interpolate(VectorPath target, double t)` which returns a new path by linearly interpolating anchors and tangents of the normalized paths.

---

## 9. Scribble Effect

### UI Context
* Live Effect (**Effect > Stylize > Scribble**).

### Parameters
* **Angle:** The tilt angle of the hatching lines.
* **Scribble Options:** `Inside` (bounds) vs `Centering`.
* **Path Overlap:** How much the scribble lines can cross the boundaries of the shape.
* **Stroke Options:** Width, variation, spacing, and curve/jitter behavior.

### Geometric Logic & Mathematics
Scribble turns a solid filled shape into a series of overlapping hatch lines within the shape's boundary.
1. **Hatch Line Generation:** Computes a bounding box rotated by the **Angle** parameter. Fills this box with a back-and-forth zigzagging line spaced according to the **Spacing** parameter.
2. **Boolean Intersection/Clipping:**
   * Rotates the hatch lines back to the original space.
   * Performs a boolean intersection between the generated zigzag pattern (treated as open strokes) and the closed boundary path.
3. **Jitter & Variation:** Applies noise (variation in displacement and angle) to the hatch coordinates before rendering.

### Ramanujan Integration
* **Implementation Path:**
  * Generate a grid of parallel line segments across the bounding box of a `Loop`.
  * Connect the ends of adjacent segments to form a single continuous zigzag path.
  * Implement an intersection/trimming algorithm to crop the open zigzag segments against the boundary of the `Loop` using the planar graph intersection tools.

---

## 10. Envelope Distort & Warp Effects

### UI Context
* **Command:** (**Object > Envelope Distort > Make with Warp / Make with Mesh**).

### Parameters
* **Warp Styles:** `Arc`, `Arc Lower`, `Arc Upper`, `Arch`, `Bulge`, `Shell`, `Flag`, `Wave`, `Fish`, `Rise`, `Fisheye`, `Inflate`, `Squeeze`, `Twist`.
* **Mesh Columns/Rows:** Grid density (e.g., $4 \times 4$).

### Geometric Logic & Mathematics
Applies a spatial mapping function $F: \mathbb{R}^2 \to \mathbb{R}^2$ to the coordinate space of the path.
* **Warp Effects:** Deforms coordinates using specific mathematical formulas. For example, a horizontal **Arc** distortion shifts coordinates as:
  $$x' = x, \quad y' = y + \text{Bend} \cdot \left(1 - \left(\frac{2x - (x_{\text{min}} + x_{\text{max}})}{x_{\text{max}} - x_{\text{min}}}\right)^2\right)$$
* **Mesh Distort:** Uses **bivariate Bernstein polynomials** (similar to a 2D Bézier patch) to interpolate coordinates within each grid cell.
  Given a grid cell with $4 \times 4$ control points $P_{i,j}$:
  $$F(u, v) = \sum_{i=0}^3 \sum_{j=0}^3 B_i^3(u) B_j^3(v) P_{i,j}$$
  where $B_n^3(t)$ are cubic Bernstein basis polynomials.
* Anchor and control points are transformed under $F$. To prevent distortion artifacts, long segments are pre-subdivided.

### Ramanujan Integration
* **Implementation Path:**
  * Implement `VectorPath.transformCoordinates(P Function(P) mapping)`.
  * Support grid deformation by evaluating bivariate bezier patches over normalized coordinates.

---

## 11. Path Cutting (Scissors, Knife, Eraser)

### UI Context
* Interactive tools in the toolbar.

### Parameters
* **Scissors:** Splits a path at a specific point on a segment.
* **Knife / Eraser:** Drag-to-cut stroke path that divides shapes.

### Geometric Logic & Mathematics
* **Scissors:** Evaluates the parameter $t$ of the selected segment at the click coordinate, and replaces that segment $S$ with two segments $S_1 = S(0 \dots t)$ and $S_2 = S(t \dots 1)$ (using `bifurcateAtInterval`), converting the path into an open path or splitting it.
* **Knife/Eraser:** Draws a stroke boundary $E$ representing the eraser sweep. Computes the Boolean Difference $S \setminus E$ where $S$ is the selected shape.

### Ramanujan Integration
* **Implementation Path:**
  * Reuses `Segment.bifurcateAtInterval` for Scissors.
  * Reuses the Boolean Difference pipeline for Knife and Eraser.

---

## 12. Smooth Tool

### UI Context
* Interactive brush (**Smooth Tool**).

### Parameters
* **Fidelity / Smoothness:** Strength of the smoothing effect.

### Geometric Logic & Mathematics
Smooths out irregularities in freehand drawn paths.
1. Isolates the sequence of vertices in the brush region.
2. Applies a **Laplacian filter** (moving average) to the coordinates of the anchors:
   $$P'_i = (1 - \lambda) \cdot P_i + \lambda \cdot \frac{P_{i-1} + P_{i+1}}{2}$$
   where $\lambda$ is the smoothing weight.
3. Tangent control handles are recalculated to fit the new anchor positions while maintaining $G^1$ or $C^1$ tangent continuity.

### Ramanujan Integration
* **Implementation Path:**
  * Implement a vertex smoothing filter that runs a localized weighted moving average on anchor points, and re-interpolates the control points.
