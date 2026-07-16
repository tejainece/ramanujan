import 'package:ramanujan/ramanujan.dart';

export 'bifurcator.dart';
export 'cardinal.dart';
export 'catmull_rom.dart';
export 'inset_outset.dart';
export 'notcher.dart';
export 'stroke_expand_with_profile.dart';
export 'stroke_expand.dart';

typedef SegmentMapperWithControls =
    List<Segment> Function(P prev, Segment cur, P next);

typedef SegmentMapper = List<Segment> Function(Segment segment);
