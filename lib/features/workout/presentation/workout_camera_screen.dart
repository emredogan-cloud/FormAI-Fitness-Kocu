import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/live_activity_service.dart';
import '../../../core/services/tour_targets.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/audio_feedback.dart';
import '../../../core/widgets/error_card.dart';
import '../../../core/widgets/spotlight_tour.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/coach_line.dart';
import '../models/exercise_model.dart';
import '../providers/workout_provider.dart';
import '../services/analyzer_factory.dart';
import '../services/coach_voice.dart';
import '../services/crunch_analyzer.dart';
import '../services/pose_analyzer.dart';
import '../services/camera_frame_converter.dart';
import '../services/pose_detector_service.dart';
import 'coach_line_copy.dart';
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
  late final CoachVoice _coach = CoachVoice(_audio);

  static const Color _neon = Color(0xFF00F0FF);

  CameraController? _controller;
  CameraDescription? _camera;
  List<Pose> _poses = const [];
  Size? _imageSize;
  // Store-submission U6 · last frame that contained a detected pose
  // (baseline = first processed frame). Drives the visual "get in
  // frame" pill — previously the only cue was the voice coach, which
  // is silent on muted phones.
  DateTime? _lastPoseAt;
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
  CoachLine? _formWarning;
  // Phase 49 · last form warning we issued a haptic for. Used as a
  // single-step debounce so a sustained warning (which can fire on
  // every frame for several seconds) only buzzes the device once per
  // occurrence instead of vibrating continuously.
  //
  // Roadmap Phase 5 · now a CoachLine rather than the sentence. The
  // debounce compares identity, which is what it always meant — two
  // different faults that happen to share wording in one language must
  // still buzz twice.
  CoachLine? _lastFormWarning;

  /// Read inside the image-analysis callback, which runs while the
  /// widget is mounted and the camera stream is live.
  AppLocalizations get _l10n => AppLocalizations.of(context);
  CrunchState _state = CrunchState.unknown;

  Timer? _workoutTimer;
  int _secondsRemaining = 0;
  bool _isPaused = false;

  /// One-shot per session: the "place the phone to your side" hint for
  /// sagittal-plane exercises (squat / push-up / hinge families).
  bool _spokeSideViewHint = false;

  // ─── Roadmap Phase 3b · in-session tutorial + voice toggle ────────

  /// True while the first-workout coach-mark layer is on screen.
  ///
  /// Rep analysis and the countdown are suspended for its duration. A
  /// user reading an explanation of the rep counter is standing still,
  /// and letting a time-based set burn down — or letting the analyzer
  /// bank reps off them shifting their weight — would make the
  /// explanation cost them the very thing it's explaining.
  ///
  /// Deliberately NOT implemented by flipping `_isPaused`: the layer
  /// spotlights the pause control while describing it, and that control
  /// showing "resume" mid-explanation is exactly the confusion this
  /// phase exists to remove.
  bool _tutorialActive = false;
  bool _tutorialFired = false;

  /// Mirrors `AppPreferences.voiceCoachEnabled` for the toggle's icon.
  bool _voiceEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceEnabled = ref.read(appPreferencesProvider).voiceCoachEnabled;
    _audio.muted = !_voiceEnabled;
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

    // Phase 138 · H-4. Probe ML Kit pose-detection availability BEFORE
    // requesting camera permission. On forked ROMs / older Huawei
    // devices / installs missing Google Play Services, the native
    // pose-detection layer can fail to initialise — the camera would
    // open fine but every frame would silently fail in
    // `_processImage`, leaving the user staring at a preview that
    // never counts a rep. Catching the unavailable case here surfaces
    // a clean error card instead of a confused user.
    final mlKitReady = await PoseDetectorService.isAvailable();
    if (!mounted) return;
    if (!mlKitReady) {
      AppLogger.warning(
        'ML Kit pose detection unavailable — graceful degradation',
        category: 'workout',
      );
      setState(() {
        _error = 'Bu cihaz form analizi için gereken yapay zeka katmanını '
            'çalıştıramıyor. Antrenmana camera-free modda devam etmek için '
            'ana ekrandaki manuel egzersizleri kullanabilirsin.';
      });
      return;
    }

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
    } on CameraException catch (e, st) {
      // Phase 138 · M-8. The camera plugin throws CameraException
      // with a string `code` derived from the native error. We map
      // the "another app holds the camera" / "max cameras in use"
      // codes to a more actionable Turkish message; everything else
      // falls through to the generic "Kamera başlatılamadı" copy.
      AppLogger.warning(
        'Camera startup failed (code=${e.code})',
        category: 'workout',
        data: {'description': e.description ?? '', 'stack': st.toString()},
      );
      if (!mounted) return;
      final code = e.code.toLowerCase();
      final description = (e.description ?? '').toLowerCase();
      final inUse = code.contains('in_use') ||
          code.contains('inuse') ||
          code.contains('cameraaccess') ||
          code.contains('max_cameras') ||
          description.contains('already in use') ||
          description.contains('in use by another');
      setState(() {
        _error = inUse
            ? 'Kamera şu an başka bir uygulama tarafından kullanılıyor. '
                'O uygulamayı kapatıp tekrar dene.'
            : 'Kamera başlatılamadı: ${e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Kamera başlatılamadı: $e');
    }
  }

  Future<bool> _showMlKitDisclosure() async {
    // UX-10 · show once, remember forever. Re-prompting the same
    // transparency dialog on every workout entry was friction with no
    // added disclosure value.
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.mlDisclosureAcked) return true;
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
    if (result == true) {
      unawaited(prefs.setMlDisclosureAcked());
    }
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
    if (_isProcessingFrame || _isPaused || _tutorialActive) return;

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
      _coach.onPause();
      return;
    }
    _coach.onResume();
    final exercise = ref.read(workoutSessionProvider).value?.activeExercise;
    if (exercise?.type == ExerciseType.timeBased && _secondsRemaining > 0) {
      _resumeWorkoutTimer();
    }
  }

  // ─── Roadmap Phase 3b · in-session tutorial layer (R1.2) ──────────

  /// Runs the first-workout coach-mark layer once, then never again.
  ///
  /// Fires only on a live, non-resting, non-preparing set: every target
  /// it points at lives in the control panel or over the preview, and
  /// none of them are laid out under the rest or HAZIRLAN! overlays.
  /// `SpotlightTour` would silently drop those steps rather than crash,
  /// which is worse than not running — the user would get a two-step
  /// tour and never be offered the rest.
  Future<void> _maybeShowInSessionTutorial() async {
    if (_tutorialFired || _tutorialActive || !mounted) return;
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.seenInSessionTutorial) return;
    final session = ref.read(workoutSessionProvider).value;
    if (session == null ||
        session.activeExercise == null ||
        session.isResting ||
        session.isPreparing ||
        session.isSessionComplete) {
      return;
    }
    _tutorialFired = true;

    // Let the control panel finish its first layout — the targets are
    // resolved from live RenderBoxes, and a rect read a frame too early
    // is a rect of zero size.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final targets = ref.read(tourTargetsProvider);
    // `showSpotlightTour` drops unresolvable steps and returns false when
    // that leaves nothing — indistinguishable, at the call site, from
    // "the user skipped". Marking the one-shot seen on that would burn
    // the tutorial without ever showing it. So check first, and let a
    // later transition retry instead.
    final anchored = [
      targets.workoutRepCounter,
      targets.workoutFormIndicator,
      targets.workoutPauseControl,
      targets.workoutVoiceToggle,
      targets.workoutNextControl,
    ].any((key) => TourTargets.rectOf(key) != null);
    if (!anchored) {
      _tutorialFired = false;
      return;
    }

    setState(() => _tutorialActive = true);
    _workoutTimer?.cancel();
    _workoutTimer = null;
    _coach.onPause();

    var completed = false;
    try {
      completed = await showSpotlightTour(
        context,
        steps: [
          SpotlightStep(
            title: 'Tekrarların burada',
            body: 'Her tamamlanan tekrarı buraya yazıyorum. Sen saymıyorsun '
                '— sadece hareketi yap.',
            rect: () => TourTargets.rectOf(targets.workoutRepCounter),
          ),
          SpotlightStep(
            title: 'Form göstergesi',
            body: 'Hareketin hangi aşamasında olduğunu buradan takip '
                'ediyorum. Formun bozulursa ekranda ve sesle uyarırım.',
            rect: () => TourTargets.rectOf(targets.workoutFormIndicator),
          ),
          SpotlightStep(
            title: 'Ara vermek istersen',
            body: 'Buradan duraklat. Analiz durur, ilerlemen kaybolmaz — '
                'kaldığın yerden devam edersin.',
            rect: () => TourTargets.rectOf(targets.workoutPauseControl),
          ),
          SpotlightStep(
            title: 'Sesli koç',
            body: 'Sesli yönlendirmeyi buradan kapatabilirsin. Kalabalık '
                'bir yerdeysen tek dokunuş yeter.',
            rect: () => TourTargets.rectOf(targets.workoutVoiceToggle),
          ),
          SpotlightStep(
            title: 'Sıradaki harekete geç',
            body: 'Bir hareketi erken bitirmek istersen buradan ilerle. '
                'Son hareketten sonra seansı tamamlarsın.',
            rect: () => TourTargets.rectOf(targets.workoutNextControl),
          ),
        ],
      );
    } finally {
      // Marked seen even on skip: a coach-mark layer that reappears
      // because the user dismissed it is the definition of nagging.
      await prefs.markSeenInSessionTutorial();
      AnalyticsService.instance.inSessionTutorialFinished(completed: completed);
      if (mounted) {
        setState(() => _tutorialActive = false);
        _coach.onResume();
        final exercise = ref.read(workoutSessionProvider).value?.activeExercise;
        if (!_isPaused &&
            exercise?.type == ExerciseType.timeBased &&
            _secondsRemaining > 0) {
          _resumeWorkoutTimer();
        }
      }
    }
  }

  /// Roadmap Phase 3b · the voice coach's mute switch.
  Future<void> _toggleVoice() async {
    AppHaptics.secondaryTap();
    final next = !_voiceEnabled;
    setState(() => _voiceEnabled = next);
    _audio.muted = !next;
    AnalyticsService.instance.voiceCoachToggled(enabled: next);
    await ref.read(appPreferencesProvider).setVoiceCoachEnabled(next);
  }

  /// Roadmap Phase 3 feature 6 · reopen the setup guide, forever after.
  ///
  /// Pushed rather than navigated to, and paused first: the user is
  /// stepping away from a live set to re-read the placement guidance, so
  /// analysis should stop and the session should still be there when
  /// they come back.
  Future<void> _replaySetupGuide() async {
    if (!_isPaused) _togglePause();
    AnalyticsService.instance.tutorialReplayed();
    await context.push(AppRoutes.cameraTutorialReplay);
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
        // Tier-A · feed the coach the post-decrement value so it can
        // emit halfway / final-10s / final-5s pacing beats. The coach
        // tracks its own fired-once gates so a re-entry through pause/
        // resume doesn't double-fire.
        _coach.onTimerTick(_secondsRemaining);
      }
    });
  }

  /// U6 · true when the live session has gone ≥4 s without a detected
  /// pose (and isn't paused) — the visual counterpart to the voice
  /// coach's "tüm vücudun görünmeli" framing cue.
  bool get _showNoPoseHint {
    if (_isPaused || _poses.isNotEmpty) return false;
    final t = _lastPoseAt;
    return t != null &&
        DateTime.now().difference(t) >= const Duration(seconds: 4);
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

      // Tier-A.6 + Tier-B.4 · feed every frame's pose (or null) into
      // the coach. Drives both the sustained-low-confidence tracking
      // cue (Tier A) and the post-set-start calibration probe
      // (Tier B). `image.width` is the input frame's pixel width;
      // the calibration probe uses it to express shoulder span as a
      // ratio of frame width.
      _coach.onPoseFrame(
        poses.isNotEmpty ? poses.first : null,
        frameWidth: image.width.toDouble(),
      );

      CrunchResult? result;
      if (poses.isNotEmpty) {
        result = _analyzer.analyze(poses.first);

        final warning = result.formWarning;
        if (warning != null) {
          // Tier-A: form warnings ride at SpeechPriority.warning so they
          // pre-empt any lower-priority utterance (ambient heartbeat,
          // milestone celebrations) and never get cut off themselves.
          _audio.speak(warning.text(_l10n), priority: SpeechPriority.warning);
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
          // Tier-A: cues are below warning but above milestones — a phase
          // transition needs to land, but it shouldn't pre-empt a safety
          // correction.
          _audio.speak(cue.text(_l10n), priority: SpeechPriority.cue);
        }

        if (result.repJustCompleted) {
          // Tier-S audit fix · gate ALL rep-derived feedback on the
          // exercise being repBased. Time-based exercises (plank,
          // flutter kick, wall sit, side plank, jumping jack…) are
          // driven by the camera-screen countdown timer; firing
          // per-rep heavy haptics and milestone speech against them
          // creates the "30s plank counted as ~10 reps" sensation
          // (see WORKOUT_INTELLIGENCE_AUDIT.md §4 Issue D). The
          // analyzer may still emit `repJustCompleted: true` because
          // some classes — FlutterKickAnalyzer, MountainClimber, etc.
          // — keep their internal state machines running regardless
          // of how the exercise is presented; we just decline to
          // surface that signal as user-visible feedback.
          final activeExercise =
              ref.read(workoutSessionProvider).value?.activeExercise;
          final isRepBased = activeExercise?.type == ExerciseType.repBased;
          if (!isRepBased) {
            // Time-based: skip haptic + rep counter + milestone speech.
            // Timer drives completion via `_onTimerComplete()`.
          } else {
            // Phase 49 · upgraded from a per-rep light tap to a heavy
            // impact. A counted rep is the unambiguous "you did the
            // thing" signal — the user's whole reason for being on this
            // screen — so it earns the strongest haptic in the app.
            AppHaptics.heavyImpact();
            if (!mounted) return;
            final notifier = ref.read(workoutSessionProvider.notifier);
            notifier.setCurrentReps(result.reps);
            final target = activeExercise?.targetReps;

            // Milestone + pacing voice coach. Priority: 2-left > halfway >
            // analyzer pacing. AudioFeedback's own 3s per-phrase dedupe and
            // the analyzer's 7s pacing throttle prevent overlap.
            final reps = result.reps;
            if (target != null && target > 1 && reps == target - 2) {
              _audio.speak('Son iki tekrar, sık dişini!',
                  priority: SpeechPriority.milestone);
            } else if (target != null &&
                target >= 4 &&
                reps == (target / 2).floor()) {
              _audio.speak('Yarıladın! Aynen böyle devam et.',
                  priority: SpeechPriority.milestone);
            } else if (result.pacingFeedback != null) {
              _audio.speak(result.pacingFeedback!.text(_l10n),
                  priority: SpeechPriority.encouragement);
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
      }

      if (!mounted) return;
      setState(() {
        _poses = poses;
        if (poses.isNotEmpty) {
          _lastPoseAt = DateTime.now();
        } else {
          // Baseline from the first processed frame so the framing hint
          // can fire even if a person never enters the frame.
          _lastPoseAt ??= DateTime.now();
        }
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

  /// Roadmap Phase 3 · delegates to the shared [CameraFrameConverter],
  /// which the camera tutorial screen also uses. Behaviour unchanged.
  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;
    return CameraFrameConverter.toInputImage(
      image,
      camera: camera,
      controller: controller,
    );
  }

  InputImageRotation _currentRotation() {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) {
      return InputImageRotation.rotation0deg;
    }
    return CameraFrameConverter.rotationFor(
          camera: camera,
          controller: controller,
        ) ??
        InputImageRotation.rotation0deg;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // P1-6 · interruption-safe session. The old handler disposed the
    // controller on `inactive` WITHOUT stopping the image stream,
    // without nulling `_controller`, and without pausing anything —
    // so a phone call / notification-shade pull mid-plank left the
    // timer draining, the coach talking to a dead camera, buffered
    // frames racing into `_onCameraImage` against a disposing
    // controller, and the next build dereferencing a disposed
    // controller ("used after being disposed" crash).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      // Auto-pause through the same state the manual pause button uses:
      // timer stops draining, coach goes quiet, and on return the user
      // lands on the existing pause overlay with its resume affordance.
      if (!_isPaused) {
        _isPaused = true;
        _workoutTimer?.cancel();
        _workoutTimer = null;
        _coach.onPause();
      }
      // Mirror dispose(): stop the stream FIRST so buffered frames are
      // dropped at the platform layer, then dispose, then null the
      // field so no code path can touch the disposed instance.
      if (controller.value.isStreamingImages) {
        unawaited(controller.stopImageStream().catchError((_) {}));
      }
      unawaited(controller.dispose());
      _controller = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        _camera != null) {
      // Re-init the camera; the session stays paused until the user
      // explicitly resumes from the overlay.
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
    _coach.dispose();
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
    _audio.speak('Süre doldu, harika!', priority: SpeechPriority.milestone);
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
        _audio.speak('Antrenman tamamlandı! Harika bir iş çıkardın.',
            priority: SpeechPriority.milestone);
      } else if (justStartedRest && exercise != null) {
        _audio.speak(
          'Harika! Şimdi ${exercise.restDurationInSeconds} saniye dinlenme.',
          priority: SpeechPriority.milestone,
        );
      } else if (justStartedPrep && exercise != null) {
        // Every shipped exercise has a non-empty `description` (Phase 26).
        // `'Başlayın!'` is a last-resort fallback for any future Exercise
        // instance that forgets to populate it.
        final desc = exercise.description.isNotEmpty
            ? exercise.description
            : 'Başlayın!';
        _audio.speak('Sıradaki hareket: ${exercise.name}. $desc',
            priority: SpeechPriority.milestone);
      }

      // Always swap analyzer the moment the exercise id flips, even while
      // resting/preparing — that way it's primed and ready when the user
      // gets cleared to start.
      if (exerciseChanged) {
        _analyzer = exercise == null ? CrunchAnalyzer() : analyzerFor(exercise);
        // P2 form-trust · squat-lean / push-up-hip-sag / hinge-ROM
        // checks measure sagittal-plane faults, which a straight-on
        // selfie view geometrically can't capture. One spoken hint per
        // session tells the user how to make those cues actually work
        // instead of silently under-delivering the headline feature.
        if (exercise != null && !_spokeSideViewHint) {
          final slug = exercise.id.toLowerCase();
          const sagittalMarkers = [
            'squat',
            'push_up',
            'pushup',
            'hinge',
            'deadlift',
            'good_morning',
          ];
          if (sagittalMarkers.any(slug.contains)) {
            _spokeSideViewHint = true;
            _audio.speak(
              'İpucu: telefonu seni yandan görecek şekilde yerleştirirsen '
              'duruş uyarıları çok daha isabetli olur.',
              priority: SpeechPriority.milestone,
            );
          }
        }
      }

      // Pause the per-exercise countdown during rest AND prep so the
      // user doesn't burn into a time-based set before they're ready.
      if (resting || preparing) {
        _workoutTimer?.cancel();
        _workoutTimer = null;
        if (resting && _secondsRemaining != 0) {
          setState(() => _secondsRemaining = 0);
        }
        // Tier-A · the active set just paused (rest started) or never
        // started (prep). Either way the mid-set heartbeat should
        // stop — the rest coach takes over during rest.
        if (justStartedRest || justStartedPrep) {
          _coach.endSet();
        }
        // Tier-A · drive the rest coach. Engage when rest starts,
        // disengage when prep starts (rest already ended by then).
        if (justStartedRest && exercise != null) {
          _coach.startRest(exercise.restDurationInSeconds);
        }
        if (justStartedPrep) {
          _coach.endRest();
        }
        return;
      }

      // Active workout ground state — we are clearly not in rest or
      // prep here. Tear down any straggling rest scheduler (e.g. when
      // the user taps "skipRest" the listener fires with resting=false
      // immediately, no prep intermediary).
      if (justFinishedRest) {
        _coach.endRest();
      }
      if (exerciseChanged ||
          justFinishedPrep ||
          justFinishedRest ||
          setChanged) {
        _analyzer.reset();
        _syncExerciseTimer(exercise);
        // Tier-A · the user is now actively repping (or holding a
        // timed set). Start the mid-set heartbeat with category-aware
        // copy. Same trigger as `_syncExerciseTimer` so the coach and
        // the visible countdown engage in lockstep.
        _coach.startSet(exercise);
      }

      // Tier-A · session completion stops every coaching surface.
      if (sessionJustCompleted) {
        _coach.endSet();
        _coach.endRest();
      }

      // Roadmap Phase 3b · the first-workout coach-mark layer. Attempted
      // on every active-state transition rather than once at mount: the
      // session arrives asynchronously and the first frames are usually
      // the HAZIRLAN! countdown, so "when the screen opens" is reliably
      // too early. `_tutorialFired` makes the repeated attempts free.
      unawaited(_maybeShowInSessionTutorial());
    });

    // Phase 138 · M-2 — system-back gesture goes through the same
    // confirmation dialog as the in-UI back button. canPop:false
    // forces the navigator to consult onPopInvoked, which delegates
    // to _confirmAndExit. The dialog itself short-circuits when the
    // session is complete or absent, so a back gesture during a
    // permission card or error card still exits cleanly.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmAndExit(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildBody()),
      ),
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
      data: (session) {
        // Roadmap Phase 3b · second, mount-side trigger for the
        // coach-mark layer.
        //
        // The `ref.listen` below only fires on session *transitions*.
        // Device QA found the gap: entering the camera screen on an
        // ALREADY-active session — switching over from camera-free mode
        // mid-workout — produces no transition after mount, so the tour
        // never ran and the user silently never learned the controls.
        // `_tutorialFired` makes this attempt free once one has landed.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_maybeShowInSessionTutorial());
        });
        return _buildSession(controller, session);
      },
    );
  }

  Widget _buildSession(
      CameraController controller, WorkoutSessionState session) {
    if (session.isResting) {
      // Tier-B.8 · the per-second countdown lives in
      // `restCountdownProvider`. The rest overlay watches it
      // directly so only the rest overlay re-renders per tick — the
      // rest of `_buildSession` stays put.
      final countdown = ref.watch(restCountdownProvider);
      return RestOverlay(
        secondsRemaining: countdown,
        upcomingExercise: session.upcomingExercise,
        upcomingSet: session.currentSet,
        totalSets: session.upcomingExercise?.sets ?? 0,
        onSkip: () => ref.read(workoutSessionProvider.notifier).skipRest(),
        onExit: () => _confirmAndExit(context),
      );
    }

    if (session.isPreparing && session.activeExercise != null) {
      return PreparationOverlay(
        exercise: session.activeExercise!,
        secondsRemaining: session.prepSecondsRemaining,
        onExit: () => _confirmAndExit(context),
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
            child: Row(
              children: [
                WorkoutBackButton(
                  onPressed: () => _confirmAndExit(context),
                ),
                const SizedBox(width: 10),
                // Roadmap Phase 3b · voice-coach mute + the replayable
                // setup guide (feature 6), both reachable without
                // leaving the set.
                _VoiceToggleButton(
                  key: ref.read(tourTargetsProvider).workoutVoiceToggle,
                  enabled: _voiceEnabled,
                  onPressed: _toggleVoice,
                ),
                const SizedBox(width: 10),
                _WorkoutOverflowMenu(onReplayGuide: _replaySetupGuide),
              ],
            ),
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
                  _FormWarning(
                      message:
                          _formWarning!.text(AppLocalizations.of(context))),
                  const SizedBox(height: 8),
                ],
                // U6 · framing hint takes the tip slot while no pose has
                // been detected for a few seconds (voice-only cue was
                // invisible on muted phones); frames keep arriving, so
                // the per-frame setState re-evaluates this continuously.
                if (_showNoPoseHint)
                  const _LiveTipPill(
                    tip: 'Kadraja gir — analiz için tüm vücudun görünmeli',
                  )
                else if (!_isPaused &&
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
    final targets = ref.read(tourTargetsProvider);
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
      repCounterKey: targets.workoutRepCounter,
      formIndicatorKey: targets.workoutFormIndicator,
      pauseControlKey: targets.workoutPauseControl,
      nextControlKey: targets.workoutNextControl,
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

  /// Phase 138 · M-2 · gatekeeper for mid-session exits. Shows a
  /// confirmation dialog so a stray back-tap doesn't void the user's
  /// in-progress workout. The natural completion path (session-
  /// complete overlay → `_exit`) skips this gate because by then
  /// the session is already done.
  Future<void> _confirmAndExit(BuildContext context) async {
    final session = ref.read(workoutSessionProvider).value;
    // If there's no session, or the session has already completed,
    // bail straight out — there's nothing left to lose.
    if (session == null || session.isSessionComplete) {
      _exit(context);
      return;
    }
    AppHaptics.secondaryTap();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _neon.withValues(alpha: 0.45)),
        ),
        title: const Text(
          'Antrenmanı bırakmak istiyor musun?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'İlerlemen kaydedildi. Ana ekrana dönersen aynı seanstan '
          'devam edemezsin.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('Devam et'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Bırak'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      _exit(context);
    }
  }
}

