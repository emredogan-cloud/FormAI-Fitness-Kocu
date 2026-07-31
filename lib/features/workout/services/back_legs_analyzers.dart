import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import 'base_rep_counter_analyzer.dart';
import 'crunch_analyzer.dart' show CrunchResult, CrunchState;
import 'pacing_tracker.dart';
import 'pose_analyzer.dart';
import '../domain/coach_line.dart';

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
class SquatAnalyzer extends BaseRepCounterAnalyzer {
  SquatAnalyzer({
    super.upThreshold = 165.0,
    super.downThreshold = 100.0,
    super.minRepInterval = const Duration(milliseconds: 1100),
    this.torsoLeanRatio = 0.7,
    this.formWarningCooldown = const Duration(seconds: 12),
  }) : super(
          countOnAngleAbove: true,
          pacing: PacingPresets.strength(),
        );

  /// `(|shoulder.x - hip.x|) / (|hip.y - shoulder.y|)` above this value
  /// is "leaning too far forward". 0.7 ≈ tan(35°).
  final double torsoLeanRatio;

  /// Minimum gap between two spoken torso-lean warnings.
  final Duration formWarningCooldown;

  DateTime _lastFormWarning =
      DateTime.now().subtract(const Duration(seconds: 30));

  @override
  void resetForm() {
    _lastFormWarning = DateTime.now().subtract(const Duration(seconds: 30));
  }

