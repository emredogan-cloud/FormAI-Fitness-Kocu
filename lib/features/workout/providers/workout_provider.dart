import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../../progress/domain/streak_calculator.dart';
import '../data/session_log_repository.dart';
import '../data/workout_repository.dart';
import '../domain/services/workout_generator_service.dart';
import '../models/exercise_model.dart';
import '../models/session_log_model.dart';
import '../models/workout_day_model.dart';
import '../models/workout_plan_model.dart';

/// Shared singleton repository instance. Phase 50A · centralises the
/// in-memory exercise cache so the antrenman tab, push-limits strip and
/// session notifier all see the same fetched catalogue.
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return WorkoutRepository(prefs);
});

/// Catalogue of region-tagged plans surfaced on the dashboard's filter
/// strip. Phase 50A · resolved asynchronously from the Supabase
/// `exercises` table, so the consumer must `.when` over the AsyncValue
/// for loading and error states.
final workoutPlansProvider = FutureProvider<List<WorkoutPlan>>((ref) {
  return ref.watch(workoutRepositoryProvider).getAllPlans();
});

/// "Ekipmanlı Egzersizler" cards for the dashboard strip. Materialised
/// from the same fetched catalogue that powers [workoutPlansProvider];
/// the shared repository keeps both providers off independent network
/// calls.
final equipmentPlansProvider = FutureProvider<List<WorkoutPlan>>((ref) {
  return ref.watch(workoutRepositoryProvider).getEquipmentPlans();
});

/// Phase 134 · raw exercise catalogue exposed for the "Yeni Egzersizler"
/// regions-menu strip and any future surface that needs per-exercise
/// data (e.g. an exercise-detail browse view). Backed by the same
/// in-flight memoisation [WorkoutRepository._exercisesFuture] uses for
/// plan resolution, so concurrent consumers coalesce on a single fetch.
final exercisesProvider = FutureProvider<List<Exercise>>((ref) {
  return ref.watch(workoutRepositoryProvider).getAllExercises();
});

/// Progress Phase 2.B · in-flight per-exercise totals accumulated
/// across the day's sets. Materialised into [ExerciseLog] entries by
/// `_buildSessionLog` on day-completion. Mutable on purpose — it lives
/// for the duration of one workout session and is wiped between
/// sessions.
class _PendingExerciseLog {
  _PendingExerciseLog({required this.exercise});
  final Exercise exercise;
  int actualSets = 0;
  int actualReps = 0;
  int durationSeconds = 0;
}

class WorkoutSessionState {
  const WorkoutSessionState({
    this.days = const [],
    this.activeDay,
    this.activeExerciseIndex = 0,
    this.currentReps = 0,
    this.currentSet = 1,
    this.isResting = false,
    this.restSecondsRemaining = 0,
    this.isSessionComplete = false,
    this.isPreparing = false,
    this.prepSecondsRemaining = 0,
    this.isStub = false,
  });

  final List<WorkoutDay> days;
  final WorkoutDay? activeDay;
  final int activeExerciseIndex;
  final int currentReps;
  final int currentSet;
  final bool isResting;
  final int restSecondsRemaining;
  final bool isSessionComplete;

  /// True for the 3-second "HAZIRLAN!" countdown that precedes every
  /// exercise (workout start + after every inter-exercise rest). The
  /// camera screen swaps in a prep overlay and the analyzer skips frames
  /// while this is true.
  final bool isPreparing;
  final int prepSecondsRemaining;

  /// `true` when [days] is the repository's offline-fallback (30 rest
  /// days returned because no plan cache existed AND the live exercise
  /// pool came back empty). The UI must NOT render success states like
  /// "Tebrikler, tamamlandı" off a stub — `_firstIncomplete` returns
  /// null on an all-rest-day list and the dashboard would mistake the
  /// placeholder for a finished program. Surface a "Senkronize
  /// ediliyor / Bağlantı yok" tile instead.
  final bool isStub;

  Exercise? get activeExercise {
    final day = activeDay;
    if (day == null) return null;
    if (activeExerciseIndex < 0 ||
        activeExerciseIndex >= day.exercises.length) {
      return null;
    }
    return day.exercises[activeExerciseIndex];
  }

