import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Roadmap Phase 3 (R1.2 · C26) · pure framing analysis for the camera
/// setup + calibration flow.
///
/// The Testers Community asked for an interactive tutorial that
/// "demonstrates how to use the AI Pose Detection". The hard part of
/// that is not the UI — it's answering, honestly and in real time,
/// *"can I see you properly right now?"* and, when the answer is no,
/// *"what exactly should you change?"*.
///
/// Everything here is a pure function over a [Pose]. No camera, no
/// widgets, no timers. That is what makes the calibration logic
/// exhaustively testable against recorded landmark fixtures — which
/// matters, because this is the code that decides whether a user's first
/// impression of FormAI's flagship feature is "it sees me" or "it's
/// broken".

/// What the framing check concluded, and what to tell the user.
enum FramingIssue {
  /// No pose at all — nobody in frame, or far too dark.
  noPose,

  /// Some landmarks are missing or low-confidence — usually partially
  /// out of frame.
  partiallyVisible,

  /// Whole body detected but small in frame: the user is too far away,
  /// so joint angles get noisy.
  tooFar,

  /// Whole body detected but overflowing the frame: too close, and the
  /// extremities will clip during a rep.
  tooClose,

  /// Facing the camera when the exercise needs a side view (or the
  /// reverse). Only reported when the caller asks for an orientation.
  wrongOrientation,

  /// Nothing to fix.
  none,
}

/// The orientation an exercise needs the phone placed in.
enum RequiredView {
  /// Squats, jumping jacks, presses — the camera faces the user.
  front,

  /// Push-ups, planks, hip hinges — the camera sits to the side.
  side,

  /// The check doesn't care.
  any,
}

/// The outcome of one framing evaluation.
class FramingResult {
  const FramingResult({
    required this.issue,
    required this.confidence,
    required this.coverage,
  });

  final FramingIssue issue;

  /// Mean visibility likelihood across the landmarks we require, 0–1.
  /// Reported so the UI can show a live "signal strength" rather than a
  /// binary state — a bar that climbs as the user steps back teaches
  /// far better than a message that flips.
  final double confidence;

  /// Fraction of the frame's height the body spans, 0–1. The single
  /// most useful number for distance guidance.
  final double coverage;

  bool get isReady => issue == FramingIssue.none;
}

/// Landmarks that must be present for a full-body read. Deliberately
/// excludes fingers, feet and facial points: ML Kit reports them
/// unreliably at typical training distances, and requiring them would
/// make the check fail for users who are actually framed fine.
const List<PoseLandmarkType> kRequiredLandmarks = [
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.leftAnkle,
  PoseLandmarkType.rightAnkle,
];

/// Below this mean likelihood we treat the read as unreliable.
const double kMinConfidence = 0.55;

/// Body height as a fraction of frame height. Below → too far; above →
/// too close. The window is wide on purpose: a user shouldn't have to
/// hunt for a millimetre-perfect spot, and every value inside it
/// produces usable joint angles.
const double kMinCoverage = 0.45;
const double kMaxCoverage = 0.96;

/// Shoulder width as a fraction of body height. A front-on torso is
/// wide; a side-on torso collapses toward the midline. Measured on the
/// *ratio* rather than raw pixels so it is distance-invariant.
const double kSideViewShoulderRatio = 0.16;

