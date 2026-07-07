# Path Manipulation Features — Adobe After Effects

Adobe After Effects (AE) features a robust vector graphics engine for shape layers. Unlike traditional design tools, After Effects' shape layer operators are applied **stack-based and non-destructively in real-time** (similar to modifiers in 3D software). This document details AE's primary path operators, their geometric logic, and their potential integration paths in `ramanujan`.

---

## 1. Trim Paths

### UI Context
* A shape layer modifier used extensively for vector stroke animations (e.g., writing effects, progressive loading circles).

### Parameters
* **Start:** Percentage of the path's total length to trim from the beginning ($0\%$ to $100\%$).
* **End:** Percentage of the path's total length to keep ($0\%$ to $100\%$).
* **Offset:** Shift value (in degrees, $-360^\circ$ to $+360^\circ$) that shifts the starting position of closed paths.
* **Trim Multiple Shapes:** `Simultaneously` (treats all paths in the group as one continuous length) or `Individually` (applies the percentages to each path independently).

### Geometric Logic & Mathematics
Trim Paths operates by parameterizing the entire path by its arc length.
1. **Total Arc Length:** Computes the cumulative arc length $L$ of the path by integrating the length of each segment $S_i$.
2. **Keyframe Mapping:** Calculates the target start distance $d_{\text{start}} = L \times \text{Start}$ and end distance $d_{\text{end}} = L \times \text{End}$.
3. **Offset Application:** For closed paths, the starting point (arc length $s = 0$) is shifted by the **Offset** angle:
   $$s_{\text{shift}} = L \times \frac{\text{Offset}}{360}$$
   The arc length coordinates are evaluated modulo $L$ around the loop.
4. **Segment Extraction:**
   * Finds the specific segment $S_i$ and the parametric value $t_1 \in [0, 1]$ where cumulative length equals $d_{\text{start}} + s_{\text{shift}}$.
   * Finds the segment $S_j$ and the parametric value $t_2 \in [0, 1]$ where cumulative length equals $d_{\text{end}} + s_{\text{shift}}$.
   * Splits the start segment at $t_1$ and the end segment at $t_2$ (using de Casteljau subdivision).
   * Extracts and returns the chain of sub-segments connecting these two points. If the path was closed, trimming splits the loop, converting it into an open `VectorPath`.

### Ramanujan Integration
* **Implementation Path:**
  1. This is a highly requested feature in vector graphics engines.
  2. Implement an arc-length integration method on `VectorPath` that returns a lookup table of segment index and parameter $t$ for any length $d \in [0, L]$.
  3. Implement `VectorPath.trim(double startFraction, double endFraction, {double offsetFraction = 0})` by locating the split parameters and using segment splitting (e.g., `CubicBezierSegment.bifurcateAtInterval` or similar).

---

## 2. Merge Paths (Shape Booleans)

### UI Context
* Group modifier that performs boolean set operations on all shape paths residing above it in the same group hierarchy.

### Parameters
* **Mode:** `Add` (Union), `Subtract` (Difference), `Intersect`, `Exclude` (XOR), and `Merge` (combines fills and strokes into a single shape without resolving overlaps unless they share color).

### Geometric Logic & Mathematics
Merge Paths acts sequentially down the shape layer stack:
1. Loops through all shape paths in the group.
2. Applies the selected boolean operation between the accumulated path geometry and the next path in the stack.
3. Emits the resulting compound path.

### Ramanujan Integration
* **Implementation Path:**
  * Reuses `ramanujan`'s boolean operations (`src/boolean/path_boolean.dart`).
  * Can be implemented as a sequential reducer:
    ```dart
    VectorPath mergePaths(List<VectorPath> paths, MergeMode mode) {
      if (paths.isEmpty) return VectorPath([]);
      var result = paths.first;
      for (int i = 1; i < paths.length; i++) {
        result = runPathBoolean(result, paths[i], mode.toMapOp());
      }
      return result;
    }
    ```

---

## 3. Offset Paths

### UI Context
* Procedurally expands or contracts shape layer paths.

### Parameters
* **Amount:** Offset distance.
* **Line Join:** `Miter`, `Round`, `Bevel`.
* **Miter Limit:** Clamping ratio.
* **Copies:** Number of offset copies to generate.
* **Copy Offset:** The progressive shift in offset distance for each subsequent copy.