  /// Exercise the user will land on AFTER the current rest finishes.
  /// During rest between sets it stays on the same exercise; during rest
  /// between exercises it points at the next entry in the day.
  Exercise? get upcomingExercise {
    final day = activeDay;
    if (day == null) return null;
    if (!isResting) return activeExercise;
    final exercise = activeExercise;
    if (exercise == null) return null;
    if (currentSet > exercise.sets) {
      final nextIndex = activeExerciseIndex + 1;
      if (nextIndex >= day.exercises.length) return null;
      return day.exercises[nextIndex];
    }
    return exercise;
  }

  int? get repsRemaining {
    final target = activeExercise?.targetReps;
    if (target == null) return null;
    final remaining = target - currentReps;
    return remaining < 0 ? 0 : remaining;
  }

  WorkoutSessionState copyWith({
    List<WorkoutDay>? days,
    WorkoutDay? activeDay,
    int? activeExerciseIndex,
    int? currentReps,
    int? currentSet,
    bool? isResting,
    int? restSecondsRemaining,
    bool? isSessionComplete,
    bool? isPreparing,
    int? prepSecondsRemaining,
    bool? isStub,
  }) {
    return WorkoutSessionState(
      days: days ?? this.days,
      activeDay: activeDay ?? this.activeDay,
      activeExerciseIndex: activeExerciseIndex ?? this.activeExerciseIndex,
      currentReps: currentReps ?? this.currentReps,
      currentSet: currentSet ?? this.currentSet,
      isResting: isResting ?? this.isResting,
      restSecondsRemaining: restSecondsRemaining ?? this.restSecondsRemaining,
      isSessionComplete: isSessionComplete ?? this.isSessionComplete,
      isPreparing: isPreparing ?? this.isPreparing,
      prepSecondsRemaining: prepSecondsRemaining ?? this.prepSecondsRemaining,
      isStub: isStub ?? this.isStub,
    );
  }
}

class WorkoutSessionNotifier extends AsyncNotifier<WorkoutSessionState> {
  late WorkoutRepository _repository;
  Timer? _restTimer;
  Timer? _prepTimer;

  /// Set when [_enterRest] is called for an inter-EXERCISE rest (vs an
  /// inter-SET rest within the same exercise). Read by the rest timer
  /// completion to decide whether to launch a HAZIRLAN! prep countdown.
  bool _restPrecedesExerciseChange = false;

  /// Progress Phase 2.B · wall-clock moment the active set transitioned
  /// from prep/rest into "user is repping." Used to compute per-set
  /// duration captured into [_pendingExerciseLogs] when the set finishes.
  /// Null during prep / rest / between sessions.
  DateTime? _setStartedAt;

  /// Progress Phase 2.B · in-flight per-exercise accumulator, keyed by
  /// `Exercise.id`. Each entry sums actualSets + actualReps + duration
  /// across the day's sets so that, on the day-completion branch, we
  /// can build a single [SessionLog] without walking the day's exercise
  /// list a second time. Cleared on `startDay` / `initializeWorkout` /
  /// `previousExercise` / `resetProgress` so a stale partial run can't
  /// leak into the next session.
  final Map<String, _PendingExerciseLog> _pendingExerciseLogs = {};

  static const Duration _prepDuration = Duration(seconds: 3);

  @override
  Future<WorkoutSessionState> build() async {
    // Phase 50A · prefer the shared repository so the in-memory exercise
    // cache is reused across the antrenman tab, push-limits strip and
    // this notifier. Fall back to a fresh instance if the override is
    // missing (e.g. some unit tests stub `sharedPreferencesProvider`).
    try {
      _repository = ref.read(workoutRepositoryProvider);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _repository = WorkoutRepository(prefs);
    }
    final result = await _loadProgram();
    final activeDay = _firstIncomplete(result.days);
    ref.onDispose(_cancelRestTimer);
    ref.onDispose(_cancelPrepTimer);
    return WorkoutSessionState(
      days: result.days,
      activeDay: activeDay,
      isStub: result.isStub,
    );
  }

