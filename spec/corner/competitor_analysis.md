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
| True circular-arc fillet | ✅ (single corner only) | ✅ | ✅ | ✅ | ✅ (rect corners only) | ✅ |
| Independently-honoured asymmetric radius (per side of one corner) | ✅, as an ellipse (`roundCornerUsingEllipticArc`) | n/a (one radius per corner) | n/a (one radius per node) | n/a (one radius per vertex) | ✅ (per corner, not per side) | ✅, as a conic (matches ramanujan's approach) |
| Chamfer / straight-bevel corner style | ✅ (`roundCornerUsingChamfer`) | ✅ | ✅ | ✗ | ✗ | n/a |
| Inverse / concave corner style | ✅ (`roundCornerUsingInvertedArc`) | ✅ (Inverted Round) | ✅ (Inverse Fillet/Chamfer) | ✗ | ✗ | n/a |
| Continuous-curvature ("squircle") corner style | ✅, fixed single cubic (`roundCornerUsingSquircle`) | ✗ | ✗ | ✅, tunable 0–100% smoothing | ✗ | n/a |
| Per-vertex independent radius across a whole shape | ✗ (no whole-shape op exists) | ✅ | ✅ | ✅ | ✅ (rect only, 4 fixed corners) | n/a |
| Round every corner of a path in one operation | ✗ | ✅ | ✅ | ✅ | ✅ (rect only) | n/a |
| Non-destructive / re-editable after rounding | ✗ (one-shot geometry replacement) | ✅ | ✅ | ✅ | n/a | ✅ |
| Automatic radius clamping vs. adjacent edge length | ✗ | ✅ | partial | ✅ | n/a (rect edges are fixed) | n/a |
| Rounding a corner where an adjacent segment is a curve | ✗ | ✅ | ✅ | ✅ | n/a | ✅ |

## Where ramanujan stands

All four corner *styles* the surveyed tools offer between them — round, inverted round, chamfer, and continuous-curvature/squircle — now exist in ramanujan, plus the asymmetric-radius round style that only the CAD tools (Onshape) expose, built the same way Onshape's own documentation says theirs is: as a conic rather than a literal circle once the two radii diverge. What's still missing is entirely about *operating at the scale of a whole shape* rather than one hand-picked corner: no whole-path "round every corner" entry point, no radius clamping once such an operation exists, no non-destructive/re-editable representation, and no support for a corner where either adjacent segment is itself a curve. Measured against any of the four design tools above, ramanujan now offers the same *variety* of corner geometry per corner that they do; it's the per-shape workflow around that geometry — find every vertex, round it, splice it back in, keep it editable — that a caller still has to build themselves.

## Gaps, ranked by leverage

### Resolved

- **Asymmetric per-side radius** (`roundCornerUsingEllipticArc`) — the circular-arc function's two radius parameters are now honored independently via an exact tangent ellipse, rather than silently averaged. The circular-arc function itself still averages, since that's a hard geometric constraint on a literal circle, not a bug; this is documented rather than papered over.
- **Chamfer** (`roundCornerUsingChamfer`) — a straight bevel between the two independently-cut points.
- **Inverse/concave corner style** (`roundCornerUsingInvertedArc`) — cuts both lines back to the same points a normal round would, then bridges them with the arc of that radius's circle centered on the original vertex (the same construction as centering a circle on a corner and Boolean-subtracting it), meeting each line at a right angle rather than tangentially. An earlier version instead extended both lines past the vertex and bridged them with a tangent arc — geometrically valid but not what Illustrator's Inverted Round / Inkscape's Inverse Fillet actually look like; that's corrected now.
- **Continuous-curvature/"squircle" style** (`roundCornerUsingSquircle`) — a single cubic with both interior control points anchored at the vertex, which is provably the only way a single cubic gets zero curvature at both ends. Not a tunable, Figma-equivalent blend (see below).
- **Broken cubic implementation** — the discontinuity bug (trailing segment built from the sharp vertex instead of the cubic's actual endpoint) is fixed; the returned three segments now connect exactly.
- **Leftover debug `print`** — removed from the circular-arc function.
- **Test coverage** — `test/rounded/rounded_test.dart` now covers all six functions.

### Remaining

#### 1. No whole-path rounding operation
Every competitor's actual product surface is "round all (or selected) corners of this shape," not "round this one pair of lines." Building that operation — walk a closed path, find each vertex, apply the appropriate corner-rounding function, and splice the results back together — is still the single highest-leverage change: it turns a set of internal geometry helpers into the feature users of Illustrator, Inkscape, and Figma actually expect.

**Impact:** without this, ramanujan cannot be used for the common case (round every corner of a polygon/icon/technical drawing) without the caller reimplementing path traversal and splicing themselves.

#### 2. No radius clamping against edge length
An oversized radius on a short edge needs to be capped once corners are rounded at the scale of a whole path — otherwise adjacent corners' fillets overlap or invert. Every design tool surveyed does this automatically. This is a natural follow-on to gap 1, not useful in isolation until whole-path rounding exists.

#### 3. Corners adjacent to curved segments are unsupported
All six current functions require both adjacent segments to be straight lines. Illustrator, Inkscape, Figma, and Onshape all round corners regardless of what kind of segment meets there. This is architecturally the hardest remaining gap to close (it needs a general tangent-offset construction per segment type, similar to what `insetOutset`'s per-type offset dispatch already does).

#### 4. Squircle isn't tunable
Figma's corner smoothing is a 0–100% control that interpolates between a plain circular arc and a fully continuous-curvature blend (a circular-arc-like middle section flanked by easing curves on each side). `roundCornerUsingSquircle` is a single, fixed point on that spectrum — always fully continuous-curvature, with no dial back toward a circular look. Matching Figma's tunable version would mean a genuinely different (multi-segment) construction, not a parameter added to the current one.

## Priority

With the cubic discontinuity, the debug `print`, and the missing corner styles (asymmetric radius, chamfer, inverted, squircle) all resolved, the highest-leverage remaining gap is the whole-path rounding operation (gap 1): it's the actual feature every competitor ships, and it's the prerequisite that makes radius clamping (gap 2) meaningful. Curve-adjacent corners (gap 3) is the deeper, longer-lead investment. A tunable squircle (gap 4) is lowest priority, consistent with ramanujan's technical/geometric orientation versus Figma's icon-design orientation — the fixed, always-continuous version already covers the "I want a smooth, non-circular corner" use case.

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