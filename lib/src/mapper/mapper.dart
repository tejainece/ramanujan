import 'package:ramanujan/ramanujan.dart';

export 'bifurcator.dart';
export 'cardinal.dart';
export 'catmull_rom.dart';
export 'notcher.dart';

typedef SegmentMapperWithControls = List<Segment> Function(
    P prev, Segment cur, P next);

typedef SegmentMapper = List<Segment> Function(Segment segment);