  /// Resolves the user's stored goal + activity level (set during the
  /// onboarding wizard) and hands them to the repository's cache-or-
  /// generate pipeline.
  ///
  /// Two sources are tried for the goal before giving up:
  ///
  ///   1. `userMetrics['targetPhysique']` — the full wizard payload
  ///      saved by onboarding / profile-edit.
  ///   2. `prefs.goal` — the flat `sixpack.goal` string written by
  ///      `completeOnboarding`. This is the fallback for legacy installs
  ///      that onboarded before the metrics-save was wired in (otherwise
  ///      those users would be stuck on the sixpack default forever even
  ///      though they picked bulk or tone).
  ///
  /// If both are absent, the repository/generator's own defaults
  /// (sixpack + beginner) kick in — never an empty 30-day list.
  Future<({List<WorkoutDay> days, bool isStub})> _loadProgram() async {
    final appPrefs = ref.read(appPreferencesProvider);
    final metrics = appPrefs.userMetrics ?? const <String, dynamic>{};
    final userGoal = (metrics['targetPhysique'] as String?) ?? appPrefs.goal;
    final fitnessLevel = metrics['activityLevel'] as String?;
    // Phase 133 · equipment filter signal. Reads through the dedicated
    // AppPreferences key (set at `completeOnboarding`). Null on legacy
    // installs — the repository treats that as "preserve current
    // behaviour" (≡ has-equipment).
    final hasEquipment = appPrefs.hasEquipment;
    return _repository.loadOrGenerateProgram(
      generator: ref.read(workoutGeneratorProvider),
      userGoal: userGoal,
      fitnessLevel: fitnessLevel,
      hasEquipment: hasEquipment,
    );
  }

  void setCurrentReps(int reps) {
    final current = state.value;
    if (current == null || current.isResting) return;
    state = AsyncData(current.copyWith(currentReps: reps));
  }

  void acknowledgeSessionComplete() {
    final current = state.value;
    if (current == null || !current.isSessionComplete) return;
    state = AsyncData(current.copyWith(isSessionComplete: false));
  }

  Future<void> startDay(int dayNumber) async {
    final current = state.value;
    if (current == null) return;
    _cancelRestTimer();
    _cancelPrepTimer();
    // Progress Phase 2.B · drop any leftover accumulator state from a
    // previous abandoned session before starting a fresh day.
    _pendingExerciseLogs.clear();
    _setStartedAt = null;
    final day = current.days.firstWhere(
      (d) => d.dayNumber == dayNumber,
      orElse: () => current.days.first,
    );
    state = AsyncData(current.copyWith(
      activeDay: day,
      activeExerciseIndex: 0,
      currentReps: 0,
      currentSet: 1,
      isResting: false,
      restSecondsRemaining: 0,
      isSessionComplete: false,
    ));
    // Phase 42 analytics — fire after state transition so the funnel
    // lines up with the actual user-visible "workout started" moment.
    AnalyticsService.instance.workoutStarted(dayNumber: dayNumber);
    _startPrep();
  }

  /// Starts an ad-hoc session from a dashboard/plan-detail entry point.
  /// Stamps a synthetic [WorkoutDay] with `dayNumber: 0` so the completion
  /// logic below knows NOT to persist this run as a real program-day
  /// completion — ad-hoc plans don't move the 30-day needle.
  void initializeWorkout(List<Exercise> exercises) {
    final current = state.value;
    if (current == null || exercises.isEmpty) return;
    _cancelRestTimer();
    _cancelPrepTimer();
    _pendingExerciseLogs.clear();
    _setStartedAt = null;
    final adHocDay = WorkoutDay(dayNumber: 0, exercises: exercises);
    state = AsyncData(current.copyWith(
      activeDay: adHocDay,
      activeExerciseIndex: 0,
      currentReps: 0,
      currentSet: 1,
      isResting: false,
      restSecondsRemaining: 0,
      isSessionComplete: false,
    ));
    // Ad-hoc run — dayNumber 0 so the funnel can segment program days
    // from Ekipmanlı Egzersizler / regional launches.
    AnalyticsService.instance.workoutStarted(
      dayNumber: 0,
      exerciseName: exercises.first.name,
    );
    _startPrep();
  }

