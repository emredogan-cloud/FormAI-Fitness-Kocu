import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import 'base_rep_counter_analyzer.dart';
import 'crunch_analyzer.dart' show CrunchResult, CrunchState;
import 'pacing_tracker.dart';
import 'pose_analyzer.dart';

// ============================================================================
// Arms — biceps / hammer curl / triceps pushdown
// ============================================================================

/// Bicep & hammer curls (and triceps pushdown's elbow-extension cycle)
/// reduce to elbow flexion — same maths as a pull-up, but tuned tighter
/// so quick partial-range curls don't squeak through. UP < 50°, DOWN >
/// 150°; a rep is the small-angle commit after a large-angle commit.
///
/// Tier-S form check · the analyzer also tracks whether the elbow drifts
/// away from the rib cage — the most common biceps-curl cheat
/// ("swinging"). If `|elbow.x - hip.x|` exceeds [maxElbowDriftRatio] of
/// shoulder width while the arm is in the UP commit, warn
/// "Dirseğini gövdene yapışık tut!".
class BicepsCurlAnalyzer extends BaseRepCounterAnalyzer {
  BicepsCurlAnalyzer({
    super.downThreshold = 150.0,
    super.upThreshold = 50.0,
    super.minRepInterval = const Duration(milliseconds: 900),
    this.maxElbowDriftRatio = 0.85,
    this.formWarningCooldown = const Duration(seconds: 12),
  }) : super(
          // Rep commits on the small-angle (flexion) crossing.
          countOnAngleAbove: false,
          pacing: PacingPresets.strength(),
        );

  /// Elbow drift `(|elbow.x - hip.x|) / shoulderWidth` above this is
  /// "elbow leaving the rib cage". 0.85 leaves enough headroom for
  /// users with naturally wider stances; tighter values produce false
  /// warnings on hammer curls performed off the hip.
  final double maxElbowDriftRatio;

  /// Minimum gap between two spoken elbow-drift warnings.
  final Duration formWarningCooldown;

  DateTime _lastFormWarning =
      DateTime.now().subtract(const Duration(seconds: 30));

  @override
  void resetForm() {
    _lastFormWarning = DateTime.now().subtract(const Duration(seconds: 30));
  }

