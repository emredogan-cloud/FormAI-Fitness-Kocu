import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/pose_detector_service.dart';
import 'pose_painter.dart';

class WorkoutCameraScreen extends StatefulWidget {
  const WorkoutCameraScreen({super.key});

  @override
  State<WorkoutCameraScreen> createState() => _WorkoutCameraScreenState();
}

class _WorkoutCameraScreenState extends State<WorkoutCameraScreen>
    with WidgetsBindingObserver {
  final PoseDetectorService _poseService = PoseDetectorService();

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _controller;
  CameraDescription? _camera;
  List<Pose> _poses = const [];
  Size? _imageSize;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() => _error = 'Camera permission is required to analyze your form.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'No cameras available on this device.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      await _startController(front);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Camera setup failed: $e');
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    _camera = camera;
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await controller.initialize();
    await controller.startImageStream(_onCameraImage);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  void _onCameraImage(CameraImage image) {
    if (_isBusy) return;
    _isBusy = true;
    _processImage(image).whenComplete(() => _isBusy = false);
  }

  Future<void> _processImage(CameraImage image) async {
    final input = _toInputImage(image);
    if (input == null) return;
    try {
      final poses = await _poseService.detectPose(input);
      if (!mounted) return;
      setState(() {
        _poses = poses;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    } catch (_) {
      // Swallow transient detection failures; keep stream running.
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final deviceRotation = _orientations[controller.value.deviceOrientation];
      if (deviceRotation == null) return null;
      final compensated = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + deviceRotation) % 360
          : (sensorOrientation - deviceRotation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensated);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
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

  InputImageRotation _currentRotation() {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return InputImageRotation.rotation0deg;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }
    final deviceRotation = _orientations[controller.value.deviceOrientation] ?? 0;
    final compensated = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(compensated) ??
        InputImageRotation.rotation0deg;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed && _camera != null) {
      _startController(_camera!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
      );
    }

    final camera = _camera!;
    final imageSize = _imageSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        if (_poses.isNotEmpty && imageSize != null)
          CustomPaint(
            painter: PosePainter(
              pose: _poses.first,
              imageSize: imageSize,
              rotation: _currentRotation(),
              cameraLensDirection: camera.lensDirection,
            ),
          ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00F0FF), width: 1),
            ),
            child: Text(
              _poses.isEmpty ? 'Searching for you…' : 'Tracking pose',
              style: const TextStyle(
                color: Color(0xFF00F0FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