  /// Called when a single set finishes (reps target hit OR time elapsed).
  /// Advances the set/exercise pointer and starts the rest timer between
  /// pieces of work. Marking the day complete only happens after the LAST
  /// set of the LAST exercise, so the user can't accidentally skip ahead.
  Future<void> completeCurrentExercise() async {
    final current = state.value;
    final day = current?.activeDay;
    final exercise = current?.activeExercise;
    if (current == null || day == null || exercise == null) return;
    if (current.isResting) return;

    // Progress Phase 2.B · capture the just-finished set into the
    // per-day accumulator. Runs BEFORE the state mutation that resets
    // `currentReps` so the accumulator reads the last-known rep count
    // for this set. Ad-hoc runs (`dayNumber <= 0`) accumulate too, but
    // the day-completion branch below skips persisting them — Phase 2
    // logs are scoped to the 30-day program.
    _captureCompletedSet(current, exercise);

    final isLastSet = current.currentSet >= exercise.sets;
    if (!isLastSet) {
      _enterRest(
        current.copyWith(
          currentReps: 0,
          currentSet: current.currentSet + 1,
        ),
        exercise.restDurationInSeconds,
        isExerciseChange: false,
      );
      return;
    }

    final nextIndex = current.activeExerciseIndex + 1;
    if (nextIndex < day.exercises.length) {
      final nextExercise = day.exercises[nextIndex];
      _enterRest(
        current.copyWith(
          activeExerciseIndex: nextIndex,
          currentReps: 0,
          currentSet: 1,
        ),
        nextExercise.restDurationInSeconds,
        isExerciseChange: true,
      );
      return;
    }

    // dayNumber == 0 indicates an ad-hoc plan started via
    // `initializeWorkout` — those runs don't persist to the 30-day program
    // completion ledger, so skip markDayCompleted + loadProgram for them.
    final isAdHoc = day.dayNumber <= 0;
    if (!isAdHoc) {
      await _repository.markDayCompleted(day.dayNumber);
      // Progress Phase 2.B · persist the day's session log alongside
      // the completion flag. Wrapped in try/catch so a corrupt
      // SharedPreferences write can't break completion — the
      // `isCompleted` flag is still the authoritative signal; logs are
      // additive UX. Invalidate the read provider so the gelisim_tab
      // stats cards see the fresh data on the next render.
      try {
        final log = _buildSessionLog(day);
        await ref.read(sessionLogRepositoryProvider).saveLog(log);
        ref.invalidate(sessionLogsProvider);
      } catch (e, st) {
        AppLogger.error(
          'SessionLog save failed — completion succeeded, log dropped',
          e,
          stackTrace: st,
          category: 'progress',
        );
      }
    }
    _pendingExerciseLogs.clear();
    _setStartedAt = null;
    final refreshedResult = isAdHoc
        ? (days: current.days, isStub: current.isStub)
        : await _loadProgram();
    final refreshed = refreshedResult.days;
    // Phase 52 · maintain the all-time-high streak watermark so the
    // AI Coach card can detect the "comeback" state (live streak == 0
    // but a past best exists) and the XP listener can pay streak
    // milestones. Now derived from the REAL calendar-day streak over
    // session-log timestamps (this completion's log was saved above),
    // not the old leading-program-run count that capped at 3.
    try {
      final logs = await ref.read(sessionLogRepositoryProvider).loadAll();
      final newStreak = calendarStreak(
        [
          for (final log in logs)
            if (DateTime.tryParse(log.completedAtIso) != null)
              DateTime.parse(log.completedAtIso),
          DateTime.now(), // this completion counts even for ad-hoc runs
        ],
        now: DateTime.now(),
      );
      await ref.read(appPreferencesProvider).bumpMaxStreakIfHigher(newStreak);
    } catch (e, st) {
      AppLogger.error(
        'max-streak bump failed (non-fatal)',
        e,
        stackTrace: st,
        category: 'progress',
      );
    }
    // Phase 58 · stamp the wall-clock so the smart notification
    // scheduler can tell "user trained today" apart from "user
    // trained yesterday". Tracked for ad-hoc runs too — the
    // reminder cares about "did you work out today", not "did you
    // tick the next 30-day box".
    await ref.read(appPreferencesProvider).setLastWorkoutAt(DateTime.now());
    final updatedDay = isAdHoc
        ? day.copyWith(isCompleted: true)
        : refreshed.firstWhere(
            (d) => d.dayNumber == day.dayNumber,
            orElse: () => day.copyWith(isCompleted: true),
          );
    _cancelRestTimer();
    // Guard: sign-out / pull-to-refresh can invalidate this notifier
    // during the awaits above — `state =` on the disposed instance
    // throws (zone-caught) and silently drops the completion update.
    if (!ref.mounted) return;
    state = AsyncData(current.copyWith(
      days: refreshed,
      activeDay: updatedDay,
      activeExerciseIndex: 0,
      currentReps: 0,
      currentSet: 1,
      isResting: false,
      restSecondsRemaining: 0,
      isSessionComplete: true,
      isStub: refreshedResult.isStub,
    ));
    // Phase 42 analytics — end-of-session marker. dayNumber 0 for ad-hoc
    // runs so the funnel can count "completed a workout" without mixing
    // 30-day progress into the same event.
    AnalyticsService.instance.workoutCompleted(dayNumber: day.dayNumber);
  }

