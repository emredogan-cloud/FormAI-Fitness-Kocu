import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'crunch_analyzer.dart' show CrunchResult;

/// Common contract every per-exercise rep counter implements. The concrete
/// analyzer is chosen at runtime by `analyzerFor(exercise)` based on the
/// active `Exercise.id`. All analyzers emit a [CrunchResult] (the original
/// crunch-specific class kept for back-compat — its `torsoAngle` /
/// `neckAngle` fields are debug-only and may be null for non-crunch flows).
abstract class PoseAnalyzer {
  CrunchResult analyze(Pose pose);
  void reset();
}