### Geometric Logic & Mathematics
Evaluates the parallel offset curves.
* If **Copies** $> 1$, evaluates multiple offsets at distances:
  $$d_k = \text{Amount} + k \cdot \text{Copy Offset} \quad \text{for } k \in [0, \text{Copies}-1]$$
* Generates a separate path for each $d_k$ and returns them as a combined group.

### Ramanujan Integration
* **Implementation Path:**
  * Build on top of the proposed `VectorPath.offset(double distance)` tool, repeating the operation in a loop to support multiple copies.

---

## 4. Round Corners

### UI Context
* Non-destructively rounds the corners of all paths within its scope.

### Parameters
* **Radius:** Circular radius of the rounded corners.

### Geometric Logic & Mathematics
For each corner (vertex where two segments meet at a sharp angle):
1. Identifies the incoming segment $S_{\text{in}}$ and outgoing segment $S_{\text{out}}$.
2. Calculates the tangent vectors at the vertex.
3. Computes the maximum safe radius $R_{\text{max}}$ to avoid overlapping with adjacent corners (radius clamping).
4. Employs the tangent-circle construction to find the arc endpoints on both segments.
5. Splits the segments at these tangent points and inserts a circular arc segment of radius $R = \min(\text{Radius}, R_{\text{max}})$.

### Ramanujan Integration
* **Implementation Path:**
  * Resolves Gap 1 ("No whole-path rounding operation") identified in the [corner competitor analysis](../corner/competitor_analysis.md).
  * Iterates through a `VectorPath`'s vertices, applying `roundCornerUsingCircularArc` or another rounding strategy at each corner, then splicing the resulting segments back together.

---

## 5. Pucker & Bloat

### UI Context
* Non-destructively deforms paths by pulling/pushing control points relative to anchor points.

### Parameters
* **Amount:** Percentage (from $-100\%$ to $+100\%$).

### Geometric Logic & Mathematics
For each segment (e.g. Bézier curve):
1. **Pucker (Negative Amount):** Pulls the control points of the curves inwards towards the anchor points, making the curve flatter or concave. Anchor points are also pulled towards the centroid of the path.
2. **Bloat (Positive Amount):** Pushes the control points outwards away from the anchor points (increasing tangent length), inflating the curve. Anchors are pushed away from the centroid.
* If a segment is a straight `LineSegment`, After Effects converts it to a cubic Bézier and places control points at the anchors, then displaces them to apply the curvature.

### Ramanujan Integration
* **Implementation Path:**
  * Reuses the Pucker & Bloat logic designed for the Illustrator specification, applying it non-destructively to the `VectorPath` segments.

---

## 6. Twist

### UI Context
* Rotates the path around a center point, with rotation angle decreasing with distance.

### Parameters
* **Angle:** The rotation angle at the center ($0^\circ$ to $+360^\circ$ or more).
* **Center:** The $(x, y)$ coordinate origin of the twist.

### Geometric Logic & Mathematics
For each vertex and control point $P = (x, y)$ in the path:
1. Computes the vector from the twist center: $\vec{r} = P - \text{Center}$.
2. Calculates the radial distance $r = \|\vec{r}\|$.
3. Applies a distance-decayed rotation angle $\theta(r)$:
   $$\theta(r) = \text{Angle} \times f(r)$$
   where $f(r)$ is a decay function (typically linear decay: $f(r) = \max(0, 1 - r/R_{\text{max}})$, where $R_{\text{max}}$ is the bounding radius of the path).
4. The deformed point $P'$ is calculated by rotating $\vec{r}$ by $\theta(r)$:
   $$P' = \text{Center} + \begin{pmatrix} \cos\theta & -\sin\theta \\ \sin\theta & \cos\theta \end{pmatrix} \vec{r}$$
5. Apply this coordinates deformation to all anchor and control points. Segments must be subdivided to capture the spiral deformation smoothly.

### Ramanujan Integration
* **Implementation Path:**
  * Implement a general coordinate transformation mapper: `VectorPath.mapCoordinates(P Function(P) transform)`.
  * For Twist, define the rotation function and map all path points. Since twisting curves non-linearly, pre-subdividing long segments into smaller Béziers ensures high fidelity.

---

## 7. Wiggle Paths

### UI Context
* Applies a procedural, animated noise deformation to the path (useful for creating hand-drawn "boiling" line styles or organic jitter).

