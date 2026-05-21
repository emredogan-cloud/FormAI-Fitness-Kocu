import 'dart:async';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/audio_feedback.dart';
import '../models/exercise_model.dart';

/// Tier-A coaching coordinator. Sits between the camera screen's
/// lifecycle events and [AudioFeedback], emitting ambient coaching
/// at the right cadence without spamming the user.
///
/// Three concerns live here:
///   1. **Mid-set heartbeat** — rotating category-aware coaching lines
///      while the user is actively repping, every [_midSetCadence].
///   2. **Timed-exercise pacing** — halfway / final-10s / final-5s cues
///      derived from the camera screen's per-second timer ticks.
///   3. **Rest coaching** *(wired in commit 3)* — recovery + transition
///      prep beats during inter-set / inter-exercise rest.
///
/// All speech goes through [AudioFeedback.speak] at one of three
/// priorities so the [SpeechPriority] queue's pre-emption rules
/// guarantee a real `warning` from an analyzer always lands cleanly
/// over a heartbeat cue.
///
/// The class is reset-on-set-boundary and dispose-safe: every timer is
/// cancelled in [dispose] / [endSet] / [endRest] so a navigation pop
/// during an active set doesn't leak callbacks.
class CoachVoice {
  CoachVoice(this._audio);

  final AudioFeedback _audio;

  // Mid-set heartbeat state ──────────────────────────────────────────
  Timer? _midSetTimer;
  ExerciseCategory? _activeCategory;
  bool _activeIsCardio = false;
  int _midSetIndex = 0;

  // Rest coaching state ─────────────────────────────────────────────
  Timer? _restTimer;

  /// Tracks the wall-clock at which the current rest window started so
  /// the rest scheduler can derive "halfway" + "final 10 s" beats
  /// independently from the camera screen's countdown widget. Null
  /// outside of an active rest.
  DateTime? _restStartedAt;

  /// Total seconds the rest window was scheduled for, captured on
  /// `startRest`. Null outside rest.
  int? _restInitialSeconds;

  /// Rotation index for the generic rest-window coaching lines, so a
  /// long inter-exercise rest (e.g. 90 s) doesn't repeat the same line.
  int _restGenericIndex = 0;

  /// Single-shot gates for the halfway / 10 s / 5 s rest beats.
  /// Cleared on startRest/endRest.
  final Set<String> _firedRestCheckpoints = <String>{};

  // Tracking-guidance state ─────────────────────────────────────────
  /// Number of consecutive low-confidence frames seen since the last
  /// clean frame. Resets whenever a clean frame arrives, increments on
  /// every low frame; once it crosses
  /// [_lowConfidenceFramesThreshold] we surface a single coaching cue
  /// and continue gating via [_lastTrackingCue].
  int _lowConfidenceStreak = 0;

  /// Last wall-clock at which a tracking-guidance cue fired. Seeded 5
  /// minutes in the past so the very first sustained low-confidence
  /// window can warn immediately on session start.
  DateTime _lastTrackingCue =
      DateTime.now().subtract(const Duration(minutes: 5));

  /// Rotation index for the tracking-guidance pool. Different lines
  /// rotate so a user who keeps stepping out of frame doesn't hear the
  /// same exact phrase every 30 s.
  int _trackingCueIndex = 0;

  /// How often to fire the rotating mid-set coaching line while the
  /// user is actively repping. 18 s is dense enough to feel present
  /// without becoming chatty — the analyzer's own warnings and the
  /// rep-milestone announcements layer on top through the priority
  /// queue.
  static const Duration _midSetCadence = Duration(seconds: 18);

  /// Rest-tick cadence — the rest coach runs at 1 Hz so it can act on
  /// per-second remaining checkpoints. Each tick decides whether to
  /// emit anything based on elapsed-vs-total and the
  /// `_firedRestCheckpoints` gate. Cheap: no allocations in the
  /// no-emit branch.
  static const Duration _restTickCadence = Duration(seconds: 1);

