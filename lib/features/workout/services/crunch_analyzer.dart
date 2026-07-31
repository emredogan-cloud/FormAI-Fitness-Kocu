import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import '../domain/coach_line.dart';
import 'pose_analyzer.dart';

enum CrunchState { unknown, down, up }

class CrunchResult {
  const CrunchResult({
    required this.reps,
    required this.state,
    required this.torsoAngle,
    required this.neckAngle,
    required this.formWarning,
    required this.repJustCompleted,
    this.pacingFeedback,
    this.contextualCue,
  });

  final int reps;
  final CrunchState state;
  final double? torsoAngle;
  final double? neckAngle;

  /// The form fault the analyzer saw this frame, or null.
  ///
  /// Roadmap Phase 5: this used to be the Turkish sentence itself. It is
  /// now the *verdict*; `presentation/coach_line_copy.dart` owns the
  /// words. Analyzers still throttle it internally, so a non-null value
  /// means "say this now".
  final CoachLine? formWarning;

  final bool repJustCompleted;

  /// Motivational coaching line emitted when the user's pacing is extreme
  /// (too fast or too slow). Null on most reps — only surfaces after the
  /// analyzer's cooldown has elapsed.
  final CoachLine? pacingFeedback;

  /// Forward-looking instruction spoken at a specific phase of an exercise
  /// (e.g. the burpee step-2 cue [CoachLine.burpeeGetDown]). Null on most
  /// frames; analyzers throttle it internally so the camera screen can
  /// speak it as-is when present.
  final CoachLine? contextualCue;
}

/// State machine for crunches ("mekik"):
///   torso angle (shoulder-hip-knee) > [downThreshold] ⇒ DOWN
///   torso angle < [upThreshold] and was DOWN          ⇒ UP, rep + 1
/// Form check while in UP: ear-shoulder-hip angle too acute means the user is
/// yanking their neck forward.
class CrunchAnalyzer implements PoseAnalyzer {
  CrunchAnalyzer({
    this.downThreshold = 140.0,
    this.upThreshold = 90.0,
    this.neckWarningThreshold = 120.0,
    this.minRepInterval = const Duration(milliseconds: 1200),
    this.tooFastThreshold = const Duration(milliseconds: 1500),
    this.strugglingThreshold = const Duration(milliseconds: 4500),
    this.feedbackCooldown = const Duration(seconds: 7),
  });

  final double downThreshold;
  final double upThreshold;
  final double neckWarningThreshold;

  /// Minimum time between two counted reps. Faster transitions are treated as
  /// false positives (phone shake, jitter in the pose stream) and ignored.
  final Duration minRepInterval;

  /// Reps faster than this trigger the "slow down" coaching line.
  final Duration tooFastThreshold;

  /// Reps slower than this trigger the "keep going" coaching line.
  final Duration strugglingThreshold;

  /// Minimum gap between two spoken pacing lines. Prevents back-to-back TTS.
  final Duration feedbackCooldown;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;
  DateTime? _lastFeedbackTime;

  /// Last time we emitted a posture warning. Seeded PAST the 15 s
  /// debounce window so the very first bad-form frame can fire the
  /// warning immediately. (The old 10 s seed silently under-shot the
  /// >15 s gate — "fire immediately" was false by five seconds; cf.
  /// PlankAnalyzer's 10 s seed against its 8 s gate, which works.)
  DateTime _lastPostureWarning =
      DateTime.now().subtract(const Duration(seconds: 16));

  int get reps => _reps;
  CrunchState get state => _state;

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
    _lastFeedbackTime = null;
    _lastPostureWarning = DateTime.now().subtract(const Duration(seconds: 16));
  }

  @override
  CrunchResult analyze(Pose pose) {
    final shoulder = _pick(
        pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    final hip =
        _pick(pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    final knee =
        _pick(pose, PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee);
    final ear =
        _pick(pose, PoseLandmarkType.leftEar, PoseLandmarkType.rightEar);

    if (shoulder == null || hip == null || knee == null) {
      return CrunchResult(
        reps: _reps,
        state: _state,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
    }

    final torsoAngle = AngleCalculator.between(shoulder, hip, knee);
    final previousState = _state;
    var repJustCompleted = false;
    CoachLine? pacingFeedback;

    if (torsoAngle > downThreshold) {
      _state = CrunchState.down;
    } else if (torsoAngle < upThreshold) {
      if (previousState == CrunchState.down) {
        final now = DateTime.now();
        final last = _lastRepTime;
        final tooFast = last != null && now.difference(last) < minRepInterval;
        if (!tooFast) {
          // Capture the per-rep duration BEFORE we overwrite _lastRepTime,
          // so pacing feedback can judge how long this rep took.
          final repDuration = last == null ? null : now.difference(last);
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;

          // Pacing coach. Skipped on the very first rep (no baseline yet)
          // and throttled by feedbackCooldown so we don't narrate every set.
          if (repDuration != null) {
            final lastFb = _lastFeedbackTime;
            final cooldownElapsed =
                lastFb == null || now.difference(lastFb) >= feedbackCooldown;
            if (cooldownElapsed) {
              if (repDuration < tooFastThreshold) {
                pacingFeedback = CoachLine.slowDownFeelIt;
                _lastFeedbackTime = now;
              } else if (repDuration > strugglingThreshold) {
                pacingFeedback = CoachLine.dontGiveUp;
                _lastFeedbackTime = now;
              }
            }
          }
        }
      }
      _state = CrunchState.up;
    }

    double? neckAngle;
    CoachLine? formWarning;
    if (ear != null) {
      neckAngle = AngleCalculator.between(ear, shoulder, hip);
      if (_state == CrunchState.up && neckAngle < neckWarningThreshold) {
        // Pose detection runs ~30 fps, so a raw posture warning would fire
        // on every frame and spam TTS. Debounce to one warning per 15 s —
        // crunches and sit-ups naturally vary head position rep-to-rep so
        // a longer window keeps the cue useful without nagging.
        final now = DateTime.now();
        if (now.difference(_lastPostureWarning).inSeconds > 15) {
          formWarning = CoachLine.neckStraight;
          _lastPostureWarning = now;
        }
      }
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: torsoAngle,
      neckAngle: neckAngle,
      formWarning: formWarning,
      repJustCompleted: repJustCompleted,
      pacingFeedback: pacingFeedback,
    );
  }

  /// Prefer the landmark with higher likelihood to tolerate partial
  /// visibility — but never one below the 0.4 confidence floor the
  /// newer analyzers enforce (a near-zero-likelihood ghost landmark
  /// used to win the pick and count phantom reps in bad lighting).
  PoseLandmark? _pick(
      Pose pose, PoseLandmarkType left, PoseLandmarkType right) {
    PoseLandmark? confident(PoseLandmark? lm) =>
        lm != null && lm.likelihood >= 0.4 ? lm : null;
    final l = confident(pose.landmarks[left]);
    final r = confident(pose.landmarks[right]);
    if (l == null) return r;
    if (r == null) return l;
    return l.likelihood >= r.likelihood ? l : r;
  }
}
