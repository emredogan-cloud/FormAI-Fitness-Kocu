// Phase 1 (P-Risk) · closes the form-warning + guard branches in
// back_legs_analyzers.dart that the existing analyzer_golden_test.dart leaves
// uncovered (it covers the Squat/HipHinge/PullUp rep cycles, not the coaching
// hooks): SquatAnalyzer's torso-lean cue and HipHingeAnalyzer's partial-ROM cue.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/services/back_legs_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';

PoseLandmark _lm(PoseLandmarkType t, double x, double y) =>
    PoseLandmark(type: t, x: x, y: y, z: 0, likelihood: 1.0);

Pose _pose(List<PoseLandmark> lms) =>
    Pose(landmarks: {for (final l in lms) l.type: l});

void main() {
  group('SquatAnalyzer torso-lean warning', () {
    // Knee flexed ≈90° (< 100 down). Shoulder thrown forward of the hip
    // (dx/dy = 1.0 > 0.7 lean ratio) → "sit back" cue.
    final leaningAtBottom = _pose([
      _lm(PoseLandmarkType.leftHip, 0, 0),
      _lm(PoseLandmarkType.leftKnee, 0, 1),
      _lm(PoseLandmarkType.leftAnkle, 1, 1),
      _lm(PoseLandmarkType.leftShoulder, 3, -3),
    ]);
    // Same depth, torso stacked over the hip (dx 0) → no cue.
    final uprightAtBottom = _pose([
      _lm(PoseLandmarkType.leftHip, 0, 0),
      _lm(PoseLandmarkType.leftKnee, 0, 1),
      _lm(PoseLandmarkType.leftAnkle, 1, 1),
      _lm(PoseLandmarkType.leftShoulder, 0, -3),
    ]);

    test('warns when the torso leans too far forward at the bottom', () {
      final r = SquatAnalyzer().analyze(leaningAtBottom);
      expect(r.state, CrunchState.down);
      expect(r.formWarning, isNotNull);
    });

    test('stays silent when the torso is upright at the bottom', () {
      final r = SquatAnalyzer().analyze(uprightAtBottom);
      expect(r.state, CrunchState.down);
      expect(r.formWarning, isNull);
    });

    test('does not run the lean check outside the DOWN state', () {
      // Knee extended ≈180° → UP; the form hook returns early on !down.
      final standing = _pose([
        _lm(PoseLandmarkType.leftHip, 0, 0),
        _lm(PoseLandmarkType.leftKnee, 0, 1),
        _lm(PoseLandmarkType.leftAnkle, 0, 2),
        _lm(PoseLandmarkType.leftShoulder, 3, -3), // leaning, but standing
      ]);
      expect(SquatAnalyzer().analyze(standing).formWarning, isNull);
    });
  });

  group('HipHingeAnalyzer partial-ROM warning', () {
    // Hip flexed ≈90° (< 130 down).
    final folded = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftKnee, 1, 1),
    ]);
    // Shallow lockout ≈168.7° — past the 165 up gate but short of 175.
    final shallowLockout = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftKnee, 2, 0.2),
    ]);
    // Full lockout ≈180°.
    final fullLockout = _pose([
      _lm(PoseLandmarkType.leftShoulder, 0, 0),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftKnee, 2, 0),
    ]);

    test(
        'counts the rep at the up-crossing and coaches the shallow '
        'lockout on the NEXT descent (full-cycle peak, not the '
        'commit-frame angle)', () {
      final a = HipHingeAnalyzer();
      expect(a.analyze(folded).state, CrunchState.down);
      final commit = a.analyze(shallowLockout);
      expect(commit.reps, 1);
      // No premature nag at the commit frame — the user may still be
      // extending toward full lockout.
      expect(commit.formWarning, isNull);
      // Descent closes the cycle: the peak stayed shallow → cue fires.
      final descent = a.analyze(folded);
      expect(descent.formWarning, 'Kalçanı sonuna kadar yukarı sık!');
    });

    test(
        'a rep that reaches full lockout AFTER the count never gets '
        'nagged (the old commit-frame check false-positived on exactly '
        'this good rep)', () {
      final a = HipHingeAnalyzer();
      a.analyze(folded);
      final commit = a.analyze(shallowLockout); // counted at ~168.7°
      expect(commit.reps, 1);
      a.analyze(fullLockout); // user keeps extending to ~180°
      final descent = a.analyze(folded);
      expect(descent.formWarning, isNull);
    });

    test('counts the rep with no warning on a full lockout', () {
      final a = HipHingeAnalyzer();
      a.analyze(folded);
      final r = a.analyze(fullLockout);
      expect(r.reps, 1);
      expect(r.formWarning, isNull);
      // And the closing descent stays quiet too — peak hit 180°.
      expect(a.analyze(folded).formWarning, isNull);
    });

    test('returns empty when required landmarks are missing', () {
      final r = HipHingeAnalyzer()
          .analyze(_pose([_lm(PoseLandmarkType.leftShoulder, 0, 0)]));
      expect(r.reps, 0);
      expect(r.torsoAngle, isNull);
    });

    test('reset() clears reps and peak-angle state', () {
      final a = HipHingeAnalyzer();
      a.analyze(folded);
      a.analyze(fullLockout);
      a.reset();
      expect(a.analyze(fullLockout).reps, 0); // no preceding down after reset
    });
  });
}
