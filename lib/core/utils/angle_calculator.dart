import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class AngleCalculator {
  const AngleCalculator._();

  /// Interior angle at vertex [b] formed by the rays b→a and b→c, in degrees.
  /// Uses atan2 so the result is always a non-reflex angle in [0, 180].
  static double between(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians =
        math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    var degrees = radians * 180.0 / math.pi;
    degrees = degrees.abs();
    if (degrees > 180.0) degrees = 360.0 - degrees;
    return degrees;
  }
}
