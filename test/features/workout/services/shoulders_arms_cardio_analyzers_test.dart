// Phase 1 (P-Risk) · golden-frame tests for the shoulders_arms_cardio_analyzers
// members the existing analyzer_golden_test.dart leaves at 0% / partial:
// JumpingJackAnalyzer (spread+arm hysteresis), BurpeeAnalyzer (sliding-window
// shoulder-Y 3-phase machine), and ShoulderPressAnalyzer (wrist-above-shoulder
// rep machine — the press→rack happy path plus its guards).

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';
import 'package:sixpack_ai/features/workout/services/shoulders_arms_cardio_analyzers.dart';
import 'package:sixpack_ai/features/workout/domain/coach_line.dart';

PoseLandmark _lm(PoseLandmarkType t, double x, double y, [double like = 1.0]) =>
    PoseLandmark(type: t, x: x, y: y, z: 0, likelihood: like);

Pose _pose(List<PoseLandmark> lms) =>
    Pose(landmarks: {for (final l in lms) l.type: l});

void main() {
  group('JumpingJackAnalyzer', () {
    // shoulderWidth 2 → openGate ankleSpread>2.5 & wristAbove>1.0,
    //                   closeGate ankleSpread<1.9 & wristAbove<0.4.
    final shoulders = [
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.rightShoulder, 2, 0),
    ];
    // Feet together, arms down → CLOSED.
    final closed = _pose([
      ...shoulders,
      _lm(PoseLandmarkType.leftAnkle, 0.5, 10),
      _lm(PoseLandmarkType.rightAnkle, 1.5, 10),
      _lm(PoseLandmarkType.leftWrist, 0, 5),
      _lm(PoseLandmarkType.rightWrist, 2, 5),
    ]);
    // Feet wide, arms overhead → OPEN.
    final open = _pose([
      ...shoulders,
      _lm(PoseLandmarkType.leftAnkle, -1, 10),
      _lm(PoseLandmarkType.rightAnkle, 4, 10),
      _lm(PoseLandmarkType.leftWrist, 0, -3),
      _lm(PoseLandmarkType.rightWrist, 2, -3),
    ]);

    test('counts a rep on a closed→open jump', () {
      final a = JumpingJackAnalyzer();
      expect(a.analyze(closed).state, CrunchState.down);
      final r = a.analyze(open);
      expect(r.state, CrunchState.up);
      expect(r.reps, 1);
    });

    test('holds state when neither hysteresis gate clears', () {
      final a = JumpingJackAnalyzer();
      a.analyze(closed); // → down
      // Mid-spread, arms mid: ankleSpread 2.2 (between 1.9 and 2.5).
      final mid = _pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftAnkle, 0, 10),
        _lm(PoseLandmarkType.rightAnkle, 2.2, 10),
        _lm(PoseLandmarkType.leftWrist, 0, 1),
        _lm(PoseLandmarkType.rightWrist, 2, 1),
      ]);
      final r = a.analyze(mid);
      expect(r.state, CrunchState.down); // unchanged
      expect(r.reps, 0);
    });

    test('ignores a low-confidence frame', () {
      final a = JumpingJackAnalyzer();
      final blurry = _pose([
        _lm(PoseLandmarkType.leftShoulder, 0, 0, 0.1),
        _lm(PoseLandmarkType.rightShoulder, 2, 0, 0.1),
        _lm(PoseLandmarkType.leftAnkle, -1, 10, 0.1),
        _lm(PoseLandmarkType.rightAnkle, 4, 10, 0.1),
        _lm(PoseLandmarkType.leftWrist, 0, -3, 0.1),
        _lm(PoseLandmarkType.rightWrist, 2, -3, 0.1),
      ]);
      expect(a.analyze(blurry).torsoAngle, isNull);
    });

    test('returns empty when a landmark is missing', () {
      final a = JumpingJackAnalyzer();
      expect(a.analyze(_pose(shoulders)).reps, 0);
    });

    test('reset() clears reps', () {
      final a = JumpingJackAnalyzer();
      a.analyze(closed);
      a.analyze(open);
      a.reset();
      expect(a.analyze(open).reps, 0);
    });
  });

  group('BurpeeAnalyzer', () {
    Pose shoulderAt(double y) =>
        _pose([_lm(PoseLandmarkType.leftShoulder, 0, y)]);

    test('counts a rep across a standing→down→standing cycle', () {
      final a = BurpeeAnalyzer();
      // Range 100 (≥ 60 minRange) → upThreshold 30, downThreshold 70.
      // <5 samples are warm-up; the machine commits from the 5th frame.
      final ys = <double>[0, 100, 0, 100, 0, 100, 0];
      final results = [for (final y in ys) a.analyze(shoulderAt(y))];
      expect(results.last.reps, 1);
      // The standing→down edge (frame 6) fires the descend cue.
      expect(results[5].contextualCue, isNotNull);
    });

    test('stays empty until it has at least 5 samples', () {
      final a = BurpeeAnalyzer();
      late CrunchResult r;
      for (final y in <double>[0, 100, 0, 100]) {
        r = a.analyze(shoulderAt(y));
      }
      expect(r.reps, 0);
      expect(r.torsoAngle, isNull);
    });

    test('stays empty when vertical range is below minRange', () {
      final a = BurpeeAnalyzer();
      late CrunchResult r;
      for (var i = 0; i < 6; i++) {
        r = a.analyze(shoulderAt(10)); // flat → range 0 < 60
      }
      expect(r.reps, 0);
      expect(r.torsoAngle, isNull);
    });

    test('returns empty when the shoulder is missing', () {
      expect(BurpeeAnalyzer().analyze(_pose([])).reps, 0);
    });

    test('reset() clears reps and the sample window', () {
      final a = BurpeeAnalyzer();
      for (final y in <double>[0, 100, 0, 100, 0, 100, 0]) {
        a.analyze(shoulderAt(y));
      }
      a.reset();
      late CrunchResult r;
      for (final y in <double>[0, 100, 0, 100]) {
        r = a.analyze(shoulderAt(y)); // < 5 samples again
      }
      expect(r.reps, 0);
    });
  });

  group('ShoulderPressAnalyzer', () {
    // shoulderWidth 2 → upThreshold 1.4, downThreshold 0.2.
    final shoulders = [
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.rightShoulder, 2, 0),
    ];
    // Wrists well overhead → delta 2 > 1.4 UP (full lockout).
    final pressed = _pose([
      ...shoulders,
      _lm(PoseLandmarkType.leftWrist, 0, -2),
      _lm(PoseLandmarkType.rightWrist, 2, -2),
    ]);
    // Wrists back at shoulder line → delta 0 < 0.2 DOWN.
    final racked = _pose([
      ...shoulders,
      _lm(PoseLandmarkType.leftWrist, 0, 0),
      _lm(PoseLandmarkType.rightWrist, 2, 0),
    ]);

    test('counts a full-lockout rep with no partial warning', () {
      final a = ShoulderPressAnalyzer();
      expect(a.analyze(pressed).state, CrunchState.up);
      final r = a.analyze(racked);
      expect(r.state, CrunchState.down);
      expect(r.reps, 1);
      expect(r.formWarning, isNull);
    });

    test(
        'a shallow press (clears the UP gate, misses the lockout bar) '
        'counts but earns the partial-rep cue — this warning was dead '
        'code while partialRatio < 1.0', () {
      final a = ShoulderPressAnalyzer();
      // delta 1.5: above upThreshold (1.4) → UP, but below the
      // full-lockout bar upThreshold × 1.3 = 1.82.
      final shallowPress = _pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, 0, -1.5),
        _lm(PoseLandmarkType.rightWrist, 2, -1.5),
      ]);
      expect(a.analyze(shallowPress).state, CrunchState.up);
      final r = a.analyze(racked);
      expect(r.reps, 1);
      expect(r.formWarning, CoachLine.armsFullyExtended);
    });

    test('returns empty when a wrist is missing', () {
      final a = ShoulderPressAnalyzer();
      final r = a.analyze(_pose([
        ...shoulders,
        _lm(PoseLandmarkType.leftWrist, 0, -2),
      ]));
      expect(r.reps, 0);
      expect(r.torsoAngle, isNull);
    });

    test('returns empty when shoulder width collapses (< 1)', () {
      final a = ShoulderPressAnalyzer();
      final narrow = _pose([
        _lm(PoseLandmarkType.leftShoulder, 0, 0),
        _lm(PoseLandmarkType.rightShoulder, 0.5, 0),
        _lm(PoseLandmarkType.leftWrist, 0, -2),
        _lm(PoseLandmarkType.rightWrist, 0.5, -2),
      ]);
      expect(a.analyze(narrow).torsoAngle, isNull);
    });

    test('reset() clears reps', () {
      final a = ShoulderPressAnalyzer();
      a.analyze(pressed);
      a.analyze(racked);
      a.reset();
      expect(a.analyze(racked).reps, 0);
    });
  });
}
