import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/live_activity_service.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/audio_feedback.dart';
import '../../../core/widgets/error_card.dart';
import '../models/exercise_model.dart';
import '../providers/workout_provider.dart';
import '../services/analyzer_factory.dart';
import '../services/crunch_analyzer.dart';
import '../services/pose_analyzer.dart';
import '../services/pose_detector_service.dart';
import 'pose_painter.dart';
import 'widgets/exercise_guide_player.dart';
import 'widgets/preparation_overlay.dart';
import 'widgets/rest_overlay.dart';
import 'widgets/session_complete_overlay.dart';
import 'widgets/workout_back_button.dart';
import 'widgets/workout_control_panel.dart';

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
  // Phase 48 · single-flight gate. Prevents the camera's image stream
  // (running at 30 FPS) from queuing up multiple BlazePose inferences
  // simultaneously — when the previous frame is still being processed
  // we drop new frames on the floor. Combined with `_minFrameIntervalMs`
  // below, this keeps the pose detector below 15 FPS on mid-range
  // devices and stops the OOM/ANR storms reported in Phase 47B.
  bool _isProcessingFrame = false;
  String? _error;
  bool _permissionPermanentlyDenied = false;
  bool _wakelockOn = false;

  // Throttles the pose detector to ~15 FPS. At 30 FPS (the camera's native
  // rate) BlazePose inference thermally throttles mid-range devices within
  // ~15 minutes; halving the rate roughly halves CPU/GPU load with no
  // observable accuracy loss for rep-counting use cases.
  static const int _minFrameIntervalMs = 66;
  DateTime? _lastFrameProcessedAt;

  String? _activeExerciseId;
  int? _activeSet;
  bool _wasResting = false;
  bool _wasPreparing = false;
  String? _formWarning;
  // Phase 49 · last form-warning string we issued a haptic for. Used
  // as a single-step debounce so a sustained "diz bükülü tut" warning
  // (which can fire on every frame for several seconds) only buzzes
  // the device once per occurrence instead of vibrating continuously.
  String? _lastFormWarning;
  CrunchState _state = CrunchState.unknown;

  Timer? _workoutTimer;
  int _secondsRemaining = 0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.init();
    _enableWakelock();
    // Defer bootstrap to the first frame so the ML Kit disclosure dialog has
    // a valid Overlay to show into (dialogs from raw initState can race the
    // first build on slower devices).
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _enableWakelock() async {
    // Keeps the screen awake for the full workout so a 20-minute session
    // doesn't get cut short by an OS-level auto-lock mid-rep. The disable
    // in dispose() guarantees we don't drain battery after the user leaves.
    try {
      await WakelockPlus.enable();
      _wakelockOn = true;
    } catch (e, st) {
      AppLogger.warning(
        'WakelockPlus.enable() failed',
        category: 'workout',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  Future<void> _disableWakelock() async {
    if (!_wakelockOn) return;
    _wakelockOn = false;
    try {
      await WakelockPlus.disable();
    } catch (e, st) {
      AppLogger.warning(
        'WakelockPlus.disable() failed',
        category: 'workout',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _permissionPermanentlyDenied = false;
    });

    // On-device ML disclosure is shown BEFORE the OS permission prompt so the
    // user understands what the camera is used for (Apple/Google transparency
    // requirement; see APP_STORE_AUDIT §1.4).
    final accepted = await _showMlKitDisclosure();
    if (!accepted || !mounted) return;

    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      setState(() => _permissionPermanentlyDenied = true);
      return;
    }
    if (!status.isGranted) {
      setState(() =>
          _error = 'Kamera izni gerekli. Antrenmanı başlatmak için izin ver.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Bu cihazda kullanılabilir kamera bulunamadı.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      await _startController(front);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Kamera başlatılamadı: $e');
    }
  }

  Future<bool> _showMlKitDisclosure() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _neon.withValues(alpha: 0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: _neon),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cihazında Analiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'FormAI, formunu cihazında Google ML Kit ile analiz eder. '
          'Görüntüler kaydedilmez ve hiçbir sunucuya gönderilmez.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _neon,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            child: const Text('ANLADIM'),
          ),
        ],
      ),
    );
    return result ?? false;
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
    // Phase 48 · hard guard against unmounted-ref crashes. The camera
    // image stream keeps firing for one or two frames after the widget
    // tree starts tearing down (dispose hasn't reached `_controller`
    // yet); reading `ref` from there throws "Bad state: Using ref when
    // a widget is unmounted". Bailing out before any `ref.read` keeps
    // us safe.
    if (!mounted) return;
    if (_isProcessingFrame || _isPaused) return;

    // Phase 48 · hard skip on rest/prep states.
    //
    // The MLKit BlazePose detector is by far the heaviest call in the
    // frame pipeline (~25-50 ms inference on mid-range Androids,
    // dominant CPU + GPU thermal contributor). Bailing out *before*
    // touching `_poseService.detectPose` saves the inference compute
    // for every frame the user is recovering between sets or watching
    // the HAZIRLAN! countdown — typically 30-60 seconds per session
    // and a meaningful battery / heat win on phones held close to the
    // user's body. Also clears the stale skeleton overlay so the
    // pose painter doesn't keep redrawing yesterday's joints while
    // the user repositions for the next exercise.
    //
    // Bonus: this gate sits BEFORE the FPS throttle so a long rest
    // window doesn't consume the timestamp slot — the first frame
    // after rest ends fires immediately instead of waiting another
    // 66 ms tick.
    final session = ref.read(workoutSessionProvider).value;
    if ((session?.isResting ?? false) || (session?.isPreparing ?? false)) {
      if (_poses.isNotEmpty) {
        // Cheap setState — empty list literal means no-op for the
        // painter on subsequent frames.
        setState(() => _poses = const []);
      }
      // Phase 49 · clear the warning debounce so the next exercise
      // re-haptics on any returning warning (otherwise resuming after
      // rest with the same form fault would silently swallow the cue).
      _lastFormWarning = null;
      return;
    }

    // FPS throttle gate: bail out of every other frame at 30 FPS so the
    // BlazePose model runs at ~15 FPS. Timestamps are only advanced when
    // we actually kick off processing, so a slow inference doesn't
    // accidentally starve the next eligible frame.
    final now = DateTime.now();
    final last = _lastFrameProcessedAt;
    if (last != null &&
        now.difference(last).inMilliseconds < _minFrameIntervalMs) {
      return;
    }
    _lastFrameProcessedAt = now;

    _isProcessingFrame = true;
    // try/finally via whenComplete so a thrown inference still releases
    // the gate — otherwise the stream wedges permanently after the
    // first failure.
    _processImage(image).whenComplete(() {
      _isProcessingFrame = false;
    });
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
      // Re-check mounted *every time* we cross an `await` boundary or
      // hop into a notifier; the user can pop the camera screen during
      // any of those gaps and `ref.read` would throw.
      if (!mounted) return;

      CrunchResult? result;
      if (poses.isNotEmpty) {
        result = _analyzer.analyze(poses.first);

        final warning = result.formWarning;
        if (warning != null) {
          _audio.speak(warning);
          // Phase 49 · double light-tap when the analyzer flags broken
          // form. Distinct from the per-rep tap so the user can tell
          // "good rep" and "fix something" apart without looking at
          // the screen. Throttled by `_lastFormWarning` below so a
          // sustained warning doesn't buzz the device every frame.
          if (warning != _lastFormWarning) {
            _lastFormWarning = warning;
            unawaited(AppHaptics.warningDoubleTap());
          }
        } else {
          _lastFormWarning = null;
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
          // Phase 49 · upgraded from a per-rep light tap to a heavy
          // impact. A counted rep is the unambiguous "you did the
          // thing" signal — the user's whole reason for being on this
          // screen — so it earns the strongest haptic in the app.
          AppHaptics.heavyImpact();
          if (!mounted) return;
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
            // Phase 49 · set/exercise completion uses the milestone
            // helper (heavy impact). Distinct from the per-rep heavy
            // tap above only by timing — but in context the user
            // perceives "rep" vs "set done" because the set-done
            // thump is followed by the rest overlay's UI swap.
            AppHaptics.milestone();
            await notifier.completeCurrentExercise();
            if (!mounted) return;
            _analyzer.reset();
          }
        }
      }

      if (!mounted) return;
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
    // Phase 48 · stop the image stream BEFORE disposing the controller.
    // `controller.dispose()` will tear down the underlying texture, but
    // any frame already buffered inside the camera plugin still races
    // through `_onCameraImage` for ~1-2 frames after dispose. Stopping
    // the stream first means those buffered frames are dropped at the
    // platform layer and never enter our Dart callback.
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      unawaited(controller.stopImageStream().catchError((_) {}));
    }
    controller?.dispose();
    _poseService.dispose();
    _audio.dispose();
    // Fire-and-forget — we don't want dispose() to await, and the plugin's
    // native call is near-instant. Failing to disable here would leave the
    // device screen permanently awake after the user exits.
    unawaited(_disableWakelock());
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
    // Phase 49 · time-based exercises don't go through the rep-counting
    // path, so this is the equivalent "set done" thump. Routed through
    // `AppHaptics.milestone()` to match the rep-based completion above.
    AppHaptics.milestone();
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

      // Prep-countdown tick haptic: fire a crisp selectionClick each time
      // prepSecondsRemaining changes to a new non-zero value while we're in
      // the HAZIRLAN! window. Matches the 3 → 2 → 1 visual countdown.
      final prevPrep = prevSession?.prepSecondsRemaining ?? 0;
      final prep = session.prepSecondsRemaining;
      if (preparing && prep > 0 && prep != prevPrep) {
        AppHaptics.success();
      }

      // Phase 55 · Live Activity sync. Mirrors the same transitions
      // the voice coach reacts to. Created on first non-null exercise
      // (i.e. as soon as the session lands), updated on every set /
      // exercise / rest flip, ended on completion. We don't gate on
      // `Platform.isIOS` here — the service no-ops on Android, which
      // keeps this branch readable.
      if (exercise != null) {
        final dayNumber = session.activeDay?.dayNumber ?? 0;
        final totalExercises = session.activeDay?.exercises.length ?? 0;
        final totalSets = exercise.sets;
        final isFirstActivityFrame = prevSession?.activeExercise == null;
        Future<void> activitySync() async {
          if (sessionJustCompleted) {
            await WorkoutLiveActivityService.instance.endWorkout();
          } else if (isFirstActivityFrame) {
            await WorkoutLiveActivityService.instance.startWorkout(
              dayNumber: dayNumber,
              exerciseName: exercise.name,
              setIndex: set,
              totalSets: totalSets,
              currentExerciseIndex: session.activeExerciseIndex,
              totalExercises: totalExercises,
              elapsed: Duration.zero,
              isResting: resting,
              restSecondsRemaining: session.restSecondsRemaining,
            );
          } else if (exerciseChanged ||
              setChanged ||
              justStartedRest ||
              justFinishedRest ||
              justStartedPrep ||
              justFinishedPrep) {
            await WorkoutLiveActivityService.instance.updateWorkout(
              dayNumber: dayNumber,
              exerciseName: exercise.name,
              setIndex: set,
              totalSets: totalSets,
              currentExerciseIndex: session.activeExerciseIndex,
              totalExercises: totalExercises,
              elapsed: Duration.zero,
              isResting: resting,
              restSecondsRemaining: session.restSecondsRemaining,
            );
          }
        }

        unawaited(activitySync());
      } else if (sessionJustCompleted) {
        unawaited(WorkoutLiveActivityService.instance.endWorkout());
      }

      // Voice coach lifecycle announcements. Priority:
      //   session complete > rest entry > prep entry.
      // The prep cue replaces the old "exercise start" cue because every
      // exercise is now preceded by a HAZIRLAN! countdown.
      if (sessionJustCompleted) {
        // Phase 49 · celebratory milestone thump to pair with the
        // TTS finale.
        AppHaptics.milestone();
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
    if (_permissionPermanentlyDenied) {
      return _PermissionCard(
        icon: Icons.lock_outline,
        title: 'Kamera İzni Kapalı',
        message: 'Formunu analiz edebilmek için kamera iznine ihtiyacımız var. '
            'Ayarlara giderek FormAI için kamera iznini aç, ardından buraya '
            'geri dön.',
        primaryLabel: 'AYARLARA GİT',
        onPrimary: () async {
          await openAppSettings();
        },
        secondaryLabel: 'TEKRAR DENE',
        onSecondary: _bootstrap,
        onExit: () => _exit(context),
      );
    }
    if (_error != null) {
      return _PermissionCard(
        icon: Icons.videocam_off_outlined,
        title: 'Kamera Hazırlanamadı',
        message: _error!,
        primaryLabel: 'TEKRAR DENE',
        onPrimary: _bootstrap,
        onExit: () => _exit(context),
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
      error: (err, st) {
        AppLogger.error(
          'workoutSessionProvider error',
          err,
          stackTrace: st,
          category: 'workout',
        );
        return ErrorCard(
          message: 'Antrenman yüklenirken bir sorun oluştu.',
          onRetry: () => ref.invalidate(workoutSessionProvider),
        );
      },
      data: (session) => _buildSession(controller, session),
    );
  }

  Widget _buildSession(
      CameraController controller, WorkoutSessionState session) {
    if (session.isResting) {
      return RestOverlay(
        secondsRemaining: session.restSecondsRemaining,
        upcomingExercise: session.upcomingExercise,
        upcomingSet: session.currentSet,
        totalSets: session.upcomingExercise?.sets ?? 0,
        onSkip: () => ref.read(workoutSessionProvider.notifier).skipRest(),
        onExit: () => _exit(context),
      );
    }

    if (session.isPreparing && session.activeExercise != null) {
      return PreparationOverlay(
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
        if (session.isSessionComplete)
          SessionCompleteOverlay(
            day: session.activeDay,
            onAcknowledge: () {
              ref
                  .read(workoutSessionProvider.notifier)
                  .acknowledgeSessionComplete();
              _exit(context);
            },
          ),
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
            child: WorkoutBackButton(onPressed: () => _exit(context)),
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

    // Phase 47B: onPrev wired to the notifier's previousExercise().
    // We still pass `null` when the pointer is already at index 0 so
    // the control-panel row swaps in an invisible puck of matching
    // width and the play control stays centered.
    final canGoBack = exercise != null && session.activeExerciseIndex > 0;
    return WorkoutControlPanel(
      currentSet: session.currentSet,
      totalSets: exercise?.sets ?? 0,
      metric: metric,
      exerciseName: exercise?.name ?? '—',
      detectorState: _state,
      isPaused: _isPaused,
      onTogglePlay: exercise == null ? null : _togglePause,
      onPrev: canGoBack ? _onPrev : null,
      onNext: exercise == null ? null : _onNext,
    );
  }

  String _formatMmSs(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _onNext() async {
    if (_isPaused) {
      setState(() => _isPaused = false);
    }
    await ref.read(workoutSessionProvider.notifier).completeCurrentExercise();
  }

  /// Phase 47B · handles the "Önceki egzersize geçiş" tap. Cancels any
  /// local countdown timer (the time-based workout timer re-seeds
  /// from the rewound exercise via the session listener), resumes
  /// analysis if paused, and asks the notifier to rewind the
  /// session pointer. Haptic tap so the user feels the action landed
  /// even before the HAZIRLAN! prep overlay surfaces.
  void _onPrev() {
    _workoutTimer?.cancel();
    _workoutTimer = null;
    _secondsRemaining = 0;
    if (_isPaused) {
      setState(() => _isPaused = false);
    }
    AppHaptics.secondaryTap();
    ref.read(workoutSessionProvider.notifier).previousExercise();
  }

  void _exit(BuildContext context) {
    // Phase 55 · ensure the Live Activity isn't orphaned on the Lock
    // Screen when the user backs out before the natural completion
    // path runs. `endWorkout` is idempotent so a duplicate call from
    // the completion listener is harmless.
    unawaited(WorkoutLiveActivityService.instance.endWorkout());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
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
                  assetPath: exercise.videoUrl,
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

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onExit,
    this.secondaryLabel,
    this.onSecondary,
  });

  static const Color _neon = Color(0xFF00F0FF);

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              decoration: BoxDecoration(
                color: const Color(0xFF111118),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _neon.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.2),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _neon.withValues(alpha: 0.15),
                    ),
                    child: Icon(icon, color: _neon, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: _neon,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(primaryLabel),
                    ),
                  ),
                  if (secondaryLabel != null && onSecondary != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _neon.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          secondaryLabel!,
                          style: const TextStyle(color: _neon),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 18,
          left: 16,
          child: WorkoutBackButton(onPressed: onExit),
        ),
      ],
    );
  }
}
