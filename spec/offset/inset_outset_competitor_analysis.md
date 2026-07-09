# Inset/Outset — Competitor Analysis

This document compares ramanujan's `insetOutset` (and its `inset`/`outset` wrappers) against three reference implementations: **Adobe Illustrator** (Offset Path), **Inkscape** (lib2geom's `Inset`/`Outset` command and its `Dynamic Offset`/`Linked Offset` LPE), and **Clipper2** (the de-facto open-source reference for polygon offsetting, used internally or as inspiration by many other tools). The goal is to place ramanujan's algorithm and its recently added self-intersection cleanup pass in context, and to record which gaps remain.

---

## Competitors at a glance

| Implementation | Curve handling | Self-intersection cleanup | Cleanup scope |
|---|---|---|---|
| **ramanujan** (`insetOutset`) | Exact parametric (lines, circular arcs); Bézier-fit approximation for cubics/quadratics/elliptical arcs | On by default (`cleanup: true`) | Per-call, single loop |
| **Illustrator** (Offset Path) | Internal approximation, Bézier refit at output | Built into the command, not user-visible | Whole compound path |
| **Inkscape** `Path > Inset`/`Outset` | Exact parametric (lib2geom) | **None** — local join resolution only | N/A |
| **Inkscape** `Dynamic Offset`/`Linked Offset` LPE | Exact parametric | Yes — "de-looping" pass | Whole path |
| **Clipper2** `InflatePaths` | Polygon only (curves must be flattened first) | Yes — self-union under the non-zero rule | Whole polygon set |

---

## Algorithm

### ramanujan

`insetOutset` runs in two stages:

1. **Per-segment offset + local join resolution.** Each segment is offset along its normal independently, preserving type where the true offset is the same type (lines → lines, circular arcs → concentric circular arcs) and Bézier-fitting where it isn't (cubics, quadratics, elliptical arcs). Adjacent offset edges are then reconciled at each corner: convex corners are bridged with the selected `OffsetJoin` (`miter`/`round`/`bevel`); concave corners are trimmed back to the edges' intersection. This stage only looks at each corner's immediate neighbours.
2. **Global cleanup.** The result of stage 1 can still self-intersect when `delta` is large relative to a feature (a narrow neck, a deep notch, overlapping convex lobes) — the local join logic has no way to see that. Since stage 1 output is closed, it's fed through `simplifyClosedPath`, which decomposes it into its correctly-filled atomic faces via the same planar half-edge graph the boolean-operations pipeline uses (`divideSelfIntersecting` → `buildFaces`), then `mergeFaces` re-stitches the atomic faces into a single minimal loop by cancelling shared interior edges. `simplifyClosedPath` returns the input unchanged when there's no self-intersection, so this stage is a no-op for the common case — verified by the existing test suite passing byte-for-byte unchanged with cleanup enabled.

This reuses machinery that already existed in the codebase for boolean operations; no new geometry algorithm was introduced for the cleanup pass itself.

### Illustrator (Offset Path)

Proprietary and undocumented. Based on observed output, it computes the offset with the same normal-displacement formula, approximates Bézier offsets by recursive subdivision + refit, and resolves self-intersections internally before returning — the result is a single well-formed compound path, and users are not exposed to a "raw" intermediate. In practice designers still sometimes follow it with `Pathfinder > Unite` on complex paths, suggesting the internal cleanup isn't airtight in every case, though this is inference from common workflow advice rather than documented behavior.

### Inkscape

Inkscape exposes the same underlying offset math through two different UI entry points with different robustness:

* **`Path > Inset` / `Path > Outset`** (Ctrl+`(` / Ctrl+`)`) is the naive, locally-resolved offset — the same category of algorithm as ramanujan's stage 1 alone. It has no de-looping pass, and is commonly reported to leave self-intersecting cusps and glitches when the offset exceeds the size of a concave feature or sharp corner.
* **`Dynamic Offset` / `Linked Offset`** LPE runs the more robust lib2geom offset path, which includes a simplification/union-filtering pass over the raw offset curve to remove degenerate loops — Inkscape's own documentation and code comments call this "de-looping." This is functionally the same goal as ramanujan's stage 2, arrived at independently.

### Clipper2

