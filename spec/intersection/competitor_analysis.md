# Segment Intersection — Competitor Analysis

A survey of how established vector geometry libraries handle segment-to-segment
intersection, with focus on which mathematical method each applies to each type of
segment pair.

## Libraries surveyed

| Library | Language | Primary domain |
|---------|----------|----------------|
| 2geom | C++ | Vector drawing (Inkscape) |
| Paper.js | JavaScript | Canvas drawing |
| kurbo | Rust | Font/path geometry (Linebender) |
| Skia PathOps | C++ | 2D rendering (Chrome, Android) |
| lyon | Rust | GPU tessellation |
| fonttools bezierTools | Python | Font engineering |
| booleanOperations | Python | Font production booleans |

## Three methods in use

### Analytic substitution

The implicit equation of one segment is substituted into the parametric form of the
other, producing a univariate polynomial in `t`. The degree depends on the curve types:
line × quadratic gives degree 2, line × cubic gives degree 3. Real roots are found with
closed-form formulae — the quadratic formula for degree 2, Cardano's method for degree 3.
This method is exact and non-iterative. It does not work when the resulting polynomial
degree exceeds 4, because no general radical solution exists above that degree
(Abel-Ruffini theorem).

### Fat-line clipping (Bézier clipping)

Introduced by Sederberg & Nishita (1990). A corridor ("fat line") is computed around
one curve's chord. The other curve's control hull is projected into distance space
relative to that corridor, and the overlapping part of its parameter interval is kept.
The roles alternate, converging on a narrow interval around each intersection. When an
iteration clips less than about 20% of the remaining interval, the curve is bisected at
`t = 0.5` to prevent stagnation. This method is iterative and numerical, but it handles
any polynomial degree — including cubic × cubic — without ever forming a high-degree
resultant polynomial.

### Bounding-box subdivision

Both curves are recursively bisected at `t = 0.5` until their bounding boxes are small
enough to treat as line segments. Simpler to implement than fat-line clipping but
converges more slowly and yields only an approximate result.

## Method by segment pair

"analytic d=N" means the library derives a degree-N polynomial and solves in closed
form. "fat-line" means Sederberg-Nishita clipping. "BBox subdiv" means bounding-box
subdivision. "—" means not implemented.

| Pair | 2geom | Paper.js | kurbo | Skia | lyon | fonttools |
|------|-------|----------|-------|------|------|-----------|
| line × line | analytic d=1 | analytic d=1 | analytic d=1 | analytic d=1 | analytic d=1 | analytic d=1 |
| line × quadratic | analytic d=2 | analytic d=2 | analytic d=2 | analytic d=2 | analytic d=2 | analytic d=2 |
| line × cubic | analytic d=3 | analytic d=3 | analytic d=3 | analytic d=3 | analytic d=3 | analytic d=3 |
| quadratic × quadratic | fat-line | fat-line | — | BBox subdiv | fat-line | BBox subdiv |
| quadratic × cubic | fat-line | fat-line | — | BBox subdiv | fat-line | BBox subdiv |
| cubic × cubic | fat-line | fat-line | — | BBox subdiv | fat-line | BBox subdiv |
| arc × anything | — | — | — | — | — | — |

booleanOperations (Python, typemytype) is excluded from the table because it does not
implement any segment intersection at all. It flattens every curve to line segments
first (adaptive step, about 5.3 font units by default) and passes the resulting polygon
to the Clipper library, which runs Vatti's polygon clipping algorithm. The output
polygon is then re-matched to the original curve parameters. This is the most
approximate approach in the survey; it is useful for font production where robustness
matters more than geometric precision.

## Notable details per library

2geom is the most complete implementation. Its fat-line clipping is in
`bezier-clipping.cpp` (Marco Cecchetti, 2008). For the line × cubic special case, a
newer code path (MR !84) rotates coordinates to axis-align the line and solves the
resulting degree-3 polynomial analytically. Tangent and collinear contacts use a
separate "focus curve" construction. Endpoint coincidence is caught by a post-pass in
`path-intersection.cpp`.

