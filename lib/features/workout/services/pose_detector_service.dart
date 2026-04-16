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
}
