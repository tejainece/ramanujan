# Corner Rounding — Competitor Analysis

Comparison of ramanujan's corner-rounding primitives (see [corner.md](corner.md)) against how major vector-graphics tools and rendering libraries let users round the corners of a shape.

## Competitors

**Adobe Illustrator — Live Corners** (introduced Illustrator CS6, 2012). A small widget appears at every corner of a path; dragging it rounds that corner live, and double-clicking opens a dialog with a numeric radius and a corner-type dropdown. Corner types offered: **Round**, **Inverted Round**, and **Chamfer**. Each corner takes a single radius value — there's no per-side control within one corner. Rounding is non-destructive — the underlying anchor points stay sharp and the fillet is computed for display/output until the user runs Expand Appearance, which bakes the arcs into real curve anchor points.

**Inkscape — Corners (Fillet/Chamfer) Live Path Effect.** A live, non-destructive effect applied on top of a path: each corner gets a fillet (arc) or chamfer (straight cut) with an editable radius, adjustable per-node via on-canvas handles as well as a global default. Like Illustrator's version, it's baked into real geometry only when the effect is flattened (Path ▸ Object to Path).

**Figma — Corner radius + Corner smoothing.** Rectangles get four independent per-corner radii (drag individual corner handles, or set numerically). Arbitrary vector paths support per-vertex radius the same way — select a point, drag or type a radius. On top of the plain circular-arc radius, Figma has a separate **corner smoothing** control (0–100%) that replaces the abrupt circular arc with a continuous-curvature ("squircle"/superellipse-style) blend — the same style of corner used on iOS app icons, where curvature changes smoothly across the transition instead of jumping instantly at the point where the arc meets the straight edge.

**Skia** (rendering library, not a design tool — the closest thing to a direct API-level peer). Its rounded-corner primitive is `SkRRect`, an axis-aligned rectangle with an independent x/y radius pair per corner. There is no general "fillet the corners of an arbitrary polygon/path" utility in Skia itself; anything beyond the rectangle case is built by the application on top of `SkPath`'s arc-drawing primitives.

**CAD tools (Onshape, Fusion 360) — asymmetric and conic fillets**, included because they're the clearest real-world precedent for genuinely independent per-side radii on a *single* corner (as opposed to per-vertex radii across a whole shape, which is what Figma/CSS/Skia offer). Onshape's Fillet feature has an "Asymmetric" option that takes a second radius for one side of the fillet — but per Onshape's own documentation, once the two sides differ the resulting cross-section is a **conic (a spline), not a circular arc**. This confirms what falls out of the tangent-length theorem (see [corner.md](corner.md)): a literal circle cannot be tangent to two lines at two independently-chosen distances, so any tool offering genuinely asymmetric per-side radii on one corner is, under the hood, building some other conic (an ellipse, here) rather than a circle once the radii diverge.

**CSS / SVG** (baseline renderer primitives, included as an anchor point rather than a competitor). CSS `border-radius` is the same idea as `SkRRect` — four independent corner radii on a box. SVG's `stroke-linejoin` (`miter` / `round` / `bevel`, with `stroke-miterlimit`) rounds the corner formed by a *stroke*, not the corners of the underlying path — the same distinction ramanujan draws between `roundCornerUsing*` (rounds the path itself) and `OffsetJoin` (rounds the join formed when offsetting/stroking).

## Feature comparison

