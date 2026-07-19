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

Replace the seven `roundCornerUsing*` functions with one function, parameterized by style:

```dart
List<Segment> roundCorner(
  Segment segment1,
  Segment segment2,
  CornerStyle style,
  CornerRadius radius,
);
```

`CornerStyle` becomes the one vocabulary for style, used by both `roundCorner` and `roundAllCorners`, instead of a name existing only on the whole-path side. Its `honorsAsymmetricRadius` field (the renamed, inverted `averagesRadii`) is now part of the public contract, not an internal budgeting detail, so a caller can ask a style directly whether both sides of a `CornerRadius` will be respected:

```dart
enum CornerStyle {
  circularArc(honorsAsymmetricRadius: false),
  ellipticArc(honorsAsymmetricRadius: true),
  invertedArc(honorsAsymmetricRadius: false),
  chamfer(honorsAsymmetricRadius: true),
  quadraticBezier(honorsAsymmetricRadius: true),
  cubicBezier(honorsAsymmetricRadius: true),
  squircle(honorsAsymmetricRadius: true);

  const CornerStyle({required this.honorsAsymmetricRadius});
  final bool honorsAsymmetricRadius;
}
```

`squircle` stays in the enum as a documented alias of `cubicBezier` rather than disappearing. Callers reach for "squircle" by that name because that's the term design tools use for this look, and removing the name would just make them go find `cubicBezier` some other way. What goes away is the second top-level function. `roundCorner(a, b, CornerStyle.squircle, radius)` and `roundCorner(a, b, CornerStyle.cubicBezier, radius)` call the same construction, and the alias relationship is stated once, on the enum, instead of duplicated as a whole separate function whose entire body is a call-through.

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

`CornerStyle` as an enum with two data fields is proposed rather than a class hierarchy, since a style's entire externally-relevant behavior so far is one boolean, `honorsAsymmetricRadius`. If a future style needs more than a flag's worth of distinct behavior, this may need revisiting, but nothing in today's seven styles asks for that.

This proposal keeps `roundCorner`'s two-segment signature as-is. `roundAllCorners` internally generalizes single segments to chains for the traversal feature, but that machinery is already private, and nothing here proposes exposing it.