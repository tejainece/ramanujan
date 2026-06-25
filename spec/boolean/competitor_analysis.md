# Boolean Operations — Competitor Analysis

This document compares ramanujan's boolean pipeline against three reference implementations: **Inkscape (lib2geom)**, **Adobe Illustrator**, and **Skia PathOps** (the engine used by Chrome, Android, and Flutter). The goal is to understand where ramanujan is stronger, where it has gaps, and which gaps matter in practice.

---

## Competitors at a glance

| Library | Used by | Curve handling | Algorithm family |
|---|---|---|---|
| **lib2geom** | Inkscape | Exact parametric | Sweep-line (Bentley-Ottmann variant) |
| **Illustrator** | Adobe CC | Internal approximation | Proprietary (Vatti-style clip suspected) |
| **Skia PathOps** | Chrome, Flutter, Android | Exact parametric (cubics only) | Custom sweep with winding analysis |
| **ramanujan** | — | Exact parametric | Face-based planar subdivision |

Clipper2 and GEOS are intentionally excluded: they operate on polygons only, flattening all curves before processing, so they are not meaningful comparators for a library that preserves exact curve geometry.

---

## Algorithm

### ramanujan

A four-step **face-based pipeline** built on a half-edge planar graph:

1. Simplify each input into simple closed faces (decompose self-intersections, drop zero-area remnants).
2. Find all A×B segment intersections, split at crossing parameters, build the planar subdivision.
3. Classify each face by containment; filter by operation (union/intersection/difference/XOR).
4. Remove interior shared edges between adjacent kept faces; chain survivors into output rings.

This is not a named classical algorithm. It avoids the sweep-line machinery entirely, operating directly on the combinatorial face structure.

### lib2geom (Inkscape)

Uses a **sweep-line algorithm** derived from Bentley-Ottmann. Curve intersections are found by parametric subdivision with Newton refinement. The sweep produces a set of monotone regions that are then classified and merged. The approach is general but requires careful numerical windowing to avoid missed intersections during subdivision.

### Skia PathOps

A custom sweep that works in **exact integer arithmetic** (paths are converted to a fixed-point rational representation). Because the arithmetic is exact, many degenerate cases that trip up floating-point implementations are handled cleanly. The tradeoff is that input coordinates must be snapped to a rational grid, which introduces a controlled but nonzero quantisation error on general floating-point inputs.

### Illustrator

The algorithm is proprietary and not publicly documented. Based on output behavior and historical technical notes, it is believed to be a **Vatti-style clip** with curve approximation at intersection boundaries. The implementation has been hardened over decades of production use, making it the robustness reference point, but exact curve preservation in output is not guaranteed — output paths sometimes contain tiny linear segments at junctions where curves met.

---

## Curve intersection

The core numerical challenge: finding where two cubic Béziers cross.

### ramanujan

Eliminates one parameter using the **Sylvester resultant**, reducing the problem to a univariate degree-9 polynomial in `t`. Roots are found by:

1. Dense sampling (1 000 points) to locate sign-change brackets.
2. Bisection refinement (up to 60 iterations per bracket).
3. Extremum detection near zero for even-multiplicity roots (tangencies).

This is systematic: it provably finds all roots including near-tangencies, because the bracketing step is exhaustive. The cost is O(1 000) evaluations of the degree-9 polynomial per pair; for typical path complexity this is fast.

### lib2geom

Adaptive **subdivision**: recursively bisect both curves until each sub-arc is nearly linear, then check linear-linear intersection. This is fast in the common case but can miss near-tangent intersections when the subdivision terminates before the curves are close enough. lib2geom has had production bugs in this area.

### Skia PathOps

Converts curves to **rational exact arithmetic** and intersects in that domain. Effectively immune to floating-point near-miss failures but introduces a grid-snap that is visible when coordinates are not originally rational.

### Illustrator

Believed to use subdivision, with additional heuristics tuned over many years. Output quality on near-tangent curves is generally good but the mechanism is opaque.

---

## Fill rule

| | even-odd | non-zero winding |
|---|---|---|
| ramanujan | Yes | Yes |
| lib2geom | Yes | Yes |
| Skia PathOps | Yes | Yes |
| Illustrator | Yes | Yes |

Both fill rules are implemented. The face-classification call in step 3 delegates to `Region.contains`, which dispatches on the region's `fillRule` field. Non-zero winding accumulates signed crossings: `_crossingSign` samples a short finite-difference interval to determine whether the boundary is travelling upward (+1) or downward (−1) at each crossing, and crossings at the same x-coordinate are grouped before accumulating so tangential touches (opposite signs cancel) correctly contribute zero. The fill rule is carried by the `Region` objects passed through the pipeline, so no extra threading was required.

The output region always uses `FillRule.evenOdd`: the pipeline emits only CCW (positive-area) faces, meaning all loops are already correctly oriented and both rules produce identical results on the output.

---

