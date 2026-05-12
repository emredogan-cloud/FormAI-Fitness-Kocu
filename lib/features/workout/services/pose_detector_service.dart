import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectorService {
  PoseDetectorService()
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
        );

  final PoseDetector _poseDetector;
  bool _isClosed = false;

  Future<List<Pose>> detectPose(InputImage image) {
    if (_isClosed) {
      throw StateError('PoseDetectorService has been disposed.');
    }
    return _poseDetector.processImage(image);
  }

  Future<void> dispose() async {
    if (_isClosed) return;
    _isClosed = true;
    await _poseDetector.close();
  }

  /// Phase 138 · H-4 · runtime probe for the device's ML Kit pose
  /// detection availability. Constructs a fresh detector + immediately
  /// closes it; any exception (e.g. ML Kit native libraries missing,
  /// Google Play Services unavailable on a fork ROM, or the underlying
  /// MediaPipe runtime failing to load) is caught and the method
  /// returns `false`.
  ///
  /// We don't run `processImage` here because doing so requires a
  /// real CameraImage / file path, which the bootstrap flow doesn't
  /// have yet. The construct-and-close cycle still exercises the
  /// native init path (the `PoseDetector` constructor lazily registers
  /// the platform channel; `close` round-trips through the native
  /// dispose); the cases we want to catch (no GMS, no MediaPipe)
  /// throw on one of those two boundaries.
  static Future<bool> isAvailable() async {
    PoseDetector? detector;
    try {
      detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.single),
      );
      // The `close` call is the round-trip that exercises the native
      // bridge. If the native side never loaded, `close` throws here.
      await detector.close();
      return true;
    } catch (_) {
      // Best-effort cleanup if construction succeeded but close did
      // not. Swallow any secondary throw — we're already in the
      // unavailable branch.
      try {
        await detector?.close();
      } catch (_) {}
      return false;
    }
  }
}