The reference open-source algorithm for polygon offsetting, and the closest published description of the general technique. `InflatePaths` offsets each polygon edge, then treats the *entire* raw offset (all edges from all input polygons) as one path set and runs it through Clipper's own polygon union under the non-zero fill rule. Overlapping same-orientation regions merge into one; reversed-orientation "bowtie" artifacts from over-aggressive insetting cancel out and disappear. This is conceptually identical to ramanujan's stage 2 — both resolve offset self-intersection by re-running a general-purpose boolean/planar-arrangement algorithm over the raw offset rather than special-casing the offset geometry. The difference is substrate: Clipper2 operates on flattened polygons (curves must be discretized first), while ramanujan's cleanup operates directly on the exact segment types (lines, circular arcs, Béziers) produced by stage 1.

---

## Feature comparison

| | ramanujan | Illustrator | Inkscape (Inset/Outset) | Inkscape (Dynamic Offset) |
|---|---|---|---|---|
| Miter / Round / Bevel joins | Yes | Yes | Yes | Yes |
| Exact line/arc offset | Yes | Yes (arcs are rare in Illustrator paths, which are cubic-only) | Yes | Yes |
| Self-intersection cleanup | Yes, on by default | Yes, always on | **No** | Yes |
| Cleanup is user-toggleable | Yes (`cleanup: false` to inspect the raw artifact) | No | N/A (no cleanup exists) | No |
| Multi-island output (offset splits into disjoint pieces) | **No — keeps only the largest island by area** | Yes | N/A (would just produce broken geometry) | Yes |
| Compound-path / hole-aware offsetting | **No — one loop per call, no interaction between an outer boundary and its holes** | Yes | Yes | Yes |
| Variable/tapered width offset | Yes, but via a separate function (`strokeExpand`, not `insetOutset`) | Only via the manual Width Tool, not Offset Path | No | No |

---

## Where ramanujan is stronger

**Cleanup is explicit and inspectable.** `cleanup: false` returns the raw, possibly self-intersecting offset directly — useful for testing the cleanup logic itself, or for callers who want to run their own resolution. Illustrator and Inkscape's Dynamic Offset both perform cleanup as an opaque, un-skippable part of the command.

**Exact curve preservation.** Lines and circular arcs offset to lines and circular arcs, not Bézier approximations of them, both before and after cleanup — matching the exact-curve philosophy documented for the boolean pipeline in [../boolean/competitor_analysis.md](../boolean/competitor_analysis.md).

**Auditable, reused machinery.** The cleanup pass is not a bespoke offset-specific algorithm; it's the same `simplifyClosedPath`/`mergeFaces` pipeline already documented and tested for boolean operations. There's one face-decomposition algorithm in the codebase, not two.

---

## Where ramanujan has gaps

**Single-loop output.** `insetOutset` always returns one `List<Segment>`. When a large offset pinches a shape into disjoint islands — insetting a dumbbell past its waist is the canonical example — the cleanup pass keeps only the largest island by area and silently discards the rest. Illustrator, Inkscape's Dynamic Offset, and Clipper2 all operate on (or produce) compound/multi-contour output natively, so nothing is dropped. Closing this gap would mean changing the return type to `List<List<Segment>>` (or a `Region`), which is a breaking API change not made as part of the cleanup work.

**No compound-path or hole awareness.** All four competitors' offset commands treat a shape-with-holes as one atomic operation: insetting a hole enough to swallow it, or to merge it with the outer boundary, is resolved automatically. `insetOutset` only ever sees one loop; offsetting a `Region` with holes means calling it per-loop and re-combining by hand, with no automatic interaction between the outer boundary's offset and each hole's offset.

**No production hardening.** No fuzz testing and no years of user-reported edge cases, the same caveat noted for the boolean pipeline in [../boolean/competitor_analysis.md](../boolean/competitor_analysis.md). The cleanup pass is validated against constructed cases (deep stars, overlapping rounded spikes) and the existing unit-test corpus, not against a large corpus of real-world paths.

---

## Related

* [../boolean/competitor_analysis.md](../boolean/competitor_analysis.md) — the equivalent analysis for boolean operations; the cleanup pass here reuses that pipeline directly.
* [../feature_planning/inkscape.md](../feature_planning/inkscape.md) — originally proposed the "de-looping" step implemented here (`Adding a "de-looping" step: when offsetting a path, self-intersections can be resolved by running the offset result through simplifyClosedPath`), now implemented in `lib/src/mapper/inset_outset.dart`.
* [../feature_planning/illustrator.md](../feature_planning/illustrator.md) — Offset Path's parameters and join geometry, which `insetOutset`'s `OffsetJoin` enum mirrors.
