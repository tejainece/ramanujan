# Path Manipulation Features — Inkscape

Inkscape is a prominent open-source vector graphics editor built around the SVG standard. Its underlying geometry library, **lib2geom**, drives its path operations. Inkscape supports standard destructive path commands as well as a powerful stack of non-destructive **Live Path Effects (LPEs)**. This document details these operations, their geometric logic, and their potential mapping to `ramanujan`.

---

## 1. Advanced Boolean Operations: Division & Cut Path

In addition to Union, Difference, Intersection, and Exclusion, Inkscape supports two unique boolean operations:
* **Division:** Cuts the bottom path into multiple closed shapes using the boundary of the top path.
* **Cut Path:** Cuts the stroke of the bottom path into open segments using the boundary of the top path. The fill of the paths is discarded.

### Parameters & Inputs
* **Inputs:** Exactly two overlapping paths.
* **Fill Rules:** Supports even-odd and non-zero winding.

### Geometric Logic & Mathematics
Inkscape's `lib2geom` uses a sweep-line algorithm to detect all intersections between the two paths, splitting their segments at these crossings.
* **Division:**
  1. The intersection coordinates are found, and both paths are split at these points.
  2. The combined edges are subdivided into planar faces.
  3. The faces that belong to the bottom path are identified.
  4. Each face is reassembled into a separate, independent closed loop, effectively partitioning the original bottom shape.
* **Cut Path:**
  1. Only the boundary lines/curves of the bottom path are preserved.
  2. Intersection points with the top path's boundary are calculated.
  3. The bottom path is split at these intersection points, producing a list of open segment chains.
  4. The top path is discarded, leaving the partitioned segments of the bottom path as independent open paths.

### Ramanujan Integration
* **Implementation Path:**
  * **Division:** Reuses `divideSelfIntersecting` and the graph building of the boolean pipeline. After building the planar subdivision of the bottom path $B$ and top path $A$, we collect all faces that reside within $B$. Instead of merging them, we output each face as its own `Loop`.
  * **Cut Path:** We can run the first two steps of the boolean pipeline (intersection search and segment splitting) on the bottom path $B$ and top path $A$. We then discard the segments belonging to $A$, and return the split segments of $B$ grouped into contiguous sub-paths.

---

## 2. Inset / Outset & Dynamic Offset LPE

### UI Context
* **Command:** `Path > Inset` (Ctrl+() and `Path > Outset` (Ctrl+)) are destructive, stepping by a preset distance.
* **LPE:** `Offset` is a non-destructive LPE that exposes an on-canvas handle to dynamically change the offset distance.

### Parameters
* **Offset:** Distance $d$ (positive for outset, negative for inset).
* **Join/Miter Limit:** Defines corner handling.

### Geometric Logic & Mathematics
For curves, Inkscape evaluates the algebraic offsets and fits new Bézier segments. If an outset causes a loop to overlap or self-intersect (which happens on sharp concave corners), Inkscape's offset engine resolves this self-intersection.
* Specifically, a negative offset (inset) of a shape with sharp corners will cause the corners to shrink and eventually collapse.
* To prevent self-intersection, Inkscape runs a simplification or union-filtering pass over the offset curves to remove degenerate loops (often called "de-looping").

### Ramanujan Integration
* **Implementation Path:**
  * Can be built upon `ramanujan`'s `insetOutset` and `OffsetJoin` mechanics.
  * Adding a "de-looping" step: when offsetting a path, self-intersections can be resolved by running the offset result through `simplifyClosedPath`.

---

## 3. Power Stroke LPE

### UI Context
* Applied via the Path Effects dialog. It adds editable width handles along the stroke of a path, allowing the designer to dynamically sculpt a variable-width stroke.

### Parameters
* **Width Control Points:** Coordinates along the path $s_i$ and the corresponding stroke half-widths $w_i$.
* **Joint/Cap Styles:** Custom joint profiles for the variable stroke.

### Geometric Logic & Mathematics
Unlike a uniform outline stroke, Power Stroke uses a non-uniform width function $w(s)$, where $s$ is the arc-length parameter of the path.
1. The width function $w(s)$ is interpolated between control points using a smooth spline (e.g., cubic spline or linear interpolation).
2. The left and right boundary curves of the stroke are computed as:
   $$P_{\text{left}}(s) = P(s) + w(s) \cdot \hat{n}(s)$$
   $$P_{\text{right}}(s) = P(s) - w(s) \cdot \hat{n}(s)$$