/// Roadmap Phase 3b · the voice coach's mute switch, on the surface where
/// the coach actually speaks.
///
/// Settings would have been the tidier home and the wrong one: the moment
/// a user needs this is the moment someone walks into the room mid-set,
/// and a control that costs them their session to reach is a control they
/// resent. It carries a state-dependent semantic label because an
/// icon-only toggle announces nothing useful otherwise.
class _VoiceToggleButton extends StatelessWidget {
  const _VoiceToggleButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: enabled,
      label: enabled ? 'Sesli koçu kapat' : 'Sesli koçu aç',
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24, width: 1),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            // 12 + 20 + 12 = 44dp of ink, matched to WorkoutBackButton's
            // footprint so the two read as one control cluster.
            padding: const EdgeInsets.all(12),
            child: Icon(
              enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: enabled ? Colors.white : Colors.white54,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Roadmap Phase 3 feature 6 · "…accessible from the workout screen's
/// overflow menu forever after". A user who forgets how far back to stand
/// three weeks from now shouldn't have to reinstall to be told again.
class _WorkoutOverflowMenu extends StatelessWidget {
  const _WorkoutOverflowMenu({required this.onReplayGuide});

  static const Color _neon = Color(0xFF00F0FF);

  final VoidCallback onReplayGuide;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Antrenman seçenekleri',
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24, width: 1),
        ),
        child: PopupMenuButton<String>(
          tooltip: 'Antrenman seçenekleri',
          color: const Color(0xFF160C26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _neon.withValues(alpha: 0.35)),
          ),
          padding: EdgeInsets.zero,
          // 44dp target — a PopupMenuButton's default icon padding is
          // below the 48dp guideline this app holds elsewhere.
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
          ),
          onSelected: (value) {
            if (value == 'guide') onReplayGuide();
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'guide',
              child: Row(
                children: [
                  Icon(Icons.center_focus_strong_rounded,
                      color: _neon, size: 19),
                  SizedBox(width: 11),
                  Flexible(
                    child: Text(
                      'Kamera kurulumunu tekrar göster',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  // Store-submission U7 · this card renders as a standalone pre-camera
  // gate, so it follows the brand purple, not the in-workout cyan.
  static const Color _neon = Color(0xFF8E5BFF);

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
