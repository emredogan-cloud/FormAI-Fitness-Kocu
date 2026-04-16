import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/audio_feedback.dart';
import '../models/exercise_model.dart';
import '../providers/workout_provider.dart';
import '../services/crunch_analyzer.dart';
import '../services/pose_detector_service.dart';
import 'pose_painter.dart';
import 'widgets/exercise_guide_player.dart';

class WorkoutCameraScreen extends ConsumerStatefulWidget {
  const WorkoutCameraScreen({super.key});

  @override
  ConsumerState<WorkoutCameraScreen> createState() =>
      _WorkoutCameraScreenState();
}

class _WorkoutCameraScreenState extends ConsumerState<WorkoutCameraScreen>
    with WidgetsBindingObserver {
  final PoseDetectorService _poseService = PoseDetectorService();
  final CrunchAnalyzer _analyzer = CrunchAnalyzer();
  final AudioFeedback _audio = AudioFeedback();

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static const Color _neon = Color(0xFF00F0FF);

  CameraController? _controller;
  CameraDescription? _camera;
  List<Pose> _poses = const [];
  Size? _imageSize;
  bool _isBusy = false;
  String? _error;

  String? _activeExerciseId;
  String? _formWarning;
  CrunchState _state = CrunchState.unknown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.init();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(
          () => _error = 'Camera permission is required to analyze your form.');
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

      CrunchResult? result;
      if (poses.isNotEmpty) {
        result = _analyzer.analyze(poses.first);

        final warning = result.formWarning;
        if (warning != null) {
          _audio.speak(warning);
        }

        if (result.repJustCompleted) {
          final notifier = ref.read(workoutSessionProvider.notifier);
          notifier.setCurrentReps(result.reps);
          final target = ref
              .read(workoutSessionProvider)
              .value
              ?.activeExercise
              ?.targetReps;
          if (target != null && result.reps >= target) {
            await notifier.completeCurrentExercise();
            _analyzer.reset();
          }
        }
      }

      setState(() {
        _poses = poses;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        if (result != null) {
          _state = result.state;
          _formWarning = result.formWarning;
        } else {
          _formWarning = null;
        }
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
    if (camera == null || controller == null) {
      return InputImageRotation.rotation0deg;
    }
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }
    final deviceRotation =
        _orientations[controller.value.deviceOrientation] ?? 0;
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
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reset the analyzer whenever the active exercise changes underneath us.
    ref.listen<AsyncValue<WorkoutSessionState>>(workoutSessionProvider,
        (previous, next) {
      final id = next.value?.activeExercise?.id;
      if (id != _activeExerciseId) {
        _activeExerciseId = id;
        _analyzer.reset();
      }
    });

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
        child: CircularProgressIndicator(color: _neon),
      );
    }

    final sessionAsync = ref.watch(workoutSessionProvider);

    return sessionAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _neon)),
      error: (err, _) => Center(
        child: Text('Workout load failed: $err',
            style: const TextStyle(color: Colors.white)),
      ),
      data: (session) => _buildSession(controller, session),
    );
  }

  Widget _buildSession(
      CameraController controller, WorkoutSessionState session) {
    final camera = _camera!;
    final imageSize = _imageSize;
    final exercise = session.activeExercise;
    final target = exercise?.targetReps;
    final completedReps = session.currentReps;

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
        _buildTopBar(session),
        if (exercise != null) _buildGuidePlayer(exercise),
        _buildRepCounter(completedReps, target, exercise),
        if (_formWarning != null) _buildFormWarning(_formWarning!),
        if (session.isSessionComplete) _buildDayCompleteOverlay(session),
      ],
    );
  }

  Widget _buildTopBar(WorkoutSessionState session) {
    final day = session.activeDay;
    final exercise = session.activeExercise;
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          _BackButton(onPressed: () => _exit(context)),
          const SizedBox(width: 8),
          _pill(
            day == null ? 'No day selected' : 'Day ${day.dayNumber}',
            icon: Icons.calendar_today,
          ),
          const SizedBox(width: 8),
          if (exercise != null)
            Flexible(
              child: _pill(exercise.name, icon: Icons.fitness_center),
            ),
          const Spacer(),
          _pill(
            _poses.isEmpty ? 'Searching…' : _state.name.toUpperCase(),
          ),
        ],
      ),
    );
  }

  void _exit(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Widget _pill(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neon, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _neon),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              color: _neon,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidePlayer(Exercise exercise) {
    return Positioned(
      top: 60,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _neon, width: 0.8),
            ),
            child: const Text(
              'ÖRNEK',
              style: TextStyle(
                color: _neon,
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 130,
            height: 95,
            child: ExerciseGuidePlayer(
              key: ValueKey('guide-${exercise.id}'),
              assetPath: exercise.videoAsset,
              exerciseName: exercise.name,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepCounter(int completed, int? target, Exercise? exercise) {
    final showTarget = target != null;
    final display = showTarget ? '$completed / $target' : '$completed';
    final subtitle = showTarget
        ? 'REPS · ${exercise?.name.toUpperCase() ?? ''}'
        : exercise?.name.toUpperCase() ?? 'REPS';
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            display,
            style: const TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w900,
              color: _neon,
              height: 1.0,
              shadows: [
                Shadow(blurRadius: 30, color: _neon),
                Shadow(blurRadius: 60, color: _neon),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              letterSpacing: 5,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormWarning(String message) {
    return Positioned(
      bottom: 250,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCompleteOverlay(WorkoutSessionState session) {
    final day = session.activeDay;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.military_tech, size: 96, color: _neon),
              const SizedBox(height: 16),
              Text(
                day == null ? 'Program Tamam!' : 'Gün ${day.dayNumber} Tamam!',
                style: const TextStyle(
                  color: _neon,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [Shadow(blurRadius: 30, color: _neon)],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Harika iş çıkardın, yarın görüşürüz.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  ref
                      .read(workoutSessionProvider.notifier)
                      .acknowledgeSessionComplete();
                  _exit(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: const Text('Tamam',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xFF00F0FF), width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF00F0FF),
            size: 16,
          ),
        ),
      ),
    );
  }
}
