import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/audio_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/framing_validator.dart';
import '../domain/workout_mode.dart';
import '../services/back_legs_analyzers.dart';
import '../services/camera_frame_converter.dart';
import '../services/crunch_analyzer.dart' show CrunchState;
import '../services/pose_detector_service.dart';
import 'coach_line_copy.dart';
import 'framing_hint.dart';
import 'widgets/practice_rep_stage.dart';

/// Roadmap Phase 3 (R1.2 · C26 · C21) · the guided first-workout setup.
///
/// The Testers Community asked for *"an interactive tutorial that guides
/// users through their first workout while demonstrating how to use the
/// AI Pose Detection"*. This is that tutorial's first half: getting the
/// camera working, once, with certainty.
///
/// Why it matters more than it looks: real-time form analysis is
/// FormAI's hardest-won asset and its most intimidating first-use
/// moment — permission, placement, framing, lighting, and the silent
/// question *"is it even seeing me?"*. A user who fails that once will
/// avoid the feature forever and rate the app on the failure. Before
/// this screen, the only guidance was a reactive "Kadraja gir" pill that
/// appeared *after* the user was already mid-workout and already lost.
///
/// Four stages, each with its own exit:
///
///   1. **Placement** — static guidance, no camera, no permission. The
///      user learns what to do before being asked for anything.
///   2. **Calibration** — live pose detection with a confidence ring and
///      specific, non-judgemental corrections ("biraz geri git"), ending
///      in the "Seni görüyorum" moment.
///   3. **Practice** — one guided rep through the production analyzer,
///      with the tracked joints named on screen. Skippable, and skipped
///      outright on a replay or for anyone who has already done it.
///   4. **Ready** — a short confirmation, then into the real workout.
///
/// **The camera-free path (C21) is offered at every stage**, and framed
/// as a legitimate choice rather than a failure exit. Users who decline
/// camera permission, train in shared spaces, or can't position a phone
/// are not second-class here.
class CameraTutorialScreen extends ConsumerStatefulWidget {
  const CameraTutorialScreen({super.key, this.replay = false});

  /// True when the user reopened the guide from the workout overflow menu
  /// rather than being routed here before their first session.
  ///
  /// A replay is a *reference* visit: it returns the user to where they
  /// came from instead of launching a workout, and it doesn't re-run the
  /// practice rep they've already done. Pushing someone who tapped
  /// "remind me how to place the phone" into a fresh workout would be a
  /// hijack.
  final bool replay;

  @override
  ConsumerState<CameraTutorialScreen> createState() =>
      _CameraTutorialScreenState();
}

enum _Stage { placement, calibration, practice, ready }