Paper.js follows the same Sederberg-Nishita algorithm as 2geom, attributed to
contributor `@hkrish`. For line × cubic it calls `getCurveLineIntersections()`, which
rotates the curve to axis-align the line and calls `Curve.solveCubic`. For curve × curve
it runs the fat-line loop with a hard recursion cap of 40 levels and 4096 total calls.

kurbo is the only library that is strictly analytic-only, by design. `intersect_line`
in `bezpath.rs` handles line × line, line × quadratic, and line × cubic, all via
polynomial substitution. `solve_cubic` in `common.rs` follows Jim Blinn's discriminant
method: `d < 0` gives one real root via `cbrt`; `d > 0` gives three real roots via the
trigonometric form. Curve × curve intersection is an open issue (#277) with no
implementation timeline.

Skia is a hybrid. For line × cubic it uses a resultant-derived polynomial that was
computed once offline with Mathematica and hard-coded in `SkDCubicLineIntersection.cpp`;
the Cardano/trig path finds the roots at runtime. All curve × curve pairs go through
the generic `SkTSect::BinarySearch` template, which intersects bounding hulls
(`hullsIntersect`) and bisects spans until they are near-linear, then solves the
near-linear sub-problem analytically. A separate `SkOpCoincidence` pass handles
coincident (overlapping) curve segments.

lyon is a near-direct port of Paper.js's fat-line implementation into Rust. The
public API is `cubic_bezier_intersections_t(curve1, curve2)` returning up to 9 parameter
pairs. Convergence epsilon is `1e-9` (f64); duplicates within `1e-3` of each other are
merged. Only cubic × cubic is exposed; line × curve goes through a simpler path.

fonttools bezierTools uses analytic substitution for line × curve (same rotate-and-solve
pattern) and bounding-box subdivision for curve × curve. Subdivision recurses until
bounding-box area falls below a threshold; results within `1e-3` of each other are
deduplicated.

## Key observations

For line × curve intersection, every library independently uses analytic substitution.
The pattern is always the same: rotate or translate so the line aligns with an axis,
substitute into the curve's parametric form, and solve the resulting low-degree
polynomial in closed form.

For curve × curve intersection, fat-line clipping is the production standard. 2geom,
Paper.js, and lyon all implement Sederberg-Nishita. Paper.js and lyon share the same
implementation lineage. The main advantage is that it handles any polynomial degree
without constructing a high-degree resultant polynomial.

No production library uses online resultant or Bézout determinants to intersect two
curves. The degree-9 Sylvester matrix for cubic × cubic is well documented in the
academic literature (Sederberg 1989; Buse, Khalil & Mourrain 2005) but is absent from
all surveyed codebases, primarily because of numerical fragility.

No library implements arc × Bézier or arc × arc intersection analytically. Those pairs
are either not supported or handled by converting the arc to a rational Bézier first and
running the general curve × curve path.

The research literature contains more refined clipping variants — quadratic clipping
(Barton & Jüttler 2007), cubic clipping (Liu et al. 2009), and fourth-order hybrid
clipping (Wu & Li 2022) — none of which have been adopted by any of the surveyed
libraries as of 2026.

## Sources

- 2geom bezier-clipping.cpp — https://gitlab.com/inkscape/lib2geom
- Paper.js Curve.js — https://github.com/paperjs/paper.js/blob/develop/src/path/Curve.js
- hkrish fat-line notes — https://gist.github.com/hkrish/0a128f21a5b9e5a7a914
- kurbo bezpath.rs / common.rs — https://github.com/linebender/kurbo
- kurbo issue #277 — https://github.com/linebender/kurbo/issues/277
- Skia pathops directory — https://github.com/google/skia/tree/main/src/pathops
- lyon cubic_bezier_intersections.rs — https://github.com/nical/lyon
- fonttools bezierTools.py — https://github.com/fonttools/fonttools
- booleanOperations — https://github.com/typemytype/booleanOperations
- Sederberg & Nishita 1990, "Curve intersection using Bézier clipping"
- Wu & Li 2022, "Hybrid Cubic Clipping" — https://pmc.ncbi.nlm.nih.gov/articles/PMC9218043/