  void skipRest() {
    final current = state.value;
    if (current == null || !current.isResting) return;
    _cancelRestTimer();
    // Tier-B.8 · clear the per-tick countdown provider alongside the
    // session-state flip so the rest overlay doesn't paint a stale
    // remaining-seconds value on its way out.
    ref.read(restCountdownProvider.notifier).set(0);
    state = AsyncData(current.copyWith(
      isResting: false,
      restSecondsRemaining: 0,
    ));
    if (_restPrecedesExerciseChange) {
      _startPrep();
    } else {
      // Progress Phase 2.B · same logic as the rest-end branch — when
      // the user skips an inter-set rest, the next set begins
      // immediately so the start-stamp lands here.
      _markSetStarted();
    }
    _restPrecedesExerciseChange = false;
  }

  /// Phase 47B · user tapped the "Önceki egzersize geçiş" control.
  ///
  /// Rewinds [activeExerciseIndex] by one position and resets
  /// [currentReps] / [currentSet] so the previous movement starts
  /// clean. Any in-flight rest or prep countdown is cancelled — if
  /// the user is backing up, they are choosing to skip the recovery
  /// window. A 3-second HAZIRLAN! prep fires for the rewound exercise
  /// so the camera/analyzer rebinds against it before the first rep
  /// is counted.
  ///
  /// No-ops when the pointer is already at index 0 (nothing to go
  /// back to) or when the session has no active day.
  void previousExercise() {
    final current = state.value;
    final day = current?.activeDay;
    if (current == null || day == null) return;
    if (current.activeExerciseIndex <= 0) return;

    _cancelRestTimer();
    _cancelPrepTimer();
    _restPrecedesExerciseChange = false;
    // Progress Phase 2.B · the user is rewinding to redo a prior
    // exercise. Drop the accumulator entry for the *new* active
    // exercise (after the index decrement) so a re-run starts clean.
    final rewoundIndex = current.activeExerciseIndex - 1;
    if (rewoundIndex >= 0 && rewoundIndex < day.exercises.length) {
      _pendingExerciseLogs.remove(day.exercises[rewoundIndex].id);
    }
    _setStartedAt = null;

    final nextIndex = current.activeExerciseIndex - 1;
    state = AsyncData(current.copyWith(
      activeExerciseIndex: nextIndex,
      currentReps: 0,
      currentSet: 1,
      isResting: false,
      restSecondsRemaining: 0,
      isSessionComplete: false,
    ));
    _startPrep();
  }

  Future<void> resetProgress() async {
    await _repository.resetProgress();
    final result = await _loadProgram();
    _cancelRestTimer();
    // Progress Phase 2.B · `WorkoutRepository.resetProgress` already
    // clears the persisted session-log file; drop the in-flight
    // accumulator + start-stamp here too so a reset triggered mid-
    // session can't leak prior reps into the next day's log.
    _pendingExerciseLogs.clear();
    _setStartedAt = null;
    ref.invalidate(sessionLogsProvider);
    // Guard: same disposed-notifier race as completeCurrentExercise.
    if (!ref.mounted) return;
    state = AsyncData(WorkoutSessionState(
      days: result.days,
      activeDay: _firstIncomplete(result.days),
      isStub: result.isStub,
    ));
  }

