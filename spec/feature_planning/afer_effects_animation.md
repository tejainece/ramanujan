# Vector Animation & Tweening — Adobe After Effects

Adobe After Effects (AE) features a sophisticated engine for animating vector shapes. Shape layers can be animated via **keyframe tweening** (interpolating path coordinates), **procedural expressions** (generating path data programmatically per frame), or by **spatial motion paths** (moving elements along Bezier curves). This document details these mechanisms, their mathematical logic, and how `ramanujan` can support them.

---

## 1. Path Keyframe Tweening (Bézier Morphing)

When keyframing the `Path` property of a shape, After Effects interpolates the geometry over time. The interpolation math depends on whether the source and target paths have matching topology.

### A. Matching Topology (Same Anchor Count)
If the starting keyframe path $A$ and the ending keyframe path $B$ contain the same number of vertices $N$, After Effects performs a direct **1-to-1 linear interpolation (LERP)** on all anchor and tangent coordinates.

Let $P_i(t)$ be the position of the $i$-th anchor at progress $\tau \in [0, 1]$:
$$P_i(\tau) = (1 - \tau) \cdot P_{A,i} + \tau \cdot P_{B,i}$$

Let $T_{\text{in},i}(\tau)$ and $T_{\text{out},i}(\tau)$ be the incoming and outgoing control point **offsets** (relative to the anchor coordinate):
$$T_{\text{in},i}(\tau) = (1 - \tau) \cdot T_{\text{in},A,i} + \tau \cdot T_{\text{in},B,i}$$
$$T_{\text{out},i}(\tau) = (1 - \tau) \cdot T_{\text{out},A,i} + \tau \cdot T_{\text{out},B,i}$$

#### The "First Vertex" & Winding Order Constraints
* **First Vertex (Index 0):** The index matching starts at the vertex designated as the **First Vertex**. If the first vertex of path $B$ does not align semantically with that of path $A$, the shape will rotate or twist during the transition.
* **Winding Direction:** If path $A$ runs clockwise and path $B$ runs counter-clockwise, the interpolation causes the shape to fold in on itself (self-intersect) as the indices sweep in opposite directions.

### B. Mismatched Topology (Different Anchor Counts)
If path $A$ has $M$ anchors and path $B$ has $N$ anchors (where $M \neq N$):
1. **Vertex Splitting & Injection:** After Effects inserts virtual vertices into the path with fewer anchors. It splits segments (typically at their parametric midpoints $t = 0.5$) until both paths have $\max(M, N)$ vertices.
2. **Anchor Collapsing:** Alternatively, excess anchors in the target path are collapsed into a single point on the source path (so a single anchor "splits" or blossoms into multiple anchors, or vice versa).
3. **Index Mapping:** AE maps the generated vertices based on spatial proximity or index order, then performs the standard LERP.

---

## 2. Expression-Based Procedural Path Control

After Effects allows writing JavaScript expressions to generate or modify path properties dynamically at runtime.

### A. The Path Expression API
An expression can query the properties of a path at any time $t$:
* **`path.points(t)`**: Returns an array of absolute coordinate pairs: `[[x0, y0], [x1, y1], ...]`
* **`path.inTangents(t)`**: Returns an array of coordinate offsets for incoming Bezier control points: `[[dx0, dy0], [dx1, dy1], ...]`
* **`path.outTangents(t)`**: Returns an array of coordinate offsets for outgoing Bezier control points: `[[dx0, dy0], [dx1, dy1], ...]`
* **`path.isClosed()`**: Returns `true` if the path forms a closed loop.

### B. Procedural Path Generation: `createPath()`
Using the `createPath` function, a designer can construct a completely custom path programmatically:
```javascript
createPath(points, inTangents, outTangents, isClosed)
```
* **Dynamic Deformations:** By querying `points()`, a script can loop through the vertices and apply mathematical offsets (e.g., adding Perlin noise, scaling, or applying sine-wave oscillation over time) before passing the arrays back to `createPath()`.

### C. Path Evaluation (Arc-Length Parametrization)
After Effects provides methods to query position and direction at any progress fraction $p \in [0, 1]$ along the path:
* **`path.pointOnPath(p, t)`**: Returns the absolute coordinate $(x, y)$ at fraction $p$ of the total path length.
* **`path.tangentOnPath(p, t)`**: Returns the normalized tangent vector $(dx, dy)$ representing the direction of the curve at $p$.
* **`path.normalOnPath(p, t)`**: Returns the normalized perpendicular normal vector $(-dy, dx)$ at $p$.

---

## 3. Spatial Motion Paths

In After Effects, the animation of a layer's spatial property (such as `Position` or `Anchor Point`) is itself represented as a 2D or 3D Bezier curve in coordinate space:
* **Vertices as Keyframes:** Keyframes represent the spatial coordinates $(x, y)$ at specific times $t_k$.
* **Bezier Handles as Curved Trajectories:** Designers can adjust Bezier handles at keyframes on the canvas to curve the trajectory of a moving object.
* **Temporal Speed Profile:** The velocity at which the layer travels along this path is governed by a separate speed graph (which defines the temporal interpolation curve $s(t)$). The actual position of the layer at time $t$ is evaluated by mapping the speed progress to the spatial path:
  $$P(t) = \text{pointOnPath}(s(t))$$

---

## 4. Ramanujan Integration Proposal

`ramanujan` can support these vector animation workflows by leveraging its geometric primitives:

### A. Implementing Path Morphing (Tweening)
We can add a path morphing utility:
```dart
VectorPath morphPaths(VectorPath source, VectorPath target, double progress)
```
* **Step 1 (Topology Equalization):** If segment/vertex counts do not match, split the segments of the simpler path at parametric midpoints (using `Segment.bifurcateAtInterval`) until both paths have matching structures.
* **Step 2 (Linear Interpolation):** Loop through the aligned segments and LERP their endpoints and control points.

### B. Implementing the Path Evaluation API
To support features like `pointOnPath`, `tangentOnPath`, and `normalOnPath`, `ramanujan` needs arc-length parameterization:
1. **Arc Length Table:** Integrate the length of each segment and cache cumulative lengths:
   $$L_{\text{cum}} = [0, l_1, l_1+l_2, \dots, L_{\text{total}}]$$
2. **Query mapping:** For a progress fraction $p \in [0, 1]$, compute target length $d = p \cdot L_{\text{total}}$. Locate the segment index $i$ where $d \in [L_{\text{cum}}[i], L_{\text{cum}}[i+1]]$.
3. **Local Parameter Evaluation:** Map $d$ to a local segment parameter $t \in [0, 1]$.
4. **Coordinate/Vector Extraction:**
   * `pointOnPath(p)` $\to$ `segment.pointAt(t)`
   * `tangentOnPath(p)` $\to$ `segment.tangent(t).normalize()`
   * `normalOnPath(p)` $\to$ `segment.normal(t).normalize()`

This evaluation API is crucial for locking objects (like text or emitter sources) to follow curved splines.
