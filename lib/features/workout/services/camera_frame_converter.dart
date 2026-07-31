import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Roadmap Phase 3 · shared `CameraImage` → `InputImage` conversion.
///
/// Extracted from `workout_camera_screen.dart` when the Phase 3 camera
/// tutorial needed the identical logic. Copying ~35 lines of rotation
/// compensation and format guards into a second screen would have meant
/// two places to get sensor orientation wrong — and getting it wrong is
/// invisible in code review but produces a pose skeleton rotated 90°
/// on exactly the devices you don't own.
///
/// Behaviour is byte-identical to the original; only the location
/// changed.
class CameraFrameConverter {
  const CameraFrameConverter._();

  /// Android device-orientation → degrees. ML Kit needs the rotation
  /// *relative to the sensor*, which differs per lens direction.
  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Converts a streamed [image] into an ML Kit [InputImage].
  ///
  /// Returns `null` — never throws — when the frame can't be described
  /// (unsupported format, unknown device orientation, empty planes). A
  /// null here means "skip this frame", which is always safe: the next
  /// one arrives in ~33ms.
  static InputImage? toInputImage(
    CameraImage image, {
    required CameraDescription camera,
    required CameraController controller,
  }) {
    final rotation = rotationFor(camera: camera, controller: controller);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    // The controller requests nv21 on Android and bgra8888 on iOS; any
    // other format means the platform ignored the request, and feeding
    // it to ML Kit would produce garbage landmarks rather than an error.
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// The rotation ML Kit should apply, or `null` when it can't be
  /// determined. Front lenses add the device rotation; back lenses
  /// subtract it.
  static InputImageRotation? rotationFor({
    required CameraDescription camera,
    required CameraController controller,
  }) {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (Platform.isAndroid) {
      final deviceRotation = _orientations[controller.value.deviceOrientation];
      if (deviceRotation == null) return null;
      final compensated = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + deviceRotation) % 360
          : (sensorOrientation - deviceRotation + 360) % 360;
      return InputImageRotationValue.fromRawValue(compensated);
    }
    return null;
  }

  /// The analysed frame's size in landmark coordinate space.
  ///
  /// ML Kit reports landmarks in the *rotated* frame, so a 90°/270°
  /// rotation swaps width and height. Anything that maps a landmark back
  /// onto a canvas — coverage maths, the tutorial's labelled overlay —
  /// must divide by these dimensions and not the raw sensor ones, or
  /// every portrait read is wrong by the aspect ratio.
  static Size analysedSize(CameraImage image, InputImageRotation rotation) {
    final swapped = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    return swapped
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
  }

  /// The height of the analysed frame in landmark coordinate space.
  /// `evaluateFraming` divides body height by this to compute coverage.
  static double analysedHeight(
          CameraImage image, InputImageRotation rotation) =>
      analysedSize(image, rotation).height;
}