/// Evaluates [pose] for framing quality.
///
/// [frameHeight] is the analysed image height in the same coordinate
/// space as the landmarks. Pass [requiredView] to also check phone
/// placement; leave it [RequiredView.any] during generic setup.
///
/// A null [pose] means the detector returned nothing this frame.
FramingResult evaluateFraming(
  Pose? pose, {
  required double frameHeight,
  RequiredView requiredView = RequiredView.any,
}) {
  if (pose == null || pose.landmarks.isEmpty || frameHeight <= 0) {
    return const FramingResult(
      issue: FramingIssue.noPose,
      confidence: 0,
      coverage: 0,
    );
  }

  final required = <PoseLandmark>[];
  for (final type in kRequiredLandmarks) {
    final landmark = pose.landmarks[type];
    if (landmark != null) required.add(landmark);
  }

  // Missing landmark entries entirely → partial read.
  if (required.length < kRequiredLandmarks.length) {
    return FramingResult(
      issue: FramingIssue.partiallyVisible,
      confidence: _meanLikelihood(required),
      coverage: 0,
    );
  }

  final confidence = _meanLikelihood(required);
  if (confidence < kMinConfidence) {
    return FramingResult(
      issue: FramingIssue.partiallyVisible,
      confidence: confidence,
      coverage: 0,
    );
  }

  // Vertical span across every required landmark, normalised.
  var top = double.infinity;
  var bottom = double.negativeInfinity;
  for (final l in required) {
    if (l.y < top) top = l.y;
    if (l.y > bottom) bottom = l.y;
  }
  final coverage = ((bottom - top) / frameHeight).clamp(0.0, 1.0);

  if (coverage < kMinCoverage) {
    return FramingResult(
      issue: FramingIssue.tooFar,
      confidence: confidence,
      coverage: coverage,
    );
  }
  if (coverage > kMaxCoverage) {
    return FramingResult(
      issue: FramingIssue.tooClose,
      confidence: confidence,
      coverage: coverage,
    );
  }

  if (requiredView != RequiredView.any) {
    final actual = detectView(pose);
    // `RequiredView.any` never reaches here, and an indeterminate read
    // is treated as acceptable rather than blocking the user on a
    // heuristic we're not certain about.
    if (actual != null && actual != requiredView) {
      return FramingResult(
        issue: FramingIssue.wrongOrientation,
        confidence: confidence,
        coverage: coverage,
      );
    }
  }

  return FramingResult(
    issue: FramingIssue.none,
    confidence: confidence,
    coverage: coverage,
  );
}

/// Infers whether the camera is looking at the user from the front or
/// the side, or `null` when the landmarks don't support a call.
///
/// Uses shoulder separation relative to torso height: face-on, the
/// shoulders are far apart; side-on they nearly overlap. Ratio-based, so
/// it holds at any distance.
RequiredView? detectView(Pose pose) {
  final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
  final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
  final lh = pose.landmarks[PoseLandmarkType.leftHip];
  final rh = pose.landmarks[PoseLandmarkType.rightHip];
  if (ls == null || rs == null || lh == null || rh == null) return null;

  final shoulderSpan = (ls.x - rs.x).abs();
  final shoulderMidY = (ls.y + rs.y) / 2;
  final hipMidY = (lh.y + rh.y) / 2;
  final torsoHeight = (hipMidY - shoulderMidY).abs();
  if (torsoHeight <= 0) return null;

  final ratio = shoulderSpan / torsoHeight;
  return ratio < kSideViewShoulderRatio
      ? RequiredView.side
      : RequiredView.front;
}

double _meanLikelihood(List<PoseLandmark> landmarks) {
  if (landmarks.isEmpty) return 0;
  var total = 0.0;
  for (final l in landmarks) {
    total += l.likelihood;
  }
  return (total / landmarks.length).clamp(0.0, 1.0);
}

/// Debounce helper for the live calibration loop.
///
/// A single good frame is not "ready" — ML Kit flickers, and a
/// calibration that succeeds on one lucky frame then immediately fails
/// teaches the user that the feature is unreliable. This requires
/// [requiredStreak] consecutive good reads before declaring success,
/// and resets on any bad one.
class FramingStabilizer {
  FramingStabilizer({this.requiredStreak = 8});

  final int requiredStreak;
  int _streak = 0;

  /// Feeds one evaluation in; returns `true` once the streak is met.
  bool accept(FramingResult result) {
    if (result.isReady) {
      _streak++;
    } else {
      _streak = 0;
    }
    return _streak >= requiredStreak;
  }

  /// 0–1 progress toward a confirmed read, for a progress ring.
  double get progress => (_streak / requiredStreak).clamp(0.0, 1.0);

  void reset() => _streak = 0;
}
