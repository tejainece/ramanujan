# Offset features

Ramanujan provides the following curve Offset features:

1. **Inset**: Shrinks a closed curve by a specific distance, moving its edges inward to create a smaller shape.
2. **Outset**: Expands a closed curve by a specific distance, moving its edges outward to create a larger shape.
3. **Stroke expand**: Converts a path into a closed, filled shape by outlining it with a specified stroke width (including support for variable width profiles).
4. **ringFromLoop**: Generates a ring-like shape (a `Region` with an even-odd fill rule) representing the area between an inner and outer offset of a closed loop.