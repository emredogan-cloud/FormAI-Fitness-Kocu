import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import 'crunch_analyzer.dart' show CrunchResult, CrunchState;
import 'pose_analyzer.dart';

/// Squats / lunges / Bulgarian split squats / leg press all reduce to a
/// knee-flexion cycle: hip-knee-ankle angle drops as the user descends and
/// extends back up. Counts a rep on UP-from-DOWN (full extension after a
/// full sit). Picks the better-tracked side automatically so we don't fail
/// when one leg is partially occluded.
///
/// Tier-S form check · while the user is at squat-bottom, the analyzer
/// measures torso lean (shoulder-vs-hip horizontal offset normalised by
/// torso length). A ratio above ~0.7 corresponds to >35° lean from
/// vertical — common forward-fold cheat that loads the lower back.
/// One warning per [formWarningCooldown].
class SquatAnalyzer implements PoseAnalyzer {
  SquatAnalyzer({
    this.upThreshold = 165.0,
    this.downThreshold = 100.0,
    this.minRepInterval = const Duration(milliseconds: 1100),
    this.torsoLeanRatio = 0.7,
    this.formWarningCooldown = const Duration(seconds: 12),
  });

  /// Knee angle threshold above which the leg is considered "extended".
  final double upThreshold;

  /// Knee angle threshold below which we count the user as "in the squat".
  final double downThreshold;
  final Duration minRepInterval;

  /// `(|shoulder.x - hip.x|) / (|hip.y - shoulder.y|)` above this value
  /// is "leaning too far forward". 0.7 ≈ tan(35°).
  final double torsoLeanRatio;

  /// Minimum gap between two spoken torso-lean warnings.
  final Duration formWarningCooldown;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;
  DateTime _lastFormWarning =
      DateTime.now().subtract(const Duration(seconds: 30));

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
    _lastFormWarning = DateTime.now().subtract(const Duration(seconds: 30));
  }

  @override
  CrunchResult analyze(Pose pose) {
    final left = _kneeAngle(
      pose,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );
    final right = _kneeAngle(
      pose,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    );
    final knee = left ?? right;
    if (knee == null) {
      return CrunchResult(
        reps: _reps,
        state: _state,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
    }

    final previous = _state;
    var repJustCompleted = false;

    if (knee < downThreshold) {
      _state = CrunchState.down;
    } else if (knee > upThreshold) {
      if (previous == CrunchState.down) {
        final now = DateTime.now();
        final last = _lastRepTime;
        if (last == null || now.difference(last) >= minRepInterval) {
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
        }
      }
      _state = CrunchState.up;
    }

    // Tier-S form check: torso lean while at squat-bottom. Reads the
    // higher-likelihood shoulder + hip on the same side we already
    // trust the knee from. Skipped outside the DOWN state so a user
    // bending to tie a shoe between sets doesn't trip the warning.
    String? formWarning;
    if (_state == CrunchState.down) {
      final shoulder = _pickHigher(pose, PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder);
      final hip = _pickHigher(
          pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      if (shoulder != null && hip != null) {
        final dx = (shoulder.x - hip.x).abs();
        final dy = (hip.y - shoulder.y).abs();
        if (dy > 1 && dx / dy > torsoLeanRatio) {
          final now = DateTime.now();
          if (now.difference(_lastFormWarning) >= formWarningCooldown) {
            formWarning = 'Göğsünü yukarı tut, geriye doğru otur!';
            _lastFormWarning = now;
          }
        }
      }
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: knee,
      neckAngle: null,
      formWarning: formWarning,
      repJustCompleted: repJustCompleted,
    );
  }
}

/// Pull-up / chin-up / lat pulldown / barbell row all hinge on elbow
/// flexion against a load: the shoulder-elbow-wrist angle goes from
/// extended (hanging / arms locked out, > 150°) to flexed (chin over bar,
/// elbow bent, < 80°). Same state machine as [SquatAnalyzer], but the
/// "down" position is the LARGE angle and the "up" is the SMALL one — i.e.
/// we count on the small-angle commit.
class PullUpAnalyzer implements PoseAnalyzer {
  PullUpAnalyzer({
    this.downThreshold = 150.0,
    this.upThreshold = 80.0,
    this.minRepInterval = const Duration(milliseconds: 1200),
  });

  /// Elbow angle threshold above which we consider the arm "hanging".
  final double downThreshold;

  /// Elbow angle threshold below which we consider the arm "pulled in".
  final double upThreshold;
  final Duration minRepInterval;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
  }

  @override
  CrunchResult analyze(Pose pose) {
    final left = _armAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );
    final right = _armAngle(
      pose,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
    );
    final elbow = left ?? right;
    if (elbow == null) {
      return CrunchResult(
        reps: _reps,
        state: _state,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
    }

    final previous = _state;
    var repJustCompleted = false;

    if (elbow > downThreshold) {
      _state = CrunchState.down;
    } else if (elbow < upThreshold) {
      if (previous == CrunchState.down) {
        final now = DateTime.now();
        final last = _lastRepTime;
        if (last == null || now.difference(last) >= minRepInterval) {
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
        }
      }
      _state = CrunchState.up;
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: elbow,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double? _kneeAngle(
  Pose pose,
  PoseLandmarkType hip,
  PoseLandmarkType knee,
  PoseLandmarkType ankle,
) {
  final h = pose.landmarks[hip];
  final k = pose.landmarks[knee];
  final a = pose.landmarks[ankle];
  if (h == null || k == null || a == null) return null;
  if (math.min(h.likelihood, math.min(k.likelihood, a.likelihood)) < 0.4) {
    return null;
  }
  return AngleCalculator.between(h, k, a);
}

double? _armAngle(
  Pose pose,
  PoseLandmarkType shoulder,
  PoseLandmarkType elbow,
  PoseLandmarkType wrist,
) {
  final s = pose.landmarks[shoulder];
  final e = pose.landmarks[elbow];
  final w = pose.landmarks[wrist];
  if (s == null || e == null || w == null) return null;
  if (math.min(s.likelihood, math.min(e.likelihood, w.likelihood)) < 0.4) {
    return null;
  }
  return AngleCalculator.between(s, e, w);
}

/// Returns the higher-likelihood of the two paired landmarks, or null
/// if both are missing. Mirrors the local helper in `core_analyzers`
/// — kept private per file so each analyzer file is self-contained.
PoseLandmark? _pickHigher(
  Pose pose,
  PoseLandmarkType left,
  PoseLandmarkType right,
) {
  final l = pose.landmarks[left];
  final r = pose.landmarks[right];
  if (l == null) return r;
  if (r == null) return l;
  return l.likelihood >= r.likelihood ? l : r;
}
