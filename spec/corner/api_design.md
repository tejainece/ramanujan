# Corner Rounding — API Design (Proposal)

This document proposes a redesigned public surface for corner rounding. It replaces the seven near-duplicate top-level functions and the two disjoint radius vocabularies described in [corner.md](corner.md). This is a design proposal, not a description of what is implemented today. Unlike `corner.md`, this document is free to reference real code, since its whole purpose is proposing what that code should look like.

## Problems with the current surface

The current surface is seven top-level functions, `roundCornerUsingCircularArc`, `roundCornerUsingEllipticArc`, `roundCornerUsingInvertedArc`, `roundCornerUsingChamfer`, `roundCornerUsingQuadraticBezier`, `roundCornerUsingCubicBezier`, and `roundCornerUsingSquircle`, plus a separate whole-path function, `roundAllCorners`, that takes a `CornerStyle` enum instead of a function choice. Four problems fall out of that shape.

The single-corner and whole-path radius vocabularies don't match. Every single-corner function takes two independent radii, `radius1` and `radius2`. `roundAllCorners` only takes one radius per corner, either a single shared value or a per-vertex list. It cannot express an asymmetric corner at all, even though five of the seven styles honor asymmetric radii perfectly well underneath. The whole-path operation is not a superset of the single-corner one. It is a narrower vocabulary wearing the same style names.

Two of the seven styles silently ignore half their input. `roundCornerUsingCircularArc` and `roundCornerUsingInvertedArc` take `radius1`/`radius2` on their signature, then average them into one true radius before doing anything, because a real circle only has one radius per corner. Nothing in the signature says so. A caller comparing that signature to `roundCornerUsingChamfer`'s, which is identical in shape, has no way to tell that one call honors both numbers and the other quietly blends them.

Style selection uses two unrelated vocabularies. For a single corner, the style is which function you call. For a whole path, the style is a value of `CornerStyle`. These name the same seven concepts two different ways, and the enum's `averagesRadii` flag has no counterpart at all on the single-corner side. A caller holding one kind of style value has to translate it before using the other entry point.

`roundCornerUsingSquircle` is an alias, not a style. It performs the exact same construction as `roundCornerUsingCubicBezier`, with no parameter or behavior difference. It is a fully duplicated entry point, and a fully duplicated `CornerStyle` member, for zero additional behavior.

## Proposed radius model

Replace `radius1`/`radius2` and `radius`/`radii` with one type used everywhere a corner radius is needed, for one corner or for a whole path:

```dart
class CornerRadius {
  const CornerRadius(this.incoming, this.outgoing);
  const CornerRadius.symmetric(double radius) : incoming = radius, outgoing = radius;

  final double incoming;
  final double outgoing;

  double get averaged => (incoming + outgoing) / 2;
}
```

A single corner takes one `CornerRadius`. `roundAllCorners` takes one `CornerRadius` (applied to every corner) or a list of `CornerRadius`, one per junction, in place of today's `radius`/`radii`. Passing `CornerRadius.symmetric(r)` everywhere reproduces today's behavior exactly. Passing a plain `CornerRadius(r1, r2)` at a single junction is new: it lets a caller ask for an asymmetric corner anywhere in a whole-path call, which today only the single-corner functions can do.

The averaging fact moves from being buried in a doc comment to being a named, readable property. A style that only supports one true radius reads `radius.averaged` instead of computing `(radius1 + radius2) / 2` inline, and a caller inspecting a `CornerRadius` value can see the same number the style will actually use.

## Proposed structure

Replace the seven `roundCornerUsing*` functions with one function that delegates to the style itself:

```dart
List<Segment> roundCorner(
  Segment segment1,
  Segment segment2,
  CornerStyle style,
  CornerRadius radius,
) => style.construct(segment1, segment2, radius);
```

`CornerStyle` becomes a sealed class, not an enum. Each style is a `final class` that owns its own construction logic, so the seven implementations stay separate instead of converging on one shared `switch`. Adding an eighth style means adding a class; it never means editing `roundCorner`, `roundAllCorners`, or any of the other seven styles' code:

```dart
sealed class CornerStyle {
  const CornerStyle();

  static const circularArc = CircularArcCorner();
  static const ellipticArc = EllipticArcCorner();
  static const invertedArc = InvertedArcCorner();
  static const chamfer = ChamferCorner();
  static const quadraticBezier = QuadraticBezierCorner();
  static const cubicBezier = CubicBezierCorner();
  static const squircle = CubicBezierCorner();
  static const values = [
    circularArc, ellipticArc, invertedArc,
    chamfer, quadraticBezier, cubicBezier, squircle,
  ];

  bool get honorsAsymmetricRadius;

  List<Segment> construct(Segment segment1, Segment segment2, CornerRadius radius);
}

final class CircularArcCorner extends CornerStyle {
  const CircularArcCorner();

  @override
  bool get honorsAsymmetricRadius => false;

  @override
  List<Segment> construct(Segment segment1, Segment segment2, CornerRadius radius) {
    // circular-arc construction, and only circular-arc construction, lives here
  }
}
```

