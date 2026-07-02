import 'package:ramanujan/ramanujan.dart';

/// Full boolean operation pipeline (steps 1–4) for two sets of closed paths.
///
/// Subclasses declare [filter]; [compute] runs the full pipeline.
abstract class PathBoolean {
  const PathBoolean();

  BooleanOpFilter get filter;

  /// Runs all four pipeline steps and returns the result as a [Region].
  ///
  /// Steps: simplify → split & classify → [filter] → merge.
  /// The output region always uses [FillRule.evenOdd]: the pipeline normalises
  /// winding so outer loops are CCW and holes are CW, making both fill rules
  /// produce identical results on the output.
  Region compute(Region a, Region b) {
    final aSimple = a.loops.expand(simplifyClosedPath).toList();
    final bSimple = b.loops.expand(simplifyClosedPath).toList();
    final classified = splitAndClassify(aSimple, bSimple, a, b);
    final filtered = filter.filter(classified);
    return Region(mergeFaces(filtered), fillRule: FillRule.evenOdd);
  }
}

final class PathUnion extends PathBoolean {
  const PathUnion();
  @override
  BooleanOpFilter get filter => const Union();
}

final class PathIntersection extends PathBoolean {
  const PathIntersection();
  @override
  BooleanOpFilter get filter => const Intersection();
}

final class PathDifference extends PathBoolean {
  const PathDifference();
  @override
  BooleanOpFilter get filter => const Difference();
}

final class PathXor extends PathBoolean {
  const PathXor();
  @override
  BooleanOpFilter get filter => const Xor();
}

final class PathDivision extends PathBoolean {
  const PathDivision();

  @override
  BooleanOpFilter get filter => throw UnsupportedError(
        'PathDivision does not use a single filter. Use compute instead.',
      );

  @override
  Region compute(Region a, Region b) {
    final aSimple = a.loops.expand(simplifyClosedPath).toList();
    final bSimple = b.loops.expand(simplifyClosedPath).toList();
    final classified = splitAndClassify(aSimple, bSimple, a, b);

    final intersectionFaces =
        classified.where((f) => f.insideA && f.insideB).toList();
    final differenceFaces =
        classified.where((f) => f.insideA && !f.insideB).toList();

    return Region(
      [...mergeFaces(intersectionFaces), ...mergeFaces(differenceFaces)],
      fillRule: FillRule.evenOdd,
    );
  }
}

final class PathFracture extends PathBoolean {
  const PathFracture();

  @override
  BooleanOpFilter get filter => throw UnsupportedError(
        'PathFracture does not use a single filter. Use compute instead.',
      );

  @override
  Region compute(Region a, Region b) {
    final aSimple = a.loops.expand(simplifyClosedPath).toList();
    final bSimple = b.loops.expand(simplifyClosedPath).toList();
    final classified = splitAndClassify(aSimple, bSimple, a, b);

    final aMinusBFaces =
        classified.where((f) => f.insideA && !f.insideB).toList();
    final bMinusAFaces =
        classified.where((f) => !f.insideA && f.insideB).toList();
    final intersectionFaces =
        classified.where((f) => f.insideA && f.insideB).toList();

    return Region(
      [
        ...mergeFaces(aMinusBFaces),
        ...mergeFaces(bMinusAFaces),
        ...mergeFaces(intersectionFaces),
      ],
      fillRule: FillRule.evenOdd,
    );
  }
}

final class PathFlatten extends PathBoolean {
  const PathFlatten();

  @override
  BooleanOpFilter get filter => throw UnsupportedError(
        'PathFlatten does not use a single filter. Use compute instead.',
      );

  @override
  Region compute(Region a, Region b) {
    final aSimple = a.loops.expand(simplifyClosedPath).toList();
    final bSimple = b.loops.expand(simplifyClosedPath).toList();
    final classified = splitAndClassify(aSimple, bSimple, a, b);

    final bFaces = classified.where((f) => f.insideB).toList();
    final aMinusBFaces =
        classified.where((f) => f.insideA && !f.insideB).toList();

    return Region(
      [...mergeFaces(bFaces), ...mergeFaces(aMinusBFaces)],
      fillRule: FillRule.evenOdd,
    );
  }
}