3. The boundary curves are then split and fitted with standard cubic Bézier segments.
4. Caps are appended at the endpoints.

### Ramanujan Integration
* **Implementation Path:**
  * Extend `ramanujan`'s stroking capability by introducing a `VariableWidthStroke` class.
  * This class takes a `VectorPath` and a list of width keyframes `(double offsetFraction, double width)`.
  * Evaluates $w(t)$ for any parameter $t$ along the path and uses it to scale the normal offset when generating boundary segments.

---

## 4. Pattern Along Path LPE

### UI Context
* Deforms a repeating pattern shape so that it follows the contour of a skeleton path.

### Parameters
* **Pattern Source:** A vector shape or compound path to repeat.
* **Pattern Copies:** `Single`, `Repeated`, `Single, stretched`, `Repeated, stretched`.
* **Width/Spacing:** Controls scaling and gap sizes.

### Geometric Logic & Mathematics
Let $S(t)$ be the skeleton curve parameterized by its arc-length $s \in [0, L]$, with unit tangent $\hat{t}(s)$ and unit normal $\hat{n}(s)$.
Let $(u, v)$ be a coordinate point inside the bounding box of the pattern, where $u \in [0, W]$ is along the horizontal axis, and $v$ is the vertical displacement from the baseline.
To deform the pattern point $(u, v)$ onto the skeleton curve:
1. **Mapping $u$ to Arc Length:** The coordinate $u$ is mapped to a target arc length $s = u \times \text{scale} + \text{spacing}$.
2. **Evaluation:** Evaluate the position $S(s)$, tangent $\hat{t}(s)$, and normal $\hat{n}(s)$ of the skeleton at this arc length.
3. **Deformation:** The deformed point $P(u, v)$ is calculated as:
   $$P(u, v) = S(s) + v \cdot \hat{n}(s)$$
4. This deformation is applied to all anchor points and control points of the pattern path. Because this is a non-linear coordinate transformation, straight lines in the pattern must be subdivided into smaller segments (often converted to cubic Béziers) to bend smoothly.

### Ramanujan Integration
* **Implementation Path:**
  * Implement an arc-length parameterization helper on `VectorPath` (e.g., mapping a normalized length $[0, 1]$ to a specific segment and segment parameter $t$).
  * Define a transformation function `P mapPoint(P input, VectorPath skeleton)`.
  * Subdivide the input pattern path, apply the transformation to all vertices, and fit new Béziers to reconstruct the bent shape.

---

## 5. Bend LPE

### UI Context
* Similar to Pattern along Path, but deforms a single target object along a single bent path instead of repeating a pattern.

