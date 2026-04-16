import 'dart:async';
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
  int? _activeSet;
  bool _wasResting = false;
  String? _formWarning;
  CrunchState _state = CrunchState.unknown;

  Timer? _workoutTimer;
  int _secondsRemaining = 0;

  Offset? _pipOffset; // null → default top-right placement.

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
    // Skip pose work entirely while resting so we don't count phantom reps
    // or trigger form-warning TTS while the user is recovering.
    final session = ref.read(workoutSessionProvider).value;
    if (session?.isResting ?? false) return;
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
    _workoutTimer?.cancel();
    _controller?.dispose();
    _poseService.dispose();
    _audio.dispose();
    super.dispose();
  }

  void _syncExerciseTimer(Exercise? exercise) {
    _workoutTimer?.cancel();
    _workoutTimer = null;
    if (exercise == null || exercise.type != ExerciseType.timeBased) {
      if (_secondsRemaining != 0) {
        setState(() => _secondsRemaining = 0);
      }
      return;
    }
    final duration = exercise.targetDurationInSeconds ?? 0;
    setState(() => _secondsRemaining = duration);
    if (duration <= 0) {
      _onTimerComplete();
      return;
    }
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _workoutTimer = null;
        setState(() => _secondsRemaining = 0);
        _onTimerComplete();
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  Future<void> _onTimerComplete() async {
    _audio.speak('Süre doldu, harika!');
    if (!mounted) return;
    await ref.read(workoutSessionProvider.notifier).completeCurrentExercise();
  }

  @override
  Widget build(BuildContext context) {
    // Reset the analyzer and re-sync the countdown whenever the active
    // exercise, set, or resting state changes.
    ref.listen<AsyncValue<WorkoutSessionState>>(workoutSessionProvider,
        (previous, next) {
      final session = next.value;
      if (session == null) return;
      final exercise = session.activeExercise;
      final id = exercise?.id;
      final set = session.currentSet;
      final resting = session.isResting;
      final justFinishedRest = _wasResting && !resting;
      final exerciseChanged = id != _activeExerciseId;
      final setChanged = set != _activeSet;

      _activeExerciseId = id;
      _activeSet = set;
      _wasResting = resting;

      if (resting) {
        _workoutTimer?.cancel();
        _workoutTimer = null;
        if (_secondsRemaining != 0) {
          setState(() => _secondsRemaining = 0);
        }
        return;
      }

      if (exerciseChanged || setChanged || justFinishedRest) {
        _analyzer.reset();
        _syncExerciseTimer(exercise);
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
    if (session.isResting) {
      return _RestOverlay(
        secondsRemaining: session.restSecondsRemaining,
        upcomingExercise: session.upcomingExercise,
        upcomingSet: session.currentSet,
        totalSets: session.upcomingExercise?.sets ?? 0,
        onSkip: () => ref.read(workoutSessionProvider.notifier).skipRest(),
        onExit: () => _exit(context),
      );
    }

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
        _buildMetricDisplay(completedReps, target, exercise),
        if (_formWarning != null) _buildFormWarning(_formWarning!),
        if (exercise != null)
          LayoutBuilder(
            builder: (context, constraints) => _PipGuide(
              exercise: exercise,
              parentSize: Size(constraints.maxWidth, constraints.maxHeight),
              offset: _pipOffset,
              onMoved: (offset) => setState(() => _pipOffset = offset),
            ),
          ),
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
            day == null ? 'No day selected' : 'Gün ${day.dayNumber}',
            icon: Icons.calendar_today,
          ),
          const SizedBox(width: 8),
          if (exercise != null)
            Flexible(
              child: _pill(exercise.name, icon: Icons.fitness_center),
            ),
          const SizedBox(width: 8),
          if (exercise != null)
            _pill(
              'Set ${session.currentSet}/${exercise.sets}',
              icon: Icons.repeat,
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

  Widget _buildMetricDisplay(int completed, int? target, Exercise? exercise) {
    if (exercise?.type == ExerciseType.timeBased) {
      return _buildCountdown(exercise!);
    }
    return _buildRepCounter(completed, target, exercise);
  }

  Widget _buildRepCounter(int completed, int? target, Exercise? exercise) {
    final showTarget = target != null;
    final display = showTarget ? '$completed / $target' : '$completed';
    final subtitle = showTarget
        ? 'REPS · ${exercise?.name.toUpperCase() ?? ''}'
        : exercise?.name.toUpperCase() ?? 'REPS';
    return _bigNeonStat(display: display, subtitle: subtitle);
  }

  Widget _buildCountdown(Exercise exercise) {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return _bigNeonStat(
      display: '$minutes:$seconds',
      subtitle: 'SÜRE · ${exercise.name.toUpperCase()}',
    );
  }

  Widget _bigNeonStat({required String display, required String subtitle}) {
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

class _RestOverlay extends StatelessWidget {
  const _RestOverlay({
    required this.secondsRemaining,
    required this.upcomingExercise,
    required this.upcomingSet,
    required this.totalSets,
    required this.onSkip,
    required this.onExit,
  });

  static const Color _neon = Color(0xFF00F0FF);

  final int secondsRemaining;
  final Exercise? upcomingExercise;
  final int upcomingSet;
  final int totalSets;
  final VoidCallback onSkip;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final minutes = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsRemaining % 60).toString().padLeft(2, '0');
    final exerciseName = upcomingExercise?.name ?? '—';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF001823), Colors.black],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 8,
            left: 8,
            child: _BackButton(onPressed: onExit),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _neon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _neon.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'DİNLENME ZAMANI',
                    style: TextStyle(
                      color: _neon,
                      fontSize: 12,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    color: _neon,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(blurRadius: 32, color: _neon),
                      Shadow(blurRadius: 64, color: _neon),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'SIRADAKİ',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalSets > 0 ? 'Set $upcomingSet / $totalSets' : '',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 40),
                _SkipButton(onTap: onSkip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});
  final VoidCallback onTap;

  static const Color _neon = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.65),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: _neon,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GEÇ',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.skip_next_rounded, color: Colors.black, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PipGuide extends StatelessWidget {
  const _PipGuide({
    required this.exercise,
    required this.parentSize,
    required this.offset,
    required this.onMoved,
  });

  static const Color _neon = Color(0xFF00F0FF);
  static const double _width = 140;
  static const double _height = 105;
  static const double _margin = 12;
  static const double _topPad = 56; // leave room below the top pill bar

  final Exercise exercise;
  final Size parentSize;
  final Offset? offset;
  final ValueChanged<Offset> onMoved;

  Offset get _resolvedOffset {
    final current = offset;
    if (current != null) return current;
    return Offset(parentSize.width - _width - _margin, _topPad);
  }

  Offset _clamp(Offset proposed) {
    final maxX = parentSize.width - _width - _margin;
    final maxY = parentSize.height - _height - _margin;
    final dx = proposed.dx.clamp(_margin, maxX < _margin ? _margin : maxX);
    final dy = proposed.dy.clamp(_margin, maxY < _margin ? _margin : maxY);
    return Offset(dx.toDouble(), dy.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final pos = _clamp(_resolvedOffset);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          onMoved(_clamp(pos + details.delta));
        },
        child: Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _neon, width: 1),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.45),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: ExerciseGuidePlayer(
                    key: ValueKey('guide-${exercise.id}'),
                    assetPath: exercise.videoAsset,
                    exerciseName: exercise.name,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _neon.withValues(alpha: 0.6),
                      width: 0.6,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drag_indicator, color: _neon, size: 11),
                      SizedBox(width: 4),
                      Text(
                        'ÖRNEK',
                        style: TextStyle(
                          color: _neon,
                          fontSize: 9,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
