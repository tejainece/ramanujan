# Boolean Operations — The "Normal Case"

ramanujan's boolean operations — **union**, **difference**, **intersection**, and
**exclusive-or (XOR)** — are specified and implemented for the **normal case** only.

This is a deliberate scope decision. Robust handling of every degenerate configuration (the kind
of hardening Clipper2, livarot, or 2geom carry) is explicitly **out of scope**. Instead, the
library defines a precise set of preconditions — the *normal case* — under which the result is
well-defined and correct, and leaves everything outside that contract to the **caller**.

> **In one line:** boolean ops are correct when the two input paths are *closed, simple, and meet
> only at clean, transversal crossings*. Anything else is the caller's responsibility.

---

## What the operations work on

- Inputs are **closed paths** (the start and end points coincide so the path encloses a region).
- Curved paths (cubic/quadratic Béziers, arcs) are **flattened to polylines** first (via the
  existing `polyline` / `toLines` machinery) and the boolean is computed on those polygons.
  Curve-exact booleans are not provided; flattening tolerance controls fidelity.
- Each input must be a **single, simple polygon** (one closed ring, no self-intersection). Paths
  with holes or multiple disjoint rings are **not** a normal-case input.

---

## Definition of the normal case

An input pair `(A, B)` is in the **normal case** when **all** of the following hold:

### 1. Both paths are closed
Each path forms a complete loop enclosing a finite region. Open paths have no inside/outside, so
boolean set operations are undefined for them.

### 2. Both paths are simple (no self-intersection)
A path's edges do not cross or touch each other except at shared endpoints of consecutive edges.

```
   normal (simple)            EXCLUDED (self-intersecting)
   ┌──────────┐                    ┌─────┐
   │          │                     \   /
   │          │                      \ /
   │          │                       X        ← edges cross
   └──────────┘                      / \
                                    /   \
                                   └─────┘
```

### 3. Intersections are transversal (clean crossings)
Where edge of `A` meets edge of `B`, they **cross through** each other — passing from one side to
the other. The boundaries are not tangent and do not merely graze.

```
   normal (transversal)        EXCLUDED (tangential / grazing)
        │                              │
   ─────┼─────   A crosses B      ─────┘        A only touches B,
        │                          ▲  ▲          does not cross
                                   B  B
```

### 4. No coincident or overlapping (collinear) edges
No edge of `A` lies on top of, or partially overlaps, an edge of `B`. Shared boundary segments
between the two inputs are not supported.

```
   normal                       EXCLUDED (collinear overlap)
   A: ───────                   A: ─────────
   B:      ───────              B:    ──────────
      (cross at a point)           (shared run of boundary)
```

### 5. No vertex lies on the other path's edge
A vertex of `A` must not fall exactly on an edge of `B` (and vice versa). Crossings happen in the
*interior* of edges, never at a vertex.

```
   normal                       EXCLUDED (vertex-on-edge)
        ●                              ●───── B
       /│\        A's vertex away      │
      / │ \       from B's edge    ────●───── A vertex sits on B's edge
   ───┼─┼─┼─── B
```

### 6. A finite number of intersection points
`A` and `B` cross at finitely many isolated points. (This follows from 1–5, but is stated so the
walking phase can assume a discrete, alternating in/out sequence.)

---

## Behaviour outside the normal case

When a precondition is violated the result is **undefined** — the operation may return an
incorrect polygon, an empty result, or throw. Callers must not rely on any particular outcome.

The implementation **should** (where cheap to detect) recognise the common degeneracies —
**collinear/overlapping edges** and **vertex-on-edge** — and **throw a clear error** rather than
return silent garbage. Detection is best-effort and subject to the floating-point caveat below; a
thrown error is a courtesy, not a guarantee.

It is the **caller's** responsibility to bring inputs into the normal case before calling — e.g.
by cleaning/simplifying self-intersections, snapping or perturbing coincident geometry, or
splitting multi-ring paths into single simple rings.

---

## Floating-point caveat

The normal/degenerate distinction is geometric, but the computation is floating-point. Inputs that
*look* normal can land **near-degenerate** after arithmetic — two crossings almost coincident, or a
crossing falling within rounding distance of a vertex. A small epsilon tolerance is used to absorb
the common cases, but it cannot eliminate all of them. Expect occasional failures on inputs that
appear normal but are numerically near a degeneracy. This is accepted for the normal-case scope.

---

## Out of scope (caller-handled or future work)

- Self-intersecting input paths
- Coincident / overlapping collinear boundaries
- Vertex-on-edge and tangential (grazing, non-crossing) contacts
- Open paths
- Paths with holes or multiple disjoint rings
- Curve-exact (non-flattened) boolean results
- Fully robust degeneracy handling à la Clipper2 / livarot / 2geom