  /// Tracking-guidance — landmark mean likelihood below this on a
  /// given frame counts the frame as "low confidence." Above this the
  /// streak resets. 0.35 is just below the analyzer's per-landmark
  /// reject threshold (0.40), so a frame the analyzers won't act on
  /// is the same frame this coach calls "low confidence."
  static const double _lowConfidenceThreshold = 0.35;

  /// How many consecutive low-confidence frames are needed before we
  /// surface a cue. At the camera screen's ~15 FPS effective rate, 30
  /// frames is ~2 s of sustained poor tracking — enough that a brief
  /// occlusion (the user reaching off-screen for a dumbbell, the
  /// hand passing in front of the chest) doesn't trip the warning.
  static const int _lowConfidenceFramesThreshold = 30;

  /// Minimum gap between two tracking-guidance cues. The user knows
  /// after one announcement; nagging at 5 s intervals is harassment.
  static const Duration _trackingCueCooldown = Duration(seconds: 45);

  // Timed-exercise pacing state ──────────────────────────────────────
  /// Total duration of the active timed exercise's set, captured on
  /// `onTimedExerciseStart`. Drives the halfway / 10s / 5s gates.
  int? _timedInitialSeconds;

  /// Set of pacing checkpoints we've already fired for the current
  /// timed set. Cleared in `endSet` / `startSet`. The string keys are
  /// stable identifiers ("halfway", "final-10", "final-5") rather
  /// than the spoken phrase, so re-tuning the copy later doesn't
  /// re-fire historical checkpoints.
  final Set<String> _firedTimedCheckpoints = <String>{};

  // ─── Public lifecycle hooks ────────────────────────────────────────

  /// Called the moment the user transitions from prep/rest into active
  /// repping. `exercise` is non-null in all real call sites; the null
  /// branch is a defensive no-op.
  void startSet(Exercise? exercise) {
    cancelAll();
    if (exercise == null) return;
    _activeCategory = exercise.category;
    _activeIsCardio = exercise.isCardio;
    _midSetIndex = 0;
    _firedTimedCheckpoints.clear();
    if (exercise.type == ExerciseType.timeBased) {
      _timedInitialSeconds = exercise.targetDurationInSeconds;
    } else {
      _timedInitialSeconds = null;
    }
    _scheduleMidSetTimer();
  }

  /// Called when the active set ends (rep completion, timer complete,
  /// user-initiated next/prev, mid-session pause, screen pop). Idempotent.
  void endSet() {
    cancelAll();
    _activeCategory = null;
    _activeIsCardio = false;
    _timedInitialSeconds = null;
    _firedTimedCheckpoints.clear();
  }