class _CameraTutorialScreenState extends ConsumerState<CameraTutorialScreen>
    with WidgetsBindingObserver {
  _Stage _stage = _Stage.placement;

  CameraController? _controller;
  CameraDescription? _camera;
  Size? _imageSize;
  final PoseDetectorService _poseService = PoseDetectorService();
  final FramingStabilizer _stabilizer = FramingStabilizer();
  final AudioFeedback _voice = AudioFeedback();

  /// The practice rep runs a real production analyzer over real
  /// landmarks. A squat is the movement that fits: the user is already
  /// standing at ~2 m in full view from calibration, so nothing about
  /// the framing they just achieved has to change.
  final SquatAnalyzer _practiceAnalyzer = SquatAnalyzer();

  bool _processing = false;
  bool _disposed = false;
  FramingResult _framing = const FramingResult(
    issue: FramingIssue.noPose,
    confidence: 0,
    coverage: 0,
  );
  String? _error;
  bool _permissionPermanentlyDenied = false;

  // ─── Practice-rep state ────────────────────────────────────────────
  Pose? _practicePose;
  int _practiceReps = 0;
  CrunchState _practiceState = CrunchState.unknown;
  String? _practiceCue;
  bool _practiceDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The voice coach's mute switch is a user setting, not a per-screen
    // one: someone who silenced the coach for the gym did not consent to
    // the tutorial talking.
    _voice.muted = !ref.read(appPreferencesProvider).voiceCoachEnabled;
    unawaited(_voice.init());
    AnalyticsService.instance.tutorialStarted();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // A user who leaves mid-calibration is a funnel drop the success
    // event can't show. Fired only while still mid-setup so a normal
    // completion doesn't also register as a failure.
    if (_stage == _Stage.calibration &&
        _error == null &&
        !_permissionPermanentlyDenied) {
      AnalyticsService.instance.tutorialCalibrationFailed(
        reason: 'left_screen',
        lastIssue: _framing.issue.name,
      );
    }
    unawaited(_teardownCamera());
    unawaited(_poseService.dispose());
    unawaited(_voice.dispose());
    super.dispose();
  }

  void _say(String phrase) {
    unawaited(_voice.speak(phrase, priority: SpeechPriority.cue));
  }

  /// Roadmap Phase 5 · every read is behind a `mounted` guard at its call
  /// site, which is what makes reaching for `context` here safe in the
  /// async paths that set `_error`.
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded — holding it would block
    // other apps and, on some OEMs, come back in a broken state.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(_teardownCamera());
    } else if (state == AppLifecycleState.resumed &&
        (_stage == _Stage.calibration || _stage == _Stage.practice) &&
        _controller == null) {
      unawaited(_startCamera());
    }
  }

  /// Stop the stream BEFORE disposing — the ordering the workout screen
  /// learned the hard way (P1-6). Disposing with the stream live lets
  /// buffered frames race a disposing controller.
  Future<void> _teardownCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Already stopped, or the platform lost the handle. Dispose anyway.
    }
    try {
      await controller.dispose();
    } catch (_) {
      // Nothing useful to do; the controller is going away regardless.
    }
  }

  // ─── Stage transitions ─────────────────────────────────────────────

  Future<void> _beginCalibration() async {
    AppHaptics.primaryCta();
    setState(() {
      _error = null;
      _permissionPermanentlyDenied = false;
      _stage = _Stage.calibration;
    });

    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      AnalyticsService.instance.tutorialCameraDeclined(permanent: true);
      AnalyticsService.instance
          .tutorialCalibrationFailed(reason: 'permission_permanent');
      setState(() => _permissionPermanentlyDenied = true);
      return;
    }
    if (!status.isGranted) {
      AnalyticsService.instance.tutorialCameraDeclined(permanent: false);
      AnalyticsService.instance.tutorialCalibrationFailed(reason: 'permission');
      setState(() => _error = _l10n.tutorialErrorPermissionDenied);
      return;
    }

    final ready = await PoseDetectorService.isAvailable();
    if (!mounted) return;
    if (!ready) {
      AppLogger.warning(
        'ML Kit unavailable during tutorial — offering camera-free path',
        category: 'workout',
      );
      AnalyticsService.instance
          .tutorialCalibrationFailed(reason: 'ml_unavailable');
      setState(() => _error = _l10n.tutorialErrorMlUnavailable);
      return;
    }
    _say(_l10n.tutorialVoiceCameraOpened);
    await _startCamera();
  }

  /// Opens the camera, retrying once after a short delay.
  ///
  /// Device QA caught this: the very first `availableCameras()` /
  /// `initialize()` immediately after the OS permission grant fails on
  /// this Redmi — the permission dialog's own camera handle hasn't been
  /// released yet — and only a manual "TEKRAR DENE" succeeded. A
  /// first-run user would have read that error as "the flagship feature
  /// is broken", which is precisely the impression this whole screen
  /// exists to prevent. One silent retry converts it into a
  /// half-second's extra loading.
  Future<void> _startCamera({bool isRetry = false}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _error = _l10n.tutorialErrorNoCamera);
        return;
      }
      // Prefer the front lens: during setup the user needs to SEE
      // themselves to correct their position. The workout screen makes
      // its own choice per exercise.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (_disposed || !mounted) {
        await controller.dispose();
        return;
      }
      await controller.startImageStream(_onFrame);
      if (_disposed || !mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _controller = controller;
      });
    } catch (e, st) {
      if (!isRetry) {
        AppLogger.warning(
          'camera tutorial first open failed ($e) — retrying once',
          category: 'workout',
        );
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted || _disposed) return;
        return _startCamera(isRetry: true);
      }
      AppLogger.error(
        'camera tutorial start failed after retry',
        e,
        stackTrace: st,
        category: 'workout',
      );
      AnalyticsService.instance
          .tutorialCalibrationFailed(reason: 'camera_error');
      if (!mounted) return;
      setState(() => _error = _l10n.tutorialErrorCameraFailed);
    }
  }

  void _onFrame(CameraImage image) {
    if (!mounted || _disposed || _processing) return;
    if (_stage != _Stage.calibration && _stage != _Stage.practice) return;
    _processing = true;
    unawaited(_analyse(image).whenComplete(() => _processing = false));
  }

  Future<void> _analyse(CameraImage image) async {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return;
    try {
      final input = CameraFrameConverter.toInputImage(
        image,
        camera: camera,
        controller: controller,
      );
      if (input == null) return;
      final rotation = CameraFrameConverter.rotationFor(
        camera: camera,
        controller: controller,
      );
      if (rotation == null) return;

      final poses = await _poseService.detectPose(input);
      if (!mounted || _disposed) return;

      if (_stage == _Stage.practice) {
        _onPracticeFrame(poses.isEmpty ? null : poses.first, image, rotation);
        return;
      }

      final result = evaluateFraming(
        poses.isEmpty ? null : poses.first,
        frameHeight: CameraFrameConverter.analysedHeight(image, rotation),
      );
      final confirmed = _stabilizer.accept(result);
      if (!mounted) return;
      setState(() => _framing = result);
      if (confirmed) await _onCalibrated();
    } catch (e) {
      // A single failed frame is not worth surfacing — the next one
      // arrives in ~33ms. Persistent failure shows as a stuck "can't
      // see you" hint, which is honest.
      AppLogger.warning(
        'tutorial frame analysis failed: $e',
        category: 'workout',
      );
    }
  }

  Future<void> _onCalibrated() async {
    if (_stage != _Stage.calibration) return;
    AnalyticsService.instance.tutorialCalibrationSucceeded(
      confidence: _framing.confidence,
    );
    AppHaptics.primaryCta();
    _say(_l10n.tutorialVoiceSeeYou);

    // Replay visitors, and anyone who has already done the practice rep,
    // stop at the confirmation. Repeating a movement drill every time
    // someone re-reads the placement guide would turn a reference into a
    // chore.
    final prefs = ref.read(appPreferencesProvider);
    if (widget.replay || prefs.completedPracticeRep) {
      setState(() => _stage = _Stage.ready);
      await _teardownCamera();
      return;
    }

    // The camera stays live: the practice rep is the next stage and it
    // needs the same stream. It is released when practice ends.
    _practiceAnalyzer.reset();
    setState(() {
      _stage = _Stage.practice;
      _practiceReps = 0;
      _practiceState = CrunchState.unknown;
      _practiceCue = null;
      _practiceDone = false;
    });
    _say(_l10n.tutorialVoicePracticePrompt);
  }

  // ─── Practice rep ──────────────────────────────────────────────────

  /// One frame of the guided practice rep, through the *production*
  /// [SquatAnalyzer]. Using the real analyzer rather than a scripted
  /// animation is the entire point: what the user watches succeed here
  /// is the same code that will count their workout.
  void _onPracticeFrame(Pose? pose, CameraImage image, InputImageRotation rot) {
    if (_practiceDone) return;
    if (pose == null) {
      if (_practicePose != null && mounted) {
        setState(() => _practicePose = null);
      }
      return;
    }

    final result = _practiceAnalyzer.analyze(pose);
    final size = CameraFrameConverter.analysedSize(image, rot);
    if (!mounted) return;

    setState(() {
      _practicePose = pose;
      _imageSize = size;
      _practiceState = result.state;
      _practiceReps = result.reps;
      // Real form warnings win; otherwise mirror the live phase back so
      // the user sees the detector tracking them rather than a frozen
      // caption. Both are read off the pose — neither is scripted.
      _practiceCue = result.formWarning?.text(_l10n) ??
          (result.state == CrunchState.down ? _l10n.tutorialCueStandUp : null);
    });

    if (result.formWarning != null) {
      _say(result.formWarning!.text(_l10n));
    }
    if (result.repJustCompleted) {
      unawaited(_onPracticeRepCounted());
    }
  }

  Future<void> _onPracticeRepCounted() async {
    if (_practiceDone) return;
    _practiceDone = true;
    AppHaptics.primaryCta();
    AnalyticsService.instance.tutorialPracticeRep(
      completed: true,
      reps: _practiceReps,
    );
    await ref.read(appPreferencesProvider).markCompletedPracticeRep();
    _say(_l10n.tutorialVoiceRepCounted);
    if (!mounted) return;
    setState(() => _stage = _Stage.ready);
    // The camera has done its job; release it before the workout screen
    // opens its own controller. Two live controllers on one lens fails
    // on most Android devices.
    await _teardownCamera();
  }

  /// Skipping is a first-class exit, not a failure. A user with a
  /// mobility limitation, in a crowded room, or simply not dressed to
  /// squat must not be blocked from their workout by a demo.
  Future<void> _skipPractice() async {
    if (_practiceDone) return;
    _practiceDone = true;
    AppHaptics.secondaryTap();
    AnalyticsService.instance.tutorialPracticeRep(
      completed: false,
      reps: _practiceReps,
    );
    await ref.read(appPreferencesProvider).markCompletedPracticeRep();
    if (!mounted) return;
    setState(() => _stage = _Stage.ready);
    await _teardownCamera();
  }

  // ─── Exits ─────────────────────────────────────────────────────────

  Future<void> _startWorkout() async {
    final prefs = ref.read(appPreferencesProvider);
    await prefs.markCameraTutorialCompleted();
    await prefs.setPreferredWorkoutMode(WorkoutMode.camera);
    AnalyticsService.instance.tutorialCompleted(mode: WorkoutMode.camera.token);
    if (!mounted) return;
    if (widget.replay) {
      _leaveReplay();
      return;
    }
    context.pushReplacement(AppRoutes.workout);
  }

  /// C21 · the camera-free path. Presented as a choice, not a failure.
  Future<void> _continueWithoutCamera() async {
    final prefs = ref.read(appPreferencesProvider);
    await prefs.markCameraTutorialCompleted();
    await prefs.setPreferredWorkoutMode(WorkoutMode.manual);
    AnalyticsService.instance.tutorialCompleted(mode: WorkoutMode.manual.token);
    await _teardownCamera();
    if (!mounted) return;
    context.pushReplacement(AppRoutes.manualWorkout);
  }

  /// Returns a replay visitor to wherever they opened the guide from.
  /// Falls back to the workout route when there is nothing to pop — a
  /// deep link into the guide should still leave the user somewhere real.
  void _leaveReplay() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.pushReplacement(AppRoutes.workout);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Leaving mid-setup is fine, but it must not silently mark the
      // tutorial done — the user gets it again next time.
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0612),
        body: SafeArea(
          child: switch (_stage) {
            _Stage.placement => _PlacementStage(
                onStart: _beginCalibration,
                onSkipCamera: _continueWithoutCamera,
              ),
            _Stage.calibration => _CalibrationStage(
                controller: _controller,
                framing: _framing,
                progress: _stabilizer.progress,
                error: _error,
                permanentlyDenied: _permissionPermanentlyDenied,
                onOpenSettings: openAppSettings,
                onRetry: _beginCalibration,
                onSkipCamera: _continueWithoutCamera,
              ),
            _Stage.practice => PracticeRepStage(
                controller: _controller,
                pose: _practicePose,
                imageSize: _imageSize,
                lensDirection: _camera?.lensDirection,
                reps: _practiceReps,
                state: _practiceState,
                cue: _practiceCue,
                onSkip: _skipPractice,
              ),
            _Stage.ready => _ReadyStage(
                isReplay: widget.replay,
                onStart: _startWorkout,
                onSkipCamera: _continueWithoutCamera,
              ),
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Stage 1 · placement guidance (no camera, no permission)
// ═══════════════════════════════════════════════════════════════════════

class _PlacementStage extends StatelessWidget {
  const _PlacementStage({required this.onStart, required this.onSkipCamera});

  final VoidCallback onStart;
  final VoidCallback onSkipCamera;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Eyebrow(AppLocalizations.of(context).tutorialEyebrowSetup),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).tutorialSetupTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context).tutorialSetupSubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                const _PlacementDiagram(),
                const SizedBox(height: 24),
                _Step(
                  index: 1,
                  icon: Icons.stay_current_portrait_rounded,
                  title: AppLocalizations.of(context).tutorialStepPlaceTitle,
                  body: AppLocalizations.of(context).tutorialStepPlaceBody,
                ),
                _Step(
                  index: 2,
                  icon: Icons.straighten_rounded,
                  title: AppLocalizations.of(context).tutorialStepDistanceTitle,
                  body: AppLocalizations.of(context).tutorialStepDistanceBody,
                ),
                _Step(
                  index: 3,
                  icon: Icons.lightbulb_outline_rounded,
                  title: AppLocalizations.of(context).tutorialStepLightTitle,
                  body: AppLocalizations.of(context).tutorialStepLightBody,
                ),
                const SizedBox(height: 8),
                const _PrivacyNote(),
              ],
            ),
          ),
        ),
        _StageFooter(
          primaryLabel: AppLocalizations.of(context).tutorialOpenCamera,
          onPrimary: onStart,
          secondaryLabel:
              AppLocalizations.of(context).tutorialContinueWithoutCamera,
          onSecondary: onSkipCamera,
        ),
      ],
    );
  }
}

