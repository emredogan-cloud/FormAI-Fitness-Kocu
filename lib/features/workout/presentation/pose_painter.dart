import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  static const Color _neonCyan = Color(0xFF00F0FF);
  static const Color _neonGreen = Color(0xFF39FF14);

  static const List<List<PoseLandmarkType>> _connections = [
    // Arms
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    // Shoulders & torso
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    // Legs
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    // Feet
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
    [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
  ];

  // Tier-S audit fix · confidence-aware rendering. The previous painter
  // drew every joint + bone at full opacity regardless of likelihood,
  // so a 0.05-confidence skeleton looked as solid as a 0.95-confidence
  // one — the visual root of the "tracks but doesn't analyse"
  // perception (see WORKOUT_INTELLIGENCE_AUDIT.md §1, §5 U1). Joints
  // and bones now fade with confidence; below [_lowConfidenceThreshold]
  // we render a hollow joint and a desaturated bone so the user can
  // see that landmark is uncertain.
  static const double _lowConfidenceThreshold = 0.3;
  static const double _mediumConfidenceThreshold = 0.6;

  /// Maps a likelihood in [0, 1] to an alpha in [0.15, 1.0]. Floors at
  /// 0.15 so a single low-confidence joint doesn't disappear entirely
  /// — the user still sees "something is there but uncertain."
  double _alphaFor(double likelihood) {
    if (likelihood >= _mediumConfidenceThreshold) return 1.0;
    if (likelihood <= 0.0) return 0.15;
    // Linear ramp from 0 → 0.6 likelihood mapped to 0.15 → 1.0 alpha.
    final t = (likelihood / _mediumConfidenceThreshold).clamp(0.0, 1.0);
    return 0.15 + t * 0.85;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in _connections) {
      final a = pose.landmarks[connection[0]];
      final b = pose.landmarks[connection[1]];
      if (a == null || b == null) continue;
      // Bone confidence is gated by the weaker of its two joints — a
      // bone is no more trustworthy than its less-certain endpoint.
      final boneLikelihood =
          a.likelihood < b.likelihood ? a.likelihood : b.likelihood;
      final boneAlpha = _alphaFor(boneLikelihood);
      final p1 = _project(a, size);
      final p2 = _project(b, size);

      final boneGlow = Paint()
        ..color = _neonCyan.withValues(alpha: 0.35 * boneAlpha)
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final bonePaint = Paint()
        ..color = _neonCyan.withValues(alpha: boneAlpha)
        ..strokeWidth = boneLikelihood < _lowConfidenceThreshold ? 2.5 : 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, boneGlow);
      canvas.drawLine(p1, p2, bonePaint);
    }

    for (final landmark in pose.landmarks.values) {
      final center = _project(landmark, size);
      final alpha = _alphaFor(landmark.likelihood);
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      if (landmark.likelihood < _lowConfidenceThreshold) {
        // Hollow joint — visually communicates "we see something here
        // but it's uncertain." No fill, narrower ring.
        final hollowRing = Paint()
          ..color = _neonGreen.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, 5, hollowRing);
      } else {
        final fillPaint = Paint()
          ..color = _neonGreen.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 5, fillPaint);
        canvas.drawCircle(center, 5, ringPaint);
      }
    }
  }

  Offset _project(PoseLandmark landmark, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    var x = landmark.x * scaleX;
    final y = landmark.y * scaleY;
    if (cameraLensDirection == CameraLensDirection.front) {
      x = canvasSize.width - x;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    // Fast paths first: image + camera config changes always need a repaint.
    if (oldDelegate.imageSize != imageSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.cameraLensDirection != cameraLensDirection) {
      return true;
    }
    // ML Kit normally returns a fresh Pose instance per detection, so
    // reference inequality is the cheapest correct signal.
    if (!identical(oldDelegate.pose, pose)) return true;
    // Defensive belt-and-suspenders: if ML Kit ever reuses the same Pose
    // object and mutates landmarks in place (it doesn't today, but it's a
    // free guard), fall back to sampling two critical landmark coordinates.
    // Cheap enough to run on every shouldRepaint call.
    const sampled = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
    ];
    for (final type in sampled) {
      final a = oldDelegate.pose.landmarks[type];
      final b = pose.landmarks[type];
      if (a?.x != b?.x || a?.y != b?.y) return true;
    }
    return false;
  }
}