| Feature | ramanujan | Illustrator | Inkscape | Figma | Skia | Onshape |
|---|---|---|---|---|---|---|
| True circular-arc fillet | ✅ (single corner or whole path) | ✅ | ✅ | ✅ | ✅ (rect corners only) | ✅ |
| Independently-honoured asymmetric radius (per side of one corner) | ✅, as an ellipse (`roundCornerUsingEllipticArc`) | n/a (one radius per corner) | n/a (one radius per node) | n/a (one radius per vertex) | ✅ (per corner, not per side) | ✅, as a conic (matches ramanujan's approach) |
| Chamfer / straight-bevel corner style | ✅ (`roundCornerUsingChamfer`) | ✅ | ✅ | ✗ | ✗ | n/a |
| Inverse / concave corner style | ✅ (`roundCornerUsingInvertedArc`) | ✅ (Inverted Round) | ✅ (Inverse Fillet/Chamfer) | ✗ | ✗ | n/a |
| Continuous-curvature ("squircle") corner style | ✅, fixed single cubic (`roundCornerUsingSquircle`) | ✗ | ✗ | ✅, tunable 0–100% smoothing | ✗ | n/a |
| Per-vertex independent radius across a whole shape | ✅ (`roundAllCorners`' `radii` list, one per junction) | ✅ | ✅ | ✅ | ✅ (rect only, 4 fixed corners) | n/a |
| Round every corner of a path in one operation | ✅ (`roundAllCorners`, all seven styles, open and closed paths) | ✅ | ✅ | ✅ | ✅ (rect only) | n/a |
| Non-destructive / re-editable after rounding | ✗ (one-shot geometry replacement) | ✅ | ✅ | ✅ | n/a | ✅ |
| Automatic radius clamping vs. adjacent edge length | ✅ — per-corner clamp in every function, plus cross-corner proportional scale-down in `roundAllCorners` ("half the shorter edge" in the equal-radius case) | ✅ | partial | ✅ | n/a (rect edges are fixed) | n/a |
| Fillet endpoints may traverse past intermediate un-rounded junctions | ✅, opt-in (`traverseSegments: true`) | ✗ | ✗ | ✗ | n/a | n/a |
| Rounding a corner where an adjacent segment is a curve | ✅ (all six styles; Bezier/squircle curvature-continuity is conditional on the neighbor also being straight, see [corner.md](corner.md)) | ✅ | ✅ | ✅ | n/a | ✅ |

## Where ramanujan stands

All four corner *styles* the surveyed tools offer between them — round, inverted round, chamfer, and continuous-curvature/squircle — exist in ramanujan, plus the asymmetric-radius round style that only the CAD tools (Onshape) expose, built the same way Onshape's own documentation says theirs is: as a conic rather than a literal circle once the two radii diverge. All six single-corner functions round a corner regardless of whether either adjacent segment is a curve, matching Illustrator/Inkscape/Figma/Onshape on that axis too (see [corner.md](corner.md) for the one real caveat: the Bezier/squircle styles' curvature-continuity claim only holds when the neighboring segment is also straight). The per-shape workflow — the thing every competitor's actual product surface is — exists as `roundAllCorners`: it walks a whole `VectorPath`/`Loop`, fillets every vertex with any of the seven `CornerStyle`s using either one uniform radius or Figma-style per-vertex radii, clamps radii both per corner and *across* corners (two corners oversubscribing a shared edge are scaled down proportionally, reproducing the "half the shorter edge" cap design tools apply), and splices the result back into a connected path. It also does one thing none of the surveyed tools do: with `traverseSegments: true`, a fillet whose radius outruns its adjacent segment continues across intermediate un-rounded junctions instead of clamping — the natural behavior when a path's "sides" are chains of several segments, such as a polyline approximating a curve. What's missing is the non-destructive layer: rounding is a one-shot geometry replacement, with no re-editable representation that remembers the sharp vertices and re-derives fillets when a radius changes (Illustrator's Live Corners before Expand Appearance, Inkscape's Corners LPE before flattening, Figma's always-live corner radius).

## Gaps, ranked by leverage

#### 1. No non-destructive / re-editable representation
`roundAllCorners` (like the single-corner functions it orchestrates) is a one-shot geometry replacement: the fillets become real segments and the original sharp vertices are gone. Every surveyed design tool keeps rounding live — Illustrator until Expand Appearance, Inkscape until the LPE is flattened, Figma always — so a radius can be re-edited after the fact. The ramanujan equivalent would be a representation that stores the original path plus per-vertex radii/style and re-derives the rounded geometry on demand; mechanically it's a thin layer over `roundAllCorners`, but it's an API-design question (where does the "live" object live, and what invalidates it) more than a geometry one. This is the highest-leverage remaining gap: it's the last workflow difference between "a geometry library with a rounding function" and "how the design tools actually behave."

#### 2. Squircle isn't tunable
Figma's corner smoothing is a 0–100% control that interpolates between a plain circular arc and a fully continuous-curvature blend (a circular-arc-like middle section flanked by easing curves on each side). `roundCornerUsingSquircle` is a single, fixed point on that spectrum — always fully continuous-curvature, with no dial back toward a circular look. Matching Figma's tunable version would mean a genuinely different (multi-segment) construction, not a parameter added to the current one. This stays lowest priority, consistent with ramanujan's technical/geometric orientation versus Figma's icon-design orientation — the fixed, always-continuous version already covers the "I want a smooth, non-circular corner" use case.

## Sources

- [Adobe Illustrator Help — Change corner radius of live shapes](https://helpx.adobe.com/illustrator/desktop/draw-shapes-and-paths/modify-live-shapes/change-corner-radius-of-live-shapes.html)
- [Adobe Illustrator Help — Reshape with Live Corners](https://helpx.adobe.com/nz/illustrator/using/reshape-with-live-corners.html)
- [Adobe Community — Manually constructing an inverted rounded corner pre-Live-Corners](https://community.adobe.com/t5/illustrator-discussions/ai-cs5-inverted-rounded-corners/m-p/3330749) (confirms the construction: a circle centered exactly on the corner, then Pathfinder ▸ Subtract)
- [Figma Blog — Desperately seeking squircles](https://www.figma.com/blog/desperately-seeking-squircles/)
- [Figma Help Center — Adjust corner radius and smoothing](https://help.figma.com/hc/en-us/articles/360050986854-Adjust-corner-radius-and-smoothing)
- [Inkscape Wiki — SpecFilletChamfer](https://wiki.inkscape.org/wiki/SpecFilletChamfer) (original design proposal for the Corners LPE; the shipped effect has evolved since — treat as directional, not an exact current spec)
- [Onshape Help — Fillet](https://cad.onshape.com/help/Content/PartStudio/fillet.htm) (asymmetric fillet's second radius, and the conic cross-section option)
- [Onshape Forum — Conic fillet advantage and working principle](https://forum.onshape.com/discussion/1220/conic-fillet-advantage-and-working-principle) (confirms an asymmetric fillet's cross-section is a spline, not a circular arc)
- [MDN — CSS `border-radius`](https://developer.mozilla.org/en-US/docs/Web/CSS/border-radius)
- [MDN — SVG `stroke-linejoin`](https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/stroke-linejoin)