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
import '../services/analyzer_factory.dart';
import '../services/crunch_analyzer.dart';
import '../services/pose_analyzer.dart';
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
  PoseAnalyzer _analyzer = CrunchAnalyzer();
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
  bool _wasPreparing = false;
  String? _formWarning;
  CrunchState _state = CrunchState.unknown;

  Timer? _workoutTimer;
  int _secondsRemaining = 0;
  bool _isPaused = false;

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
    if (_isBusy || _isPaused) return;
    // Skip pose work entirely while resting OR during the HAZIRLAN! prep
    // window so we don't count phantom reps before the user is ready and
    // don't trigger form-warning TTS while recovering / setting up.
    final session = ref.read(workoutSessionProvider).value;
    if ((session?.isResting ?? false) || (session?.isPreparing ?? false)) {
      return;
    }
    _isBusy = true;
    _processImage(image).whenComplete(() => _isBusy = false);
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _workoutTimer?.cancel();
      _workoutTimer = null;
      return;
    }
    final exercise = ref.read(workoutSessionProvider).value?.activeExercise;
    if (exercise?.type == ExerciseType.timeBased && _secondsRemaining > 0) {
      _resumeWorkoutTimer();
    }
  }

  void _resumeWorkoutTimer() {
    _workoutTimer?.cancel();
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

        // Mid-rep coaching cue (e.g. Burpee step-2 "Şimdi aşağı in…").
        // Analyzers throttle this internally so we just speak whenever it
        // shows up. Won't fight `formWarning` since the analyzer that emits
        // a cue doesn't also emit a warning on the same frame.
        final cue = result.contextualCue;
        if (cue != null) {
          _audio.speak(cue);
        }

        if (result.repJustCompleted) {
          final notifier = ref.read(workoutSessionProvider.notifier);
          notifier.setCurrentReps(result.reps);
          final target = ref
              .read(workoutSessionProvider)
              .value
              ?.activeExercise
              ?.targetReps;

          // Milestone + pacing voice coach. Priority: 2-left > halfway >
          // analyzer pacing. AudioFeedback's own 3s per-phrase dedupe and
          // the analyzer's 7s pacing throttle prevent overlap.
          final reps = result.reps;
          if (target != null && target > 1 && reps == target - 2) {
            _audio.speak('Son iki tekrar, sık dişini!');
          } else if (target != null &&
              target >= 4 &&
              reps == (target / 2).floor()) {
            _audio.speak('Yarıladın! Aynen böyle devam et.');
          } else if (result.pacingFeedback != null) {
            _audio.speak(result.pacingFeedback!);
          }

          if (target != null && reps >= target) {
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
    if (_isPaused) return;
    _resumeWorkoutTimer();
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
      final prevSession = previous?.value;
      final exercise = session.activeExercise;
      final id = exercise?.id;
      final set = session.currentSet;
      final resting = session.isResting;
      final preparing = session.isPreparing;
      final justFinishedRest = _wasResting && !resting;
      final justStartedRest = !_wasResting && resting;
      final justStartedPrep = !_wasPreparing && preparing;
      final justFinishedPrep = _wasPreparing && !preparing;
      final exerciseChanged = id != _activeExerciseId;
      final setChanged = set != _activeSet;
      final sessionJustCompleted = (prevSession?.isSessionComplete == false) &&
          session.isSessionComplete;

      _activeExerciseId = id;
      _activeSet = set;
      _wasResting = resting;
      _wasPreparing = preparing;

      // Voice coach lifecycle announcements. Priority:
      //   session complete > rest entry > prep entry.
      // The prep cue replaces the old "exercise start" cue because every
      // exercise is now preceded by a HAZIRLAN! countdown.
      if (sessionJustCompleted) {
        _audio.speak('Antrenman tamamlandı! Harika bir iş çıkardın.');
      } else if (justStartedRest && exercise != null) {
        _audio.speak(
          'Harika! Şimdi ${exercise.restDurationInSeconds} saniye dinlenme.',
        );
      } else if (justStartedPrep && exercise != null) {
        // Every shipped exercise has a non-empty `description` (Phase 26).
        // `'Başlayın!'` is a last-resort fallback for any future Exercise
        // instance that forgets to populate it.
        final desc = exercise.description.isNotEmpty
            ? exercise.description
            : 'Başlayın!';
        _audio.speak('Sıradaki hareket: ${exercise.name}. $desc');
      }

      // Always swap analyzer the moment the exercise id flips, even while
      // resting/preparing — that way it's primed and ready when the user
      // gets cleared to start.
      if (exerciseChanged) {
        _analyzer = exercise == null ? CrunchAnalyzer() : analyzerFor(exercise);
      }

      // Pause the per-exercise countdown during rest AND prep so the
      // user doesn't burn into a time-based set before they're ready.
      if (resting || preparing) {
        _workoutTimer?.cancel();
        _workoutTimer = null;
        if (resting && _secondsRemaining != 0) {
          setState(() => _secondsRemaining = 0);
        }
        return;
      }

      // Active workout ground state.
      if (exerciseChanged ||
          justFinishedPrep ||
          justFinishedRest ||
          setChanged) {
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

    if (session.isPreparing && session.activeExercise != null) {
      return _PreparationOverlay(
        exercise: session.activeExercise!,
        secondsRemaining: session.prepSecondsRemaining,
        onExit: () => _exit(context),
      );
    }

    final exercise = session.activeExercise;
    final totalExercises = session.activeDay?.exercises.length ?? 0;
    final exerciseProgress = totalExercises == 0
        ? 0.0
        : ((session.activeExerciseIndex + 1) / totalExercises).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              flex: 75,
              child: _buildCameraSection(
                controller: controller,
                exercise: exercise,
                exerciseProgress: exerciseProgress,
                exerciseIndex: session.activeExerciseIndex,
                totalExercises: totalExercises,
              ),
            ),
            Expanded(
              flex: 25,
              child: _buildControlPanel(session, exercise),
            ),
          ],
        ),
        if (session.isSessionComplete) _buildDayCompleteOverlay(session),
      ],
    );
  }

  Widget _buildCameraSection({
    required CameraController controller,
    required Exercise? exercise,
    required double exerciseProgress,
    required int exerciseIndex,
    required int totalExercises,
  }) {
    final camera = _camera!;
    final imageSize = _imageSize;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Stack(
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
            top: 0,
            left: 0,
            right: 0,
            child: _ExerciseProgressBar(
              progress: exerciseProgress,
              currentIndex: exerciseIndex,
              total: totalExercises,
            ),
          ),
          Positioned(
            top: 18,
            left: 16,
            child: _BackButton(onPressed: () => _exit(context)),
          ),
          if (exercise != null)
            Positioned(
              top: 18,
              right: 16,
              child: _PipPanel(exercise: exercise),
            ),
          // Bottom-stack: form warning above the live tactical tip pill
          // so they coexist without overlapping. Tip pill hides while the
          // user has explicitly paused.
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_formWarning != null) ...[
                  _FormWarning(message: _formWarning!),
                  const SizedBox(height: 8),
                ],
                if (!_isPaused &&
                    exercise != null &&
                    exercise.shortTip.isNotEmpty)
                  _LiveTipPill(tip: exercise.shortTip),
              ],
            ),
          ),
          if (_isPaused)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: _PausedBadge(),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(
    WorkoutSessionState session,
    Exercise? exercise,
  ) {
    final isTimeBased = exercise?.type == ExerciseType.timeBased;
    final reps = session.currentReps;
    final target = exercise?.targetReps;

    final metric = isTimeBased
        ? _formatMmSs(_secondsRemaining)
        : (target == null ? 'x $reps' : 'x $reps / $target');

    return _ControlPanel(
      currentSet: session.currentSet,
      totalSets: exercise?.sets ?? 0,
      metric: metric,
      exerciseName: exercise?.name ?? '—',
      detectorState: _state,
      isPaused: _isPaused,
      onPrev: _onPrev,
      onTogglePlay: exercise == null ? null : _togglePause,
      onNext: exercise == null ? null : _onNext,
    );
  }

  String _formatMmSs(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _onPrev() {
    // Provider doesn't expose backwards navigation yet — surface intent via
    // a transient snackbar so the control feels responsive.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Önceki egzersize geçiş yakında'),
          backgroundColor: Color(0xFF0A3A50),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1400),
        ),
      );
  }

  Future<void> _onNext() async {
    if (_isPaused) {
      setState(() => _isPaused = false);
    }
    await ref.read(workoutSessionProvider.notifier).completeCurrentExercise();
  }

  void _exit(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
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

class _PipPanel extends StatelessWidget {
  const _PipPanel({required this.exercise});

  static const Color _neon = Color(0xFF00F0FF);
  static const double _width = 140;
  static const double _height = 180;

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neon, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 160,
                height: 200,
                child: ExerciseGuidePlayer(
                  key: ValueKey('pip-${exercise.id}'),
                  assetPath: exercise.videoAsset,
                  exerciseName: exercise.name,
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _neon.withValues(alpha: 0.6),
                    width: 0.6,
                  ),
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
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Text(
                  exercise.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseProgressBar extends StatelessWidget {
  const _ExerciseProgressBar({
    required this.progress,
    required this.currentIndex,
    required this.total,
  });

  static const Color _neon = Color(0xFF00F0FF);

  final double progress;
  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 4,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(0),
              topRight: Radius.circular(0),
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation(_neon),
            ),
          ),
        ),
        if (total > 0)
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _neon.withValues(alpha: 0.5),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  'EGZERSİZ ${currentIndex + 1} / $total',
                  style: const TextStyle(
                    color: _neon,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FormWarning extends StatelessWidget {
  const _FormWarning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparationOverlay extends StatelessWidget {
  const _PreparationOverlay({
    required this.exercise,
    required this.secondsRemaining,
    required this.onExit,
  });

  static const Color _neon = Color(0xFF00F0FF);

  final Exercise exercise;
  final int secondsRemaining;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final countdownText = secondsRemaining > 0 ? '$secondsRemaining' : 'BAŞLA';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF00111A), Colors.black],
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _neon.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _neon.withValues(alpha: 0.65),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'HAZIRLAN',
                      style: TextStyle(
                        color: _neon,
                        fontSize: 12,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    exercise.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      shadows: [Shadow(blurRadius: 18, color: _neon)],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    exercise.description.isNotEmpty
                        ? exercise.description
                        : 'Pozisyonunu al ve hazırlan.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    countdownText,
                    style: TextStyle(
                      color: secondsRemaining > 0
                          ? _neon
                          : const Color(0xFF39FF14),
                      fontSize: secondsRemaining > 0 ? 140 : 80,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          blurRadius: 32,
                          color: secondsRemaining > 0
                              ? _neon
                              : const Color(0xFF39FF14),
                        ),
                        Shadow(
                          blurRadius: 64,
                          color: secondsRemaining > 0
                              ? _neon
                              : const Color(0xFF39FF14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTipPill extends StatelessWidget {
  const _LiveTipPill({required this.tip});
  static const Color _neon = Color(0xFF00F0FF);

  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _neon.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.25),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb_outline, color: _neon, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tip,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PausedBadge extends StatelessWidget {
  static const Color _neon = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _neon.withValues(alpha: 0.6), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled, color: _neon, size: 18),
            SizedBox(width: 8),
            Text(
              'DURAKLATILDI',
              style: TextStyle(
                color: _neon,
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.currentSet,
    required this.totalSets,
    required this.metric,
    required this.exerciseName,
    required this.detectorState,
    required this.isPaused,
    required this.onPrev,
    required this.onTogglePlay,
    required this.onNext,
  });

  static const Color _neon = Color(0xFF00F0FF);
  static const Color _panel = Color(0xFF101010);

  final int currentSet;
  final int totalSets;
  final String metric;
  final String exerciseName;
  final CrunchState detectorState;
  final bool isPaused;
  final VoidCallback onPrev;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        children: [
          _SetIndicator(
            currentSet: currentSet,
            totalSets: totalSets,
            detectorLabel: detectorState.name.toUpperCase(),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              metric,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 1,
                shadows: [Shadow(blurRadius: 14, color: _neon)],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            exerciseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ControlIconButton(
                icon: Icons.skip_previous_rounded,
                onTap: onPrev,
              ),
              _CenterPlayButton(
                isPaused: isPaused,
                onTap: onTogglePlay,
              ),
              _ControlIconButton(
                icon: Icons.skip_next_rounded,
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetIndicator extends StatelessWidget {
  const _SetIndicator({
    required this.currentSet,
    required this.totalSets,
    required this.detectorLabel,
  });

  static const Color _neon = Color(0xFF00F0FF);

  final int currentSet;
  final int totalSets;
  final String detectorLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _neon.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _neon.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Text(
            totalSets > 0 ? 'SET $currentSet / $totalSets' : 'SET —',
            style: const TextStyle(
              color: _neon,
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          detectorLabel,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white24, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  const _CenterPlayButton({required this.isPaused, required this.onTap});

  static const Color _neon = Color(0xFF00F0FF);

  final bool isPaused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: _neon,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 58,
            height: 58,
            child: Icon(
              isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.black,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
