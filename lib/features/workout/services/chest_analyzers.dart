import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import 'crunch_analyzer.dart' show CrunchResult, CrunchState;
import 'pose_analyzer.dart';

/// Push-ups (and inclined / declined / dip variants) all reduce to elbow
/// flexion: the shoulder-elbow-wrist angle drops as the user lowers and
/// extends back up. UP-from-DOWN crossings are reps. Same machine as
/// [CrunchAnalyzer], but pivoted around the elbow joint.
class PushUpAnalyzer implements PoseAnalyzer {
  PushUpAnalyzer({
    this.upThreshold = 160.0,
    this.downThreshold = 95.0,
    this.minRepInterval = const Duration(milliseconds: 900),
  });

  /// Elbow angle threshold above which we consider the arm "extended".
  final double upThreshold;

  /// Elbow angle threshold below which we consider the arm "flexed".
  final double downThreshold;
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
    // Pick whichever arm has the cleanest tracking; works for one-handed
    // tripods at awkward angles where one side is occluded.
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
    final elbowAngle = left ?? right;
    if (elbowAngle == null) {
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

    if (elbowAngle < downThreshold) {
      _state = CrunchState.down;
    } else if (elbowAngle > upThreshold) {
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
      torsoAngle: elbowAngle,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
    );
  }
}

/// Bench press shares the elbow-flexion mechanic with push-ups but we
/// expose it as a distinct type so the factory + TTS can speak a
/// bench-specific cue. Tighter UP threshold reflects the shorter ROM
/// users hit with dumbbells under tension.
class BenchPressAnalyzer extends PushUpAnalyzer {
  BenchPressAnalyzer()
      : super(
          upThreshold: 155.0,
          downThreshold: 100.0,
          minRepInterval: const Duration(milliseconds: 1100),
        );
}

/// Chest fly tracks the horizontal distance between the wrists. The arms
/// open wide (large wrist gap) then close above the chest (small gap).
/// One open→close→open cycle is a rep; we count on each close commit.
class ChestFlyAnalyzer implements PoseAnalyzer {
  ChestFlyAnalyzer({
    this.openFraction = 1.4,
    this.closeFraction = 0.5,
    this.minRepInterval = const Duration(milliseconds: 900),
  });

  /// Wrist gap is "open" when it exceeds this fraction of shoulder width.
  final double openFraction;

  /// Wrist gap is "closed" when it drops below this fraction.
  final double closeFraction;
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
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];
    if (ls == null || rs == null || lw == null || rw == null) {
      return _empty();
    }

    final shoulderWidth = _distance(ls, rs);
    if (shoulderWidth < 1) return _empty();
    final wristGap = _distance(lw, rw);
    final ratio = wristGap / shoulderWidth;

    final previous = _state;
    var repJustCompleted = false;

    if (ratio > openFraction) {
      // OPEN ≈ "down" (start of the rep — arms wide).
      _state = CrunchState.down;
    } else if (ratio < closeFraction) {
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
      torsoAngle: ratio,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
    );
  }

  CrunchResult _empty() => CrunchResult(
        reps: _reps,
        state: _state,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
}

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

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

double _distance(PoseLandmark a, PoseLandmark b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