## Degenerate cases

### Coincident edges

| | Full-segment coincidence | Partial overlap (≥1 endpoint in the shared region) | Sub-interval (both transition points interior to both segments) |
|---|---|---|---|
| ramanujan | Handled | Handled | Not handled |
| lib2geom | Handled (historically buggy) | Partially | Not handled |
| Skia PathOps | Handled | Partially | Not handled |
| Illustrator | Handled | Handled | Unknown |

ramanujan detects full-segment coincidence via polynomial coefficient matching (closed-form: match cubic coefficients degree by degree to solve for the linear reparametrisation B(s) = A(αs + β)). Partial overlaps — where at least one endpoint of either segment lands within the coincident region — are handled by probing all four endpoints via `ilerp` and recovering the overlap interval from whichever probes return valid parameters.

The unsupported sub-case is when both transition points (where the paths diverge) are interior to their respective segments, so none of the four endpoint probes find valid parameters. This requires solving a nonlinear system with no closed form. Per ramanujan's own spec, no production library handles this case: Skia PathOps, GEOS, Clipper2, and 2geom all restrict curve coincidence handling to the full-segment case.

### Self-intersecting input paths

ramanujan explicitly pre-processes self-intersecting inputs via `divideSelfIntersecting`, decomposing them into simple face paths before the boolean pipeline runs. This is equivalent to what the other tools achieve through winding-number classification during the sweep. The outcome is the same; ramanujan's approach makes it a separate, testable step rather than a side effect of the sweep.

### Tangential contacts

ramanujan's resultant approach detects even-multiplicity roots (tangencies) via polynomial extrema near zero. lib2geom's subdivision can miss these when the contact is near-degenerate. Skia's exact arithmetic handles them cleanly.

### Vertex on edge

All four implementations handle this. ramanujan snaps intersection points to graph nodes within `1e-4`; the split is recorded on the non-endpoint segment while the vertex segment is left at its existing graph node.

### Open paths

| | ramanujan | lib2geom | Skia PathOps | Illustrator |
|---|---|---|---|---|
| Open path input | **Not supported** | Limited | Not supported (paths must be closed) | Supported (as stroked outlines) |

Illustrator's Pathfinder can operate on open paths by treating them as the outline of a zero-width stroke. The other tools, including ramanujan, require closed paths.

---

## Robustness

All four implementations are susceptible to failures on numerically near-degenerate inputs. The differences are in degree and mitigation strategy.

**Skia PathOps** is the most robust by design: exact integer arithmetic eliminates floating-point failures at the cost of a rational grid. It is fuzz-tested extensively and is the implementation Chrome relies on for SVG rendering correctness.

**Illustrator** is the most battle-tested in practice: 35+ years of designer bug reports have driven corner-case coverage that no open-source library matches. Output is not always geometrically exact but is nearly always visually correct.

**lib2geom** has historically been the most fragile, producing crashes or garbage on complex inputs. The Inkscape 1.x series substantially improved this, but production designers still encounter failures on pathological inputs.

**ramanujan** explicitly accepts occasional failures on near-degenerate inputs. Its tolerance strategy (`1e-4` node snap, `1e-6` parameter deduplication) is appropriate for programmatically constructed geometry. Paths round-tripped from Illustrator/Inkscape SVG may carry coordinate noise that pushes near-degenerate cases into failure.

---

## Where ramanujan is stronger

**Exact curve output.** Because the pipeline never flattens, output segments are always the same primitive types as the inputs — cubic stays cubic, arc stays arc. Illustrator's output sometimes contains small linear segments at curve junctions. lib2geom and Skia also preserve curves in principle but with more rounding at split points.

**Systematic intersection finding.** The Sylvester resultant + exhaustive bracketing provably locates all roots of the degree-9 intersection polynomial, including near-tangencies that subdivision-based implementations can miss.

**Auditable specification.** The algorithm is fully documented in `boolean.md`, `face_stitching.md`, and `decompose_self_intersecting.md`. Inkscape's lib2geom is partially documented; Illustrator and Skia PathOps are essentially opaque.

**Separation of concerns.** Each pipeline step (simplify, split, filter, merge) is independently testable and replaceable. This makes the boolean algorithm easier to reason about and extend than a monolithic sweep implementation.

---

## Where ramanujan has gaps

**Open paths.** Low priority for a library focused on closed shape geometry, but worth noting.

**Sub-interval curve coincidence (both transition points interior to both segments).** This is a universal limitation: Skia PathOps, lib2geom, GEOS, and Clipper2 all leave it unhandled. In practice it arises when two paths were independently trimmed from the same source curve, with neither trim point landing at a segment boundary — uncommon in hand-authored paths, possible in programmatically generated geometry.

**Production hardening.** No fuzz testing, no years of designer-reported edge cases. Failures on numerically noisy SVG inputs from design tools should be expected until the library accumulates coverage comparable to its competitors.