with one more `final class` per remaining style (`EllipticArcCorner`, `InvertedArcCorner`, `ChamferCorner`, `QuadraticBezierCorner`, `CubicBezierCorner`), each holding only its own construction and its own answer to `honorsAsymmetricRadius`. That getter (the renamed, inverted `averagesRadii`) is still a public part of the contract, so a caller can still ask a style directly whether both sides of a `CornerRadius` will be respected — the difference from the enum version is that each answer lives next to the code that makes it true, rather than in a table of enum constructor arguments read by a switch elsewhere.

The static const fields on `CornerStyle` keep the call-site spelling identical to what an enum would have given: `CornerStyle.circularArc`, `CornerStyle.squircle`, and so on resolve the same way and are still usable as compile-time constants. `CornerStyle.values` is a plain const list standing in for the enumeration an `enum` gives for free.

`squircle` stops being an enum member documented as an alias and becomes an actual one: `static const squircle = CubicBezierCorner();` is the same const-canonicalized instance as `cubicBezier` — `identical(CornerStyle.squircle, CornerStyle.cubicBezier)` is true. What goes away is the second top-level function *and* the second construction; there is exactly one `CubicBezierCorner` class, and `squircle` is another name for its one instance.

Marking the hierarchy `sealed` rather than `abstract` keeps it closed to this library, the same closed-set guarantee an enum gives: no external subclass can appear, and an exhaustive `switch` over `CornerStyle` still compiler-checks every case, anywhere calling code needs to branch on style.

`roundAllCorners` keeps its name and its own concerns (junction walking, cross-corner clamping, traversal), but now takes the same `CornerStyle` and `CornerRadius` types `roundCorner` does, so the two entry points share one vocabulary instead of two.

## Comparison with today

| Today | Proposed |
|---|---|
| `roundCornerUsingCircularArc(a, b, r1, r2)` | `roundCorner(a, b, CornerStyle.circularArc, CornerRadius(r1, r2))` |
| `roundCornerUsingChamfer(a, b, r1, r2)` | `roundCorner(a, b, CornerStyle.chamfer, CornerRadius(r1, r2))` |
| `roundCornerUsingSquircle(a, b, r1, r2)` | `roundCorner(a, b, CornerStyle.squircle, CornerRadius(r1, r2))` |
| `roundAllCorners(path, style, radius: r)` | `roundAllCorners(path, style, radius: CornerRadius.symmetric(r))` |
| `roundAllCorners(path, style, radii: [r0, r1, ...])` | `roundAllCorners(path, style, radii: [CornerRadius.symmetric(r0), ...])` |
| no way to ask asymmetric radii of one corner in a whole-path call | `roundAllCorners(path, style, radii: [..., CornerRadius(3, 8), ...])` |

## Open questions

Naming: `roundCorner` is proposed as the natural single-corner counterpart to `roundAllCorners`, but it isn't the only option. `fillet` reads more geometry-literate but doesn't obviously cover the chamfer and inverted-arc styles, which aren't fillets. Worth deciding before this is built.

`CornerStyle` is a sealed class hierarchy, one `final class` per style, rather than an enum. A single boolean field would have been enough to describe how styles differ, but dispatch was the deciding factor: a `switch` big enough to cover seven styles is a shared piece of code every new style has to pass through, and each style's construction was already sitting in its own top-level function anyway. The class hierarchy keeps that separation instead of erasing it into a `switch` the way collapsing to one function plus an enum would have. Each style class also lives in its own file — `circular_arc_corner.dart`, `elliptic_arc_corner.dart`, and so on — with the shared `sealed class CornerStyle` base in its own file that the style files import and extend. That's a deliberate departure from the one sealed hierarchy already in this codebase, `Angle`/`Radian`/`Degree` in `lib/src/primitive/angle.dart`, which colocates its subclasses with their base in a single file; worth flagging so the difference between the two hierarchies doesn't read as an inconsistency nobody noticed.

This proposal keeps `roundCorner`'s two-segment signature as-is. `roundAllCorners` internally generalizes single segments to chains for the traversal feature, but that machinery is already private, and nothing here proposes exposing it.