### Parameters
* **Size:** Amplitude of the noise displacement.
* **Detail:** Density of the jaggedness (frequency of divisions).
* **Points:** `Smooth` or `Corner`.
* **Wiggles/Second:** Frequency of the temporal animation.
* **Correlation:** How much adjacent points move together ($0\%$ to $100\%$).
* **Temporal / Spatial Phase:** Phase offsets for the noise functions.
* **Random Seed:** Seed for reproducibility.

### Geometric Logic & Mathematics
Wiggle Paths combines spatial and temporal noise (typically 1D or 2D Simplex/Perlin noise):
1. **Subdivision:** Subdivides the path into smaller segments based on the **Detail** value.
2. **Noise Evaluation:** For each vertex $V_i$ at position $(x_i, y_i)$, evaluates a noise function:
   $$\vec{n}_i = \text{Noise2D}(x_i \cdot s_{\text{spatial}} + \phi_s, \text{time} \cdot \omega_t + \phi_t)$$
   where $s_{\text{spatial}}$ is spatial frequency, $\omega_t$ is temporal frequency, and $\phi$ represents phase.
3. **Displacement:** Displaces the vertex by:
   $$V'_i = V_i + \text{Size} \cdot \vec{n}_i$$
4. **Reassembly:** Joins the displaced points using straight lines (for `Corner`) or smooth splines (for `Smooth`).

### Ramanujan Integration
* **Implementation Path:**
  * A key feature for dynamic canvas rendering.
  * We can implement a noise-based path modifier. It would require importing a simple Perlin/Simplex noise utility, subdividing the `VectorPath`, displacing the points, and re-interpolating the segments.

---

## 8. Zig Zag

### UI Context
* Procedurally transforms paths into alternating waves or spikes.

### Parameters
* **Size:** Amplitude of the spikes/waves.
* **Ridges per Segment:** Spikes per individual segment.
* **Points:** `Smooth` or `Corner`.

### Geometric Logic & Mathematics
* Identical to the Zig Zag behavior in Adobe Illustrator: partitions segments parametrically and offsets vertices in alternating directions along the path normal.

---

## 9. Repeater

### UI Context
* Procedurally duplicates shapes and applies incremental transform modifications (translating, scaling, rotating) to each subsequent copy.

### Parameters
* **Copies:** Number of copies to render.
* **Offset:** Offset position of the copies.
* **Composite:** `Above` or `Below` (stacking order of the copies).
* **Transform Properties:** Position, Scale, Rotation, Anchor Point, and Opacity shifts applied progressively.

### Geometric Logic & Mathematics
1. Let $P$ be the input path representation.
2. For copy index $k \in [0, \text{Copies}-1]$:
   * Formulates a cumulative transformation matrix $M_k$:
     $$M_k = T(\text{Anchor}) \times R(k \cdot \text{Rotation}) \times S(k \cdot \text{Scale}) \times T(k \cdot \text{Position}) \times T(-\text{Anchor})$$
   * Transforms the path: $P_k = M_k \times P$.
3. Merges the paths into a compound shape group.

### Ramanujan Integration
* **Implementation Path:**
  * Implement matrix compounding and replication on `VectorPath` using the existing `Affine2D` transform.

---

## 10. Stroke Taper & Stroke Wave

### UI Context
* Modifiers applied to the width profile of strokes in shape layer properties (added in recent versions of After Effects).

### Parameters
* **Taper Options:** `Start Length`, `End Length`, `Start Width`, `End Width`, `Start Ease`, `End Ease`.
* **Wave Options:** `Amount` (waves amplitude), `Wavelength`, `Phase` (animatable wave travel).

### Geometric Logic & Mathematics
Similar to Inkscape's Power Stroke LPE:
1. Formulates a width profile function $w(s)$ over the arc length $s \in [0, L]$.
2. **Taper:** Applies a linear or cubic ease-in/out to $w(s)$ at the boundaries $[0, L_{\text{start}}]$ and $[L - L_{\text{end}}, L]$:
   $$w_{\text{taper}}(s) = w_0 \cdot \text{Ease}\left(\frac{s}{L_{\text{start}}}\right)$$
3. **Wave:** Multiplies or adds a sine wave oscillation to the stroke width along its path:
   $$w_{\text{wave}}(s) = w(s) + \text{Amount} \cdot \sin\left(\frac{2\pi \cdot s}{\text{Wavelength}} + \text{Phase}\right)$$
4. Calculates left and right offset boundaries and fits Bézier segments.

### Ramanujan Integration
* **Implementation Path:**
  * Integrated into the proposed `VariableWidthStroke` class, using ease functions and sine wave equations to calculate the offset widths along the segments.
