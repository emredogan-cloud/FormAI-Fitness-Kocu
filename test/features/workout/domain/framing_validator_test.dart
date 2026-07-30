import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/domain/framing_validator.dart';

/// Roadmap Phase 3 (R1.2 · C26) · the framing/calibration policy.
///
/// This is the code that decides whether a user's first encounter with
/// pose detection reads as "it sees me" or "it's broken", so it is
/// tested against synthesised landmark sets covering every branch.
const double _frameH = 1000;

PoseLandmark _lm(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.95,
}) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: likelihood,
  );
}

/// Builds a well-formed standing pose.
///
/// [top]/[bottom] set the vertical span (drives `coverage`),
/// [shoulderSpan] the horizontal shoulder separation (drives the
/// front/side call), and [likelihood] every landmark's confidence.
Pose _pose({
  double top = 150,
  double bottom = 850,
  double shoulderSpan = 180,
  double likelihood = 0.95,
  Set<PoseLandmarkType> omit = const {},
}) {
  final height = bottom - top;
  final shoulderY = top;
  final hipY = top + height * 0.45;
  final kneeY = top + height * 0.75;
  final ankleY = bottom;
  const centerX = 500.0;
  final half = shoulderSpan / 2;

  final all = <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.leftShoulder: _lm(
        PoseLandmarkType.leftShoulder, centerX - half, shoulderY,
        likelihood: likelihood),
    PoseLandmarkType.rightShoulder: _lm(
        PoseLandmarkType.rightShoulder, centerX + half, shoulderY,
        likelihood: likelihood),
    PoseLandmarkType.leftHip: _lm(
        PoseLandmarkType.leftHip, centerX - half * 0.7, hipY,
        likelihood: likelihood),
    PoseLandmarkType.rightHip: _lm(
        PoseLandmarkType.rightHip, centerX + half * 0.7, hipY,
        likelihood: likelihood),
    PoseLandmarkType.leftKnee: _lm(
        PoseLandmarkType.leftKnee, centerX - half * 0.6, kneeY,
        likelihood: likelihood),
    PoseLandmarkType.rightKnee: _lm(
        PoseLandmarkType.rightKnee, centerX + half * 0.6, kneeY,
        likelihood: likelihood),
    PoseLandmarkType.leftAnkle: _lm(
        PoseLandmarkType.leftAnkle, centerX - half * 0.5, ankleY,
        likelihood: likelihood),
    PoseLandmarkType.rightAnkle: _lm(
        PoseLandmarkType.rightAnkle, centerX + half * 0.5, ankleY,
        likelihood: likelihood),
  };
  for (final type in omit) {
    all.remove(type);
  }
  return Pose(landmarks: all);
}

