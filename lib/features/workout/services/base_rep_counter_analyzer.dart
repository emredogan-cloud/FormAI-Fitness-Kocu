import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'crunch_analyzer.dart' show CrunchResult, CrunchState;
import 'pacing_tracker.dart';
import 'pose_analyzer.dart';
import '../domain/coach_line.dart';

/// Phase 2 (P-Risk) · shared rep-counting state machine.
///
/// The audit (P1) flagged ~3,200 LOC of copy-paste across the per-exercise
/// analyzers: each repeated the same `_reps` / `_state` / `_lastRepTime`
/// machinery, the same minRepInterval debounce, and the same UP-from-DOWN
/// rep-commit. This base class owns that machine once. A subclass supplies:
///
///   • [measureAngle]      — the primary joint angle for this exercise, or
///                           null when the required landmarks are missing /
///                           low-confidence (the analyzer then no-ops).
///   • thresholds + polarity ([countOnAngleAbove]) — whether a rep commits
///     when the angle crosses ABOVE [upThreshold] (squat/push-up: extend at
///     the top) or BELOW it (pull-up/crunch: flex at the top).
///   • [formWarning]       — optional per-frame coaching hook (default none).
///   • an optional [PacingTracker] for tempo feedback.
///
/// Behaviour is intentionally identical to the hand-rolled analyzers it
/// replaces; the Phase 1 golden-frame tests are the regression guard.
abstract class BaseRepCounterAnalyzer implements PoseAnalyzer {
  BaseRepCounterAnalyzer({
    required this.downThreshold,
    required this.upThreshold,
    required this.countOnAngleAbove,
    this.minRepInterval = const Duration(milliseconds: 1100),
    PacingTracker? pacing,
  }) : _pacing = pacing;

  /// Angle classifying the "loaded"/bottom position.
  final double downThreshold;

  /// Angle classifying the "extended"/top position. A rep commits on the
  /// UP-from-DOWN crossing.
  final double upThreshold;

  /// `true`  → DOWN is `angle < downThreshold`, UP is `angle > upThreshold`
  ///           (squat, push-up, hip-hinge: large angle at the top).
  /// `false` → DOWN is `angle > downThreshold`, UP is `angle < upThreshold`
  ///           (pull-up, crunch: small angle at the top).
  final bool countOnAngleAbove;

  /// Minimum time between two counted reps. Faster transitions are treated
  /// as pose-stream jitter and ignored. The FIRST rep is never gated
  /// (`_lastRepTime == null`), which also makes single-cycle tests
  /// deterministic.
  final Duration minRepInterval;

  final PacingTracker? _pacing;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;

  int get reps => _reps;
  CrunchState get state => _state;

  /// Subclass: compute the primary joint angle from [pose], or null when the
  /// required landmarks are missing or below the confidence floor.
  double? measureAngle(Pose pose);

  /// Subclass hook: optional form-coaching line for this frame, evaluated
  /// after the state machine has advanced. Default: no warning.
  CoachLine? formWarning(Pose pose, double angle, CrunchState state) => null;

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
    _pacing?.reset();
    resetForm();
  }

  /// Subclass hook: reset any bespoke form-check state (cooldown stamps).
  void resetForm() {}

  @override
  CrunchResult analyze(Pose pose) {
    final angle = measureAngle(pose);
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
    CoachLine? pacingFeedback;

    final bool isDown =
        countOnAngleAbove ? angle < downThreshold : angle > downThreshold;
    final bool isUp =
        countOnAngleAbove ? angle > upThreshold : angle < upThreshold;

    if (isDown) {
      _state = CrunchState.down;
    } else if (isUp) {
      if (previous == CrunchState.down) {
        final now = DateTime.now();
        final last = _lastRepTime;
        if (last == null || now.difference(last) >= minRepInterval) {
          final repDuration = last == null ? null : now.difference(last);
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
          if (repDuration != null) {
            pacingFeedback = _pacing?.evaluate(repDuration, now);
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
      formWarning: formWarning(pose, angle, _state),
      repJustCompleted: repJustCompleted,
      pacingFeedback: pacingFeedback,
    );
  }
}
