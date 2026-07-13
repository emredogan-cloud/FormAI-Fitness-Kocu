// Phase 1 (P-Risk) · golden-frame tests for the chest_analyzers.dart members
// the existing analyzer_golden_test.dart leaves uncovered: BenchPressAnalyzer
// (PushUp subclass with tighter ROM), ChestFlyAnalyzer (wrist-gap machine with
// the side-camera z fallback), and PushUpAnalyzer's hip-sag form warning.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/services/chest_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';

PoseLandmark _lm(PoseLandmarkType t, double x, double y, [double z = 0]) =>
    PoseLandmark(type: t, x: x, y: y, z: z, likelihood: 1.0);

Pose _pose(List<PoseLandmark> lms) =>
    Pose(landmarks: {for (final l in lms) l.type: l});

void main() {
  group('BenchPressAnalyzer', () {
    // Elbow flexed ≈90° (< 100 down).
    final down = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftElbow, 1, 0),
      _lm(PoseLandmarkType.leftWrist, 1, 1),
    ]);
    // Elbow extended ≈180° (> 155 up).
    final up = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftElbow, 1, 0),
      _lm(PoseLandmarkType.leftWrist, 2, 0),
    ]);

    test('counts a rep on a lower→press cycle', () {
      final a = BenchPressAnalyzer();
      expect(a.analyze(down).state, CrunchState.down);
      final r = a.analyze(up);
      expect(r.state, CrunchState.up);
      expect(r.reps, 1);
    });

    test('reset() clears reps', () {
      final a = BenchPressAnalyzer();
      a.analyze(down);
      a.analyze(up);
      a.reset();
      expect(a.analyze(up).reps, 0);
    });
  });

  group('PushUpAnalyzer hip-sag warning', () {
    // Arm extended (valid measure angle) AND a straight shoulder-hip-ankle
    // line ≈180° → no warning.
    final straight = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftElbow, 1, 0),
      _lm(PoseLandmarkType.leftWrist, 2, 0),
      _lm(PoseLandmarkType.leftHip, 2, 0),
      _lm(PoseLandmarkType.leftAnkle, 4, 0),
    ]);
    // Same arm, but the hip drops below the line → line angle ≈135° (< 155).
    final sagging = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftElbow, 1, 0),
      _lm(PoseLandmarkType.leftWrist, 2, 0),
      _lm(PoseLandmarkType.leftHip, 2, 0),
      _lm(PoseLandmarkType.leftAnkle, 4, 2),
    ]);

    test('stays silent while the body line is straight', () {
      expect(PushUpAnalyzer().analyze(straight).formWarning, isNull);
    });

    test('warns when the hips sag below the body line', () {
      expect(PushUpAnalyzer().analyze(sagging).formWarning, isNotNull);
    });
  });

  group('ChestFlyAnalyzer', () {
    final shoulders = [
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.rightShoulder, 2, 0),
    ];

    test('counts a rep on a front-camera open→close cycle', () {
      final a = ChestFlyAnalyzer();
      // Wrists wide: gap 4 / width 2 = 2.0 > 1.4 open.
      final open = _pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, -1, 0),
        _lm(PoseLandmarkType.rightWrist, 3, 0),
      ]);
      // Wrists together: gap 0.2 / 2 = 0.1 < 0.5 close.
      final close = _pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, 0.9, 0),
        _lm(PoseLandmarkType.rightWrist, 1.1, 0),
      ]);
      expect(a.analyze(open).state, CrunchState.down);
      expect(a.analyze(close).reps, 1);
    });

    test('counts a rep when the open signal is on the z (depth) axis', () {
      final a = ChestFlyAnalyzer();
      // 2D gap 0 but z-spread 4 → dominant z signal opens the arms.
      final openZ = _pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, 1, 0, -2),
        _lm(PoseLandmarkType.rightWrist, 1, 0, 2),
      ]);
      final close = _pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, 0.9, 0),
        _lm(PoseLandmarkType.rightWrist, 1.1, 0),
      ]);
      expect(a.analyze(openZ).state, CrunchState.down);
      expect(a.analyze(close).reps, 1);
    });

    test('returns empty when the shoulder width collapses (< 1)', () {
      final a = ChestFlyAnalyzer();
      final narrow = _pose([
        _lm(PoseLandmarkType.leftShoulder, 0, 0),
        _lm(PoseLandmarkType.rightShoulder, 0.5, 0),
        _lm(PoseLandmarkType.leftWrist, -1, 0),
        _lm(PoseLandmarkType.rightWrist, 3, 0),
      ]);
      expect(a.analyze(narrow).torsoAngle, isNull);
    });

    test('returns empty when a wrist is missing', () {
      final a = ChestFlyAnalyzer();
      final r = a.analyze(_pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, -1, 0),
      ]));
      expect(r.reps, 0);
      expect(r.torsoAngle, isNull);
    });

    test('reset() clears reps and state', () {
      final a = ChestFlyAnalyzer();
      final open = _pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, -1, 0),
        _lm(PoseLandmarkType.rightWrist, 3, 0),
      ]);
      final close = _pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, 0.9, 0),
        _lm(PoseLandmarkType.rightWrist, 1.1, 0),
      ]);
      a.analyze(open);
      a.analyze(close);
      a.reset();
      expect(a.analyze(close).reps, 0); // no preceding open after reset
    });
  });
}