### Geometric Logic & Mathematics
Uses the exact same mathematical projection as Pattern along Path:
$$P(x, y) = S(x') + y' \cdot \hat{n}(x')$$
where $x'$ is the normalized horizontal coordinate mapped to the skeleton's length, and $y'$ is the vertical coordinate scaled by the bounding box of the object.

---

## 6. Spiro Spline LPE

### UI Context
* A drawing mode and Live Path Effect. The user enters standard anchor points, and the engine automatically computes a highly aesthetic, organic curve (a Spiro spline) passing through them.

### Geometric Logic & Mathematics
Spiro curves are based on **clothoid splines** (also known as Euler spirals or Cornu spirals), where the curvature $\kappa(s)$ varies linearly with the arc length $s$:
$$\kappa(s) = a \cdot s + b$$
* **Curvature Continuity:** Unlike standard cubic splines which enforce $C^2$ continuity but can have rapid curvature jumps, Spiro splines achieve $G^2$ (geometric curvature) continuity and minimize the rate of change of curvature (minimizing bending energy).
* The engine solves a global system of equations to find the clothoid parameters for each segment between anchors, then approximates the resulting clothoid curves with cubic Bézier segments for rendering/SVG output.

### Ramanujan Integration
* **Implementation Path:**
  * Spiro curves represent a premium mathematical primitive.
  * We can implement a Spiro solver that takes a list of control points and outputs a `VectorPath` composed of cubic Bézier approximations of the clothoid segments.
  * This fits perfectly with `ramanujan`'s curve-fitting and advanced geometry goals.

---

## 7. Simplify LPE

### UI Context
* Non-destructive version of the Simplify command, added in recent versions of Inkscape to keep the original path editable while rendering a simplified version.

### Geometric Logic & Mathematics
* Employs the Douglas-Peucker algorithm on vertices, or a parametric subdivision solver.
* Smooths out high-frequency noise while leaving low-frequency geometric features intact, exposing a "Lignify" or "Smooth" factor to control the strength.

---

## 8. Knot LPE

### UI Context
* Interactively creates interlacing patterns (under/over weaving) where paths cross.

### Parameters
* **Interrupter Width:** The width of the gap cut in the "under" path.
* **Gaps Selection:** User interactive selection of which crossing point goes under.

### Geometric Logic & Mathematics
1. Locates all self-intersections and mutual intersections of the paths in the LPE scope.
2. For each crossing designated as "under", computes the crossing parameter $t_{\text{cross}}$ on the under-segment.
3. Computes the parameter interval corresponding to the gap width $w$:
   $$\Delta t \approx \frac{w}{2 \cdot \|S'(t_{\text{cross}})\|}$$
4. Splits the under-segment at $t_{\text{cross}} - \Delta t$ and $t_{\text{cross}} + \Delta t$.
5. Removes the intermediate sub-segment, creating a gap in the path representation.

### Ramanujan Integration
* **Implementation Path:**
  * Find intersections of overlapping segments.
  * Implement segment cutting and removal to create local gaps at crossings.

---

## 9. Mirror Symmetry & Rotate Copies LPE

### UI Context
* Generates live symmetrical structures from a base path.

### Parameters
* **Mirror LPE:** Reflection line (origin and direction angle).
* **Rotate Copies LPE:** Center of rotation, number of copies, and split/fuse parameters.

### Geometric Logic & Mathematics
* **Mirror:** Reflects all anchors and tangents across a mirror line $\vec{L}(t) = P_0 + t \cdot \vec{v}$. For a point $P$, the reflected point $P'$ is:
  $$P' = P - 2 \cdot ((P - P_0) \cdot \hat{n}) \cdot \hat{n}$$
  where $\hat{n}$ is the normal to the mirror line.
* **Rotate Copies:** Generates copies at angular intervals $\theta_k = k \cdot \frac{360^\circ}{N}$. Fuses endpoints that lie within an epsilon distance of the rotational seams.

### Ramanujan Integration
* **Implementation Path:**
  * Use affine transformation matrix multiplication (`Affine2D` in `primitive/affine2d.dart`) to replicate paths and combine them into a composite `VectorPath` or `Region`.

---

## 10. Lattice Deformation 2D LPE

### UI Context
* Deforms the path based on an $N \times M$ control point grid.

### Geometric Logic & Mathematics
* Uses a 2D **tensor-product spline or Bezier patch** formulation to deform the coordinate space.
* Deforms the anchors and control points of the path continuously based on their normalized positions within the lattice boundaries.

### Ramanujan Integration
* **Implementation Path:**
  * Implement a 2D grid-based coordinate mapping function, and apply it to path coordinates.

---

## 11. Interpolate Sub-Paths LPE

### UI Context
* Generates intermediate morph paths between sub-paths of a compound path.

### Geometric Logic & Mathematics
* Uses linear interpolation (similar to Illustrator's Blend Tool) between matching nodes of successive sub-paths (e.g. morphing sub-path $0$ into sub-path $1$).

---

## 12. Dashed Stroke LPE

### UI Context
* Live Path Effect that replaces standard dashed stroke styles with fully realized vector dash segments.

### Parameters
* **Dash Pattern:** List of dash and gap lengths.
* **Cap Style / Align to Corners:** Options to adjust dash spacing so dashes end exactly on path corners.

### Geometric Logic & Mathematics
1. Traverses the path by arc length.
2. Segments are split at the transitions of the dash-gap pattern:
   $$s_m = \text{cumulative sum of dash/gap lengths}$$
3. Keep the segments representing "dashes" and discard those representing "gaps".
4. Re-applies caps to each generated sub-path.

### Ramanujan Integration
* **Implementation Path:**
  * Implement `VectorPath.dash(List<double> pattern, {bool alignCorners = true})` which traverses the path, splits segments at dash intervals using arc-length parameters, and collects the resulting sub-paths.