  void _enterRest(
    WorkoutSessionState base,
    int seconds, {
    required bool isExerciseChange,
  }) {
    _cancelRestTimer();
    _restPrecedesExerciseChange = isExerciseChange;
    final clamped = seconds <= 0 ? 0 : seconds;
    // Tier-B.8 · session state mutates ONLY here on rest entry
    // (isResting=true + initial seconds frozen) and on the rest-end
    // transition below. Per-second ticks land on
    // `restCountdownProvider` instead, so listeners that only care
    // about session transitions stop running every second.
    state = AsyncData(base.copyWith(
      isResting: clamped > 0,
      restSecondsRemaining: clamped,
    ));
    ref.read(restCountdownProvider.notifier).set(clamped);
    if (clamped <= 0) {
      // Zero-second rest is effectively immediate transition — fire prep
      // straight away so the user still gets the HAZIRLAN! countdown.
      if (_restPrecedesExerciseChange) {
        _startPrep();
      }
      _restPrecedesExerciseChange = false;
      return;
    }

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.value;
      if (current == null || !current.isResting) {
        timer.cancel();
        return;
      }
      final remaining = ref.read(restCountdownProvider) - 1;
      if (remaining <= 0) {
        timer.cancel();
        _restTimer = null;
        ref.read(restCountdownProvider.notifier).set(0);
        // Single session-state mutation per rest end.
        state = AsyncData(current.copyWith(
          isResting: false,
          restSecondsRemaining: 0,
        ));
        if (_restPrecedesExerciseChange) {
          // Inter-exercise rest → fire prep countdown; the prep-end
          // branch will mark the set started once the user is actually
          // ready to rep.
          _startPrep();
        } else {
          // Inter-set rest within the same exercise — no prep
          // countdown. The next set begins immediately, so the
          // start-stamp lands here.
          _markSetStarted();
        }
        _restPrecedesExerciseChange = false;
      } else {
        // Tier-B.8 · per-second decrement no longer touches the
        // session state. The rest overlay watches
        // `restCountdownProvider`, the camera-screen listener only
        // fires on real session transitions.
        ref.read(restCountdownProvider.notifier).set(remaining);
      }
    });
  }

  /// Kicks off the 3-second HAZIRLAN! countdown. Each tick decrements
  /// `prepSecondsRemaining`; the final tick flips `isPreparing` back to
  /// false so the analyzer wakes up for the new exercise.
  void _startPrep() {
    _cancelPrepTimer();
    final current = state.value;
    if (current == null || current.activeExercise == null) return;
    final initial = _prepDuration.inSeconds;
    state = AsyncData(current.copyWith(
      isPreparing: true,
      prepSecondsRemaining: initial,
    ));
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final cur = state.value;
      if (cur == null || !cur.isPreparing) {
        timer.cancel();
        return;
      }
      final remaining = cur.prepSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        _prepTimer = null;
        state = AsyncData(cur.copyWith(
          isPreparing: false,
          prepSecondsRemaining: 0,
        ));
        // Progress Phase 2.B · prep just ended → user is now repping.
        // This is the canonical "set started" moment for inter-exercise
        // and start-of-day transitions.
        _markSetStarted();
      } else {
        state = AsyncData(cur.copyWith(prepSecondsRemaining: remaining));
      }
    });
  }

  void _cancelRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  void _cancelPrepTimer() {
    _prepTimer?.cancel();
    _prepTimer = null;
  }

  /// Skips rest days: they never flow through `markDayCompleted`, so
  /// including them would cause the session to "resume" on a day with
  /// no exercises.
  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final day in days) {
      if (day.isRestDay) continue;
      if (!day.isCompleted) return day;
    }
    return null;
  }

  /// Progress Phase 2.B · stamps the wall-clock at the moment the
  /// active set transitions from prep/rest into "user is repping". The
  /// difference between this stamp and the [completeCurrentExercise]
  /// call is captured as the set's duration in [_captureCompletedSet].
  void _markSetStarted() {
    _setStartedAt = DateTime.now();
  }

  /// Progress Phase 2.B · folds the just-finished set into the
  /// per-day accumulator. `currentReps == 0` falls back to the
  /// exercise's `targetReps` so a user who skipped pose detection
  /// (or completed manually without entering reps) still gets a
  /// defensible record rather than a zero-rep ghost.
  void _captureCompletedSet(WorkoutSessionState current, Exercise exercise) {
    final actualReps = current.currentReps > 0
        ? current.currentReps
        : (exercise.targetReps ?? 0);
    final setDuration = _setStartedAt == null
        ? 0
        : DateTime.now().difference(_setStartedAt!).inSeconds;
    final pending = _pendingExerciseLogs.putIfAbsent(
      exercise.id,
      () => _PendingExerciseLog(exercise: exercise),
    );
    pending.actualSets += 1;
    pending.actualReps += actualReps;
    pending.durationSeconds += setDuration < 0 ? 0 : setDuration;
    _setStartedAt = null;
  }

  /// Progress Phase 2.B · materialises a [SessionLog] from the
  /// in-flight accumulator. Iterates the day's exercises in their
  /// canonical order so the log preserves the program's intended
  /// sequence even if the user backed out of an exercise mid-flow.
  /// Exercises the user never reached collapse to a zero-actual log
  /// — never omitted — so the calendar drilldown can still show them
  /// as "planned but skipped" if a future Phase wants that.
  SessionLog _buildSessionLog(WorkoutDay day) {
    final exerciseLogs = day.exercises.map((ex) {
      final pending = _pendingExerciseLogs[ex.id];
      return ExerciseLog(
        exerciseId: ex.id,
        exerciseName: ex.name,
        targetMuscle: ex.targetMuscle,
        isCardio: ex.isCardio,
        plannedSets: ex.sets,
        plannedReps: ex.targetReps ?? 0,
        actualSets: pending?.actualSets ?? 0,
        actualReps: pending?.actualReps ?? 0,
        durationSeconds: pending?.durationSeconds ?? 0,
      );
    }).toList(growable: false);
    final totalDuration =
        exerciseLogs.fold<int>(0, (sum, e) => sum + e.durationSeconds);
    return SessionLog(
      dayNumber: day.dayNumber,
      completedAtIso: DateTime.now().toIso8601String(),
      durationSeconds: totalDuration,
      exerciseLogs: exerciseLogs,
    );
  }
}

