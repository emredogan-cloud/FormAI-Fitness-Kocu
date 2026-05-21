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
