import 'dart:async';

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

  /// How often to fire the rotating mid-set coaching line while the
  /// user is actively repping. 18 s is dense enough to feel present
  /// without becoming chatty — the analyzer's own warnings and the
  /// rep-milestone announcements layer on top through the priority
  /// queue.
  static const Duration _midSetCadence = Duration(seconds: 18);

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

  // ─── Fired-once helper ─────────────────────────────────────────────

  void _fireOnce(
    String key,
    String phrase, {
    required SpeechPriority priority,
  }) {
    if (_firedTimedCheckpoints.contains(key)) return;
    _firedTimedCheckpoints.add(key);
    _audio.speak(phrase,
        priority: priority, cooldown: const Duration(seconds: 4));
  }
}
