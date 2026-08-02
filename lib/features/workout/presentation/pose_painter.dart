import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show mapEquals;
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
    // Phase 2 (P-Risk) F20 · hoist Paint allocations out of the per-frame
    // loops. Previously every bone (×18) and every joint allocated two
    // fresh Paint objects per frame at ~30 fps → heavy GC churn. We now
    // allocate four Paints once per paint() and mutate their per-element
    // properties. Rendering output is byte-for-byte identical.
    //
    // DEFERRED — REQUIRES PHYSICAL VALIDATION: the larger cost flagged by
    // the audit (the MaskFilter.blur glow drawn as a second pass per bone)
    // is a *visual* change; removing it needs on-device frame-time
    // profiling + a visual sign-off, so it is intentionally left intact.
    final boneGlow = Paint()
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final bonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final ringPaint = Paint()..style = PaintingStyle.stroke;

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

      boneGlow.color = _neonCyan.withValues(alpha: 0.35 * boneAlpha);
      bonePaint
        ..color = _neonCyan.withValues(alpha: boneAlpha)
        ..strokeWidth = boneLikelihood < _lowConfidenceThreshold ? 2.5 : 4.0;

      canvas.drawLine(p1, p2, boneGlow);
      canvas.drawLine(p1, p2, bonePaint);
    }

    for (final landmark in pose.landmarks.values) {
      final center = _project(landmark, size);
      final alpha = _alphaFor(landmark.likelihood);

      if (landmark.likelihood < _lowConfidenceThreshold) {
        // Hollow joint — "we see something here but it's uncertain."
        ringPaint
          ..color = _neonGreen.withValues(alpha: alpha)
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, 5, ringPaint);
      } else {
        fillPaint.color = _neonGreen.withValues(alpha: alpha);
        canvas.drawCircle(center, 5, fillPaint);
        ringPaint
          ..color = Colors.white.withValues(alpha: 0.85 * alpha)
          ..strokeWidth = 1.2;
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

  /// Exposed for [TutorialPosePainter], which needs the same projection
  /// so its labels land on the joints the base painter drew.
  @protected
  Offset projectLandmark(PoseLandmark landmark, Size canvasSize) =>
      _project(landmark, canvasSize);

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

/// Roadmap Phase 3 (R1.2) · the practice-rep painter — the skeleton plus
/// a name on every joint the active analyzer is actually reading.
///
/// This is the phase's whole claim made literal. "AI form analysis" is an
/// abstraction until the user watches the app label *their* knee and then
/// count *their* rep off it; after that it is a thing they have seen work.
/// The labels are therefore not decoration — they are the evidence.
///
/// Which is also why the label set is passed in by the caller from the
/// analyzer's own geometry rather than hardcoded here: a painter that
/// claims to watch the knee while the analyzer reads the hip would be
/// a lie rendered at 15 fps, and the least detectable kind.
class TutorialPosePainter extends PosePainter {
  TutorialPosePainter({
    required super.pose,
    required super.imageSize,
    required super.rotation,
    required super.cameraLensDirection,
    required this.trackedJoints,
    required this.textDirection,
  });

  /// Joint → localized label, e.g. `PoseLandmarkType.leftKnee: 'Diz'`.
  final Map<PoseLandmarkType, String> trackedJoints;

  /// Roadmap Phase 8 (C13) · the ambient direction, passed in because a
  /// [CustomPainter] has no `BuildContext` to read it from.
  ///
  /// These labels are ARB copy, not tokens. Laying them out with a
  /// hardcoded `TextDirection.ltr` resolves Arabic and Hebrew bidi
  /// wrongly — and the *projection* above must not move with it, because
  /// that mirror is driven by the camera lens and mirroring a skeleton to
  /// match a reading direction would put the coaching on the wrong limb.
  /// Text direction and landmark direction are different things here.
  final TextDirection textDirection;

  static const Color _labelColor = Color(0xFF39FF14);

  /// Below this likelihood the joint's label is suppressed. Naming a
  /// joint the detector can barely see would attach the app's confidence
  /// to a guess.
  static const double _labelConfidenceFloor = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);

    for (final entry in trackedJoints.entries) {
      final landmark = pose.landmarks[entry.key];
      if (landmark == null) continue;
      if (landmark.likelihood < _labelConfidenceFloor) continue;
      _drawLabel(canvas, size, projectLandmark(landmark, size), entry.value);
    }
  }

  void _drawLabel(Canvas canvas, Size size, Offset at, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _labelColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: textDirection,
    )..layout();

    const gap = 12.0;
    const padH = 7.0;
    const padV = 3.5;
    final chipWidth = painter.width + padH * 2;
    final chipHeight = painter.height + padV * 2;

    // Prefer the right of the joint; flip to the left when that would
    // run off-canvas. A label clipped at the screen edge reads as a
    // rendering bug on exactly the framing this screen is teaching.
    var left = at.dx + gap;
    if (left + chipWidth > size.width - 4) {
      left = at.dx - gap - chipWidth;
    }
    // The canvas can be smaller than the chip — a zero-size box during a
    // layout transition, or a long label on a narrow preview. Clamping
    // against a max below the min throws, so the degenerate case pins to
    // the inset instead. Found by test, and it would have crashed the
    // live camera screen rather than merely misplacing a label.
    left = _pin(left, 4.0, size.width - chipWidth - 4);
    final top = _pin(at.dy - chipHeight / 2, 4.0, size.height - chipHeight - 4);

    final chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, chipWidth, chipHeight),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      chip,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
    canvas.drawRRect(
      chip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _labelColor.withValues(alpha: 0.7),
    );
    painter.paint(canvas, Offset(left + padH, top + padV));
  }

  /// `clamp` with a max that may fall below the min. Returns [min] in
  /// that case rather than throwing.
  static double _pin(double value, double min, double max) =>
      max <= min ? min : value.clamp(min, max);

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    if (oldDelegate is! TutorialPosePainter) return true;
    if (!mapEquals(oldDelegate.trackedJoints, trackedJoints)) return true;
    if (oldDelegate.textDirection != textDirection) return true;
    return super.shouldRepaint(oldDelegate);
  }
}
