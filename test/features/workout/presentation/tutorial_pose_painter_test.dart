import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/presentation/pose_painter.dart';

/// Roadmap Phase 3 · the labelled practice-rep painter.
///
/// The painter's job is to name, on the user's own body, the joints the
/// analyzer is reading. Two things must hold: it must never be the thing
/// that crashes a live camera screen (it runs ~15×/second over landmark
/// data the app does not control), and it must not put a confident label
/// on a landmark the detector is unsure about.
PoseLandmark _lm(PoseLandmarkType type, double x, double y,
        {double likelihood = 0.9}) =>
    PoseLandmark(
      type: type,
      x: x,
      y: y,
      z: 0,
      likelihood: likelihood,
    );

Pose _pose(Map<PoseLandmarkType, PoseLandmark> landmarks) =>
    Pose(landmarks: landmarks);

Pose _fullBody({double likelihood = 0.9}) {
  const types = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
    PoseLandmarkType.nose,
  ];
  var y = 40.0;
  return _pose({
    for (final t in types)
      t: _lm(t, 120 + (types.indexOf(t) % 2) * 40, y += 40,
          likelihood: likelihood),
  });
}

TutorialPosePainter _painter(
  Pose pose, {
  Map<PoseLandmarkType, String> tracked = const {
    PoseLandmarkType.leftKnee: 'Diz',
  },
  Size imageSize = const Size(480, 640),
  TextDirection textDirection = TextDirection.ltr,
}) =>
    TutorialPosePainter(
      pose: pose,
      imageSize: imageSize,
      rotation: InputImageRotation.rotation0deg,
      cameraLensDirection: CameraLensDirection.front,
      trackedJoints: tracked,
      textDirection: textDirection,
    );

/// Rasterises the painter so `paint()` genuinely executes — a painter
/// that is only constructed proves nothing about the code that runs on
/// the device.
void _paint(CustomPainter painter, {Size size = const Size(390, 520)}) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void main() {
  group('paint never throws on real-world landmark data', () {
    test('a full-body pose with labels', () {
      _paint(_painter(_fullBody()));
    });

    test('a pose missing every tracked joint', () {
      // ML Kit routinely drops occluded joints. Labelling what is not
      // there must be a no-op, not a crash on the flagship screen.
      _paint(_painter(_pose({
        PoseLandmarkType.nose: _lm(PoseLandmarkType.nose, 100, 100),
      })));
    });

    test('an entirely empty pose', () {
      _paint(_painter(_pose(const {})));
    });

    test('landmarks far outside the frame', () {
      // Coordinates outside the image happen when the user steps out of
      // shot mid-rep; the label clamps rather than drawing off-canvas.
      _paint(_painter(_pose({
        PoseLandmarkType.leftKnee: _lm(PoseLandmarkType.leftKnee, -900, 4000),
      })));
    });

    test('a landmark exactly on the right edge flips the label inward', () {
      _paint(_painter(_pose({
        PoseLandmarkType.leftKnee: _lm(PoseLandmarkType.leftKnee, 479, 320),
      })));
    });

    test('a zero-size canvas degrades instead of dividing by zero', () {
      _paint(_painter(_fullBody()), size: Size.zero);
    });

    test('a long label on a narrow canvas still lays out', () {
      _paint(
        _painter(
          _fullBody(),
          tracked: const {PoseLandmarkType.leftAnkle: 'Ayak bileği'},
        ),
        size: const Size(120, 300),
      );
    });

    test('low-confidence landmarks are skipped rather than labelled', () {
      // Below the floor the label is suppressed: attaching the app's
      // confidence to a guess is how "it sees me" turns into "it's
      // wrong about me".
      _paint(_painter(_fullBody(likelihood: 0.05)));
    });

    test('an empty tracked-joint map paints the plain skeleton', () {
      _paint(_painter(_fullBody(), tracked: const {}));
    });
  });

  group('shouldRepaint', () {
    test('repaints when the tracked joint set changes', () {
      final a = _painter(_fullBody());
      final b = _painter(
        a.pose,
        tracked: const {PoseLandmarkType.leftHip: 'Kalça'},
      );
      expect(b.shouldRepaint(a), isTrue);
    });

    test('repaints when the same key carries different copy', () {
      final a = _painter(_fullBody());
      final b = _painter(a.pose, tracked: const {
        PoseLandmarkType.leftKnee: 'Diz eklemi',
      });
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint for an identical pose and identical labels', () {
      final pose = _fullBody();
      final a = _painter(pose);
      final b = _painter(pose);
      expect(b.shouldRepaint(a), isFalse);
    });

    test('repaints when the pose moved', () {
      final a = _painter(_fullBody());
      final b = _painter(_pose({
        ...a.pose.landmarks,
        PoseLandmarkType.nose: _lm(PoseLandmarkType.nose, 999, 999),
      }));
      expect(b.shouldRepaint(a), isTrue);
    });

    test(
        'repaints when handed a plain PosePainter — the label layer '
        'would otherwise be stale', () {
      final pose = _fullBody();
      final plain = PosePainter(
        pose: pose,
        imageSize: const Size(480, 640),
        rotation: InputImageRotation.rotation0deg,
        cameraLensDirection: CameraLensDirection.front,
      );
      expect(_painter(pose).shouldRepaint(plain), isTrue);
    });

    test(
        'Roadmap Phase 8 (C13) · repaints when the reading direction '
        'changes', () {
      // The joint labels are ARB copy laid out by a TextPainter, and a
      // CustomPainter has no BuildContext — so the ambient direction is
      // handed in. It used to be hardcoded `TextDirection.ltr`, which
      // resolves Arabic and Hebrew bidi wrongly. If a refactor drops the
      // field, this is what notices.
      final pose = _fullBody();
      final ltr = _painter(pose);
      final rtl = _painter(pose, textDirection: TextDirection.rtl);
      expect(rtl.shouldRepaint(ltr), isTrue);
      expect(ltr.shouldRepaint(ltr), isFalse);
      // And both directions still rasterise without throwing.
      _paint(ltr);
      _paint(rtl);
    });
  });
}
