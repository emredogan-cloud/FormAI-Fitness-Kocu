// Phase 1 (P-Risk) · neck-angle posture path for CrunchAnalyzer, which the
// rep-focused crunch group in analyzer_golden_test.dart doesn't exercise.
//
// The pacing-feedback lines and the actual neck-warning emit are wall-clock
// gated (a counted 2nd rep needs a >1.2 s gap; the posture cue needs >15 s),
// so they can't be driven deterministically without a clock seam — left
// uncovered by design. What IS covered here: the ear→neckAngle computation
// and the UP-state acute-neck branch.
//
// Behaviour note: the posture cue seeds _lastPostureWarning to only 10 s in
// the past but gates on `> 15 s`, so — unlike PlankAnalyzer (10 s seed / 8 s
// gate) — it canNOT fire on the first bad-form frame, contradicting the code
// comment that says it should. These tests pin the current (suppressed)
// behaviour; flagged for a follow-up.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';

PoseLandmark _lm(PoseLandmarkType t, double x, double y) =>
    PoseLandmark(type: t, x: x, y: y, z: 0, likelihood: 1.0);

Pose _pose(List<PoseLandmark> lms) =>
    Pose(landmarks: {for (final l in lms) l.type: l});

void main() {
  // Lying flat: shoulder-hip-knee ≈180° (> 140 down).
  final downLandmarks = [
    _lm(PoseLandmarkType.leftShoulder, 0, 0),
    _lm(PoseLandmarkType.leftHip, 1, 0),
    _lm(PoseLandmarkType.leftKnee, 2, 0),
  ];
  // Crunched up: torso ≈76° (< 90 up). Ear thrown forward of the shoulder so
  // the ear-shoulder-hip angle is acute (≈104° < 120 neck-warning threshold).
  final upLandmarks = [
    _lm(PoseLandmarkType.leftShoulder, 1.5, -2),
    _lm(PoseLandmarkType.leftHip, 1, 0),
    _lm(PoseLandmarkType.leftKnee, 2, 0),
    _lm(PoseLandmarkType.leftEar, 2, -2),
  ];

  test('computes the neck angle when the ear is visible', () {
    final a = CrunchAnalyzer();
    a.analyze(_pose(downLandmarks));
    final r = a.analyze(_pose(upLandmarks));
    expect(r.state, CrunchState.up);
    expect(r.reps, 1);
    expect(r.neckAngle, isNotNull);
    expect(r.neckAngle, lessThan(120)); // acute → would warrant a cue
  });

  test('leaves the neck angle null when no ear landmark is present', () {
    final a = CrunchAnalyzer();
    a.analyze(_pose(downLandmarks));
    final r = a.analyze(_pose([
      _lm(PoseLandmarkType.leftShoulder, 1.5, -2),
      _lm(PoseLandmarkType.leftHip, 1, 0),
      _lm(PoseLandmarkType.leftKnee, 2, 0),
    ]));
    expect(r.reps, 1);
    expect(r.neckAngle, isNull);
  });

  test('emits the posture cue on the first acute-neck frame', () {
    // The debounce seed (16 s) now clears the >15 s gate, so the very
    // first bad-form frame coaches immediately — the old 10 s seed
    // silently swallowed the first 5 seconds of bad form.
    final a = CrunchAnalyzer();
    a.analyze(_pose(downLandmarks));
    expect(a.analyze(_pose(upLandmarks)).formWarning, 'Boynunu düz tut!');
  });
}