void main() {
  group('no pose', () {
    test('a null pose reports noPose with zero confidence', () {
      final r = evaluateFraming(null, frameHeight: _frameH);
      expect(r.issue, FramingIssue.noPose);
      expect(r.confidence, 0);
      expect(r.isReady, isFalse);
    });

    test('an empty landmark map reports noPose', () {
      final r = evaluateFraming(
        Pose(landmarks: const {}),
        frameHeight: _frameH,
      );
      expect(r.issue, FramingIssue.noPose);
    });

    test(
        'a zero frame height degrades to noPose rather than dividing '
        'by zero', () {
      final r = evaluateFraming(_pose(), frameHeight: 0);
      expect(r.issue, FramingIssue.noPose);
    });
  });

  group('partial visibility', () {
    test('a missing required landmark reports partiallyVisible', () {
      final r = evaluateFraming(
        _pose(omit: {PoseLandmarkType.leftAnkle}),
        frameHeight: _frameH,
      );
      expect(r.issue, FramingIssue.partiallyVisible);
    });

    test(
        'low likelihood reports partiallyVisible even with every '
        'landmark present', () {
      final r = evaluateFraming(
        _pose(likelihood: 0.3),
        frameHeight: _frameH,
      );
      expect(r.issue, FramingIssue.partiallyVisible);
      expect(r.confidence, closeTo(0.3, 0.001));
    });

    test('confidence just above the floor passes the confidence gate', () {
      final r = evaluateFraming(
        _pose(likelihood: kMinConfidence + 0.01),
        frameHeight: _frameH,
      );
      expect(r.issue, isNot(FramingIssue.partiallyVisible));
    });
  });

  group('distance', () {
    test('a small body in frame reports tooFar', () {
      // 200/1000 = 0.20 coverage, well under the 0.45 floor.
      final r = evaluateFraming(
        _pose(top: 400, bottom: 600),
        frameHeight: _frameH,
      );
      expect(r.issue, FramingIssue.tooFar);
      expect(r.coverage, closeTo(0.2, 0.001));
    });

    test('a body filling the frame reports tooClose', () {
      final r = evaluateFraming(
        _pose(top: 5, bottom: 995),
        frameHeight: _frameH,
      );
      expect(r.issue, FramingIssue.tooClose);
    });

    test('a body inside the window is ready', () {
      final r = evaluateFraming(
        _pose(top: 150, bottom: 850),
        frameHeight: _frameH,
      );
      expect(r.issue, FramingIssue.none);
      expect(r.isReady, isTrue);
      expect(r.coverage, closeTo(0.7, 0.001));
    });

    test(
        'the acceptance window is wide enough to be findable — both '
        'ends of it pass', () {
      for (final coverage in [kMinCoverage + 0.02, kMaxCoverage - 0.02]) {
        final span = coverage * _frameH;
        final r = evaluateFraming(
          _pose(top: 20, bottom: 20 + span),
          frameHeight: _frameH,
        );
        expect(r.isReady, isTrue, reason: 'coverage $coverage');
      }
    });
  });

  group('view detection', () {
    test('a wide shoulder span reads as front', () {
      expect(detectView(_pose(shoulderSpan: 180)), RequiredView.front);
    });

    test('a collapsed shoulder span reads as side', () {
      // torso height = 700*0.45 = 315; ratio 20/315 = 0.063 < 0.16.
      expect(detectView(_pose(shoulderSpan: 20)), RequiredView.side);
    });

    test('missing torso landmarks make the call indeterminate', () {
      expect(
        detectView(_pose(omit: {PoseLandmarkType.leftHip})),
        isNull,
      );
    });

    test('a side-on user is flagged when a front view is required', () {
      final r = evaluateFraming(
        _pose(shoulderSpan: 20),
        frameHeight: _frameH,
        requiredView: RequiredView.front,
      );
      expect(r.issue, FramingIssue.wrongOrientation);
    });

    test('a front-on user is flagged when a side view is required', () {
      final r = evaluateFraming(
        _pose(shoulderSpan: 180),
        frameHeight: _frameH,
        requiredView: RequiredView.side,
      );
      expect(r.issue, FramingIssue.wrongOrientation);
    });

    test('the correct orientation passes', () {
      final r = evaluateFraming(
        _pose(shoulderSpan: 180),
        frameHeight: _frameH,
        requiredView: RequiredView.front,
      );
      expect(r.isReady, isTrue);
    });

    test('RequiredView.any never reports wrongOrientation', () {
      for (final span in [20.0, 180.0]) {
        final r = evaluateFraming(
          _pose(shoulderSpan: span),
          frameHeight: _frameH,
        );
        expect(r.issue, isNot(FramingIssue.wrongOrientation));
      }
    });
  });

  group('hints', () {
    test(
        'every issue has non-empty guidance — a state with no copy '
        'would leave the user stuck', () {
      for (final issue in FramingIssue.values) {
        final r = FramingResult(issue: issue, confidence: 0, coverage: 0);
        expect(r.hint.trim(), isNotEmpty, reason: issue.name);
      }
    });

    test('guidance instructs the setup rather than judging the user', () {
      // "biraz geri git" (move back a bit), not "you are too close".
      final tooClose = const FramingResult(
        issue: FramingIssue.tooClose,
        confidence: 1,
        coverage: 1,
      );
      expect(tooClose.hint, contains('geri git'));
    });
  });

  group('FramingStabilizer', () {
    test('a single good frame is not enough — ML Kit flickers', () {
      final s = FramingStabilizer(requiredStreak: 5);
      const good = FramingResult(
        issue: FramingIssue.none,
        confidence: 1,
        coverage: 0.7,
      );
      expect(s.accept(good), isFalse);
      expect(s.accept(good), isFalse);
    });

    test('a full streak confirms', () {
      final s = FramingStabilizer(requiredStreak: 3);
      const good = FramingResult(
        issue: FramingIssue.none,
        confidence: 1,
        coverage: 0.7,
      );
      expect(s.accept(good), isFalse);
      expect(s.accept(good), isFalse);
      expect(s.accept(good), isTrue);
    });

    test('one bad frame resets the streak', () {
      final s = FramingStabilizer(requiredStreak: 3);
      const good = FramingResult(
        issue: FramingIssue.none,
        confidence: 1,
        coverage: 0.7,
      );
      const bad = FramingResult(
        issue: FramingIssue.tooFar,
        confidence: 1,
        coverage: 0.2,
      );
      s.accept(good);
      s.accept(good);
      s.accept(bad);
      expect(s.progress, 0);
      expect(s.accept(good), isFalse);
    });

    test('progress climbs monotonically and clamps at 1', () {
      final s = FramingStabilizer(requiredStreak: 4);
      const good = FramingResult(
        issue: FramingIssue.none,
        confidence: 1,
        coverage: 0.7,
      );
      final seen = <double>[];
      for (var i = 0; i < 6; i++) {
        s.accept(good);
        seen.add(s.progress);
      }
      expect(seen.first, closeTo(0.25, 0.001));
      expect(seen.last, 1.0);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });

    test('reset clears the streak', () {
      final s = FramingStabilizer(requiredStreak: 2);
      const good = FramingResult(
        issue: FramingIssue.none,
        confidence: 1,
        coverage: 0.7,
      );
      s.accept(good);
      s.reset();
      expect(s.progress, 0);
      expect(s.accept(good), isFalse);
    });
  });
}