final workoutSessionProvider =
    AsyncNotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>(
  WorkoutSessionNotifier.new,
);

/// Tier-B.8 · live per-second rest countdown. Previously the rest
/// tick was held inside `WorkoutSessionState.restSecondsRemaining`,
/// which meant every tick emitted a new `workoutSessionProvider`
/// state — the camera screen's `ref.listen` body, the iOS Live
/// Activity sync, and every other workout-state consumer all ran
/// once per second. Most of that work was no-ops.
///
/// The countdown now lives in its own minimal provider that only the
/// rest overlay watches. `workoutSessionProvider` only re-emits when
/// real session transitions happen — rest enter, rest exit, exercise
/// change, etc. The `restSecondsRemaining` field on the session state
/// is preserved but now holds the INITIAL rest duration (frozen at
/// rest entry); the live decrement lives here.
///
/// Implemented as a `Notifier<int>` because Riverpod 3 removed the
/// older `StateProvider`. The notifier exposes a `set` method so the
/// session timer can write without touching `state` directly through
/// `notifier.state =` (banned in Riverpod 3 outside the notifier
/// class itself).
class RestCountdownNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Replaces the current countdown value. Called from the workout
  /// session notifier's rest timer once per second, and at rest
  /// enter/exit/skip transitions.
  void set(int seconds) {
    state = seconds < 0 ? 0 : seconds;
  }
}

final restCountdownProvider =
    NotifierProvider<RestCountdownNotifier, int>(RestCountdownNotifier.new);
