import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import 'base_rep_counter_analyzer.dart';
import 'crunch_analyzer.dart' show CrunchResult, CrunchState;
import 'pacing_tracker.dart';
import 'pose_analyzer.dart';

/// Push-ups (and inclined / declined / dip variants) all reduce to elbow
/// flexion: the shoulder-elbow-wrist angle drops as the user lowers and
/// extends back up. UP-from-DOWN crossings are reps. Same machine as
/// [CrunchAnalyzer], but pivoted around the elbow joint.
///
/// Tier-S form check · the analyzer also evaluates the shoulder-hip-
/// ankle line and warns "Kalçanı yukarı tut, vücudunu düz tut!" when
/// the angle drops below [minBodyLineAngle] — i.e. hips are sagging
/// (the most common push-up form fault). Throttled internally so a
/// fatigued user with chronic sag only hears the cue every
/// [formWarningCooldown].
class PushUpAnalyzer extends BaseRepCounterAnalyzer {
  PushUpAnalyzer({
    super.upThreshold = 160.0,
    super.downThreshold = 95.0,
    super.minRepInterval = const Duration(milliseconds: 900),
    this.minBodyLineAngle = 155.0,
    this.formWarningCooldown = const Duration(seconds: 10),
  }) : super(
          countOnAngleAbove: true,
          pacing: PacingPresets.strength(),
        );

  /// Shoulder-hip-ankle interior angle below this is "hips sagging".
  /// In a clean push-up the spine is nearly straight (≈ 180°); 155°
  /// corresponds to a ~25° break at the hip — visible sag but not
  /// catastrophic, so we warn before the user injures themselves.
  final double minBodyLineAngle;

  /// Minimum gap between two spoken hip-sag warnings.
  final Duration formWarningCooldown;

  DateTime _lastFormWarning =
      DateTime.now().subtract(const Duration(seconds: 30));

  @override
  void resetForm() {
    _lastFormWarning = DateTime.now().subtract(const Duration(seconds: 30));
  }

  @override
  double? measureAngle(Pose pose) {
    // Pick whichever arm has the cleanest tracking; works for one-handed
    // tripods at awkward angles where one side is occluded.
    final left = _armAngle(pose, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final right = _armAngle(pose, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    return left ?? right;
  }

  // Tier-S form check: hip sag detection. Reads the better-tracked
  // shoulder/hip/ankle. A straight body holds ≈180°; sagging hips shrink
  // the interior angle. The 0.35 floor is looser than the 0.4 rep-angle
  // floor because a marginal ankle is still informative for the line check.
  @override
  String? formWarning(Pose pose, double angle, CrunchState state) {
    final shoulder = _pickHigher(
        pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    final hip =
        _pickHigher(pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    final ankle = _pickHigher(
        pose, PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle);
    if (shoulder == null || hip == null || ankle == null) return null;
    final minLikelihood =
        [shoulder.likelihood, hip.likelihood, ankle.likelihood]
            .reduce((a, b) => a < b ? a : b);
    if (minLikelihood < 0.35) return null;
    final lineAngle = AngleCalculator.between(shoulder, hip, ankle);
    if (lineAngle < minBodyLineAngle) {
      final now = DateTime.now();
      if (now.difference(_lastFormWarning) >= formWarningCooldown) {
        _lastFormWarning = now;
        return 'Kalçanı yukarı tut, vücudunu düz tut!';
      }
    }
    return null;
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

/// Chest fly tracks the distance between the wrists. The arms open
/// wide (large wrist gap) then close above the chest (small gap).
/// One open→close→open cycle is a rep; we count on each close commit.
///
/// Coverage-pass closure · the previous implementation used 2D distance
/// only. For a side-camera setup the arms open toward and away from
/// the camera (z axis), so the 2D gap barely changed. Same fix pattern
/// as `RussianTwistAnalyzer` (Tier B.10): compute both the 2D distance
/// AND a z-component, then use whichever is dominant on the current
/// frame. Side-camera flies now count; front-camera flies unchanged.
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
  final PacingTracker _pacing = PacingPresets.strength();

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
    _pacing.reset();
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

    // Front-camera signal: 2D wrist gap.
    final wristGap2D = _distance(lw, rw);

    // Side-camera signal: z-axis spread (|wrist.z - wrist.z|). When
    // arms open toward/away from the camera, x stays similar but z
    // diverges. Same normalisation against shoulder width applies
    // because BlazePose z is on roughly the same scale as x/y.
    final wristGapZ = (lw.z - rw.z).abs();

    // Use the larger of the two — the dominant signal on this frame.
    final wristGap = wristGap2D > wristGapZ ? wristGap2D : wristGapZ;
    final ratio = wristGap / shoulderWidth;

    final previous = _state;
    var repJustCompleted = false;
    String? pacingFeedback;

    if (ratio > openFraction) {
      // OPEN ≈ "down" (start of the rep — arms wide).
      _state = CrunchState.down;
    } else if (ratio < closeFraction) {
      if (previous == CrunchState.down) {
        final now = DateTime.now();
        final last = _lastRepTime;
        if (last == null || now.difference(last) >= minRepInterval) {
          final repDuration = last == null ? null : now.difference(last);
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
          if (repDuration != null) {
            pacingFeedback = _pacing.evaluate(repDuration, now);
          }
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
      pacingFeedback: pacingFeedback,
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

/// Returns the higher-likelihood of the two paired landmarks, or null
/// if both are missing. File-private; mirrors the helper in
/// `back_legs_analyzers.dart` and `core_analyzers.dart`.
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
