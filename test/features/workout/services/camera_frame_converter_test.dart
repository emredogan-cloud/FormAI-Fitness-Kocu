import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/services/camera_frame_converter.dart';

/// Roadmap Phase 3 · analysed-frame geometry.
///
/// ML Kit reports landmarks in the **rotated** frame. Every consumer that
/// maps a landmark back onto something — coverage maths in
/// `evaluateFraming`, the tutorial's labelled overlay — divides by these
/// dimensions. Getting the swap wrong is silent: no exception, no
/// warning, just every portrait read wrong by the aspect ratio and a
/// user told to step back when they were already framed correctly.
CameraImage _frame({int width = 480, int height = 640}) {
  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.nv21, raw: 17),
      planes: <CameraImagePlane>[
        CameraImagePlane(
          bytes: Uint8List(width * height),
          bytesPerRow: width,
        ),
      ],
      width: width,
      height: height,
    ),
  );
}

void main() {
  group('analysedSize', () {
    test('0° and 180° keep the sensor orientation', () {
      final image = _frame();
      expect(
        CameraFrameConverter.analysedSize(
            image, InputImageRotation.rotation0deg),
        const Size(480, 640),
      );
      expect(
        CameraFrameConverter.analysedSize(
            image, InputImageRotation.rotation180deg),
        const Size(480, 640),
      );
    });

    test('90° and 270° swap width and height', () {
      final image = _frame();
      expect(
        CameraFrameConverter.analysedSize(
            image, InputImageRotation.rotation90deg),
        const Size(640, 480),
      );
      expect(
        CameraFrameConverter.analysedSize(
            image, InputImageRotation.rotation270deg),
        const Size(640, 480),
      );
    });

    test('a square frame is unchanged by every rotation', () {
      final image = _frame(width: 512, height: 512);
      for (final rotation in InputImageRotation.values) {
        expect(
          CameraFrameConverter.analysedSize(image, rotation),
          const Size(512, 512),
          reason: 'rotation $rotation',
        );
      }
    });
  });

  group('analysedHeight agrees with analysedSize', () {
    test('on every rotation', () {
      // The two must never disagree: `analysedHeight` is the coverage
      // divisor and `analysedSize` is the overlay basis. A drift between
      // them puts the framing verdict and the drawn skeleton into
      // different coordinate spaces — a bug with no symptom except users
      // who cannot get calibrated.
      final image = _frame();
      for (final rotation in InputImageRotation.values) {
        expect(
          CameraFrameConverter.analysedHeight(image, rotation),
          CameraFrameConverter.analysedSize(image, rotation).height,
          reason: 'rotation $rotation',
        );
      }
    });

    test('portrait height is the long edge, landscape height the short one',
        () {
      final image = _frame();
      expect(
        CameraFrameConverter.analysedHeight(
            image, InputImageRotation.rotation0deg),
        640.0,
      );
      expect(
        CameraFrameConverter.analysedHeight(
            image, InputImageRotation.rotation90deg),
        480.0,
      );
    });

    test(
        'the swap is what keeps a correctly-framed user from being told '
        'to step back', () {
      // Magnitude of the bug this prevents: a body filling 60% of a
      // 640-tall frame reads as 80% against a 480 divisor — over
      // `kMaxCoverage`, i.e. "too close", for someone standing right.
      final image = _frame();
      const bodyHeight = 384.0;
      final correct = bodyHeight /
          CameraFrameConverter.analysedHeight(
              image, InputImageRotation.rotation0deg);
      final wrong = bodyHeight /
          CameraFrameConverter.analysedHeight(
              image, InputImageRotation.rotation90deg);
      expect(correct, closeTo(0.60, 0.001));
      expect(wrong, closeTo(0.80, 0.001));
    });
  });
}
