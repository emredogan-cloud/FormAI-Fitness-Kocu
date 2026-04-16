import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';

enum CrunchState { unknown, down, up }

class CrunchResult {
  const CrunchResult({
    required this.reps,
    required this.state,
    required this.torsoAngle,
    required this.neckAngle,
    required this.formWarning,
    required this.repJustCompleted,
  });

  final int reps;
  final CrunchState state;
  final double? torsoAngle;
  final double? neckAngle;
  final String? formWarning;
  final bool repJustCompleted;
}

/// State machine for crunches ("mekik"):
///   torso angle (shoulder-hip-knee) > [downThreshold] ⇒ DOWN
///   torso angle < [upThreshold] and was DOWN          ⇒ UP, rep + 1
/// Form check while in UP: ear-shoulder-hip angle too acute means the user is
/// yanking their neck forward.
class CrunchAnalyzer {
  CrunchAnalyzer({
    this.downThreshold = 140.0,
    this.upThreshold = 90.0,
    this.neckWarningThreshold = 120.0,
    this.minRepInterval = const Duration(milliseconds: 1200),
  });

  final double downThreshold;
  final double upThreshold;
  final double neckWarningThreshold;

  /// Minimum time between two counted reps. Faster transitions are treated as
  /// false positives (phone shake, jitter in the pose stream) and ignored.
  final Duration minRepInterval;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;

  int get reps => _reps;
  CrunchState get state => _state;

  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
  }

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

    if (torsoAngle > downThreshold) {
      _state = CrunchState.down;
    } else if (torsoAngle < upThreshold) {
      if (previousState == CrunchState.down) {
        final now = DateTime.now();
        final last = _lastRepTime;
        final tooFast = last != null && now.difference(last) < minRepInterval;
        if (!tooFast) {
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
        }
      }
      _state = CrunchState.up;
    }

    double? neckAngle;
    String? formWarning;
    if (ear != null) {
      neckAngle = AngleCalculator.between(ear, shoulder, hip);
      if (_state == CrunchState.up && neckAngle < neckWarningThreshold) {
        formWarning = 'Boynunu düz tut!';
      }
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: torsoAngle,
      neckAngle: neckAngle,
      formWarning: formWarning,
      repJustCompleted: repJustCompleted,
    );
  }

  /// Prefer the landmark with higher likelihood to tolerate partial visibility.
  PoseLandmark? _pick(
      Pose pose, PoseLandmarkType left, PoseLandmarkType right) {
    final l = pose.landmarks[left];
    final r = pose.landmarks[right];
    if (l == null) return r;
    if (r == null) return l;
    return l.likelihood >= r.likelihood ? l : r;
  }
}