  @override
  double? measureAngle(Pose pose) {
    final left = _kneeAngle(pose, PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    final right = _kneeAngle(pose, PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    return left ?? right;
  }

  // Tier-S form check: torso lean while at squat-bottom. Skipped outside the
  // DOWN state so a user bending to tie a shoe between sets doesn't trip it.
  @override
  CoachLine? formWarning(Pose pose, double angle, CrunchState state) {
    if (state != CrunchState.down) return null;
    final shoulder = _pickHigher(
        pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    final hip =
        _pickHigher(pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    if (shoulder == null || hip == null) return null;
    final dx = (shoulder.x - hip.x).abs();
    final dy = (hip.y - shoulder.y).abs();
    if (dy > 1 && dx / dy > torsoLeanRatio) {
      final now = DateTime.now();
      if (now.difference(_lastFormWarning) >= formWarningCooldown) {
        _lastFormWarning = now;
        return CoachLine.squatChestUp;
      }
    }
    return null;
  }
}

/// Hip-hinge family analyzer · Tier B.1.
///
/// Targets:
///   • glute_bridge          (lying, knees bent, hip up/down cycle)
///   • hip_thrust            (shoulders on bench, same cycle but bigger ROM)
///   • single_leg_glute_bridge (one leg in air, same cycle)
///   • frog_pump             (feet butterflied, same cycle)
///   • kettlebell_swing      (standing, hip hinge → drive; bigger ROM)
///   • single_leg_rdl        (standing, single-leg hip hinge)
///
/// All six reduce to a shoulder-hip-knee angle cycle. In the flexed/
/// loaded position the body folds at the hip (angle < [downThreshold]).
/// At the top of the lift the body is roughly straight (angle >
/// [upThreshold]). One UP-from-DOWN crossing = one rep.
///
/// The 130°/165° defaults bracket the full extension/flexion ROM of
/// the lying-down variants (glute bridge, hip thrust, frog pump, single
/// leg glute bridge). Kettlebell swing has a similar ROM at the bottom
/// of the swing and an over-extension closer to 180° at the top — it
/// fits the same gates.
///
/// Picks the better-tracked side so single-leg variants don't fail
/// when one limb is in the air or occluded.
class HipHingeAnalyzer implements PoseAnalyzer {
  HipHingeAnalyzer({
    this.downThreshold = 130.0,
    this.upThreshold = 165.0,
    this.minRepInterval = const Duration(milliseconds: 1000),
    this.formWarningCooldown = const Duration(seconds: 12),
  });

  /// Shoulder-hip-knee angle below this = "hip flexed" (DOWN).
  final double downThreshold;

  /// Shoulder-hip-knee angle above this = "hip extended" (UP).
  /// Counts the rep on UP-from-DOWN.
  final double upThreshold;
  final Duration minRepInterval;

  /// Minimum gap between two spoken partial-rep warnings.
  final Duration formWarningCooldown;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;

  /// Peak shoulder-hip-knee angle observed since the last DOWN commit.
  /// Used to fire a partial-extension warning when the user passes the
  /// upThreshold but never gets near full lockout (≈ 180°).
  double _peakAngle = 0;
  DateTime _lastFormWarning =
      DateTime.now().subtract(const Duration(seconds: 30));
  final PacingTracker _pacing = PacingPresets.strength();

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
    _peakAngle = 0;
    _lastFormWarning = DateTime.now().subtract(const Duration(seconds: 30));
    _pacing.reset();
  }

  @override
  CrunchResult analyze(Pose pose) {
    // Per-side hip angle. Each side computed independently; we trust
    // whichever side returned a non-null value (likelihood >= 0.4 for
    // all three of its landmarks).
    final left = _hipAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
    );
    final right = _hipAngle(
      pose,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
    );
    final angle = left ?? right;
    if (angle == null) {
      return CrunchResult(
        reps: _reps,
        state: _state,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
    }

    if (angle > _peakAngle) _peakAngle = angle;

    final previous = _state;
    var repJustCompleted = false;
    CoachLine? formWarning;
    CoachLine? pacingFeedback;

    if (angle < downThreshold) {
      // Partial-ROM check happens HERE, on the descent that closes the
      // cycle — `_peakAngle` now holds the true maximum of the whole
      // UP phase. The old code evaluated it at the up-crossing commit
      // frame, where the peak had just been reset and equalled the
      // ~165° entry angle by construction: it nagged users who went on
      // to reach a full 180° lockout right after the count (audit P2 —
      // false positive on GOOD reps, the exact anti-trust failure a
      // form coach can't afford).
      if (previous == CrunchState.up) {
        final now = DateTime.now();
        if (_peakAngle < 175.0 &&
            now.difference(_lastFormWarning) >= formWarningCooldown) {
          formWarning = CoachLine.gluteBridgeSqueeze;
          _lastFormWarning = now;
        }
      }
      _state = CrunchState.down;
      _peakAngle = angle;
    } else if (angle > upThreshold) {
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
      torsoAngle: angle,
      neckAngle: null,
      formWarning: formWarning,
      repJustCompleted: repJustCompleted,
      pacingFeedback: pacingFeedback,
    );
  }
}

/// Pull-up / chin-up / lat pulldown / barbell row all hinge on elbow
/// flexion against a load: the shoulder-elbow-wrist angle goes from
/// extended (hanging / arms locked out, > 150°) to flexed (chin over bar,
/// elbow bent, < 80°). Same state machine as [SquatAnalyzer], but the
/// "down" position is the LARGE angle and the "up" is the SMALL one — i.e.
/// we count on the small-angle commit.
class PullUpAnalyzer extends BaseRepCounterAnalyzer {
  // Inverse polarity: DOWN is the large (hanging) angle, UP is the small
  // (chin-over-bar) angle, so the rep commits on flexion.
  PullUpAnalyzer({
    super.downThreshold = 150.0,
    super.upThreshold = 80.0,
    super.minRepInterval = const Duration(milliseconds: 1200),
  }) : super(
          countOnAngleAbove: false,
          pacing: PacingPresets.strength(),
        );

  @override
  double? measureAngle(Pose pose) {
    final left = _armAngle(pose, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final right = _armAngle(pose, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    return left ?? right;
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

/// Per-side shoulder-hip-knee angle for [HipHingeAnalyzer]. Returns
/// null if any of the three landmarks is unreliable.
double? _hipAngle(
  Pose pose,
  PoseLandmarkType shoulder,
  PoseLandmarkType hip,
  PoseLandmarkType knee,
) {
  final s = pose.landmarks[shoulder];
  final h = pose.landmarks[hip];
  final k = pose.landmarks[knee];
  if (s == null || h == null || k == null) return null;
  if (math.min(s.likelihood, math.min(h.likelihood, k.likelihood)) < 0.4) {
    return null;
  }
  return AngleCalculator.between(s, h, k);
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
