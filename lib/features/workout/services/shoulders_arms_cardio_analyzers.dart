import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import 'crunch_analyzer.dart' show CrunchResult, CrunchState;
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
class BicepsCurlAnalyzer implements PoseAnalyzer {
  BicepsCurlAnalyzer({
    this.downThreshold = 150.0,
    this.upThreshold = 50.0,
    this.minRepInterval = const Duration(milliseconds: 900),
    this.maxElbowDriftRatio = 0.85,
    this.formWarningCooldown = const Duration(seconds: 12),
  });

  final double downThreshold;
  final double upThreshold;
  final Duration minRepInterval;

  /// Elbow drift `(|elbow.x - hip.x|) / shoulderWidth` above this is
  /// "elbow leaving the rib cage". 0.85 leaves enough headroom for
  /// users with naturally wider stances; tighter values produce false
  /// warnings on hammer curls performed off the hip.
  final double maxElbowDriftRatio;

  /// Minimum gap between two spoken elbow-drift warnings.
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

    // Tier-S form check: elbow drift away from the torso during the UP
    // phase. We measure the dominant side (the one we already used for
    // the rep angle) and compare elbow.x to hip.x on the same side.
    // Normalised by shoulder-to-shoulder width so the check holds at
    // any camera distance.
    String? formWarning;
    if (_state == CrunchState.up) {
      final dominantIsLeft = left != null;
      final elbowLm = pose.landmarks[
          dominantIsLeft ? PoseLandmarkType.leftElbow : PoseLandmarkType.rightElbow];
      final hipLm = pose.landmarks[
          dominantIsLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip];
      final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
      if (elbowLm != null && hipLm != null && ls != null && rs != null) {
        final shoulderWidth = (ls.x - rs.x).abs();
        if (shoulderWidth > 1) {
          final drift = (elbowLm.x - hipLm.x).abs() / shoulderWidth;
          if (drift > maxElbowDriftRatio) {
            final now = DateTime.now();
            if (now.difference(_lastFormWarning) >= formWarningCooldown) {
              formWarning = 'Dirseğini gövdene yapışık tut!';
              _lastFormWarning = now;
            }
          }
        }
      }
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: elbow,
      neckAngle: null,
      formWarning: formWarning,
      repJustCompleted: repJustCompleted,
    );
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
    this.partialRatio = 0.55,
    this.minRepInterval = const Duration(milliseconds: 900),
  });

  /// Wrist must rise above shoulderY by at least `upRatio × shoulderWidth`
  /// for a clean UP.
  final double upRatio;

  /// Wrist back to within `downRatio × shoulderWidth` of shoulderY = DOWN.
  final double downRatio;

  /// If the highest delta during a rep is below `partialRatio × upRatio`
  /// the rep counts but we whisper a "go all the way up" warning.
  final double partialRatio;
  final Duration minRepInterval;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;
  double _maxDelta = 0; // largest wrist-above-shoulder delta this rep

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
    _maxDelta = 0;
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

    if (delta > upThreshold) {
      _state = CrunchState.up;
    } else if (delta < downThreshold) {
      if (previous == CrunchState.up) {
        final now = DateTime.now();
        final last = _lastRepTime;
        if (last == null || now.difference(last) >= minRepInterval) {
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
          // Partial-rep nudge: rep counted but never reached full lockout.
          if (_maxDelta < upThreshold * partialRatio) {
            formWarning = 'Kolları tam yukarı uzat!';
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
class LateralRaiseAnalyzer implements PoseAnalyzer {
  LateralRaiseAnalyzer({
    this.upThreshold = 75.0,
    this.downThreshold = 25.0,
    this.minRepInterval = const Duration(milliseconds: 900),
    this.maxArmAboveShoulderRatio = 0.35,
    this.formWarningCooldown = const Duration(seconds: 12),
  });

  final double upThreshold;
  final double downThreshold;
  final Duration minRepInterval;

  /// `(shoulder.y - wrist.y) / shoulderWidth` above this means the
  /// wrist is sitting clearly above the shoulder line — over-extension.
  final double maxArmAboveShoulderRatio;

  /// Minimum gap between two spoken arm-too-high warnings.
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
    final left = _shoulderArmAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftHip,
    );
    final right = _shoulderArmAngle(
      pose,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightHip,
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

    final previous = _state;
    var repJustCompleted = false;

    if (angle > upThreshold) {
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
    } else if (angle < downThreshold) {
      _state = CrunchState.down;
    }

    // Tier-S form check: wrist-above-shoulder during the UP phase.
    // Same dominant-side pattern as the rep angle.
    String? formWarning;
    if (_state == CrunchState.up) {
      final dominantIsLeft = left != null;
      final wrist = pose.landmarks[
          dominantIsLeft ? PoseLandmarkType.leftWrist : PoseLandmarkType.rightWrist];
      final shoulder = pose.landmarks[dominantIsLeft
          ? PoseLandmarkType.leftShoulder
          : PoseLandmarkType.rightShoulder];
      final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
      if (wrist != null && shoulder != null && ls != null && rs != null) {
        final shoulderWidth = (ls.x - rs.x).abs();
        if (shoulderWidth > 1) {
          final aboveBy = shoulder.y - wrist.y; // positive when wrist is higher
          if (aboveBy / shoulderWidth > maxArmAboveShoulderRatio) {
            final now = DateTime.now();
            if (now.difference(_lastFormWarning) >= formWarningCooldown) {
              formWarning = 'Kolları omuz hizasında tut, daha yukarı kaldırma.';
              _lastFormWarning = now;
            }
          }
        }
      }
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: angle,
      neckAngle: null,
      formWarning: formWarning,
      repJustCompleted: repJustCompleted,
    );
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
class ScapularAnalyzer implements PoseAnalyzer {
  ScapularAnalyzer({
    this.upRatio = 0.45,
    this.downRatio = 0.05,
    this.minRepInterval = const Duration(milliseconds: 900),
  });

  /// `(shoulderMidY - wristMidY) / shoulderWidth` above this commits UP.
  final double upRatio;

  /// `(shoulderMidY - wristMidY) / shoulderWidth` below this commits DOWN.
  final double downRatio;

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
    // Skip the frame if either shoulder is unreliable — without a
    // baseline shoulder line the ratio is meaningless. We tolerate one
    // weak wrist (it gets averaged into the mid-point with the other).
    final minShoulder =
        ls.likelihood < rs.likelihood ? ls.likelihood : rs.likelihood;
    if (minShoulder < 0.4) return _empty();

    final shoulderWidth = (ls.x - rs.x).abs();
    if (shoulderWidth < 1) return _empty();

    final shoulderMidY = (ls.y + rs.y) / 2;
    final wristMidY = (lw.y + rw.y) / 2;
    final ratio = (shoulderMidY - wristMidY) / shoulderWidth;

    final previous = _state;
    var repJustCompleted = false;

    if (ratio > upRatio) {
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
    } else if (ratio < downRatio) {
      _state = CrunchState.down;
    }
    // Between the two thresholds we hold the previous state — natural
    // hysteresis that prevents borderline frames from re-counting.

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

// ============================================================================
// Cardio — jumping jack
// ============================================================================

/// Jumping jacks: legs spread + wrists overhead = OPEN. Legs together +
/// wrists at sides = CLOSED. One OPEN→CLOSED→OPEN cycle is a rep.
/// Uses shoulder width as the unit so it self-calibrates to camera distance.
class JumpingJackAnalyzer implements PoseAnalyzer {
  JumpingJackAnalyzer({
    this.spreadRatio = 1.4,
    this.armRatio = 0.6,
    this.minRepInterval = const Duration(milliseconds: 500),
  });

  /// Ankle distance must exceed `spreadRatio × shoulderWidth` to count
  /// as legs-open.
  final double spreadRatio;

  /// Wrist must be above shoulder by `armRatio × shoulderWidth` to count
  /// as arms-overhead.
  final double armRatio;
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

    final shoulderWidth = (ls.x - rs.x).abs();
    if (shoulderWidth < 1) return _empty();

    final ankleSpread = (la.x - ra.x).abs();
    final shoulderY = (ls.y + rs.y) / 2;
    final wristY = (lw.y + rw.y) / 2;
    final wristAbove = shoulderY - wristY;

    final isOpen = ankleSpread > shoulderWidth * spreadRatio &&
        wristAbove > shoulderWidth * armRatio;

    final previous = _state;
    var repJustCompleted = false;

    if (isOpen) {
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
    } else {
      _state = CrunchState.down;
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: ankleSpread / shoulderWidth,
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

// ============================================================================
// Cardio — burpee (state machine)
// ============================================================================

/// Three-state cycle: STANDING → DOWN (squat/plank) → STANDING. Counts
/// the rep on the closing STANDING transition. The intermediate
/// STANDING→DOWN edge fires a throttled `contextualCue` so the voice
/// coach can guide the user as they drop.
///
/// Uses the shoulder Y coordinate self-calibrated against the running
/// min/max so the analyzer adapts to whatever camera distance the user
/// happens to set up. We need ≥ 60 px of vertical movement before any
/// state commits — keeps a stationary frame from triggering false reps.
class BurpeeAnalyzer implements PoseAnalyzer {
  BurpeeAnalyzer({
    this.minRange = 60.0,
    this.minRepInterval = const Duration(milliseconds: 1500),
    this.cueCooldown = const Duration(seconds: 8),
  });

  final double minRange;
  final Duration minRepInterval;
  final Duration cueCooldown;

  int _reps = 0;
  _BurpeePhase _phase = _BurpeePhase.unknown;
  DateTime? _lastRepTime;
  DateTime? _lastCueTime;
  double? _yMin;
  double? _yMax;

  @override
  void reset() {
    _reps = 0;
    _phase = _BurpeePhase.unknown;
    _lastRepTime = null;
    _lastCueTime = null;
    _yMin = null;
    _yMax = null;
  }

  @override
  CrunchResult analyze(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder] ??
        pose.landmarks[PoseLandmarkType.rightShoulder];
    if (shoulder == null) return _empty();

    final y = shoulder.y;
    _yMin = (_yMin == null || y < _yMin!) ? y : _yMin;
    _yMax = (_yMax == null || y > _yMax!) ? y : _yMax;

    final yMin = _yMin!;
    final yMax = _yMax!;
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

    if (current != previous && previous != _BurpeePhase.unknown) {
      if (current == _BurpeePhase.standing && previous == _BurpeePhase.down) {
        // Full STANDING→DOWN→STANDING cycle complete.
        final now = DateTime.now();
        final last = _lastRepTime;
        if (last == null || now.difference(last) >= minRepInterval) {
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
        }
      } else if (current == _BurpeePhase.down &&
          previous == _BurpeePhase.standing) {
        // User just started descending → coach the next phase. Throttled
        // so consecutive burpees don't say it on every rep.
        final now = DateTime.now();
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
