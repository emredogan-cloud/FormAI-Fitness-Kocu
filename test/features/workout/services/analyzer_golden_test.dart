// Phase 1 (P-Risk) · golden-frame unit tests for the rule-based pose
// analyzers — the audit's P0 ("3.600 LOC form-detection engine, zero tests").
//
// These are SYNTHETIC-pose tests: each frame is a hand-built [Pose] whose
// landmark coordinates yield a known joint angle, so the analyzer's state
// machine (DOWN/UP transitions, rep counting, reset) is validated
// deterministically. They do NOT measure accuracy on real human video —
// that requires labelled footage and is tracked separately as deferred,
// physical validation. What they DO lock down is the angle-threshold logic
// that every rep count depends on.
//
// Key property exploited for determinism: the FIRST rep counts immediately
// (`_lastRepTime == null` bypasses the minRepInterval gate), so a single
// DOWN→UP cycle reliably yields exactly one rep with no wall-clock delay.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/services/back_legs_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/chest_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';

PoseLandmark _lm(PoseLandmarkType t, double x, double y) =>
    PoseLandmark(type: t, x: x, y: y, z: 0, likelihood: 1.0);

Pose _pose(List<PoseLandmark> lms) =>
    Pose(landmarks: {for (final l in lms) l.type: l});

void main() {
  group('CrunchAnalyzer', () {
    // Lying flat: shoulder-hip-knee collinear → torso ≈180° (> downThreshold).
    final down = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftKnee, 2, 0),
    ]);
    // Crunched up: shoulder lifted over the hip → torso ≈76° (< upThreshold).
    final up = _pose([
      _lm(PoseLandmarkType.leftShoulder, 1.5, -2),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftKnee, 2, 0),
    ]);

    test('counts exactly one rep on a down→up cycle', () {
      final a = CrunchAnalyzer();
      expect(a.analyze(down).state, CrunchState.down);
      final r = a.analyze(up);
      expect(r.state, CrunchState.up);
      expect(r.reps, 1);
      expect(r.repJustCompleted, isTrue);
    });

    test('does not count an up frame with no preceding down', () {
      final a = CrunchAnalyzer();
      expect(a.analyze(up).reps, 0);
      expect(a.analyze(up).reps, 0);
    });

    test('returns no rep when required landmarks are missing', () {
      final a = CrunchAnalyzer();
      final partial = _pose([_lm(PoseLandmarkType.leftShoulder, 0, 0)]);
      final r = a.analyze(partial);
      expect(r.reps, 0);
      expect(r.repJustCompleted, isFalse);
      expect(r.torsoAngle, isNull);
    });

    test('reset() clears rep count and state', () {
      final a = CrunchAnalyzer();
      a.analyze(down);
      a.analyze(up);
      expect(a.reps, 1);
      a.reset();
      expect(a.reps, 0);
      expect(a.state, CrunchState.unknown);
    });
  });

  group('SquatAnalyzer', () {
    // Deep squat: knee flexed ≈90° (< downThreshold 100).
    final deep = _pose([
      _lm(PoseLandmarkType.leftHip, 0, 0),
      _lm(PoseLandmarkType.leftKnee, 0, 1),
      _lm(PoseLandmarkType.leftAnkle, 1, 1),
    ]);
    // Standing: knee extended ≈180° (> upThreshold 165).
    final stand = _pose([
      _lm(PoseLandmarkType.leftHip, 0, 0),
      _lm(PoseLandmarkType.leftKnee, 0, 1),
      _lm(PoseLandmarkType.leftAnkle, 0, 2),
    ]);

    test('counts exactly one rep on a deep→stand cycle', () {
      final a = SquatAnalyzer();
      expect(a.analyze(deep).state, CrunchState.down);
      final r = a.analyze(stand);
      expect(r.state, CrunchState.up);
      expect(r.reps, 1);
      expect(r.repJustCompleted, isTrue);
    });

    test('ignores low-confidence landmarks (likelihood < 0.4)', () {
      final a = SquatAnalyzer();
      final blurry = Pose(landmarks: {
        PoseLandmarkType.leftHip:
            PoseLandmark(type: PoseLandmarkType.leftHip, x: 0, y: 0, z: 0, likelihood: 0.1),
        PoseLandmarkType.leftKnee:
            PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0, y: 1, z: 0, likelihood: 0.1),
        PoseLandmarkType.leftAnkle:
            PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 1, y: 1, z: 0, likelihood: 0.1),
      });
      final r = a.analyze(blurry);
      expect(r.torsoAngle, isNull);
      expect(r.reps, 0);
    });

    test('reset() clears rep count', () {
      final a = SquatAnalyzer();
      a.analyze(deep);
      a.analyze(stand);
      a.reset();
      final r = a.analyze(stand);
      expect(r.reps, 0);
    });
  });

  group('PushUpAnalyzer', () {
    // Elbow flexed ≈90° (< downThreshold 95).
    final down = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftElbow, 1, 0),
      _lm(PoseLandmarkType.leftWrist, 1, 1),
    ]);
    // Elbow extended ≈180° (> upThreshold 160).
    final up = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftElbow, 1, 0),
      _lm(PoseLandmarkType.leftWrist, 2, 0),
    ]);

    test('counts exactly one rep on a lower→press cycle', () {
      final a = PushUpAnalyzer();
      expect(a.analyze(down).state, CrunchState.down);
      final r = a.analyze(up);
      expect(r.state, CrunchState.up);
      expect(r.reps, 1);
      expect(r.repJustCompleted, isTrue);
    });

    test('reset() clears rep count', () {
      final a = PushUpAnalyzer();
      a.analyze(down);
      a.analyze(up);
      a.reset();
      expect(a.analyze(up).reps, 0);
    });
  });

  group('PullUpAnalyzer', () {
    // Hanging: elbow extended ≈180° (> downThreshold 150) ⇒ DOWN.
    final hang = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftElbow, 1, 0),
      _lm(PoseLandmarkType.leftWrist, 2, 0),
    ]);
    // Chin over bar: elbow flexed ≈20° (< upThreshold 80) ⇒ UP, rep counts
    // on the flexion crossing (inverse of the squat/push-up machine).
    final pulled = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftElbow, 1, 0),
      _lm(PoseLandmarkType.leftWrist, 0.2, 0.3),
    ]);

    test('counts a rep on a hang→pull cycle (rep on flexion)', () {
      final a = PullUpAnalyzer();
      expect(a.analyze(hang).state, CrunchState.down);
      final r = a.analyze(pulled);
      expect(r.state, CrunchState.up);
      expect(r.reps, 1);
    });
  });

  group('HipHingeAnalyzer', () {
    // Hip flexed ≈90° (< downThreshold 130) ⇒ DOWN.
    final folded = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftKnee, 1, 1),
    ]);
    // Hip extended ≈180° (> upThreshold 165) ⇒ UP, full lockout, rep.
    final locked = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftKnee, 2, 0),
    ]);

    test('counts a rep on a fold→lockout cycle', () {
      final a = HipHingeAnalyzer();
      expect(a.analyze(folded).state, CrunchState.down);
      final r = a.analyze(locked);
      expect(r.state, CrunchState.up);
      expect(r.reps, 1);
    });
  });
}
