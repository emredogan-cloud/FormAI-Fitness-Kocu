// Phase 1 (P-Risk) · golden-frame unit tests for the core_analyzers.dart
// state machines — the analyzers the existing analyzer_golden_test.dart does
// NOT cover (LegRaise, RussianTwist, MountainClimber, BicycleCrunch,
// FlutterKick, Plank, SilentHold). Same approach: hand-built [Pose]s whose
// landmark coordinates yield a known signal, validating the rep/state logic
// deterministically. These do NOT measure accuracy on real human video
// (deferred, physical validation) — they lock the threshold + transition math.
//
// Determinism levers exploited:
//   • First rep bypasses the minRepInterval gate (_lastRepTime == null), so a
//     single state flip yields exactly one rep with no wall-clock dependency.
//   • PlankAnalyzer seeds _lastWarning to now-10s, so the first sustained-sag
//     warning clears the 8 s cooldown immediately.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/services/core_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';

PoseLandmark _lm(PoseLandmarkType t, double x, double y, [double z = 0]) =>
    PoseLandmark(type: t, x: x, y: y, z: z, likelihood: 1.0);

Pose _pose(List<PoseLandmark> lms) =>
    Pose(landmarks: {for (final l in lms) l.type: l});

void main() {
  group('LegRaiseAnalyzer', () {
    // Lying flat: shoulder-hip-ankle collinear → hip angle ≈180° (> 150 down).
    final down = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftAnkle, 2, 0),
    ]);
    // Legs vertical: ankle lifted over the hip → hip angle ≈90° (< 110 up).
    final up = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftAnkle, 1, -2),
    ]);

    test('counts exactly one rep on a down→up cycle', () {
      final a = LegRaiseAnalyzer();
      expect(a.analyze(down).state, CrunchState.down);
      final r = a.analyze(up);
      expect(r.state, CrunchState.up);
      expect(r.reps, 1);
      expect(r.repJustCompleted, isTrue);
    });

    test('returns no rep when required landmarks are missing', () {
      final a = LegRaiseAnalyzer();
      final r = a.analyze(_pose([_lm(PoseLandmarkType.leftShoulder, 0, 0)]));
      expect(r.reps, 0);
      expect(r.torsoAngle, isNull);
    });

    test('reset() clears reps and state', () {
      final a = LegRaiseAnalyzer();
      a.analyze(down);
      a.analyze(up);
      expect(a.analyze(down).reps, 1); // still 1 until reset
      a.reset();
      expect(a.analyze(up).reps, 0); // no preceding down after reset
    });
  });

  group('RussianTwistAnalyzer', () {
    // Hips fixed at centre; the torso (shoulders) swings left/right. z=0 on
    // every landmark so the x-axis (front-camera) signal dominates.
    final hips = [
      _lm(PoseLandmarkType.leftHip, 0, 2),
      _lm(PoseLandmarkType.rightHip, 2, 2),
    ];
    // shoulderMidX 2 vs hipMidX 1 → +1 offset > 0.36 threshold → right.
    final twistRight = _pose([
      ...hips,
      _lm(PoseLandmarkType.leftShoulder, 1, 0),
      _lm(PoseLandmarkType.rightShoulder, 3, 0),
    ]);
    // shoulderMidX 0 vs hipMidX 1 → -1 offset < -0.36 → left.
    final twistLeft = _pose([
      ...hips,
      _lm(PoseLandmarkType.leftShoulder, -1, 0),
      _lm(PoseLandmarkType.rightShoulder, 1, 0),
    ]);

    test('counts a rep on a right→left swing', () {
      final a = RussianTwistAnalyzer();
      expect(a.analyze(twistRight).reps, 0); // first side commit, no rep yet
      final r = a.analyze(twistLeft);
      expect(r.reps, 1);
      expect(r.repJustCompleted, isTrue);
    });

    test('returns empty when shoulder width collapses (< 1)', () {
      final a = RussianTwistAnalyzer();
      final narrow = _pose([
        ...hips,
        _lm(PoseLandmarkType.leftShoulder, 1, 0),
        _lm(PoseLandmarkType.rightShoulder, 1.2, 0),
      ]);
      expect(a.analyze(narrow).torsoAngle, isNull);
    });

    test('reset() clears reps', () {
      final a = RussianTwistAnalyzer();
      a.analyze(twistRight);
      a.analyze(twistLeft);
      a.reset();
      expect(a.analyze(twistRight).reps, 0);
    });
  });

  group('MountainClimberAnalyzer', () {
    // Torso length 10 (shoulders at y=0, hips at y=10). Knees kept 2D-far from
    // their shoulders so only the z-depth signal drives "active".
    List<PoseLandmark> frame({required double lkz, required double rkz}) => [
          _lm(PoseLandmarkType.leftShoulder, 0, 0),
          _lm(PoseLandmarkType.rightShoulder, 2, 0),
          _lm(PoseLandmarkType.leftHip, 0, 10),
          _lm(PoseLandmarkType.rightHip, 2, 10),
          _lm(PoseLandmarkType.leftKnee, 0, 10, lkz),
          _lm(PoseLandmarkType.rightKnee, 2, 10, rkz),
        ];
    // hip.z - knee.z = 3 > torso(10)*0.25 = 2.5 → that knee is driven forward.
    final leftDrive = _pose(frame(lkz: -3, rkz: 0));
    final rightDrive = _pose(frame(lkz: 0, rkz: -3));

    test('counts a rep on a left→right knee hand-off', () {
      final a = MountainClimberAnalyzer();
      expect(a.analyze(leftDrive).reps, 0);
      expect(a.analyze(rightDrive).reps, 1);
    });

    test('returns empty when a required landmark is missing', () {
      final a = MountainClimberAnalyzer();
      final r = a.analyze(_pose([_lm(PoseLandmarkType.leftShoulder, 0, 0)]));
      expect(r.reps, 0);
      expect(r.state, CrunchState.unknown);
    });

    test('reset() clears reps', () {
      final a = MountainClimberAnalyzer();
      a.analyze(leftDrive);
      a.analyze(rightDrive);
      a.reset();
      expect(a.analyze(rightDrive).reps, 0);
    });
  });

  group('BicycleCrunchAnalyzer', () {
    // Shoulder reference width 4 → threshold 2. One cross-pair collapses to ~0
    // while the other stays well above threshold.
    final base = [
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.rightShoulder, 4, 0),
    ];
    // LE↔RK touch (0); RE↔LK far (√32).
    final leftTouch = _pose([
      ...base,
      _lm(PoseLandmarkType.leftElbow, 1, 1),
      _lm(PoseLandmarkType.rightKnee, 1, 1),
      _lm(PoseLandmarkType.rightElbow, 4, 0),
      _lm(PoseLandmarkType.leftKnee, 0, 4),
    ]);
    // RE↔LK touch (0); LE↔RK far (√32).
    final rightTouch = _pose([
      ...base,
      _lm(PoseLandmarkType.rightElbow, 3, 1),
      _lm(PoseLandmarkType.leftKnee, 3, 1),
      _lm(PoseLandmarkType.leftElbow, 0, 0),
      _lm(PoseLandmarkType.rightKnee, 4, 4),
    ]);

    test('counts a rep on a left→right elbow-knee alternation', () {
      final a = BicycleCrunchAnalyzer();
      expect(a.analyze(leftTouch).reps, 0);
      expect(a.analyze(rightTouch).reps, 1);
    });

    test('returns empty when the shoulder reference collapses (< 1)', () {
      final a = BicycleCrunchAnalyzer();
      final narrow = _pose([
        _lm(PoseLandmarkType.leftShoulder, 0, 0),
        _lm(PoseLandmarkType.rightShoulder, 0.5, 0),
        _lm(PoseLandmarkType.leftElbow, 0, 0),
        _lm(PoseLandmarkType.rightElbow, 0, 0),
        _lm(PoseLandmarkType.leftKnee, 0, 0),
        _lm(PoseLandmarkType.rightKnee, 0, 0),
      ]);
      expect(a.analyze(narrow).reps, 0);
    });
  });

  group('FlutterKickAnalyzer', () {
    // Shoulder at y=0; ankles near y=9 → scale ≈9, minDelta ≈0.36.
    final leftLift = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftAnkle, 0, 8),
      _lm(PoseLandmarkType.rightAnkle, 0, 10),
    ]);
    final rightLift = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftAnkle, 0, 10),
      _lm(PoseLandmarkType.rightAnkle, 0, 8),
    ]);

    test('counts a rep when the lifted leg switches', () {
      final a = FlutterKickAnalyzer();
      expect(a.analyze(leftLift).reps, 0);
      expect(a.analyze(rightLift).reps, 1);
    });

    test('returns empty when an ankle is missing', () {
      final a = FlutterKickAnalyzer();
      final r = a.analyze(_pose([
        _lm(PoseLandmarkType.leftShoulder, 0, 0),
        _lm(PoseLandmarkType.leftAnkle, 0, 8),
      ]));
      expect(r.reps, 0);
      expect(r.torsoAngle, isNull);
    });

    test('returns empty when the body scale collapses (< 1)', () {
      final a = FlutterKickAnalyzer();
      final flat = _pose([
        _lm(PoseLandmarkType.leftShoulder, 0, 9),
        _lm(PoseLandmarkType.leftAnkle, 0, 9),
        _lm(PoseLandmarkType.rightAnkle, 0, 9),
      ]);
      expect(a.analyze(flat).torsoAngle, isNull);
    });
  });

  group('PlankAnalyzer', () {
    final straight = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftAnkle, 2, 0),
    ]);
    // Hip below the shoulder-ankle line → line angle ≈135° (< 155 sag).
    final sag = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftAnkle, 2, 1),
    ]);

    test('a straight plank produces no warning', () {
      final a = PlankAnalyzer();
      final r = a.analyze(straight);
      expect(r.formWarning, isNull);
      expect(r.state, CrunchState.up);
      expect(r.reps, 0);
      expect(r.torsoAngle, closeTo(180, 0.5));
    });

    test('warns only after a sustained sag (5-frame streak)', () {
      final a = PlankAnalyzer();
      for (var i = 0; i < 4; i++) {
        expect(a.analyze(sag).formWarning, isNull,
            reason: 'frame ${i + 1} is below the streak threshold');
      }
      expect(a.analyze(sag).formWarning, isNotNull); // 5th frame fires
    });

    test('a clean frame resets the streak before it warns', () {
      final a = PlankAnalyzer();
      a.analyze(sag);
      a.analyze(sag);
      a.analyze(straight); // wipes the streak
      a.analyze(sag);
      a.analyze(sag);
      a.analyze(sag);
      expect(a.analyze(sag).formWarning, isNull); // only 4 since the reset
    });

    test('missing landmarks yield an unknown, warning-free frame', () {
      final a = PlankAnalyzer();
      final r = a.analyze(_pose([_lm(PoseLandmarkType.leftShoulder, 0, 0)]));
      expect(r.state, CrunchState.unknown);
      expect(r.formWarning, isNull);
    });
  });

  group('SilentHoldAnalyzer', () {
    test('never counts reps or warns on the first frame', () {
      final a = SilentHoldAnalyzer();
      final r = a.analyze(_pose([_lm(PoseLandmarkType.leftShoulder, 0, 0)]));
      expect(r.reps, 0);
      expect(r.state, CrunchState.up);
      expect(r.formWarning, isNull);
      expect(r.torsoAngle, isNull);
    });

    test('reset() does not throw and keeps results empty', () {
      final a = SilentHoldAnalyzer();
      a.analyze(_pose([]));
      a.reset();
      expect(a.analyze(_pose([])).reps, 0);
    });
  });
}
