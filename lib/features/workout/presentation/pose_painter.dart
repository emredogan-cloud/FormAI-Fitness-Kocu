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

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()
      ..color = _neonGreen
      ..style = PaintingStyle.fill;

    final jointRing = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final bonePaint = Paint()
      ..color = _neonCyan
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final boneGlow = Paint()
      ..color = _neonCyan.withOpacity(0.35)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final connection in _connections) {
      final a = pose.landmarks[connection[0]];
      final b = pose.landmarks[connection[1]];
      if (a == null || b == null) continue;
      final p1 = _project(a, size);
      final p2 = _project(b, size);
      canvas.drawLine(p1, p2, boneGlow);
      canvas.drawLine(p1, p2, bonePaint);
    }

    for (final landmark in pose.landmarks.values) {
      final center = _project(landmark, size);
      canvas.drawCircle(center, 5, jointPaint);
      canvas.drawCircle(center, 5, jointRing);
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
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.cameraLensDirection != cameraLensDirection;
  }
}