  @override
  double? measureAngle(Pose pose) {
    final left = _armAngle(pose, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final right = _armAngle(pose, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    return left ?? right;
  }

  // Tier-S form check: elbow drift away from the torso during the UP phase.
  // Dominant side = the side the rep angle came from (recomputed here).
  @override
  String? formWarning(Pose pose, double angle, CrunchState state) {
    if (state != CrunchState.up) return null;
    final dominantIsLeft = _armAngle(pose, PoseLandmarkType.leftShoulder,
            PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist) !=
        null;
    final elbowLm = pose.landmarks[dominantIsLeft
        ? PoseLandmarkType.leftElbow
        : PoseLandmarkType.rightElbow];
    final hipLm = pose.landmarks[
        dominantIsLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip];
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (elbowLm == null || hipLm == null || ls == null || rs == null) {
      return null;
    }
    final shoulderWidth = (ls.x - rs.x).abs();
    if (shoulderWidth <= 1) return null;
    final drift = (elbowLm.x - hipLm.x).abs() / shoulderWidth;
    if (drift > maxElbowDriftRatio) {
      final now = DateTime.now();
      if (now.difference(_lastFormWarning) >= formWarningCooldown) {
        _lastFormWarning = now;
        return 'Dirseğini gövdene yapışık tut!';
      }
    }
    return null;
  }
}

// ============================================================================
// Shoulders — overhead press
// ============================================================================

/// Vertical wrist-vs-shoulder tracking. UP = wrists pushed clearly above
/// the shoulder line (delta > 0.7 × shoulderWidth). DOWN = wrists back
/// near shoulder height. Surfaces a "Kolları tam yukarı uzat!" warning
/// when a rep completes without ever achieving full extension.
class ShoulderPressAnalyzer implements PoseAnalyzer {
  ShoulderPressAnalyzer({
    this.upRatio = 0.7,
    this.downRatio = 0.1,
    this.partialRatio = 1.3,
    this.minRepInterval = const Duration(milliseconds: 900),
  });

  /// Wrist must rise above shoulderY by at least `upRatio × shoulderWidth`
  /// for a clean UP.
  final double upRatio;

  /// Wrist back to within `downRatio × shoulderWidth` of shoulderY = DOWN.
  final double downRatio;

  /// Full-lockout bar for the partial-rep cue, as a multiple of
  /// `upThreshold`: a counted rep whose peak delta stayed below
  /// `upThreshold × partialRatio` (default ≈ 0.91 × shoulderWidth)
  /// earns a "go all the way up" whisper. MUST be > 1.0 — entering the
  /// UP state already guarantees the peak exceeded `upThreshold × 1.0`,
  /// so the old 0.55 value made the warning mathematically unreachable
  /// (dead code, audit P2). Full overhead extension puts the wrists
  /// well past ~0.9 × shoulderWidth above the shoulder line; a press
  /// that barely clears the 0.7 entry gate is the partial we coach.
  final double partialRatio;
  final Duration minRepInterval;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;
  double _maxDelta = 0; // largest wrist-above-shoulder delta this rep
  final PacingTracker _pacing = PacingPresets.strength();

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
    _maxDelta = 0;
    _pacing.reset();
  }

  @override
  CrunchResult analyze(Pose pose) {
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (lw == null || rw == null || ls == null || rs == null) {
      return _empty();
    }

    final wristY = (lw.y + rw.y) / 2;
    final shoulderY = (ls.y + rs.y) / 2;
    final shoulderWidth = (ls.x - rs.x).abs();
    if (shoulderWidth < 1) return _empty();

    final delta = shoulderY - wristY; // positive when wrists above shoulders
    if (delta > _maxDelta) _maxDelta = delta;

    final upThreshold = shoulderWidth * upRatio;
    final downThreshold = shoulderWidth * downRatio;

    final previous = _state;
    var repJustCompleted = false;
    String? formWarning;
    String? pacingFeedback;

    if (delta > upThreshold) {
      _state = CrunchState.up;
    } else if (delta < downThreshold) {
      if (previous == CrunchState.up) {
        final now = DateTime.now();
        final last = _lastRepTime;
        if (last == null || now.difference(last) >= minRepInterval) {
          final repDuration = last == null ? null : now.difference(last);
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
          // Partial-rep nudge: rep counted but never reached full lockout.
          if (_maxDelta < upThreshold * partialRatio) {
            formWarning = 'Kolları tam yukarı uzat!';
          }
          // Pacing only emitted when no form warning to avoid same-frame
          // queue contention. Form warning is the higher-value signal.
          if (formWarning == null && repDuration != null) {
            pacingFeedback = _pacing.evaluate(repDuration, now);
          }
          _maxDelta = 0;
        }
      }
      _state = CrunchState.down;
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: delta,
      neckAngle: null,
      formWarning: formWarning,
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

// ============================================================================
// Shoulders — lateral / front raise
// ============================================================================

/// Counts a rep when the arm reaches roughly horizontal (≥ 75°) measured
/// at the shoulder vertex, then returns to the side (< 25°). Works for
/// both lateral raises (arms out to the side) and front raises (arms
/// forward) because the angle math at the shoulder vertex is identical.
///
/// Tier-S form check · the analyzer also catches the over-extension
/// fault — pulling the wrist visibly above the shoulder line shifts
/// load from the deltoids onto the upper trapezius. If the wrist rises
/// above the shoulder by more than [maxArmAboveShoulderRatio] of
/// shoulder width while the arm is in the UP commit, warn
/// "Kolları omuz hizasına kadar kaldır."
class LateralRaiseAnalyzer extends BaseRepCounterAnalyzer {
  LateralRaiseAnalyzer({
    super.upThreshold = 75.0,
    super.downThreshold = 25.0,
    super.minRepInterval = const Duration(milliseconds: 900),
    this.maxArmAboveShoulderRatio = 0.35,
    this.formWarningCooldown = const Duration(seconds: 12),
  }) : super(
          countOnAngleAbove: true,
          pacing: PacingPresets.strength(),
        );

  /// `(shoulder.y - wrist.y) / shoulderWidth` above this means the
  /// wrist is sitting clearly above the shoulder line — over-extension.
  final double maxArmAboveShoulderRatio;

  /// Minimum gap between two spoken arm-too-high warnings.
  final Duration formWarningCooldown;

  DateTime _lastFormWarning =
      DateTime.now().subtract(const Duration(seconds: 30));

  @override
  void resetForm() {
    _lastFormWarning = DateTime.now().subtract(const Duration(seconds: 30));
  }

  @override
  double? measureAngle(Pose pose) {
    final left = _shoulderArmAngle(pose, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow, PoseLandmarkType.leftHip);
    final right = _shoulderArmAngle(pose, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow, PoseLandmarkType.rightHip);
    return left ?? right;
  }

  // Tier-S form check: wrist-above-shoulder during the UP phase.
  @override
  String? formWarning(Pose pose, double angle, CrunchState state) {
    if (state != CrunchState.up) return null;
    final dominantIsLeft = _shoulderArmAngle(
            pose,
            PoseLandmarkType.leftShoulder,
            PoseLandmarkType.leftElbow,
            PoseLandmarkType.leftHip) !=
        null;
    final wrist = pose.landmarks[dominantIsLeft
        ? PoseLandmarkType.leftWrist
        : PoseLandmarkType.rightWrist];
    final shoulder = pose.landmarks[dominantIsLeft
        ? PoseLandmarkType.leftShoulder
        : PoseLandmarkType.rightShoulder];
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (wrist == null || shoulder == null || ls == null || rs == null) {
      return null;
    }
    final shoulderWidth = (ls.x - rs.x).abs();
    if (shoulderWidth <= 1) return null;
    final aboveBy = shoulder.y - wrist.y; // positive when wrist is higher
    if (aboveBy / shoulderWidth > maxArmAboveShoulderRatio) {
      final now = DateTime.now();
      if (now.difference(_lastFormWarning) >= formWarningCooldown) {
        _lastFormWarning = now;
        return 'Kolları omuz hizasında tut, daha yukarı kaldırma.';
      }
    }
    return null;
  }
}

// ============================================================================
// Scapular / postural family — Tier B.2
// ============================================================================

/// Targets: `prone_y_raise`, `prone_t_raise`, `scapular_wall_slide`.
///
/// All three are small-ROM arm-raise patterns:
///   • prone Y raise — lying face-down, arms overhead in Y shape; lift
///     wrists off the floor.
///   • prone T raise — lying face-down, arms out to sides; lift wrists
///     off the floor.
///   • scapular wall slide — standing against a wall, arms in W or Y;
///     slide them up the wall and back down.
///
/// The common signal is the **wrist position relative to the shoulder
/// line**, normalised by shoulder width so the analyzer self-calibrates
/// to camera distance. We average the two wrists and the two shoulders
/// to be tolerant of one-side occlusion; the ratio is then:
///
///   ratio = (shoulderMidY - wristMidY) / shoulderWidth
///
/// Positive ratio = wrists above shoulder line (lifted / slid up).
/// Negative or near-zero ratio = arms resting / at sides.
///
/// State machine:
///   • ratio > upRatio (default 0.45)   → UP, count a rep on UP-from-DOWN
///   • ratio < downRatio (default 0.05) → DOWN
///
/// Both thresholds are intentionally loose because these are small-ROM
/// movements with noisy wrist landmarks; a tight gate would miss most
/// reps. Form warning is deliberately omitted — scapular reps are too
/// subtle for any geometric form check that wouldn't false-positive.
class ScapularAnalyzer extends BaseRepCounterAnalyzer {
  ScapularAnalyzer({
    double upRatio = 0.45,
    double downRatio = 0.05,
    super.minRepInterval = const Duration(milliseconds: 900),
  }) : super(
          // The "angle" here is the wrist-vs-shoulder height ratio; up/down
          // thresholds map directly. Rep commits on the high-ratio crossing.
          downThreshold: downRatio,
          upThreshold: upRatio,
          countOnAngleAbove: true,
          pacing: PacingPresets.strength(),
        );

  @override
  double? measureAngle(Pose pose) {
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];
    if (ls == null || rs == null || lw == null || rw == null) return null;
    // Skip the frame if either shoulder is unreliable — without a baseline
    // shoulder line the ratio is meaningless. We tolerate one weak wrist
    // (it gets averaged into the mid-point with the other).
    final minShoulder =
        ls.likelihood < rs.likelihood ? ls.likelihood : rs.likelihood;
    if (minShoulder < 0.4) return null;
    final shoulderWidth = (ls.x - rs.x).abs();
    if (shoulderWidth < 1) return null;
    final shoulderMidY = (ls.y + rs.y) / 2;
    final wristMidY = (lw.y + rw.y) / 2;
    return (shoulderMidY - wristMidY) / shoulderWidth;
  }
}

// ============================================================================
// Cardio — jumping jack
// ============================================================================

/// Jumping jacks: legs spread + wrists overhead = OPEN. Legs together +
/// wrists at sides = CLOSED. One OPEN→CLOSED→OPEN cycle is a rep.
/// Uses shoulder width as the unit so it self-calibrates to camera
/// distance.
///
/// Tier-B.9 · the previous thresholds were a single open/close
/// boundary (`spreadRatio = 1.4`, `armRatio = 0.6`). A fatigued user
/// who barely cleared 1.39× shoulder-width spread + 0.59× arm rise
/// would oscillate between OPEN and CLOSED on every frame, double-
/// counting or missing reps depending on which side of the threshold
/// the noise landed.
///
/// Replaced with proper hysteresis — separate `open*Ratio` (to commit
/// to OPEN) and `close*Ratio` (to commit to CLOSED) thresholds, with
/// a gap that absorbs frame-to-frame jitter. Both gates also loosen
/// the requirements (open at 1.25×, arms at 0.5×) so a lazy/fatigued
/// jumping jack still counts.
class JumpingJackAnalyzer implements PoseAnalyzer {
  JumpingJackAnalyzer({
    this.spreadOpenRatio = 1.25,
    this.spreadCloseRatio = 0.95,
    this.armOpenRatio = 0.50,
    this.armCloseRatio = 0.20,
    this.minRepInterval = const Duration(milliseconds: 500),
  });

  /// Ankle distance must exceed `spreadOpenRatio × shoulderWidth`
  /// (and arms must be above by `armOpenRatio`) to commit to OPEN.
  final double spreadOpenRatio;

  /// Ankle distance must fall below `spreadCloseRatio × shoulderWidth`
  /// (and arms must drop below `armCloseRatio`) to commit to CLOSED.
  /// Between the two thresholds the state holds — that's the hysteresis.
  final double spreadCloseRatio;

  /// Wrist must rise above the shoulder line by `armOpenRatio ×
  /// shoulderWidth` to satisfy the OPEN gate.
  final double armOpenRatio;

  /// Wrist must drop below `armCloseRatio × shoulderWidth` to satisfy
  /// the CLOSED gate.
  final double armCloseRatio;

  final Duration minRepInterval;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;
  final PacingTracker _pacing = PacingPresets.cardio();

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
    final la = pose.landmarks[PoseLandmarkType.leftAnkle];
    final ra = pose.landmarks[PoseLandmarkType.rightAnkle];
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];
    if (ls == null ||
        rs == null ||
        la == null ||
        ra == null ||
        lw == null ||
        rw == null) {
      return _empty();
    }

    // Tier-B.9 also adds a minimum landmark-likelihood gate. Without
    // it, a low-confidence frame from a shaky camera could trip the
    // hysteresis thresholds purely from noise. 0.4 mirrors the gate
    // used by other analyzers.
    final minLikelihood = [
      ls.likelihood,
      rs.likelihood,
      la.likelihood,
      ra.likelihood,
      lw.likelihood,
      rw.likelihood,
    ].reduce((a, b) => a < b ? a : b);
    if (minLikelihood < 0.4) return _empty();

    final shoulderWidth = (ls.x - rs.x).abs();
    if (shoulderWidth < 1) return _empty();

    final ankleSpread = (la.x - ra.x).abs();
    final shoulderY = (ls.y + rs.y) / 2;
    final wristY = (lw.y + rw.y) / 2;
    final wristAbove = shoulderY - wristY;

    // Independent open / close checks for each pair (legs, arms).
    final spreadOpen = ankleSpread > shoulderWidth * spreadOpenRatio;
    final spreadClose = ankleSpread < shoulderWidth * spreadCloseRatio;
    final armOpen = wristAbove > shoulderWidth * armOpenRatio;
    final armClose = wristAbove < shoulderWidth * armCloseRatio;

    // Commit to OPEN only when BOTH pairs cleared their open gates.
    // Commit to CLOSED only when BOTH pairs cleared their close gates.
    // Neither condition true → hold previous state (hysteresis).
    final commitOpen = spreadOpen && armOpen;
    final commitClose = spreadClose && armClose;

    final previous = _state;
    var repJustCompleted = false;
    String? pacingFeedback;

    if (commitOpen) {
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
    } else if (commitClose) {
      _state = CrunchState.down;
    }
    // Else: keep previous state — neither hysteresis gate cleared.

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: ankleSpread / shoulderWidth,
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

// ============================================================================
// Cardio — burpee (state machine)
// ============================================================================

/// Three-state cycle: STANDING → DOWN (squat/plank) → STANDING. Counts
/// the rep on the closing STANDING transition. The intermediate
/// STANDING→DOWN edge fires a throttled `contextualCue` so the voice
/// coach can guide the user as they drop.
///
/// Uses the shoulder Y coordinate self-calibrated against the recent
/// min/max so the analyzer adapts to whatever camera distance the user
/// happens to set up. We need ≥ 60 px of vertical movement before any
/// state commits — keeps a stationary frame from triggering false reps.
///
/// Tier-B.7 · the previous implementation kept a monotonic running
/// min/max over the entire set. Late in a long burpee set, a single
/// outlier yMin from a stretch-out frame would pollute the thresholds
/// indefinitely, causing false reps to register from breathing or
/// subtle weight-shifts. Switched to a sliding-window sample list
/// pruned at [_decayWindow] — only the last 8 s of shoulder-Y data
/// influences the thresholds, so old extrema fade out cleanly.
class BurpeeAnalyzer implements PoseAnalyzer {
  BurpeeAnalyzer({
    this.minRange = 60.0,
    this.minRepInterval = const Duration(milliseconds: 1500),
    this.cueCooldown = const Duration(seconds: 8),
  });

  final double minRange;
  final Duration minRepInterval;
  final Duration cueCooldown;

  /// Sliding-window length for the shoulder-Y samples that drive the
  /// running min/max thresholds. 8 s is long enough to span a slow
  /// burpee (~5 s/rep) and short enough that stale extrema from
  /// outlier frames decay out before they break a subsequent rep.
  static const Duration _decayWindow = Duration(seconds: 8);

  /// Hard upper bound on the sample list size so a degenerate slow-fps
  /// device doesn't grow it unbounded. 256 entries ≈ 17 s of frames at
  /// the effective 15 FPS rate — far above _decayWindow, so this never
  /// triggers in normal operation; it's purely a safety cap.
  static const int _maxSamples = 256;

  int _reps = 0;
  _BurpeePhase _phase = _BurpeePhase.unknown;
  DateTime? _lastRepTime;
  DateTime? _lastCueTime;

  /// Sliding window of (timestamp, shoulderY) samples. New samples
  /// append to the tail on every frame; old samples are pruned from
  /// the head when they age past [_decayWindow]. yMin/yMax derived
  /// per-frame are pure functions of this list.
  final List<_YSample> _ySamples = <_YSample>[];

  final PacingTracker _pacing = PacingPresets.compound();

  @override
  void reset() {
    _reps = 0;
    _phase = _BurpeePhase.unknown;
    _lastRepTime = null;
    _lastCueTime = null;
    _ySamples.clear();
    _pacing.reset();
  }

  @override
  CrunchResult analyze(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder] ??
        pose.landmarks[PoseLandmarkType.rightShoulder];
    if (shoulder == null) return _empty();

    final now = DateTime.now();
    final y = shoulder.y;
    _ySamples.add(_YSample(now, y));

    // Prune the head of the window. The list is timestamp-ascending
    // (we always append), so the head is the oldest sample.
    while (_ySamples.isNotEmpty &&
        now.difference(_ySamples.first.timestamp) > _decayWindow) {
      _ySamples.removeAt(0);
    }
    // Safety cap.
    while (_ySamples.length > _maxSamples) {
      _ySamples.removeAt(0);
    }

    // Need a handful of samples before deriving thresholds; one
    // outlier from a single frame shouldn't drive the state machine.
    if (_ySamples.length < 5) return _empty();

    var yMin = _ySamples.first.y;
    var yMax = _ySamples.first.y;
    for (var i = 1; i < _ySamples.length; i++) {
      final v = _ySamples[i].y;
      if (v < yMin) yMin = v;
      if (v > yMax) yMax = v;
    }
    final range = yMax - yMin;
    if (range < minRange) return _empty();

    final upThreshold = yMin + range * 0.3;
    final downThreshold = yMin + range * 0.7;

    final previous = _phase;
    var current = previous;
    if (y < upThreshold) {
      current = _BurpeePhase.standing;
    } else if (y > downThreshold) {
      current = _BurpeePhase.down;
    }

    var repJustCompleted = false;
    String? contextualCue;
    String? pacingFeedback;

    if (current != previous && previous != _BurpeePhase.unknown) {
      if (current == _BurpeePhase.standing && previous == _BurpeePhase.down) {
        // Full STANDING→DOWN→STANDING cycle complete.
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
      } else if (current == _BurpeePhase.down &&
          previous == _BurpeePhase.standing) {
        // User just started descending → coach the next phase. Throttled
        // so consecutive burpees don't say it on every rep.
        final last = _lastCueTime;
        if (last == null || now.difference(last) >= cueCooldown) {
          contextualCue = 'Şimdi aşağı in ve plank pozisyonu al.';
          _lastCueTime = now;
        }
      }
    }
    _phase = current;

    return CrunchResult(
      reps: _reps,
      state: switch (current) {
        _BurpeePhase.unknown => CrunchState.unknown,
        _BurpeePhase.standing => CrunchState.up,
        _BurpeePhase.down => CrunchState.down,
      },
      torsoAngle: y,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
      contextualCue: contextualCue,
      pacingFeedback: pacingFeedback,
    );
  }

  CrunchResult _empty() => CrunchResult(
        reps: _reps,
        state: switch (_phase) {
          _BurpeePhase.unknown => CrunchState.unknown,
          _BurpeePhase.standing => CrunchState.up,
          _BurpeePhase.down => CrunchState.down,
        },
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
}

class _YSample {
  const _YSample(this.timestamp, this.y);
  final DateTime timestamp;
  final double y;
}

enum _BurpeePhase { unknown, standing, down }

// ============================================================================
// Helpers
// ============================================================================

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

double? _shoulderArmAngle(
  Pose pose,
  PoseLandmarkType shoulder,
  PoseLandmarkType elbow,
  PoseLandmarkType hip,
) {
  final s = pose.landmarks[shoulder];
  final e = pose.landmarks[elbow];
  final h = pose.landmarks[hip];
  if (s == null || e == null || h == null) return null;
  if (math.min(s.likelihood, math.min(e.likelihood, h.likelihood)) < 0.4) {
    return null;
  }
  return AngleCalculator.between(e, s, h);
}