/// A phone-position diagram drawn in code — no asset to ship, and it
/// scales cleanly at any text size.
class _PlacementDiagram extends StatelessWidget {
  const _PlacementDiagram();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 22),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.neon, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 13,
                  color: AppColors.neon,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).tutorialDiagramPhone,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: AppColors.neon.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).tutorialDiagramDistance,
                  style: TextStyle(
                    color: AppColors.neon.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                size: 52,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).tutorialDiagramYou,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(width: 22),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Stage 2 · live calibration
// ═══════════════════════════════════════════════════════════════════════

class _CalibrationStage extends StatelessWidget {
  const _CalibrationStage({
    required this.controller,
    required this.framing,
    required this.progress,
    required this.error,
    required this.permanentlyDenied,
    required this.onOpenSettings,
    required this.onRetry,
    required this.onSkipCamera,
  });

  final CameraController? controller;
  final FramingResult framing;
  final double progress;
  final String? error;
  final bool permanentlyDenied;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
  final VoidCallback onSkipCamera;

  @override
  Widget build(BuildContext context) {
    if (permanentlyDenied) {
      return _BlockedState(
        title: AppLocalizations.of(context).tutorialPermissionBlockedTitle,
        body: AppLocalizations.of(context).tutorialPermissionBlockedBody,
        primaryLabel: AppLocalizations.of(context).tutorialOpenSettings,
        onPrimary: onOpenSettings,
        onSkipCamera: onSkipCamera,
      );
    }
    if (error != null) {
      return _BlockedState(
        title: AppLocalizations.of(context).tutorialCameraFailedTitle,
        body: error!,
        primaryLabel: AppLocalizations.of(context).tutorialRetry,
        onPrimary: onRetry,
        onSkipCamera: onSkipCamera,
      );
    }

    final ready = controller != null && controller!.value.isInitialized;
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.previewSize?.height ?? 720,
                    height: controller!.value.previewSize?.width ?? 1280,
                    child: CameraPreview(controller!),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: AppColors.neon),
                ),
              // Framing guide + live status.
              if (ready) _FramingOverlay(framing: framing, progress: progress),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
          child: Semantics(
            liveRegion: true,
            child: Text(
              framing.issue.hint(AppLocalizations.of(context)),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: framing.isReady
                    ? const Color(0xFF39FF14)
                    : Colors.white.withValues(alpha: 0.86),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onSkipCamera,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.55),
            minimumSize: const Size(120, 48),
          ),
          child: Text(
            AppLocalizations.of(context).tutorialContinueWithoutCamera,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// The framing rectangle + confidence ring. Amber while adjusting, neon
/// green when locked — a colour change the user can read from 2 metres
/// away, which is the whole point.
class _FramingOverlay extends StatelessWidget {
  const _FramingOverlay({required this.framing, required this.progress});

  final FramingResult framing;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ok = framing.isReady;
    final color = ok ? const Color(0xFF39FF14) : const Color(0xFFFFB84D);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: color.withValues(alpha: 0.85), width: 3),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: ok ? progress : null,
                      strokeWidth: 2.4,
                      color: color,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    ok
                        ? AppLocalizations.of(context).tutorialHoldStill
                        : AppLocalizations.of(context).tutorialSearchingForYou,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
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

// ═══════════════════════════════════════════════════════════════════════
// Stage 4 · confirmed
// ═══════════════════════════════════════════════════════════════════════

class _ReadyStage extends StatelessWidget {
  const _ReadyStage({
    required this.isReplay,
    required this.onStart,
    required this.onSkipCamera,
  });

  final bool isReplay;
  final VoidCallback onStart;
  final VoidCallback onSkipCamera;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF39FF14).withValues(alpha: 0.12),
                      border: Border.all(
                        color: const Color(0xFF39FF14).withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF39FF14),
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    AppLocalizations.of(context).tutorialReadyTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context).tutorialReadyBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _StageFooter(
          primaryLabel: isReplay
              ? AppLocalizations.of(context).tutorialBackToWorkout
              : AppLocalizations.of(context).tutorialStartWorkout,
          onPrimary: onStart,
          secondaryLabel:
              AppLocalizations.of(context).tutorialContinueWithoutCamera,
          onSecondary: onSkipCamera,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Shared chrome
// ═══════════════════════════════════════════════════════════════════════

class _BlockedState extends StatelessWidget {
  const _BlockedState({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSkipCamera,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSkipCamera;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 46,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _StageFooter(
          primaryLabel: primaryLabel,
          onPrimary: onPrimary,
          secondaryLabel:
              AppLocalizations.of(context).tutorialContinueWithoutCamera,
          onSecondary: onSkipCamera,
        ),
      ],
    );
  }
}

class _StageFooter extends StatelessWidget {
  const _StageFooter({
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                primaryLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onSecondary,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.58),
              minimumSize: const Size(120, 48),
            ),
            child: Text(
              secondaryLabel,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.neon.withValues(alpha: 0.95),
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int index;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neon.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.neon.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 17, color: AppColors.neon),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The privacy claim, stated at the moment the user is deciding whether
/// to grant camera access — not buried in a policy they'll never open.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context).tutorialPrivacyNote,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
