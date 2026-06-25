import 'cross_split.dart';

abstract interface class BooleanOpFilter {
  static List<ClassifiedFace> apply(
    List<ClassifiedFace> faces,
    BooleanOpFilter op,
  ) =>
      op.filter(faces);

  List<ClassifiedFace> filter(List<ClassifiedFace> faces);
}

final class Union implements BooleanOpFilter {
  const Union();
  @override
  List<ClassifiedFace> filter(List<ClassifiedFace> faces) =>
      faces.where((f) => f.insideA || f.insideB).toList();
}

final class Intersection implements BooleanOpFilter {
  const Intersection();
  @override
  List<ClassifiedFace> filter(List<ClassifiedFace> faces) =>
      faces.where((f) => f.insideA && f.insideB).toList();
}

final class Difference implements BooleanOpFilter {
  const Difference();
  @override
  List<ClassifiedFace> filter(List<ClassifiedFace> faces) =>
      faces.where((f) => f.insideA && !f.insideB).toList();
}

final class Xor implements BooleanOpFilter {
  const Xor();
  @override
  List<ClassifiedFace> filter(List<ClassifiedFace> faces) =>
      faces.where((f) => f.insideA != f.insideB).toList();
}