  /// Called for every pose frame the analyzer processes. Pure
  /// observation — no rep/set side-effects. Used to detect sustained
  /// low-confidence tracking and emit a single Turkish positioning
  /// cue with a strict 45 s cooldown.
  ///
  /// [pose] may be null if pose detection returned no result for this
  /// frame; that counts as a low-confidence frame.
  void onPoseFrame(Pose? pose) {
    final double meanLikelihood;
    if (pose == null || pose.landmarks.isEmpty) {
      meanLikelihood = 0.0;
    } else {
      // Subset of landmarks that matter for rep counting across all
      // analyzers — shoulders/hips/knees/ankles/wrists/elbows. Tracking
      // the full 33-point ML Kit set would dilute the signal with
      // face/foot points that the analyzers don't read anyway.
      const tracked = <PoseLandmarkType>[
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.rightElbow,
      ];
      var total = 0.0;
      var count = 0;
      for (final t in tracked) {
        final lm = pose.landmarks[t];
        if (lm != null) {
          total += lm.likelihood;
          count++;
        }
      }
      // Missing landmarks count as zero — a partially-out-of-frame body
      // is exactly the case we want to warn about.
      meanLikelihood = count == 0 ? 0.0 : total / tracked.length;
    }

    if (meanLikelihood < _lowConfidenceThreshold) {
      _lowConfidenceStreak += 1;
      if (_lowConfidenceStreak >= _lowConfidenceFramesThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastTrackingCue) >= _trackingCueCooldown) {
          _lastTrackingCue = now;
          final pool = _trackingCueRotation;
          final phrase = pool[_trackingCueIndex % pool.length];
          _trackingCueIndex += 1;
          // High enough priority to pre-empt ambient/encouragement
          // heartbeats (the user can't follow coaching if the camera
          // can't see them) but below form warnings (a form warning
          // landed means the pose IS being read — different problem).
          _audio.speak(
            phrase,
            priority: SpeechPriority.cue,
            cooldown: const Duration(seconds: 30),
          );
        }
        // Reset the streak after emitting so the next sustained window
        // has to re-cross the threshold before another cue fires.
        _lowConfidenceStreak = 0;
      }
    } else {
      _lowConfidenceStreak = 0;
    }
  }

  /// Called once per second by the camera screen's workout countdown
  /// while a `timeBased` exercise is in progress. Fires the
  /// halfway/final-10s/final-5s pacing checkpoints.
  ///
  /// [remainingSeconds] is the value AFTER the most recent decrement
  /// (i.e. how many seconds are left).
  void onTimerTick(int remainingSeconds) {
    final total = _timedInitialSeconds;
    if (total == null || total <= 0) return;

    // Halfway — only fires for sets long enough that "halfway" reads
    // as a real milestone (< 10 s holds skip the halfway beat).
    if (total >= 10 && remainingSeconds == (total / 2).floor()) {
      _fireOnce('halfway', 'Yarıladın, sık dişini ve dayan!',
          priority: SpeechPriority.encouragement);
    }
    // Final 10 s — only for sets long enough that 10 s left isn't the
    // first half. Avoids a "Son on saniye!" on a 12-second hold.
    if (total >= 20 && remainingSeconds == 10) {
      _fireOnce('final-10', 'Son on saniye, bırakma!',
          priority: SpeechPriority.encouragement);
    }
    // Final 5 s — always announce when applicable, even on shorter sets,
    // because the home stretch is where the user most needs voice support.
    if (total >= 8 && remainingSeconds == 5) {
      _fireOnce('final-5', 'Beş saniye, dayan!',
          priority: SpeechPriority.encouragement);
    }
  }

  /// Cancel any running timers without resetting set-scoped state.
  /// Called on dispose and on pause.
  void cancelAll() {
    _midSetTimer?.cancel();
    _midSetTimer = null;
    _restTimer?.cancel();
    _restTimer = null;
  }

  /// Called when the user transitions into a rest window. The
  /// camera-screen "Harika! Şimdi N saniye dinlenme" line plays
  /// through the milestone path immediately before this — the rest
  /// coach picks up after.
  ///
  /// Three things happen across the rest:
  ///   1. Halfway beat (rest >= 30 s, at elapsed ≈ total/2):
  ///      "Nefesini topla, yarısı geçti."
  ///   2. Final 10 s (rest >= 20 s, at remaining == 10):
  ///      "On saniye sonra başlıyoruz, hazırlan."
  ///   3. Generic rotating cue every 18 s while rest is in progress
  ///      and at least 12 s of rest remains (so we don't talk over
  ///      the user transitioning into the next set).
  void startRest(int restSeconds) {
    _restTimer?.cancel();
    if (restSeconds <= 0) return;
    _restStartedAt = DateTime.now();
    _restInitialSeconds = restSeconds;
    _firedRestCheckpoints.clear();
    // First generic line lands at the 18 s mark — the milestone
    // "Harika! ... dinlenme" speech (which fires synchronously with
    // startRest) is still finishing in its own queue slot at t=0–3 s.
    _restTimer = Timer.periodic(_restTickCadence, (_) => _restTick());
  }

  /// Called when the rest window ends — naturally (countdown hit 0),
  /// via the skip button, or because the user popped the screen.
  /// Idempotent.
  void endRest() {
    _restTimer?.cancel();
    _restTimer = null;
    _restStartedAt = null;
    _restInitialSeconds = null;
    _firedRestCheckpoints.clear();
  }

  void _restTick() {
    final startedAt = _restStartedAt;
    final total = _restInitialSeconds;
    if (startedAt == null || total == null || total <= 0) return;

    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = total - elapsed;
    if (remaining <= 0) {
      _restTimer?.cancel();
      _restTimer = null;
      return;
    }

    // Halfway beat — only meaningful on rests long enough that
    // "halfway" reads as a real waypoint. 30 s rests get one;
    // shorter rests skip straight to the rotating cue + final 10s.
    if (total >= 30 && elapsed == (total / 2).floor()) {
      _fireOnce('rest-halfway', 'Nefesini topla, yarısı geçti.',
          priority: SpeechPriority.ambient,
          firedSet: _firedRestCheckpoints);
    }

    // Final 10 s — only fires for rests long enough that 10 s left
    // isn't the first half (avoids talking over the rest-start
    // announcement on short windows).
    if (total >= 20 && remaining == 10) {
      _fireOnce('rest-final-10',
          'On saniye sonra başlıyoruz, hazırlan.',
          priority: SpeechPriority.encouragement,
          firedSet: _firedRestCheckpoints);
    }

    // Generic rotation — every 18 s past start, but only while we
    // still have ≥ 12 s of rest left. This prevents a generic line
    // from landing 2 s before the next set's HAZIRLAN! countdown.
    if (remaining >= 12 && elapsed > 0 && elapsed % 18 == 0) {
      final pool = _restRotation;
      final line = pool[_restGenericIndex % pool.length];
      _restGenericIndex += 1;
      _audio.speak(
        line,
        priority: SpeechPriority.ambient,
        cooldown: const Duration(seconds: 20),
      );
    }
  }

  /// Lifecycle: pause the heartbeat (user tapped pause). Timed pacing
  /// keeps firing on the next tick when the workout resumes — the
  /// camera screen's `_resumeWorkoutTimer` re-engages and `onTimerTick`
  /// re-enters cleanly because the fired-checkpoint set is preserved.
  void onPause() {
    _midSetTimer?.cancel();
    _midSetTimer = null;
  }

  /// Lifecycle: resume the heartbeat after pause.
  void onResume() {
    if (_activeCategory != null && _midSetTimer == null) {
      _scheduleMidSetTimer();
    }
  }

  /// Release native resources on widget dispose.
  void dispose() {
    cancelAll();
  }

  // ─── Mid-set heartbeat ─────────────────────────────────────────────

  void _scheduleMidSetTimer() {
    _midSetTimer = Timer.periodic(_midSetCadence, (_) {
      _emitMidSetLine();
    });
  }

  void _emitMidSetLine() {
    final category = _activeCategory;
    if (category == null) return;
    final pool = _midSetLines(category, isCardio: _activeIsCardio);
    if (pool.isEmpty) return;
    final line = pool[_midSetIndex % pool.length];
    _midSetIndex += 1;
    // 14 s phrase-level cooldown ensures the SAME line doesn't fire
    // back-to-back even if a category has a very short rotation pool;
    // different lines bypass dedupe and play normally.
    _audio.speak(
      line,
      priority: SpeechPriority.ambient,
      cooldown: const Duration(seconds: 14),
    );
  }

  /// Category-keyed rotation of mid-set coaching lines. Lists are kept
  /// intentionally short (3–4 entries) so the user hears each line at
  /// most once per ~60 s of active work — long enough that it feels
  /// like coaching rather than a recorded loop.
  ///
  /// Cardio overrides apply when [isCardio] is true regardless of the
  /// nominal category (e.g. burpee is `fullBody` but cardio-tagged).
  static List<String> _midSetLines(
    ExerciseCategory category, {
    required bool isCardio,
  }) {
    if (isCardio) {
      return const [
        'Ritmini koru, nefesini tutma.',
        'Tempoyu sabit tut, patlama anı geliyor.',
        'Hafif diz, esnek omuz — devam!',
        'Nefesi düzenli al, vücudun hazır.',
      ];
    }
    switch (category) {
      case ExerciseCategory.legs:
        return const [
          'Kontrollü in, patlayarak kalk.',
          'Topuğuna bas, dizlerin hizada kalsın.',
          'Karnını sık, gövdeni dik tut.',
          'Nefesini boşalt yukarı kalkarken.',
        ];
      case ExerciseCategory.chest:
        return const [
          'Hareketi aceleye getirme, kasları hisset.',
          'Aşağı inerken nefes al, yukarı iterken ver.',
          'Omuz bıçaklarını sıkı tut, kontrolü kaybetme.',
          'Gövdeni düz tut, kalçayı düşürme.',
        ];
      case ExerciseCategory.back:
        return const [
          'Kürek kemiklerini sıkıştır, sırtla çek.',
          'Hareketi sonuna kadar götür, kontrolünü kaybetme.',
          'Bilekten değil dirsekten çek.',
          'Sırtını hafif kavislendir, omuzları geride tut.',
        ];
      case ExerciseCategory.shoulders:
        return const [
          'Yavaş ve kontrollü kaldır, sallama.',
          'Omuzlarını kulağına çekme, gevşet.',
          'Karnını sık, beli koru.',
          'Tepe noktada bir an dur.',
        ];
      case ExerciseCategory.arms:
        return const [
          'Dirseğini sabit tut, hareketi izole et.',
          'Yavaş indir, kontrolünü hissedin.',
          'Bileği gevşek tut, kası çalıştır.',
          'Tepe noktada bir saniye bekle.',
        ];
      case ExerciseCategory.core:
        return const [
          'Karnını sık, nefesin akıyor olsun.',
          'Beli yere yapışık tut, hareketi yüklenme.',
          'Yavaş gel, çabuk inme.',
          'Karın kaslarını kasarken nefes ver.',
        ];
      case ExerciseCategory.fullBody:
        return const [
          'Bütün vücudu kullan, ritmi düşürme.',
          'Nefesini bırakma, tempoyu koru.',
          'Kontrol senin elinde, devam!',
          'Hafif diz, gevşek omuz.',
        ];
    }
  }

  // ─── Rest-rotation pool ────────────────────────────────────────────

  /// Generic rest-window coaching lines. Light, recovery-flavoured,
  /// non-strenuous — the user should breathe and reset, not be pushed.
  /// Four entries so a 90 s inter-exercise rest can land three of them
  /// (at 18 s, 36 s, 54 s) without repeating.
  static const List<String> _restRotation = [
    'Derin nefes al, kasları gevşet.',
    'Omuzlarını indir, posturanı topla.',
    'Su iç, vücudunu hazırla.',
    'Toparlan, sıradaki set yaklaşıyor.',
  ];

  /// Tracking-guidance lines. Rotated so a user with persistent camera
  /// issues hears actionable variety rather than the same nag. Strict
  /// 45 s cooldown enforced by `_lastTrackingCue` keeps these from
  /// stacking up.
  static const List<String> _trackingCueRotation = [
    'Kameraya biraz daha yaklaş, tüm vücudun görünmeli.',
    'Pozisyonunu ayarla, kamera vücudunu net görsün.',
    'Bir adım geri çekil, vücudun çerçeveye sığsın.',
  ];

  // ─── Fired-once helper ─────────────────────────────────────────────

  void _fireOnce(
    String key,
    String phrase, {
    required SpeechPriority priority,
    Set<String>? firedSet,
  }) {
    final ledger = firedSet ?? _firedTimedCheckpoints;
    if (ledger.contains(key)) return;
    ledger.add(key);
    _audio.speak(phrase,
        priority: priority, cooldown: const Duration(seconds: 4));
  }
}
